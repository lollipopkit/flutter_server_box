//! `/api/v1/update`: the agent's newest release, read the way `install.sh`
//! reads it, and the desk notification it leaves once per version.

mod common;

use std::collections::HashMap;
use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex};

use ntex::http::Method;
use ntex::web::test::{self as web_test, TestServer};
use ntex::web::{self, App};
use sbm_parser::monitor_agent::{InstallKind, UPDATE_LOG, releases_url};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::desk_themes::Fetch;
use server_box_monitor::api::server::AppState;
use server_box_monitor::api::update;
use server_box_monitor::core::config::Config;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// Answers from memory, and counts what it was asked for.
struct Memory {
    pages: Mutex<HashMap<String, String>>,
    asked: Mutex<Vec<String>>,
}

impl Fetch for Memory {
    fn get<'a>(&'a self, url: &'a str, _max: usize) -> Pin<Box<dyn Future<Output = Result<Vec<u8>, String>> + Send + 'a>> {
        self.asked.lock().unwrap().push(url.to_string());
        let answer = self.pages.lock().unwrap().get(url).map(|p| p.clone().into_bytes()).ok_or_else(|| "HTTP 403".to_string());
        Box::pin(async move { answer })
    }
}

async fn setup(pages: HashMap<String, String>) -> (Arc<AppState>, Arc<Memory>, TestServer) {
    let _ = rustls::crypto::ring::default_provider().install_default();
    let db = common::database().await;
    common::add_owner(&db).await;
    let state = AppState::new(Arc::new(Config { jwt_secret: Some(SECRET.into()), ..Default::default() }), db);
    let memory = Arc::new(Memory { pages: Mutex::new(pages), asked: Mutex::default() });
    state.update.set_fetch(memory.clone());
    let srv = web_test::server({
        let state = state.clone();
        move || {
            let state = state.clone();
            async move {
                App::new().state(state).service(
                    web::scope("/api/v1")
                        .route("/update", web::get().to(update::get))
                        .route("/update/run", web::post().to(update::start)),
                )
            }
        }
    })
    .await;
    (state, memory, srv)
}

async fn call(srv: &TestServer, signed: bool, path: &str) -> (u16, serde_json::Value) {
    send(srv, signed, Method::GET, path).await
}

async fn send(srv: &TestServer, signed: bool, method: Method, path: &str) -> (u16, serde_json::Value) {
    let mut req = srv.request(method.clone(), srv.url(path));
    if signed {
        req = req.header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()));
    }
    let resp = if method == Method::POST {
        req.header("content-type", "application/json").send_body("{}").await.unwrap()
    } else {
        req.send().await.unwrap()
    };
    let body = resp.body().await.unwrap();
    (resp.status().as_u16(), serde_json::from_slice(&body).unwrap_or_default())
}

async fn notices(state: &AppState) -> Vec<String> {
    sqlx::query_scalar("SELECT params FROM desk_notification WHERE source = 'agent' AND kind = 'agent.update'")
        .fetch_all(&state.db)
        .await
        .unwrap()
}

