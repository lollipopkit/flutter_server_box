//! API tokens (#1681): bearer credentials for MCP clients, as
//! [`crate::db::accounts`] is for the one account's password — plain queries,
//! nothing else. The token itself is never here: a row holds its SHA-256,
//! looked up on every use.

use sqlx::{Row, SqlitePool};

use crate::utils::error::Result;

/// The prefix every API token starts with, so a credential pasted somewhere
/// says what it is — the same idea as `sbw_` on a watch token.
pub const PREFIX: &str = "sbt_";

/// What a token lets its holder do. The fixed set the `scopes` column holds,
/// comma-separated; `read` is every tool that only reads (PR1), the rest come
/// with the tools that need them.
///
/// There is no scope for the account's own administration — creating and
/// revoking these tokens is what the password is for, and a credential that
/// could mint credentials would outlive its own revocation.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Scope {
    /// The machine's readings: status, metrics, capabilities, the tools.
    Read,
    /// Running a command on the machine through the shared exec path.
    Exec,
    /// Acting on the machine: power, processes, services, the rest of
    /// `api::machine`'s surface.
    Machine,
}

impl Scope {
    pub const ALL: &'static [Scope] = &[Scope::Read, Scope::Exec, Scope::Machine];

    pub fn as_str(self) -> &'static str {
        match self {
            Scope::Read => "read",
            Scope::Exec => "exec",
            Scope::Machine => "machine",
        }
    }

    fn from_str(s: &str) -> Option<Self> {
        Scope::ALL.iter().copied().find(|sc| sc.as_str() == s)
    }
}

/// A token's row, as the owner lists it or the bearer resolves it.
#[derive(Debug, Clone)]
pub struct Token {
    pub id: i64,
    pub name: String,
    pub scopes: Vec<Scope>,
    pub created_at: String,
    pub expires_at: String,
    pub last_used_at: Option<String>,
    pub last_used_ip: Option<String>,
}

fn row_token(row: &sqlx::sqlite::SqliteRow) -> Token {
    Token {
        id: row.get("id"),
        name: row.get("name"),
        scopes: parse_scopes(&row.get::<String, _>("scopes")),
        created_at: row.get("created_at"),
        expires_at: row.get("expires_at"),
        last_used_at: row.get("last_used_at"),
        last_used_ip: row.get("last_used_ip"),
    }
}

/// The `scopes` column: unknown names are dropped rather than refused, so a
/// scope removed from the code leaves a token that still says what it does.
pub fn parse_scopes(raw: &str) -> Vec<Scope> {
    raw.split(',').filter_map(Scope::from_str).collect()
}

fn scopes_value(scopes: &[Scope]) -> String {
    scopes.iter().map(|s| s.as_str()).collect::<Vec<_>>().join(",")
}

/// Stores a token's hash. The caller has the token and the hash; the database
/// keeps only the latter.
pub async fn create(
    pool: &SqlitePool,
    name: &str,
    token_hash: &str,
    scopes: &[Scope],
    expires_at: &str,
) -> Result<i64> {
    let done = sqlx::query(
        "INSERT INTO api_tokens (name, token_hash, scopes, expires_at) VALUES (?, ?, ?, ?)",
    )
    .bind(name)
    .bind(token_hash)
    .bind(scopes_value(scopes))
    .bind(expires_at)
    .execute(pool)
    .await?;
    Ok(done.last_insert_rowid())
}

/// The token a hash stands for, if it exists and has not expired. Its use is
/// recorded by the caller, which knows the peer's address.
pub async fn find(pool: &SqlitePool, token_hash: &str) -> Result<Option<Token>> {
    let row = sqlx::query(
        "SELECT * FROM api_tokens WHERE token_hash = ? AND expires_at > CURRENT_TIMESTAMP",
    )
    .bind(token_hash)
    .fetch_optional(pool)
    .await?;
    Ok(row.as_ref().map(row_token))
}

