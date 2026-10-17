//! A `wasm` app's backend (`apps::runtime`), as its frame reaches it through
//! the desk's bridge:
//!
//! - `POST /apps/{id}/call {function, args, sudo?}`: one of its `api`
//!   functions → `200 {value}`, or `{error, message}` (4xx).
//! - `POST /apps/{id}/jobs {function, args, sudo?}`: one of its `jobs` as the
//!   app's job (one at a time) → `202` its view.
//! - `GET /apps/{id}/jobs?since=`: the job running or the last: state, lines
//!   after `since`, and once ended `value` or `error`.
//! - `POST /apps/{id}/jobs/cancel`.
//! - `GET /apps/sudo`: whether a sudo password is remembered for the account.
//!
//! `sudo` is `{password, remember}`, sent by the desk after its own dialog
//! (the frame never sees the password): tried first (`sudo_rejected`), held
//! for that call or job only, or kept in memory with Agent mode's for 15
//! minutes when `remember`; an empty one uses the remembered one, else tries
//! without (root, `NOPASSWD`). What reaches the machine also needs the app's
//! approved permission and the transport rule, checked at the moment of use.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::{Value, json};
use zeroize::Zeroizing;

use super::authz;
use super::server::AppState;
use super::shares::{as_root, record};
use crate::apps::runtime::{Ctx, Failure, Grant, Kind, error_code};
use crate::apps::{Outcome, Refusal};
use crate::stacks::job::JobState;

