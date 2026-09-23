//! `/api/v1/desktop` — the desktops this agent can reach, and the routes the
//! panel connects to them through.
//!
//! # What this endpoint is, and what it deliberately is not
//!
//! It is a **stored list of routes**, not a session. Nothing here dials
//! anything: a session is `/api/v1/stream/ws`, which relays one TCP connection
//! to an address the client names, and that is what the panel opens a VNC or
//! RDP client onto. The reason both exist is the reason the relay exists at
//! all — a desktop is usually reachable from the machine the agent runs on and
//! from nowhere the browser is, so the agent is the client's way in.
//!
//! # Why the routes are here rather than in the browser
//!
//! The panel keeps a server list in `localStorage`, but a saved route is not
//! the same kind of state: it is what this agent can reach, so it belongs with
//! the agent — a second browser, or a phone, would otherwise have to be told
//! again, and the app's own profiles have always lived with the server rather
//! than with the client. It is also the arrangement the decision behind this
//! whole panel made: state and configuration live agent-side, and the panel
//! reads them.
//!
//! **No credential is stored in one.** See [`DesktopConfig`]: the password a
//! desktop protocol asks for is typed by the operator in the browser that runs
//! the session, and never travels to this agent at all — which is the
//! difference between this and `api::push`, where a secret is stored and
//! answered as `null`. Here there is nothing to withhold, so the ordinary read
//! is safe.
//!
//! # Privilege
//!
//! Both the read and the write need only the panel login. A route is not a
//! grant: it is answered to anyone who has already authenticated to this panel,
//! it executes nothing, and it becomes usable only through the relay, which is
//! `full_access` and checks the grant again when the socket opens. What the
//! panel may *do* with a route is therefore not this endpoint's question, and
//! the response does not claim an `editable` it would then have to keep true —
//! the page reads the `stream` capability for that.

use std::collections::HashSet;
use std::sync::Arc;

use ntex::web::{self, HttpRequest, HttpResponse};
use serde::{Deserialize, Serialize};

use super::server::AppState;
use super::server::verify_auth;
use super::ws::audit::{Action, Event, Kind, Outcome, peer_ip};
use crate::core::config::{DesktopProtocol, DesktopTarget};
use crate::core::config_file;

/// The longest a route name may be. It is an identity rather than a label —
/// the panel edits a route by it and the audit subject joins the names of a
/// whole save — so it is bounded where a comment would not be. 64 is the
/// length `useradd` allows an account name, which is the name this is most
/// likely to be typed beside.
const MAX_NAME: usize = 64;

/// The longest a host may be: a DNS name's own limit, so a route can hold
/// anything that could be resolved and nothing that could not.
const MAX_HOST: usize = 253;

/// A host, an account name or a domain may not hold anything below the space
/// bar, and this is where a route that was pasted with a newline in it stops.
/// The address is interpreted by this agent (it is what dials), so a value that
/// could not be one is refused before the browser is told a session may open.
const MAX_IDENT: usize = 256;

#[derive(Serialize)]
struct ListResponse {
    targets: Vec<TargetView>,
    /// Which protocols the panel may offer, and the port each is given when
    /// none is named. Sent rather than hard-coded in the panel so that a
    /// protocol added here — or a default port changed here — reaches every
    /// client, which is the same reason the process page is told which orders
    /// its table leaves available.
    protocols: Vec<ProtocolView>,
}

#[derive(Serialize)]
struct ProtocolView {
    id: &'static str,
    default_port: u16,
}

/// One route as the panel edits it. The same fields as [`DesktopTarget`],
/// which is deliberate: the shape a config file holds and the shape a form
/// edits being the same is what keeps a save from losing a field.
#[derive(Serialize)]
struct TargetView {
    name: String,
    protocol: &'static str,
    host: String,
    port: u16,
    username: Option<String>,
    domain: Option<String>,
    view_only: bool,
    shared: bool,
}

#[derive(Deserialize)]
pub struct ReplaceRequest {
    /// The whole set, in order. A replace rather than a per-route edit, like
    /// `/custom-cmds` and `/push`: the order is what is stored, and a rename
    /// is then an ordinary edit rather than a second operation.
    targets: Vec<DesktopTarget>,
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

