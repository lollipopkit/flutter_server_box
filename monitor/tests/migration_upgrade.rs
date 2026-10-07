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
    // Recreated by 006 when it runs again below; 023 dropped it.
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

/// Applies the migrations a release before roles shipped (001–009), from the
/// same files, through the public migrator — so the database is the one that
/// release left behind, and the full set then applies on top of it exactly as
/// it does in the field.
async fn migrate_through_009(pool: &SqlitePool) {
    let dir = tempfile::tempdir().unwrap();
    let source = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("migrations");
    for entry in std::fs::read_dir(&source).unwrap() {
        let path = entry.unwrap().path();
        let name = path.file_name().unwrap().to_string_lossy().into_owned();
        let version: i64 = name.split('_').next().unwrap().parse().unwrap();
        if version <= 9 {
            std::fs::copy(&path, dir.path().join(&name)).unwrap();
        }
    }
    sqlx::migrate::Migrator::new(dir.path())
        .await
        .unwrap()
        .run(pool)
        .await
        .unwrap();
}

/// Accounts and a watch token, written the way the release before roles
/// wrote them: `ensure_admin_user` / `user set-password` inserted a name and a
/// hash and left the timestamps to their defaults, `login` stamped
/// `last_login` with `CURRENT_TIMESTAMP`, and `issue_watch_token` had no
/// scope to write.
async fn seed_like_the_release_before_roles(pool: &SqlitePool) {
    for (name, hash) in [("admin", "$2b$12$hash-a"), ("ops", "$2b$12$hash-b")] {
        sqlx::query("INSERT INTO users (username, password_hash) VALUES (?, ?)")
            .bind(name)
            .bind(hash)
            .execute(pool)
            .await
            .unwrap();
    }
    sqlx::query("UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE username = 'admin'")
        .execute(pool)
        .await
        .unwrap();
    sqlx::query(
        "INSERT INTO watch_tokens(subject, client_id, token_hash, created_at, expires_at) \
         VALUES ('admin', 'watch:one', 'deadbeef', 10, 99999999999)",
    )
    .execute(pool)
    .await
    .unwrap();
}

/// What an old `config.toml` with these switches parses to.
fn old_config(toml: &str) -> server_box_monitor::core::config::Config {
    toml::from_str(toml).unwrap()
}

async fn upgraded(config_toml: &str) -> SqlitePool {
    let pool = pool().await;
    migrate_through_009(&pool).await;
    seed_like_the_release_before_roles(&pool).await;
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();
    server_box_monitor::db::bootstrap::ensure_roles(
        &pool,
        &old_config(config_toml),
        server_box_monitor::core::permissions::InitPermissions::Read,
    )
    .await
    .unwrap();
    pool
}

#[tokio::test]
async fn upgrading_to_roles_keeps_every_account_and_what_it_could_do() {
    use server_box_monitor::core::permissions::{ConnectGrant, FilesGrant, FilesMode, ListenGrant};
    use server_box_monitor::db::accounts;

    let root = tempfile::tempdir().unwrap();
    let pool = upgraded(&format!(
        "[remote_access]\nfull_access = true\nlisten_public = true\n\
         [remote_access.terminal]\nenabled = true\n\
         [remote_access.fs]\nenabled = true\nroots = [{:?}]\n",
        root.path().display().to_string()
    ))
    .await;

    // Every account survives, each now an admin — which is what every login
    // was before roles. `InitPermissions::Read` was passed and did nothing:
    // it is a fresh install's choice, and this is not one.
    let users = accounts::accounts(&pool).await.unwrap();
    assert_eq!(users.len(), 2);
    assert!(users.iter().all(|u| u.role == "admin"));
    let admin = users.iter().find(|u| u.username == "admin").unwrap();
    assert!(admin.last_login.as_deref().is_some_and(|t| t.contains('T')), "{admin:?}");
    assert!(admin.created_at.is_some());
    assert_eq!(
        accounts::password_hash(&pool, "ops").await.unwrap().as_deref(),
        Some("$2b$12$hash-b")
    );

    // And the admin role holds what those switches gave.
    let role = accounts::role(&pool, "admin").await.unwrap().unwrap();
    assert!(role.admin && role.builtin);
    assert!(role.grants.shell);
    assert_eq!(role.grants.connect, Some(ConnectGrant::default()));
    assert_eq!(
        role.grants.listen,
        Some(ListenGrant {
            public: true,
            ports: None
        })
    );
    assert_eq!(
        role.grants.files,
        Some(FilesGrant {
            mode: FilesMode::Write
        })
    );
    let viewer = accounts::role(&pool, "viewer").await.unwrap().unwrap();
    assert_eq!(viewer.grants, Default::default());

    // The watch token is a read token, which is all it ever was.
    let scope: String = sqlx::query_scalar("SELECT scope FROM watch_tokens")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(scope, "read");
}

