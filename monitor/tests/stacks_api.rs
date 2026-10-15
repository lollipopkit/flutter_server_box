//! `/api/v1/stacks*` and the web apps' proxy (`stacks::proxy`). Nothing here
//! runs Docker: deploying is refused before it would, and the proxy is put in
//! front of a fake service.

mod common;

use std::collections::HashMap;
use std::convert::Infallible;
use std::future::Future;
use std::io::Write;
use std::pin::Pin;
use std::sync::Arc;

use http_body_util::Full;
use hyper::body::{Bytes, Incoming};
use hyper::header::HeaderValue;
use hyper::{Request, Response};
use hyper_util::rt::TokioIo;
use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::json;
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::desk_themes::Fetch;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::stacks;
use server_box_monitor::core::config::{Config, StacksConfig};
use server_box_monitor::stacks::proxy::{Hosts, Target};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// Answers from memory: the catalog's repositories, for tests.
struct Memory(HashMap<String, Vec<u8>>);

impl Fetch for Memory {
    fn get<'a>(&'a self, url: &'a str, _max: usize) -> Pin<Box<dyn Future<Output = Result<Vec<u8>, String>> + Send + 'a>> {
        let answer = self.0.get(url).cloned().ok_or_else(|| "HTTP 404".to_string());
        Box::pin(async move { answer })
    }
}

const CATALOG: &str = "https://catalog.test/repos.toml";

/// A repository tree as a hosting service serves it: one wrapper folder.
fn tar_gz(entries: &[(&str, &[u8])]) -> Vec<u8> {
    let mut builder = tar::Builder::new(Vec::new());
    for (name, bytes) in entries {
        let mut header = tar::Header::new_gnu();
        header.set_size(bytes.len() as u64);
        header.set_mode(0o644);
        header.set_cksum();
        builder.append_data(&mut header, format!("store/{name}"), *bytes).unwrap();
    }
    let mut gz = flate2::write::GzEncoder::new(Vec::new(), flate2::Compression::fast());
    gz.write_all(&builder.into_inner().unwrap()).unwrap();
    gz.finish().unwrap()
}

