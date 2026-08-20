//! Shared admission control for the WebSocket endpoints.
//!
//! Everything here runs before an upgrade is accepted, and none of it depends
//! on which endpoint is being opened.

pub mod audit;
pub mod session;
pub mod terminal;
pub mod ticket;

use std::net::IpAddr;

use ntex::http::header;
use ntex::web::HttpRequest;

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
