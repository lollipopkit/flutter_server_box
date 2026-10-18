//! `POST /mcp` (issue #1681): Streamable HTTP JSON, API tokens only.

mod common;

use std::sync::{Arc, Once};

use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use server_box_monitor::core::permissions::{Grants, InitPermissions};
use server_box_monitor::db::api_tokens;

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
        let dir = std::env::temp_dir().join(format!("sbm-mcp-api-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
    });
}

async fn state(root: Option<&str>) -> Arc<AppState> {
    leave_the_crate();
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    if let Some(root) = root {
        let mut remote = config.get_remote_access();
        remote.fs.roots = vec![root.to_string()];
        config.remote_access = Some(remote);
    }
    let db = common::database().await;
    for name in common::ACCOUNTS {
        common::add_account(&db, name, "admin").await;
    }
    server_box_monitor::db::bootstrap::ensure_roles(&db, &Config::default(), InitPermissions::Full)
        .await
        .unwrap();
    common::set_grants(&db, "admin", &Grants::all()).await;
    AppState::new(Arc::new(config), db)
}

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

fn jwt() -> String {
    generate_token("admin", SECRET).unwrap()
}

async fn mint(srv: &TestServer, scopes: &[&str]) -> String {
    let resp = srv
        .post("/api/v1/api-tokens")
        .timeout(std::time::Duration::from_secs(30))
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({
            "name": "mcp-test",
            "scopes": scopes,
            "current_password": common::PASSWORD,
        }))
        .await
        .unwrap();
    assert!(resp.status().is_success(), "minting the token itself failed");
    let body: Value = resp.json().await.unwrap();
    body["token"].as_str().unwrap().to_string()
}

async fn rpc(srv: &TestServer, token: &str, body: Value) -> (u16, Value) {
    let resp = srv
        .post("/mcp")
        .timeout(std::time::Duration::from_secs(30))
        .header("Authorization", format!("Bearer {token}"))
        .send_json(&body)
        .await
        .unwrap();
    let status = resp.status().as_u16();
    let bytes = resp.body().limit(16 * 1024 * 1024).await.unwrap_or_default();
    (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

fn init() -> Value {
    json!({
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": { "name": "mcp_api", "version": "0" }
        }
    })
}

#[ntex::test]
async fn an_rmcp_shaped_client_initializes_lists_and_calls_read_tools() {
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("note.txt"), "hello").unwrap();
    let srv = test_server(state(Some(root.path().to_str().unwrap())).await).await;
    let token = mint(&srv, &["files", "shell"]).await;

    let (status, body) = rpc(&srv, &token, init()).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["result"]["protocolVersion"], "2025-03-26");
    assert_eq!(body["result"]["serverInfo"]["name"], "serverbox-monitor");

    let (status, _) = rpc(
        &srv,
        &token,
        json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }),
    )
    .await;
    assert_eq!(status, 202);

    let (status, listed) = rpc(
        &srv,
        &token,
        json!({ "jsonrpc": "2.0", "id": 2, "method": "tools/list" }),
    )
    .await;
    assert_eq!(status, 200, "{listed}");
    let names: Vec<&str> = listed["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|t| t["name"].as_str().unwrap())
        .collect();
    for need in [
        "get_metrics",
        "get_capabilities",
        "list_processes",
        "fs_roots",
        "fs_list",
        "fs_stat",
    ] {
        assert!(names.contains(&need), "{names:?}");
    }

    let (status, caps) = rpc(
        &srv,
        &token,
        json!({
            "jsonrpc": "2.0",
            "id": 3,
            "method": "tools/call",
            "params": { "name": "get_capabilities", "arguments": {} }
        }),
    )
    .await;
    assert_eq!(status, 200, "{caps}");
    assert_eq!(caps["result"]["isError"], false);
    let text = caps["result"]["content"][0]["text"].as_str().unwrap();
    let parsed: Value = serde_json::from_str(text).unwrap();
    assert_eq!(parsed["mcp"], true);
    assert_eq!(parsed["me"]["admin"], false, "a token is never admin");

    let (status, roots) = rpc(
        &srv,
        &token,
        json!({
            "jsonrpc": "2.0",
            "id": 4,
            "method": "tools/call",
            "params": { "name": "fs_roots", "arguments": {} }
        }),
    )
    .await;
    assert_eq!(status, 200, "{roots}");
    assert_eq!(roots["result"]["isError"], false);

    let (status, ping) = rpc(
        &srv,
        &token,
        json!({ "jsonrpc": "2.0", "id": 5, "method": "ping" }),
    )
    .await;
    assert_eq!(status, 200, "{ping}");
    assert!(ping.get("result").is_some());
}

