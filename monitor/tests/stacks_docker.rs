//! A web app deployed on a real Docker: the test web app (`tests/apps`)
//! installed, reached through its proxy, given new settings, held off a port
//! in use, stopped and started, and removed with its data.
//!
//! Opt-in, as the SSH e2e tests: it pulls an image and runs containers.
//!
//!     SBM_E2E_DOCKER=1 cargo test -p server_box_monitor --test stacks_docker -- --ignored --nocapture
//!
//! Needs Docker (or Podman) with Compose for the account running it, and the
//! proxy's ports (3780–3799) free.

mod common;

use std::sync::Arc;
use std::time::{Duration, Instant};

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::{container_backups, stacks};
use server_box_monitor::core::config::{Config, StacksConfig};
use tokio::io::{AsyncReadExt, AsyncWriteExt};

const SECRET: &str = "test-secret-that-is-long-enough-32ch";
/// The test web app under a name of its own, so a copy an agent on the same
/// machine deployed (`serverbox.testweb`) is never touched.
const APP: &str = "serverbox.testweb_e2e";
const PROJECT: &str = "sbm-serverbox-testweb_e2e";

/// `tests/apps/serverbox.testweb` copied as [APP] into a folder of its own.
fn apps_dir() -> tempfile::TempDir {
    let dir = tempfile::tempdir().unwrap();
    let from = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/apps/serverbox.testweb");
    let to = dir.path().join(APP);
    std::fs::create_dir(&to).unwrap();
    for entry in std::fs::read_dir(&from).unwrap() {
        let entry = entry.unwrap();
        let mut text = std::fs::read_to_string(entry.path()).unwrap();
        if entry.file_name() == "manifest.toml" {
            text = text.replace("name = \"testweb\"", "name = \"testweb_e2e\"");
        }
        std::fs::write(to.join(entry.file_name()), text).unwrap();
    }
    dir
}

async fn setup(apps: &std::path::Path) -> (TestServer, Arc<AppState>) {
    let db = common::database().await;
    let config = Config {
        jwt_secret: Some(SECRET.to_string()),
        stacks: Some(StacksConfig { local_apps: Some(apps.to_string_lossy().into_owned()), ..Default::default() }),
        ..Default::default()
    };
    common::seed_as_upgrade(&db, &config).await;
    let state: Arc<AppState> = AppState::new(Arc::new(config), db);
    let shared = state.clone();
    let srv = web_test::server(move || {
        let state = shared.clone();
        async move {
            App::new().state(state).service(
                web::scope("/api/v1")
                    .service(web::resource("/stacks").route(web::get().to(stacks::list)))
                    .service(
                        web::resource("/container-backups")
                            .route(web::get().to(container_backups::list))
                            .route(web::post().to(container_backups::create)),
                    )
                    .service(web::resource("/container-backups/job").route(web::get().to(container_backups::job)))
                    .service(web::resource("/container-backups/{id}/restore").route(web::post().to(container_backups::restore)))
                    .service(web::resource("/container-backups/{id}").route(web::delete().to(container_backups::remove)))
                    .service(
                        web::resource("/stacks/{id}")
                            .route(web::post().to(stacks::install))
                            .route(web::delete().to(stacks::remove)),
                    )
                    .service(web::resource("/stacks/{id}/check").route(web::post().to(stacks::check)))
                    .service(web::resource("/stacks/{id}/settings").route(web::put().to(stacks::reconfigure)))
                    .service(web::resource("/stacks/{id}/action").route(web::post().to(stacks::act)))
                    .service(web::resource("/stacks/{id}/job").route(web::get().to(stacks::job)))
                    .service(web::resource("/stacks/{id}/services").route(web::get().to(stacks::services)))
                    .service(web::resource("/stacks/{id}/login").route(web::post().to(stacks::login)))
                    .service(web::resource("/stacks/{id}/enter").route(web::post().to(stacks::enter))),
            )
        }
    })
    .await;
    (srv, state)
}

