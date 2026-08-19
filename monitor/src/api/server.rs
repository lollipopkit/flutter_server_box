use crate::{
    api::auth::{self, Claims},
    api::cors::Cors,
    api::ratelimit::LoginThrottle,
    api::ws::{
        self,
        audit::{self, Action, Event, Kind, Outcome},
        session::SessionStore,
        terminal::{start_reaper, terminal_ws},
        ticket::{Purpose, TicketRequest, TicketResponse, TicketStore},
        tunnel::{TunnelCount, tunnel_ws},
    },
    core::config::Config,
    core::config_file,
    core::remote_access::RemoteAccess,
    monitoring::{self, LiveSettings, SystemMetrics},
    monitoring::size::Size,
    monitoring::velocity::{NetworkSpeedInfo, VelocityAnalysisResponse, VelocityManager},
    utils::error::{MonitorError, Result},
};
use ntex::http::header::RETRY_AFTER;
use ntex::web::{self, App, HttpRequest, HttpResponse, HttpServer, middleware::Logger};
use ntex_files::Files;
use sbm_parser::{SystemType, capabilities::Capabilities};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use sqlx::SqlitePool;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, OnceLock};
use std::time::Duration;
use tokio::sync::{Mutex, RwLock, Semaphore};
use tracing::info;

const MAX_CONCURRENT_PASSWORD_CHECKS: usize = 4;
const WATCH_TOKEN_LIFETIME: chrono::Duration = chrono::Duration::days(90);

fn password_check_limit() -> &'static Arc<Semaphore> {
    static LIMIT: OnceLock<Arc<Semaphore>> = OnceLock::new();
    LIMIT.get_or_init(|| {
        let permits = std::thread::available_parallelism()
            .map(|count| count.get())
            .unwrap_or(1)
            .min(MAX_CONCURRENT_PASSWORD_CHECKS);
        Arc::new(Semaphore::new(permits))
    })
}

async fn verify_login_password_off_worker(password: String, hash: Option<String>) -> Result<bool> {
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
    /// `config`: turning the tunnel or terminal on is a restart-level change,
    /// not something a running process should pick up mid-session.
    pub remote_access: Arc<RemoteAccess>,
    /// Whether this process terminates TLS itself. Decided once at startup
    /// from the same config `start_server` binds with, so handlers don't have
    /// to re-derive it.
    pub tls_active: bool,
    pub tickets: Arc<TicketStore>,
    /// Live tunnel count, for `remote_access.tunnel.max_conns`.
    pub tunnel_count: Arc<TunnelCount>,
    /// Terminal sessions, which outlive the WebSockets driving them so a
    /// reconnect can rejoin the same shell — see `api::ws::session`.
    pub sessions: Arc<SessionStore>,
    pub login_throttle: Arc<LoginThrottle>,
    /// Set when the panel turns the access without SSH off, so the change
    /// applies to the running process rather than waiting for a restart.
    /// One-way: nothing here can switch it back on.
    pub full_access_off: Arc<AtomicBool>,
    /// Serialises every read-modify-write of `config.toml`.
    ///
    /// `config_file::write` is atomic, so no reader ever sees a half-written
    /// file — but atomicity alone doesn't stop two handlers from each reading
    /// the same starting state and the later write discarding the earlier
    /// one's field. `/settings` and `/card-order` are separate endpoints
    /// precisely so ordinary use doesn't contend here, yet they still edit
    /// one file and must not race.
    pub config_write: Arc<Mutex<()>>,
}

impl AppState {
    pub fn new(config: Arc<Config>, db: SqlitePool) -> Arc<Self> {
        let db_arc = Arc::new(db.clone());
        let velocity_manager = Arc::new(RwLock::new(VelocityManager::new(db_arc)));
        let live_settings = Arc::new(RwLock::new(LiveSettings::from_config(&config.get_monitoring())));
        let tls_active = config.get_server().tls.is_some();
        let remote_access = config
            .get_remote_access()
            .resolve(sbm_native::total_memory());
        remote_access.log_summary(tls_active);
        let sessions = Arc::new(SessionStore::new(
            remote_access.terminal.max_sessions,
            remote_access.terminal.detached_timeout,
        ));
        Arc::new(Self {
            remote_access: Arc::new(remote_access),
            tls_active,
            tickets: Arc::new(TicketStore::new()),
            tunnel_count: Arc::new(Default::default()),
            sessions,
            login_throttle: Arc::new(LoginThrottle::new()),
            full_access_off: Arc::new(AtomicBool::new(false)),
            config,
            db,
            current_metrics: Arc::new(RwLock::new(None)),
            velocity_manager,
            live_settings,
            last_viewer_seen: Arc::new(RwLock::new(chrono::Utc::now())),
            config_write: Arc::new(Mutex::new(())),
        })
    }

    /// Whether a shell may be opened without SSH credentials right now.
    ///
    /// The config snapshot minus anything the panel has switched off since
    /// startup. Both halves are checked at the point of use rather than
    /// resolved once, so pressing "turn this off" takes effect on the next
    /// request instead of the next restart.
    pub fn full_access_allowed(&self, secure: bool) -> bool {
        self.remote_access.full_access_available(secure)
            && !self.full_access_off.load(Ordering::Acquire)
    }
}

#[derive(Deserialize)]
struct LoginRequest {
    username: String,
    password: String,
}

