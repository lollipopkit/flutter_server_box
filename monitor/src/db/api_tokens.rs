//! Rows in `api_tokens` (issue #1681).
//!
//! The plaintext is `sbt_` plus 64 hex and is shown once. What is stored is
//! the SHA-256 of that string, same shape as `watch_tokens`. Scopes are a
//! JSON array of grant names; `admin` is refused on the way in.

use sha2::{Digest, Sha256};
use sqlx::SqlitePool;

use crate::core::permissions::{FilesGrant, Grants};
use crate::utils::error::Result;

/// Default lifetime, matching the issue and the watch-token TTL.
pub const DEFAULT_TTL_DAYS: i64 = 90;
/// A token that never expires is a credential that cannot be forgotten.
pub const MAX_TTL_DAYS: i64 = 365;

/// `sbt_` plus 64 lowercase hex — 32 random bytes.
pub const PREFIX: &str = "sbt_";

#[derive(Debug, Clone)]
pub struct ApiToken {
    pub id: String,
    pub subject: String,
    pub name: String,
    pub scopes: Vec<String>,
    pub created_at: i64,
    pub expires_at: i64,
    pub last_used_at: Option<i64>,
    pub last_used_ip: Option<String>,
}

pub fn hash(token: &str) -> String {
    hex::encode(Sha256::digest(token.as_bytes()))
}

/// Whether [raw] is this kind of credential, before hashing it.
pub fn looks_like(raw: &str) -> bool {
    let rest = match raw.strip_prefix(PREFIX) {
        Some(rest) => rest,
        None => return false,
    };
    rest.len() == 64 && rest.bytes().all(|b| b.is_ascii_hexdigit())
}

/// Grant names a token may carry. `read` is always held and need not be
/// stored. `admin` is never one of them.
pub fn parse_scopes(names: &[String], role: &Grants) -> std::result::Result<Grants, String> {
    let mut asked = Grants::none();
    for name in names {
        match name.as_str() {
            "read" => {}
            "admin" => {
                return Err("admin is never granted to a token".into());
            }
            "shell" => asked.shell = true,
            "ssh_terminal" => asked.ssh_terminal = true,
            "files" => {
                asked.files = role.files.clone().or(Some(FilesGrant {
                    mode: crate::core::permissions::FilesMode::Read,
                }));
            }
            "connect" => {
                asked.connect = role.connect.clone().or(Some(Default::default()));
            }
            "listen" => {
                asked.listen = role.listen.clone().or(Some(Default::default()));
            }
            "virt" => asked.virt = true,
            other => {
                return Err(format!("unknown scope {other:?}"));
            }
        }
    }
    Ok(asked.intersect(role))
}

/// The names a token was minted with, for the listing. Not the effective
/// grants — those depend on the role at the moment of use.
pub fn scope_names_json(names: &[String]) -> Result<String> {
    Ok(serde_json::to_string(names)?)
}

pub fn scope_names_from_json(raw: &str) -> Result<Vec<String>> {
    Ok(serde_json::from_str(raw)?)
}

type TokenRow = (
    String,
    String,
    String,
    String,
    i64,
    i64,
    Option<i64>,
    Option<String>,
);

#[allow(clippy::too_many_arguments)]
pub async fn insert(
    pool: &SqlitePool,
    id: &str,
    subject: &str,
    name: &str,
    token_hash: &str,
    scopes: &str,
    created_at: i64,
    expires_at: i64,
) -> Result<()> {
    sqlx::query(
        "INSERT INTO api_tokens \
         (id, subject, name, token_hash, scopes, created_at, expires_at) \
         VALUES (?, ?, ?, ?, ?, ?, ?)",
    )
    .bind(id)
    .bind(subject)
    .bind(name)
    .bind(token_hash)
    .bind(scopes)
    .bind(created_at)
    .bind(expires_at)
    .execute(pool)
    .await?;
    Ok(())
}

fn token_from_row(
    (id, subject, name, scopes, created_at, expires_at, last_used_at, last_used_ip): TokenRow,
) -> Result<ApiToken> {
    Ok(ApiToken {
        id,
        subject,
        name,
        scopes: scope_names_from_json(&scopes)?,
        created_at,
        expires_at,
        last_used_at,
        last_used_ip,
    })
}

