//! Agent mode: an AI agent that works on this machine for an account — reads
//! its state, proposes a plan, runs commands once they are confirmed.
//!
//! # pi, on the server
//!
//! The agent loop is pi's (`pi-durable`, `pi-ai`), run by `fl_pi_llm`'s
//! Rust host: the same bundle the apps run, so a task here is a pi session in
//! the format theirs are in. It runs on the server, not in a browser: a task
//! goes on when the page that started it closes, and every page and app that
//! opens it sees the same thing.
//!
//! A task ("flow") is one pi session, a pi-durable storage in
//! `<database dir>/agent/chats/<id>.db` (the agent's own state, outside every
//! file root), and one `agent_flow` row that
//! lists and owns it. What happens while it runs — model output, commands
//! and their output, what it waits on — goes out on [`AgentMode::subscribe`].
//!
//! # What runs without asking
//!
//! The model calls three tools (`tools.rs`): `run_command`, `propose_plan`,
//! `ask_user`. The configured command rules come first; then a command runs
//! unasked when both readers call it a read: the model's `effect` and
//! `sbm_parser::command_risk`. Anything else goes by the task's mode
//! (`permissions`): asked, judged by the model, or run — a plan the account
//! approved covers the commands the plan listed, word for word — and outside
//! `bypass` a command that cannot be undone asks for the machine's name to
//! be typed, plan or not. A sudo password is asked
//! for when needed, used on sudo's stdin only, and kept in memory for 15
//! minutes when the account says so; never written anywhere.
//!
//! # Privilege
//!
//! A task runs commands as the agent's user, which is what a shell does. The
//! transport rule is checked when a task is started or answered, and again
//! before every command — after a password change, or over a link that may
//! no longer act, nothing more runs.

pub(crate) mod command;
mod pi_file;
pub mod files;
mod memory;
pub mod config;
pub mod mcp;
pub mod mcp_oauth;
pub mod skills;
pub mod permissions;
pub(crate) mod prompt;
mod search;
mod tools;

use zeroize::Zeroizing;
use crate::utils::lock::{LockExt, RwLockExt};
use std::collections::{HashMap, HashSet, VecDeque};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use fl_pi_llm::host::memory::Memory;
use fl_pi_llm::host::{BoxFuture, Cancel, Config as PiConfig, OpenSession, ReqwestFetch, Runtime, Session};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};
use sqlx::SqlitePool;
use tokio::sync::{broadcast, oneshot};

use crate::api::server::AppState;

pub use search::SearchKind;
pub use tools::{PlanStep, Choice};

/// Kept in memory after the account said so, then asked again.
const SUDO_REMEMBER: Duration = Duration::from_secs(15 * 60);
/// The longest prompt or reply, in bytes. A pasted log fits; a disk image
/// does not.
pub const MAX_PROMPT: usize = 512 << 10;
/// The longest title.
const MAX_TITLE_CHARS: usize = 80;
/// The lines of the running command a list shows.
const TAIL_LINES: usize = 6;
/// The oldest finished ones go first.
pub const MAX_FLOWS: i64 = 500;
/// The most tasks one page of the list holds.
pub const MAX_PAGE: i64 = 200;

/// What `GET /agent/flows` is asked for: a page of `limit` after the cursor
/// `before` (`<updatedAt>|<id>`, as the last page answered), and only tasks
/// whose title or last line contains `q`. Absent `limit` is every task.
#[derive(Debug, Default, Deserialize)]
pub struct ListQuery {
    pub limit: Option<i64>,
    pub before: Option<String>,
    pub q: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Status {
    Queued,
    Running,
    Waiting,
    Done,
    Failed,
    Cancelled,
}

impl Status {
    pub fn as_str(self) -> &'static str {
        match self {
            Status::Queued => "queued",
            Status::Running => "running",
            Status::Waiting => "waiting",
            Status::Done => "done",
            Status::Failed => "failed",
            Status::Cancelled => "cancelled",
        }
    }

    fn parse(s: &str) -> Status {
        match s {
            "queued" => Status::Queued,
            "running" => Status::Running,
            "waiting" => Status::Waiting,
            "done" => Status::Done,
            "cancelled" => Status::Cancelled,
            _ => Status::Failed,
        }
    }

    pub fn active(self) -> bool {
        matches!(self, Status::Queued | Status::Running | Status::Waiting)
    }
}

/// A task as a list shows it.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FlowView {
    pub id: String,
    pub title: String,
    pub status: Status,
    /// What it is doing, or what it did.
    pub line: String,
    pub areas: Vec<String>,
    /// The permission mode it was started in (`permissions`).
    pub mode: permissions::Mode,
    /// The model and thinking level its account picked; absent is the
    /// machine's, whatever that is when it runs.
    pub model: Option<config::ModelRef>,
    pub thinking_level: Option<String>,
    pub created_at: String,
    pub updated_at: String,
    pub started_at: Option<String>,
    pub finished_at: Option<String>,
    /// What it waits on, when it does: the kind of [`PendingView`].
    pub waiting: Option<&'static str>,
    /// The steps so far, while it is active: what a list draws its progress
    /// from. A finished task's are in its session.
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub steps: Vec<StepBrief>,
    /// The last lines of the running command, while there is one.
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub tail: Vec<(u8, String)>,
}

/// What starts a task.
pub struct NewTask {
    pub prompt: String,
    /// Absent is the machine's default.
    pub mode: Option<permissions::Mode>,
    /// Uploads ([`files::Files::put`]) it is given.
    pub files: Vec<String>,
    pub choice: TaskChoice,
}

/// The model and thinking level a task is started or replied to with; absent
/// keeps what it had (the machine's, for a new one).
#[derive(Debug, Default, Clone, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct TaskChoice {
    #[serde(default)]
    pub model: Option<config::ModelRef>,
    #[serde(default)]
    pub thinking_level: Option<String>,
}

/// One step (a tool call) as a list shows it.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct StepBrief {
    pub tool_call_id: String,
    pub title: String,
    pub area: String,
    /// `running` | `waiting` | `done` | `failed` | `cancelled`.
    pub state: &'static str,
}

/// What a task waits on the account for.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PendingView {
    pub id: String,
    /// `confirm` (a plan or a command), `danger` (a command that cannot be
    /// undone), `sudo` (a password), `clarify` (a choice).
    pub kind: &'static str,
    pub tool_call_id: String,
    pub title: String,
    #[serde(skip_serializing_if = "String::is_empty")]
    pub summary: String,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub steps: Vec<PlanStep>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub command: Option<String>,
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub options: Vec<Choice>,
    /// Other ways out a `danger` offers (`先备份再删除`), told to the model
    /// when picked.
    #[serde(skip_serializing_if = "Vec::is_empty")]
    pub alternatives: Vec<String>,
    /// What has to be typed to run a `danger` command: the machine's name.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub confirm_text: Option<String>,
    /// Whose password `sudo` asks for.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user: Option<String>,
    /// The allow rule a command's `confirm` offers to add ("always allow",
    /// `command_rules::suggest`).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub allow_rule: Option<String>,
    /// Why the last answer was not taken (a wrong password).
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

/// An answer to a [`PendingView`].
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
pub struct Answer {
    /// The [`PendingView::id`] answered: an answer to something no longer
    /// asked is refused rather than taken for what is asked now.
    pub id: String,
    /// `run`, `cancel`, `edit` (with `text`), `pick` (with `index`), `text`
    /// (with `text`), `password` (with `password`, `remember`),
    /// `alternative` (with `index`).
    pub action: String,
    #[serde(default)]
    pub text: Option<String>,
    #[serde(default)]
    pub index: Option<usize>,
    #[serde(default)]
    pub password: Option<String>,
    #[serde(default)]
    pub remember: bool,
    /// For `danger`: what was typed.
    #[serde(default)]
    pub confirm: Option<String>,
}

struct Pending {
    view: PendingView,
    answer: oneshot::Sender<Answer>,
}

/// The command running now, and its output so far.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LiveOutput {
    pub tool_call_id: String,
    /// `[stream, text]`: 1 stdout, 2 stderr.
    pub lines: Vec<(u8, String)>,
    pub omitted: usize,
}

/// What goes out to a page. `user` scopes it.
#[derive(Debug, Clone)]
pub struct AgentEvent {
    pub user: i64,
    pub payload: Value,
}

