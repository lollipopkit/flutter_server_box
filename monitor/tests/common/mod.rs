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
    AppState::new(Arc::new(config), db)
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
        let resp = match body {
            Some(body) => req.send_json(&body).await.unwrap(),
            None => req.send().await.unwrap(),
        };
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
