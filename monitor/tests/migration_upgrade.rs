//! Upgrading a database that already holds data.
//!
//! Every other test starts from an empty file, which is the one case that
//! can't go wrong. What matters in the field is an agent that has been
//! running for months getting migration 006 applied on top of real rows —
//! a failure there is the hardest kind to recover from.

use sqlx::{Row, SqlitePool};

/// Applies the migrations that shipped before remote access existed.
async fn migrate_to_005(pool: &SqlitePool) {
    let migrator = sqlx::migrate!("./migrations");
    // `run_direct` isn't public, so instead run everything and rely on the
    // seeded rows below to prove 006 coped with pre-existing data. The
    // ordering guarantee is sqlx's: migrations apply in version order.
    migrator.run(pool).await.unwrap();
}

async fn pool() -> SqlitePool {
    SqlitePool::connect("sqlite::memory:").await.unwrap()
}

#[tokio::test]
async fn migrations_apply_to_a_database_that_already_has_rows() {
    let pool = pool().await;

    // A database as it looks before the upgrade: schema through 005, with
    // real content in the tables 006 touches or sits beside
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();
    sqlx::query("DELETE FROM retention_policies WHERE table_name = 'access_log'")
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query("DROP TABLE access_log").execute(&pool).await.unwrap();
    sqlx::query("DROP TABLE ssh_known_hosts").execute(&pool).await.unwrap();
    sqlx::query("DELETE FROM _sqlx_migrations WHERE version = 6")
        .execute(&pool)
        .await
        .unwrap();

    for i in 0..50 {
        sqlx::query(
            "INSERT INTO system_metrics (server_name, cpu_usage, memory_total, memory_used) \
             VALUES (?, ?, ?, ?)",
        )
        .bind(format!("host-{i}"))
        .bind(12.5_f64)
        .bind(8_000_000_000_i64)
        .bind(4_000_000_000_i64)
        .execute(&pool)
        .await
        .unwrap();
    }
    sqlx::query("INSERT INTO users (username, password_hash) VALUES ('admin', 'hash')")
        .execute(&pool)
        .await
        .unwrap();

    // Now upgrade
    migrate_to_005(&pool).await;

    // The pre-existing rows survive
    let metrics: i64 = sqlx::query_scalar("SELECT count(*) FROM system_metrics")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(metrics, 50, "existing metrics must not be touched");
    let users: i64 = sqlx::query_scalar("SELECT count(*) FROM users")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(users, 1, "existing accounts must not be touched");

    // And the new schema is usable
    sqlx::query(
        "INSERT INTO access_log (kind, action, subject, result) VALUES ('terminal','open','admin','ok')",
    )
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query(
        "INSERT INTO ssh_known_hosts (addr, key_type, fingerprint) VALUES ('127.0.0.1:22','ssh-ed25519','SHA256:x')",
    )
    .execute(&pool)
    .await
    .unwrap();

    let policy: Option<i64> = sqlx::query_scalar(
        "SELECT retention_days FROM retention_policies WHERE table_name = 'access_log'",
    )
    .fetch_optional(&pool)
    .await
    .unwrap();
    assert_eq!(
        policy,
        Some(90),
        "the audit log must be picked up by the existing retention mechanism"
    );
}

#[tokio::test]
async fn the_audit_log_is_cleaned_up_by_the_retention_service() {
    use server_box_monitor::core::config::DataRetentionConfig;
    use server_box_monitor::db::cleanup::DataCleanupService;

    let pool = pool().await;
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();

    // One row inside the window and one well outside it
    sqlx::query(
        "INSERT INTO access_log (timestamp, kind, action, result) \
         VALUES (datetime('now','-200 days'),'terminal','open','ok')",
    )
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query("INSERT INTO access_log (kind, action, result) VALUES ('terminal','open','ok')")
        .execute(&pool)
        .await
        .unwrap();

    let service = DataCleanupService::new(
        pool.clone(),
        DataRetentionConfig {
            metrics_days: 30,
            alerts_days: 90,
            cleanup_interval_hours: 24,
            max_db_size_mb: 1024,
        },
    );
    service.cleanup_expired_data().await.unwrap();

    let rows = sqlx::query("SELECT kind FROM access_log").fetch_all(&pool).await.unwrap();
    assert_eq!(
        rows.len(),
        1,
        "an entry older than its retention policy must be collected"
    );
    assert_eq!(rows[0].get::<String, _>("kind"), "terminal");
}

#[tokio::test]
async fn unused_metric_tables_and_policies_are_removed_on_upgrade() {
    let pool = pool().await;
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();

    // Recreate the pre-008 state with real rows, then mark only migration 008
    // pending. This exercises the same upgrade path as an existing agent.
    sqlx::query(
        "CREATE TABLE velocity_metrics (id INTEGER PRIMARY KEY, timestamp DATETIME, server_name TEXT)",
    )
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query(
        "CREATE TABLE cpu_core_metrics (id INTEGER PRIMARY KEY, timestamp DATETIME, server_name TEXT)",
    )
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query("INSERT INTO velocity_metrics VALUES (1, CURRENT_TIMESTAMP, 'host')")
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query("INSERT INTO cpu_core_metrics VALUES (1, CURRENT_TIMESTAMP, 'host')")
        .execute(&pool)
        .await
        .unwrap();
    sqlx::query(
        "INSERT INTO retention_policies (table_name, retention_days) VALUES ('velocity_metrics', 30), ('cpu_core_metrics', 7)",
    )
    .execute(&pool)
    .await
    .unwrap();
    sqlx::query("DELETE FROM _sqlx_migrations WHERE version = 8")
        .execute(&pool)
        .await
        .unwrap();

    sqlx::migrate!("./migrations").run(&pool).await.unwrap();

    for table in ["velocity_metrics", "cpu_core_metrics"] {
        let exists: Option<String> = sqlx::query_scalar(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        )
        .bind(table)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert!(exists.is_none(), "{table} should be dropped");

        let policy: Option<i64> = sqlx::query_scalar(
            "SELECT retention_days FROM retention_policies WHERE table_name = ?",
        )
        .bind(table)
        .fetch_optional(&pool)
        .await
        .unwrap();
        assert!(policy.is_none(), "{table} policy should be removed");
    }

    let system_metrics_exists: Option<String> = sqlx::query_scalar(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'system_metrics'",
    )
    .fetch_optional(&pool)
    .await
    .unwrap();
    assert_eq!(system_metrics_exists.as_deref(), Some("system_metrics"));
}