/// A task while it is active (queued, running or waiting).
pub(crate) struct Flow {
    pub id: String,
    pub user_id: i64,
    /// Whether the request that last set it going came over a secure link:
    /// what the transport rule is checked against at each command.
    secure: Mutex<bool>,
    view: Mutex<FlowView>,
    pending: Mutex<Option<Pending>>,
    /// Turns typed while it runs: text and pi `ImageContent` parts.
    replies: Mutex<VecDeque<(String, Option<Value>)>>,
    /// Commands a plan the account approved listed.
    approved: Mutex<HashSet<String>>,
    output: Mutex<Option<LiveOutput>>,
    steps: Mutex<Vec<StepBrief>>,
    session: Mutex<Option<Arc<Session>>>,
    cancel: Mutex<Cancel>,
}

impl Flow {
    fn status(&self) -> Status {
        self.view.locked().status
    }

    fn view(&self) -> FlowView {
        let mut v = self.view.locked().clone();
        v.waiting = self.pending.locked().as_ref().map(|p| p.view.kind);
        v.steps = self.steps.locked().clone();
        v.tail = self.output.locked().as_ref().map(|o| o.lines[o.lines.len().saturating_sub(TAIL_LINES)..].to_vec()).unwrap_or_default();
        v
    }

    pub(crate) fn secure(&self) -> bool {
        *self.secure.locked()
    }

    pub(crate) fn cancel_token(&self) -> Cancel {
        self.cancel.locked().clone()
    }
}

/// By account id: the sudo password, wiped when dropped, and when it was given.
type SudoCache = HashMap<i64, (Zeroizing<String>, Instant)>;

pub struct AgentMode {
    db: SqlitePool,
    /// Where tasks' chats, files and skills are.
    dir: PathBuf,
    /// Removed with this value: the directory made for an in-memory database.
    owned: bool,
    fetch: Arc<AgentFetch>,
    runtime: tokio::sync::Mutex<Option<Runtime>>,
    /// Held for writing while the endpoints' models are listed: a model one
    /// lists is pi's only once listed, so what runs one waits
    /// ([`Self::ready_runtime`]); what only reads does not.
    listing: Arc<tokio::sync::RwLock<()>>,
    /// One model listing at a time: each widens what plain HTTP may reach.
    probing: tokio::sync::Mutex<()>,
    /// Held while a session is opened or closed, so a read of a finished task
    /// and a reply to it never open it twice.
    opening: tokio::sync::Mutex<()>,
    flows: Mutex<HashMap<String, Arc<Flow>>>,
    /// Tasks waiting their turn: the id and its first prompt (text and pi
    /// `ImageContent` parts).
    queue: Mutex<VecDeque<(String, String, Option<Value>)>>,
    pub files: files::Files,
    max_running: AtomicI64,
    events: broadcast::Sender<AgentEvent>,
    /// By account id: the password, and when it was given.
    sudo: Arc<Mutex<SudoCache>>,
    /// By account id: its memory, held once so its changes are made one at
    /// a time.
    memories: Mutex<HashMap<i64, Arc<Memory>>>,
    /// Searches not yet carried into a task, by session id.
    searches: Mutex<HashMap<String, search::SearchEntry>>,
    /// By account id: its running search, to end when it searches again.
    search_runs: Mutex<HashMap<i64, (u64, Cancel)>>,
    search_seq: std::sync::atomic::AtomicU64,
    hostname: String,
    /// The MCP servers' connections, kept between tasks.
    pub mcp: mcp::Hub,
    /// OAuth sign-ins to MCP servers waiting for the browser to come back.
    pub mcp_oauth: mcp_oauth::Flows,
    /// Where the skills are (`skills::root`).
    pub skills_root: PathBuf,
    /// The model servers on this machine offered as providers
    /// ([`Self::set_app_providers`]).
    apps: Arc<std::sync::RwLock<Vec<config::AppProvider>>>,
}

/// Agent mode's network: [`ReqwestFetch`], kept to this machine when asked
/// ([`AgentMode::reach_this_machine_only`]).
struct AgentFetch {
    inner: ReqwestFetch,
    this_machine_only: AtomicBool,
}

impl AgentFetch {
    fn set_insecure_origins(&self, origins: Vec<String>) {
        self.inner.set_insecure_origins(origins);
    }
}

impl fl_pi_llm::host::Fetch for AgentFetch {
    fn fetch(&self, req: fl_pi_llm::host::FetchRequest) -> BoxFuture<'_, Result<fl_pi_llm::host::FetchResponse, String>> {
        if self.this_machine_only.load(Ordering::Relaxed) {
            let local = url::Url::parse(&req.url).ok().and_then(|u| u.host_str().map(String::from)).is_some_and(|h| {
                h == "localhost" || h.trim_matches(['[', ']']).parse::<std::net::IpAddr>().is_ok_and(|ip| ip.is_loopback())
            });
            if !local {
                return Box::pin(async move { Err(format!("{}: this agent reaches this machine alone", req.url)) });
            }
        }
        self.inner.fetch(req)
    }
}

static TEMP: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

impl AgentMode {
    /// Sessions in `agent/` beside the database file [db_file], or in a
    /// directory of its own for an in-memory database.
    pub fn new(db: SqlitePool, db_file: Option<&Path>) -> Self {
        let (dir, owned) = match db_file {
            Some(f) => (Self::dir_beside(f), false),
            None => {
                let n = TEMP.fetch_add(1, Ordering::Relaxed);
                (std::env::temp_dir().join(format!("sbm-agent-{}-{n}", std::process::id())), true)
            }
        };
        // reqwest is built without a crypto provider; the agent's is ring.
        let _ = rustls::crypto::ring::default_provider().install_default();
        let client = reqwest::Client::builder()
            // Not followed: the address a request was allowed to was judged,
            // not wherever it is sent on to with the key.
            .redirect(reqwest::redirect::Policy::none())
            .connect_timeout(Duration::from_secs(20))
            .read_timeout(Duration::from_secs(300))
            .build()
            .expect("a valid HTTP client");
        Self {
            db,
            files: files::Files::new(&dir),
            owned,
            fetch: Arc::new(AgentFetch { inner: ReqwestFetch::new(client), this_machine_only: AtomicBool::new(false) }),
            runtime: tokio::sync::Mutex::new(None),
            listing: Arc::default(),
            opening: tokio::sync::Mutex::new(()),
            probing: tokio::sync::Mutex::new(()),
            flows: Mutex::default(),
            queue: Mutex::default(),
            max_running: AtomicI64::new(config::DEFAULT_MAX_RUNNING),
            events: broadcast::channel(1024).0,
            sudo: Arc::default(),
            memories: Mutex::default(),
            searches: Mutex::default(),
            search_runs: Mutex::default(),
            search_seq: std::sync::atomic::AtomicU64::new(0),
            hostname: hostname::get().map(|h| h.to_string_lossy().into_owned()).unwrap_or_else(|_| "localhost".into()),
            mcp: mcp::Hub::default(),
            mcp_oauth: mcp_oauth::Flows::default(),
            skills_root: skills::root(&dir),
            apps: Arc::default(),
            dir,
        }
    }

    /// Where sessions are kept for the database file [db_file]: the agent's
    /// own state (`fs_roots::Protected`).
    pub fn dir_beside(db_file: &Path) -> PathBuf {
        db_file.parent().unwrap_or_else(|| Path::new(".")).join("agent")
    }

    /// The account [user]'s memory.
    pub fn memory(&self, user: i64) -> Arc<Memory> {
        self.memories
            .locked()
            .entry(user)
            .or_insert_with(|| Arc::new(Memory::new(Arc::new(memory::DbMemory { db: self.db.clone(), user_id: user }))))
            .clone()
    }

    /// The built-in auto mode lists, for this machine.
    pub fn auto_defaults(&self) -> Value {
        permissions::defaults(&self.hostname, &prompt::os_name(), &prompt::system_user())
    }

    /// The network Agent mode uses: for MCP servers and skill downloads too.
    pub fn fetch(&self) -> Arc<dyn fl_pi_llm::host::Fetch> {
        self.fetch.clone()
    }

    /// From now on Agent mode reaches this machine alone: for tests, whose
    /// models and servers are on loopback, so none depends on the internet
    /// (a model listing's metadata, `fl_pi_llm`'s, is then left out).
    #[doc(hidden)]
    pub fn reach_this_machine_only(&self) {
        self.fetch.this_machine_only.store(true, Ordering::Relaxed);
    }

