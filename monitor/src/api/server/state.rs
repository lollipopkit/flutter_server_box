//! `AppState`: what every handler is given, and how it is built.

use crate::{
    api::auth,
    api::ratelimit::LoginThrottle,
    api::ws::{
        listen::PendingStore,
        session::SessionStore,
        ticket::TicketStore,
    },
    core::config::Config,
    core::remote_access::RemoteAccess,
    monitoring::{LiveSettings, SystemMetrics},
    monitoring::velocity::VelocityManager,
    utils::error::{MonitorError, Result},
};
use sqlx::SqlitePool;
use std::sync::{Arc, OnceLock};
use tokio::sync::{Mutex, RwLock, Semaphore, broadcast};

pub(super) const MAX_CONCURRENT_PASSWORD_CHECKS: usize = 4;
pub(super) fn password_check_limit() -> &'static Arc<Semaphore> {
    static LIMIT: OnceLock<Arc<Semaphore>> = OnceLock::new();
    LIMIT.get_or_init(|| {
        let permits = std::thread::available_parallelism()
            .map(|count| count.get())
            .unwrap_or(1)
            .min(MAX_CONCURRENT_PASSWORD_CHECKS);
        Arc::new(Semaphore::new(permits))
    })
}

/// Hashes [password] for storage on a blocking thread, under the same limit
/// as a check: a bcrypt hash is the same work as a verify, and done on the
/// worker it stalls every request that worker is serving.
pub(crate) async fn hash_password_off_worker(password: String) -> Result<String> {
    let permit = password_check_limit()
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| MonitorError::Monitoring("Password hasher is unavailable".to_string()))?;
    tokio::task::spawn_blocking(move || {
        let _permit = permit;
        auth::hash_password(&password)
    })
    .await
    .map_err(|error| MonitorError::Monitoring(format!("Password hasher failed: {error}")))?
}

pub(crate) async fn verify_login_password_off_worker(password: String, hash: Option<String>) -> Result<bool> {
    let permit = password_check_limit()
        .clone()
        .acquire_owned()
        .await
        .map_err(|_| MonitorError::Monitoring("Password verifier is unavailable".to_string()))?;

    tokio::task::spawn_blocking(move || {
        // Keep the permit in the blocking task so cancellation of the request
        // cannot admit another bcrypt check before this one actually stops.
        let _permit = permit;
        auth::verify_login_password(&password, hash.as_deref())
    })
    .await
    .map_err(|error| MonitorError::Monitoring(format!("Password verifier failed: {error}")))?
}

#[derive(Clone)]
pub struct AppState {
    pub config: Arc<Config>,
    pub db: SqlitePool,
    pub current_metrics: Arc<RwLock<Option<SystemMetrics>>>,
    pub velocity_manager: Arc<RwLock<VelocityManager>>,
    /// Settings that apply immediately on save — see `LiveSettings` doc
    pub live_settings: Arc<RwLock<LiveSettings>>,
    /// Last time an authenticated client polled `/metrics` or `/status` —
    /// the idle-pause heartbeat (see `MonitoringConfig.idle_pause_enabled`).
    /// Initialized to startup time, not the epoch, so the extended cycle
    /// isn't treated as already-idle before any client has ever connected.
    pub last_viewer_seen: Arc<RwLock<chrono::DateTime<chrono::Utc>>>,
    /// Resolved remote-access settings (capacities filled in from physical
    /// memory at startup — see `core::remote_access`). A snapshot, like
    /// `config`: turning the terminal on is a restart-level change,
    /// not something a running process should pick up mid-session.
    pub remote_access: Arc<RemoteAccess>,
    /// Whether this process terminates TLS itself. Decided once at startup
    /// from the same config `start_server` binds with, so handlers don't have
    /// to re-derive it.
    pub tls_active: bool,
    pub tickets: Arc<TicketStore>,
    /// Terminal sessions, which outlive the WebSockets driving them so a
    /// reconnect can rejoin the same shell — see `api::ws::session`.
    pub sessions: Arc<SessionStore>,
    /// Connections a remote forward's listener accepted and the app has not
    /// taken yet — see `api::ws::listen`.
    pub pending: Arc<PendingStore>,
    /// Relayed connections, listened ports, consoles and remote desktops open
    /// now — see `api::ws::live`.
    pub live: Arc<crate::api::ws::live::LiveConnections>,
    pub login_throttle: Arc<LoginThrottle>,
    /// Fired when the password changed, carrying the code a client whose
    /// connection ends because of it is told (`password_changed`).
    ///
    /// Every handler asks the database afresh whether its caller may *start*
    /// something; this answers "may this carry on", which only a long-lived
    /// connection has to be told. A relay or a listener holds a subscription
    /// and re-checks the account when it fires; terminal sessions, which
    /// outlive their sockets, are closed by `authz::end_account` itself.
    pub password_changed: broadcast::Sender<&'static str>,
    /// The desk's events and which monitoring rules are firing — see
    /// `api::desk`.
    pub desk: Arc<crate::api::desk::DeskHub>,
    /// The theme store as last read — see `api::desk_themes`.
    pub themes: Arc<crate::api::desk_themes::ThemeStore>,
    /// Files kept beside the database — see `core::blobs`.
    pub blobs: Arc<crate::core::blobs::Blobs>,
    /// Agent mode's tasks and the pi runtime they run in — see `agent_mode`.
    pub agent: Arc<crate::agent_mode::AgentMode>,
    /// Desk app backend calls running now (`api::app_runtime`).
    pub app_calls: crate::api::app_runtime::AppCalls,
    /// The web apps this agent deployed, their jobs and proxies — see
    /// `stacks`.
    pub stacks: Arc<crate::stacks::Stacks>,
    /// Local inference (`inference`).
    pub inference: Arc<crate::inference::Inference>,
    /// AI agents' installs (`api::agent_tools`).
    pub agent_tools: Arc<crate::api::agent_tools::AgentToolsJobs>,
    /// Reverse proxies' installs (`api::proxy`).
    pub proxy: Arc<crate::api::proxy::ProxyJobs>,
    pub container_backups: Arc<crate::container_backups::ContainerBackups>,
    pub storage: Arc<crate::api::storage::StorageJobs>,
    pub shares: Arc<crate::api::shares::SharesJobs>,
    /// The last process table read, which the next one's read and write
    /// speeds are differenced against — see `api::process`.
    pub process_sample: Arc<tokio::sync::Mutex<Option<crate::api::process::ProcessSample>>>,
    /// The PVE session and the libvirt rate history kept between the
    /// Virtualization page's requests — see `api::virt`.
    pub virt: Arc<crate::api::virt::VirtState>,
    /// Serialises every read-modify-write of `config.toml`.
    ///
    /// `config_file::write` is atomic, so no reader ever sees a half-written
    /// file — but atomicity alone doesn't stop two handlers from each reading
    /// the same starting state and the later write discarding the earlier
    /// one's field. `/settings` and `/card-order` are separate endpoints
    /// precisely so ordinary use doesn't contend here, yet they still edit
    /// one file and must not race.
    pub config_write: Arc<Mutex<()>>,
    /// The agent's own releases as last read — see `api::update`.
    pub update: Arc<crate::api::update::AgentUpdate>,
}

