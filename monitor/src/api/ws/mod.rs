//! Shared admission control for the WebSocket endpoints.
//!
//! Everything here runs before an upgrade is accepted, and none of it depends
//! on which endpoint is being opened.

pub mod audit;
pub mod listen;
pub mod live;
pub mod rdcleanpath;
pub mod session;
pub mod stream;
pub mod terminal;
pub mod ticket;
pub mod upgrade;
pub mod virt_console;

use std::fmt;
use std::net::IpAddr;
use std::sync::Arc;

use ntex::http::header;
use ntex::service::Service;
use ntex::util::ByteString;
use ntex::web::ws::{self, Frame, Message};
use ntex::web::{HttpRequest, HttpResponse};

use crate::api::WebError;
use crate::api::authz;
use crate::api::server::AppState;

pub(crate) const TICKET_PROTOCOL_PREFIX: &str = "sbm-ticket.";

/// Encodes a control frame as JSON text; falls back to `{}` rather than
/// dropping the socket if serialization ever failed.
pub(crate) fn json_frame(msg: &impl serde::Serialize) -> Message {
    let json = serde_json::to_string(msg).unwrap_or_else(|_| "{}".to_string());
    Message::Text(ByteString::from(json))
}

pub(crate) fn pong_frame() -> Message {
    Message::Text(ByteString::from_static("{\"type\":\"pong\"}"))
}

/// Verified WebSocket handshake admission, before the HTTP upgrade runs.
pub(crate) struct AdmittedWs {
    pub(crate) protocol: String,
    pub(crate) raw_ticket: String,
    pub(crate) reservation: ticket::TicketReservation,
    pub(crate) remote_ip: Option<String>,
    pub(crate) secure: bool,
    pub(crate) since: i64,
}

/// Shared caller context retained for the lifetime of an upgraded WebSocket so
/// mid-stream rechecks see password changes or transport-rule changes.
pub(crate) struct WsCallerCtx {
    pub(crate) state: Arc<AppState>,
    pub(crate) remote_ip: Option<String>,
    pub(crate) secure: bool,
    pub(crate) since: i64,
}

impl WsCallerCtx {
    /// Re-reads the caller, returning `None` if the password has changed since
    /// the handshake.
    pub(crate) async fn caller(&self) -> Option<authz::Caller> {
        authz::caller(&self.state)
            .await
            .filter(|caller| caller.since == self.since)
    }

    /// Checks that the caller's password has not changed and the transport
    /// policy still allows acting on the host.
    pub(crate) async fn check(&self) -> Result<(), &'static str> {
        match self.caller().await {
            Some(caller) => caller
                .check(&self.state, self.secure)
                .map_err(|why| why.as_str()),
            None => Err("password_changed"),
        }
    }

    pub(crate) async fn still_admitted(&self) -> bool {
        self.check().await.is_ok()
    }
}

/// Runs origin validation, single-use ticket reservation, and caller admission
/// before a WebSocket upgrade. Denied attempts are audited with `kind` (and
/// optional `detail_prefix`).
pub(crate) async fn admit_ws(
    req: &HttpRequest,
    app_state: &Arc<AppState>,
    purpose: ticket::Purpose,
    kind: audit::Kind,
    detail_prefix: Option<&str>,
) -> Result<AdmittedWs, HttpResponse> {
    let remote_ip = audit::peer_ip(req);
    let deny = async |reason: &'static str, status: HttpResponse| {
        let detail = match detail_prefix {
            Some(prefix) => format!("{prefix}: {reason}"),
            None => reason.to_string(),
        };
        audit::Event::new(kind, audit::Action::Denied, audit::Outcome::Denied)
            .remote_ip(remote_ip.clone())
            .detail(detail)
            .record(&app_state.db)
            .await;
        Err(status)
    };

    let secure = is_secure_transport(req, app_state.tls_active);
    if !origin_allowed(req, &app_state.config.get_server().cors_allowed_origins) {
        return deny("origin", HttpResponse::Unauthorized().build()).await;
    }

    let Some(protocol) = ws::subprotocols(req)
        .find(|value| value.starts_with(TICKET_PROTOCOL_PREFIX))
        .map(str::to_owned)
    else {
        return deny("no ticket", HttpResponse::Unauthorized().build()).await;
    };
    let raw_ticket = protocol[TICKET_PROTOCOL_PREFIX.len()..].to_owned();
    let Ok(reservation) = app_state.tickets.reserve(&raw_ticket, purpose) else {
        return deny("ticket", HttpResponse::Unauthorized().build()).await;
    };

    let admitted = authz::caller(app_state)
        .await
        .filter(|caller| caller.check(app_state, secure).is_ok());
    let Some(admitted) = admitted else {
        app_state.tickets.rollback(reservation);
        return deny("not admitted", HttpResponse::Forbidden().build()).await;
    };

    Ok(AdmittedWs {
        protocol,
        raw_ticket,
        reservation,
        remote_ip,
        secure,
        since: admitted.since,
    })
}

