//! Web apps the agent deploys with Docker Compose and the desk shows in a
//! window. Their catalog is `store/apps/` (one folder per app, read by
//! [`manifest`], shipped in the binary by [`builtin`]).
//!
//! A deployed app is a stack: its folder's files and an env file in
//! `<database dir>/stacks/<id>/`, a `stack` row, the compose project
//! `sbm-<publisher>-<name>`, and a listener of the agent's own in front of it
//! ([`proxy`]). Deploying, updating, starting, stopping and removing are
//! [`job`]s: their commands run while the page that asked may close.
//!
//! The generated secrets (a database password) live in the env file alone
//! (0600, a protected file for the file API). Removing a stack without its
//! data keeps that file, so deploying again finds its database.

pub mod builtin;
pub mod job;
pub mod manifest;
pub mod ports;
pub mod proxy;
pub mod store;

use std::collections::{BTreeMap, HashMap};
use std::net::SocketAddr;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};

use serde::Serialize;
use serde_json::Value;
use sbm_parser::container::ContainerType;
use sbm_parser::stack::Stack;

use crate::api::server::AppState;
use crate::api::ws::audit::{Action, Event, Kind, Outcome};
use job::{Job, JobKind, JobState};
use manifest::{Machine, MovedPort, Package};
use store::StackRow;

/// The agent's own ports in front of deployed apps, one per app.
pub const PROXY_PORTS: std::ops::RangeInclusive<u16> = 3780..=3799;
const ENV_FILE: &str = ".env";

static TEMP: std::sync::atomic::AtomicU64 = std::sync::atomic::AtomicU64::new(0);

pub struct Stacks {
    root: PathBuf,
    /// Removed with this value: the directory made for an in-memory database.
    owned: bool,
    /// The latest job of each app.
    jobs: Mutex<HashMap<String, Arc<Job>>>,
    pub proxies: proxy::Proxies,
}

impl Drop for Stacks {
    fn drop(&mut self) {
        if self.owned {
            let _ = std::fs::remove_dir_all(&self.root);
        }
    }
}

/// Why a step was not started: an HTTP status, a code the panel words, and
/// the setting when one is to blame.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Refusal {
    #[serde(skip)]
    pub status: u16,
    pub error: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub field: Option<String>,
}

fn refusal(status: u16, error: &'static str) -> Refusal {
    Refusal { status, error, field: None }
}

impl Stacks {
    /// Stacks in `stacks/` beside the database file [db_file], or in a
    /// directory of their own for an in-memory database.
    pub fn new(db_file: Option<&Path>) -> Self {
        let (root, owned) = match db_file {
            // Absolute, whatever the database URL said: the paths go into an
            // env file Compose reads from the stack's own directory.
            Some(f) => (std::path::absolute(Self::dir_beside(f)).unwrap_or_else(|_| Self::dir_beside(f)), false),
            None => {
                let n = TEMP.fetch_add(1, std::sync::atomic::Ordering::Relaxed);
                (std::env::temp_dir().join(format!("sbm-stacks-{}-{n}", std::process::id())), true)
            }
        };
        Self { root, owned, jobs: Mutex::default(), proxies: proxy::Proxies::default() }
    }

    pub fn dir_beside(db: &Path) -> PathBuf {
        db.parent().unwrap_or_else(|| Path::new(".")).join("stacks")
    }

    /// The env files of every app this agent can deploy, for the file API to
    /// keep out of reach.
    pub fn env_files_beside(db: &Path) -> Vec<PathBuf> {
        builtin::packages().iter().map(|p| Self::dir_beside(db).join(&p.manifest.id).join(ENV_FILE)).collect()
    }

    pub fn dir(&self, id: &str) -> PathBuf {
        self.root.join(id)
    }

