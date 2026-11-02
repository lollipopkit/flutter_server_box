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

// TODO: remove when MIN_CLIENT_PROTOCOL reaches 2, with `api::compat_v1`.
/// A client at protocol 1 (or naming none) still reads `remote_access` and
/// `grants`, each what `access` says; one at 2 reads `access` alone.
#[ntex::test]
async fn capabilities_answer_a_first_protocol_client_in_its_shape() {
    let (srv, _) = server().await;
    for protocol in [None, Some("1")] {
        let (status, body) = call(&srv, Method::GET, "/api/v1/capabilities", protocol, false).await;
        assert_eq!(status, 200, "{protocol:?}");
        // The test server is loopback: acting is allowed.
        assert_eq!(body["access"]["ok"], true, "{body}");
        for grant in ["shell", "files", "connect", "listen", "virt"] {
            assert_eq!(body["grants"][grant]["ok"], true, "{grant}: {body}");
        }
        assert_eq!(body["grants"]["files"]["mode"], "write");
        assert_eq!(body["grants"]["ssh_terminal"], serde_json::json!({ "ok": false, "why": "not_granted" }));
        for flag in ["terminal", "full_access", "files", "stream", "listen"] {
            assert_eq!(body["remote_access"][flag], true, "{flag}: {body}");
        }
        assert!(body.get("me").is_none(), "no accounts to manage: {body}");
    }
    let (status, body) = call(&srv, Method::GET, "/api/v1/capabilities", Some(&PROTOCOL.to_string()), false).await;
    assert_eq!(status, 200);
    assert_eq!(body["access"]["ok"], true);
    for gone in ["grants", "remote_access", "me"] {
        assert!(body.get(gone).is_none(), "{gone}: {body}");
    }
}

/// Over a link that may not act, the first protocol's grants say why.
#[test]
fn a_refused_link_is_refused_grant_by_grant() {
    let mut body = serde_json::json!({ "access": { "ok": false, "why": "insecure_transport" } });
    server_box_monitor::api::compat_v1::capabilities(&mut body);
    assert_eq!(body["grants"]["shell"], serde_json::json!({ "ok": false, "why": "insecure_transport" }));
    assert_eq!(body["grants"]["files"], serde_json::json!({ "ok": false, "why": "insecure_transport", "mode": "write" }));
    assert_eq!(body["remote_access"]["full_access"], false);
    // A watch token's `access` names no reason.
    let mut body = serde_json::json!({ "access": { "ok": false } });
    server_box_monitor::api::compat_v1::capabilities(&mut body);
    assert_eq!(body["grants"]["virt"]["why"], "not_granted");
}

// TODO: remove when MIN_CLIENT_PROTOCOL reaches 2, with `api::compat_v1`.
/// `/bmc` says `editable` to a first-protocol client only.
#[ntex::test]
async fn bmc_answers_a_first_protocol_client_in_its_shape() {
    let (srv, _) = server().await;
    for protocol in [None, Some("1")] {
        let (status, body) = call(&srv, Method::GET, "/api/v1/bmc", protocol, false).await;
        assert_eq!(status, 200, "{protocol:?}: {body}");
        assert_eq!(body["editable"], true, "{body}");
        assert!(body["targets"].is_array());
    }
    let (status, body) = call(&srv, Method::GET, "/api/v1/bmc", Some(&PROTOCOL.to_string()), false).await;
    assert_eq!(status, 200);
    assert!(body.get("editable").is_none(), "{body}");
    assert!(body["targets"].is_array());
}
