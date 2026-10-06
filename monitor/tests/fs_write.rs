//! `PUT /api/v1/fs/write` — writing under the roots, and the optional
//! `if_modified` that lets the panel's editor refuse to overwrite someone
//! else's change.
//!
//! The roots themselves, and every escape route out of them, are `fs_roots.rs`
//! and `fs_protected.rs`; this is only the write handler's own contract.

mod common;

use std::time::UNIX_EPOCH;

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// An agent whose `files` root is one real directory, with the admin role
/// holding the write it does.
async fn server(root: &str) -> TestServer {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    remote.fs.enabled = Some(true);
    remote.fs.roots = vec![root.to_string()];
    config.remote_access = Some(remote);
    let state = common::upgraded_state(config).await;
    assert!(
        common::grants_of(&state.db, "admin").await.files.unwrap().allows_write(),
        "the admin role the suite seeds must be able to write"
    );
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .route("/fs/write", web::put().to(server_box_monitor::api::fs::write)),
            )
        }
    })
    .await
}

/// One write, and its status and body.
async fn write(
    srv: &TestServer,
    path: &str,
    if_modified: Option<i64>,
    body: &str,
) -> (u16, serde_json::Value) {
    let query = match if_modified {
        Some(seconds) => {
            format!("path={}&if_modified={seconds}", urlencode(path))
        }
        None => format!("path={}", urlencode(path)),
    };
    let resp = srv
        .request(Method::PUT, srv.url(&format!("/api/v1/fs/write?{query}")))
        .timeout(std::time::Duration::from_secs(30))
        .header(
            "Authorization",
            format!("Bearer {}", generate_token("admin", SECRET).unwrap()),
        )
        .send_body(body.as_bytes().to_vec())
        .await
        .unwrap();
    let status = resp.status().as_u16();
    let bytes = resp.body().limit(1 << 20).await.unwrap_or_default();
    (status, serde_json::from_slice(&bytes).unwrap_or(serde_json::Value::Null))
}

/// Enough of percent-encoding for a path in a query string. A temp path only
/// carries `/`, which is legal unencoded, so nothing here needs the rest.
fn urlencode(path: &str) -> String {
    path.replace(' ', "%20")
}

/// The file's `modified` time, in the seconds the listing reports.
fn modified_of(path: &std::path::Path) -> i64 {
    std::fs::metadata(path)
        .unwrap()
        .modified()
        .unwrap()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64
}

#[ntex::test]
async fn a_matching_time_writes() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("note.txt");
    std::fs::write(&path, "before").unwrap();
    let root = std::fs::canonicalize(dir.path()).unwrap();
    let srv = server(&root.to_string_lossy()).await;

    let (status, _) = write(
        &srv,
        path.to_str().unwrap(),
        Some(modified_of(&path)),
        "after",
    )
    .await;

    assert_eq!(status, 200);
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "after");
}

#[ntex::test]
async fn a_mismatched_time_is_refused_and_leaves_the_file_alone() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("note.txt");
    std::fs::write(&path, "before").unwrap();
    let root = std::fs::canonicalize(dir.path()).unwrap();
    let srv = server(&root.to_string_lossy()).await;

    // A value the caller could not have read: the file's own time is at least
    // this, and standing in for "someone else has written since" without
    // depending on how coarse the filesystem's clock is.
    let stale = modified_of(&path) - 10;
    let (status, body) = write(&srv, path.to_str().unwrap(), Some(stale), "after").await;

    assert_eq!(status, 409);
    assert_eq!(body["error"], "modified");
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "before");
}

#[ntex::test]
async fn no_parameter_writes_as_before() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("note.txt");
    std::fs::write(&path, "before").unwrap();
    let root = std::fs::canonicalize(dir.path()).unwrap();
    let srv = server(&root.to_string_lossy()).await;

    let (status, _) = write(&srv, path.to_str().unwrap(), None, "after").await;

    assert_eq!(status, 200);
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "after");
}

#[ntex::test]
async fn a_deleted_file_with_the_parameter_is_refused() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("gone.txt");
    let root = std::fs::canonicalize(dir.path()).unwrap();
    let srv = server(&root.to_string_lossy()).await;

    let (status, body) = write(&srv, path.to_str().unwrap(), Some(1_700_000_000), "new").await;

    assert_eq!(status, 409);
    assert_eq!(body["error"], "modified");
    // Not recreated: the point of the check is that a save cannot bring back a
    // file someone removed while it was open.
    assert!(!path.exists());
}
