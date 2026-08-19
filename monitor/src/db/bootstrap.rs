//! First-start bootstrap: create the initial admin with a random password when the users table is empty

use crate::utils::error::{MonitorError, Result};
use crate::utils::secrets::random_password;
use sqlx::SqlitePool;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use tracing::info;

pub const INITIAL_ADMIN: &str = "admin";
pub const INITIAL_CREDENTIALS_FILE: &str = "initial-admin-credentials.txt";

fn initial_credentials_path(database_url: &str) -> PathBuf {
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
            "Initial credentials file {} already exists while the users table is empty; move or remove the stale file after confirming it is no longer needed, then restart",
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
    writeln!(file, "Initial ServerBox Monitor credentials")?;
    writeln!(file, "username: {INITIAL_ADMIN}")?;
    writeln!(file, "password: {password}")?;
    writeln!(
        file,
        "Change the password, then securely delete this file."
    )?;
    file.sync_all()?;
    Ok(())
}

pub async fn ensure_admin_user(pool: &SqlitePool, database_url: &str) -> Result<()> {
    let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users")
        .fetch_one(pool)
        .await?;
    if count > 0 {
        return Ok(());
    }

    let credentials_path = initial_credentials_path(database_url);
    let password = random_password(24)?;
    let hash = crate::api::auth::hash_password(&password)?;
    write_initial_credentials(&credentials_path, &password)?;
    let inserted = sqlx::query("INSERT INTO users (username, password_hash) VALUES (?, ?)")
        .bind(INITIAL_ADMIN)
        .bind(hash)
        .execute(pool)
        .await;
    if let Err(error) = inserted {
        let _ = std::fs::remove_file(&credentials_path);
        return Err(error.into());
    }

    info!(
        "No users found; created initial admin user. Credentials were written to {} with owner-only permissions on Unix and inherited directory ACLs on Windows; change the password and remove the file.",
        credentials_path.display()
    );
    Ok(())
}

/// Set/reset a user's password; creates the user if absent
pub async fn set_password(pool: &SqlitePool, username: &str, password: &str) -> Result<()> {
    let hash = crate::api::auth::hash_password(password)?;
    sqlx::query(
        "INSERT INTO users (username, password_hash) VALUES (?, ?)
         ON CONFLICT(username) DO UPDATE SET password_hash = excluded.password_hash",
    )
    .bind(username)
    .bind(hash)
    .execute(pool)
    .await?;
    Ok(())
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

        ensure_admin_user(&pool, &database_url).await.unwrap();

        assert!(dir.path().join(INITIAL_CREDENTIALS_FILE).is_file());
    }

    #[tokio::test]
    async fn stale_credentials_file_has_an_actionable_error() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join(INITIAL_CREDENTIALS_FILE);
        std::fs::write(&path, "stale").unwrap();
        let database_url = format!("sqlite:{}", dir.path().join("data.db").display());
        let pool = pool().await;

        let error = ensure_admin_user(&pool, &database_url).await.unwrap_err();

        let message = error.to_string();
        assert!(message.contains("already exists"));
        assert!(message.contains(&path.display().to_string()));
    }
}
