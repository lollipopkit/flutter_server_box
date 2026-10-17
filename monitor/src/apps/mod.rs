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

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AppJobView {
    #[serde(flatten)]
    pub job: JobView,
    pub function: String,
    #[serde(flatten)]
    pub outcome: Option<Outcome>,
}

impl AppJob {
    pub fn view(&self, since: u64) -> AppJobView {
        AppJobView { job: self.job.view(since), function: self.function.clone(), outcome: self.outcome.locked().clone() }
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
    backends: Mutex<HashMap<String, Arc<Backend>>>,
    jobs: Mutex<HashMap<String, Slot>>,
    pub calls: Arc<tokio::sync::Semaphore>,
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
        Self { cache: dir.join("cache"), backends: Mutex::default(), jobs: Mutex::default(), calls: Arc::new(tokio::sync::Semaphore::new(MAX_CALLS)) }
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
