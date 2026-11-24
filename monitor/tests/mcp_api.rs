//! `/api-tokens*` and `/api/v1/mcp` (#1681): default full control, global and
//! per-token fine-grained restrictions, structured tools, transport contract
//! and audit logging.

mod common;

use std::sync::Arc;

use ntex::http::Method;
use ntex::web::test::TestServer;
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::{Config, ServerConfig};
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::TcpStream;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

async fn server() -> (TestServer, Arc<AppState>) {
    server_with(Value::Null).await
}

async fn server_with(mcp: Value) -> (TestServer, Arc<AppState>) {
    let mcp = if mcp.is_null() {
        None
    } else {
        Some(serde_json::from_value(mcp).unwrap())
    };
    common::machine::server_with(Config {
        server: Some(ServerConfig {
            cors_allowed_origins: vec!["https://panel.example".into()],
            ..Default::default()
        }),
        mcp,
        ..Default::default()
    })
    .await
}

fn jwt() -> String {
    generate_token(SECRET).unwrap()
}

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

async fn mint_default(srv: &TestServer, name: &str) -> (i64, String) {
    let (status, body) = panel(
        srv,
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({
            "name": name,
            "password": common::PASSWORD,
        })),
    )
    .await;
    assert_eq!(status, 200, "{body}");
    let id = body["id"].as_i64().unwrap();
    let token = body["token_value"].as_str().unwrap().to_string();
    assert!(token.starts_with("sbt_"), "{token}");
    (id, token)
}

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
    (
        body["id"].as_i64().unwrap(),
        body["token_value"].as_str().unwrap().to_string(),
    )
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

fn tool_names(body: &Value) -> Vec<&str> {
    body["result"]["tools"]
        .as_array()
        .unwrap()
        .iter()
        .map(|t| t["name"].as_str().unwrap())
        .collect()
}

#[ntex::test]
async fn a_default_token_gets_full_control_and_runs_commands_out_of_the_box() {
    let (srv, _) = server().await;
    let (_, token) = mint_default(&srv, "default-full").await;
    let mcp = Mcp::new(&srv, Some(token));

    let (_, body) = mcp.post(rpc(1, "tools/list", json!({}))).await;
    let names = tool_names(&body);
    for expected in [
        "machine_status",
        "processes",
        "storage",
        "virt",
        "stacks",
        "system_users",
        "fs_roots",
        "fs_read",
        "fs_write",
        "run_command",
        "kill_process",
        "service_action",
        "container_action",
        "cron_edit",
        "virt_power",
        "stack_action",
        "power",
    ] {
        assert!(names.contains(&expected), "missing {expected} in {names:?}");
    }

    let (_, ran) = mcp
        .post(rpc(
            2,
            "tools/call",
            json!({ "name": "run_command", "arguments": { "command": "echo ok:1&& echo ok:2" } }),
        ))
        .await;
    assert_eq!(ran["result"]["isError"], false, "{ran}");
    let lines: Vec<&str> = ran["result"]["structuredContent"]["stdout"]
        .as_str()
        .unwrap()
        .lines()
        .map(str::trim)
        .collect();
    assert_eq!(lines, vec!["ok:1", "ok:2"]);
}

