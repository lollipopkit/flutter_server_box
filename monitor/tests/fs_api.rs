//! `GET /api/v1/fs/roots` — where a file browser starts: the account's home,
//! then the filesystem's roots. What keeps a *request* away from the agent's
//! own state is `FsRoots`' job and is tested directly in `fs_roots.rs`.

mod common;

use std::sync::{Arc, Once};
use std::{fs, path::Path};

use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use rustls::crypto::ring;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// The test client speaks TLS whether or not this server does, and rustls
/// refuses to pick a provider for itself.
fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

async fn app_state() -> Arc<AppState> {
    ensure_crypto_provider();
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    common::add_owner(&db).await;
    AppState::new(Arc::new(config), db)
}

async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .route("/fs/roots", web::get().to(server_box_monitor::api::fs::roots)),
            )
        }
    })
    .await
}

/// The body, or the status when the call was refused.
async fn get_roots(srv: &TestServer, token: Option<&str>) -> Result<serde_json::Value, u16> {
    let mut req = srv.get("/api/v1/fs/roots");
    if let Some(token) = token {
        req = req.header("Authorization", format!("Bearer {token}"));
    }
    let resp = req.send().await.unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

fn token() -> String {
    generate_token(SECRET).unwrap()
}

#[ntex::test]
async fn home_then_the_filesystem_roots_come_back() {
    let srv = test_server(app_state().await).await;
    let body = get_roots(&srv, Some(&token())).await.unwrap();
    let roots: Vec<String> = body["roots"]
        .as_array()
        .expect("roots is an array")
        .iter()
        .map(|r| r.as_str().unwrap().to_string())
        .collect();
    let home = std::env::var_os("HOME").or_else(|| std::env::var_os("USERPROFILE")).unwrap();
    let home = fs::canonicalize(Path::new(&home)).unwrap();
    assert_eq!(fs::canonicalize(&roots[0]).unwrap(), home, "{roots:?}");
    #[cfg(not(windows))]
    assert_eq!(roots[1..], ["/".to_string()]);
    #[cfg(windows)]
    assert!(roots.len() > 1, "{roots:?}");
}

#[ntex::test]
async fn the_roots_need_a_token() {
    let srv = test_server(app_state().await).await;
    assert_eq!(get_roots(&srv, None).await.unwrap_err(), 401);
}