/// The test web app (`tests/apps`), as its files.
fn testweb(file: &str) -> Vec<u8> {
    std::fs::read(std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/apps/serverbox.testweb").join(file)).unwrap()
}

async fn setup() -> (TestServer, Arc<AppState>) {
    setup_with(None, HashMap::new()).await
}

/// An agent with [local_apps] and a catalog whose repositories [repos] holds.
async fn setup_with(local_apps: Option<&str>, repos: HashMap<String, Vec<u8>>) -> (TestServer, Arc<AppState>) {
    let db = common::database().await;
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        stacks: Some(StacksConfig { local_apps: local_apps.map(String::from), ..Default::default() }),
        ..Default::default()
    };
    common::add_owner(&db).await;
    let state: Arc<AppState> = AppState::new(Arc::new(config), db);
    state.stacks.catalog.set_source(CATALOG, Arc::new(Memory(repos)));
    let shared = state.clone();
    let srv = web_test::server(move || {
        let state = shared.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .service(web::resource("/stacks").route(web::get().to(stacks::list)))
                    .service(web::resource("/stacks/refresh").route(web::post().to(stacks::refresh)))
                    .service(
                        web::resource("/stacks/{id}")
                            .route(web::post().to(stacks::install))
                            .route(web::delete().to(stacks::remove)),
                    )
                    .service(web::resource("/stacks/{id}/prepare").route(web::get().to(stacks::prepare)))
                    .service(web::resource("/stacks/{id}/check").route(web::post().to(stacks::check)))
                    .service(web::resource("/stacks/{id}/settings").route(web::put().to(stacks::reconfigure)))
                    .service(web::resource("/stacks/{id}/action").route(web::post().to(stacks::act)))
                    .service(web::resource("/stacks/{id}/job").route(web::get().to(stacks::job)))
                    .service(web::resource("/stacks/{id}/job/cancel").route(web::post().to(stacks::cancel)))
                    .service(web::resource("/stacks/{id}/services").route(web::get().to(stacks::services)))
                    .service(web::resource("/stacks/{id}/login").route(web::post().to(stacks::login)))
                    .service(web::resource("/stacks/{id}/enter").route(web::post().to(stacks::enter))),
            )
        }
    })
    .await;
    (srv, state)
}

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<serde_json::Value>) -> (u16, serde_json::Value) {
    let req = srv
        .request(method, srv.url(path))
        .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()))
        .timeout(std::time::Duration::from_secs(30));
    let resp = match body {
        Some(body) => req.send_json(&body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let bytes = resp.body().await.unwrap_or_default();
    (resp.status().as_u16(), serde_json::from_slice(&bytes).unwrap_or(serde_json::Value::Null))
}

#[ntex::test]
async fn the_catalog_is_listed() {
    let (srv, _) = setup().await;
    let (status, body) = call(&srv, Method::GET, "/api/v1/stacks", None).await;
    assert_eq!(status, 200);
    let immich = body["apps"].as_array().unwrap().iter().find(|a| a["manifest"]["id"] == "futo.immich").expect("immich");
    assert_eq!(immich["stack"], serde_json::Value::Null);
    assert_eq!(immich["manifest"]["license"]["spdx"], "AGPL-3.0");
    // What the desk's first-run guide recommends from.
    assert_eq!(immich["manifest"]["recommended"], true);
    let ariang = body["apps"].as_array().unwrap().iter().find(|a| a["manifest"]["id"] == "mayswind.ariang").expect("ariang");
    assert_eq!(ariang["manifest"]["recommended"], false);
}

#[ntex::test]
async fn deploying_asks_the_password_and_the_licence() {
    let (srv, _) = setup().await;
    let (status, _) = call(
        &srv,
        Method::POST,
        "/api/v1/stacks/futo.immich",
        Some(json!({ "current_password": "wrong", "accept_license": true })),
    )
    .await;
    assert_ne!(status, 202);
    let (status, body) =
        call(&srv, Method::POST, "/api/v1/stacks/futo.immich", Some(json!({ "current_password": common::PASSWORD }))).await;
    assert_eq!((status, body["error"].as_str()), (400, Some("notAcknowledged")));
    let (status, body) = call(
        &srv,
        Method::POST,
        "/api/v1/stacks/futo.immich",
        Some(json!({ "current_password": common::PASSWORD, "acknowledged": true })),
    )
    .await;
    assert_eq!((status, body["error"].as_str()), (400, Some("licenseNotAccepted")));
    let (status, _) = call(
        &srv,
        Method::POST,
        "/api/v1/stacks/nope",
        Some(json!({ "current_password": common::PASSWORD, "acknowledged": true, "accept_license": true })),
    )
    .await;
    assert_eq!(status, 404);
}

#[ntex::test]
async fn the_check_shows_what_deploying_would_do() {
    let (srv, _) = setup().await;
    let (status, body) = call(&srv, Method::POST, "/api/v1/stacks/futo.immich/check", Some(json!({ "settings": {} }))).await;
    assert_eq!(status, 200);
    let images: Vec<&str> = body["images"].as_array().unwrap().iter().filter_map(|i| i.as_str()).collect();
    assert!(images.contains(&"ghcr.io/immich-app/immich-server:v3.3.1"), "{images:?}");
    assert_eq!(body["data_paths"].as_array().unwrap().len(), 2);
    assert!(body["settings"]["library"].as_str().unwrap().ends_with("/futo.immich/library"));
    let (status, body) =
        call(&srv, Method::POST, "/api/v1/stacks/futo.immich/check", Some(json!({ "settings": { "port": 0 } }))).await;
    assert_eq!((status, body["field"].as_str()), (400, Some("port")));
}

#[ntex::test]
async fn a_suggested_port_in_use_moves_and_a_chosen_one_is_refused() {
    let (srv, _) = setup().await;
    // Held here, or already in use on this machine: either way not free.
    let _held = std::net::TcpListener::bind(("0.0.0.0", 2283));
    let (status, body) =
        call(&srv, Method::POST, "/api/v1/stacks/futo.immich/check", Some(json!({ "settings": { "port": 2283 } }))).await;
    assert_eq!(status, 200, "{body}");
    let to = body["settings"]["port"].as_u64().unwrap();
    assert!((2284..=2383).contains(&to), "{body}");
    assert_eq!(body["moved"], json!([{ "setting": "port", "from": 2283, "to": to }]));

    let chosen = std::net::TcpListener::bind(("0.0.0.0", 0)).unwrap();
    let port = chosen.local_addr().unwrap().port();
    let (status, body) =
        call(&srv, Method::POST, "/api/v1/stacks/futo.immich/check", Some(json!({ "settings": { "port": port } }))).await;
    assert_eq!((status, body["error"].as_str(), body["field"].as_str()), (409, Some("portTaken"), Some("port")), "{body}");
}

#[ntex::test]
async fn new_settings_need_the_password_and_a_deployed_app() {
    let (srv, _) = setup().await;
    let path = "/api/v1/stacks/futo.immich/settings";
    let (status, _) = call(&srv, Method::PUT, path, Some(json!({ "current_password": "wrong", "settings": {} }))).await;
    assert_ne!(status, 202);
    let (status, body) = call(&srv, Method::PUT, path, Some(json!({ "current_password": common::PASSWORD, "settings": {} }))).await;
    assert_eq!((status, body["error"].as_str()), (404, Some("notInstalled")));
}

#[ntex::test]
async fn the_sign_in_needs_the_password_and_a_deployed_app() {
    let apps = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/apps");
    let (srv, state) = setup_with(apps.to_str(), HashMap::new()).await;
    let path = "/api/v1/stacks/serverbox.testweb/login";
    let password = Some(json!({ "current_password": common::PASSWORD }));
    let (status, _) = call(&srv, Method::POST, path, Some(json!({ "current_password": "wrong" }))).await;
    assert_ne!(status, 200);
    let (status, body) = call(&srv, Method::POST, path, password.clone()).await;
    assert_eq!((status, body["error"].as_str()), (409, Some("notDeployed")), "{body}");
    // An app without a sign-in has none to show.
    let (status, body) = call(&srv, Method::POST, "/api/v1/stacks/futo.immich/login", password.clone()).await;
    assert_eq!((status, body["error"].as_str()), (404, Some("noLogin")), "{body}");

    // Deployed, as the agent leaves it: a row and the env file.
    let row = server_box_monitor::stacks::store::StackRow {
        id: "serverbox.testweb".into(),
        version: "1.0.0".into(),
        settings: Default::default(),
        proxy_port: 3780,
        state: "installed".into(),
        license: "BSD-2-Clause".into(),
        license_accepted_at: String::new(),
        installed_at: String::new(),
        updated_at: String::new(),
        last_error: None,
        stopped: false,
        update_noticed: None,
    };
    assert!(server_box_monitor::stacks::store::insert(&state.db, &row).await.unwrap());
    let dir = state.stacks.dir("serverbox.testweb");
    std::fs::create_dir_all(&dir).unwrap();
    std::fs::write(dir.join(".env"), "WEB_PORT='18080'\nADMIN_PASSWORD='s3cretS3cret'\n").unwrap();
    let (status, body) = call(&srv, Method::POST, path, password).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!((body["user"].as_str(), body["password"].as_str()), (Some("admin"), Some("s3cretS3cret")));
    assert_eq!(body["note"]["en"], "A test sign-in; nginx asks for none.");
}

#[ntex::test]
async fn an_app_not_running_cannot_be_entered() {
    let (srv, _) = setup().await;
    let (status, body) = call(&srv, Method::POST, "/api/v1/stacks/futo.immich/enter", None).await;
    assert_eq!((status, body["error"].as_str()), (409, Some("notRunning")));
}

/// A service that answers what it was sent, refuses framing, sets a cookie,
/// and echoes a WebSocket-style upgraded stream.
async fn fake_service() -> u16 {
    let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
    let port = listener.local_addr().unwrap().port();
    tokio::spawn(async move {
        loop {
            let (stream, _) = listener.accept().await.unwrap();
            tokio::spawn(async move {
                let service = hyper::service::service_fn(|mut req: Request<Incoming>| async move {
                    if req.headers().contains_key("upgrade") {
                        let upgrade = hyper::upgrade::on(&mut req);
                        tokio::spawn(async move {
                            let mut io = TokioIo::new(upgrade.await.unwrap());
                            let mut buf = [0u8; 64];
                            let n = io.read(&mut buf).await.unwrap();
                            io.write_all(&buf[..n]).await.unwrap();
                        });
                        return Ok::<_, Infallible>(
                            Response::builder()
                                .status(101)
                                .header("connection", "upgrade")
                                .header("upgrade", "websocket")
                                .body(Full::new(Bytes::new()))
                                .unwrap(),
                        );
                    }
                    let seen = json!({
                        "path": req.uri().path(),
                        "cookie": req.headers().get("cookie").map(|v| v.to_str().unwrap().to_string()),
                        "proto": req.headers().get("x-forwarded-proto").map(|v| v.to_str().unwrap().to_string()),
                        "authorization": req.headers().get("authorization").map(|v| v.to_str().unwrap().to_string()),
                    });
                    Ok(Response::builder()
                        .header("x-frame-options", "DENY")
                        .header("set-cookie", "svc=1; Path=/; SameSite=Lax")
                        .body(Full::new(Bytes::from(seen.to_string())))
                        .unwrap())
                });
                let _ = hyper::server::conn::http1::Builder::new()
                    .serve_connection(TokioIo::new(stream), service)
                    .with_upgrades()
                    .await;
            });
        }
    });
    port
}

/// One HTTP/1.1 request over a fresh connection; the raw answer.
async fn raw(port: u16, request: String) -> String {
    let mut stream = tokio::net::TcpStream::connect(("127.0.0.1", port)).await.unwrap();
    stream.write_all(request.as_bytes()).await.unwrap();
    let mut out = Vec::new();
    let _ = tokio::time::timeout(std::time::Duration::from_secs(5), stream.read_to_end(&mut out)).await;
    String::from_utf8_lossy(&out).into_owned()
}

fn get(path: &str, cookie: Option<&str>) -> String {
    let cookie = cookie.map(|c| format!("Cookie: {c}\r\n")).unwrap_or_default();
    format!("GET {path} HTTP/1.1\r\nHost: nas.local:3780\r\n{cookie}Connection: close\r\n\r\n")
}

#[ntex::test]
async fn the_proxy_admits_a_window_and_forwards_to_the_service() {
    let (srv, state) = setup().await;
    let upstream_port = fake_service().await;
    state
        .stacks
        .proxies
        .start(
            state.clone(),
            Target {
                stack: "futo.immich".into(),
                listen: "127.0.0.1:0".parse().unwrap(),
                upstream_port,
                tls: None,
                frame_origins: vec!["https://panel.example".into()],
                authorization: Some(HeaderValue::from_static("Basic YWRtaW46cHc=")),
            },
        )
        .await
        .unwrap();

    let (status, body) = call(&srv, Method::POST, "/api/v1/stacks/futo.immich/enter", None).await;
    assert_eq!(status, 200);
    let port = body["port"].as_u64().unwrap() as u16;
    let ticket = body["ticket"].as_str().unwrap().to_string();

    // Without the session cookie, the sign-in page.
    let answer = raw(port, get("/photos", None)).await;
    assert!(answer.starts_with("HTTP/1.1 401"), "{answer}");

    // The ticket buys a cookie and a redirect, once.
    let answer = raw(port, get(&format!("/__sbm/enter?ticket={ticket}&next=%2Fphotos"), None)).await;
    assert!(answer.starts_with("HTTP/1.1 303"), "{answer}");
    assert!(answer.contains("location: /photos"), "{answer}");
    let cookie = answer
        .lines()
        .find_map(|l| l.strip_prefix("set-cookie: "))
        .and_then(|c| c.split(';').next())
        .expect("a session cookie")
        .to_string();
    assert!(cookie.starts_with("__sbm_futo.immich="));
    let again = raw(port, get(&format!("/__sbm/enter?ticket={ticket}"), None)).await;
    assert!(again.starts_with("HTTP/1.1 401"), "{again}");

    // Forwarded without the agent's cookie, made frameable.
    let answer = raw(port, get("/photos", Some(&format!("{cookie}; theirs=1")))).await;
    assert!(answer.starts_with("HTTP/1.1 200"), "{answer}");
    assert!(!answer.to_ascii_lowercase().contains("x-frame-options"), "{answer}");
    let body: serde_json::Value = serde_json::from_str(answer.split("\r\n\r\n").nth(1).unwrap()).unwrap();
    assert_eq!(body["path"], "/photos");
    assert_eq!(body["cookie"], "theirs=1");
    assert_eq!(body["proto"], "http");
    // The service's basic auth answered by the proxy, unless the browser
    // answers it itself.
    assert_eq!(body["authorization"], "Basic YWRtaW46cHc=");
    let own = format!("GET /photos HTTP/1.1\r\nHost: nas.local:3780\r\nCookie: {cookie}\r\nAuthorization: Basic b3duOm93bg==\r\nConnection: close\r\n\r\n");
    let answer = raw(port, own).await;
    let body: serde_json::Value = serde_json::from_str(answer.split("\r\n\r\n").nth(1).unwrap()).unwrap();
    assert_eq!(body["authorization"], "Basic b3duOm93bg==");

    // An upgrade is spliced through.
    let mut stream = tokio::net::TcpStream::connect(("127.0.0.1", port)).await.unwrap();
    stream
        .write_all(
            format!(
                "GET /api/socket HTTP/1.1\r\nHost: nas.local:3780\r\nCookie: {cookie}\r\nConnection: Upgrade\r\n\
                 Upgrade: websocket\r\n\r\n"
            )
            .as_bytes(),
        )
        .await
        .unwrap();
    let mut head = vec![0u8; 1024];
    let n = stream.read(&mut head).await.unwrap();
    assert!(String::from_utf8_lossy(&head[..n]).starts_with("HTTP/1.1 101"), "{}", String::from_utf8_lossy(&head[..n]));
    stream.write_all(b"ping").await.unwrap();
    let mut echo = [0u8; 4];
    tokio::time::timeout(std::time::Duration::from_secs(5), stream.read_exact(&mut echo)).await.unwrap().unwrap();
    assert_eq!(&echo, b"ping");

    // The account's sessions end with it.
    state.stacks.proxies.end_account();
    let answer = raw(port, get("/photos", Some(&cookie))).await;
    assert!(answer.starts_with("HTTP/1.1 401"), "{answer}");
    state.stacks.proxies.stop("futo.immich");
}

#[ntex::test]
async fn apps_taken_by_host_each_have_their_own() {
    let (srv, state) = setup().await;
    let upstream_port = fake_service().await;
    let target = Target {
        stack: "futo.immich".into(),
        listen: "127.0.0.1:0".parse().unwrap(),
        upstream_port,
        tls: None,
        frame_origins: vec![],
        authorization: None,
    };
    state.stacks.proxies.start(state.clone(), target).await.unwrap();
    let hosts = Hosts::parse("https://*.apps.test").unwrap();
    let port = state.stacks.proxies.start_by_host("127.0.0.1:0".parse().unwrap(), hosts, None, state.clone()).await.unwrap();

    // Asked from the panel's page: the window's address is the app's host.
    let req = srv
        .request(Method::POST, srv.url("/api/v1/stacks/futo.immich/enter"))
        .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()))
        .header("Origin", format!("http://{}", srv.addr()));
    let resp = req.send().await.unwrap();
    let body: serde_json::Value = serde_json::from_slice(&resp.body().await.unwrap()).unwrap();
    assert_eq!(body["url"], "https://futo-immich.apps.test");
    let ticket = body["ticket"].as_str().unwrap();

    let at = |path: &str, host: &str, cookie: Option<&str>| {
        let cookie = cookie.map(|c| format!("Cookie: {c}\r\n")).unwrap_or_default();
        format!("GET {path} HTTP/1.1\r\nHost: {host}\r\n{cookie}Connection: close\r\n\r\n")
    };
    let answer = raw(port, at(&format!("/__sbm/enter?ticket={ticket}"), "futo-immich.apps.test", None)).await;
    assert!(answer.starts_with("HTTP/1.1 303"), "{answer}");
    let set = answer.lines().find_map(|l| l.strip_prefix("set-cookie: ")).expect("a session cookie").to_string();
    // HTTPS as the browser sees it: a cookie a cross-site frame keeps.
    assert!(set.contains("SameSite=None; Secure; Partitioned"), "{set}");
    let cookie = set.split(';').next().unwrap();

    let answer = raw(port, at("/photos", "futo-immich.apps.test", Some(cookie))).await;
    assert!(answer.starts_with("HTTP/1.1 200"), "{answer}");
    assert!(answer.contains("svc=1; Path=/; SameSite=None; Secure; Partitioned"), "{answer}");
    let body: serde_json::Value = serde_json::from_str(answer.split("\r\n\r\n").nth(1).unwrap()).unwrap();
    assert_eq!(body["proto"], "https");
    assert!(body["authorization"].is_null());

    // Another host, or none of this agent's apps: nothing.
    for host in ["acme-notes.apps.test", "futo-immich.apps.other", "apps.test", "a.futo-immich.apps.test"] {
        let answer = raw(port, at("/photos", host, Some(cookie))).await;
        assert!(answer.starts_with("HTTP/1.1 404"), "{host}: {answer}");
    }
    state.stacks.proxies.stop("futo.immich");
}

