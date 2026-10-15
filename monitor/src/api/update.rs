//! `GET /api/v1/update`: whether a newer agent is released, and how this one
//! is updated (`sbm_parser::monitor_agent`, shared with the app).
//!
//! The agent reads its releases itself, every [EVERY] and on a client's
//! `?check=1`, and leaves a desk notification once per newer version.
//!
//! `POST /update/run` starts `install.sh upgrade` outside the agent
//! (`sbm_parser::monitor_agent::start_update_script`): the upgrade restarts
//! the agent, which a terminal or a command the agent ran would not outlive.
//! Its output goes to `update.log` in the agent's directory, and `GET /update`
//! answers it as `run` — from the agent that comes back, too.

use crate::utils::lock::RwLockExt;
use std::sync::{Arc, RwLock};
use std::time::{Duration, Instant};

use ntex::web::{self, HttpRequest, HttpResponse};
use sbm_parser::monitor_agent::{self as agent, InstallKind};
use serde::{Deserialize, Serialize};
use tokio::sync::Mutex;

use super::authz;
use super::desk::{Level, Source, account};
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use super::desk_themes::{Fetch, HttpFetch};
use super::server::AppState;

/// How often the releases are read.
const EVERY: Duration = Duration::from_secs(12 * 3600);
/// The first read after a start, out of the way of the start itself.
const FIRST: Duration = Duration::from_secs(10);
/// The soonest a `?check=1` reads them again: GitHub allows 60 unsigned
/// requests an hour from one address.
const RECHECK: Duration = Duration::from_secs(60);
/// One page of 100 releases with their notes and assets.
const MAX_PAGE_BYTES: usize = 8 << 20;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// The last read of the releases.
#[derive(Debug, Clone, Serialize)]
pub struct Checked {
    /// The newest released version; absent when the read failed or found
    /// none.
    pub latest: Option<String>,
    /// When it was read (RFC 3339); absent before the first read.
    pub checked_at: Option<String>,
    /// Why it was not, in English.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
    #[serde(skip)]
    at: Option<Instant>,
}

/// How long an update with no exit mark is taken to be running; after that
/// it was cut short (the machine restarted, say).
const RUN_TIMEOUT: chrono::TimeDelta = chrono::TimeDelta::minutes(20);

pub struct AgentUpdate {
    fetch: RwLock<Arc<dyn Fetch>>,
    /// Answered at once: a read never holds it.
    last: RwLock<Option<Checked>>,
    /// Held through a read, so two do not run at once.
    reading: Mutex<()>,
    /// Where `update.log` is: the working directory, which an agent
    /// `install.sh` installed runs in.
    dir: RwLock<std::path::PathBuf>,
    /// For tests: how the agent was installed, rather than read off its
    /// binary.
    install: RwLock<Option<InstallKind>>,
    /// Held while one is being started.
    starting: Mutex<()>,
    /// Held while a newer version's notification is looked for and left.
    noticing: Mutex<()>,
}

impl Default for AgentUpdate {
    fn default() -> Self {
        Self {
            fetch: RwLock::new(Arc::new(HttpFetch::default())),
            last: RwLock::new(None),
            reading: Mutex::new(()),
            dir: RwLock::new(std::env::current_dir().unwrap_or_default()),
            install: RwLock::new(None),
            starting: Mutex::new(()),
            noticing: Mutex::new(()),
        }
    }
}

impl AgentUpdate {
    /// How releases are read: for tests, which answer from memory.
    pub fn set_fetch(&self, fetch: Arc<dyn Fetch>) {
        *self.fetch.write_locked() = fetch;
    }

    /// For tests: where the log is, and how the agent was installed.
    pub fn set_local(&self, dir: &std::path::Path, install: InstallKind) {
        *self.dir.write_locked() = dir.to_path_buf();
        *self.install.write_locked() = Some(install);
    }

    /// For tests: the last read taken as older than [RECHECK].
    pub fn age_last_read(&self) {
        if let Some(last) = self.last.write_locked().as_mut() {
            last.at = None;
        }
    }

    fn install(&self) -> InstallKind {
        (*self.install.read_locked()).unwrap_or_else(install_kind)
    }

    fn dir(&self) -> std::path::PathBuf {
        self.dir.read_locked().clone()
    }

    /// The last update started here, as its log tells it.
    async fn run(&self) -> Option<RunView> {
        let text = tokio::fs::read_to_string(self.dir().join(agent::UPDATE_LOG)).await.ok()?;
        let log = agent::read_update_log(&text);
        let started = log.started_at.as_deref().and_then(|at| chrono::DateTime::parse_from_rfc3339(at).ok());
        let state = match log.exit {
            Some(0) => RunState::Done,
            Some(_) => RunState::Failed,
            None if started.is_some_and(|at| chrono::Utc::now() - at.to_utc() < RUN_TIMEOUT) => RunState::Running,
            None => RunState::Interrupted,
        };
        Some(RunView { state, log })
    }

