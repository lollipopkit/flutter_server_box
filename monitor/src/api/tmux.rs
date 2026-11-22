//! `/api/v1/tmux` — the tmux sessions on the machine the agent runs on.
//!
//! The panel's terminal attaches to one of these through the terminal
//! endpoint's `target`, with tmux's own UI (the plain client, not the app's
//! control-mode one). Listing them is what that page needs first, and it is a
//! command and its output — `sbm_parser::tmux`'s, asked through
//! [`sbm_mcp::machine::tmux`], so the app and this endpoint read one machine
//! the same way.
//!
//! The transport rule (`api::machine::gate`), like every other machine
//! endpoint: a session is a shell, so whoever may attach to one may already
//! open one.

use crate::api::WebError;
use std::sync::Arc;

use ntex::web::{HttpRequest, HttpResponse};

use super::machine::{self, Here};
use super::server::AppState;

/// The machine's tmux sessions — see [`sbm_mcp::machine::tmux::sessions`].
pub async fn list(
    req: HttpRequest,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    if let Err(refused) = machine::gate(&req, &state, "tmux list").await {
        return Ok(refused);
    }
    let here = Here::quiet(&state.remote_access.exec);
    Ok(HttpResponse::Ok().json(&sbm_mcp::machine::tmux::sessions(&here).await))
}
