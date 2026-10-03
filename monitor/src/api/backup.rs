//! `GET /api/v1/backup` and `GET/PUT/DELETE /api/v1/backup/blob?name=` — the
//! backups this agent hosts: the app's sync file, as a fourth remote storage
//! beside WebDAV, iCloud and Gist, and what an operator uploads from the panel.
//!
//! # What a blob is
//!
//! Opaque bytes under a name (migration 015). The app encrypts a backup before
//! it is sent (`fl_lib`'s `Cryptor`, a key derived from a password the operator
//! typed), so what arrives is ciphertext. **Nothing here reads a blob**: there
//! is nothing it could check, and the one thing it could do is leak.
//!
//! # Privilege
//!
//! Admin, both ways (`docs/dev/monitor-permissions.md`): a backup holds the
//! operator's servers and keys, encrypted or not, and replacing it is
//! replacing what every synced device merges next.

use std::sync::Arc;

use futures::StreamExt;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;

use super::authz;
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};

/// The most one blob may be. The app's backup is kilobytes to a few megabytes;
/// this bounds what one request makes the agent hold in memory.
pub const MAX_BYTES: u64 = 64 * 1024 * 1024;

/// The most blobs the store keeps, so the database cannot be grown without
/// bound one name at a time.
pub const MAX_BLOBS: i64 = 64;

/// The longest name, in bytes.
const MAX_NAME: usize = 128;

/// A name a blob may have: letters, digits, dot, dash, underscore, no leading
/// dot. Refused rather than rewritten, so two names never mean one blob; and
/// it is what goes into `content-disposition`, which nothing else here could
/// break.
pub fn valid_name(name: &str) -> bool {
    !name.is_empty()
        && name.len() <= MAX_NAME
        && !name.starts_with('.')
        && name
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | '_'))
}

/// One blob, as a listing shows it. Never its contents.
#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct BlobView {
    pub name: String,
    pub size: i64,
    /// RFC 3339. With `size`, what the app's sync compares to skip a download.
    pub updated_at: String,
}

#[derive(Serialize)]
struct ListResponse {
    blobs: Vec<BlobView>,
    /// So the panel can say it before a file is chosen.
    max_bytes: u64,
}

#[derive(Deserialize)]
pub struct NameQuery {
    name: String,
}

fn refusal(status: ntex::http::StatusCode, error: &'static str) -> HttpResponse {
    HttpResponse::build(status).json(&serde_json::json!({ "error": error }))
}

fn internal_error(e: &sqlx::Error) -> HttpResponse {
    tracing::error!("backup: {e}");
    refusal(ntex::http::StatusCode::INTERNAL_SERVER_ERROR, "internal")
}

async fn record(state: &AppState, req: &HttpRequest, caller: &authz::Caller, outcome: Outcome, detail: String) {
    Event::new(Kind::Backup, Action::Write, outcome)
        .subject(&caller.username)
        .remote_ip(peer_ip(req))
        .detail(detail)
        .record(&state.db)
        .await;
}

pub async fn list(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = authz::admin_caller(&req, &state).await {
        return Ok(refused);
    }
    match load(&state.db).await {
        Ok(blobs) => Ok(HttpResponse::Ok().json(&ListResponse { blobs, max_bytes: MAX_BYTES })),
        Err(e) => Ok(internal_error(&e)),
    }
}

/// The blob, byte for byte.
pub async fn download(
    req: HttpRequest,
    query: web::types::Query<NameQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = authz::admin_caller(&req, &state).await {
        return Ok(refused);
    }
    if !valid_name(&query.name) {
        return Ok(refusal(ntex::http::StatusCode::BAD_REQUEST, "invalidName"));
    }
    let row = sqlx::query_scalar::<_, Vec<u8>>("SELECT data FROM backup_blob WHERE name = ?")
        .bind(&query.name)
        .fetch_optional(&state.db)
        .await;
    match row {
        Ok(Some(data)) => Ok(HttpResponse::Ok()
            .content_type("application/octet-stream")
            .header(
                "content-disposition",
                format!("attachment; filename=\"{}\"", query.name),
            )
            .body(data)),
        Ok(None) => Ok(refusal(ntex::http::StatusCode::NOT_FOUND, "noSuchBlob")),
        Err(e) => Ok(internal_error(&e)),
    }
}

