//! `/api/v1/apps*`: desk app packages an admin installs and approves, and
//! the sandboxed UI they are served as.

mod common;

use std::io::Read;
use std::sync::Arc;

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::json;
use server_box_monitor::api::{app_backend, apps};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::agent_mode::config;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;

const PLAIN: &str = "line one\nline two\nline three";
const SECRET: &str = "test-secret-that-is-long-enough-32ch";

async fn server() -> TestServer {
    server_on(common::database().await).await
}

async fn server_on(db: sqlx::SqlitePool) -> TestServer {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let config = Config { jwt_secret: Some(SECRET.to_string()), ..Default::default() };
    common::add_owner(&db).await;
    let state: Arc<AppState> = AppState::new(Arc::new(config), db);
    web_test::server(move || {
        let state = state.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .service(
                        web::resource("/apps")
                            .state(web::types::PayloadConfig::new(apps::MAX_PACKAGE_BYTES))
                            .route(web::get().to(apps::list))
                            .route(web::post().to(apps::install)),
                    )
                    .service(web::resource("/apps/catalog").route(web::get().to(apps::catalog)))
                    // What a backend's HTTP reaches in `http` tests.
                    .service(web::resource("/plain").route(web::get().to(|| async { web::HttpResponse::Ok().body(PLAIN) })))
                    .service(web::resource("/moved").route(web::get().to(|| async { web::HttpResponse::Found().header("location", "/api/v1/plain").finish() })))
                    .service(web::resource("/apps/catalog/{id}/install").route(web::post().to(apps::install_offered)))
                    .service(web::resource("/apps/{id}").route(web::delete().to(apps::remove)))
                    .service(web::resource("/apps/{id}/approval").route(web::put().to(apps::approve)))
                    .service(web::resource("/apps/{id}/launch").route(web::get().to(apps::launch)))
                    .service(web::resource("/apps/{id}/call").route(web::post().to(app_backend::call)))
                    .service(
                        web::resource("/apps/{id}/jobs").route(web::get().to(app_backend::job)).route(web::post().to(app_backend::start_job)),
                    )
                    .service(web::resource("/apps/{id}/jobs/cancel").route(web::post().to(app_backend::cancel_job)))
                    .service(web::resource("/apps/{id}/ui/{ticket}/{path}*").route(web::get().to(apps::ui))),
            )
        }
    })
    .await
}

struct Reply {
    status: u16,
    json: serde_json::Value,
    headers: ntex::http::HeaderMap,
    bytes: Vec<u8>,
}

async fn call(srv: &TestServer, signed: bool, method: Method, path: &str, body: Option<(Vec<u8>, &str)>) -> Reply {
    let mut req = srv.request(method, srv.url(path)).timeout(std::time::Duration::from_secs(30));
    if signed {
        req = req.header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()));
    }
    let resp = match body {
        Some((body, kind)) => req.header("content-type", kind).send_body(body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let bytes = resp.body().limit(32 << 20).await.unwrap_or_default().to_vec();
    Reply {
        status: resp.status().as_u16(),
        json: serde_json::from_slice(&bytes).unwrap_or(serde_json::Value::Null),
        headers: resp.headers().clone(),
        bytes,
    }
}

fn manifest(permissions: &[&str]) -> serde_json::Value {
    json!({
        "publisher": "acme", "name": "notes", "version": "1.0.0", "api": 1, "kind": "web",
        "title": { "en": "Notes" }, "glyph": "sticky_note_2", "tone": "amber",
        "permissions": permissions,
    })
}

/// A package of [entries]: (path, bytes) as regular files, or a symlink when
/// the bytes start with `->`.
fn package(entries: &[(&str, Vec<u8>)]) -> Vec<u8> {
    let mut builder = tar::Builder::new(flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast()));
    for (path, data) in entries {
        let mut header = tar::Header::new_gnu();
        if let Some(target) = data.strip_prefix(b"->") {
            header.set_entry_type(tar::EntryType::Symlink);
            header.set_size(0);
            header.set_mode(0o777);
            builder.append_link(&mut header, path, std::str::from_utf8(target).unwrap()).unwrap();
        } else {
            header.set_size(data.len() as u64);
            header.set_mode(0o644);
            header.set_entry_type(tar::EntryType::Regular);
            // Written raw, so the paths a builder would refuse reach the agent.
            let name = path.as_bytes();
            header.as_old_mut().name[..name.len()].copy_from_slice(name);
            header.set_cksum();
            builder.append(&header, data.as_slice()).unwrap();
        }
    }
    builder.into_inner().unwrap().finish().unwrap()
}

