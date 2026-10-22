//! What a backup holds and how it goes back.
//!
//! An archive (`tar.gz`) of:
//! - `manifest.json` ([`Manifest`]),
//! - `config.toml` as it was on disk,
//! - `settings.db`: a database with this monitor's schema whose [`KEPT`] tables
//!   are filled from the live one (the account's row only its password), every
//!   other table empty,
//! - `blobs/<sha256>`: the files those rows name (`core::blobs`).
//!
//! Restoring brings `settings.db` up to this build's migrations, then replaces
//! the [`KEPT`] tables in one transaction, and puts back from `config.toml`
//! only what is not this machine's ([`merge_config`]).

use std::collections::BTreeSet;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};
use sha2::{Digest as _, Sha256};
use sqlx::{Executor, SqliteConnection, SqlitePool};

use crate::core::blobs::Blobs;
use crate::core::config::Config;

/// A table a backup carries, parents before children, with the columns that
/// change on their own: left out of the stable hash, so they alone never make
/// a new backup ([`Digest`]).
pub struct Kept {
    pub table: &'static str,
    pub volatile: &'static [&'static str],
}

const fn kept(table: &'static str) -> Kept {
    Kept { table, volatile: &[] }
}

/// What a backup carries. `users` is the account's password only.
pub const KEPT: &[Kept] = &[
    Kept { table: "users", volatile: &[] },
    kept("snippet"),
    kept("snippet_tag"),
    kept("desktop_profile"),
    kept("bmc_target"),
    kept("virt_pve"),
    kept("desk_preferences"),
    kept("desk_dock"),
    kept("desk_icon"),
    kept("desk_wallpaper"),
    kept("desk_background_denied"),
    kept("desk_onboarding"),
    kept("desk_theme"),
    kept("desk_theme_background"),
    Kept { table: "desk_app_storage", volatile: &["value", "updated_at"] },
    kept("desk_app_declined"),
    kept("agent_settings"),
    kept("agent_provider"),
    kept("agent_credential"),
    kept("agent_permissions"),
    kept("agent_mcp_server"),
    Kept { table: "mcp_oauth", volatile: &["access_token", "refresh_token", "expires_at", "updated_at"] },
    kept("container_backup_settings"),
    Kept { table: "container_backup_schedule", volatile: &["last_run", "last_error"] },
    Kept { table: "storage_maintenance", volatile: &["last_run", "last_error"] },
    Kept { table: "retention_policies", volatile: &["last_cleanup", "updated_at"] },
];

/// What a backup leaves out: history, what is signed in, what lives in files
/// of its own (installed apps, deployed web apps, Agent mode's tasks and
/// skills), and where backups go. A new table goes in one list or the other
/// (`every_table_is_kept_or_left_out`).
pub const LEFT_OUT: &[&str] = &[
    "system_metrics",
    "alerts",
    "network_totals",
    "config_versions",
    "config_audit_log",
    "enhanced_alerts",
    "component_metrics",
    "rule_executions",
    "performance_metrics",
    "access_log",
    "benchmark_run",
    "backup_blob",
    "backup_file",
    "desk_session",
    "desk_window",
    "desk_notification",
    "desk_notification_read",
    "desk_app_package",
    "desk_app_file",
    "agent_flow",
    "agent_memory",
    "agent_skill",
    "stack",
    "stack_mcp",
    "watch_tokens",
    "login_device",
    "monitor_backup",
];

/// The account's columns a backup carries.
const USER_COLUMNS: &[&str] = &["id", "password_hash"];

/// Blob columns of the [`KEPT`] tables (`core::blobs`).
const BLOBS: &str = "SELECT sha256 FROM main.desk_wallpaper UNION SELECT sha256 FROM main.desk_theme_background";

pub const MANIFEST: &str = "manifest.json";
pub const CONFIG: &str = "config.toml";
pub const DATABASE: &str = "settings.db";
pub const FORMAT: u32 = 1;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    pub format: u32,
    /// The monitor that wrote it.
    pub monitor_version: String,
    /// Its newest migration.
    pub migration: i64,
    /// The machine's name (`Config::get_server_name`).
    pub host: String,
    pub created_at: String,
}

/// What the settings hold, hashed twice: `stable` without [`Kept::volatile`],
/// `full` with everything.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Digest {
    pub stable: String,
    pub full: String,
}