#[tokio::test]
async fn an_upgrade_grants_only_what_the_old_switches_effectively_gave() {
    use server_box_monitor::db::accounts;

    // `full_access` only counted while the terminal was enabled.
    let pool = upgraded("[remote_access]\nfull_access = true\n").await;
    let grants = accounts::role(&pool, "admin").await.unwrap().unwrap().grants;
    assert_eq!(grants, Default::default());

    // The terminal alone was the SSH terminal, which is gone: nothing.
    let pool = upgraded("[remote_access]\nfull_access = false\n[remote_access.terminal]\nenabled = true\n").await;
    let grants = accounts::role(&pool, "admin").await.unwrap().unwrap().grants;
    assert_eq!(grants, Default::default());

    // The file API switched on with no roots served nothing.
    let pool = upgraded("[remote_access.fs]\nenabled = true\n").await;
    let grants = accounts::role(&pool, "admin").await.unwrap().unwrap().grants;
    assert!(grants.files.is_none());
}

#[tokio::test]
async fn roles_are_decided_once() {
    use server_box_monitor::db::accounts;

    let pool = upgraded("[remote_access]\nfull_access = false\n").await;
    // A later start with switches that would have granted more changes
    // nothing: the roles are the admin's now, not the file's.
    server_box_monitor::db::bootstrap::ensure_roles(
        &pool,
        &old_config("[remote_access]\nfull_access = true\n[remote_access.terminal]\nenabled = true\n"),
        server_box_monitor::core::permissions::InitPermissions::Full,
    )
    .await
    .unwrap();
    let grants = accounts::role(&pool, "admin").await.unwrap().unwrap().grants;
    assert_eq!(grants, Default::default());
}

#[tokio::test]
async fn a_fresh_install_starts_with_what_the_installer_chose() {
    use server_box_monitor::core::permissions::{Grants, InitPermissions};

    // The shipped example: written for roles, none of the moved keys in it.
    let example = old_config(include_str!("../config.example.toml"));
    for (init, expected) in [
        (InitPermissions::Full, Grants::all()),
        (InitPermissions::Read, Grants::none()),
    ] {
        let role = fresh_admin_role(&example, init).await;
        assert!(role.admin, "the first account administers the agent either way");
        assert_eq!(role.grants, expected, "{init}");
    }
}

#[tokio::test]
async fn a_fresh_install_with_an_old_config_grants_no_more_than_it_said() {
    // A config written for the model before roles over a new database — a
    // mounted file on a fresh volume, a declarative deployment. It said no
    // shell, and the installer's default must not say yes.
    use server_box_monitor::core::permissions::{Grants, InitPermissions};

    let denied = old_config("[remote_access]\nfull_access = false\n");
    let role = fresh_admin_role(&denied, InitPermissions::Full).await;
    assert!(role.admin);
    assert_eq!(role.grants, Grants::none());

    // One that said `enabled = false` for the terminal is the same answer:
    // presence is what counts, not the value.
    let off = old_config("[remote_access.terminal]\nenabled = false\n");
    assert_eq!(fresh_admin_role(&off, InitPermissions::Full).await.grants, Grants::none());

    // And what it did allow is still a ceiling a `read` install stays under.
    let open = old_config("[remote_access]\nfull_access = true\n[remote_access.terminal]\nenabled = true\n");
    let full = fresh_admin_role(&open, InitPermissions::Full).await.grants;
    assert!(full.shell);
    assert!(full.files.is_none(), "no roots, no files");
    assert_eq!(
        fresh_admin_role(&open, InitPermissions::Read).await.grants,
        Grants::none()
    );
}

/// The admin role a fresh database ends up with under [config] and [init].
async fn fresh_admin_role(
    config: &server_box_monitor::core::config::Config,
    init: server_box_monitor::core::permissions::InitPermissions,
) -> server_box_monitor::core::permissions::Role {
    use server_box_monitor::db::{accounts, bootstrap};
    let dir = tempfile::tempdir().unwrap();
    let database_url = format!("sqlite:{}", dir.path().join("data.db").display());
    let pool = pool().await;
    sqlx::migrate!("./migrations").run(&pool).await.unwrap();
    bootstrap::ensure_roles(&pool, config, init).await.unwrap();
    bootstrap::ensure_admin_user(&pool, &database_url).await.unwrap();
    let (name, role) = accounts::account(&pool, "admin").await.unwrap().unwrap();
    assert_eq!(name, "admin");
    role
}

