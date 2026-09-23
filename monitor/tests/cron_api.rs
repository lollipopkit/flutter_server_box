//! End-to-end coverage for `GET/PUT /api/v1/cron`.
//!
//! What these assert is deliberately the refusals, plus what is recorded, and
//! **not** a successful save: this endpoint writes the crontab of whoever runs
//! the suite. A test that saved a job would leave it behind on every machine
//! that ever ran the suite, and one that saved an empty document would delete
//! an operator's real schedule — the second is worse, and both are the same
//! code path.
//!
//! The model underneath — what a line is, which line an edit addresses, what a
//! disabled job looks like on disk, where the next run is — is covered where it
//! lives, by `crates/sbm_parser/src/cron.rs`'s own tests. What is left here is
//! the door: who may open it, what a client is told about it, and what is
//! recorded when it is tried.
//!
//! Reading is different, and is exercised: `crontab -l` changes nothing. The
//! assertions accept whatever state the machine is in — a schedule, no
//! schedule, or no `crontab(1)` at all — because which of those a CI container
//! is in is not this test's subject.

use std::sync::{Arc, Once};

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::App;
use rustls::crypto::ring;
use serde_json::json;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;

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

/// Mounts the real route table.
///
/// A scope of its own would assert something about the handler and nothing
/// about what the shipped binary exposes — which route gets which gate is a
/// property of [`configure_api`], and this endpoint is two lines in it.
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

/// An edit that no crond would accept, and that this endpoint refuses before it
/// reads or writes anything.
fn invalid_edit() -> serde_json::Value {
    json!({
        "op": "upsert",
        "line_index": null,
        "schedule": "0 3 * * *",
        "command": "backup\nrm -rf /",
        "enabled": true,
    })
}

async fn put(srv: &TestServer, body: serde_json::Value) -> Result<serde_json::Value, u16> {
    let resp = srv
        .put("/api/v1/cron")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&body)
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

async fn get(srv: &TestServer) -> Result<serde_json::Value, u16> {
    let resp = srv
        .get("/api/v1/cron")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

#[ntex::test]
async fn a_request_without_a_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv.get("/api/v1/cron").send().await.unwrap();
    assert_eq!(resp.status().as_u16(), 401);

    let resp = srv.put("/api/v1/cron").send_json(&invalid_edit()).await.unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

#[ntex::test]
async fn a_forged_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let forged = generate_token("admin", "another-secret-that-is-long-enough").unwrap();
    let resp = srv
        .get("/api/v1/cron")
        .header("Authorization", format!("Bearer {forged}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

/// A write is refusing to be told about `full_access` by the client. The grant
/// is re-read per request, so what capabilities said earlier decides nothing.
#[ntex::test]
async fn writing_is_refused_when_full_access_is_off() {
    let srv = test_server(app_state(false).await).await;
    assert_eq!(put(&srv, invalid_edit()).await.unwrap_err(), 403);
}

/// Reading is not gated on the shell grant: the schedule is the agent's own
/// user's, the same as the custom commands, and a panel that may only look can
/// still say so honestly.
#[ntex::test]
async fn reading_is_allowed_without_full_access() {
    let srv = test_server(app_state(false).await).await;
    let body = get(&srv).await.expect("the listing is readable");
    assert_eq!(body["editable"], false);
}

#[ntex::test]
async fn reading_reports_the_schedule_it_found() {
    let srv = test_server(app_state(true).await).await;
    let body = get(&srv).await.expect("the listing is readable");
    assert_eq!(body["editable"], true);
    // Whatever the machine is in, the answer has one of the two shapes — and
    // never a job list without the fields that go with it.
    if body["available"] == true {
        assert!(body["jobs"].is_array());
        assert!(body["preserved"].is_array());
        assert!(body["user"].is_string());
    } else {
        assert!(
            body["reason_kind"].is_string(),
            "an unavailable listing says why: {body}"
        );
    }
}

/// A line break is what would damage the file — it splits one task into two —
/// and it is refused before the crontab is read or written.
#[ntex::test]
async fn an_edit_that_would_damage_the_file_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let body = put(&srv, invalid_edit()).await.unwrap_err();
    assert_eq!(body, 400);
}

/// Every validation case is answered as its own word, so the panel shows its
/// own sentence rather than a server's English one.
#[ntex::test]
async fn a_refused_edit_says_which_rule_it_broke() {
    let srv = test_server(app_state(true).await).await;
    for (body, expected) in [
        (
            json!({ "op": "upsert", "line_index": null, "schedule": "", "command": "x", "enabled": true }),
            "scheduleEmpty",
        ),
        (
            json!({ "op": "upsert", "line_index": null, "schedule": "* * * * *", "command": "  ", "enabled": true }),
            "commandEmpty",
        ),
        (
            json!({ "op": "upsert", "line_index": null, "schedule": "* * * *", "command": "x", "enabled": true }),
            "fieldCount",
        ),
    ] {
        let resp = srv
            .put("/api/v1/cron")
            .header("Authorization", format!("Bearer {}", token()))
            .send_json(&body)
            .await
            .unwrap();
        assert_eq!(resp.status().as_u16(), 400, "{body}");
        let answered: serde_json::Value = resp.json().await.unwrap();
        assert_eq!(answered["error"], expected, "{body}");
    }
}

/// An edit that names a line which is not a job is a listing that moved, and it
/// is answered as its own word rather than as a bad schedule — the expression is
/// fine and the remedy is to read the schedule again.
///
/// The index is one no crontab can hold, so this asserts the same thing on a
/// machine with a hundred jobs as on one with none, and cannot write anything
/// even if the answer were wrong. Only asserted when the listing is readable at
/// all: an agent with no `crontab(1)` answers 200 and says so, which is the
/// subject of the read tests rather than this one.
#[ntex::test]
async fn an_edit_naming_a_line_that_is_not_a_job_is_refused() {
    let srv = test_server(app_state(true).await).await;
    if get(&srv).await.expect("readable")["available"] != true {
        return;
    }
    let resp = srv
        .put("/api/v1/cron")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&json!({ "op": "remove", "line_index": 4_294_967_295u32 }))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 400);
    let answered: serde_json::Value = resp.json().await.unwrap();
    assert_eq!(answered["error"], "unknownLine");
}

