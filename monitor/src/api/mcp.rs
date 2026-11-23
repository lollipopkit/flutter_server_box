//! `POST /api/v1/mcp` (#1681): an MCP client's way in, behind an API token.
//!
//! Streamable HTTP in its stateless JSON shape: every POST carries a whole
//! JSON-RPC message and is answered with one `application/json` body (a
//! notification by `202 Accepted`), no session is issued and none is
//! required; `GET` and `DELETE` answer `405 Method Not Allowed` per spec.
//!
//! Permissions default open — every scope enabled and `allow_all` commands —
//! and narrow by intersecting three layers: `config.toml` (`[mcp]`), the
//! UI-managed global policy (`mcp_policy`), and each token's own scopes and
//! command rules (`api_tokens`). `tools/list` shows only what that
//! intersection allows, and `tools/call` runs nothing outside it.

use std::net::SocketAddr;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};

use async_trait::async_trait;
use base64::Engine;
use ntex::http::StatusCode;
use ntex::http::header::{ACCEPT, ALLOW, CONTENT_TYPE, HeaderValue};
use ntex::web::{self, HttpRequest, HttpResponse};
use serde_json::{Value, json};

use sbm_mcp::{Answer, CallToolResult, Host, Tool, catalog, structured, tool_error};

use super::cron::{self, CronEdit};
use super::firewall;
use super::fs;
use super::json;
use super::machine::{Here, McpCommand};
use super::process;
use super::server::{self, AppState};
use super::stacks;
use super::storage;
use super::system_users::{self, UserPart};
use super::virt;
use super::ws::audit::{Action, Event, Kind, Outcome};
use super::ws::origin_allowed;
use crate::api::authz::{self, Caller, TokenCaller};
use crate::api::respond::error;
use crate::db::api_tokens::{self, CommandPolicy, Scope};

/// Large enough to carry a file written through `fs_write` (base64 or text),
/// bounded up front before a byte is read.
const MAX_BODY: usize = 4 * 1024 * 1024;

struct TokenHost {
    state: Arc<AppState>,
    caller: Caller,
    token_name: String,
    peer: Option<SocketAddr>,
    remote_ip: Option<String>,
    scopes: Vec<Scope>,
    config_commands: CommandPolicy,
    global_commands: CommandPolicy,
    token_commands: CommandPolicy,
    audited_before_run: AtomicBool,
}

#[async_trait]
impl Host for TokenHost {
    fn server_info(&self) -> (&'static str, &'static str) {
        ("serverbox-monitor", env!("CARGO_PKG_VERSION"))
    }

    fn tools(&self) -> Vec<Tool> {
        self.scopes.iter().flat_map(|scope| catalog::monitor(*scope)).collect()
    }

