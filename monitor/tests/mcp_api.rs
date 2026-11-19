//! `/api-tokens` and `/api/v1/mcp` (#1681): what mints an MCP client's
//! credential, what the endpoint answers it, and what it refuses — through
//! the real route table, since what a route is behind is decided there.

mod common;

use std::sync::Arc;

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::{Config, ServerConfig};

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

async fn server() -> (TestServer, Arc<AppState>) {
    common::machine::server_with(Config {
        server: Some(ServerConfig {
            cors_allowed_origins: vec!["https://panel.example".into()],
            ..Default::default()
        }),
        ..Default::default()
    })
    .await
}

fn jwt() -> String {
    generate_token(SECRET).unwrap()
}

/// One request to `/mcp` as an MCP client sends it, with every header this
/// endpoint reads, overridable one at a time.
struct Mcp<'a> {
    srv: &'a TestServer,
    token: Option<String>,
    accept: Option<&'static str>,
    content_type: Option<&'static str>,
    origin: Option<String>,
}

impl<'a> Mcp<'a> {
    fn new(srv: &'a TestServer, token: Option<String>) -> Self {
        Self {
            srv,
            token,
            accept: Some("application/json, text/event-stream"),
            content_type: Some("application/json"),
            origin: None,
        }
    }

    async fn post(&self, body: impl Into<Body>) -> (u16, Value) {
        let mut req = self
            .srv
            .request(Method::POST, self.srv.url("/api/v1/mcp"))
            .timeout(std::time::Duration::from_secs(30));
        if let Some(token) = &self.token {
            req = req.header("Authorization", format!("Bearer {token}"));
        }
        if let Some(accept) = self.accept {
            req = req.header("Accept", accept);
        }
        if let Some(content_type) = self.content_type {
            req = req.header("Content-Type", content_type);
        }
        if let Some(origin) = &self.origin {
            req = req.header("Origin", origin);
        }
        let resp = match body.into() {
            Body::Json(value) => req.send_json(&value).await,
            Body::Raw(bytes) => req.send_body(bytes).await,
        }
        .unwrap();
        let status = resp.status().as_u16();
        let bytes = resp.body().limit(16 * 1024 * 1024).await.unwrap_or_default();
        (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
    }
}

enum Body {
    Json(Value),
    Raw(Vec<u8>),
}

impl From<Value> for Body {
    fn from(value: Value) -> Self {
        Body::Json(value)
    }
}

impl From<Vec<u8>> for Body {
    fn from(bytes: Vec<u8>) -> Self {
        Body::Raw(bytes)
    }
}

/// One request to a `/api/v1` route of the panel's, as the panel sends it.
async fn panel(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    let req = srv
        .request(method, srv.url(path))
        .timeout(std::time::Duration::from_secs(30))
        .header("Authorization", format!("Bearer {}", jwt()));
    let resp = match body {
        Some(body) => req.send_json(&body).await,
        None => req.send().await,
    }
    .unwrap();
    let status = resp.status().as_u16();
    let bytes = resp.body().await.unwrap_or_default();
    (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

/// A token minted the way a person mints one: the password again, and the
/// scopes it is to have.
async fn mint(srv: &TestServer, name: &str, scopes: &[&str]) -> (i64, String) {
    let (status, body) = panel(
        srv,
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({
            "name": name,
            "password": common::PASSWORD,
            "scopes": scopes,
            "days": 1,
        })),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    let id = body["id"].as_i64().unwrap();
    let token = body["token_value"].as_str().unwrap().to_string();
    assert!(token.starts_with("sbt_"), "{token}");
    (id, token)
}

fn rpc(id: u32, method: &str, params: Value) -> Value {
    json!({ "jsonrpc": "2.0", "id": id, "method": method, "params": params })
}

fn initialize() -> Value {
    rpc(
        1,
        "initialize",
        json!({
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": { "name": "test", "version": "0" },
        }),
    )
}

#[ntex::test]
async fn a_token_minted_with_the_password_reads_the_machine() {
    let (srv, _) = server().await;
    let (_, token) = mint(&srv, "claude", &["read"]).await;
    let mcp = Mcp::new(&srv, Some(token));

    let (status, body) = mcp.post(initialize()).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["result"]["protocolVersion"], "2025-06-18");
    assert_eq!(body["result"]["serverInfo"]["name"], "serverbox-monitor");

    let (_, body) = mcp.post(rpc(2, "tools/list", json!({}))).await;
    let names: Vec<&str> = body["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|t| t["name"].as_str().unwrap())
        .collect();
    assert_eq!(
        names,
        [
            "machine_status",
            "machine_metrics",
            "machine_capabilities",
            "processes",
            "services",
            "containers",
            "cron",
            "tmux",
            "firewall",
        ]
    );

    // One tool that answers without touching the machine's services.
    let (_, body) = mcp
        .post(rpc(
            3,
            "tools/call",
            json!({ "name": "machine_capabilities", "arguments": {} }),
        ))
        .await;
    let caps = &body["result"]["structuredContent"];
    assert_eq!(caps["version"], env!("CARGO_PKG_VERSION"));
    assert_eq!(caps["access"]["ok"], true);

    // A method this server does not serve, and a tool it does not have.
    let (_, body) = mcp.post(rpc(4, "resources/list", json!({}))).await;
    assert_eq!(body["error"]["code"], -32601);
    let (_, body) = mcp
        .post(rpc(5, "tools/call", json!({ "name": "power", "arguments": {} })))
        .await;
    assert_eq!(body["error"]["code"], -32602);

    // A notification has nothing to answer.
    let (status, _) = mcp
        .post(json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }))
        .await;
    assert_eq!(status, 202);
}

#[ntex::test]
async fn only_an_api_token_that_has_not_expired_gets_in() {
    let (srv, state) = server().await;
    let (id, token) = mint(&srv, "claude", &["read"]).await;

    // The panel's own credential, and no credential, are not MCP's.
    for none in [None, Some(jwt())] {
        let (status, _) = Mcp::new(&srv, none).post(initialize()).await;
        assert_eq!(status, 401);
    }
    let (status, _) = Mcp::new(&srv, Some("sbt_not-a-token".into())).post(initialize()).await;
    assert_eq!(status, 401);

    // An expired row, as a token minted before its expiry and used after.
    sqlx::query(
        "INSERT INTO api_tokens (name, token_hash, scopes, expires_at) VALUES (?, ?, 'read', '2001-01-01 00:00:00')",
    )
    .bind("old")
    .bind(server_box_monitor::db::api_tokens::hash("sbt_expired"))
    .execute(&state.db)
    .await
    .unwrap();
    let (status, _) = Mcp::new(&srv, Some("sbt_expired".into())).post(initialize()).await;
    assert_eq!(status, 401);

    // Revoked, it is a missing credential from then on.
    let (status, _) = panel(&srv, Method::DELETE, &format!("/api/v1/api-tokens/{id}"), None).await;
    assert_eq!(status, 204);
    let (status, _) = Mcp::new(&srv, Some(token)).post(initialize()).await;
    assert_eq!(status, 401);
}

#[ntex::test]
async fn a_token_without_read_is_told_so_and_shown_no_tools() {
    let (srv, _) = server().await;
    let (_, token) = mint(&srv, "later", &["exec"]).await;
    let (status, body) = Mcp::new(&srv, Some(token.clone())).post(initialize()).await;
    assert_eq!(status, 200);
    assert_eq!(body["error"]["code"], -32602, "{body}");
    // A notification is acknowledged even when there is nothing to serve it.
    let (status, _) = Mcp::new(&srv, Some(token))
        .post(json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }))
        .await;
    assert_eq!(status, 202);
}

