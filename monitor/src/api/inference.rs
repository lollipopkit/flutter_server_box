//! `/api/v1/inference*`: Local inference (`crate::inference`). The machine
//! and the engines that fit it, llmfit's models for each, MLX on Apple
//! Silicon, and Ollama's models. The engines in containers are stacks
//! (`/stacks/{id}*`, `source: part`); deploying one is that route's.
//!
//! Everything goes through `machine::gate`: a reading of the machine runs
//! commands, and each change starts or replaces a server.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::json;

use super::machine;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome};
use crate::inference::{self, mlx, ollama};

fn refused(status: u16, error: &str) -> HttpResponse {
    let status = ntex::http::StatusCode::from_u16(status).unwrap_or(ntex::http::StatusCode::BAD_REQUEST);
    HttpResponse::build(status).json(&json!({ "error": error }))
}

async fn audit(state: &AppState, gated: &machine::Gated, outcome: Outcome, detail: String) {
    Event::new(Kind::Machine, Action::Write, outcome).remote_ip(gated.remote_ip.clone()).detail(detail).record(&state.db).await;
}

/// The machine, each engine and whether it runs here, MLX's server, the
/// Ollamas found, and MLX's installation job.
pub async fn overview(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    if let Err(refusal) = machine::gate(&req, &state, "inference read").await {
        return Ok(refusal);
    }
    let hw = state.inference.hardware(&state).await;
    let mlx = mlx::service(&state).await;
    let ollama = ollama::instances(&state).await;
    // What was started or stopped outside the panel is offered again.
    inference::refresh_providers(state.get_ref());
    Ok(HttpResponse::Ok().json(&json!({
        "hardware": hw,
        "engines": inference::engines(&hw),
        "mlx": mlx.map(|svc| json!({ "installed": mlx::installed(&state), "version": sbm_parser::inference::MLX_LM_VERSION, "service": svc })),
        "ollama": ollama,
        "pulls": state.inference.ollama.pulls(),
        "llmfit": { "version": sbm_parser::inference::LLMFIT_VERSION, "installed": state.inference.llmfit.installed() },
        "job": state.inference.job().map(|j| j.view(u64::MAX)),
    })))
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct RecommendBody {
    #[serde(default)]
    use_case: Option<String>,
    /// Repositories of anyone, not only known publishers.
    #[serde(default)]
    all_publishers: bool,
    #[serde(default)]
    limit: Option<usize>,
}

/// llmfit's models for each engine that runs here, best engine first.
pub async fn recommend(
    req: HttpRequest,
    body: web::types::Json<RecommendBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refusal) = machine::gate(&req, &state, "inference recommend").await {
        return Ok(refusal);
    }
    let body = body.into_inner();
    let query = sbm_parser::inference::RecommendQuery { use_case: body.use_case };
    match inference::recommend(&state, &query, body.all_publishers, body.limit.unwrap_or(12).clamp(1, 50)).await {
        Ok((hw, candidates)) => {
            let engines: Vec<_> = inference::runnable(&hw);
            Ok(HttpResponse::Ok().json(&json!({ "engines": engines, "candidates": candidates })))
        }
        Err(e) if e == "invalidUseCase" => Ok(refused(400, "invalidUseCase")),
        Err(e) => {
            tracing::warn!("inference: llmfit: {e}");
            Ok(HttpResponse::BadGateway().json(&json!({ "error": "llmfit", "reason": e })))
        }
    }
}

pub async fn mlx_install(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, "inference mlx install").await {
        Ok(g) => g,
        Err(refusal) => return Ok(refusal),
    };
    match mlx::install(state.get_ref()) {
        Ok(job) => {
            audit(&state, &gated, Outcome::Ok, format!("inference: install mlx-lm {}", sbm_parser::inference::MLX_LM_VERSION)).await;
            Ok(HttpResponse::Accepted().json(&job.view(0)))
        }
        Err(e) => Ok(refused(409, e)),
    }
}

#[derive(Deserialize)]
pub struct JobQuery {
    #[serde(default)]
    since: u64,
}

pub async fn job(req: HttpRequest, q: web::types::Query<JobQuery>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    if let Err(refusal) = machine::gate(&req, &state, "inference job").await {
        return Ok(refusal);
    }
    match state.inference.job() {
        Some(j) => Ok(HttpResponse::Ok().json(&j.view(q.since))),
        None => Ok(refused(404, "noJob")),
    }
}

