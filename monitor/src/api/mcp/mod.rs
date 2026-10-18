//! `POST /mcp` — Streamable HTTP JSON for MCP clients (issue #1681).
//!
//! ntex is not hyper, so this is a small JSON-RPC adapter rather than
//! rmcp's Tower `StreamableHttpService`. The wire shape is the one a
//! `legacy_session_mode: false` / `json_response: true` client speaks:
//! one JSON object in, one JSON object out, no session id.
//!
//! Read tools only. Destructive ones wait on the next change, with
//! confirmation. What a token may call is its scopes intersected with the
//! account's role; `admin` is never on a token.

use std::net::{IpAddr, Ipv4Addr};
use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::{Value, json};
use sbm_parser::proc::ProcSortMode;

use crate::api::authz::{self, TokenCaller, error};
use crate::api::fs::{self, EntryView};
use crate::api::process;
use crate::api::server::{self, AppState};
use crate::api::ws;
use crate::api::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::permissions::Grant;
use crate::utils::error::Result;

/// Versions this adapter will echo. Anything else is answered with
/// [`PROTOCOL`].
const SUPPORTED: &[&str] = &["2024-11-05", "2025-03-26", "2025-06-18"];
const PROTOCOL: &str = "2025-03-26";

#[derive(Clone, Copy)]
enum Tool {
    GetMetrics,
    GetCapabilities,
    ListProcesses,
    FsRoots,
    FsList,
    FsStat,
}

impl Tool {
    fn parse(name: &str) -> Option<Self> {
        Some(match name {
            "get_metrics" => Self::GetMetrics,
            "get_capabilities" => Self::GetCapabilities,
            "list_processes" => Self::ListProcesses,
            "fs_roots" => Self::FsRoots,
            "fs_list" => Self::FsList,
            "fs_stat" => Self::FsStat,
            _ => return None,
        })
    }

    fn name(self) -> &'static str {
        match self {
            Self::GetMetrics => "get_metrics",
            Self::GetCapabilities => "get_capabilities",
            Self::ListProcesses => "list_processes",
            Self::FsRoots => "fs_roots",
            Self::FsList => "fs_list",
            Self::FsStat => "fs_stat",
        }
    }

    fn description(self) -> &'static str {
        match self {
            Self::GetMetrics => "Current status sample for this machine.",
            Self::GetCapabilities => {
                "What this agent serves, and what this token may use over this link."
            }
            Self::ListProcesses => "The process table. Needs the shell scope.",
            Self::FsRoots => "Directories the file API will serve. Needs the files scope.",
            Self::FsList => "List one directory under the file roots. Needs the files scope.",
            Self::FsStat => "Describe one path under the file roots. Needs the files scope.",
        }
    }

    fn input_schema(self) -> Value {
        match self {
            Self::GetMetrics | Self::GetCapabilities | Self::FsRoots => {
                json!({ "type": "object", "properties": {} })
            }
            Self::ListProcesses => json!({
                "type": "object",
                "properties": {
                    "sort": {
                        "type": "string",
                        "enum": ["cpu", "mem", "rss", "read", "write", "pid", "user", "name"]
                    },
                    "ascending": { "type": "boolean" }
                }
            }),
            Self::FsList | Self::FsStat => json!({
                "type": "object",
                "properties": {
                    "path": { "type": "string" }
                },
                "required": ["path"]
            }),
        }
    }

    fn grant(self) -> Option<Grant> {
        match self {
            Self::GetMetrics | Self::GetCapabilities => None,
            Self::ListProcesses => Some(Grant::Shell),
            Self::FsRoots | Self::FsList | Self::FsStat => Some(Grant::Files),
        }
    }

    fn listed_for(self, token: &TokenCaller, state: &AppState, secure: bool) -> bool {
        match self.grant() {
            None => true,
            Some(grant) => token.caller.check(grant, state, secure).is_ok(),
        }
    }
}

fn all_tools() -> [Tool; 6] {
    [
        Tool::GetMetrics,
        Tool::GetCapabilities,
        Tool::ListProcesses,
        Tool::FsRoots,
        Tool::FsList,
        Tool::FsStat,
    ]
}

pub async fn handle(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
    body: web::types::Json<Value>,
) -> Result<HttpResponse> {
    if let Some(response) = admit(&req, &state) {
        return Ok(response);
    }
    let token = match authz::token_caller(&req, &state).await {
        Ok(token) => token,
        Err(response) => return Ok(response),
    };
    let body = body.into_inner();
    if body.is_array() {
        return Ok(rpc_error(
            Value::Null,
            -32600,
            "batched JSON-RPC is not served; send one request",
        ));
    }
    Ok(dispatch(&req, &state, &token, body).await)
}