    // Off disk rather than off `AppState.config`, which is a startup snapshot:
    // a GET right after a save has to show what was saved.
    let config = match config_file::read() {
        Ok(config) => config,
        Err(e) => return Ok(internal_error(e.to_string())),
    };

    Ok(HttpResponse::Ok().json(&view(&config.get_desktop().targets)))
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
    let ReplaceRequest { targets } = body.into_inner();

    if let Err(e) = validate(&targets) {
        Event::new(Kind::Desktop, Action::Write, Outcome::Error)
            .remote_ip(remote_ip)
            .detail(e.clone())
            .record(&app_state.db)
            .await;
        return Ok(bad_request(e));
    }

    // Held across the whole read-modify-write: `config_file::write` is atomic,
    // but two handlers each reading the same starting state would still lose
    // one of the two changes.
    let _config_guard = app_state.config_write.lock().await;

    let mut config = match config_file::read() {
        Ok(config) => config,
        Err(e) => return Ok(internal_error(e.to_string())),
    };

    // Names never the hosts: the audit subject is what an operator recognises
    // the entry by, and the address is this agent's own network rather than
    // anything a client sent.
    let subject = targets
        .iter()
        .map(|target| format!("{} ({})", target.name, target.protocol.as_str()))
        .collect::<Vec<_>>()
        .join(", ");

    config.desktop = Some(crate::core::config::DesktopConfig {
        targets: targets.clone(),
    });

    if let Err(e) = config_file::write(&config) {
        Event::new(Kind::Desktop, Action::Write, Outcome::Error)
            .remote_ip(remote_ip)
            .detail(e.to_string())
            .record(&app_state.db)
            .await;
        return Ok(internal_error(e.to_string()));
    }

    Event::new(Kind::Desktop, Action::Write, Outcome::Ok)
        .remote_ip(remote_ip)
        .subject(subject)
        .record(&app_state.db)
        .await;
    tracing::info!("Desktop routes saved via PUT /api/v1/desktop");

    // Read back rather than echoing what was sent, like `/push`: what the
    // panel will edit next time is what the file now holds.
    Ok(HttpResponse::Ok().json(&view(&config.get_desktop().targets)))
}

fn view(targets: &[DesktopTarget]) -> ListResponse {
    ListResponse {
        targets: targets
            .iter()
            .map(|target| TargetView {
                name: target.name.clone(),
                protocol: target.protocol.as_str(),
                host: target.host.clone(),
                port: target.port,
                username: target.username.clone(),
                domain: target.domain.clone(),
                view_only: target.view_only,
                shared: target.shared,
            })
            .collect(),
        protocols: [DesktopProtocol::Vnc, DesktopProtocol::Rdp]
            .into_iter()
            .map(|protocol| ProtocolView {
                id: protocol.as_str(),
                default_port: protocol.default_port(),
            })
            .collect(),
    }
}

/// Everything about this set that can be wrong before the machine or the file
/// is touched. The caller's own mistake, so it is a 400 with a code rather
/// than a stored value that fails at connect time — where the only thing to
/// report would be a name that does not resolve.
fn validate(targets: &[DesktopTarget]) -> Result<(), String> {
    let mut seen: HashSet<&str> = HashSet::with_capacity(targets.len());
    for target in targets {
        if target.name.is_empty() || target.name.len() > MAX_NAME || has_control(&target.name) {
            return Err("invalidName".to_string());
        }
        // After the shape check, so a name that is two ways wrong is reported
        // by the rule a reader would look for first.
        if !seen.insert(&target.name) {
            return Err("duplicateName".to_string());
        }
        if target.host.is_empty() || target.host.len() > MAX_HOST || has_space(&target.host) {
            return Err("invalidHost".to_string());
        }
        // A u16 is already the port domain; zero is not: it is not a port a
        // desktop listens on, and the relay would dial it as one.
        if target.port == 0 {
            return Err("invalidPort".to_string());
        }
        if let Some(username) = &target.username
            && (username.len() > MAX_IDENT || has_space(username))
        {
            return Err("invalidUsername".to_string());
        }
        if let Some(domain) = &target.domain
            && (domain.len() > MAX_IDENT || has_space(domain))
        {
            return Err("invalidDomain".to_string());
        }
    }
    Ok(())
}

