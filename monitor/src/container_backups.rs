//! Backups of what containers keep: a container's (or its whole compose
//! project's) volumes and bound folders, each archived to
//! `<database dir>/container-backups/<id>/m<N>.tar.gz` from inside a
//! throwaway container (`sbm_parser::container_backup`), with a `meta.json`
//! saying what came from where. Restoring writes each archive back into the
//! same volume or folder, its containers stopped meanwhile.
//!
//! - Containers are stopped while archived when asked (a database copied
//!   while it writes may not open), and started again whatever happens.
//! - System folders of the host bound into a container (`/etc`, `/`) are
//!   never archived nor written back; a bound file is not a folder and is
//!   left out too. Both are listed in the backup as skipped.
//! - One backup or restore at a time; a [`Job`], as a web app's deploy is.
//! - The directory is the agent's own state (`fs_roots::Protected`): it
//!   holds databases.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use sbm_parser::container::ContainerType;
use sbm_parser::container_backup::{self as cb, Inspected, Mount};
use serde::{Deserialize, Serialize};

use crate::api::server::AppState;
use crate::api::ws::audit::{Action, Event, Kind, Outcome};
use crate::stacks::Refusal;
use crate::stacks::job::{Job, JobKind, JobState};

const META: &str = "meta.json";

/// A backup's directory name: `<date>-<time>-<label>`.
pub fn valid_id(id: &str) -> bool {
    let b = id.as_bytes();
    (17..=64).contains(&b.len())
        && b[..8].iter().all(u8::is_ascii_digit)
        && b[8] == b'-'
        && b[9..15].iter().all(u8::is_ascii_digit)
        && b[15] == b'-'
        && b[16..].iter().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || *c == b'-')
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Meta {
    pub id: String,
    /// The project's name, or the container's.
    pub label: String,
    pub created_at: String,
    pub created_by: String,
    /// Whether the containers were stopped while archived.
    pub stopped: bool,
    pub containers: Vec<Saved>,
    pub archives: Vec<Archive>,
    pub skipped: Vec<Skipped>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Saved {
    pub name: String,
    pub image: String,
    pub project: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Archive {
    pub file: String,
    /// The container it was found in (the first, when several share it).
    pub container: String,
    pub mount: Mount,
    pub bytes: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Skipped {
    pub container: String,
    pub mount: Mount,
    /// `system` (a system folder of the host) | `notFolder` (a bound file).
    pub why: String,
}

pub struct ContainerBackups {
    root: PathBuf,
    /// Removed with this value: the directory made for an in-memory database.
    owned: bool,
    job: Mutex<Option<Arc<Job>>>,
}

impl Drop for ContainerBackups {
    fn drop(&mut self) {
        if self.owned {
            let _ = std::fs::remove_dir_all(&self.root);
        }
    }
}

fn refusal(status: u16, error: &'static str) -> Refusal {
    Refusal { status, error, field: None }
}

impl ContainerBackups {
    pub fn new(db_file: Option<&Path>) -> Self {
        match db_file {
            Some(f) => {
                let dir = Self::dir_beside(f);
                Self { root: std::path::absolute(&dir).unwrap_or(dir), owned: false, job: Mutex::default() }
            }
            None => {
                let dir = std::env::temp_dir().join(format!("sbm-container-backups-{}-{}", std::process::id(), rand_suffix()));
                Self { root: dir, owned: true, job: Mutex::default() }
            }
        }
    }

    pub fn dir_beside(db: &Path) -> PathBuf {
        db.parent().unwrap_or_else(|| Path::new(".")).join("container-backups")
    }

    pub fn job(&self) -> Option<Arc<Job>> {
        self.job.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }

    fn begin(&self, kind: JobKind) -> Result<Arc<Job>, Refusal> {
        let mut job = self.job.lock().unwrap_or_else(|e| e.into_inner());
        if job.as_ref().is_some_and(|j| j.running()) {
            return Err(refusal(409, "busy"));
        }
        let next = Arc::new(Job::new(kind));
        *job = Some(next.clone());
        Ok(next)
    }

    fn dir(&self, id: &str) -> PathBuf {
        self.root.join(id)
    }

    /// Every finished backup, newest first.
    pub fn list(&self) -> Vec<Meta> {
        let mut out: Vec<Meta> = std::fs::read_dir(&self.root)
            .into_iter()
            .flatten()
            .flatten()
            .filter_map(|e| std::fs::read(e.path().join(META)).ok())
            .filter_map(|bytes| serde_json::from_slice(&bytes).ok())
            .collect();
        out.sort_by(|a: &Meta, b: &Meta| b.id.cmp(&a.id));
        out
    }

    fn meta(&self, id: &str) -> Option<Meta> {
        if !valid_id(id) {
            return None;
        }
        serde_json::from_slice(&std::fs::read(self.dir(id).join(META)).ok()?).ok()
    }

    pub fn remove(&self, id: &str) -> Result<(), Refusal> {
        if self.job().is_some_and(|j| j.running()) {
            return Err(refusal(409, "busy"));
        }
        self.meta(id).ok_or_else(|| refusal(404, "notFound"))?;
        std::fs::remove_dir_all(self.dir(id)).map_err(|e| {
            tracing::error!("container backup {id}: {e}");
            refusal(500, "internal")
        })
    }
}

fn rand_suffix() -> String {
    crate::utils::secrets::random_hex(4).unwrap_or_default()
}

async fn runtime(state: &AppState) -> Result<ContainerType, Refusal> {
    crate::api::containers::detect_runtime(&state.remote_access.exec).await.ok_or_else(|| refusal(409, "noRuntime"))
}

async fn run(state: &AppState, cmd: &str) -> Result<String, Refusal> {
    let limits = crate::api::machine::at_least(&state.remote_access.exec, 4 << 20);
    match crate::api::exec::run(cmd, None, None, &limits).await {
        Ok(out) if out.exit_code == Some(0) => Ok(out.stdout),
        Ok(out) => {
            tracing::warn!("container backup: {cmd}: exit {:?}: {}", out.exit_code, out.stderr.trim());
            Err(refusal(502, "runtimeFailed"))
        }
        Err(e) => {
            tracing::warn!("container backup: {cmd}: {e}");
            Err(refusal(502, "runtimeFailed"))
        }
    }
}

async fn inspect(state: &AppState, runtime: ContainerType, ids: &[String]) -> Result<Vec<Inspected>, Refusal> {
    if ids.is_empty() {
        return Ok(Vec::new());
    }
    Ok(cb::parse_inspect(&run(state, &cb::inspect_command(runtime, ids)).await?))
}

fn ids_of(stdout: &str) -> Vec<String> {
    stdout.lines().map(str::trim).filter(|l| !l.is_empty()).map(String::from).collect()
}

fn slug(label: &str) -> String {
    let s: String = label
        .to_ascii_lowercase()
        .chars()
        .map(|c| if c.is_ascii_alphanumeric() { c } else { '-' })
        .collect::<String>()
        .split('-')
        .filter(|p| !p.is_empty())
        .collect::<Vec<_>>()
        .join("-");
    let s: String = s.chars().take(40).collect();
    if s.is_empty() { "backup".into() } else { s.trim_end_matches('-').to_string() }
}

async fn audit(state: &AppState, username: &str, outcome: Outcome, detail: String) {
    Event::new(Kind::Machine, Action::Write, outcome).subject(username).detail(detail).record(&state.db).await;
}

/// Backs up [ids] (with [whole_project], every container of their compose
/// project), stopping them meanwhile when [stop].
pub async fn back_up(state: &Arc<AppState>, username: &str, ids: &[String], whole_project: bool, stop: bool) -> Result<Arc<Job>, Refusal> {
    // A container's id or name: what the runtimes allow in one.
    let named = |id: &str| {
        (1..=128).contains(&id.len())
            && id.as_bytes()[0].is_ascii_alphanumeric()
            && id.bytes().all(|b| b.is_ascii_alphanumeric() || b"_.-".contains(&b))
    };
    if !ids.iter().all(|id| named(id)) {
        return Err(refusal(400, "invalidContainer"));
    }
    let runtime = runtime(state).await?;
    let mut containers = inspect(state, runtime, ids).await?;
    if containers.is_empty() {
        return Err(refusal(404, "notFound"));
    }
    let project = containers[0].project.clone();
    if whole_project && let Some(project) = &project {
        let all = ids_of(&run(state, &cb::project_command(runtime, project)).await?);
        containers = inspect(state, runtime, &all).await?;
    }
    let label = match (&project, whole_project) {
        (Some(p), true) => p.clone(),
        _ => containers[0].name.clone(),
    };

    let backups = &state.container_backups;
    let job = backups.begin(JobKind::Backup)?;
    let id = format!("{}-{}", chrono::Local::now().format("%Y%m%d-%H%M%S"), slug(&label));
    let dir = backups.dir(&id);
    if let Err(e) = std::fs::create_dir_all(&dir) {
        tracing::error!("container backup {id}: {e}");
        job.finish(JobState::Failed, Some("writeFailed".into()));
        return Err(refusal(500, "writeFailed"));
    }
    set_private(&dir);
    let mut archives = Vec::new();
    let mut skipped = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for c in &containers {
        for m in &c.mounts {
            if !seen.insert(m.source().to_string()) {
                continue;
            }
            let why = if m.is_system() {
                Some("system")
            } else if matches!(m, Mount::Bind { source, .. } if !Path::new(source).is_dir()) {
                Some("notFolder")
            } else {
                None
            };
            match why {
                Some(why) => skipped.push(Skipped { container: c.name.clone(), mount: m.clone(), why: why.into() }),
                None => archives.push(Archive { file: format!("m{}.tar.gz", archives.len() + 1), container: c.name.clone(), mount: m.clone(), bytes: 0 }),
            }
        }
    }
    let running: Vec<String> = containers.iter().filter(|c| c.running).map(|c| c.id.clone()).collect();
    let dir_text = dir.to_string_lossy().into_owned();
    let mut steps = Vec::new();
    if stop && !running.is_empty() {
        steps.push(cb::lifecycle_command(runtime, &running, false));
    }
    steps.extend(archives.iter().map(|a| cb::archive_command(runtime, &a.mount, &dir_text, &a.file)));
    let restart = (stop && !running.is_empty()).then(|| cb::lifecycle_command(runtime, &running, true));
    let mut meta = Meta {
        id: id.clone(),
        label: label.clone(),
        created_at: chrono::Utc::now().to_rfc3339(),
        created_by: username.to_string(),
        stopped: stop && !running.is_empty(),
        containers: containers.iter().map(|c| Saved { name: c.name.clone(), image: c.image.clone(), project: c.project.clone() }).collect(),
        archives,
        skipped,
    };
    audit(state, username, Outcome::Ok, format!("container backup {id} started")).await;
    let (state, job2, username) = (state.clone(), job.clone(), username.to_string());
    tokio::spawn(async move {
        let mut result = job2.run_steps(&steps).await;
        // Started again whatever happened to the archives.
        if let Some(restart) = restart {
            let started = job2.run_steps(&[restart]).await;
            if result.is_ok() {
                result = started;
            }
        }
        if result.is_ok() {
            for a in &mut meta.archives {
                a.bytes = std::fs::metadata(dir.join(&a.file)).map(|m| m.len()).unwrap_or(0);
            }
            let written = serde_json::to_vec_pretty(&meta).map_err(|e| e.to_string()).and_then(|bytes| std::fs::write(dir.join(META), bytes).map_err(|e| e.to_string()));
            if let Err(e) = written {
                result = Err(format!("writing {META}: {e}"));
            }
        }
        if result.is_err() {
            let _ = std::fs::remove_dir_all(&dir);
        }
        finish(&state, &job2, &username, &format!("container backup {id}"), result).await;
    });
    Ok(job)
}

/// Writes backup [id] back into the volumes and folders it came from, its
/// containers (those still there, by name) stopped meanwhile and started
/// again if they ran.
pub async fn restore(state: &Arc<AppState>, username: &str, id: &str) -> Result<Arc<Job>, Refusal> {
    let backups = &state.container_backups;
    let meta = backups.meta(id).ok_or_else(|| refusal(404, "notFound"))?;
    let runtime = runtime(state).await?;
    let names: Vec<String> = meta.containers.iter().map(|c| c.name.clone()).collect();
    let present = inspect(state, runtime, &ids_of(&run(state, &cb::named_command(runtime, &names)).await?)).await?;
    // Only containers this backup named: a filter by name matches a prefix
    // in some runtimes.
    let present: Vec<Inspected> = present.into_iter().filter(|c| names.contains(&c.name)).collect();
    let running: Vec<String> = present.iter().filter(|c| c.running).map(|c| c.id.clone()).collect();
    let job = backups.begin(JobKind::Restore)?;
    let dir = backups.dir(id).to_string_lossy().into_owned();
    let mut steps = Vec::new();
    if !running.is_empty() {
        steps.push(cb::lifecycle_command(runtime, &running, false));
    }
    steps.extend(meta.archives.iter().filter(|a| !a.mount.is_system()).map(|a| cb::restore_command(runtime, &a.mount, &dir, &a.file)));
    let restart = (!running.is_empty()).then(|| cb::lifecycle_command(runtime, &running, true));
    audit(state, username, Outcome::Ok, format!("container backup {id} restore started")).await;
    let (state, job2, username, id) = (state.clone(), job.clone(), username.to_string(), id.to_string());
    tokio::spawn(async move {
        let mut result = job2.run_steps(&steps).await;
        if let Some(restart) = restart {
            let started = job2.run_steps(&[restart]).await;
            if result.is_ok() {
                result = started;
            }
        }
        finish(&state, &job2, &username, &format!("container backup {id} restore"), result).await;
    });
    Ok(job)
}

async fn finish(state: &AppState, job: &Job, username: &str, what: &str, result: Result<(), String>) {
    match result {
        Ok(()) => {
            job.finish(JobState::Succeeded, None);
            audit(state, username, Outcome::Ok, format!("{what} done")).await;
        }
        Err(e) => {
            let cancelled = e == "cancelled";
            job.push(format!("✕ {e}"));
            job.finish(if cancelled { JobState::Cancelled } else { JobState::Failed }, Some(e.clone()));
            audit(state, username, Outcome::Error, format!("{what} failed: {e}")).await;
        }
    }
}

fn set_private(dir: &Path) {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(dir, std::fs::Permissions::from_mode(0o700));
    }
    #[cfg(not(unix))]
    let _ = dir;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ids_are_dated_slugs() {
        assert!(valid_id("20261011-013000-sbm-futo-immich"));
        for bad in ["../x", "20261011-013000-", "2026101-013000-x", "20261011-013000-A", "20261011-013000-x/y"] {
            assert!(!valid_id(bad), "{bad}");
        }
        assert_eq!(slug("sbm-futo-immich"), "sbm-futo-immich");
        assert_eq!(slug("My_App.v2"), "my-app-v2");
        assert_eq!(slug("..."), "backup");
    }
}
