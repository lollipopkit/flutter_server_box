//! `/api/v1/stacks*` — the web apps this agent can deploy and has deployed
//! (`stacks`).
//!
//! - `GET /stacks`: every app of the catalog, with its deployment (the
//!   settings it was deployed with) and the running job.
//!   Its catalog is read again in the background when an hour old;
//!   `POST /stacks/refresh` reads it now. Each app says where it is
//!   from (`source`: `bundled` | `store` | `local`, and `repo`).
//! - `GET /stacks/{id}/prepare`: what the deploy dialog starts from:
//!   defaults for this machine, whether Docker/Podman and Compose are here,
//!   the machine's memory and cores.
//! - `POST /stacks/{id}/check`: what deploying `{settings}` would
//!   do (images, folders, port), or the setting that is wrong.
//! - `POST /stacks/{id}` (password): deploys, `{settings,
//!   acknowledged, accept_license}`: the operator confirmed it installs
//!   third-party software, and accepted the licence where the manifest asks;
//!   answers the job (202).
//! - `PUT /stacks/{id}/settings` (password): `{settings}` for a
//!   deployed app; deployed again with them (its ports checked, never moved).
//! - `POST /stacks/{id}/action`: `start` | `stop` | `restart` |
//!   `update`.
//! - `DELETE /stacks/{id}` (password): takes it down, `{purge}` with
//!   its data.
//! - `GET /stacks/{id}/job?since=<seq>`, `POST /stacks/{id}/job/cancel`.
//! - `GET /stacks/{id}/services`: its containers.
//! - `POST /stacks/{id}/login` (password): how to sign in to the
//!   deployed app the first time (`[login]`), its password included.
//! - `POST /stacks/{id}/enter`: a ticket for the app's proxy
//!   (`url` when apps are taken by host, `[stacks] apps_url`)
//!   (`stacks::proxy`), and its port.

use std::collections::BTreeMap;
use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::{Value, json};

use super::admin::reauth;
use super::authz;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use super::ws::ticket::Purpose;
use crate::stacks::{self, Refusal, StackAction, store};

macro_rules! require {
    ($result:expr) => {{
        match $result {
            Ok(value) => value,
            Err(response) => return Ok(response),
        }
    }};
}

fn refused(r: Refusal) -> HttpResponse {
    let status = ntex::http::StatusCode::from_u16(r.status).unwrap_or(ntex::http::StatusCode::BAD_REQUEST);
    HttpResponse::build(status).json(&r)
}

fn internal_error(e: &dyn std::fmt::Display) -> HttpResponse {
    tracing::error!("stacks: {e}");
    HttpResponse::InternalServerError().json(&json!({ "error": "internal" }))
}

fn not_found() -> HttpResponse {
    HttpResponse::NotFound().json(&json!({ "error": "notFound" }))
}

pub async fn list(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::jwt_caller(&req, &state).await);
    // Read again in the background when an hour old; this answer is what is
    // known now.
    let st = state.get_ref().clone();
    tokio::spawn(async move { st.stacks.catalog.refresh(false).await });
    answer_list(&state).await
}

/// Reads the catalog's repositories now, and answers as [`list`].
pub async fn refresh(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    state.stacks.catalog.refresh(true).await;
    answer_list(&state).await
}

async fn answer_list(state: &AppState) -> Result<HttpResponse, web::Error> {
    let rows = match store::all(&state.db).await {
        Ok(rows) => rows,
        Err(e) => return Ok(internal_error(&e)),
    };
    let apps: Vec<Value> = state
        .stacks
        .catalog
        .all()
        .iter()
        .map(|entry| {
            let id = &entry.package.manifest.id;
            let row = rows.iter().find(|r| &r.id == id);
            let stack = row.map(|r| serde_json::to_value(r).unwrap_or(Value::Null));
            let job = state.stacks.job(id).map(|j| j.view(u64::MAX));
            json!({
                "manifest": entry.package.manifest,
                "source": entry.source,
                "repo": entry.repo,
                "stack": stack,
                "job": job,
                "proxy": state.stacks.proxies.port(id).is_some(),
                "health": row.and_then(|_| state.stacks.health(id)),
            })
        })
        .collect();
    Ok(HttpResponse::Ok().json(&json!({ "apps": apps })))
}

pub async fn prepare(
    req: HttpRequest,
    id: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let Some(package) = state.stacks.package(&id) else { return Ok(not_found()) };
    let machine = stacks::machine(&state, &id).await;
    let runtime = match stacks::runtime(&state).await {
        Ok((ty, compose)) => json!({ "available": true, "runtime": ty, "compose": compose }),
        Err(r) => json!({ "available": false, "error": r.error }),
    };
    let (memory_mib, cores) = match state.current_metrics.read().await.as_ref() {
        Some(m) => (Some(m.memory.total / (1 << 20)), Some(m.cpu_cores.len())),
        None => (None, None),
    };
    Ok(HttpResponse::Ok().json(&json!({
        "defaults": package.manifest.defaults(&machine),
        "runtime": runtime,
        "memory_mib": memory_mib,
        "cores": cores,
        "gpus": machine.gpus,
        "gpus_seen": stacks::gpus_seen(&state).await,
        "wsl": machine.wsl,
        "ports_partial": stacks::ports::partial(machine.wsl),
    })))
}

