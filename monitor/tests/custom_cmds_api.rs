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

mod common;

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

async fn app_state() -> Arc<AppState> {
    ensure_crypto_provider();
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    common::add_owner(&db).await;
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
    generate_token(SECRET).unwrap()
}

#[ntex::test]
async fn listing_needs_a_token() {
    let srv = test_server(app_state().await).await;
    let resp = srv.get("/api/v1/custom-cmds").send().await.unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

#[ntex::test]
async fn writing_needs_a_token() {
    let srv = test_server(app_state().await).await;
    let resp = srv
        .put("/api/v1/custom-cmds")
        .send_json(&json!({"commands": [{"name": "x", "cmd": "echo x"}]}))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

/// The editor is told whether a save would be taken over this link, so it
/// can show a read-only view rather than fail on save.
#[ntex::test]
async fn listing_says_whether_it_is_editable() {
    let srv = test_server(app_state().await).await;
    let resp = srv
        .get("/api/v1/custom-cmds")
        .header("Authorization", format!("Bearer {}", token()))
        .send()
        .await
        .unwrap();
    assert!(resp.status().is_success());
    let body: serde_json::Value = resp.json().await.unwrap();
    // The test client is a loopback peer, which counts as secure.
    assert_eq!(body["editable"], true);
    assert!(body["commands"].is_array());
}