fn good(permissions: &[&str]) -> Vec<u8> {
    package(&[
        ("manifest.json", manifest(permissions).to_string().into_bytes()),
        ("ui/index.html", b"<!doctype html><script type=module src=app.js></script>".to_vec()),
        ("ui/app.js", b"parent.postMessage({ type: 'ready' }, '*')".to_vec()),
    ])
}

async fn install(srv: &TestServer, bytes: Vec<u8>) -> Reply {
    call(srv, true, Method::POST, "/api/v1/apps", Some((bytes, "application/gzip"))).await
}

/// Approves what is installed now as acme.notes, naming its package.
async fn approve(srv: &TestServer, permissions: &[&str], password: &str) -> Reply {
    let apps = call(srv, true, Method::GET, "/api/v1/apps", None).await.json;
    let sha = apps["apps"][0]["sha256"].as_str().unwrap_or_default().to_string();
    approve_package(srv, &sha, permissions, password).await
}

async fn approve_package(srv: &TestServer, sha256: &str, permissions: &[&str], password: &str) -> Reply {
    let body = json!({ "sha256": sha256, "permissions": permissions, "current_password": password }).to_string().into_bytes();
    call(srv, true, Method::PUT, "/api/v1/apps/acme.notes/approval", Some((body, "application/json"))).await
}

#[ntex::test]
async fn an_app_is_served_only_once_approved_and_only_with_a_ticket() {
    let srv = server().await;

    let r = install(&srv, good(&["notifications"])).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert!(r.json["approved_permissions"].is_null());

    // Waiting: listed, and nothing serves it.
    let r = call(&srv, true, Method::GET, "/api/v1/apps", None).await;
    assert_eq!(r.json["apps"][0]["id"], "acme.notes");
    assert_eq!(call(&srv, true, Method::GET, "/api/v1/apps/acme.notes/launch", None).await.status, 404);

    // Approval asks for the password and for exactly what the manifest lists.
    assert_eq!(approve(&srv, &["notifications"], "wrong").await.status, 403);
    assert_eq!(approve(&srv, &[], common::PASSWORD).await.status, 409);
    let r = approve(&srv, &["notifications"], common::PASSWORD).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert_eq!(r.json["approved_permissions"], json!(["notifications"]));

    let r = call(&srv, true, Method::GET, "/api/v1/apps/acme.notes/launch", None).await;
    assert_eq!(r.status, 200);
    let url = r.json["url"].as_str().unwrap().to_string();
    assert!(url.ends_with("/index.html"));

    // The UI: no bearer needed, the ticket is the key; sandboxed, no network.
    let r = call(&srv, false, Method::GET, &url, None).await;
    assert_eq!(r.status, 200);
    let csp = r.headers.get("content-security-policy").unwrap().to_str().unwrap();
    assert!(csp.starts_with("sandbox allow-scripts"), "{csp}");
    assert!(csp.contains("connect-src 'none'"), "{csp}");
    assert_eq!(r.headers.get("x-content-type-options").unwrap(), "nosniff");
    assert!(String::from_utf8_lossy(&r.bytes).contains("app.js"));
    let js = call(&srv, false, Method::GET, &url.replace("index.html", "app.js"), None).await;
    assert_eq!(js.headers.get("content-type").unwrap(), "text/javascript; charset=utf-8");

    // A ticket whose MAC is not the agent's opens nothing.
    let ticket = url.split('/').nth(6).unwrap();
    let expiry = ticket.split('.').next().unwrap();
    let forged = url.replace(ticket, &format!("{expiry}.{}", "0".repeat(64)));
    assert_eq!(call(&srv, false, Method::GET, &forged, None).await.status, 403);
    for path in ["../manifest.json", "%2e%2e/manifest.json", "missing.js"] {
        let r = call(&srv, false, Method::GET, &url.replace("index.html", path), None).await;
        assert_eq!(r.status, 404, "{path}");
    }
    // The manifest is not part of the UI.
    let r = call(&srv, false, Method::GET, &url.replace("index.html", "../manifest.json"), None).await;
    assert!(!String::from_utf8_lossy(&r.bytes).contains("\"publisher\""));
}

