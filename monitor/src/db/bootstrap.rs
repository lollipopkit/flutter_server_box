//! First start: the agent's account, with a random password.

use crate::utils::error::{MonitorError, Result};
use crate::utils::secrets::random_password;
use sqlx::SqlitePool;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use tracing::info;

pub const INITIAL_CREDENTIALS_FILE: &str = "initial-admin-credentials.txt";

pub fn initial_credentials_path(database_url: &str) -> PathBuf {
    let db_path = database_url
        .trim_start_matches("sqlite://")
        .trim_start_matches("sqlite:")
        .split('?')
        .next()
        .unwrap_or_default();
    let dir = Path::new(db_path)
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    dir.join(INITIAL_CREDENTIALS_FILE)
}

fn write_initial_credentials(path: &Path, password: &str) -> Result<()> {
    if path.exists() {
        return Err(MonitorError::Config(anyhow::anyhow!(
            "Initial credentials file {} already exists while the agent has no password yet; move or remove the stale file after confirming it is no longer needed, then restart",
            path.display()
        )));
    }
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let mut file = options.open(path).map_err(|error| {
        MonitorError::Config(anyhow::anyhow!(
            "Failed to securely create initial credentials file {}: {error}. On Windows, verify that the database directory ACL permits this account to create files and does not grant unintended access",
            path.display()
        ))
    })?;
    writeln!(file, "Initial ServerBox Monitor password")?;
    writeln!(file, "password: {password}")?;
    writeln!(
        file,
        "Change the password, then securely delete this file."
    )?;
    file.sync_all()?;
    Ok(())
}

/// Creates the account with a random password on a database that has none,
/// and writes the password next to the database for whoever installed the
/// agent to read once.
pub async fn ensure_owner(pool: &SqlitePool, database_url: &str) -> Result<()> {
    if crate::db::accounts::owner(pool).await?.is_some() {
        return Ok(());
    }

    let credentials_path = initial_credentials_path(database_url);
    let password = random_password(24)?;
    let hash = crate::api::auth::hash_password(&password)?;
    write_initial_credentials(&credentials_path, &password)?;
    match crate::db::accounts::insert_owner(pool, &hash).await {
        Ok(true) => {}
        // Another process set a password first; this one would not sign in.
        Ok(false) => {
            let _ = std::fs::remove_file(&credentials_path);
            return Ok(());
        }
        Err(error) => {
            let _ = std::fs::remove_file(&credentials_path);
            return Err(error);
        }
    }

    info!(
        "Created the agent's password. It was written to {} with owner-only permissions on Unix and inherited directory ACLs on Windows; sign in, change it, and remove the file.",
        credentials_path.display()
    );
    Ok(())
}

/// Sets the password, creating the account on a database that has none.
///
/// A reset ends what the old password had paid for, as one through the API
/// does — see [`crate::db::accounts::set_password_hash`].
pub async fn set_password(pool: &SqlitePool, password: &str) -> Result<PasswordSet> {
    let hash = crate::api::auth::hash_password(password)?;
    if crate::db::accounts::owner(pool).await?.is_some() {
        crate::db::accounts::set_password_hash(pool, &hash).await?;
        return Ok(PasswordSet::Reset);
    }
    if crate::db::accounts::insert_owner(pool, &hash).await? {
        return Ok(PasswordSet::Created);
    }
    // Created by another process since: replace it, as asked.
    crate::db::accounts::set_password_hash(pool, &hash).await?;
    Ok(PasswordSet::Reset)
}

/// What [`set_password`] did.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PasswordSet {
    Created,
    /// Replaced, ending what the old one paid for.
    Reset,
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn pool() -> SqlitePool {
        let pool = SqlitePool::connect("sqlite::memory:").await.unwrap();
        sqlx::migrate!("./migrations").run(&pool).await.unwrap();
        pool
    }

    #[tokio::test]
    async fn credentials_are_written_next_to_the_database() {
        let dir = tempfile::tempdir().unwrap();
        let database_url = format!("sqlite:{}", dir.path().join("data.db").display());
        let pool = pool().await;

        ensure_owner(&pool, &database_url).await.unwrap();

        assert!(dir.path().join(INITIAL_CREDENTIALS_FILE).is_file());
    }

    #[tokio::test]
    async fn stale_credentials_file_has_an_actionable_error() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join(INITIAL_CREDENTIALS_FILE);
        std::fs::write(&path, "stale").unwrap();
        let database_url = format!("sqlite:{}", dir.path().join("data.db").display());
        let pool = pool().await;

        let error = ensure_owner(&pool, &database_url).await.unwrap_err();

        let message = error.to_string();
        assert!(message.contains("already exists"));
        assert!(message.contains(&path.display().to_string()));
    }
}