#[ntex::test]
async fn the_transport_contract_is_answered_before_the_body() {
    let (srv, _) = server().await;
    let (_, token) = mint(&srv, "claude", &["read"]).await;
    let token = Some(token);

    let mut mcp = Mcp::new(&srv, token.clone());
    mcp.accept = Some("text/html");
    let (status, _) = mcp.post(initialize()).await;
    assert_eq!(status, 406);

    let mut mcp = Mcp::new(&srv, token.clone());
    mcp.content_type = Some("text/plain");
    let (status, _) = mcp.post(initialize()).await;
    assert_eq!(status, 415);

    let (status, _) = Mcp::new(&srv, token.clone()).post(b"{".to_vec()).await;
    assert_eq!(status, 400);

    // A body a client would have to send for this is not one of ours: refused
    // on its declared length, before it is read.
    let mut big = initialize();
    big["params"]["padding"] = json!("x".repeat(300 * 1024));
    let (status, _) = Mcp::new(&srv, token.clone()).post(big).await;
    assert_eq!(status, 413);

    // A page that may drive this endpoint says so; one that may not, is not.
    let mut mcp = Mcp::new(&srv, token.clone());
    mcp.origin = Some("https://evil.example".into());
    let (status, _) = mcp.post(initialize()).await;
    assert_eq!(status, 403);
    let mut mcp = Mcp::new(&srv, token.clone());
    mcp.origin = Some("https://panel.example".into());
    let (status, _) = mcp.post(initialize()).await;
    assert_eq!(status, 200);
    // No Origin at all is every real MCP client, and allowed.
    let (status, _) = Mcp::new(&srv, token.clone()).post(initialize()).await;
    assert_eq!(status, 200);
}