async fn call(srv: &TestServer, method: Method, path: &str, body: Option<Value>) -> (u16, Value) {
    let req = srv
        .request(method, srv.url(path))
        .header("Authorization", format!("Bearer {}", generate_token("admin", SECRET).unwrap()))
        .timeout(Duration::from_secs(60));
    let resp = match body {
        Some(body) => req.send_json(&body).await.unwrap(),
        None => req.send().await.unwrap(),
    };
    let bytes = resp.body().limit(16 << 20).await.unwrap_or_default();
    (resp.status().as_u16(), serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

/// Waits for the app's job to end; its state, and its log on failure.
async fn finished(srv: &TestServer) -> String {
    finished_at(srv, &format!("/api/v1/stacks/{APP}/job")).await
}

async fn finished_at(srv: &TestServer, path: &str) -> String {
    let deadline = Instant::now() + Duration::from_secs(600);
    loop {
        let (_, job) = call(srv, Method::GET, path, None).await;
        let state = job["state"].as_str().unwrap_or_default().to_string();
        if state != "running" {
            if state != "succeeded" {
                let lines: Vec<&str> = job["lines"].as_array().unwrap().iter().filter_map(|l| l["text"].as_str()).collect();
                eprintln!("job {state}:\n{}", lines.join("\n"));
            }
            return state;
        }
        assert!(Instant::now() < deadline, "the job did not end");
        tokio::time::sleep(Duration::from_secs(1)).await;
    }
}

/// The app's health after the agent's watch looks, waiting while its
/// containers start.
async fn health(srv: &TestServer, state: &Arc<AppState>, until: &str) -> String {
    let deadline = Instant::now() + Duration::from_secs(90);
    loop {
        server_box_monitor::stacks::health::check(state).await;
        let (_, list) = call(srv, Method::GET, "/api/v1/stacks", None).await;
        let app = list["apps"].as_array().unwrap().iter().find(|a| a["manifest"]["id"] == APP).unwrap().clone();
        let now = app["health"]["state"].as_str().unwrap_or_default().to_string();
        if now == until || Instant::now() > deadline {
            return now;
        }
        tokio::time::sleep(Duration::from_secs(2)).await;
    }
}

async fn notifications(state: &Arc<AppState>) -> Vec<(String, String)> {
    sqlx::query_as("SELECT source, subject FROM desk_notification ORDER BY id").fetch_all(&state.db).await.unwrap()
}

/// A port free now.
fn free_port() -> u16 {
    std::net::TcpListener::bind(("0.0.0.0", 0)).unwrap().local_addr().unwrap().port()
}

/// GET [path] from the service itself, retried while it starts.
async fn fetch(port: u16, path: &str) -> String {
    let deadline = Instant::now() + Duration::from_secs(60);
    loop {
        let answer = raw(port, format!("GET {path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")).await;
        if answer.starts_with("HTTP/1.1 200") || Instant::now() > deadline {
            return answer;
        }
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}

async fn raw(port: u16, request: String) -> String {
    let Ok(mut stream) = tokio::net::TcpStream::connect(("127.0.0.1", port)).await else { return String::new() };
    if stream.write_all(request.as_bytes()).await.is_err() {
        return String::new();
    }
    let mut out = Vec::new();
    let _ = tokio::time::timeout(Duration::from_secs(10), stream.read_to_end(&mut out)).await;
    String::from_utf8_lossy(&out).into_owned()
}

/// Whatever a failed run left: the project's containers and network.
struct Cleanup;

impl Drop for Cleanup {
    fn drop(&mut self) {
        let _ = std::process::Command::new("sh")
            .arg("-c")
            .arg(
                format!(
                    "docker ps -aq --filter label=com.docker.compose.project={PROJECT} | xargs -r docker rm -f; \
                     docker network rm {PROJECT}_default"
                ),
            )
            .output();
    }
}

#[ntex::test]
#[ignore = "deploys on a real Docker: SBM_E2E_DOCKER=1"]
async fn a_web_app_lives_on_a_real_docker() {
    if std::env::var("SBM_E2E_DOCKER").is_err() {
        eprintln!("SBM_E2E_DOCKER is not set");
        return;
    }
    let _cleanup = Cleanup;
    let apps = apps_dir();
    let (srv, state) = setup(apps.path()).await;
    let (port, status_port) = (free_port(), free_port());
    let settings = json!({ "port": port, "status_port": status_port, "greeting": "first" });

    // Installed: the service answers with the setting, and so does its proxy.
    let (status, body) = call(
        &srv,
        Method::POST,
        &format!("/api/v1/stacks/{APP}"),
        Some(json!({ "current_password": common::PASSWORD, "settings": settings, "acknowledged": true })),
    )
    .await;
    assert_eq!(status, 202, "{body}");
    assert_eq!(finished(&srv).await, "succeeded");
    assert!(fetch(port, "/greeting.txt").await.ends_with("first\n"));
    // The host's time zone, and the shared folder made for it.
    assert!(!fetch(port, "/tz.txt").await.trim().is_empty());
    assert!(state.stacks.shared().join("media").is_dir());
    // The sign-in's password is the one generated into its env file.
    let (status, login) =
        call(&srv, Method::POST, &format!("/api/v1/stacks/{APP}/login"), Some(json!({ "current_password": common::PASSWORD }))).await;
    assert_eq!(status, 200, "{login}");
    let env = std::fs::read_to_string(state.stacks.dir(APP).join(".env")).unwrap();
    assert!(env.contains(&format!("ADMIN_PASSWORD='{}'", login["password"].as_str().unwrap())), "{login}");
    let (_, entry) = call(&srv, Method::POST, &format!("/api/v1/stacks/{APP}/enter"), None).await;
    let proxy = entry["port"].as_u64().expect("a proxy") as u16;
    let ticket = entry["ticket"].as_str().unwrap();
    let answer = raw(proxy, format!("GET /__sbm/enter?ticket={ticket}&next=%2Fgreeting.txt HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n")).await;
    let cookie = answer
        .lines()
        .find_map(|l| l.strip_prefix("set-cookie: "))
        .and_then(|c| c.split(';').next())
        .expect("a session cookie")
        .to_string();
    let answer = raw(proxy, format!("GET /greeting.txt HTTP/1.1\r\nHost: localhost\r\nCookie: {cookie}\r\nConnection: close\r\n\r\n")).await;
    assert!(answer.starts_with("HTTP/1.1 200") && answer.ends_with("first\n"), "{answer}");
    let (_, services) = call(&srv, Method::GET, &format!("/api/v1/stacks/{APP}/services"), None).await;
    assert_eq!(services["services"][0]["service"], "web", "{services}");
    assert_eq!(health(&srv, &state, "healthy").await, "healthy");

    // Down behind the agent's back: said once, and that it is back.
    let source = format!("stack:{APP}");
    std::process::Command::new("docker").args(["stop", "sbm-serverbox-testweb_e2e-web-1"]).output().unwrap();
    assert_eq!(health(&srv, &state, "down").await, "down");
    server_box_monitor::stacks::health::check(&state).await;
    std::process::Command::new("docker").args(["start", "sbm-serverbox-testweb_e2e-web-1"]).output().unwrap();
    assert_eq!(health(&srv, &state, "healthy").await, "healthy");
    let said: Vec<String> = notifications(&state).await.into_iter().filter(|(s, _)| *s == source).map(|(_, subject)| subject).collect();
    assert_eq!(said, ["Test Web App is down", "Test Web App is running again"], "{said:?}");

    // Backed up whole, changed, restored: what it served is back.
    let site = state.stacks.dir(APP).join("site");
    std::fs::write(site.join("mine.txt"), "kept").unwrap();
    let (_, ps) = call(&srv, Method::GET, &format!("/api/v1/stacks/{APP}/services"), None).await;
    let container = ps["services"][0]["name"].as_str().unwrap().to_string();
    let (status, body) =
        call(&srv, Method::POST, "/api/v1/container-backups", Some(json!({ "containers": [container], "project": true, "stop": true }))).await;
    assert_eq!(status, 202, "{body}");
    assert_eq!(finished_at(&srv, "/api/v1/container-backups/job").await, "succeeded");
    let (_, list) = call(&srv, Method::GET, "/api/v1/container-backups", None).await;
    let backup = list["backups"][0].clone();
    assert_eq!(backup["label"], PROJECT, "{list}");
    assert_eq!(backup["archives"].as_array().unwrap().len(), 1, "{backup}");
    // The folder every app shares is no one app's data.
    assert_eq!(backup["skipped"][0]["why"], "shared", "{backup}");
    assert!(backup["archives"][0]["bytes"].as_u64().unwrap() > 0);
    assert!(fetch(port, "/greeting.txt").await.ends_with("first\n"), "started again after the backup");
    std::fs::remove_file(site.join("mine.txt")).unwrap();
    std::fs::write(site.join("stray.txt"), "gone after the restore").unwrap();
    let id = backup["id"].as_str().unwrap();
    let (status, body) =
        call(&srv, Method::POST, &format!("/api/v1/container-backups/{id}/restore"), Some(json!({ "current_password": common::PASSWORD }))).await;
    assert_eq!(status, 202, "{body}");
    assert_eq!(finished_at(&srv, "/api/v1/container-backups/job").await, "succeeded");
    assert_eq!(std::fs::read_to_string(site.join("mine.txt")).unwrap(), "kept");
    assert!(!site.join("stray.txt").exists());
    assert!(fetch(port, "/greeting.txt").await.ends_with("first\n"));
    let (status, _) = call(&srv, Method::DELETE, &format!("/api/v1/container-backups/{id}"), Some(json!({ "current_password": common::PASSWORD }))).await;
    assert_eq!(status, 204);

    // Its own running ports are not in use for it: restarting checks and goes.
    let (status, body) = call(&srv, Method::POST, &format!("/api/v1/stacks/{APP}/action"), Some(json!({ "action": "restart" }))).await;
    assert_eq!(status, 202, "{body}");
    assert_eq!(finished(&srv).await, "succeeded");

    // A port taken by something else is refused, by its setting.
    let held = std::net::TcpListener::bind(("0.0.0.0", 0)).unwrap();
    let taken = held.local_addr().unwrap().port();
    let (status, body) = call(
        &srv,
        Method::PUT,
        &format!("/api/v1/stacks/{APP}/settings"),
        Some(json!({ "current_password": common::PASSWORD, "settings": { "port": port, "status_port": taken, "greeting": "x" } })),
    )
    .await;
    assert_eq!((status, body["error"].as_str(), body["field"].as_str()), (409, Some("portTaken"), Some("status_port")), "{body}");
    drop(held);

    // New settings: deployed again, on the new port, saying the new words.
    let moved = free_port();
    let (status, body) = call(
        &srv,
        Method::PUT,
        &format!("/api/v1/stacks/{APP}/settings"),
        Some(json!({ "current_password": common::PASSWORD, "settings": { "port": moved, "status_port": status_port, "greeting": "second" } })),
    )
    .await;
    assert_eq!(status, 202, "{body}");
    assert_eq!(finished(&srv).await, "succeeded");
    assert!(fetch(moved, "/greeting.txt").await.ends_with("second\n"));
    assert!(raw(port, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".into()).await.is_empty(), "the old port is let go");
    // The proxy follows the service.
    let answer = raw(proxy, format!("GET /greeting.txt HTTP/1.1\r\nHost: localhost\r\nCookie: {cookie}\r\nConnection: close\r\n\r\n")).await;
    assert!(answer.ends_with("second\n"), "{answer}");

    // Stopped, then started again.
    let (status, _) = call(&srv, Method::POST, &format!("/api/v1/stacks/{APP}/action"), Some(json!({ "action": "stop" }))).await;
    assert_eq!(status, 202);
    assert_eq!(finished(&srv).await, "succeeded");
    assert!(raw(moved, "GET / HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".into()).await.is_empty());
    // Stopped on purpose: no notification.
    let before = notifications(&state).await.len();
    assert_eq!(health(&srv, &state, "stopped").await, "stopped");
    assert_eq!(notifications(&state).await.len(), before);
    let (status, _) = call(&srv, Method::POST, &format!("/api/v1/stacks/{APP}/action"), Some(json!({ "action": "start" }))).await;
    assert_eq!(status, 202);
    assert_eq!(finished(&srv).await, "succeeded");
    assert!(fetch(moved, "/greeting.txt").await.ends_with("second\n"));

    // Removed with its data: the containers and the folder go.
    let dir = state.stacks.dir(APP);
    let (status, body) = call(
        &srv,
        Method::DELETE,
        &format!("/api/v1/stacks/{APP}"),
        Some(json!({ "current_password": common::PASSWORD, "purge": true })),
    )
    .await;
    assert_eq!(status, 202, "{body}");
    assert_eq!(finished(&srv).await, "succeeded");
    assert!(!dir.exists(), "{} is left", dir.display());
    let (_, list) = call(&srv, Method::GET, "/api/v1/stacks", None).await;
    let app = list["apps"].as_array().unwrap().iter().find(|a| a["manifest"]["id"] == APP).unwrap();
    assert_eq!(app["stack"], Value::Null);
}
