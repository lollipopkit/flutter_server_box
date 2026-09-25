use anyhow::Result;
use sqlx::sqlite::{
    SqliteAutoVacuum, SqliteConnectOptions, SqliteJournalMode, SqlitePool, SqlitePoolOptions,
    SqliteSynchronous,
};
use sqlx::{Sqlite, migrate::MigrateDatabase};
use std::str::FromStr;
use std::time::Duration;
use tracing::info;

/// WAL frames to accumulate before SQLite folds them back into the database
/// file, well below SQLite's own default of 1000 (4 MiB at the default page
/// size).
///
/// This agent commits one small row every few seconds for as long as it runs,
/// so with the default the WAL sits near its ceiling essentially all the time.
/// That costs nothing while the file stays cached — and everything when it
/// does not: rebuilding the WAL index reads *every* frame, so on a host that
/// keeps reclaiming the page cache (a VM with free-page reporting, a small
/// VPS) each sample was measured re-reading ~4 MB from disk to append ~16 KB.
/// Checkpointing more often moves the same bytes into the database file, just
/// in smaller pieces, so the ceiling is what to lower.
const WAL_AUTOCHECKPOINT_PAGES: u32 = 128;

/// Size the WAL file is truncated back to after a checkpoint that leaves it
/// larger, in bytes.
///
/// A checkpoint resets the WAL, it does not shorten the file, and SQLite's
/// default `journal_size_limit` of -1 means it never will — so the file stays
/// as large as the largest transaction ever written through it. One
/// transaction here is far larger than the rest: VACUUM rewrites the whole
/// database, and `cleanup::reclaim_free_pages` runs one on the first pass
/// after an upgrade. Measured on a real agent, that reclaimed 84 MB from the
/// database and left a 52 MB WAL behind it, which is most of the point of
/// reclaiming given back.
///
/// Twice [`WAL_AUTOCHECKPOINT_PAGES`] at the default 4 KiB page, so it is a
/// backstop for the outlier rather than something that fires on every
/// checkpoint: the WAL sits at roughly the autocheckpoint ceiling in normal
/// use and never reaches this.
const WAL_SIZE_LIMIT_BYTES: u32 = WAL_AUTOCHECKPOINT_PAGES * 4096 * 2;

pub async fn init(database_url: &str) -> Result<SqlitePool> {
    let options = connect_options(database_url)?;
    let file = options.get_filename().to_path_buf();

    // Logged, not created. `Sqlite::create_database` opens a connection of its
    // own with default settings, and the file it leaves behind is past the
    // point where `auto_vacuum` can still be chosen — the setting is only
    // applied to a database with no pages yet. `create_if_missing` below makes
    // the first connection to a new file one that carries every setting.
    if !Sqlite::database_exists(database_url).await? {
        info!("Creating database {}", database_url);
        // An empty file is a database with no pages, so every setting above
        // still applies to it; what this decides is the mode, which SQLite
        // would otherwise take from the umask.
        #[cfg(unix)]
        create_owner_only(&file)?;
    }

    let pool = SqlitePoolOptions::new().connect_with(options).await?;

    // Run migrations
    sqlx::migrate!("./migrations").run(&pool).await?;

    // After the first connection, which is what creates `-wal` and `-shm`.
    #[cfg(unix)]
    restrict_to_owner(&file)?;

    info!("Database initialized");
    Ok(pool)
}

/// Connection settings applied to every connection the pool opens.
///
/// They belong here rather than in a `PRAGMA` statement run after connecting:
/// these are per-connection settings, a pool opens connections lazily and
/// replaces them over their lifetime, so a statement executed once against the
/// pool configures whichever single connection happened to answer it.
fn connect_options(database_url: &str) -> Result<SqliteConnectOptions> {
    Ok(SqliteConnectOptions::from_str(database_url)?
        .create_if_missing(true)
        // Named explicitly rather than relied on: sqlx stopped setting a
        // journal mode of its own accord, and `journal_mode` is a persistent
        // property of the file, so an existing database stays in WAL either
        // way while a newly created one would quietly get a rollback journal —
        // a fsync-per-commit against the whole database file.
        .journal_mode(SqliteJournalMode::Wal)
        // Kept at SQLite's default, and named so that lowering it is a
        // decision rather than an omission. NORMAL under WAL cannot corrupt
        // the file and only risks the most recent transactions, which for a
        // metrics row seconds away from its successor costs nothing — but this
        // database is not only metrics. `users` carries the panel credential,
        // `watch_tokens` is what revoking a watch's access deletes from, and
        // `access_log` and `config_audit_log` exist to be readable after
        // exactly the kind of event that would lose an unsynced commit. A
        // password change or a revocation silently not having happened is not
        // a cost worth an fsync, and the read amplification this file set out
        // to fix was `wal_autocheckpoint`, not this.
        .synchronous(SqliteSynchronous::Full)
        // Only ever takes effect on a database that is still empty, so this
        // sets the behaviour for new installs; an existing file reports NONE
        // until the one full VACUUM in `cleanup` converts it.
        .auto_vacuum(SqliteAutoVacuum::Incremental)
        .pragma(
            "wal_autocheckpoint",
            WAL_AUTOCHECKPOINT_PAGES.to_string(),
        )
        .pragma("journal_size_limit", WAL_SIZE_LIMIT_BYTES.to_string())
        .busy_timeout(Duration::from_secs(30)))
}

/// Creates [path] empty and readable by its owner only, if it is not there.
///
/// This file holds the panel's password hashes, the watch tokens and the
/// access log, and the agent's directory is an ordinary 0755 one: created by
/// SQLite under a 022 umask it was 0644, readable by every account on the
/// machine, beside a `jwt.secret` kept at 0600.
#[cfg(unix)]
fn create_owner_only(path: &std::path::Path) -> Result<()> {
    use std::os::unix::fs::OpenOptionsExt;

    // In-memory and URI databases name no file; neither has a mode to set.
    if path.as_os_str().is_empty() || path == std::path::Path::new(":memory:") {
        return Ok(());
    }
    if let Some(dir) = path.parent().filter(|d| !d.as_os_str().is_empty()) {
        std::fs::create_dir_all(dir)?;
    }
    match std::fs::OpenOptions::new()
        .write(true)
        .create_new(true)
        .mode(0o600)
        .open(path)
    {
        Ok(_) => Ok(()),
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => Ok(()),
        Err(e) => Err(e.into()),
    }
}

/// Takes group and other access off the database and its WAL and shared-memory
/// files. For a database created before [`create_owner_only`]; SQLite gives a
/// new `-wal`/`-shm` the database file's own mode, so after this they stay so.
#[cfg(unix)]
fn restrict_to_owner(path: &std::path::Path) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;

    for suffix in ["", "-wal", "-shm"] {
        let mut name = path.as_os_str().to_os_string();
        name.push(suffix);
        let file = std::path::PathBuf::from(name);
        let Ok(meta) = std::fs::metadata(&file) else {
            continue;
        };
        if !meta.is_file() || meta.permissions().mode() & 0o077 == 0 {
            continue;
        }
        std::fs::set_permissions(&file, std::fs::Permissions::from_mode(0o600))?;
        info!("Restricted {} to its owner", file.display());
    }
    Ok(())
}