#[ntex::test]
async fn new_code_waits_for_approval_again() {
    let srv = server().await;
    install(&srv, good(&["notifications"])).await;
    approve(&srv, &["notifications"], common::PASSWORD).await;

    let r = install(&srv, good(&["notifications"])).await;
    assert_eq!(r.json["approved_permissions"], json!(["notifications"]), "the same package: still approved");
    // Other code under the same version and asks: an upload needs no
    // password, so it never inherits an approval.
    let mut other = manifest(&["notifications"]);
    other["title"] = json!("Notes 2");
    let r = install(&srv, package(&[("manifest.json", other.to_string().into_bytes()), ("ui/index.html", b"x".to_vec())])).await;
    assert!(r.json["approved_permissions"].is_null(), "new code: waits");
    assert_eq!(call(&srv, true, Method::GET, "/api/v1/apps/acme.notes/launch", None).await.status, 404);
}

#[ntex::test]
async fn an_approval_names_the_package_it_was_given_for() {
    let srv = server().await;
    let first = install(&srv, good(&[])).await.json["sha256"].as_str().unwrap().to_string();
    // Replaced while the admin was reading the first.
    let mut other = manifest(&[]);
    other["title"] = json!("Other");
    install(&srv, package(&[("manifest.json", other.to_string().into_bytes()), ("ui/index.html", b"x".to_vec())])).await;
    let r = approve_package(&srv, &first, &[], common::PASSWORD).await;
    assert_eq!(r.status, 409);
    let r = call(&srv, true, Method::GET, "/api/v1/apps", None).await;
    assert!(r.json["apps"][0]["approved_permissions"].is_null());
}

#[ntex::test]
async fn a_built_in_apps_id_is_not_taken() {
    let srv = server().await;
    let mut m = manifest(&[]);
    m["publisher"] = json!("serverbox");
    m["name"] = json!("system_users");
    let r = install(&srv, package(&[("manifest.json", m.to_string().into_bytes()), ("ui/index.html", b"x".to_vec())])).await;
    assert_eq!(r.json["error"], "invalidId");
}

#[ntex::test]
async fn archive_headers_are_bounded_too() {
    let srv = server().await;
    // A GNU long-name header declaring 30 MiB: tar reads such a header whole.
    let mut builder = tar::Builder::new(flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast()));
    let mut header = tar::Header::new_gnu();
    header.set_entry_type(tar::EntryType::GNULongName);
    header.set_size(30 << 20);
    header.as_old_mut().name[..13].copy_from_slice(b"././@LongLink");
    header.set_cksum();
    builder.append(&header, std::io::repeat(b'a').take(30 << 20)).unwrap();
    let bytes = builder.into_inner().unwrap().finish().unwrap();
    let r = install(&srv, bytes).await;
    assert_eq!(r.status, 400, "{}", r.json);
}

#[ntex::test]
async fn removing_asks_for_the_password() {
    let srv = server().await;
    install(&srv, good(&[])).await;
    let wrong = json!({ "current_password": "nope" }).to_string().into_bytes();
    let r = call(&srv, true, Method::DELETE, "/api/v1/apps/acme.notes", Some((wrong, "application/json"))).await;
    assert_eq!(r.status, 403);
    let right = json!({ "current_password": common::PASSWORD }).to_string().into_bytes();
    let r = call(&srv, true, Method::DELETE, "/api/v1/apps/acme.notes", Some((right.clone(), "application/json"))).await;
    assert_eq!(r.status, 204);
    let r = call(&srv, true, Method::DELETE, "/api/v1/apps/acme.notes", Some((right, "application/json"))).await;
    assert_eq!(r.status, 404);
}

