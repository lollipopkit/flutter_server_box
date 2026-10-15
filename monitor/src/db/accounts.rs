//! The agent's one account, as stored: the single row of `users`
//! (migration 032).
//!
//! Plain queries and nothing else.

use sqlx::{Row, SqlitePool};

use crate::utils::error::Result;

/// The account: its password hash, and when the password was last set (Unix
/// milliseconds) — what a token or a connection opened before then no longer
/// counts against. `id` is what the account's rows (desk, tasks) are keyed by.
#[derive(Debug, Clone)]
pub struct Owner {
    pub id: i64,
    pub password_hash: String,
    pub since: i64,
}

/// The account, or `None` before the first start made it.
pub async fn owner(pool: &SqlitePool) -> Result<Option<Owner>> {
    let row = sqlx::query(
        "SELECT id, password_hash, password_changed_ms FROM users ORDER BY id LIMIT 1",
    )
    .fetch_optional(pool)
    .await?;
    Ok(row.map(|row| Owner {
        id: row.get("id"),
        password_hash: row.get("password_hash"),
        since: row.get("password_changed_ms"),
    }))
}

/// Creates the account. Only on a database that has none.
/// Whether the account was created: false when one already existed, which
/// another process may have made since the caller looked.
pub async fn insert_owner(pool: &SqlitePool, password_hash: &str) -> Result<bool> {
    let done = sqlx::query("INSERT INTO users (password_hash) SELECT ? WHERE NOT EXISTS (SELECT 1 FROM users)")
        .bind(password_hash)
        .execute(pool)
        .await?;
    Ok(done.rows_affected() == 1)
}

pub async fn record_login(pool: &SqlitePool, id: i64) -> Result<()> {
    sqlx::query("UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = ?")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}

/// Sets a new password, and ends what the old one had paid for: panel
/// tokens issued before now stop counting (`password_changed_ms`), and every
/// paired watch token is deleted — a password is reset because somebody else
/// may have it, and they may have paired a token too.
///
/// The connections already running are the caller's to end — see
/// `api::authz::end_account`; a process that is not the running agent (the
/// CLI) cannot reach them.
pub async fn set_password_hash(pool: &SqlitePool, hash: &str) -> Result<()> {
    let mut tx = pool.begin().await?;
    sqlx::query(
        // Strictly later than before, even within one millisecond: a change
        // is what ends the connections opened under the old value, and one
        // that left it where it was would end nothing.
        "UPDATE users SET password_hash = ?, password_changed_ms = \
         max(CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER), \
             password_changed_ms + 1)",
    )
    .bind(hash)
    .execute(&mut *tx)
    .await?;
    sqlx::query("DELETE FROM watch_tokens")
        .execute(&mut *tx)
        .await?;
    sqlx::query("DELETE FROM login_device")
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    Ok(())
}

/// How long a device that signed in stays known without signing in again.
pub const DEVICE_TTL_SECS: i64 = 180 * 24 * 3600;

/// The most devices kept; the least recently used go first.
pub const MAX_DEVICES: i64 = 64;

/// Whether [token_hash] names a device that signed in within
/// [`DEVICE_TTL_SECS`] of [now].
pub async fn device_known(pool: &SqlitePool, token_hash: &str, now: i64) -> Result<bool> {
    let found = sqlx::query_scalar::<_, i64>("SELECT 1 FROM login_device WHERE token_hash = ? AND last_used > ?")
        .bind(token_hash)
        .bind(now - DEVICE_TTL_SECS)
        .fetch_optional(pool)
        .await?;
    Ok(found.is_some())
}

/// Records a sign-in from [token_hash]: a new device, or one seen again, as
/// [label] from [ip]. Keeps the newest [`MAX_DEVICES`] and drops expired ones.
pub async fn remember_device(
    pool: &SqlitePool,
    token_hash: &str,
    now: i64,
    label: &str,
    ip: Option<&str>,
) -> Result<()> {
    let mut tx = pool.begin().await?;
    sqlx::query(
        "INSERT INTO login_device (token_hash, label, last_ip, created_at, last_used) VALUES (?, ?, ?, ?, ?) \
         ON CONFLICT(token_hash) DO UPDATE SET label = excluded.label, last_ip = excluded.last_ip, last_used = excluded.last_used",
    )
    .bind(token_hash)
    .bind(label)
    .bind(ip)
    .bind(now)
    .bind(now)
    .execute(&mut *tx)
    .await?;
    sqlx::query(
        "DELETE FROM login_device WHERE last_used <= ? OR id NOT IN \
         (SELECT id FROM login_device ORDER BY last_used DESC, id DESC LIMIT ?)",
    )
    .bind(now - DEVICE_TTL_SECS)
    .bind(MAX_DEVICES)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(())
}

/// A device that signed in, as `GET /live` lists it. Never its token.
#[derive(Debug, Clone, serde::Serialize, sqlx::FromRow)]
pub struct LoginDevice {
    pub id: i64,
    pub label: String,
    pub last_ip: Option<String>,
    pub created_at: i64,
    pub last_used: i64,
}

/// The devices still known at [now], most recently used first.
pub async fn devices(pool: &SqlitePool, now: i64) -> Result<Vec<LoginDevice>> {
    Ok(sqlx::query_as::<_, LoginDevice>(
        "SELECT id, label, last_ip, created_at, last_used FROM login_device \
         WHERE last_used > ? ORDER BY last_used DESC, id DESC",
    )
    .bind(now - DEVICE_TTL_SECS)
    .fetch_all(pool)
    .await?)
}

/// Forgets device [id]: its token stops being a known device's, so its next
/// sign-in goes through the account-wide throttle and is handed a new one.
/// `false` when there was none.
pub async fn forget_device(pool: &SqlitePool, id: i64) -> Result<bool> {
    let done = sqlx::query("DELETE FROM login_device WHERE id = ?")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(done.rows_affected() == 1)
}
