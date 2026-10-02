//! `/api/v1/system-users`, against the real route table.
//!
//! The refusals and what is recorded, and the listing of the machine the suite
//! runs on — and **never** a change. A create, edit or removal here would add
//! or alter an account on whatever machine ran the suite. What a command is and
//! what is refused before one is built are `sbm_parser::users`' own tests
//! (`crates/sbm_parser/tests/user_compat.rs`) and this module's unit tests.

mod common;

use ntex::http::Method;
use ntex::web::test::TestServer;
use sbm_parser::SystemType;
use serde_json::{Value, json};
use server_box_monitor::monitoring::system_type;

use common::machine::{audit, call, server};

const PATH: &str = "/api/v1/system-users";

async fn act(srv: &TestServer, user: &str, body: Value) -> (u16, Value) {
    call(srv, Some(user), Method::POST, PATH, Some(body)).await
}

#[ntex::test]
async fn both_halves_need_the_shell_grant() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::GET, PATH, None).await;
    assert_eq!(status, 401);

    let (status, body) = call(&srv, Some("viewer"), Method::GET, PATH, None).await;
    assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")));
    let (status, _) = act(
        &srv,
        "viewer",
        json!({"action": "create", "draft": {"name": "svc", "password": "hunter2"}, "password": "sudo-secret"}),
    )
    .await;
    assert_eq!(status, 403);

    let rows = audit(&db).await;
    assert_eq!(rows.len(), 2, "{rows:?}");
    assert!(rows.iter().all(|(action, _, subject, _)| action == "denied" && subject.as_deref() == Some("viewer")));
    // The action and the account, and neither password.
    let detail = rows[1].3.as_deref().unwrap();
    assert_eq!(detail, "system-users create svc: shell not_granted");
}

/// A listing on Linux, and a reason everywhere else. A read is not audited, so
/// a row in the log is always a change or a refusal of one.
#[ntex::test]
async fn the_read_lists_the_machine_or_says_why_not() {
    let (srv, db) = server().await;
    let (status, body) = call(&srv, Some("admin"), Method::GET, PATH, None).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["part"], "list");
    assert!(body["users"].is_array(), "{body}");
    if system_type() != SystemType::Linux {
        assert_eq!(body["available"], false);
        assert_eq!(body["reason_kind"], "unsupported_platform", "{body}");
        assert!(body["agent_account"].is_null(), "no account is named safe to keep without a listing");
    } else if body["available"] == true {
        let agent = body["agent_account"].as_str().unwrap();
        let users = body["users"].as_array().unwrap();
        let root = users.iter().find(|user| user["name"] == "root").expect("every Linux machine has root");
        assert_eq!((root["is_root"].as_bool(), root["deletable"].as_bool()), (Some(true), Some(false)));
        let own = users.iter().find(|user| user["name"] == agent).expect("the agent's account is listed");
        assert_eq!(own["deletable"], false, "{own}");
    }
    assert!(audit(&db).await.is_empty());
}

#[ntex::test]
async fn a_detail_needs_an_account_and_names_one_it_cannot_find() {
    let (srv, _) = server().await;
    let (status, _) = call(&srv, Some("admin"), Method::GET, &format!("{PATH}?part=detail"), None).await;
    assert_eq!(status, 400);

    let (status, body) = call(
        &srv,
        Some("admin"),
        Method::GET,
        &format!("{PATH}?part=detail&name=sbm-no-such-account"),
        None,
    )
    .await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["available"], false);
    if system_type() == SystemType::Linux {
        if body["reason_kind"] == "no_such_user" {
            assert_eq!(body["reason"], "sbm-no-such-account");
        }
    } else {
        assert_eq!(body["reason_kind"], "unsupported_platform", "{body}");
    }
}

/// Refused before anything runs as root: an account the machine does not
/// have, a name `useradd` would be handed shell syntax in, and a write with
/// nothing to write. Each is recorded under its own code.
#[ntex::test]
async fn a_write_the_endpoint_will_not_build_is_refused_and_recorded() {
    let (srv, db) = server().await;
    let cases = [
        (json!({"action": "delete", "name": "sbm-no-such-account"}), 404, "noSuchUser"),
        (json!({"action": "create", "draft": {"name": "bad;touch /tmp/pwned"}}), 400, "invalidName"),
        (json!({"action": "create"}), 400, "missingDraft"),
        (json!({"action": "delete"}), 400, "missingName"),
    ];
    for (body, status, code) in cases {
        let (got_status, got) = act(&srv, "admin", body).await;
        if system_type() != SystemType::Linux {
            assert_eq!((got_status, got["error"].as_str()), (400, Some("unsupportedPlatform")), "{got}");
            continue;
        }
        // A machine whose catalog cannot be read refuses every write the same
        // way, which is the honest answer and not the case under test.
        if got["error"] == "unreadable" {
            continue;
        }
        assert_eq!((got_status, got["error"].as_str()), (status, Some(code)), "{got}");
    }
    let rows = audit(&db).await;
    assert!(rows.iter().all(|(action, _, _, _)| action == "denied"), "{rows:?}");
}