    pub fn hostname(&self) -> &str {
        &self.hostname
    }

    pub fn subscribe(&self) -> broadcast::Receiver<AgentEvent> {
        self.events.subscribe()
    }

    fn emit(&self, user: i64, payload: Value) {
        let _ = self.events.send(AgentEvent { user, payload });
    }

    /// Tasks a stopped agent left active can go on no more: they are failed,
    /// and a reply starts them again. Sessions no row names are deleted. Run
    /// at start.
    pub async fn recover(&self) -> anyhow::Result<()> {
        let now = chrono::Utc::now().to_rfc3339();
        sqlx::query(
            "UPDATE agent_flow SET status = 'failed', line = 'interrupted', updated_at = ?, finished_at = ? \
             WHERE status IN ('queued', 'running', 'waiting')",
        )
        .bind(&now)
        .bind(&now)
        .execute(&self.db)
        .await?;
        self.drop_legacy_sessions().await?;
        let known: HashSet<String> = sqlx::query_scalar("SELECT id FROM agent_flow").fetch_all(&self.db).await?.into_iter().collect();
        self.files.recover(&known).await;
        let chats = self.dir.join("chats");
        tokio::task::spawn_blocking(move || {
            for chat in fl_pi_llm::db::list(&chats)? {
                if !known.contains(&chat.id) {
                    fl_pi_llm::db::remove(&chats, &chat.id)?;
                }
            }
            Ok::<_, String>(())
        })
        .await?
        .map_err(anyhow::Error::msg)
    }

    /// TODO: remove once no agent keeps a task from before fl_pi_llm kept
    /// chats in SQLite. Its sessions (`chats/<id>/` with `meta/<id>.json`, or
    /// `sessions/<cwd>/<created>_<id>.jsonl` from before pi-durable) are no
    /// longer read, so they go with their tasks. Agent mode never shipped in
    /// them.
    async fn drop_legacy_sessions(&self) -> anyhow::Result<()> {
        let mut ids = Vec::new();
        if let Ok(mut dirs) = tokio::fs::read_dir(self.dir.join("chats")).await {
            while let Some(d) = dirs.next_entry().await? {
                if d.file_type().await?.is_dir() {
                    ids.push(decode_component(&d.file_name().to_string_lossy()));
                    tokio::fs::remove_dir_all(d.path()).await?;
                }
            }
        }
        if let Ok(mut dirs) = tokio::fs::read_dir(self.dir.join("sessions")).await {
            while let Some(d) = dirs.next_entry().await? {
                let Ok(mut files) = tokio::fs::read_dir(d.path()).await else { continue };
                while let Some(f) = files.next_entry().await? {
                    // pi names a session `<created>_<id>.jsonl`.
                    let name = f.file_name().to_string_lossy().into_owned();
                    if let Some((_, id)) = name.strip_suffix(".jsonl").and_then(|n| n.split_once('_')) {
                        ids.push(decode_component(id));
                    }
                }
            }
        }
        for gone in ["meta", "sessions"] {
            match tokio::fs::remove_dir_all(self.dir.join(gone)).await {
                Err(e) if e.kind() != std::io::ErrorKind::NotFound => return Err(e.into()),
                _ => {}
            }
        }
        for id in &ids {
            sqlx::query("DELETE FROM agent_flow WHERE id = ?").bind(id).execute(&self.db).await?;
        }
        if !ids.is_empty() {
            tracing::warn!("agent mode: {} task(s) kept in a format no longer read were removed", ids.len());
        }
        Ok(())
    }

    /// The runtime, started on first use with the current configuration.
    async fn runtime(&self) -> anyhow::Result<Runtime> {
        let mut rt = self.runtime.lock().await;
        if let Some(r) = rt.as_ref() {
            return Ok(r.clone());
        }
        let r = Runtime::start(PiConfig {
            dir: self.dir.clone(),
            credentials: Arc::new(config::AppCredentials { db: config::DbCredentials(self.db.clone()), apps: self.apps.clone() }),
            fetch: self.fetch.clone(),
            logger: Some(Arc::new(|level, message| match level {
                "error" => tracing::error!("agent mode: {message}"),
                "warn" => tracing::warn!("agent mode: {message}"),
                _ => tracing::debug!("agent mode: {message}"),
            })),
        })
        .map_err(|e| anyhow::anyhow!("{e}"))?;
        self.apply(&r, &config::load(&self.db).await?).await?;
        *rt = Some(r.clone());
        Ok(r)
    }

    /// [`Self::runtime`] once the endpoints' models are listed: for what runs
    /// a model.
    async fn ready_runtime(&self) -> anyhow::Result<Runtime> {
        let rt = self.runtime().await?;
        drop(self.listing.read().await);
        Ok(rt)
    }

    /// The operator's providers, then the app providers whose id none of
    /// those takes.
    fn providers(&self, settings: &config::Settings) -> Vec<config::Provider> {
        let mut all = settings.providers.clone();
        for app in self.apps.read_locked().iter() {
            if !all.iter().any(|p| p.id == app.provider.id) {
                all.push(app.provider.clone());
            }
        }
        all
    }

    /// The model servers on this machine to offer as providers; applied
    /// when they changed.
    pub async fn set_app_providers(&self, apps: Vec<config::AppProvider>) -> anyhow::Result<()> {
        {
            let mut current = self.apps.write_locked();
            if *current == apps {
                return Ok(());
            }
            *current = apps;
        }
        self.reconfigure().await
    }

    pub fn app_providers(&self) -> Vec<config::AppProvider> {
        self.apps.read_locked().clone()
    }

    async fn apply(&self, rt: &Runtime, settings: &config::Settings) -> anyhow::Result<()> {
        let providers = self.providers(settings);
        self.fetch.set_insecure_origins(providers.iter().filter_map(config::Provider::insecure_origin).collect());
        rt.set_custom_providers(Value::Array(providers.iter().map(config::Provider::to_pi).collect()))
            .await
            .map_err(|e| anyhow::anyhow!("{e}"))?;
        self.max_running.store(settings.max_running, Ordering::Relaxed);
        // An endpoint's listed models exist for pi only once listed (from its
        // cache, or the endpoint): until then a model it lists is "unavailable"
        // and no task can open. Listed apart, so a slow endpoint holds up only
        // what runs a model.
        let listing: Vec<String> = providers.iter().filter(|p| p.lists_models()).map(|p| p.id.clone()).collect();
        if !listing.is_empty() {
            let listed = self.listing.clone().write_owned().await;
            let rt = rt.clone();
            tokio::spawn(async move {
                match rt.request("providers.refresh", json!({ "providers": listing })).await {
                    Ok(v) => {
                        for (id, e) in v["errors"].as_object().into_iter().flatten() {
                            tracing::warn!("agent mode: listing the models of {id}: {e}");
                        }
                    }
                    Err(e) => tracing::warn!("agent mode: listing models: {e}"),
                }
                drop(listed);
            });
        }
        Ok(())
    }

    /// After the configuration changed.
    pub async fn reconfigure(&self) -> anyhow::Result<()> {
        let settings = config::load(&self.db).await?;
        self.max_running.store(settings.max_running, Ordering::Relaxed);
        let rt = self.runtime.lock().await.clone();
        if let Some(rt) = rt {
            self.apply(&rt, &settings).await?;
        }
        Ok(())
    }

    /// The models the endpoint [base_url] lists, before it is saved: with
    /// [key], or the credential stored for [stored_for]. Only an
    /// OpenAI-compatible endpoint lists its models.
    pub async fn probe(&self, api: &str, base_url: &str, allow_insecure: bool, key: Option<String>, stored_for: Option<&str>) -> Result<Value, FlowError> {
        config::check_endpoint(api, base_url, allow_insecure).map_err(FlowError::Invalid)?;
        let credential = match (key, stored_for) {
            (Some(k), _) if !k.trim().is_empty() => Some(json!({ "type": "api_key", "key": k.trim() })),
            (_, Some(id)) => fl_pi_llm::host::Credentials::read(&config::DbCredentials(self.db.clone()), id).await.map_err(|e| anyhow::anyhow!(e))?,
            _ => None,
        };
        let rt = self.runtime().await?;
        let provider = config::Provider {
            id: "probe".into(),
            name: "probe".into(),
            api: api.into(),
            base_url: base_url.trim_end_matches('/').into(),
            allow_insecure,
            models: Vec::new(),
        };
        // The endpoint being set up is allowed plain HTTP for this request
        // alone, on the terms it is being set up with.
        let _one = self.probing.lock().await;
        let saved: Vec<String> = self.providers(&config::load(&self.db).await?).iter().filter_map(config::Provider::insecure_origin).collect();
        if let Some(origin) = provider.insecure_origin() {
            self.fetch.set_insecure_origins(saved.iter().cloned().chain([origin]).collect());
        }
        let r = rt.request("providers.probe", json!({ "provider": provider.to_pi(), "credential": credential })).await;
        self.fetch.set_insecure_origins(saved);
        r.map_err(|e| FlowError::Upstream(e.0))
    }

