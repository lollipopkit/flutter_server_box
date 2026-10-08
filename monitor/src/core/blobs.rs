//! Files the agent keeps for its accounts — custom wallpapers, theme
//! backgrounds, desk app files, hosted backups — stored beside the database,
//! not in it: `<database dir>/blobs/<sha256[..2]>/<sha256>`.
//!
//! The database holds what a file is (its owner, name, type, size) and its
//! SHA-256; the bytes are a file named by that digest, so equal contents are
//! one file, a name in a URL or an ETag is the digest, and the database (and
//! a copy of it) stays the size of what it describes. A backup of an agent is
//! the database *and* this directory.
//!
//! Written once and never changed: a file is written to `tmp/` and renamed
//! into place, so a reader sees all of it or nothing. A file no row names any
//! more is removed by [`Blobs::collect`], which every writer is kept out of
//! while it runs ([`Blobs::writing`]), so a file written and not yet named by
//! its row is never taken for garbage. The directory is the agent's state
//! (`fs_roots::Protected`): the file API never reaches it.

use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

use sha2::{Digest, Sha256};
use sqlx::SqlitePool;
use tokio::sync::{RwLock, RwLockReadGuard};

/// Every digest a row names. A table added with a blob column has to be
/// listed here, or [`Blobs::collect`] removes its files.
const NAMED: &str = "SELECT sha256 FROM desk_wallpaper \
     UNION SELECT sha256 FROM desk_theme_background \
     UNION SELECT sha256 FROM desk_app_file \
     UNION SELECT sha256 FROM backup_file";

pub struct Blobs {
    dir: PathBuf,
    /// Writers share it; [`Blobs::collect`] takes it alone.
    gate: RwLock<()>,
    /// Removed with this value: the directory made for an in-memory database.
    owned: bool,
}

static TEMP: AtomicU64 = AtomicU64::new(0);

impl Blobs {
    /// The directory beside the database file [db].
    pub fn beside(db: &Path) -> Self {
        let dir = db.parent().unwrap_or_else(|| Path::new(".")).join("blobs");
        Self { dir, gate: RwLock::new(()), owned: false }
    }

    /// A directory of its own, removed when this is dropped: for an in-memory
    /// database (tests), whose files go with it.
    pub fn temporary() -> Self {
        let n = TEMP.fetch_add(1, Ordering::Relaxed);
        let dir = std::env::temp_dir().join(format!("sbm-blobs-{}-{n}", std::process::id()));
        Self { dir, gate: RwLock::new(()), owned: true }
    }

    pub fn dir(&self) -> &Path {
        &self.dir
    }

    /// Held from writing a file ([`Blobs::put`]) until the row naming it is
    /// committed.
    pub async fn writing(&self) -> RwLockReadGuard<'_, ()> {
        self.gate.read().await
    }

    /// Stores [bytes] and answers their digest. Call it holding
    /// [`Blobs::writing`] until the row naming the digest is committed.
    pub async fn put(&self, bytes: &[u8]) -> std::io::Result<String> {
        let sha = hex::encode(Sha256::digest(bytes));
        let path = self.path(&sha).expect("a digest is a valid name");
        if tokio::fs::try_exists(&path).await? {
            return Ok(sha);
        }
        let tmp = self.dir.join("tmp");
        create_private_dir(&tmp).await?;
        create_private_dir(path.parent().expect("a blob is in a directory")).await?;
        let n = TEMP.fetch_add(1, Ordering::Relaxed);
        let staged = tmp.join(format!("{sha}.{}.{n}", std::process::id()));
        let written = async {
            let mut options = tokio::fs::OpenOptions::new();
            options.write(true).create_new(true);
            #[cfg(unix)]
            options.mode(0o600);
            let mut file = options.open(&staged).await?;
            tokio::io::AsyncWriteExt::write_all(&mut file, bytes).await?;
            file.sync_all().await?;
            tokio::fs::rename(&staged, &path).await
        }
        .await;
        if written.is_err() {
            let _ = tokio::fs::remove_file(&staged).await;
        }
        written.map(|()| sha)
    }

    /// The file [sha] names, or `None` when there is none (or the name is
    /// not a digest).
    pub async fn read(&self, sha: &str) -> std::io::Result<Option<Vec<u8>>> {
        let Some(path) = self.path(sha) else { return Ok(None) };
        match tokio::fs::read(&path).await {
            Ok(bytes) => Ok(Some(bytes)),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(e) => Err(e),
        }
    }

    /// [`Blobs::read`] from a thread that is not the runtime's.
    pub fn read_blocking(&self, sha: &str) -> std::io::Result<Option<Vec<u8>>> {
        let Some(path) = self.path(sha) else { return Ok(None) };
        match std::fs::read(&path) {
            Ok(bytes) => Ok(Some(bytes)),
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => Ok(None),
            Err(e) => Err(e),
        }
    }

    fn path(&self, sha: &str) -> Option<PathBuf> {
        let digest = sha.len() == 64 && sha.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b));
        digest.then(|| self.dir.join(&sha[..2]).join(sha))
    }

    /// Removes every file no row names, and what an interrupted write left
    /// in `tmp/`. Answers how many files went.
    pub async fn collect(&self, db: &SqlitePool) -> anyhow::Result<usize> {
        let _alone = self.gate.write().await;
        let named: std::collections::HashSet<String> = sqlx::query_scalar(NAMED).fetch_all(db).await?.into_iter().collect();
        let dir = self.dir.clone();
        let removed = tokio::task::spawn_blocking(move || -> std::io::Result<usize> {
            let mut removed = 0;
            let Ok(entries) = std::fs::read_dir(&dir) else { return Ok(0) };
            for entry in entries {
                let entry = entry?;
                if !entry.file_type()?.is_dir() {
                    continue;
                }
                let tmp = entry.file_name() == "tmp";
                for file in std::fs::read_dir(entry.path())? {
                    let file = file?;
                    let name = file.file_name();
                    if tmp || !named.contains(name.to_string_lossy().as_ref()) {
                        std::fs::remove_file(file.path())?;
                        removed += 1;
                    }
                }
            }
            Ok(removed)
        })
        .await??;
        Ok(removed)
    }

    /// [`Blobs::collect`] after a row naming a file was removed or replaced,
    /// without holding up the request that did it.
    pub fn collect_soon(self: &std::sync::Arc<Self>, db: &SqlitePool) {
        let (blobs, db) = (self.clone(), db.clone());
        tokio::spawn(async move {
            if let Err(e) = blobs.collect(&db).await {
                tracing::warn!("blobs: collecting unused files failed: {e:#}");
            }
        });
    }
}

