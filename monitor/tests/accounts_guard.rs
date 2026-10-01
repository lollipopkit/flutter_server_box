//! The account writes that must hold under concurrency or from the CLI.
//!
//! On a database file with several connections, as the agent runs: the
//! in-memory pool the API tests use has one connection, under which two
//! requests can never interleave and a check-then-write race cannot show.

use server_box_monitor::core::config::Config;
use server_box_monitor::core::permissions::InitPermissions;
use server_box_monitor::db::accounts::{self, Guarded};
use server_box_monitor::db::bootstrap::{self, PasswordSet};
use sqlx::SqlitePool;
use sqlx::sqlite::{SqliteConnectOptions, SqlitePoolOptions};

async fn file_pool(dir: &tempfile::TempDir) -> SqlitePool {
    let options = SqliteConnectOptions::new()
        .filename(dir.path().join("data.db"))
        .create_if_missing(true)
        .busy_timeout(std::time::Duration::from_secs(5));
    let pool = SqlitePoolOptions::new()
        .max_connections(8)
        .connect_with(options)
        .await
        .unwrap();
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();
    bootstrap::ensure_roles(&pool, &Config::default(), InitPermissions::Full)
        .await
        .unwrap();
    pool
}

async fn add(pool: &SqlitePool, name: &str, role: &str) {
    accounts::insert_account(pool, name, "x", role).await.unwrap();
}

#[tokio::test(flavor = "multi_thread", worker_threads = 4)]
async fn two_admins_removing_each_other_at_once_leave_one() {
    for round in 0..20 {
        let dir = tempfile::tempdir().unwrap();
        let pool = file_pool(&dir).await;
        add(&pool, "a", "admin").await;
        add(&pool, "b", "admin").await;

        // Each the other's last move: one deleted, one demoted.
        let (first, second) = tokio::join!(
            accounts::delete_account(&pool, "a"),
            accounts::set_role_keeping_an_admin(&pool, "b", "viewer"),
        );
        let outcomes = [first.unwrap(), second.unwrap()];
        assert!(
            outcomes.contains(&Guarded::LastAdmin),
            "round {round}: {outcomes:?}"
        );
        assert_eq!(accounts::admin_count(&pool).await.unwrap(), 1, "round {round}");
    }
}

#[tokio::test]
async fn the_guard_tells_a_missing_account_from_the_last_admin() {
    let dir = tempfile::tempdir().unwrap();
    let pool = file_pool(&dir).await;
    add(&pool, "only", "admin").await;
    assert_eq!(
        accounts::delete_account(&pool, "nobody").await.unwrap(),
        Guarded::NotFound
    );
    assert_eq!(
        accounts::delete_account(&pool, "only").await.unwrap(),
        Guarded::LastAdmin
    );
    assert_eq!(
        accounts::set_role_keeping_an_admin(&pool, "only", "viewer")
            .await
            .unwrap(),
        Guarded::LastAdmin
    );
    // Staying an admin is never refused.
    assert_eq!(
        accounts::set_role_keeping_an_admin(&pool, "only", "admin")
            .await
            .unwrap(),
        Guarded::Done
    );
}

#[tokio::test]
async fn the_cli_makes_the_first_account_on_an_adminless_database_the_admin() {
    let dir = tempfile::tempdir().unwrap();
    let pool = file_pool(&dir).await;

    // A database nothing has served yet: no account at all.
    assert_eq!(
        bootstrap::set_password(&pool, "ops", "a-password", None)
            .await
            .unwrap(),
        PasswordSet::Created { first_admin: true }
    );
    let (_, role) = accounts::account(&pool, "ops").await.unwrap().unwrap();
    assert_eq!(role.name, "admin");

    // With an admin there, a new account is a viewer unless told otherwise.
    assert_eq!(
        bootstrap::set_password(&pool, "guest", "a-password", None)
            .await
            .unwrap(),
        PasswordSet::Created { first_admin: false }
    );
    let (_, role) = accounts::account(&pool, "guest").await.unwrap().unwrap();
    assert_eq!(role.name, "viewer");
}

#[tokio::test]
async fn a_cli_reset_ends_what_the_old_password_paid_for() {
    let dir = tempfile::tempdir().unwrap();
    let pool = file_pool(&dir).await;
    add(&pool, "ops", "admin").await;
    sqlx::query(
        "INSERT INTO watch_tokens (subject, client_id, token_hash, created_at, expires_at, scope) \
         VALUES ('ops', 'widget', 'h', 0, 9999999999, 'read')",
    )
    .execute(&pool)
    .await
    .unwrap();
    let (_, _, before) = accounts::account_since(&pool, "ops").await.unwrap().unwrap();

    assert_eq!(
        bootstrap::set_password(&pool, "ops", "a-new-password", None)
            .await
            .unwrap(),
        PasswordSet::Reset
    );
    let (_, _, after) = accounts::account_since(&pool, "ops").await.unwrap().unwrap();
    assert!(after > before, "the change moves the account's epoch: {before} → {after}");
    let tokens: i64 = sqlx::query_scalar("SELECT count(*) FROM watch_tokens WHERE subject = 'ops'")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(tokens, 0);
}

#[tokio::test]
async fn the_cli_cannot_move_the_last_admin_away_either() {
    // The same rule as the API: the CLI moving the only admin to another role
    // would leave a database nobody administers. And the password given with
    // the refused move is not set either.
    let dir = tempfile::tempdir().unwrap();
    let pool = file_pool(&dir).await;
    add(&pool, "ops", "admin").await;
    let (_, _, before) = accounts::account_since(&pool, "ops").await.unwrap().unwrap();

    assert!(
        bootstrap::set_password(&pool, "ops", "a-new-password", Some("viewer"))
            .await
            .is_err()
    );
    let (_, role) = accounts::account(&pool, "ops").await.unwrap().unwrap();
    assert_eq!(role.name, "admin");
    let (_, _, after) = accounts::account_since(&pool, "ops").await.unwrap().unwrap();
    assert_eq!(after, before, "the password was not changed");

    // With a second admin it goes through.
    add(&pool, "root2", "admin").await;
    assert_eq!(
        bootstrap::set_password(&pool, "ops", "a-new-password", Some("viewer"))
            .await
            .unwrap(),
        PasswordSet::Reset
    );
    let (_, role) = accounts::account(&pool, "ops").await.unwrap().unwrap();
    assert_eq!(role.name, "viewer");
}