#[ntex::test]
async fn a_package_is_refused_whole_for_any_bad_entry() {
    let srv = server().await;
    let m = manifest(&[]).to_string().into_bytes();
    let index = b"<p>hi</p>".to_vec();
    let cases: Vec<(Vec<u8>, u16, &str)> = vec![
        (b"not a package".to_vec(), 400, "notAPackage"),
        (package(&[("ui/index.html", index.clone())]), 400, "noManifest"),
        (package(&[("manifest.json", m.clone())]), 400, "noEntry"),
        (package(&[("manifest.json", m.clone()), ("ui/index.html", index.clone()), ("ui/../../etc/x", b"x".to_vec())]), 400, "invalidPath"),
        (package(&[("manifest.json", m.clone()), ("ui/index.html", index.clone()), ("/etc/x", b"x".to_vec())]), 400, "invalidPath"),
        (package(&[("manifest.json", m.clone()), ("ui/index.html", index.clone()), ("ui/link", b"->/etc/passwd".to_vec())]), 400, "notAFile"),
        (package(&[("manifest.json", m.clone()), ("ui/index.html", index.clone()), ("bin/run", b"x".to_vec())]), 400, "unexpectedFile"),
        (package(&[("manifest.json", b"{".to_vec()), ("ui/index.html", index.clone())]), 400, "invalidManifest"),
        // Small on the wire, past the bound once inflated.
        (package(&[("manifest.json", m.clone()), ("ui/index.html", index.clone()), ("ui/big.bin", vec![0u8; 21 << 20])]), 413, "tooLarge"),
    ];
    for (bytes, status, code) in cases {
        let r = install(&srv, bytes).await;
        assert_eq!((r.status, r.json["error"].as_str()), (status, Some(code)), "{}", r.json);
    }
    let r = call(&srv, true, Method::GET, "/api/v1/apps", None).await;
    assert_eq!(r.json["apps"], json!([]), "nothing kept of a refused package");
}

// ---------------------------------------------------------------------------
// Backends (`kind: wasm`, API 2: a component)
// ---------------------------------------------------------------------------

/// `tests/apps/probe` built for wasm32-wasip2, once per test binary.
fn probe() -> Vec<u8> {
    static WASM: std::sync::OnceLock<Vec<u8>> = std::sync::OnceLock::new();
    WASM.get_or_init(|| {
        let dir = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/apps/probe");
        let target = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../target/app-guests");
        let status = std::process::Command::new(env!("CARGO"))
            .args(["build", "--release", "--target", "wasm32-wasip2", "--manifest-path"])
            .arg(dir.join("Cargo.toml"))
            .arg("--target-dir")
            .arg(&target)
            .env_remove("RUSTFLAGS")
            .status()
            .expect("cargo");
        assert!(status.success(), "building the probe needs `rustup target add wasm32-wasip2`");
        std::fs::read(target.join("wasm32-wasip2/release/sbm_app_probe.wasm")).unwrap()
    })
    .clone()
}

fn wasm_package(wasm: Vec<u8>, permissions: &[&str]) -> Vec<u8> {
    let mut m = manifest(permissions);
    m["kind"] = json!("wasm");
    m["api"] = json!(2);
    package(&[
        ("manifest.json", m.to_string().into_bytes()),
        ("ui/index.html", b"<p>backend</p>".to_vec()),
        ("backend.wasm", wasm),
    ])
}

async fn installed_backend(srv: &TestServer, permissions: &[&str]) {
    let r = install(srv, wasm_package(probe(), permissions)).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert_eq!(approve(srv, permissions, common::PASSWORD).await.status, 200);
}

async fn call_fn(srv: &TestServer, function: &str, args: serde_json::Value) -> Reply {
    let body = json!({ "function": function, "args": args }).to_string().into_bytes();
    call(srv, true, Method::POST, "/api/v1/apps/acme.notes/call", Some((body, "application/json"))).await
}

