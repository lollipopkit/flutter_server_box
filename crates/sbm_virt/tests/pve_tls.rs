//! The PVE client's certificate policy against a real TLS server on loopback:
//! a CA-signed certificate is trusted as it is, an unpinned one is shown
//! (`CertUnconfirmed`) and pinned by `confirm_cert`, a different pin is
//! `CertChanged` — each decided in the handshake, before the token is sent.
//!
//! The certificates are the app's `test/fixtures/virt_tls/` (a test CA and a
//! `localhost` leaf it signed, valid to 2126; how they were made is in
//! `test/unit/virt/pve_tls_test.dart`, which this replaces).

use std::io;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};

use bytes::Bytes;
use http_body_util::Full;
use hyper::service::service_fn;
use rustls::RootCertStore;
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use sbm_redfish::cert::fingerprint;
use sbm_virt::error::{Detail, ErrorKind};
use sbm_virt::pve::http::{BoxFuture, Dial, IDLE_TIMEOUT, Stream, TcpDial, TlsConnector};
use sbm_virt::pve::{Auth, Client, Config, Options};
use tokio::net::TcpListener;

fn dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../test/fixtures/virt_tls")
}

fn certs(name: &str) -> Vec<CertificateDer<'static>> {
    let pem = std::fs::read(dir().join(name)).unwrap();
    CertificateDer::pem_slice_iter(&pem).collect::<Result<_, _>>().unwrap()
}

fn leaf_fingerprint() -> String {
    fingerprint(certs("leaf.pem")[0].as_ref())
}

/// A TLS server answering `/version` and one guest, recording each request's
/// `Authorization`.
struct Server {
    addr: SocketAddr,
    auth: Arc<Mutex<Vec<String>>>,
}

