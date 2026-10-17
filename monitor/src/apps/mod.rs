//! Desk apps' backends run by the agent (`docs/dev/desk-sys.md`): the
//! compiled components by package, and each app's job.

pub mod catalog;
pub mod runtime;
pub mod sign;
pub mod value;

use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use serde::Serialize;
use serde_json::Value;

use crate::stacks::job::{Job, JobSlot, JobView};
use crate::utils::lock::LockExt;
use runtime::Backend;

/// Calls running at once, across apps: each holds an instance (up to
/// `runtime::MAX_MEMORY`) until it ends.
const MAX_CALLS: usize = 8;
/// Jobs running at once, across apps (one per app): each holds an instance
/// for as long as it runs, so apart from the calls'.
const MAX_JOBS: usize = 4;

/// How a job ended, beside its lines: the function's value or its error.
#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Outcome {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<Refusal>,
}

/// An app's own error or the host's, as the frame gets it.
#[derive(Clone, Serialize)]
pub struct Refusal {
    pub error: String,
    #[serde(skip_serializing_if = "String::is_empty")]
    pub message: String,
}

/// An app's job: the job (lines, state, cancel), the function it runs and how
/// it ended.
pub struct AppJob {
    pub job: Arc<Job>,
    pub function: String,
    pub outcome: Mutex<Option<Outcome>>,
}

/// An app's job as the frame reads it: the job's lines and state, its
/// function, and how it ended (`error` the app's or the host's refusal, one
/// key, never the job's own text beside it).
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppJobView {
    pub id: u64,
    pub kind: crate::stacks::job::JobKind,
    pub state: crate::stacks::job::JobState,
    pub lines: Vec<crate::stacks::job::Line>,
    pub next: u64,
    pub function: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<Refusal>,
}

impl AppJob {
    pub fn view(&self, since: u64) -> AppJobView {
        let JobView { id, kind, state, error, lines, next } = self.job.view(since);
        let Outcome { value, error: refusal } = self.outcome.locked().clone().unwrap_or(Outcome { value: None, error: None });
        // Ended with no outcome of the app's (the host's own failure): the
        // job's words.
        let error = refusal.or_else(|| error.map(|e| Refusal { error: e, message: String::new() }));
        AppJobView { id, kind, state, lines, next, function: self.function.clone(), value, error }
    }
}

/// One app's job slot and the job it holds, with its function and outcome.
#[derive(Default)]
struct Slot {
    slot: JobSlot,
    last: Option<Arc<AppJob>>,
}

pub struct Apps {
    /// `<database dir>/apps/cache`: compiled components (a protected tree).
    cache: PathBuf,
    /// `<database dir>/apps/data/<app id>`: each app's own folder.
    data: PathBuf,
    backends: Mutex<HashMap<String, Arc<Backend>>>,
    jobs: Mutex<HashMap<String, Slot>>,
    pub calls: Arc<tokio::sync::Semaphore>,
    pub job_slots: Arc<tokio::sync::Semaphore>,
}

impl Apps {
    pub fn dir_beside(db: &Path) -> PathBuf {
        db.parent().unwrap_or_else(|| Path::new(".")).join("apps")
    }

    pub fn new(db_file: Option<&Path>) -> Self {
        let dir = match db_file {
            Some(f) => std::path::absolute(Self::dir_beside(f)).unwrap_or_else(|_| Self::dir_beside(f)),
            None => std::env::temp_dir().join(format!("sbm-apps-{}", std::process::id())),
        };
        Self { cache: dir.join("cache"), data: dir.join("data"), backends: Mutex::default(), jobs: Mutex::default(), calls: Arc::new(tokio::sync::Semaphore::new(MAX_CALLS)), job_slots: Arc::new(tokio::sync::Semaphore::new(MAX_JOBS)) }
    }

    /// The backend whose component's digest is [sha256], compiled from
    /// [bytes] (read only when it is not loaded yet) off the executor.
    pub async fn backend(&self, sha256: &str, bytes: impl FnOnce() -> Option<Vec<u8>> + Send + 'static) -> Result<Arc<Backend>, String> {
        if let Some(b) = self.backends.locked().get(sha256) {
            return Ok(b.clone());
        }
        let (sha, cache) = (sha256.to_string(), self.cache.clone());
        let backend = tokio::task::spawn_blocking(move || {
            let bytes = bytes().ok_or("missing")?;
            Backend::load(&bytes, &sha, &cache)
        })
        .await
        .map_err(|e| e.to_string())??;
        let backend = Arc::new(backend);
        self.backends.locked().insert(sha256.to_string(), backend.clone());
        Ok(backend)
    }

    /// A package went (removed or replaced): its compiled component too.
    pub fn forget(&self, sha256: &str) {
        self.backends.locked().remove(sha256);
        let _ = std::fs::remove_file(self.cache.join(format!("{sha256}.cwasm")));
    }

    /// [app]'s own folder, made (0700) when it is not there.
    pub fn data_dir(&self, app: &str) -> std::io::Result<PathBuf> {
        let dir = self.data.join(app);
        std::fs::create_dir_all(&dir)?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&dir, std::fs::Permissions::from_mode(0o700))?;
        }
        Ok(dir)
    }

    /// [app] went: its job cancelled and forgotten, so neither outlives it
    /// nor shows to an app installed under its id later; the job, to wait
    /// for.
    pub fn end_jobs(&self, app: &str) -> Option<Arc<AppJob>> {
        let last = self.jobs.locked().remove(app).and_then(|s| s.last)?;
        if last.job.running() {
            last.job.cancel();
        }
        Some(last)
    }

    /// [app] went: its folder too.
    pub fn forget_data(&self, app: &str) {
        let dir = self.data.join(app);
        if dir.exists()
            && let Err(e) = std::fs::remove_dir_all(&dir)
        {
            tracing::warn!("app {app}: removing {}: {e}", dir.display());
        }
    }

    /// A new job for [app], unless one is running.
    pub fn begin(&self, app: &str, function: &str) -> Option<Arc<AppJob>> {
        let mut jobs = self.jobs.locked();
        let entry = jobs.entry(app.to_string()).or_default();
        let job = entry.slot.begin(crate::stacks::job::JobKind::App)?;
        let app_job = Arc::new(AppJob { job, function: function.to_string(), outcome: Mutex::new(None) });
        entry.last = Some(app_job.clone());
        Some(app_job)
    }

    /// [app]'s job running now, or its last.
    pub fn job(&self, app: &str) -> Option<Arc<AppJob>> {
        self.jobs.locked().get(app).and_then(|s| s.last.clone())
    }
}