/// Rate limit, TLS-or-loopback, and Origin — all before the token is looked
/// at, so a guessed `sbt_` is not confirmed by a different status.
fn admit(req: &HttpRequest, state: &AppState) -> Option<HttpResponse> {
    let ip = req
        .peer_addr()
        .map(|addr| addr.ip())
        .unwrap_or(IpAddr::V4(Ipv4Addr::UNSPECIFIED));
    let limited = state.mcp_limiter.check_rate_limit(ip);
    if !limited.allowed {
        return Some(error(
            StatusCode::TOO_MANY_REQUESTS,
            "rate_limited",
            "Too many MCP requests from this address",
        ));
    }
    if !authz::is_secure(req, state) {
        return Some(error(
            StatusCode::FORBIDDEN,
            "insecure_transport",
            "MCP requires TLS or a loopback peer",
        ));
    }
    if !ws::origin_allowed(req, &state.config.get_server().cors_allowed_origins) {
        return Some(error(
            StatusCode::FORBIDDEN,
            "origin",
            "Origin is not on cors_allowed_origins",
        ));
    }
    None
}

async fn dispatch(
    req: &HttpRequest,
    state: &AppState,
    token: &TokenCaller,
    body: Value,
) -> HttpResponse {
    let method = body.get("method").and_then(Value::as_str).unwrap_or("");
    let id = body.get("id").cloned();
    let params = body.get("params").cloned().unwrap_or(Value::Null);

    if id.is_none() {
        // A notification. Streamable HTTP answers 202 and nothing else.
        return HttpResponse::Accepted().finish();
    }
    let id = id.unwrap();

    match method {
        "initialize" => HttpResponse::Ok().json(&json!({
            "jsonrpc": "2.0",
            "id": id,
            "result": initialize_result(&params),
        })),
        "ping" => HttpResponse::Ok().json(&json!({
            "jsonrpc": "2.0",
            "id": id,
            "result": {},
        })),
        "tools/list" => {
            let secure = authz::is_secure(req, state);
            let tools: Vec<Value> = all_tools()
                .into_iter()
                .filter(|tool| tool.listed_for(token, state, secure))
                .map(|tool| {
                    json!({
                        "name": tool.name(),
                        "description": tool.description(),
                        "inputSchema": tool.input_schema(),
                    })
                })
                .collect();
            HttpResponse::Ok().json(&json!({
                "jsonrpc": "2.0",
                "id": id,
                "result": { "tools": tools },
            }))
        }
        "tools/call" => {
            let name = params.get("name").and_then(Value::as_str).unwrap_or("");
            let arguments = params.get("arguments").cloned().unwrap_or(json!({}));
            call_tool(req, state, token, id, name, arguments).await
        }
        "" => rpc_error(id, -32600, "method is required"),
        _ => rpc_error(id, -32601, &format!("unknown method {method:?}")),
    }
}

fn initialize_result(params: &Value) -> Value {
    let asked = params
        .get("protocolVersion")
        .and_then(Value::as_str)
        .unwrap_or(PROTOCOL);
    let protocol = if SUPPORTED.contains(&asked) {
        asked
    } else {
        PROTOCOL
    };
    json!({
        "protocolVersion": protocol,
        "capabilities": { "tools": { "listChanged": false } },
        "serverInfo": {
            "name": "serverbox-monitor",
            "version": env!("CARGO_PKG_VERSION"),
        },
    })
}

