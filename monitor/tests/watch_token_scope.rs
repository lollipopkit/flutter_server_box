//! What a watch token can reach, asserted against the real route table.
//!
//! A watch token is the credential the phone hands to a second device — an
//! Apple Watch, and now a home-screen widget — so that it can draw a server's
//! numbers without carrying the panel login. It is meant to be *read-only*,
//! and nothing in the token says so: `watch_tokens` has no scope column, and
//! `verify_watch_token` answers with the subject exactly like a JWT would.
//!
//! What makes it read-only is which gate each route sits behind.
//! `require_read_access!` accepts a watch token, `require_jwt!` does not, and
//! the choice is made once per route in [`configure_api`]. So a new write
//! endpoint copy-pasted from `get_metrics` — bringing its `require_read_access!`
//! along — would hand every paired watch the ability to use it, and nothing
//! would fail. This file is that missing failure.
//!
//! It mounts [`configure_api`] rather than a scope of its own, which is the
//! whole point: a hand-built router would assert something about a handler and
//! nothing about what the shipped binary exposes.
//!
//! The agent is configured as permissively as it can be — full access on, the
//! file API on with a real root, the terminal on — so that a refusal cannot
//! come from a grant being switched off. With every door unlocked, 401 is the
//! only thing left that can be doing the refusing.

use std::sync::{Arc, Once};

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::App;
use rustls::crypto::ring;
use serde_json::json;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
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

/// Every grant this agent has, switched on.
///
/// Deliberately the opposite of what the other API tests do. They check that a
/// switched-off grant refuses; this one needs every grant *on*, so that a 401
/// cannot be a 403 wearing a different number.
async fn permissive_state() -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    remote.terminal.enabled = true;
    remote.full_access = Some(true);
    remote.fs.enabled = true;
    remote.fs.roots = vec![
        std::fs::canonicalize(std::env::current_dir().unwrap())
            .unwrap()
            .to_string_lossy()
            .into_owned(),
    ];
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    AppState::new(Arc::new(config), db)
}

async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move { App::new().state(state).configure(configure_api) }
    })
    .await
}

fn jwt() -> String {
    generate_token("admin", SECRET).unwrap()
}

/// A real watch token, minted through the endpoint that mints them.
///
/// Not inserted into `watch_tokens` by hand: the hash the row holds is
/// `watch_token_hash`'s business, and a test that wrote its own would still
/// pass if the two ever disagreed.
async fn issue_watch_token(srv: &TestServer) -> String {
    let resp = srv
        .post("/api/v1/watch-token")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({ "client_id": "widget:test" }))
        .await
        .unwrap();
    assert!(resp.status().is_success(), "minting the token itself failed");
    let body: serde_json::Value = resp.json().await.unwrap();
    body["token"].as_str().unwrap().to_string()
}

