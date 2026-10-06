//! `/api/v1/tmux` — the tmux sessions on the machine the agent runs on.
//!
//! The panel's terminal attaches to one of these through the terminal
//! endpoint's `target`, with tmux's own UI (the plain client, not the app's
//! control-mode one). Listing them is what that page needs first, and it is a
//! command and its output — `sbm_parser::tmux`'s, so the app and this endpoint
//! read one machine the same way.
//!
//! `shell` for the grant, like every other machine endpoint: a session is a
//! shell, so whoever may attach to one may already open one.

use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde_json::json;

use super::exec::{ExecResponse, run};
use super::machine;
use super::server::AppState;
use crate::core::permissions::Grant;

/// The machine's tmux sessions, or `available: false` when tmux is not
/// installed.
///
/// "No server running" — what tmux prints on a machine with tmux installed but
/// no session started — is `available: true` with an empty list, not an error:
/// there is nothing to attach to, which is an answer rather than a failure. A
/// listing that failed for any other reason says so in `error`, since an empty
/// list would otherwise read as "this machine has no sessions".
pub async fn list(
    req: HttpRequest,
    state: web::types::State<Arc<AppState>>,
) -> Result<HttpResponse, web::Error> {
    if let Err(refused) = machine::gate(&req, &state, Grant::Shell, "tmux list").await {
        return Ok(refused);
    }
    let exec = &state.remote_access.exec;

    // Found through the agent's own command, never named by the client: a
    // binary path from a request would be a way to run something else.
    let found = run(sbm_parser::tmux::FIND_COMMAND, None, None, exec).await;
    let bin = match &found {
        Ok(out) => sbm_parser::tmux::parse_find(&out.stdout, out.exit_code == Some(0)),
        Err(e) => {
            tracing::warn!("tmux: could not look for the binary: {e}");
            None
        }
    };
    let Some(bin) = bin else {
        return Ok(HttpResponse::Ok().json(&json!({
            "available": false,
            "sessions": [],
            "error": null,
        })));
    };

    let (sessions, error) =
        match run(&sbm_parser::tmux::list_sessions_command(&bin), None, None, exec).await {
            Ok(out) if out.exit_code == Some(0) => {
                (sbm_parser::tmux::parse_sessions(&out.stdout).sessions, None)
            }
            // The machine has tmux and nothing running, which is not a failure.
            Ok(out) if out.stderr.contains("no server running") => (Vec::new(), None),
            Ok(out) => {
                let reason = failure_reason(&out);
                tracing::warn!("tmux list-sessions: {reason}");
                (Vec::new(), Some(reason))
            }
            Err(e) => {
                tracing::warn!("tmux: could not list the sessions: {e}");
                (Vec::new(), Some(e.to_string()))
            }
        };
    Ok(HttpResponse::Ok().json(&json!({
        "available": true,
        "sessions": sessions,
        "error": error,
    })))
}

/// A one-line reason a listing failed, for the panel to show under its own
/// sentence: the command's own words where it had any, and what the agent saw
/// otherwise. Never the whole output.
fn failure_reason(out: &ExecResponse) -> String {
    if out.timed_out {
        return "did not finish in time".to_owned();
    }
    if out.truncated {
        return "printed more than this agent reads".to_owned();
    }
    if let Some(line) = out.stderr.lines().map(str::trim).find(|l| !l.is_empty()) {
        return line.to_owned();
    }
    match out.exit_code {
        Some(code) => format!("exited {code}"),
        None => "did not finish".to_owned(),
    }
}