    /// The models the configured providers offer, as pi lists them.
    pub async fn models(&self) -> anyhow::Result<Value> {
        let rt = self.runtime().await?;
        let _ = rt.request("providers.refresh", json!({})).await;
        rt.request("providers.list", json!({})).await.map_err(|e| anyhow::anyhow!("{e}"))
    }

    // -------------------------------------------------------------------------
    // Listing

    /// The account's tasks, newest change first: a page of [q]'s `limit` after
    /// its `before` cursor, or all of them without a limit. Answers the
    /// cursor of the next page, if there is one.
    pub async fn list(&self, user: i64, q: &ListQuery) -> Result<(Vec<FlowView>, Option<String>), sqlx::Error> {
        let after = q.before.as_deref().and_then(|c| c.split_once('|'));
        let needle = q.q.as_deref().map(str::trim).filter(|t| !t.is_empty()).map(|t| {
            let escaped = t.replace('\\', "\\\\").replace('%', "\\%").replace('_', "\\_");
            format!("%{escaped}%")
        });
        let limit = q.limit.map(|l| l.clamp(1, MAX_PAGE));
        // A NULL turns its condition off; `LIMIT -1` is no limit. One more row
        // than asked says whether there is a next page.
        let mut rows = sqlx::query_as::<_, Row>(
            "SELECT id, title, status, line, areas, mode, model, thinking_level, created_at, updated_at, started_at, finished_at FROM agent_flow \
             WHERE user_id = ?1 \
             AND (?2 IS NULL OR updated_at < ?2 OR (updated_at = ?2 AND id < ?3)) \
             AND (?4 IS NULL OR title LIKE ?4 ESCAPE '\\' OR line LIKE ?4 ESCAPE '\\') \
             ORDER BY updated_at DESC, id DESC LIMIT ?5",
        )
        .bind(user)
        .bind(after.map(|(at, _)| at))
        .bind(after.map(|(_, id)| id))
        .bind(needle)
        .bind(limit.map_or(-1, |l| l + 1))
        .fetch_all(&self.db)
        .await?;
        let next = match limit {
            Some(l) if rows.len() as i64 > l => {
                rows.truncate(l as usize);
                rows.last().map(|r| format!("{}|{}", r.updated_at, r.id))
            }
            _ => None,
        };
        let active = self.flows.locked();
        let flows = rows
            .into_iter()
            .map(|r| match active.get(&r.id) {
                Some(f) => f.view(),
                None => r.view(),
            })
            .collect();
        Ok((flows, next))
    }

    async fn row(&self, user: i64, id: &str) -> Result<Option<FlowView>, sqlx::Error> {
        if let Some(f) = self.active(user, id) {
            return Ok(Some(f.view()));
        }
        let row = sqlx::query_as::<_, Row>(
            "SELECT id, title, status, line, areas, mode, model, thinking_level, created_at, updated_at, started_at, finished_at FROM agent_flow \
             WHERE user_id = ? AND id = ?",
        )
        .bind(user)
        .bind(id)
        .fetch_optional(&self.db)
        .await?;
        Ok(row.map(Row::view))
    }

    fn active(&self, user: i64, id: &str) -> Option<Arc<Flow>> {
        self.flows.locked().get(id).filter(|f| f.user_id == user).cloned()
    }

    /// One task whole: its row, the entries on its session's current branch,
    /// what it waits on and the output of the command running now.
    pub async fn detail(&self, state: &Arc<AppState>, user: i64, id: &str) -> Result<Option<Value>, FlowError> {
        let Some(view) = self.row(user, id).await? else { return Ok(None) };
        let active = self.active(user, id);
        let mut entries = self.entries(state, id, active.as_ref()).await?;
        entries.iter_mut().for_each(files::annotate_entry);
        let (pending, output) = match &active {
            Some(f) => (f.pending.locked().as_ref().map(|p| p.view.clone()), f.output.locked().clone()),
            None => (None, None),
        };
        Ok(Some(json!({ "flow": view, "entries": entries, "pending": pending, "output": output })))
    }

    async fn entries(&self, state: &Arc<AppState>, id: &str, active: Option<&Arc<Flow>>) -> Result<Vec<Value>, FlowError> {
        let _open = self.opening.lock().await;
        if let Some(s) = active.and_then(|f| f.session.locked().clone()) {
            return Ok(s.entries().await?);
        }
        // Not open: opened to be read, and closed again.
        let rt = self.runtime().await?;
        let Some(model) = config::load(&self.db).await?.model else { return Err(FlowError::NotConfigured) };
        let tools = tools::all(state.clone(), None);
        let (s, _events) = rt
            .open_session(OpenSession {
                id: id.to_string(),
                model: json!(model),
                system_prompt: String::new(),
                tools,
                approver: None,
                thinking_level: None,
                compaction: None,
            })
            .await?;
        let entries = s.entries().await;
        s.close().await?;
        Ok(entries?)
    }

    // -------------------------------------------------------------------------
    // Starting, replying, answering, stopping

    /// Starts [task] for [user]. Answers its row; it runs when its turn
    /// comes.
    pub async fn start(self: &Arc<Self>, state: &Arc<AppState>, user: i64, secure: bool, task: NewTask) -> Result<FlowView, FlowError> {
        let NewTask { prompt, mode, files: file_ids, choice } = task;
        if config::load(&self.db).await?.model.is_none() {
            return Err(FlowError::NotConfigured);
        }
        self.check_choice(&choice).await?;
        let perms = permissions::load(&self.db).await?;
        let mode = mode.unwrap_or(perms.default_mode);
        if perms.mode_for(mode) != mode {
            return Err(FlowError::Invalid("bypassDisabled"));
        }
        if !self.files.has(user, &file_ids) {
            return Err(FlowError::Invalid("unknownFile"));
        }
        let id = uuid_v4();
        let now = chrono::Utc::now().to_rfc3339();
        let attached = self.attach(user, &id, &file_ids).await?;
        let named = match attached.first() {
            Some(f) if prompt.trim().is_empty() => f.name.clone(),
            _ => prompt.clone(),
        };
        let title = first_line(&named, MAX_TITLE_CHARS);
        let (text, images) = files::compose(&prompt, &attached, true).await;
        let inserted = sqlx::query(
            "INSERT INTO agent_flow (id, user_id, title, status, line, areas, mode, model, thinking_level, created_at, updated_at) \
             VALUES (?, ?, ?, 'queued', '', '[]', ?, ?, ?, ?, ?)",
        )
        .bind(&id)
        .bind(user)
        .bind(&title)
        .bind(mode.as_str())
        .bind(choice.model.as_ref().map(|m| serde_json::to_string(m).expect("a model reference serialises")))
        .bind(&choice.thinking_level)
        .bind(&now)
        .bind(&now)
        .execute(&self.db)
        .await;
        if let Err(e) = inserted {
            self.files.remove_task(&id).await;
            return Err(e.into());
        }
        self.trim(user).await?;
        let view = FlowView {
            id: id.clone(),
            title,
            status: Status::Queued,
            line: String::new(),
            areas: Vec::new(),
            mode,
            model: choice.model,
            thinking_level: choice.thinking_level,
            created_at: now.clone(),
            updated_at: now,
            started_at: None,
            finished_at: None,
            waiting: None,
            steps: Vec::new(),
            tail: Vec::new(),
        };
        let flow = Arc::new(Flow {
            id: id.clone(),
            user_id: user,
            secure: Mutex::new(secure),
            view: Mutex::new(view.clone()),
            pending: Mutex::new(None),
            replies: Mutex::new(VecDeque::new()),
            approved: Mutex::new(HashSet::new()),
            output: Mutex::new(None),
            steps: Mutex::new(Vec::new()),
            session: Mutex::new(None),
            cancel: Mutex::new(Cancel::new()),
        });
        self.flows.locked().insert(id.clone(), flow.clone());
        self.queue.locked().push_back((id.clone(), text, images));
        self.emit(user, json!({ "type": "flow", "flow": view }));
        self.schedule(state);
        self.name_later(user, id, named);
        Ok(flow.view())
    }

