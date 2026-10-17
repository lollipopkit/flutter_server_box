//! `/api/v1/cleanup*`: what can go to free space (`sbm_parser::cleanup`).
//! Linux only.
//!
//! - `GET /cleanup`: the last scan (when, what it found) and the job.
//! - `POST /cleanup/scan`: `{sudo_password}`, a scan as root, as a job (its
//!   findings kept here, not in the job's lines).
//! - `POST /cleanup/clean`: `{ids, sudo_password}`: a job that scans again,
//!   removes the chosen items the new scan still finds, and scans once more.
//!
//! The account's items are the agent's account's (its home); one that holds
//! the agent's own state (`fs_roots`) is offered as not cleanable. A removed
//! web app's folder is one under the stacks' directory with no stack row.

use std::path::Path;
use std::sync::{Arc, Mutex};

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::authz;
use super::server::AppState;
use super::shares::{as_root, record};
use crate::stacks::job::{Job, JobKind, JobSlot, JobState};
use crate::utils::lock::LockExt;
use sbm_parser::cleanup::{self as cl, Item};

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Scan {
    /// Unix milliseconds.
    pub at: i64,
    pub items: Vec<Item>,
}

#[derive(Default)]
pub struct Cleanup {
    jobs: JobSlot,
    last: Mutex<Option<Scan>>,
}

fn home() -> Option<String> {
    std::env::var("HOME").ok().filter(|h| h.starts_with('/'))
}

/// Removed web apps' folders, by app id.
async fn leftovers(state: &AppState) -> Vec<(String, String)> {
    let installed: Vec<String> = crate::stacks::store::all(&state.db).await.map(|rows| rows.into_iter().map(|r| r.id).collect()).unwrap_or_default();
    state.stacks.leftovers(&installed).into_iter().map(|(id, path)| (id, path.to_string_lossy().into_owned())).collect()
}

/// A scan as root in [job]; its items, those holding the agent's state
/// marked not cleanable.
async fn scan(state: &AppState, job: &Job, home: &str, password: &str, left: &[(String, String)]) -> Result<Vec<Item>, String> {
    let out = job.capture_root(&cl::scan_script(home, left), password).await?;
    let mut items = cl::parse_scan(&out);
    for item in &mut items {
        if let Some(path) = cl::account_path(home, &item.id) {
            let canonical = std::fs::canonicalize(&path).unwrap_or_else(|_| Path::new(&path).to_path_buf());
            if state.remote_access.fs.roots.check_mutable(&canonical).is_err() {
                item.cleanable = false;
            }
        }
    }
    Ok(items)
}

fn keep(state: &AppState, items: Vec<Item>) {
    *state.cleanup.last.locked() = Some(Scan { at: chrono::Utc::now().timestamp_millis(), items });
}

fn finish(job: &Job, result: Result<(), String>) {
    match result {
        Ok(()) => job.finish(JobState::Succeeded, None),
        Err(e) => {
            job.push(format!("✕ {e}"));
            job.finish(if e == "cancelled" { JobState::Cancelled } else { JobState::Failed }, Some(e));
        }
    }
}

pub async fn view(req: HttpRequest, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let scan = state.cleanup.last.locked().clone();
    let job = state.cleanup.jobs.current().map(|j| j.view(0));
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "scan": scan, "job": job })))
}

#[derive(Deserialize)]
pub struct ScanBody {
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn start_scan(req: HttpRequest, body: web::types::Json<ScanBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let Some(home) = home() else { return Ok(super::respond::error_u16(409, "noHome")) };
    let password = body.into_inner().sudo_password.unwrap_or_default();
    require!(as_root(&state, "true", Some(&password).filter(|p| !p.is_empty()).map(String::as_str), false).await);
    let Some(job) = state.cleanup.jobs.begin(JobKind::Scan) else { return Ok(super::respond::error_u16(409, "busy")) };
    let (state2, job2) = (state.get_ref().clone(), job.clone());
    tokio::spawn(async move {
        let left = leftovers(&state2).await;
        let result = scan(&state2, &job2, &home, &password, &left).await.map(|items| keep(&state2, items));
        finish(&job2, result);
    });
    Ok(HttpResponse::Accepted().json(&job.view(0)))
}

#[derive(Deserialize)]
pub struct CleanBody {
    ids: Vec<String>,
    #[serde(default)]
    sudo_password: Option<String>,
}

pub async fn clean(req: HttpRequest, body: web::types::Json<CleanBody>, state: web::types::State<Arc<AppState>>) -> Result<HttpResponse, web::Error> {
    require!(authz::acting_caller(&req, &state).await);
    if !cfg!(target_os = "linux") {
        return Ok(super::respond::error_u16(409, "notLinux"));
    }
    let Some(home) = home() else { return Ok(super::respond::error_u16(409, "noHome")) };
    let CleanBody { ids, sudo_password } = body.into_inner();
    // Refused here on what the page saw; the job checks a fresh scan again.
    let seen = state.cleanup.last.locked().clone();
    let Some(seen) = seen else { return Ok(super::respond::error_u16(409, "notScanned")) };
    if let Err(e) = cl::check(&seen.items, &ids) {
        return Ok(super::respond::error_u16(409, e));
    }
    let password = sudo_password.unwrap_or_default();
    require!(as_root(&state, "true", Some(&password).filter(|p| !p.is_empty()).map(String::as_str), false).await);
    let Some(job) = state.cleanup.jobs.begin(JobKind::Cleanup) else { return Ok(super::respond::error_u16(409, "busy")) };
    record(&req, &state, format!("cleanup {}", ids.join(", "))).await;
    let (state2, job2) = (state.get_ref().clone(), job.clone());
    tokio::spawn(async move {
        let result = async {
            let left = leftovers(&state2).await;
            let now = scan(&state2, &job2, &home, &password, &left).await?;
            cl::check(&now, &ids).map_err(|e| format!("{e}: the machine changed since its scan"))?;
            let freed: u64 = now.iter().filter(|i| ids.contains(&i.id)).map(|i| i.bytes).sum();
            job2.run_root(&cl::clean_script(&home, &ids, &left), &password).await?;
            let after = scan(&state2, &job2, &home, &password, &leftovers(&state2).await).await?;
            keep(&state2, after);
            job2.push(format!("about {} MiB freed", freed >> 20));
            Ok(())
        }
        .await;
        finish(&job2, result);
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
    match state.cleanup.jobs.current() {
        Some(job) => Ok(HttpResponse::Ok().json(&job.view(query.since))),
        None => Ok(super::respond::error_u16(404, "notFound")),
    }
}