#[derive(Serialize)]
struct LoginResponse {
    token: String,
}

#[derive(Deserialize)]
struct WatchTokenRequest {
    client_id: String,
}

#[derive(Serialize)]
struct WatchTokenResponse {
    token: String,
    expires_at: i64,
}

#[derive(Serialize)]
struct StatusResponse {
    name: String,
    cpu: String,
    memory: String,
    disk: String,
    network: String,
    temperature: Option<String>,
    timestamp: String,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

pub async fn start_server(app_state: Arc<AppState>) -> Result<()> {
    let server_config = app_state.config.get_server();
    let bind_addr = format!("{}:{}", server_config.host, server_config.port);

    if app_state.remote_access.terminal.enabled {
        // A quarter of the grace period: often enough that a reaped session
        // isn't held much past its deadline, rare enough to be invisible
        start_reaper(
            app_state.sessions.clone(),
            (app_state.remote_access.terminal.detached_timeout / 4)
                .max(Duration::from_secs(10)),
        );
    }

    let server = HttpServer::new(async move || {
        let cors = Cors::new(app_state.config.get_server().cors_allowed_origins);

        App::new()
            .state(app_state.clone())
            .middleware(Logger::default())
            .middleware(cors)
            .service(
                web::scope("/api/v1")
                    .route("/login", web::post().to(login))
                    .service(
                        web::resource("/watch-token")
                            .route(web::post().to(issue_watch_token))
                            .route(web::delete().to(revoke_watch_token)),
                    )
                    .route("/status", web::get().to(get_status))
                    .route("/metrics", web::get().to(get_metrics))
                    .route("/capabilities", web::get().to(get_capabilities))
                    .route("/ws-ticket", web::post().to(issue_ws_ticket))
                    .route("/tunnel/ws", web::get().to(tunnel_ws))
                    .route("/terminal/ws", web::get().to(terminal_ws))
                    .service(
                        // Its own payload limit: ntex allows 32 KiB by
                        // default, and this endpoint's `stdin` carries the
                        // generated status script — 5 KiB today, but it grows
                        // with every custom command a user adds, and going
                        // over would answer 413 with nothing to explain it.
                        web::resource("/exec")
                            .state(
                                web::types::JsonConfig::default()
                                    .limit(crate::api::exec::MAX_REQUEST),
                            )
                            .route(web::post().to(crate::api::exec::exec)),
                    )
                    .service(
                        // A streamed body, so ntex's payload limit must not
                        // apply: the point of this endpoint is the file that
                        // `/exec` could not carry.
                        web::resource("/fs/write")
                            .route(web::put().to(crate::api::fs::write)),
                    )
                    .route("/fs/roots", web::get().to(crate::api::fs::roots))
                    .route("/fs/list", web::get().to(crate::api::fs::list))
                    .route("/fs/stat", web::get().to(crate::api::fs::stat))
                    .route("/fs/read", web::get().to(crate::api::fs::read))
                    .route("/fs/mkdir", web::post().to(crate::api::fs::mkdir))
                    .route("/fs/rename", web::post().to(crate::api::fs::rename))
                    .route("/fs/chmod", web::post().to(crate::api::fs::chmod))
                    .route("/fs/remove", web::delete().to(crate::api::fs::remove))
                    .route(
                        "/remote-access/full-access",
                        web::delete().to(disable_full_access),
                    )
                    .service(
                        // Its own payload limit, like `/exec`: the body is
                        // every custom command at once, and a user who pastes
                        // a real script into one would otherwise meet ntex's
                        // 32 KiB default as a 413 with nothing to explain it.
                        web::resource("/custom-cmds")
                            .state(
                                web::types::JsonConfig::default()
                                    .limit(crate::api::custom_cmds::MAX_REQUEST),
                            )
                            .route(web::get().to(crate::api::custom_cmds::list))
                            .route(web::put().to(crate::api::custom_cmds::replace)),
                    )
                    .route("/settings", web::get().to(get_settings))
                    .route("/settings", web::put().to(update_settings))
                    .route("/card-order", web::get().to(get_card_order))
                    .route("/card-order", web::put().to(update_card_order))
                    .route("/metrics/history", web::get().to(get_metrics_history))
                    .route("/health", web::get().to(health_check))
                    .route("/velocity", web::get().to(get_velocity))
                    .route("/velocity/history", web::get().to(get_velocity_history)),
            )
            // TODO: Go-compat endpoint (used by the flutter_server_box app); remove once the app migrates to /api/v1
            .route("/status", web::get().to(get_status_compat))
            // Static file serving configuration:
            // 1. /static/* routes serve files from {static_dir}/static/ directory (React build structure)
            // 2. Root level files (favicon.ico, manifest.json, etc.) served from {static_dir}/
            // 3. SPA fallback serves index.html for client-side routing
            .service(
                Files::new("/static", "frontend/dist")
                    .use_etag(true) // Enable ETag headers for caching
                    .use_last_modified(true), // Enable Last-Modified headers
            )
            .service(
                Files::new("/", "frontend/dist")
                    .use_etag(true)
                    .use_last_modified(true)
                    .index_file("index.html"),
            )
            // SPA fallback - serves index.html for unmatched routes (client-side routing)
            .service(serve_index)
            .default_service(web::to(spa_fallback))
    });

    let server = match &server_config.tls {
        Some(tls) => {
            info!("Starting web server on {} (TLS)", bind_addr);
            server.bind_rustls(&bind_addr, &load_rustls_config(tls)?)?
        }
        None => {
            info!("Starting web server on {}", bind_addr);
            server.bind(&bind_addr)?
        }
    };
    server.run().await?;

    Ok(())
}

/// Build the rustls server config from PEM cert/key (ring provider, consistent with our dependency choices)
fn load_rustls_config(tls: &crate::core::config::TlsConfig) -> Result<rustls::ServerConfig> {
    use std::{fs::File, io::BufReader};

    let certs = rustls_pemfile::certs(&mut BufReader::new(File::open(&tls.cert_path)?))
        .collect::<std::io::Result<Vec<_>>>()?;
    let key = rustls_pemfile::private_key(&mut BufReader::new(File::open(&tls.key_path)?))?
        .ok_or_else(|| anyhow::anyhow!("No private key found in {}", tls.key_path))?;

    let config = rustls::ServerConfig::builder_with_provider(Arc::new(
        rustls::crypto::ring::default_provider(),
    ))
    .with_safe_default_protocol_versions()
    .map_err(|e| anyhow::anyhow!("TLS protocol config: {e}"))?
    .with_no_client_auth()
    .with_single_cert(certs, key)
    .map_err(|e| anyhow::anyhow!("Invalid TLS cert/key: {e}"))?;
    Ok(config)
}

#[web::get("/")]
async fn serve_index() -> impl web::Responder {
    spa_fallback().await
}

async fn spa_fallback() -> HttpResponse {
    match tokio::fs::read_to_string("frontend/dist/index.html").await {
        Ok(content) => HttpResponse::Ok()
            .content_type("text/html; charset=utf-8")
            .body(content),
        Err(_) => HttpResponse::InternalServerError().json(&ErrorResponse {
            error: "Failed to load index.html".to_string(),
        }),
    }
}

async fn login(
    http_req: HttpRequest,
    req: web::types::Json<LoginRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    let peer_ip = http_req.peer_addr().map(|addr| addr.ip());

    // Checked before touching the database, so a guessing loop can't keep
    // spending bcrypt verifications (~100ms each) on this process.
    if let Some(wait) = app_state.login_throttle.check(peer_ip, &req.username) {
        let seconds = wait.as_secs().max(1);
        return Ok(HttpResponse::TooManyRequests()
            .header(RETRY_AFTER, seconds.to_string())
            .json(&ErrorResponse {
                error: format!("Too many failed attempts; retry in {seconds}s"),
            }));
    }

    // Verify user credentials
    let user = sqlx::query!(
        "SELECT id, username, password_hash FROM users WHERE username = ?",
        req.username
    )
    .fetch_optional(&app_state.db)
    .await?;

    // A missing account must cost the same bcrypt verification as a wrong
    // password, or response timing turns the login endpoint into a username
    // oracle even though both paths return the same status and throttle key.
    let password_matches = verify_login_password_off_worker(
        req.password.clone(),
        user.as_ref().map(|user| user.password_hash.clone()),
    )
    .await?;

    if let Some(user) = user
        && password_matches
    {
        app_state.login_throttle.record_success(peer_ip, &req.username);

        // Update last login
        sqlx::query!(
            "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?",
            user.id
        )
        .execute(&app_state.db)
        .await?;

        // Generate JWT token
        let token = auth::generate_token(&user.username, &app_state.config.get_jwt_secret())?;

        return Ok(HttpResponse::Ok().json(&LoginResponse { token }));
    }

    // One counter for both "no such user" and "wrong password": tracking them
    // separately would let an attacker tell the two apart by how quickly they
    // get throttled.
    app_state.login_throttle.record_failure(peer_ip, &req.username);

    Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
        error: "Invalid credentials".to_string(),
    }))
}

