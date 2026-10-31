//! `/api/v1/live*`: what is signed in to and open on this agent right now,
//! and ending one of them.
//!
//! - `GET /live`: terminal sessions (`ws::session`), relayed connections,
//!   listened ports, consoles and remote desktops (`ws::live`), watch tokens
//!   (one per watch or widget; revoked with `DELETE /watch-token`), and the
//!   devices that signed in with the password (`db::accounts`).
//! - `DELETE /live/sessions/{id}`, `/live/connections/{id}`: ends one; the
//!   client driving it is told `ended`.
//! - `DELETE /live/devices/{id}`: forgets a device. It is no longer a known
//!   device to the login throttle, and its next sign-in gets a new token; it
//!   does not sign it out, since a device that keeps the password signs in
//!   again: changing the password is what keeps one out.
//!
//! Acting rule (`authz::acting_caller`): the list names addresses, and
//! ending something is acting. Every ending is audited (`Kind::Admin`).

use crate::api::WebError;
use std::sync::Arc;

use ntex::http::StatusCode;
use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Serialize;

use super::authz;
use super::server::AppState;
use super::ws::audit::Action;
use super::ws::live::LiveConnection;
use super::ws::session::SessionInfo;
use crate::db::accounts::{self, LoginDevice};

#[derive(Debug, Serialize, sqlx::FromRow)]
pub struct WatchToken {
    pub client_id: String,
    /// Unix seconds, as the table keeps them.
    pub created_at: i64,
    pub expires_at: i64,
    pub scope: String,
}

#[derive(Debug, Serialize)]
pub struct Live {
    sessions: Vec<SessionInfo>,
    connections: Vec<LiveConnection>,
    watch_tokens: Vec<WatchToken>,
    devices: Vec<LoginDevice>,
}

pub async fn list(req: HttpRequest, state: Arc<AppState>) -> Result<HttpResponse, WebError> {
    if let Err(refused) = authz::acting_caller(&req, &state).await {
        return Ok(refused);
    }
    let now = chrono::Utc::now().timestamp();
    let watch_tokens = sqlx::query_as::<_, WatchToken>(
        "SELECT client_id, created_at, expires_at, scope FROM watch_tokens \
         WHERE expires_at > ? ORDER BY created_at DESC",
    )
    .bind(now)
    .fetch_all(&state.db)
    .await;
    let devices = accounts::devices(&state.db, now).await;
    let (watch_tokens, devices) = match (watch_tokens, devices) {
        (Ok(watch_tokens), Ok(devices)) => (watch_tokens, devices),
        (Err(e), _) => return Ok(super::respond::internal(&e)),
        (_, Err(e)) => return Ok(super::respond::internal(&e)),
    };
    Ok(HttpResponse::Ok().json(&Live {
        sessions: state.sessions.list(),
        connections: state.live.list(),
        watch_tokens,
        devices,
    }))
}

pub async fn end_session(
    req: HttpRequest,
    path: web::types::Path<String>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    if let Err(refused) = authz::acting_caller(&req, &state).await {
        return Ok(refused);
    }
    let ended = state.sessions.close(&path, "ended");
    Ok(answer(&req, &state, ended, &format!("end terminal session {}", path.as_str())).await)
}

pub async fn end_connection(
    req: HttpRequest,
    path: web::types::Path<String>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    if let Err(refused) = authz::acting_caller(&req, &state).await {
        return Ok(refused);
    }
    let ended = state.live.end(&path);
    Ok(answer(&req, &state, ended, &format!("end connection {}", path.as_str())).await)
}

pub async fn forget_device(
    req: HttpRequest,
    path: web::types::Path<i64>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    if let Err(refused) = authz::acting_caller(&req, &state).await {
        return Ok(refused);
    }
    let forgotten = match accounts::forget_device(&state.db, *path).await {
        Ok(forgotten) => forgotten,
        Err(e) => return Ok(super::respond::internal(&e)),
    };
    Ok(answer(&req, &state, forgotten, &format!("forget device {}", *path)).await)
}

/// 204 when [done], audited; a 404 otherwise (gone already, or never was).
async fn answer(req: &HttpRequest, state: &AppState, done: bool, what: &str) -> HttpResponse {
    if !done {
        return authz::error(StatusCode::NOT_FOUND, "not_found", "Nothing open by that id");
    }
    super::admin::audit(req, state, Action::Close, what.to_string()).await;
    HttpResponse::NoContent().build()
}
