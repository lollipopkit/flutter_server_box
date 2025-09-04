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

    info!("Starting web server on {}", bind_addr);

    HttpServer::new(move || {
        App::new()
            .state(app_state.clone())
            .wrap(Logger::default())
            .service(
                web::scope("/api/v1")
                    .route("/login", web::post().to(login))
                    .route("/status", web::get().to(get_status))
                    .route("/metrics", web::get().to(get_metrics))
                    .route("/health", web::get().to(health_check))
                    .route("/velocity", web::get().to(get_velocity))
                    .route("/velocity/history", web::get().to(get_velocity_history)),
            )
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
    })
    .bind(&bind_addr)?
    .run()
    .await?;

    Ok(())
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

    match app_state
        .velocity_manager
        .read()
        .await
        .get_server_velocity("server", interval)
        .await
    {
        Ok(velocity_data) => {
            let network_totals = app_state
                .velocity_manager
                .read()
                .await
                .get_network_totals("server")
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
                    .is_ready("server")
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
        .get_server_velocity_history("server", limit)
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
