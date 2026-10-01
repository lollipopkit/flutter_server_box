//! First-start bootstrap: decide what the built-in roles grant, and create the
//! initial admin with a random password when the users table is empty.

use crate::core::config::Config;
use crate::core::remote_access::RemoteAccessConfig;
use crate::core::permissions::{ADMIN_ROLE, Grants, InitPermissions, VIEWER_ROLE};
use crate::utils::error::{MonitorError, Result};
use crate::utils::secrets::random_password;
use sqlx::SqlitePool;
use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use tracing::info;

pub const INITIAL_ADMIN: &str = "admin";
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

/// Decides what the built-in roles grant, the first time an agent with roles
/// starts on this database — migration 010 creates them with `grants` NULL.
///
/// - **Fresh install** (no account yet): `admin` holds [`init`]'s grants —
///   everything, or nothing for an installer run with `--permissions read`.
///   The admin can still administer the agent either way, and turns grants on
///   from the app or the panel.
/// - **Upgrade** (accounts exist; migration 010 made each of them an admin):
///   `admin` holds what the old `config.toml` switches *effectively* gave every
///   login — [`Grants::from_legacy`] — so nobody's access changes by upgrading.
///
/// `viewer` holds nothing either way. Run before [`ensure_admin_user`], whose
/// account is what would otherwise make a fresh install look like an upgrade.
pub async fn ensure_roles(pool: &SqlitePool, config: &Config, init: InitPermissions) -> Result<()> {
    let remote = config.get_remote_access();
    let unresolved: i64 =
        sqlx::query_scalar("SELECT count(*) FROM roles WHERE builtin = 1 AND grants IS NULL")
            .fetch_one(pool)
            .await?;
    if unresolved > 0 {
        let accounts: i64 = sqlx::query_scalar("SELECT count(*) FROM users")
            .fetch_one(pool)
            .await?;
        let admin = if accounts == 0 {
            if remote.legacy_present(RemoteAccessConfig::legacy_env()) {
                // A configuration written for the model before roles, on a
                // new database — a mounted config over a fresh volume, a
                // declarative deployment. What it said it allowed is a
                // ceiling the installer's choice cannot raise.
                let grants = init.grants().intersect(&remote.legacy_grants());
                info!(
                    "Fresh install with a config.toml written before roles: the admin role \
                     starts with {init} permissions, limited to what its old switches \
                     allowed — {}",
                    serde_json::to_string(&grants)?
                );
                grants
            } else {
                info!("Fresh install: the admin role starts with {init} permissions");
                init.grants()
            }
        } else {
            let grants = remote.legacy_grants();
            info!(
                "Permissions moved from config.toml to roles: every existing account is now an \
                 admin, and the admin role holds what the old switches gave — {}",
                serde_json::to_string(&grants)?
            );
            grants
        };
        for (name, grants) in [(ADMIN_ROLE, admin), (VIEWER_ROLE, Grants::none())] {
            sqlx::query("UPDATE roles SET grants = ? WHERE name = ? AND grants IS NULL")
                .bind(serde_json::to_string(&grants)?)
                .bind(name)
                .execute(pool)
                .await?;
        }
    }

    let legacy = remote.legacy_keys_set();
    if !legacy.is_empty() {
        info!(
            "{} no longer read: who may do what is each account's role now, edited from \
             the app or the panel. Safe to delete from config.toml.",
            legacy.join(", ")
        );
    }
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
    let inserted = sqlx::query("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)")
        .bind(INITIAL_ADMIN)
        .bind(hash)
        .bind(ADMIN_ROLE)
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

/// Set/reset a user's password; creates the user if absent.
///
/// [role] is given to the account when set. A new account without one is a
/// `viewer` — the CLI is how an operator with a shell recovers an account,
/// not a way to hand out more than they ask for by accident — unless there
/// is no admin at all, which is a database nobody could administer: then it
/// is the admin. Answers which of these happened, for the CLI to say so.
///
/// A reset ends what the old password had paid for, as one through the API
/// does — see [`crate::db::accounts::set_password_hash`].
pub async fn set_password(
    pool: &SqlitePool,
    username: &str,
    password: &str,
    role: Option<&str>,
) -> Result<PasswordSet> {
    if let Some(role) = role
        && crate::db::accounts::role(pool, role).await?.is_none()
    {
        return Err(MonitorError::Parse(format!("No such role: {role}")));
    }
    let hash = crate::api::auth::hash_password(password)?;
    let exists = crate::db::accounts::account(pool, username).await?.is_some();
    if exists {
        // The role first, through the same last-admin guard as the API: a
        // refused move must not leave the password changed behind it.
        if let Some(role) = role {
            match crate::db::accounts::set_role_keeping_an_admin(pool, username, role).await? {
                crate::db::accounts::Guarded::LastAdmin => {
                    return Err(MonitorError::Parse(format!(
                        "{username} is the last admin account; make another account an admin first"
                    )));
                }
                crate::db::accounts::Guarded::Done | crate::db::accounts::Guarded::NotFound => {}
            }
        }
        crate::db::accounts::set_password_hash(pool, username, &hash).await?;
        return Ok(PasswordSet::Reset);
    }
    let first_admin = role.is_none() && crate::db::accounts::admin_count(pool).await? == 0;
    let role = role.unwrap_or(if first_admin { ADMIN_ROLE } else { VIEWER_ROLE });
    crate::db::accounts::insert_account(pool, username, &hash, role).await?;
    Ok(PasswordSet::Created { first_admin })
}

/// What [`set_password`] did.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PasswordSet {
    /// A new account; [first_admin] when it became the admin because there
    /// was none.
    Created { first_admin: bool },
    /// An existing account's password, ending what the old one paid for.
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
