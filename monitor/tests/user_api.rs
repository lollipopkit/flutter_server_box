//! End-to-end coverage for `/api/v1/users`.
//!
//! The catalog is asserted against the machine the suite runs on, which is
//! whatever it is: on the BSD family and on Windows the endpoint answers
//! `unsupported_platform`, which is a real answer and the one that is portable
//! to every machine that is not a Linux host. The cases that need a catalog are
//! skipped there rather than asserting a refusal that would say nothing about
//! the Linux path — the shape `service_api` uses for a machine whose service
//! manager this build cannot list.
//!
//! Nothing here changes an account, and the one thing a suite could usefully
//! create it does not: a suite that ran `useradd` would be leaving an account
//! on the test machine. The command text each write would run is locked by
//! `sbm_parser`'s `user_compat`, so the half that matters is covered without
//! one. What is covered here is everything before the command runs — the
//! platform answer, the part and name a request has to carry, and the refusals,
//! which are the same on a machine that has the account as on one that does
//! not.

use std::sync::{Arc, Once};

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::App;
use rustls::crypto::ring;
use serde_json::{json, Value};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use server_box_monitor::monitoring::system_type;
use sbm_parser::SystemType;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

async fn app_state(full_access: bool) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    // The grant is gated on the terminal being available, so that switching
    // the terminal off cannot leave this door open behind it. The test server
    // listens on loopback, which counts as a secure transport.
    remote.terminal.enabled = true;
    remote.full_access = Some(full_access);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    AppState::new(Arc::new(config), db)
}

/// Mounts the real route table — see `power_api` for why.
async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            let limit = state.remote_access.exec.max_request_bytes;
            App::new().state(state).configure(configure_api(limit))
        }
    })
    .await
}

fn token() -> String {
    generate_token("admin", SECRET).unwrap()
}

async fn read(srv: &TestServer, query: &str) -> Result<Value, u16> {
    let resp = srv
        .get(format!("/api/v1/users{query}"))
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

async fn act(srv: &TestServer, body: Value) -> Result<Value, u16> {
    let resp = srv
        .post("/api/v1/users")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&body)
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

/// The catalog of the machine this suite runs on, or `None` where this build
/// has none for its platform. The cases that need one are skipped rather than
/// asserting a refusal that says nothing about the Linux path.
async fn catalog(srv: &TestServer) -> Option<Value> {
    let body = read(srv, "").await.unwrap();
    body["available"].as_bool().unwrap().then_some(body)
}

/// The error code a refusal carries, which is what the panel phrases.
async fn refusal(srv: &TestServer, body: Value) -> (u16, String) {
    let resp = srv
        .post("/api/v1/users")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&body)
        .await
        .unwrap();
    let status = resp.status().as_u16();
    let body: Value = resp.json().await.unwrap();
    (status, body["error"].as_str().unwrap_or_default().to_string())
}

#[ntex::test]
async fn a_request_without_a_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv.get("/api/v1/users").send().await.unwrap();

    assert_eq!(resp.status().as_u16(), 401);
}

/// The platform answer, and the account the agent itself runs as — which is the
/// one account this endpoint will not remove, and the only thing that tells the
/// panel which row that is.
#[ntex::test]
async fn the_read_says_which_account_the_agent_runs_as() {
    let srv = test_server(app_state(true).await).await;
    let body = read(&srv, "").await.unwrap();

    assert_eq!(body["part"], "list");

    if system_type() != SystemType::Linux {
        assert_eq!(body["available"], false, "{body}");
        assert_eq!(body["reason_kind"], "unsupported_platform", "{body}");
        // Nothing is named, so the panel draws no row it cannot vouch for.
        assert_eq!(body["agent_account"], Value::Null);
        assert_eq!(body["users"], json!([]));
        return;
    }

    assert_eq!(body["available"], true, "{body}");
    assert!(body["editable"].is_boolean(), "{body}");

    let agent = body["agent_account"].as_str().unwrap();
    assert!(!agent.is_empty(), "{body}");
    let uid_min = body["uid_min"].as_u64().unwrap() as u32;
    assert!(uid_min > 0, "{body}");

    let users = body["users"].as_array().unwrap();
    let mine = users
        .iter()
        .find(|user| user["name"] == agent)
        .unwrap_or_else(|| panic!("the agent's own account is not in the catalog: {body}"));
    assert_eq!(mine["agent_account"], true, "{mine}");
    // Root and the agent's own account are the two this endpoint refuses, and
    // the panel draws its disabled button from this rather than deriving it.
    assert_eq!(mine["deletable"], uid_min != 0, "{mine}");
    assert_eq!(mine["is_root"], false, "{mine}");

    for user in users {
        assert!(!user["name"].as_str().unwrap().is_empty(), "{user}");
        assert!(user["uid"].is_u64(), "{user}");
        assert!(user["home"].is_string(), "{user}");
        assert_eq!(
            user["system"],
            user["uid"].as_u64().unwrap() < uid_min as u64,
            "{user}"
        );
        assert!(user["login_disabled"].is_boolean(), "{user}");
        assert_eq!(
            user["deletable"],
            user["uid"] != 0 && user["name"] != agent,
            "{user}"
        );
    }

    // Ordered by uid and then by name, which is the model's rule rather than
    // the machine's file order.
    for pair in users.windows(2) {
        assert!(
            (pair[0]["uid"].as_u64().unwrap(), pair[0]["name"].as_str().unwrap())
                < (pair[1]["uid"].as_u64().unwrap(), pair[1]["name"].as_str().unwrap()),
            "not by uid then name: {} then {}",
            pair[0]["name"],
            pair[1]["name"]
        );
    }
}