    async fn call(&self, name: &str, arguments: Value) -> CallToolResult {
        let state = &self.state;
        match name {
            "machine_status" => {
                server::metrics::touch_viewer_heartbeat(state).await;
                let metrics = state.current_metrics.read().await;
                match metrics.as_ref() {
                    Some(m) => structured(serde_json::to_value(server::metrics::status_view(m)).unwrap_or(Value::Null)),
                    None => tool_error("metrics are not available yet"),
                }
            }
            "machine_metrics" => {
                server::metrics::touch_viewer_heartbeat(state).await;
                let metrics = state.current_metrics.read().await;
                match metrics.as_ref() {
                    Some(m) => structured(server::metrics::metrics_json(m).unwrap_or(Value::Null)),
                    None => tool_error("metrics are not available yet"),
                }
            }
            "machine_capabilities" => {
                let secure = state.tls_active || self.peer.is_some_and(|p| p.ip().is_loopback());
                structured(server::capabilities_view(state, Some(&self.caller), secure).await)
            }
            "processes" => {
                let sort = match arguments.get("sort") {
                    None => None,
                    Some(v) => match serde_json::from_value(v.clone()) {
                        Ok(s) => Some(s),
                        Err(e) => return tool_error(format!("invalid sort: {e}")),
                    },
                };
                let ascending = match arguments.get("ascending") {
                    None => None,
                    Some(v) => match v.as_bool() {
                        Some(b) => Some(b),
                        None => return tool_error("ascending must be a boolean"),
                    },
                };
                structured(serde_json::to_value(process::table(state, sort, ascending).await).unwrap_or(Value::Null))
            }
            "cron" => structured(
                serde_json::to_value(cron::read_crontab(&state.remote_access.exec).await).unwrap_or(Value::Null),
            ),
            "firewall" => {
                let kind = match arguments.get("kind") {
                    None => None,
                    Some(v) => match serde_json::from_value(v.clone()) {
                        Ok(k) => Some(k),
                        Err(e) => return tool_error(format!("invalid firewall kind: {e}")),
                    },
                };
                structured(serde_json::to_value(firewall::read_view(state, self.peer, kind, None).await).unwrap_or(Value::Null))
            }
            "storage" => match storage::view_body(state).await {
                Ok(body) => structured(body),
                Err(code) => tool_error(format!("storage unavailable: {code}")),
            },
            "virt" => match virt::load_view(state, None).await {
                Ok(body) => structured(body),
                Err(e) => tool_error(format!("virtualization load failed: {e}")),
            },
            "stacks" => match stacks::list_apps(state).await {
                Ok(body) => structured(body),
                Err(e) => tool_error(format!("stacks unavailable: {e}")),
            },
            "system_users" => {
                let part: UserPart = match arguments.get("part") {
                    None => UserPart::default(),
                    Some(v) => match serde_json::from_value(v.clone()) {
                        Ok(p) => p,
                        Err(e) => return tool_error(format!("invalid part: {e}")),
                    },
                };
                let name = arguments.get("name").and_then(Value::as_str);
                structured(system_users::listing(state, part, name).await)
            }
            "fs_roots" => structured(fs::mcp_ops::roots(state, self.remote_ip.clone()).await),
            "fs_list" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                match fs::mcp_ops::list(state, path, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_stat" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                match fs::mcp_ops::stat(state, path, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_read" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                let offset = match arguments.get("offset") {
                    None => 0,
                    Some(v) => match v.as_u64() {
                        Some(n) => n,
                        None => return tool_error("offset must be a non-negative integer"),
                    },
                };
                let max_bytes = match arguments.get("max_bytes") {
                    None => None,
                    Some(v) => match v.as_u64().filter(|&n| (1..=4_194_304).contains(&n)) {
                        Some(n) => Some(n as usize),
                        None => return tool_error("max_bytes must be an integer in 1..=4194304"),
                    },
                };
                match fs::mcp_ops::read(state, path, offset, max_bytes, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_write" => self.fs_write(arguments).await,
            "fs_mkdir" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                match fs::mcp_ops::mkdir(state, path, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_rename" => {
                let Some(from) = arguments.get("from").and_then(Value::as_str) else {
                    return tool_error("from is required");
                };
                let Some(to) = arguments.get("to").and_then(Value::as_str) else {
                    return tool_error("to is required");
                };
                match fs::mcp_ops::rename(state, from, to, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_chmod" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                let Some(mode) = arguments
                    .get("mode")
                    .and_then(Value::as_u64)
                    .filter(|&m| m <= 0o7777)
                    .map(|m| m as u32)
                else {
                    return tool_error("mode is required (integer 0..=4095)");
                };
                match fs::mcp_ops::chmod(state, path, mode, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "fs_remove" => {
                let Some(path) = arguments.get("path").and_then(Value::as_str) else {
                    return tool_error("path is required");
                };
                let recursive = arguments.get("recursive").and_then(Value::as_bool).unwrap_or(false);
                match fs::mcp_ops::remove(state, path, recursive, self.remote_ip.clone()).await {
                    Ok(v) => structured(v),
                    Err(e) => tool_error(e),
                }
            }
            "run_command" => {
                let max_bytes = state.remote_access.exec.max_request_bytes;
                let layers = [
                    ("config.toml [mcp.commands]", &self.config_commands),
                    ("global MCP policy", &self.global_commands),
                    ("token command policy", &self.token_commands),
                ];
                sbm_mcp::machine::run_command(&self.here(), &arguments, &layers, max_bytes).await
            }
            "cron_edit" => self.cron_edit(arguments).await,
            "virt_power" => self.virt_power(arguments).await,
            "stack_action" => self.stack_action(arguments).await,
            "power" => self.power(arguments).await,
            _ => match sbm_mcp::machine::call(&self.here(), name, &arguments).await {
                Some(result) => result,
                None => tool_error(format!("unknown tool: {name}")),
            },
        }
    }
}

impl TokenHost {
    /// This machine, its changes recorded as this token's.
    fn here(&self) -> Here<'_> {
        Here {
            limits: &self.state.remote_access.exec,
            db: Some(&self.state.db),
            remote_ip: self.remote_ip.clone(),
            mcp: Some(McpCommand { token_name: &self.token_name, recorded: &self.audited_before_run }),
        }
    }

    async fn fs_write(&self, arguments: Value) -> CallToolResult {
        let Some(path) = arguments.get("path").and_then(Value::as_str) else {
            return tool_error("path is required");
        };
        let Some(content) = arguments.get("content").and_then(Value::as_str) else {
            return tool_error("content is required");
        };
        let encoding = arguments.get("encoding").and_then(Value::as_str).unwrap_or("utf8");
        let bytes = match encoding {
            "utf8" => content.as_bytes().to_vec(),
            "base64" => match base64::engine::general_purpose::STANDARD.decode(content) {
                Ok(bytes) => bytes,
                Err(e) => return tool_error(format!("invalid base64 content: {e}")),
            },
            other => return tool_error(format!("unsupported encoding `{other}` (expected utf8 or base64)")),
        };
        let if_version = match arguments.get("if_version") {
            None | Some(Value::Null) => None,
            Some(Value::String(s)) => Some(s.as_str()),
            Some(_) => return tool_error("if_version must be a string"),
        };
        match fs::mcp_ops::write(&self.state, path, &bytes, if_version, self.remote_ip.clone()).await {
            Ok(v) => structured(v),
            Err(e) => tool_error(e),
        }
    }

    async fn cron_edit(&self, arguments: Value) -> CallToolResult {
        let edit: CronEdit = match serde_json::from_value(arguments) {
            Ok(edit) => edit,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        match cron::apply_edit(&self.state, edit, self.remote_ip.clone()).await {
            Ok(response) => structured(serde_json::to_value(response).unwrap_or(Value::Null)),
            Err(e) => tool_error(format!("invalid cron edit: {e}")),
        }
    }

    async fn virt_power(&self, arguments: Value) -> CallToolResult {
        let mut request: virt::PowerRequest = match serde_json::from_value(arguments) {
            Ok(r) => r,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        request.password = None;
        match virt::power_guest(&self.state, request, self.remote_ip.clone()).await {
            Ok(resp) => match resp.error {
                None => structured(json!({ "ok": true })),
                Some(err) => tool_error(serde_json::to_string(&err).unwrap_or_else(|_| "virt power failed".into())),
            },
            Err(e) => tool_error(format!("virt power failed: {e}")),
        }
    }

    async fn stack_action(&self, arguments: Value) -> CallToolResult {
        #[derive(serde::Deserialize)]
        struct Args {
            id: String,
            action: crate::stacks::StackAction,
        }
        let args: Args = match serde_json::from_value(arguments) {
            Ok(a) => a,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        match crate::stacks::act(&self.state, &args.id, args.action).await {
            Ok(job) => structured(serde_json::to_value(job.view(0)).unwrap_or(Value::Null)),
            Err(r) => tool_error(match r.field {
                Some(field) => format!("{} ({field})", r.error),
                None => r.error.to_string(),
            }),
        }
    }

    async fn power(&self, arguments: Value) -> CallToolResult {
        let mut request: super::power::PowerRequest = match serde_json::from_value(arguments) {
            Ok(r) => r,
            Err(e) => return tool_error(format!("invalid arguments: {e}")),
        };
        request.password = None;
        let action_name = request.action.as_str();
        // Recorded before `perform` runs, since shutdown/reboot may stop the
        // process before `serve` returns.
        let written = Event::new(Kind::Mcp, Action::Open, Outcome::Ok)
            .subject(format!("api token '{}'", self.token_name))
            .remote_ip(self.remote_ip.clone())
            .detail(format!("tool power: {action_name}"))
            .record(&self.state.db)
            .await;
        if written {
            self.audited_before_run.store(true, Ordering::Relaxed);
        }

        match super::power::perform(&self.state, request, self.remote_ip.clone()).await {
            Ok(response) => structured(serde_json::to_value(response).unwrap_or(Value::Null)),
            Err(super::power::PowerRefused::Script) => {
                tool_error("the power script could not be written")
            }
            Err(super::power::PowerRefused::Failed(e)) => tool_error(e),
        }
    }
}

/// Streamable HTTP spec: `GET` (standalone SSE stream) and `DELETE` (session
/// termination) answer `405 Method Not Allowed` when the server is stateless
/// JSON-only.
pub async fn method_not_allowed() -> HttpResponse {
    HttpResponse::MethodNotAllowed()
        .header(ALLOW, HeaderValue::from_static("POST"))
        .json(&json!({ "error": sbm_mcp::http::METHOD_NOT_ALLOWED.error }))
}

pub async fn post(
    req: HttpRequest,
    payload: web::types::Payload,
    state: Arc<AppState>,
) -> HttpResponse {
    let ip_rate = state.mcp_ip_limiter.check_http_request(&req);
    if !ip_rate.allowed {
        return ip_rate.error_response();
    }

    let caller: TokenCaller = match authz::token_caller(&req, &state).await {
        Ok(caller) => caller,
        Err(refused) => return refused,
    };

    let token_rate = state.mcp_token_limiter.check_rate_limit(&caller.token.id);
    if !token_rate.allowed {
        return token_rate.error_response();
    }

    api_tokens::record_use(&state.db, caller.token.id, caller.remote_ip.as_deref())
        .await
        .ok();

    let mut response = post_authed(req, payload, state, caller).await;
    if response.status() != StatusCode::UNAUTHORIZED {
        token_rate.apply_headers(response.headers_mut());
    }
    response
}

async fn post_authed(
    req: HttpRequest,
    mut payload: web::types::Payload,
    state: Arc<AppState>,
    caller: TokenCaller,
) -> HttpResponse {
    if let Err(why) = caller.caller.check(&state, authz::is_secure(&req, &state)) {
        Event::new(Kind::Mcp, Action::Denied, Outcome::Denied)
            .subject(format!("api token '{}'", caller.token.name))
            .remote_ip(caller.remote_ip.clone())
            .detail(format!("mcp: {}", why.as_str()))
            .record(&state.db)
            .await;
        return authz::error(StatusCode::FORBIDDEN, "forbidden", why.as_str());
    }

    if !origin_allowed(&req, &state.config.get_server().cors_allowed_origins) {
        return error(StatusCode::FORBIDDEN, "forbidden");
    }

    // A header that is there and cannot be read names no version: refused
    // rather than read as absent.
    if req.headers().get("mcp-protocol-version").is_some_and(|v| v.to_str().is_err()) {
        return error(StatusCode::BAD_REQUEST, "unsupported_protocol_version");
    }
    let header = |name| req.headers().get(name).and_then(|v| v.to_str().ok());
    let accept: Vec<&str> = req.headers().get_all(ACCEPT).filter_map(|v| v.to_str().ok()).collect();
    if let Err(refused) = sbm_mcp::http::check_post(header("mcp-protocol-version"), &accept, header(CONTENT_TYPE.as_str()))
    {
        return error(StatusCode::from_u16(refused.status).unwrap_or(StatusCode::BAD_REQUEST), refused.error);
    }

    let body = match json::collect(&req, &mut payload.0, MAX_BODY).await {
        Ok(body) => body,
        Err(_) => return error(StatusCode::PAYLOAD_TOO_LARGE, "too_large"),
    };
    let message: Value = match serde_json::from_slice(&body) {
        Ok(value) => value,
        Err(_) => return error(StatusCode::BAD_REQUEST, "bad_request"),
    };

    let is_call = message.get("method").and_then(Value::as_str) == Some("tools/call");
    let tool_name = message
        .get("params")
        .and_then(|p| p.get("name"))
        .and_then(Value::as_str)
        .unwrap_or("");

    // `[remote_access.exec] max_request_bytes` bounds command payloads across
    // every entry point; only `fs_write` uses the larger 4 MiB body envelope.
    if is_call && tool_name == "run_command" && body.len() > state.remote_access.exec.max_request_bytes {
        return error(StatusCode::PAYLOAD_TOO_LARGE, "too_large");
    }

    // Re-fetch the token and account generation after reading the body (without
    // recording another use) so revocations, expirations, scope tightenings, or
    // password changes committed during upload take effect before dispatch.
    let token = match api_tokens::find_with_owner(&state.db, &caller.token_hash).await {
        Ok(Some((token, _, owner_since))) if owner_since == caller.caller.since => token,
        Ok(_) => return authz::unauthorized(),
        Err(e) => {
            tracing::warn!("Could not re-verify API token: {e}");
            return authz::unauthorized();
        }
    };

    let global_policy = match api_tokens::load_policy(&state.db).await {
        Ok(policy) => policy,
        Err(e) => {
            tracing::warn!("Could not load MCP policy: {e}");
            return error(StatusCode::INTERNAL_SERVER_ERROR, "internal_error");
        }
    };
    let config_mcp = state.config.get_mcp();
    let effective_scopes: Vec<Scope> = Scope::MONITOR
        .iter()
        .copied()
        .filter(|&s| {
            config_mcp.allows_scope(s)
                && global_policy.scopes.contains(&s)
                && token.scopes.contains(&s)
        })
        .collect();

    let host = TokenHost {
        state: state.clone(),
        caller: caller.caller.clone(),
        token_name: token.name.clone(),
        peer: req.peer_addr(),
        remote_ip: caller.remote_ip.clone(),
        scopes: effective_scopes,
        config_commands: config_mcp.commands,
        global_commands: global_policy.commands,
        token_commands: token.commands.clone(),
        audited_before_run: AtomicBool::new(false),
    };

    let answer = sbm_mcp::serve(&host, &message).await;

    match answer {
        Answer::Json(value) => {
            if is_call && !host.audited_before_run.load(Ordering::Relaxed) {
                let failed = value.get("error").is_some()
                    || value.pointer("/result/isError").and_then(Value::as_bool) == Some(true);
                let detail = if tool_name == "run_command"
                    && let Some(cmd) = message.pointer("/params/arguments/command").and_then(Value::as_str)
                    && !cmd.trim().is_empty()
                {
                    format!("tool run_command: {}", super::exec::command_summary(cmd))
                } else {
                    format!("tool {tool_name}")
                };
                Event::new(
                    Kind::Mcp,
                    Action::Open,
                    if failed { Outcome::Error } else { Outcome::Ok },
                )
                .subject(format!("api token '{}'", caller.token.name))
                .remote_ip(caller.remote_ip.clone())
                .detail(detail)
                .record(&state.db)
                .await;
            }
            HttpResponse::Ok()
                .content_type(HeaderValue::from_static("application/json"))
                .json(&value)
        }
        Answer::Accepted => HttpResponse::builder(StatusCode::ACCEPTED).build(),
    }
}
