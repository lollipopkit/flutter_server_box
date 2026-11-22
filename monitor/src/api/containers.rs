//! `/api/v1/containers` — the containers on the machine the agent runs on.
//!
//! # Why this is not `/exec`
//!
//! Every command here is a fixed string this agent composes, and every answer
//! is parsed. Sending `docker ps` through `/exec` and parsing it in the panel
//! would work — it is what the app does over SSH — but the choice of *which*
//! fields to ask for, how to tell Podman from Docker, how a container's state
//! is read out of either one's wording and what a prune is allowed to remove is
//! a model, not a command. It lives in [`sbm_parser::container`], asked in the
//! order [`sbm_mcp::machine::containers`] asks it, so the app, this endpoint
//! and the panel read one machine the same way.
//!
//! The panel also never composes a command line. A start, a stop, a removal, an
//! image pull or prune, a `run` is a [`ContainerAction`] on the wire,
//! serialized as a tagged object, and an action this build does not implement
//! is refused while deserializing rather than reaching a shell. A `run`'s extra
//! arguments are the one free-form text here, and they are split by
//! [`sbm_parser::container::parse_run_args`] — never by the caller — so a `;` in
//! them is an ordinary character. A value the runtime would read as an option,
//! or a reference it cannot take, is refused as `400 invalid_input` with the
//! issue in `issue`, before anything is probed or run.
//!
//! A shell *inside* a container is not here: it needs a PTY, so it is the
//! terminal endpoint's `target` (`api::ws::terminal`), which builds the same
//! [`sbm_parser::container::shell_command`] this module would.
//!
//! # Runtime detection
//!
//! The agent asks `docker` first and `podman` second, and honours the client
//! that lies about its name: Podman prints `Emulate Docker CLI using podman` on
//! stderr and otherwise answers every Docker command exactly, so a machine where
//! `/usr/bin/docker` is a Podman symlink would otherwise be reported as Docker
//! and silently show Podman's dialect.
//!
//! There is no way for the caller to name the runtime or the socket. A remote
//! `DOCKER_HOST` is a real case the app supports and this endpoint does not yet
//! — TODO: an agent-side setting, alongside the container type, edited through
//! `MonitorSettingsPage` the way the rest of the agent's own configuration is.
//!
//! # Privilege
//!
//! The transport rule, both ways (`api::machine::gate`): changing a
//! container is running code, and a container's log and its command line are
//! where a secret it was started with shows.
//!
//! A runtime the agent's user is not a member of answers `permission denied`,
//! which is reported as its own [`ContainerReason`] rather than as a failure of
//! the request: the remedy is on the machine (`usermod -aG docker <user>`), not
//! in the panel, and a page that showed the shell's words would say neither
//! which group nor which user. TODO: run through `machine::as_root` with a
//! password from the body, as `/process` and `/services` do, for a runtime
//! only root may reach.

use crate::api::WebError;
use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::Deserialize;
use serde_json::json;

use super::exec::Limits;
use super::machine::{self, Here};
use super::server::AppState;
use sbm_mcp::machine::containers::{self, ContainerPart};
use sbm_parser::container::{ContainerAction, ContainerType};

#[derive(Debug, Deserialize)]
pub struct ContainerQuery {
    part: Option<ContainerPart>,
    /// Which container a part about one is about. Ignored by the parts that are
    /// about the machine, so a client may carry it along without harm.
    id: Option<String>,
}

/// Reads one part of the machine's container state.
pub async fn list(
    req: HttpRequest,
    query: web::types::Query<ContainerQuery>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    if let Err(refused) = machine::gate(&req, &state, "containers list").await {
        return Ok(refused);
    }
    // A part that is about one container and was not told which, or told an
    // id the runtime would read as an option, is refused before the runtime
    // is run.
    let here = Here::quiet(&state.remote_access.exec);
    match containers::listing(&here, query.part.unwrap_or_default(), query.id.as_deref()).await {
        Ok(response) => Ok(HttpResponse::Ok().json(&response)),
        Err(_) => Ok(HttpResponse::BadRequest().build()),
    }
}

/// Performs one change and reports how the machine answered.
pub async fn act(
    req: HttpRequest,
    body: web::types::Json<ContainerAction>,
    state: Arc<AppState>,
) -> Result<HttpResponse, WebError> {
    let action = body.into_inner();
    let what = format!("containers {}", containers::action_subject(&action));
    let gated = match machine::gate(&req, &state, &what).await {
        Ok(gated) => gated,
        Err(refused) => return Ok(refused),
    };
    match containers::apply(&Here::recorded(&state, gated.remote_ip), action).await {
        Ok(response) => Ok(HttpResponse::Ok().json(&response)),
        Err(issue) => Ok(HttpResponse::BadRequest().json(&json!({ "error": "invalid_input", "issue": issue }))),
    }
}

/// Which runtime this machine has, for the agent's own uses of one (stacks,
/// backups, a shell in a container).
pub(crate) async fn detect_runtime(exec: &Limits) -> Option<ContainerType> {
    containers::detect_runtime(&Here::quiet(exec)).await
}
