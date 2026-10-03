//! `/api/v1/virt`, against the real route table and a fake PVE API over TLS:
//! who may see, control and configure, secrets nobody reads back, a
//! certificate shown and pinned before the token is sent, and a power action
//! that waits for its task.
//!
//! The libvirt half is asserted for its shape only: whatever the machine
//! running the suite has (no `virsh`, or one refusing this account), the
//! answer says so rather than failing, and no guest is ever acted on.

mod common;

use std::net::SocketAddr;
use std::sync::{Arc, Mutex};

use ntex::http::Method;
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use serde_json::{Value, json};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

use common::machine::{audit, call, server};

const UPID: &str = "UPID:pve:0001:0002:0003:qmshutdown:100:root@pam:";

fn fixture(name: &str) -> String {
    // A self-signed leaf, the one the BMC tests serve.
    format!("{}/../crates/sbm_redfish/tests/fixtures/{name}", env!("CARGO_MANIFEST_DIR"))
}

#[derive(Default)]
struct Seen {
    /// `METHOD path` of every request.
    paths: Vec<String>,
    /// Every Authorization header.
    auth: Vec<String>,
}

/// A PVE API with one running VM, answering a token.
struct FakePve {
    addr: SocketAddr,
    seen: Arc<Mutex<Seen>>,
}

