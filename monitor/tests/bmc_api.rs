//! `/api/v1/bmc`, against the real route table and a fake Redfish service:
//! who may see, control and configure, a password nobody reads back, a pin
//! the agent will not do without, and one session per request.

mod common;

use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use ntex::http::Method;
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use serde_json::{Value, json};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

use common::machine::{audit, call, server};

const LIST: &str = "/api/v1/bmc";

fn fixture(name: &str) -> String {
    format!("{}/../crates/sbm_redfish/tests/fixtures/{name}", env!("CARGO_MANIFEST_DIR"))
}

#[derive(Default)]
struct Seen {
    logins: usize,
    logouts: usize,
    resets: Vec<String>,
    /// Every Authorization / X-Auth-Token header, to assert what was sent.
    passwords: Vec<String>,
}

/// A Redfish service with one system that answers four reset types and a
/// chassis without sensors.
struct FakeBmc {
    addr: SocketAddr,
    seen: Arc<Mutex<Seen>>,
}

impl FakeBmc {
    async fn start() -> Self {
        let certs = CertificateDer::pem_file_iter(fixture("redfish_test_cert.pem"))
            .unwrap()
            .collect::<Result<Vec<_>, _>>()
            .unwrap();
        let key = PrivateKeyDer::from_pem_file(fixture("redfish_test_key.pem")).unwrap();
        let config = rustls::ServerConfig::builder_with_provider(Arc::new(
            rustls::crypto::ring::default_provider(),
        ))
        .with_safe_default_protocol_versions()
        .unwrap()
        .with_no_client_auth()
        .with_single_cert(certs, key)
        .unwrap();
        let acceptor = tokio_rustls::TlsAcceptor::from(Arc::new(config));
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let seen = Arc::new(Mutex::new(Seen::default()));
        let shared = seen.clone();
        tokio::spawn(async move {
            while let Ok((tcp, _)) = listener.accept().await {
                let acceptor = acceptor.clone();
                let seen = shared.clone();
                tokio::spawn(async move {
                    let Ok(mut tls) = acceptor.accept(tcp).await else { return };
                    let Some((method, path, headers, body)) = read_request(&mut tls).await else {
                        return;
                    };
                    let response = handle(&seen, &method, &path, &headers, &body);
                    let _ = tls.write_all(&response).await;
                    let _ = tls.shutdown().await;
                });
            }
        });
        Self { addr, seen }
    }

    fn url(&self) -> String {
        format!("https://127.0.0.1:{}", self.addr.port())
    }

    async fn pin(&self) -> String {
        sbm_redfish::cert::fetch_server_cert("127.0.0.1", self.addr.port(), Duration::from_secs(5))
            .await
            .unwrap()
            .fingerprint
    }
}

type Request = (String, String, Vec<(String, String)>, Vec<u8>);

async fn read_request<S: AsyncReadExt + Unpin>(stream: &mut S) -> Option<Request> {
    let mut buf = Vec::new();
    let mut chunk = [0u8; 4096];
    let end = loop {
        if let Some(i) = buf.windows(4).position(|w| w == b"\r\n\r\n") {
            break i;
        }
        let n = stream.read(&mut chunk).await.ok()?;
        if n == 0 {
            return None;
        }
        buf.extend_from_slice(&chunk[..n]);
    };
    let head = String::from_utf8_lossy(&buf[..end]).to_string();
    let mut lines = head.split("\r\n");
    let mut first = lines.next()?.split(' ');
    let (method, path) = (first.next()?.to_string(), first.next()?.to_string());
    let headers: Vec<(String, String)> = lines
        .filter_map(|l| l.split_once(':'))
        .map(|(k, v)| (k.trim().to_ascii_lowercase(), v.trim().to_string()))
        .collect();
    let length: usize = headers
        .iter()
        .find(|(k, _)| k == "content-length")
        .and_then(|(_, v)| v.parse().ok())
        .unwrap_or(0);
    let mut body = buf[end + 4..].to_vec();
    while body.len() < length {
        let n = stream.read(&mut chunk).await.ok()?;
        if n == 0 {
            break;
        }
        body.extend_from_slice(&chunk[..n]);
    }
    Some((method, path, headers, body))
}