fn ident(name: &str) -> String {
    format!("\"{}\"", name.replace('"', "\"\""))
}

async fn columns(conn: &mut SqliteConnection, schema: &str, table: &str) -> sqlx::Result<Vec<String>> {
    let rows: Vec<(String,)> =
        sqlx::query_as(sqlx::AssertSqlSafe(format!("SELECT name FROM pragma_table_info({}, {}) ORDER BY cid", quote(table), quote(schema))))
            .fetch_all(&mut *conn)
            .await?;
    Ok(rows.into_iter().map(|(n,)| n).collect())
}

fn quote(text: &str) -> String {
    format!("'{}'", text.replace('\'', "''"))
}

/// The account's row: the oldest (`accounts::owner`).
const OWNER: &str = "id = (SELECT MIN(id) FROM main.users)";

/// The hashes of what a backup taken now would hold, beside [config] (the
/// file's bytes).
pub async fn digest(db: &SqlitePool, config: Option<&[u8]>) -> sqlx::Result<Digest> {
    let mut conn = Guarded::acquire(db).await?;
    let mut stable = Sha256::new();
    let mut full = Sha256::new();
    let mut both = |bytes: &[u8]| {
        stable.update(bytes);
        full.update(bytes);
    };
    both(&FORMAT.to_le_bytes());
    match config {
        Some(c) => both(&[&(c.len() as u64).to_le_bytes()[..], c].concat()),
        None => both(b"no config"),
    }
    conn.execute("BEGIN").await?;
    let result: sqlx::Result<()> = async {
        for k in KEPT {
            let mut cols = columns(&mut conn, "main", k.table).await?;
            if k.table == "users" {
                cols.retain(|c| USER_COLUMNS.contains(&c.as_str()) && c != "id");
            }
            let full_expr = cols.iter().map(|c| format!("quote({})", ident(c))).collect::<Vec<_>>().join(" || char(31) || ");
            let stable_expr = cols
                .iter()
                .map(|c| if k.volatile.contains(&c.as_str()) { "'-'".to_string() } else { format!("quote({})", ident(c)) })
                .collect::<Vec<_>>()
                .join(" || char(31) || ");
            let filter = if k.table == "users" { format!(" WHERE {OWNER}") } else { String::new() };
            let sql = format!("SELECT {full_expr}, {stable_expr} FROM main.{}{filter} ORDER BY rowid", ident(k.table));
            let rows: Vec<(String, String)> = sqlx::query_as(sqlx::AssertSqlSafe(sql)).fetch_all(&mut *conn).await?;
            let head = format!("\u{1e}{}\u{1e}{}", k.table, cols.join(","));
            stable.update(head.as_bytes());
            full.update(head.as_bytes());
            for (f, s) in rows {
                full.update(f.as_bytes());
                full.update(b"\x1d");
                stable.update(s.as_bytes());
                stable.update(b"\x1d");
            }
        }
        Ok(())
    }
    .await;
    let committed = conn.execute("COMMIT").await;
    result?;
    committed?;
    conn.done();
    Ok(Digest { stable: hex::encode(stable.finalize()), full: hex::encode(full.finalize()) })
}

/// A pooled connection closed, not given back, when dropped before
/// [`Guarded::done`]: a future dropped mid-transaction (a client gone during
/// a restore) would leave the transaction open and `other` attached in the
/// pool, holding up every writer and refusing the next `ATTACH`.
struct Guarded {
    conn: sqlx::pool::PoolConnection<sqlx::Sqlite>,
    done: bool,
}

impl Guarded {
    async fn acquire(db: &SqlitePool) -> sqlx::Result<Self> {
        Ok(Self { conn: db.acquire().await?, done: false })
    }

    /// The transaction and the attachment are over: back to the pool.
    fn done(&mut self) {
        self.done = true;
    }
}

impl std::ops::Deref for Guarded {
    type Target = SqliteConnection;
    fn deref(&self) -> &SqliteConnection {
        &self.conn
    }
}

impl std::ops::DerefMut for Guarded {
    fn deref_mut(&mut self) -> &mut SqliteConnection {
        &mut self.conn
    }
}

impl Drop for Guarded {
    fn drop(&mut self) {
        if !self.done {
            self.conn.close_on_drop();
        }
    }
}

