//! `/api/v1/agent/*` — Agent mode (`agent_mode`): tasks an AI agent runs on
//! this machine.
//!
//! - `GET /agent/flows`, `POST /agent/flows {prompt}`: the account's tasks,
//!   newest first; a new one.
//! - `GET /agent/flows/{id}`: one whole — its row, the entries of its pi
//!   session's current branch, what it waits on, the running command's
//!   output so far. `DELETE` removes a task that is not active.
//! - `POST /agent/flows/{id}/reply {text}`, `/answer {…}`, `/stop`.
//! - `GET /agent/events`: a `text/event-stream` of the account's tasks as
//!   they change (`flow`, `removed`, `pending`, `output`, and pi's own
//!   session events as `event`), read with `fetch` and the bearer header.
//!   `{type: resync}` when events were dropped: refetch.
//! - `GET /agent/settings`: everything but credentials, `PUT`, `GET
//!   /agent/models`: the providers and their models, as pi lists them.
//! - `POST /agent/search {query, kind?}`: the desk's search, answered by
//!   the agent reading only: a `text/event-stream` (`kind`, `step`, `items`,
//!   `plan`, `delta`, `said`, `done` with the search's id, `error`) that ends
//!   with the search; closing it stops it. `POST /agent/search/{id}/task
//!   {text?}` carries it into a task, and runs it on with [text].
//! - `GET /agent/permissions`: how commands are approved, and the built-in
//!   auto mode lists; `PUT` replaces it.
//! - `GET /agent/mcp`: the MCP servers, their headers named, and how each is
//!   doing (connected now, with its tools); `PUT` replaces them, `{servers:
//!   [{name, url, enabled, headers}]}`.
//! - `GET /agent/skills`: the skills; `POST /agent/skills {source}`
//!   installs from a GitHub repository as `npx skills add` takes it;
//!   `PUT /agent/skills/{dir} {enabled}`, `DELETE /agent/skills/{dir}`.
//! - `GET /agent/memory`: the account's memory, its files without their
//!   content; `GET /agent/memory/file?path=` one with it, `PUT
//!   /agent/memory/file {path, content}` writes one, `DELETE
//!   /agent/memory/file?path=` removes a file or a directory.
//!
//! # Privilege
//!
//! The transport rule, checked here per request and by the tools before every
//! command (`agent_mode`).

use std::sync::Arc;

use futures::StreamExt as _;
use ntex::http::StatusCode;
use ntex::util::Bytes;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use tokio::sync::broadcast;

use super::authz::{self, Caller};
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::agent_mode::files::FileError;
use crate::agent_mode::{Answer, FlowError, MAX_PROMPT, NewTask, SearchKind, config, first_line, permissions};
use fl_pi_llm::host::memory::{self, MemoryError};

const HEARTBEAT: std::time::Duration = std::time::Duration::from_secs(25);
/// A JSON body here: a prompt with a pasted log in it.
pub const MAX_REQUEST: usize = MAX_PROMPT + (64 << 10);
/// A memory file's body: its longest content, every character escaped.
pub const MAX_MEMORY_REQUEST: usize = memory::MAX_FILE_CHARS * 12 + (4 << 10);

/// The account, its id and whether the link is secure, when the transport
/// rule lets it act.
async fn shell(req: &HttpRequest, state: &AppState) -> Result<(Caller, i64, bool), HttpResponse> {
    let caller = super::machine::gate_as(Kind::Agent, req, state, "agent").await?.caller;
    let user = caller.id;
    Ok((caller, user, authz::is_secure(req, state)))
}

fn refused(e: FlowError) -> HttpResponse {
    let status = match &e {
        FlowError::NotConfigured | FlowError::NotActive | FlowError::NotWaiting | FlowError::Stale | FlowError::Busy => StatusCode::CONFLICT,
        FlowError::NotFound => StatusCode::NOT_FOUND,
        FlowError::Invalid(_) => StatusCode::BAD_REQUEST,
        FlowError::Upstream(reason) => {
            return HttpResponse::BadGateway().json(&serde_json::json!({ "error": "upstream", "reason": reason }));
        }
        FlowError::Db(_) | FlowError::Pi(_) | FlowError::Other(_) => {
            tracing::error!("agent mode: {e}");
            StatusCode::INTERNAL_SERVER_ERROR
        }
    };
    HttpResponse::build(status).json(&serde_json::json!({ "error": e.code() }))
}

fn valid_text(text: &str) -> bool {
    !text.trim().is_empty() && text.len() <= MAX_PROMPT
}