    /// The last read, at once; without [check] nothing waits on GitHub
    /// (the first read is [watch]'s, soon after the start). With [check], a
    /// fresh read when the last is older than [RECHECK]; whether this call
    /// made one is the second value.
    ///
    /// A read that fails keeps the version the last one found, with its
    /// error: a release once found is still out.
    pub async fn checked(&self, check: bool) -> (Checked, bool) {
        let stale = |last: &Option<Checked>| last.as_ref().is_none_or(|c| c.at.is_none_or(|at| at.elapsed() >= RECHECK));
        if !check || !stale(&self.last.read_locked()) {
            let last = self.last.read_locked().clone();
            return (last.unwrap_or(Checked { latest: None, checked_at: None, error: None, at: None }), false);
        }
        let _reading = self.reading.lock().await;
        // Another read may have finished while this one waited.
        if !stale(&self.last.read_locked()) {
            return (self.last.read_locked().clone().expect("read"), false);
        }
        let mut fresh = self.read().await;
        let mut last = self.last.write_locked();
        if fresh.error.is_some() {
            fresh.latest = last.as_ref().and_then(|c| c.latest.clone());
        }
        *last = Some(fresh.clone());
        (fresh, true)
    }

    async fn read(&self) -> Checked {
        let fetch = self.fetch.read_locked().clone();
        let (latest, error) = match newest(fetch.as_ref()).await {
            Ok(latest) => (latest, None),
            Err(e) => {
                tracing::warn!("update: reading the releases: {e}");
                (None, Some(e))
            }
        };
        Checked { latest, checked_at: Some(chrono::Utc::now().to_rfc3339()), error, at: Some(Instant::now()) }
    }
}

/// The newest agent release, walking pages as `install.sh` does.
async fn newest(fetch: &dyn Fetch) -> Result<Option<String>, String> {
    for page in 1..=agent::MAX_PAGES {
        let bytes = fetch.get(&agent::releases_url(page), MAX_PAGE_BYTES).await?;
        let read = agent::release_page(&String::from_utf8_lossy(&bytes));
        if read.newest.is_some() || !read.read_on {
            return Ok(read.newest);
        }
    }
    Ok(None)
}

