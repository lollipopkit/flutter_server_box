//! The agent's account for the integration tests.
//!
//! Built the way the agent does — migrations, then the account's row —
//! rather than writing rows by hand, so a test cannot pass against a shape
//! the agent would never store.
#![allow(dead_code)]

use std::sync::Arc;

use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;
use server_box_monitor::db::accounts;
use sqlx::SqlitePool;

/// The account's password.
pub const PASSWORD: &str = "test-password";

/// A fresh in-memory database, migrated.
pub async fn database() -> SqlitePool {
    let db = SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    db
}

/// The account, password [`PASSWORD`]. bcrypt at its lowest cost: what is
/// under test is never how expensive a hash is.
pub async fn add_owner(db: &SqlitePool) {
    let hash = bcrypt::hash(PASSWORD, 4).unwrap();
    accounts::insert_owner(db, &hash).await.unwrap();
}

/// An `AppState` over a fresh database with the account.
pub async fn owned_state(config: Config) -> Arc<AppState> {
    let db = database().await;
    add_owner(&db).await;
    let state = AppState::new(Arc::new(config), db);
    state.agent.reach_this_machine_only();
    state
}

/// For the machine-management endpoints (`api::machine`): an agent with its
/// account, mounted on the real route table.
pub mod machine {
    use std::sync::{Arc, Once};

    use ntex::http::Method;
    use ntex::web::App;
    use ntex::web::test::{self as web_test, TestServer};
    use serde_json::Value;
    use server_box_monitor::api::auth::generate_token;
    use server_box_monitor::api::server::{AppState, configure_api};
    use server_box_monitor::core::config::Config;

    pub const SECRET: &str = "test-secret-that-is-long-enough-32ch";

    /// Out of the crate's directory, so a file a test writes cannot land in
    /// the sources.
    fn leave_the_crate() {
        static ONCE: Once = Once::new();
        ONCE.call_once(|| {
            let dir = std::env::temp_dir().join(format!("sbm-machine-api-{}", std::process::id()));
            std::fs::create_dir_all(&dir).unwrap();
            std::env::set_current_dir(&dir).unwrap();
        });
    }

    /// The server, and its database for asserting what was recorded.
    pub async fn server() -> (TestServer, sqlx::SqlitePool) {
        let (srv, state) = server_with(Config::default()).await;
        (srv, state.db.clone())
    }

    /// [server] with [config], its JWT secret the tests'.
    pub async fn server_with(config: Config) -> (TestServer, Arc<AppState>) {
        leave_the_crate();
        static ONCE: Once = Once::new();
        ONCE.call_once(|| {
            let _ = rustls::crypto::ring::default_provider().install_default();
        });
        let config = Config { jwt_secret: Some(SECRET.to_string()), ..config };
        let db = super::database().await;
        super::add_owner(&db).await;
        let state = AppState::new(Arc::new(config), db);
        // The models and servers the tests run are on loopback.
        state.agent.reach_this_machine_only();
        let shared = state.clone();
        let srv = web_test::server(move || {
            let state = shared.clone();
            async move {
                let limit = state.remote_access.exec.max_request_bytes;
                App::new().state(state).configure(configure_api(limit))
            }
        })
        .await;
        (srv, state)
    }

    /// The `(action, result, subject, detail)` of every `machine` row,
    /// oldest first.
    pub async fn audit(
        db: &sqlx::SqlitePool,
    ) -> Vec<(String, String, Option<String>, Option<String>)> {
        sqlx::query_as(
            "SELECT action, result, subject, detail FROM access_log WHERE kind = 'machine' ORDER BY id",
        )
        .fetch_all(db)
        .await
        .unwrap()
    }

    /// One request as [user] (`None` for no token), and its status and body.
    pub async fn call(
        srv: &TestServer,
        signed: bool,
        method: Method,
        path: &str,
        body: Option<Value>,
    ) -> (u16, Value) {
        let mut req = srv
            .request(method, srv.url(path))
            .timeout(std::time::Duration::from_secs(30));
        if signed {
            req = req.header(
                "Authorization",
                format!("Bearer {}", generate_token(SECRET).unwrap()),
            );
        }
        let started = std::time::Instant::now();
        let resp = match body {
            Some(body) => req.send_json(&body).await,
            None => req.send().await,
        }
        .unwrap_or_else(|e| panic!("{path}: {e:?} after {:?}", started.elapsed()));
        let status = resp.status().as_u16();
        // A process table is well past the client's default body limit.
        let bytes = resp.body().limit(16 * 1024 * 1024).await.unwrap_or_default();
        (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
    }

    /// A POST answered with a stream: the whole of it, once it ends.
    #[allow(dead_code)]
    /// Posts raw [bytes] with [content_type].
    pub async fn post_bytes(srv: &TestServer, path: &str, content_type: &str, bytes: Vec<u8>) -> (u16, Value) {
        let resp = srv
            .request(Method::POST, srv.url(path))
            .timeout(std::time::Duration::from_secs(60))
            .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()))
            .header("Content-Type", content_type)
            .send_body(bytes)
            .await
            .unwrap();
        let status = resp.status().as_u16();
        let body = resp.json::<Value>().await.unwrap_or(Value::Null);
        (status, body)
    }

    pub async fn post_text(srv: &TestServer, path: &str, body: Value) -> (u16, String) {
        let resp = srv
            .request(Method::POST, srv.url(path))
            .timeout(std::time::Duration::from_secs(60))
            .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()))
            .send_json(&body)
            .await
            .unwrap();
        let status = resp.status().as_u16();
        // A stream ends when the work does, which can outlast the client's
        // default 5 s for a body when every test runs at once.
        let bytes = resp
            .body()
            .limit(16 * 1024 * 1024)
            .timeout(ntex::time::Millis::from_secs(60))
            .await
            .expect("the whole stream");
        (status, String::from_utf8_lossy(&bytes).into_owned())
    }
}

