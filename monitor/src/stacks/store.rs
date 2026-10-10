//! The `stack` rows (migration 024): which apps are deployed, from which
//! version, with what settings.

use std::collections::BTreeMap;

use serde::Serialize;
use serde_json::Value;
use sqlx::SqlitePool;

#[derive(Debug, Clone, Serialize)]
pub struct StackRow {
    pub id: String,
    pub version: String,
    pub settings: BTreeMap<String, Value>,
    pub proxy_port: u16,
    /// `installing` | `installed` | `failed`.
    pub state: String,
    pub license: String,
    pub license_accepted_by: String,
    pub license_accepted_at: String,
    pub installed_by: String,
    pub installed_at: String,
    pub updated_at: String,
    pub last_error: Option<String>,
}

#[derive(sqlx::FromRow)]
struct Raw {
    id: String,
    version: String,
    settings: String,
    proxy_port: i64,
    state: String,
    license: String,
    license_accepted_by: String,
    license_accepted_at: String,
    installed_by: String,
    installed_at: String,
    updated_at: String,
    last_error: Option<String>,
}

impl From<Raw> for StackRow {
    fn from(r: Raw) -> Self {
        Self {
            id: r.id,
            version: r.version,
            settings: serde_json::from_str(&r.settings).unwrap_or_default(),
            proxy_port: u16::try_from(r.proxy_port).unwrap_or_default(),
            state: r.state,
            license: r.license,
            license_accepted_by: r.license_accepted_by,
            license_accepted_at: r.license_accepted_at,
            installed_by: r.installed_by,
            installed_at: r.installed_at,
            updated_at: r.updated_at,
            last_error: r.last_error,
        }
    }
}

macro_rules! columns {
    () => {
        "id, version, settings, proxy_port, state, license, license_accepted_by, license_accepted_at, \
         installed_by, installed_at, updated_at, last_error"
    };
}

fn now() -> String {
    chrono::Utc::now().to_rfc3339()
}

pub async fn all(db: &SqlitePool) -> sqlx::Result<Vec<StackRow>> {
    let rows = sqlx::query_as::<_, Raw>(concat!("SELECT ", columns!(), " FROM stack ORDER BY id")).fetch_all(db).await?;
    Ok(rows.into_iter().map(Into::into).collect())
}

pub async fn load(db: &SqlitePool, id: &str) -> sqlx::Result<Option<StackRow>> {
    let row = sqlx::query_as::<_, Raw>(concat!("SELECT ", columns!(), " FROM stack WHERE id = ?")).bind(id).fetch_optional(db).await?;
    Ok(row.map(Into::into))
}

/// A new row in `installing`; `false` when [row]'s app or port is taken.
pub async fn insert(db: &SqlitePool, row: &StackRow) -> sqlx::Result<bool> {
    let done = sqlx::query(concat!(
        "INSERT OR IGNORE INTO stack (",
        columns!(),
        ") VALUES (?, ?, ?, ?, 'installing', ?, ?, ?, ?, ?, ?, NULL)"
    ))
    .bind(&row.id)
    .bind(&row.version)
    .bind(serde_json::to_string(&row.settings).unwrap_or_default())
    .bind(i64::from(row.proxy_port))
    .bind(&row.license)
    .bind(&row.license_accepted_by)
    .bind(&row.license_accepted_at)
    .bind(&row.installed_by)
    .bind(&row.installed_at)
    .bind(&row.updated_at)
    .execute(db)
    .await?;
    Ok(done.rows_affected() == 1)
}

/// A step's outcome: `installed`, or `failed` with its summary.
pub async fn finish(db: &SqlitePool, id: &str, error: Option<&str>) -> sqlx::Result<()> {
    sqlx::query("UPDATE stack SET state = ?, last_error = ?, updated_at = ? WHERE id = ?")
        .bind(if error.is_some() { "failed" } else { "installed" })
        .bind(error)
        .bind(now())
        .bind(id)
        .execute(db)
        .await?;
    Ok(())
}

/// The files were written again from [version] with [settings].
pub async fn rewrite(db: &SqlitePool, id: &str, version: &str, settings: &BTreeMap<String, Value>) -> sqlx::Result<()> {
    sqlx::query("UPDATE stack SET version = ?, settings = ?, updated_at = ? WHERE id = ?")
        .bind(version)
        .bind(serde_json::to_string(settings).unwrap_or_default())
        .bind(now())
        .bind(id)
        .execute(db)
        .await?;
    Ok(())
}

pub async fn delete(db: &SqlitePool, id: &str) -> sqlx::Result<()> {
    sqlx::query("DELETE FROM stack WHERE id = ?").bind(id).execute(db).await?;
    Ok(())
}

/// Rows a stopped agent left `installing`: their step never finished.
pub async fn fail_interrupted(db: &SqlitePool) -> sqlx::Result<u64> {
    let done = sqlx::query("UPDATE stack SET state = 'failed', last_error = 'interrupted', updated_at = ? WHERE state = 'installing'")
        .bind(now())
        .execute(db)
        .await?;
    Ok(done.rows_affected())
}
