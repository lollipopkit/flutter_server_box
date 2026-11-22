//! `/api/v1/services` — the service units of the machine the agent runs on,
//! and the start, stop, restart, enable or disable of one.
//!
//! # Why this is not `/exec`
//!
//! Which manager a machine runs, whether it has a per-account scope, how each
//! manager's listing is assembled and parsed, which of the three words for a
//! state means what, and what may be done to a unit in a given state — all of
//! that is one model, and it lives in [`sbm_parser::service`], asked in the
//! order [`sbm_mcp::machine::services`] asks it — the app's MCP server asks
//! its servers the same way — so the panel composes no command line and
//! parses nothing. A unit is resolved against a listing read now, never
//! taken from the client.
//!
//! # Privilege
//!
//! The transport rule, both ways (`api::machine::gate`): anyone with a
//! shell can run `systemctl`, and a unit's definition and log are the
//! machine's configuration rather than its numbers. A `sudo` password travels
//! in the body, never in a command line, and a refusal comes back as a field
//! (`sudo_rejected`) rather than as a failed request, since the caller's next
//! move is to ask for a different one.

use crate::api::WebError;
use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;

use super::machine::{self, Here};
use super::server::AppState;
use sbm_mcp::machine::services::{self, ServiceActRequest, ServicePart, ServiceRefused};

#[derive(Debug, Deserialize)]
pub struct ServiceQuery {
    /// Which part of the machine's service state to read. Defaults to the
    /// units themselves.
    part: Option<ServicePart>,
    /// [`sbm_parser::service::ServiceUnit::key`] for the parts that are about
    /// one unit.
    key: Option<String>,
}

/// Reads the machine's units, or one unit's own files.
pub async fn list(
    req: HttpRequest,
    query: web::types::Query<ServiceQuery>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    if let Err(refused) = machine::gate(&req, &state, "service list").await {
        return Ok(refused);
    }
    let part = query.part.unwrap_or_default();
    let key = query.key.as_deref();
    // A part that is about one unit and was not told which is a request that
    // cannot be answered, not one to guess a default for. Refused before
    // anything runs, so a malformed request costs nothing on the machine.
    if part.needs_key() && key.is_none_or(str::is_empty) {
        return Ok(HttpResponse::BadRequest().build());
    }
    let here = Here::quiet(&state.remote_access.exec);
    Ok(HttpResponse::Ok().json(&services::listing(&here, part, key).await))
}

/// Runs one action on one unit.
pub async fn act(
    req: HttpRequest,
    body: web::types::Json<ServiceActRequest>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    let request = body.into_inner();
    let what = format!("service {} {}", request.action.as_str(), request.key);
    let gated = match machine::gate(&req, &state, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    match services::perform(&Here::recorded(&state, gated.remote_ip), request).await {
        Ok(response) => Ok(HttpResponse::Ok().json(&response)),
        Err(ServiceRefused::Unsupported) => Ok(HttpResponse::BadRequest().build()),
        Err(ServiceRefused::NoSuchUnit) => Ok(HttpResponse::NotFound().build()),
    }
}