fn bad(code: &str) -> HttpResponse {
    HttpResponse::BadRequest().json(&serde_json::json!({ "error": code }))
}

pub async fn list(
    req: HttpRequest,
    query: web::types::Query<crate::agent_mode::ListQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    let settings = match config::load(&state.db).await {
        Ok(s) => s,
        Err(e) => return Ok(refused(e.into())),
    };
    let perms = match crate::agent_mode::permissions::load(&state.db).await {
        Ok(p) => p,
        Err(e) => return Ok(refused(e.into())),
    };
    match state.agent.list(user, &query).await {
        Ok((flows, next)) => Ok(HttpResponse::Ok().json(&serde_json::json!({
            "flows": flows,
            // The cursor of the next page, when one was asked for and is there.
            "next": next,
            "configured": settings.model.is_some(),
            "maxRunning": settings.max_running,
            "hostname": state.agent.hostname(),
            "defaultMode": perms.default_mode,
            "bypassAllowed": !perms.disable_bypass,
        }))),
        Err(e) => Ok(refused(e.into())),
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Start {
    prompt: String,
    /// The permission mode; absent is the machine's default.
    #[serde(default)]
    mode: Option<crate::agent_mode::permissions::Mode>,
    /// Uploads (`POST /agent/files`) the task is given.
    #[serde(default)]
    files: Vec<String>,
    /// The model and thinking level; absent is the machine's.
    #[serde(default)]
    model: Option<crate::agent_mode::config::ModelRef>,
    #[serde(default, rename = "thinkingLevel")]
    thinking_level: Option<String>,
}

pub async fn start(req: HttpRequest, body: web::types::Json<Start>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, secure) = require!(shell(&req, &state).await);
    let Start { prompt, mode, files, model, thinking_level } = body.into_inner();
    let choice = crate::agent_mode::TaskChoice { model, thinking_level };
    // Files alone are a prompt too.
    if prompt.len() > MAX_PROMPT || (prompt.trim().is_empty() && files.is_empty()) {
        return Ok(bad("invalidPrompt"));
    }
    if files.len() > crate::agent_mode::files::MAX_PER_TASK {
        return Ok(bad("tooManyFiles"));
    }
    let state = state.get_ref().clone();
    match state.agent.start(&state, user, secure, NewTask { prompt, mode, files, choice }).await {
        Ok(view) => {
            Event::new(Kind::Agent, Action::Open, Outcome::Ok)
                .remote_ip(peer_ip(&req))
                .detail(format!("task {}", view.id))
                .record(&state.db)
                .await;
            Ok(HttpResponse::Created().json(&view))
        }
        Err(e) => Ok(refused(e)),
    }
}

#[derive(Deserialize)]
pub struct Upload {
    name: String,
}

/// A file for a task the account is about to start: the body is its bytes,
/// `Content-Type` its type, `?name=` its name.
pub async fn upload(
    req: HttpRequest,
    query: web::types::Query<Upload>,
    body: ntex::util::Bytes,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    let mime = req.headers().get("content-type").and_then(|v| v.to_str().ok()).unwrap_or("");
    match state.agent.files.put(user, &query.name, mime, &body).await {
        Ok(view) => Ok(HttpResponse::Created().json(&view)),
        Err(FileError::TooMany) => Ok(HttpResponse::Conflict().json(&serde_json::json!({ "error": "tooManyFiles" }))),
        Err(e) => {
            tracing::error!("agent mode: keeping an upload: {e:?}");
            Ok(HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "internal" })))
        }
    }
}

pub async fn discard(req: HttpRequest, id: web::types::Path<String>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    if state.agent.files.discard(user, &id).await {
        Ok(HttpResponse::NoContent().finish())
    } else {
        Ok(refused(FlowError::NotFound))
    }
}