/// A database at [path] with this build's schema, every table empty.
async fn empty_database(path: &Path) -> anyhow::Result<()> {
    let db = single(path, true).await?;
    crate::db::database::MIGRATOR.run(&db).await?;
    let tables: Vec<(String,)> =
        sqlx::query_as("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != '_sqlx_migrations'")
            .fetch_all(&db)
            .await?;
    for (t,) in tables {
        sqlx::query(sqlx::AssertSqlSafe(format!("DELETE FROM {}", ident(&t)))).execute(&db).await?;
    }
    db.close().await;
    Ok(())
}

/// The database file at [path] alone, foreign keys off (a backup's tables
/// are filled one at a time). A pool of one: the migrator run on a bare
/// connection is a future that is not `Send` for every lifetime.
async fn single(path: &Path, create: bool) -> sqlx::Result<SqlitePool> {
    // Rollback journal, not WAL: the file is read whole once its connections
    // close, and attached from the live database in between.
    let options = sqlx::sqlite::SqliteConnectOptions::new()
        .filename(path)
        .create_if_missing(create)
        .foreign_keys(false)
        .journal_mode(sqlx::sqlite::SqliteJournalMode::Delete);
    sqlx::sqlite::SqlitePoolOptions::new().max_connections(1).connect_with(options).await
}

/// Attaches the database file [file] to [conn] as `other`. As a `file:` URI
/// with `mode=rw`: a plain name attached to an in-memory database (a test's)
/// would be another in-memory one.
async fn attach(conn: &mut SqliteConnection, file: &Path) -> anyhow::Result<()> {
    let mut uri = url::Url::from_file_path(std::fs::canonicalize(file)?).map_err(|()| anyhow::anyhow!("not an absolute path"))?;
    uri.set_query(Some("mode=rw"));
    sqlx::query("ATTACH DATABASE ? AS other").bind(uri.as_str()).execute(&mut *conn).await?;
    Ok(())
}

/// Ends what [result] left open on [conn] and detaches `other`; only then
/// may the connection go back to the pool.
async fn detach<T>(conn: &mut Guarded, result: anyhow::Result<T>) -> anyhow::Result<T> {
    if result.is_err() {
        let _ = conn.execute("ROLLBACK").await;
    }
    sqlx::query("DETACH DATABASE other").execute(&mut **conn).await?;
    conn.done();
    result
}

/// Writes the settings into a new database at [path]; answers the blobs its
/// rows name.
pub async fn write_database(db: &SqlitePool, path: &Path) -> anyhow::Result<Vec<String>> {
    empty_database(path).await?;
    let mut conn = Guarded::acquire(db).await?;
    attach(&mut conn, path).await?;
    let result = copy_out(&mut conn).await;
    detach(&mut conn, result).await
}

async fn copy_out(conn: &mut SqliteConnection) -> anyhow::Result<Vec<String>> {
    conn.execute("BEGIN").await?;
    for k in KEPT {
        let mut cols = columns(conn, "main", k.table).await?;
        let filter = if k.table == "users" {
            cols.retain(|c| USER_COLUMNS.contains(&c.as_str()));
            format!(" WHERE {OWNER}")
        } else {
            String::new()
        };
        let list = cols.iter().map(|c| ident(c)).collect::<Vec<_>>().join(", ");
        let t = ident(k.table);
        conn.execute(sqlx::AssertSqlSafe(format!("INSERT INTO other.{t} ({list}) SELECT {list} FROM main.{t}{filter}"))).await?;
    }
    let blobs: Vec<(String,)> = sqlx::query_as(BLOBS).fetch_all(&mut *conn).await?;
    conn.execute("COMMIT").await?;
    Ok(blobs.into_iter().map(|(b,)| b).collect())
}

/// The archive's entries, read back: at most this many.
const MAX_ENTRIES: usize = 10_000;
/// And at most this much inflated.
const MAX_INFLATED: u64 = 1 << 30;

