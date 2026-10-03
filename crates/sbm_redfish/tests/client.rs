//! What only a live connection has: a TLS handshake, and a session that has to
//! be given back — `client_test.dart`, plus the checks the Rust client adds
//! (redirects, unsafe links, bounded bodies, re-login on 401).
//!
//! Against a real HTTPS server on loopback, self-signed with the throwaway
//! `localhost` keypair in `tests/fixtures/` (the Dart suite's own), so the
//! suite needs no certificate generator. One request per connection, answered
//! with `Connection: close`, which keeps the fake to a page of code.

use std::collections::HashSet;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use base64::Engine as _;
use rustls::pki_types::pem::PemObject;
use rustls::pki_types::{CertificateDer, PrivateKeyDer};
use sbm_redfish::cert::fetch_server_cert;
use sbm_redfish::client::{Auth, Client, ClientConfig, MAX_BODY, Outcome};
use sbm_redfish::model::TaskState;
use sbm_redfish::{Error, Failure, discover};
use serde_json::{Value, json};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::task::JoinHandle;

/// A Redfish service, as far as these tests need one.
#[derive(Default)]
struct State {
    /// Every session ever created, and which were given back. The point of the
    /// whole exercise.
    sessions_created: Vec<String>,
    sessions_deleted: Vec<String>,
    /// Tokens the service still honours.
    live_tokens: HashSet<String>,
    logins: usize,
    /// Requests that arrived with an `authorization` header.
    basic_requests: usize,
    /// Every request line, `METHOD /path`.
    requests: Vec<String>,
    last_if_match: Option<String>,
    etag: String,
    /// The service root advertises no session collection.
    sessionless: bool,
    /// A POST to the reset action answers 202 with a task.
    reset_is_async: bool,
    /// How many more polls of the task report it still running.
    task_running_for: usize,
    login_delay: Duration,
    /// Make this many logins fail with a 500 first.
    fail_logins: usize,
    /// The password logins are accepted with.
    password: String,
    /// The session collection, as the root names it.
    sessions_link: Option<String>,
    /// Answer a login's `Location` as an absolute URL of this origin.
    absolute_location: bool,
    next_session: usize,
    port: u16,
}

struct FakeBmc {
    addr: SocketAddr,
    state: Arc<Mutex<State>>,
    server: JoinHandle<()>,
}

impl FakeBmc {
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
        let state = Arc::new(Mutex::new(State {
            etag: "W/\"1\"".into(),
            password: "right".into(),
            port: addr.port(),
            ..State::default()
        }));
        let shared = state.clone();
        let server = tokio::spawn(async move {
            loop {
                let Ok((tcp, _)) = listener.accept().await else { return };
                let acceptor = acceptor.clone();
                let state = shared.clone();
                tokio::spawn(async move {
                    let Ok(mut tls) = acceptor.accept(tcp).await else { return };
                    let Some(request) = read_request(&mut tls).await else { return };
                    let response = handle(&state, request).await;
                    let _ = tls.write_all(&response).await;
                    let _ = tls.shutdown().await;
                });
            }
        });
        Self { addr, state, server }
    }

    fn url(&self) -> String {
        format!("https://127.0.0.1:{}", self.addr.port())
    }

    fn state(&self) -> std::sync::MutexGuard<'_, State> {
        self.state.lock().unwrap()
    }

    async fn fingerprint(&self) -> String {
        fetch_server_cert("127.0.0.1", self.addr.port(), Duration::from_secs(5))
            .await
            .unwrap()
            .fingerprint
    }

    /// A client against this service, pinned to its certificate.
    async fn client(&self) -> Client {
        let pin = self.fingerprint().await;
        self.client_with(|c| c.pinned_sha256 = Some(pin))
    }

    fn client_with(&self, edit: impl FnOnce(&mut ClientConfig)) -> Client {
        let mut config = ClientConfig {
            base_url: self.url(),
            user: "admin".into(),
            password: Some("right".into()),
            timeout: Duration::from_secs(5),
            ..ClientConfig::default()
        };
        edit(&mut config);
        Client::new(config).unwrap()
    }

    fn stop(&self) {
        self.server.abort();
    }
}

