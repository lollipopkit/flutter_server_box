//! Error answers shared by the handlers: `{"error": <code>}` with a status.
//!
//! A cause (a database or IO error) is logged, never sent: its text can name
//! paths, rows or, for `config.toml`, a credential.

use std::fmt::Display;

use ntex::http::StatusCode;
use ntex::web::HttpResponse;

/// `{"error": code}` with [status].
pub fn error(status: StatusCode, code: &str) -> HttpResponse {
    HttpResponse::builder(status).json(&serde_json::json!({ "error": code }))
}

/// [error] by a numeric status, as `stacks::Refusal` and the managers carry
/// it; one that is not a status is a 400.
pub fn error_u16(status: u16, code: &str) -> HttpResponse {
    error(StatusCode::from_u16(status).unwrap_or(StatusCode::BAD_REQUEST), code)
}

/// 500 `{"error":"internal"}`, the cause logged with where it was met.
#[track_caller]
pub fn internal(e: &dyn Display) -> HttpResponse {
    let at = std::panic::Location::caller();
    tracing::error!("{}:{}: {e}", at.file(), at.line());
    error(StatusCode::INTERNAL_SERVER_ERROR, "internal")
}

/// `config.toml` could not be read. The cause stays in the log: a parse
/// error quotes the offending line, which may hold a credential.
pub fn config_unreadable(e: &dyn Display) -> HttpResponse {
    tracing::error!("config: {e}");
    error(StatusCode::INTERNAL_SERVER_ERROR, "config_unreadable")
}
