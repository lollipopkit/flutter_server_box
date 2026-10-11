//! `/api/v1/storage*` — the machine's disks, RAID arrays and ZFS pools, and
//! changes to them (`sbm_parser::storage`). Linux; admin.
//!
//! - `GET /storage`: every block device as a tree (filesystems, mounts,
//!   usage), why each is in use (`busy`, `storage::in_use`), the devices
//!   mounted where the system lives (`system`, never unmounted), the md arrays
//!   (`/proc/mdstat`), the pools (`zpool`), which tools are installed, the
//!   last SMART reading (`health`, null until one is made).
//! - `POST /storage/health`: `{sudo_password?}`, reads every disk's SMART
//!   as root (`storage::HEALTH_COMMAND`) and keeps it for `GET /storage`.
//!   Without a password `sudo -n`: enough for a root agent or a `NOPASSWD`
//!   rule, else `sudo_rejected` (403). A self-test started here is read
//!   again when its job ends, with the password it was started with.
//! - `POST /storage/act`: `{action…, sudo_password}`, one
//!   `StorageAction`, checked against a fresh device listing (nothing in use
//!   is partitioned, formatted or built on) and the sudo password tried
//!   first; then run as root as a job (202). `sudo_rejected` (403) when the
//!   password is not sudo's; `systemMount` / `notMounted` (409) for an
//!   unmount of the system's mount or of nothing.
//! - `GET /storage/job?since=<seq>`.
//! - `PUT /storage/maintenance`, `POST /storage/maintenance/{task}/run`: the
//!   maintenance schedule (`storage_watch`), answered in `GET /storage` as
//!   `maintenance`. Growing an array is refused (`notGrowable`) but for RAID
//!   1, 5 and 6; expanding a filesystem but for a mounted ext2/3/4, xfs or
//!   btrfs (`storage::growable`).
//!
//! Every change is audited (`Kind::Machine`), never the password.

use std::sync::{Arc, Mutex};

use ntex::web::{self, HttpRequest, HttpResponse};
use sbm_parser::storage::{self as st, StorageAction};
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

/// The storage change running or last run: one at a time. And the last
/// SMART reading, which needs root and so is not made on every page load.
#[derive(Default)]
pub struct StorageJobs {
    job: Mutex<Option<Arc<Job>>>,
    health: Mutex<Option<HealthReading>>,
    seen: Mutex<crate::storage_watch::Seen>,
}

#[derive(Clone, serde::Serialize)]
pub struct HealthReading {
    /// Unix seconds.
    pub at: u64,
    pub disks: Vec<st::DiskHealth>,
}

impl StorageJobs {
    pub fn job(&self) -> Option<Arc<Job>> {
        self.job.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }

    pub fn health(&self) -> Option<HealthReading> {
        self.health.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }

    pub(crate) fn seen(&self) -> std::sync::MutexGuard<'_, crate::storage_watch::Seen> {
        self.seen.lock().unwrap_or_else(|e| e.into_inner())
    }

    pub(crate) fn keep_health(&self, disks: Vec<st::DiskHealth>) -> HealthReading {
        let at = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
        let reading = HealthReading { at, disks };
        *self.health.lock().unwrap_or_else(|e| e.into_inner()) = Some(reading.clone());
        reading
    }

    fn begin(&self) -> Option<Arc<Job>> {
        let mut job = self.job.lock().unwrap_or_else(|e| e.into_inner());
        if job.as_ref().is_some_and(|j| j.running()) {
            return None;
        }
        let next = Arc::new(Job::new(JobKind::Storage));
        *job = Some(next.clone());
        Some(next)
    }
}

fn refused(status: u16, error: &str) -> HttpResponse {
    HttpResponse::build(ntex::http::StatusCode::from_u16(status).unwrap_or(ntex::http::StatusCode::BAD_REQUEST))
        .json(&json!({ "error": error }))
}

/// The machine's storage as it is now (`storage::parse_view`).
async fn read_view(state: &AppState) -> Option<st::StorageView> {
    let limits = super::machine::at_least(&state.remote_access.exec, 8 << 20);
    match super::exec::run(&st::view_command(), None, None, &limits).await {
        Ok(out) if !out.timed_out => {
            let view = st::parse_view(&out.stdout);
            if view.is_none() {
                tracing::warn!(exit = ?out.exit_code, stderr = %out.stderr.trim(), "storage: lsblk answered nothing");
            }
            view
        }
        Ok(_) => {
            tracing::warn!("storage: reading the disks timed out");
            None
        }
        Err(e) => {
            tracing::warn!("storage: reading the disks did not run: {e}");
            None
        }
    }
}

