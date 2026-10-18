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
    // Recreated by 006 when it runs again below; 019 dropped it.
    sqlx::query("DROP TABLE IF EXISTS ssh_known_hosts").execute(&pool).await.unwrap();
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
    sqlx::query("INSERT INTO users (password_hash) VALUES ('hash')")
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

    // One row inside the window and one well outside it, both timestamped the
    // way `audit::Event::record` timestamps one. Written with
    // `datetime('now', ...)` and the column's old default before migration
    // 009, which is a shape the agent never produces and does not compare
    // against the cutoff the way the shape it does produce compares.
    let now = chrono::Utc::now();
    for at in [now - chrono::Duration::days(200), now] {
        sqlx::query(
            "INSERT INTO access_log (timestamp, kind, action, result) \
             VALUES (?, 'terminal', 'open', 'ok')",
        )
        .bind(at)
        .execute(&pool)
        .await
        .unwrap();
    }

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

/// Everything up to and including [`through`], so a migration can be run
/// against a database that genuinely predates it.
///
/// `Migrator`'s fields are public for the `migrate!()` macro's sake. Building
/// a subset out of the same `Migration` values is what makes the second run
/// apply only what is left: it re-validates the checksums of what is already
/// recorded, and those match by construction.
/// The backups monitor 0.2.0 hosted in the database (migration 015) become
/// files once migration 020 has run and the agent starts, and the table that
/// held them goes.
#[tokio::test]
async fn hosted_backups_move_out_of_the_database() {
    use server_box_monitor::core::blobs::{Blobs, move_database_backups};
    let pool = pool().await;
    migrator_through(17).run(&pool).await.unwrap();
    for (name, data) in [("srvbox_bak_v3.json", b"ciphertext".as_slice()), ("panel.json", b"other".as_slice())] {
        sqlx::query("INSERT INTO backup_blob (name, data, size, updated_at) VALUES (?, ?, ?, '2026-10-01T00:00:00.000Z')")
            .bind(name)
            .bind(data)
            .bind(data.len() as i64)
            .execute(&pool)
            .await
            .unwrap();
    }
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();
    let blobs = Blobs::temporary();
    move_database_backups(&pool, &blobs).await.unwrap();
    // Once: a second start finds nothing to move.
    move_database_backups(&pool, &blobs).await.unwrap();

    let gone: bool = sqlx::query_scalar("SELECT NOT EXISTS (SELECT 1 FROM sqlite_master WHERE name = 'backup_blob')")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(gone);
    let (sha, size, updated_at): (String, i64, String) =
        sqlx::query_as("SELECT sha256, size, updated_at FROM backup_file WHERE name = 'srvbox_bak_v3.json'")
            .fetch_one(&pool)
            .await
            .unwrap();
    assert_eq!((size, updated_at.as_str()), (10, "2026-10-01T00:00:00.000Z"));
    assert_eq!(blobs.read(&sha).await.unwrap().as_deref(), Some(&b"ciphertext"[..]));
    // Named by its row, so a collection keeps it.
    blobs.collect(&pool).await.unwrap();
    assert!(blobs.read(&sha).await.unwrap().is_some());
}

fn migrator_through(through: i64) -> sqlx::migrate::Migrator {
    let all = sqlx::migrate!("./migrations");
    sqlx::migrate::Migrator {
        migrations: all
            .migrations
            .iter()
            .filter(|m| m.version <= through)
            .cloned()
            .collect::<Vec<_>>()
            .into(),
        ..sqlx::migrate::Migrator::DEFAULT
    }
}