impl FakePve {
    async fn start() -> Self {
        let certs = CertificateDer::pem_file_iter(fixture("redfish_test_cert.pem"))
            .unwrap()
            .collect::<Result<Vec<_>, _>>()
            .unwrap();
        let key = PrivateKeyDer::from_pem_file(fixture("redfish_test_key.pem")).unwrap();
        let config = rustls::ServerConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
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
                let (acceptor, seen) = (acceptor.clone(), shared.clone());
                tokio::spawn(async move {
                    let Ok(mut tls) = acceptor.accept(tcp).await else { return };
                    let Some((method, path, auth)) = read_request(&mut tls).await else { return };
                    let response = handle(&seen, &method, &path, auth);
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
}

async fn read_request<S: AsyncReadExt + Unpin>(stream: &mut S) -> Option<(String, String, Option<String>)> {
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
    let auth = lines
        .filter_map(|l| l.split_once(':'))
        .find(|(k, _)| k.trim().eq_ignore_ascii_case("authorization"))
        .map(|(_, v)| v.trim().to_string());
    // The bodies here are a few bytes of form, read with the head or not at
    // all; nothing below looks at them.
    Some((method, path, auth))
}

fn respond(status: u16, data: Value) -> Vec<u8> {
    let body = json!({ "data": data }).to_string();
    format!(
        "HTTP/1.1 {status} X\r\nconnection: close\r\ncontent-type: application/json\r\ncontent-length: {}\r\n\r\n{body}",
        body.len()
    )
    .into_bytes()
}

fn handle(seen: &Mutex<Seen>, method: &str, path: &str, auth: Option<String>) -> Vec<u8> {
    let mut seen = seen.lock().unwrap();
    seen.paths.push(format!("{method} {path}"));
    let Some(auth) = auth else { return respond(401, Value::Null) };
    seen.auth.push(auth.clone());
    if auth != "PVEAPIToken=root@pam!panel=s3cret" {
        return respond(401, Value::Null);
    }
    let path = path.trim_start_matches("/api2/json");
    match (method, path) {
        ("GET", "/version") => respond(200, json!({"version": "9.2.2"})),
        ("GET", "/cluster/resources") => respond(
            200,
            json!([
                {"id": "qemu/100", "type": "qemu", "vmid": 100, "node": "pve", "name": "web",
                 "status": "running", "maxcpu": 2, "maxmem": 2147483648u64, "cpu": 0.5, "mem": 1073741824u64,
                 "uptime": 600},
                {"id": "node/pve", "type": "node", "node": "pve", "status": "online", "maxcpu": 8}
            ]),
        ),
        ("POST", "/nodes/pve/qemu/100/status/shutdown") => respond(200, json!(UPID)),
        ("GET", p) if p.starts_with("/nodes/pve/tasks/") => respond(200, json!({"status": "stopped", "exitstatus": "OK"})),
        ("GET", "/nodes/pve/qemu/100/status/current") => respond(200, json!({"status": "stopped", "qmpstatus": "stopped"})),
        ("POST", "/nodes/pve/qemu/100/vncproxy") => {
            respond(200, json!({"port": "5900", "ticket": "PVEVNC:x", "user": "root@pam!panel", "password": "abcdefghij"}))
        }
        ("GET", "/nodes/pve/qemu/100/config") => respond(200, json!({"scsi0": "local-lvm:vm-100-disk-0,size=8G", "net0": "virtio=BC:24:11:00:00:01,bridge=vmbr0", "ostype": "l26"})),
        ("GET", p) if p.starts_with("/nodes/pve/qemu/100/rrddata") => {
            respond(200, json!([{"time": 1700000060, "cpu": 0.5}, {"time": 1700000000, "cpu": 0.25}]))
        }
        _ => respond(404, Value::Null),
    }
}

fn token_config(url: &str, pin: Option<&str>) -> Value {
    json!({"addr": url, "auth": "token", "token_id": "root@pam!panel", "token_secret": "s3cret", "cert_sha256": pin})
}

#[ntex::test]
async fn seeing_and_controlling_need_virt_configuring_needs_admin() {
    let (srv, db) = server().await;
    let (status, _) = call(&srv, None, Method::POST, "/api/v1/virt", Some(json!({}))).await;
    assert_eq!(status, 401);
    for (method, path, body) in [
        (Method::POST, "/api/v1/virt", Some(json!({}))),
        (Method::POST, "/api/v1/virt/power", Some(json!({"guest": "qemu/100", "action": "force_stop"}))),
        (Method::GET, "/api/v1/virt/pve", None),
        (Method::POST, "/api/v1/virt/pve/tfa", Some(json!({"code": "123456"}))),
    ] {
        let (status, body) = call(&srv, Some("viewer"), method, path, body).await;
        assert_eq!((status, body["error"].as_str()), (403, Some("forbidden")), "{path}");
    }
    for (method, path, body) in [
        (Method::PUT, "/api/v1/virt/pve", Some(token_config("https://127.0.0.1:8006", None))),
        (Method::DELETE, "/api/v1/virt/pve", None),
        (Method::POST, "/api/v1/virt/pve/cert", Some(json!({"fingerprint": "ab"}))),
    ] {
        let (status, _) = call(&srv, Some("viewer"), method, path, body).await;
        assert_eq!(status, 403, "{path}");
    }
    let details: Vec<_> = audit(&db).await.into_iter().map(|row| row.3.unwrap()).collect();
    assert_eq!(
        details,
        [
            "virt load: virt not_granted",
            "virt force_stop qemu/100: virt not_granted",
            "virt pve: virt not_granted",
            "virt pve tfa: virt not_granted",
        ]
    );
}

#[ntex::test]
async fn secrets_are_written_never_read_and_kept_when_not_sent() {
    let (srv, db) = server().await;
    let (status, body) = call(&srv, Some("admin"), Method::GET, "/api/v1/virt/pve", None).await;
    assert_eq!((status, &body["configured"], &body["editable"]), (200, &json!(false), &json!(true)));

    let (status, body) =
        call(&srv, Some("admin"), Method::PUT, "/api/v1/virt/pve", Some(token_config("https://127.0.0.1:8006/", None))).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["addr"], "https://127.0.0.1:8006");
    assert_eq!((&body["has_token_secret"], &body["token_id"]), (&json!(true), &json!("root@pam!panel")));
    assert!(!body.to_string().contains("s3cret"));

    // `null` keeps it, and so does switching to a password and back.
    let password = json!({"addr": "https://127.0.0.1:8006", "auth": "password", "username": "root",
                          "password": "pw", "token_id": "root@pam!panel", "token_secret": null});
    let (_, body) = call(&srv, Some("admin"), Method::PUT, "/api/v1/virt/pve", Some(password)).await;
    assert_eq!((&body["auth"], &body["has_password"], &body["has_token_secret"]), (&json!("password"), &json!(true), &json!(true)));
    let stored: (Option<String>, Option<String>) =
        sqlx::query_as("SELECT password, token_secret FROM virt_pve WHERE id = 1").fetch_one(&db).await.unwrap();
    assert_eq!(stored, (Some("pw".into()), Some("s3cret".into())));

    for (body, code) in [
        (token_config("http://127.0.0.1:8006", None), "invalidAddr"),
        (json!({"addr": "https://h", "auth": "token", "token_id": "root"}), "invalidTokenId"),
        (json!({"addr": "https://h", "auth": "password"}), "invalidUsername"),
        (token_config("https://h", Some("zz")), "invalidCertificate"),
    ] {
        let (status, answer) = call(&srv, Some("admin"), Method::PUT, "/api/v1/virt/pve", Some(body.clone())).await;
        assert_eq!((status, answer["error"].as_str()), (400, Some(code)), "{body}");
    }

    let (status, body) = call(&srv, Some("admin"), Method::DELETE, "/api/v1/virt/pve", None).await;
    assert_eq!((status, &body["configured"]), (200, &json!(false)));
}

#[ntex::test]
async fn an_unpinned_certificate_is_shown_and_nothing_is_sent_until_it_is_pinned() {
    let pve = FakePve::start().await;
    let (srv, db) = server().await;
    call(&srv, Some("admin"), Method::PUT, "/api/v1/virt/pve", Some(token_config(&pve.url(), None))).await;

    let (status, body) = call(&srv, Some("admin"), Method::POST, "/api/v1/virt", Some(json!({}))).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!((&body["host"], &body["pve_configured"]), (&json!("pve"), &json!(true)));
    assert_eq!(body["error"]["kind"], "cert_unconfirmed", "{body}");
    let fingerprint = body["error"]["cert"]["fingerprint"].as_str().unwrap().to_owned();
    assert!(pve.seen.lock().unwrap().auth.is_empty(), "the token went nowhere");

    // Only what was presented, and only an admin.
    let (_, wrong) =
        call(&srv, Some("admin"), Method::POST, "/api/v1/virt/pve/cert", Some(json!({"fingerprint": "ab".repeat(32)}))).await;
    assert_eq!(wrong["error"]["detail"]["code"], "cert_not_presented", "{wrong}");
    let (status, pinned) =
        call(&srv, Some("admin"), Method::POST, "/api/v1/virt/pve/cert", Some(json!({"fingerprint": fingerprint}))).await;
    assert_eq!((status, &pinned["error"]), (200, &Value::Null), "{pinned}");
    let (_, config) = call(&srv, Some("admin"), Method::GET, "/api/v1/virt/pve", None).await;
    assert_eq!(config["cert_sha256"], fingerprint);

    let (_, body) = call(&srv, Some("admin"), Method::POST, "/api/v1/virt", Some(json!({}))).await;
    assert_eq!(body["error"], Value::Null, "{body}");
    let view = &body["view"];
    assert_eq!(view["host"]["kind"], "pve");
    assert_eq!(view["host"]["version"], "9.2.2");
    assert_eq!(view["guests"][0]["id"], "qemu/100");
    assert_eq!(view["guests"][0]["state"], "running");
    assert_eq!(view["guests"][0]["actions"], json!(["shutdown", "reboot", "force_stop", "suspend"]));
    assert_eq!(view["capabilities"]["lxc"], true);

    let details: Vec<_> = audit(&db).await.into_iter().map(|row| row.3.unwrap()).collect();
    assert_eq!(details, [format!("virt pve set: {} (token)", pve.url()), format!("virt pve pin: {fingerprint}")]);
}

#[ntex::test]
async fn a_power_action_waits_for_its_task_and_is_recorded() {
    let pve = FakePve::start().await;
    let (srv, db) = server().await;
    let pin = sbm_redfish::cert::fetch_server_cert("127.0.0.1", pve.addr.port(), std::time::Duration::from_secs(5))
        .await
        .unwrap()
        .fingerprint;
    call(&srv, Some("admin"), Method::PUT, "/api/v1/virt/pve", Some(token_config(&pve.url(), Some(&pin)))).await;

    let (status, body) = call(
        &srv,
        Some("admin"),
        Method::POST,
        "/api/v1/virt/power",
        Some(json!({"guest": "qemu/100", "action": "shutdown"})),
    )
    .await;
    assert_eq!((status, &body["error"]), (200, &Value::Null), "{body}");
    let paths = pve.seen.lock().unwrap().paths.clone();
    assert!(paths.iter().any(|p| p == "POST /api2/json/nodes/pve/qemu/100/status/shutdown"), "{paths:?}");
    assert!(paths.iter().any(|p| p.contains("/tasks/UPID%3Apve")), "{paths:?}");
    // What PVE said right after the task, laid over its lagging listing.
    let (_, body) = call(&srv, Some("admin"), Method::POST, "/api/v1/virt", Some(json!({}))).await;
    assert_eq!(body["view"]["guests"][0]["state"], "stopped", "{body}");

    // An action the guest does not offer is refused before it is sent.
    let (_, body) = call(
        &srv,
        Some("admin"),
        Method::POST,
        "/api/v1/virt/power",
        Some(json!({"guest": "qemu/100", "action": "resume"})),
    )
    .await;
    assert_eq!(body["error"]["kind"], "unsupported", "{body}");

    let details: Vec<_> = audit(&db).await.into_iter().filter_map(|row| row.3).collect();
    assert!(details.contains(&"virt shutdown qemu/100".to_owned()), "{details:?}");
    assert!(details.contains(&"virt resume qemu/100: Unsupported".to_owned()), "{details:?}");
}

#[ntex::test]
async fn a_machine_without_a_configuration_answers_what_it_found() {
    let (srv, _) = server().await;
    let (status, body) = call(&srv, Some("admin"), Method::POST, "/api/v1/virt", Some(json!({}))).await;
    assert_eq!(status, 200, "{body}");
    assert_eq!(body["pve_configured"], false);
    assert!(body["supported"].is_boolean(), "{body}");
    // None, PVE not set up, or a libvirt (listed, or refused with a kind).
    match body["host"].as_str() {
        None | Some("pve") => assert!(body["view"].is_null(), "{body}"),
        Some("libvirt") => assert!(body["view"].is_object() || body["error"]["kind"].is_string(), "{body}"),
        Some(other) => panic!("{other}"),
    }
}

#[ntex::test]
async fn capabilities_list_the_virtualization_page() {
    let (srv, _) = server().await;
    let (_, caps) = call(&srv, Some("viewer"), Method::GET, "/api/v1/capabilities", None).await;
    assert!(caps["features"].as_array().unwrap().iter().any(|f| f == "virt"), "{caps}");
}

async fn pinned(pve: &FakePve) -> String {
    sbm_redfish::cert::fetch_server_cert("127.0.0.1", pve.addr.port(), std::time::Duration::from_secs(5))
        .await
        .unwrap()
        .fingerprint
}

#[ntex::test]
async fn detail_history_and_a_console_ticket() {
    let pve = FakePve::start().await;
    let (srv, db) = server().await;
    let pin = pinned(&pve).await;
    call(&srv, Some("admin"), Method::PUT, "/api/v1/virt/pve", Some(token_config(&pve.url(), Some(&pin)))).await;

    let (_, body) = call(&srv, Some("admin"), Method::POST, "/api/v1/virt/detail", Some(json!({"guest": "qemu/100"}))).await;
    assert_eq!(body["detail"]["disks"][0]["size"], 8u64 << 30, "{body}");
    assert_eq!(body["detail"]["nics"][0]["source"], "vmbr0");
    assert_eq!(body["detail"]["consoles"], json!(["vnc"]));

    let (_, body) = call(&srv, Some("admin"), Method::POST, "/api/v1/virt/history", Some(json!({"guest": "qemu/100", "window": "day"}))).await;
    assert_eq!(body["history"].as_array().map(Vec::len), Some(2), "{body}");
    assert_eq!(body["history"][0]["cpu"], 25.0, "oldest first: {body}");
    assert!(pve.seen.lock().unwrap().paths.iter().any(|p| p.contains("rrddata?timeframe=day&cf=AVERAGE")));

    let (status, body) =
        call(&srv, Some("admin"), Method::POST, "/api/v1/virt/console", Some(json!({"guest": "qemu/100", "kind": "vnc"}))).await;
    assert_eq!(status, 200, "{body}");
    assert!(body["ticket"].as_str().is_some_and(|t| !t.is_empty()), "{body}");
    // What RFB uses of it; the console ticket itself stays in the agent.
    assert_eq!(body["vnc_password"], "abcdefgh");
    assert!(!body.to_string().contains("PVEVNC"), "{body}");

    // A guest the host does not have.
    let (_, body) =
        call(&srv, Some("admin"), Method::POST, "/api/v1/virt/console", Some(json!({"guest": "qemu/404", "kind": "vnc"}))).await;
    assert_eq!(body["error"]["kind"], "action_failed", "{body}");

    let details: Vec<_> = audit(&db).await.into_iter().filter_map(|r| r.3).collect();
    assert!(details.iter().all(|d| !d.contains("PVEVNC")), "{details:?}");
}

#[ntex::test]
async fn a_console_needs_virt_and_its_own_ticket() {
    let (srv, _) = server().await;
    let (status, _) =
        call(&srv, Some("viewer"), Method::POST, "/api/v1/virt/console", Some(json!({"guest": "x", "kind": "vnc"}))).await;
    assert_eq!(status, 403);
    // The generic issuer does not mint one: a virt ticket is bound to the
    // console it opens.
    let (status, _) = call(&srv, Some("admin"), Method::POST, "/api/v1/ws-ticket", Some(json!({"purpose": "virt"}))).await;
    assert_eq!(status, 403);
}
