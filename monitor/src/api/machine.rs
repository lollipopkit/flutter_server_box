//! What the machine-management endpoints share: the panel's power, process,
//! service, cron and container pages (issue #1623).
//!
//! Each of them runs a command on the machine the agent is installed on,
//! built and parsed in Rust (`sbm_parser`) rather than sent through `/exec` by
//! the panel, so the command text lives in one place with the app's. What they
//! have in common is who may call them and what is written down when someone
//! may not: [`gate`] is that, and nothing else in these handlers decides it.

use ntex::http::StatusCode;
use ntex::web::{HttpRequest, HttpResponse};

use super::authz::{self, Caller};
use super::server::AppState;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::permissions::Grant;

/// The machine-management endpoints this agent serves, as `features` in
/// `/capabilities`. A panel shows a page only when its name is here, which is
/// how it tells an agent without the endpoint from one that refused.
pub const FEATURES: &[&str] = &["power"];

/// Who is asking, and from where, once [`gate`] let them through.
pub struct Gated {
    pub caller: Caller,
    pub remote_ip: Option<String>,
}

/// The caller, if their role holds [grant] over this link.
///
/// A refusal is recorded under [`Kind::Machine`] — the account as the
/// subject, [what] (the feature and verb, never anything the request carried)
/// and the reason as the detail — and answered
/// `403 {"error":"forbidden","message":<why>}`. Re-checked on every request
/// rather than trusted from `/capabilities`: that answer is a hint for the
/// UI, and the UI is not a boundary.
pub async fn gate(
    req: &HttpRequest,
    state: &AppState,
    grant: Grant,
    what: &str,
) -> Result<Gated, HttpResponse> {
    let caller = authz::jwt_caller(req, state).await?;
    let remote_ip = peer_ip(req);
    if let Err(why) = caller.check(grant, state, authz::is_secure(req, state)) {
        Event::new(Kind::Machine, Action::Denied, Outcome::Denied)
            .subject(&caller.username)
            .remote_ip(remote_ip)
            .detail(format!("{what}: {} {}", grant.as_str(), why.as_str()))
            .record(&state.db)
            .await;
        return Err(authz::error(StatusCode::FORBIDDEN, "forbidden", why.as_str()));
    }
    Ok(Gated { caller, remote_ip })
}
