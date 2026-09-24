//! `GET/PUT /api/v1/desktop` end to end, against the real route table and a
//! real `config.toml`.
//!
//! Two things are asserted here that the module's own unit tests cannot show,
//! because both are about the file rather than about a function:
//!
//! - A route list is a *replace*, so a save that omits a route removes it, and
//!   what a `PUT` answered is what a following `GET` answers. The panel reads
//!   the answer as the new state of the form, so an echo of the request would
//!   hide a field the file lost.
//! - A refusal happens **before the file is touched**. `validate` is called
//!   ahead of the read-modify-write for that reason: a rejected save that had
//!   already been written would leave the operator's routes replaced by the
//!   set that was refused.
//!
//! The privilege split is asserted too, and it is the one thing about this
//! endpoint most likely to be misread: a route list needs only the panel
//! login, and opening a session through a route needs `full_access`. The two
//! are separate fields on `/capabilities` for exactly that reason.
//!
//! `config_file::CONFIG_PATH` is relative to the process working directory on
//! purpose, so this file chdirs into a temp directory — once, since cargo gives
//! each integration test file its own process — and serialises its tests, which
//! all write the same `config.toml`.

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

/// An install that predates this endpoint: no `[desktop]` section at all.
const CONFIG_WITHOUT_DESKTOP: &str = r#"
[server]
host = "127.0.0.1"
port = 3770
name = "test"
"#;

/// The same install with the shell grant switched off, so the panel may list
/// and edit routes but may not open a session.
const CONFIG_WITHOUT_FULL_ACCESS: &str = r#"
[server]
host = "127.0.0.1"
port = 3770
name = "test"

[remote_access]
full_access = false

[remote_access.terminal]
enabled = true
"#;

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// Moves the process into a directory of its own, once, and hands out the lock
/// that keeps these tests from writing each other's `config.toml`.
///
/// `tokio::sync::Mutex` rather than the one in `std`: every test below holds
/// this across the `await` that starts its server, which is what
/// `clippy::await_holding_lock` refuses.
async fn workspace() -> MutexGuard<'static, PathBuf> {
    static DIR: OnceLock<Mutex<PathBuf>> = OnceLock::new();
    let dir = DIR.get_or_init(|| {
        let dir = std::env::temp_dir().join(format!("sbm-desktop-api-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
        Mutex::new(dir)
    });
    dir.lock().await
}

fn write_config(contents: &str) {
    std::fs::write("config.toml", contents).unwrap();
}

/// The routes **as the file holds them**, which is what a save is judged on
/// rather than what a response said about it.
fn routes_on_disk() -> Vec<(String, String, String, u16)> {
    let config: Config = toml::from_str(&std::fs::read_to_string("config.toml").unwrap()).unwrap();
    config
        .get_desktop()
        .targets
        .into_iter()
        .map(|t| (t.name, t.protocol.as_str().to_string(), t.host, t.port))
        .collect()
}

/// The in-memory state, plus the pool so a test can read what was recorded.
async fn app_state(full_access: bool) -> (Arc<AppState>, sqlx::SqlitePool) {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    // The grant is gated on the terminal being available, so that switching
    // the terminal off cannot leave this door open behind it. The test server
    // listens on loopback, which counts as a secure transport.
    remote.terminal.enabled = true;
    remote.full_access = Some(full_access);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    (AppState::new(Arc::new(config), db.clone()), db)
}

/// Mounts the real route table.
///
/// A scope of its own would assert something about the handler and nothing
/// about what the shipped binary exposes — which route gets which gate is a
/// property of [`configure_api`], and this endpoint is two lines in it.
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

async fn get(srv: &TestServer) -> Result<Value, u16> {
    let resp = srv
        .get("/api/v1/desktop")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    if !resp.status().is_success() {
        return Err(resp.status().as_u16());
    }
    Ok(resp.json().await.unwrap())
}

async fn put(srv: &TestServer, targets: Value) -> Result<Value, (u16, String)> {
    let resp = srv
        .put("/api/v1/desktop")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({ "targets": targets }))
        .await
        .unwrap();
    let status = resp.status().as_u16();
    let body: Value = resp.json().await.unwrap();
    if !resp.status().is_success() {
        // The codes are what the panel phrases; a sentence would be a second
        // vocabulary for the same refusal.
        let code = body["error"].as_str().unwrap_or_default().to_string();
        return Err((status, code));
    }
    Ok(body)
}