/// What the caller may change is a field rather than a status code, and it
/// follows the grant the capabilities endpoint reported.
#[ntex::test]
async fn the_read_reports_whether_this_caller_may_change_anything() {
    let on = test_server(app_state(true).await).await;
    let off = test_server(app_state(false).await).await;

    assert_eq!(read(&on, "").await.unwrap()["editable"], true);
    assert_eq!(read(&off, "").await.unwrap()["editable"], false);
}

/// Reading is not recorded at all, so a row in the audit log is always a
/// change — which is what makes the column worth reading.
#[ntex::test]
async fn a_read_is_not_audited() {
    let state = app_state(true).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    read(&srv, "").await.unwrap();

    let rows: i64 = sqlx::query_scalar("SELECT count(*) FROM access_log")
        .fetch_one(&db)
        .await
        .unwrap();
    assert_eq!(rows, 0);
}

/// The detail is about one account, so it cannot be answered without it — and
/// that is refused before anything runs on the machine.
#[ntex::test]
async fn a_part_about_one_account_needs_the_account() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(read(&srv, "?part=detail").await.unwrap_err(), 400);
    assert_eq!(read(&srv, "?part=detail&name=").await.unwrap_err(), 400);
}

/// A name that is not in the catalog is an account that was removed between the
/// panel drawing the row and the click. Answered as its own reason rather than
/// as a failure, and — like every read — not recorded.
#[ntex::test]
async fn a_name_that_is_not_in_the_catalog_is_answered_as_such() {
    let srv = test_server(app_state(true).await).await;
    if catalog(&srv).await.is_none() {
        return;
    }
    let body = read(&srv, "?part=detail&name=definitely-not-an-account")
        .await
        .unwrap();

    assert_eq!(body["available"], false, "{body}");
    assert_eq!(body["reason_kind"], "no_such_user", "{body}");
    assert_eq!(body["reason"], "definitely-not-an-account", "{body}");
    assert_eq!(body["detail"], Value::Null, "{body}");
}

/// An account's own records are read as the catalog's account, so the answer is
/// about the account the machine has rather than about the string the caller
/// sent.
#[ntex::test]
async fn an_account_can_be_looked_up_by_the_name_the_catalog_gave_it() {
    let srv = test_server(app_state(true).await).await;
    let Some(body) = catalog(&srv).await else {
        return;
    };
    let agent = body["agent_account"].as_str().unwrap();

    let detail = read(&srv, &format!("?part=detail&name={agent}"))
        .await
        .unwrap();

    assert_eq!(detail["part"], "detail");
    assert_eq!(detail["name"], agent, "{detail}");
    assert_eq!(detail["available"], true, "{detail}");

    // Every field of a detail may be unreadable on its own — an unprivileged
    // session cannot read shadow — so the shape stays and the fields say which
    // of them were read. What must never appear is a value standing in for
    // "could not read it": `null` is that, and it is the only spelling.
    let fields = detail["detail"].as_object().unwrap();
    for (name, value) in fields {
        match name.as_str() {
            "never_expires" => assert!(value.is_boolean(), "{detail}"),
            "ssh_key_types" => assert!(
                value.is_null() || value.is_array(),
                "an unread keys file must be null and an empty one an empty list: {detail}"
            ),
            _ => assert!(
                value.is_null() || value.is_string(),
                "a record that could not be read is null: {detail}"
            ),
        }
    }
}

/// The grant is re-read per request, so what the client was told earlier about
/// capabilities decides nothing.
#[ntex::test]
async fn a_write_is_refused_when_full_access_is_off() {
    let srv = test_server(app_state(false).await).await;
    assert_eq!(
        act(&srv, json!({"action": "delete", "name": "someone"}))
            .await
            .unwrap_err(),
        403
    );
    assert_eq!(
        act(&srv, json!({"action": "create", "draft": {"name": "someone"}}))
            .await
            .unwrap_err(),
        403
    );
}

/// Refusals are recorded — the row that matters most here is the one naming an
/// account that was *not* touched.
#[ntex::test]
async fn a_refusal_is_audited() {
    let state = app_state(false).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    assert!(act(&srv, json!({"action": "delete", "name": "someone"}))
        .await
        .is_err());

    let (kind, action, result): (String, String, String) =
        sqlx::query_as("SELECT kind, action, result FROM access_log ORDER BY id DESC LIMIT 1")
            .fetch_one(&db)
            .await
            .unwrap();

    assert_eq!(
        (kind.as_str(), action.as_str(), result.as_str()),
        ("user", "denied", "denied")
    );
}