impl Drop for Blobs {
    fn drop(&mut self) {
        if self.owned {
            let _ = std::fs::remove_dir_all(&self.dir);
        }
    }
}

async fn create_private_dir(dir: &Path) -> std::io::Result<()> {
    let mut builder = tokio::fs::DirBuilder::new();
    builder.recursive(true);
    #[cfg(unix)]
    builder.mode(0o700);
    builder.create(dir).await
}

/// Moves the backups an agent before migration 020 kept in the database
/// (`backup_blob`) into files, then drops that table. Run after the
/// migrations; does nothing once the table is gone.
///
/// TODO: remove once no agent from before migration 020 can be upgraded
/// (with a migration dropping `backup_blob` for any that never ran this).
pub async fn move_database_backups(db: &SqlitePool, blobs: &Blobs) -> anyhow::Result<()> {
    let exists: bool = sqlx::query_scalar("SELECT EXISTS (SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'backup_blob')")
        .fetch_one(db)
        .await?;
    if !exists {
        return Ok(());
    }
    let _writing = blobs.writing().await;
    let rows: Vec<(String, Vec<u8>, i64, String)> = sqlx::query_as("SELECT name, data, size, updated_at FROM backup_blob").fetch_all(db).await?;
    let mut named = Vec::with_capacity(rows.len());
    for (name, data, size, updated_at) in rows {
        let sha = blobs.put(&data).await?;
        named.push((name, sha, size, updated_at));
    }
    let mut tx = db.begin().await?;
    for (name, sha, size, updated_at) in &named {
        sqlx::query(
            "INSERT INTO backup_file (name, sha256, size, updated_at) VALUES (?, ?, ?, ?) \
             ON CONFLICT(name) DO UPDATE SET sha256 = excluded.sha256, size = excluded.size, updated_at = excluded.updated_at",
        )
        .bind(name)
        .bind(sha)
        .bind(size)
        .bind(updated_at)
        .execute(&mut *tx)
        .await?;
    }
    sqlx::query("DROP TABLE backup_blob").execute(&mut *tx).await?;
    tx.commit().await?;
    tracing::info!("blobs: moved {} hosted backups out of the database", named.len());
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn db() -> SqlitePool {
        let pool = SqlitePool::connect("sqlite::memory:").await.unwrap();
        for table in ["desk_wallpaper", "desk_theme_background", "desk_app_file", "backup_file"] {
            sqlx::query(sqlx::AssertSqlSafe(format!("CREATE TABLE {table} (sha256 TEXT)"))).execute(&pool).await.unwrap();
        }
        pool
    }

    #[tokio::test]
    async fn a_file_is_its_digest_and_equal_bytes_are_one_file() {
        let blobs = Blobs::temporary();
        let a = blobs.put(b"hello").await.unwrap();
        assert_eq!(a, hex::encode(Sha256::digest(b"hello")));
        assert_eq!(blobs.put(b"hello").await.unwrap(), a);
        assert_eq!(blobs.read(&a).await.unwrap().as_deref(), Some(&b"hello"[..]));
        assert_eq!(blobs.read(&"0".repeat(64)).await.unwrap(), None);
        // Not a digest: never a path.
        assert_eq!(blobs.read("../../etc/passwd").await.unwrap(), None);
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = std::fs::metadata(blobs.path(&a).unwrap()).unwrap().permissions().mode();
            assert_eq!(mode & 0o777, 0o600);
            let mode = std::fs::metadata(blobs.dir().join(&a[..2])).unwrap().permissions().mode();
            assert_eq!(mode & 0o777, 0o700);
        }
    }

    #[tokio::test]
    async fn collecting_keeps_what_a_row_names() {
        let (pool, blobs) = (db().await, Blobs::temporary());
        let kept = blobs.put(b"kept").await.unwrap();
        let gone = blobs.put(b"gone").await.unwrap();
        sqlx::query("INSERT INTO desk_app_file VALUES (?)").bind(&kept).execute(&pool).await.unwrap();
        let tmp = blobs.dir().join("tmp").join("left.over");
        std::fs::write(&tmp, b"x").unwrap();
        assert_eq!(blobs.collect(&pool).await.unwrap(), 2);
        assert!(blobs.read(&kept).await.unwrap().is_some());
        assert!(blobs.read(&gone).await.unwrap().is_none());
        assert!(!tmp.exists());
    }

    #[tokio::test]
    async fn a_temporary_directory_goes_with_its_store() {
        let blobs = Blobs::temporary();
        blobs.put(b"x").await.unwrap();
        let dir = blobs.dir().to_path_buf();
        assert!(dir.exists());
        drop(blobs);
        assert!(!dir.exists());
    }
}
