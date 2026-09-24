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
//!
//! # Three things this file has to be careful about
//!
//! **It runs on a real machine, and some of these routes write.** Every entry
//! sends a body the handler *refuses*, so the panel-login half proves the gate
//! without changing anything; where no such body exists the route is left out
//! and the pair below is what covers it. Two entries in the list do write —
//! `PUT /card-order` and `DELETE /remote-access/full-access`, neither of which
//! has any refusal between the auth check and the file — and `workspace` chdirs
//! so that what they write is a temp directory rather than the operator's
//! `config.toml`. One endpoint writes somewhere the chdir cannot reach,
//! `~/.config/server_box/custom_cmds`, which is why its entry must never send
//! the empty list that would clear it.
//!
//! **A missing entry is a route nothing guards.** The list has to be kept in
//! step with `configure_api_inner` by hand, and it fell a long way behind: the
//! containers, PVE, benchmark, snippets, AI, desktop, users, services and
//! process endpoints all arrived without one. Nobody failing anything is what
//! that looks like.
//!
//! **Two routes answer a watch token and are not the file's subject.**
//! `POST /login` reads no bearer token at all — it is how one is obtained — and
//! `GET /health` takes no request and checks nothing. Neither can be in the
//! list: `/login`'s refusal is a 401, the same number the gate answers with, and
//! `/health` answers everyone. What the file is about is therefore the three
//! *read* endpoints of a paired device rather than "exactly three routes".
//!
//! **One route cannot be in the list at all.** `POST /power` validates nothing
//! after the auth check and every body it accepts runs a command, so
//! [`the_power_endpoint_is_refused_on_both_sides_of_its_gate`] covers it from
//! the other side of the grant instead — where the command is never reached.

use std::path::PathBuf;
use std::sync::{Arc, Once, OnceLock};

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

