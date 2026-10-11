//! `/api/v1/shares*` on a real machine: an SMB share made, changed and
//! removed (`testparm` sees it), an account's SMB password set (`pdbedit`
//! lists it), an NFS export made and removed (`exportfs` serves it), a path
//! that is not a folder refused, shares set up elsewhere left alone. The
//! panel's side: `frontend/e2e/sharing.e2e.ts`.
//!
//! Opt-in and root only, with Samba and the NFS server installed: it changes
//! `/etc/samba` and `/etc/exports.d` (put back after) and adds an account.
//!
//!     SBM_E2E_SHARES=1 cargo test -p server_box_monitor --test shares_e2e -- --ignored --nocapture

mod common;

use std::process::Command;
use std::sync::Arc;
use std::time::Duration;

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::shares;
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";
const USER: &str = "sbme2eshare";

async fn setup() -> TestServer {
    let db = common::database().await;
    let config = Config { jwt_secret: Some(SECRET.to_string()), ..Default::default() };
    common::seed_as_upgrade(&db, &config).await;
    let state: Arc<AppState> = AppState::new(Arc::new(config), db);
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .service(web::resource("/shares").route(web::get().to(shares::view)))
                    .service(web::resource("/shares/smb").route(web::put().to(shares::set_smb)))
                    .service(web::resource("/shares/nfs").route(web::put().to(shares::set_nfs)))
                    .service(web::resource("/shares/smb/password").route(web::post().to(shares::smb_password)))
                    .service(web::resource("/shares/connections").route(web::post().to(shares::connections))),
            )
        }
    })
    .await
}

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    let req = srv
        .request(method, srv.url(path))
        .header("Authorization", format!("Bearer {}", generate_token("admin", SECRET).unwrap()))
        .timeout(Duration::from_secs(120));
    let resp = match body {
        Some(body) => req.send_json(&body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let bytes = resp.body().limit(16 << 20).await.unwrap_or_default();
    (resp.status().as_u16(), serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

fn sh(script: &str) -> String {
    let out = Command::new("sh").arg("-c").arg(script).output().unwrap();
    String::from_utf8_lossy(&out.stdout).trim().to_string()
}

/// `/etc/samba/smb.conf`, ServerBox's files and the test account as they
/// were, put back whatever happens.
struct Lab {
    dir: tempfile::TempDir,
    smb_conf: String,
}

impl Lab {
    fn new() -> Self {
        let dir = tempfile::Builder::new().prefix("sbm-share-").tempdir_in("/srv").unwrap();
        sh(&format!("chmod 755 '{}'", dir.path().display()));
        sh(&format!("id {USER} >/dev/null 2>&1 || useradd -M -s /usr/sbin/nologin {USER}"));
        Self { dir, smb_conf: std::fs::read_to_string("/etc/samba/smb.conf").unwrap() }
    }
}

impl Drop for Lab {
    fn drop(&mut self) {
        std::fs::write("/etc/samba/smb.conf", &self.smb_conf).unwrap();
        sh("rm -f /etc/samba/serverbox.conf /etc/samba/serverbox.conf.sbm-bak /etc/exports.d/serverbox.exports /etc/exports.d/serverbox.exports.sbm-bak /etc/exports.d/sbm-e2e-other.exports; exportfs -ra");
        sh(&format!("pdbedit -x {USER} >/dev/null 2>&1; userdel {USER}"));
        sh("systemctl reload smbd 2>/dev/null || true");
    }
}

#[ntex::test]
#[ignore = "changes Samba and NFS: SBM_E2E_SHARES=1, as root, both installed"]
async fn a_machines_shares_are_managed_end_to_end() {
    if std::env::var("SBM_E2E_SHARES").is_err() || sh("id -u") != "0" || sh("command -v smbd; command -v exportfs").lines().count() < 2 {
        eprintln!("SBM_E2E_SHARES is not set, not root, or Samba / the NFS server is not installed");
        return;
    }
    let lab = Lab::new();
    let folder = lab.dir.path().to_string_lossy().into_owned();
    // An export someone else made stays as it is.
    std::fs::create_dir_all("/etc/exports.d").unwrap();
    std::fs::write("/etc/exports.d/sbm-e2e-other.exports", format!("{folder} 10.9.9.9(ro)\n")).unwrap();
    let srv = setup().await;

    let (status, v) = call(&srv, Method::GET, "/api/v1/shares", None).await;
    assert_eq!(status, 200, "{v}");
    assert!(v["tools"].as_array().unwrap().iter().any(|t| t == "smbd"), "{v}");
    let other = v["nfs"].as_array().unwrap().iter().find(|e| e["path"] == folder).expect("the other export").clone();
    assert_eq!(other["managed"], false);

    // An SMB share, for one account, then read only.
    let share = |read_only: bool| json!({ "name": "sbme2e", "path": folder, "comment": "e2e", "read_only": read_only, "guest": false, "users": [USER] });
    let (status, v) = call(&srv, Method::PUT, "/api/v1/shares/smb", Some(json!({ "shares": [share(false)] }))).await;
    assert_eq!(status, 200, "{v}");
    let made = v["smb"].as_array().unwrap().iter().find(|s| s["name"] == "sbme2e").expect("the share").clone();
    assert_eq!((made["managed"].as_bool(), made["read_only"].as_bool(), made["users"].clone()), (Some(true), Some(false), json!([USER])));
    assert!(sh("testparm -s 2>/dev/null").contains("[sbme2e]"));
    let (status, v) = call(&srv, Method::PUT, "/api/v1/shares/smb", Some(json!({ "shares": [share(true)] }))).await;
    assert_eq!(status, 200, "{v}");
    assert_eq!(v["smb"].as_array().unwrap().iter().find(|s| s["name"] == "sbme2e").unwrap()["read_only"], true);

    // Time Machine and a recycle bin on it.
    let mut tm = share(true);
    tm["time_machine"] = json!(true);
    tm["recycle"] = json!(true);
    let (status, v) = call(&srv, Method::PUT, "/api/v1/shares/smb", Some(json!({ "shares": [tm] }))).await;
    assert_eq!(status, 200, "{v}");
    let made = v["smb"].as_array().unwrap().iter().find(|s| s["name"] == "sbme2e").unwrap().clone();
    assert_eq!((made["time_machine"].as_bool(), made["recycle"].as_bool()), (Some(true), Some(true)), "{made}");
    let parsed = sh("testparm -s 2>/dev/null");
    assert!(parsed.contains("fruit:time machine = Yes") && parsed.contains("recycle"), "{parsed}");

    // Who is connected: nobody yet, read as root.
    let (status, c) = call(&srv, Method::POST, "/api/v1/shares/connections", Some(json!({}))).await;
    assert_eq!(status, 200, "{c}");
    assert!(c["smb"].as_array().unwrap().is_empty() && c["nfs"].is_array(), "{c}");

    // Its account's SMB password.
    let (status, v) = call(&srv, Method::POST, "/api/v1/shares/smb/password", Some(json!({ "user": USER, "password": "e2e pass" }))).await;
    assert_eq!(status, 204, "{v}");
    assert!(sh("pdbedit -L").lines().any(|l| l.starts_with(&format!("{USER}:"))));

    // Refused before anything is written.
    let (status, v) = call(&srv, Method::PUT, "/api/v1/shares/smb", Some(json!({ "shares": [{ "name": "gone", "path": "/srv/sbm-not-there" }] }))).await;
    assert_eq!((status, v["error"].as_str(), v["path"].as_str()), (409, Some("notAFolder"), Some("/srv/sbm-not-there")), "{v}");
    let (status, v) = call(&srv, Method::PUT, "/api/v1/shares/smb", Some(json!({ "shares": [{ "name": "a]b", "path": folder }] }))).await;
    assert_eq!((status, v["error"].as_str()), (400, Some("invalidName")), "{v}");
    assert!(sh("testparm -s 2>/dev/null").contains("[sbme2e]"), "the share made before stays");

    // An NFS export for a network, then removed; the other one stays.
    let export = json!({ "path": folder, "clients": [{ "host": "192.168.77.0/24", "read_only": false, "squash": "all" }] });
    let (status, v) = call(&srv, Method::PUT, "/api/v1/shares/nfs", Some(json!({ "exports": [export] }))).await;
    assert_eq!(status, 200, "{v}");
    assert!(sh("exportfs -v").contains("192.168.77.0/24"), "{}", sh("exportfs -v"));
    let (status, v) = call(&srv, Method::PUT, "/api/v1/shares/nfs", Some(json!({ "exports": [] }))).await;
    assert_eq!(status, 200, "{v}");
    assert!(!sh("exportfs -v").contains("192.168.77.0/24"));
    assert!(sh("exportfs -v").contains("10.9.9.9"), "not ServerBox's, left alone");

    let (status, v) = call(&srv, Method::PUT, "/api/v1/shares/smb", Some(json!({ "shares": [] }))).await;
    assert_eq!(status, 200, "{v}");
    assert!(!sh("testparm -s 2>/dev/null").contains("[sbme2e]"));
    drop(lab);
}