/// Migration 011 against roles saved the way monitor 0.2.0 saved them.
///
/// 0.2.0 wrote `grants` with `serde_json::to_string(&Grants)` and had no
/// `virt` field, so the JSON below is byte for byte what it stored: a role
/// with `shell` (the upgraded admin), one without (a remote-desktop role an
/// admin created), and a built-in still waiting for `ensure_roles`.
/// Migration 023 against roles saved with `ssh_terminal`, as every agent from
/// 0.2.0 until it saved them.
#[tokio::test]
async fn migration_023_drops_the_ssh_terminal_grant_and_the_pinned_host_key() {
    use server_box_monitor::db::accounts;
    use server_box_monitor::core::permissions::ConnectGrant;

    let pool = pool().await;
    migrator_through(22).run(&pool).await.unwrap();
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

    sqlx::migrate!("./migrations").run(&pool).await.unwrap();

    // Readable again (`Grants` refuses the field), and nothing else changed.
    let admin = accounts::role(&pool, "admin").await.unwrap().unwrap();
    assert!(admin.grants.shell && admin.grants.virt);
    assert_eq!(admin.grants.connect, Some(ConnectGrant::default()));
    // A role that held only the SSH terminal holds nothing now: it is not
    // given `shell` in its place.
    let ssh_only = accounts::role(&pool, "ssh_only").await.unwrap().unwrap();
    assert_eq!(ssh_only.grants, Default::default());
    // Undecided stays undecided.
    let viewer: Option<String> = sqlx::query_scalar("SELECT grants FROM roles WHERE name = 'viewer'")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(viewer, None);
    let table: i64 = sqlx::query_scalar(
        "SELECT count(*) FROM sqlite_master WHERE type = 'table' AND name = 'ssh_known_hosts'",
    )
    .fetch_one(&pool)
    .await
    .unwrap();
    assert_eq!(table, 0);
}

#[tokio::test]
async fn migration_011_gives_virt_to_the_roles_that_hold_shell() {
    use server_box_monitor::db::accounts;

    let pool = pool().await;
    migrator_through(10).run(&pool).await.unwrap();
    let saved_by_0_2_0 = [
        (
            "admin",
            r#"{"shell":true,"ssh_terminal":true,"files":{"mode":"write"},"connect":{"allow":[]},"listen":{"public":false,"ports":null}}"#,
        ),
        (
            "desktop",
            r#"{"shell":false,"ssh_terminal":false,"files":null,"connect":{"allow":["127.0.0.1:3389"]},"listen":null}"#,
        ),
    ];
    for (name, grants) in saved_by_0_2_0 {
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

    sqlx::migrate!("./migrations").run(&pool).await.unwrap();

    let admin = accounts::role(&pool, "admin").await.unwrap().unwrap();
    assert!(admin.grants.virt && admin.grants.shell);
    let desktop = accounts::role(&pool, "desktop").await.unwrap().unwrap();
    assert!(!desktop.grants.virt);
    assert_eq!(desktop.grants.connect.unwrap().allow, ["127.0.0.1:3389"]);
    // Undecided stays undecided, for `ensure_roles` to settle.
    let viewer: Option<String> = sqlx::query_scalar("SELECT grants FROM roles WHERE name = 'viewer'")
        .fetch_one(&pool)
        .await
        .unwrap();
    assert_eq!(viewer, None);
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
        (18, "d01153e6b7558e25e007cce38b62ce6d64117f07ba932c1726317b48625c9fdd438ea3b58bc86e0d6b90d421c8dcc77d"),
        (19, "b3b7998eb4ddae83e72cf79667588eaae5c197ae667f4c836e5533b91adf228acda1c237111472a9661045f8feb70e24"),
        (20, "3fcf9300b02b96325ae075c7147ace3a3ac085693a5c7bc80400d035fd334937f86e180ef901082dde02f1b08aec2d3c"),
        (21, "8549100ea818734178a5c13ddcb90999e29d3636163abda31f2f7b6ae749a17e53ba128315f60a0b7d879aca525f5c7e"),
        (22, "7122ab7e33fe302a7e82f40a3b79efb8fd6fd85047f4bc7dd675a85aedc02e92813b4987db46891978f4cba329dd4c3a"),
        (23, "5f9544a9e8df9e588c6c604ca7be4871c4b4996489f0faeacd34037fe44f8beca506a418f56fe79598f39f7fa5c03aad"),
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