    pub fn package(id: &str) -> Option<&'static Package> {
        builtin::packages().iter().find(|p| p.manifest.id == id)
    }

    pub fn job(&self, id: &str) -> Option<Arc<Job>> {
        self.jobs.lock().unwrap_or_else(|e| e.into_inner()).get(id).cloned()
    }

    /// A new job for [id], unless one is running.
    fn begin(&self, id: &str, kind: JobKind) -> Result<Arc<Job>, Refusal> {
        let mut jobs = self.jobs.lock().unwrap_or_else(|e| e.into_inner());
        if jobs.get(id).is_some_and(|j| j.running()) {
            return Err(refusal(409, "busy"));
        }
        let job = Arc::new(Job::new(kind));
        jobs.insert(id.to_string(), job.clone());
        Ok(job)
    }
}

/// [id]'s compose project. Compose takes no `.`; an id's parts have no `-`,
/// so this maps one way.
fn project(id: &str) -> String {
    format!("sbm-{}", id.replace('.', "-"))
}

fn compose(runtime: ContainerType, id: &str, dir: &Path, package: &Package) -> Stack {
    Stack {
        runtime,
        project: project(id),
        dir: dir.to_string_lossy().into_owned(),
        files: package.manifest.compose.files.clone(),
        env_file: ENV_FILE.into(),
    }
}

fn wsl() -> bool {
    std::fs::read_to_string("/proc/sys/kernel/osrelease").is_ok_and(|r| r.to_ascii_lowercase().contains("microsoft"))
}

/// The vendors of the GPUs the agent sees.
pub async fn gpus_seen(state: &AppState) -> Vec<String> {
    let mut gpus: Vec<String> = state
        .current_metrics
        .read()
        .await
        .as_ref()
        .map(|m| m.gpus.iter().map(|g| g.vendor.to_ascii_lowercase()).collect())
        .unwrap_or_default();
    gpus.sort();
    gpus.dedup();
    gpus
}

/// Of [seen], the GPUs containers can be given: NVIDIA's through the NVIDIA
/// Container Toolkit (Docker's `nvidia` runtime, or a CDI spec), Intel's
/// and AMD's through `/dev/dri` (`/dev/dxg` under WSL2).
async fn container_gpus(state: &AppState, runtime: Option<ContainerType>, seen: &[String], wsl: bool) -> Vec<String> {
    let mut usable = Vec::new();
    if seen.iter().any(|g| g == "nvidia") {
        let mut toolkit = ["/etc/cdi", "/var/run/cdi"].iter().any(|dir| {
            std::fs::read_dir(dir).is_ok_and(|entries| {
                entries.flatten().any(|e| e.file_name().to_string_lossy().to_ascii_lowercase().contains("nvidia"))
            })
        });
        if !toolkit && let Some(cmd) = runtime.and_then(sbm_parser::stack::runtimes_command) {
            let out = crate::api::exec::run(&cmd, None, None, &state.remote_access.exec).await;
            toolkit = out.is_ok_and(|o| sbm_parser::stack::parse_runtimes(&o.stdout).iter().any(|r| r == "nvidia"));
        }
        if toolkit {
            usable.push("nvidia".to_string());
        }
    }
    let dri = Path::new(if wsl { "/dev/dxg" } else { "/dev/dri" }).exists();
    for vendor in ["intel", "amd"] {
        if dri && seen.iter().any(|g| g == vendor) {
            usable.push(vendor.to_string());
        }
    }
    usable
}

/// What a deploy dialog's defaults depend on, on this machine: its GPUs are
/// those containers can be given, its free ports those [id] may publish.
pub async fn machine(state: &AppState, id: &str) -> Machine {
    let wsl = wsl();
    let runtime = crate::api::containers::detect_runtime(&state.remote_access.exec).await;
    let seen = gpus_seen(state).await;
    let gpus = container_gpus(state, runtime, &seen, wsl).await;
    let ports = ports::Ports::read(state, runtime, project(id)).await;
    Machine { stack: state.stacks.dir(id), gpus, wsl, ports: Some(ports) }
}