fn respond(status: u16, headers: &[(&str, &str)], body: Option<Value>) -> Vec<u8> {
    let body = body.map(|b| b.to_string()).unwrap_or_default();
    let mut out = format!("HTTP/1.1 {status} X\r\nconnection: close\r\ncontent-length: {}\r\n", body.len());
    if !body.is_empty() {
        out.push_str("content-type: application/json\r\n");
    }
    for (k, v) in headers {
        out.push_str(&format!("{k}: {v}\r\n"));
    }
    out.push_str("\r\n");
    out.push_str(&body);
    out.into_bytes()
}

fn handle(seen: &Mutex<Seen>, method: &str, path: &str, headers: &[(String, String)], body: &[u8]) -> Vec<u8> {
    let mut seen = seen.lock().unwrap();
    let header = |name: &str| headers.iter().find(|(k, _)| k == name).map(|(_, v)| v.clone());
    if method == "POST" && path == "/redfish/v1/SessionService/Sessions" {
        let login: Value = serde_json::from_slice(body).unwrap_or(Value::Null);
        seen.passwords.push(login["Password"].as_str().unwrap_or_default().to_string());
        if login["Password"] != "right" {
            return respond(401, &[], None);
        }
        seen.logins += 1;
        return respond(
            201,
            &[("x-auth-token", "token"), ("location", "/redfish/v1/SessionService/Sessions/1")],
            Some(json!({})),
        );
    }
    if path != "/redfish/v1/" && header("x-auth-token").as_deref() != Some("token") {
        return respond(401, &[], None);
    }
    match (method, path) {
        ("DELETE", "/redfish/v1/SessionService/Sessions/1") => {
            seen.logouts += 1;
            respond(204, &[], None)
        }
        ("GET", "/redfish/v1/") => respond(200, &[], Some(json!({
            "RedfishVersion": "1.6.0",
            "Systems": {"@odata.id": "/redfish/v1/Systems"},
            "Chassis": {"@odata.id": "/redfish/v1/Chassis"},
            "Links": {"Sessions": {"@odata.id": "/redfish/v1/SessionService/Sessions"}},
        }))),
        ("GET", "/redfish/v1/Systems") => respond(200, &[], Some(json!({
            "Members": [{"@odata.id": "/redfish/v1/Systems/1"}],
        }))),
        ("GET", "/redfish/v1/Systems/1") => respond(200, &[], Some(json!({
            "PowerState": "On",
            "Model": "Test",
            "Actions": {"#ComputerSystem.Reset": {
                "target": "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset",
                "ResetType@Redfish.AllowableValues": ["On", "ForceOff", "GracefulShutdown", "GracefulRestart"],
            }},
        }))),
        ("GET", "/redfish/v1/Chassis") => respond(200, &[], Some(json!({"Members": []}))),
        ("POST", "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset") => {
            let reset: Value = serde_json::from_slice(body).unwrap_or(Value::Null);
            seen.resets.push(reset["ResetType"].as_str().unwrap_or_default().to_string());
            respond(204, &[], None)
        }
        _ => respond(404, &[], None),
    }
}

fn target(url: &str, password: Option<&str>, pin: Option<&str>) -> Value {
    json!({"id": "t1", "name": "rack-1", "url": url, "username": "admin",
           "password": password, "cert_sha256": pin})
}

#[ntex::test]
async fn seeing_and_controlling_need_virt_configuring_needs_admin() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::GET, LIST, None).await;
    assert_eq!(status, 401);
    for (method, path, body) in [
        (Method::GET, LIST.to_string(), None),
        (Method::GET, format!("{LIST}/t1"), None),
        (Method::POST, format!("{LIST}/t1/power"), Some(json!({"intent": "forceOff"}))),
    ] {
        let (status, body) = call(&srv, Some("viewer"), method, &path, body).await;
        assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")), "{path}");
    }
    let (status, _) = call(&srv, Some("viewer"), Method::PUT, LIST, Some(json!({"targets": []}))).await;
    assert_eq!(status, 403);
    let (status, _) =
        call(&srv, Some("viewer"), Method::POST, "/api/v1/bmc/probe", Some(json!({"url": "https://h"}))).await;
    assert_eq!(status, 403);

    let details: Vec<_> = audit(&db).await.into_iter().map(|row| row.3.unwrap()).collect();
    assert_eq!(
        details,
        ["bmc list: virt not_granted", "bmc status: virt not_granted", "bmc power forceOff: virt not_granted"]
    );
}

