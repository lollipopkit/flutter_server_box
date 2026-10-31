//! The monitor's settings backup against a real WebDAV server: the folder
//! made, the key and a backup uploaded, listed, pruned and restored, with the
//! server's own answers (its PROPFIND, MKCOL, MOVE). The panel's side:
//! `frontend/e2e/monitor_backup.e2e.ts`; both, with rclone's and nginx's
//! WebDAV started on this machine, and the files opened with Go's age:
//! `scripts/monitor-backup-e2e.sh`.
//!
//!     SBM_E2E_WEBDAV_URL=http://127.0.0.1:18080/ SBM_E2E_WEBDAV_USER=… SBM_E2E_WEBDAV_PASSWORD=… \
//!     cargo test -p server_box_monitor --test monitor_backup_e2e -- --ignored --nocapture
//!
//! It works in a folder of its own under the URL (`sbm-e2e-<time>/`) and
//! removes what it put there.

mod common;

use ntex::http::Method;
use serde_json::json;
use server_box_monitor::core::config::Config;
use server_box_monitor::monitor_backup::{self, webdav};

use common::machine::{call, server_with};

#[ntex::test]
#[ignore]
async fn a_real_webdav_server_keeps_backups_that_restore() {
    let env = |k: &str| std::env::var(k).ok().filter(|v| !v.is_empty());
    let Some(base) = env("SBM_E2E_WEBDAV_URL") else {
        eprintln!("SBM_E2E_WEBDAV_URL is not set");
        return;
    };
    let user = env("SBM_E2E_WEBDAV_USER").unwrap_or_default();
    let password = env("SBM_E2E_WEBDAV_PASSWORD").unwrap_or_default();
    let base = if base.ends_with('/') { base } else { format!("{base}/") };
    let folder = format!("{base}sbm-e2e-{}/box/", chrono::Utc::now().format("%Y%m%d%H%M%S%3f"));

    let (srv, state) = server_with(Config::default()).await;
    state.monitor_backup.never_restart();
    let pw = common::PASSWORD;
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(json!({ "url": folder, "username": user, "password": password, "keep": 2, "current_password": pw }))).await;
    assert_eq!(status, 200, "{body}");
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/test", Some(json!({ "url": folder, "username": user }))).await;
    assert_eq!((status, body["missing"].clone()), (200, json!(true)), "{body}");

    // Two levels below what exists: made parent first.
    let passphrase = "an end-to-end passphrase";
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup/key", Some(json!({ "passphrase": passphrase, "current_password": pw }))).await;
    assert_eq!(status, 200, "{body}");

    std::fs::write("config.toml", "[server]\nhost = \"0.0.0.0\"\nport = 3770\nname = \"e2e-box\"\n").unwrap();
    for (i, id) in ["s1", "s2", "s3"].iter().enumerate() {
        sqlx::query("INSERT INTO snippet (id, name, script, position, updated_at) VALUES (?, ?, 'uptime', ?, 'x')")
            .bind(id)
            .bind(id)
            .bind(i as i64)
            .execute(&state.db)
            .await
            .unwrap();
        monitor_backup::check(&state, false).await;
        let (_, view) = call(&srv, true, Method::GET, "/api/v1/monitor-backup", None).await;
        assert_eq!(view["last_error"], serde_json::Value::Null, "{view}");
    }
    let (status, body) = call(&srv, true, Method::GET, "/api/v1/monitor-backup/list", None).await;
    assert_eq!(status, 200, "{body}");
    let listed = body["backups"].as_array().unwrap();
    assert_eq!(listed.len(), 2, "two kept: {body}");
    let newest = listed[0]["name"].as_str().unwrap().to_string();

    // The server lists only the two backups and their key: no upload left
    // under its temporary name.
    let dav = webdav::Dav::new(webdav::folder_url(&folder, true).unwrap(), &user, Some(&password));
    let mut names: Vec<String> = dav.list().await.unwrap().into_iter().map(|e| e.name).collect();
    names.sort();
    assert_eq!(names.len(), 3, "{names:?}");
    assert!(names.iter().all(|n| !n.ends_with(".part")), "{names:?}");

    sqlx::query("DELETE FROM snippet").execute(&state.db).await.unwrap();
    std::fs::write("config.toml", "[server]\nhost = \"127.0.0.1\"\nport = 4000\nname = \"other\"\n").unwrap();
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/restore", Some(json!({ "name": newest, "passphrase": "not it, but long", "current_password": pw }))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("wrongPassphrase")));
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/restore", Some(json!({ "name": newest, "passphrase": passphrase, "current_password": pw }))).await;
    assert_eq!(status, 200, "{body}");
    let snippets: Vec<String> = sqlx::query_scalar("SELECT id FROM snippet ORDER BY id").fetch_all(&state.db).await.unwrap();
    assert_eq!(snippets, ["s1", "s2", "s3"]);
    let config: Config = toml::from_str(&std::fs::read_to_string("config.toml").unwrap()).unwrap();
    assert_eq!((config.get_server().name.as_deref(), config.get_server().port), (Some("e2e-box"), 4000));

    // Clean up what this test put there; the folders stay (WebDAV removes a
    // folder with what is in it, which this client never asks for).
    for n in names {
        dav.delete(&n).await.unwrap();
    }
    assert!(dav.list().await.unwrap().is_empty());
}