async fn start_job(srv: &TestServer, function: &str, args: serde_json::Value) -> Reply {
    let body = json!({ "function": function, "args": args }).to_string().into_bytes();
    call(srv, true, Method::POST, "/api/v1/apps/acme.notes/jobs", Some((body, "application/json"))).await
}

/// The job once it is no longer running.
async fn ended(srv: &TestServer) -> serde_json::Value {
    for _ in 0..200 {
        let r = call(srv, true, Method::GET, "/api/v1/apps/acme.notes/jobs", None).await;
        if r.json["state"] != "running" {
            return r.json;
        }
        tokio::time::sleep(std::time::Duration::from_millis(50)).await;
    }
    panic!("the job did not end");
}

#[ntex::test]
async fn a_backend_answers_typed_calls_in_json() {
    let srv = server().await;
    installed_backend(&srv, &[]).await;
    let args = json!({ "text": "hi", "count": 3, "tags": ["a"], "maybeNote": null, "shade": "veryDark", "shape": { "tag": "circle", "val": 2 } });
    let r = call_fn(&srv, "echo", args.clone()).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert_eq!(r.json["value"], args);

    let r = call_fn(&srv, "echo", json!({ "text": "hi", "count": -1, "tags": [], "shade": "light", "shape": { "tag": "noneAtAll" } })).await;
    assert_eq!((r.status, r.json["error"].as_str()), (400, Some("invalidArgument")), "{}", r.json);
    assert_eq!(r.json["message"], "$.count: not an integer in range");
    let r = call_fn(&srv, "echo", json!({ "nope": 1 })).await;
    assert_eq!((r.status, r.json["message"].as_str()), (400, Some("$: unknown parameter nope")));
    assert_eq!(call_fn(&srv, "missing", json!(null)).await.json["error"], "unknownFunction");
    // A job is not a call.
    assert_eq!(call_fn(&srv, "count", json!({ "lines": 1 })).await.status, 404);

    // The app's own error, by gRPC's code.
    let r = call_fn(&srv, "refuse", json!(null)).await;
    assert_eq!((r.status, r.json.clone()), (409, json!({ "error": "failedPrecondition", "message": "notScanned" })));
}

#[ntex::test]
async fn a_backend_is_stopped_by_its_bounds() {
    let srv = server().await;
    installed_backend(&srv, &[]).await;
    // 64 MiB of memory.
    let r = call_fn(&srv, "grow", json!(null)).await;
    assert_eq!((r.status, r.json["error"].as_str()), (422, Some("trap")), "{}", r.json);
    // 10 s of its own work.
    let r = call_fn(&srv, "spin", json!(null)).await;
    assert_eq!((r.status, r.json["error"].as_str()), (422, Some("trap")), "{}", r.json);
    // The agent is still here.
    assert_eq!(call_fn(&srv, "refuse", json!(null)).await.status, 409);
}

#[ntex::test]
async fn host_functions_need_the_permission() {
    let srv = server().await;
    installed_backend(&srv, &[]).await;
    let r = call_fn(&srv, "run", json!({ "script": "echo hi" })).await;
    assert_eq!((r.status, r.json.clone()), (403, json!({ "error": "permissionDenied", "message": "process" })));
    let r = call_fn(&srv, "asRoot", json!({ "script": "id -u" })).await;
    assert_eq!(r.json["message"], "root");

    let srv = server().await;
    installed_backend(&srv, &["process", "root"]).await;
    let r = call_fn(&srv, "run", json!({ "script": "echo hi" })).await;
    assert_eq!(r.json["value"], "hi\n", "{}", r.json);
    // Root needs the desk's sudo password with the call, whatever was
    // approved.
    let r = call_fn(&srv, "asRoot", json!({ "script": "id -u" })).await;
    assert_eq!((r.status, r.json["message"].as_str()), (403, Some("sudo")));
    // `job` is a job's own.
    let r = call_fn(&srv, "lineOutside", json!(null)).await;
    assert_eq!(r.json, json!({ "error": "failedPrecondition", "message": "notAJob" }));
}

