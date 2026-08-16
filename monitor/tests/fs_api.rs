//! `GET /api/v1/fs/roots` — the only fs endpoint that answers about the
//! confinement itself rather than about a path inside it.
//!
//! Worth its own coverage because it is the one place the roots are handed out
//! deliberately. Everything that keeps a *request* inside them is `FsRoots`'
//! job and is tested directly in `fs_roots.rs`.

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

/// [`roots`] empty is how "the file API is off" is configured: `fs_available`
/// is `enabled && !roots.is_empty()`.
async fn app_state(enabled: bool, roots: &[&str]) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config::default();
    config.jwt_secret = Some(SECRET.to_string());
    let mut remote = config.get_remote_access();
    remote.fs.enabled = enabled;
    remote.fs.roots = roots.iter().map(|r| r.to_string()).collect();
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
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
    generate_token("admin", SECRET).unwrap()
}

fn existing_root() -> String {
    fs::canonicalize(std::env::current_dir().unwrap())
        .unwrap()
        .to_string_lossy()
        .into_owned()
}

fn canonical(path: &str) -> std::path::PathBuf {
    fs::canonicalize(Path::new(path)).unwrap()
}

#[ntex::test]
async fn the_configured_roots_come_back() {
    let dir = tempfile::tempdir().unwrap();
    let first = dir.path().join("first");
    let second = dir.path().join("second");
    fs::create_dir(&first).unwrap();
    fs::create_dir(&second).unwrap();
    let first = first.to_string_lossy().into_owned();
    let second = second.to_string_lossy().into_owned();
    let srv = test_server(app_state(true, &[&first, &second]).await).await;
    let body = get_roots(&srv, Some(&token())).await.unwrap();

    let roots = body["roots"].as_array().expect("roots is an array");
    let got: Vec<&str> = roots.iter().map(|r| r.as_str().unwrap()).collect();
    assert!(got.iter().all(|root| !root.contains('\\')), "got {got:?}");
    let mut got: Vec<_> = got.iter().map(|root| canonical(root)).collect();
    got.sort_unstable();
    let mut expected = vec![canonical(&first), canonical(&second)];
    expected.sort_unstable();
    assert_eq!(got.len(), 2, "got {got:?}");
    assert_eq!(got, expected);
}

/// The same 401 every other fs handler gives: this one says where the agent
/// will let a caller go, which is not something an unauthenticated one may ask.
#[ntex::test]
async fn an_unauthenticated_caller_is_refused() {
    let root = existing_root();
    let srv = test_server(app_state(true, &[&root]).await).await;
    assert_eq!(get_roots(&srv, None).await.unwrap_err(), 401);
}

/// Switched off is switched off: it must not answer with an empty list, which
/// a client would read as "no limit" rather than as "not serving files".
#[ntex::test]
async fn a_disabled_file_api_refuses_rather_than_answering_empty() {
    let root = existing_root();
    let srv = test_server(app_state(false, &[&root]).await).await;
    assert_eq!(get_roots(&srv, Some(&token())).await.unwrap_err(), 403);
}

/// Enabled with nothing named is the same as off — `fs_available()` is what
/// both mean, and the agent warns about this combination at startup.
#[ntex::test]
async fn enabled_with_no_roots_is_refused_too() {
    let srv = test_server(app_state(true, &[]).await).await;
    assert_eq!(get_roots(&srv, Some(&token())).await.unwrap_err(), 403);
}