    /// Keeps the newest [`MAX_FLOWS`] of [user]'s tasks.
    async fn trim(&self, user: i64) -> Result<(), sqlx::Error> {
        let old: Vec<String> = sqlx::query_scalar(
            "SELECT id FROM agent_flow WHERE user_id = ? AND status IN ('done', 'failed', 'cancelled') \
             ORDER BY updated_at DESC LIMIT -1 OFFSET ?",
        )
        .bind(user)
        .bind(MAX_FLOWS)
        .fetch_all(&self.db)
        .await?;
        for id in old {
            let _ = self.remove_stored(user, &id).await;
        }
        Ok(())
    }

    /// A title better than the prompt's first line, from the model, when it
    /// answers; the first line stays otherwise.
    fn name_later(self: &Arc<Self>, user: i64, id: String, prompt: String) {
        let this = self.clone();
        tokio::spawn(async move {
            let Ok(rt) = this.ready_runtime().await else { return };
            let Ok(Some(model)) = config::load(&this.db).await.map(|s| s.model) else { return };
            let excerpt: String = prompt.chars().take(2000).collect();
            let messages = json!([{ "role": "user", "content": [{ "type": "text", "text": excerpt }], "timestamp": 0 }]);
            let Ok(reply) = rt.complete(json!(model), messages, Some(prompt::TITLE.into()), None).await else { return };
            let text = reply["content"].as_array().into_iter().flatten().filter_map(|c| c["text"].as_str()).collect::<String>();
            let title = first_line(text.trim().trim_matches(['"', '“', '”', '。', '.']), MAX_TITLE_CHARS);
            if title.is_empty() {
                return;
            }
            let _ = sqlx::query("UPDATE agent_flow SET title = ? WHERE id = ?").bind(&title).bind(&id).execute(&this.db).await;
            let view = match this.flows.locked().get(&id).cloned() {
                Some(f) => {
                    f.view.locked().title = title;
                    Some(f.view())
                }
                None => None,
            };
            let view = match view {
                Some(v) => Some(v),
                None => this.row(user, &id).await.ok().flatten(),
            };
            if let Some(v) = view {
                this.emit(user, json!({ "type": "flow", "flow": v }));
            }
        });
    }

    async fn attach(&self, user: i64, flow: &str, ids: &[String]) -> Result<Vec<files::Attached>, FlowError> {
        self.files.attach(user, flow, ids).await.map_err(|e| match e {
            files::FileError::TooMany => FlowError::Invalid("tooManyFiles"),
            files::FileError::Unknown => FlowError::Invalid("unknownFile"),
            files::FileError::Io(e) => FlowError::Other(anyhow::anyhow!("attaching files: {e}")),
        })
    }

    /// Something the account typed into a task, with the uploads [file_ids]:
    /// the answer to what it waits on when it waits for words, a turn after
    /// the current one while it runs, and a new run of a finished task.
    #[allow(clippy::too_many_arguments)]
    pub async fn reply(
        self: &Arc<Self>,
        state: &Arc<AppState>,
        user: i64,
        secure: bool,
        id: &str,
        text: String,
        file_ids: Vec<String>,
        choice: TaskChoice,
    ) -> Result<FlowView, FlowError> {
        if !self.files.has(user, &file_ids) {
            return Err(FlowError::Invalid("unknownFile"));
        }
        self.check_choice(&choice).await?;
        if let Some(flow) = self.active(user, id) {
            *flow.secure.locked() = secure;
            self.apply_choice(&flow, &choice).await;
            let kind = flow.pending.locked().as_ref().map(|p| (p.view.kind, p.view.id.clone()));
            if matches!(kind, Some((k, _)) if !matches!(k, "confirm" | "danger" | "clarify")) {
                return Err(FlowError::Busy);
            }
            let attached = self.attach(user, id, &file_ids).await?;
            // An answer is a tool's result, which carries no images.
            let (text, images) = files::compose(&text, &attached, kind.is_none()).await;
            match kind {
                Some(("confirm", pid)) | Some(("danger", pid)) => {
                    self.answer_flow(&flow, Answer { id: pid, action: "edit".into(), text: Some(text), index: None, password: None, remember: false, confirm: None })?;
                }
                Some(("clarify", pid)) => {
                    self.answer_flow(&flow, Answer { id: pid, action: "text".into(), text: Some(text), index: None, password: None, remember: false, confirm: None })?;
                }
                Some(_) => return Err(FlowError::Busy),
                None => flow.replies.locked().push_back((text, images)),
            }
            return Ok(flow.view());
        }
        let Some(view) = self.row(user, id).await? else { return Err(FlowError::NotFound) };
        if config::load(&self.db).await?.model.is_none() {
            return Err(FlowError::NotConfigured);
        }
        if self.flows.locked().contains_key(id) {
            return Err(FlowError::Busy);
        }
        let attached = self.attach(user, id, &file_ids).await?;
        let (text, images) = files::compose(&text, &attached, true).await;
        let flow = Arc::new(Flow {
            id: id.to_string(),
            user_id: user,
            secure: Mutex::new(secure),
            view: Mutex::new(FlowView {
                status: Status::Queued,
                waiting: None,
                finished_at: None,
                model: choice.model.clone().or(view.model.clone()),
                thinking_level: choice.thinking_level.clone().or(view.thinking_level.clone()),
                ..view
            }),
            pending: Mutex::new(None),
            replies: Mutex::new(VecDeque::new()),
            approved: Mutex::new(HashSet::new()),
            output: Mutex::new(None),
            steps: Mutex::new(Vec::new()),
            session: Mutex::new(None),
            cancel: Mutex::new(Cancel::new()),
        });
        {
            let mut flows = self.flows.locked();
            if flows.contains_key(id) {
                return Err(FlowError::Busy);
            }
            flows.insert(id.to_string(), flow.clone());
        }
        self.queue.locked().push_back((id.to_string(), text, images));
        self.persist(&flow).await;
        self.schedule(state);
        Ok(flow.view())
    }

    /// The allow rule what [id] waits on offers, when [pending] is it.
    pub fn pending_rule(&self, user: i64, id: &str, pending: &str) -> Option<String> {
        let flow = self.active(user, id)?;
        let p = flow.pending.locked();
        p.as_ref().filter(|p| p.view.id == pending).and_then(|p| p.view.allow_rule.clone())
    }

    /// Answers what [id] waits on.
    pub fn answer(&self, user: i64, secure: bool, id: &str, answer: Answer) -> Result<(), FlowError> {
        let flow = self.active(user, id).ok_or(FlowError::NotWaiting)?;
        *flow.secure.locked() = secure;
        self.answer_flow(&flow, answer)
    }

    fn answer_flow(&self, flow: &Flow, answer: Answer) -> Result<(), FlowError> {
        let mut pending = flow.pending.locked();
        let Some(p) = pending.as_ref() else { return Err(FlowError::NotWaiting) };
        if p.view.id != answer.id {
            return Err(FlowError::Stale);
        }
        tools::check_answer(&p.view, &answer).map_err(FlowError::Invalid)?;
        let p = pending.take().expect("checked above");
        drop(pending);
        let _ = p.answer.send(answer);
        Ok(())
    }

    /// Stops [id]: what it waits on is cancelled, the command running is
    /// stopped, the model is interrupted. A queued task never starts.
    pub async fn stop(self: &Arc<Self>, state: &Arc<AppState>, user: i64, id: &str) -> Result<(), FlowError> {
        let flow = self.active(user, id).ok_or(FlowError::NotActive)?;
        flow.cancel_token().cancel();
        flow.replies.locked().clear();
        drop(flow.pending.locked().take());
        let queued = {
            let mut q = self.queue.locked();
            let before = q.len();
            q.retain(|(qid, _, _)| qid != id);
            q.len() != before
        };
        if queued {
            self.finish(&flow, Status::Cancelled, None).await;
            self.flows.locked().remove(id);
            self.schedule(state);
            return Ok(());
        }
        let session = flow.session.locked().clone();
        if let Some(s) = session {
            let _ = s.abort().await;
        }
        Ok(())
    }