/// [given] completed and checked for [machine], its ports settled
/// (`Manifest::settle_ports`).
fn settings_for(
    package: &Package,
    given: &BTreeMap<String, Value>,
    machine: &Machine,
    follow: bool,
) -> Result<(BTreeMap<String, Value>, Vec<MovedPort>), Refusal> {
    let invalid = |i: manifest::Invalid| Refusal {
        status: if i.error == "portTaken" { 409 } else { 400 },
        error: i.error,
        field: Some(i.field),
    };
    let mut settings = package.manifest.check_settings(given, machine).map_err(invalid)?;
    let moved = package.manifest.settle_ports(&mut settings, machine, follow).map_err(invalid)?;
    Ok((settings, moved))
}

/// The container runtime and its Compose, or why there is none.
pub async fn runtime(state: &AppState) -> Result<(ContainerType, String), Refusal> {
    let exec = &state.remote_access.exec;
    let Some(ty) = crate::api::containers::detect_runtime(exec).await else {
        return Err(refusal(409, "noRuntime"));
    };
    let out = crate::api::exec::run(&sbm_parser::stack::version_command(ty), None, None, exec).await;
    match out.ok().filter(|o| o.exit_code == Some(0)).and_then(|o| sbm_parser::stack::parse_version(&o.stdout)) {
        Some(version) => Ok((ty, version)),
        None => Err(refusal(409, "noCompose")),
    }
}

async fn audit(state: &AppState, username: &str, action: Action, outcome: Outcome, detail: String) {
    Event::new(Kind::Stack, action, outcome).subject(username).detail(detail).record(&state.db).await;
}

/// The files written for checked [settings]: the folder's files, the env
/// file (secrets kept from an earlier one, else generated), and every path
/// setting's directory.
async fn write_files(state: &AppState, id: &str, package: &Package, settings: &BTreeMap<String, Value>) -> Result<(), Refusal> {
    let dir = state.stacks.dir(id);
    let failed = |e: std::io::Error| {
        tracing::error!("stack {id}: {e}");
        refusal(500, "writeFailed")
    };
    tokio::fs::create_dir_all(&dir).await.map_err(failed)?;
    set_mode(&dir, 0o700).await;
    for (name, text) in &package.files {
        tokio::fs::write(dir.join(name), text).await.map_err(failed)?;
    }
    let env_path = dir.join(ENV_FILE);
    let earlier = tokio::fs::read_to_string(&env_path).await.unwrap_or_default();
    let names: Vec<&str> = package.manifest.secrets.iter().map(|s| s.env.as_str()).collect();
    let mut secrets = read_env(&earlier, &names);
    for s in &package.manifest.secrets {
        if !secrets.contains_key(&s.env) {
            let value = crate::utils::secrets::random_password(s.length).map_err(|e| {
                tracing::error!("stack {id}: {e}");
                refusal(500, "writeFailed")
            })?;
            secrets.insert(s.env.clone(), value);
        }
    }
    let env = package.manifest.env_file(settings, &secrets);
    // Created 0600 before the secrets go in.
    tokio::fs::write(&env_path, "").await.map_err(failed)?;
    set_mode(&env_path, 0o600).await;
    tokio::fs::write(&env_path, env).await.map_err(failed)?;
    for s in &package.manifest.settings {
        if let manifest::Setting::Path { key, .. } = s
            && let Some(path) = settings.get(key).and_then(Value::as_str)
            && tokio::fs::create_dir_all(path).await.is_err()
        {
            return Err(Refusal { status: 400, error: "pathUnavailable", field: Some(key.clone()) });
        }
    }
    Ok(())
}

async fn set_mode(path: &Path, mode: u32) {
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = tokio::fs::set_permissions(path, std::fs::Permissions::from_mode(mode)).await;
    }
    #[cfg(not(unix))]
    let _ = (path, mode);
}

/// The values of [names] in an env file the agent wrote (`NAME='value'`).
fn read_env(text: &str, names: &[&str]) -> BTreeMap<String, String> {
    text.lines()
        .filter_map(|line| line.split_once('='))
        .filter(|(k, _)| names.contains(&k.trim()))
        .map(|(k, v)| (k.trim().to_string(), v.trim().trim_matches('\'').to_string()))
        .collect()
}

