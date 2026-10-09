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
//! - `GET /agent/settings` (any account with `shell`: whether it is set up;
//!   an admin: everything but credentials), `PUT` (admin), `GET
//!   /agent/models` (admin): the providers and their models, as pi lists
//!   them.
//! - `POST /agent/search {query, kind?}`: the desk's search, answered by
//!   the agent reading only: a `text/event-stream` (`kind`, `step`, `items`,
//!   `plan`, `delta`, `said`, `done` with the search's id, `error`) that ends
//!   with the search; closing it stops it. `POST /agent/search/{id}/task
//!   {text?}` carries it into a task, and runs it on with [text].
//! - `GET /agent/permissions` (any account with `shell`): how commands are
//!   approved, and the built-in auto mode lists; `PUT` (admin) replaces it.
//! - `GET /agent/memory`: the account's memory, its files without their
//!   content; `GET /agent/memory/file?path=` one with it, `PUT
//!   /agent/memory/file {path, content}` writes one, `DELETE
//!   /agent/memory/file?path=` removes a file or a directory.
//!
//! # Privilege
//!
//! `shell`, checked here per request and by the tools before every command
//! (`agent_mode`). A task is its account's alone.

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
use crate::agent_mode::{Answer, FlowError, MAX_PROMPT, NewTask, SearchKind, config};
use fl_pi_llm::host::memory::{self, MemoryError};
use crate::core::permissions::Grant;

const HEARTBEAT: std::time::Duration = std::time::Duration::from_secs(25);
/// A JSON body here: a prompt with a pasted log in it.
pub const MAX_REQUEST: usize = MAX_PROMPT + (64 << 10);
/// A memory file's body: its longest content, every character escaped.
pub const MAX_MEMORY_REQUEST: usize = memory::MAX_FILE_CHARS * 12 + (4 << 10);

macro_rules! require {
    ($result:expr) => {{
        match $result {
            Ok(value) => value,
            Err(response) => return Ok(response),
        }
    }};
}

