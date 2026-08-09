use crate::{
    core::config::Config,
    utils::error::Result,
    monitoring::monitoring::{LiveSettings, SystemMetrics},
    monitoring::velocity::{NetworkSpeedInfo, VelocityAnalysisResponse, VelocityManager},
};
use ntex::web::{self, App, HttpRequest, HttpResponse, HttpServer, middleware::Logger};
use ntex_files::Files;
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::info;

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
}

impl AppState {
    pub fn new(config: Arc<Config>, db: SqlitePool) -> Arc<Self> {
        let db_arc = Arc::new(db.clone());
        let velocity_manager = Arc::new(RwLock::new(VelocityManager::new(db_arc)));
        let live_settings = Arc::new(RwLock::new(LiveSettings::from_config(&config.get_monitoring())));
        Arc::new(Self {
            config,
            db,
            current_metrics: Arc::new(RwLock::new(None)),
            velocity_manager,
            live_settings,
            last_viewer_seen: Arc::new(RwLock::new(chrono::Utc::now())),
        })
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

    let server = HttpServer::new(async move || {
        let cors = crate::api::cors::Cors::new(app_state.config.get_server().cors_allowed_origins);

        App::new()
            .state(app_state.clone())
            .middleware(Logger::default())
            .middleware(cors)
            .service(
                web::scope("/api/v1")
                    .route("/login", web::post().to(login))
                    .route("/status", web::get().to(get_status))
                    .route("/metrics", web::get().to(get_metrics))
                    .route("/capabilities", web::get().to(get_capabilities))
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
    match std::fs::read_to_string("frontend/dist/index.html") {
        Ok(content) => HttpResponse::Ok()
            .content_type("text/html; charset=utf-8")
            .body(content),
        Err(_) => HttpResponse::InternalServerError().json(&ErrorResponse {
            error: "Failed to load index.html".to_string(),
        }),
    }
}

async fn login(
    req: web::types::Json<LoginRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse> {
    // Verify user credentials
    let user = sqlx::query!(
        "SELECT id, username, password_hash FROM users WHERE username = ?",
        req.username
    )
    .fetch_optional(&app_state.db)
    .await?;

    if let Some(user) = user
        && crate::api::auth::verify_password(&req.password, &user.password_hash)?
    {
        // Update last login
        sqlx::query!(
            "UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?",
            user.id
        )
        .execute(&app_state.db)
        .await?;

        // Generate JWT token
        let token = crate::api::auth::generate_token(&user.username, &app_state.config.get_jwt_secret())?;

        return Ok(HttpResponse::Ok().json(&LoginResponse { token }));
    }

    Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
        error: "Invalid credentials".to_string(),
    }))
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
    use crate::monitoring::size::Size;
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
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
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
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
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
    capabilities: sbm_parser::capabilities::Capabilities,
    platform: sbm_parser::SystemType,
}

async fn get_capabilities(req: HttpRequest, app_state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }
    let platform = crate::monitoring::monitoring::system_type();
    let capabilities = crate::monitoring::monitoring::effective_capabilities(platform);
    Ok(HttpResponse::Ok().json(&CapabilitiesView { capabilities, platform }))
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

/// Reads `config.toml` fresh off disk rather than `app_state.config` —
/// after a `PUT` the file is updated immediately but `app_state.config`
/// (an `Arc<Config>`, not `Arc<RwLock<Config>>`) intentionally stays the
/// pre-restart snapshot for the non-live fields, so reading from it here
/// would show stale values right after a successful save.
fn read_config_file() -> Result<crate::core::config::Config> {
    let content = std::fs::read_to_string("config.toml")
        .map_err(crate::utils::error::MonitorError::Io)?;
    toml::from_str(&content)
        .map_err(|e| crate::utils::error::MonitorError::Config(anyhow::anyhow!(e)))
}

async fn get_settings(req: HttpRequest, app_state: web::types::State<Arc<AppState>>) -> Result<HttpResponse> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().json(&ErrorResponse {
            error: "Invalid or missing token".to_string(),
        }));
    }

    let file_config = match read_config_file() {
        Ok(c) => c,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: format!("Failed to read config.toml: {e}") }));
        }
    };
    let monitoring = file_config.get_monitoring();
    let live = app_state.live_settings.read().await.clone();

    Ok(HttpResponse::Ok().json(&SettingsView {
        settings: SettingsPayload {
            interval_seconds: monitoring.interval_seconds,
            extended_interval_secs: monitoring.extended_interval_secs,
            idle_pause_enabled: live.idle_pause_enabled,
            idle_pause_threshold_secs: monitoring.idle_pause_threshold_secs,
            rules: monitoring.rules,
            data_retention: monitoring.data_retention,
            cors_allowed_origins: file_config.get_server().cors_allowed_origins,
        },
        live_fields: SETTINGS_LIVE_FIELDS,
    }))
}

