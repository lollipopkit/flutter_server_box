//! `/api/v1/monitor-backup*` against a WebDAV server in this process: the
//! settings and what they refuse, the key, backups made only when something
//! changed, the oldest pruned with the keys no backup needs, a failure said
//! once, and a restore. Real WebDAV servers: `monitor_backup_e2e.rs`.

mod common;

use std::collections::{BTreeMap, BTreeSet};
use std::sync::{Arc, Mutex};

use ntex::http::{Method, StatusCode};
use ntex::util::Bytes;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App, HttpRequest, HttpResponse};
use serde_json::{Value, json};
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;
use server_box_monitor::monitor_backup;

use common::machine::{call, server_with};

// -----------------------------------------------------------------------------
// A WebDAV server
// -----------------------------------------------------------------------------

#[derive(Default)]
struct Dav {
    folders: BTreeSet<String>,
    files: BTreeMap<String, Vec<u8>>,
    /// Answers every PUT with this status instead.
    refuse_put: Option<u16>,
    /// Answers every DELETE with this status instead.
    refuse_delete: Option<u16>,
}

type Shared = Arc<Mutex<Dav>>;

const USER: &str = "backup";
const PASSWORD: &str = "dav-secret";

fn parent(path: &str) -> String {
    let trimmed = path.trim_end_matches('/');
    format!("{}/", &trimmed[..trimmed.rfind('/').unwrap_or(0)])
}