/// Migration 009 against a row written the way the agent wrote them before it.
///
/// A migration gets one pass over a user's records and is not repeatable, so a
/// mistake in the conversion is silence rather than a crash — the rows are
/// simply wrong afterwards, in a column only retention reads. Every other test
/// here runs the whole set first and inserts after, which exercises the new
/// schema and never the conversion.
///
/// The row is inserted through the pre-009 default rather than with a value of
/// this test's own choosing: `CURRENT_TIMESTAMP` is what produced every
/// timestamp in this column in the field, and a fixture that types the text
/// itself would prove the migration handles the fixture.
#[tokio::test]
async fn migration_009_converts_the_timestamps_already_in_access_log() {
    let pool = pool().await;
    migrator_through(8).run(&pool).await.unwrap();

    sqlx::query(
        "INSERT INTO access_log (kind, action, subject, remote_ip, ssh_user, result, detail) \
         VALUES ('terminal','open','admin','10.0.0.1','root','ok','pre-009')",
    )
    .execute(&pool)
    .await
    .unwrap();

    let before = sqlx::query("SELECT id, timestamp FROM access_log")
        .fetch_one(&pool)
        .await
        .unwrap();
    let old_id: i64 = before.get("id");
    let old_ts: String = before.get("timestamp");
    assert_eq!(
        old_ts.len(),
        19,
        "the pre-009 default should write 'YYYY-MM-DD HH:MM:SS', got {old_ts:?}"
    );

    sqlx::migrate!("./migrations").run(&pool).await.unwrap();

    let row = sqlx::query("SELECT id, timestamp, subject, remote_ip, ssh_user, detail FROM access_log")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(row.get::<i64, _>("id"), old_id, "the row was renumbered");
    // Every other column carried across the rebuild, not just the one being
    // converted — a copy that names its columns in the wrong order still
    // typechecks.
    assert_eq!(row.get::<String, _>("subject"), "admin");
    assert_eq!(row.get::<String, _>("remote_ip"), "10.0.0.1");
    assert_eq!(row.get::<String, _>("ssh_user"), "root");
    assert_eq!(row.get::<String, _>("detail"), "pre-009");

    // Exact, rather than "looks like RFC 3339": the same instant, in the shape
    // sqlx encodes a whole-second `DateTime<Utc>` as. Checked against the text
    // that was there, so the clock cannot make this flaky.
    let converted: String = row.get("timestamp");
    assert_eq!(converted, format!("{}+00:00", old_ts.replace(' ', "T")));
    let parsed = chrono::DateTime::parse_from_rfc3339(&converted)
        .unwrap_or_else(|e| panic!("{converted:?} is not RFC 3339: {e}"));

    // The point of the conversion. A cutoff one second older than the row used
    // to read as newer than it, because the comparison stopped meaning
    // anything at the ' ' where the new shape has a 'T'.
    let cutoff = parsed.with_timezone(&chrono::Utc) - chrono::Duration::seconds(1);
    let kept: i64 = sqlx::query_scalar("SELECT count(*) FROM access_log WHERE timestamp >= ?")
        .bind(cutoff)
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(kept, 1, "the converted row is still older than {cutoff}");

    // The rebuild drops the old table, which takes its index and its
    // sqlite_sequence entry with it.
    let indexes: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM sqlite_master WHERE type = 'index' AND name = 'idx_access_log_timestamp'",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(indexes, 1, "the timestamp index did not survive the rebuild");

    sqlx::query("INSERT INTO access_log (timestamp, kind, action, result) VALUES (?,'ticket','open','ok')")
        .bind(chrono::Utc::now())
        .execute(&pool)
        .await
        .unwrap();
    let next: i64 = sqlx::query_scalar("SELECT max(id) FROM access_log")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(
        next > old_id,
        "AUTOINCREMENT restarted after the rebuild: {next} follows {old_id}"
    );
}