/// A first-party package the agent ships (`store/desk/<id>.fsba`), installed
/// from its catalog and approved on a [`machine`] server, its backend called
/// as the desk calls it. Root's work gets an empty sudo password: these run
/// as root on a throwaway machine.
pub mod package {
    use std::time::{Duration, Instant};

    use ntex::http::Method;
    use ntex::web::test::TestServer;
    use serde_json::{Value, json};

    use super::machine::call;

    pub struct App<'a> {
        srv: &'a TestServer,
        id: String,
    }

    /// A function's failure: the agent's code (`failedPrecondition`, …) and
    /// its words.
    #[derive(Debug, PartialEq, Eq)]
    pub struct Refusal {
        pub error: String,
        pub message: String,
    }

    /// A job that ended: its state, its value or error, its lines.
    #[derive(Debug)]
    pub struct Ended {
        pub state: String,
        pub value: Value,
        pub error: Value,
        pub lines: Vec<String>,
    }

    /// [id] installed from the catalog and approved with what it asks for.
    pub async fn install<'a>(srv: &'a TestServer, id: &str) -> App<'a> {
        let (status, app) = call(srv, true, Method::POST, &format!("/api/v1/apps/catalog/{id}/install"), None).await;
        assert_eq!(status, 200, "{id}: {app}");
        let body = json!({ "sha256": app["sha256"], "permissions": app["manifest"]["permissions"], "current_password": super::PASSWORD });
        let (status, approved) = call(srv, true, Method::PUT, &format!("/api/v1/apps/{id}/approval"), Some(body)).await;
        assert_eq!(status, 200, "{id}: {approved}");
        App { srv, id: id.to_string() }
    }

    fn sudo(root: bool) -> Value {
        if root { json!({ "password": "" }) } else { Value::Null }
    }

    impl App<'_> {
        /// [function] of the backend's `api`, as root when [root].
        pub async fn call(&self, function: &str, args: Value, root: bool) -> Result<Value, Refusal> {
            let body = json!({ "function": function, "args": args, "sudo": sudo(root) });
            let (status, r) = call(self.srv, true, Method::POST, &format!("/api/v1/apps/{}/call", self.id), Some(body)).await;
            if status == 200 {
                return Ok(r["value"].clone());
            }
            Err(Refusal { error: r["error"].as_str().unwrap_or_default().into(), message: r["message"].as_str().unwrap_or_default().into() })
        }

        /// [function] of its `jobs`, as root when [root], followed until it
        /// ends (at most [wait]).
        pub async fn job(&self, function: &str, args: Value, root: bool, wait: Duration) -> Ended {
            let body = json!({ "function": function, "args": args, "sudo": sudo(root) });
            let (status, r) = call(self.srv, true, Method::POST, &format!("/api/v1/apps/{}/jobs", self.id), Some(body)).await;
            assert_eq!(status, 202, "{function}: {r}");
            let deadline = Instant::now() + wait;
            loop {
                let (_, v) = call(self.srv, true, Method::GET, &format!("/api/v1/apps/{}/jobs", self.id), None).await;
                if v["state"] != "running" {
                    let lines = v["lines"].as_array().into_iter().flatten().filter_map(|l| l["text"].as_str().map(str::to_string)).collect();
                    return Ended { state: v["state"].as_str().unwrap_or_default().into(), value: v["value"].clone(), error: v["error"].clone(), lines };
                }
                assert!(Instant::now() < deadline, "{function}: did not end");
                tokio::time::sleep(Duration::from_secs(2)).await;
            }
        }

        /// As [Self::job], which must end well; its value.
        pub async fn job_ok(&self, function: &str, args: Value, root: bool, wait: Duration) -> Value {
            let ended = self.job(function, args, root, wait).await;
            assert_eq!(ended.state, "succeeded", "{function}: {:?}\n{}", ended.error, ended.lines.join("\n"));
            ended.value
        }
    }
}

