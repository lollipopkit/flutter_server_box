//! `/api/v1/shares*` — the machine's SMB and NFS shares (`sbm_parser::shares`).
//! Linux.
//!
//! - `GET /shares`: what is installed and running, every SMB share and NFS
//!   export (`managed`: ServerBox's, in its own files), the install job.
//! - `PUT /shares/smb`: `{shares, sudo_password}`, every share ServerBox
//!   keeps; `PUT /shares/nfs`: `{exports, sudo_password}`, the same for
//!   exports. Written as root and checked before they take effect; answers
//!   the shares as they are then. `notAFolder` (409, `path`) for a path that
//!   is not a folder, `refused` (409, `detail`) when Samba or `exportfs`
//!   refuses the result (the previous file is back).
//! - `POST /shares/smb/password`: `{user, password, sudo_password}`, an
//!   account's SMB password (Samba keeps its own), run so the password is
//!   on no command line (`machine::as_root_private`).
//! - `POST /shares/connections`: `{sudo_password?}`, who is connected now
//!   (`smbstatus` needs root: without a password `sudo -n`, else
//!   `sudo_rejected`).
//! - `POST /shares/install`: `{nfs, sudo_password}`, Samba or the NFS server
//!   installed as a job; `GET /shares/job?since=<seq>`.
//!
//! Every change is audited (`Kind::Machine`), never a password.

use std::sync::{Arc, Mutex};

use ntex::web::{self, HttpRequest, HttpResponse};
use sbm_parser::shares::{self as sh, NfsExport, SmbShare};
use serde::Deserialize;
use serde_json::json;

use super::authz;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::stacks::job::{Job, JobKind, JobState};

macro_rules! require {
    ($result:expr) => {{
        match $result {
            Ok(value) => value,
            Err(response) => return Ok(response),
        }
    }};
}

/// The install running or last run.
#[derive(Default)]
pub struct SharesJobs {
    job: Mutex<Option<Arc<Job>>>,
}

impl SharesJobs {
    fn job(&self) -> Option<Arc<Job>> {
        self.job.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }

    fn begin(&self) -> Option<Arc<Job>> {
        let mut job = self.job.lock().unwrap_or_else(|e| e.into_inner());
        if job.as_ref().is_some_and(|j| j.running()) {
            return None;
        }
        let next = Arc::new(Job::new(JobKind::Shares));
        *job = Some(next.clone());
        Some(next)
    }
}

fn refused(status: u16, error: &str) -> HttpResponse {
    HttpResponse::build(ntex::http::StatusCode::from_u16(status).unwrap_or(ntex::http::StatusCode::BAD_REQUEST))
        .json(&json!({ "error": error }))
}

async fn read(state: &AppState) -> Option<sh::Shares> {
    let limits = super::machine::at_least(&state.remote_access.exec, 4 << 20);
    match super::exec::run(sh::READ_COMMAND, None, None, &limits).await {
        Ok(out) if !out.timed_out => Some(sh::parse(&out.stdout)),
        Ok(_) => None,
        Err(e) => {
            tracing::warn!("shares: reading did not run: {e}");
            None
        }
    }
}

fn answer(shares: sh::Shares, job: Option<serde_json::Value>) -> HttpResponse {
    let mut body = serde_json::to_value(shares).unwrap_or_default();
    body["job"] = job.unwrap_or(serde_json::Value::Null);
    HttpResponse::Ok().json(&body)
}

pub async fn view(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let Some(shares) = read(&state).await else { return Ok(refused(502, "unreadable")) };
    let job = state.shares.job().map(|j| serde_json::to_value(j.view(0)).unwrap_or_default());
    Ok(answer(shares, job))
}

/// Runs [script] as root and says how it went the way the endpoints answer.
async fn as_root(state: &AppState, script: &str, password: Option<&str>, private: bool) -> Result<(), HttpResponse> {
    let exec = &state.remote_access.exec;
    let out = if private { super::machine::as_root_private(script, password, exec).await } else { super::machine::as_root(script, password, exec).await };
    match out {
        Ok(out) if out.exit_code == Some(0) => Ok(()),
        Ok(out) if sbm_parser::script::sudo_password_rejected(&out.stderr) => Err(refused(403, "sudo_rejected")),
        Ok(out) if out.exit_code == Some(sh::EXIT_NOT_A_FOLDER) => {
            Err(HttpResponse::Conflict().json(&json!({ "error": "notAFolder", "path": out.stderr.lines().next().unwrap_or("").trim() })))
        }
        Ok(out) => {
            let detail: String = out.stderr.lines().rev().find(|l| !l.trim().is_empty()).unwrap_or("").trim().chars().take(300).collect();
            tracing::warn!(exit = ?out.exit_code, %detail, "shares: change failed");
            let error = if out.exit_code == Some(sh::EXIT_REFUSED) { "refused" } else { "failed" };
            Err(HttpResponse::Conflict().json(&json!({ "error": error, "detail": detail })))
        }
        Err(e) => {
            tracing::warn!("shares: change did not run: {e}");
            Err(refused(403, "sudo_unavailable"))
        }
    }
}

