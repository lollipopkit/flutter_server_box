//! `GET/PUT /api/v1/backup/*` end to end: the real route table, a real
//! `config.toml`, and a store this test owns under a temp directory.
//!
//! Four things here cannot be shown by a unit test, because each is a decision
//! that spans the wire:
//!
//! - **A blob is bytes, not text.** What goes in comes back identical for a
//!   body that is not valid UTF-8, which is the whole claim: the app's backup
//!   is ciphertext, so anything that decoded it on the way through would be
//!   corrupting the one thing this store must not touch.
//! - **A name is a name, not a path.** The names that would address a file
//!   outside the store are refused, and the test checks the outside file is
//!   still absent rather than only that the status was 400.
//! - **The cap is the body's, not the request's.** A body over `[backup]
//!   max_bytes` is refused *and* leaves nothing behind, which is the difference
//!   between a bound and a truncated file.
//! - **Reading is not writing.** The store is readable without the shell grant
//!   and changeable only with it, and the configuration pair is neither: that
//!   file holds every write-only credential the agent has, so it is
//!   `full_access` in both directions.
//!
//! `config_file::CONFIG_PATH` is relative to the process working directory, and
//! `[backup] dir` is set per test into the same tree — so nothing here writes
//! the operator's `config.toml` or the default store under their home. The
//! tests serialise on one lock because they share that file.

use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, Once, OnceLock};