/// The file a `sqlite:` [url] opens, or `None` for an in-memory database.
pub(super) fn sqlite_file(url: &str) -> Option<std::path::PathBuf> {
    use std::str::FromStr;
    let options = sqlx::sqlite::SqliteConnectOptions::from_str(url).ok()?;
    let file = options.get_filename();
    let memory = url.contains("mode=memory")
        || file.as_os_str().is_empty()
        || file.to_string_lossy().starts_with("file:");
    (!memory).then(|| file.to_path_buf())
}

/// The file [db] opened, or `None` for an in-memory database.
pub(super) fn sqlite_file_of(db: &SqlitePool) -> Option<std::path::PathBuf> {
    let file = db.connect_options().get_filename().to_path_buf();
    let memory = file.as_os_str().is_empty() || file.to_string_lossy().starts_with("file:") || file.to_string_lossy() == ":memory:";
    (!memory).then_some(file)
}

/// Where this agent keeps what the file API must never reach — see
/// [`crate::core::fs_roots::Protected`]: the database (and its journal files)
/// with `jwt.secret`, the first-start credentials and the blob directory
/// (`core::blobs`) beside it, `config.toml`
/// and its backups, `.env`, the TLS certificate and key, and the
/// custom-commands directory.
pub(super) fn agent_state(config: &Config) -> crate::core::fs_roots::Protected {
    use std::path::Path;
    let mut protected = crate::core::fs_roots::Protected::default();
    let url = config.get_database_url();
    // The file sqlx opens, as sqlx reads the URL — percent-decoded, query
    // removed. Taking it apart here by hand protected `my%20db.db` while the
    // database was `my db.db`.
    if let Some(db) = sqlite_file(&url) {
        protected.file(&db);
        protected.tree(crate::core::blobs::Blobs::beside(&db).dir());
        protected.tree(&crate::agent_mode::AgentMode::dir_beside(&db));
        crate::stacks::Stacks::protect_beside(&db, &mut protected);
        protected.tree(&crate::container_backups::ContainerBackups::dir_beside(&db));
        protected.tree(&crate::inference::Inference::dir_beside(&db));
    }
    protected.file(&config.jwt_secret_path());
    protected.file(&crate::db::bootstrap::initial_credentials_path(&url));
    protected.file(Path::new(crate::core::config_file::CONFIG_PATH));
    // The environment file: the one in the working directory (and its
    // backups, by prefix), and the one actually loaded, which `dotenvy` may
    // have found in a parent directory.
    protected.file(Path::new(".env"));
    if let Some(env) = crate::core::config::loaded_dotenv() {
        protected.file(env);
    }
    if let Some(tls) = config.get_server().tls {
        protected.file(Path::new(&tls.cert_path));
        protected.file(Path::new(&tls.key_path));
    }
    if let Some(dir) = sbm_parser::script::custom_cmd_dir_path() {
        protected.tree(&dir);
    }
    protected
}

