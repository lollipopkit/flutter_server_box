//! `GET/PUT /api/v1/custom-cmds` — the custom commands installed on this
//! machine.
//!
//! The store is the directory itself (`monitoring::custom_cmds`), which is the
//! same one the app writes over SSH and the status script reads. So the panel
//! and the app edit one set rather than each keeping its own, and a command
//! added here shows up on the next extended collection cycle without anything
//! having to be told about it.
//!
//! Writing is gated on `remote_access.full_access`, the same grant the shell
//! and `/exec` need. A file in that directory is run by the status script on
//! every extended cycle, so adding one is arranging for code to run as the
//! agent's user — the same decision, and not a second, weaker one. Reading
//! only needs the panel login: it discloses the commands, not the machine.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::server::AppState;
use super::server::verify_auth;
use super::ws;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::monitoring::custom_cmds::{self, CustomCmd, Error};

/// The largest request body accepted: every command at once, since a write
/// replaces the whole set. Bounded so one caller cannot make the agent buffer
/// whatever it likes, and generous next to what a set of shell snippets is.
pub const MAX_REQUEST: usize = 1024 * 1024;

#[derive(Serialize)]
struct ListResponse {
    commands: Vec<CustomCmd>,
    /// Whether this panel may change them. The editor asks so it can show a
    /// read-only view instead of failing on save; the answer is re-checked on
    /// the write itself, since a UI hint is not a boundary.
    editable: bool,
}

#[derive(Deserialize)]
pub struct ReplaceRequest {
    /// The whole set, in the order it should run in. A replace rather than a
    /// per-command edit: the order is part of what is stored, and expressing a
    /// move as a patch would mean renumbering on both sides.
    commands: Vec<CustomCmd>,
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

pub async fn list(
    req: HttpRequest,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    let editable = app_state.full_access_allowed(secure);

    match custom_cmds::list() {
        Ok(commands) => Ok(HttpResponse::Ok().json(&ListResponse { commands, editable })),
        Err(e) => Ok(error_response(e)),
    }
}

pub async fn replace(
    req: HttpRequest,
    body: web::types::Json<ReplaceRequest>,
    app_state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if verify_auth(&req, &app_state.config.get_jwt_secret()).is_err() {
        return Ok(HttpResponse::Unauthorized().finish());
    }

    let remote_ip = peer_ip(&req);
    let secure = ws::is_secure_transport(&req, app_state.tls_active);
    if !app_state.full_access_allowed(secure) {
        Event::new(Kind::CustomCmd, Action::Denied, Outcome::Denied)
            .remote_ip(remote_ip)
            .detail("full access disabled")
            .record(&app_state.db)
            .await;
        return Ok(HttpResponse::Forbidden().finish());
    }

    let commands = body.into_inner().commands;
    // Names, never bodies: a command's text is what the user typed and may
    // hold anything, including something they would not want in a log.
    let subject = commands.iter().map(|c| c.name.as_str()).collect::<Vec<_>>().join(", ");
    match custom_cmds::replace(&commands) {
        Ok(()) => {
            Event::new(Kind::CustomCmd, Action::Open, Outcome::Ok)
                .remote_ip(remote_ip)
                .subject(subject)
                .record(&app_state.db)
                .await;
            Ok(HttpResponse::Ok().json(&ListResponse { commands, editable: true }))
        }
        Err(e) => {
            Event::new(Kind::CustomCmd, Action::Close, Outcome::Error)
                .remote_ip(remote_ip)
                .detail(e.to_string())
                .record(&app_state.db)
                .await;
            Ok(error_response(e))
        }
    }
}

/// A rejected set is the caller's fault and says which command was wrong; a
/// missing home directory or an unwritable path is the machine's, and the
/// panel can only report it.
fn error_response(e: Error) -> HttpResponse {
    let body = ErrorResponse { error: e.to_string() };
    match e {
        Error::Invalid(_) => HttpResponse::BadRequest().json(&body),
        Error::NoHome | Error::Io(_) => HttpResponse::InternalServerError().json(&body),
    }
}