impl Drop for FakeBmc {
    fn drop(&mut self) {
        self.server.abort();
    }
}

fn fixture(name: &str) -> String {
    format!("{}/tests/fixtures/{name}", env!("CARGO_MANIFEST_DIR"))
}

struct Request {
    method: String,
    path: String,
    headers: Vec<(String, String)>,
    body: Vec<u8>,
}

impl Request {
    fn header(&self, name: &str) -> Option<&str> {
        self.headers
            .iter()
            .find(|(k, _)| k == name)
            .map(|(_, v)| v.as_str())
    }
}

async fn read_request<S: AsyncReadExt + Unpin>(stream: &mut S) -> Option<Request> {
    let mut buf = Vec::new();
    let mut chunk = [0u8; 4096];
    let head_end = loop {
        if let Some(i) = buf.windows(4).position(|w| w == b"\r\n\r\n") {
            break i;
        }
        let n = stream.read(&mut chunk).await.ok()?;
        if n == 0 {
            return None;
        }
        buf.extend_from_slice(&chunk[..n]);
    };
    let head = String::from_utf8_lossy(&buf[..head_end]).to_string();
    let mut lines = head.split("\r\n");
    let mut first = lines.next()?.split(' ');
    let method = first.next()?.to_string();
    let path = first.next()?.to_string();
    let headers: Vec<(String, String)> = lines
        .filter_map(|l| l.split_once(':'))
        .map(|(k, v)| (k.trim().to_ascii_lowercase(), v.trim().to_string()))
        .collect();
    let length: usize = headers
        .iter()
        .find(|(k, _)| k == "content-length")
        .and_then(|(_, v)| v.parse().ok())
        .unwrap_or(0);
    let mut body = buf[head_end + 4..].to_vec();
    while body.len() < length {
        let n = stream.read(&mut chunk).await.ok()?;
        if n == 0 {
            break;
        }
        body.extend_from_slice(&chunk[..n]);
    }
    Some(Request { method, path, headers, body })
}

fn response(status: u16, headers: &[(&str, String)], body: &[u8]) -> Vec<u8> {
    let mut out = format!("HTTP/1.1 {status} X\r\nconnection: close\r\ncontent-length: {}\r\n", body.len());
    if !body.is_empty() && !headers.iter().any(|(k, _)| *k == "content-type") {
        out.push_str("content-type: application/json\r\n");
    }
    for (k, v) in headers {
        out.push_str(&format!("{k}: {v}\r\n"));
    }
    out.push_str("\r\n");
    let mut bytes = out.into_bytes();
    bytes.extend_from_slice(body);
    bytes
}

fn json_response(status: u16, headers: &[(&str, String)], body: Value) -> Vec<u8> {
    response(status, headers, body.to_string().as_bytes())
}