/// Writes the archive to [out]: [manifest], [config], the database at [db]
/// and [blobs] (`(sha256, bytes)`).
/// [blobs]: each file open, with its length, streamed into the archive.
pub fn write_archive(out: &Path, manifest: &Manifest, config: Option<&[u8]>, db: &Path, blobs: Vec<(String, std::fs::File, u64)>) -> anyhow::Result<()> {
    let file = std::fs::File::create(out)?;
    let gz = flate2::write::GzEncoder::new(file, flate2::Compression::default());
    let mut tar = tar::Builder::new(gz);
    tar.mode(tar::HeaderMode::Deterministic);
    let mut add = |name: &str, len: u64, data: &mut dyn Read| -> std::io::Result<()> {
        let mut header = tar::Header::new_gnu();
        header.set_size(len);
        header.set_mode(0o600);
        header.set_cksum();
        tar.append_data(&mut header, name, data)
    };
    let manifest = serde_json::to_vec_pretty(manifest)?;
    add(MANIFEST, manifest.len() as u64, &mut manifest.as_slice())?;
    if let Some(c) = config {
        add(CONFIG, c.len() as u64, &mut &c[..])?;
    }
    let mut db = std::fs::File::open(db)?;
    let len = db.metadata()?.len();
    add(DATABASE, len, &mut db)?;
    for (sha, file, len) in blobs {
        // At the length measured: a file that changed since is not this blob.
        add(&format!("blobs/{sha}"), len, &mut file.take(len))?;
    }
    tar.into_inner()?.finish()?.sync_all()?;
    Ok(())
}

/// An archive unpacked into a folder.
pub struct Unpacked {
    pub manifest: Manifest,
    pub config: Option<Vec<u8>>,
    pub database: PathBuf,
    /// `(sha256, path)`, each checked against its name.
    pub blobs: Vec<(String, PathBuf)>,
}

/// Why an archive is refused.
#[derive(Debug, thiserror::Error)]
pub enum Invalid {
    #[error("not a backup this monitor reads: {0}")]
    Format(String),
    #[error("{0}")]
    Io(#[from] std::io::Error),
}

/// The most the manifest or `config.toml` may be: both are read whole.
const MAX_SMALL: u64 = 1 << 20;

/// A file written and hashed at once.
struct Hashing(std::fs::File, Sha256);

impl Write for Hashing {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        let n = self.0.write(buf)?;
        self.1.update(&buf[..n]);
        Ok(n)
    }
    fn flush(&mut self) -> std::io::Result<()> {
        self.0.flush()
    }
}

fn is_sha(name: &str) -> bool {
    name.len() == 64 && name.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

/// Unpacks the archive at [archive] into [dir], each entry checked: only the
/// names a backup has, regular files, bounded in count and size.
pub fn unpack(archive: &Path, dir: &Path) -> Result<Unpacked, Invalid> {
    let bad = |why: &str| Invalid::Format(why.to_string());
    let gz = flate2::read::GzDecoder::new(std::fs::File::open(archive)?);
    let mut tar = tar::Archive::new(gz);
    let (mut manifest, mut config, mut database, mut blobs) = (None, None, None, Vec::new());
    let mut inflated = 0u64;
    let mut seen = BTreeSet::new();
    for (n, entry) in tar.entries().map_err(|_| bad("not a tar.gz"))?.enumerate() {
        let mut entry = entry.map_err(|_| bad("a damaged entry"))?;
        if n >= MAX_ENTRIES {
            return Err(bad("too many entries"));
        }
        if !entry.header().entry_type().is_file() {
            return Err(bad("an entry that is not a file"));
        }
        let name = entry.path().map_err(|_| bad("an entry name"))?.to_string_lossy().into_owned();
        if !seen.insert(name.clone()) {
            return Err(bad("an entry twice"));
        }
        inflated += entry.size();
        if inflated > MAX_INFLATED {
            return Err(bad("too large"));
        }
        // Files go to disk as they are read; only the small ones are held.
        let small = |entry: &mut tar::Entry<'_, _>| -> Result<Vec<u8>, Invalid> {
            if entry.size() > MAX_SMALL {
                return Err(bad("too large"));
            }
            let mut bytes = Vec::new();
            entry.take(MAX_SMALL).read_to_end(&mut bytes)?;
            Ok(bytes)
        };
        match name.as_str() {
            MANIFEST => manifest = Some(serde_json::from_slice::<Manifest>(&small(&mut entry)?).map_err(|_| bad("its manifest"))?),
            CONFIG => config = Some(small(&mut entry)?),
            DATABASE => {
                let path = dir.join(DATABASE);
                std::io::copy(&mut (&mut entry).take(MAX_INFLATED), &mut std::fs::File::create(&path)?)?;
                database = Some(path);
            }
            other => {
                let sha = other.strip_prefix("blobs/").filter(|s| is_sha(s)).ok_or_else(|| bad("an unknown entry"))?;
                let path = dir.join(format!("blob-{sha}"));
                let mut out = Hashing(std::fs::File::create(&path)?, Sha256::new());
                std::io::copy(&mut (&mut entry).take(MAX_INFLATED), &mut out)?;
                if hex::encode(out.1.finalize()) != sha {
                    return Err(bad("a file that does not match its name"));
                }
                blobs.push((sha.to_string(), path));
            }
        }
    }
    let manifest = manifest.ok_or_else(|| bad("no manifest"))?;
    if manifest.format != FORMAT {
        return Err(bad("a newer format"));
    }
    Ok(Unpacked { manifest, config, database: database.ok_or_else(|| bad("no database"))?, blobs })
}

