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

/// The bytes of a migration that has already run somewhere are frozen.
///
/// `Migrator::run` compares the checksum embedded in the binary against the one
/// `_sqlx_migrations` recorded when the file was first applied. Editing a
/// shipped migration — even a comment, even to correct it — changes that
/// checksum, and every agent that already applied it then refuses to start with
/// `VersionMismatch`, which is not something an operator can fix from the
/// outside.
///
/// The test above cannot catch that: it starts from an empty database and
/// replays the *current* files, so the checksum it records is always the new
/// one. This pins them instead. A failure here means a file that has run
/// somewhere was edited — restore it and put the change in a new migration.
/// Adding a migration is expected to add a line.
#[test]
fn shipped_migrations_keep_their_checksums() {
    let pinned: &[(i64, &str)] = &[
        (1, "ac7a765b2d29d0b1e0b55180fca0fe9c582a84ca8ff15e12f1cdac60eb1879009c86603dfb2bbe9efda4046921c86a5a"),
        (2, "995500f86fcaba8e42845c708779f6e154be1d9df4627d1acbd7a5d6a445f414f6ac0c4002ba41b07c2830681abacfe9"),
        (3, "33f9861299257235c1fe0bc1bbce5b9f98386e1333c9da2ed636c572e37acef2266948b4e05c052bcf402b53c6a0b393"),
        (4, "1afb432633d79277bebc544db394282237b0f286f1a31514fc7279e7993dbde19389553a521b8346b6661f03b0582a73"),
        (5, "a7cf936c175f498f26c2277f92e6a782a5831e1a3269ef9477876949e5aa3e041e06e95c0544d709536cd7a1e2fafec2"),
        (6, "bc1d80ef7f88751b0bb2a64974a7efb928301cd61740cfe77d9e2306a8f71d8cfbdd24a2e2e5dc2e5b9094755b9e03f9"),
        (7, "d7726fdbe4fad21ac01dc6b9a3058550aa138829baff1e0968a259f33e9b182e60bc4b658e0227fd4418a3c0fbd0a1f5"),
        (8, "9961008300f34069365756a67bc45c596baaf1290ddf9825198377feeafe11901c08603bbcabcb14f2df943eacebe054"),
    ];
    let migrator = sqlx::migrate!("./migrations");
    let mut seen = std::collections::BTreeMap::new();
    for m in migrator.iter() {
        seen.insert(m.version, hex(&m.checksum));
    }
    for (version, checksum) in pinned {
        let actual = seen
            .get(version)
            .unwrap_or_else(|| panic!("migration {version} is gone; it has run in the field"));
        assert_eq!(
            actual, checksum,
            "migration {version} was edited after shipping. Its checksum is what \
             every agent that applied it recorded; changing it makes them refuse \
             to start. Restore the file and add a new migration instead."
        );
    }

    // Otherwise the list above is a subset and a migration added tomorrow is
    // pinned by nothing: this test would pass while the checksum it should be
    // guarding went unrecorded.
    assert_eq!(
        seen.len(),
        pinned.len(),
        "a migration ships without a pinned checksum. Add its version and \
         checksum to the list above; embedded = {:?}",
        seen.keys().collect::<Vec<_>>()
    );
}

fn hex(bytes: &[u8]) -> String {
    use std::fmt::Write;
    bytes.iter().fold(String::new(), |mut s, b| {
        let _ = write!(s, "{b:02x}");
        s
    })
}