/// Performs the WebSocket upgrade and commits or rolls back `reservation`
/// depending on whether the handshake succeeded.
pub(crate) async fn upgrade_with_ticket<S>(
    req: &HttpRequest,
    tickets: &Arc<ticket::TicketStore>,
    protocol: &str,
    reservation: ticket::TicketReservation,
    service: impl FnOnce(upgrade::WsSink) -> S,
) -> Result<HttpResponse, WebError>
where
    S: Service<upgrade::WsSink, Frame, Res = Option<Message>> + 'static,
    S::Error: fmt::Debug + 'static,
{
    let upgraded = upgrade::start(req, Some(protocol), service).await;
    if upgraded.is_ok() {
        tickets.commit(reservation);
    } else {
        tickets.rollback(reservation);
    }
    upgraded
}

/// Whether this request reached us over a link that can't be passively read.
///
/// Two ways that holds:
///
/// - the listener itself terminates TLS, or
/// - the peer is on loopback, which is how every same-host reverse proxy shows
///   up (nginx, Caddy, `cloudflared`). Those deployments
///   are genuinely encrypted end to end even though monitor's own socket is
///   plaintext, and refusing them would push people to `allow_insecure`,
///   which would then also switch the check off for setups that really are
///   in the clear.
///
/// Deliberately does **not** consult `X-Forwarded-Proto`: that header is set
/// by whoever is talking to us, so trusting it turns the check into a
/// formality. Loopback can't be spoofed from off-host.
///
/// A proxy on a *different* host counts as insecure, because the leg between
/// it and this agent really does cross a network in the clear.
pub fn is_secure_transport(req: &HttpRequest, tls_active: bool) -> bool {
    secure_transport(tls_active, req.peer_addr().map(|addr| addr.ip()))
}

/// The rule itself, separated from pulling the peer address out of the
/// request: ntex's `TestRequest` accepts a `peer_addr` but never applies it
/// (its own tests assert `peer_addr()` stays `None`), so the loopback branch
/// is only reachable in a test through the pure form.
fn secure_transport(tls_active: bool, peer: Option<IpAddr>) -> bool {
    tls_active || peer.is_some_and(|ip| ip.is_loopback())
}

/// Whether a browser-originated upgrade may proceed.
///
/// The CORS middleware does nothing here — the same-origin policy never
/// applied to WebSockets, so a page on any site can open one against this
/// agent and the browser will let it. What stops that being useful is that
/// authorisation is a single-use ticket the attacking page has no way to
/// obtain (there are no cookies to ride on). This check is the second layer:
/// it keeps a hostile page from even reaching the handler.
///
/// A missing `Origin` is allowed: browsers always send one on a WebSocket
/// handshake, so its absence means a native client — the app — which isn't
/// subject to the confused-deputy problem this guards against.
pub fn origin_allowed(req: &HttpRequest, allowed_origins: &[String]) -> bool {
    let Some(origin) = req
        .headers()
        .get(header::ORIGIN)
        .and_then(|v| v.to_str().ok())
    else {
        return true;
    };

    if allowed_origins.iter().any(|a| a == origin) {
        return true;
    }

    // Same-origin: the panel served by this agent. Compare authorities rather
    // than whole URLs, since the scheme the browser saw isn't observable here
    // when a proxy terminated TLS.
    let Some((_, authority)) = origin.split_once("://") else {
        return false;
    };
    req.headers()
        .get(header::HOST)
        .and_then(|v| v.to_str().ok())
        .is_some_and(|host| host == authority)
}