pub async fn detail(req: HttpRequest, id: web::types::Path<String>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    let state = state.get_ref().clone();
    match state.agent.detail(&state, user, &id).await {
        Ok(Some(v)) => Ok(HttpResponse::Ok().json(&v)),
        Ok(None) => Ok(refused(FlowError::NotFound)),
        Err(e) => Ok(refused(e)),
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Reply {
    text: String,
    /// Uploads (`POST /agent/files`) given with it.
    #[serde(default)]
    files: Vec<String>,
    /// A model and thinking level from now on; absent keeps the task's.
    #[serde(default)]
    model: Option<crate::agent_mode::config::ModelRef>,
    #[serde(default, rename = "thinkingLevel")]
    thinking_level: Option<String>,
}

pub async fn reply(req: HttpRequest, id: web::types::Path<String>, body: web::types::Json<Reply>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, secure) = require!(shell(&req, &state).await);
    let Reply { text, files, model, thinking_level } = body.into_inner();
    let choice = crate::agent_mode::TaskChoice { model, thinking_level };
    if text.len() > MAX_PROMPT || (text.trim().is_empty() && files.is_empty()) {
        return Ok(bad("invalidPrompt"));
    }
    if files.len() > crate::agent_mode::files::MAX_PER_TASK {
        return Ok(bad("tooManyFiles"));
    }
    let state = state.get_ref().clone();
    match state.agent.reply(&state, user, secure, &id, text, files, choice).await {
        Ok(view) => Ok(HttpResponse::Ok().json(&view)),
        Err(e) => Ok(refused(e)),
    }
}

pub async fn answer(req: HttpRequest, id: web::types::Path<String>, body: web::types::Json<Answer>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, secure) = require!(shell(&req, &state).await);
    let mut answer = body.into_inner();
    let action = answer.action.clone();
    // "Always allow": the rule goes to the machine's rules first; the command
    // then runs as with "run".
    if action == "always" {
        let Some(rule) = state.agent.pending_rule(user, &id, &answer.id) else {
            return Ok(refused(FlowError::Stale));
        };
        let mut perms = match permissions::load(&state.db).await {
            Ok(p) => p,
            Err(e) => return Ok(refused(e.into())),
        };
        if !perms.rules.allow.contains(&rule) {
            perms.rules.allow.push(rule.clone());
            if let Err(reason) = perms.check() {
                return Ok(HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalidPermissions", "reason": reason })));
            }
            if let Err(e) = permissions::store(&state.db, &perms).await {
                return Ok(refused(e.into()));
            }
            Event::new(Kind::Agent, Action::Write, Outcome::Ok)
                .remote_ip(peer_ip(&req))
                .detail(format!("permissions: allow `{}` from task {}", first_line(&rule, 200), id.as_str()))
                .record(&state.db)
                .await;
        }
        answer.action = "always".into();
    }
    match state.agent.answer(user, secure, &id, answer) {
        Ok(()) => {
            // The verb only: never a password, never what was typed.
            Event::new(Kind::Agent, Action::Write, Outcome::Ok)
                .remote_ip(peer_ip(&req))
                .detail(format!("task {} answer {}", id.as_str(), if action.len() <= 16 { action.as_str() } else { "?" }))
                .record(&state.db)
                .await;
            Ok(HttpResponse::NoContent().finish())
        }
        Err(e) => Ok(refused(e)),
    }
}

pub async fn stop(req: HttpRequest, id: web::types::Path<String>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    let state = state.get_ref().clone();
    match state.agent.stop(&state, user, &id).await {
        Ok(()) => Ok(HttpResponse::NoContent().finish()),
        Err(e) => Ok(refused(e)),
    }
}

pub async fn remove(req: HttpRequest, id: web::types::Path<String>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    match state.agent.remove(user, &id).await {
        Ok(()) => Ok(HttpResponse::NoContent().finish()),
        Err(e) => Ok(refused(e)),
    }
}

/// `text/event-stream`, one `data:` line of JSON per event. Ends when the
/// account's password changes, it is gone, or the link may no longer act.
pub async fn events(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (caller, user, secure) = require!(shell(&req, &state).await);
    let mut rx = state.agent.subscribe();
    let mut changes = state.password_changed.subscribe();
    let state = state.get_ref().clone();
    let stream = async_stream::stream! {
        yield Ok::<_, std::io::Error>(Bytes::from_static(b": ok\n\n"));
        let mut beat = tokio::time::interval(HEARTBEAT);
        beat.tick().await;
        loop {
            tokio::select! {
                event = rx.recv() => {
                    let json = match event {
                        Ok(e) if e.user == user => e.payload,
                        Ok(_) => continue,
                        Err(broadcast::error::RecvError::Lagged(_)) => serde_json::json!({ "type": "resync" }),
                        Err(broadcast::error::RecvError::Closed) => break,
                    };
                    yield Ok(Bytes::from(format!("data: {json}\n\n")));
                }
                changed = changes.recv() => {
                    if matches!(changed, Err(broadcast::error::RecvError::Closed)) {
                        break;
                    }
                    let still = authz::caller(&state).await
                        .filter(|now| now.since == caller.since)
                        .is_some_and(|now| now.check(&state, secure).is_ok());
                    if !still {
                        break;
                    }
                }
                _ = beat.tick() => {
                    yield Ok(Bytes::from_static(b": ping\n\n"));
                }
            }
        }
    };
    Ok(HttpResponse::Ok()
        .content_type("text/event-stream")
        .header("cache-control", "no-cache")
        .header("x-accel-buffering", "no")
        .streaming(Box::pin(stream.boxed())))
}

pub async fn get_settings(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(shell(&req, &state).await);
    match config::load(&state.db).await {
        Ok(settings) => {
            let mut v = serde_json::to_value(&settings).unwrap_or_default();
            // The model servers on this machine, offered on their own
            // (`inference::providers`): shown, not edited.
            v["appProviders"] = serde_json::to_value(state.agent.app_providers()).unwrap_or_default();
            Ok(HttpResponse::Ok().json(&v))
        }
        Err(e) => Ok(refused(e.into())),
    }
}

/// What a task may be started or replied to with (`AgentMode::choices`):
/// whenever one may be run.
pub async fn choices(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(shell(&req, &state).await);
    match state.agent.choices().await {
        Ok(v) => Ok(HttpResponse::Ok().json(&v)),
        Err(e) => Ok(refused(e)),
    }
}

async fn mcp_answer(state: &AppState) -> HttpResponse {
    match crate::agent_mode::mcp::load(&state.db).await {
        Ok(servers) => {
            let status = state.agent.mcp.refresh(state).await;
            let apps = crate::agent_mode::mcp::app_servers(state).await;
            let signed_in = crate::agent_mode::mcp_oauth::signed_in(&state.db).await;
            HttpResponse::Ok().json(&serde_json::json!({ "servers": servers, "apps": apps, "status": status, "signedIn": signed_in }))
        }
        Err(e) => refused(e.into()),
    }
}

pub async fn get_mcp(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    Ok(mcp_answer(&state).await)
}

pub async fn put_mcp(
    req: HttpRequest,
    body: web::types::Json<crate::agent_mode::mcp::ServersWrite>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let w = body.into_inner();
    if let Err(why) = w.check() {
        return Ok(HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalid", "reason": why })));
    }
    if let Err(e) = crate::agent_mode::mcp::store(&state.db, &w).await {
        return Ok(refused(e.into()));
    }
    // Where they are, never a header's value.
    Event::new(Kind::Agent, Action::Write, Outcome::Ok)
        .remote_ip(peer_ip(&req))
        .detail(format!("mcp: {}", w.servers.iter().map(|s| s.url.as_str()).collect::<Vec<_>>().join(", ")))
        .record(&state.db)
        .await;
    Ok(mcp_answer(&state).await)
}

/// What changes about a deployed app's MCP server: on or off, and the token
/// it asks for (`null` removes it, absent keeps it).
#[derive(Debug, serde::Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct AppServerWrite {
    #[serde(default)]
    pub enabled: Option<bool>,
    #[serde(default, deserialize_with = "present")]
    pub token: Option<Option<String>>,
}

/// A field that is there, `null` included: `Some(None)` for `null`, and
/// `None` (by `default`) when absent.
fn present<'de, D: serde::Deserializer<'de>>(d: D) -> Result<Option<Option<String>>, D::Error> {
    <Option<String> as serde::Deserialize>::deserialize(d).map(Some)
}

pub async fn put_mcp_app(
    req: HttpRequest,
    path: web::types::Path<(String, usize)>,
    body: web::types::Json<AppServerWrite>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let (stack, index) = path.into_inner();
    let w = body.into_inner();
    let known = crate::stacks::mcp::servers(&state).await.into_iter().find(|s| s.stack == stack && s.index == index);
    let Some(server) = known else {
        return Ok(HttpResponse::NotFound().json(&serde_json::json!({ "error": "notFound" })));
    };
    if let Some(Some(token)) = &w.token
        && (!matches!(server.credential, crate::stacks::mcp::Credential::Asked { .. }) || !crate::agent_mode::mcp::header_value_ok(token.trim()))
    {
        return Ok(HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalid", "reason": "token" })));
    }
    let token = w.token.as_ref().map(|t| t.as_deref().map(str::trim));
    if let Err(e) = crate::stacks::store::set_mcp_use(&state.db, &stack, index, w.enabled, token).await {
        return Ok(refused(e.into()));
    }
    // Which server and what changed, never the token.
    let mut what = Vec::new();
    if let Some(on) = w.enabled {
        what.push(if on { "on" } else { "off" });
    }
    match &w.token {
        Some(Some(_)) => what.push("token set"),
        Some(None) => what.push("token removed"),
        None => {}
    }
    Event::new(Kind::Agent, Action::Write, Outcome::Ok)
        .remote_ip(peer_ip(&req))
        .detail(format!("mcp: {stack} #{index} {}", what.join(", ")))
        .record(&state.db)
        .await;
    Ok(mcp_answer(&state).await)
}

/// Which server to sign in to, and the agent's address as the browser
/// reaches it (where the sign-in comes back).
#[derive(Debug, serde::Deserialize)]
#[serde(deny_unknown_fields)]
pub struct OAuthStart {
    pub url: String,
    pub origin: String,
}

/// The id of [url] when it is a server Agent mode knows: one an admin added
/// or a deployed app's.
async fn known_server(state: &AppState, url: &str) -> Option<String> {
    let id = fl_pi_llm::host::mcp::server_id(url);
    let added = crate::agent_mode::mcp::load(&state.db).await.unwrap_or_default().into_iter().any(|s| s.url == url);
    let app = crate::agent_mode::mcp::app_servers(state).await.into_iter().any(|s| s.app.url == url);
    (added || app).then_some(id)
}

/// An origin the browser comes back to: `http(s)://host[:port]`, nothing else.
fn origin_ok(origin: &str) -> bool {
    url::Url::parse(origin).is_ok_and(|u| {
        matches!(u.scheme(), "http" | "https") && u.host().is_some() && u.path() == "/" && u.query().is_none() && u.fragment().is_none()
    }) && !origin.ends_with('/')
}

/// Starts signing in to an MCP server with OAuth: where to send the browser.
pub async fn mcp_oauth_start(
    req: HttpRequest,
    body: web::types::Json<OAuthStart>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let OAuthStart { url, origin } = body.into_inner();
    if !origin_ok(&origin) {
        return Ok(HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalid", "reason": "origin" })));
    }
    let Some(id) = known_server(&state, &url).await else {
        return Ok(HttpResponse::NotFound().json(&serde_json::json!({ "error": "notFound" })));
    };
    let fetch = state.agent.fetch();
    let started = state.agent.mcp_oauth.start(fetch.as_ref(), &id, &url, &origin).await;
    let outcome = if started.is_ok() { Outcome::Ok } else { Outcome::Error };
    Event::new(Kind::Agent, Action::Write, outcome).remote_ip(peer_ip(&req)).detail(format!("mcp sign-in started: {url}")).record(&state.db).await;
    match started {
        Ok(to) => Ok(HttpResponse::Ok().json(&serde_json::json!({ "authorizeUrl": to }))),
        Err(reason) => Ok(HttpResponse::BadGateway().json(&serde_json::json!({ "error": "oauth", "reason": reason }))),
    }
}

#[derive(Debug, serde::Deserialize)]
pub struct OAuthCallback {
    pub state: String,
    #[serde(default)]
    pub code: Option<String>,
    #[serde(default)]
    pub error: Option<String>,
}

/// Where the browser comes back from signing in. No session: the one-time
/// `state` the sign-in was started with is what lets it in.
pub async fn mcp_oauth_callback(
    req: HttpRequest,
    query: web::types::Query<OAuthCallback>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let q = query.into_inner();
    let page = |ok: bool, text: &str| {
        let title = if ok { "Signed in" } else { "Not signed in" };
        let body = format!(
            "<!doctype html><meta charset=utf-8><title>{title}</title><body style=\"font:15px system-ui;margin:3em\"><h1 style=\"font-size:20px\">{title}</h1><p>{}</p>",
            html_escape(text)
        );
        HttpResponse::build(if ok { ntex::http::StatusCode::OK } else { ntex::http::StatusCode::BAD_REQUEST })
            .content_type("text/html; charset=utf-8")
            .header("cache-control", "no-store")
            .header("content-security-policy", "default-src 'none'; style-src 'unsafe-inline'")
            .body(body)
    };
    let Some(code) = q.code.filter(|_| q.error.is_none()) else {
        state.agent.mcp_oauth.abandon(&q.state);
        return Ok(page(false, "The sign-in was declined. You can close this tab."));
    };
    let fetch = state.agent.fetch();
    match state.agent.mcp_oauth.finish(&state.db, fetch.as_ref(), &q.state, &code).await {
        Ok(signed) => {
            state.agent.mcp.forget(&signed.server_id).await;
            Event::new(Kind::Agent, Action::Write, Outcome::Ok)
                .remote_ip(peer_ip(&req))
                .detail(format!("mcp signed in: {}", signed.url))
                .record(&state.db)
                .await;
            Ok(page(true, "Agent mode can use this server now. You can close this tab."))
        }
        Err(e) => {
            Event::new(Kind::Agent, Action::Write, Outcome::Denied).remote_ip(peer_ip(&req)).detail("mcp sign-in refused").record(&state.db).await;
            tracing::warn!("MCP sign-in: {e}");
            Ok(page(false, &e))
        }
    }
}

fn html_escape(s: &str) -> String {
    s.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('"', "&quot;")
}

#[derive(Debug, serde::Deserialize)]
pub struct OAuthForget {
    pub url: String,
}

/// Forgets the sign-in to an MCP server.
pub async fn mcp_oauth_forget(
    req: HttpRequest,
    query: web::types::Query<OAuthForget>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let id = fl_pi_llm::host::mcp::server_id(&query.url);
    if let Err(e) = crate::agent_mode::mcp_oauth::forget(&state.db, &id).await {
        return Ok(refused(e.into()));
    }
    state.agent.mcp.forget(&id).await;
    Event::new(Kind::Agent, Action::Write, Outcome::Ok).remote_ip(peer_ip(&req)).detail(format!("mcp signed out: {}", query.url)).record(&state.db).await;
    Ok(mcp_answer(&state).await)
}

async fn skills_answer(state: &AppState) -> HttpResponse {
    match crate::agent_mode::skills::list(&state.db, &state.agent.skills_root).await {
        Ok(skills) => HttpResponse::Ok().json(&serde_json::json!({ "skills": skills })),
        Err(e) => refused(e.into()),
    }
}

pub async fn get_skills(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    Ok(skills_answer(&state).await)
}

#[derive(Deserialize)]
pub struct InstallSkill {
    source: String,
}

pub async fn install_skill(
    req: HttpRequest,
    body: web::types::Json<InstallSkill>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    use crate::agent_mode::skills::InstallError;
    require!(authz::acting_caller(&req, &state).await);
    let source = body.into_inner().source;
    if source.len() > 1024 {
        return Ok(bad("invalidSource"));
    }
    let fetch = state.agent.fetch();
    match crate::agent_mode::skills::install(&state.db, &state.agent.skills_root, fetch.as_ref(), &source).await {
        Ok(dirs) => {
            Event::new(Kind::Agent, Action::Write, Outcome::Ok)
                .remote_ip(peer_ip(&req))
                .detail(format!("skills: installed {} from {}", dirs.join(", "), first_line(&source, 200)))
                .record(&state.db)
                .await;
            Ok(skills_answer(&state).await)
        }
        Err(InstallError::Source(reason)) => Ok(HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalidSource", "reason": reason }))),
        Err(InstallError::Fetch(reason)) => Ok(HttpResponse::BadGateway().json(&serde_json::json!({ "error": "fetchFailed", "reason": reason }))),
        Err(InstallError::NoSkill) => Ok(HttpResponse::NotFound().json(&serde_json::json!({ "error": "noSkill" }))),
        Err(InstallError::TooMany) => Ok(HttpResponse::Conflict().json(&serde_json::json!({ "error": "tooMany" }))),
        Err(InstallError::Write(e)) => {
            tracing::error!("agent skills: {e}");
            Ok(HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "internal" })))
        }
    }
}

#[derive(Deserialize)]
pub struct SkillSwitch {
    enabled: bool,
}

pub async fn put_skill(
    req: HttpRequest,
    dir: web::types::Path<String>,
    body: web::types::Json<SkillSwitch>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match crate::agent_mode::skills::set_enabled(&state.db, &state.agent.skills_root, &dir, body.enabled).await {
        Ok(true) => Ok(skills_answer(&state).await),
        Ok(false) => Ok(HttpResponse::NotFound().json(&serde_json::json!({ "error": "notFound" }))),
        Err(e) => Ok(refused(e.into())),
    }
}

pub async fn delete_skill(req: HttpRequest, dir: web::types::Path<String>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match crate::agent_mode::skills::remove(&state.db, &state.agent.skills_root, &dir).await {
        Ok(true) => {
            Event::new(Kind::Agent, Action::Write, Outcome::Ok)
                .remote_ip(peer_ip(&req))
                .detail(format!("skills: removed {dir}"))
                .record(&state.db)
                .await;
            Ok(skills_answer(&state).await)
        }
        Ok(false) => Ok(HttpResponse::NotFound().json(&serde_json::json!({ "error": "notFound" }))),
        Err(e) => {
            tracing::error!("agent skills: {e}");
            Ok(HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "internal" })))
        }
    }
}