async fn handle(state: &Arc<Mutex<State>>, req: Request) -> Vec<u8> {
    let path = req.path.clone();
    let delay = {
        let mut s = state.lock().unwrap();
        s.requests.push(format!("{} {path}", req.method));
        if req.header("authorization").is_some() {
            s.basic_requests += 1;
        }
        s.login_delay
    };

    if req.method == "POST" && path == "/redfish/v1/SessionService/Sessions" {
        state.lock().unwrap().logins += 1;
        if !delay.is_zero() {
            tokio::time::sleep(delay).await;
        }
        let mut s = state.lock().unwrap();
        if s.fail_logins > 0 {
            s.fail_logins -= 1;
            return json_response(500, &[], json!({}));
        }
        let body: Value = serde_json::from_slice(&req.body).unwrap_or(Value::Null);
        if body["UserName"] != "admin" || body["Password"] != s.password.as_str() {
            return json_response(401, &[], json!({}));
        }
        let id = format!("/redfish/v1/SessionService/Sessions/{}", s.next_session);
        s.next_session += 1;
        s.sessions_created.push(id.clone());
        let token = format!("token-for-{id}");
        s.live_tokens.insert(token.clone());
        let location = if s.absolute_location {
            format!("https://127.0.0.1:{}{id}", s.port)
        } else {
            id.clone()
        };
        return json_response(201, &[("x-auth-token", token), ("location", location)], json!({"@odata.id": id}));
    }

    let mut s = state.lock().unwrap();

    if req.method == "DELETE" && path.starts_with("/redfish/v1/SessionService/Sessions/") {
        s.sessions_deleted.push(path.clone());
        if let Some(token) = req.header("x-auth-token") {
            s.live_tokens.remove(token);
        }
        return response(204, &[], b"");
    }

    if path == "/redfish/v1/" {
        // Unauthenticated by specification, which is what makes a probe free
        let mut root = json!({
            "RedfishVersion": "1.13.0",
            "Systems": {"@odata.id": "/redfish/v1/Systems"},
            "Chassis": {"@odata.id": "/redfish/v1/Chassis"},
        });
        if !s.sessionless {
            let link = s
                .sessions_link
                .clone()
                .unwrap_or_else(|| "/redfish/v1/SessionService/Sessions".into());
            root["Links"] = json!({"Sessions": {"@odata.id": link}});
        }
        return json_response(200, &[], root);
    }

    // Everything else needs a live token, or the basic credential.
    let expected_basic = format!(
        "Basic {}",
        base64::engine::general_purpose::STANDARD.encode(format!("admin:{}", s.password))
    );
    let ok = req.header("x-auth-token").is_some_and(|t| s.live_tokens.contains(t))
        || req.header("authorization") == Some(expected_basic.as_str());
    if !ok {
        return json_response(401, &[], json!({}));
    }

    match (req.method.as_str(), path.as_str()) {
        ("GET", "/redfish/v1/TaskService/Tasks/1") => {
            let running = s.task_running_for > 0;
            if running {
                s.task_running_for -= 1;
            }
            json_response(
                200,
                &[],
                json!({
                    "Id": "1",
                    "TaskState": if running { "Running" } else { "Completed" },
                    "PercentComplete": if running { 50 } else { 100 },
                }),
            )
        }
        ("PATCH", _) => {
            s.last_if_match = req.header("if-match").map(str::to_string);
            match &s.last_if_match {
                None => json_response(428, &[], json!({})),
                Some(m) if *m != s.etag => json_response(412, &[], json!({})),
                Some(_) => response(204, &[], b""),
            }
        }
        ("POST", "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset") => {
            if s.reset_is_async {
                json_response(
                    202,
                    &[("location", "/redfish/v1/TaskService/Tasks/1".into())],
                    json!({"@odata.id": "/redfish/v1/TaskService/Tasks/1"}),
                )
            } else {
                response(204, &[], b"")
            }
        }
        ("POST", "/redfish/v1/Systems/1/Actions/BodyOnly") => {
            json_response(202, &[], json!({"@odata.id": "/redfish/v1/TaskService/Tasks/1"}))
        }
        ("POST", "/redfish/v1/Systems/1/Actions/Nowhere") => response(202, &[], b""),
        ("GET", "/redfish/v1/Systems") => {
            json_response(200, &[], json!({"Members": [{"@odata.id": "/redfish/v1/Systems/1"}]}))
        }
        ("GET", "/redfish/v1/Chassis") => json_response(200, &[], json!({"Members": []})),
        ("GET", "/redfish/v1/Systems/1") => json_response(
            200,
            &[("etag", s.etag.clone())],
            json!({"PowerState": "On", "Model": "Fake 1U"}),
        ),
        // Licensing gates parts of some services; this is that answer
        ("GET", "/redfish/v1/Licensed") => json_response(403, &[], json!({"error": "license-secret-body"})),
        ("GET", "/redfish/v1/Redirect") => response(
            302,
            &[("location", "https://evil.example/redfish/v1/Systems/1".into())],
            b"",
        ),
        ("GET", "/redfish/v1/Big") => {
            let filler = "x".repeat(MAX_BODY + 10);
            json_response(200, &[], json!({ "filler": filler }))
        }
        ("GET", "/redfish/v1/Html") => response(
            200,
            &[("content-type", "text/html".into())],
            b"<html>an index page</html>",
        ),
        _ => json_response(404, &[], json!({})),
    }
}