/// Stores a blob, replacing one of the same name. Read whole before anything
/// is written, so a request that dies halfway leaves the old blob in place.
pub async fn upload(
    req: HttpRequest,
    query: web::types::Query<NameQuery>,
    mut body: web::types::Payload,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = match authz::admin_caller(&req, &state).await {
        Ok(caller) => caller,
        Err(refused) => return Ok(refused),
    };
    let name = query.into_inner().name;
    if !valid_name(&name) {
        return Ok(refusal(ntex::http::StatusCode::BAD_REQUEST, "invalidName"));
    }

    let mut data = Vec::new();
    while let Some(chunk) = body.next().await {
        let Ok(chunk) = chunk else {
            return Ok(HttpResponse::BadRequest().finish());
        };
        if (data.len() + chunk.len()) as u64 > MAX_BYTES {
            return Ok(refusal(ntex::http::StatusCode::PAYLOAD_TOO_LARGE, "tooLarge"));
        }
        data.extend_from_slice(&chunk);
    }

    let size = data.len() as i64;
    match store(&state.db, &name, data).await {
        Ok(Some(view)) => {
            record(&state, &req, &caller, Outcome::Ok, format!("backup write {name}: {size} bytes")).await;
            Ok(HttpResponse::Ok().json(&view))
        }
        Ok(None) => Ok(refusal(ntex::http::StatusCode::CONFLICT, "tooMany")),
        Err(e) => {
            record(&state, &req, &caller, Outcome::Error, format!("backup write {name}: failed")).await;
            Ok(internal_error(&e))
        }
    }
}

pub async fn remove(
    req: HttpRequest,
    query: web::types::Query<NameQuery>,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    let caller = match authz::admin_caller(&req, &state).await {
        Ok(caller) => caller,
        Err(refused) => return Ok(refused),
    };
    if !valid_name(&query.name) {
        return Ok(refusal(ntex::http::StatusCode::BAD_REQUEST, "invalidName"));
    }
    match sqlx::query("DELETE FROM backup_blob WHERE name = ?")
        .bind(&query.name)
        .execute(&state.db)
        .await
    {
        Ok(done) if done.rows_affected() == 0 => {
            Ok(refusal(ntex::http::StatusCode::NOT_FOUND, "noSuchBlob"))
        }
        Ok(_) => {
            record(&state, &req, &caller, Outcome::Ok, format!("backup remove {}", query.name)).await;
            Ok(HttpResponse::NoContent().finish())
        }
        Err(e) => Ok(internal_error(&e)),
    }
}

async fn load(db: &SqlitePool) -> Result<Vec<BlobView>, sqlx::Error> {
    sqlx::query_as::<_, BlobView>("SELECT name, size, updated_at FROM backup_blob ORDER BY name")
        .fetch_all(db)
        .await
}

/// Writes the blob, or answers `None` when it would be a new name past
/// [`MAX_BLOBS`]. Counted in the same transaction as the write, so two
/// uploads cannot both take the last place.
async fn store(db: &SqlitePool, name: &str, data: Vec<u8>) -> Result<Option<BlobView>, sqlx::Error> {
    let mut tx = db.begin().await?;
    let exists = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM backup_blob WHERE name = ?")
        .bind(name)
        .fetch_one(&mut *tx)
        .await?
        > 0;
    if !exists {
        let count = sqlx::query_scalar::<_, i64>("SELECT COUNT(*) FROM backup_blob")
            .fetch_one(&mut *tx)
            .await?;
        if count >= MAX_BLOBS {
            return Ok(None);
        }
    }
    let view = BlobView {
        name: name.to_string(),
        size: data.len() as i64,
        updated_at: chrono::Utc::now().to_rfc3339_opts(chrono::SecondsFormat::Millis, true),
    };
    sqlx::query(
        "INSERT INTO backup_blob (name, data, size, updated_at) VALUES (?, ?, ?, ?) \
         ON CONFLICT(name) DO UPDATE SET data = excluded.data, size = excluded.size, \
         updated_at = excluded.updated_at",
    )
    .bind(name)
    .bind(data)
    .bind(view.size)
    .bind(&view.updated_at)
    .execute(&mut *tx)
    .await?;
    tx.commit().await?;
    Ok(Some(view))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_name_is_not_a_path() {
        for good in ["srvbox_bak_v3.json", "2026-10-03-srvbox_bak_v3.json", "a"] {
            assert!(valid_name(good), "{good}");
        }
        let long = "a".repeat(MAX_NAME + 1);
        for bad in ["", ".hidden", "../x", "a/b", "a\\b", "a b", "a\"b", "名", long.as_str()] {
            assert!(!valid_name(bad), "{bad:?}");
        }
    }
}