pub async fn put_settings(req: HttpRequest, body: web::types::Json<config::SettingsWrite>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let w = body.into_inner();
    if let Err(code) = config::check(&w) {
        return Ok(bad(code));
    }
    if let Err(e) = config::store(&state.db, &w).await {
        return Ok(refused(e.into()));
    }
    if let Err(e) = state.agent.reconfigure().await {
        tracing::warn!("agent mode: applying the configuration: {e:#}");
    }
    // Which providers changed, never a key.
    Event::new(Kind::Agent, Action::Write, Outcome::Ok)
        .remote_ip(peer_ip(&req))
        .detail(format!(
            "settings: {} providers, credentials {}",
            w.providers.len(),
            w.credentials.keys().cloned().collect::<Vec<_>>().join(",")
        ))
        .record(&state.db)
        .await;
    match config::load(&state.db).await {
        Ok(s) => Ok(HttpResponse::Ok().json(&s)),
        Err(e) => Ok(refused(e.into())),
    }
}

pub async fn models(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match state.agent.models().await {
        Ok(v) => Ok(HttpResponse::Ok().json(&v)),
        Err(e) => Ok(refused(e.into())),
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Probe {
    api: String,
    base_url: String,
    #[serde(default)]
    allow_insecure: bool,
    /// The key being typed; absent, the one stored for [provider_id].
    #[serde(default)]
    api_key: Option<String>,
    #[serde(default)]
    provider_id: Option<String>,
}

/// `POST /agent/models/probe`: what an endpoint being set up lists.
/// `502 {error: "upstream", reason}` when it answers with a failure.
pub async fn probe(req: HttpRequest, body: web::types::Json<Probe>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let p = body.into_inner();
    match state.agent.probe(&p.api, p.base_url.trim(), p.allow_insecure, p.api_key, p.provider_id.as_deref()).await {
        Ok(v) => Ok(HttpResponse::Ok().json(&v)),
        Err(e) => Ok(refused(e)),
    }
}

fn memory_refused(e: MemoryError) -> HttpResponse {
    match e {
        MemoryError::Invalid(reason) => HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalidMemory", "reason": reason })),
        MemoryError::Backend(why) => {
            tracing::error!("agent mode: memory: {why}");
            authz::error(StatusCode::INTERNAL_SERVER_ERROR, "internal", "memory")
        }
    }
}

/// A file of the memory, as a key below `/memories`; never its root.
fn memory_key(path: &str) -> Result<String, HttpResponse> {
    match memory::key_of(path) {
        Ok(k) if !k.is_empty() => Ok(k),
        Ok(_) => Err(memory_refused(MemoryError::Invalid("Not a file".into()))),
        Err(reason) => Err(memory_refused(MemoryError::Invalid(reason))),
    }
}

pub async fn memory_list(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    match state.agent.memory(user).files().await {
        Ok(files) => Ok(HttpResponse::Ok().json(&serde_json::json!({
            "files": files
                .iter()
                .map(|f| serde_json::json!({
                    "path": f.key,
                    "chars": f.content.encode_utf16().count(),
                    "modified": f.modified,
                }))
                .collect::<Vec<_>>(),
        }))),
        Err(e) => Ok(memory_refused(e)),
    }
}

#[derive(Deserialize)]
pub struct MemoryPath {
    path: String,
}

pub async fn memory_get(req: HttpRequest, q: web::types::Query<MemoryPath>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    let key = require!(memory_key(&q.path));
    match state.agent.memory(user).read(&key).await {
        Ok(Some(f)) => Ok(HttpResponse::Ok().json(&serde_json::json!({ "path": f.key, "content": f.content, "modified": f.modified }))),
        Ok(None) => Ok(authz::error(StatusCode::NOT_FOUND, "notFound", "memory")),
        Err(e) => Ok(memory_refused(e)),
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MemoryWrite {
    path: String,
    content: String,
}

pub async fn memory_put(req: HttpRequest, body: web::types::Json<MemoryWrite>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    let w = body.into_inner();
    let key = require!(memory_key(&w.path));
    if let Err(e) = state.agent.memory(user).write(&key, &w.content).await {
        return Ok(memory_refused(e));
    }
    Event::new(Kind::Agent, Action::Write, Outcome::Ok)
        .remote_ip(peer_ip(&req))
        .detail(format!("memory: wrote {}", memory::path_of(&key)))
        .record(&state.db)
        .await;
    Ok(HttpResponse::NoContent().finish())
}

pub async fn memory_delete(req: HttpRequest, q: web::types::Query<MemoryPath>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    let key = require!(memory_key(&q.path));
    match state.agent.memory(user).delete(&key).await {
        Ok(0) => Ok(authz::error(StatusCode::NOT_FOUND, "notFound", "memory")),
        Ok(n) => {
            Event::new(Kind::Agent, Action::Write, Outcome::Ok)
                .remote_ip(peer_ip(&req))
                .detail(format!("memory: deleted {} ({n} files)", memory::path_of(&key)))
                .record(&state.db)
                .await;
            Ok(HttpResponse::NoContent().finish())
        }
        Err(e) => Ok(memory_refused(e)),
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Search {
    query: String,
    kind: Option<String>,
}

/// Ends the search when the page stops listening.
struct StopOnDrop(fl_pi_llm::host::Cancel);

impl Drop for StopOnDrop {
    fn drop(&mut self) {
        self.0.cancel();
    }
}

pub async fn search(req: HttpRequest, body: web::types::Json<Search>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, secure) = require!(shell(&req, &state).await);
    let Search { query, kind } = body.into_inner();
    let query = query.trim().to_string();
    if query.is_empty() || query.len() > 2000 {
        return Ok(bad("invalidQuery"));
    }
    let kind = match kind.as_deref() {
        None => None,
        Some(k) => match SearchKind::parse(k) {
            Some(k) => Some(k),
            None => return Ok(bad("invalidKind")),
        },
    };
    if let Err(e) = config::load(&state.db).await.map_err(FlowError::from).and_then(|s| s.model.map(drop).ok_or(FlowError::NotConfigured)) {
        return Ok(refused(e));
    }
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel::<serde_json::Value>();
    let cancel = fl_pi_llm::host::Cancel::new();
    let guard = StopOnDrop(cancel.clone());
    let state = state.get_ref().clone();
    {
        let state = state.clone();
        tokio::spawn(async move {
            let sink = tx.clone();
            if let Err(e) = state.agent.search(&state, user, secure, query, kind, tx, cancel).await {
                let _ = sink.send(serde_json::json!({ "type": "error", "message": e.to_string() }));
            }
        });
    }
    let stream = async_stream::stream! {
        let _guard = guard;
        yield Ok::<_, std::io::Error>(Bytes::from_static(b": ok\n\n"));
        let mut beat = tokio::time::interval(HEARTBEAT);
        beat.tick().await;
        loop {
            tokio::select! {
                event = rx.recv() => match event {
                    Some(json) => yield Ok(Bytes::from(format!("data: {json}\n\n"))),
                    None => break,
                },
                _ = beat.tick() => yield Ok(Bytes::from_static(b": ping\n\n")),
            }
        }
    };
    Ok(HttpResponse::Ok()
        .content_type("text/event-stream")
        .header("cache-control", "no-cache")
        .header("x-accel-buffering", "no")
        .streaming(Box::pin(stream.boxed())))
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Adopt {
    text: Option<String>,
}

pub async fn adopt_search(req: HttpRequest, id: web::types::Path<String>, body: web::types::Json<Adopt>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, secure) = require!(shell(&req, &state).await);
    let text = body.into_inner().text;
    if let Some(t) = &text
        && !valid_text(t)
    {
        return Ok(bad("invalidPrompt"));
    }
    let state = state.get_ref().clone();
    match state.agent.adopt(&state, user, secure, &id, text).await {
        Ok(view) => Ok(HttpResponse::Created().json(&view)),
        Err(e) => Ok(refused(e)),
    }
}

pub async fn get_permissions(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let _ = require!(shell(&req, &state).await);
    match crate::agent_mode::permissions::load(&state.db).await {
        Ok(p) => Ok(HttpResponse::Ok().json(&serde_json::json!({
            "permissions": p,
            "defaults": state.agent.auto_defaults(),
        }))),
        Err(e) => Ok(refused(e.into())),
    }
}

pub async fn put_permissions(
    req: HttpRequest,
    body: web::types::Json<crate::agent_mode::permissions::Permissions>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let p = body.into_inner();
    if let Err(reason) = p.check() {
        return Ok(HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalidPermissions", "reason": reason })));
    }
    if let Err(e) = crate::agent_mode::permissions::store(&state.db, &p).await {
        return Ok(refused(e.into()));
    }
    Event::new(Kind::Agent, Action::Write, Outcome::Ok)
        .remote_ip(peer_ip(&req))
        .detail(format!(
            "permissions: default {}{}, {} allow, {} ask, {} deny",
            p.default_mode.as_str(),
            if p.disable_bypass { ", bypass off" } else { "" },
            p.rules.allow.len(),
            p.rules.ask.len(),
            p.rules.deny.len()
        ))
        .record(&state.db)
        .await;
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "permissions": p, "defaults": state.agent.auto_defaults() })))
}