fn record(req: &HttpRequest, state: &AppState, detail: String) -> impl std::future::Future<Output = ()> {
    let event = Event::new(Kind::Machine, Action::Write, Outcome::Ok).remote_ip(peer_ip(req)).detail(detail);
    let db = state.db.clone();
    async move { event.record(&db).await }
}

#[derive(Deserialize)]
pub struct SmbBody {
    shares: Vec<SmbShare>,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn set_smb(req: HttpRequest, body: web::types::Json<SmbBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let SmbBody { shares, sudo_password } = body.into_inner();
    let script = match sh::smb_script(&shares) {
        Ok(s) => s,
        Err(e) => return Ok(refused(400, e.code())),
    };
    require!(as_root(&state, &script, sudo_password.as_deref().filter(|p| !p.is_empty()), false).await);
    let names: Vec<&str> = shares.iter().map(|s| s.name.as_str()).collect();
    record(&req, &state, format!("shares smb {}", names.join(","))).await;
    let Some(now) = read(&state).await else { return Ok(refused(502, "unreadable")) };
    Ok(answer(now, None))
}

#[derive(Deserialize)]
pub struct NfsBody {
    exports: Vec<NfsExport>,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn set_nfs(req: HttpRequest, body: web::types::Json<NfsBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let NfsBody { exports, sudo_password } = body.into_inner();
    let script = match sh::nfs_script(&exports) {
        Ok(s) => s,
        Err(e) => return Ok(refused(400, e.code())),
    };
    require!(as_root(&state, &script, sudo_password.as_deref().filter(|p| !p.is_empty()), false).await);
    let paths: Vec<&str> = exports.iter().map(|e| e.path.as_str()).collect();
    record(&req, &state, format!("shares nfs {}", paths.join(","))).await;
    let Some(now) = read(&state).await else { return Ok(refused(502, "unreadable")) };
    Ok(answer(now, None))
}

#[derive(Deserialize)]
pub struct PasswordBody {
    user: String,
    password: String,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn smb_password(req: HttpRequest, body: web::types::Json<PasswordBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let PasswordBody { user, password, sudo_password } = body.into_inner();
    let script = match sh::smb_password_script(&user, &password) {
        Ok(s) => s,
        Err(e) => return Ok(refused(400, e.code())),
    };
    require!(as_root(&state, &script, sudo_password.as_deref().filter(|p| !p.is_empty()), true).await);
    record(&req, &state, format!("shares smb password {user}")).await;
    Ok(HttpResponse::NoContent().finish())
}

#[derive(Deserialize)]
pub struct ConnectionsBody {
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn connections(req: HttpRequest, body: web::types::Json<ConnectionsBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let password = body.into_inner().sudo_password.filter(|p| !p.is_empty());
    let limits = super::machine::at_least(&state.remote_access.exec, 4 << 20);
    match super::machine::as_root(sh::CONNECTIONS_COMMAND, password.as_deref(), &limits).await {
        Ok(out) if out.exit_code == Some(0) => Ok(HttpResponse::Ok().json(&sh::parse_connections(&out.stdout))),
        Ok(out) if sbm_parser::script::sudo_password_rejected(&out.stderr) => Ok(refused(403, "sudo_rejected")),
        _ => Ok(refused(403, "sudo_unavailable")),
    }
}

#[derive(Deserialize)]
pub struct InstallBody {
    #[serde(default)]
    nfs: bool,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn install(req: HttpRequest, body: web::types::Json<InstallBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let InstallBody { nfs, sudo_password } = body.into_inner();
    let password = sudo_password.unwrap_or_default();
    // Tried first, so a wrong password is said here rather than in a log.
    require!(as_root(&state, "true", Some(&password).filter(|p| !p.is_empty()).map(String::as_str), false).await);
    let Some(job) = state.shares.begin() else { return Ok(refused(409, "busy")) };
    let what = if nfs { "nfs" } else { "samba" };
    record(&req, &state, format!("shares install {what}")).await;
    let script = sh::install_script(nfs);
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
    match state.shares.job() {
        Some(job) => Ok(HttpResponse::Ok().json(&job.view(query.since))),
        None => Ok(refused(404, "notFound")),
    }
}