/// Moves the process into a directory of its own, once.
///
/// `config_file::CONFIG_PATH` is relative to the working directory, and cargo
/// runs an integration test with it set to the crate root — so without this,
/// the panel-login half of these tests really does rewrite
/// `monitor/config.toml`: `/settings`, `/card-order` and
/// `DELETE /remote-access/full-access` all pass validation and write. The last
/// of those persists `full_access = false` into the operator's file, and no
/// later run notices, because the state they assert against is built in memory.
///
/// Everything these endpoints write is then confined to a temp directory that
/// is thrown away. `~/.config/server_box/custom_cmds` is *not* — it is rooted at
/// `$HOME` — which is why the custom-command entry below sends a body the
/// handler refuses rather than an empty list, which it accepts by clearing the
/// directory.
///
/// No lock is taken: nothing here writes a file another test of this file reads
/// back, so ordering does not matter.
fn workspace() {
    static DIR: OnceLock<PathBuf> = OnceLock::new();
    DIR.get_or_init(|| {
        let dir = std::env::temp_dir().join(format!("sbm-watch-scope-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
        dir
    });
}

/// Every grant this agent has, switched on.
///
/// Deliberately the opposite of what the other API tests do. They check that a
/// switched-off grant refuses; this one needs every grant *on*, so that a 401
/// cannot be a 403 wearing a different number.
async fn permissive_state() -> Arc<AppState> {
    state_with(true).await
}

/// The same agent with the shell grant switched off, which is the only thing
/// that tells a 403 apart from a 401 on a route that acts on the machine.
async fn restrictive_state() -> Arc<AppState> {
    state_with(false).await
}

async fn state_with(full_access: bool) -> Arc<AppState> {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    remote.terminal.enabled = true;
    remote.full_access = Some(full_access);
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
        // An empty command, which is refused after the auth check. A body that
        // ran would be a real `sh -c` on the machine running the suite, and
        // proving the gate does not need one.
        (
            Method::POST,
            "/api/v1/exec",
            Some(json!({ "cmd": "" })),
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
        // A command with no name, refused before any file is touched. An empty
        // *list* is accepted — it clears the directory — and that directory is
        // `~/.config/server_box/custom_cmds`, which is the operator's own and is
        // executed on every extended cycle. The chdir above does not reach it,
        // so this entry must never send one.
        (
            Method::PUT,
            "/api/v1/custom-cmds",
            Some(json!({ "commands": [{ "name": "", "cmd": "scope" }] })),
        ),
        (Method::GET, "/api/v1/cron", None),
        // An empty schedule, for the reason the two push bodies below are
        // malformed: the panel-login half of this test reaches the handler, and
        // a body that passed validation would rewrite the crontab of whatever
        // user runs the suite.
        (
            Method::PUT,
            "/api/v1/cron",
            Some(json!({
                "op": "upsert",
                "line_index": null,
                "schedule": "",
                "command": "scope",
                "enabled": true,
            })),
        ),
        (Method::GET, "/api/v1/bmc", None),
        (Method::GET, "/api/v1/bmc/settings", None),
        // An address nothing can be dialed from, which validation refuses before
        // the file is written — and it is the refusal, not an empty address,
        // that has to be sent here: an empty one means "clear the section" and
        // is accepted, which would rewrite the `config.toml` this suite runs
        // beside.
        (
            Method::PUT,
            "/api/v1/bmc/settings",
            Some(json!({ "url": "not-an-address", "username": "scope", "fingerprint": "" })),
        ),
        // An intent no service implements, refused before the machine is
        // dialed — which is also why it cannot touch anything.
        (
            Method::POST,
            "/api/v1/bmc/control",
            Some(json!({ "intent": "nope" })),
        ),
        // A port nothing is listening on. The probe sends no credential and
        // reads no document, so the only thing it can do is fail.
        (
            Method::POST,
            "/api/v1/bmc/probe",
            Some(json!({ "url": "http://127.0.0.1:1" })),
        ),
        (Method::GET, "/api/v1/containers?part=containers", None),
        // A container's own output is reachable from the panel login, and a
        // watch token reaches `/metrics` and nothing else.
        (
            Method::GET,
            "/api/v1/containers?part=logs&id=sbm-scope-test-nonexistent",
            None,
        ),
        // An id no container can have, for the reason the cron body above is an
        // empty schedule: the panel-login half of this test reaches the
        // handler, and every other action here would really change the runtime
        // of whoever runs the suite. `start` on an id that does not exist is
        // refused by the runtime itself and stops nothing.
        (
            Method::POST,
            "/api/v1/containers",
            Some(json!({ "action": "start", "id": "sbm-scope-test-nonexistent" })),
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
        // An interval of zero, which validation refuses before the write — so
        // the panel-login half reaches the handler without rewriting
        // `config.toml`. The workspace chdir above is the second belt: these
        // endpoints write at all, and what they write when a body *is* accepted
        // must not be the operator's file.
        (
            Method::PUT,
            "/api/v1/settings",
            Some(json!({
                "interval_seconds": 0,
                "idle_pause_enabled": false,
                "rules": [],
                "cors_allowed_origins": [],
            })),
        ),
        (Method::GET, "/api/v1/card-order", None),
        // Accepted, and it writes: there is no refusal between the auth check
        // and the file. What it writes lands in the temp directory the helper
        // above chdirs into, which is the only reason this entry can be here.
        (
            Method::PUT,
            "/api/v1/card-order",
            Some(json!({ "card_order": [] })),
        ),
        (Method::GET, "/api/v1/velocity", None),
        (Method::GET, "/api/v1/velocity/history", None),
        // ---- Every endpoint added after this file was written had been
        // ---- missing from it, which is the one failure mode it exists to
        // ---- prevent: a route nothing asserts about is a route a watch token
        // ---- may reach. Each body below is one the *handler* refuses, so the
        // ---- panel-login half reaches it without changing anything.
        (Method::GET, "/api/v1/pve/settings", None),
        (
            Method::PUT,
            "/api/v1/pve/settings",
            Some(json!({ "auth": "password", "url": "http://10.0.0.1" })),
        ),
        (Method::GET, "/api/v1/pve/resources", None),
        (
            Method::POST,
            "/api/v1/pve/control",
            Some(json!({
                "node": "sbm-scope-test",
                "kind": "scope-test",
                "vmid": 1,
                "action": "start",
            })),
        ),
        (Method::GET, "/api/v1/process", None),
        // No `start_id`, which is what stopping a process checks the pid
        // against — without it no command is composed at all.
        (
            Method::POST,
            "/api/v1/process",
            Some(json!({ "pid": 999999999, "signal": "term" })),
        ),
        (Method::GET, "/api/v1/services", None),
        // A unit that does not exist: the listing is re-read, nothing matches,
        // and nothing is run.
        (
            Method::POST,
            "/api/v1/services",
            Some(json!({ "key": "sbm-scope-test-nonexistent", "action": "restart" })),
        ),
        (Method::GET, "/api/v1/users", None),
        (
            Method::POST,
            "/api/v1/users",
            Some(json!({ "action": "delete", "name": "sbm-scope-test-nonexistent" })),
        ),
        (Method::GET, "/api/v1/desktop", None),
        // An empty host, refused before the lock — so the routes this agent
        // has stored are untouched.
        (
            Method::PUT,
            "/api/v1/desktop",
            Some(json!({
                "targets": [{ "name": "scope-test", "protocol": "vnc", "host": "", "port": 5900 }],
            })),
        ),
        (Method::GET, "/api/v1/benchmark", None),
        // An estimate, which is pure arithmetic and is answered before the
        // grant: it starts no run and writes no row.
        (
            Method::POST,
            "/api/v1/benchmark",
            Some(json!({ "action": "estimate" })),
        ),
        // `run` is a required query field, so it has to be here or the
        // extractor answers 400 before the handler sees the token.
        (
            Method::DELETE,
            "/api/v1/benchmark?run=sbm-scope-test-nonexistent",
            None,
        ),
        (Method::GET, "/api/v1/ai/settings", None),
        // Both fields are required, and the address is refused before the lock.
        (
            Method::PUT,
            "/api/v1/ai/settings",
            Some(json!({ "base_url": "not-an-url", "model": "scope" })),
        ),
        (Method::GET, "/api/v1/ai/conversations", None),
        // Stopping a turn is looked up in memory and answered before the grant:
        // nothing is sent, stored or run.
        (
            Method::POST,
            "/api/v1/ai/conversations",
            Some(json!({ "action": "stop", "conversation": "sbm-scope-test-nonexistent" })),
        ),
        // Required query fields, for the reason `/benchmark`'s is.
        (
            Method::DELETE,
            "/api/v1/ai/conversations?conversation=sbm-scope-test-nonexistent",
            None,
        ),
        (
            Method::GET,
            "/api/v1/ai/follow?conversation=sbm-scope-test-nonexistent",
            None,
        ),
        (Method::GET, "/api/v1/snippets", None),
        // An id of the wrong shape, refused before the table is written.
        (
            Method::PUT,
            "/api/v1/snippets",
            Some(json!({ "snippets": [{ "id": "", "name": "scope", "script": "" }] })),
        ),
        // Planning a script returns keystrokes. Nothing in this endpoint runs
        // anything, so an empty script is as far as a caller can get.
        (
            Method::POST,
            "/api/v1/snippets/plan",
            Some(json!({ "script": "" })),
        ),
    ]
}


#[ntex::test]
async fn a_watch_token_reads_metrics_and_nothing_else() {
    workspace();
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
    workspace();
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
    workspace();
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

/// The one route that cannot be in the list above, and why.
///
/// `POST /power` validates nothing after the auth check: every body it accepts
/// is one of shutdown, reboot or suspend, and the handler runs the command. A
/// body that fails to deserialize is a 400 for both callers, so it cannot stand
/// in for the proof either. What can prove it is the other side of its gate:
/// with the shell grant off, the panel login is refused *before* the command is
/// reached — and the watch token is refused before that.
///
/// The same shape covers every write endpoint where no refusal exists between
/// the auth check and the effect. Only the ones with such a refusal are in the
/// list above, which is why the list is worth reading as a pair with this.
#[ntex::test]
async fn the_power_endpoint_is_refused_on_both_sides_of_its_gate() {
    workspace();
    let srv = test_server(restrictive_state().await).await;
    let token = issue_watch_token(&srv).await;
    let body = Some(json!({ "action": "shutdown", "password": null }));

    let status = status_with(&srv, &token, Method::POST, "/api/v1/power", body.clone()).await;
    assert_eq!(status, 401, "a watch token reached the power endpoint");

    let status = status_with(&srv, &jwt(), Method::POST, "/api/v1/power", body).await;
    assert_eq!(
        status, 403,
        "the grant refused it, so the machine was never asked to go down",
    );
}