#[derive(Deserialize)]
pub struct CheckBody {
    #[serde(default)]
    settings: BTreeMap<String, Value>,
}

/// What deploying these settings would do, or which setting is wrong: what
/// the confirmation shows before the password is asked.
pub async fn check(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<CheckBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match stacks::preview(&state, &id, &body.settings).await {
        Ok(preview) => Ok(HttpResponse::Ok().json(&preview)),
        Err(r) => Ok(refused(r)),
    }
}

#[derive(Deserialize)]
pub struct InstallBody {
    current_password: Option<String>,
    #[serde(default)]
    settings: BTreeMap<String, Value>,
    /// That this installs third-party software, as the confirmation said.
    #[serde(default)]
    acknowledged: bool,
    #[serde(default)]
    accept_license: bool,
}

pub async fn install(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<InstallBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.into_inner();
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    let consent = stacks::Consent { third_party: body.acknowledged, license: body.accept_license };
    match stacks::install(&state, &id, &body.settings, consent).await {
        Ok(job) => Ok(HttpResponse::Accepted().json(&job.view(0))),
        Err(r) => Ok(refused(r)),
    }
}

#[derive(Deserialize)]
pub struct SettingsBody {
    current_password: Option<String>,
    settings: BTreeMap<String, Value>,
}

/// New settings for a deployed app: its files written again and its
/// containers recreated.
pub async fn reconfigure(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<SettingsBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.into_inner();
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    match stacks::reconfigure(&state, &id, &body.settings).await {
        Ok(job) => Ok(HttpResponse::Accepted().json(&job.view(0))),
        Err(r) => Ok(refused(r)),
    }
}

#[derive(Deserialize)]
pub struct ActionBody {
    action: StackAction,
}

pub async fn act(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<ActionBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match stacks::act(&state, &id, body.action).await {
        Ok(job) => Ok(HttpResponse::Accepted().json(&job.view(0))),
        Err(r) => Ok(refused(r)),
    }
}

#[derive(Deserialize, Default)]
pub struct RemoveBody {
    current_password: Option<String>,
    #[serde(default)]
    purge: bool,
}

pub async fn remove(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: Option<web::types::Json<RemoveBody>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.map(|b| b.into_inner()).unwrap_or_default();
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    match stacks::remove(&state, &id, body.purge).await {
        Ok(job) => Ok(HttpResponse::Accepted().json(&job.view(0))),
        Err(r) => Ok(refused(r)),
    }
}

#[derive(Deserialize)]
pub struct JobQuery {
    #[serde(default)]
    since: u64,
}

pub async fn job(
    req: HttpRequest,
    id: web::types::Path<String>,
    query: web::types::Query<JobQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match state.stacks.job(&id) {
        Some(job) => Ok(HttpResponse::Ok().json(&job.view(query.since))),
        None => Ok(not_found()),
    }
}

pub async fn cancel(
    req: HttpRequest,
    id: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match state.stacks.job(&id) {
        Some(job) => {
            job.cancel();
            Ok(HttpResponse::NoContent().finish())
        }
        None => Ok(not_found()),
    }
}

#[derive(Deserialize, Default)]
pub struct LoginBody {
    current_password: Option<String>,
}

/// The deployed app's first sign-in: a password, so the account's own again.
pub async fn login(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: Option<web::types::Json<LoginBody>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let body = body.map(|b| b.into_inner()).unwrap_or_default();
    require!(reauth(&req, &state, body.current_password.as_deref()).await);
    match stacks::login(&state, &id).await {
        Ok(login) => Ok(HttpResponse::Ok().json(&login)),
        Err(r) => Ok(refused(r)),
    }
}

pub async fn services(
    req: HttpRequest,
    id: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match stacks::services(&state, &id).await {
        Ok(services) => Ok(HttpResponse::Ok().json(&json!({ "services": services }))),
        Err(r) => Ok(refused(r)),
    }
}

pub async fn enter(
    req: HttpRequest,
    id: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let Some(package) = state.stacks.package(&id) else { return Ok(not_found()) };
    let Some(port) = state.stacks.proxies.port(&id) else {
        return Ok(HttpResponse::Conflict().json(&json!({ "error": "notRunning" })));
    };
    let ticket = match state.tickets.issue(Purpose::Proxy) {
        Ok(t) => t,
        Err(e) => return Ok(internal_error(&e)),
    };
    // The window is framed by the page that asked, when the agent would let
    // that page call it anyway.
    if let Some(origin) = req.headers().get("origin").and_then(|v| v.to_str().ok())
        && super::ws::origin_allowed(&req, &state.config.get_server().cors_allowed_origins)
    {
        state.stacks.proxies.note_entry(&ticket, origin.to_string());
    }
    Event::new(Kind::Stack, Action::Connect, Outcome::Ok)
        .remote_ip(peer_ip(&req))
        .detail(format!("enter {id}"))
        .record(&state.db)
        .await;
    Ok(HttpResponse::Ok().json(&json!({
        "ticket": ticket,
        "port": port,
        "tls": state.tls_active,
        "path": package.manifest.web.path,
        "enter": crate::stacks::proxy::ENTER_PATH,
        // Taken by host (`[stacks] apps_url`): the window's address, instead of
        // the agent's host on `port`.
        "url": state.stacks.proxies.host_url(&id),
    })))
}