    /// Deletes a task that is not active, with its session.
    pub async fn remove(&self, user: i64, id: &str) -> Result<(), FlowError> {
        if self.active(user, id).is_some() {
            return Err(FlowError::Busy);
        }
        if !self.remove_stored(user, id).await? {
            return Err(FlowError::NotFound);
        }
        self.emit(user, json!({ "type": "removed", "id": id }));
        Ok(())
    }

    async fn remove_stored(&self, user: i64, id: &str) -> Result<bool, FlowError> {
        let gone = sqlx::query("DELETE FROM agent_flow WHERE user_id = ? AND id = ?").bind(user).bind(id).execute(&self.db).await?.rows_affected() > 0;
        if gone {
            self.files.remove_task(id).await;
            pi_file::remove(id).await;
            let _open = self.opening.lock().await;
            let rt = self.runtime().await?;
            if let Err(e) = rt.delete_session(id).await {
                tracing::warn!("agent mode: deleting the session of {id}: {e}");
            }
        }
        Ok(gone)
    }

    // -------------------------------------------------------------------------
    // Running

    fn running(&self) -> i64 {
        self.flows.locked().values().filter(|f| f.status() == Status::Running).count() as i64
    }

    /// Starts what the queue holds while there is room.
    fn schedule(self: &Arc<Self>, state: &Arc<AppState>) {
        loop {
            if self.running() >= self.max_running.load(Ordering::Relaxed) {
                return;
            }
            let Some((id, text, images)) = self.queue.locked().pop_front() else { return };
            let Some(flow) = self.flows.locked().get(&id).cloned() else { continue };
            {
                let mut v = flow.view.locked();
                v.status = Status::Running;
                v.started_at = Some(chrono::Utc::now().to_rfc3339());
            }
            let (this, state) = (self.clone(), state.clone());
            tokio::spawn(async move { this.drive(state, flow, text, images).await });
        }
    }

    async fn drive(self: Arc<Self>, state: Arc<AppState>, flow: Arc<Flow>, first: String, images: Option<Value>) {
        self.persist(&flow).await;
        let outcome = self.run(&state, &flow, first, images).await;
        // Closed before the task leaves the active set, under the lock a
        // read takes, so a read never opens it alongside.
        {
            let _open = self.opening.lock().await;
            let session = flow.session.locked().take();
            if let Some(s) = &session {
                self.write_pi_file(&flow, s).await;
            }
            if let Some(s) = session {
                match Arc::try_unwrap(s) {
                    Ok(s) => {
                        let _ = s.close().await;
                    }
                    // Still held somewhere: closed by id all the same, or it
                    // could never be opened again.
                    Err(s) => {
                        if let Ok(rt) = self.runtime().await {
                            let _ = rt.close_session(s.id()).await;
                        }
                    }
                }
            }
        }
        let cancelled = flow.cancel_token().is_cancelled();
        match outcome {
            _ if cancelled => self.finish(&flow, Status::Cancelled, None).await,
            Ok(Outcome::Done) => self.finish(&flow, Status::Done, None).await,
            Ok(Outcome::Failed(why)) => self.finish(&flow, Status::Failed, Some(why)).await,
            Err(e) => self.finish(&flow, Status::Failed, Some(e.to_string())).await,
        }
        self.flows.locked().remove(&flow.id);
        self.schedule(&state);
    }

    async fn run(&self, state: &Arc<AppState>, flow: &Arc<Flow>, first: String, images: Option<Value>) -> Result<Outcome, FlowError> {
        let settings = config::load(&self.db).await?;
        let Some(machine) = settings.model else { return Err(FlowError::NotConfigured) };
        let (model, thinking_level) = {
            let v = flow.view.locked();
            (v.model.clone().unwrap_or(machine), v.thinking_level.clone().unwrap_or(settings.thinking_level.clone()))
        };
        let rt = self.ready_runtime().await?;
        let memory = self.memory(flow.user_id);
        let mut system_prompt = prompt::system(&self.hostname);
        if let Some(m) = memory.prompt(true).await.map_err(|e| anyhow::anyhow!("memory: {e}"))? {
            system_prompt = format!("{system_prompt}\n\n{m}");
        }
        if let Some(apps) = crate::stacks::agent_note(state).await {
            system_prompt = format!("{system_prompt}\n\n{apps}");
        }
        let mut tools = tools::all(state.clone(), Some(flow.clone()));
        tools.extend(fl_pi_llm::host::memory::tools(memory));
        if let Some((prompt, tool)) = skills::for_task(&self.db, &self.skills_root).await {
            system_prompt = format!("{system_prompt}\n\n{prompt}");
            tools.push(tool);
        }
        let (mcp_tools, mcp_note) = self.mcp.tools_for(state, flow).await;
        if let Some(note) = mcp_note {
            system_prompt = format!("{system_prompt}\n\n{note}");
        }
        tools.extend(mcp_tools);
        let session = {
            let _open = self.opening.lock().await;
            let (session, events) = rt
                .open_session(OpenSession {
                    id: flow.id.clone(),
                    model: json!(model),
                    system_prompt,
                    tools,
                    approver: None,
                    thinking_level: Some(thinking_level),
                    compaction: None,
                })
                .await?;
            let session = Arc::new(session);
            *flow.session.locked() = Some(session.clone());
            self.forward(flow.clone(), events);
            session
        };
        let (mut text, mut images) = (first, images);
        loop {
            if flow.cancel_token().is_cancelled() {
                return Ok(Outcome::Done);
            }
            let result = session.prompt(&text, images.take()).await?;
            match result["status"].as_str() {
                Some("failed") => {
                    let why = result["error"]["message"].as_str().unwrap_or("failed").to_string();
                    return Ok(Outcome::Failed(why));
                }
                Some("aborted") => return Ok(Outcome::Done),
                _ => {}
            }
            let next = flow.replies.locked().pop_front();
            match next {
                Some((t, i)) => (text, images) = (t, i),
                None => return Ok(Outcome::Done),
            }
        }
    }

    /// What the session says, out to pages; the model's words become the
    /// task's line.
    fn forward(&self, flow: Arc<Flow>, mut events: tokio::sync::mpsc::UnboundedReceiver<Value>) {
        let tx = self.events.clone();
        tokio::spawn(async move {
            while let Some(mut e) = events.recv().await {
                if e["type"] == "entry_added" {
                    files::annotate_entry(&mut e["entry"]);
                }
                if e["type"] == "message_end" && e["message"]["role"] == "assistant" {
                    let text: String = e["message"]["content"].as_array().into_iter().flatten().filter(|c| c["type"] == "text").filter_map(|c| c["text"].as_str()).collect();
                    let line = first_line(text.trim(), 160);
                    if !line.is_empty() {
                        flow.view.locked().line = line;
                    }
                }
                let _ = tx.send(AgentEvent { user: flow.user_id, payload: json!({ "type": "event", "id": flow.id, "event": e }) });
            }
        });
    }

    async fn finish(&self, flow: &Flow, status: Status, why: Option<String>) {
        {
            let mut v = flow.view.locked();
            v.status = status;
            v.finished_at = Some(chrono::Utc::now().to_rfc3339());
            if let Some(w) = why {
                v.line = first_line(&w, 160);
            }
        }
        drop(flow.pending.locked().take());
        *flow.output.locked() = None;
        self.persist(flow).await;
    }

