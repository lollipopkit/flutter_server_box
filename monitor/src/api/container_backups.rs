//! `/api/v1/container-backups*` — backups of containers' volumes and bound
//! folders (`container_backups`). Admin; restoring and removing re-ask the
//! password.
//!
//! - `GET /container-backups`: every finished backup, newest first.
//! - `POST /container-backups`: `{containers: [id], project, stop}` backs up
//!   those containers (with `project`, their whole compose project); answers
//!   the job (202).
//! - `GET /container-backups/job?since=<seq>`, `POST …/job/cancel`.
//! - `POST /container-backups/{id}/restore` (password): written back.
//! - `DELETE /container-backups/{id}` (password).
//! - `PUT /container-backups/settings`: `{destination, keep}`, the folder
//!   backups go to (a backup disk's mount; null beside the database) and how
//!   many of each are kept.
//! - `POST /container-backups/schedules`: `{containers: [name], project, stop,
//!   every, at, weekday, keep}`; `DELETE /container-backups/schedules/{id}`.
//!
//! The list answers the settings, the free space where backups go, the
//! schedules and the job too.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::json;

use super::admin::reauth;
use super::authz;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::container_backups;
use crate::stacks::Refusal;

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

pub async fn list(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
    let job = state.container_backups.job().map(|j| j.view(u64::MAX));
    Ok(HttpResponse::Ok().json(&json!({
        "backups": state.container_backups.list(),
        "job": job,
        "settings": container_backups::settings(&state.db).await,
        "folder": state.container_backups.root(),
        "default_folder": state.container_backups.default_root(),
        "free_bytes": container_backups::free_bytes(&state),
        "schedules": container_backups::schedules(&state.db).await,
    })))
}

#[derive(Deserialize)]
pub struct CreateBody {
    containers: Vec<String>,
    #[serde(default)]
    project: bool,
    #[serde(default = "yes")]
    stop: bool,
}

fn yes() -> bool {
    true
}

pub async fn create(
    req: HttpRequest,
    body: web::types::Json<CreateBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    if body.containers.is_empty() || body.containers.len() > 64 {
        return Ok(HttpResponse::BadRequest().json(&json!({ "error": "invalidContainer" })));
    }
    match container_backups::back_up(&state, &caller.username, &body.containers, body.project, body.stop, None).await {
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
    query: web::types::Query<JobQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
    match state.container_backups.job() {
        Some(job) => Ok(HttpResponse::Ok().json(&job.view(query.since))),
        None => Ok(HttpResponse::NotFound().json(&json!({ "error": "notFound" }))),
    }
}

pub async fn cancel(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
    if let Some(job) = state.container_backups.job() {
        job.cancel();
    }
    Ok(HttpResponse::NoContent().finish())
}

#[derive(Deserialize, Default)]
pub struct PasswordBody {
    current_password: Option<String>,
}

pub async fn restore(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: Option<web::types::Json<PasswordBody>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let body = body.map(|b| b.into_inner()).unwrap_or_default();
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    match container_backups::restore(&state, &caller.username, &id).await {
        Ok(job) => Ok(HttpResponse::Accepted().json(&job.view(0))),
        Err(r) => Ok(refused(r)),
    }
}

pub async fn remove(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: Option<web::types::Json<PasswordBody>>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let body = body.map(|b| b.into_inner()).unwrap_or_default();
    require!(reauth(&req, &state, &caller, body.current_password.as_deref()).await);
    match state.container_backups.remove(&id) {
        Ok(()) => {
            Event::new(Kind::Machine, Action::Write, Outcome::Ok)
                .subject(&caller.username)
                .detail(format!("container backup {id} removed"))
                .record(&state.db)
                .await;
            Ok(HttpResponse::NoContent().finish())
        }
        Err(r) => Ok(refused(r)),
    }
}

pub async fn put_settings(
    req: HttpRequest,
    body: web::types::Json<container_backups::Settings>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    match container_backups::set_settings(&state, body.into_inner()).await {
        Ok(settings) => {
            Event::new(Kind::Machine, Action::Write, Outcome::Ok)
                .subject(&caller.username)
                .detail(format!("container backups go to {}", settings.destination.as_deref().unwrap_or("the default folder")))
                .record(&state.db)
                .await;
            Ok(HttpResponse::Ok().json(&settings))
        }
        Err(r) => Ok(refused(r)),
    }
}

pub async fn add_schedule(
    req: HttpRequest,
    body: web::types::Json<container_backups::NewSchedule>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    match container_backups::add_schedule(&state, &caller.username, body.into_inner()).await {
        Ok(schedule) => Ok(HttpResponse::Created().json(&schedule)),
        Err(r) => Ok(refused(r)),
    }
}

pub async fn remove_schedule(
    req: HttpRequest,
    id: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
    match container_backups::remove_schedule(&state, &id).await {
        Ok(()) => Ok(HttpResponse::NoContent().finish()),
        Err(r) => Ok(refused(r)),
    }
}
