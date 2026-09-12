//! `GET /api/v1/velocity` against the monitoring loop's writer.
//!
//! The handler needs three things out of the velocity manager, and used to take
//! the lock once per thing. A temporary in a `match` scrutinee lives to the end
//! of the whole `match`, so the first guard was still held while the second was
//! asked for — and tokio's `RwLock` is fair, so a writer that queued in between
//! blocked that second reader while itself waiting on the first guard. Neither
//! side could finish.
//!
//! The writer is the monitoring loop (`monitoring.rs`, once per cycle), so the
//! cost was not one failed request: the loop never took its lock again, and
//! with it went metric collection, rule evaluation and every push, until
//! someone restarted the agent. The panel polls this endpoint while it is open,
//! which is what made it reachable at all.
//!
//! This is a stress test rather than a construction — the window is real
//! parallelism between two threads, not a scheduler point that can be steered
//! from here. Verified to hang the old handler well inside the iteration count
//! below.

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use ntex::time::timeout;
use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use rustls::crypto::ring;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use std::sync::Once;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// The test client speaks TLS whether or not this server does, and rustls
/// refuses to pick a provider for itself.
fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

async fn state() -> Arc<AppState> {
    ensure_crypto_provider();
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();

    let state = AppState::new(Arc::new(config), db);

    // One sample, so the handler goes through the per-server processor rather
    // than the "server unknown" early return — that path holds the outer guard
    // across an inner lock, which is where the window actually is.
    let server_name = state.config.get_server_name();
    state
        .velocity_manager
        .write()
        .await
        .update_server_metrics(&server_name, 0, 0, vec![], chrono::Utc::now())
        .await;

    state
}

async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            let limit = state.remote_access.exec.max_request_bytes;
            App::new().state(state).configure(configure_api(limit))
        }
    })
    .await
}

#[ntex::test]
async fn velocity_survives_a_concurrent_collection_cycle() {
    let state = state().await;
    let srv = test_server(state.clone()).await;
    let token = generate_token("admin", SECRET).unwrap();

    // Stands in for the monitoring loop, which takes this lock once per cycle.
    let stop = Arc::new(AtomicBool::new(false));
    let writer = {
        let state = state.clone();
        let stop = stop.clone();
        ntex::rt::spawn(async move {
            let server_name = state.config.get_server_name();
            let mut rx = 0u64;
            while !stop.load(Ordering::Relaxed) {
                rx += 1_000;
                state
                    .velocity_manager
                    .write()
                    .await
                    .update_server_metrics(&server_name, rx, rx, vec![], chrono::Utc::now())
                    .await;
            }
        })
    };

    let requests = async {
        for i in 0..200 {
            let resp = srv
                .get("/api/v1/velocity")
                .header("Authorization", format!("Bearer {token}"))
                .send()
                .await
                .unwrap_or_else(|e| {
                    panic!("request {i} never answered ({e}) — deadlocked against the writer")
                });
            assert!(resp.status().is_success(), "request {i}: {}", resp.status());
        }
    };

    let outcome = timeout(Duration::from_secs(30), requests).await;
    stop.store(true, Ordering::Relaxed);
    let _ = writer.await;

    assert!(
        outcome.is_ok(),
        "/velocity deadlocked against the collection cycle's writer"
    );
}
