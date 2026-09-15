//! `GET/PUT /api/v1/push` end to end, against the real route table and a real
//! `config.toml`.
//!
//! The unit tests in `api::push` cover the merge rules on their own values.
//! What they cannot show is the property the whole design exists for: that a
//! stored credential is not in the bytes the agent sends back, and that an
//! editor which never saw one can still save an edit without destroying it.
//! Both of those are about the response body and the file on disk, so they are
//! asserted here on both.
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
const BARK_KEY: &str = "bark-key-not-to-be-disclosed";
const HOOK_HEADER: &str = "Bearer hook-token-not-to-be-disclosed";

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
/// `clippy::await_holding_lock` refuses. The lock is contended for the whole
/// length of a test by design, so "drop it before the await" is not available.
async fn workspace() -> MutexGuard<'static, PathBuf> {
    static DIR: OnceLock<Mutex<PathBuf>> = OnceLock::new();
    let dir = DIR.get_or_init(|| {
        let dir = std::env::temp_dir().join(format!("sbm-push-api-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
        Mutex::new(dir)
    });
    dir.lock().await
}

fn write_config(contents: &str) {
    std::fs::write("config.toml", contents).unwrap();
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

fn jwt() -> String {
    generate_token("admin", SECRET).unwrap()
}

/// Two channels, each holding something that must never come back out.
const CONFIG_WITH_SECRETS: &str = r#"
[server]
host = "127.0.0.1"
port = 3770
name = "test"

[monitoring]
interval_seconds = 60
rules = []
push_rate = "2/1m"

[[push]]
name = "phone"
push_type = "bark"
server = "https://api.day.app"
key = "bark-key-not-to-be-disclosed"
title = "ServerBox Monitor"

[[push]]
name = "hook"
push_type = "webhook"
url = "https://example.invalid/hook"
method = "POST"

[push.headers]
Authorization = "Bearer hook-token-not-to-be-disclosed"
Content-Type = "application/json"
"#;

#[ntex::test]
async fn a_credential_is_withheld_and_survives_an_edit_that_never_saw_it() {
    let _dir = workspace().await;
    write_config(CONFIG_WITH_SECRETS);
    let srv = test_server().await;

    let resp = srv
        .get("/api/v1/push")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);
    let raw = resp.body().await.unwrap();
    let raw = String::from_utf8(raw.to_vec()).unwrap();

    // The property the whole module exists for, asserted on the bytes rather
    // than on a parsed field: a key added to the redaction list later would
    // still have to pass this.
    assert!(!raw.contains(BARK_KEY), "the bark key was on the wire: {raw}");
    assert!(
        !raw.contains("hook-token-not-to-be-disclosed"),
        "the webhook's Authorization header was on the wire: {raw}"
    );

    let view: Value = serde_json::from_str(&raw).unwrap();
    assert_eq!(view["pushes"][0]["config"]["key"], Value::Null);
    assert_eq!(view["pushes"][0]["config"]["server"], "https://api.day.app");
    assert_eq!(
        view["pushes"][1]["config"]["headers"]["Authorization"],
        Value::Null
    );
    // Not a credential by decision: it is the channel's identity in an editor.
    assert_eq!(view["pushes"][1]["config"]["url"], "https://example.invalid/hook");
    // Every header value is withheld, not just the one that is obviously a
    // credential — the header *names* are what an editor needs to show a list,
    // and one rule over the whole table is easier to be sure of than a list of
    // names believed to be safe.
    assert_eq!(
        view["pushes"][1]["config"]["headers"]["Content-Type"],
        Value::Null
    );
    assert_eq!(view["push_rate"], "2/1m");
    assert_eq!(view["applies_on_restart"], true);

    // What an editor does with that: rename the channel, change a title, move
    // it second, and send back the `null` it was given.
    let resp = srv
        .put("/api/v1/push")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({
            "push_rate": "3/5m",
            "pushes": [
                {
                    "from_index": 1,
                    "name": "hook",
                    "push_type": "webhook",
                    "config": {
                        "url": "https://example.invalid/hook",
                        "method": "POST",
                        "headers": {
                            "Authorization": null,
                            "Content-Type": "application/json",
                        },
                    },
                },
                {
                    "from_index": 0,
                    "name": "my phone",
                    "push_type": "bark",
                    "config": {
                        "server": "https://api.day.app",
                        "key": null,
                        "title": "Alerts",
                    },
                },
            ],
        }))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200, "the edit should have been accepted");

    let saved = read_config();
    let pushes = saved.get_push();
    assert_eq!(pushes[0].name, "hook");
    assert_eq!(pushes[1].name, "my phone");
    assert_eq!(
        pushes[1].config["key"].as_str(),
        Some(BARK_KEY),
        "a rename and a reorder must not lose the credential"
    );
    assert_eq!(pushes[1].config["title"].as_str(), Some("Alerts"));
    assert_eq!(
        pushes[0].config["headers"]["Authorization"].as_str(),
        Some(HOOK_HEADER),
    );
    assert_eq!(saved.get_monitoring().push_rate.as_deref(), Some("3/5m"));
}

#[ntex::test]
async fn a_value_the_editor_does_supply_replaces_the_stored_one() {
    let _dir = workspace().await;
    write_config(CONFIG_WITH_SECRETS);
    let srv = test_server().await;

    let resp = srv
        .put("/api/v1/push")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({
            "pushes": [{
                "from_index": 0,
                "name": "phone",
                "push_type": "bark",
                "config": { "server": "https://api.day.app", "key": "a-new-key" },
            }],
        }))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);

    let saved = read_config();
    assert_eq!(saved.get_push()[0].config["key"].as_str(), Some("a-new-key"));
    // The whole set is replaced, so the channel left out of the request is gone.
    assert_eq!(saved.get_push().len(), 1);
}

#[ntex::test]
async fn a_withheld_credential_with_nothing_behind_it_is_refused_whole() {
    let _dir = workspace().await;
    write_config(CONFIG_WITH_SECRETS);
    let srv = test_server().await;

    let resp = srv
        .put("/api/v1/push")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({
            "pushes": [{
                "from_index": null,
                "name": "phone",
                "push_type": "bark",
                "config": { "key": null },
            }],
        }))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 400);

    // And nothing was written: a rejected set leaves the agent as it was,
    // rather than half of what the editor is showing.
    let saved = read_config();
    assert_eq!(saved.get_push().len(), 2);
    assert_eq!(saved.get_push()[0].config["key"].as_str(), Some(BARK_KEY));
}

#[ntex::test]
async fn a_rate_the_loader_would_ignore_is_refused() {
    let _dir = workspace().await;
    write_config(CONFIG_WITH_SECRETS);
    let srv = test_server().await;

    let resp = srv
        .put("/api/v1/push")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({ "pushes": [], "push_rate": "every minute" }))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 400);
    assert_eq!(
        read_config().get_monitoring().push_rate.as_deref(),
        Some("2/1m"),
        "a refused rate must not have taken the channels down with it"
    );
}