/// Catalog apps (`store/apps`) on a real Docker, for the e2e tests that
/// deploy them: each a copy under a name of its own (`<name>_e2e`, its built
/// images too), so a copy an agent on the same machine deployed is never
/// touched.
pub mod catalog {
    use std::time::{Duration, Instant};

    use ntex::http::Method;
    use ntex::web::test::TestServer;
    use serde_json::{Value, json};

    use super::machine::call;

    /// `store/apps/<id>` copied as `<id>_e2e` into [dir]; the copy's id.
    pub fn copy_app(id: &str, dir: &std::path::Path) -> String {
        let from = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../store/apps").join(id);
        let (publisher, name) = id.split_once('.').unwrap();
        let copy = format!("{publisher}.{name}_e2e");
        let to = dir.join(&copy);
        std::fs::create_dir(&to).unwrap();
        for entry in std::fs::read_dir(&from).unwrap() {
            let entry = entry.unwrap();
            let mut text = std::fs::read_to_string(entry.path()).unwrap();
            if entry.file_name() == "manifest.toml" {
                text = text.replacen(&format!("name = \"{name}\""), &format!("name = \"{name}_e2e\""), 1);
            } else {
                // The image a package builds, which a purge removes.
                text = text.replace(&format!("localhost/{publisher}-{name}:"), &format!("localhost/{publisher}-{name}_e2e:"));
            }
            std::fs::write(to.join(entry.file_name()), text).unwrap();
        }
        copy
    }

    /// The compose project of app [id].
    pub fn project(id: &str) -> String {
        let (publisher, name) = id.split_once('.').unwrap();
        format!("sbm-{publisher}-{name}")
    }

    /// The containers of app [id]'s project, by `docker ps -a`.
    pub fn containers(id: &str) -> Vec<String> {
        let out = std::process::Command::new("docker")
            .args(["ps", "-aq", "--filter", &format!("label=com.docker.compose.project={}", project(id))])
            .output()
            .unwrap();
        String::from_utf8_lossy(&out.stdout).split_whitespace().map(str::to_string).collect()
    }

    /// Waits for app [id]'s job to end; its state, and its log on failure.
    pub async fn finished(srv: &TestServer, id: &str) -> String {
        let deadline = Instant::now() + Duration::from_secs(1800);
        loop {
            let (_, job) = call(srv, true, Method::GET, &format!("/api/v1/stacks/{id}/job"), None).await;
            let state = job["state"].as_str().unwrap_or_default().to_string();
            if state != "running" {
                if state != "succeeded" {
                    let lines: Vec<&str> = job["lines"].as_array().into_iter().flatten().filter_map(|l| l["text"].as_str()).collect();
                    eprintln!("job {state}:\n{}", lines.join("\n"));
                }
                return state;
            }
            assert!(Instant::now() < deadline, "the job did not end");
            tokio::time::sleep(Duration::from_secs(2)).await;
        }
    }

    /// The app's containers and network gone, should the test end early (its
    /// data is in a temporary folder of the agent's).
    pub struct Cleanup(pub String);

    impl Drop for Cleanup {
        fn drop(&mut self) {
            let project = project(&self.0);
            let _ = std::process::Command::new("sh")
                .arg("-c")
                .arg(format!("docker ps -aq --filter label=com.docker.compose.project={project} | xargs -r docker rm -f; docker network rm {project}_default"))
                .output();
        }
    }

    /// App [id] deployed with the settings its check offers, licence and
    /// notices accepted; those settings, once the deploy succeeded.
    pub async fn deploy(srv: &TestServer, id: &str) -> (Value, Cleanup) {
        let (status, check) = call(srv, true, Method::POST, &format!("/api/v1/stacks/{id}/check"), Some(json!({ "settings": {} }))).await;
        assert_eq!(status, 200, "{check}");
        let (status, body) = call(
            srv,
            true,
            Method::POST,
            &format!("/api/v1/stacks/{id}"),
            Some(json!({ "current_password": super::PASSWORD, "settings": check["settings"], "acknowledged": true, "accept_license": true })),
        )
        .await;
        assert_eq!(status, 202, "{body}");
        let cleanup = Cleanup(id.to_string());
        assert_eq!(finished(srv, id).await, "succeeded", "{id} deployed");
        (check["settings"].clone(), cleanup)
    }

    /// App [id] and its data removed through the agent: nothing of its
    /// project is left.
    pub async fn remove(srv: &TestServer, id: &str) {
        let (status, body) =
            call(srv, true, Method::DELETE, &format!("/api/v1/stacks/{id}"), Some(json!({ "current_password": super::PASSWORD, "purge": true }))).await;
        assert_eq!(status, 202, "{body}");
        assert_eq!(finished(srv, id).await, "succeeded", "{id} removed");
        assert_eq!(containers(id), Vec::<String>::new(), "{id}: containers left");
    }
}