impl AppState {
    pub fn new(config: Arc<Config>, db: SqlitePool) -> Arc<Self> {
        let velocity_manager = Arc::new(RwLock::new(VelocityManager::new()));
        let live_settings = Arc::new(RwLock::new(LiveSettings::from_config(&config.get_monitoring())));
        let tls_active = config.get_server().tls.is_some();
        let remote_access_config = config.get_remote_access();
        let retired = remote_access_config.retired_keys();
        if !retired.is_empty() {
            // TODO: remove with `RemoteAccessConfig::retired_keys`.
            tracing::warn!(
                "[remote_access] {} no longer restrict anything: whoever signs in may do what this \
                 system account may. Remove them, and run the agent as an account with only the \
                 access you want it to have.",
                retired.join(", ")
            );
        }
        let mut remote_access = remote_access_config.resolve(sbm_native::total_memory());
        remote_access.fs.roots = remote_access
            .fs
            .roots
            .clone()
            .protecting(agent_state(&config));
        remote_access.log_summary(tls_active);
        let sessions = Arc::new(SessionStore::new(
            remote_access.terminal.max_sessions,
            remote_access.terminal.detached_timeout,
        ));
        Arc::new(Self {
            remote_access: Arc::new(remote_access),
            tls_active,
            tickets: Arc::new(TicketStore::new()),
            sessions,
            pending: Arc::new(PendingStore::default()),
            live: Arc::default(),
            login_throttle: Arc::new(LoginThrottle::new()),
            password_changed: broadcast::channel(16).0,
            desk: Arc::new(crate::api::desk::DeskHub::default()),
            themes: Arc::new(crate::api::desk_themes::ThemeStore::default()),
            // Beside the database actually open, which a test's in-memory
            // one is not, whatever its configuration names.
            blobs: Arc::new(match sqlite_file_of(&db) {
                Some(file) => crate::core::blobs::Blobs::beside(&file),
                None => crate::core::blobs::Blobs::temporary(),
            }),
            agent: Arc::new(crate::agent_mode::AgentMode::new(db.clone(), sqlite_file_of(&db).as_deref())),
            container_backups: Arc::new(crate::container_backups::ContainerBackups::new(sqlite_file_of(&db).as_deref())),
            storage: Arc::default(),
            shares: Arc::default(),
            stacks: Arc::new(crate::stacks::Stacks::new(
                sqlite_file_of(&db).as_deref(),
                config.get_stacks().local_apps.as_deref().map(std::path::Path::new),
                config.get_stacks().shared_dir.as_deref().map(std::path::Path::new),
            )),
            inference: Arc::new(crate::inference::Inference::new(sqlite_file_of(&db).as_deref())),
            agent_tools: Arc::default(),
            proxy: Arc::default(),
            app_calls: Default::default(),
            process_sample: Arc::new(tokio::sync::Mutex::new(None)),
            virt: Arc::new(crate::api::virt::VirtState::default()),
            config,
            db,
            current_metrics: Arc::new(RwLock::new(None)),
            velocity_manager,
            live_settings,
            last_viewer_seen: Arc::new(RwLock::new(chrono::Utc::now())),
            config_write: Arc::new(Mutex::new(())),
            update: Arc::default(),
        })
    }
}

#[cfg(test)]
mod agent_state_tests {
    use super::*;

    #[test]
    fn the_database_is_the_file_sqlx_opens() {
        assert_eq!(
            sqlite_file("sqlite:///data/my%20db.db?mode=rwc"),
            Some(std::path::PathBuf::from("/data/my db.db"))
        );
        assert_eq!(
            sqlite_file("sqlite:serverbox_monitor.db"),
            Some(std::path::PathBuf::from("serverbox_monitor.db"))
        );
        assert_eq!(sqlite_file("sqlite::memory:"), None);
        assert_eq!(sqlite_file("sqlite://?mode=memory"), None);
    }

    #[test]
    fn the_environment_file_is_agent_state() {
        // Whatever the operator put in the environment — credentials included —
        // is in `.env`, and the installer leaves `.env.bak-*` beside it.
        let protected = agent_state(&Config::default());
        let cwd = std::fs::canonicalize(".").unwrap();
        assert!(protected.covers(&cwd.join(".env")));
        assert!(protected.covers(&cwd.join(".env.bak-1789489640")));
        assert!(!protected.covers(&cwd.join("notes.env")));
    }

    #[test]
    fn the_blob_directory_is_agent_state() {
        // The default database is `serverbox_monitor.db` in the working
        // directory, so its files are `./blobs/...`, every one of them.
        let protected = agent_state(&Config::default());
        let cwd = std::fs::canonicalize(".").unwrap();
        assert!(protected.covers(&cwd.join("blobs").join("ab").join("ab".repeat(32))));
        assert!(protected.covers(&cwd.join("blobs").join("tmp").join("x")));
    }
}