fn vnc(name: &str, host: &str) -> Value {
    json!({ "name": name, "protocol": "vnc", "host": host, "port": 5900 })
}

#[ntex::test]
async fn a_route_list_round_trips_through_the_file() {
    let _dir = workspace().await;
    write_config(CONFIG_WITHOUT_DESKTOP);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    // An install with no section is an empty list, not a 404 and not an error:
    // the config file is the store, and a store with nothing in it is empty.
    let body = get(&srv).await.expect("an empty list is readable");
    assert_eq!(body["targets"], json!([]));
    // The protocol table is sent rather than hard-coded in the panel, so a port
    // changed here reaches every client.
    assert_eq!(
        body["protocols"],
        json!([
            { "id": "vnc", "default_port": 5900 },
            { "id": "rdp", "default_port": 3389 },
        ])
    );

    let saved = put(
        &srv,
        json!([
            vnc("office", "10.0.0.5"),
            {
                "name": "build box",
                "protocol": "rdp",
                "host": "10.0.0.9",
                "port": 3389,
                "username": "Administrator",
                "domain": "CORP",
                "view_only": true,
                "shared": false,
            },
        ]),
    )
    .await
    .expect("a well-formed set is saved");

    // The order is what is stored, so the answer is the file rather than a set.
    assert_eq!(saved["targets"][0]["name"], "office");
    assert_eq!(saved["targets"][1]["username"], "Administrator");
    assert_eq!(saved["targets"][1]["domain"], "CORP");
    assert_eq!(saved["targets"][1]["view_only"], true);
    assert_eq!(saved["targets"][1]["shared"], false);
    // `shared` defaults to true, which is the value a form leaves alone rather
    // than a value it has to send.
    assert_eq!(saved["targets"][0]["shared"], true);
    assert_eq!(get(&srv).await.unwrap(), saved, "what the file holds");
    assert_eq!(
        routes_on_disk(),
        vec![
            ("office".to_string(), "vnc".to_string(), "10.0.0.5".to_string(), 5900),
            ("build box".to_string(), "rdp".to_string(), "10.0.0.9".to_string(), 3389),
        ]
    );

    // A replace, which is the reason this is a whole set: the route that is not
    // in the next request is gone from the file, not merely absent from the
    // response.
    put(&srv, json!([vnc("office", "10.0.0.6")]))
        .await
        .expect("a shorter set replaces the longer one");
    assert_eq!(
        routes_on_disk(),
        vec![("office".to_string(), "vnc".to_string(), "10.0.0.6".to_string(), 5900)],
        "the route that was not sent was removed"
    );

    // And removing the last one is a save rather than a mistake.
    put(&srv, json!([])).await.expect("an empty set is a save");
    assert!(routes_on_disk().is_empty());
}

