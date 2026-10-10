//! `/api/v1/stacks*` — the web apps this agent can deploy and has deployed
//! (`stacks`).
//!
//! - `GET /stacks` (any account): every app of the catalog, with its
//!   deployment's state. An admin also gets the settings it was deployed
//!   with and the running job.
//! - `GET /stacks/{id}/prepare` (admin): what the deploy dialog starts from:
//!   defaults for this machine, whether Docker/Podman and Compose are here,
//!   the machine's memory and cores.
//! - `POST /stacks/{id}/check` (admin): what deploying `{settings}` would
//!   do (images, folders, port), or the setting that is wrong.
//! - `POST /stacks/{id}` (admin, password): deploys, `{settings,
//!   acknowledged, accept_license}`: the admin confirmed it installs
//!   third-party software, and accepted the licence where the manifest asks;
//!   answers the job (202).
//! - `POST /stacks/{id}/action` (admin): `start` | `stop` | `restart` |
//!   `update`.
//! - `DELETE /stacks/{id}` (admin, password): takes it down, `{purge}` with
//!   its data.
//! - `GET /stacks/{id}/job?since=<seq>` (admin), `POST /stacks/{id}/job/cancel`.
//! - `GET /stacks/{id}/services` (admin): its containers.
//! - `POST /stacks/{id}/enter` (any account): a ticket for the app's proxy
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
use crate::stacks::{self, Refusal, StackAction, Stacks, store};

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
    let caller = require!(authz::jwt_caller(&req, &state).await);
    let rows = match store::all(&state.db).await {
        Ok(rows) => rows,
        Err(e) => return Ok(internal_error(&e)),
    };
    let apps: Vec<Value> = stacks::builtin::packages()
        .iter()
        .map(|p| {
            let id = &p.manifest.id;
            let row = rows.iter().find(|r| &r.id == id);
            let stack = row.map(|r| {
                if caller.is_admin() {
                    serde_json::to_value(r).unwrap_or(Value::Null)
                } else {
                    json!({ "state": r.state, "version": r.version })
                }
            });
            let job = caller.is_admin().then(|| state.stacks.job(id).map(|j| j.view(u64::MAX))).flatten();
            json!({
                "manifest": p.manifest,
                "stack": stack,
                "job": job,
                "proxy": state.stacks.proxies.port(id).is_some(),
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
    require!(authz::admin_caller(&req, &state).await);
    let Some(package) = Stacks::package(&id) else { return Ok(not_found()) };
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
    require!(authz::admin_caller(&req, &state).await);
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
    let caller = require!(authz::admin_caller(&req, &state).await);
    let body = body.into_inner();
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    let consent = stacks::Consent { third_party: body.acknowledged, license: body.accept_license };
    match stacks::install(&state, &caller.username, &id, &body.settings, consent).await {
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
    let caller = require!(authz::admin_caller(&req, &state).await);
    match stacks::act(&state, &caller.username, &id, body.action).await {
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
    let caller = require!(authz::admin_caller(&req, &state).await);
    let body = body.map(|b| b.into_inner()).unwrap_or_default();
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    match stacks::remove(&state, &caller.username, &id, body.purge).await {
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
    require!(authz::admin_caller(&req, &state).await);
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
    require!(authz::admin_caller(&req, &state).await);
    match state.stacks.job(&id) {
        Some(job) => {
            job.cancel();
            Ok(HttpResponse::NoContent().finish())
        }
        None => Ok(not_found()),
    }
}

pub async fn services(
    req: HttpRequest,
    id: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
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
    let caller = require!(authz::jwt_caller(&req, &state).await);
    let Some(package) = Stacks::package(&id) else { return Ok(not_found()) };
    let Some(port) = state.stacks.proxies.port(&id) else {
        return Ok(HttpResponse::Conflict().json(&json!({ "error": "notRunning" })));
    };
    let ticket = match state.tickets.issue(Purpose::Proxy, &caller.username) {
        Ok(t) => t,
        Err(e) => return Ok(internal_error(&e)),
    };
    Event::new(Kind::Stack, Action::Connect, Outcome::Ok)
        .subject(&caller.username)
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
    })))
}
