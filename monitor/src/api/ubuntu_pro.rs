//! `/api/v1/ubuntu-pro*`: Ubuntu Pro through its client
//! (`sbm_parser::ubuntu_pro`). Linux only; Ubuntu only, said in the view.
//!
//! - `GET /ubuntu-pro`: attached or not, the account, contract and expiry,
//!   the services, Livepatch's state, the job.
//! - `POST /ubuntu-pro/act`: `{action, …, token?, sudo_password}`, one
//!   [`Action`], checked against a fresh read, run as root as a job
//!   (`GET /ubuntu-pro/job`). An attach's token goes into a file only the
//!   agent's account and root can read, kept until the job ends; the script,
//!   which the job logs, names its path, and the audit never has it.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use super::authz;
use super::server::AppState;
use super::shares::{as_root, record};
use crate::stacks::job::{JobKind, JobState};
use sbm_parser::ubuntu_pro::{self as pro, Action};

async fn read(state: &AppState) -> Option<pro::ProView> {
    let limits = super::machine::at_least(&state.remote_access.exec, 4 << 20);
    match super::exec::run(pro::READ_COMMAND, None, None, &limits).await {
        Ok(out) if !out.timed_out => Some(pro::parse(&out.stdout)),
        Ok(_) => None,
        Err(e) => {
            tracing::warn!("ubuntu pro: reading did not run: {e}");
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
    body["job"] = state.ubuntu_pro.current().map(|j| serde_json::to_value(j.view(0)).unwrap_or_default()).unwrap_or_default();
    Ok(HttpResponse::Ok().json(&body))
}

#[derive(Deserialize)]
pub struct ActBody {
    #[serde(flatten)]
    action: Action,
    #[serde(default)]
    token: Option<String>,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn act(req: HttpRequest, body: web::types::Json<ActBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let ActBody { action, token, sudo_password } = body.into_inner();
    let Some(now) = read(&state).await else { return Ok(super::respond::error_u16(502, "unreadable")) };
    if let Err(e) = pro::check(&now, &action) {
        return Ok(super::respond::error_u16(409, e));
    }
    #[cfg(unix)]
    let config = if matches!(action, Action::Attach { .. }) {
        let Some(text) = token.as_deref().map(str::trim).and_then(pro::attach_config) else {
            return Ok(super::respond::error_u16(400, "invalidToken"));
        };
        match super::machine::PrivateScript::write(&text) {
            Ok(file) => Some(file),
            Err(e) => {
                tracing::warn!("ubuntu pro: writing the attach configuration: {e}");
                return Ok(super::respond::error_u16(500, "internal"));
            }
        }
    } else {
        None
    };
    // Never reached: anywhere but Linux was answered `notLinux` above.
    #[cfg(not(unix))]
    let config: Option<std::convert::Infallible> = {
        let _ = token;
        None
    };
    #[cfg(unix)]
    let config_path = config.as_ref().map(|c| c.path().to_string_lossy().into_owned());
    #[cfg(not(unix))]
    let config_path: Option<String> = None;
    let script = match pro::script(&action, config_path.as_deref()) {
        Ok(s) => s,
        Err(e) => return Ok(super::respond::error_u16(400, e)),
    };
    let password = sudo_password.unwrap_or_default();
    // Tried first, so a wrong password is said here rather than in a log.
    require!(as_root(&state, "true", Some(&password).filter(|p| !p.is_empty()).map(String::as_str), false).await);
    let Some(job) = state.ubuntu_pro.begin(JobKind::UbuntuPro) else { return Ok(super::respond::error_u16(409, "busy")) };
    let detail = match &action {
        Action::InstallClient => "ubuntu pro install client".to_string(),
        Action::Attach { auto_enable } => format!("ubuntu pro attach{}", if *auto_enable { " with recommended services" } else { "" }),
        Action::Detach => "ubuntu pro detach".to_string(),
        Action::Enable { service } => format!("ubuntu pro enable {service}"),
        Action::Disable { service } => format!("ubuntu pro disable {service}"),
    };
    record(&req, &state, detail).await;
    let job2 = job.clone();
    tokio::spawn(async move {
        let result = job2.run_root(&script, &password).await;
        // The token's file goes once the job has read it.
        drop(config);
        match result {
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
    match state.ubuntu_pro.current() {
        Some(job) => Ok(HttpResponse::Ok().json(&job.view(query.since))),
        None => Ok(super::respond::error_u16(404, "notFound")),
    }
}