pub async fn list_for(pool: &SqlitePool, subject: &str) -> Result<Vec<ApiToken>> {
    let rows: Vec<TokenRow> = sqlx::query_as(
        "SELECT id, subject, name, scopes, created_at, expires_at, last_used_at, last_used_ip \
         FROM api_tokens WHERE subject = ? ORDER BY created_at DESC",
    )
    .bind(subject)
    .fetch_all(pool)
    .await?;
    let mut out = Vec::with_capacity(rows.len());
    for row in rows {
        out.push(token_from_row(row)?);
    }
    Ok(out)
}

pub async fn list_all(pool: &SqlitePool) -> Result<Vec<ApiToken>> {
    let rows: Vec<TokenRow> = sqlx::query_as(
        "SELECT id, subject, name, scopes, created_at, expires_at, last_used_at, last_used_ip \
         FROM api_tokens ORDER BY subject, created_at DESC",
    )
    .fetch_all(pool)
    .await?;
    let mut out = Vec::with_capacity(rows.len());
    for row in rows {
        out.push(token_from_row(row)?);
    }
    Ok(out)
}

pub async fn get(pool: &SqlitePool, id: &str) -> Result<Option<ApiToken>> {
    let row: Option<TokenRow> = sqlx::query_as(
        "SELECT id, subject, name, scopes, created_at, expires_at, last_used_at, last_used_ip \
         FROM api_tokens WHERE id = ?",
    )
    .bind(id)
    .fetch_optional(pool)
    .await?;
    match row {
        Some(row) => Ok(Some(token_from_row(row)?)),
        None => Ok(None),
    }
}

/// The live token whose hash is [token_hash], if it has not expired.
pub async fn find_live(
    pool: &SqlitePool,
    token_hash: &str,
    now: i64,
) -> Result<Option<ApiToken>> {
    let row: Option<TokenRow> = sqlx::query_as(
        "SELECT id, subject, name, scopes, created_at, expires_at, last_used_at, last_used_ip \
         FROM api_tokens WHERE token_hash = ? AND expires_at > ?",
    )
    .bind(token_hash)
    .bind(now)
    .fetch_optional(pool)
    .await?;
    match row {
        Some(row) => Ok(Some(token_from_row(row)?)),
        None => Ok(None),
    }
}

pub async fn touch(pool: &SqlitePool, id: &str, now: i64, ip: Option<&str>) -> Result<()> {
    sqlx::query("UPDATE api_tokens SET last_used_at = ?, last_used_ip = ? WHERE id = ?")
        .bind(now)
        .bind(ip)
        .bind(id)
        .execute(pool)
        .await?;
    Ok(())
}

pub async fn delete(pool: &SqlitePool, id: &str) -> Result<bool> {
    let done = sqlx::query("DELETE FROM api_tokens WHERE id = ?")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(done.rows_affected() > 0)
}

pub async fn delete_for(pool: &SqlitePool, subject: &str) -> Result<()> {
    sqlx::query("DELETE FROM api_tokens WHERE subject = ?")
        .bind(subject)
        .execute(pool)
        .await?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::permissions::{FilesMode, Grants};

    #[test]
    fn looks_like_is_the_prefix_and_64_hex() {
        assert!(looks_like(&format!(
            "{PREFIX}{}",
            "ab".repeat(32)
        )));
        assert!(!looks_like("sbw_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
        assert!(!looks_like(&format!("{PREFIX}{}", "ab".repeat(31))));
        assert!(!looks_like(&format!("{PREFIX}{}", "zz".repeat(32))));
    }

    #[test]
    fn parse_scopes_refuses_admin_and_unknown_and_intersects() {
        let role = Grants::all();
        assert!(parse_scopes(&["admin".into()], &role).unwrap_err().contains("admin"));
        assert!(parse_scopes(&["nope".into()], &role).unwrap_err().contains("unknown"));
        let none = parse_scopes(&[], &role).unwrap();
        assert_eq!(none, Grants::none());
        let files = parse_scopes(&["files".into()], &role).unwrap();
        assert_eq!(files.files.as_ref().unwrap().mode, FilesMode::Write);
        assert!(!files.shell);
        let viewer = Grants::none();
        let asked = parse_scopes(&["shell".into()], &viewer).unwrap();
        assert!(!asked.shell);
    }
}