/// A request's body: the parameters are the function's, bounded with it.
pub const MAX_REQUEST: usize = 1 << 20;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Sudo {
    #[serde(default)]
    password: Option<String>,
    #[serde(default)]
    remember: bool,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CallBody {
    function: String,
    #[serde(default)]
    args: Value,
    #[serde(default)]
    sudo: Option<Sudo>,
}

fn refusal(status: u16, error: &str, message: impl Into<String>) -> HttpResponse {
    let message: String = message.into();
    let mut body = json!({ "error": error });
    if !message.is_empty() {
        body["message"] = Value::String(message);
    }
    HttpResponse::build(ntex::http::StatusCode::from_u16(status).unwrap_or(ntex::http::StatusCode::BAD_REQUEST)).json(&body)
}

fn failure(f: Failure) -> (u16, Refusal) {
    let r = |error: &str, message: String| Refusal { error: error.into(), message };
    match f {
        Failure::Unknown => (404, r("unknownFunction", String::new())),
        Failure::Arguments(m) => (400, r("invalidArgument", m)),
        Failure::App(e) => {
            let (code, message) = error_code(&e);
            let status = match code {
                "invalidArgument" => 400,
                "notFound" => 404,
                "alreadyExists" | "failedPrecondition" => 409,
                "permissionDenied" => 403,
                "unavailable" => 503,
                "deadlineExceeded" => 504,
                "cancelled" => 499,
                _ => 500,
            };
            (status, r(code, message))
        }
        Failure::Trap(m) => {
            tracing::debug!("app trap: {m}");
            (422, r("trap", String::new()))
        }
        Failure::Deadline => (504, r("deadlineExceeded", String::new())),
        Failure::Cancelled => (499, r("cancelled", String::new())),
    }
}

/// An approved `wasm` app's backend digest and approved permissions.
async fn approved(state: &AppState, id: &str) -> Result<Option<(String, Vec<String>)>, sqlx::Error> {
    let row: Option<(Option<String>, String)> = sqlx::query_as(
        "SELECT p.approved_permissions, f.sha256 FROM desk_app_package p \
         JOIN desk_app_file f ON f.app_id = p.app_id AND f.path = 'backend.wasm' WHERE p.app_id = ?",
    )
    .bind(id)
    .fetch_optional(&state.db)
    .await?;
    Ok(row.and_then(|(approved, sha)| Some((sha, serde_json::from_str(&approved?).unwrap_or_default()))))
}

/// The sudo password a request may use: tried before anything runs.
async fn password(state: &AppState, user: i64, sudo: Option<Sudo>) -> Result<Option<Zeroizing<String>>, HttpResponse> {
    let Some(sudo) = sudo else { return Ok(None) };
    let given = sudo.password.filter(|p| !p.is_empty()).map(Zeroizing::new);
    let password = given.clone().or_else(|| state.agent.sudo_password(user));
    as_root(state, "true", password.as_deref().map(String::as_str), false).await?;
    if sudo.remember && given.is_some() {
        state.agent.remember_sudo(user, given);
    }
    Ok(Some(password.unwrap_or_default()))
}

/// What a request runs with: the app, the account, the permissions, the
/// link it came by, and the sudo password it was given.
async fn prepare(req: &HttpRequest, state: &Arc<AppState>, id: &str, body: &mut CallBody) -> Result<(Arc<crate::apps::runtime::Backend>, Ctx), HttpResponse> {
    let caller = authz::jwt_caller(req, state).await?;
    if !(1..=64).contains(&body.function.len()) {
        return Err(refusal(400, "invalidArgument", "function"));
    }
    let (sha, permissions) = match approved(state, id).await {
        Ok(Some(v)) => v,
        Ok(None) => return Err(refusal(404, "notFound", "")),
        Err(e) => return Err(super::respond::internal(&e)),
    };
    let blobs = state.blobs.clone();
    let blob = sha.clone();
    let backend = state.apps.backend(&sha, move || blobs.read_blocking(&blob).ok().flatten()).await.map_err(|e| {
        tracing::warn!(app = %id, "app backend: {e}");
        // A `wasm` package of API 1 (a core module) is not run any more.
        // TODO: remove once no agent has one installed.
        refusal(422, "unsupportedApi", "")
    })?;
    let reach = caller.check(state, authz::is_secure(req, state)).map_err(|why| why.as_str().to_string());
    let password = password(state, caller.id, body.sudo.take()).await?;
    let grant = Grant { state: state.clone(), app: id.to_string(), user: caller.id, permissions, reach };
    Ok((backend, Ctx::new(grant, password, None)))
}

pub async fn call(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<CallBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let mut body = body.into_inner();
    let Ok(_slot) = state.apps.calls.clone().try_acquire_owned() else {
        return Ok(refusal(429, "unavailable", "busy"));
    };
    let sudo = body.sudo.is_some();
    let (backend, ctx) = match prepare(&req, &state, &id, &mut body).await {
        Ok(v) => v,
        Err(r) => return Ok(r),
    };
    if sudo {
        record(&req, &state, format!("app {} {} as root", id.as_str(), body.function)).await;
    }
    tracing::info!(app = %id.as_str(), "app call {}", body.function);
    match backend.invoke(Kind::Call, &body.function, &body.args, ctx).await {
        Ok(value) => Ok(HttpResponse::Ok().json(&json!({ "value": value }))),
        Err(f) => {
            let (status, r) = failure(f);
            Ok(refusal(status, &r.error, r.message))
        }
    }
}

pub async fn start_job(
    req: HttpRequest,
    id: web::types::Path<String>,
    body: web::types::Json<CallBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let mut body = body.into_inner();
    let sudo = body.sudo.is_some();
    let (backend, ctx) = match prepare(&req, &state, &id, &mut body).await {
        Ok(v) => v,
        Err(r) => return Ok(r),
    };
    if !backend.names(Kind::Job).contains(&body.function.as_str()) {
        return Ok(refusal(404, "unknownFunction", ""));
    }
    let Some(app_job) = state.apps.begin(&id, &body.function) else { return Ok(refusal(409, "unavailable", "busy")) };
    record(&req, &state, format!("app {} job {}{}", id.as_str(), body.function, if sudo { " as root" } else { "" })).await;
    let ctx = ctx.with_job(app_job.job.clone());
    let (run, args, function) = (app_job.clone(), body.args, body.function);
    tokio::spawn(async move {
        let answer = backend.invoke(Kind::Job, &function, &args, ctx).await;
        let (state, outcome) = match answer {
            Ok(value) => (JobState::Succeeded, Outcome { value: Some(value), error: None }),
            Err(f) => {
                let cancelled = matches!(f, Failure::Cancelled);
                let (_, r) = failure(f);
                run.job.push(format!("✕ {}{}", r.error, if r.message.is_empty() { String::new() } else { format!(": {}", r.message) }));
                (if cancelled { JobState::Cancelled } else { JobState::Failed }, Outcome { value: None, error: Some(r) })
            }
        };
        let error = outcome.error.as_ref().map(|e| e.error.clone());
        *run.outcome.lock().unwrap_or_else(|p| p.into_inner()) = Some(outcome);
        run.job.finish(state, error);
    });
    Ok(HttpResponse::Accepted().json(&app_job.view(0)))
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
    require!(authz::jwt_caller(&req, &state).await);
    match state.apps.job(&id) {
        Some(j) => Ok(HttpResponse::Ok().json(&j.view(query.since))),
        None => Ok(refusal(404, "notFound", "")),
    }
}

pub async fn cancel_job(req: HttpRequest, id: web::types::Path<String>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::jwt_caller(&req, &state).await);
    match state.apps.job(&id) {
        Some(j) => {
            j.job.cancel();
            Ok(HttpResponse::Accepted().json(&j.view(0)))
        }
        None => Ok(refusal(404, "notFound", "")),
    }
}

pub async fn sudo(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let caller = match authz::jwt_caller(&req, &state).await {
        Ok(c) => c,
        Err(r) => return Ok(r),
    };
    Ok(HttpResponse::Ok().json(&json!({ "remembered": state.agent.sudo_password(caller.id).is_some() })))
}