/// One request, and the status it came back with.
async fn status_with(
    srv: &TestServer,
    token: &str,
    method: Method,
    path: &str,
    body: Option<serde_json::Value>,
) -> u16 {
    let req = srv
        .request(method, srv.url(path))
        .header("Authorization", format!("Bearer {token}"));
    let resp = match body {
        Some(body) => req.send_json(&body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    resp.status().as_u16()
}

/// Every route a watch token must not reach, with a body that deserializes.
///
/// The body matters more than it looks: ntex runs the `Json` extractor
/// *before* the handler, so a request with a missing or malformed body is a
/// 400 that never reaches the auth check at all. Asserting "not 2xx" would
/// have passed on those for entirely the wrong reason, which is why every
/// assertion below is on 401 exactly.
fn forbidden_routes() -> Vec<(Method, &'static str, Option<serde_json::Value>)> {
    vec![
        // A watch token must not be able to mint another one, or to revoke
        // the sibling credential belonging to a different device.
        (
            Method::POST,
            "/api/v1/watch-token",
            Some(json!({ "client_id": "widget:escalated" })),
        ),
        (
            Method::DELETE,
            "/api/v1/watch-token",
            Some(json!({ "client_id": "widget:test" })),
        ),
        // The gateway to the terminal. `GET /terminal/ws` takes no bearer
        // token at all — it is admitted by a single-use ticket — so refusing
        // to mint the ticket is what keeps a watch token away from a shell.
        (
            Method::POST,
            "/api/v1/ws-ticket",
            Some(json!({ "purpose": "terminal" })),
        ),
        (
            Method::POST,
            "/api/v1/exec",
            Some(json!({ "cmd": "echo scoped" })),
        ),
        (Method::GET, "/api/v1/capabilities", None),
        (Method::GET, "/api/v1/fs/roots", None),
        (Method::GET, "/api/v1/fs/list?path=/", None),
        (Method::GET, "/api/v1/fs/stat?path=/", None),
        (Method::GET, "/api/v1/fs/read?path=/etc/hostname", None),
        (Method::PUT, "/api/v1/fs/write?path=/tmp/sbm-scope-test", None),
        (
            Method::POST,
            "/api/v1/fs/mkdir",
            Some(json!({ "path": "/tmp/sbm-scope-test-dir" })),
        ),
        (
            Method::POST,
            "/api/v1/fs/rename",
            Some(json!({ "from": "/tmp/a", "to": "/tmp/b" })),
        ),
        (
            Method::POST,
            "/api/v1/fs/chmod",
            Some(json!({ "path": "/tmp/a", "mode": 493 })),
        ),
        (
            Method::DELETE,
            "/api/v1/fs/remove",
            Some(json!({ "path": "/tmp/a", "recursive": false })),
        ),
        (Method::DELETE, "/api/v1/remote-access/full-access", None),
        (Method::GET, "/api/v1/custom-cmds", None),
        (
            Method::PUT,
            "/api/v1/custom-cmds",
            Some(json!({ "commands": [] })),
        ),
        (Method::GET, "/api/v1/settings", None),
        (
            Method::PUT,
            "/api/v1/settings",
            Some(json!({
                "interval_seconds": 60,
                "idle_pause_enabled": false,
                "rules": [],
                "cors_allowed_origins": [],
            })),
        ),
        (Method::GET, "/api/v1/card-order", None),
        (
            Method::PUT,
            "/api/v1/card-order",
            Some(json!({ "card_order": [] })),
        ),
        (Method::GET, "/api/v1/velocity", None),
        (Method::GET, "/api/v1/velocity/history", None),
    ]
}

#[ntex::test]
async fn a_watch_token_reads_metrics_and_nothing_else() {
    let srv = test_server(permissive_state().await).await;
    let token = issue_watch_token(&srv).await;

    // The three it is for. Asserted as "not a refusal" rather than as 200:
    // what these answer with is the monitoring loop's business and a test
    // server has never sampled anything.
    for path in [
        "/api/v1/status",
        "/api/v1/metrics",
        "/api/v1/metrics/history?minutes=60",
    ] {
        let status = status_with(&srv, &token, Method::GET, path, None).await;
        assert_ne!(status, 401, "{path} should accept a watch token");
        assert_ne!(status, 403, "{path} should accept a watch token");
    }

    for (method, path, body) in forbidden_routes() {
        let status = status_with(&srv, &token, method.clone(), path, body).await;
        assert_eq!(
            status, 401,
            "{method} {path} answered {status} to a watch token; every route \
             outside the three read endpoints must sit behind require_jwt!",
        );
    }
}

#[ntex::test]
async fn the_same_routes_are_reachable_with_the_panel_login() {
    // Without this the test above could pass because the routes are broken
    // rather than because they are guarded — a typo in a path answers 404 to
    // every caller, and 404 is not 401, so it would have been caught; but a
    // route that refuses *everyone* would not be.
    let srv = test_server(permissive_state().await).await;
    let jwt = jwt();

    for (method, path, body) in forbidden_routes() {
        let status = status_with(&srv, &jwt, method.clone(), path, body).await;
        assert_ne!(
            status, 401,
            "{method} {path} refused the panel login, so its 401 above proves \
             nothing about the watch token",
        );
    }
}

#[ntex::test]
async fn a_revoked_token_stops_reading() {
    let srv = test_server(permissive_state().await).await;
    let token = issue_watch_token(&srv).await;

    assert_ne!(
        status_with(&srv, &token, Method::GET, "/api/v1/metrics", None).await,
        401,
    );

    let resp = srv
        .delete("/api/v1/watch-token")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({ "client_id": "widget:test" }))
        .await
        .unwrap();
    assert!(resp.status().is_success());

    assert_eq!(
        status_with(&srv, &token, Method::GET, "/api/v1/metrics", None).await,
        401,
        "a revoked watch token kept working",
    );
}
