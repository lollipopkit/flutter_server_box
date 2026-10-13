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
//!   left out too; nor is the folder web apps share (`stacks::Stacks::shared`,
//!   downloads and media libraries of every app, none's data alone). All
//!   are listed in the backup as skipped.
//! - One backup or restore at a time; a [`Job`], as a web app's deploy is.
//! - The directory is the agent's own state (`fs_roots::Protected`): it
//!   holds databases.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, RwLock};

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
    /// `system` (a system folder of the host) | `notFolder` (a bound file) |
    /// `shared` (in the folder web apps share).
    pub why: String,
}

pub struct ContainerBackups {
    /// Beside the database: where backups go unless a destination is set.
    default_root: PathBuf,
    /// Where backups go now: [default_root] or `<destination>/BACKUP_DIR`.
    root: RwLock<PathBuf>,
    /// Removed with this value: the directory made for an in-memory database.
    owned: bool,
    job: Mutex<Option<Arc<Job>>>,
}

impl Drop for ContainerBackups {
    fn drop(&mut self) {
        if self.owned {
            let _ = std::fs::remove_dir_all(&self.default_root);
        }
    }
}

/// The folder a destination gets for this agent's backups.
const BACKUP_DIR: &str = "serverbox-container-backups";

fn refusal(status: u16, error: &'static str) -> Refusal {
    Refusal { status, error, field: None }
}