#[ntex::test]
async fn a_read_only_token_does_not_see_shell_or_files_tools() {
    let srv = test_server(state(None).await).await;
    let token = mint(&srv, &[]).await;
    let (status, listed) = rpc(
        &srv,
        &token,
        json!({ "jsonrpc": "2.0", "id": 1, "method": "tools/list" }),
    )
    .await;
    assert_eq!(status, 200, "{listed}");
    let names: Vec<&str> = listed["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|t| t["name"].as_str().unwrap())
        .collect();
    assert_eq!(names, ["get_metrics", "get_capabilities"]);

    let (status, call) = rpc(
        &srv,
        &token,
        json!({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": { "name": "list_processes", "arguments": {} }
        }),
    )
    .await;
    assert_eq!(status, 200, "{call}");
    assert_eq!(call["result"]["isError"], true);
}

#[ntex::test]
async fn a_watch_token_and_a_jwt_are_refused() {
    let srv = test_server(state(None).await).await;
    let watch = srv
        .post("/api/v1/watch-token")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({ "client_id": "widget:mcp" }))
        .await
        .unwrap();
    let watch_body: Value = watch.json().await.unwrap();
    let watch = watch_body["token"].as_str().unwrap();

    let (status, _) = rpc(&srv, watch, init()).await;
    assert_eq!(status, 401);
    let (status, _) = rpc(&srv, &jwt(), init()).await;
    assert_eq!(status, 401);

    let resp = srv
        .get("/api/v1/api-tokens")
        .header("Authorization", format!("Bearer {watch}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);
}

#[ntex::test]
async fn a_foreign_origin_is_refused_and_a_missing_one_is_not() {
    let srv = test_server(state(None).await).await;
    let token = mint(&srv, &[]).await;
    let resp = srv
        .post("/mcp")
        .header("Authorization", format!("Bearer {token}"))
        .header("Origin", "https://evil.example")
        .send_json(&init())
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 403);

    let (status, body) = rpc(&srv, &token, init()).await;
    assert_eq!(status, 200, "{body}");
}

#[ntex::test]
async fn an_expired_token_is_refused() {
    let st = state(None).await;
    let now = chrono::Utc::now().timestamp();
    let secret = format!("{}{}", api_tokens::PREFIX, "ab".repeat(32));
    api_tokens::insert(
        &st.db,
        "expired",
        "admin",
        "old",
        &api_tokens::hash(&secret),
        "[]",
        now - 10,
        now - 1,
    )
    .await
    .unwrap();
    let srv = test_server(st).await;
    let (status, _) = rpc(&srv, &secret, init()).await;
    assert_eq!(status, 401);
}

#[ntex::test]
async fn capabilities_advertise_mcp() {
    let srv = test_server(state(None).await).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    let body: Value = resp.json().await.unwrap();
    assert_eq!(body["mcp"], true, "{body}");
}

#[ntex::test]
async fn tool_calls_are_written_to_the_access_log() {
    let st = state(None).await;
    let db = st.db.clone();
    let srv = test_server(st).await;
    let token = mint(&srv, &[]).await;
    let (status, _) = rpc(
        &srv,
        &token,
        json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "tools/call",
            "params": { "name": "get_capabilities", "arguments": {} }
        }),
    )
    .await;
    assert_eq!(status, 200);
    let rows: Vec<(String, String, Option<String>, Option<String>)> = sqlx::query_as(
        "SELECT action, result, subject, detail FROM access_log WHERE kind = 'mcp' ORDER BY id",
    )
    .fetch_all(&db)
    .await
    .unwrap();
    assert_eq!(rows.len(), 1, "{rows:?}");
    assert_eq!(rows[0].0, "open");
    assert_eq!(rows[0].1, "ok");
    assert_eq!(rows[0].2.as_deref(), Some("admin"));
    assert_eq!(rows[0].3.as_deref(), Some("get_capabilities"));
}