/// Lowercase hex of the SHA-256, which is what the `watch_tokens` rows already
/// hold — `hex::encode` writes the same bytes the `{:x}` of digest 0.10 did.
fn watch_token_hash(token: &str) -> String {
    hex::encode(Sha256::digest(token.as_bytes()))
}

fn validate_watch_client_id(client_id: &str) -> Result<&str> {
    let client_id = client_id.trim();
    if client_id.is_empty() || client_id.len() > 128 {
        return Err(MonitorError::Parse(
            "watch token client_id must be 1..=128 characters".to_string(),
        ));
    }
    Ok(client_id)
}

async fn issue_watch_token(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<WatchTokenRequest>,
) -> Result<HttpResponse> {
    let claims = match verify_auth(&req, &app_state.config.get_jwt_secret()) {
        Ok(claims) => claims,
        Err(_) => {
            return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
                error: "Invalid or missing token".to_string(),
            }));
        }
    };
    let client_id = validate_watch_client_id(&payload.client_id)?;
    let token = format!("sbw_{}", crate::utils::secrets::random_hex(32)?);
    let token_hash = watch_token_hash(&token);
    let now = chrono::Utc::now().timestamp();
    let expires_at = (chrono::Utc::now() + WATCH_TOKEN_LIFETIME).timestamp();
    sqlx::query(
        "INSERT INTO watch_tokens(subject, client_id, token_hash, created_at, expires_at) \
         VALUES (?, ?, ?, ?, ?) \
         ON CONFLICT(subject, client_id) DO UPDATE SET \
         token_hash = excluded.token_hash, created_at = excluded.created_at, \
         expires_at = excluded.expires_at",
    )
    .bind(&claims.sub)
    .bind(client_id)
    .bind(token_hash)
    .bind(now)
    .bind(expires_at)
    .execute(&app_state.db)
    .await?;
    Ok(HttpResponse::Ok().json(&WatchTokenResponse { token, expires_at }))
}