async fn server() -> Server {
    let key_pem = std::fs::read(dir().join("leaf.key")).unwrap();
    let key: PrivateKeyDer<'static> = PrivateKeyDer::from_pem_slice(&key_pem).unwrap();
    let tls = rustls::ServerConfig::builder_with_provider(Arc::new(rustls::crypto::ring::default_provider()))
        .with_safe_default_protocol_versions()
        .unwrap()
        .with_no_client_auth()
        .with_single_cert(certs("leaf.pem"), key)
        .unwrap();
    let acceptor = tokio_rustls::TlsAcceptor::from(Arc::new(tls));
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    let auth = Arc::new(Mutex::new(Vec::new()));
    let seen = auth.clone();
    tokio::spawn(async move {
        loop {
            let Ok((tcp, _)) = listener.accept().await else { return };
            let (acceptor, seen) = (acceptor.clone(), seen.clone());
            tokio::spawn(async move {
                let Ok(tls) = acceptor.accept(tcp).await else { return };
                let service = service_fn(move |mut req: hyper::Request<hyper::body::Incoming>| {
                    let seen = seen.clone();
                    async move {
                        if let Some(a) = req.headers().get("authorization") {
                            seen.lock().unwrap().push(a.to_str().unwrap().to_owned());
                        }
                        if req.uri().path().ends_with("/vncwebsocket") {
                            return Ok(termproxy(&mut req));
                        }
                        let data = match req.uri().path() {
                            "/api2/json/version" => r#"{"version":"8.2.4"}"#,
                            // One guest: a host with none has its permissions asked as well.
                            "/api2/json/cluster/resources" => {
                                r#"[{"id":"lxc/100","type":"lxc","vmid":100,"node":"pve","name":"ct","status":"running"}]"#
                            }
                            _ => "null",
                        };
                        Ok::<_, io::Error>(hyper::Response::new(Full::new(Bytes::from(format!(r#"{{"data":{data}}}"#)))))
                    }
                });
                let _ = hyper::server::conn::http1::Builder::new()
                    .serve_connection(hyper_util::rt::TokioIo::new(tls), service)
                    .with_upgrades()
                    .await;
            });
        }
    });
    Server { addr, auth }
}

/// A termproxy behind `vncwebsocket`: takes `root@pam!sb:T\n`, answers `OK`
/// with a prompt in the same frame, then echoes each input frame's data back
/// as output, and a resize as `size <cols>x<rows>`.
fn termproxy(req: &mut hyper::Request<hyper::body::Incoming>) -> hyper::Response<Full<Bytes>> {
    use futures_util::{SinkExt, StreamExt};
    use tokio_tungstenite::tungstenite::{Message, handshake::derive_accept_key, protocol::Role};
    let key = req.headers()["sec-websocket-key"].as_bytes().to_vec();
    let upgrade = hyper::upgrade::on(req);
    tokio::spawn(async move {
        let io = hyper_util::rt::TokioIo::new(upgrade.await.unwrap());
        let mut ws = tokio_tungstenite::WebSocketStream::from_raw_socket(io, Role::Server, None).await;
        match ws.next().await {
            Some(Ok(Message::Binary(b))) if b.as_ref() == b"root@pam!sb:T\n" => {}
            _ => return,
        }
        ws.send(Message::Binary(b"OK$ ".to_vec().into())).await.unwrap();
        while let Some(Ok(Message::Binary(frame))) = ws.next().await {
            let text = String::from_utf8_lossy(&frame).into_owned();
            let reply = if let Some(size) = text.strip_prefix("1:") {
                let mut parts = size.split(':');
                format!("size {}x{}", parts.next().unwrap(), parts.next().unwrap())
            } else if let Some((_, data)) = text.strip_prefix("0:").and_then(|r| r.split_once(':')) {
                data.to_owned()
            } else {
                continue;
            };
            ws.send(Message::Binary(reply.into_bytes().into())).await.unwrap();
        }
    });
    hyper::Response::builder()
        .status(101)
        .header("connection", "Upgrade")
        .header("upgrade", "websocket")
        .header("sec-websocket-accept", derive_accept_key(&key))
        .header("sec-websocket-protocol", "binary")
        .body(Full::new(Bytes::new()))
        .unwrap()
}

/// Whatever the configured address, the far end is this test's server —
/// the dialer's job.
struct ToServer {
    addr: SocketAddr,
    dials: Arc<AtomicUsize>,
}

impl Dial for ToServer {
    fn dial(&self, _host: String, _port: u16) -> BoxFuture<'static, io::Result<Box<dyn Stream>>> {
        self.dials.fetch_add(1, Ordering::SeqCst);
        TcpDial.dial(self.addr.ip().to_string(), self.addr.port())
    }
}

fn config(pin: Option<String>) -> Config {
    Config {
        addr: "https://localhost:8006".into(),
        auth: Auth::Token { id: "root@pam!sb".into(), secret: "secret".into() },
        cert_sha256: pin,
    }
}

/// No public roots, so "a CA vouches for it" is exactly the given ones.
fn client(server: &Server, pin: Option<String>, roots: RootCertStore) -> (Client, Arc<AtomicUsize>) {
    let dials = Arc::new(AtomicUsize::new(0));
    let dial = Arc::new(ToServer { addr: server.addr, dials: dials.clone() });
    let connector = Arc::new(TlsConnector::with_roots(dial, roots));
    (Client::new(config(pin), connector, Options::default()), dials)
}

#[tokio::test]
async fn a_ca_signed_certificate_needs_no_pin() {
    let srv = server().await;
    let mut roots = RootCertStore::empty();
    roots.add(certs("ca.pem")[0].clone()).unwrap();
    let (pve, _) = client(&srv, None, roots);
    let view = pve.load().await.unwrap();
    assert_eq!(view.host.version.as_deref(), Some("8.2.4"));
    assert!(srv.auth.lock().unwrap().iter().all(|a| a == "PVEAPIToken=root@pam!sb=secret"));
}

#[tokio::test]
async fn unpinned_refused_before_any_request_shown_then_pinned() {
    let srv = server().await;
    let (pve, _) = client(&srv, None, RootCertStore::empty());
    let e = pve.load().await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::CertUnconfirmed);
    let cert = e.cert.unwrap();
    assert_eq!(cert.fingerprint, leaf_fingerprint());
    assert!(cert.subject.contains("localhost"), "{}", cert.subject);
    assert!(srv.auth.lock().unwrap().is_empty(), "the token never left");

    // Only what was presented can be pinned.
    let wrong = pve.confirm_cert(&"00".repeat(32)).unwrap_err();
    assert_eq!(wrong.detail.as_deref(), Some(&Detail::CertNotPresented));

    assert_eq!(pve.confirm_cert(&cert.fingerprint.to_uppercase()).unwrap(), leaf_fingerprint());
    assert_eq!(pve.config().cert_sha256, Some(leaf_fingerprint()));
    pve.load().await.unwrap();
    assert!(!srv.auth.lock().unwrap().is_empty());
}

#[tokio::test]
async fn a_pinned_certificate_is_accepted_without_a_ca() {
    let srv = server().await;
    let (pve, _) = client(&srv, Some(leaf_fingerprint()), RootCertStore::empty());
    pve.load().await.unwrap();
}

#[tokio::test]
async fn a_different_certificate_than_the_pinned_one_is_cert_changed() {
    let srv = server().await;
    let old = "ab".repeat(32);
    let (pve, _) = client(&srv, Some(old.clone()), RootCertStore::empty());
    let e = pve.load().await.unwrap_err();
    assert_eq!(e.kind, ErrorKind::CertChanged);
    assert_eq!(e.previous_fingerprint, Some(old));
    assert_eq!(e.cert.unwrap().fingerprint, leaf_fingerprint());
    assert!(srv.auth.lock().unwrap().is_empty());
}

#[tokio::test]
async fn nothing_listening_is_unreachable() {
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    drop(listener);
    let srv = Server { addr, auth: Default::default() };
    let (pve, _) = client(&srv, None, RootCertStore::empty());
    assert_eq!(pve.load().await.unwrap_err().kind, ErrorKind::Unreachable);
}

#[tokio::test]
async fn an_idle_connection_is_let_go_before_pveproxy_closes_it() {
    // pveproxy closes an idle keep-alive connection after 5 s; a request sent
    // on it just then fails. So a connection idle for longer than
    // IDLE_TIMEOUT is not reused.
    assert!(IDLE_TIMEOUT < std::time::Duration::from_secs(5));
    let srv = server().await;
    let (pve, dials) = client(&srv, Some(leaf_fingerprint()), RootCertStore::empty());
    pve.load().await.unwrap();
    let after_first = dials.load(Ordering::SeqCst);
    pve.load().await.unwrap();
    assert_eq!(dials.load(Ordering::SeqCst), after_first, "reused while fresh");
    tokio::time::sleep(IDLE_TIMEOUT + std::time::Duration::from_millis(500)).await;
    pve.load().await.unwrap();
    assert_eq!(dials.load(Ordering::SeqCst), after_first + 1);
}

#[tokio::test]
async fn a_text_console_logs_in_to_termproxy_and_carries_framed_input() {
    use sbm_virt::model::{ConsoleKind, GuestKind};
    use sbm_virt::pve::client::PveConsole;
    let srv = server().await;
    let (pve, _) = client(&srv, Some(leaf_fingerprint()), RootCertStore::empty());
    let console = PveConsole {
        node: "pve".into(),
        guest_kind: GuestKind::Lxc,
        vmid: 100,
        kind: ConsoleKind::Text,
        port: 5900,
        ticket: "T".into(),
        user: "root@pam!sb".into(),
        password: None,
    };
    let ws = pve.open_console(&console).await.unwrap();
    // The prompt that came in `OK`'s frame is the first output.
    assert_eq!(ws.recv().await.as_deref(), Some(&b"$ "[..]));
    ws.resize(80, 24).await.unwrap();
    assert_eq!(ws.recv().await.as_deref(), Some(&b"size 80x24"[..]));
    ws.send(b"ls\r").await.unwrap();
    assert_eq!(ws.recv().await.as_deref(), Some(&b"ls\r"[..]));
    ws.close().await;
    // A refused ticket ends the socket before `OK`.
    let wrong = PveConsole { ticket: "nope".into(), ..console };
    let refused = pve.open_console(&wrong).await.err().map(|e| e.kind);
    assert_eq!(refused, Some(ErrorKind::ActionFailed));
}