/// Every refusal that does not depend on the machine is made before it is
/// touched, and the row that records it carries the same code the caller was
/// given. The account names below are ones this machine does not have for the
/// reason each case is about.
#[ntex::test]
async fn a_write_is_refused_with_a_code_the_panel_can_phrase() {
    let state = app_state(true).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    if catalog(&srv).await.is_none() {
        return;
    }

    // A name `useradd` would not accept, and a field that would break the line
    // it is written on. Both are the caller's own mistake.
    assert_eq!(
        refusal(&srv, json!({"action": "create", "draft": {"name": "bad;touch /tmp/pwned"}})).await,
        (400, "invalidName".to_string())
    );
    assert_eq!(
        refusal(
            &srv,
            json!({"action": "create", "draft": {"name": "deploy", "comment": "a\nb"}})
        )
        .await,
        (400, "lineBreak".to_string())
    );
    assert_eq!(
        refusal(
            &srv,
            json!({"action": "create", "draft": {"name": "deploy", "password": "a\nb"}})
        )
        .await,
        (400, "passwordLineBreak".to_string())
    );
    // A draft that is not there at all.
    assert_eq!(
        refusal(&srv, json!({"action": "create"})).await,
        (400, "missingDraft".to_string())
    );
    // A change names the account it is about, and a removal too.
    assert_eq!(
        refusal(&srv, json!({"action": "edit", "draft": {"name": "deploy"}})).await,
        (400, "missingName".to_string())
    );
    assert_eq!(
        refusal(&srv, json!({"action": "delete"})).await,
        (400, "missingName".to_string())
    );

    let (kind, subject, detail): (String, String, Option<String>) = sqlx::query_as(
        "SELECT kind, subject, detail FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();
    assert_eq!(kind, "user");
    assert_eq!(subject, "delete");
    assert_eq!(detail.as_deref(), Some("missingName"));
}

/// Root is not removable, and neither is the account the agent itself runs as:
/// it is a process on this machine, and `userdel -r` would take the home it
/// reads its own config from.
#[ntex::test]
async fn the_two_accounts_this_endpoint_will_not_remove() {
    let srv = test_server(app_state(true).await).await;
    let Some(body) = catalog(&srv).await else {
        return;
    };

    assert_eq!(
        refusal(&srv, json!({"action": "delete", "name": "root"})).await,
        (400, "rootNotDeletable".to_string())
    );

    let agent = body["agent_account"].as_str().unwrap();
    // Unless the suite is running as root, in which case the two are one row
    // and root's refusal is the one above.
    if agent != "root" {
        assert_eq!(
            refusal(&srv, json!({"action": "delete", "name": agent})).await,
            (400, "agentAccount".to_string())
        );
    }
}

/// An account that is not in the catalog is not one to run a command about, and
/// its own 404 rather than a 400: nothing about the request is wrong, the
/// machine simply has no such account.
#[ntex::test]
async fn a_write_about_an_account_the_machine_does_not_have_is_404() {
    let srv = test_server(app_state(true).await).await;
    if catalog(&srv).await.is_none() {
        return;
    }

    assert_eq!(
        refusal(
            &srv,
            json!({"action": "delete", "name": "definitely-not-an-account"})
        )
        .await,
        (404, "noSuchUser".to_string())
    );
    // A change is diffed against the account as the machine has it, so an
    // account that is not there is the same refusal.
    assert_eq!(
        refusal(
            &srv,
            json!({
                "action": "edit",
                "name": "definitely-not-an-account",
                "draft": {"name": "definitely-not-an-account", "comment": "x"},
            })
        )
        .await,
        (404, "noSuchUser".to_string())
    );
}

/// An account is created once: a duplicate is answered as one rather than as
/// whatever `useradd` says about a uid that is already taken.
#[ntex::test]
async fn creating_an_account_that_exists_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let Some(body) = catalog(&srv).await else {
        return;
    };
    let agent = body["agent_account"].as_str().unwrap();

    assert_eq!(
        refusal(&srv, json!({"action": "create", "draft": {"name": agent}})).await,
        (400, "userExists".to_string())
    );
}

/// An action this build does not have is refused while deserializing, rather
/// than reaching a shell to be interpreted.
#[ntex::test]
async fn an_action_this_build_does_not_have_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .post("/api/v1/users")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&json!({"action": "rename", "name": "someone"}))
        .await
        .unwrap();

    assert_eq!(resp.status().as_u16(), 400);
}

/// An agent older than the endpoint answers `full_access` and would 404, so
/// the panel reads this field rather than that one.
#[ntex::test]
async fn capabilities_report_the_users_endpoint() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    let body: Value = resp.json().await.unwrap();

    assert_eq!(body["remote_access"]["users"], true);
    // Servable, not grantable: the answer is what the caller may *change* that
    // carries the grant, and the read is a field on the catalog.
    assert_eq!(body["remote_access"]["full_access"], true);
}