/// The arrays and pools as they are now.
pub(crate) async fn arrays_and_pools(state: &AppState) -> (Vec<st::MdArray>, Vec<st::Pool>) {
    let arrays = std::fs::read_to_string("/proc/mdstat").map(|t| st::parse_mdstat(&t)).unwrap_or_default();
    let limits = super::machine::at_least(&state.remote_access.exec, 4 << 20);
    let mut pools = Vec::new();
    if let Ok(out) = super::exec::run(st::ZPOOL_LIST_COMMAND, None, None, &limits).await
        && out.exit_code == Some(0)
    {
        pools = st::parse_zpool_list(&out.stdout);
        if !pools.is_empty()
            && let Ok(out) = super::exec::run(st::ZPOOL_STATUS_COMMAND, None, None, &limits).await
        {
            st::merge_zpool_status(&mut pools, &out.stdout);
        }
    }
    (arrays, pools)
}

pub async fn view(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let Some(v) = read_view(&state).await else { return Ok(refused(502, "unreadable")) };
    let job = state.storage.job().map(|j| j.view(u64::MAX));
    let health = state.storage.health();
    let maintenance = crate::storage_watch::tasks(&state.db).await;
    Ok(HttpResponse::Ok().json(&json!({
        "disks": v.disks, "busy": v.busy, "system": v.system, "arrays": v.arrays, "pools": v.pools, "tools": v.tools, "job": job, "health": health,
        "maintenance": maintenance,
        // Who a sudoers rule for the schedule names.
        "account": std::env::var("USER").ok(),
    })))
}

/// Every disk's SMART as root; `Err` is sudo's refusal, as `act` answers it.
async fn read_health(state: &AppState, password: Option<&str>) -> Result<HealthReading, &'static str> {
    let limits = super::machine::at_least(&state.remote_access.exec, 16 << 20);
    match super::machine::as_root(st::HEALTH_COMMAND, password, &limits).await {
        Ok(out) if out.exit_code == Some(0) => Ok(state.storage.keep_health(st::parse_health(&out.stdout))),
        Ok(out) if sbm_parser::script::sudo_password_rejected(&out.stderr) => Err("sudo_rejected"),
        Ok(out) => {
            tracing::warn!(exit = ?out.exit_code, timed_out = out.timed_out, stderr = %out.stderr.trim(), "storage: SMART read failed");
            Err("sudo_unavailable")
        }
        Err(e) => {
            tracing::warn!("storage: SMART read did not run: {e}");
            Err("sudo_unavailable")
        }
    }
}

#[derive(Deserialize)]
pub struct HealthBody {
    #[serde(default)]
    sudo_password: Option<String>,
}

#[derive(Deserialize)]
pub struct MaintenancePath {
    task: String,
}

/// `PUT /storage/maintenance`: one task's schedule (`storage_watch::SetTask`);
/// answers them all.
pub async fn set_maintenance(
    req: HttpRequest,
    body: web::types::Json<crate::storage_watch::SetTask>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    let next = body.into_inner();
    let what = format!("storage maintenance {} {}", next.task, next.every.as_deref().unwrap_or("off"));
    match crate::storage_watch::set_task(&state, &caller.username, next).await {
        Ok(tasks) => {
            Event::new(Kind::Machine, Action::Write, Outcome::Ok).subject(&caller.username).remote_ip(peer_ip(&req)).detail(what).record(&state.db).await;
            Ok(HttpResponse::Ok().json(&json!({ "maintenance": tasks })))
        }
        Err(r) => Ok(refused(r.status, r.error)),
    }
}

/// `POST /storage/maintenance/{task}/run`: now, unattended as the schedule
/// runs it; answers them all, its `last_error` saying how it went.
pub async fn run_maintenance(
    req: HttpRequest,
    path: web::types::Path<MaintenancePath>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let Some(task) = st::Maintenance::from_name(&path.task) else { return Ok(refused(404, "notFound")) };
    if !crate::storage_watch::tasks(&state.db).await.iter().any(|t| t.task == path.task) {
        return Ok(refused(409, "notScheduled"));
    }
    Event::new(Kind::Machine, Action::Write, Outcome::Ok)
        .subject(&caller.username)
        .remote_ip(peer_ip(&req))
        .detail(format!("storage maintenance {} run", task.name()))
        .record(&state.db)
        .await;
    let _ = crate::storage_watch::run_task(state.get_ref(), task).await;
    Ok(HttpResponse::Ok().json(&json!({ "maintenance": crate::storage_watch::tasks(&state.db).await })))
}

