//! A stack's long step (deploy, update, start, stop, remove): its commands run
//! one after another in their own process group, every output line kept for
//! the panel to read as it comes (by sequence number), cancellable.
//!
//! Not `/exec`: pulling images takes minutes, past what `[remote_access.exec]`
//! allows a request, and nobody's page has to stay open for it.

use std::collections::VecDeque;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::Duration;

use fl_pi_llm::host::Cancel;
use serde::Serialize;
use tokio::sync::{mpsc, watch};

use crate::agent_mode::command::{self, Spec, Stream};

/// Lines kept per job; older ones go first.
const MAX_LINES: usize = 4000;
/// One command's longest run: an image pull over a slow line.
const STEP_TIMEOUT: Duration = Duration::from_secs(3 * 3600);

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum JobKind {
    Install,
    Update,
    /// Deployed again with new settings.
    Reconfigure,
    Start,
    Stop,
    Restart,
    Remove,
    /// A container backup (`container_backups`).
    Backup,
    Restore,
    /// A change to the machine's disks (`api::storage`).
    Storage,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum JobState {
    Running,
    Succeeded,
    Failed,
    Cancelled,
}

#[derive(Debug, Clone, Serialize)]
pub struct Line {
    pub seq: u64,
    pub text: String,
}

/// What a page reads: the state and the lines after the one it has.
#[derive(Debug, Clone, Serialize)]
pub struct JobView {
    pub id: u64,
    pub kind: JobKind,
    pub state: JobState,
    pub error: Option<String>,
    pub lines: Vec<Line>,
    /// The next line's sequence number: what to ask from next time.
    pub next: u64,
}

pub struct Job {
    pub id: u64,
    pub kind: JobKind,
    lines: Mutex<VecDeque<Line>>,
    next: AtomicU64,
    state: watch::Sender<(JobState, Option<String>)>,
    cancel: Cancel,
}

static IDS: AtomicU64 = AtomicU64::new(1);

impl Job {
    pub fn new(kind: JobKind) -> Self {
        Self {
            id: IDS.fetch_add(1, Ordering::Relaxed),
            kind,
            lines: Mutex::new(VecDeque::new()),
            next: AtomicU64::new(0),
            state: watch::channel((JobState::Running, None)).0,
            cancel: Cancel::new(),
        }
    }

    pub fn push(&self, text: impl Into<String>) {
        let seq = self.next.fetch_add(1, Ordering::Relaxed);
        let mut lines = self.lines.lock().unwrap_or_else(|e| e.into_inner());
        if lines.len() >= MAX_LINES {
            lines.pop_front();
        }
        lines.push_back(Line { seq, text: text.into() });
    }

    pub fn state(&self) -> JobState {
        self.state.borrow().0
    }

    pub fn running(&self) -> bool {
        self.state() == JobState::Running
    }

    pub fn cancel(&self) {
        self.cancel.cancel();
    }

    pub fn finish(&self, state: JobState, error: Option<String>) {
        self.state.send_replace((state, error));
    }

    /// Resolves once the job has ended.
    pub async fn done(&self) -> JobState {
        let mut rx = self.state.subscribe();
        loop {
            let state = rx.borrow_and_update().0;
            if state != JobState::Running || rx.changed().await.is_err() {
                return state;
            }
        }
    }

    pub fn view(&self, since: u64) -> JobView {
        let (state, error) = self.state.borrow().clone();
        let lines = self.lines.lock().unwrap_or_else(|e| e.into_inner());
        JobView {
            id: self.id,
            kind: self.kind,
            state,
            error,
            lines: lines.iter().filter(|l| l.seq >= since).cloned().collect(),
            next: self.next.load(Ordering::Relaxed),
        }
    }

    /// Runs [script] as root (`sudo -S`, [password] on its stdin alone; an
    /// empty one does for root and `NOPASSWD`). The script holds no secret:
    /// it is logged as it is.
    pub async fn run_root(&self, script: &str, password: &str) -> Result<(), String> {
        if self.cancel.is_cancelled() {
            return Err("cancelled".into());
        }
        self.push(format!("# {script}"));
        let (tx, mut rx) = mpsc::unbounded_channel::<(Stream, String)>();
        let run = command::run(Spec { command: script, sudo_password: Some(password), timeout: STEP_TIMEOUT }, tx, &self.cancel);
        let drain = async {
            while let Some((_, line)) = rx.recv().await {
                self.push(line);
            }
        };
        let (finished, ()) = tokio::join!(run, drain);
        match finished {
            Err(e) => Err(e.to_string()),
            Ok(f) if f.cancelled => Err("cancelled".into()),
            Ok(f) if f.timed_out => Err("timed out".into()),
            Ok(f) if f.exit_code != Some(0) => Err(format!("exited with {}", f.exit_code.map_or("a signal".into(), |c| c.to_string()))),
            Ok(_) => Ok(()),
        }
    }

    /// Runs [steps] in order, each a shell command; stops at the first that
    /// fails. `Err` carries the summary kept as the stack's `last_error`.
    pub async fn run_steps(&self, steps: &[String]) -> Result<(), String> {
        for (i, step) in steps.iter().enumerate() {
            if self.cancel.is_cancelled() {
                return Err("cancelled".into());
            }
            self.push(format!("$ {step}"));
            let (tx, mut rx) = mpsc::unbounded_channel::<(Stream, String)>();
            let run = command::run(Spec { command: step, sudo_password: None, timeout: STEP_TIMEOUT }, tx, &self.cancel);
            let drain = async {
                while let Some((_, line)) = rx.recv().await {
                    self.push(line);
                }
            };
            let (finished, ()) = tokio::join!(run, drain);
            match finished {
                Err(e) => return Err(format!("step {}: {e}", i + 1)),
                Ok(f) if f.cancelled => return Err("cancelled".into()),
                Ok(f) if f.timed_out => return Err(format!("step {} timed out", i + 1)),
                Ok(f) if f.exit_code != Some(0) => {
                    return Err(format!("step {} exited with {}", i + 1, f.exit_code.map_or("a signal".into(), |c| c.to_string())));
                }
                Ok(_) => {}
            }
        }
        Ok(())
    }
}

#[cfg(all(test, unix))]
mod tests {
    use super::*;

    #[tokio::test]
    async fn steps_run_in_order_and_stop_at_a_failure() {
        let job = Job::new(JobKind::Install);
        let r = job.run_steps(&["echo one; echo two >&2".into(), "exit 3".into(), "echo never".into()]).await;
        assert_eq!(r.unwrap_err(), "step 2 exited with 3");
        let texts: Vec<String> = job.view(0).lines.into_iter().map(|l| l.text).collect();
        assert!(texts.contains(&"one".to_string()) && texts.contains(&"two".to_string()), "{texts:?}");
        assert!(!texts.contains(&"never".to_string()));
        assert_eq!(job.view(job.view(0).next).lines.len(), 0);
    }

    #[tokio::test]
    async fn a_cancel_ends_the_running_step() {
        let job = std::sync::Arc::new(Job::new(JobKind::Install));
        let running = job.clone();
        let handle = tokio::spawn(async move { running.run_steps(&["sleep 30".into()]).await });
        tokio::time::sleep(Duration::from_millis(200)).await;
        job.cancel();
        let r = tokio::time::timeout(Duration::from_secs(10), handle).await.expect("ended").expect("joined");
        assert_eq!(r.unwrap_err(), "cancelled");
    }

    #[tokio::test]
    async fn done_resolves_when_finished() {
        let job = std::sync::Arc::new(Job::new(JobKind::Stop));
        let waiter = job.clone();
        let wait = tokio::spawn(async move { waiter.done().await });
        job.finish(JobState::Succeeded, None);
        assert_eq!(wait.await.unwrap(), JobState::Succeeded);
    }
}