#[ntex::test]
async fn the_catalog_has_the_stores_apps_the_operators_and_the_shipped_ones() {
    let local = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/apps");
    let manifest = String::from_utf8(testweb("manifest.toml")).unwrap();
    let store_manifest = manifest.replace("name = \"testweb\"", "name = \"fromstore\"");
    let renamed = manifest.replace("name = \"testweb\"", "name = \"other\"");
    let repos = HashMap::from([
        (CATALOG.to_string(), b"schema = 1\nname = \"Test\"\n[[repo]]\nurl = \"https://repo.test/store.tar.gz\"\n".to_vec()),
        (
            "https://repo.test/store.tar.gz".to_string(),
            tar_gz(&[
                ("repo.toml", b"schema = 1\nname = \"Test\"\n"),
                ("apps/serverbox.fromstore/manifest.toml", store_manifest.as_bytes()),
                ("apps/serverbox.fromstore/compose.yaml", &testweb("compose.yaml")),
                ("apps/serverbox.fromstore/built.Dockerfile", &testweb("built.Dockerfile")),
                // Its folder names another id: left out.
                ("apps/serverbox.wrong/manifest.toml", renamed.as_bytes()),
                ("apps/serverbox.wrong/compose.yaml", &testweb("compose.yaml")),
                ("apps/serverbox.wrong/built.Dockerfile", &testweb("built.Dockerfile")),
            ]),
        ),
    ]);
    let (srv, state) = setup_with(Some(local.to_str().unwrap()), repos).await;
    let source = |body: &serde_json::Value, id: &str| {
        body["apps"].as_array().unwrap().iter().find(|a| a["manifest"]["id"] == id).map(|a| a["source"].clone())
    };

    let (status, body) = call(&srv, Method::POST, "/api/v1/stacks/refresh", None).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(source(&body, "serverbox.testweb"), Some(json!("local")));
    assert_eq!(source(&body, "serverbox.fromstore"), Some(json!("store")));
    assert_eq!(source(&body, "futo.immich"), Some(json!("bundled")));
    assert_eq!(source(&body, "serverbox.wrong"), None);
    // A Dockerfile comes with the package it builds.
    assert!(state.stacks.package("serverbox.fromstore").is_some_and(|p| p.builds() && p.files.contains_key("built.Dockerfile")));

    // Kept on disk: an agent started without the network still has it.
    let cache = state.stacks.dir(".catalog");
    let again = server_box_monitor::stacks::catalog::Catalog::new(cache, None);
    assert_eq!(again.get("serverbox.fromstore").map(|e| e.source), Some(server_box_monitor::stacks::catalog::Source::Store));
}