#[ntex::test]
async fn global_policy_and_token_permissions_intersect_live() {
    let (srv, _) = server().await;
    let (id, token) = mint_default(&srv, "claude").await;
    let mcp = Mcp::new(&srv, Some(token));

    // Narrow globally via API: turn off `power` and `fs_write`, and deny `rm *`.
    let (status, policy) = panel(
        &srv,
        Method::PUT,
        "/api/v1/api-tokens/policy",
        Some(json!({
            "scopes": ["read", "fs_read", "exec", "process"],
            "commands": { "mode": "allow_all", "allow": [], "deny": ["rm *"] },
        })),
    )
    .await;
    assert_eq!(status, 200, "{policy}");

    let (_, body) = mcp.post(rpc(1, "tools/list", json!({}))).await;
    let names = tool_names(&body);
    assert!(names.contains(&"run_command"));
    assert!(names.contains(&"fs_read"));
    assert!(!names.contains(&"power"));
    assert!(!names.contains(&"fs_write"));

    // Calling a globally disabled tool is rejected by the protocol.
    let (_, denied_tool) = mcp
        .post(rpc(2, "tools/call", json!({ "name": "power", "arguments": { "action": "reboot" } })))
        .await;
    assert_eq!(denied_tool["error"]["code"], -32602);

    // Global deny rule blocks `rm` while allowing everything else.
    let (_, denied_cmd) = mcp
        .post(rpc(3, "tools/call", json!({ "name": "run_command", "arguments": { "command": "echo hi && rm -f /tmp/nope" } })))
        .await;
    assert_eq!(denied_cmd["result"]["isError"], true, "{denied_cmd}");
    assert!(denied_cmd["result"]["content"][0]["text"].as_str().unwrap().contains("global MCP policy"));

    // Narrow the token itself to an allowlist of `echo *` and scopes `["read", "exec"]`.
    let (status, updated) = panel(
        &srv,
        Method::PUT,
        &format!("/api/v1/api-tokens/{id}"),
        Some(json!({
            "name": "claude-narrow",
            "scopes": ["read", "exec"],
            "commands": { "mode": "allowlist", "allow": ["echo *"], "deny": [] },
        })),
    )
    .await;
    assert_eq!(status, 200, "{updated}");
    assert_eq!(updated["name"], "claude-narrow");

    let (_, body) = mcp.post(rpc(4, "tools/list", json!({}))).await;
    let names = tool_names(&body);
    assert!(!names.contains(&"fs_read"));
    assert!(!names.contains(&"kill_process"));
    assert!(names.contains(&"run_command"));

    let (_, ok_cmd) = mcp
        .post(rpc(5, "tools/call", json!({ "name": "run_command", "arguments": { "command": "echo allowed" } })))
        .await;
    assert_eq!(ok_cmd["result"]["isError"], false);

    let (_, blocked_by_token) = mcp
        .post(rpc(6, "tools/call", json!({ "name": "run_command", "arguments": { "command": "uname -a" } })))
        .await;
    assert_eq!(blocked_by_token["result"]["isError"], true);
    assert!(blocked_by_token["result"]["content"][0]["text"].as_str().unwrap().contains("token command policy"));
}

#[ntex::test]
async fn config_toml_ceiling_bounds_every_token() {
    // `Config::validate` rejects unknown scope names and wildcard allow rules.
    let bad_scope = Config {
        mcp: Some(serde_json::from_value(json!({ "disabled_scopes": ["fs-write"] })).unwrap()),
        ..Default::default()
    };
    assert!(bad_scope.validate().is_err());
    let bad_rule = Config {
        mcp: Some(serde_json::from_value(json!({ "commands": { "mode": "allowlist", "allow": ["*"] } })).unwrap()),
        ..Default::default()
    };
    assert!(bad_rule.validate().is_err());

    let (srv, _) = server_with(json!({
        "allow_power": false,
        "disabled_scopes": ["fs_write"],
        "commands": { "mode": "allowlist", "allow": ["echo *"], "deny": ["rm *"] }
    }))
    .await;
    let (_, token) = mint_default(&srv, "t").await;
    let mcp = Mcp::new(&srv, Some(token));

    let (_, body) = mcp.post(rpc(1, "tools/list", json!({}))).await;
    let names = tool_names(&body);
    assert!(!names.contains(&"power"));
    assert!(!names.contains(&"fs_write"));
    assert!(names.contains(&"run_command"));

    let (_, refused) = mcp
        .post(rpc(2, "tools/call", json!({ "name": "run_command", "arguments": { "command": "ls" } })))
        .await;
    assert_eq!(refused["result"]["isError"], true);

    // When all scopes are turned off globally, `initialize` and `tools/list`
    // still speak MCP cleanly (`tools: []`), while batch arrays are `-32600`.
    let (status, _) = panel(
        &srv,
        Method::PUT,
        "/api/v1/api-tokens/policy",
        Some(json!({ "scopes": [] })),
    )
    .await;
    assert_eq!(status, 200);
    let (status, init) = mcp.post(initialize()).await;
    assert_eq!(status, 200);
    assert_eq!(init["result"]["serverInfo"]["name"], "serverbox-monitor");
    let (_, listed) = mcp.post(rpc(3, "tools/list", json!({}))).await;
    assert_eq!(listed["result"]["tools"], json!([]));
    let (batch_status, batch_body) = mcp.post(json!([initialize()])).await;
    assert_eq!(batch_status, 200);
    assert_eq!(batch_body["error"]["code"], -32600);
}

