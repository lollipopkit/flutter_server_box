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

mod common;

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
/// Out of the crate's directory, once, before any server starts.
///
/// The panel-login half below sends every write route a valid login, and three
/// of them — settings, the card order, turning full access off — rewrite
/// `config.toml` in the working directory. `cargo test` runs from the crate,
/// whose `config.toml` is a developer's own: running this file cleared its
/// alert rules and switched its full access off. With no `config.toml` here
/// those routes fail reading it, which is still not a 401.
fn leave_the_crate() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let dir = std::env::temp_dir().join(format!(
            "sbm-watch-token-scope-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
    });
}

async fn permissive_state() -> Arc<AppState> {
    leave_the_crate();
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    remote.terminal.enabled = Some(true);
    remote.full_access = Some(true);
    remote.fs.enabled = Some(true);
    remote.fs.roots = vec![
        std::fs::canonicalize(std::env::current_dir().unwrap())
            .unwrap()
            .to_string_lossy()
            .into_owned(),
    ];
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    common::seed_as_upgrade(&db, &config).await;
    AppState::new(Arc::new(config), db)
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
        // The relay, which is the other endpoint a ticket authorises. Its
        // upgrade takes no bearer token either, so this is the HTTP half: a
        // watch token must not be able to mint a ticket for it.
        (
            Method::POST,
            "/api/v1/ws-ticket",
            Some(json!({ "purpose": "stream" })),
        ),
        (
            Method::POST,
            "/api/v1/exec",
            Some(json!({ "cmd": "echo scoped" })),
        ),
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
        (Method::GET, "/api/v1/push", None),
        // Both bodies name a channel type this agent has no sender for, so the
        // panel-login half of this test stops at validation. Auth is checked
        // before that, so these still prove the gate; a body that passed
        // validation would rewrite the config.toml the test runs next to, and
        // a test send would really make a request to wherever it pointed.
        (
            Method::PUT,
            "/api/v1/push",
            Some(json!({
                "pushes": [{ "name": "scope", "push_type": "telegram", "config": {} }],
            })),
        ),
        (
            Method::POST,
            "/api/v1/push/test",
            Some(json!({
                "push": { "name": "scope", "push_type": "telegram", "config": {} },
            })),
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
        (
            Method::PUT,
            "/api/v1/card-order",
            Some(json!({ "card_order": [] })),
        ),
        // Accounts and roles. The panel-login half sends a wrong
        // `current_password` to every one that would change something, so
        // they stop at re-authentication — which is still not a 401.
        (Method::GET, "/api/v1/me", None),
        (
            Method::PUT,
            "/api/v1/me/password",
            Some(json!({ "current_password": "nope", "new_password": "new-password" })),
        ),
        (Method::GET, "/api/v1/users", None),
        (
            Method::POST,
            "/api/v1/users",
            Some(json!({ "username": "x", "password": "password-x", "role": "viewer", "current_password": "nope" })),
        ),
        (
            Method::PUT,
            "/api/v1/users/intruder",
            Some(json!({ "role": "viewer", "current_password": "nope" })),
        ),
        (
            Method::DELETE,
            "/api/v1/users/intruder",
            Some(json!({ "current_password": "nope" })),
        ),
        (Method::GET, "/api/v1/roles", None),
        (
            Method::POST,
            "/api/v1/roles",
            Some(json!({ "role": { "name": "x", "grants": {} }, "current_password": "nope" })),
        ),
        (
            Method::PUT,
            "/api/v1/roles/viewer",
            Some(json!({ "role": { "name": "viewer", "grants": {} }, "current_password": "nope" })),
        ),
        (
            Method::DELETE,
            "/api/v1/roles/viewer",
            Some(json!({ "current_password": "nope" })),
        ),
        // The machine-management endpoints (#1623). Each request is one the
        // panel login can send harmlessly: a PID nothing holds, a unit no
        // machine has, a container no runtime has, a crontab line no crontab
        // holds, an account no machine has. `/power` is left out
        // for the same reason — every body it accepts takes the machine down
        // under the panel login, and one it does not accept is a 400 from the
        // extractor before the token is looked at.
        (Method::GET, "/api/v1/process", None),
        (
            Method::POST,
            "/api/v1/process",
            Some(json!({ "pid": 4_000_000_000i64, "start_id": "1", "signal": "kill" })),
        ),
        (Method::GET, "/api/v1/services", None),
        (
            Method::POST,
            "/api/v1/services",
            Some(json!({ "key": "system:definitely-not-a-unit.service", "action": "start" })),
        ),
        (Method::GET, "/api/v1/containers", None),
        (
            Method::POST,
            "/api/v1/containers",
            Some(json!({ "action": "stop", "id": "sbm-scope-test-nonexistent" })),
        ),
        (Method::GET, "/api/v1/benchmark", None),
        (
            Method::POST,
            "/api/v1/benchmark",
            Some(json!({ "action": "estimate" })),
        ),
        (Method::DELETE, "/api/v1/benchmark?run=bench_scope_test", None),
        (Method::GET, "/api/v1/cron", None),
        (
            Method::PUT,
            "/api/v1/cron",
            Some(json!({ "op": "remove", "line_index": 4_294_967_295u32 })),
        ),
        (Method::GET, "/api/v1/system-users", None),
        (
            Method::POST,
            "/api/v1/system-users",
            Some(json!({ "action": "delete", "name": "sbm-scope-test-nonexistent" })),
        ),
        (Method::GET, "/api/v1/snippets", None),
        (Method::PUT, "/api/v1/snippets", Some(json!({ "snippets": [] }))),
        (Method::POST, "/api/v1/snippets/plan", Some(json!({ "script": "ls" }))),
        (Method::GET, "/api/v1/desktops", None),
        (Method::PUT, "/api/v1/desktops", Some(json!({ "desktops": [] }))),
        (Method::GET, "/api/v1/backup", None),
        (Method::GET, "/api/v1/backup/blob?name=absent", None),
        (Method::DELETE, "/api/v1/backup/blob?name=absent", None),
        (Method::GET, "/api/v1/bmc", None),
        (Method::GET, "/api/v1/bmc/absent", None),
        (Method::POST, "/api/v1/virt", Some(json!({}))),
        (Method::POST, "/api/v1/virt/power", Some(json!({ "guest": "absent", "action": "start" }))),
        (Method::GET, "/api/v1/virt/pve", None),
        (Method::POST, "/api/v1/virt/pve/tfa", Some(json!({ "code": "000000" }))),
        (Method::POST, "/api/v1/virt/storage", Some(json!({}))),
        (Method::POST, "/api/v1/virt/volumes", Some(json!({ "pool": "absent" }))),
        (Method::POST, "/api/v1/virt/networks", Some(json!({}))),
        (Method::POST, "/api/v1/virt/manage", Some(json!({ "change": { "op": "pool_refresh", "pool": "absent" } }))),
        (Method::POST, "/api/v1/virt/create/form", Some(json!({ "kind": "qemu" }))),
        (
            Method::POST,
            "/api/v1/virt/create",
            Some(json!({ "spec": { "kind": "qemu", "name": "x", "cores": 1, "memory_mib": 512, "storage": "absent", "disk_gib": 1 } })),
        ),
        (Method::POST, "/api/v1/virt/delete", Some(json!({ "guest": "absent" }))),
        (Method::POST, "/api/v1/virt/clone/form", Some(json!({ "guest": "absent" }))),
        (Method::POST, "/api/v1/virt/clone", Some(json!({ "guest": "absent", "request": { "name": "x" } }))),
        (Method::POST, "/api/v1/virt/template", Some(json!({ "guest": "absent" }))),
        (Method::POST, "/api/v1/virt/hardware", Some(json!({ "guest": "absent" }))),
        (
            Method::POST,
            "/api/v1/virt/hardware/change",
            Some(json!({ "guest": "absent", "change": { "op": "set_autostart", "on": true } })),
        ),
        (Method::POST, "/api/v1/virt/hardware/revert", Some(json!({ "guest": "absent" }))),
        (Method::POST, "/api/v1/virt/cloud-init", Some(json!({ "guest": "absent" }))),
        (
            Method::POST,
            "/api/v1/virt/cloud-init/set",
            Some(json!({ "guest": "absent", "edit": { "values": { "user": "x" }, "revision": "" } })),
        ),
        (Method::POST, "/api/v1/virt/host-devices", Some(json!({ "guest": "absent" }))),
    ]
}

