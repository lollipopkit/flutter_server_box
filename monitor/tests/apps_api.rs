//! `/api/v1/apps*`: desk app packages an admin installs and approves, and
//! the sandboxed UI they are served as.

mod common;

use std::sync::Arc;

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::json;
use server_box_monitor::api::{app_runtime, apps};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

async fn server() -> TestServer {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let db = common::database().await;
    let config = Config { jwt_secret: Some(SECRET.to_string()), ..Default::default() };
    common::seed_as_upgrade(&db, &config).await;
    common::add_account(&db, "watcher", "viewer").await;
    common::set_grants(&db, "admin", &server_box_monitor::core::permissions::Grants::all()).await;
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
                    .service(web::resource("/apps/{id}").route(web::delete().to(apps::remove)))
                    .service(web::resource("/apps/{id}/approval").route(web::put().to(apps::approve)))
                    .service(web::resource("/apps/{id}/launch").route(web::get().to(apps::launch)))
                    .service(web::resource("/apps/{id}/call").route(web::post().to(app_runtime::call)))
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

async fn call(srv: &TestServer, user: Option<&str>, method: Method, path: &str, body: Option<(Vec<u8>, &str)>) -> Reply {
    let mut req = srv.request(method, srv.url(path)).timeout(std::time::Duration::from_secs(30));
    if let Some(user) = user {
        req = req.header("Authorization", format!("Bearer {}", generate_token(user, SECRET).unwrap()));
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
        "id": "acme_notes", "version": "1.0.0", "api": 1, "kind": "web",
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
    call(srv, Some("admin"), Method::POST, "/api/v1/apps", Some((bytes, "application/gzip"))).await
}

async fn approve(srv: &TestServer, permissions: &[&str], password: &str) -> Reply {
    let body = json!({ "permissions": permissions, "current_password": password }).to_string().into_bytes();
    call(srv, Some("admin"), Method::PUT, "/api/v1/apps/acme_notes/approval", Some((body, "application/json"))).await
}

#[ntex::test]
async fn an_app_is_served_only_once_approved_and_only_with_a_ticket() {
    let srv = server().await;
    let r = call(&srv, Some("watcher"), Method::POST, "/api/v1/apps", Some((good(&[]), "application/gzip"))).await;
    assert_eq!(r.status, 403, "only an admin installs");

    let r = install(&srv, good(&["notifications"])).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert!(r.json["approved_permissions"].is_null());

    // Waiting: no one but an admin sees it, nothing serves it.
    let r = call(&srv, Some("watcher"), Method::GET, "/api/v1/apps", None).await;
    assert_eq!(r.json["apps"], json!([]));
    let r = call(&srv, Some("admin"), Method::GET, "/api/v1/apps", None).await;
    assert_eq!(r.json["apps"][0]["id"], "acme_notes");
    assert_eq!(call(&srv, Some("watcher"), Method::GET, "/api/v1/apps/acme_notes/launch", None).await.status, 404);

    // Approval asks for the password and for exactly what the manifest lists.
    assert_eq!(approve(&srv, &["notifications"], "wrong").await.status, 403);
    assert_eq!(approve(&srv, &[], common::PASSWORD).await.status, 409);
    let r = approve(&srv, &["notifications"], common::PASSWORD).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert_eq!(r.json["approved_permissions"], json!(["notifications"]));

    let r = call(&srv, Some("watcher"), Method::GET, "/api/v1/apps/acme_notes/launch", None).await;
    assert_eq!(r.status, 200);
    let url = r.json["url"].as_str().unwrap().to_string();
    assert!(url.ends_with("/index.html"));

    // The UI: no bearer needed, the ticket is the key; sandboxed, no network.
    let r = call(&srv, None, Method::GET, &url, None).await;
    assert_eq!(r.status, 200);
    let csp = r.headers.get("content-security-policy").unwrap().to_str().unwrap();
    assert!(csp.starts_with("sandbox allow-scripts"), "{csp}");
    assert!(csp.contains("connect-src 'none'"), "{csp}");
    assert_eq!(r.headers.get("x-content-type-options").unwrap(), "nosniff");
    assert!(String::from_utf8_lossy(&r.bytes).contains("app.js"));
    let js = call(&srv, None, Method::GET, &url.replace("index.html", "app.js"), None).await;
    assert_eq!(js.headers.get("content-type").unwrap(), "text/javascript; charset=utf-8");

    // A ticket whose MAC is not the agent's opens nothing.
    let ticket = url.split('/').nth(6).unwrap();
    let expiry = ticket.split('.').next().unwrap();
    let forged = url.replace(ticket, &format!("{expiry}.{}", "0".repeat(64)));
    assert_eq!(call(&srv, None, Method::GET, &forged, None).await.status, 403);
    for path in ["../manifest.json", "%2e%2e/manifest.json", "missing.js"] {
        let r = call(&srv, None, Method::GET, &url.replace("index.html", path), None).await;
        assert_eq!(r.status, 404, "{path}");
    }
    // The manifest is not part of the UI.
    let r = call(&srv, None, Method::GET, &url.replace("index.html", "../manifest.json"), None).await;
    assert!(!String::from_utf8_lossy(&r.bytes).contains("acme_notes"));
}

#[ntex::test]
async fn a_new_version_asking_for_more_waits_for_approval_again() {
    let srv = server().await;
    install(&srv, good(&["notifications"])).await;
    approve(&srv, &["notifications"], common::PASSWORD).await;

    let r = install(&srv, good(&["notifications"])).await;
    assert_eq!(r.json["approved_permissions"], json!(["notifications"]), "same asks: still approved");
    let r = install(&srv, good(&["notifications", "background"])).await;
    assert!(r.json["approved_permissions"].is_null(), "asks for more: waits");
    assert_eq!(call(&srv, Some("watcher"), Method::GET, "/api/v1/apps/acme_notes/launch", None).await.status, 404);
}

#[ntex::test]
async fn removing_asks_for_the_password() {
    let srv = server().await;
    install(&srv, good(&[])).await;
    let wrong = json!({ "current_password": "nope" }).to_string().into_bytes();
    let r = call(&srv, Some("admin"), Method::DELETE, "/api/v1/apps/acme_notes", Some((wrong, "application/json"))).await;
    assert_eq!(r.status, 403);
    let right = json!({ "current_password": common::PASSWORD }).to_string().into_bytes();
    let r = call(&srv, Some("admin"), Method::DELETE, "/api/v1/apps/acme_notes", Some((right.clone(), "application/json"))).await;
    assert_eq!(r.status, 204);
    let r = call(&srv, Some("admin"), Method::DELETE, "/api/v1/apps/acme_notes", Some((right, "application/json"))).await;
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
    let r = call(&srv, Some("admin"), Method::GET, "/api/v1/apps", None).await;
    assert_eq!(r.json["apps"], json!([]), "nothing kept of a refused package");
}

// ---------------------------------------------------------------------------
// Backends (`kind: wasm`)
// ---------------------------------------------------------------------------

/// A guest in the agent's ABI: a bump allocator, and `sbm_call` doing [body]
/// (which may use `$ptr`/`$len`, the request, and the data at 16).
fn guest(data: &str, body: &str) -> Vec<u8> {
    let escaped = data.replace('\\', "\\\\").replace('"', "\\\"");
    wat::parse_str(format!(
        r#"(module
          (import "sbm" "host" (func $host (param i32 i32) (result i64)))
          (memory (export "memory") 1)
          (global $next (mut i32) (i32.const 4096))
          (data (i32.const 16) "{escaped}")
          (func (export "sbm_alloc") (param $len i32) (result i32)
            (local $p i32)
            global.get $next
            local.set $p
            global.get $next
            local.get $len
            i32.add
            global.set $next
            (block $done
              (loop $grow
                global.get $next
                memory.size
                i32.const 65536
                i32.mul
                i32.le_u
                br_if $done
                i32.const 1
                memory.grow
                i32.const -1
                i32.eq
                if
                  unreachable
                end
                br $grow))
            local.get $p)
          (func (export "sbm_call") (param $ptr i32) (param $len i32) (result i64)
            {body}))"#
    ))
    .unwrap()
}

const ECHO: &str = "local.get $ptr i64.extend_i32_u i64.const 32 i64.shl local.get $len i64.extend_i32_u i64.or";

/// Asks the host [request] (the data at 16) and answers what it said.
fn asking(request: &str) -> Vec<u8> {
    guest(request, &format!("i32.const 16 i32.const {} call $host", request.len()))
}

fn wasm_package(wasm: Vec<u8>, permissions: &[&str]) -> Vec<u8> {
    let mut m = manifest(permissions);
    m["kind"] = json!("wasm");
    package(&[
        ("manifest.json", m.to_string().into_bytes()),
        ("ui/index.html", b"<p>backend</p>".to_vec()),
        ("backend.wasm", wasm),
    ])
}

async fn installed_backend(srv: &TestServer, wasm: Vec<u8>, permissions: &[&str]) {
    let r = install(srv, wasm_package(wasm, permissions)).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert_eq!(approve(srv, permissions, common::PASSWORD).await.status, 200);
}

async fn call_backend(srv: &TestServer, user: &str, method: &str, params: serde_json::Value) -> Reply {
    let body = json!({ "method": method, "params": params }).to_string().into_bytes();
    call(srv, Some(user), Method::POST, "/api/v1/apps/acme_notes/call", Some((body, "application/json"))).await
}

#[ntex::test]
async fn a_backend_answers_as_the_account_calling() {
    let srv = server().await;
    installed_backend(&srv, guest("", ECHO), &[]).await;
    let r = call_backend(&srv, "watcher", "ping", json!({ "n": 1 })).await;
    assert_eq!(r.status, 200, "{}", r.json);
    assert_eq!(r.json, json!({ "method": "ping", "params": { "n": 1 }, "caller": { "username": "watcher", "admin": false } }));
}

#[ntex::test]
async fn a_backend_is_stopped_by_its_bounds() {
    let srv = server().await;
    installed_backend(&srv, guest("", "(loop $l br $l) i64.const 0"), &[]).await;
    let r = call_backend(&srv, "admin", "spin", json!(null)).await;
    assert_eq!((r.status, r.json["error"].as_str()), (422, Some("tooLong")));

    // 64 MiB is 1024 pages; asking for 2000 more is refused.
    let srv = server().await;
    installed_backend(&srv, guest("", "i32.const 2000 memory.grow drop i32.const 2000 memory.grow i64.extend_i32_s"), &[]).await;
    let r = call_backend(&srv, "admin", "grow", json!(null)).await;
    assert_eq!(r.status, 422, "{}", r.json);
}

#[ntex::test]
async fn host_functions_need_the_permission_and_the_callers_grant() {
    // Not approved for `exec`: refused whoever calls.
    let srv = server().await;
    installed_backend(&srv, asking(r#"{"fn":"exec","args":{"cmd":"echo hi"}}"#), &[]).await;
    let r = call_backend(&srv, "admin", "run", json!(null)).await;
    assert_eq!(r.json, json!({ "error": "notPermitted" }));

    // Approved: runs for an account with the shell, not for one without.
    let srv = server().await;
    installed_backend(&srv, asking(r#"{"fn":"exec","args":{"cmd":"echo hi"}}"#), &["exec"]).await;
    let r = call_backend(&srv, "admin", "run", json!(null)).await;
    assert_eq!(r.json["ok"]["stdout"], "hi\n", "{}", r.json);
    let r = call_backend(&srv, "watcher", "run", json!(null)).await;
    assert!(r.json["error"].as_str().unwrap().starts_with("forbidden"), "{}", r.json);
}

#[ntex::test]
async fn a_backend_keeps_what_it_stores_per_account() {
    let srv = server().await;
    installed_backend(&srv, asking(r#"{"fn":"kv.set","args":{"key":"k","value":42}}"#), &[]).await;
    assert_eq!(call_backend(&srv, "admin", "set", json!(null)).await.json, json!({ "ok": null }));
    let srv2 = srv;
    // Read back by a module that asks for it (a new version keeps its approval).
    let r = install(&srv2, wasm_package(asking(r#"{"fn":"kv.get","args":{"key":"k"}}"#), &[])).await;
    assert_eq!(r.status, 200);
    assert_eq!(call_backend(&srv2, "admin", "get", json!(null)).await.json, json!({ "ok": 42 }));
    assert_eq!(call_backend(&srv2, "watcher", "get", json!(null)).await.json, json!({ "ok": null }));
}

#[ntex::test]
async fn a_package_brings_a_backend_only_as_wasm() {
    let srv = server().await;
    let mut m = manifest(&[]);
    m["kind"] = json!("wasm");
    let no_backend = package(&[("manifest.json", m.to_string().into_bytes()), ("ui/index.html", b"x".to_vec())]);
    assert_eq!(install(&srv, no_backend).await.json["error"], "backendMismatch");
    let stray = package(&[
        ("manifest.json", manifest(&[]).to_string().into_bytes()),
        ("ui/index.html", b"x".to_vec()),
        ("backend.wasm", guest("", ECHO)),
    ]);
    assert_eq!(install(&srv, stray).await.json["error"], "backendMismatch");
    // A web app has no backend to call.
    install(&srv, good(&[])).await;
    approve(&srv, &[], common::PASSWORD).await;
    assert_eq!(call_backend(&srv, "admin", "x", json!(null)).await.status, 404);
}
