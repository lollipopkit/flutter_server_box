//! `GET /api/v1/audit`: the audit log (`access_log`, written through
//! `api::ws::audit`) read back, newest first.
//!
//! The same rule as acting on the machine (`authz::acting_caller`): the rows
//! name commands, paths and addresses, which a plaintext link should not
//! carry. Nothing here writes; reading the log is not itself recorded.

use crate::api::WebError;
use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::authz;
use super::server::AppState;
use super::ws::audit::{Kind, Outcome};

pub const DEFAULT_PAGE: u32 = 100;
pub const MAX_PAGE: u32 = 500;

#[derive(Debug, Deserialize)]
pub struct AuditQuery {
    /// At most this many rows (default [`DEFAULT_PAGE`], at most [`MAX_PAGE`]).
    limit: Option<u32>,
    /// Rows older than this id: the previous page's `next`.
    before: Option<i64>,
    /// One kind (`login`, `exec`, …; `Kind::ALL`).
    kind: Option<String>,
    /// One result: `ok`, `denied` or `error`.
    result: Option<String>,
}

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct Entry {
    id: i64,
    timestamp: String,
    kind: String,
    action: String,
    result: String,
    /// What it was about, in the kind's terms (a command's first line, a
    /// verb and a path, a feature and its target). Rows from before the agent
    /// had one account may hold an account name.
    subject: Option<String>,
    remote_ip: Option<String>,
    /// The system account a terminal session ran as.
    ssh_user: Option<String>,
    detail: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct Page {
    entries: Vec<Entry>,
    /// `before` for the next page; absent on the last.
    next: Option<i64>,
}

pub async fn list(
    req: HttpRequest,
    query: web::types::Query<AuditQuery>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    if let Err(refused) = authz::acting_caller(&req, &state).await {
        return Ok(refused);
    }
    let kind = query.kind.as_deref().filter(|k| !k.is_empty());
    if let Some(kind) = kind
        && !Kind::ALL.iter().any(|k| k.as_str() == kind)
    {
        return Ok(authz::error(StatusCode::BAD_REQUEST, "invalid_input", "unknown kind"));
    }
    let result = query.result.as_deref().filter(|r| !r.is_empty());
    if let Some(result) = result
        && !Outcome::ALL.iter().any(|o| o.as_str() == result)
    {
        return Ok(authz::error(StatusCode::BAD_REQUEST, "invalid_input", "unknown result"));
    }
    let limit = query.limit.unwrap_or(DEFAULT_PAGE).clamp(1, MAX_PAGE);

    // One more than asked: whether there is a next page.
    let rows = sqlx::query_as::<_, Entry>(
        "SELECT id, timestamp, kind, action, result, subject, remote_ip, ssh_user, detail \
         FROM access_log \
         WHERE (?1 IS NULL OR id < ?1) AND (?2 IS NULL OR kind = ?2) AND (?3 IS NULL OR result = ?3) \
         ORDER BY id DESC LIMIT ?4",
    )
    .bind(query.before)
    .bind(kind)
    .bind(result)
    .bind(i64::from(limit) + 1)
    .fetch_all(&state.db)
    .await;
    let mut entries = match rows {
        Ok(rows) => rows,
        Err(e) => return Ok(super::respond::internal(&e)),
    };
    let next = if entries.len() > limit as usize {
        entries.truncate(limit as usize);
        entries.last().map(|entry| entry.id)
    } else {
        None
    };
    Ok(HttpResponse::Ok().json(&Page { entries, next }))
}