async fn revoke_watch_token(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<WatchTokenRequest>,
) -> Result<HttpResponse> {
    let claims = match verify_auth(&req, &app_state.config.get_jwt_secret()) {
        Ok(claims) => claims,
        Err(_) => {
            return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
                error: "Invalid or missing token".to_string(),
            }));
        }
    };
    let client_id = validate_watch_client_id(&payload.client_id)?;
    sqlx::query("DELETE FROM watch_tokens WHERE subject = ? AND client_id = ?")
        .bind(&claims.sub)
        .bind(client_id)
        .execute(&app_state.db)
        .await?;
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "status": "revoked" })))
}

// TODO: Go-compat endpoint (matches the legacy GET /status response format, unauthenticated); remove once flutter_server_box migrates
async fn get_status_compat(
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    let metrics = app_state.current_metrics.read().await;
    let data = go_status_data(metrics.as_ref(), &app_state.config.get_server_name());
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "code": 0, "data": data })))
}

/// Response data of Go web.Status: sizes in Size.String() format (e.g. "26.0g"), CPU as one-decimal percentage
pub fn go_status_data(metrics: Option<&SystemMetrics>, server_name: &str) -> serde_json::Value {
    match metrics {
        Some(m) => serde_json::json!({
            "name": m.server_name,
            "cpu": format!("{:.1}%", m.cpu_usage),
            "mem": format!("{} / {}", Size(m.memory.used), Size(m.memory.total)),
            "net": format!("{} / {}", Size(m.network.rx_bytes), Size(m.network.tx_bytes)),
            "disk": format!("{} / {}", Size(m.disk.used), Size(m.disk.total)),
        }),
        None => serde_json::json!({
            "name": server_name,
            "cpu": "", "mem": "", "net": "", "disk": "",
        }),
    }
}

async fn get_status(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    // Verify JWT token
    if verify_read_auth(&req, &app_state).await.is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }
    touch_viewer_heartbeat(&app_state).await;

    let metrics = app_state.current_metrics.read().await;

    if let Some(ref metrics) = *metrics {
        let response = StatusResponse {
            name: metrics.server_name.clone(),
            cpu: format!("{:.1}%", metrics.cpu_usage),
            memory: format!(
                "{:.1}% ({} / {})",
                metrics.memory.usage_percent,
                format_bytes(metrics.memory.used),
                format_bytes(metrics.memory.total)
            ),
            disk: format!(
                "{:.1}% ({} / {})",
                metrics.disk.usage_percent,
                format_bytes(metrics.disk.used),
                format_bytes(metrics.disk.total)
            ),
            network: format!(
                "RX: {} / TX: {}",
                format_bytes(metrics.network.rx_bytes),
                format_bytes(metrics.network.tx_bytes)
            ),
            temperature: metrics.temperature.map(|t| format!("{:.1}°C", t)),
            timestamp: metrics.timestamp.to_rfc3339(),
        };

        Ok(HttpResponse::Ok().json(&response))
    } else {
        Ok(HttpResponse::ServiceUnavailable().json(&ErrorResponse {
            error: "Metrics not available yet".to_string(),
        }))
    }
}

async fn get_metrics(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    // Verify JWT token
    if verify_read_auth(&req, &app_state).await.is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }
    touch_viewer_heartbeat(&app_state).await;

    let metrics = app_state.current_metrics.read().await;

    if let Some(ref metrics) = *metrics {
        Ok(HttpResponse::Ok().json(metrics))
    } else {
        Ok(HttpResponse::ServiceUnavailable().json(&ErrorResponse {
            error: "Metrics not available yet".to_string(),
        }))
    }
}

/// Which `ServerStatus` fields this platform can collect at all — depends
/// only on the OS the agent runs on, never on a sample, so unlike `/metrics`
/// this isn't meant to be polled; the frontend fetches it once per server
/// connection. See `sbm_parser::capabilities` for the three-state meaning and
/// `monitoring::effective_capabilities` for monitor's native-sampling overrides.
/// `Capabilities` plus the OS family — mechanically derived from the same
/// `system_type()` used to compute `capabilities` itself, so it can't drift
/// out of sync. Used by the panel to pick an OS icon for the sidebar/header;
/// `Bsd` covers macOS (the only Bsd target this monitor actually ships on).
#[derive(Serialize)]
struct CapabilitiesView {
    #[serde(flatten)]
    capabilities: Capabilities,
    platform: SystemType,
    remote_access: RemoteAccessView,
}

/// Which remote-access paths this agent will actually accept, as opposed to
/// what the config asks for: `terminal` already accounts for the transport
/// check, so the panel can hide the entry rather than offer something that
/// answers 403. `secure` is reported separately so it can explain *why*.
#[derive(Serialize)]
struct RemoteAccessView {
    tunnel: bool,
    terminal: bool,
    secure: bool,
    /// Whether a shell can be opened without SSH credentials. The panel only
    /// offers that entry when this is true — and, being a UI decision, it is
    /// re-checked server-side when the request actually arrives.
    full_access: bool,
    /// Whether `/api/v1/fs/*` will answer. Its own field rather than folded
    /// into [`Self::full_access`]: the file API is confined to the roots the
    /// operator named, so it can be on while the shell is off.
    files: bool,
}

