//! `POST /api/v1/mcp` (#1681): an MCP client's way in, behind an API token.
//!
//! Streamable HTTP in its stateless JSON shape: every POST carries a whole
//! JSON-RPC message and is answered with one `application/json` body (a
//! notification by `202 Accepted`), no session is issued and none is
//! required. [`sbm_mcp`] owns the dispatch; this file owns the transport —
//! the credential, the headers, the limit — and the tools.
//!
//! Every tool answers the same bytes its HTTP route does, because it calls
//! the same function: `/status`, `/metrics`, `/capabilities`, `/process`,
//! `/services`, `/containers`, `/cron`, `/tmux` and `/firewall` each keep one
//! body builder, and a second one here would be a second thing to drift.
//!
//! What a token's scopes allow is what `tools/list` shows and `tools/call`
//! runs: a client cannot even learn the name of a tool it may not use. PR1
//! serves the reading tools only, under `read`; the ones that act on the
//! machine come with the scopes that name them (#1681 PR2), each then asking
//! the transport rule its route asks.

use std::net::SocketAddr;
use std::sync::Arc;

use ntex::http::header::{ACCEPT, CONTENT_TYPE, HeaderValue};
use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde_json::Value;

use async_trait::async_trait;
use sbm_mcp::{Answer, CallToolResult, Host, Tool, structured, tool_error};

use super::containers::{self, ContainerPart};
use super::cron;
use super::firewall;
use super::json;
use super::process;
use super::service::{self, ServicePart};
use super::server::{self, AppState};
use super::tmux;
use super::ws::audit::{Action, Event, Kind, Outcome};
use super::ws::origin_allowed;
use crate::api::authz::{self, Caller, TokenCaller};
use crate::api::respond::error;
use crate::db::api_tokens::Scope;

/// A request body this large is no client of ours: tools take small
/// arguments, and the limit keeps a client from parking a body here.
const MAX_BODY: usize = 256 * 1024;

/// The reading tools, one host for every token with [`Scope::Read`].
struct ReadHost {
    state: Arc<AppState>,
    caller: Caller,
    peer: Option<SocketAddr>,
}

impl ReadHost {
    /// The tools, in the order a client lists them. No arguments: each reads
    /// the whole machine, as the panel's page for it does.
    fn all_tools() -> Vec<Tool> {
        fn tool(name: &'static str, description: &'static str) -> Tool {
            sbm_mcp::tool(
                name,
                description,
                serde_json::json!({ "type": "object", "properties": {}, "additionalProperties": false }),
            )
        }
        vec![
            tool(
                "machine_status",
                "This machine's current readings, as the panel's status line: CPU, memory, disk, network and temperature, each as the one line it is shown on.",
            ),
            tool(
                "machine_metrics",
                "This machine's current metrics in full, as the panel's charts read them: per-core CPU, memory, disks, network interfaces and disk I/O.",
            ),
            tool(
                "machine_capabilities",
                "What this Monitor is and may be asked: platform, version, the data it collects, how long it keeps it, and which pages it offers.",
            ),
            tool(
                "processes",
                "The machine's process table: PID, parent, user, state, CPU and memory use, and command line, in CPU order.",
            ),
            tool(
                "services",
                "The service units of the machine's service manager, with their state and whether they are enabled at boot.",
            ),
            tool(
                "containers",
                "The containers the machine's runtime (Docker or Podman) has, with a stats sample for each running one.",
            ),
            tool("cron", "The crontab of the account the Monitor runs as."),
            tool("tmux", "The machine's tmux sessions."),
            tool(
                "firewall",
                "The machine's firewall as the panel draws it: the rules in force, and how this Monitor and SSH reach it. A firewall whose read needs root comes back saying so.",
            ),
        ]
    }
}

#[async_trait]
impl Host for ReadHost {
    fn server_info(&self) -> (&'static str, &'static str) {
        ("serverbox-monitor", env!("CARGO_PKG_VERSION"))
    }

    fn tools(&self) -> Vec<Tool> {
        Self::all_tools()
    }

    async fn call(&self, name: &str, _arguments: Value) -> CallToolResult {
        let state = &self.state;
        match name {
            // A reader is someone looking: the extended cycle (sensors, SMART,
            // batteries) would otherwise pause while only this client polls,
            // and hand back what was sampled at start.
            "machine_status" => {
                server::metrics::touch_viewer_heartbeat(state).await;
                let metrics = state.current_metrics.read().await;
                match metrics.as_ref() {
                    Some(metrics) => structured(
                        serde_json::to_value(server::metrics::status_view(metrics))
                            .unwrap_or(Value::Null),
                    ),
                    None => tool_error("metrics are not available yet"),
                }
            }
            "machine_metrics" => {
                server::metrics::touch_viewer_heartbeat(state).await;
                let metrics = state.current_metrics.read().await;
                match metrics.as_ref() {
                    Some(metrics) => structured(
                        server::metrics::metrics_json(metrics).unwrap_or(Value::Null),
                    ),
                    None => tool_error("metrics are not available yet"),
                }
            }
            "machine_capabilities" => {
                let secure = state.tls_active || self.peer.is_some_and(|p| p.ip().is_loopback());
                structured(server::capabilities_view(state, Some(&self.caller), secure).await)
            }
            "processes" => structured(
                serde_json::to_value(process::table(state, None, None).await).unwrap_or(Value::Null),
            ),
            "services" => structured(
                serde_json::to_value(service::listing(state, ServicePart::List, None).await)
                    .unwrap_or(Value::Null),
            ),
            "containers" => structured(
                serde_json::to_value(containers::listing(state, ContainerPart::Containers, None).await)
                    .unwrap_or(Value::Null),
            ),
            "cron" => structured(
                serde_json::to_value(cron::read_crontab(&state.remote_access.exec).await)
                    .unwrap_or(Value::Null),
            ),
            "tmux" => structured(tmux::sessions(state).await),
            "firewall" => structured(
                serde_json::to_value(firewall::read_view(state, self.peer, None, None).await)
                    .unwrap_or(Value::Null),
            ),
            _ => tool_error(format!("unknown tool: {name}")),
        }
    }
}