use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use rustls::crypto::ring;
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use tokio::sync::{Mutex as AsyncMutex, MutexGuard};

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// A directory of its own, once, handed out with the lock that keeps these
/// tests from writing each other's `config.toml`.
async fn workspace() -> MutexGuard<'static, PathBuf> {
    static DIR: OnceLock<AsyncMutex<PathBuf>> = OnceLock::new();
    let dir = DIR.get_or_init(|| {
        let dir = std::env::temp_dir().join(format!("sbm-backup-api-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
        AsyncMutex::new(dir)
    });
    dir.lock().await
}

/// A config whose store is `name` under this test's own directory, and whose
/// cap is `cap`.
///
/// The name is per test because the working directory is not: a store directly
/// in it would be one store shared by every test in this file, and each one's
/// blobs would appear in the others' listings.
fn write_config(dir: &Path, name: &str, cap: u64) -> PathBuf {
    let store = dir.join(name);
    let text = format!(
        r#"
[server]
host = "127.0.0.1"
port = 3770
name = "test"

[remote_access]
full_access = true

[remote_access.terminal]
enabled = true

[backup]
dir = "{store}"
max_bytes = {cap}
"#,
        store = store.display()
    );
    std::fs::write("config.toml", text).unwrap();
    store
}

async fn app_state(full_access: bool) -> (Arc<AppState>, sqlx::SqlitePool) {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    // The grant is gated on the terminal being available, so that switching the
    // terminal off cannot leave this door open behind it. The test server
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
/// property of [`configure_api`], and this endpoint is three lines in it.
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

// ------------------------------------------------------------- the panel

/// A request as its status and its raw body, because the body of a download is
/// bytes rather than a document.
async fn raw(
    srv: &TestServer,
    method: ntex::http::Method,
    path: &str,
    body: Option<Vec<u8>>,
) -> (u16, Vec<u8>) {
    let request = srv
        .request(method, srv.url(path))
        .header("Authorization", format!("Bearer {}", jwt()));
    let resp = match body {
        Some(body) => request.send_body(body).await.unwrap(),
        None => request.send().await.unwrap(),
    };
    let status = resp.status().as_u16();
    (status, resp.body().await.unwrap().to_vec())
}

async fn get_json(srv: &TestServer, path: &str) -> Result<Value, (u16, String)> {
    let (status, body) = raw(srv, ntex::http::Method::GET, path, None).await;
    let text = String::from_utf8_lossy(&body).into_owned();
    let value: Value = serde_json::from_str(&text).unwrap_or(Value::Null);
    if !(200..300).contains(&status) {
        return Err((status, error_code(&value)));
    }
    Ok(value)
}

fn error_code(body: &Value) -> String {
    body["error"].as_str().unwrap_or_default().to_string()
}

/// A refused request as its status and code. Anything a handler *accepts*
/// answers 2xx, so a test that only wanted the refusal can say so.
async fn refused(srv: &TestServer, method: ntex::http::Method, path: &str, body: &[u8]) -> (u16, String) {
    let (status, body) = raw(srv, method, path, Some(body.to_vec())).await;
    let value: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    (status, error_code(&value))
}

async fn put_blob(srv: &TestServer, name: &str, bytes: &[u8]) -> Result<Value, (u16, String)> {
    let (status, body) = raw(
        srv,
        ntex::http::Method::PUT,
        &format!("/api/v1/backup/blob?name={name}"),
        Some(bytes.to_vec()),
    )
    .await;
    let value: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    if !(200..300).contains(&status) {
        return Err((status, error_code(&value)));
    }
    Ok(value)
}

async fn get_blob(srv: &TestServer, name: &str) -> (u16, Vec<u8>) {
    raw(
        srv,
        ntex::http::Method::GET,
        &format!("/api/v1/backup/blob?name={name}"),
        None,
    )
    .await
}

async fn delete_blob(srv: &TestServer, name: &str) -> (u16, String) {
    let (status, body) = raw(
        srv,
        ntex::http::Method::DELETE,
        &format!("/api/v1/backup/blob?name={name}"),
        None,
    )
    .await;
    let value: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    (status, error_code(&value))
}

async fn export_config(srv: &TestServer) -> (u16, String) {
    let (status, body) = raw(srv, ntex::http::Method::GET, "/api/v1/backup/config", None).await;
    (status, String::from_utf8_lossy(&body).into_owned())
}

async fn import_config(srv: &TestServer, text: &str) -> (u16, String) {
    let (status, body) = raw(
        srv,
        ntex::http::Method::PUT,
        "/api/v1/backup/config",
        Some(text.as_bytes().to_vec()),
    )
    .await;
    let value: Value = serde_json::from_slice(&body).unwrap_or(Value::Null);
    (status, error_code(&value))
}

// ------------------------------------------------------------- the tests

#[ntex::test]
async fn a_fresh_store_lists_nothing() {
    let dir = workspace().await;
    write_config(&dir, "fresh", 1024);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let body = get_json(&srv, "/api/v1/backup").await.expect("a listing");
    assert_eq!(body["blobs"], json!([]));
    assert_eq!(body["max_bytes"], 1024);
    assert_eq!(body["editable"], true);
}

/// The claim the whole feature rests on: what went in comes back.
///
/// The body is deliberately not valid UTF-8 — the app's backup is ciphertext by
/// the time it arrives, and anything on the way through that decoded it would
/// be corrupting the one thing this store must not touch.
#[ntex::test]
async fn a_blob_round_trips_byte_for_byte() {
    let dir = workspace().await;
    write_config(&dir, "round-trip", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let bytes: Vec<u8> = (0u16..=255).map(|b| b as u8).chain([0xff, 0x00, 0xfe]).collect();
    let stored = put_blob(&srv, "srvbox_bak_v3.json", &bytes).await.expect("a store");
    assert_eq!(stored["name"], "srvbox_bak_v3.json");
    assert_eq!(stored["size"], bytes.len() as u64);
    assert!(stored["updated_at"].as_str().is_some_and(|t| !t.is_empty()));

    let (status, got) = get_blob(&srv, "srvbox_bak_v3.json").await;
    assert_eq!(status, 200);
    assert_eq!(got, bytes, "the bytes changed on the way through");

    let listed = get_json(&srv, "/api/v1/backup").await.expect("a listing");
    assert_eq!(listed["blobs"][0]["name"], "srvbox_bak_v3.json");
    assert_eq!(listed["blobs"][0]["size"], bytes.len() as u64);

    // And gone when it is dropped.
    let (status, _) = delete_blob(&srv, "srvbox_bak_v3.json").await;
    assert_eq!(status, 200);
    let listed = get_json(&srv, "/api/v1/backup").await.expect("a listing");
    assert_eq!(listed["blobs"], json!([]));
}

#[ntex::test]
async fn storing_a_name_that_exists_replaces_it() {
    let dir = workspace().await;
    write_config(&dir, "replace", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    put_blob(&srv, "one", b"first").await.expect("a store");
    put_blob(&srv, "one", b"second").await.expect("a replace");

    let (_, got) = get_blob(&srv, "one").await;
    assert_eq!(got, b"second");
    let listed = get_json(&srv, "/api/v1/backup").await.expect("a listing");
    assert_eq!(
        listed["blobs"].as_array().unwrap().len(),
        1,
        "a replace left the old one behind",
    );
}

/// A name is a name and not a path.
///
/// The assertion that matters is the second one: a refused name must not have
/// written anything outside the store, and a 400 alone would not say that.
#[ntex::test]
async fn a_name_that_would_address_another_file_is_refused() {
    let dir = workspace().await;
    write_config(&dir, "name", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    for name in [
        "..",
        "../escape",
        "a/b",
        "a\\b",
        ".hidden",
        "",
        &"x".repeat(129),
    ] {
        let (status, code) = refused(
            &srv,
            ntex::http::Method::PUT,
            &format!("/api/v1/backup/blob?name={name}"),
            b"x",
        )
        .await;
        assert_eq!((status, code.as_str()), (400, "invalidName"), "{name:?}");

        let (status, code) = delete_blob(&srv, name).await;
        assert_eq!((status, code.as_str()), (400, "invalidName"), "{name:?}");
    }

    let written: Vec<String> = std::fs::read_dir(dir.join("name"))
        .map(|entries| {
            entries
                .flatten()
                .map(|e| e.file_name().to_string_lossy().into_owned())
                .collect()
        })
        .unwrap_or_default();
    assert!(written.is_empty(), "a refused name wrote something: {written:?}");
    assert!(
        !dir.join("escape").exists(),
        "a refused name wrote outside the store",
    );
}

/// The cap is the body's. Over it, the request is refused *and* the store is
/// left as it was — which is the difference between a bound and a truncation.
#[ntex::test]
async fn a_body_over_the_cap_is_refused_and_leaves_nothing() {
    let dir = workspace().await;
    write_config(&dir, "cap", 16);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    assert_eq!(
        put_blob(&srv, "big", &[b'x'; 32]).await.unwrap_err(),
        (413, "tooLarge".to_string()),
    );

    let listed = get_json(&srv, "/api/v1/backup").await.expect("a listing");
    assert_eq!(listed["blobs"], json!([]), "a refused upload left a file behind");
    assert_eq!(get_blob(&srv, "big").await.0, 404);
}

#[ntex::test]
async fn a_blob_that_is_not_there_is_answered_as_such() {
    let dir = workspace().await;
    write_config(&dir, "cap", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    assert_eq!(get_blob(&srv, "absent").await.0, 404);
    assert_eq!(delete_blob(&srv, "absent").await, (404, "noSuchBlob".to_string()));
}

/// Reading is not writing, which is `cron`'s and `pve`'s rule here too — with
/// one exception, and this asserts both halves of it.
#[ntex::test]
async fn reading_needs_only_the_panel_login() {
    let dir = workspace().await;
    write_config(&dir, "absent", 4096);
    let (state, _permissive_db) = app_state(true).await;
    let srv = test_server(state).await;
    put_blob(&srv, "kept", b"bytes").await.expect("a store");

    // The state the refusals are recorded against, which is this one: each
    // `app_state` has its own in-memory database.
    let (state, db) = app_state(false).await;
    let restricted = test_server(state).await;

    // Readable either way.
    let listed = get_json(&restricted, "/api/v1/backup").await.expect("a listing");
    assert_eq!(listed["editable"], false);
    assert_eq!(listed["blobs"][0]["name"], "kept");
    assert_eq!(get_blob(&restricted, "kept").await, (200, b"bytes".to_vec()));

    // Changeable only with the grant.
    assert_eq!(
        refused(
            &restricted,
            ntex::http::Method::PUT,
            "/api/v1/backup/blob?name=other",
            b"x",
        )
        .await
        .0,
        403,
    );
    assert_eq!(delete_blob(&restricted, "kept").await.0, 403);

    // And the configuration is neither direction: that file holds every
    // write-only credential this agent has.
    assert_eq!(export_config(&restricted).await.0, 403);
    assert_eq!(import_config(&restricted, "x = 1").await.0, 403);

    // A refusal is what someone reading this table is looking for, and it has
    // no subject: nothing was named.
    let (kind, action, result, subject): (String, String, String, Option<String>) = sqlx::query_as(
        "SELECT kind, action, result, subject FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();
    assert_eq!((kind.as_str(), action.as_str(), result.as_str()), ("backup", "denied", "denied"));
    assert_eq!(subject, None);
}

/// A row says a name was stored and how large it was, and never what is in it.
#[ntex::test]
async fn the_audit_row_names_the_blob_and_not_its_contents() {
    let dir = workspace().await;
    write_config(&dir, "reading", 4096);
    let (state, db) = app_state(true).await;
    let srv = test_server(state).await;

    put_blob(&srv, "srvbox_bak_v3.json", b"secret-looking-bytes").await.expect("a store");

    let (kind, action, result, subject, detail): (String, String, String, Option<String>, Option<String>) =
        sqlx::query_as("SELECT kind, action, result, subject, detail FROM access_log ORDER BY id DESC LIMIT 1")
            .fetch_one(&db)
            .await
            .unwrap();
    assert_eq!((kind.as_str(), action.as_str(), result.as_str()), ("backup", "write", "ok"));
    assert_eq!(subject.as_deref(), Some("srvbox_bak_v3.json"));
    assert_eq!(detail.as_deref(), Some("20 bytes"));
    assert!(
        !detail.unwrap_or_default().contains("secret"),
        "the row carried the blob's contents",
    );
}

#[ntex::test]
async fn the_config_can_be_exported_and_imported() {
    let dir = workspace().await;
    write_config(&dir, "audit", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let (status, exported) = export_config(&srv).await;
    assert_eq!(status, 200);
    assert!(exported.contains("[backup]"), "the export is not the file: {exported}");

    // The same text back, which is what an unchanged export-and-import is.
    let (status, code) = import_config(&srv, &exported).await;
    assert_eq!((status, code.as_str()), (200, ""));
    assert_eq!(std::fs::read_to_string("config.toml").unwrap(), exported);
}

#[ntex::test]
async fn an_imported_config_keeps_what_this_build_does_not_know() {
    let dir = workspace().await;
    write_config(&dir, "config", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    // A comment and a key no build reads. Both survive because what is written
    // is the caller's own text and not a reserialization of the struct.
    let uploaded = format!(
        "{}\n# the operator's own note\n[future]\nsomething = 1\n",
        std::fs::read_to_string("config.toml").unwrap(),
    );
    let (status, code) = import_config(&srv, &uploaded).await;
    assert_eq!((status, code.as_str()), (200, ""));

    let written = std::fs::read_to_string("config.toml").unwrap();
    assert!(written.contains("the operator's own note"), "the comment was lost");
    assert!(written.contains("[future]"), "an unknown section was dropped");
}

/// The two keys a file must not be able to change, refused by name so the
/// operator knows which line to take out.
#[ntex::test]
async fn an_import_that_would_change_who_can_log_in_is_refused() {
    let dir = workspace().await;
    write_config(&dir, "unknown", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    let before = std::fs::read_to_string("config.toml").unwrap();

    // Prepended, because a key after the last section belongs to that section:
    // `[backup] jwt_secret` is not the top-level one and would be accepted.
    let other_secret = format!("jwt_secret = \"a-different-secret-entirely-32ch\"\n{before}");
    assert_eq!(
        import_config(&srv, &other_secret).await,
        (400, "jwtSecretDiffers".to_string()),
    );

    let other_db = format!("database_url = \"sqlite:elsewhere.db\"\n{before}");
    assert_eq!(
        import_config(&srv, &other_db).await,
        (400, "databaseUrlDiffers".to_string()),
    );

    // A file naming neither is accepted: a default install keeps both in `.env`.
    assert_eq!(import_config(&srv, &before).await.1, "");
    assert_eq!(
        std::fs::read_to_string("config.toml").unwrap(),
        before,
        "a refused import changed the file",
    );
}

/// The imported text is the text that lands, byte for byte.
///
/// The body is sent split *inside* a multi-byte character, which is what a real
/// transfer does whenever a chunk boundary happens to fall there — and the
/// handler writes this very text to disk, so decoding each chunk on its own
/// would put replacement characters into the file the operator asked for.
#[ntex::test]
async fn an_imported_config_keeps_a_character_that_straddles_a_chunk() {
    let dir = workspace().await;
    write_config(&dir, "split", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    let before = std::fs::read_to_string("config.toml").unwrap();

    // One comment with a two-byte and a three-byte character in it, plus the
    // config itself so the file is one this agent would accept.
    let comment = "# 中 · ça va — ok\n";
    let text = format!("{comment}{before}");
    let bytes = text.as_bytes().to_vec();

    // One byte per chunk through the comment, so every character in it lands
    // across a boundary; the rest in the sizes a real transfer uses, since a
    // handler that only survived the pathological case would be one that
    // mishandled an ordinary one.
    let mut chunks: Vec<Vec<u8>> = comment.as_bytes().iter().map(|b| vec![*b]).collect();
    for chunk in bytes[comment.len()..].chunks(32) {
        chunks.push(chunk.to_vec());
    }

    let stream = futures::stream::iter(
        chunks
            .into_iter()
            .map(|chunk| Ok::<_, std::io::Error>(ntex::util::Bytes::from(chunk))),
    );
    let resp = srv
        .put("/api/v1/backup/config")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_stream(stream)
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 200);

    let written = std::fs::read_to_string("config.toml").unwrap();
    assert!(
        written.contains(comment),
        "the comment did not survive the round trip: {written:?}",
    );
    assert!(!written.contains('\u{fffd}'), "a replacement character was written");
}

#[ntex::test]
async fn an_import_that_is_not_a_config_is_refused() {
    let dir = workspace().await;
    write_config(&dir, "secret", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    let before = std::fs::read_to_string("config.toml").unwrap();

    assert_eq!(
        import_config(&srv, "this is not toml at all [").await,
        (400, "invalidConfig".to_string()),
    );
    assert_eq!(
        std::fs::read_to_string("config.toml").unwrap(),
        before,
        "a refused import changed the file",
    );
}

#[ntex::test]
async fn capabilities_say_this_agent_serves_backup() {
    let dir = workspace().await;
    write_config(&dir, "invalid", 4096);
    let (state, _db) = app_state(false).await;
    let srv = test_server(state).await;

    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    let body: Value = resp.json().await.unwrap();

    assert_eq!(body["remote_access"]["backup"], true);
    assert_eq!(body["remote_access"]["full_access"], false);
}

/// The store is created owner-only, for the reason `ensure_script` learned: a
/// directory another local account can enter is one where the file can be
/// swapped between the write and the read that follows.
#[cfg(unix)]
#[ntex::test]
async fn the_store_is_owner_only() {
    use std::os::unix::fs::PermissionsExt;

    let dir = workspace().await;
    let store = write_config(&dir, "owner-only", 4096);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    get_json(&srv, "/api/v1/backup").await.expect("a listing");

    let mode = std::fs::metadata(store).unwrap().permissions().mode() & 0o777;
    assert_eq!(mode, 0o700, "the store is readable by other accounts");
}

/// The lock the other tests serialise on, held for the whole of each test body
/// above. Named here so the reason is written down once: `config.toml` and the
/// store are one tree, and two tests writing it at once would interleave.
#[allow(dead_code)]
fn serialised() -> Mutex<()> {
    Mutex::new(())
}