    /// The task as a session file `pi` on this machine lists, when the
    /// configuration asks for that; rewritten after every run. A failure costs only the
    /// copy.
    async fn write_pi_file(&self, flow: &Flow, session: &Session) {
        match config::load(&self.db).await {
            Ok(s) if s.pi_sessions => {}
            _ => return,
        }
        let cwd = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("/"));
        let text = match session.export_pi(&cwd.to_string_lossy()).await {
            Ok(t) => t,
            Err(e) => return tracing::warn!("agent mode: exporting {} for pi: {e}", flow.id),
        };
        let created = flow.view.locked().created_at.clone();
        if let Err(e) = pi_file::write(&cwd, &created, &flow.id, &text).await {
            tracing::warn!("agent mode: writing {} for pi: {e}", flow.id);
        }
    }

    /// What a task may be started or replied to with: the models whose
    /// provider has a key here, the thinking levels, and what the machine
    /// uses when nothing is picked. Never a key.
    pub async fn choices(&self) -> Result<Value, FlowError> {
        let settings = config::load(&self.db).await?;
        let models = match settings.model {
            Some(_) => self.ready_runtime().await?.request("providers.available", json!({})).await.map_err(|e| anyhow::anyhow!("{e}"))?,
            None => json!([]),
        };
        Ok(json!({
            "models": models,
            "thinkingLevels": config::THINKING_LEVELS,
            "model": settings.model,
            "thinkingLevel": settings.thinking_level,
        }))
    }

    /// Every model a provider here has a key for (pi's `providers.available`),
    /// whatever the machine's own choice is.
    pub async fn available_models(&self) -> Result<Value, FlowError> {
        Ok(self.ready_runtime().await?.request("providers.available", json!({})).await.map_err(|e| anyhow::anyhow!("{e}"))?)
    }

    /// An added or app provider's endpoint and its key, to point another
    /// program at it (`api::agent_tools`). Built-in providers have no
    /// address of their own here.
    pub async fn endpoint(&self, provider: &str) -> Result<Option<(config::Provider, Option<String>)>, FlowError> {
        let settings = config::load(&self.db).await?;
        let Some(p) = self.providers(&settings).into_iter().find(|p| p.id == provider) else { return Ok(None) };
        let creds = config::AppCredentials { db: config::DbCredentials(self.db.clone()), apps: self.apps.clone() };
        let key = fl_pi_llm::host::Credentials::read(&creds, provider).await.map_err(|e| anyhow::anyhow!(e))?;
        let key = key.and_then(|v| v["key"].as_str().map(String::from));
        Ok(Some((p, key)))
    }

    /// Whether [c] names a model a provider here has a key for, and a
    /// thinking level there is.
    async fn check_choice(&self, c: &TaskChoice) -> Result<(), FlowError> {
        if let Some(level) = &c.thinking_level
            && !config::THINKING_LEVELS.contains(&level.as_str())
        {
            return Err(FlowError::Invalid("invalidThinkingLevel"));
        }
        if let Some(m) = &c.model {
            let models = self.choices().await?;
            let known = models["models"].as_array().is_some_and(|a| a.iter().any(|x| x["provider"] == m.provider.as_str() && x["id"] == m.id.as_str()));
            if !known {
                return Err(FlowError::Invalid("unknownModel"));
            }
        }
        Ok(())
    }

    /// [c] on a task that is active: kept for its next run, and on its open
    /// session from its next request.
    async fn apply_choice(&self, flow: &Flow, c: &TaskChoice) {
        if c.model.is_none() && c.thinking_level.is_none() {
            return;
        }
        {
            let mut v = flow.view.locked();
            if let Some(m) = &c.model {
                v.model = Some(m.clone());
            }
            if let Some(l) = &c.thinking_level {
                v.thinking_level = Some(l.clone());
            }
        }
        let session = flow.session.locked().clone();
        if let Some(s) = session {
            if let Some(m) = &c.model
                && let Err(e) = s.set_model(json!(m)).await
            {
                tracing::warn!("agent mode: switching the model of {}: {e}", flow.id);
            }
            if let Some(l) = &c.thinking_level
                && let Err(e) = s.set_thinking_level(l).await
            {
                tracing::warn!("agent mode: switching the thinking level of {}: {e}", flow.id);
            }
        }
        self.persist(flow).await;
    }

    /// Writes [flow]'s row and tells its pages.
    pub(crate) async fn persist(&self, flow: &Flow) {
        let mut v = flow.view();
        v.updated_at = chrono::Utc::now().to_rfc3339();
        flow.view.locked().updated_at = v.updated_at.clone();
        let r = sqlx::query(
            "UPDATE agent_flow SET title = ?, status = ?, line = ?, areas = ?, model = ?, thinking_level = ?, updated_at = ?, started_at = ?, finished_at = ? WHERE id = ?",
        )
        .bind(&v.title)
        .bind(v.status.as_str())
        .bind(&v.line)
        .bind(serde_json::to_string(&v.areas).expect("areas serialise"))
        .bind(v.model.as_ref().map(|m| serde_json::to_string(m).expect("a model reference serialises")))
        .bind(&v.thinking_level)
        .bind(&v.updated_at)
        .bind(&v.started_at)
        .bind(&v.finished_at)
        .bind(&flow.id)
        .execute(&self.db)
        .await;
        if let Err(e) = r {
            tracing::warn!("agent mode: writing {}: {e}", flow.id);
        }
        self.emit(flow.user_id, json!({ "type": "flow", "flow": v }));
    }

    // -------------------------------------------------------------------------
    // What tools use

    /// Waits for the account to answer [view]; `None` when the task was
    /// stopped meanwhile.
    pub(crate) async fn ask(&self, flow: &Arc<Flow>, mut view: PendingView) -> Option<Answer> {
        view.id = uuid_v4();
        let call_id = view.tool_call_id.clone();
        let (tx, rx) = oneshot::channel();
        *flow.pending.locked() = Some(Pending { view: view.clone(), answer: tx });
        self.step_state(flow, &call_id, "waiting");
        flow.view.locked().status = Status::Waiting;
        self.persist(flow).await;
        self.emit(flow.user_id, json!({ "type": "pending", "id": flow.id, "pending": view }));
        let cancel = flow.cancel_token();
        let answer = tokio::select! {
            a = rx => a.ok(),
            _ = cancel.cancelled() => None,
        };
        drop(flow.pending.locked().take());
        if !cancel.is_cancelled() {
            self.step_state(flow, &call_id, "running");
            flow.view.locked().status = Status::Running;
            self.persist(flow).await;
        }
        self.emit(flow.user_id, json!({ "type": "pending", "id": flow.id, "pending": null }));
        answer
    }

    /// Wiped when dropped, like the cached one it copies.
    pub(crate) fn sudo_password(&self, user: i64) -> Option<Zeroizing<String>> {
        let mut cache = self.sudo.locked();
        match cache.get(&user) {
            Some((p, at)) if at.elapsed() < SUDO_REMEMBER => Some(p.clone()),
            Some(_) => {
                cache.remove(&user);
                None
            }
            None => None,
        }
    }

    pub(crate) fn remember_sudo(&self, user: i64, password: Option<Zeroizing<String>>) {
        let mut cache = self.sudo.locked();
        match password {
            Some(p) => {
                let at = Instant::now();
                cache.insert(user, (p, at));
                // Gone when its time is up, asked for again or not: not left in
                // memory until the next read.
                if let Ok(runtime) = tokio::runtime::Handle::try_current() {
                    let sudo = self.sudo.clone();
                    runtime.spawn(async move {
                        tokio::time::sleep(SUDO_REMEMBER).await;
                        let mut cache = sudo.locked();
                        if cache.get(&user).is_some_and(|(_, kept)| *kept == at) {
                            cache.remove(&user);
                        }
                    });
                }
            }
            None => {
                cache.remove(&user);
            }
        }
    }

    /// The password changed: the tasks stop and the sudo password left in
    /// memory goes, with the uploads nobody named yet.
    pub fn end_account(&self) {
        self.sudo.locked().clear();
        self.files.forget();
        let flows: Vec<Arc<Flow>> = self.flows.locked().values().cloned().collect();
        for f in flows {
            f.cancel_token().cancel();
            drop(f.pending.locked().take());
            let session = f.session.locked().clone();
            if let Some(s) = session {
                tokio::spawn(s.abort());
            }
        }
    }

    pub(crate) fn note_area(&self, flow: &Flow, area: &str, line: &str) {
        let mut v = flow.view.locked();
        if !v.areas.iter().any(|a| a == area) {
            v.areas.push(area.to_string());
        }
        if !line.is_empty() {
            v.line = first_line(line, 160);
        }
    }

    pub(crate) fn output_started(&self, flow: &Flow, tool_call_id: &str) {
        *flow.output.locked() = Some(LiveOutput { tool_call_id: tool_call_id.to_string(), lines: Vec::new(), omitted: 0 });
    }

    /// Lines of the running command: kept (the newest [`tools::LIVE_LINES`])
    /// for a page that opens later, and sent to the pages open now.
    pub(crate) fn output_lines(&self, flow: &Flow, tool_call_id: &str, lines: Vec<(u8, String)>) {
        if lines.is_empty() {
            return;
        }
        {
            let mut out = flow.output.locked();
            if let Some(o) = out.as_mut().filter(|o| o.tool_call_id == tool_call_id) {
                o.lines.extend(lines.iter().cloned());
                let over = o.lines.len().saturating_sub(tools::LIVE_LINES);
                if over > 0 {
                    o.lines.drain(..over);
                    o.omitted += over;
                }
            }
        }
        self.emit(flow.user_id, json!({ "type": "output", "id": flow.id, "toolCallId": tool_call_id, "lines": lines }));
    }

    pub(crate) fn output_ended(&self, flow: &Flow) {
        *flow.output.locked() = None;
    }

    pub(crate) fn step_begin(&self, flow: &Flow, tool_call_id: &str, title: &str, area: &str) {
        let mut steps = flow.steps.locked();
        steps.retain(|s| s.tool_call_id != tool_call_id);
        steps.push(StepBrief { tool_call_id: tool_call_id.to_string(), title: title.to_string(), area: area.to_string(), state: "running" });
    }

    pub(crate) fn step_state(&self, flow: &Flow, tool_call_id: &str, state: &'static str) {
        if let Some(s) = flow.steps.locked().iter_mut().find(|s| s.tool_call_id == tool_call_id) {
            s.state = state;
        }
    }

    pub(crate) fn approve_commands(&self, flow: &Flow, commands: impl IntoIterator<Item = String>) {
        flow.approved.locked().extend(commands);
    }

    pub(crate) fn approved(&self, flow: &Flow, command: &str) -> bool {
        flow.approved.locked().contains(command.trim())
    }
}

