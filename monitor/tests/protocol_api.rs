//! The protocol check on `/api/v1` (`api::protocol`) and what `/health`
//! tells a client before it signs in.

mod common;

use common::machine::{SECRET, server};
use ntex::http::Method;
use ntex::web::test::TestServer;
use sbm_parser::protocol::{HEADER, MIN_CLIENT_PROTOCOL, PROTOCOL};
use serde_json::Value;
use server_box_monitor::api::auth::generate_token;

/// [path] signed in, naming [protocol] when given, with [upgrade] asking
/// for a WebSocket.
async fn call(srv: &TestServer, method: Method, path: &str, protocol: Option<&str>, upgrade: bool) -> (u16, Value) {
    let mut req = srv
        .request(method, srv.url(path))
        .header("Authorization", format!("Bearer {}", generate_token(SECRET).unwrap()));
    if let Some(p) = protocol {
        req = req.header(HEADER, p);
    }
    if upgrade {
        req = req.header("Upgrade", "websocket");
    }
    let resp = req.send().await.unwrap();
    let status = resp.status().as_u16();
    let bytes = resp.body().await.unwrap_or_default();
    (status, serde_json::from_slice(&bytes).unwrap_or(Value::Null))
}

fn too_old() -> String {
    (MIN_CLIENT_PROTOCOL - 1).to_string()
}

#[ntex::test]
async fn health_names_the_protocol_but_not_the_release() {
    let (srv, _) = server().await;
    let (status, body) = call(&srv, Method::GET, "/api/v1/health", None, false).await;
    assert_eq!(status, 200);
    assert_eq!(body["protocol"], PROTOCOL);
    assert_eq!(body["min_client_protocol"], MIN_CLIENT_PROTOCOL);
    assert!(body.get("version").is_none(), "{body}");
}

#[ntex::test]
async fn a_client_from_before_the_header_is_answered() {
    let (srv, _) = server().await;
    assert_eq!(call(&srv, Method::GET, "/api/v1/capabilities", None, false).await.0, 200);
    let current = PROTOCOL.to_string();
    assert_eq!(call(&srv, Method::GET, "/api/v1/capabilities", Some(&current), false).await.0, 200);
}

#[ntex::test]
async fn a_client_too_old_is_told_so() {
    let (srv, _) = server().await;
    for path in ["/api/v1/capabilities", "/api/v1/login"] {
        let method = if path.ends_with("login") { Method::POST } else { Method::GET };
        let (status, body) = call(&srv, method, path, Some(&too_old()), false).await;
        assert_eq!(status, 426, "{path}");
        assert_eq!(body["error"], "client_too_old");
        assert_eq!(body["min_client_protocol"], MIN_CLIENT_PROTOCOL);
    }
    let (status, _) = call(&srv, Method::POST, "/api/v1/ws-ticket", Some(&too_old()), false).await;
    assert_eq!(status, 426, "the ticket before an upgrade is where a WebSocket is checked");
}

#[ntex::test]
async fn health_preflights_and_upgrades_are_not_checked() {
    let (srv, _) = server().await;
    assert_eq!(call(&srv, Method::GET, "/api/v1/health", Some(&too_old()), false).await.0, 200);
    assert_ne!(call(&srv, Method::OPTIONS, "/api/v1/capabilities", Some(&too_old()), false).await.0, 426);
    assert_ne!(call(&srv, Method::GET, "/api/v1/stream/ws", Some(&too_old()), true).await.0, 426);
}

#[ntex::test]
async fn an_upgrade_header_alone_exempts_nothing() {
    let (srv, _) = server().await;
    assert_eq!(call(&srv, Method::GET, "/api/v1/capabilities", Some(&too_old()), true).await.0, 426);
}

#[ntex::test]
async fn a_protocol_that_is_not_a_number_is_refused() {
    let (srv, _) = server().await;
    let (status, body) = call(&srv, Method::GET, "/api/v1/capabilities", Some("two"), false).await;
    assert_eq!(status, 400);
    assert_eq!(body["error"], "bad_protocol");
}