impl ContainerBackups {
    pub fn new(db_file: Option<&Path>) -> Self {
        match db_file {
            Some(f) => {
                let dir = Self::dir_beside(f);
                let dir = std::path::absolute(&dir).unwrap_or(dir);
                Self { root: RwLock::new(dir.clone()), default_root: dir, owned: false, job: Mutex::default() }
            }
            None => {
                let dir = std::env::temp_dir().join(format!("sbm-container-backups-{}-{}", std::process::id(), rand_suffix()));
                Self { root: RwLock::new(dir.clone()), default_root: dir, owned: true, job: Mutex::default() }
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

    /// Where backups go now.
    pub fn root(&self) -> PathBuf {
        self.root.read().unwrap_or_else(|e| e.into_inner()).clone()
    }

    pub fn default_root(&self) -> &Path {
        &self.default_root
    }

    /// Backups go to [destination] (a folder made in it), or beside the
    /// database for `None`. The folder is the agent's state from now on.
    fn use_destination(&self, destination: Option<&Path>) {
        let next = destination.map(|d| d.join(BACKUP_DIR)).unwrap_or_else(|| self.default_root.clone());
        let previous = std::mem::replace(&mut *self.root.write().unwrap_or_else(|e| e.into_inner()), next.clone());
        if previous != next && previous != self.default_root {
            crate::core::fs_roots::protect_at_runtime(&next, Some(&previous));
        } else {
            crate::core::fs_roots::protect_at_runtime(&next, None);
        }
    }

    fn dir(&self, id: &str) -> PathBuf {
        self.root().join(id)
    }

    /// Every finished backup, newest first.
    pub fn list(&self) -> Vec<Meta> {
        let mut out: Vec<Meta> = std::fs::read_dir(self.root())
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
/// [keep]: backups of this label kept (the oldest past it removed once this
/// one is made); `None` for the settings'.
pub async fn back_up(
    state: &Arc<AppState>,
    username: &str,
    ids: &[String],
    whole_project: bool,
    stop: bool,
    keep: Option<u32>,
) -> Result<Arc<Job>, Refusal> {
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

    // What it would take, against what is free where backups go: archives
    // are compressed, so this errs on the safe side.
    // A backup disk unmounted since: never written into the folder under it.
    let root = state.container_backups.root();
    if root != state.container_backups.default_root() && !root.is_dir() {
        return Err(refusal(409, "destinationMissing"));
    }
    let mounts: Vec<&Mount> = containers.iter().flat_map(|c| &c.mounts).filter(|m| !m.is_system()).collect();
    if let (Some(need), Some(free)) = (estimate(state, runtime, &mounts).await, free_bytes(state))
        && need > free
    {
        tracing::warn!("container backup of {label}: {need} bytes to archive, {free} free");
        return Err(refusal(507, "notEnoughSpace"));
    }
    let keep = match keep {
        Some(k) => k,
        None => settings(&state.db).await.keep,
    };

    let backups = &state.container_backups;
    let job = backups.begin(JobKind::Backup)?;
    let id = format!("{}-{}", chrono::Local::now().format("%Y%m%d-%H%M%S"), slug(&label));
    let dir = backups.dir(&id);
    let made = if root == backups.default_root() { std::fs::create_dir_all(&dir) } else { std::fs::create_dir(&dir) };
    if let Err(e) = made {
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
            } else if matches!(m, Mount::Bind { source, .. } if Path::new(source).starts_with(state.stacks.shared())) {
                Some("shared")
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
        } else {
            prune(&state.container_backups, &meta.label, keep);
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

// -----------------------------------------------------------------------------
// Where they go, how many are kept, when they are made
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    /// A folder backups go to (a backup disk's mount); `None` beside the
    /// database.
    pub destination: Option<String>,
    /// Backups of one label kept, the oldest removed past it; 0 keeps all.
    pub keep: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Schedule {
    pub id: String,
    pub label: String,
    /// Container names: ids change when a project is recreated.
    pub containers: Vec<String>,
    pub project: bool,
    pub stop: bool,
    /// `daily` | `weekly`.
    pub every: String,
    /// `HH:MM`, the machine's time.
    pub at: String,
    /// Weekly: 0 Monday … 6 Sunday.
    pub weekday: Option<u8>,
    /// Overrides [`Settings::keep`] for this label.
    pub keep: Option<u32>,
    pub last_run: Option<String>,
    pub last_error: Option<String>,
}

pub async fn settings(db: &sqlx::SqlitePool) -> Settings {
    let row: Option<(Option<String>, i64)> =
        sqlx::query_as("SELECT destination, keep FROM container_backup_settings WHERE id = 1").fetch_optional(db).await.ok().flatten();
    match row {
        Some((destination, keep)) => Settings { destination, keep: keep.max(0) as u32 },
        None => Settings { destination: None, keep: 7 },
    }
}

/// A folder backups may go to: absolute, there, and one this agent can write
/// in (a disk mounted for it, `api::storage`'s Mount with its owner).
fn destination_ok(path: &str) -> Result<PathBuf, Refusal> {
    let p = Path::new(path);
    if !p.is_absolute() || path.contains('\n') || path.split('/').any(|s| s == "..") {
        return Err(refusal(400, "invalidDestination"));
    }
    if !p.is_dir() {
        return Err(refusal(400, "destinationMissing"));
    }
    let dir = p.join(BACKUP_DIR);
    std::fs::create_dir_all(&dir).map_err(|_| refusal(400, "destinationNotWritable"))?;
    set_private(&dir);
    let probe = dir.join(".sbm-write-test");
    std::fs::write(&probe, b"").map_err(|_| refusal(400, "destinationNotWritable"))?;
    let _ = std::fs::remove_file(probe);
    Ok(p.to_path_buf())
}

pub async fn set_settings(state: &AppState, next: Settings) -> Result<Settings, Refusal> {
    let destination = match next.destination.as_deref().filter(|d| !d.trim().is_empty()) {
        Some(d) => Some(destination_ok(d.trim())?),
        None => None,
    };
    sqlx::query(
        "INSERT INTO container_backup_settings (id, destination, keep) VALUES (1, ?, ?) \
         ON CONFLICT(id) DO UPDATE SET destination = excluded.destination, keep = excluded.keep",
    )
    .bind(destination.as_ref().map(|d| d.to_string_lossy().into_owned()))
    .bind(i64::from(next.keep))
    .execute(&state.db)
    .await
    .map_err(|e| {
        tracing::error!("container backups: {e}");
        refusal(500, "internal")
    })?;
    state.container_backups.use_destination(destination.as_deref());
    Ok(settings(&state.db).await)
}

/// Free bytes where backups go now.
pub fn free_bytes(state: &AppState) -> Option<u64> {
    let root = state.container_backups.root();
    let probe = root.ancestors().find(|p| p.exists())?.to_path_buf();
    fs2::available_space(probe).ok()
}

pub async fn schedules(db: &sqlx::SqlitePool) -> Vec<Schedule> {
    type Row = (String, String, String, bool, bool, String, String, Option<i64>, Option<i64>, Option<String>, Option<String>);
    let rows: Vec<Row> = sqlx::query_as(
        "SELECT id, label, containers, project, stop, every, at, weekday, keep, last_run, last_error FROM container_backup_schedule ORDER BY created_at",
    )
    .fetch_all(db)
    .await
    .unwrap_or_default();
    rows.into_iter()
        .map(|(id, label, containers, project, stop, every, at, weekday, keep, last_run, last_error)| Schedule {
            id,
            label,
            containers: serde_json::from_str(&containers).unwrap_or_default(),
            project,
            stop,
            every,
            at,
            weekday: weekday.map(|w| w as u8),
            keep: keep.map(|k| k.max(0) as u32),
            last_run,
            last_error,
        })
        .collect()
}

#[derive(Debug, Clone, Deserialize)]
pub struct NewSchedule {
    pub containers: Vec<String>,
    #[serde(default)]
    pub project: bool,
    #[serde(default = "yes")]
    pub stop: bool,
    pub every: String,
    pub at: String,
    pub weekday: Option<u8>,
    pub keep: Option<u32>,
}

fn yes() -> bool {
    true
}

pub(crate) fn time_ok(at: &str) -> bool {
    at.split_once(':').is_some_and(|(h, m)| {
        h.len() == 2 && m.len() == 2 && h.parse::<u8>().is_ok_and(|h| h < 24) && m.parse::<u8>().is_ok_and(|m| m < 60)
    })
}

pub async fn add_schedule(state: &AppState, username: &str, new: NewSchedule) -> Result<Schedule, Refusal> {
    let named = |id: &str| (1..=128).contains(&id.len()) && id.bytes().all(|b| b.is_ascii_alphanumeric() || b"_.-".contains(&b));
    if new.containers.is_empty() || new.containers.len() > 64 || !new.containers.iter().all(|c| named(c)) {
        return Err(refusal(400, "invalidContainer"));
    }
    let weekly = match new.every.as_str() {
        "daily" => false,
        "weekly" => true,
        _ => return Err(refusal(400, "invalidSchedule")),
    };
    if !time_ok(&new.at) || weekly != new.weekday.is_some() || new.weekday.is_some_and(|w| w > 6) {
        return Err(refusal(400, "invalidSchedule"));
    }
    let id = crate::utils::secrets::random_hex(8).map_err(|_| refusal(500, "internal"))?;
    let label = new.containers[0].clone();
    sqlx::query(
        "INSERT INTO container_backup_schedule (id, label, containers, project, stop, every, at, weekday, keep, created_by, created_at) \
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(&id)
    .bind(&label)
    .bind(serde_json::to_string(&new.containers).unwrap_or_default())
    .bind(new.project)
    .bind(new.stop)
    .bind(&new.every)
    .bind(&new.at)
    .bind(new.weekday.map(i64::from))
    .bind(new.keep.map(i64::from))
    .bind(username)
    .bind(chrono::Utc::now().to_rfc3339())
    .execute(&state.db)
    .await
    .map_err(|e| {
        tracing::error!("container backups: {e}");
        refusal(500, "internal")
    })?;
    schedules(&state.db).await.into_iter().find(|s| s.id == id).ok_or_else(|| refusal(500, "internal"))
}

pub async fn remove_schedule(state: &AppState, id: &str) -> Result<(), Refusal> {
    let done = sqlx::query("DELETE FROM container_backup_schedule WHERE id = ?").bind(id).execute(&state.db).await.map_err(|_| refusal(500, "internal"))?;
    if done.rows_affected() == 0 { Err(refusal(404, "notFound")) } else { Ok(()) }
}

/// The time slot [s] last fell due at, before or at [now] (local).
fn due_since(s: &Schedule, now: chrono::DateTime<chrono::Local>) -> Option<chrono::DateTime<chrono::Local>> {
    use chrono::{Datelike, Duration as D, NaiveTime, TimeZone};
    let time = NaiveTime::parse_from_str(&s.at, "%H:%M").ok()?;
    let mut day = now.date_naive();
    for _ in 0..8 {
        let weekday_ok = s.weekday.is_none_or(|w| day.weekday().num_days_from_monday() == u32::from(w));
        if weekday_ok
            && let Some(at) = chrono::Local.from_local_datetime(&day.and_time(time)).earliest()
            && at <= now
        {
            return Some(at);
        }
        day -= D::days(1);
    }
    None
}

/// Removes the oldest backups of [label] past [keep] (0 keeps all).
fn prune(backups: &ContainerBackups, label: &str, keep: u32) {
    if keep == 0 {
        return;
    }
    let mut of: Vec<Meta> = backups.list().into_iter().filter(|m| m.label == label).collect();
    // Newest first already.
    for old in of.drain(..).skip(keep as usize) {
        if let Err(e) = std::fs::remove_dir_all(backups.dir(&old.id)) {
            tracing::warn!("container backup {}: removing past what is kept: {e}", old.id);
        }
    }
}

/// At start: the destination set, and the schedule watched until the agent
/// stops.
pub async fn start(state: Arc<AppState>) {
    let s = settings(&state.db).await;
    state.container_backups.use_destination(s.destination.as_deref().map(Path::new));
    let mut tick = tokio::time::interval(std::time::Duration::from_secs(60));
    loop {
        tick.tick().await;
        run_due(&state).await;
    }
}

async fn run_due(state: &Arc<AppState>) {
    let now = chrono::Local::now();
    for s in schedules(&state.db).await {
        let Some(slot) = due_since(&s, now) else { continue };
        let ran = s.last_run.as_deref().and_then(|r| chrono::DateTime::parse_from_rfc3339(r).ok());
        if ran.is_some_and(|r| r >= slot) {
            continue;
        }
        if state.container_backups.job().is_some_and(|j| j.running()) {
            return;
        }
        let result = scheduled(state, &s).await;
        let _ = sqlx::query("UPDATE container_backup_schedule SET last_run = ?, last_error = ? WHERE id = ?")
            .bind(now.to_rfc3339())
            .bind(result.err())
            .bind(&s.id)
            .execute(&state.db)
            .await;
    }
}

/// Runs schedule [s] now and waits for it.
async fn scheduled(state: &Arc<AppState>, s: &Schedule) -> Result<(), String> {
    let runtime = runtime(state).await.map_err(|r| r.error.to_string())?;
    let ids = ids_of(&run(state, &cb::named_command(runtime, &s.containers)).await.map_err(|r| r.error.to_string())?);
    if ids.is_empty() {
        return Err("notFound".into());
    }
    let job = back_up(state, "schedule", &ids, s.project, s.stop, s.keep).await.map_err(|r| r.error.to_string())?;
    match job.done().await {
        JobState::Succeeded => Ok(()),
        _ => Err(job.view(u64::MAX).error.unwrap_or_else(|| "failed".into())),
    }
}

/// What [mounts] hold, in bytes, as `du` sees them from a throwaway
/// container; `None` when it cannot be told.
async fn estimate(state: &AppState, runtime: ContainerType, mounts: &[&Mount]) -> Option<u64> {
    let mut total = 0;
    for m in mounts {
        let out = run(state, &cb::size_command(runtime, m)).await.ok()?;
        total += out.split_whitespace().next()?.parse::<u64>().ok()?;
    }
    Some(total)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_schedule_falls_due_at_its_slot() {
        use chrono::TimeZone;
        let at = |y, mo, d, h, mi| chrono::Local.with_ymd_and_hms(y, mo, d, h, mi, 0).unwrap();
        let mut s = Schedule {
            id: "x".into(),
            label: "x".into(),
            containers: vec!["web".into()],
            project: false,
            stop: true,
            every: "daily".into(),
            at: "03:30".into(),
            weekday: None,
            keep: None,
            last_run: None,
            last_error: None,
        };
        // 2026-10-11 is a Sunday.
        assert_eq!(due_since(&s, at(2026, 10, 11, 9, 0)), Some(at(2026, 10, 11, 3, 30)));
        assert_eq!(due_since(&s, at(2026, 10, 11, 3, 0)), Some(at(2026, 10, 10, 3, 30)));
        s.weekday = Some(6);
        assert_eq!(due_since(&s, at(2026, 10, 14, 12, 0)), Some(at(2026, 10, 11, 3, 30)));
        s.weekday = Some(0);
        assert_eq!(due_since(&s, at(2026, 10, 14, 12, 0)), Some(at(2026, 10, 12, 3, 30)));
        assert!(time_ok("00:00") && time_ok("23:59") && !time_ok("24:00") && !time_ok("3:30"));
    }

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