#[ntex::test]
async fn a_route_that_could_not_be_dialled_is_refused_before_the_file_is_written() {
    let _dir = workspace().await;
    write_config(CONFIG_WITHOUT_DESKTOP);
    let (state, db) = app_state(true).await;
    let srv = test_server(state).await;

    put(&srv, json!([vnc("kept", "10.0.0.5")]))
        .await
        .expect("the route the refusals must leave alone");
    let before = routes_on_disk();

    // Each of these is a value the panel could have typed: it is interpreted by
    // this agent, which is what dials, so a value that could not be one is
    // refused while the operator is still looking at the form. Waiting until
    // connect time would report a name that does not resolve.
    let cases = [
        (json!([vnc("", "10.0.0.5")]), "invalidName"),
        (json!([vnc("a\nb", "10.0.0.5")]), "invalidName"),
        (json!([vnc(&"n".repeat(65), "10.0.0.5")]), "invalidName"),
        // Uniqueness is a property of the set being saved, not of what is
        // already on disk: the two routes in one save are the case.
        (json!([vnc("same", "10.0.0.5"), vnc("same", "10.0.0.6")]), "duplicateName"),
        (json!([vnc("other", "")]), "invalidHost"),
        (json!([vnc("other", "10.0.0.5 3389")]), "invalidHost"),
        (json!([vnc("other", "10.0.0.5\n")]), "invalidHost"),
        (
            json!([{ "name": "other", "protocol": "vnc", "host": "10.0.0.5", "port": 0 }]),
            "invalidPort",
        ),
        (
            json!([{ "name": "other", "protocol": "vnc", "host": "10.0.0.5",
                     "port": 5900, "username": "ad\nmin" }]),
            "invalidUsername",
        ),
        (
            json!([{ "name": "other", "protocol": "vnc", "host": "10.0.0.5",
                     "port": 5900, "domain": "CO RP" }]),
            "invalidDomain",
        ),
    ];

    for (targets, code) in cases {
        let (status, answer) = put(&srv, targets)
            .await
            .expect_err("a value that is not a route must be refused");
        assert_eq!(status, 400, "{code} answered {status}");
        assert_eq!(answer, code);
    }

    assert_eq!(routes_on_disk(), before, "a refused save touched the file");

    // A refusal the caller could have avoided is recorded as an error rather
    // than as a save, and the detail is the code — never the value, which is
    // the caller's own text.
    let (kind, action, result): (String, String, String) = sqlx::query_as(
        "SELECT kind, action, result FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();
    assert_eq!((kind.as_str(), action.as_str(), result.as_str()), ("desktop", "write", "error"));

    // Renaming an existing route is an ordinary edit, not a collision: the
    // identity is carried by the set, so the old name is simply absent.
    put(&srv, json!([vnc("renamed", "10.0.0.5")]))
        .await
        .expect("a rename is a replace");
    assert_eq!(routes_on_disk()[0].0, "renamed");
}

#[ntex::test]
async fn a_save_is_recorded_by_name_and_never_by_address() {
    let _dir = workspace().await;
    write_config(CONFIG_WITHOUT_DESKTOP);
    let (state, db) = app_state(true).await;
    let srv = test_server(state).await;

    put(&srv, json!([vnc("office", "desk.internal.example"), vnc("lab", "10.0.0.7")]))
        .await
        .expect("saved");

    let (kind, action, result, subject): (String, String, String, Option<String>) = sqlx::query_as(
        "SELECT kind, action, result, subject FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();

    assert_eq!((kind.as_str(), action.as_str(), result.as_str()), ("desktop", "write", "ok"));
    let subject = subject.expect("a save names what was saved");
    assert_eq!(subject, "office (vnc), lab (vnc)");
    // The point: an address is this agent's own network, and the panel's own
    // page is where an operator recognises a route by its name.
    assert!(!subject.contains("10.0.0.7"), "the address was recorded: {subject}");
    assert!(!subject.contains("desk.internal.example"), "the address was recorded: {subject}");
}

/// The split this endpoint is most likely to be misread on. A route list is
/// answered to anyone who has authenticated to the panel — it executes
/// nothing — and a *session* is the relay or the RDP endpoint, both of which
/// are `full_access` and check the grant again when the socket opens.
#[ntex::test]
async fn routes_are_editable_without_the_shell_grant() {
    let _dir = workspace().await;
    write_config(CONFIG_WITHOUT_FULL_ACCESS);
    let (state, _db) = app_state(false).await;
    let srv = test_server(state).await;

    put(&srv, json!([vnc("office", "10.0.0.5")]))
        .await
        .expect("the panel login is enough to save a route");
    assert_eq!(get(&srv).await.unwrap()["targets"][0]["name"], "office");

    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    assert!(resp.status().is_success(), "capabilities answered {}", resp.status());
    let body: Value = resp.json().await.unwrap();

    // Three fields, and the panel reads the last two before it offers to open a
    // session: `desktop` says the route list exists, which is not a claim about
    // a grant. `rdp` is reported the way `stream` is, as *will answer* — a
    // client gates a button on it, and a `true` that the endpoint then refuses
    // would be that button opening nothing.
    assert_eq!(body["remote_access"]["desktop"], true);
    assert_eq!(body["remote_access"]["stream"], false);
    assert_eq!(body["remote_access"]["rdp"], false);
    assert_eq!(body["remote_access"]["full_access"], false);
}

#[ntex::test]
async fn an_unauthenticated_caller_is_refused() {
    let _dir = workspace().await;
    write_config(CONFIG_WITHOUT_DESKTOP);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let resp = srv.get("/api/v1/desktop").send().await.unwrap();
    assert_eq!(resp.status().as_u16(), 401);

    let resp = srv
        .put("/api/v1/desktop")
        .send_json(&json!({ "targets": [vnc("office", "10.0.0.5")] }))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 401);
    assert!(routes_on_disk().is_empty(), "a refused save wrote the file");
}
