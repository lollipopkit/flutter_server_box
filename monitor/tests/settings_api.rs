//! `GET/PUT /api/v1/settings` end to end for `disk_counts_network` (#1669),
//! against the real route table and a real `config.toml`.
//!
//! The one property worth a test of its own: a PUT that does not name the
//! field — from a panel or app older than it — keeps what is stored rather
//! than switching it off.
//!
//! `config_file::CONFIG_PATH` is relative to the working directory, so this
//! file chdirs into a temp directory once (cargo gives each integration test
//! file its own process), as `push_api.rs` does.

mod common;

use std::path::PathBuf;
use std::sync::{Arc, Once, OnceLock};

use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use rustls::crypto::ring;
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use tokio::sync::{Mutex, MutexGuard};

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

async fn workspace() -> MutexGuard<'static, PathBuf> {
    static DIR: OnceLock<Mutex<PathBuf>> = OnceLock::new();
    let dir = DIR.get_or_init(|| {
        let dir = std::env::temp_dir().join(format!("sbm-settings-api-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
        Mutex::new(dir)
    });
    dir.lock().await
}

fn read_config() -> Config {
    toml::from_str(&std::fs::read_to_string("config.toml").unwrap()).unwrap()
}

async fn test_server() -> TestServer {
    ensure_crypto_provider();
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    common::seed_as_upgrade(&db, &config).await;
    let state = AppState::new(Arc::new(config), db);

    web_test::server(move || {
        let state = state.clone();
        async move {
            let limit = state.remote_access.exec.max_request_bytes;
            App::new().state(state).configure(configure_api(limit))
        }
    })
    .await
}

fn bearer() -> String {
    format!("Bearer {}", generate_token("admin", SECRET).unwrap())
}

async fn get(srv: &TestServer) -> Value {
    let resp = srv
        .get("/api/v1/settings")
        .header("Authorization", bearer())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);
    resp.json().await.unwrap()
}

async fn put(srv: &TestServer, body: Value) {
    let resp = srv
        .put("/api/v1/settings")
        .header("Authorization", bearer())
        .send_json(&body)
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);
}

/// What an editor sends back: the GET's fields, `live_fields` and the
/// defaults aside — and, as an older one, without the new field.
fn payload_from(view: &Value, disk_counts_network: Option<bool>) -> Value {
    let mut body = json!({
        "interval_seconds": view["interval_seconds"],
        "extended_interval_secs": view["extended_interval_secs"],
        "idle_pause_enabled": view["idle_pause_enabled"],
        "idle_pause_threshold_secs": view["idle_pause_threshold_secs"],
        "rules": view["rules"],
        "data_retention": view["data_retention"],
        "cors_allowed_origins": view["cors_allowed_origins"],
    });
    if let Some(counts) = disk_counts_network {
        body["disk_counts_network"] = counts.into();
    }
    body
}

#[ntex::test]
async fn the_network_disk_switch_is_live_and_kept_by_an_editor_that_never_saw_it() {
    let _dir = workspace().await;
    std::fs::write(
        "config.toml",
        "[server]\nhost = \"127.0.0.1\"\nport = 3770\n\n[monitoring]\ninterval_seconds = 60\n",
    )
    .unwrap();
    let srv = test_server().await;

    let view = get(&srv).await;
    assert_eq!(view["disk_counts_network"], json!(false));
    assert!(
        view["live_fields"]
            .as_array()
            .unwrap()
            .contains(&json!("disk_counts_network"))
    );

    put(&srv, payload_from(&view, Some(true))).await;
    assert!(read_config().get_monitoring().disk_counts_network);
    let view = get(&srv).await;
    assert_eq!(view["disk_counts_network"], json!(true), "applied without a restart");

    // An editor from before the field saves something else.
    put(&srv, payload_from(&view, None)).await;
    assert!(read_config().get_monitoring().disk_counts_network, "kept");
    assert_eq!(get(&srv).await["disk_counts_network"], json!(true));
}
