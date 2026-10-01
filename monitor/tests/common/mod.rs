//! Accounts and roles for the integration tests.
//!
//! Every route checks the caller's role now (issue #1610), so a test that
//! signs in as `admin` needs an `admin` account that holds the role its
//! assertions assume. These build it the way the agent does — migrations,
//! then `db::bootstrap::ensure_roles` — rather than writing role rows by
//! hand, so a test cannot pass against a shape the agent would never store.
#![allow(dead_code)]

use std::sync::Arc;

use server_box_monitor::api::server::AppState;
use server_box_monitor::core::config::Config;
use server_box_monitor::core::permissions::{Grants, InitPermissions, Role};
use server_box_monitor::db::{accounts, bootstrap};
use sqlx::SqlitePool;

/// The password every seeded account has.
pub const PASSWORD: &str = "test-password";

/// The accounts the tests sign in as. `intruder` is the second account the
/// ownership tests need; it holds the same role, so what tells it apart is
/// only that it is not the account that opened the thing.
pub const ACCOUNTS: [&str; 2] = ["admin", "intruder"];

/// A fresh in-memory database, migrated.
pub async fn database() -> SqlitePool {
    let db = SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    db
}

/// Adds [username] with [role], password [`PASSWORD`]. bcrypt at its lowest
/// cost: what is under test is never how expensive a hash is.
pub async fn add_account(db: &SqlitePool, username: &str, role: &str) {
    let hash = bcrypt::hash(PASSWORD, 4).unwrap();
    accounts::insert_account(db, username, &hash, role)
        .await
        .unwrap();
}

/// [`ACCOUNTS`], both admins, and the admin role holding what [config]'s old
/// switches gave — the state an agent upgraded from that config is in. The
/// tests written before roles describe what they need as such a config.
pub async fn seed_as_upgrade(db: &SqlitePool, config: &Config) {
    for name in ACCOUNTS {
        add_account(db, name, "admin").await;
    }
    bootstrap::ensure_roles(db, config, InitPermissions::Full)
        .await
        .unwrap();
}

/// An `AppState` over a fresh database seeded by [`seed_as_upgrade`].
pub async fn upgraded_state(config: Config) -> Arc<AppState> {
    let db = database().await;
    seed_as_upgrade(&db, &config).await;
    AppState::new(Arc::new(config), db)
}

/// Replaces what [role] grants.
pub async fn set_grants(db: &SqlitePool, role: &str, grants: &Grants) {
    assert!(accounts::set_grants(db, role, grants).await.unwrap());
}

/// What [role] grants now.
pub async fn grants_of(db: &SqlitePool, role: &str) -> Grants {
    accounts::role(db, role).await.unwrap().unwrap().grants
}

/// Creates [role] as given.
pub async fn add_role(db: &SqlitePool, role: &Role) {
    accounts::insert_role(db, role).await.unwrap();
}

/// For the machine-management endpoints (`api::machine`): an agent whose
/// `admin` and `intruder` hold every grant and whose `viewer` holds none,
/// mounted on the real route table.
pub mod machine {
    use std::sync::{Arc, Once};

    use ntex::http::Method;
    use ntex::web::App;
    use ntex::web::test::{self as web_test, TestServer};
    use serde_json::Value;
    use server_box_monitor::api::auth::generate_token;
    use server_box_monitor::api::server::{AppState, configure_api};
    use server_box_monitor::core::config::Config;
    use server_box_monitor::core::permissions::{Grants, InitPermissions};

    pub const SECRET: &str = "test-secret-that-is-long-enough-32ch";

    /// Out of the crate's directory, as `permissions_api.rs` explains.
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
        leave_the_crate();
        static ONCE: Once = Once::new();
        ONCE.call_once(|| {
            let _ = rustls::crypto::ring::default_provider().install_default();
        });
        let config = Config {
            jwt_secret: Some(SECRET.to_string()),
            ..Default::default()
        };
        let db = super::database().await;
        for name in super::ACCOUNTS {
            super::add_account(&db, name, "admin").await;
        }
        server_box_monitor::db::bootstrap::ensure_roles(&db, &Config::default(), InitPermissions::Full)
            .await
            .unwrap();
        super::set_grants(&db, "admin", &Grants::all()).await;
        super::add_account(&db, "viewer", "viewer").await;
        let state = AppState::new(Arc::new(config), db.clone());
        let srv = web_test::server(move || {
            let state = state.clone();
            async move {
                let limit = state.remote_access.exec.max_request_bytes;
                App::new().state(state).configure(configure_api(limit))
            }
        })
        .await;
        (srv, db)
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
        user: Option<&str>,
        method: Method,
        path: &str,
        body: Option<Value>,
    ) -> (u16, Value) {
        let mut req = srv
            .request(method, srv.url(path))
            .timeout(std::time::Duration::from_secs(30));
        if let Some(user) = user {
            req = req.header(
                "Authorization",
                format!("Bearer {}", generate_token(user, SECRET).unwrap()),
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
}
