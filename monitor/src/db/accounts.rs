//! Accounts and roles, as stored: `users` and `roles` (migration 010).
//!
//! Plain queries and nothing else. What may be changed, by whom, and what
//! has to be true afterwards — at least one admin, a built-in role kept —
//! is `api::admin`'s; this is only how it is read and written.

use sqlx::{Row, SqlitePool};

use crate::core::permissions::{ADMIN_ROLE, Grants, Role};
use crate::utils::error::Result;

/// A row of `roles`, decoded.
///
/// A `grants` column that is NULL (a built-in role not resolved yet) or does
/// not parse reads as nothing granted: a role whose grants cannot be read
/// must fail closed, not open.
fn role_from_row(row: &sqlx::sqlite::SqliteRow) -> Role {
    let name: String = row.get("name");
    let grants = match row.get::<Option<String>, _>("grants") {
        None => Grants::none(),
        Some(json) => serde_json::from_str(&json).unwrap_or_else(|e| {
            tracing::warn!("Role {name:?} has grants that do not parse ({e}); treating it as holding none");
            Grants::none()
        }),
    };
    Role {
        name,
        admin: row.get::<i64, _>("admin") != 0,
        builtin: row.get::<i64, _>("builtin") != 0,
        grants,
    }
}

fn now() -> String {
    chrono::Utc::now().to_rfc3339()
}

/// Built-ins first, then by name.
pub async fn roles(pool: &SqlitePool) -> Result<Vec<Role>> {
    let rows = sqlx::query(
        "SELECT name, admin, builtin, grants FROM roles ORDER BY builtin DESC, name",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows.iter().map(role_from_row).collect())
}

pub async fn role(pool: &SqlitePool, name: &str) -> Result<Option<Role>> {
    let row = sqlx::query("SELECT name, admin, builtin, grants FROM roles WHERE name = ?")
        .bind(name)
        .fetch_optional(pool)
        .await?;
    Ok(row.as_ref().map(role_from_row))
}

/// Creates a role. The caller has validated it and checked the name is free.
pub async fn insert_role(pool: &SqlitePool, role: &Role) -> Result<()> {
    let now = now();
    sqlx::query(
        "INSERT INTO roles (name, admin, builtin, grants, created_at, updated_at) \
         VALUES (?, ?, 0, ?, ?, ?)",
    )
    .bind(&role.name)
    .bind(role.admin)
    .bind(serde_json::to_string(&role.grants)?)
    .bind(&now)
    .bind(&now)
    .execute(pool)
    .await?;
    Ok(())
}

/// Replaces what [name] grants. Its name, `admin` and `builtin` never change.
pub async fn set_grants(pool: &SqlitePool, name: &str, grants: &Grants) -> Result<bool> {
    let done = sqlx::query("UPDATE roles SET grants = ?, updated_at = ? WHERE name = ?")
        .bind(serde_json::to_string(grants)?)
        .bind(now())
        .bind(name)
        .execute(pool)
        .await?;
    Ok(done.rows_affected() > 0)
}

pub async fn delete_role(pool: &SqlitePool, name: &str) -> Result<bool> {
    let done = sqlx::query("DELETE FROM roles WHERE name = ? AND builtin = 0")
        .bind(name)
        .execute(pool)
        .await?;
    Ok(done.rows_affected() > 0)
}

/// How many accounts hold [role].
pub async fn role_holders(pool: &SqlitePool, role: &str) -> Result<i64> {
    Ok(sqlx::query_scalar("SELECT count(*) FROM users WHERE role = ?")
        .bind(role)
        .fetch_one(pool)
        .await?)
}

/// An account and the role it holds, or `None` for no such account.
pub async fn account(pool: &SqlitePool, username: &str) -> Result<Option<(String, Role)>> {
    Ok(account_since(pool, username)
        .await?
        .map(|(name, role, _)| (name, role)))
}

/// [`account`], with when its password was last set (Unix milliseconds) —
/// what a token or a connection opened before then no longer counts against.
pub async fn account_since(
    pool: &SqlitePool,
    username: &str,
) -> Result<Option<(String, Role, i64)>> {
    let row = sqlx::query(
        "SELECT u.username AS username, u.password_changed_ms AS since, \
         r.name AS name, r.admin AS admin, r.builtin AS builtin, r.grants AS grants \
         FROM users u JOIN roles r ON r.name = u.role WHERE u.username = ?",
    )
    .bind(username)
    .fetch_optional(pool)
    .await?;
    Ok(row.map(|row| (row.get("username"), role_from_row(&row), row.get("since"))))
}

/// One account as `GET /users` lists it.
#[derive(Debug, Clone, serde::Serialize)]
pub struct AccountView {
    pub username: String,
    pub role: String,
    /// RFC 3339, or null.
    pub created_at: Option<String>,
    pub last_login: Option<String>,
}

/// `users.created_at` and `last_login` are SQLite's `CURRENT_TIMESTAMP`
/// (`2026-10-01 08:00:00`, UTC); the API speaks RFC 3339.
fn rfc3339(raw: Option<String>) -> Option<String> {
    let raw = raw?;
    if let Ok(parsed) = chrono::NaiveDateTime::parse_from_str(&raw, "%Y-%m-%d %H:%M:%S") {
        return Some(parsed.and_utc().to_rfc3339());
    }
    chrono::DateTime::parse_from_rfc3339(&raw)
        .ok()
        .map(|t| t.to_rfc3339())
}