/// `detail` may carry paths and status codes, never a credential, a token or
/// a body.
fn assert_log_safe(err: &Error) {
    let text = err.to_string();
    for secret in ["right", "wrong", "token-for", "license-secret-body", "an index page"] {
        assert!(!text.contains(secret), "{text:?} contains {secret:?}");
    }
}

fn failure<T: std::fmt::Debug>(result: Result<T, Error>) -> Failure {
    let err = result.unwrap_err();
    assert_log_safe(&err);
    err.failure
}

// --- the certificate ---

#[tokio::test]
async fn fetch_server_cert_reads_it_without_sending_anything() {
    let bmc = FakeBmc::start().await;
    let info = fetch_server_cert("127.0.0.1", bmc.addr.port(), Duration::from_secs(5))
        .await
        .unwrap();
    assert_eq!(info.fingerprint.len(), 64);
    assert!(info.subject.contains("localhost"));
    assert!(info.pretty_fingerprint().contains(':'));
    assert!(!info.is_expired());
    // Nothing was requested, so nothing was authenticated
    assert!(bmc.state().requests.is_empty());
    assert_eq!(bmc.state().logins, 0);
}

#[tokio::test]
async fn fetch_server_cert_names_an_address_nothing_answers_on() {
    let bmc = FakeBmc::start().await;
    let port = bmc.addr.port();
    bmc.stop();
    drop(bmc);
    tokio::time::sleep(Duration::from_millis(50)).await;
    let err = fetch_server_cert("127.0.0.1", port, Duration::from_secs(2)).await.unwrap_err();
    assert_eq!(err.failure, Failure::Unreachable);
}

#[tokio::test]
async fn an_unreviewed_certificate_is_refused_not_trusted_on_first_use() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client_with(|_| {});
    assert_eq!(failure(c.probe().await), Failure::CertificateRejected);
    assert_eq!(failure(c.get("/redfish/v1/Systems/1").await), Failure::CertificateRejected);
    // and no credential was ever offered to it
    assert_eq!(bmc.state().logins, 0);
    assert!(bmc.state().requests.is_empty());
}

#[tokio::test]
async fn a_required_pin_refuses_to_build_a_client_without_one() {
    let bmc = FakeBmc::start().await;
    let config = ClientConfig {
        base_url: bmc.url(),
        user: "admin".into(),
        password: Some("right".into()),
        require_pin: true,
        ..ClientConfig::default()
    };
    assert_eq!(Client::new(config.clone()).unwrap_err().failure, Failure::CertNotReviewed);
    let empty = ClientConfig { pinned_sha256: Some(String::new()), ..config.clone() };
    assert_eq!(Client::new(empty).unwrap_err().failure, Failure::CertNotReviewed);
    let pinned = ClientConfig { pinned_sha256: Some(bmc.fingerprint().await), ..config };
    assert!(Client::new(pinned).is_ok());
}

#[tokio::test]
async fn a_certificate_that_is_not_the_pinned_one_is_refused() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client_with(|c| c.pinned_sha256 = Some("a".repeat(64)));
    assert_eq!(failure(c.probe().await), Failure::CertificateRejected);
    assert_eq!(bmc.state().logins, 0);
}

#[tokio::test]
async fn the_reviewed_certificate_is_accepted_in_any_spelling() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    assert_eq!(c.probe().await.unwrap()["RedfishVersion"], "1.13.0");

    let pretty = sbm_redfish::cert::pretty_fingerprint(&bmc.fingerprint().await);
    let c = bmc.client_with(|c| c.pinned_sha256 = Some(pretty));
    assert!(c.probe().await.is_ok());
}

// --- sessions ---

#[tokio::test]
async fn a_probe_costs_no_session() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    c.probe().await.unwrap();
    assert!(bmc.state().sessions_created.is_empty());
}

#[tokio::test]
async fn a_session_token_rides_on_every_request() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let system = c.get("/redfish/v1/Systems/1").await.unwrap();
    assert_eq!(system["Model"], "Fake 1U");
    assert_eq!(bmc.state().logins, 1);
    assert_eq!(bmc.state().basic_requests, 0, "the session, not the password");
    c.close().await;
}