/// A proxy port: in [`PROXY_PORTS`], not a stack's (its own old one
/// included), free now.
async fn proxy_port(state: &AppState) -> Result<u16, Refusal> {
    let taken: Vec<u16> = store::all(&state.db).await.map_err(db_failed)?.iter().map(|r| r.proxy_port).collect();
    PROXY_PORTS.clone().find(|p| !taken.contains(p) && ports::bindable(*p)).ok_or_else(|| refusal(409, "noProxyPort"))
}

fn db_failed(e: sqlx::Error) -> Refusal {
    tracing::error!("stacks: {e}");
    refusal(500, "internal")
}

/// Starts [row]'s proxy listener on the agent's own address. When its port
/// has been taken (another program started first), it moves to a free one.
pub async fn start_proxy(state: &Arc<AppState>, row: &StackRow) {
    let Some(package) = Stacks::package(&row.id) else { return };
    let Some(upstream_port) = package.manifest.web_port(&row.settings) else { return };
    let server = state.config.get_server();
    let host: std::net::IpAddr = server.host.parse().unwrap_or(std::net::Ipv4Addr::UNSPECIFIED.into());
    let tls = match &server.tls {
        Some(tls) => match crate::api::server::load_rustls_config(tls) {
            Ok(config) => Some(Arc::new(config)),
            Err(e) => {
                tracing::error!("stack {} proxy: {e}", row.id);
                return;
            }
        },
        None => None,
    };
    let target = |port: u16| proxy::Target {
        stack: row.id.clone(),
        listen: SocketAddr::new(host, port),
        upstream_port,
        tls: tls.clone(),
        frame_origins: server.cors_allowed_origins.clone(),
    };
    let e = match state.stacks.proxies.start(state.clone(), target(row.proxy_port)).await {
        Ok(()) => return,
        Err(e) => e,
    };
    if e.kind() != std::io::ErrorKind::AddrInUse {
        tracing::error!("stack {} proxy on port {}: {e}", row.id, row.proxy_port);
        return;
    }
    let port = match proxy_port(state).await {
        Ok(port) => port,
        Err(r) => {
            tracing::error!("stack {} proxy: port {} is taken, and {}", row.id, row.proxy_port, r.error);
            return;
        }
    };
    if let Err(e) = store::set_proxy_port(&state.db, &row.id, port).await {
        tracing::error!("stack {}: {e}", row.id);
        return;
    }
    tracing::warn!("stack {} proxy: port {} is taken, moved to {port}", row.id, row.proxy_port);
    if let Err(e) = state.stacks.proxies.start(state.clone(), target(port)).await {
        tracing::error!("stack {} proxy on port {port}: {e}", row.id);
    }
}

/// At start: steps a stopped agent left unfinished fail, and every deployed
/// app gets its proxy back.
pub async fn resume(state: &Arc<AppState>) {
    match store::fail_interrupted(&state.db).await {
        Ok(0) => {}
        Ok(n) => tracing::warn!("{n} app deployments were interrupted by a restart"),
        Err(e) => tracing::error!("stacks: {e}"),
    }
    match store::all(&state.db).await {
        Ok(rows) => {
            for row in rows.iter().filter(|r| r.state == "installed") {
                start_proxy(state, row).await;
            }
        }
        Err(e) => tracing::error!("stacks: {e}"),
    }
}

/// What the admin confirmed before deploying.
#[derive(Debug, Clone, Copy, Default)]
pub struct Consent {
    /// That this installs third-party software, shown with its project,
    /// licence, images, folders and port.
    pub third_party: bool,
    /// The licence, when the manifest asks for it to be accepted.
    pub license: bool,
}

