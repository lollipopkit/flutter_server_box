//! `GET/PUT /api/v1/cron`, against the real route table.
//!
//! The refusals and what is recorded, and **not** a successful save: this
//! endpoint writes the crontab of whoever runs the suite. A test that saved a
//! job would leave it behind on every machine that ran the suite, and one that
//! saved an empty document would delete an operator's real schedule. The model
//! underneath — which line an edit addresses, what a disabled job looks like
//! on disk, when it next runs — is `sbm_parser::cron`'s own tests.
//!
//! Reading is exercised: `crontab -l` changes nothing, and the assertions
//! accept whatever the machine has — a schedule, none, or no `crontab(1)`.

mod common;

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};

use common::machine::{audit, call, server};

async fn put(srv: &TestServer, user: &str, body: Value) -> (u16, Value) {
    call(srv, Some(user), Method::PUT, "/api/v1/cron", Some(body)).await
}

/// A line break, which would split one task into two: refused before the
/// crontab is read or written.
fn damaging_edit() -> Value {
    json!({ "op": "upsert", "line_index": null, "schedule": "* * * * *", "command": "a\nb", "enabled": true })
}

#[ntex::test]
async fn both_halves_need_the_shell_grant() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::GET, "/api/v1/cron", None).await;
    assert_eq!(status, 401);

    let (status, body) = call(&srv, Some("viewer"), Method::GET, "/api/v1/cron", None).await;
    assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")));
    let (status, _) = put(&srv, "viewer", damaging_edit()).await;
    assert_eq!(status, 403);

    let rows = audit(&db).await;
    assert_eq!(rows.len(), 2, "{rows:?}");
    assert!(rows.iter().all(|(action, _, subject, _)| action == "denied" && subject.as_deref() == Some("viewer")));
    // The schedule, never the command: a command is free text that may hold
    // a token.
    let detail = rows[1].3.as_deref().unwrap();
    assert_eq!(detail, "cron append: * * * * *: shell not_granted");
}

#[ntex::test]
async fn reading_reports_the_schedule_it_found() {
    let (srv, db) = server().await;
    let (status, body) = call(&srv, Some("admin"), Method::GET, "/api/v1/cron", None).await;
    assert_eq!(status, 200, "{body}");
    if body["available"] == true {
        assert!(body["jobs"].is_array() && body["preserved"].is_array() && body["user"].is_string(), "{body}");
    } else {
        assert!(body["reason_kind"].is_string(), "an unavailable listing says why: {body}");
    }
    assert!(audit(&db).await.is_empty(), "a read is not recorded");
}

/// Each validation case is its own word, so the panel shows its own sentence.
#[ntex::test]
async fn a_refused_edit_says_which_rule_it_broke() {
    let (srv, db) = server().await;
    for (body, expected) in [
        (damaging_edit(), None),
        (
            json!({ "op": "upsert", "line_index": null, "schedule": "", "command": "x", "enabled": true }),
            Some("scheduleEmpty"),
        ),
        (
            json!({ "op": "upsert", "line_index": null, "schedule": "* * * * *", "command": "  ", "enabled": true }),
            Some("commandEmpty"),
        ),
        (
            json!({ "op": "upsert", "line_index": null, "schedule": "* * * *", "command": "x", "enabled": true }),
            Some("fieldCount"),
        ),
    ] {
        let (status, answered) = put(&srv, "admin", body.clone()).await;
        assert_eq!(status, 400, "{body}");
        if let Some(expected) = expected {
            assert_eq!(answered["error"], expected, "{body}");
        }
    }
    // Nothing was written, so nothing was recorded.
    assert!(audit(&db).await.is_empty());
}

/// A line no crontab can hold: the listing moved under the client, answered
/// as its own word. Cannot write anything even if the answer were wrong.
#[ntex::test]
async fn an_edit_naming_a_line_that_is_not_a_job_is_refused() {
    let (srv, _) = server().await;
    let (_, listing) = call(&srv, Some("admin"), Method::GET, "/api/v1/cron", None).await;
    if listing["available"] != true {
        return;
    }
    let (status, answered) = put(&srv, "admin", json!({ "op": "remove", "line_index": 4_294_967_295u32 })).await;
    assert_eq!((status, answered["error"].as_str()), (400, Some("unknownLine")));
}

/// An operation this endpoint does not have, or none at all, never falls
/// through to a default.
#[ntex::test]
async fn an_unknown_or_missing_operation_is_rejected() {
    let (srv, _) = server().await;
    assert_eq!(put(&srv, "admin", json!({ "op": "reload", "line_index": 0 })).await.0, 400);
    assert_eq!(put(&srv, "admin", json!({})).await.0, 400);
}

#[ntex::test]
async fn capabilities_list_the_cron_page() {
    let (srv, _) = server().await;
    let (_, caps) = call(&srv, Some("viewer"), Method::GET, "/api/v1/capabilities", None).await;
    assert!(caps["features"].as_array().unwrap().iter().any(|f| f == "cron"), "{caps}");
}