async fn get_capabilities(req: HttpRequest, app_state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }
    let platform = monitoring::system_type();
    let capabilities = monitoring::effective_capabilities(platform);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    Ok(HttpResponse::Ok().json(&CapabilitiesView {
        capabilities,
        platform,
        remote_access: RemoteAccessView {
            tunnel: app_state.remote_access.tunnel.enabled,
            terminal: app_state.remote_access.terminal.available(secure),
            secure,
            full_access: app_state.full_access_allowed(secure),
            files: app_state.remote_access.fs.available(),
        },
    }))
}

/// Exchanges the caller's JWT for a short-lived, single-use ticket that
/// authorises one WebSocket upgrade — see `api::ws::ticket` for why the
/// upgrade can't just carry the JWT.
///
/// Refuses to mint a ticket for a path that isn't open, so a client finds out
/// here rather than at a failed handshake.
async fn issue_ws_ticket(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<TicketRequest>,
) -> Result<HttpResponse> {

    let claims = match verify_auth(&req, &app_state.config.get_jwt_secret()) {
        Ok(claims) => claims,
        Err(_) => {
            return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
                error: "Invalid or missing token".to_string(),
            }));
        }
    };

    let purpose = payload.into_inner().purpose;
    let remote_ip = audit::peer_ip(&req);
    let available = match purpose {
        Purpose::Tunnel => app_state.remote_access.tunnel.enabled,
        Purpose::Terminal => app_state
            .remote_access
            .terminal.available(ws::is_secure_transport(&req, app_state.tls_active)),
    };
    if !available {
        Event::new(Kind::Ticket, Action::Denied, Outcome::Denied)
            .subject(&claims.sub)
            .remote_ip(remote_ip)
            .detail(format!("{purpose:?} not available"))
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().json(&ErrorResponse {
            error: "Remote access is not enabled for this purpose".to_string(),
        }));
    }

    match app_state.tickets.issue(purpose, &claims.sub) {
        Ok(ticket) => {
            Event::new(Kind::Ticket, Action::Open, Outcome::Ok)
                .subject(&claims.sub)
                .remote_ip(remote_ip)
                .detail(format!("{purpose:?}"))
                .record(&app_state.db)
                .await;
            Ok(HttpResponse::Ok()
                .json(&TicketResponse::new(ticket)))
        }
        Err(e) => {
            Event::new(Kind::Ticket, Action::Denied, Outcome::Error)
                .subject(&claims.sub)
                .remote_ip(remote_ip)
                .detail("issue failed")
                .record(&app_state.db)
                .await;
            Ok(HttpResponse::ServiceUnavailable().json(&ErrorResponse {
                error: e.to_string(),
            }))
        }
    }
}

/// Whitelisted, writable subset of `Config` the settings page exposes.
/// Deliberately excludes `jwt_secret`/`database_url`/`push` (secrets, or
/// need their own dedicated design for session-invalidation-on-rotation) —
/// see the settings-page plan for why those are out of scope.
#[derive(Serialize, Deserialize)]
struct SettingsPayload {
    interval_seconds: u64,
    /// `null` = follow `interval_seconds` (see `LiveSettings`)
    extended_interval_secs: Option<u64>,
    idle_pause_enabled: bool,
    /// `null` = `interval_seconds * 4`
    idle_pause_threshold_secs: Option<u64>,
    rules: Vec<crate::core::config::MonitoringRule>,
    data_retention: Option<crate::core::config::DataRetentionConfig>,
    cors_allowed_origins: Vec<String>,
}

/// GET-only wrapper: which fields take effect immediately vs. need a
/// restart, so the settings UI can label fields honestly instead of
/// guessing. A separate type from `SettingsPayload` (rather than an
/// `Option<Vec<&'static str>>` field on it) because a `'static` field breaks
/// deriving `Deserialize`, which `SettingsPayload` also needs for PUT.
#[derive(Serialize)]
struct SettingsView {
    #[serde(flatten)]
    settings: SettingsPayload,
    live_fields: &'static [&'static str],
}

const SETTINGS_LIVE_FIELDS: &[&str] = &["extended_interval_secs", "idle_pause_enabled", "idle_pause_threshold_secs"];

async fn get_settings(req: HttpRequest, app_state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }

    let file_config = match config_file::read() {
        Ok(c) => c,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: e.to_string() }));
        }
    };
    let monitoring = file_config.get_monitoring();
    let live = app_state.live_settings.read().await.clone();

    Ok(HttpResponse::Ok().json(&SettingsView {
        settings: SettingsPayload {
            interval_seconds: monitoring.interval_seconds,
            extended_interval_secs: monitoring.extended.interval_secs,
            idle_pause_enabled: live.idle_pause_enabled,
            idle_pause_threshold_secs: monitoring.extended.idle_pause.threshold_secs,
            rules: monitoring.rules,
            data_retention: monitoring.data_retention,
            cors_allowed_origins: file_config.get_server().cors_allowed_origins,
        },
        live_fields: SETTINGS_LIVE_FIELDS,
    }))
}

