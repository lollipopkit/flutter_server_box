//! End-to-end coverage for `POST /api/v1/power`.
//!
//! What these assert is deliberately the refusals, plus what is recorded, and
//! **not** the action itself: the three things this endpoint can do are shut
//! the machine down, reboot it and suspend it, and a test suite that runs on
//! the machine it targets cannot do any of them. The execution path — write the
//! shared script, run one function of it, pipe a password into `sudo -S` — is
//! the same path `monitoring::run_local_shell_func` gives every function of
//! that script, and is covered where it lives by a function that is harmless to
//! run.
//!
//! So a green suite here says the door is locked to the right people. What it
//! does not say is that a reboot reboots, which is a fact that has no test that
//! can be run twice.

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
/// property of [`configure_api`], and this endpoint is one line in it.
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

/// The response body, or the status when the call was refused.
///
/// Every action this endpoint accepts is destructive, so nothing here sends a
/// well-formed one: what a caller gets back for `{"action":"shutdown"}` is not
/// something a test can ask for and then keep running.
async fn post(srv: &TestServer, body: serde_json::Value) -> Result<serde_json::Value, u16> {
    let resp = srv
        .post("/api/v1/power")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&body)
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

fn token() -> String {
    generate_token("admin", SECRET).unwrap()
}

/// An action this endpoint does not have is refused by the extractor, before
/// any handler — and therefore before anything runs.
///
/// This is the one well-formed-looking request the suite can send: the value is
/// rejected at deserialization, so no script is reached.
#[ntex::test]
async fn an_unknown_action_is_rejected() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(
        post(&srv, json!({"action": "halt"})).await.unwrap_err(),
        400
    );
}

/// A missing one is the same refusal — a request that names no action must
/// never fall through to a default.
#[ntex::test]
async fn a_missing_action_is_rejected() {
    let srv = test_server(app_state(true).await).await;
    assert_eq!(post(&srv, json!({})).await.unwrap_err(), 400);
}

/// The grant is re-read per request, so what the client was told earlier about
/// capabilities decides nothing.
#[ntex::test]
async fn the_endpoint_is_refused_when_full_access_is_off() {
    let srv = test_server(app_state(false).await).await;
    assert_eq!(
        post(&srv, json!({"action": "shutdown"})).await.unwrap_err(),
        403
    );
}

#[ntex::test]
async fn a_request_without_a_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .post("/api/v1/power")
        .send_json(&json!({"action": "shutdown"}))
        .await
        .unwrap();

    assert_eq!(resp.status().as_u16(), 401);
}

#[ntex::test]
async fn a_forged_token_is_refused() {
    let srv = test_server(app_state(true).await).await;
    let forged = generate_token("admin", "another-secret-that-is-long-enough").unwrap();
    let resp = srv
        .post("/api/v1/power")
        .header("Authorization", format!("Bearer {forged}"))
        .send_json(&json!({"action": "shutdown"}))
        .await
        .unwrap();

    assert_eq!(resp.status().as_u16(), 401);
}

/// Refusals are recorded. An attempt to power a machine down that was *turned
/// down* is exactly what someone reading this table is looking for, and it is
/// the only kind of power row a test can produce.
#[ntex::test]
async fn a_refusal_is_audited() {
    let state = app_state(false).await;
    let db = state.db.clone();
    let srv = test_server(state).await;
    assert!(post(&srv, json!({"action": "reboot"})).await.is_err());

    let (kind, action, result): (String, String, String) = sqlx::query_as(
        "SELECT kind, action, result FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();

    assert_eq!((kind.as_str(), action.as_str(), result.as_str()), ("power", "denied", "denied"));
}

/// The grant is a UI hint to the client, so the answer the client reads has to
/// name the endpoint it is about to call — an agent older than `/power` reports
/// `full_access` and would answer 404.
#[ntex::test]
async fn capabilities_report_power_over_the_same_grant_as_the_shell() {
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
    assert_eq!(body["remote_access"]["power"], true);
}

/// And the other way round: the panel hides the entry rather than offering a
/// button that answers 403.
#[ntex::test]
async fn capabilities_report_power_off_when_the_grant_is_off() {
    let srv = test_server(app_state(false).await).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    let body: serde_json::Value = resp.json().await.unwrap();

    assert_eq!(body["remote_access"]["full_access"], false);
    assert_eq!(body["remote_access"]["power"], false);
}
