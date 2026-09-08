//! The connection settings `db::database::init` puts on the pool, and the
//! space reclamation that one of them enables.
//!
//! Both are asserted through a real file rather than `sqlite::memory:`: WAL,
//! `wal_autocheckpoint` and `auto_vacuum` all describe how a database is laid
//! out on disk, and an in-memory one answers about none of it.

use anyhow::Result;
use server_box_monitor::core::config::DataRetentionConfig;
use server_box_monitor::db::cleanup::DataCleanupService;
use server_box_monitor::db::database;
use sqlx::{Row, SqlitePool};

/// A pool over a fresh database file, plus the directory keeping it alive.
async fn fresh_db() -> Result<(SqlitePool, tempfile::TempDir)> {
    let dir = tempfile::tempdir()?;
    let path = dir.path().join("monitor.db");
    let pool = database::init(&format!("sqlite:{}", path.display())).await?;
    Ok((pool, dir))
}

async fn pragma<T>(pool: &SqlitePool, stmt: &'static str) -> Result<T>
where
    T: for<'r> sqlx::Decode<'r, sqlx::Sqlite> + sqlx::Type<sqlx::Sqlite> + Send + Unpin,
{
    Ok(sqlx::query_scalar(stmt).fetch_one(pool).await?)
}

/// `synchronous` and `wal_autocheckpoint` are per-*connection* settings, and a
/// pool opens connections lazily and replaces them over their lifetime. A
/// `PRAGMA` run once against the pool therefore configures whichever single
/// connection answered it and silently leaves the rest on the defaults, which
/// is why these belong in the connect options.
///
/// `wal_autocheckpoint` is the one that can fail here. `synchronous` is
/// asserted because the value is a decision worth stating, but FULL is also
/// what a connection carrying no settings at all reports, so it cannot tell
/// the two apart on its own.
///
/// Held open at the same time on purpose: acquiring them one after another
/// hands back the same connection every time and would pass either way.
#[tokio::test]
async fn every_pooled_connection_carries_the_settings() -> Result<()> {
    let (pool, _dir) = fresh_db().await?;

    let mut held = Vec::new();
    for _ in 0..4 {
        held.push(pool.acquire().await?);
    }

    for (i, conn) in held.iter_mut().enumerate() {
        use sqlx::Executor;
        let row = conn
            .fetch_one("PRAGMA synchronous")
            .await
            .map_err(anyhow::Error::from)?;
        // 2 is FULL, 1 the NORMAL this database deliberately does not use —
        // see the note in `connect_options`.
        assert_eq!(row.get::<i64, _>(0), 2, "connection {i} synchronous");

        let row = conn
            .fetch_one("PRAGMA wal_autocheckpoint")
            .await
            .map_err(anyhow::Error::from)?;
        assert_eq!(
            row.get::<i64, _>(0),
            128,
            "connection {i} wal_autocheckpoint"
        );
    }

    Ok(())
}

/// WAL and INCREMENTAL are properties of the file, so these only answer for a
/// database this code created. An existing one keeps whatever it was made
/// with — which for `auto_vacuum` is the whole reason `reclaim_free_pages`
/// still has a full-VACUUM branch.
#[tokio::test]
async fn a_new_database_is_laid_out_for_incremental_reclaim() -> Result<()> {
    let (pool, _dir) = fresh_db().await?;

    let journal: String = pragma(&pool, "PRAGMA journal_mode").await?;
    assert_eq!(journal.to_lowercase(), "wal");

    // 2 is INCREMENTAL, 0 the NONE every pre-existing database reports.
    let auto_vacuum: i64 = pragma(&pool, "PRAGMA auto_vacuum").await?;
    assert_eq!(auto_vacuum, 2);

    Ok(())
}

/// Retention deletes rows and leaves the pages on the freelist; without this
/// the file only ever grows. Measured on a month-old agent: 20329 of 33331
/// pages free, a 136 MB file holding 53 MB of data, every page of it walked
/// past on a cold read.
#[tokio::test]
async fn reclaim_gives_back_the_pages_a_deletion_freed() -> Result<()> {
    let (pool, _dir) = fresh_db().await?;

    // Padded so each row costs about a page: the reclaim threshold is stated
    // in pages, and 2000 rows of real metrics would not reach it.
    let padding = "x".repeat(4000);
    let mut tx = pool.begin().await?;
    for i in 0..2000 {
        sqlx::query(
            "INSERT INTO system_metrics (timestamp, server_name, cpu_usage) VALUES (?, ?, ?)",
        )
        .bind(chrono::Utc::now())
        .bind(format!("{padding}{i}"))
        .bind(1.0)
        .execute(&mut *tx)
        .await?;
    }
    tx.commit().await?;

    let before: i64 = pragma(&pool, "PRAGMA page_count").await?;
    sqlx::query("DELETE FROM system_metrics").execute(&pool).await?;
    let freed: i64 = pragma(&pool, "PRAGMA freelist_count").await?;
    assert!(
        freed > 1024,
        "fixture freed only {freed} pages, below the reclaim threshold"
    );

    let cleanup = DataCleanupService::new(pool.clone(), DataRetentionConfig::default());
    let reclaimed = cleanup.reclaim_free_pages().await?;
    assert!(reclaimed > 0, "reclaimed nothing from {freed} free pages");

    let after: i64 = pragma(&pool, "PRAGMA page_count").await?;
    assert!(
        after < before / 2,
        "file went from {before} pages to {after} after deleting every row"
    );

    Ok(())
}

/// Below the threshold nothing is rewritten. A cleanup pass runs on a timer
/// whether or not it deleted anything, and rewriting a database because a
/// handful of rows aged out is the cost this guard exists to avoid.
#[tokio::test]
async fn a_small_freelist_is_left_alone() -> Result<()> {
    let (pool, _dir) = fresh_db().await?;

    sqlx::query("INSERT INTO system_metrics (timestamp, server_name, cpu_usage) VALUES (?, ?, ?)")
        .bind(chrono::Utc::now())
        .bind("test")
        .bind(1.0)
        .execute(&pool)
        .await?;
    sqlx::query("DELETE FROM system_metrics").execute(&pool).await?;

    let cleanup = DataCleanupService::new(pool.clone(), DataRetentionConfig::default());
    assert_eq!(cleanup.reclaim_free_pages().await?, 0);

    Ok(())
}