#[ntex::test]
async fn a_password_is_written_never_read_and_kept_when_not_sent() {
    let (srv, db) = server().await;
    let (status, body) =
        call(&srv, Some("admin"), Method::PUT, LIST, Some(json!({"targets": [target("https://10.0.0.9/", Some("secret"), None)]})))
            .await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(
        body["targets"],
        json!([{"id": "t1", "name": "rack-1", "url": "https://10.0.0.9", "username": "admin",
                "has_password": true, "cert_sha256": null}])
    );
    assert!(!body.to_string().contains("secret"));

    // `null` keeps it; renaming does not lose it.
    let renamed = json!({"targets": [{"id": "t1", "name": "rack-2", "url": "https://10.0.0.9",
                                      "username": "admin", "password": null}]});
    let (_, body) = call(&srv, Some("admin"), Method::PUT, LIST, Some(renamed)).await;
    assert_eq!(body["targets"][0]["has_password"], true);
    let stored: Option<String> = sqlx::query_scalar("SELECT password FROM bmc_target WHERE id = 't1'")
        .fetch_one(&db)
        .await
        .unwrap();
    assert_eq!(stored.as_deref(), Some("secret"));

    let (status, body) = call(&srv, Some("admin"), Method::PUT, LIST,
        Some(json!({"targets": [target("http://10.0.0.9", None, None)]}))).await;
    assert_eq!((status, body), (400, json!({"error": "invalidUrl", "index": 0})));
}

#[ntex::test]
async fn an_unpinned_target_is_not_dialled() {
    let bmc = FakeBmc::start().await;
    let (srv, _) = server().await;
    call(&srv, Some("admin"), Method::PUT, LIST, Some(json!({"targets": [target(&bmc.url(), Some("right"), None)]}))).await;
    let (status, body) = call(&srv, Some("admin"), Method::GET, &format!("{LIST}/t1"), None).await;
    assert_eq!((status, body["failure"].as_str()), (502, Some("certNotReviewed")), "{body}");
    assert!(bmc.seen.lock().unwrap().passwords.is_empty(), "the password went nowhere");

    let (status, body) = call(&srv, Some("admin"), Method::GET, &format!("{LIST}/nope"), None).await;
    assert_eq!((status, body["error"].as_str()), (404, Some("noSuchTarget")));
}

#[ntex::test]
async fn a_pinned_target_answers_its_state_and_a_power_action() {
    let bmc = FakeBmc::start().await;
    let (srv, db) = server().await;

    let (status, probed) =
        call(&srv, Some("admin"), Method::POST, "/api/v1/bmc/probe", Some(json!({"url": bmc.url()}))).await;
    assert_eq!(status, 200, "{probed}");
    let pin = bmc.pin().await;
    assert_eq!(probed["fingerprint"], pin);
    assert_eq!(bmc.seen.lock().unwrap().logins, 0, "a probe signs nothing in");

    call(&srv, Some("admin"), Method::PUT, LIST,
        Some(json!({"targets": [target(&bmc.url(), Some("right"), Some(&pin))]}))).await;

    let (status, body) = call(&srv, Some("admin"), Method::GET, &format!("{LIST}/t1"), None).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["snapshot"]["topology"]["system"]["power_state"], "on");
    assert_eq!(body["intents"], json!(["on", "gracefulShutdown", "forceOff", "restart"]));

    let (status, body) = call(&srv, Some("admin"), Method::POST, &format!("{LIST}/t1/power"),
        Some(json!({"intent": "restart"}))).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["outcome"]["kind"], "done");

    {
        let seen = bmc.seen.lock().unwrap();
        assert_eq!(seen.resets, ["GracefulRestart"]);
        assert_eq!((seen.logins, seen.logouts), (2, 2), "one session per request, given back");
    }

    let rows = audit(&db).await;
    let details: Vec<_> = rows.iter().map(|row| row.3.clone().unwrap()).collect();
    assert_eq!(details, ["bmc replace: rack-1", "bmc power restart t1"]);
}

#[ntex::test]
async fn a_wrong_password_is_the_bmcs_refusal_not_the_panels() {
    let bmc = FakeBmc::start().await;
    let (srv, _) = server().await;
    let pin = bmc.pin().await;
    call(&srv, Some("admin"), Method::PUT, LIST,
        Some(json!({"targets": [target(&bmc.url(), Some("wrong"), Some(&pin))]}))).await;
    let (status, body) = call(&srv, Some("admin"), Method::GET, &format!("{LIST}/t1"), None).await;
    // Not 401: that would log the panel out of this agent.
    assert_eq!((status, body["failure"].as_str()), (502, Some("unauthorized")), "{body}");
    assert!(!body.to_string().contains("wrong"));
}