#[ntex::test]
async fn providers_and_their_keys_need_their_permission() {
    let db = common::database().await;
    let settings: config::SettingsWrite = serde_json::from_value(json!({
        "model": { "provider": "local", "id": "m" },
        "providers": [{ "id": "local", "name": "Local", "api": "openai-completions", "baseUrl": "http://127.0.0.1:9/v1", "models": [{ "id": "m" }] }],
        "credentials": { "local": "sk-probe" },
    }))
    .unwrap();
    config::store(&db, &settings).await.unwrap();
    let srv = server_on(db).await;
    installed_backend(&srv, &[]).await;
    let r = call_fn(&srv, "providers", json!(null)).await;
    assert_eq!((r.status, r.json.clone()), (403, json!({ "error": "permissionDenied", "message": "providers" })));

    // The same app asking for them, approved again.
    installed_backend(&srv, &["providers"]).await;
    let r = call_fn(&srv, "providers", json!(null)).await;
    assert_eq!(r.json["value"], json!([["local"], "sk-probe"]), "{}", r.json);
}

#[ntex::test]
async fn a_backend_reaches_http_with_the_permission_and_keeps_files_in_its_folder() {
    use sha2::{Digest, Sha256};
    let srv = server().await;
    let url = srv.url("/api/v1/plain");
    installed_backend(&srv, &[]).await;
    let r = call_fn(&srv, "fetchText", json!({ "url": url })).await;
    assert_eq!((r.status, r.json["message"].as_str()), (403, Some("network")));

    installed_backend(&srv, &["network"]).await;
    let r = call_fn(&srv, "fetchText", json!({ "url": url })).await;
    assert_eq!(r.json["value"], json!([200, PLAIN]), "{}", r.json);
    // The last line has no line break.
    let r = call_fn(&srv, "countLines", json!({ "url": url })).await;
    assert_eq!(r.json["value"], 3, "{}", r.json);
    // A plain request follows no redirect; a download does.
    let r = call_fn(&srv, "fetchText", json!({ "url": srv.url("/api/v1/moved") })).await;
    assert_eq!(r.json["value"][0], 302, "{}", r.json);
    let r = call_fn(&srv, "fetchText", json!({ "url": "file:///etc/passwd" })).await;
    assert_eq!(r.json["error"], "invalidArgument");
    let r = call_fn(&srv, "save", json!({ "url": srv.url("/api/v1/apps"), "sha256": "0".repeat(64), "name": "x" })).await;
    assert_eq!(r.json, json!({ "error": "unavailable", "message": "HTTP 401" }));

    let digest = hex::encode(Sha256::digest(PLAIN));
    let r = call_fn(&srv, "save", json!({ "url": url, "sha256": "0".repeat(64), "name": "x.json" })).await;
    assert_eq!(r.json["error"], "failedPrecondition", "{}", r.json);
    let r = call_fn(&srv, "save", json!({ "url": url, "sha256": digest, "name": "../x.json" })).await;
    assert_eq!(r.json["error"], "invalidArgument");
    let r = call_fn(&srv, "save", json!({ "url": srv.url("/api/v1/moved"), "sha256": digest, "name": "x.json" })).await;
    let path = r.json["value"].as_str().expect("a path").to_string();
    assert_eq!(std::fs::read_to_string(&path).unwrap(), PLAIN);
    let dir = call_fn(&srv, "ownDir", json!(null)).await.json["value"].as_str().unwrap().to_string();
    assert!(path.starts_with(&dir) && dir.ends_with("acme.notes"), "{path} in {dir}");

    // Removing the app takes its folder.
    let r = call(&srv, true, Method::DELETE, "/api/v1/apps/acme.notes", Some((json!({ "current_password": common::PASSWORD }).to_string().into_bytes(), "application/json"))).await;
    assert!(r.status < 300, "{}", r.json);
    assert!(!std::path::Path::new(&dir).exists());
}

