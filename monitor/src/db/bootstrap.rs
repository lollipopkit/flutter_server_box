//! First-start bootstrap: create the initial admin with a random password when the users table is empty

use crate::utils::error::Result;
use crate::utils::secrets::random_password;
use sqlx::SqlitePool;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::Path;
use tracing::info;

pub const INITIAL_ADMIN: &str = "admin";
pub const INITIAL_CREDENTIALS_FILE: &str = "initial-admin-credentials.txt";

fn write_initial_credentials(password: &str) -> Result<()> {
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let mut file = options.open(INITIAL_CREDENTIALS_FILE)?;
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

pub async fn ensure_admin_user(pool: &SqlitePool) -> Result<()> {
    let count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users")
        .fetch_one(pool)
        .await?;
    if count > 0 {
        return Ok(());
    }

    let password = random_password(24)?;
    let hash = crate::api::auth::hash_password(&password)?;
    write_initial_credentials(&password)?;
    let inserted = sqlx::query("INSERT INTO users (username, password_hash) VALUES (?, ?)")
        .bind(INITIAL_ADMIN)
        .bind(hash)
        .execute(pool)
        .await;
    if let Err(error) = inserted {
        let _ = std::fs::remove_file(Path::new(INITIAL_CREDENTIALS_FILE));
        return Err(error.into());
    }

    info!(
        "No users found; created initial admin user. Credentials were written to {INITIAL_CREDENTIALS_FILE} with owner-only permissions; change the password and remove the file."
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