#[tokio::test]
async fn concurrent_reads_share_one_login() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let (a, b, d) = tokio::join!(
        c.get("/redfish/v1/Systems"),
        c.get("/redfish/v1/Systems/1"),
        c.get("/redfish/v1/Systems"),
    );
    a.unwrap();
    b.unwrap();
    d.unwrap();
    assert_eq!(bmc.state().logins, 1);
    assert_eq!(bmc.state().sessions_created.len(), 1);
    c.close().await;
}

#[tokio::test]
async fn close_gives_the_session_back() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    c.get("/redfish/v1/Systems/1").await.unwrap();
    assert_eq!(bmc.state().sessions_created.len(), 1);
    c.close().await;
    let s = bmc.state();
    assert_eq!(s.sessions_deleted, s.sessions_created);
}

#[tokio::test]
async fn an_absolute_same_origin_location_is_followed_to_close() {
    let bmc = FakeBmc::start().await;
    bmc.state().absolute_location = true;
    let c = bmc.client().await;
    c.get("/redfish/v1/Systems/1").await.unwrap();
    c.close().await;
    let s = bmc.state();
    assert_eq!(s.sessions_deleted, s.sessions_created);
}

#[tokio::test]
async fn close_is_safe_twice_and_a_closed_client_refuses_requests() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    c.get("/redfish/v1/Systems/1").await.unwrap();
    c.close().await;
    c.close().await;
    assert_eq!(bmc.state().sessions_deleted.len(), 1);
    assert_eq!(failure(c.get("/redfish/v1/Systems/1").await), Failure::Closed);
    assert_eq!(bmc.state().logins, 1, "no login after close");
}

#[tokio::test]
async fn closing_during_a_login_still_gives_the_session_back() {
    let bmc = FakeBmc::start().await;
    bmc.state().login_delay = Duration::from_millis(300);
    let c = Arc::new(bmc.client().await);

    let in_flight = tokio::spawn({
        let c = c.clone();
        async move { c.get("/redfish/v1/Systems/1").await }
    });
    tokio::time::sleep(Duration::from_millis(50)).await;
    c.close().await;
    let result = in_flight.await.unwrap();
    assert_eq!(result.unwrap_err().failure, Failure::Closed);

    let s = bmc.state();
    assert_eq!(s.sessions_created.len(), 1);
    assert_eq!(s.sessions_deleted, s.sessions_created);
}

#[tokio::test]
async fn a_client_that_never_logged_in_still_closes() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    c.close().await;
    assert!(bmc.state().sessions_deleted.is_empty());
}

// --- a failed login is not remembered ---

#[tokio::test]
async fn after_a_failed_login_the_next_request_tries_again() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    bmc.state().fail_logins = 1;
    // A 500 at login is the service's bad day, not the account's.
    assert_eq!(failure(c.get("/redfish/v1/Systems/1").await), Failure::Unreachable);
    assert_eq!(c.get("/redfish/v1/Systems/1").await.unwrap()["Model"], "Fake 1U");
    assert_eq!(bmc.state().logins, 2);
    c.close().await;
}

#[tokio::test]
async fn a_wrong_password_is_still_refused_every_time() {
    let bmc = FakeBmc::start().await;
    let pin = bmc.fingerprint().await;
    let c = bmc.client_with(|c| {
        c.pinned_sha256 = Some(pin);
        c.password = Some("wrong".into());
    });
    for _ in 0..2 {
        assert_eq!(failure(c.get("/redfish/v1/Systems/1").await), Failure::Unauthorized);
    }
    assert_eq!(bmc.state().logins, 2, "one attempt per request, never a retry loop");
}

// --- a 401 on a live session ---

#[tokio::test]
async fn an_expired_session_is_replaced_once() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    c.get("/redfish/v1/Systems/1").await.unwrap();
    // The BMC reaps the session.
    bmc.state().live_tokens.clear();

    assert_eq!(c.get("/redfish/v1/Systems/1").await.unwrap()["Model"], "Fake 1U");
    {
        let s = bmc.state();
        assert_eq!(s.logins, 2);
        assert_eq!(s.sessions_deleted, ["/redfish/v1/SessionService/Sessions/0"], "the old one given back");
    }
    c.close().await;
    let s = bmc.state();
    assert_eq!(s.sessions_deleted, s.sessions_created);
}