/// The account, its id and whether the link is secure, when it holds `shell`.
async fn shell(req: &HttpRequest, state: &AppState) -> Result<(Caller, i64, bool), HttpResponse> {
    let (caller, user) = super::desk::account(req, state).await?;
    let secure = authz::is_secure(req, state);
    if let Err(why) = caller.check(Grant::Shell, state, secure) {
        Event::new(Kind::Agent, Action::Denied, Outcome::Denied)
            .subject(&caller.username)
            .remote_ip(peer_ip(req))
            .detail(format!("agent: shell {}", why.as_str()))
            .record(&state.db)
            .await;
        return Err(authz::error(StatusCode::FORBIDDEN, "forbidden", why.as_str()));
    }
    Ok((caller, user, secure))
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

pub async fn list(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (_, user, _) = require!(shell(&req, &state).await);
    let settings = match config::load(&state.db).await {
        Ok(s) => s,
        Err(e) => return Ok(refused(e.into())),
    };
    let perms = match crate::agent_mode::permissions::load(&state.db).await {
        Ok(p) => p,
        Err(e) => return Ok(refused(e.into())),
    };
    match state.agent.list(user).await {
        Ok(flows) => Ok(HttpResponse::Ok().json(&serde_json::json!({
            "flows": flows,
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
}

pub async fn start(req: HttpRequest, body: web::types::Json<Start>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (caller, user, secure) = require!(shell(&req, &state).await);
    let Start { prompt, mode, files } = body.into_inner();
    // Files alone are a prompt too.
    if prompt.len() > MAX_PROMPT || (prompt.trim().is_empty() && files.is_empty()) {
        return Ok(bad("invalidPrompt"));
    }
    if files.len() > crate::agent_mode::files::MAX_PER_TASK {
        return Ok(bad("tooManyFiles"));
    }
    let state = state.get_ref().clone();
    match state.agent.start(&state, user, &caller.username, secure, NewTask { prompt, mode, files }).await {
        Ok(view) => {
            Event::new(Kind::Agent, Action::Open, Outcome::Ok)
                .subject(&caller.username)
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
}

pub async fn reply(req: HttpRequest, id: web::types::Path<String>, body: web::types::Json<Reply>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (caller, user, secure) = require!(shell(&req, &state).await);
    let Reply { text, files } = body.into_inner();
    if text.len() > MAX_PROMPT || (text.trim().is_empty() && files.is_empty()) {
        return Ok(bad("invalidPrompt"));
    }
    if files.len() > crate::agent_mode::files::MAX_PER_TASK {
        return Ok(bad("tooManyFiles"));
    }
    let state = state.get_ref().clone();
    match state.agent.reply(&state, user, &caller.username, secure, &id, text, files).await {
        Ok(view) => Ok(HttpResponse::Ok().json(&view)),
        Err(e) => Ok(refused(e)),
    }
}

pub async fn answer(req: HttpRequest, id: web::types::Path<String>, body: web::types::Json<Answer>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (caller, user, secure) = require!(shell(&req, &state).await);
    let answer = body.into_inner();
    let action = answer.action.clone();
    match state.agent.answer(user, secure, &id, answer) {
        Ok(()) => {
            // The verb only: never a password, never what was typed.
            Event::new(Kind::Agent, Action::Write, Outcome::Ok)
                .subject(&caller.username)
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
/// account's password changes, it is gone, or loses `shell`.
pub async fn events(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (caller, user, secure) = require!(shell(&req, &state).await);
    let mut rx = state.agent.subscribe();
    let mut changes = state.grants_changed.subscribe();
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
                    let still = authz::caller_named(&state, &caller.username).await
                        .filter(|now| now.since == caller.since)
                        .is_some_and(|now| now.check(Grant::Shell, &state, secure).is_ok());
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
    let (caller, _, _) = require!(shell(&req, &state).await);
    let settings = match config::load(&state.db).await {
        Ok(s) => s,
        Err(e) => return Ok(refused(e.into())),
    };
    if caller.is_admin() {
        return Ok(HttpResponse::Ok().json(&settings));
    }
    Ok(HttpResponse::Ok().json(&serde_json::json!({
        "model": settings.model,
        "thinkingLevel": settings.thinking_level,
        "maxRunning": settings.max_running,
    })))
}

pub async fn put_settings(req: HttpRequest, body: web::types::Json<config::SettingsWrite>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
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
        .subject(&caller.username)
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
    require!(authz::admin_caller(&req, &state).await);
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

/// `POST /agent/models/probe` (admin): what an endpoint being set up lists.
/// `502 {error: "upstream", reason}` when it answers with a failure.
pub async fn probe(req: HttpRequest, body: web::types::Json<Probe>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
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
    let (caller, user, _) = require!(shell(&req, &state).await);
    let w = body.into_inner();
    let key = require!(memory_key(&w.path));
    if let Err(e) = state.agent.memory(user).write(&key, &w.content).await {
        return Ok(memory_refused(e));
    }
    Event::new(Kind::Agent, Action::Write, Outcome::Ok)
        .subject(&caller.username)
        .remote_ip(peer_ip(&req))
        .detail(format!("memory: wrote {}", memory::path_of(&key)))
        .record(&state.db)
        .await;
    Ok(HttpResponse::NoContent().finish())
}

pub async fn memory_delete(req: HttpRequest, q: web::types::Query<MemoryPath>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let (caller, user, _) = require!(shell(&req, &state).await);
    let key = require!(memory_key(&q.path));
    match state.agent.memory(user).delete(&key).await {
        Ok(0) => Ok(authz::error(StatusCode::NOT_FOUND, "notFound", "memory")),
        Ok(n) => {
            Event::new(Kind::Agent, Action::Write, Outcome::Ok)
                .subject(&caller.username)
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
    let (caller, user, secure) = require!(shell(&req, &state).await);
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
        let username = caller.username.clone();
        tokio::spawn(async move {
            let sink = tx.clone();
            if let Err(e) = state.agent.search(&state, user, &username, secure, query, kind, tx, cancel).await {
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
    let (caller, user, secure) = require!(shell(&req, &state).await);
    let text = body.into_inner().text;
    if let Some(t) = &text
        && !valid_text(t)
    {
        return Ok(bad("invalidPrompt"));
    }
    let state = state.get_ref().clone();
    match state.agent.adopt(&state, user, &caller.username, secure, &id, text).await {
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
    let caller = require!(authz::admin_caller(&req, &state).await);
    let p = body.into_inner();
    if let Err(reason) = p.check() {
        return Ok(HttpResponse::BadRequest().json(&serde_json::json!({ "error": "invalidPermissions", "reason": reason })));
    }
    if let Err(e) = crate::agent_mode::permissions::store(&state.db, &p).await {
        return Ok(refused(e.into()));
    }
    Event::new(Kind::Agent, Action::Write, Outcome::Ok)
        .subject(&caller.username)
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
