//! `/api/v1/tailscale*`: Tailscale on this machine (`sbm_parser::tailscale`).
//! Linux only.
//!
//! - `GET /tailscale`: installed, the daemon, signed in or the URL a
//!   sign-in waits on, this device, its peers, its settings, the job.
//! - `POST /tailscale/act`: `{action, …, auth_key?, sudo_password}`, one
//!   [`Action`], checked against a fresh read, run as root as a job
//!   (`GET /tailscale/job`). A sign-in without a key waits in the job
//!   until its URL (in `GET /tailscale`) is opened. An auth key goes into a
//!   file only the agent's account and root can read, kept until the job
//!   ends; neither the script nor the audit has it.
//! - `POST /tailscale/ping`: `{ip}`, how a peer is reached (any account's).

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use super::authz;
use super::server::AppState;
use super::shares::{as_root, record};
use crate::stacks::job::{JobKind, JobState};
use sbm_parser::tailscale::{self as ts, Action};

/// The view and the OS release it was read on (Tailscale's repository is
/// named by them).
async fn read(state: &AppState) -> Option<(ts::TailscaleView, String, String)> {
    let limits = super::machine::at_least(&state.remote_access.exec, 4 << 20);
    match super::exec::run(ts::READ_COMMAND, None, None, &limits).await {
        Ok(out) if !out.timed_out => {
            let mut os = out.stdout.split("### os\n").nth(1).unwrap_or("").lines().map(|l| l.trim().to_string());
            let (id, codename) = (os.next().unwrap_or_default(), os.next().unwrap_or_default());
            Some((ts::parse(&out.stdout), id, codename))
        }
        Ok(_) => None,
        Err(e) => {
            tracing::warn!("tailscale: reading did not run: {e}");
            None
        }
    }
}

pub async fn view(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let Some((v, _, _)) = read(&state).await else { return Ok(super::respond::error_u16(502, "unreadable")) };
    let mut body = serde_json::to_value(&v).unwrap_or_default();
    body["job"] = state.tailscale.current().map(|j| serde_json::to_value(j.view(0)).unwrap_or_default()).unwrap_or_default();
    Ok(HttpResponse::Ok().json(&body))
}

#[derive(Deserialize)]
pub struct ActBody {
    #[serde(flatten)]
    action: Action,
    #[serde(default)]
    auth_key: Option<String>,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn act(req: HttpRequest, body: web::types::Json<ActBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let ActBody { action, auth_key, sudo_password } = body.into_inner();
    let Some((now, os, codename)) = read(&state).await else { return Ok(super::respond::error_u16(502, "unreadable")) };
    if let Err(e) = ts::check(&now, &action) {
        return Ok(super::respond::error_u16(409, e));
    }
    let key = auth_key.map(|k| k.trim().to_string()).filter(|k| !k.is_empty());
    if key.as_deref().is_some_and(|k| !ts::auth_key_ok(k)) {
        return Ok(super::respond::error_u16(400, "invalidAuthKey"));
    }
    #[cfg(unix)]
    let key_file = match (&action, key) {
        (Action::Login { .. }, Some(k)) => match super::machine::PrivateScript::write(&k) {
            Ok(file) => Some(file),
            Err(e) => {
                tracing::warn!("tailscale: writing the auth key file: {e}");
                return Ok(super::respond::error_u16(500, "internal"));
            }
        },
        _ => None,
    };
    // Never reached: anywhere but Linux was answered `notLinux` above.
    #[cfg(not(unix))]
    let key_file: Option<std::convert::Infallible> = {
        let _ = key;
        None
    };
    #[cfg(unix)]
    let key_path = key_file.as_ref().map(|f| f.path().to_string_lossy().into_owned());
    #[cfg(not(unix))]
    let key_path: Option<String> = None;
    let script = match ts::script(&action, &now, &os, &codename, key_path.as_deref()) {
        Ok(s) => s,
        Err(e) => return Ok(super::respond::error_u16(400, e)),
    };
    let password = sudo_password.unwrap_or_default();
    // Tried first, so a wrong password is said here rather than in a log.
    require!(as_root(&state, "true", Some(&password).filter(|p| !p.is_empty()).map(String::as_str), false).await);
    let Some(job) = state.tailscale.begin(JobKind::Tailscale) else { return Ok(super::respond::error_u16(409, "busy")) };
    let detail = match &action {
        Action::Install => "tailscale install".to_string(),
        Action::StartDaemon => "tailscale start daemon".to_string(),
        Action::Login { login_server, .. } => format!(
            "tailscale login{}{}",
            login_server.as_deref().filter(|s| !s.is_empty()).map(|s| format!(" to {s}")).unwrap_or_default(),
            if key_path.is_some() { " with an auth key" } else { "" }
        ),
        Action::Logout => "tailscale logout".to_string(),
        Action::Connect => "tailscale up".to_string(),
        Action::Disconnect => "tailscale down".to_string(),
        Action::Set { .. } => "tailscale set".to_string(),
    };
    record(&req, &state, detail).await;
    let job2 = job.clone();
    tokio::spawn(async move {
        let result = job2.run_root(&script, &password).await;
        // The key's file goes once the job has read it.
        drop(key_file);
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
    match state.tailscale.current() {
        Some(job) => Ok(HttpResponse::Ok().json(&job.view(query.since))),
        None => Ok(super::respond::error_u16(404, "notFound")),
    }
}

/// A sign-in waiting on its URL is stopped here (the job's process group).
pub async fn cancel(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if let Some(job) = state.tailscale.current() {
        job.cancel();
    }
    Ok(HttpResponse::NoContent().finish())
}

#[derive(Deserialize)]
pub struct PingBody {
    ip: String,
}

pub async fn ping(req: HttpRequest, body: web::types::Json<PingBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    let Some(command) = ts::ping_command(body.ip.trim()) else { return Ok(super::respond::error_u16(400, "invalidIp")) };
    let limits = super::machine::at_least(&state.remote_access.exec, 64 << 10);
    match super::exec::run(&command, None, None, &limits).await {
        Ok(out) => Ok(HttpResponse::Ok().json(&serde_json::json!({ "ok": out.exit_code == Some(0), "output": out.stdout.trim() }))),
        Err(e) => {
            tracing::warn!("tailscale ping did not run: {e}");
            Ok(super::respond::error_u16(502, "unreadable"))
        }
    }
}