/// Why restoring the database stopped.
#[derive(Debug, thiserror::Error)]
pub enum RestoreError {
    /// Made by a monitor with migrations this one does not have.
    #[error("the backup is from a newer monitor")]
    Newer,
    #[error("the backup is not one this monitor reads: {0}")]
    Invalid(String),
    #[error(transparent)]
    Other(#[from] anyhow::Error),
}

impl From<sqlx::Error> for RestoreError {
    fn from(e: sqlx::Error) -> Self {
        Self::Other(e.into())
    }
}

/// What a restore put back.
#[derive(Debug, Clone, Default, Serialize)]
pub struct Restored {
    /// Rows per table.
    pub tables: Vec<(String, i64)>,
    pub blobs: usize,
    pub config: bool,
}

/// Brings the backup's database at [file] to this build's schema.
async fn upgrade(file: &Path) -> Result<(), RestoreError> {
    let db = single(file, false).await.map_err(|e| RestoreError::Invalid(e.to_string()))?;
    let applied: Vec<(i64,)> = sqlx::query_as("SELECT version FROM _sqlx_migrations")
        .fetch_all(&db)
        .await
        .map_err(|e| RestoreError::Invalid(e.to_string()))?;
    let known: BTreeSet<i64> = crate::db::database::MIGRATOR.iter().map(|m| m.version).collect();
    if applied.iter().any(|(v,)| !known.contains(v)) {
        return Err(RestoreError::Newer);
    }
    crate::db::database::MIGRATOR.run(&db).await.map_err(|e| RestoreError::Other(e.into()))?;
    db.close().await;
    Ok(())
}

/// Replaces the [`KEPT`] tables of [db] with the backup's, its files put in
/// [store] first. The account keeps its row; its password becomes the
/// backup's, as a password change.
pub async fn restore_database(db: &SqlitePool, store: &Blobs, unpacked: &Unpacked) -> Result<Restored, RestoreError> {
    upgrade(&unpacked.database).await?;
    let _writing = store.writing().await;
    for (sha, path) in &unpacked.blobs {
        let bytes = tokio::fs::read(path).await.map_err(anyhow::Error::from)?;
        let put = store.put(&bytes).await.map_err(anyhow::Error::from)?;
        if &put != sha {
            return Err(RestoreError::Invalid("a file that does not match its name".into()));
        }
    }
    let mut conn = Guarded::acquire(db).await?;
    attach(&mut conn, &unpacked.database).await?;
    let result = copy_in(&mut conn, unpacked.blobs.len()).await;
    Ok(detach(&mut conn, result).await?)
}

async fn copy_in(conn: &mut SqliteConnection, blobs: usize) -> anyhow::Result<Restored> {
    conn.execute("BEGIN IMMEDIATE").await?;
    let backup_owner: Option<(i64, String)> = sqlx::query_as("SELECT id, password_hash FROM other.users ORDER BY id LIMIT 1").fetch_optional(&mut *conn).await?;
    let (backup_owner, hash) = backup_owner.ok_or_else(|| anyhow::anyhow!("the backup has no account"))?;
    let now_ms = chrono::Utc::now().timestamp_millis();
    let owner: Option<i64> = sqlx::query_scalar("SELECT MIN(id) FROM main.users").fetch_one(&mut *conn).await?;
    let owner = match owner {
        Some(id) => {
            // As `accounts::set_password_hash`: strictly later, and what
            // the old password paired goes.
            sqlx::query("UPDATE main.users SET password_hash = ?, password_changed_ms = max(?, password_changed_ms + 1) WHERE id = ?")
                .bind(&hash)
                .bind(now_ms)
                .bind(id)
                .execute(&mut *conn)
                .await?;
            conn.execute("DELETE FROM main.watch_tokens").await?;
            conn.execute("DELETE FROM main.login_device").await?;
            id
        }
        None => {
            sqlx::query("INSERT INTO main.users (id, password_hash, password_changed_ms) VALUES (?, ?, ?)").bind(backup_owner).bind(&hash).bind(now_ms).execute(&mut *conn).await?;
            backup_owner
        }
    };
    // Plain loops: an iterator's closure held across an await makes this
    // future not `Send` for every lifetime.
    for k in KEPT.iter().rev() {
        if k.table == "users" {
            continue;
        }
        conn.execute(sqlx::AssertSqlSafe(format!("DELETE FROM main.{}", ident(k.table)))).await?;
    }
    let mut tables = Vec::new();
    for k in KEPT {
        if k.table == "users" {
            continue;
        }
        let cols = columns(conn, "main", k.table).await?;
        let list = cols.iter().map(|c| ident(c)).collect::<Vec<_>>().join(", ");
        let by_user = cols.iter().any(|c| c == "user_id");
        let select = cols.iter().map(|c| if c == "user_id" { "?1".to_string() } else { ident(c) }).collect::<Vec<_>>().join(", ");
        let t = ident(k.table);
        let filter = if by_user { " WHERE user_id = ?2" } else { "" };
        let query = sqlx::query(sqlx::AssertSqlSafe(format!("INSERT INTO main.{t} ({list}) SELECT {select} FROM other.{t}{filter}")));
        let query = if by_user { query.bind(owner).bind(backup_owner) } else { query };
        let done = query.execute(&mut *conn).await?;
        tables.push((k.table.to_string(), done.rows_affected() as i64));
    }
    for k in KEPT {
        let broken = sqlx::query(sqlx::AssertSqlSafe(format!("PRAGMA main.foreign_key_check({})", ident(k.table)))).fetch_all(&mut *conn).await?;
        if !broken.is_empty() {
            anyhow::bail!("restored rows of {} name rows that are not there", k.table);
        }
    }
    conn.execute("COMMIT").await?;
    Ok(Restored { tables, blobs, config: false })
}

/// [current] with what [backup] says that is not this machine's: monitoring
/// (intervals, rules, retention), push channels, and the server's name,
/// allowed origins and card order. Addresses, TLS, the database, remote
/// access limits and web apps' folders stay [current]'s.
pub fn merge_config(mut current: Config, backup: &Config) -> Config {
    current.monitoring = backup.monitoring.clone();
    current.push = backup.push.clone();
    if let Some(from) = &backup.server {
        let mut server = current.get_server();
        server.name = from.name.clone();
        server.cors_allowed_origins = from.cors_allowed_origins.clone();
        server.card_order = from.card_order.clone();
        current.server = Some(server);
    }
    current
}

#[cfg(test)]
mod tests {
    use super::*;
    use sqlx::Connection;