#[tokio::test]
async fn a_401_after_the_fresh_login_too_is_unauthorized() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    c.get("/redfish/v1/Systems/1").await.unwrap();
    {
        // The password was rotated on the BMC.
        let mut s = bmc.state();
        s.live_tokens.clear();
        s.password = "rotated".into();
    }
    assert_eq!(failure(c.get("/redfish/v1/Systems/1").await), Failure::Unauthorized);
    assert_eq!(bmc.state().logins, 2, "one re-login, not a loop");
}

#[tokio::test]
async fn a_401_on_basic_auth_is_not_retried() {
    let bmc = FakeBmc::start().await;
    bmc.state().sessionless = true;
    let pin = bmc.fingerprint().await;
    let c = bmc.client_with(|c| {
        c.pinned_sha256 = Some(pin);
        c.password = Some("wrong".into());
    });
    assert_eq!(failure(c.get("/redfish/v1/Systems/1").await), Failure::Unauthorized);
    let s = bmc.state();
    assert_eq!(s.basic_requests, 1);
    assert_eq!(s.logins, 0);
}

// --- a transport failure keeps its name ---

#[tokio::test]
async fn a_post_that_cannot_be_sent_is_a_redfish_error() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    c.get("/redfish/v1/Systems/1").await.unwrap();
    bmc.stop();
    tokio::time::sleep(Duration::from_millis(50)).await;
    // A machine being reset stops answering, which is the normal case here.
    let result = c
        .post("/redfish/v1/Systems/1/Actions/ComputerSystem.Reset", json!({"ResetType": "ForceOff"}))
        .await;
    assert_eq!(failure(result), Failure::Unreachable);
}

// --- answers that mean something ---

#[tokio::test]
async fn a_licensed_only_resource_is_forbidden_and_names_itself() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let err = c.get("/redfish/v1/Licensed").await.unwrap_err();
    assert_log_safe(&err);
    assert_eq!(err.failure, Failure::Forbidden);
    assert!(err.detail.unwrap().contains("Licensed"));
    c.close().await;
}

#[tokio::test]
async fn a_body_that_is_not_json_is_not_a_service() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    assert_eq!(failure(c.get("/redfish/v1/Html").await), Failure::NotAService);
    c.close().await;
}

#[tokio::test]
async fn a_missing_resource_is_unreachable_with_its_status() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let err = c.get("/redfish/v1/Nothing").await.unwrap_err();
    assert_eq!(err.failure, Failure::Unreachable);
    assert_eq!(err.detail.as_deref(), Some("HTTP 404 at /redfish/v1/Nothing"));
    c.close().await;
}

// --- what this client will not follow ---

#[tokio::test]
async fn a_redirect_is_refused_not_followed() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let err = c.get("/redfish/v1/Redirect").await.unwrap_err();
    assert_log_safe(&err);
    assert_eq!(err.failure, Failure::Unreachable);
    assert!(err.detail.unwrap().contains("302"));
    c.close().await;
}

#[tokio::test]
async fn an_unsafe_path_is_refused_before_anything_is_sent() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    for path in [
        "https://evil.example/redfish/v1/Systems/1",
        "http://127.0.0.1/redfish/v1/Systems/1",
        "//evil.example/redfish/v1/",
        "/redfish/v1/../../etc/passwd",
        "/redfish/v1/%2e%2e/secret",
        "/redfish/v1/Systems/1?x=1",
        "/redfish/v1/Systems/1#frag",
        "/redfish/v1/Sys tems",
        "/other/v1/Systems",
        "redfish/v1/Systems",
        "",
    ] {
        assert_eq!(failure(c.get(path).await), Failure::InvalidResponse, "{path}");
    }
    assert!(bmc.state().requests.is_empty(), "nothing reached the wire");
    assert_eq!(bmc.state().logins, 0);

    // The same origin, spelled absolutely, is the same service.
    let own = format!("{}/redfish/v1/Systems/1", bmc.url());
    assert_eq!(c.get(&own).await.unwrap()["Model"], "Fake 1U");
    c.close().await;
}

