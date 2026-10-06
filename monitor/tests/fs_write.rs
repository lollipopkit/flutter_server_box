//! `PUT /api/v1/fs/write` — writing under the roots, and the optional
//! `if_version` that lets the panel's editor refuse to overwrite someone
//! else's change.
//!
//! The roots themselves, and every escape route out of them, are `fs_roots.rs`
//! and `fs_protected.rs`; this is only the write handler's own contract.

mod common;

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
        common::grants_of(&state.db, "admin")
            .await
            .files
            .unwrap()
            .allows_write(),
        "the admin role the suite seeds must be able to write"
    );
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .route(
                        "/fs/write",
                        web::put().to(server_box_monitor::api::fs::write),
                    )
                    .route("/fs/stat", web::get().to(server_box_monitor::api::fs::stat)),
            )
        }
    })
    .await
}

/// One request with a bearer token, and its status and JSON body.
async fn call(
    srv: &TestServer,
    method: Method,
    path: &str,
    body: Option<&str>,
) -> (u16, serde_json::Value) {
    let req = srv
        .request(method, srv.url(path))
        .timeout(std::time::Duration::from_secs(30))
        .header(
            "Authorization",
            format!("Bearer {}", generate_token("admin", SECRET).unwrap()),
        );
    let resp = match body {
        Some(body) => req.send_body(body.as_bytes().to_vec()).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let status = resp.status().as_u16();
    let bytes = resp.body().limit(1 << 20).await.unwrap_or_default();
    (
        status,
        serde_json::from_slice(&bytes).unwrap_or(serde_json::Value::Null),
    )
}

/// One write, and its status and body.
async fn write(
    srv: &TestServer,
    path: &str,
    if_version: Option<&str>,
    body: &str,
) -> (u16, serde_json::Value) {
    let mut target = format!("/api/v1/fs/write?path={}", urlencode(path));
    if let Some(version) = if_version {
        target.push_str(&format!("&if_version={}", urlencode(version)));
    }
    call(srv, Method::PUT, &target, Some(body)).await
}

/// The `version` the listing reports for a path — what an editor saves back.
async fn version_of(srv: &TestServer, path: &str) -> String {
    let (status, body) = call(
        srv,
        Method::GET,
        &format!("/api/v1/fs/stat?path={}", urlencode(path)),
        None,
    )
    .await;
    assert_eq!(status, 200, "{body}");
    body["version"]
        .as_str()
        .unwrap_or_else(|| panic!("no version in {body}"))
        .to_owned()
}

/// Enough of percent-encoding for a path or a token in a query string: a temp
/// path carries `/` (legal unencoded) and the token carries `-`.
fn urlencode(value: &str) -> String {
    value.replace(' ', "%20")
}

#[ntex::test]
async fn a_matching_version_writes() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("note.txt");
    std::fs::write(&path, "before").unwrap();
    let root = std::fs::canonicalize(dir.path()).unwrap();
    let srv = server(&root.to_string_lossy()).await;
    let version = version_of(&srv, path.to_str().unwrap()).await;

    let (status, _) = write(&srv, path.to_str().unwrap(), Some(&version), "after").await;

    assert_eq!(status, 200);
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "after");
}

#[ntex::test]
async fn a_mismatched_version_is_refused_and_leaves_the_file_alone() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("note.txt");
    std::fs::write(&path, "before").unwrap();
    let root = std::fs::canonicalize(dir.path()).unwrap();
    let srv = server(&root.to_string_lossy()).await;

    let (status, body) = write(&srv, path.to_str().unwrap(), Some("1-1"), "after").await;

    assert_eq!(status, 409);
    assert_eq!(body["error"], "modified");
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "before");
}

/// The reason the token is not the second-resolution time: two writes inside
/// one second are the ordinary case for an editor, and the second one — sent
/// with what the caller read before the first — must still be refused.
#[ntex::test]
async fn a_second_write_in_the_same_second_is_refused() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("note.txt");
    std::fs::write(&path, "x").unwrap();
    let root = std::fs::canonicalize(dir.path()).unwrap();
    let srv = server(&root.to_string_lossy()).await;
    let version = version_of(&srv, path.to_str().unwrap()).await;

    // The larger body makes this deterministic even on a filesystem whose
    // clock has no sub-second resolution: the size alone changes the token.
    let (status, _) = write(&srv, path.to_str().unwrap(), Some(&version), "aaaa").await;
    assert_eq!(status, 200);

    let (status, body) = write(&srv, path.to_str().unwrap(), Some(&version), "bbbb").await;
    assert_eq!(status, 409, "{body}");
    assert_eq!(std::fs::read_to_string(&path).unwrap(), "aaaa");
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

    let (status, body) = write(&srv, path.to_str().unwrap(), Some("1-1"), "new").await;

    assert_eq!(status, 409);
    assert_eq!(body["error"], "modified");
    // Not recreated: the point of the check is that a save cannot bring back a
    // file someone removed while it was open.
    assert!(!path.exists());
}

/// What a listing reports is what the guard takes: the two are one token, and
/// a client never composes one.
#[ntex::test]
async fn the_version_changes_when_the_file_does() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("note.txt");
    std::fs::write(&path, "one").unwrap();
    let root = std::fs::canonicalize(dir.path()).unwrap();
    let srv = server(&root.to_string_lossy()).await;

    let first = version_of(&srv, path.to_str().unwrap()).await;
    let (status, _) = write(&srv, path.to_str().unwrap(), Some(&first), "one!").await;
    assert_eq!(status, 200);
    let second = version_of(&srv, path.to_str().unwrap()).await;

    assert_ne!(first, second);
    // And the new one is what the next save needs.
    let (status, _) = write(&srv, path.to_str().unwrap(), Some(&second), "one!!").await;
    assert_eq!(status, 200);
}