#[ntex::test]
async fn filesystem_tools_manage_files_and_protect_agent_state() {
    let (srv, _) = server().await;
    let (_, token) = mint(&srv, "fs", &["fs_read", "fs_write"]).await;
    let mcp = Mcp::new(&srv, Some(token));

    // Protected agent state (`config.toml`) is refused by `fs_roots::Protected`.
    let cfg_path = std::env::current_dir().unwrap().join("config.toml");
    let (_, denied) = mcp
        .post(rpc(99, "tools/call", json!({ "name": "fs_write", "arguments": { "path": cfg_path.to_str().unwrap(), "content": "nope" } })))
        .await;
    assert_eq!(denied["result"]["isError"], true, "{denied}");

    let tmp = tempfile::tempdir_in(std::env::temp_dir()).unwrap();
    let sub = tmp.path().join("mcp-sub");
    let file = sub.join("hello.txt");
    let renamed = sub.join("moved.txt");

    let (_, r) = mcp
        .post(rpc(1, "tools/call", json!({ "name": "fs_mkdir", "arguments": { "path": sub.to_str().unwrap() } })))
        .await;
    assert_eq!(r["result"]["isError"], false, "{r}");

    let (_, w) = mcp
        .post(rpc(2, "tools/call", json!({ "name": "fs_write", "arguments": { "path": file.to_str().unwrap(), "content": "v1" } })))
        .await;
    assert_eq!(w["result"]["isError"], false, "{w}");
    let v1 = w["result"]["structuredContent"]["version"].as_str().unwrap().to_string();

    let (_, read) = mcp
        .post(rpc(3, "tools/call", json!({ "name": "fs_read", "arguments": { "path": file.to_str().unwrap() } })))
        .await;
    assert_eq!(read["result"]["structuredContent"]["content"], "v1");
    assert_eq!(read["result"]["structuredContent"]["version"], v1);

    // Stale `if_version` refuses overwrite.
    let (_, conflict) = mcp
        .post(rpc(4, "tools/call", json!({ "name": "fs_write", "arguments": { "path": file.to_str().unwrap(), "content": "v2", "if_version": "stale" } })))
        .await;
    assert_eq!(conflict["result"]["isError"], true);

    let (_, w2) = mcp
        .post(rpc(5, "tools/call", json!({ "name": "fs_write", "arguments": { "path": file.to_str().unwrap(), "content": "中文测试", "if_version": v1 } })))
        .await;
    assert_eq!(w2["result"]["isError"], false, "{w2}");

    // Truncating inside a multi-byte UTF-8 sequence steps back to a char boundary.
    let (_, cut) = mcp
        .post(rpc(55, "tools/call", json!({ "name": "fs_read", "arguments": { "path": file.to_str().unwrap(), "max_bytes": 4 } })))
        .await;
    assert_eq!(cut["result"]["structuredContent"]["encoding"], "utf8");
    assert_eq!(cut["result"]["structuredContent"]["content"], "中");
    assert_eq!(cut["result"]["structuredContent"]["truncated"], true);

    let (_, mv) = mcp
        .post(rpc(6, "tools/call", json!({ "name": "fs_rename", "arguments": { "from": file.to_str().unwrap(), "to": renamed.to_str().unwrap() } })))
        .await;
    assert_eq!(mv["result"]["isError"], false, "{mv}");

    let (_, rm) = mcp
        .post(rpc(7, "tools/call", json!({ "name": "fs_remove", "arguments": { "path": sub.to_str().unwrap(), "recursive": true } })))
        .await;
    assert_eq!(rm["result"]["isError"], false, "{rm}");
    assert!(!sub.exists());
}