#[tokio::test]
async fn a_session_link_to_another_host_gets_no_password() {
    let bmc = FakeBmc::start().await;
    bmc.state().sessions_link = Some("https://evil.example/redfish/v1/SessionService/Sessions".into());
    let c = bmc.client().await;
    assert_eq!(failure(c.get("/redfish/v1/Systems/1").await), Failure::InvalidResponse);
    let s = bmc.state();
    assert_eq!(s.logins, 0);
    assert_eq!(s.requests, ["GET /redfish/v1/"]);
}

#[tokio::test]
async fn a_body_over_the_bound_is_refused() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    assert_eq!(failure(c.get("/redfish/v1/Big").await), Failure::InvalidResponse);
    c.close().await;
}

#[test]
fn an_address_that_is_not_https_is_refused() {
    for url in ["http://10.0.0.9", "ftp://10.0.0.9", "not a url", "https://", "https://10.0.0.9/?q=1", "https://u:p@10.0.0.9"] {
        let config = ClientConfig {
            base_url: url.into(),
            pinned_sha256: Some("a".repeat(64)),
            ..ClientConfig::default()
        };
        assert_eq!(Client::new(config).unwrap_err().failure, Failure::InvalidUrl, "{url}");
    }
}

#[test]
fn the_password_never_reaches_debug_output() {
    let config = ClientConfig {
        base_url: "https://10.0.0.9".into(),
        password: Some("hunter2".into()),
        ..ClientConfig::default()
    };
    assert!(!format!("{config:?}").contains("hunter2"));
}

// --- ETag and If-Match ---

#[tokio::test]
async fn fetch_carries_the_etag_the_resource_was_served_with() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let r = c.fetch("/redfish/v1/Systems/1").await.unwrap();
    assert_eq!(r.etag.as_deref(), Some("W/\"1\""));
    assert_eq!(r.json["Model"], "Fake 1U");
    c.close().await;
}

#[tokio::test]
async fn a_patch_without_one_is_refused_and_says_which_kind_of_refusal() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let result = c.patch("/redfish/v1/Systems/1", json!({"Boot": {}}), None).await;
    assert_eq!(failure(result), Failure::PreconditionRequired);
    c.close().await;
}

#[tokio::test]
async fn a_stale_one_is_refused_the_same_way() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let r = c.fetch("/redfish/v1/Systems/1").await.unwrap();
    bmc.state().etag = "W/\"2\"".into(); // changed through the web interface
    let result = c.patch("/redfish/v1/Systems/1", json!({"Boot": {}}), r.etag.as_deref()).await;
    assert_eq!(failure(result), Failure::PreconditionRequired);
    c.close().await;
}

#[tokio::test]
async fn a_current_one_goes_through() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let r = c.fetch("/redfish/v1/Systems/1").await.unwrap();
    let outcome = c
        .patch(
            "/redfish/v1/Systems/1",
            json!({"Boot": {"BootSourceOverrideTarget": "Pxe"}}),
            r.etag.as_deref(),
        )
        .await
        .unwrap();
    assert_eq!(outcome, Outcome::Done);
    assert_eq!(bmc.state().last_if_match.as_deref(), Some("W/\"1\""));
    c.close().await;
}

// --- a 202 is not a result ---

const RESET: &str = "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset";

#[tokio::test]
async fn an_action_that_finishes_inline_says_so() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    assert_eq!(c.post(RESET, json!({"ResetType": "On"})).await.unwrap(), Outcome::Done);
    c.close().await;
}

#[tokio::test]
async fn one_that_does_not_comes_back_with_somewhere_to_look() {
    let bmc = FakeBmc::start().await;
    bmc.state().reset_is_async = true;
    let c = bmc.client().await;
    assert_eq!(
        c.post(RESET, json!({"ResetType": "On"})).await.unwrap(),
        Outcome::Accepted("/redfish/v1/TaskService/Tasks/1".into())
    );
    // `@odata.id` where `Location` is missing; nothing to wait on with neither
    assert_eq!(
        c.post("/redfish/v1/Systems/1/Actions/BodyOnly", json!({})).await.unwrap(),
        Outcome::Accepted("/redfish/v1/TaskService/Tasks/1".into())
    );
    assert_eq!(c.post("/redfish/v1/Systems/1/Actions/Nowhere", json!({})).await.unwrap(), Outcome::Done);
    c.close().await;
}