/// What deploying [given] settings would do, for the confirmation: the
/// settings completed, the images pulled, the folders written, the port.
#[derive(Debug, Clone, Serialize)]
pub struct Preview {
    pub settings: BTreeMap<String, Value>,
    pub images: Vec<String>,
    pub data_paths: Vec<PathBuf>,
    pub port: Option<u16>,
    /// Ports suggested in the dialog that are in use now, and where they
    /// will move (`Manifest::settle_ports`).
    pub moved: Vec<MovedPort>,
}

/// What deploying [given] would do. A deployed stack's ports are not
/// followed: a setting changed there is the admin's choice.
pub async fn preview(state: &AppState, id: &str, given: &BTreeMap<String, Value>) -> Result<Preview, Refusal> {
    let package = Stacks::package(id).ok_or_else(|| refusal(404, "notFound"))?;
    let installed = store::load(&state.db, id).await.map_err(db_failed)?.is_some();
    let machine = machine(state, id).await;
    let (settings, moved) = settings_for(package, given, &machine, !installed)?;
    Ok(Preview {
        images: package.images(&settings),
        data_paths: package.manifest.data_paths(&settings),
        port: package.manifest.web_port(&settings),
        moved,
        settings,
    })
}

/// Deploys [id] with [given] settings for [username].
pub async fn install(
    state: &Arc<AppState>,
    username: &str,
    id: &str,
    given: &BTreeMap<String, Value>,
    consent: Consent,
) -> Result<Arc<Job>, Refusal> {
    let package = Stacks::package(id).ok_or_else(|| refusal(404, "notFound"))?;
    let m = &package.manifest;
    if !consent.third_party {
        return Err(refusal(400, "notAcknowledged"));
    }
    if m.license.accept && !consent.license {
        return Err(refusal(400, "licenseNotAccepted"));
    }
    if store::load(&state.db, id).await.map_err(db_failed)?.is_some() {
        return Err(refusal(409, "installed"));
    }
    let (runtime, _) = runtime(state).await?;
    let job = state.stacks.begin(id, JobKind::Install)?;
    let result = async {
        let machine = machine(state, id).await;
        let (settings, moved) = settings_for(package, given, &machine, true)?;
        for m in moved {
            job.push(format!("port {} ({}) is in use; using {}", m.from, m.setting, m.to));
        }
        write_files(state, id, package, &settings).await?;
        let now = chrono::Utc::now().to_rfc3339();
        let row = StackRow {
            id: id.to_string(),
            version: m.version.clone(),
            settings,
            proxy_port: proxy_port(state).await?,
            state: "installing".into(),
            license: m.license.spdx.clone(),
            license_accepted_by: username.to_string(),
            license_accepted_at: now.clone(),
            installed_by: username.to_string(),
            installed_at: now.clone(),
            updated_at: now,
            last_error: None,
        };
        if !store::insert(&state.db, &row).await.map_err(db_failed)? {
            return Err(refusal(409, "installed"));
        }
        Ok(row)
    }
    .await;
    let row = match result {
        Ok(row) => row,
        Err(r) => {
            job.finish(JobState::Failed, Some(r.error.into()));
            return Err(r);
        }
    };
    audit(state, username, Action::Open, Outcome::Ok, format!("install {id} {}", m.version)).await;
    let stack = compose(runtime, id, &state.stacks.dir(id), package);
    let (state, job2, username, id) = (state.clone(), job.clone(), username.to_string(), id.to_string());
    tokio::spawn(async move {
        let result = job2.run_steps(&[stack.pull(), stack.up()]).await;
        let error = result.as_ref().err().map(String::as_str);
        if let Err(e) = store::finish(&state.db, &id, error).await {
            tracing::error!("stack {id}: {e}");
        }
        if error.is_none() {
            start_proxy(&state, &row).await;
        }
        conclude(&state, &job2, &username, &id, "install", result).await;
    });
    Ok(job)
}

