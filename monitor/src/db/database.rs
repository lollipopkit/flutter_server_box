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

pub async fn init(database_url: &str) -> Result<SqlitePool> {
    // Logged, not created. `Sqlite::create_database` opens a connection of its
    // own with default settings, and the file it leaves behind is past the
    // point where `auto_vacuum` can still be chosen — the setting is only
    // applied to a database with no pages yet. `create_if_missing` below makes
    // the first connection to a new file one that carries every setting.
    if !Sqlite::database_exists(database_url).await? {
        info!("Creating database {}", database_url);
    }

    let pool = SqlitePoolOptions::new()
        .connect_with(connect_options(database_url)?)
        .await?;

    // Run migrations
    sqlx::migrate!("./migrations").run(&pool).await?;

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
        // FULL is SQLite's default and means an fsync per commit on top of the
        // one WAL already does. Under WAL, NORMAL risks losing the most recent
        // transactions to a power failure and cannot corrupt the database —
        // the right trade for a sampler whose next row is seconds away.
        .synchronous(SqliteSynchronous::Normal)
        // Only ever takes effect on a database that is still empty, so this
        // sets the behaviour for new installs; an existing file reports NONE
        // until the one full VACUUM in `cleanup` converts it.
        .auto_vacuum(SqliteAutoVacuum::Incremental)
        .pragma(
            "wal_autocheckpoint",
            WAL_AUTOCHECKPOINT_PAGES.to_string(),
        )
        .busy_timeout(Duration::from_secs(30)))
}