#[ntex::test]
async fn a_panel_this_agent_serves_is_a_same_origin_caller() {
    // No CORS list, as an agent serving its own panel has: the page it serves
    // is same-origin, which `origin_allowed` admits.
    let (srv, _) = common::machine::server().await;
    let (_, token) = mint(&srv, "claude", &["read"]).await;
    let mut mcp = Mcp::new(&srv, Some(token));
    let base = srv.url("/");
    mcp.origin = Some(base.trim_end_matches('/').to_string());
    let (status, _) = mcp.post(initialize()).await;
    assert_eq!(status, 200);
}

#[ntex::test]
async fn a_password_change_ends_every_token() {
    let (srv, _) = server().await;
    let (_, token) = mint(&srv, "claude", &["read"]).await;
    let (status, _) = Mcp::new(&srv, Some(token.clone())).post(initialize()).await;
    assert_eq!(status, 200);

    let (status, body) = panel(
        &srv,
        Method::PUT,
        "/api/v1/me/password",
        Some(json!({ "current_password": common::PASSWORD, "new_password": "another-password" })),
    )
    .await;
    assert_eq!(status, 204, "{body}");

    let (status, _) = Mcp::new(&srv, Some(token)).post(initialize()).await;
    assert_eq!(status, 401);
}

#[ntex::test]
async fn what_a_token_does_is_audited_by_tool_and_token_name() {
    let (srv, state) = server().await;
    let (_, token) = mint(&srv, "claude", &["read"]).await;
    let (status, _) = Mcp::new(&srv, Some(token))
        .post(rpc(
            1,
            "tools/call",
            json!({ "name": "machine_capabilities", "arguments": {} }),
        ))
        .await;
    assert_eq!(status, 200);

    let rows: Vec<(String, String, Option<String>, Option<String>)> = sqlx::query_as(
        "SELECT action, result, subject, detail FROM access_log WHERE kind = 'mcp' ORDER BY id",
    )
    .fetch_all(&state.db)
    .await
    .unwrap();
    assert_eq!(rows.len(), 1, "{rows:?}");
    assert_eq!(rows[0].0, "open");
    assert_eq!(rows[0].1, "ok");
    assert_eq!(rows[0].2.as_deref(), Some("api token 'claude'"));
    assert_eq!(rows[0].3.as_deref(), Some("tool machine_capabilities"));
}

#[ntex::test]
async fn a_token_is_listed_with_its_scopes_and_what_it_last_used() {
    let (srv, _) = server().await;
    let (id, token) = mint(&srv, "claude", &["read"]).await;
    Mcp::new(&srv, Some(token)).post(initialize()).await;

    let (status, body) = panel(&srv, Method::GET, "/api/v1/api-tokens", None).await;
    assert_eq!(status, 200);
    let row = &body.as_array().unwrap()[0];
    assert_eq!(row["id"], id);
    assert_eq!(row["name"], "claude");
    assert_eq!(row["scopes"], json!(["read"]));
    assert!(row["last_used_at"].is_string(), "{row}");

    // Minting one costs the password.
    let (status, _) = panel(
        &srv,
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({ "name": "x", "password": "wrong", "scopes": ["read"] })),
    )
    .await;
    assert_eq!(status, 403);
    // And a scope this build does not know is refused, not dropped.
    let (status, _) = panel(
        &srv,
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({ "name": "x", "password": common::PASSWORD, "scopes": ["root"] })),
    )
    .await;
    assert_eq!(status, 400);
}