pub async fn health(req: HttpRequest, body: web::types::Json<HealthBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let password = body.into_inner().sudo_password.filter(|p| !p.is_empty());
    match read_health(&state, password.as_deref()).await {
        Ok(reading) => Ok(HttpResponse::Ok().json(&reading)),
        Err(why) => Ok(refused(403, why)),
    }
}

#[derive(Deserialize)]
pub struct ActBody {
    #[serde(flatten)]
    action: StorageAction,
    #[serde(default)]
    sudo_password: Option<String>,
    /// A LUKS passphrase, for an encrypted format or an unlock; never logged.
    #[serde(default)]
    passphrase: Option<String>,
}

pub async fn act(req: HttpRequest, body: web::types::Json<ActBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let ActBody { action, sudo_password, passphrase } = body.into_inner();
    // The passphrase reaches cryptsetup as a key file only the agent's
    // account and root can read, kept until the job ends; the script, which
    // the job logs, names its path.
    let key = if action.needs_key() {
        let Some(p) = passphrase.filter(|p| st::passphrase_ok(p)) else {
            return Ok(refused(400, "invalidPassphrase"));
        };
        #[cfg(unix)]
        match super::machine::PrivateScript::write(&p) {
            Ok(file) => Some(file),
            Err(e) => {
                tracing::warn!("storage: writing the key file: {e}");
                return Ok(refused(500, "internal"));
            }
        }
        #[cfg(not(unix))]
        return Ok(refused(409, "notLinux"));
    } else {
        None
    };
    #[cfg(unix)]
    let key_path = key.as_ref().map(|k| k.path().to_string_lossy().into_owned());
    #[cfg(not(unix))]
    let key_path: Option<String> = None;
    let script = match action.script_with_key(key_path.as_deref()) {
        Ok(s) => s,
        Err(e) => return Ok(refused(400, e.code())),
    };
    // Decided on what the machine has now, not on what a page saw.
    let Some(v) = read_view(&state).await else { return Ok(refused(502, "unreadable")) };
    if let Err(r) = st::check(&v, &action) {
        let status = ntex::http::StatusCode::from_u16(r.status).unwrap_or(ntex::http::StatusCode::BAD_REQUEST);
        let body = match (&r.device, &r.why) {
            (Some(device), Some(why)) => json!({ "error": r.error, "device": device, "why": why }),
            _ => json!({ "error": r.error }),
        };
        return Ok(HttpResponse::build(status).json(&body));
    }
    let password = sudo_password.unwrap_or_default();
    let tried = super::machine::as_root("true", Some(&password).filter(|p| !p.is_empty()).map(String::as_str), &state.remote_access.exec).await;
    match tried {
        Ok(out) if out.exit_code == Some(0) => {}
        Ok(out) if sbm_parser::script::sudo_password_rejected(&out.stderr) => return Ok(refused(403, "sudo_rejected")),
        _ => return Ok(refused(403, "sudo_unavailable")),
    }
    let Some(job) = state.storage.begin() else { return Ok(refused(409, "busy")) };
    let what = serde_json::to_string(&action).unwrap_or_default();
    let reread = matches!(action, StorageAction::SmartTest { .. });
    Event::new(Kind::Machine, Action::Write, Outcome::Ok)
        .subject(&caller.username)
        .remote_ip(peer_ip(&req))
        .detail(format!("storage {what}"))
        .record(&state.db)
        .await;
    let (state2, job2, username) = (state.get_ref().clone(), job.clone(), caller.username.clone());
    tokio::spawn(async move {
        let result = job2.run_root(&script, &password).await;
        drop(key);
        let outcome = if result.is_ok() { Outcome::Ok } else { Outcome::Error };
        match &result {
            Ok(()) => job2.finish(JobState::Succeeded, None),
            Err(e) => {
                job2.push(format!("✕ {e}"));
                job2.finish(if e == "cancelled" { JobState::Cancelled } else { JobState::Failed }, Some(e.clone()));
            }
        }
        // The test's progress, read while the password is still at hand.
        if reread && result.is_ok() {
            let _ = read_health(&state2, Some(&password).filter(|p| !p.is_empty()).map(String::as_str)).await;
        }
        Event::new(Kind::Machine, Action::Write, outcome)
            .subject(&username)
            .detail(format!("storage {what} {}", if result.is_ok() { "done" } else { "failed" }))
            .record(&state2.db)
            .await;
    });
    Ok(HttpResponse::Accepted().json(&job.view(0)))
}

#[derive(Deserialize)]
pub struct JobQuery {
    #[serde(default)]
    since: u64,
}

pub async fn job(req: HttpRequest, query: web::types::Query<JobQuery>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
    match state.storage.job() {
        Some(job) => Ok(HttpResponse::Ok().json(&job.view(query.since))),
        None => Ok(refused(404, "notFound")),
    }
}