fn has_space(value: &str) -> bool {
    value.chars().any(char::is_whitespace)
}

fn has_control(value: &str) -> bool {
    value.chars().any(char::is_control)
}

fn bad_request(error: impl Into<String>) -> HttpResponse {
    HttpResponse::BadRequest().json(&ErrorResponse { error: error.into() })
}

fn internal_error(error: impl Into<String>) -> HttpResponse {
    HttpResponse::InternalServerError().json(&ErrorResponse { error: error.into() })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn target(name: &str, host: &str, port: u16) -> DesktopTarget {
        DesktopTarget {
            name: name.to_string(),
            protocol: DesktopProtocol::Vnc,
            host: host.to_string(),
            port,
            username: None,
            domain: None,
            view_only: false,
            shared: true,
        }
    }

    #[test]
    fn a_plain_route_is_accepted() {
        assert_eq!(validate(&[target("desk", "10.0.0.5", 5900)]), Ok(()));
    }

    #[test]
    fn an_empty_set_is_accepted() {
        // Removing the last route is a save, not a mistake.
        assert_eq!(validate(&[]), Ok(()));
    }

    #[test]
    fn a_name_is_bounded_and_unique() {
        assert_eq!(validate(&[target("", "h", 5900)]), Err("invalidName".into()));
        assert_eq!(
            validate(&[target(&"n".repeat(MAX_NAME + 1), "h", 5900)]),
            Err("invalidName".into())
        );
        // The reason it is checked at all: it is an identity, and two routes
        // answering to one name have no way to be told apart in the list.
        assert_eq!(
            validate(&[target("a", "h", 5900), target("a", "h2", 5901)]),
            Err("duplicateName".into())
        );
    }

    #[test]
    fn a_name_may_not_carry_a_line_break() {
        // It reaches the config file and the audit subject, both of which are
        // read one line at a time.
        assert_eq!(validate(&[target("a\nb", "h", 5900)]), Err("invalidName".into()));
    }

    #[test]
    fn a_host_is_bounded_and_may_not_hold_whitespace() {
        assert_eq!(validate(&[target("a", "", 5900)]), Err("invalidHost".into()));
        assert_eq!(
            validate(&[target("a", &"h".repeat(MAX_HOST + 1), 5900)]),
            Err("invalidHost".into())
        );
        // A pasted address with a newline in it is the case this catches: the
        // value is dialled by this agent, not by the browser.
        assert_eq!(validate(&[target("a", "10.0.0.5\n", 5900)]), Err("invalidHost".into()));
        assert_eq!(validate(&[target("a", "10.0.0.5 3389", 5900)]), Err("invalidHost".into()));
    }

    #[test]
    fn port_zero_is_refused() {
        assert_eq!(validate(&[target("a", "h", 0)]), Err("invalidPort".into()));
        // 1 and 65535 are the ends of the range a u16 could hold, and both are
        // accepted: a desktop on 65535 is unusual, not impossible.
        assert_eq!(validate(&[target("a", "h", 1)]), Ok(()));
        assert_eq!(validate(&[target("a", "h", u16::MAX)]), Ok(()));
    }

    #[test]
    fn an_optional_field_may_be_absent_but_not_multiline() {
        let mut ok = target("a", "h", 5900);
        ok.username = Some("admin".to_string());
        ok.domain = Some("CORP".to_string());
        assert_eq!(validate(&[ok]), Ok(()));

        let mut bad = target("a", "h", 5900);
        bad.username = Some("ad\nmin".to_string());
        assert_eq!(validate(&[bad]), Err("invalidUsername".into()));

        let mut bad = target("a", "h", 5900);
        bad.domain = Some("CO RP".to_string());
        assert_eq!(validate(&[bad]), Err("invalidDomain".into()));
    }

    #[test]
    fn the_view_offers_both_protocols_with_their_default_ports() {
        let response = view(&[target("desk", "10.0.0.5", 5900)]);
        assert_eq!(response.targets.len(), 1);
        assert_eq!(response.targets[0].protocol, "vnc");
        let ports: Vec<(&str, u16)> = response
            .protocols
            .iter()
            .map(|p| (p.id, p.default_port))
            .collect();
        assert_eq!(ports, vec![("vnc", 5900), ("rdp", 3389)]);
    }
}