    async fn database() -> SqlitePool {
        let db = SqlitePool::connect("sqlite::memory:").await.unwrap();
        crate::db::database::MIGRATOR.run(&db).await.unwrap();
        db
    }

    #[tokio::test]
    async fn every_table_is_kept_or_left_out() {
        let db = database().await;
        let tables: Vec<(String,)> = sqlx::query_as("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name != '_sqlx_migrations'")
            .fetch_all(&db)
            .await
            .unwrap();
        let kept: BTreeSet<&str> = KEPT.iter().map(|k| k.table).collect();
        let left: BTreeSet<&str> = LEFT_OUT.iter().copied().collect();
        assert!(kept.is_disjoint(&left));
        let named: BTreeSet<&str> = kept.union(&left).copied().collect();
        let found: BTreeSet<&str> = tables.iter().map(|(t,)| t.as_str()).collect();
        assert_eq!(found, named, "a table must be in KEPT or LEFT_OUT");
        for k in KEPT {
            let mut conn = db.acquire().await.unwrap();
            let cols = columns(&mut conn, "main", k.table).await.unwrap();
            for v in k.volatile {
                assert!(cols.iter().any(|c| c == v), "{}.{v}", k.table);
            }
        }
    }

    #[tokio::test]
    async fn only_a_change_that_matters_changes_the_stable_hash() {
        let db = database().await;
        crate::db::accounts::insert_owner(&db, "hash").await.unwrap();
        let before = digest(&db, Some(b"a = 1")).await.unwrap();
        assert_eq!(before, digest(&db, Some(b"a = 1")).await.unwrap());
        assert_ne!(before.stable, digest(&db, Some(b"a = 2")).await.unwrap().stable);

        sqlx::query("UPDATE users SET last_login = CURRENT_TIMESTAMP").execute(&db).await.unwrap();
        sqlx::query("INSERT INTO storage_maintenance (task, every, at, day, updated_at) VALUES ('scrub', 'weekly', '03:00', 1, 'x')").execute(&db).await.unwrap();
        let added = digest(&db, Some(b"a = 1")).await.unwrap();
        assert_ne!(added.stable, before.stable);
        sqlx::query("UPDATE storage_maintenance SET last_run = 'now'").execute(&db).await.unwrap();
        let ran = digest(&db, Some(b"a = 1")).await.unwrap();
        assert_eq!(ran.stable, added.stable, "a run is not a change");
        assert_ne!(ran.full, added.full);
    }