async fn conclude(state: &AppState, job: &Job, username: &str, id: &str, verb: &str, result: Result<(), String>) {
    match result {
        Ok(()) => {
            job.finish(JobState::Succeeded, None);
            audit(state, username, Action::Close, Outcome::Ok, format!("{verb} {id} done")).await;
        }
        Err(e) => {
            let cancelled = e == "cancelled";
            job.push(format!("✕ {e}"));
            job.finish(if cancelled { JobState::Cancelled } else { JobState::Failed }, Some(e.clone()));
            audit(state, username, Action::Close, Outcome::Error, format!("{verb} {id} failed: {e}")).await;
        }
    }
}

/// What can be done to a deployed stack with the settings it has.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum StackAction {
    Start,
    Stop,
    Restart,
    /// The files written again from this agent's catalog (a newer release),
    /// images pulled, containers recreated.
    Update,
}

pub async fn act(state: &Arc<AppState>, username: &str, id: &str, action: StackAction) -> Result<Arc<Job>, Refusal> {
    let package = Stacks::package(id).ok_or_else(|| refusal(404, "notFound"))?;
    let row = store::load(&state.db, id).await.map_err(db_failed)?.ok_or_else(|| refusal(404, "notInstalled"))?;
    if action == StackAction::Update {
        return redeploy(state, username, id, package, &row.settings, JobKind::Update).await;
    }
    let (runtime, _) = runtime(state).await?;
    if action != StackAction::Stop {
        // Said before Compose fails on it halfway.
        settings_for(package, &row.settings, &machine(state, id).await, false)?;
    }
    let (kind, verb) = match action {
        StackAction::Start => (JobKind::Start, "start"),
        StackAction::Stop => (JobKind::Stop, "stop"),
        StackAction::Restart | StackAction::Update => (JobKind::Restart, "restart"),
    };
    let job = state.stacks.begin(id, kind)?;
    let stack = compose(runtime, id, &state.stacks.dir(id), package);
    let steps = match action {
        StackAction::Start => vec![stack.start()],
        StackAction::Stop => vec![stack.stop()],
        StackAction::Restart | StackAction::Update => vec![stack.restart()],
    };
    audit(state, username, Action::Open, Outcome::Ok, format!("{verb} {id}")).await;
    let (state, job2, username, id) = (state.clone(), job.clone(), username.to_string(), id.to_string());
    tokio::spawn(async move {
        let result = job2.run_steps(&steps).await;
        if row.state != "installed" {
            let _ = store::finish(&state.db, &id, result.as_ref().err().map(String::as_str)).await;
            if result.is_ok()
                && let Ok(Some(row)) = store::load(&state.db, &id).await
            {
                start_proxy(&state, &row).await;
            }
        }
        conclude(&state, &job2, &username, &id, verb, result).await;
    });
    Ok(job)
}

/// Writes [id]'s files again from this agent's catalog with [given]
/// settings, pulls its images and recreates its containers: an update
/// ([`JobKind::Update`], the settings it has) or new settings
/// ([`JobKind::Reconfigure`]). Its ports are checked first, never moved.
async fn redeploy(
    state: &Arc<AppState>,
    username: &str,
    id: &str,
    package: &'static Package,
    given: &BTreeMap<String, Value>,
    kind: JobKind,
) -> Result<Arc<Job>, Refusal> {
    let (runtime, _) = runtime(state).await?;
    let (settings, _) = settings_for(package, given, &machine(state, id).await, false)?;
    let job = state.stacks.begin(id, kind)?;
    if let Err(r) = write_files(state, id, package, &settings).await {
        job.finish(JobState::Failed, Some(r.error.into()));
        return Err(r);
    }
    store::rewrite(&state.db, id, &package.manifest.version, &settings).await.map_err(db_failed)?;
    let verb = if kind == JobKind::Reconfigure { "reconfigure" } else { "update" };
    audit(state, username, Action::Open, Outcome::Ok, format!("{verb} {id} {}", package.manifest.version)).await;
    let stack = compose(runtime, id, &state.stacks.dir(id), package);
    let (state, job2, username, id) = (state.clone(), job.clone(), username.to_string(), id.to_string());
    tokio::spawn(async move {
        let result = job2.run_steps(&[stack.pull(), stack.up()]).await;
        let _ = store::finish(&state.db, &id, result.as_ref().err().map(String::as_str)).await;
        // The service's port may be another now.
        if result.is_ok()
            && let Ok(Some(row)) = store::load(&state.db, &id).await
        {
            start_proxy(&state, &row).await;
        }
        conclude(&state, &job2, &username, &id, verb, result).await;
    });
    Ok(job)
}

