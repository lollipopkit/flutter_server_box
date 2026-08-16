//! Coverage for `GET/PUT /api/v1/custom-cmds`, which is about the refusals.
//!
//! A file in the custom-command directory is run by the status script on every
//! extended cycle, so writing one is arranging for code to run as the agent's
//! user — the same thing `/exec` does, and it must cost the same grant. What
//! is asserted here is that it does.
//!
//! The write path itself is covered by unit tests in
//! `monitoring::custom_cmds`, against a temporary directory. Nothing here
//! writes: these handlers act on the real `~/.config/server_box/custom_cmds`,
//! and a test suite that replaced the developer's own commands to prove a
//! point would be a poor trade.

use std::sync::{Arc, Once};

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use rustls::crypto::ring;
use serde_json::json;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
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
    let mut config = Config::default();
    config.jwt_secret = Some(SECRET.to_string());
    let mut remote = config.get_remote_access();
    remote.terminal.enabled = true;
    remote.full_access = Some(full_access);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    AppState::new(Arc::new(config), db)
}

async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .route(
                        "/custom-cmds",
                        web::get().to(server_box_monitor::api::custom_cmds::list),
                    )
                    .route(
                        "/custom-cmds",
                        web::put().to(server_box_monitor::api::custom_cmds::replace),
                    ),
            )
        }
    })
    .await
}

fn token() -> String {
    generate_token("admin", SECRET).unwrap()
}

#[ntex::test]
async fn listing_needs_a_token() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv.get("/api/v1/custom-cmds").send().await.unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

#[ntex::test]
async fn writing_needs_a_token() {
    let srv = test_server(app_state(true).await).await;
    let resp = srv
        .put("/api/v1/custom-cmds")
        .send_json(&json!({"commands": [{"name": "x", "cmd": "echo x"}]}))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

/// The panel login alone is not enough to write one. Anyone who can add a
/// command can run anything as the agent's user on the next cycle, which is
/// the decision `full_access` exists to record.
#[ntex::test]
async fn writing_needs_full_access() {
    let srv = test_server(app_state(false).await).await;
    let resp = srv
        .put("/api/v1/custom-cmds")
        .header("Authorization", format!("Bearer {}", token()))
        .send_json(&json!({"commands": [{"name": "x", "cmd": "echo x"}]}))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 403);
}

/// Reading does not: it discloses the commands, not the machine. The editor
/// is told so it can show a read-only view rather than fail on save.
#[ntex::test]
async fn listing_works_without_full_access_and_says_it_is_read_only() {
    let srv = test_server(app_state(false).await).await;
    let resp = srv
        .get("/api/v1/custom-cmds")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    assert!(resp.status().is_success());
    let body: serde_json::Value = resp.json().await.unwrap();
    assert_eq!(body["editable"], false);
    assert!(body["commands"].is_array());
}
