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