/// Kept beside the settings endpoint so file and API validation cannot drift.
fn validate_threshold_format(threshold: &str) -> std::result::Result<(), String> {
    let re = regex::Regex::new(r"^(>=|<=|>|<|==|!=)(\d+(?:\.\d+)?)([%KMGTB]*)(/s)?$").unwrap();
    if re.is_match(threshold) {
        Ok(())
    } else {
        Err(format!("Invalid threshold format: {threshold}"))
    }
}

async fn update_settings(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<SettingsPayload>,
) -> Result<HttpResponse> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }
    let payload = payload.into_inner();

    if payload.interval_seconds < 1 {
        return Ok(HttpResponse::BadRequest()
            .json(&ErrorResponse { error: "interval_seconds must be at least 1".to_string() }));
    }
    for rule in &payload.rules {
        if let Err(e) = validate_threshold_format(&rule.threshold) {
            return Ok(HttpResponse::BadRequest().json(&ErrorResponse {
                error: format!("Rule '{}': {e}", rule.name),
            }));
        }
    }

    // Held across the whole read-modify-write so a concurrent PUT can't read
    // the same starting state and drop this change on its own save.
    let _config_guard = app_state.config_write.lock().await;

    let mut config = match config_file::read() {
        Ok(c) => c,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: e.to_string() }));
        }
    };

    let mut monitoring = config.get_monitoring();
    monitoring.interval_seconds = payload.interval_seconds;
    monitoring.extended.interval_secs = payload.extended_interval_secs;
    monitoring.extended.idle_pause.enabled = payload.idle_pause_enabled;
    monitoring.extended.idle_pause.threshold_secs = payload.idle_pause_threshold_secs;
    monitoring.rules = payload.rules;
    monitoring.data_retention = payload.data_retention;
    config.monitoring = Some(monitoring.clone());

    let mut server_config = config.get_server();
    server_config.cors_allowed_origins = payload.cors_allowed_origins;
    config.server = Some(server_config);

    // Writes atomically and keeps a bounded set of timestamped backups as a
    // manual undo path — see `config_file`
    if let Err(e) = config_file::write(&config) {
        return Ok(HttpResponse::InternalServerError()
            .json(&ErrorResponse { error: e.to_string() }));
    }

    // The live-reloadable subset takes effect immediately; everything else
    // needs a restart (the settings UI must say so — this response doesn't
    // repeat itself here, see SETTINGS_LIVE_FIELDS via GET)
    *app_state.live_settings.write().await = LiveSettings::from_config(&monitoring);

    tracing::info!("Settings saved via PUT /api/v1/settings");
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "status": "ok" })))
}

/// Turns the access without SSH off, permanently, from the panel.
///
/// The rest of `remote_access` is deliberately absent from the settings API:
/// a panel-password holder must not be able to *widen* what the agent exposes.
/// This is the one direction that is always safe, so it gets its own endpoint
/// rather than a general read-write field — there is no way to spell "enable"
/// through it, which is what the first-run prompt in the panel needs and all
/// it needs.
///
/// Takes effect immediately as well as on disk: `AppState.remote_access` is
/// otherwise a startup snapshot, and a switch the user just pressed for
/// safety reasons should not wait for a restart.
async fn disable_full_access(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    let claims = match verify_auth(&req, &app_state.config.get_jwt_secret()) {
        Ok(claims) => claims,
        Err(_) => {
            return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
                error: "Invalid or missing token".to_string(),
            }));
        }
    };

    let _config_guard = app_state.config_write.lock().await;
    let mut config = match config_file::read() {
        Ok(c) => c,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: e.to_string() }));
        }
    };
    let mut remote = config.get_remote_access();
    remote.full_access = Some(false);
    config.remote_access = Some(remote);
    if let Err(e) = config_file::write(&config) {
        return Ok(HttpResponse::InternalServerError()
            .json(&ErrorResponse { error: e.to_string() }));
    }

    app_state.full_access_off.store(true, Ordering::Release);
    tracing::info!(
        "Access without SSH disabled from the panel by {}",
        claims.sub
    );
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "status": "ok" })))
}

/// Home-grid card order — split out from `SettingsPayload`/`PUT /settings`
/// deliberately: reordering cards by drag-and-drop happens far more often
/// than editing rules/CORS, and routing it through the full settings payload
/// would mean read-modify-write races against whatever the settings page has
/// open, risking clobbering an in-progress edit there. No restart-required
/// concept applies — this is never read by the backend, only stored for sync.
#[derive(Serialize, Deserialize)]
struct CardOrderPayload {
    card_order: Vec<String>,
}

async fn get_card_order(req: HttpRequest, app_state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }
    let file_config = match config_file::read() {
        Ok(c) => c,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: e.to_string() }));
        }
    };
    Ok(HttpResponse::Ok().json(&CardOrderPayload { card_order: file_config.get_server().card_order }))
}

async fn update_card_order(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
    payload: web::types::Json<CardOrderPayload>,
) -> Result<HttpResponse> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }
    let _config_guard = app_state.config_write.lock().await;

    let mut config = match config_file::read() {
        Ok(c) => c,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: e.to_string() }));
        }
    };
    let mut server_config = config.get_server();
    server_config.card_order = payload.into_inner().card_order;
    config.server = Some(server_config);

    if let Err(e) = config_file::write(&config) {
        return Ok(HttpResponse::InternalServerError()
            .json(&ErrorResponse { error: e.to_string() }));
    }
    Ok(HttpResponse::Ok().json(&serde_json::json!({ "status": "ok" })))
}

