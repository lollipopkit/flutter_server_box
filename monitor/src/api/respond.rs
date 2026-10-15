//! Error answers shared by the handlers.

use ntex::web::HttpResponse;

/// `config.toml` could not be read. The cause stays in the log: a parse
/// error quotes the offending line, which may hold a credential.
pub fn config_unreadable(e: &dyn std::fmt::Display) -> HttpResponse {
    tracing::error!("config: {e}");
    HttpResponse::InternalServerError().json(&serde_json::json!({ "error": "config_unreadable" }))
}