impl Drop for AgentMode {
    fn drop(&mut self) {
        if self.owned {
            let _ = std::fs::remove_dir_all(&self.dir);
        }
    }
}

enum Outcome {
    Done,
    Failed(String),
}

#[derive(Debug, thiserror::Error)]
pub enum FlowError {
    #[error("no model is configured")]
    NotConfigured,
    #[error("no such task")]
    NotFound,
    #[error("the task is not active")]
    NotActive,
    #[error("the task waits on nothing")]
    NotWaiting,
    #[error("that is no longer asked")]
    Stale,
    #[error("the task is busy")]
    Busy,
    #[error("invalid: {0}")]
    Invalid(&'static str),
    /// A provider answered with a failure.
    #[error("{0}")]
    Upstream(String),
    #[error("database: {0}")]
    Db(#[from] sqlx::Error),
    #[error("{0}")]
    Pi(#[from] fl_pi_llm::host::Error),
    #[error("{0}")]
    Other(#[from] anyhow::Error),
}

impl FlowError {
    pub fn code(&self) -> &'static str {
        match self {
            FlowError::NotConfigured => "notConfigured",
            FlowError::NotFound => "notFound",
            FlowError::NotActive => "notActive",
            FlowError::NotWaiting => "notWaiting",
            FlowError::Stale => "stale",
            FlowError::Busy => "busy",
            FlowError::Invalid(c) => c,
            FlowError::Upstream(_) => "upstream",
            FlowError::Db(_) | FlowError::Pi(_) | FlowError::Other(_) => "internal",
        }
    }
}

#[derive(sqlx::FromRow)]
struct Row {
    id: String,
    title: String,
    status: String,
    line: String,
    areas: String,
    mode: String,
    model: Option<String>,
    thinking_level: Option<String>,
    created_at: String,
    updated_at: String,
    started_at: Option<String>,
    finished_at: Option<String>,
}

impl Row {
    fn view(self) -> FlowView {
        FlowView {
            id: self.id,
            title: self.title,
            status: Status::parse(&self.status),
            line: self.line,
            areas: serde_json::from_str(&self.areas).unwrap_or_default(),
            mode: permissions::Mode::parse(&self.mode),
            model: self.model.as_deref().and_then(|m| serde_json::from_str(m).ok()),
            thinking_level: self.thinking_level,
            created_at: self.created_at,
            updated_at: self.updated_at,
            started_at: self.started_at,
            finished_at: self.finished_at,
            waiting: None,
            steps: Vec::new(),
            tail: Vec::new(),
        }
    }
}

/// The first line of [text], at most [max] characters.
pub(crate) fn first_line(text: &str, max: usize) -> String {
    let line = text.lines().map(str::trim).find(|l| !l.is_empty()).unwrap_or("");
    if line.chars().count() <= max {
        return line.to_string();
    }
    let mut s: String = line.chars().take(max - 1).collect();
    s.push('…');
    s
}

pub(crate) fn uuid_v4() -> String {
    let mut b = [0u8; 16];
    getrandom::fill(&mut b).expect("the system's random source");
    b[6] = (b[6] & 0x0f) | 0x40;
    b[8] = (b[8] & 0x3f) | 0x80;
    let h = hex::encode(b);
    format!("{}-{}-{}-{}-{}", &h[..8], &h[8..12], &h[12..16], &h[16..20], &h[20..])
}

/// A chat id from a legacy session's directory or file name: fl_pi_llm named
/// it with `encodeURIComponent`. TODO: remove with `drop_legacy_sessions`.
fn decode_component(name: &str) -> String {
    percent_encoding::percent_decode_str(name).decode_utf8_lossy().into_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// A task kept before chats were SQLite goes with its session; one in
    /// the current format stays, and a chat no task names goes.
    #[tokio::test]
    async fn recover_drops_legacy_tasks_and_orphan_chats() {
        let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
        sqlx::migrate!("./migrations").run(&db).await.unwrap();
        let user: i64 = sqlx::query_scalar("INSERT INTO users (password_hash) VALUES ('x') RETURNING id").fetch_one(&db).await.unwrap();
        for id in ["old dir", "old_file", "new"] {
            sqlx::query("INSERT INTO agent_flow (id, user_id, title, status, created_at, updated_at) VALUES (?, ?, 't', 'done', '', '')")
                .bind(id)
                .bind(user)
                .execute(&db)
                .await
                .unwrap();
        }
        let agent = AgentMode::new(db.clone(), None);
        let chats = agent.dir.join("chats");
        std::fs::create_dir_all(chats.join("old%20dir")).unwrap();
        std::fs::create_dir_all(agent.dir.join("meta")).unwrap();
        let sessions = agent.dir.join("sessions").join("--cwd--");
        std::fs::create_dir_all(&sessions).unwrap();
        std::fs::write(sessions.join("2026-10-01T00-00-00-000Z_old_file.jsonl"), "").unwrap();
        for id in ["new", "orphan"] {
            std::fs::write(chats.join(fl_pi_llm::db::file_name(id)), "").unwrap();
        }

        agent.recover().await.unwrap();

        let left: Vec<String> = sqlx::query_scalar("SELECT id FROM agent_flow").fetch_all(&db).await.unwrap();
        assert_eq!(left, ["new"]);
        let mut files: Vec<String> = std::fs::read_dir(&chats).unwrap().map(|e| e.unwrap().file_name().to_string_lossy().into_owned()).collect();
        files.sort();
        assert_eq!(files, [fl_pi_llm::db::file_name("new")]);
        assert!(!agent.dir.join("meta").exists() && !agent.dir.join("sessions").exists());
    }

    /// The sudo password goes when its time is up, without being asked for.
    #[tokio::test]
    async fn a_remembered_sudo_password_goes_on_its_own() {
        let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
        let agent = AgentMode::new(db, None);
        // After the pool is up: its connect times out on a paused clock.
        tokio::time::pause();
        agent.remember_sudo(1, Some(Zeroizing::new("pw".into())));
        assert_eq!(agent.sudo_password(1).as_deref().map(String::as_str), Some("pw"));
        tokio::time::sleep(SUDO_REMEMBER + std::time::Duration::from_secs(1)).await;
        assert!(agent.sudo.locked().is_empty());
    }

    #[test]
    fn a_line_is_cut_at_a_character() {
        assert_eq!(first_line("\n  更新系统包\n第二行", 80), "更新系统包");
        assert_eq!(first_line("一二三四五", 3), "一二…");
    }

    #[test]
    fn an_id_is_a_v4_uuid() {
        let id = uuid_v4();
        assert_eq!(id.len(), 36);
        assert_eq!(&id[14..15], "4");
        assert_ne!(uuid_v4(), id);
    }
}