#[cfg(test)]
mod tests {
    use super::*;
    use ntex::web::test::TestRequest;

    fn origins() -> Vec<String> {
        vec!["https://panel.example.com".to_string()]
    }

    fn ip(s: &str) -> Option<IpAddr> {
        Some(s.parse().unwrap())
    }

    #[test]
    fn tls_listener_is_always_secure() {
        assert!(secure_transport(true, None));
        assert!(secure_transport(true, ip("203.0.113.7")));
    }

    #[test]
    fn a_plaintext_listener_without_a_peer_address_is_not_trusted() {
        // No peer address means we can't tell where it came from; the safe
        // reading is "not loopback".
        assert!(!secure_transport(false, None));
    }

    #[test]
    fn a_loopback_peer_counts_as_secure_on_a_plaintext_listener() {
        assert!(secure_transport(false, ip("127.0.0.1")));
        assert!(secure_transport(false, ip("127.0.0.53")));
        assert!(secure_transport(false, ip("::1")));
    }

    #[test]
    fn a_remote_peer_on_a_plaintext_listener_is_insecure() {
        assert!(!secure_transport(false, ip("192.168.1.20")));
        assert!(!secure_transport(false, ip("203.0.113.7")));
        assert!(!secure_transport(false, ip("fd00::1")));
    }

    #[test]
    fn forwarded_proto_is_never_consulted() {
        // The rule takes no headers at all, by construction: a client-supplied
        // header must not be able to assert its own security.
        let req = TestRequest::default()
            .header("X-Forwarded-Proto", "https")
            .to_http_request();
        assert!(!is_secure_transport(&req, false));
    }

    #[test]
    fn a_missing_origin_is_a_native_client() {
        let req = TestRequest::default().to_http_request();
        assert!(origin_allowed(&req, &origins()));
        assert!(origin_allowed(&req, &[]));
    }

    #[test]
    fn a_configured_origin_is_allowed() {
        let req = TestRequest::default()
            .header("Origin", "https://panel.example.com")
            .to_http_request();
        assert!(origin_allowed(&req, &origins()));
    }

    #[test]
    fn an_unknown_origin_is_refused() {
        let req = TestRequest::default()
            .header("Origin", "https://evil.example.com")
            .header("Host", "agent.example.com")
            .to_http_request();
        assert!(!origin_allowed(&req, &origins()));
    }

    #[test]
    fn the_agents_own_panel_is_allowed_without_being_configured() {
        let req = TestRequest::default()
            .header("Origin", "https://agent.example.com:3770")
            .header("Host", "agent.example.com:3770")
            .to_http_request();
        assert!(origin_allowed(&req, &[]));
    }

    #[test]
    fn a_prefix_of_the_host_is_not_the_same_origin() {
        // Guards against matching by `ends_with`/`contains`
        let req = TestRequest::default()
            .header("Origin", "https://evil-agent.example.com")
            .header("Host", "agent.example.com")
            .to_http_request();
        assert!(!origin_allowed(&req, &[]));
    }

    #[test]
    fn a_malformed_origin_is_refused() {
        let req = TestRequest::default()
            .header("Origin", "agent.example.com")
            .header("Host", "agent.example.com")
            .to_http_request();
        assert!(!origin_allowed(&req, &[]));
    }
}