    #[tokio::test]
    async fn settings_go_back_and_history_stays() {
        let dir = tempfile::tempdir().unwrap();
        let blobs = Blobs::beside(&dir.path().join("db"));
        let src = database().await;
        crate::db::accounts::insert_owner(&src, "old-hash").await.unwrap();
        sqlx::query("INSERT INTO snippet (id, name, script, position, updated_at) VALUES ('s1', 'Hi', 'echo hi', 0, 'x')").execute(&src).await.unwrap();
        sqlx::query("INSERT INTO snippet_tag (snippet_id, tag, position) VALUES ('s1', 'net', 0)").execute(&src).await.unwrap();
        let sha = blobs.put(b"a wallpaper").await.unwrap();
        sqlx::query("INSERT INTO desk_wallpaper (user_id, mime, sha256) VALUES (1, 'image/png', ?)").bind(&sha).execute(&src).await.unwrap();
        sqlx::query("INSERT INTO access_log (timestamp, kind, action, result) VALUES ('x', 'login', 'open', 'ok')").execute(&src).await.unwrap();

        let file = dir.path().join("settings.db");
        let named = write_database(&src, &file).await.unwrap();
        assert_eq!(named, vec![sha.clone()]);
        let archive = dir.path().join("a.tar.gz");
        let manifest = Manifest { format: FORMAT, monitor_version: "t".into(), migration: 39, host: "h".into(), created_at: "now".into() };
        let wallpaper = std::fs::File::open(blobs.path(&sha).unwrap()).unwrap();
        write_archive(&archive, &manifest, Some(b"x = 1"), &file, vec![(sha.clone(), wallpaper, 11)]).unwrap();
        let out = dir.path().join("out");
        std::fs::create_dir(&out).unwrap();
        let unpacked = unpack(&archive, &out).unwrap();
        assert_eq!(unpacked.config.as_deref(), Some(&b"x = 1"[..]));
        assert_eq!(unpacked.blobs.len(), 1);

        // Another machine: its own account (id 5), history and snippets.
        let dst = database().await;
        sqlx::query("INSERT INTO users (id, password_hash) VALUES (5, 'new-hash')").execute(&dst).await.unwrap();
        sqlx::query("INSERT INTO snippet (id, name, script, position, updated_at) VALUES ('s9', 'Old', 'true', 0, 'x')").execute(&dst).await.unwrap();
        sqlx::query("INSERT INTO access_log (timestamp, kind, action, result) VALUES ('y', 'login', 'open', 'ok')").execute(&dst).await.unwrap();
        let other_blobs = Blobs::beside(&dir.path().join("other").join("db"));
        let restored = restore_database(&dst, &other_blobs, &unpacked).await.unwrap();
        assert!(restored.tables.contains(&("snippet".to_string(), 1)));

        let (hash, id): (String, i64) = sqlx::query_as("SELECT password_hash, id FROM users").fetch_one(&dst).await.unwrap();
        assert_eq!((hash.as_str(), id), ("old-hash", 5));
        let snippets: Vec<(String,)> = sqlx::query_as("SELECT id FROM snippet").fetch_all(&dst).await.unwrap();
        assert_eq!(snippets, vec![("s1".to_string(),)]);
        let tags: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM snippet_tag").fetch_one(&dst).await.unwrap();
        assert_eq!(tags, 1);
        let wall: (i64, String) = sqlx::query_as("SELECT user_id, sha256 FROM desk_wallpaper").fetch_one(&dst).await.unwrap();
        assert_eq!(wall, (5, sha.clone()));
        assert_eq!(other_blobs.read(&sha).await.unwrap().as_deref(), Some(&b"a wallpaper"[..]));
        let log: Vec<(String,)> = sqlx::query_as("SELECT timestamp FROM access_log").fetch_all(&dst).await.unwrap();
        assert_eq!(log, vec![("y".to_string(),)], "history is the machine's own");
    }