/// What the owner sees: every token, used and never used.
pub async fn list(pool: &SqlitePool) -> Result<Vec<Token>> {
    let rows = sqlx::query("SELECT * FROM api_tokens ORDER BY id").fetch_all(pool).await?;
    Ok(rows.iter().map(row_token).collect())
}

/// One token, for what answers by id rather than by walking the list.
pub async fn get(pool: &SqlitePool, id: i64) -> Result<Option<Token>> {
    let row = sqlx::query("SELECT * FROM api_tokens WHERE id = ?")
        .bind(id)
        .fetch_optional(pool)
        .await?;
    Ok(row.as_ref().map(row_token))
}

/// How stale `last_used_at` may be before a use rewrites it. Every call would
/// otherwise be a write, and what the owner reads is the last time, not every
/// time.
const USE_INTERVAL_SECS: i64 = 60;

/// Records a use, as the owner reads it in the list — at most once per
/// [`USE_INTERVAL_SECS`], so a client polling does not turn every read into a
/// database write.
pub async fn record_use(pool: &SqlitePool, id: i64, ip: Option<&str>) -> Result<()> {
    sqlx::query(
        "UPDATE api_tokens SET last_used_at = CURRENT_TIMESTAMP, last_used_ip = ? \
         WHERE id = ? AND (last_used_at IS NULL OR last_used_at < datetime('now', ?))",
    )
    .bind(ip)
    .bind(id)
    .bind(format!("-{USE_INTERVAL_SECS} seconds"))
    .execute(pool)
    .await?;
    Ok(())
}

/// Deletes a token. Whether it was there: a revoke of what is already gone is
/// fine to report as such.
pub async fn revoke(pool: &SqlitePool, id: i64) -> Result<bool> {
    let done = sqlx::query("DELETE FROM api_tokens WHERE id = ?")
        .bind(id)
        .execute(pool)
        .await?;
    Ok(done.rows_affected() == 1)
}

/// The hash a token is stored under, as `watch_token_hash` is for a watch
/// token.
pub fn hash(token: &str) -> String {
    use sha2::{Digest, Sha256};
    hex::encode(Sha256::digest(token.as_bytes()))
}

#[cfg(test)]
mod tests {
    use super::*;

    async fn pool() -> SqlitePool {
        let pool = SqlitePool::connect("sqlite::memory:").await.unwrap();
        sqlx::migrate!("./migrations").run(&pool).await.unwrap();
        pool
    }

    #[test]
    fn scopes_round_trip() {
        assert_eq!(parse_scopes("read,exec"), vec![Scope::Read, Scope::Exec]);
        // A scope the code dropped is not an error in the row.
        assert_eq!(parse_scopes("read,retired"), vec![Scope::Read]);
        assert!(parse_scopes("").is_empty());
    }

    #[tokio::test]
    async fn a_token_is_found_until_it_expires() {
        let pool = pool().await;
        let digest = hash("sbt_example");
        create(&pool, "ci", &digest, &[Scope::Read], "9999-12-31 00:00:00")
            .await
            .unwrap();
        create(&pool, "old", &hash("sbt_old"), &[Scope::Read], "2001-01-01 00:00:00")
            .await
            .unwrap();

        let found = find(&pool, &digest).await.unwrap().expect("there");
        assert_eq!(found.name, "ci");
        assert_eq!(found.scopes, vec![Scope::Read]);
        assert!(find(&pool, &hash("sbt_old")).await.unwrap().is_none());

        record_use(&pool, found.id, Some("127.0.0.1")).await.unwrap();
        assert_eq!(
            list(&pool).await.unwrap()[0].last_used_ip.as_deref(),
            Some("127.0.0.1")
        );
        assert!(revoke(&pool, found.id).await.unwrap());
        assert!(!revoke(&pool, found.id).await.unwrap());
        // The expired one is still listed: it is the owner's to revoke, not
        // something a lookup silently dropped.
        let left = list(&pool).await.unwrap();
        assert_eq!(left.len(), 1);
        assert_eq!(left[0].name, "old");
        assert!(revoke(&pool, left[0].id).await.unwrap());
        assert!(list(&pool).await.unwrap().is_empty());
    }
}