pub async fn job_cancel(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    if let Err(refusal) = machine::gate(&req, &state, "inference job cancel").await {
        return Ok(refusal);
    }
    if let Some(j) = state.inference.job() {
        j.cancel();
    }
    Ok(HttpResponse::NoContent().finish())
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct MlxStart {
    model: String,
    #[serde(default = "mlx_port")]
    port: u16,
}

fn mlx_port() -> u16 {
    8585
}

/// Serves a model with MLX, replacing the one served.
pub async fn mlx_start(req: HttpRequest, body: web::types::Json<MlxStart>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, "inference mlx start").await {
        Ok(g) => g,
        Err(refusal) => return Ok(refusal),
    };
    if body.port < 1024 {
        return Ok(refused(400, "invalidPort"));
    }
    match mlx::start(state.get_ref(), &body.model, body.port).await {
        Ok(()) => {
            audit(&state, &gated, Outcome::Ok, format!("inference: mlx serves {} on {}", body.model, body.port)).await;
            Ok(HttpResponse::NoContent().finish())
        }
        Err(e) if e == "invalidModel" || e == "notInstalled" => Ok(refused(400, &e)),
        Err(e) => {
            audit(&state, &gated, Outcome::Error, "inference: mlx start failed".into()).await;
            Ok(HttpResponse::BadGateway().json(&json!({ "error": "mlx", "reason": e })))
        }
    }
}

pub async fn mlx_stop(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, "inference mlx stop").await {
        Ok(g) => g,
        Err(refusal) => return Ok(refusal),
    };
    match mlx::stop(state.get_ref()).await {
        Ok(()) => {
            audit(&state, &gated, Outcome::Ok, "inference: mlx stopped".into()).await;
            Ok(HttpResponse::NoContent().finish())
        }
        Err(e) => Ok(HttpResponse::BadGateway().json(&json!({ "error": "mlx", "reason": e }))),
    }
}

async fn instance_base(state: &AppState, instance: &str) -> Result<String, HttpResponse> {
    ollama::base_of(state, instance).await.ok_or_else(|| refused(404, "noOllama"))
}

/// An Ollama's models and the ones loaded.
pub async fn ollama_models(
    req: HttpRequest,
    instance: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refusal) = machine::gate(&req, &state, "inference ollama models").await {
        return Ok(refusal);
    }
    let base = match instance_base(&state, &instance).await {
        Ok(b) => b,
        Err(r) => return Ok(r),
    };
    match state.inference.ollama.models(&base).await {
        Ok(v) => Ok(HttpResponse::Ok().json(&v)),
        Err(e) => Ok(HttpResponse::BadGateway().json(&json!({ "error": "ollama", "reason": e }))),
    }
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ModelBody {
    model: String,
}

pub async fn ollama_pull(
    req: HttpRequest,
    instance: web::types::Path<String>,
    body: web::types::Json<ModelBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, "inference ollama pull").await {
        Ok(g) => g,
        Err(refusal) => return Ok(refusal),
    };
    if !sbm_parser::inference::valid_model(&body.model) {
        return Ok(refused(400, "invalidModel"));
    }
    let base = match instance_base(&state, &instance).await {
        Ok(b) => b,
        Err(r) => return Ok(r),
    };
    match state.inference.ollama.pull(&instance, &base, &body.model) {
        Ok(()) => {
            audit(&state, &gated, Outcome::Ok, format!("inference: ollama pull {}", body.model)).await;
            Ok(HttpResponse::Accepted().json(&json!({ "pulls": state.inference.ollama.pulls() })))
        }
        Err(e) => Ok(refused(409, e)),
    }
}

pub async fn ollama_delete(
    req: HttpRequest,
    instance: web::types::Path<String>,
    body: web::types::Json<ModelBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let gated = match machine::gate(&req, &state, "inference ollama delete").await {
        Ok(g) => g,
        Err(refusal) => return Ok(refusal),
    };
    let base = match instance_base(&state, &instance).await {
        Ok(b) => b,
        Err(r) => return Ok(r),
    };
    match state.inference.ollama.delete(&base, &body.model).await {
        Ok(()) => {
            audit(&state, &gated, Outcome::Ok, format!("inference: ollama delete {}", body.model)).await;
            Ok(HttpResponse::NoContent().finish())
        }
        Err(e) if e == "notFound" => Ok(refused(404, "notFound")),
        Err(e) => Ok(HttpResponse::BadGateway().json(&json!({ "error": "ollama", "reason": e }))),
    }
}
