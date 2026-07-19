use crate::{
    core::config::Config,
    utils::error::Result,
    monitoring::monitoring::SystemMetrics,
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
}

impl AppState {
    pub fn new(config: Arc<Config>, db: SqlitePool) -> Arc<Self> {
        let db_arc = Arc::new(db.clone());
        let velocity_manager = Arc::new(RwLock::new(VelocityManager::new(db_arc)));
        Arc::new(Self {
            config,
            db,
            current_metrics: Arc::new(RwLock::new(None)),
            velocity_manager,
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

    let metrics = app_state.current_metrics.read().await;

    if let Some(ref metrics) = *metrics {
        Ok(HttpResponse::Ok().json(metrics))
    } else {
        Ok(HttpResponse::ServiceUnavailable().json(&ErrorResponse {
            error: "Metrics not available yet".to_string(),
        }))
    }
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
}

/// Bucketed time series from system_metrics. `?minutes=` selects the window
/// (default 60, clamped to 5..=10080); rows are averaged into ~300 buckets and
/// network rates are derived from consecutive cumulative counters.
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

    const TARGET_POINTS: i64 = 300;
    let bucket_secs = (minutes * 60 / TARGET_POINTS).max(1);

    use sqlx::Row;
    let rows = sqlx::query(
        "SELECT cast(strftime('%s', timestamp) as integer) / ?1 AS bucket,                 min(timestamp) AS ts,                 avg(cpu_usage) AS cpu,                 avg(CASE WHEN memory_total > 0 THEN memory_used * 100.0 / memory_total END) AS mem,                 avg(CASE WHEN disk_total > 0 THEN disk_used * 100.0 / disk_total END) AS disk,                 avg(network_rx_bytes) AS rx,                 avg(network_tx_bytes) AS tx,                 avg(temperature) AS temp          FROM system_metrics          WHERE timestamp >= datetime('now', ?2)          GROUP BY bucket ORDER BY bucket",
    )
    .bind(bucket_secs)
    .bind(format!("-{minutes} minutes"))
    .fetch_all(&app_state.db)
    .await?;

    let mut points = Vec::with_capacity(rows.len());
    let mut prev: Option<(i64, f64, f64)> = None; // (bucket, rx, tx)
    for row in rows {
        let bucket: i64 = row.get("bucket");
        let rx: f64 = row.try_get("rx").unwrap_or(0.0);
        let tx: f64 = row.try_get("tx").unwrap_or(0.0);
        let (net_rx_speed, net_tx_speed) = match prev {
            Some((pb, prx, ptx)) if bucket > pb => {
                let dt = ((bucket - pb) * bucket_secs) as f64;
                (((rx - prx) / dt).max(0.0), ((tx - ptx) / dt).max(0.0))
            }
            _ => (0.0, 0.0),
        };
        prev = Some((bucket, rx, tx));
        points.push(HistoryPoint {
            timestamp: row.get("ts"),
            cpu: row.try_get("cpu").unwrap_or(0.0),
            memory: row.try_get("mem").unwrap_or(0.0),
            disk: row.try_get("disk").unwrap_or(0.0),
            net_rx_speed,
            net_tx_speed,
            temperature: row.try_get::<Option<f64>, _>("temp").ok().flatten(),
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

    let interval = app_state.config.get_monitoring().interval_seconds as f64;
    let server_name = app_state.config.get_server_name();

    match app_state
        .velocity_manager
        .read()
        .await
        .get_server_velocity(&server_name, interval)
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
