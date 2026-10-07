//! `/api/v1/desk/apps/{app}/storage` — what a desk app keeps for itself
//! (`sys.storage` in the panel): JSON values by key, per account and app.
//!
//! - `GET`: every key and value, `{"items": {key: value}}`.
//! - `PUT ?key=`: the body (any JSON) becomes the key's value.
//! - `DELETE ?key=`: the key goes; absent already is fine.
//!
//! Any signed-in account, for its own rows only. An app's rows are bounded
//! together ([`MAX_APP_BYTES`], keys and values as stored), so one app cannot
//! fill the database. Nothing here reaches the machine; the panel, not the
//! agent, decides which app is asking, so this is storage for convenience,
//! never for something one app must hide from another of the same account.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use super::desk::{account, internal_error, refused, valid_app_id};
use super::server::AppState;

/// Every key and value one app keeps, together.
pub const MAX_APP_BYTES: usize = 256 << 10;
/// A write's body: one value, at most all an app may keep.
pub const MAX_BODY: usize = MAX_APP_BYTES + 1024;
const MAX_KEY_BYTES: usize = 128;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct KeyQuery {
    key: String,
}

fn valid_key(key: &str) -> bool {
    (1..=MAX_KEY_BYTES).contains(&key.len()) && !key.chars().any(char::is_control)
}

macro_rules! require {
    ($result:expr) => {{
        match $result {
            Ok(value) => value,
            Err(response) => return Ok(response),
        }
    }};
}

fn checked_app(app: &str) -> Result<(), HttpResponse> {
    if valid_app_id(app) { Ok(()) } else { Err(HttpResponse::BadRequest().json(&refused("invalidAppId", None))) }
}

fn checked_key(key: &str) -> Result<(), HttpResponse> {
    if valid_key(key) { Ok(()) } else { Err(HttpResponse::BadRequest().json(&refused("invalidKey", None))) }
}

pub async fn list(
    req: HttpRequest,
    app: web::types::Path<String>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    require!(checked_app(&app));
    let rows = sqlx::query_as::<_, (String, String)>(
        "SELECT key, value FROM desk_app_storage WHERE user_id = ? AND app_id = ? ORDER BY key",
    )
    .bind(user)
    .bind(app.as_str())
    .fetch_all(&state.db)
    .await;
    match rows {
        Ok(rows) => {
            let mut items = serde_json::Map::new();
            for (key, value) in rows {
                // Stored by `put` from parsed JSON, so it parses.
                items.insert(key, serde_json::from_str(&value).unwrap_or(serde_json::Value::Null));
            }
            Ok(HttpResponse::Ok().json(&serde_json::json!({ "items": items })))
        }
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn put(
    req: HttpRequest,
    app: web::types::Path<String>,
    query: web::types::Query<KeyQuery>,
    body: web::types::Json<serde_json::Value>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    require!(checked_app(&app));
    require!(checked_key(&query.key));
    let value = body.into_inner().to_string();
    match store(&state.db, user, &app, &query.key, &value).await {
        Ok(true) => Ok(HttpResponse::NoContent().finish()),
        Ok(false) => Ok(HttpResponse::PayloadTooLarge().json(&refused("tooLarge", None))),
        Err(e) => Ok(internal_error(&e)),
    }
}

pub async fn remove(
    req: HttpRequest,
    app: web::types::Path<String>,
    query: web::types::Query<KeyQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let (_, user) = require!(account(&req, &state).await);
    require!(checked_app(&app));
    require!(checked_key(&query.key));
    let done = sqlx::query("DELETE FROM desk_app_storage WHERE user_id = ? AND app_id = ? AND key = ?")
        .bind(user)
        .bind(app.as_str())
        .bind(query.key.as_str())
        .execute(&state.db)
        .await;
    match done {
        Ok(_) => Ok(HttpResponse::NoContent().finish()),
        Err(e) => Ok(internal_error(&e)),
    }
}

/// Writes [value] at [key] unless the app's rows would then pass
/// [`MAX_APP_BYTES`]; false when refused. The sum and the write share one
/// transaction, so two writes racing cannot both slip under the bound.
async fn store(db: &sqlx::SqlitePool, user: i64, app: &str, key: &str, value: &str) -> Result<bool, sqlx::Error> {
    let mut tx = db.begin().await?;
    // A write first, so SQLite's write lock is held while the sum is read.
    sqlx::query(
        "INSERT INTO desk_app_storage (user_id, app_id, key, value, updated_at) VALUES (?, ?, ?, ?, ?) \
         ON CONFLICT(user_id, app_id, key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at",
    )
    .bind(user)
    .bind(app)
    .bind(key)
    .bind(value)
    .bind(chrono::Utc::now().to_rfc3339())
    .execute(&mut *tx)
    .await?;
    let total: i64 = sqlx::query_scalar(
        "SELECT COALESCE(SUM(LENGTH(CAST(key AS BLOB)) + LENGTH(CAST(value AS BLOB))), 0) \
         FROM desk_app_storage WHERE user_id = ? AND app_id = ?",
    )
    .bind(user)
    .bind(app)
    .fetch_one(&mut *tx)
    .await?;
    if total as usize > MAX_APP_BYTES {
        tx.rollback().await?;
        return Ok(false);
    }
    tx.commit().await?;
    Ok(true)
}