#[ntex::test]
async fn a_machine_tool_refuses_before_it_acts() {
    let (srv, _) = server().await;
    let (_, token) = mint(&srv, "t", &["read", "process", "service", "container"]).await;
    let mcp = Mcp::new(&srv, Some(token));
    for bad in [
        json!({ "part": "logs" }),
        json!({ "part": "logs", "id": "--help" }),
        json!({ "part": "nope" }),
    ] {
        let (_, body) = mcp
            .post(rpc(9, "tools/call", json!({ "name": "containers", "arguments": bad })))
            .await;
        assert_eq!(body["result"]["isError"], true, "{bad}: {body}");
    }
    for arguments in [
        json!({ "pid": 1 }),
        json!({ "pid": "one", "start_id": "x" }),
    ] {
        let (_, body) = mcp
            .post(rpc(1, "tools/call", json!({ "name": "kill_process", "arguments": arguments })))
            .await;
        assert_eq!(body["result"]["isError"], true, "{arguments}: {body}");
    }
    let (_, body) = mcp
        .post(rpc(
            2,
            "tools/call",
            json!({ "name": "service_action", "arguments": { "key": "system:nothing.service", "action": "restart" } }),
        ))
        .await;
    assert_eq!(body["result"]["isError"], true, "{body}");
    let (_, body) = mcp
        .post(rpc(
            3,
            "tools/call",
            json!({ "name": "container_action", "arguments": { "action": "stop", "id": "" } }),
        ))
        .await;
    assert_eq!(body["result"]["isError"], true, "{body}");
}

#[ntex::test]
async fn a_token_minted_with_read_scope_reads_the_machine() {
    let (srv, _) = server().await;
    let (_, token) = mint(&srv, "claude", &["read"]).await;
    let mcp = Mcp::new(&srv, Some(token));

    let (status, body) = mcp.post(initialize()).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["result"]["protocolVersion"], "2025-06-18");
    assert_eq!(body["result"]["serverInfo"]["name"], "serverbox-monitor");

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
    assert!(body["result"].get("resultType").is_none());

    let (_, body) = mcp.post(rpc(4, "resources/list", json!({}))).await;
    assert_eq!(body["error"]["code"], -32601);
    let (_, body) = mcp
        .post(rpc(5, "tools/call", json!({ "name": "power", "arguments": {} })))
        .await;
    assert_eq!(body["error"]["code"], -32602);
}

#[ntex::test]
async fn non_post_methods_on_mcp_answer_405_with_allow_post() {
    let (srv, _) = server().await;
    for method in [Method::GET, Method::DELETE] {
        let resp = srv.request(method.clone(), srv.url("/api/v1/mcp")).send().await.unwrap();
        assert_eq!(resp.status().as_u16(), 405, "{method}");
        assert_eq!(resp.headers().get("allow").and_then(|v| v.to_str().ok()), Some("POST"));
    }
}

#[ntex::test]
async fn only_an_api_token_that_has_not_expired_gets_in() {
    let (srv, state) = server().await;
    let (id, token) = mint(&srv, "claude", &["read"]).await;

    for none in [None, Some(jwt())] {
        let (status, _) = Mcp::new(&srv, none).post(initialize()).await;
        assert_eq!(status, 401);
    }
    let (status, _) = Mcp::new(&srv, Some("sbt_not-a-token".into())).post(initialize()).await;
    assert_eq!(status, 401);

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

    let (status, listed) = panel(&srv, Method::GET, "/api/v1/api-tokens", None).await;
    assert_eq!(status, 200);
    assert_eq!(listed[1]["expired"], true);

    let (status, _) = panel(&srv, Method::DELETE, &format!("/api/v1/api-tokens/{id}"), None).await;
    assert_eq!(status, 204);
    let (status, _) = Mcp::new(&srv, Some(token)).post(initialize()).await;
    assert_eq!(status, 401);
}