/// The retention cutoff is a moment, not a date.
///
/// `cleanup_policy_tables` binds `now - retention_days` and compares it
/// against this column. While the column carried `CURRENT_TIMESTAMP`'s
/// `YYYY-MM-DD HH:MM:SS` and the cutoff arrived as RFC 3339, the text
/// comparison stopped meaning anything at position 10 — `' '` against `'T'` —
/// so every row from the cutoff's own date read as older than the cutoff
/// whatever its time, and up to a day of audit log past it was deleted on
/// each pass. One second either side of the boundary is what that got wrong.
#[tokio::test]
async fn the_audit_log_cutoff_is_a_moment_not_a_date() {
    use server_box_monitor::core::config::DataRetentionConfig;
    use server_box_monitor::db::cleanup::DataCleanupService;

    let pool = pool().await;
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();

    // 90 days is the policy migration 006 seeds for this table.
    let cutoff = chrono::Utc::now() - chrono::Duration::days(90);
    for (at, detail) in [
        (cutoff + chrono::Duration::seconds(1), "keep"),
        (cutoff - chrono::Duration::seconds(1), "drop"),
    ] {
        sqlx::query(
            "INSERT INTO access_log (timestamp, kind, action, result, detail) \
             VALUES (?, 'terminal', 'open', 'ok', ?)",
        )
        .bind(at)
        .bind(detail)
        .execute(&pool)
        .await
        .unwrap();
    }

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

    let kept = sqlx::query("SELECT detail FROM access_log")
        .fetch_all(&pool)
        .await
        .unwrap();
    let kept: Vec<String> = kept.iter().map(|r| r.get::<String, _>("detail")).collect();
    assert_eq!(kept, ["keep"], "kept {kept:?} across the retention boundary");
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

/// The grants a role holds after every migration through 031, as JSON.
async fn grants_through_031(pool: &SqlitePool, role: &str) -> Option<serde_json::Value> {
    let raw: Option<String> = sqlx::query_scalar("SELECT grants FROM roles WHERE name = ?")
        .bind(role)
        .fetch_one(pool)
        .await
        .unwrap();
    raw.map(|raw| serde_json::from_str(&raw).unwrap())
}

/// Migration 019 against roles saved with `ssh_terminal`, as every agent from
/// 0.2.0 until it saved them.
#[tokio::test]
async fn migration_019_drops_the_ssh_terminal_grant_and_the_pinned_host_key() {
    let pool = pool().await;
    migrator_through(18).run(&pool).await.unwrap();
    sqlx::query(
        "INSERT INTO ssh_known_hosts (addr, key_type, fingerprint) VALUES ('127.0.0.1:22','ssh-ed25519','SHA256:x')",
    )
    .execute(&pool)
    .await
    .unwrap();
    for (name, grants) in [
        (
            "admin",
            r#"{"shell":true,"ssh_terminal":true,"files":{"mode":"write"},"connect":{"allow":[]},"listen":{"public":false,"ports":null},"virt":true}"#,
        ),
        (
            "ssh_only",
            r#"{"shell":false,"ssh_terminal":true,"files":null,"connect":null,"listen":null,"virt":false}"#,
        ),
    ] {
        sqlx::query(
            "INSERT INTO roles (name, admin, builtin, grants, created_at, updated_at) \
             VALUES (?, 0, 0, ?, '2026-10-01T00:00:00Z', '2026-10-01T00:00:00Z') \
             ON CONFLICT(name) DO UPDATE SET grants = excluded.grants",
        )
        .bind(name)
        .bind(grants)
        .execute(&pool)
        .await
        .unwrap();
    }

    migrator_through(31).run(&pool).await.unwrap();

    let admin = grants_through_031(&pool, "admin").await.unwrap();
    assert!(admin.get("ssh_terminal").is_none());
    assert_eq!(admin["shell"], true);
    assert_eq!(admin["virt"], true);
    let ssh_only = grants_through_031(&pool, "ssh_only").await.unwrap();
    assert!(ssh_only.get("ssh_terminal").is_none());
    assert_eq!(ssh_only["shell"], false);
    let table: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'ssh_known_hosts'",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(table, 0);
}

/// Migration 011 against roles saved the way monitor 0.2.0 saved them, with
/// no `virt` field.
#[tokio::test]
async fn migration_011_gives_virt_to_the_roles_that_hold_shell() {
    let pool = pool().await;
    migrator_through(10).run(&pool).await.unwrap();
    for (name, grants) in [
        (
            "admin",
            r#"{"shell":true,"ssh_terminal":true,"files":{"mode":"write"},"connect":{"allow":[]},"listen":{"public":false,"ports":null}}"#,
        ),
        (
            "desktop",
            r#"{"shell":false,"ssh_terminal":false,"files":null,"connect":{"allow":["127.0.0.1:3389"]},"listen":null}"#,
        ),
    ] {
        sqlx::query(
            "INSERT INTO roles (name, admin, builtin, grants, created_at, updated_at) \
             VALUES (?, 0, 0, ?, '2026-10-01T00:00:00Z', '2026-10-01T00:00:00Z') \
             ON CONFLICT(name) DO UPDATE SET grants = excluded.grants",
        )
        .bind(name)
        .bind(grants)
        .execute(&pool)
        .await
        .unwrap();
    }

    migrator_through(31).run(&pool).await.unwrap();

    assert_eq!(grants_through_031(&pool, "admin").await.unwrap()["virt"], true);
    let desktop = grants_through_031(&pool, "desktop").await.unwrap();
    assert_ne!(desktop["virt"], true);
    assert_eq!(desktop["connect"]["allow"], serde_json::json!(["127.0.0.1:3389"]));
}

/// Migration 032 against several accounts, the way 031 left them: the oldest
/// admin is kept with its password, what the others made that does not
/// collide is moved to it, and the rest goes.
#[tokio::test]
async fn migration_032_keeps_the_oldest_admin_and_moves_the_others_work_to_it() {
    let pool = pool().await;
    migrator_through(31).run(&pool).await.unwrap();
    // A viewer first, so the oldest account is not the one kept.
    for (name, role) in [("watcher", "viewer"), ("admin", "admin"), ("ops", "admin")] {
        sqlx::query("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)")
            .bind(name)
            .bind(format!("hash-{name}"))
            .bind(role)
            .execute(&pool)
            .await
            .unwrap();
    }
    let id = |name: &'static str| {
        let pool = pool.clone();
        async move {
            sqlx::query_scalar::<_, i64>("SELECT id FROM users WHERE username = ?")
                .bind(name)
                .fetch_one(&pool)
                .await
                .unwrap()
        }
    };
    let (admin, ops, watcher) = (id("admin").await, id("ops").await, id("watcher").await);
    let at = "2026-10-01T00:00:00Z";
    for (flow, user) in [("f-admin", admin), ("f-ops", ops)] {
        sqlx::query("INSERT INTO agent_flow (id, user_id, title, status, created_at, updated_at) VALUES (?, ?, 't', 'done', ?, ?)")
            .bind(flow).bind(user).bind(at).bind(at)
            .execute(&pool).await.unwrap();
    }
    for (user, path, content) in [(admin, "MEMORY.md", "mine"), (ops, "MEMORY.md", "theirs"), (ops, "ops.md", "notes")] {
        sqlx::query("INSERT INTO agent_memory (user_id, path, content, updated_at) VALUES (?, ?, ?, ?)")
            .bind(user).bind(path).bind(content).bind(at)
            .execute(&pool).await.unwrap();
    }
    for (user, app, key) in [(admin, "a.one", "k"), (ops, "a.one", "other"), (ops, "a.two", "k")] {
        sqlx::query("INSERT INTO desk_app_storage (user_id, app_id, key, value, updated_at) VALUES (?, ?, ?, '1', ?)")
            .bind(user).bind(app).bind(key).bind(at)
            .execute(&pool).await.unwrap();
    }
    for (user, installation, theme) in [(admin, "i1", "t.one"), (ops, "i2", "t.one"), (ops, "i3", "t.two")] {
        sqlx::query("INSERT INTO desk_theme (user_id, installation_id, theme_id, name, summary, installed_at) VALUES (?, ?, ?, 'n', '{}', ?)")
            .bind(user).bind(installation).bind(theme).bind(at)
            .execute(&pool).await.unwrap();
        sqlx::query("INSERT INTO desk_theme_background (user_id, installation_id, variant, mime, sha256, size) VALUES (?, ?, '', 'image/png', 'ab', 1)")
            .bind(user).bind(installation)
            .execute(&pool).await.unwrap();
    }
    sqlx::query("INSERT INTO desk_preferences (user_id, wallpaper, wallpaper_fit, updated_at) VALUES (?, 'preset:x', 'cover', ?)")
        .bind(watcher).bind(at)
        .execute(&pool).await.unwrap();
    for subject in ["admin", "ops"] {
        sqlx::query("INSERT INTO watch_tokens (subject, client_id, token_hash, created_at, expires_at) VALUES (?, 'watch', ?, 1, 99999999999)")
            .bind(subject).bind(format!("h-{subject}"))
            .execute(&pool).await.unwrap();
    }

    let migrated_at = chrono::Utc::now().timestamp_millis();
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();

    let users: Vec<(i64, String)> = sqlx::query_as("SELECT id, password_hash FROM users")
        .fetch_all(&pool)
        .await
        .unwrap();
    assert_eq!(users, [(admin, "hash-admin".to_string())]);
    let columns: Vec<String> = sqlx::query_scalar("SELECT name FROM pragma_table_info('users')")
        .fetch_all(&pool)
        .await
        .unwrap();
    assert!(!columns.contains(&"role".to_string()) && !columns.contains(&"username".to_string()));
    for (table, column) in [
        ("stack", "installed_by"),
        ("stack", "license_accepted_by"),
        ("desk_app_package", "installed_by"),
        ("container_backup_schedule", "created_by"),
        ("storage_maintenance", "updated_by"),
    ] {
        let columns: Vec<String> = sqlx::query_scalar(sqlx::AssertSqlSafe(format!("SELECT name FROM pragma_table_info('{table}')")))
            .fetch_all(&pool)
            .await
            .unwrap();
        assert!(!columns.contains(&column.to_string()), "{table}.{column}");
    }
    let roles: i64 = sqlx::query_scalar("SELECT count(*) FROM sqlite_master WHERE name = 'roles'")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(roles, 0);

    let flows: Vec<i64> = sqlx::query_scalar("SELECT user_id FROM agent_flow ORDER BY id")
        .fetch_all(&pool)
        .await
        .unwrap();
    assert_eq!(flows, [admin, admin]);
    let memory: Vec<(String, String)> = sqlx::query_as("SELECT path, content FROM agent_memory ORDER BY path")
        .fetch_all(&pool)
        .await
        .unwrap();
    assert_eq!(memory, [("MEMORY.md".into(), "mine".into()), ("ops.md".into(), "notes".into())]);
    let storage: Vec<(String, String)> = sqlx::query_as("SELECT app_id, key FROM desk_app_storage ORDER BY app_id, key")
        .fetch_all(&pool)
        .await
        .unwrap();
    assert_eq!(storage, [("a.one".into(), "k".into()), ("a.two".into(), "k".into())]);
    let themes: Vec<String> = sqlx::query_scalar("SELECT installation_id FROM desk_theme ORDER BY installation_id")
        .fetch_all(&pool)
        .await
        .unwrap();
    assert_eq!(themes, ["i1", "i3"]);
    let backgrounds: Vec<String> = sqlx::query_scalar("SELECT installation_id FROM desk_theme_background ORDER BY installation_id")
        .fetch_all(&pool)
        .await
        .unwrap();
    assert_eq!(backgrounds, ["i1", "i3"]);
    let preferences: i64 = sqlx::query_scalar("SELECT count(*) FROM desk_preferences")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(preferences, 0);
    let tokens: Vec<(String, String)> = sqlx::query_as("SELECT client_id, token_hash FROM watch_tokens")
        .fetch_all(&pool)
        .await
        .unwrap();
    assert_eq!(tokens, [("watch".to_string(), "h-admin".to_string())]);
    // No panel token from before counts (034): an account named `owner` held
    // one whose subject is the one account's now.
    let since: i64 = sqlx::query_scalar("SELECT password_changed_ms FROM users")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert!(since >= migrated_at, "{since} < {migrated_at}");

    // Foreign keys still hold and still name the rebuilt table.
    let broken: Vec<(String,)> = sqlx::query_as("SELECT \"table\" FROM pragma_foreign_key_check")
        .fetch_all(&pool)
        .await
        .unwrap();
    assert!(broken.is_empty(), "{broken:?}");
    sqlx::query("DELETE FROM users").execute(&pool).await.unwrap();
    let flows: i64 = sqlx::query_scalar("SELECT count(*) FROM agent_flow")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(flows, 0, "an account's tasks go with it");
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
        (9, "f50849af86f5e456829df80ddb0c716540a23bd0a15527925bfb27f5e05b8dd567e83c6e1d08898a93135aa05052877b"),
        (10, "92495a720d33186675f04e757b7e28756d1233ee2152be1f86fda8d48ee28d628419336de8f8ea742a575ddeea9d85c8"),
        (11, "9081aeb2c58f141bd2efa4db9c41042208fe7940a294984e6b5891dd05a09f4055b10efc4539eed515bac0a32a08fdc5"),
        (12, "a08c9dd7513dd8f6cf23a9ff028c1f4145e1af76d12cadab08ce0fce6f6c57c3ff9b34cabf7bbd3987fcfd7a13805b93"),
        (13, "bdaecb81f939bd7892470d5cd0d46b14930c2a313905eb6c0c1c4d85b9e9e597552f3868637b2024858eb69c2b6d8743"),
        (14, "23646b4b6318910b944979232d7419104b8467a230da0ee5a80b92c1a14cd79df7dbe42fc85a35f5e393155ebb96e5ac"),
        (15, "3f6636970de6cca7356e0e1107330778898416f76f71bf5aae1bd3baa78e011ca6551f5e2c27f03166c9cdb7ae9d5618"),
        (16, "7196b34f2a606e66eb4c66659542d023b3d9e2dcb10f859efc0dae770102088963dda18b5cdc93a4c00fbbf54d16f2c1"),
        (17, "ba885b434ae998eb589c4ea50f2d7a68790e5a44007ddfe50ebed79f767d8a81a04744bf10774e94056e58d51c3920ac"),
        (18, "441e628e50c650653e520d2e381b2fb7e2ea9a577c13da2d7a207793627a45355e646250c2c5c6f99e743e1a3f49d71d"),
        (19, "5f9544a9e8df9e588c6c604ca7be4871c4b4996489f0faeacd34037fe44f8beca506a418f56fe79598f39f7fa5c03aad"),
        (20, "6f2530558f99971da044a40d3915e6ff0f1941d01cd455174582b1ee38688dce1eed560c7da805f91c500f196751b9b7"),
        (21, "698d6dc12f8faad2042b189dbd4d7ef7e05cad67e82ac45ac8a21a4959a5e8ee3c5eaaed3b6dc194b2382fdd48113afe"),
        (22, "4cdc307a072820d20b606c08671e7d46fd9d728f83a6196c94140994819378ed65ba9a2f78b92dc20ea06248b82044f3"),
        (23, "97e7c461406b486d71f3171e7c1f734fc479908aefea35f4d50f6800353e9dd49c3e61468d14e0e74ce85b40bd6b0255"),
        (24, "a95c2255bbff4d415f7a3ba3610f28f2ce5ce330bb10ee85e776865a390aad07f123d2ecd6aa4bb3861d7e0ff766ceb1"),
        (25, "81805e785afc1f41301bfb7f59203fe8c42942cb13de95fcbffeaa6eacc3ee7313b6c42734b843e51008508be76bca47"),
        (26, "2175172e580c2cbc5c1ab9ebcdd3152d98b73f29bdd7927d47193637ad936999515be810a35fecdb766754f4751d7144"),
        (27, "622c1b88f06e096e1152043e84dcee24411aee5eb92df3726d6cb1ce314e578c9751cd89168d4f4e84e9340ede00e7d1"),
        (28, "6ba73f6135f7d778ad741030c5cec439fe385b0ef676b665dc27a0fb9879edbaf26bed952b3285ebb985a480452aa964"),
        (29, "a4a3a8a1b8b70088b0c2032cf4068e9118907014f05abb67b0baca3becd4879b54712187d01070961c7152ec8d44e52f"),
        (30, "be8a53e70bf0670c35829073aefa0132e18ea896a00563e4f97c4ad7b1bd69e6e4bd9a4c240e430dc6a69dd6c73d9064"),
        (31, "9fcac3bab0ddf4541448523036bf12a4940c2799159626039649ac12e6534a414e81a2a1da09f41df661c6475251a036"),
        (32, "7ee52e75564e183b601cad20c3ea1f22ec0795c6667c9fff937baa57cb0634ecd724b79abc30a890d21e19a22ef7f4ef"),
        (33, "4a90ec253d6baad87ee23d43b505dd10c6fcd965995de0c970307237ec1b1ecc8fecdb5378e62a20648a7b4380db3286"),
        (34, "85444f411ccc2f057e28c7e6580ddcd82896160d57485fa03b2d92bf89e894717d9bc667342e3a252d92b306c7ff8be3"),
        (35, "4d2aec522451fa3289c2c51fb846cc2b6b8f3fd210d58102c7318ac3617d7c6eea4cb93152df24f7c1d558675db0181c"),
        (36, "882c004ee7ace1a28080dc2dd25aa71ae86667030a97387cf913f1e26a54a895498d2a3e5d84cb64ad6d2bd426781c17"),
        (37, "e8d79fc4304a960d6d268f7adbf7fe9cf5a40920b9bdf38501b25baf317f5b52f30b407445fed1e1953e595505c51b7e"),
        (38, "0828a286019ed43008da80bb602e4f6a2ceebda295c2f63c9c9197ce6af6bc908cd45cae89ca8389147f15c009a8a992"),
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