#[ntex::test]
async fn a_job_runs_a_script_as_the_account_with_its_lines() {
    let srv = server().await;
    installed_backend(&srv, &[]).await;
    assert_eq!(start_job(&srv, "shell", json!({ "script": "echo a" })).await.status, 202);
    let done = ended(&srv).await;
    assert_eq!(done["error"]["message"], "process", "{done}");

    let srv = server().await;
    installed_backend(&srv, &["process"]).await;
    assert_eq!(start_job(&srv, "shell", json!({ "script": "echo a; echo b; exit 3" })).await.status, 202);
    let done = ended(&srv).await;
    assert_eq!((done["state"].as_str(), done["value"].as_i64()), (Some("succeeded"), Some(3)), "{done}");
    let lines: Vec<&str> = done["lines"].as_array().unwrap().iter().map(|l| l["text"].as_str().unwrap()).collect();
    assert_eq!(lines, ["# echo a; echo b; exit 3", "a", "b"]);
}

#[ntex::test]
async fn a_backend_keeps_what_it_stores() {
    let srv = server().await;
    installed_backend(&srv, &[]).await;
    assert_eq!(call_fn(&srv, "get", json!({ "key": "k" })).await.json["value"], json!(null));
    assert_eq!(call_fn(&srv, "put", json!({ "key": "k", "value": "{\"n\":42}" })).await.status, 200);
    assert_eq!(call_fn(&srv, "get", json!({ "key": "k" })).await.json["value"], "{\"n\":42}");
    // JSON texts only: the frame's storage reads the same rows.
    let r = call_fn(&srv, "put", json!({ "key": "k", "value": "{" })).await;
    assert_eq!((r.status, r.json["error"].as_str()), (400, Some("invalidArgument")));
    let r = call(&srv, true, Method::GET, "/api/v1/apps", None).await;
    assert_eq!(r.status, 200);
}

#[ntex::test]
async fn a_job_streams_its_lines_and_answers_once_done() {
    let srv = server().await;
    installed_backend(&srv, &[]).await;
    let r = start_job(&srv, "count", json!({ "lines": 3 })).await;
    assert_eq!(r.status, 202, "{}", r.json);
    assert_eq!(r.json["function"], "count");
    let done = ended(&srv).await;
    assert_eq!(done["state"], "succeeded", "{done}");
    assert_eq!(done["value"], 3);
    let lines: Vec<&str> = done["lines"].as_array().unwrap().iter().map(|l| l["text"].as_str().unwrap()).collect();
    assert_eq!(lines, ["line 0", "line 1", "line 2"]);
    // A call is not a job.
    assert_eq!(start_job(&srv, "echo", json!(null)).await.status, 404);
}

#[ntex::test]
async fn a_job_runs_alone_and_stops_when_cancelled() {
    let srv = server().await;
    installed_backend(&srv, &[]).await;
    assert_eq!(start_job(&srv, "forever", json!(null)).await.status, 202);
    let r = start_job(&srv, "count", json!({ "lines": 1 })).await;
    assert_eq!((r.status, r.json["message"].as_str()), (409, Some("busy")));
    let r = call(&srv, true, Method::POST, "/api/v1/apps/acme.notes/jobs/cancel", None).await;
    assert_eq!(r.status, 202);
    let done = ended(&srv).await;
    assert_eq!((done["state"].as_str(), done["error"]["error"].as_str()), (Some("cancelled"), Some("cancelled")), "{done}");
}

#[ntex::test]
async fn removing_an_app_ends_its_job() {
    let srv = server().await;
    installed_backend(&srv, &[]).await;
    assert_eq!(start_job(&srv, "forever", json!(null)).await.status, 202);
    let body = json!({ "current_password": common::PASSWORD }).to_string().into_bytes();
    let r = call(&srv, true, Method::DELETE, "/api/v1/apps/acme.notes", Some((body, "application/json"))).await;
    assert!(r.status < 300, "{}", r.json);
    // Installed again: none of the old one's job.
    installed_backend(&srv, &[]).await;
    let r = call(&srv, true, Method::GET, "/api/v1/apps/acme.notes/jobs", None).await;
    assert_eq!(r.status, 404, "{}", r.json);
    assert_eq!(start_job(&srv, "count", json!({ "lines": 1 })).await.status, 202);
}