#[ntex::test]
async fn a_watch_token_reads_metrics_and_nothing_else() {
    let srv = test_server(permissive_state().await).await;
    let token = issue_watch_token(&srv).await;

    // The read routes it is for. Asserted as "not a refusal" rather than as
    // 200: what these answer with is the monitoring loop's business and a
    // test server has never sampled anything.
    for path in [
        "/api/v1/status",
        "/api/v1/metrics",
        "/api/v1/metrics/history?minutes=60",
        "/api/v1/capabilities",
        "/api/v1/card-order",
        "/api/v1/velocity",
        "/api/v1/velocity/history",
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
             outside the read endpoints must refuse one",
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

#[ntex::test]
async fn a_watch_tokens_capabilities_grant_nothing() {
    // The read routes answer it, and `/capabilities` is one of them: it must
    // say nothing is usable rather than describe the account that paired it.
    let srv = test_server(permissive_state().await).await;
    let token = issue_watch_token(&srv).await;
    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {token}"))
        .send()
        .await
        .unwrap();
    let body: serde_json::Value = resp.json().await.unwrap();
    assert!(body.get("me").is_none(), "{body}");
    for grant in ["shell", "ssh_terminal", "files", "connect", "listen"] {
        assert_eq!(body["grants"][grant]["ok"], false, "{grant}");
        assert_eq!(body["grants"][grant]["why"], "not_granted", "{grant}");
    }
    assert_eq!(body["remote_access"]["full_access"], false);
}