/// Deploys [id] again with new [given] settings.
pub async fn reconfigure(state: &Arc<AppState>, username: &str, id: &str, given: &BTreeMap<String, Value>) -> Result<Arc<Job>, Refusal> {
    let package = Stacks::package(id).ok_or_else(|| refusal(404, "notFound"))?;
    store::load(&state.db, id).await.map_err(db_failed)?.ok_or_else(|| refusal(404, "notInstalled"))?;
    redeploy(state, username, id, package, given, JobKind::Reconfigure).await
}

/// Takes [id] down and forgets it; with [purge] its data and files go too.
/// Without, the stack's directory stays (its env file holds the database's
/// password), so deploying again finds the data where it was.
pub async fn remove(state: &Arc<AppState>, username: &str, id: &str, purge: bool) -> Result<Arc<Job>, Refusal> {
    let package = Stacks::package(id).ok_or_else(|| refusal(404, "notFound"))?;
    let row = store::load(&state.db, id).await.map_err(db_failed)?.ok_or_else(|| refusal(404, "notInstalled"))?;
    let (runtime, _) = runtime(state).await?;
    let job = state.stacks.begin(id, JobKind::Remove)?;
    let dir = state.stacks.dir(id);
    let stack = compose(runtime, id, &dir, package);
    let mut steps = vec![stack.down(purge)];
    if purge {
        for path in package.manifest.data_paths(&row.settings) {
            if let Some(cmd) = sbm_parser::stack::purge_command(runtime, &path.to_string_lossy()) {
                steps.push(cmd);
            }
        }
    }
    audit(state, username, Action::Open, Outcome::Ok, format!("remove {id}{}", if purge { " with its data" } else { "" })).await;
    let (state, job2, username, id) = (state.clone(), job.clone(), username.to_string(), id.to_string());
    tokio::spawn(async move {
        let result = job2.run_steps(&steps).await;
        if result.is_ok() {
            state.stacks.proxies.stop(&id);
            if purge && let Err(e) = tokio::fs::remove_dir_all(&dir).await {
                job2.push(format!("{}: {e}", dir.display()));
            }
            if let Err(e) = store::delete(&state.db, &id).await {
                tracing::error!("stack {id}: {e}");
            }
        } else {
            let _ = sqlx::query("UPDATE stack SET last_error = ? WHERE id = ?")
                .bind(result.as_ref().err())
                .bind(&id)
                .execute(&state.db)
                .await;
        }
        conclude(&state, &job2, &username, &id, "remove", result).await;
    });
    Ok(job)
}

/// The stack's containers as Compose reports them.
pub async fn services(state: &AppState, id: &str) -> Result<Vec<sbm_parser::stack::StackService>, Refusal> {
    let package = Stacks::package(id).ok_or_else(|| refusal(404, "notFound"))?;
    let (runtime, _) = runtime(state).await?;
    let stack = compose(runtime, id, &state.stacks.dir(id), package);
    let limits = crate::api::machine::at_least(&state.remote_access.exec, 4 << 20);
    match crate::api::exec::run(&stack.ps(), None, None, &limits).await {
        Ok(out) if out.exit_code == Some(0) => Ok(sbm_parser::stack::parse_ps(&out.stdout)),
        _ => Err(refusal(502, "unreadable")),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn env_values_read_back_unquoted() {
        let env = "# x\nDB_PASSWORD='abc123'\nOTHER='y'\n";
        assert_eq!(read_env(env, &["DB_PASSWORD"]), BTreeMap::from([("DB_PASSWORD".into(), "abc123".into())]));
    }
}