fn account_view(row: &sqlx::sqlite::SqliteRow) -> AccountView {
    AccountView {
        username: row.get("username"),
        role: row.get("role"),
        created_at: rfc3339(row.get("created_at")),
        last_login: rfc3339(row.get("last_login")),
    }
}

pub async fn accounts(pool: &SqlitePool) -> Result<Vec<AccountView>> {
    let rows = sqlx::query(
        "SELECT username, role, CAST(created_at AS TEXT) AS created_at, \
         CAST(last_login AS TEXT) AS last_login FROM users ORDER BY username",
    )
    .fetch_all(pool)
    .await?;
    Ok(rows.iter().map(account_view).collect())
}

pub async fn account_view_of(pool: &SqlitePool, username: &str) -> Result<Option<AccountView>> {
    let row = sqlx::query(
        "SELECT username, role, CAST(created_at AS TEXT) AS created_at, \
         CAST(last_login AS TEXT) AS last_login FROM users WHERE username = ?",
    )
    .bind(username)
    .fetch_optional(pool)
    .await?;
    Ok(row.as_ref().map(account_view))
}

pub async fn password_hash(pool: &SqlitePool, username: &str) -> Result<Option<String>> {
    Ok(
        sqlx::query_scalar("SELECT password_hash FROM users WHERE username = ?")
            .bind(username)
            .fetch_optional(pool)
            .await?,
    )
}

/// Creates an account. Fails on a name that is taken (the UNIQUE index).
pub async fn insert_account(
    pool: &SqlitePool,
    username: &str,
    password_hash: &str,
    role: &str,
) -> Result<()> {
    sqlx::query("INSERT INTO users (username, password_hash, role) VALUES (?, ?, ?)")
        .bind(username)
        .bind(password_hash)
        .bind(role)
        .execute(pool)
        .await?;
    Ok(())
}

/// Sets a new password, and ends what the old one had paid for: panel
/// tokens issued before now stop counting (`password_changed_ms`), and the
/// watch tokens the account paired are deleted — a password is reset because
/// somebody else may have it, and they may have paired a token too.
///
/// The connections already running are the caller's to end — see
/// `api::authz::end_account`; a process that is not the running agent (the
/// CLI) cannot reach them, and they end on the agent's next role change.
pub async fn set_password_hash(pool: &SqlitePool, username: &str, hash: &str) -> Result<()> {
    let mut tx = pool.begin().await?;
    sqlx::query(
        // Strictly later than before, even within one millisecond: a change
        // is what ends the connections opened under the old value, and one
        // that left it where it was would end nothing.
        "UPDATE users SET password_hash = ?, password_changed_ms = \
         max(CAST((julianday('now') - 2440587.5) * 86400000 AS INTEGER), \
             password_changed_ms + 1) \
         WHERE username = ?",
    )
    .bind(hash)
    .bind(username)
    .execute(&mut *tx)
    .await?;
    sqlx::query("DELETE FROM watch_tokens WHERE subject = ?")
        .bind(username)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    Ok(())
}

/// What a change that must leave an admin behind did.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Guarded {
    Done,
    NotFound,
    /// Refused: it would have left no account in the admin role.
    LastAdmin,
}

/// The condition that keeps one admin, as part of the statement that writes:
/// checked and applied in one step, so two requests each removing one of the
/// last two admins cannot both see two. SQLite runs a write statement under
/// its write lock, subquery included.
///
/// A macro so the statements stay `&'static str`: SQL is never built at
/// runtime here.
macro_rules! keeps_an_admin {
    () => {
        "(role <> 'admin' OR (SELECT count(*) FROM users WHERE role = 'admin') > 1)"
    };
}

/// What a guarded write that touched no row means: no such account, or the
/// guard refused it.
async fn unguarded(pool: &SqlitePool, username: &str) -> Result<Guarded> {
    Ok(if account(pool, username).await?.is_some() {
        Guarded::LastAdmin
    } else {
        Guarded::NotFound
    })
}

/// Moves [username] to [role], unless that would leave no admin.
pub async fn set_role_keeping_an_admin(
    pool: &SqlitePool,
    username: &str,
    role: &str,
) -> Result<Guarded> {
    let done = sqlx::query(concat!(
        "UPDATE users SET role = ? WHERE username = ? AND (? = 'admin' OR ",
        keeps_an_admin!(),
        ")"
    ))
    .bind(role)
    .bind(username)
    .bind(role)
    .execute(pool)
    .await?;
    if done.rows_affected() > 0 {
        Ok(Guarded::Done)
    } else {
        unguarded(pool, username).await
    }
}

/// Removes the account and every watch token it paired — a token is the
/// account's, and must not outlive it as a way to keep reading — unless it is
/// the last admin.
pub async fn delete_account(pool: &SqlitePool, username: &str) -> Result<Guarded> {
    let mut tx = pool.begin().await?;
    let done = sqlx::query(concat!(
        "DELETE FROM users WHERE username = ? AND ",
        keeps_an_admin!()
    ))
    .bind(username)
    .execute(&mut *tx)
    .await?;
    if done.rows_affected() == 0 {
        tx.rollback().await?;
        return unguarded(pool, username).await;
    }
    sqlx::query("DELETE FROM watch_tokens WHERE subject = ?")
        .bind(username)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;
    Ok(Guarded::Done)
}

/// How many accounts hold the admin role.
pub async fn admin_count(pool: &SqlitePool) -> Result<i64> {
    role_holders(pool, ADMIN_ROLE).await
}