/// Same shape `config_manager.rs::validate_threshold_format` uses — not
/// reusing that struct wholesale (it's file-JSON-versioned, dead code
/// predating the config.toml migration; see the settings-page plan)
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

    let mut config = match read_config_file() {
        Ok(c) => c,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: format!("Failed to read config.toml: {e}") }));
        }
    };

    let mut monitoring = config.get_monitoring();
    monitoring.interval_seconds = payload.interval_seconds;
    monitoring.extended_interval_secs = payload.extended_interval_secs;
    monitoring.idle_pause_enabled = payload.idle_pause_enabled;
    monitoring.idle_pause_threshold_secs = payload.idle_pause_threshold_secs;
    monitoring.rules = payload.rules;
    monitoring.data_retention = payload.data_retention;
    config.monitoring = Some(monitoring.clone());

    let mut server_config = config.get_server();
    server_config.cors_allowed_origins = payload.cors_allowed_origins;
    config.server = Some(server_config);

    // Backup before overwriting — a timestamped copy, not the version-chain
    // ConfigManager builds (that's dead code, see the settings-page plan);
    // this is just a manual undo path, not meant to be browsable
    if let Ok(existing) = std::fs::read_to_string("config.toml") {
        let backup_path = format!("config.toml.bak-{}", chrono::Utc::now().timestamp());
        if let Err(e) = std::fs::write(&backup_path, existing) {
            tracing::warn!("Failed to back up config.toml before saving settings: {e}");
        }
    }

    let toml_content = match toml::to_string_pretty(&config) {
        Ok(s) => s,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: format!("Failed to serialize config: {e}") }));
        }
    };
    if let Err(e) = std::fs::write("config.toml", toml_content) {
        return Ok(HttpResponse::InternalServerError()
            .json(&ErrorResponse { error: format!("Failed to write config.toml: {e}") }));
    }

    // The live-reloadable subset takes effect immediately; everything else
    // needs a restart (the settings UI must say so — this response doesn't
    // repeat itself here, see SETTINGS_LIVE_FIELDS via GET)
    *app_state.live_settings.write().await = crate::monitoring::monitoring::LiveSettings::from_config(&monitoring);

    tracing::info!("Settings saved via PUT /api/v1/settings");
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
    let file_config = match read_config_file() {
        Ok(c) => c,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: format!("Failed to read config.toml: {e}") }));
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
    let mut config = match read_config_file() {
        Ok(c) => c,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: format!("Failed to read config.toml: {e}") }));
        }
    };
    let mut server_config = config.get_server();
    server_config.card_order = payload.into_inner().card_order;
    config.server = Some(server_config);

    let toml_content = match toml::to_string_pretty(&config) {
        Ok(s) => s,
        Err(e) => {
            return Ok(HttpResponse::InternalServerError()
                .json(&ErrorResponse { error: format!("Failed to serialize config: {e}") }));
        }
    };
    if let Err(e) = std::fs::write("config.toml", toml_content) {
        return Ok(HttpResponse::InternalServerError()
            .json(&ErrorResponse { error: format!("Failed to write config.toml: {e}") }));
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
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
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

    let query = web::types::Query::<serde_json::Value>::from_query(&req.query_string())
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

fn verify_auth(req: &HttpRequest, jwt_secret: &str) -> Result<crate::api::auth::Claims> {
    let auth_header = req
        .headers()
        .get("Authorization")
        .ok_or_else(|| {
            crate::utils::error::MonitorError::Auth("Missing Authorization header".to_string())
        })?
        .to_str()
        .map_err(|_| {
            crate::utils::error::MonitorError::Auth("Invalid Authorization header".to_string())
        })?;

    if !auth_header.starts_with("Bearer ") {
        return Err(crate::utils::error::MonitorError::Auth(
            "Invalid Authorization format".to_string(),
        ));
    }

    let token = &auth_header[7..];
    crate::api::auth::verify_token(token, jwt_secret)
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
