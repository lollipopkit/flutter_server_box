//! `/api/v1/api-tokens` (issue #1681), against the real route table.

mod common;

use std::sync::{Arc, Once};

use ntex::http::Method;
use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use server_box_monitor::core::permissions::{Grants, InitPermissions};
use server_box_monitor::db::accounts;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = rustls::crypto::ring::default_provider().install_default();
    });
}

fn leave_the_crate() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let dir = std::env::temp_dir().join(format!("sbm-api-tokens-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
    });
}

async fn server() -> TestServer {
    leave_the_crate();
    ensure_crypto_provider();
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let db = common::database().await;
    for name in common::ACCOUNTS {
        common::add_account(&db, name, "admin").await;
    }
    server_box_monitor::db::bootstrap::ensure_roles(&db, &Config::default(), InitPermissions::Full)
        .await
        .unwrap();
    common::set_grants(&db, "admin", &Grants::all()).await;
    common::add_account(&db, "viewer", "viewer").await;
    let state = AppState::new(Arc::new(config), db);
    web_test::server(move || {
        let state = state.clone();
        async move {
            let limit = state.remote_access.exec.max_request_bytes;
            App::new().state(state).configure(configure_api(limit))
        }
    })
    .await
}

fn jwt(user: &str) -> String {
    generate_token(user, SECRET).unwrap()
}

async fn call(
    srv: &TestServer,
    user: &str,
    method: Method,
    path: &str,
    body: Option<Value>,
) -> (u16, Value) {
    let req = srv
        .request(method, srv.url(path))
        .timeout(std::time::Duration::from_secs(30))
        .header("Authorization", format!("Bearer {}", jwt(user)));
    let resp = match body {
        Some(body) => req.send_json(&body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let status = resp.status().as_u16();
    let bytes = resp.body().await.unwrap_or_default();
    (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

#[ntex::test]
async fn an_account_mints_lists_and_revokes_its_own_token() {
    let srv = server().await;
    let (status, _) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({
            "name": "cursor",
            "scopes": ["read", "files"],
            "current_password": "wrong",
        })),
    )
    .await;
    assert_eq!(status, 403, "a stolen session must not mint a token");

    let (status, created) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({
            "name": "cursor",
            "scopes": ["read", "files"],
            "current_password": common::PASSWORD,
        })),
    )
    .await;
    assert_eq!(status, 200, "{created}");
    let token = created["token"].as_str().unwrap();
    assert!(token.starts_with("sbt_"), "{token}");
    assert_eq!(token.len(), 4 + 64);
    let id = created["id"].as_str().unwrap();

    let (status, listed) = call(&srv, "admin", Method::GET, "/api/v1/api-tokens", None).await;
    assert_eq!(status, 200);
    let rows = listed.as_array().unwrap();
    assert_eq!(rows.len(), 1);
    assert_eq!(rows[0]["id"], id);
    assert!(rows[0].get("token").is_none(), "the secret is shown once");

    let (status, _) = call(
        &srv,
        "admin",
        Method::DELETE,
        &format!("/api/v1/api-tokens/{id}"),
        None,
    )
    .await;
    assert_eq!(status, 200);
    let (status, listed) = call(&srv, "admin", Method::GET, "/api/v1/api-tokens", None).await;
    assert_eq!(status, 200);
    assert!(listed.as_array().unwrap().is_empty());
}

#[ntex::test]
async fn admin_is_never_a_scope_and_unknown_names_are_refused() {
    let srv = server().await;
    let (status, body) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({
            "name": "escalation",
            "scopes": ["admin"],
            "current_password": common::PASSWORD,
        })),
    )
    .await;
    assert_eq!(status, 400, "{body}");
    let (status, body) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({
            "name": "escalation",
            "scopes": ["nope"],
            "current_password": common::PASSWORD,
        })),
    )
    .await;
    assert_eq!(status, 400, "{body}");
}

#[ntex::test]
async fn a_viewer_cannot_list_every_account_and_cannot_revoke_anothers() {
    let srv = server().await;
    let (status, created) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({
            "name": "ops",
            "scopes": [],
            "current_password": common::PASSWORD,
        })),
    )
    .await;
    assert_eq!(status, 200, "{created}");
    let id = created["id"].as_str().unwrap();

    let (status, _) = call(&srv, "viewer", Method::GET, "/api/v1/api-tokens?all=1", None).await;
    assert_eq!(status, 403);

    let (status, listed) = call(&srv, "admin", Method::GET, "/api/v1/api-tokens?all=1", None).await;
    assert_eq!(status, 200);
    assert_eq!(listed.as_array().unwrap().len(), 1);

    let (status, _) = call(
        &srv,
        "viewer",
        Method::DELETE,
        &format!("/api/v1/api-tokens/{id}"),
        None,
    )
    .await;
    assert_eq!(status, 403);
}

#[ntex::test]
async fn changing_the_password_deletes_the_account_tokens() {
    let srv = server().await;
    let (status, created) = call(
        &srv,
        "admin",
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({
            "name": "old",
            "scopes": [],
            "current_password": common::PASSWORD,
        })),
    )
    .await;
    assert_eq!(status, 200, "{created}");
    let secret = created["token"].as_str().unwrap().to_string();

    let (status, body) = call(
        &srv,
        "admin",
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({
            "current_password": common::PASSWORD,
            "new_password": "new-password-ok",
        })),
    )
    .await;
    assert_eq!(status, 204, "{body}");

    let resp = srv
        .post("/mcp")
        .header("Authorization", format!("Bearer {secret}"))
        .send_json(&json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": { "protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": { "name": "t", "version": "0" } }
        }))
        .await
        .unwrap();
    assert_eq!(
        resp.status().as_u16(),
        401,
        "an API token must not outlive the password it was paid for with"
    );
}

#[ntex::test]
async fn deleting_the_account_deletes_its_tokens() {
    let db = common::database().await;
    common::add_account(&db, "admin", "admin").await;
    common::add_account(&db, "ops", "viewer").await;
    server_box_monitor::db::bootstrap::ensure_roles(
        &db,
        &Config::default(),
        InitPermissions::Full,
    )
    .await
    .unwrap();
    sqlx::query(
        "INSERT INTO api_tokens (id, subject, name, token_hash, scopes, created_at, expires_at) \
         VALUES ('t1', 'ops', 'mcp', 'h', '[]', 0, 9999999999)",
    )
    .execute(&db)
    .await
    .unwrap();
    assert_eq!(
        accounts::delete_account(&db, "ops").await.unwrap(),
        server_box_monitor::db::accounts::Guarded::Done
    );
    let left: i64 = sqlx::query_scalar("SELECT count(*) FROM api_tokens WHERE subject = 'ops'")
        .fetch_one(&db)
        .await
        .unwrap();
    assert_eq!(left, 0);
}