#[derive(Serialize)]
struct HistoryPoint {
    timestamp: String,
    cpu: f64,
    memory: f64,
    disk: f64,
    net_rx_speed: f64,
    net_tx_speed: f64,
    temperature: Option<f64>,
    diskio_read_speed: f64,
    diskio_write_speed: f64,
    battery_percent: Option<f64>,
}

/// Bucketed time series from system_metrics. `?minutes=` selects the window
/// (default 60, clamped to 5..=10080); rows are averaged into at most 300
/// buckets and network rates are derived from consecutive cumulative counters.
async fn get_metrics_history(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    if verify_read_auth(&req, &app_state).await.is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }

    let minutes: i64 = req
        .query_string()
        .split('&')
        .find_map(|kv| kv.strip_prefix("minutes="))
        .and_then(|v| v.parse().ok())
        .unwrap_or(60)
        .clamp(5, 7 * 24 * 60);

    const MAX_POINTS: i64 = 300;
    let bucket_secs = (minutes * 60 / MAX_POINTS).max(1);

    use sqlx::Row;
    let rows = sqlx::query(
        "SELECT cast(strftime('%s', timestamp) as integer) / ?1 AS bucket,                 min(timestamp) AS ts,                 avg(cpu_usage) AS cpu,                 avg(CASE WHEN memory_total > 0 THEN memory_used * 100.0 / memory_total END) AS mem,                 avg(CASE WHEN disk_total > 0 THEN disk_used * 100.0 / disk_total END) AS disk,                 avg(network_rx_bytes) AS rx,                 avg(network_tx_bytes) AS tx,                 avg(temperature) AS temp,                 avg(diskio_read_bytes) AS dio_r,                 avg(diskio_write_bytes) AS dio_w,                 avg(battery_percent) AS battery          FROM system_metrics          WHERE timestamp >= datetime('now', ?2)          GROUP BY bucket ORDER BY bucket",
    )
    .bind(bucket_secs)
    .bind(format!("-{minutes} minutes"))
    .fetch_all(&app_state.db)
    .await?;

    let mut points = Vec::with_capacity(rows.len());
    // (bucket, rx, tx, diskio_read, diskio_write)
    let mut prev: Option<(i64, f64, f64, f64, f64)> = None;
    for row in rows {
        let bucket: i64 = row.get("bucket");
        let rx: f64 = row.try_get("rx").unwrap_or(0.0);
        let tx: f64 = row.try_get("tx").unwrap_or(0.0);
        let dio_r: f64 = row.try_get("dio_r").unwrap_or(0.0);
        let dio_w: f64 = row.try_get("dio_w").unwrap_or(0.0);
        let (net_rx_speed, net_tx_speed, diskio_read_speed, diskio_write_speed) = match prev {
            Some((pb, prx, ptx, pdr, pdw)) if bucket > pb => {
                let dt = ((bucket - pb) * bucket_secs) as f64;
                (
                    ((rx - prx) / dt).max(0.0),
                    ((tx - ptx) / dt).max(0.0),
                    ((dio_r - pdr) / dt).max(0.0),
                    ((dio_w - pdw) / dt).max(0.0),
                )
            }
            _ => (0.0, 0.0, 0.0, 0.0),
        };
        prev = Some((bucket, rx, tx, dio_r, dio_w));
        points.push(HistoryPoint {
            timestamp: row.get("ts"),
            cpu: row.try_get("cpu").unwrap_or(0.0),
            memory: row.try_get("mem").unwrap_or(0.0),
            disk: row.try_get("disk").unwrap_or(0.0),
            net_rx_speed,
            net_tx_speed,
            temperature: row.try_get::<Option<f64>, _>("temp").ok().flatten(),
            diskio_read_speed,
            diskio_write_speed,
            battery_percent: row.try_get::<Option<f64>, _>("battery").ok().flatten(),
        });
    }

    Ok(HttpResponse::Ok().json(&points))
}

async fn get_velocity(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    // Verify JWT token
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }

    let server_name = app_state.config.get_server_name();

    match app_state
        .velocity_manager
        .read()
        .await
        .get_server_velocity(&server_name)
        .await
    {
        Ok(velocity_data) => {
            let network_totals = app_state
                .velocity_manager
                .read()
                .await
                .get_network_totals(&server_name)
                .await;

            let network_info = NetworkSpeedInfo::new(
                velocity_data.network_rx_speed,
                velocity_data.network_tx_speed,
                network_totals.map(|(rx, _)| rx),
                network_totals.map(|(_, tx)| tx),
            );

            let response = VelocityAnalysisResponse::new(
                network_info,
                velocity_data.cpu_usage_percent,
                app_state
                    .velocity_manager
                    .read()
                    .await
                    .is_ready(&server_name)
                    .await,
            );

            Ok(HttpResponse::Ok().json(&response))
        }
        Err(e) => Ok(HttpResponse::InternalServerError().json(&ErrorResponse {
            error: format!("Failed to get velocity data: {}", e),
        })),
    }
}