#[ntex::test]
async fn a_notification_is_acknowledged_without_an_answer() {
    let (srv, _) = server().await;
    let (_, token) = mint(&srv, "claude", &["read"]).await;
    let (status, body) = Mcp::new(&srv, Some(token))
        .post(json!({ "jsonrpc": "2.0", "method": "notifications/initialized" }))
        .await;
    assert_eq!(status, 202);
    assert_eq!(body, Value::Null);
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

    // Write the oversized request concurrently while reading the status line so
    // an early 413 + socket close from the server cannot fail with WSAECONNRESET
    // on Windows while the client is still pushing the 5 MiB body.
    let stream = TcpStream::connect(srv.addr()).await.unwrap();
    let (read_half, mut write_half) = stream.into_split();
    let mut big = initialize();
    big["params"]["padding"] = json!("x".repeat(5 * 1024 * 1024));
    let body = serde_json::to_vec(&big).unwrap();
    let headers = format!(
        "POST /api/v1/mcp HTTP/1.1\r\n\
         Host: {}\r\n\
         Authorization: Bearer {}\r\n\
         Accept: application/json, text/event-stream\r\n\
         Content-Type: application/json\r\n\
         Content-Length: {}\r\n\
         Connection: close\r\n\r\n",
        srv.addr(),
        token.as_deref().unwrap(),
        body.len(),
    );
    let writer = tokio::spawn(async move {
        let _ = write_half.write_all(headers.as_bytes()).await;
        let _ = write_half.write_all(&body).await;
    });
    let mut status_line = String::new();
    tokio::time::timeout(
        std::time::Duration::from_secs(5),
        BufReader::new(read_half).read_line(&mut status_line),
    )
    .await
    .expect("server did not answer 413 within 5s")
    .unwrap();
    writer.abort();
    assert!(
        status_line.starts_with("HTTP/1.1 413 "),
        "expected 413, got: {status_line}"
    );

    let mut mcp = Mcp::new(&srv, token.clone());
    mcp.origin = Some("https://evil.example".into());
    let (status, _) = mcp.post(initialize()).await;
    assert_eq!(status, 403);
    let mut mcp = Mcp::new(&srv, token.clone());
    mcp.origin = Some("https://panel.example".into());
    let (status, _) = mcp.post(initialize()).await;
    assert_eq!(status, 200);
    let (status, _) = Mcp::new(&srv, token.clone()).post(initialize()).await;
    assert_eq!(status, 200);

    // `MCP-Protocol-Version` is accepted for spoken versions and 400 otherwise.
    let ok_ver = srv
        .request(Method::POST, srv.url("/api/v1/mcp"))
        .header("Authorization", format!("Bearer {}", token.as_deref().unwrap()))
        .header("Accept", "application/json")
        .header("Content-Type", "application/json")
        .header("MCP-Protocol-Version", "2025-06-18")
        .send_json(&rpc(1, "ping", json!({})))
        .await
        .unwrap();
    assert_eq!(ok_ver.status().as_u16(), 200);
    let bad_ver = srv
        .request(Method::POST, srv.url("/api/v1/mcp"))
        .header("Authorization", format!("Bearer {}", token.as_deref().unwrap()))
        .header("Accept", "application/json")
        .header("Content-Type", "application/json")
        .header("MCP-Protocol-Version", "1999-01-01")
        .send_json(&rpc(1, "ping", json!({})))
        .await
        .unwrap();
    assert_eq!(bad_ver.status().as_u16(), 400);
}