/// One request's tools: the host every token with `read` sees. The tools that
/// act on the machine (#1681 PR2) take their own hosts and scopes.
fn host_for(
    scopes: &[Scope],
    caller: &Caller,
    state: Arc<AppState>,
    peer: Option<SocketAddr>,
) -> Option<Box<dyn Host>> {
    if scopes.contains(&Scope::Read) {
        let host: Box<dyn Host> = Box::new(ReadHost {
            state,
            caller: caller.clone(),
            peer,
        });
        Some(host)
    } else {
        None
    }
}

pub async fn post(
    req: HttpRequest,
    mut payload: web::types::Payload,
    state: Arc<AppState>,
) -> HttpResponse {
    let caller: TokenCaller = match authz::token_caller(&req, &state).await {
        Ok(caller) => caller,
        Err(refused) => return refused,
    };
    // The same rule every route that acts takes, refused and recorded here
    // rather than in `authz`, so the audit names the credential that tried.
    if let Err(why) = caller.caller.check(&state, authz::is_secure(&req, &state)) {
        Event::new(Kind::Mcp, Action::Denied, Outcome::Denied)
            .subject(format!("api token '{}'", caller.token.name))
            .remote_ip(caller.remote_ip.clone())
            .detail(format!("mcp: {}", why.as_str()))
            .record(&state.db)
            .await;
        return authz::error(StatusCode::FORBIDDEN, "forbidden", why.as_str());
    }

    // A browser is the one sender an Origin names, and a cross-origin page
    // must not drive a token its user pasted somewhere: an Origin this agent
    // was not told to allow is refused, whether or not the token is real.
    // Everything else — every real MCP client — sends no Origin at all. Asked
    // as the WebSocket routes ask it, so a panel this agent serves counts.
    if !origin_allowed(&req, &state.config.get_server().cors_allowed_origins) {
        return error(StatusCode::FORBIDDEN, "forbidden");
    }

    // Streamable HTTP's contract on what comes in, minus the half this
    // server never speaks: a client must accept `application/json` (an SSE
    // answer never comes, so `text/event-stream` is not asked of it) and
    // must send the one content type there is.
    let accepts_json = req
        .headers()
        .get(ACCEPT)
        .and_then(|v| v.to_str().ok())
        .is_some_and(|a| a.contains("application/json"));
    if !accepts_json {
        return error(StatusCode::NOT_ACCEPTABLE, "not_acceptable");
    }
    let content_type_json = req
        .headers()
        .get(CONTENT_TYPE)
        .and_then(|v| v.to_str().ok())
        .is_some_and(|c| c.split(';').next().unwrap_or("").trim() == "application/json");
    if !content_type_json {
        return error(StatusCode::UNSUPPORTED_MEDIA_TYPE, "unsupported_media_type");
    }

    // Refused by its declared length before a byte is read, and as it
    // arrives otherwise: ntex's default limit for the app is larger.
    let body = match json::collect(&req, &mut payload.0, MAX_BODY).await {
        Ok(body) => body,
        Err(_) => return error(StatusCode::PAYLOAD_TOO_LARGE, "too_large"),
    };
    let message: Value = match serde_json::from_slice(&body) {
        Ok(value) => value,
        Err(_) => return error(StatusCode::BAD_REQUEST, "bad_request"),
    };

    // The token's own use is recorded by `token_caller`; what the audit adds
    // is what it did — a tool, by name, never its arguments.
    // The transport rule was asked above; what one tool needs on top is
    // where the request came from, to report how this machine is reached.
    let answer = match host_for(&caller.token.scopes, &caller.caller, state.clone(), req.peer_addr()) {
        Some(host) => sbm_mcp::serve(host.as_ref(), &message).await,
        // Nothing to serve it: a request is told so, a notification is
        // acknowledged as any other.
        None => match message.get("id") {
            None => Answer::Accepted,
            Some(id) => Answer::Json(serde_json::json!({
                "jsonrpc": "2.0",
                "id": id,
                "error": { "code": -32602, "message": "this token has no scopes the server serves" }
            })),
        },
    };

    let is_call = message.get("method").and_then(Value::as_str) == Some("tools/call");
    let tool = message
        .get("params")
        .and_then(|p| p.get("name"))
        .and_then(Value::as_str)
        .unwrap_or("");

    match answer {
        Answer::Json(value) => {
            if is_call {
                // Refused by the protocol (an unknown tool) is as failed as a
                // tool that answered with an error.
                let failed = value.get("error").is_some()
                    || value.pointer("/result/isError").and_then(Value::as_bool) == Some(true);
                Event::new(
                    Kind::Mcp,
                    Action::Open,
                    if failed { Outcome::Error } else { Outcome::Ok },
                )
                .subject(format!("api token '{}'", caller.token.name))
                .remote_ip(caller.remote_ip.clone())
                .detail(format!("tool {tool}"))
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