/// A page full of the app's releases sends the read to the next one, where
/// the agent's is; a newer version is said once.
#[ntex::test]
async fn a_newer_release_is_found_and_said_once() {
    let apps = format!("[{}]", vec![r#"{"tag_name":"v1.0.1"}"#; 100].join(","));
    let pages = HashMap::from([
        (releases_url(1), apps),
        (releases_url(2), r#"[{"tag_name":"monitor-v99.0.0"},{"tag_name":"monitor-v98.0.0"}]"#.into()),
    ]);
    let (state, memory, srv) = setup(pages).await;

    assert_eq!(call(&srv, false, "/api/v1/update").await.0, 401);
    // Nothing read yet, and a plain read does not wait on GitHub.
    let (_, body) = call(&srv, true, "/api/v1/update").await;
    assert_eq!((body["latest"].clone(), body["checked_at"].clone()), (serde_json::Value::Null, serde_json::Value::Null));
    assert!(memory.asked.lock().unwrap().is_empty());
    let (status, body) = call(&srv, true, "/api/v1/update?check=1").await;
    assert_eq!(status, 200);
    assert_eq!(body["version"], update::VERSION);
    assert_eq!(body["latest"], "99.0.0");
    assert_eq!(body["outdated"], true);
    assert!(body["checked_at"].is_string());
    // A test binary is under target/, which install.sh never puts there.
    assert_eq!(body["install"], "other");
    assert!(body.get("command").is_none());

    // The last read is answered; a check this soon after reads nothing.
    call(&srv, true, "/api/v1/update").await;
    call(&srv, true, "/api/v1/update?check=1").await;
    assert_eq!(memory.asked.lock().unwrap().len(), 2);
    let said = notices(&state).await;
    assert_eq!(said.len(), 1);
    let params: serde_json::Value = serde_json::from_str(&said[0]).unwrap();
    assert_eq!(params, serde_json::json!({ "version": "99.0.0", "current": update::VERSION }));

    // GitHub stops answering: the version found is still out, and said once.
    memory.pages.lock().unwrap().clear();
    state.update.age_last_read();
    let (_, body) = call(&srv, true, "/api/v1/update?check=1").await;
    assert_eq!((body["latest"].clone(), body["outdated"].clone()), ("99.0.0".into(), true.into()));
    assert_eq!(body["error"], "HTTP 403");
    assert_eq!(notices(&state).await.len(), 1);
}

/// GitHub not answering is no newer version, and says why.
#[ntex::test]
async fn a_failed_read_is_no_update() {
    let (state, _, srv) = setup(HashMap::new()).await;
    let (status, body) = call(&srv, true, "/api/v1/update?check=1").await;
    assert_eq!(status, 200);
    assert_eq!(body["latest"], serde_json::Value::Null);
    assert_eq!(body["outdated"], false);
    assert_eq!(body["error"], "HTTP 403");
    assert!(notices(&state).await.is_empty());
}

/// An update started earlier is told from its log, by whichever agent reads
/// it — the one that comes back after the restart, too.
#[ntex::test]
async fn a_started_update_is_told_from_its_log() {
    let (state, _, srv) = setup(HashMap::new()).await;
    assert!(call(&srv, true, "/api/v1/update").await.1.get("run").is_none());

    let dir = tempfile::tempdir().unwrap();
    state.update.set_local(dir.path(), InstallKind::Script);
    let log = dir.path().join(UPDATE_LOG);
    let now = chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Secs, true);
    std::fs::write(&log, format!("sbm-update-start {now}\nDownloading the package\n")).unwrap();
    let (_, body) = call(&srv, true, "/api/v1/update").await;
    assert_eq!(body["run"]["state"], "running");
    assert_eq!(body["run"]["lines"], serde_json::json!(["Downloading the package"]));
    assert!(body["command"].is_string());
    // One at a time.
    assert_eq!(send(&srv, true, Method::POST, "/api/v1/update/run").await, (409, serde_json::json!({ "error": "running" })));

    std::fs::write(&log, format!("sbm-update-start {now}\nUpgrade success\nsbm-update-exit 0\n")).unwrap();
    assert_eq!(call(&srv, true, "/api/v1/update").await.1["run"]["state"], "done");
    std::fs::write(&log, "sbm-update-start 2020-01-01T00:00:00Z\nDownloading\n").unwrap();
    assert_eq!(call(&srv, true, "/api/v1/update").await.1["run"]["state"], "interrupted");
}

/// Only an agent `install.sh` installed is updated by it, and only by an
/// account that may act.
#[ntex::test]
async fn only_an_installer_agent_is_started() {
    let (_, _, srv) = setup(HashMap::new()).await;
    assert_eq!(send(&srv, false, Method::POST, "/api/v1/update/run").await.0, 401);
    // A test binary is under target/.
    assert_eq!(send(&srv, true, Method::POST, "/api/v1/update/run").await, (409, serde_json::json!({ "error": "not_script" })));
}
