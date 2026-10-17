//! `/api/v1/kernel*`: the machine's Linux kernels (`sbm_parser::kernel`):
//! Debian and Ubuntu with GRUB. Linux only.
//!
//! - `GET /kernel`: the running kernel, the installed ones, which GRUB
//!   boots, the series and versions the archive offers, the job.
//! - `POST /kernel/act`: `{action, …, sudo_password}`, one [`Action`],
//!   checked against a fresh read, run as root as a job (`GET /kernel/job`).
//!   A new kernel runs after a restart (`/power`).

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use super::authz;
use super::server::AppState;
use super::shares::{as_root, record};
use crate::stacks::job::{JobKind, JobState};
use sbm_parser::kernel::{self as kn, Action};

async fn read(state: &AppState) -> Option<kn::KernelView> {
    let limits = super::machine::at_least(&state.remote_access.exec, 8 << 20);
    match super::exec::run(kn::READ_COMMAND, None, None, &limits).await {
        Ok(out) if !out.timed_out => Some(kn::parse(&out.stdout)),
        Ok(_) => None,
        Err(e) => {
            tracing::warn!("kernel: reading did not run: {e}");
            None
        }
    }
}

pub async fn view(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let Some(v) = read(&state).await else { return Ok(super::respond::error_u16(502, "unreadable")) };
    let mut body = serde_json::to_value(&v).unwrap_or_default();
    body["job"] = state.kernel.current().map(|j| serde_json::to_value(j.view(0)).unwrap_or_default()).unwrap_or_default();
    Ok(HttpResponse::Ok().json(&body))
}

#[derive(Deserialize)]
pub struct ActBody {
    #[serde(flatten)]
    action: Action,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn act(req: HttpRequest, body: web::types::Json<ActBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let ActBody { action, sudo_password } = body.into_inner();
    let Some(now) = read(&state).await else { return Ok(super::respond::error_u16(502, "unreadable")) };
    if let Err(e) = kn::check(&now, &action) {
        return Ok(super::respond::error_u16(409, e));
    }
    let password = sudo_password.unwrap_or_default();
    // Tried first, so a wrong password is said here rather than in a log.
    require!(as_root(&state, "true", Some(&password).filter(|p| !p.is_empty()).map(String::as_str), false).await);
    let Some(job) = state.kernel.begin(JobKind::Kernel) else { return Ok(super::respond::error_u16(409, "busy")) };
    let detail = match &action {
        Action::Install { package } => format!("kernel install {package}"),
        Action::Remove { release } => format!("kernel remove {release}"),
        Action::Boot { release, once } => format!("kernel boot {release}{}", if *once { " once" } else { "" }),
        Action::BootNewest => "kernel boot newest".to_string(),
    };
    record(&req, &state, detail).await;
    let script = kn::script(&action);
    let job2 = job.clone();
    tokio::spawn(async move {
        match job2.run_root(&script, &password).await {
            Ok(()) => job2.finish(JobState::Succeeded, None),
            Err(e) => {
                job2.push(format!("✕ {e}"));
                job2.finish(if e == "cancelled" { JobState::Cancelled } else { JobState::Failed }, Some(e));
            }
        }
    });
    Ok(HttpResponse::Accepted().json(&job.view(0)))
}

#[derive(Deserialize)]
pub struct JobQuery {
    #[serde(default)]
    since: u64,
}

pub async fn job(req: HttpRequest, query: web::types::Query<JobQuery>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    match state.kernel.current() {
        Some(job) => Ok(HttpResponse::Ok().json(&job.view(query.since))),
        None => Ok(super::respond::error_u16(404, "notFound")),
    }
}