/// An operation this endpoint does not have is refused by the extractor, before
/// any handler — and therefore before the crontab is read.
#[ntex::test]
async fn an_unknown_operation_is_rejected() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(
        put(&srv, json!({ "op": "reload", "line_index": 0 }))
            .await
            .unwrap_err(),
        400,
    );
}

/// An edit that names no operation must never fall through to a default.
#[ntex::test]
async fn a_missing_operation_is_rejected() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(put(&srv, json!({})).await.unwrap_err(), 400);
}

/// A write that was *turned down* is what someone reading this table is looking
/// for, and it is the only kind of cron row a suite that must not touch the
/// crontab can produce.
#[ntex::test]
async fn a_refused_write_is_audited() {
    let state = app_state(false).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    assert!(put(&srv, invalid_edit()).await.is_err());

    let (kind, action, result): (String, String, String) = sqlx::query_as(
        "SELECT kind, action, result FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();

    assert_eq!((kind.as_str(), action.as_str(), result.as_str()), ("cron", "denied", "denied"));
}

/// The grant is a UI hint to the client, so the answer the client reads has to
/// name the endpoint it is about to call — an agent older than `/cron` reports
/// `full_access` and would answer 404.
///
/// It reports the endpoint being *served*, not the write grant. Reading the
/// schedule needs only the panel login, and the panel has implemented the
/// read-only page for that case all along — reporting the grant hid a
/// reachable page behind a switch that has nothing to do with reaching it.
#[ntex::test]
async fn capabilities_report_cron_being_served() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    assert!(
        resp.status().is_success(),
        "capabilities answered {}",
        resp.status()
    );
    let body: serde_json::Value = resp.json().await.unwrap();

    assert_eq!(body["remote_access"]["full_access"], true);
    assert_eq!(body["remote_access"]["cron"], true);
}

/// And the other way round: with the write grant off the tab stays, and the
/// page it opens goes read-only off `editable` rather than failing on a save.
/// `power` is the one that still reports the grant, because it has nothing to
/// read.
#[ntex::test]
async fn capabilities_report_cron_with_the_grant_off() {
    let srv = test_server(app_state(false).await).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    let body: serde_json::Value = resp.json().await.unwrap();

    assert_eq!(body["remote_access"]["full_access"], false);
    assert_eq!(body["remote_access"]["cron"], true);
    assert_eq!(body["remote_access"]["power"], false);
}