#[ntex::test]
async fn a_panel_this_agent_serves_is_a_same_origin_caller() {
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
    let (_, token) = mint_default(&srv, "claude").await;
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
async fn calls_are_audited_and_run_command_records_its_programs() {
    let (srv, state) = server().await;
    let (_, token) = mint_default(&srv, "claude").await;
    let mcp = Mcp::new(&srv, Some(token));

    let (status, _) = mcp
        .post(rpc(1, "tools/call", json!({ "name": "machine_capabilities", "arguments": {} })))
        .await;
    assert_eq!(status, 200);

    let (status, _) = mcp
        .post(rpc(2, "tools/call", json!({ "name": "run_command", "arguments": { "command": "echo first\necho second" } })))
        .await;
    assert_eq!(status, 200);

    let rows: Vec<(String, String, Option<String>, Option<String>)> = sqlx::query_as(
        "SELECT action, result, subject, detail FROM access_log WHERE kind = 'mcp' ORDER BY id",
    )
    .fetch_all(&state.db)
    .await
    .unwrap();
    assert_eq!(rows.len(), 2, "{rows:?}");
    assert_eq!(rows[0].2.as_deref(), Some("api token 'claude'"));
    assert_eq!(rows[0].3.as_deref(), Some("tool machine_capabilities"));
    assert_eq!(rows[1].1, "ok");
    let detail = rows[1].3.as_deref().unwrap();
    assert!(detail.starts_with("tool run_command: echo (22 bytes, blake3 "), "{detail}");
    assert!(!detail.contains("first"), "{detail}");
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
    assert_eq!(row["expired"], false);
    assert!(row["last_used_at"].is_string(), "{row}");

    let (status, _) = panel(
        &srv,
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({ "name": "x", "password": "wrong", "scopes": ["read"] })),
    )
    .await;
    assert_eq!(status, 403);
    let (status, _) = panel(
        &srv,
        Method::POST,
        "/api/v1/api-tokens",
        Some(json!({ "name": "x", "password": common::PASSWORD, "scopes": ["root"] })),
    )
    .await;
    assert_eq!(status, 400);
}

#[ntex::test]
async fn per_token_rate_limit_isolates_tokens_and_answers_429() {
    let (srv, state) = server().await;
    let (id_a, token_a) = mint(&srv, "token-a", &["read"]).await;
    let (_, token_b) = mint(&srv, "token-b", &["read"]).await;

    // Drain token A's bucket without consuming the IP limiter.
    for _ in 0..state.mcp_token_limiter.stats().capacity {
        assert!(state.mcp_token_limiter.check_rate_limit(&id_a).allowed);
    }

    let resp_a = srv
        .post("/api/v1/mcp")
        .header("authorization", format!("Bearer {token_a}"))
        .header("accept", "application/json")
        .header("content-type", "application/json")
        .send_json(&initialize())
        .await
        .unwrap();
    assert_eq!(resp_a.status().as_u16(), 429);
    assert_eq!(resp_a.headers().get("x-ratelimit-remaining").unwrap(), "0");
    assert!(resp_a.headers().get("retry-after").is_some());

    // Token B on the same peer IP keeps its own bucket and succeeds.
    let resp_b = srv
        .post("/api/v1/mcp")
        .header("authorization", format!("Bearer {token_b}"))
        .header("accept", "application/json")
        .header("content-type", "application/json")
        .send_json(&initialize())
        .await
        .unwrap();
    assert_eq!(resp_b.status().as_u16(), 200);
    assert!(resp_b.headers().get("x-ratelimit-remaining").is_some());
    assert!(resp_b.headers().get("x-ratelimit-limit").is_some());
    assert!(resp_b.headers().get("x-ratelimit-reset").is_some());
}

#[ntex::test]
async fn pre_auth_ip_rate_limit_blocks_before_auth_and_ignores_xff() {
    let (srv, state) = server().await;
    let loopback: std::net::IpAddr = "127.0.0.1".parse().unwrap();

    for _ in 0..state.mcp_ip_limiter.stats().capacity {
        assert!(state.mcp_ip_limiter.check_rate_limit(&loopback).allowed);
    }

    // Even without credentials and with a spoofed X-Forwarded-For, IP limiting
    // rejects with 429 before auth runs (rather than 401).
    let resp = srv
        .post("/api/v1/mcp")
        .header("x-forwarded-for", "203.0.113.9")
        .header("accept", "application/json")
        .header("content-type", "application/json")
        .send_json(&initialize())
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 429);
    assert_eq!(resp.headers().get("x-ratelimit-remaining").unwrap(), "0");
    assert!(resp.headers().get("retry-after").is_some());
}
