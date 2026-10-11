//! `/api/v1/storage*` — the machine's disks, RAID arrays and ZFS pools, and
//! changes to them (`sbm_parser::storage`). Linux; admin.
//!
//! - `GET /storage`: every block device as a tree (filesystems, mounts,
//!   usage), why each is in use (`busy`, `storage::in_use`), the devices
//!   mounted where the system lives (`system`, never unmounted), the md arrays
//!   (`/proc/mdstat`), the pools (`zpool`), which tools are installed.
//! - `POST /storage/act`: `{action…, sudo_password}`, one
//!   `StorageAction`, checked against a fresh device listing (nothing in use
//!   is partitioned, formatted or built on) and the sudo password tried
//!   first; then run as root as a job (202). `sudo_rejected` (403) when the
//!   password is not sudo's; `systemMount` / `notMounted` (409) for an
//!   unmount of the system's mount or of nothing.
//! - `GET /storage/job?since=<seq>`.
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

/// The storage change running or last run: one at a time.
#[derive(Default)]
pub struct StorageJobs {
    job: Mutex<Option<Arc<Job>>>,
}

impl StorageJobs {
    pub fn job(&self) -> Option<Arc<Job>> {
        self.job.lock().unwrap_or_else(|e| e.into_inner()).clone()
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

async fn devices(state: &AppState) -> Option<Vec<st::BlockDevice>> {
    let limits = super::machine::at_least(&state.remote_access.exec, 4 << 20);
    match super::exec::run(st::LSBLK_COMMAND, None, None, &limits).await {
        Ok(out) if out.exit_code == Some(0) => Some(st::parse_lsblk(&out.stdout)),
        Ok(out) => {
            tracing::warn!(exit = ?out.exit_code, timed_out = out.timed_out, stderr = %out.stderr.trim(), "storage: lsblk failed");
            None
        }
        Err(e) => {
            tracing::warn!("storage: lsblk did not run: {e}");
            None
        }
    }
}

/// The arrays and pools as they are now.
async fn arrays_and_pools(state: &AppState) -> (Vec<st::MdArray>, Vec<st::Pool>) {
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

async fn held(state: &AppState) -> st::Held {
    let (arrays, pools) = arrays_and_pools(state).await;
    st::Held::of(&arrays, &pools)
}

pub async fn view(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::admin_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let limits = super::machine::at_least(&state.remote_access.exec, 4 << 20);
    let tools = match super::exec::run(st::TOOLS_COMMAND, None, None, &limits).await {
        Ok(out) => st::parse_tools(&out.stdout),
        Err(_) => Vec::new(),
    };
    let Some(disks) = devices(&state).await else { return Ok(refused(502, "unreadable")) };
    let (arrays, pools) = arrays_and_pools(&state).await;
    let job = state.storage.job().map(|j| j.view(u64::MAX));
    // Why each device may not be partitioned, formatted or built on: the
    // agent's rule, so a page offers only what it would do.
    let held = st::Held::of(&arrays, &pools);
    let busy: serde_json::Map<String, serde_json::Value> = disks
        .iter()
        .flat_map(st::BlockDevice::walk)
        .filter_map(|d| st::in_use(&disks, &d.path, &held).map(|why| (d.path.clone(), json!(why))))
        .collect();
    let system: Vec<&str> = disks.iter().flat_map(st::BlockDevice::walk).filter(|d| st::system_mounted(d)).map(|d| d.path.as_str()).collect();
    Ok(HttpResponse::Ok().json(&json!({ "disks": disks, "busy": busy, "system": system, "arrays": arrays, "pools": pools, "tools": tools, "job": job })))
}

#[derive(Deserialize)]
pub struct ActBody {
    #[serde(flatten)]
    action: StorageAction,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn act(req: HttpRequest, body: web::types::Json<ActBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    let caller = require!(authz::admin_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(refused(409, "notLinux"));
    }
    let ActBody { action, sudo_password } = body.into_inner();
    let script = match action.script() {
        Ok(s) => s,
        Err(e) => return Ok(refused(400, e.code())),
    };
    // Decided on what the machine has now, not on what a page saw.
    if let StorageAction::Unmount { mountpoint } = &action {
        let Some(disks) = devices(&state).await else { return Ok(refused(502, "unreadable")) };
        if let Some(why) = st::unmount_refusal(&disks, mountpoint) {
            return Ok(refused(409, why));
        }
    }
    let consumes = action.consumes();
    if !consumes.is_empty() {
        let Some(disks) = devices(&state).await else { return Ok(refused(502, "unreadable")) };
        if st::overlapping(&disks, &consumes) {
            return Ok(refused(400, "overlapping"));
        }
        let held = held(&state).await;
        for device in consumes {
            if let Some(why) = st::in_use(&disks, device, &held) {
                return Ok(HttpResponse::Conflict().json(&json!({ "error": "inUse", "device": device, "why": why })));
            }
        }
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
    Event::new(Kind::Machine, Action::Write, Outcome::Ok)
        .subject(&caller.username)
        .remote_ip(peer_ip(&req))
        .detail(format!("storage {what}"))
        .record(&state.db)
        .await;
    let (state2, job2, username) = (state.get_ref().clone(), job.clone(), caller.username.clone());
    tokio::spawn(async move {
        let result = job2.run_root(&script, &password).await;
        let outcome = if result.is_ok() { Outcome::Ok } else { Outcome::Error };
        match &result {
            Ok(()) => job2.finish(JobState::Succeeded, None),
            Err(e) => {
                job2.push(format!("✕ {e}"));
                job2.finish(if e == "cancelled" { JobState::Cancelled } else { JobState::Failed }, Some(e.clone()));
            }
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