    #[tokio::test]
    async fn a_backup_from_a_newer_monitor_is_refused() {
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("settings.db");
        empty_database(&file).await.unwrap();
        let mut conn = SqliteConnection::connect_with(&sqlx::sqlite::SqliteConnectOptions::new().filename(&file)).await.unwrap();
        sqlx::query("INSERT INTO _sqlx_migrations (version, description, success, checksum, execution_time) VALUES (9999, 'future', 1, x'00', 0)")
            .execute(&mut conn)
            .await
            .unwrap();
        conn.close().await.unwrap();
        assert!(matches!(upgrade(&file).await, Err(RestoreError::Newer)));
    }

    #[test]
    fn a_file_that_does_not_match_its_name_is_refused() {
        let dir = tempfile::tempdir().unwrap();
        let archive = dir.path().join("a.tar.gz");
        let gz = flate2::write::GzEncoder::new(std::fs::File::create(&archive).unwrap(), flate2::Compression::default());
        let mut tar = tar::Builder::new(gz);
        let mut header = tar::Header::new_gnu();
        header.set_size(1);
        header.set_cksum();
        tar.append_data(&mut header, format!("blobs/{}", "0".repeat(64)), &b"x"[..]).unwrap();
        tar.into_inner().unwrap().finish().unwrap();
        assert!(matches!(unpack(&archive, dir.path()), Err(Invalid::Format(_))));
    }

    #[test]
    fn an_archive_with_anything_else_is_refused() {
        let dir = tempfile::tempdir().unwrap();
        let archive = dir.path().join("a.tar.gz");
        let gz = flate2::write::GzEncoder::new(std::fs::File::create(&archive).unwrap(), flate2::Compression::default());
        let mut tar = tar::Builder::new(gz);
        let mut header = tar::Header::new_gnu();
        header.set_size(1);
        header.set_cksum();
        tar.append_data(&mut header, "run.sh", &b"x"[..]).unwrap();
        tar.into_inner().unwrap().finish().unwrap();
        assert!(matches!(unpack(&archive, dir.path()), Err(Invalid::Format(_))));
        assert!(!dir.path().join("run.sh").exists());
    }

    #[test]
    fn only_what_is_not_the_machines_is_merged() {
        let base = Config::default().get_server();
        let current = Config {
            database_url: Some("sqlite:here.db".into()),
            server: Some(crate::core::config::ServerConfig { port: 4000, ..base.clone() }),
            ..Default::default()
        };
        let backup = Config {
            database_url: Some("sqlite:/elsewhere.db".into()),
            server: Some(crate::core::config::ServerConfig { port: 1, name: Some("box".into()), ..base }),
            push: Some(vec![]),
            ..Default::default()
        };
        let merged = merge_config(current, &backup);
        assert_eq!(merged.database_url.as_deref(), Some("sqlite:here.db"));
        assert_eq!(merged.get_server().port, 4000);
        assert_eq!(merged.get_server().name.as_deref(), Some("box"));
        assert_eq!(merged.push.as_ref().map(Vec::len), Some(0));
    }
}