#[ntex::test]
async fn a_backend_must_be_a_component_of_api_2() {
    let srv = server().await;
    // API 1's core module.
    let mut m = manifest(&[]);
    m["kind"] = json!("wasm");
    let old = package(&[("manifest.json", m.to_string().into_bytes()), ("ui/index.html", b"x".to_vec()), ("backend.wasm", probe())]);
    assert_eq!(install(&srv, old).await.json["error"], "unsupportedApi");
    // Not a component.
    let r = install(&srv, wasm_package(wat::parse_str("(module)").unwrap(), &[])).await;
    assert_eq!((r.status, r.json["error"].as_str()), (400, Some("invalidBackend")), "{}", r.json);
}

#[ntex::test]
async fn a_package_brings_a_backend_only_as_wasm() {
    let srv = server().await;
    let mut m = manifest(&[]);
    m["kind"] = json!("wasm");
    m["api"] = json!(2);
    let no_backend = package(&[("manifest.json", m.to_string().into_bytes()), ("ui/index.html", b"x".to_vec())]);
    assert_eq!(install(&srv, no_backend).await.json["error"], "backendMismatch");
    let stray = package(&[
        ("manifest.json", manifest(&[]).to_string().into_bytes()),
        ("ui/index.html", b"x".to_vec()),
        ("backend.wasm", probe()),
    ]);
    assert_eq!(install(&srv, stray).await.json["error"], "backendMismatch");
    // A web app has no backend to call.
    install(&srv, good(&[])).await;
    approve(&srv, &[], common::PASSWORD).await;
    assert_eq!(call_fn(&srv, "x", json!(null)).await.status, 404);
}

// ---------------------------------------------------------------------------
// The catalog and first-party signatures
// ---------------------------------------------------------------------------

#[ntex::test]
async fn the_catalog_offers_the_shipped_packages_signed() {
    let srv = server().await;
    let r = call(&srv, true, Method::GET, "/api/v1/apps/catalog", None).await;
    assert_eq!(r.status, 200, "{}", r.json);
    let cleanup = r.json["apps"].as_array().unwrap().iter().find(|a| a["id"] == "serverbox.cleanup").cloned().expect("Cleanup is offered");
    assert_eq!((cleanup["signedBy"].as_str(), cleanup["source"].as_str()), (Some("serverbox-2026"), Some("bundled")));
    assert_eq!(cleanup["manifest"]["permissions"], json!(["root"]));

    // Installed from it as an upload is: waiting, then approved.
    let r = call(&srv, true, Method::POST, "/api/v1/apps/catalog/serverbox.cleanup/install", None).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert_eq!((r.json["signed_by"].as_str(), r.json["approved_permissions"].is_null()), (Some("serverbox-2026"), true));
    let body = json!({ "sha256": r.json["sha256"], "permissions": ["root"], "current_password": common::PASSWORD }).to_string().into_bytes();
    let r = call(&srv, true, Method::PUT, "/api/v1/apps/serverbox.cleanup/approval", Some((body, "application/json"))).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert_eq!(call(&srv, true, Method::POST, "/api/v1/apps/catalog/nobody.here/install", None).await.status, 404);

    // The panel's own publisher, unsigned: refused.
    let mut m = manifest(&[]);
    m["publisher"] = json!("serverbox");
    let unsigned = package(&[("manifest.json", m.to_string().into_bytes()), ("ui/index.html", b"x".to_vec())]);
    assert_eq!(install(&srv, unsigned).await.json["error"], "invalidId");
    // A signed app is replaced only by a package with its signature: an
    // unsigned upload of its id is refused before its publisher is.
    let mut m = manifest(&["root"]);
    m["publisher"] = json!("serverbox");
    m["name"] = json!("cleanup");
    let swapped = package(&[("manifest.json", m.to_string().into_bytes()), ("ui/index.html", b"x".to_vec()), ("SIGNATURE", br#"{"key":"other","signature":"AA=="}"#.to_vec())]);
    assert_eq!(install(&srv, swapped).await.json["error"], "invalidId");
}