/// How this agent was installed, from where its binary is.
pub fn install_kind() -> InstallKind {
    let exe = std::env::current_exe().map(|p| p.to_string_lossy().into_owned()).unwrap_or_default();
    let container = ["/.dockerenv", "/run/.containerenv"].iter().any(|p| std::path::Path::new(p).exists());
    agent::install_kind(&exe, container)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
enum RunState {
    Running,
    Done,
    Failed,
    /// No exit mark, and too long ago to be running still.
    Interrupted,
}

#[derive(Serialize)]
struct RunView {
    state: RunState,
    #[serde(flatten)]
    log: agent::UpdateLog,
}

#[derive(Serialize)]
struct UpdateView {
    /// This agent's version.
    version: &'static str,
    #[serde(flatten)]
    checked: Checked,
    /// Whether [latest] is newer than [version].
    outdated: bool,
    install: InstallKind,
    /// What updates it, run in a terminal on this machine: only for
    /// `install: script`.
    #[serde(skip_serializing_if = "Option::is_none")]
    command: Option<String>,
    /// Whether `POST /update/run` needs the sudo password
    /// (`sbm_parser::monitor_agent::update_needs_password`).
    needs_password: bool,
    /// The last update `POST /update/run` started, while its log is there.
    #[serde(skip_serializing_if = "Option::is_none")]
    run: Option<RunView>,
}

#[derive(Deserialize)]
pub struct UpdateQuery {
    /// `1`: read the releases again rather than answer the last read.
    #[serde(default)]
    check: Option<u8>,
}

pub async fn get(
    req: HttpRequest,
    query: web::types::Query<UpdateQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(response) = account(&req, &state).await {
        return Ok(response);
    }
    let (checked, read) = state.update.checked(query.check == Some(1)).await;
    if read {
        notice(&state, &checked).await;
    }
    let install = state.update.install();
    Ok(HttpResponse::Ok().json(&UpdateView {
        version: VERSION,
        outdated: checked.latest.as_deref().is_some_and(|l| agent::outdated(VERSION, l)),
        checked,
        install,
        command: (install == InstallKind::Script).then(agent::upgrade_command),
        needs_password: needs_password(),
        run: state.update.run().await,
    }))
}

fn needs_password() -> bool {
    agent::update_needs_password(std::path::Path::new("/run/systemd/system").exists(), crate::agent_mode::prompt::is_root())
}

#[derive(Deserialize)]
pub struct RunBody {
    /// The sudo password, where `needs_password`: on the starter's stdin
    /// alone, never stored or logged.
    #[serde(default)]
    password: Option<String>,
}

/// `POST /update/run`: starts the update and answers `202` once it is under
/// way. `409 {"error":"not_script"}` for an agent `install.sh` did not
/// install, `409 {"error":"running"}` while one runs, `403
/// {"error":"sudo_password"}` when root is needed and sudo refused the
/// password (or none was given). The acting rule.
pub async fn start(
    req: HttpRequest,
    body: web::types::Json<RunBody>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(response) = authz::acting_caller(&req, &state).await {
        return Ok(response);
    }
    let refused = |status: ntex::http::StatusCode, error: &str| {
        HttpResponse::build(status).json(&serde_json::json!({ "error": error }))
    };
    if state.update.install() != InstallKind::Script {
        return Ok(refused(ntex::http::StatusCode::CONFLICT, "not_script"));
    }
    let _starting = state.update.starting.lock().await;
    if state.update.run().await.is_some_and(|r| r.state == RunState::Running) {
        return Ok(refused(ntex::http::StatusCode::CONFLICT, "running"));
    }
    let dir = state.update.dir();
    let script = format!(
        "cd {} || exit 1\n{}",
        sbm_parser::script::shell_quote_unix(&dir.to_string_lossy()),
        agent::start_update_script()
    );
    let stdin = body.password.as_deref().map(|p| format!("{p}\n"));
    let limits = super::machine::at_least(&state.remote_access.exec, 64 << 10);
    let out = super::exec::run(&script, stdin.as_deref(), None, &limits).await;
    let event = Event::new(Kind::Machine, Action::Open, Outcome::Ok).remote_ip(peer_ip(&req));
    match out {
        Ok(out) if out.exit_code == Some(0) => {
            event.detail("update start").record(&state.db).await;
            Ok(HttpResponse::Accepted().json(&serde_json::json!({ "run": state.update.run().await })))
        }
        Ok(out) if out.exit_code == Some(agent::SUDO_REFUSED_EXIT) => {
            Event::new(Kind::Machine, Action::Denied, Outcome::Denied)
                .remote_ip(peer_ip(&req))
                .detail("update start: sudo refused")
                .record(&state.db)
                .await;
            Ok(refused(ntex::http::StatusCode::FORBIDDEN, "sudo_password"))
        }
        Ok(out) => {
            let why = format!("{}{}", out.stdout, out.stderr).trim().to_string();
            Event::new(Kind::Machine, Action::Open, Outcome::Error)
                .remote_ip(peer_ip(&req))
                .detail("update start failed")
                .record(&state.db)
                .await;
            Ok(HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "start", "message": why })))
        }
        Err(e) => Ok(HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "start", "message": e.to_string() }))),
    }
}

/// Reads the releases every [EVERY] until the agent stops.
pub async fn watch(state: Arc<AppState>) {
    tokio::time::sleep(FIRST).await;
    loop {
        let (checked, read) = state.update.checked(true).await;
        if read {
            notice(&state, &checked).await;
        }
        tokio::time::sleep(EVERY).await;
    }
}

/// A desk notification for a newer version, once per version: kept as the
/// notification itself, so one that has rotated out is said again. After a
/// read only, one at a time.
async fn notice(state: &AppState, checked: &Checked) {
    let Some(latest) = checked.latest.as_deref().filter(|l| agent::outdated(VERSION, l)) else { return };
    let _noticing = state.update.noticing.lock().await;
    let said: Result<bool, _> = sqlx::query_scalar(
        "SELECT EXISTS (SELECT 1 FROM desk_notification WHERE source = 'agent' AND kind = 'agent.update' \
         AND json_extract(params, '$.version') = ?)",
    )
    .bind(latest)
    .fetch_one(&state.db)
    .await;
    if said.unwrap_or(true) {
        return;
    }
    let params = serde_json::json!({ "version": latest, "current": VERSION });
    if let Err(e) = state
        .desk
        .notify(
            &state.db,
            Level::Info,
            Source::Agent,
            "ServerBox Monitor: an update",
            &format!("Version {latest} can be installed (now {VERSION})."),
            Some(("agent.update", &params)),
        )
        .await
    {
        tracing::error!("update: notifying: {e}");
    }
}