#[tokio::test]
async fn await_task_polls_it_until_the_service_stops_working() {
    let bmc = FakeBmc::start().await;
    {
        let mut s = bmc.state();
        s.reset_is_async = true;
        s.task_running_for = 2;
    }
    let c = bmc.client().await;
    let Outcome::Accepted(path) = c.post(RESET, json!({"ResetType": "On"})).await.unwrap() else {
        panic!("expected a task");
    };
    let task = c
        .await_task(&path, Duration::from_secs(10), Duration::from_millis(10))
        .await
        .unwrap();
    assert_eq!(task.state, TaskState::Completed);
    assert!(task.state.is_success());
    assert_eq!(task.percent_complete, Some(100));
    c.close().await;
}

#[tokio::test]
async fn a_task_still_running_when_the_wait_ends_comes_back_running() {
    let bmc = FakeBmc::start().await;
    {
        let mut s = bmc.state();
        s.reset_is_async = true;
        s.task_running_for = 1000;
    }
    let c = bmc.client().await;
    let Outcome::Accepted(path) = c.post(RESET, json!({"ResetType": "On"})).await.unwrap() else {
        panic!("expected a task");
    };
    let task = c
        .await_task(&path, Duration::from_millis(60), Duration::from_millis(10))
        .await
        .unwrap();
    assert!(task.state.is_running());
    c.close().await;
}

// --- basic auth ---

#[tokio::test]
async fn a_service_offering_no_sessions_is_used_with_the_credential() {
    let bmc = FakeBmc::start().await;
    bmc.state().sessionless = true;
    let c = bmc.client().await;
    assert_eq!(c.get("/redfish/v1/Systems/1").await.unwrap()["Model"], "Fake 1U");
    c.get("/redfish/v1/Systems").await.unwrap();
    let s = bmc.state();
    assert_eq!(s.logins, 0, "nothing was created to be released");
    assert_eq!(s.basic_requests, 2);
}

#[tokio::test]
async fn asking_for_it_directly_skips_the_login_entirely() {
    let bmc = FakeBmc::start().await;
    let pin = bmc.fingerprint().await;
    let c = bmc.client_with(|c| {
        c.pinned_sha256 = Some(pin);
        c.auth = Auth::Basic;
    });
    c.get("/redfish/v1/Systems/1").await.unwrap();
    let s = bmc.state();
    assert_eq!(s.logins, 0);
    assert!(s.sessions_created.is_empty());
    assert_eq!(s.requests, ["GET /redfish/v1/Systems/1"], "not even the root");
}

// --- discovery over the real transport ---

#[tokio::test]
async fn discovery_walks_the_service_and_stops_where_it_runs_out() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let topology = discover(&c).await.unwrap();
    assert_eq!(topology.system_path.as_deref(), Some("/redfish/v1/Systems/1"));
    assert_eq!(topology.system.as_ref().unwrap().model.as_deref(), Some("Fake 1U"));
    // The chassis collection is empty, which costs the sensors only
    assert!(topology.chassis.is_none());
    // One login for the whole walk, not one per resource
    assert_eq!(bmc.state().logins, 1);
    c.close().await;
}

#[tokio::test]
async fn a_snapshot_then_a_power_request_over_the_wire() {
    let bmc = FakeBmc::start().await;
    let c = bmc.client().await;
    let snap = sbm_redfish::snapshot(&c, None).await.unwrap();
    assert!(snap.sensors.is_empty());
    // The fake advertises no reset action, so nothing is sent.
    let err = sbm_redfish::power(&c, &snap.topology, sbm_redfish::model::PowerIntent::ForceOff)
        .await
        .unwrap_err();
    assert_eq!(err.failure, Failure::NotSupported);
    assert!(!bmc.state().requests.iter().any(|r| r.starts_with("POST /redfish/v1/Systems")));
    c.close().await;
}