async fn call_tool(
    req: &HttpRequest,
    state: &AppState,
    token: &TokenCaller,
    id: Value,
    name: &str,
    arguments: Value,
) -> HttpResponse {
    let Some(tool) = Tool::parse(name) else {
        return tool_error(id, format!("unknown tool {name:?}"));
    };
    let secure = authz::is_secure(req, state);
    if !tool.listed_for(token, state, secure) {
        Event::new(Kind::Mcp, Action::Denied, Outcome::Denied)
            .subject(&token.caller.username)
            .remote_ip(peer_ip(req))
            .detail(tool.name())
            .record(&state.db)
            .await;
        return tool_error(id, format!("{} is not granted to this token", tool.name()));
    }
    let result = match run_tool(state, token, tool, arguments, secure).await {
        Ok(value) => {
            Event::new(Kind::Mcp, Action::Open, Outcome::Ok)
                .subject(&token.caller.username)
                .remote_ip(peer_ip(req))
                .detail(tool.name())
                .record(&state.db)
                .await;
            json!({
                "content": [{ "type": "text", "text": value.to_string() }],
                "isError": false,
            })
        }
        Err(message) => {
            Event::new(Kind::Mcp, Action::Open, Outcome::Error)
                .subject(&token.caller.username)
                .remote_ip(peer_ip(req))
                .detail(tool.name())
                .record(&state.db)
                .await;
            return tool_error(id, message);
        }
    };
    HttpResponse::Ok().json(&json!({
        "jsonrpc": "2.0",
        "id": id,
        "result": result,
    }))
}

async fn run_tool(
    state: &AppState,
    token: &TokenCaller,
    tool: Tool,
    arguments: Value,
    secure: bool,
) -> std::result::Result<Value, String> {
    match tool {
        Tool::GetMetrics => {
            let metrics = state.current_metrics.read().await;
            match &*metrics {
                Some(metrics) => server::metrics_json(metrics).map_err(|e| e.to_string()),
                None => Err("Metrics not available yet".into()),
            }
        }
        Tool::GetCapabilities => {
            Ok(server::capabilities_view(Some(&token.caller), state, secure).await)
        }
        Tool::ListProcesses => {
            #[derive(Deserialize, Default)]
            struct Args {
                sort: Option<ProcSortMode>,
                ascending: Option<bool>,
            }
            let args: Args = serde_json::from_value(arguments).unwrap_or_default();
            let table = process::snapshot(state, args.sort, args.ascending).await;
            serde_json::to_value(table).map_err(|e| e.to_string())
        }
        Tool::FsRoots => {
            let roots: Vec<String> = state
                .remote_access
                .fs
                .roots
                .as_slice()
                .iter()
                .map(|p| fs::exposed_path(p))
                .collect();
            Ok(json!({ "roots": roots }))
        }
        Tool::FsList => {
            let path = arg_path(&arguments)?;
            list_dir(state, path).await
        }
        Tool::FsStat => {
            let path = arg_path(&arguments)?;
            stat_path(state, path).await
        }
    }
}

fn arg_path(arguments: &Value) -> std::result::Result<&str, String> {
    arguments
        .get("path")
        .and_then(Value::as_str)
        .filter(|p| !p.is_empty())
        .ok_or_else(|| "path is required".into())
}

async fn list_dir(state: &AppState, path: &str) -> std::result::Result<Value, String> {
    let dir = state
        .remote_access
        .fs
        .roots
        .resolve_existing(path)
        .map_err(|e| e.to_string())?;
    let mut reader = tokio::fs::read_dir(&dir)
        .await
        .map_err(|e| e.to_string())?;
    let roots = &state.remote_access.fs.roots;
    let mut entries: Vec<EntryView> = Vec::new();
    loop {
        match reader.next_entry().await {
            Ok(Some(entry)) if roots.hides(&entry.path()) => {}
            Ok(Some(entry)) if fs::is_staging_name(&entry.file_name().to_string_lossy()) => {}
            Ok(Some(entry)) => entries.push(fs::view_of(&entry.path()).await),
            Ok(None) => break,
            Err(e) => return Err(e.to_string()),
        }
    }
    serde_json::to_value(entries).map_err(|e| e.to_string())
}

async fn stat_path(state: &AppState, path: &str) -> std::result::Result<Value, String> {
    let path = match state.remote_access.fs.roots.resolve_existing(path) {
        Ok(path) => path,
        Err(crate::core::fs_roots::FsDenied::OutsideRoots) => {
            return Err("not found".into());
        }
        Err(e) => return Err(e.to_string()),
    };
    serde_json::to_value(fs::view_of(&path).await).map_err(|e| e.to_string())
}

fn rpc_error(id: Value, code: i64, message: &str) -> HttpResponse {
    HttpResponse::Ok().json(&json!({
        "jsonrpc": "2.0",
        "id": id,
        "error": { "code": code, "message": message },
    }))
}

fn tool_error(id: Value, message: String) -> HttpResponse {
    HttpResponse::Ok().json(&json!({
        "jsonrpc": "2.0",
        "id": id,
        "result": {
            "content": [{ "type": "text", "text": message }],
            "isError": true,
        },
    }))
}