async fn get_velocity_history(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    // Verify JWT token
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }

    let query = web::types::Query::<serde_json::Value>::from_query(req.query_string())
        .unwrap_or_else(|_| web::types::Query(serde_json::Value::Object(serde_json::Map::new())));

    let limit = query
        .get("limit")
        .and_then(|v| v.as_u64())
        .map(|l| l as usize);

    match app_state
        .velocity_manager
        .read()
        .await
        .get_server_velocity_history(&app_state.config.get_server_name(), limit)
        .await
    {
        Ok(history) => Ok(HttpResponse::Ok().json(&history)),
        Err(e) => Ok(HttpResponse::InternalServerError().json(&ErrorResponse {
            error: format!("Failed to get velocity history: {}", e),
        })),
    }
}

async fn health_check() -> HttpResponse {
    HttpResponse::Ok().json(&serde_json::json!({
        "status": "healthy",
        "timestamp": chrono::Utc::now().to_rfc3339()
    }))
}

/// The idle-pause heartbeat: called from the endpoints the panel actually
/// polls while open (`/metrics`, `/status`), not every authenticated
/// request — a one-off `/capabilities`/`/settings` fetch shouldn't count as
/// "someone's actively watching."
async fn touch_viewer_heartbeat(app_state: &AppState) {
    *app_state.last_viewer_seen.write().await = chrono::Utc::now();
}

fn bearer_token(req: &HttpRequest) -> Result<&str> {
    let auth_header = req
        .headers()
        .get("Authorization")
        .ok_or_else(|| {
            MonitorError::Auth("Missing Authorization header".to_string())
        })?
        .to_str()
        .map_err(|_| {
            MonitorError::Auth("Invalid Authorization header".to_string())
        })?;

    if !auth_header.starts_with("Bearer ") {
        return Err(MonitorError::Auth(
            "Invalid Authorization format".to_string(),
        ));
    }

    Ok(&auth_header[7..])
}

pub(crate) fn verify_auth(req: &HttpRequest, jwt_secret: &str) -> Result<Claims> {
    auth::verify_token(bearer_token(req)?, jwt_secret)
}

async fn verify_read_auth(req: &HttpRequest, app_state: &AppState) -> Result<String> {
    let token = bearer_token(req)?;
    if let Ok(claims) = auth::verify_token(token, &app_state.config.get_jwt_secret()) {
        return Ok(claims.sub);
    }
    verify_watch_token(&app_state.db, token, chrono::Utc::now().timestamp()).await
}

async fn verify_watch_token(db: &SqlitePool, token: &str, now: i64) -> Result<String> {
    let token_hash = watch_token_hash(token);
    let subject = sqlx::query_scalar::<_, String>(
        "SELECT subject FROM watch_tokens WHERE token_hash = ? AND expires_at > ?",
    )
    .bind(token_hash)
    .bind(now)
    .fetch_optional(db)
    .await?
    .ok_or_else(|| MonitorError::Auth("Invalid or expired token".to_string()))?;
    Ok(subject)
}

fn format_bytes(bytes: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    let mut size = bytes as f64;
    let mut unit_index = 0;

    while size >= 1024.0 && unit_index < UNITS.len() - 1 {
        size /= 1024.0;
        unit_index += 1;
    }

    if unit_index == 0 {
        format!("{} {}", bytes, UNITS[unit_index])
    } else {
        format!("{:.1} {}", size, UNITS[unit_index])
    }
}

#[cfg(test)]
mod watch_token_tests {
    use super::*;
    use sqlx::sqlite::SqlitePoolOptions;

    async fn pool() -> SqlitePool {
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect("sqlite::memory:")
            .await
            .unwrap();
        sqlx::query(
            "CREATE TABLE watch_tokens (\
             subject TEXT NOT NULL, client_id TEXT NOT NULL, \
             token_hash TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL, \
             expires_at INTEGER NOT NULL, PRIMARY KEY(subject, client_id))",
        )
        .execute(&pool)
        .await
        .unwrap();
        pool
    }

    /// The published SHA-256 of `abc`, so the row below is seeded with a value
    /// this crate did not produce. Hashing the token through
    /// `watch_token_hash` on both sides would agree with itself whatever the
    /// encoding became, and an agent's `watch_tokens` rows outlive the build
    /// that wrote them: a change there invalidates every paired watch, silently.
    const TOKEN: &str = "abc";
    const TOKEN_HASH: &str =
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad";

    #[tokio::test]
    async fn watch_tokens_are_hashed_expiring_and_revocable() {
        let pool = pool().await;
        let token = TOKEN;
        assert_eq!(watch_token_hash(token), TOKEN_HASH);
        sqlx::query(
            "INSERT INTO watch_tokens(subject, client_id, token_hash, created_at, expires_at) \
             VALUES (?, ?, ?, ?, ?)",
        )
        .bind("admin")
        .bind("watch:one")
        .bind(TOKEN_HASH)
        .bind(10_i64)
        .bind(20_i64)
        .execute(&pool)
        .await
        .unwrap();

        assert_eq!(verify_watch_token(&pool, token, 19).await.unwrap(), "admin");
        assert!(verify_watch_token(&pool, token, 20).await.is_err());
        sqlx::query("DELETE FROM watch_tokens WHERE client_id = ?")
            .bind("watch:one")
            .execute(&pool)
            .await
            .unwrap();
        assert!(verify_watch_token(&pool, token, 19).await.is_err());
    }
}