async fn dav(req: HttpRequest, body: Bytes, store: web::types::State<Shared>) -> HttpResponse {
    use base64::Engine;
    let expected = format!("Basic {}", base64::engine::general_purpose::STANDARD.encode(format!("{USER}:{PASSWORD}")));
    if req.headers().get("authorization").and_then(|v| v.to_str().ok()) != Some(expected.as_str()) {
        return HttpResponse::Unauthorized().finish();
    }
    let path = percent_encoding::percent_decode_str(req.path()).decode_utf8_lossy().into_owned();
    let mut d = store.lock().unwrap();
    match req.method().as_str() {
        "PROPFIND" => {
            let folder = if path.ends_with('/') { path.clone() } else { format!("{path}/") };
            if !d.folders.contains(&folder) {
                return HttpResponse::NotFound().finish();
            }
            let mut xml = String::from(r#"<?xml version="1.0"?><D:multistatus xmlns:D="DAV:">"#);
            let entry = |href: &str, prop: &str| format!("<D:response><D:href>{href}</D:href><D:propstat><D:prop>{prop}</D:prop><D:status>HTTP/1.1 200 OK</D:status></D:propstat></D:response>");
            xml += &entry(&folder, "<D:resourcetype><D:collection/></D:resourcetype>");
            for f in d.folders.iter().filter(|f| *f != &folder && parent(f) == folder) {
                xml += &entry(f, "<D:resourcetype><D:collection/></D:resourcetype>");
            }
            for (f, bytes) in d.files.iter().filter(|(f, _)| parent(f) == folder) {
                xml += &entry(f, &format!("<D:resourcetype/><D:getcontentlength>{}</D:getcontentlength>", bytes.len()));
            }
            xml += "</D:multistatus>";
            HttpResponse::build(StatusCode::MULTI_STATUS).content_type("application/xml").body(xml)
        }
        "MKCOL" => {
            let folder = if path.ends_with('/') { path.clone() } else { format!("{path}/") };
            if d.folders.contains(&folder) {
                return HttpResponse::MethodNotAllowed().finish();
            }
            if !d.folders.contains(&parent(&folder)) {
                return HttpResponse::Conflict().finish();
            }
            d.folders.insert(folder);
            HttpResponse::Created().finish()
        }
        "PUT" => {
            if let Some(status) = d.refuse_put {
                return HttpResponse::build(StatusCode::from_u16(status).unwrap()).finish();
            }
            if !d.folders.contains(&parent(&path)) {
                return HttpResponse::Conflict().finish();
            }
            d.files.insert(path, body.to_vec());
            HttpResponse::Created().finish()
        }
        "MOVE" => {
            let to = req.headers().get("destination").and_then(|v| v.to_str().ok()).and_then(|v| url::Url::parse(v).ok());
            let Some(to) = to else { return HttpResponse::BadRequest().finish() };
            let to = percent_encoding::percent_decode_str(to.path()).decode_utf8_lossy().into_owned();
            match d.files.remove(&path) {
                Some(bytes) => {
                    d.files.insert(to, bytes);
                    HttpResponse::Created().finish()
                }
                None => HttpResponse::NotFound().finish(),
            }
        }
        "GET" => match d.files.get(&path) {
            Some(bytes) => HttpResponse::Ok().body(bytes.clone()),
            None => HttpResponse::NotFound().finish(),
        },
        "DELETE" if d.refuse_delete.is_some() => HttpResponse::build(StatusCode::from_u16(d.refuse_delete.unwrap()).unwrap()).finish(),
        "DELETE" => match d.files.remove(&path) {
            Some(_) => HttpResponse::NoContent().finish(),
            None => HttpResponse::NotFound().finish(),
        },
        _ => HttpResponse::MethodNotAllowed().finish(),
    }
}

async fn dav_server() -> (TestServer, Shared) {
    let store: Shared = Arc::new(Mutex::new(Dav { folders: ["/".to_string()].into(), ..Default::default() }));
    let shared = store.clone();
    let srv = web_test::server(move || {
        let store = shared.clone();
        async move { App::new().state(store).default_service(web::to(dav)) }
    })
    .await;
    (srv, store)
}

fn names(store: &Shared, prefix: &str) -> Vec<String> {
    store
        .lock()
        .unwrap()
        .files
        .keys()
        .filter_map(|k| k.strip_prefix("/dav/box/"))
        .filter(|k| k.starts_with(prefix))
        .map(String::from)
        .collect()
}

fn backups(store: &Shared) -> Vec<String> {
    names(store, "serverbox-monitor-").into_iter().filter(|n| n.ends_with(".tar.gz.age")).collect()
}

fn keys(store: &Shared) -> Vec<String> {
    names(store, "serverbox-monitor-key-")
}

async fn notices(state: &AppState, kind: &str) -> i64 {
    sqlx::query_scalar("SELECT COUNT(*) FROM desk_notification WHERE kind = ?").bind(kind).fetch_one(&state.db).await.unwrap()
}

async fn snippet(state: &AppState, id: &str) {
    sqlx::query("INSERT INTO snippet (id, name, script, position, updated_at) VALUES (?, ?, 'echo hi', 0, 'x')")
        .bind(id)
        .bind(id)
        .execute(&state.db)
        .await
        .unwrap();
}

#[ntex::test]
async fn backups_are_made_kept_and_restored() {
    let (dav_srv, store) = dav_server().await;
    let (srv, state) = server_with(Config::default()).await;
    state.monitor_backup.never_restart();
    let folder = format!("http://{}/dav/box", dav_srv.addr());
    let pw = common::PASSWORD;
    let settings = |password: Option<&str>, keep: i64| {
        let mut body = json!({ "url": folder, "username": USER, "keep": keep, "current_password": pw });
        if let Some(p) = password {
            body["password"] = json!(p);
        }
        body
    };

    let (status, body) = call(&srv, true, Method::GET, "/api/v1/monitor-backup", None).await;
    assert_eq!((status, body["configured"].clone()), (200, json!(false)));

    // Where backups go needs the password, an address credentials may go
    // to, and a sane count.
    let (status, _) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(json!({ "url": folder, "username": USER }))).await;
    assert_ne!(status, 200);
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(json!({ "url": "http://nas.lan/dav", "current_password": pw }))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("invalidUrl")));
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(settings(Some(PASSWORD), 0))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("invalidKeep")));

    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/test", Some(json!({ "url": folder, "username": USER, "password": "wrong" }))).await;
    assert_eq!((status, body["error"].as_str()), (502, Some("webdav.unauthorized")));
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(settings(Some(PASSWORD), 10))).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["has_password"], true);
    assert!(body.get("password").is_none(), "{body}");
    // The stored password is used for the same server, never another.
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/test", Some(json!({ "url": folder, "username": USER }))).await;
    assert_eq!((status, body["missing"].clone()), (200, json!(true)), "{body}");
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/test", Some(json!({ "url": "https://elsewhere.example.com/", "username": USER }))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("passwordRequired")));

    // No key, no backup.
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/run", None).await;
    assert_eq!((status, body["error"].as_str()), (409, Some("notReady")));
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup/key", Some(json!({ "passphrase": "short", "current_password": pw }))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("weakPassphrase")));
    let first_pass = "first passphrase, long enough";
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup/key", Some(json!({ "passphrase": first_pass, "current_password": pw }))).await;
    assert_eq!(status, 200, "{body}");
    let first_key = body["key_id"].as_str().unwrap().to_string();
    let only = keys(&store);
    assert!(only.len() == 1 && only[0].ends_with(&format!("-{first_key}.age")), "the folder was made, parents first: {only:?}");

    // A backup, then none while nothing changed.
    std::fs::write("config.toml", "[server]\nhost = \"0.0.0.0\"\nport = 3770\nname = \"box-a\"\n").unwrap();
    snippet(&state, "s1").await;
    monitor_backup::check(&state, false).await;
    assert_eq!(backups(&store).len(), 1);
    let (_, body) = call(&srv, true, Method::GET, "/api/v1/monitor-backup", None).await;
    assert_eq!(body["last_name"].as_str(), backups(&store).first().map(String::as_str));
    assert_eq!(body["last_error"], Value::Null);
    monitor_backup::check(&state, false).await;
    assert_eq!(backups(&store).len(), 1, "unchanged");
    // A run is not a change.
    sqlx::query("INSERT INTO storage_maintenance (task, every, at, day, updated_at) VALUES ('scrub', 'weekly', '03:00', 1, 'x')").execute(&state.db).await.unwrap();
    monitor_backup::check(&state, false).await;
    assert_eq!(backups(&store).len(), 2);
    sqlx::query("UPDATE storage_maintenance SET last_run = 'now'").execute(&state.db).await.unwrap();
    monitor_backup::check(&state, false).await;
    assert_eq!(backups(&store).len(), 2, "only what changes on its own changed, within the day");

    // Two kept: the oldest goes.
    let (status, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(settings(None, 2))).await;
    assert_eq!((status, body["key_id"].as_str()), (200, Some(first_key.as_str())), "the same folder keeps its key");
    snippet(&state, "s2").await;
    monitor_backup::check(&state, false).await;
    assert_eq!(backups(&store).len(), 2);
    // Fewer kept with nothing else changed: the surplus goes at the next check.
    let (status, _) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(settings(None, 1))).await;
    assert_eq!(status, 200);
    monitor_backup::check(&state, false).await;
    assert_eq!(backups(&store).len(), 1, "pruned to the lower keep");
    let (status, _) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(settings(None, 2))).await;
    assert_eq!(status, 200);

    // A new passphrase is a new key; the old key stays while a backup needs it.
    let second_pass = "second passphrase, long enough";
    let (_, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup/key", Some(json!({ "passphrase": second_pass, "current_password": pw }))).await;
    let second_key = body["key_id"].as_str().unwrap().to_string();
    assert_ne!(second_key, first_key);
    monitor_backup::check(&state, true).await;
    assert_eq!(keys(&store).len(), 2);
    monitor_backup::check(&state, true).await;
    let only = keys(&store);
    assert!(only.len() == 1 && only[0].ends_with(&format!("-{second_key}.age")), "no backup needs the first key: {only:?}");

    let (status, body) = call(&srv, true, Method::GET, "/api/v1/monitor-backup/list", None).await;
    assert_eq!(status, 200, "{body}");
    let listed = body["backups"].as_array().unwrap().clone();
    assert_eq!(listed.len(), 2);
    assert!(listed.iter().all(|b| b["current_key"] == true && b["key_id"] == second_key.as_str()));
    assert!(listed[0]["created_at"].as_str() > listed[1]["created_at"].as_str(), "newest first");

    // A failure is said once, and when it works again.
    store.lock().unwrap().refuse_put = Some(507);
    snippet(&state, "s3").await;
    monitor_backup::check(&state, false).await;
    monitor_backup::check(&state, false).await;
    let (_, body) = call(&srv, true, Method::GET, "/api/v1/monitor-backup", None).await;
    assert_eq!(body["last_error"], "webdav.serverFull");
    assert_eq!(notices(&state, "backup.failed").await, 1);
    store.lock().unwrap().refuse_put = None;
    monitor_backup::check(&state, false).await;
    assert_eq!(notices(&state, "backup.back").await, 1);
    // Without its key file a backup would never be read.
    store.lock().unwrap().files.retain(|k, _| !k.contains("-key-"));
    monitor_backup::check(&state, true).await;
    let (_, body) = call(&srv, true, Method::GET, "/api/v1/monitor-backup", None).await;
    assert_eq!(body["last_error"], "keyMissing");
    let (_, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup/key", Some(json!({ "passphrase": second_pass, "current_password": pw }))).await;
    let third_key = body["key_id"].as_str().unwrap().to_string();
    monitor_backup::check(&state, false).await;
    let newest = backups(&store).into_iter().max().unwrap();
    assert!(newest.contains(&third_key));

    // Restoring: refused names, a wrong passphrase, then the settings back.
    let restore = |name: &str, passphrase: &str| json!({ "name": name, "passphrase": passphrase, "current_password": pw });
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/restore", Some(restore("../etc/passwd", second_pass))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("invalidName")));
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/restore", Some(restore(&newest, first_pass))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("wrongPassphrase")));

    sqlx::query("DELETE FROM snippet").execute(&state.db).await.unwrap();
    sqlx::query("INSERT INTO access_log (timestamp, kind, action, result) VALUES ('kept', 'login', 'open', 'ok')").execute(&state.db).await.unwrap();
    std::fs::write("config.toml", "[server]\nhost = \"127.0.0.1\"\nport = 9999\nname = \"box-b\"\n").unwrap();
    let changed = || async { sqlx::query_scalar::<_, i64>("SELECT password_changed_ms FROM users").fetch_one(&state.db).await.unwrap() };
    let before = changed().await;
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/restore", Some(restore(&newest, second_pass))).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["restart"], false);
    assert_eq!(body["restored"]["config"], true);
    let snippets: Vec<String> = sqlx::query_scalar("SELECT id FROM snippet ORDER BY id").fetch_all(&state.db).await.unwrap();
    assert_eq!(snippets, ["s1", "s2", "s3"]);
    let kept: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM access_log WHERE timestamp = 'kept'").fetch_one(&state.db).await.unwrap();
    assert_eq!(kept, 1, "history is this machine's own");
    let config: Config = toml::from_str(&std::fs::read_to_string("config.toml").unwrap()).unwrap();
    assert_eq!((config.get_server().name.as_deref(), config.get_server().port), (Some("box-a"), 9999), "the name came back, the port stayed");
    // Where backups go is this machine's, untouched.
    let row = monitor_backup::row(&state.db).await.unwrap().unwrap();
    assert_eq!(row.keep, 2);
    // The password is the backup's now, as a change: tokens from before go.
    assert!(changed().await > before);
}

/// Another monitor's backups and key in the same folder are never pruned; a
/// folder that refuses deletes keeps the backup made and is not sent another
/// at every check; a run asked while turned off is refused; another folder
/// starts with none of the last one's state.
#[ntex::test]
async fn shared_folders_and_refused_deletes() {
    let (dav_srv, store) = dav_server().await;
    let (srv, state) = server_with(Config::default()).await;
    state.monitor_backup.never_restart();
    let folder = format!("http://{}/dav/box", dav_srv.addr());
    let pw = common::PASSWORD;
    let save = |enabled: bool, keep: i64, url: &str| json!({ "url": url, "username": USER, "password": PASSWORD, "keep": keep, "enabled": enabled, "current_password": pw });
    let (status, _) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(save(true, 1, &folder))).await;
    assert_eq!(status, 200);
    let (status, _) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup/key", Some(json!({ "passphrase": "shared folder passphrase", "current_password": pw }))).await;
    assert_eq!(status, 200);

    // Another monitor's files, older than anything this one makes.
    let theirs = ["serverbox-monitor-ffffffff-20200101T000000.000Z-aaaaaaaa.tar.gz.age", "serverbox-monitor-key-ffffffff-aaaaaaaa.age", "serverbox-monitor-key-ffffffff-bbbbbbbb.age"];
    for name in theirs {
        store.lock().unwrap().files.insert(format!("/dav/box/{name}"), b"theirs".to_vec());
    }
    snippet(&state, "a").await;
    monitor_backup::check(&state, false).await;
    snippet(&state, "b").await;
    monitor_backup::check(&state, false).await;
    let all = names(&store, "serverbox-monitor-");
    for name in theirs {
        assert!(all.iter().any(|n| n == name), "{name} pruned: {all:?}");
    }
    let mine: Vec<_> = backups(&store).into_iter().filter(|n| !n.contains("-ffffffff-")).collect();
    assert_eq!(mine.len(), 1, "keep 1 of this monitor's: {all:?}");
    let (_, body) = call(&srv, true, Method::GET, "/api/v1/monitor-backup/list", None).await;
    let listed = body["backups"].as_array().unwrap();
    assert_eq!(listed.len(), 2);
    assert_eq!((listed[0]["own"].clone(), listed[1]["own"].clone()), (json!(true), json!(false)), "{body}");
    assert_eq!(listed[1]["instance"], "ffffffff");

    // Deletes refused: the backup is made and recorded, the failure said once,
    // and nothing is uploaded again while nothing changes.
    store.lock().unwrap().refuse_delete = Some(403);
    snippet(&state, "c").await;
    monitor_backup::check(&state, false).await;
    let (_, view) = call(&srv, true, Method::GET, "/api/v1/monitor-backup", None).await;
    assert_eq!(view["last_error"], "webdav.forbidden");
    let made = view["last_name"].as_str().unwrap().to_string();
    assert!(backups(&store).contains(&made));
    let count = backups(&store).len();
    for _ in 0..3 {
        monitor_backup::check(&state, false).await;
    }
    assert_eq!(backups(&store).len(), count, "no backup sent again");
    assert_eq!(notices(&state, "backup.failed").await, 1);
    // Deletes allowed again: the next check prunes and says so.
    store.lock().unwrap().refuse_delete = None;
    monitor_backup::check(&state, false).await;
    let (_, view) = call(&srv, true, Method::GET, "/api/v1/monitor-backup", None).await;
    assert_eq!(view["last_error"], serde_json::Value::Null);
    assert_eq!(view["last_name"].as_str(), Some(made.as_str()), "the same backup");
    assert_eq!(notices(&state, "backup.back").await, 1);
    assert_eq!(backups(&store).into_iter().filter(|n| !n.contains("-ffffffff-")).count(), 1);

    // Turned off: a run is refused, not silently skipped.
    let (status, _) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(save(false, 1, &folder))).await;
    assert_eq!(status, 200);
    let (status, body) = call(&srv, true, Method::POST, "/api/v1/monitor-backup/run", None).await;
    assert_eq!((status, body["error"].as_str()), (409, Some("disabled")));

    // Another folder: no key, no last backup or failure from the old one.
    store.lock().unwrap().refuse_put = Some(507);
    monitor_backup::check(&state, true).await;
    let (_, body) = call(&srv, true, Method::PUT, "/api/v1/monitor-backup", Some(save(true, 1, &format!("{folder}-2")))).await;
    assert_eq!((body["key_id"].clone(), body["last_name"].clone(), body["last_error"].clone()), (json!(null), json!(null), json!(null)), "{body}");
}
