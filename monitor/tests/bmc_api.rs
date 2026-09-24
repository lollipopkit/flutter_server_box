//! `GET/PUT /api/v1/bmc/*` end to end: the real route table, a real
//! `config.toml`, and a fake BMC this test owns on loopback.
//!
//! The fake is routed by path and records what it was asked for, so what is
//! asserted is the request the agent *composed* — the path a reset was
//! addressed at, the JSON a login was sent as, the header a read carries, the
//! `DELETE` that ends the session — rather than a shape a helper agreed with
//! itself about. `tests/pve_api.rs` does the same for the cluster endpoint.
//!
//! Five things here cannot be shown by the module's own unit tests, because
//! each is a decision that spans the wire:
//!
//! - **The certificate is the whole of the trust, and it is reviewed first.**
//!   A service presenting a certificate nobody pinned is refused, and
//!   `POST /bmc/probe` is how one is looked at — asserted by a fake behind a
//!   certificate generated here, whose fingerprint is compared against what the
//!   probe answers, and which records *no request at all* because the handshake
//!   is meant to fail before anything is sent.
//! - **The password reaches the BMC and never the panel.** The login's JSON
//!   carries it, `GET /bmc/settings` answers `null` with `secret_set` beside it,
//!   and the response bytes are searched for the plaintext.
//! - **A save keeps the password it was not given.** The test reads the file for
//!   that, not the answer, since the answer is built from the request.
//! - **No upstream status is answered as itself.** A BMC answering 401 is a 400
//!   with `unauthorized`; `frontend/src/lib/api.ts` logs the operator out on a
//!   401, and what failed is the *agent's* credential to a machine the operator
//!   is not signed in to.
//! - **A session this agent opened is closed again.** A BMC keeps a handful of
//!   concurrent sessions and the operator's own browser usually holds one, so a
//!   leaked session is the operator locked out of their own machine.
//!
//! `config_file::CONFIG_PATH` is relative to the process working directory on
//! purpose, so this file chdirs into a temp directory — once, since cargo gives
//! each integration test file its own process — and serialises its tests, which
//! all write the same `config.toml`.

use std::path::PathBuf;
use std::sync::{Arc, Mutex, Once, OnceLock};

use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use rcgen::{CertifiedKey, generate_simple_self_signed};
use rustls::ServerConfig;
use rustls::crypto::ring;
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use sha2::{Digest, Sha256};
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::{Mutex as AsyncMutex, MutexGuard};
use tokio_rustls::TlsAcceptor;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// The password the fake BMC is configured with. Searchable in a response,
/// which is what the "never the panel" assertions are about.
const PASSWORD: &str = "hunter2-bmc";

/// What the fake BMC answers a login with. An opaque string: what is asserted
/// is that it comes back on the reads that follow and on the `DELETE`, not what
/// it says.
const TOKEN: &str = "session-token-abc123";
const SESSION: &str = "/redfish/v1/SessionService/Sessions/1";

/// A fingerprint of the right shape, for the tests whose fake answers the root
/// before anything is dialed. Not a certificate anything presents.
const SOME_PIN: &str = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

fn ensure_crypto_provider() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        let _ = ring::default_provider().install_default();
    });
}

/// Moves the process into a directory of its own, once, and hands out the lock
/// that keeps these tests from writing each other's `config.toml`.
async fn workspace() -> MutexGuard<'static, PathBuf> {
    static DIR: OnceLock<AsyncMutex<PathBuf>> = OnceLock::new();
    let dir = DIR.get_or_init(|| {
        // A prefix of its own: cargo runs every integration test file as a
        // separate process, and `pve_api.rs` is in the same invocation.
        let dir = std::env::temp_dir().join(format!("sbm-bmc-api-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
        AsyncMutex::new(dir)
    });
    dir.lock().await
}

fn write_config(contents: &str) {
    std::fs::write("config.toml", contents).unwrap();
}

/// The `[bmc]` section **as the file holds it**, which is what a save is judged
/// on rather than what a response said about it.
fn bmc_on_disk() -> Config {
    toml::from_str(&std::fs::read_to_string("config.toml").unwrap()).unwrap()
}

/// A controller configured with a pinned certificate, which is what every test
/// that reads the machine dials.
fn config_with_bmc(url: &str, fingerprint: &str) -> String {
    format!(
        r#"
[server]
host = "127.0.0.1"
port = 3770
name = "test"

[remote_access]
full_access = true

[remote_access.terminal]
enabled = true

[bmc]
url = "{url}"
username = "root"
secret = "{PASSWORD}"
fingerprint = "{fingerprint}"
"#
    )
}

/// The same section with nothing reviewed: an address and an account, and no
/// certificate this agent will speak to.
fn config_without_a_pin(url: &str) -> String {
    config_with_bmc(url, "").replace("fingerprint = \"\"", "")
}

/// An install that has never been pointed at a controller.
const CONFIG_WITHOUT_BMC: &str = r#"
[server]
host = "127.0.0.1"
port = 3770
name = "test"

[remote_access]
full_access = true

[remote_access.terminal]
enabled = true
"#;

/// The in-memory state, plus the pool so a test can read what was recorded.
async fn app_state(full_access: bool) -> (Arc<AppState>, sqlx::SqlitePool) {
    ensure_crypto_provider();
    let mut config = Config {
        jwt_secret: Some(SECRET.to_string()),
        ..Default::default()
    };
    let mut remote = config.get_remote_access();
    // The grant is gated on the terminal being available, so that switching the
    // terminal off cannot leave this door open behind it. The test server
    // listens on loopback, which counts as a secure transport.
    remote.terminal.enabled = true;
    remote.full_access = Some(full_access);
    config.remote_access = Some(remote);

    let db = sqlx::SqlitePool::connect("sqlite::memory:").await.unwrap();
    sqlx::migrate!("./migrations").run(&db).await.unwrap();
    (AppState::new(Arc::new(config), db.clone()), db)
}

/// Mounts the real route table.
///
/// A scope of its own would assert something about the handler and nothing
/// about what the shipped binary exposes — which route gets which gate is a
/// property of [`configure_api`], and this endpoint is four lines in it.
async fn test_server(state: Arc<AppState>) -> TestServer {
    web_test::server(move || {
        let state = state.clone();
        async move {
            let limit = state.remote_access.exec.max_request_bytes;
            App::new().state(state).configure(configure_api(limit))
        }
    })
    .await
}

fn jwt() -> String {
    generate_token("admin", SECRET).unwrap()
}

// ------------------------------------------------------------- the panel

async fn get_raw(srv: &TestServer, path: &str) -> (u16, String) {
    let resp = srv
        .get(path)
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    let status = resp.status().as_u16();
    let body = resp.body().await.unwrap();
    (status, String::from_utf8(body.to_vec()).unwrap())
}

/// A read, as its status and its body. The code is what the panel phrases; a
/// sentence would be a second vocabulary for the same refusal.
async fn get(srv: &TestServer, path: &str) -> Result<Value, (u16, String)> {
    let (status, text) = get_raw(srv, path).await;
    let body: Value = serde_json::from_str(&text).unwrap_or(Value::Null);
    if !(200..300).contains(&status) {
        return Err((status, error_code(&body)));
    }
    Ok(body)
}

fn error_code(body: &Value) -> String {
    body["error"].as_str().unwrap_or_default().to_string()
}

async fn put(srv: &TestServer, section: Value) -> Result<Value, (u16, String)> {
    let resp = srv
        .put("/api/v1/bmc/settings")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&section)
        .await
        .unwrap();
    let status = resp.status().as_u16();
    // An empty body is a real answer: a 403 is `finish()`, with none at all,
    // and `json()` on one panics.
    let text = String::from_utf8(resp.body().await.unwrap().to_vec()).unwrap();
    let body: Value = serde_json::from_str(&text).unwrap_or(Value::Null);
    if !(200..300).contains(&status) {
        return Err((status, error_code(&body)));
    }
    Ok(body)
}

async fn probe(srv: &TestServer, url: &str) -> Result<Value, (u16, String)> {
    let resp = srv
        .post("/api/v1/bmc/probe")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({ "url": url }))
        .await
        .unwrap();
    let status = resp.status().as_u16();
    // An empty body is a real answer: a 403 is `finish()`, with none at all,
    // and `json()` on one panics.
    let text = String::from_utf8(resp.body().await.unwrap().to_vec()).unwrap();
    let body: Value = serde_json::from_str(&text).unwrap_or(Value::Null);
    if !(200..300).contains(&status) {
        return Err((status, error_code(&body)));
    }
    Ok(body)
}

async fn control(srv: &TestServer, request: Value) -> Result<Value, (u16, String)> {
    let resp = srv
        .post("/api/v1/bmc/control")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&request)
        .await
        .unwrap();
    let status = resp.status().as_u16();
    // An empty body is a real answer: a 403 is `finish()`, with none at all,
    // and `json()` on one panics.
    let text = String::from_utf8(resp.body().await.unwrap().to_vec()).unwrap();
    let body: Value = serde_json::from_str(&text).unwrap_or(Value::Null);
    if !(200..300).contains(&status) {
        return Err((status, error_code(&body)));
    }
    Ok(body)
}

/// The body a save sends, with the password left out so a test that is not
/// about the password does not have to say so.
fn section(url: &str, fingerprint: &str) -> Value {
    json!({ "url": url, "username": "root", "fingerprint": fingerprint })
}

// ----------------------------------------------------------- a fake BMC

/// One request as the fake controller read it.
#[derive(Clone, Debug)]
struct Recorded {
    method: String,
    path: String,
    headers: Vec<(String, String)>,
    body: String,
}

impl Recorded {
    /// Header lookup, case-insensitively: reqwest lowercases what it sends and
    /// nothing here should depend on that.
    fn header(&self, name: &str) -> Option<&str> {
        self.headers
            .iter()
            .find(|(key, _)| key == name)
            .map(|(_, value)| value.as_str())
    }

    fn json(&self) -> Value {
        serde_json::from_str(&self.body).unwrap_or(Value::Null)
    }
}

type Answer = Arc<dyn Fn(&Recorded) -> (u16, String) + Send + Sync>;

/// A fake Redfish service on loopback, answering one request per connection.
#[derive(Clone)]
struct Fake {
    base: String,
    seen: Arc<Mutex<Vec<Recorded>>>,
}

impl Fake {
    async fn start(answer: Answer) -> Fake {
        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let seen = Arc::new(Mutex::new(Vec::new()));
        let recorded = seen.clone();
        tokio::spawn(async move {
            while let Ok((socket, _)) = listener.accept().await {
                let answer = answer.clone();
                let recorded = recorded.clone();
                tokio::spawn(async move { serve(socket, answer, recorded).await });
            }
        });
        Fake {
            base: format!("http://{addr}"),
            seen,
        }
    }

    /// Starts one behind a certificate nothing has reviewed — which is what a
    /// BMC presents, self-signed unless the operator replaced it. Returns the
    /// SHA-256 of its DER, which is the pin.
    async fn start_tls(answer: Answer) -> (Fake, String) {
        ensure_crypto_provider();
        let CertifiedKey { cert, signing_key } =
            generate_simple_self_signed(vec!["localhost".into()]).expect("a certificate");
        let fingerprint = hex::encode(Sha256::digest(cert.der()));
        let tls = ServerConfig::builder_with_provider(Arc::new(ring::default_provider()))
            .with_safe_default_protocol_versions()
            .unwrap()
            .with_no_client_auth()
            .with_single_cert(
                vec![CertificateDer::from(cert.der().to_vec())],
                PrivateKeyDer::Pkcs8(PrivatePkcs8KeyDer::from(signing_key.serialize_der())),
            )
            .unwrap();
        let acceptor = TlsAcceptor::from(Arc::new(tls));

        let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
        let addr = listener.local_addr().unwrap();
        let seen = Arc::new(Mutex::new(Vec::new()));
        let recorded = seen.clone();
        tokio::spawn(async move {
            while let Ok((socket, _)) = listener.accept().await {
                let answer = answer.clone();
                let recorded = recorded.clone();
                let acceptor = acceptor.clone();
                tokio::spawn(async move {
                    // A refused handshake is the answer most of these tests are
                    // about, so the connection is simply dropped.
                    let Ok(socket) = acceptor.accept(socket).await else {
                        return;
                    };
                    serve(socket, answer, recorded).await;
                });
            }
        });
        (
            Fake {
                base: format!("https://localhost:{}", addr.port()),
                seen,
            },
            fingerprint,
        )
    }

    /// What was asked for, oldest first.
    fn requests(&self) -> Vec<Recorded> {
        self.seen.lock().unwrap().clone()
    }

    fn paths(&self) -> Vec<String> {
        self.requests().into_iter().map(|r| r.path).collect()
    }

    /// The one request for a path, or a panic naming what was asked for instead.
    fn request(&self, method: &str, path: &str) -> Recorded {
        self.requests()
            .into_iter()
            .find(|r| r.method == method && r.path == path)
            .unwrap_or_else(|| {
                panic!("no {method} {path} was made; saw {:?}", self.paths());
            })
    }
}

/// The root, as a service that has both a system and a chassis answers it.
fn root() -> Value {
    json!({
        "RedfishVersion": "1.18.0",
        "Product": "Integrated Dell Remote Access Controller",
        "Vendor": "Dell",
        "Systems": { "@odata.id": "/redfish/v1/Systems" },
        "Chassis": { "@odata.id": "/redfish/v1/Chassis" },
        "Links": { "Sessions": { "@odata.id": "/redfish/v1/SessionService/Sessions" } },
    })
}

/// A system whose reset action offers everything the intents need.
fn system(allowable: &[&str]) -> Value {
    json!({
        "PowerState": "On",
        "Manufacturer": "Dell Inc.",
        "Model": "PowerEdge R750",
        "SerialNumber": "CN12345678",
        "BiosVersion": "1.9.2",
        "Status": { "HealthRollup": "OK" },
        "Actions": {
            "#ComputerSystem.Reset": {
                "target": "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset",
                "ResetType@Redfish.AllowableValues": allowable,
            },
        },
    })
}

const RESET_TARGET: &str = "/redfish/v1/Systems/1/Actions/ComputerSystem.Reset";

/// A healthy controller: a root, a session, one system, one chassis and the
/// deprecated pair of sensor documents.
fn healthy(request: &Recorded) -> (u16, String) {
    match (request.method.as_str(), request.path.as_str()) {
        ("GET", "/redfish/v1/") => (200, root().to_string()),
        ("POST", "/redfish/v1/SessionService/Sessions") => (
            201,
            json!({ "@odata.id": SESSION }).to_string(),
        ),
        ("DELETE", SESSION) => (204, String::new()),
        ("GET", "/redfish/v1/Systems") => (
            200,
            json!({ "Members": [{ "@odata.id": "/redfish/v1/Systems/1" }] }).to_string(),
        ),
        // Reached without a credential: the service root is unauthenticated by
        // specification, and it is where the session endpoint is named.
        ("GET", "/redfish/v1/Systems/1") => (
            200,
            system(&[
                "On",
                "ForceOn",
                "GracefulShutdown",
                "ForceOff",
                "GracefulRestart",
                "ForceRestart",
                "PowerCycle",
            ])
            .to_string(),
        ),
        ("GET", "/redfish/v1/Chassis") => (
            200,
            json!({ "Members": [{ "@odata.id": "/redfish/v1/Chassis/1" }] }).to_string(),
        ),
        ("GET", "/redfish/v1/Chassis/1") => (
            200,
            json!({
                "Name": "Chassis",
                "Thermal": { "@odata.id": "/redfish/v1/Chassis/1/Thermal" },
                "Power": { "@odata.id": "/redfish/v1/Chassis/1/Power" },
            })
            .to_string(),
        ),
        ("GET", "/redfish/v1/Chassis/1/Thermal") => (
            200,
            json!({
                "Temperatures": [
                    { "Name": "CPU1 Temp", "ReadingCelsius": 42 },
                    // A sensor with nothing to report, which is a gap rather
                    // than a reading of 0 °C.
                    { "Name": "CPU2 Temp", "ReadingCelsius": null },
                ],
                "Fans": [
                    { "Name": "Fan1A", "Reading": 4680, "ReadingUnits": "RPM" },
                ],
            })
            .to_string(),
        ),
        ("GET", "/redfish/v1/Chassis/1/Power") => (
            200,
            json!({ "PowerControl": [{ "PowerConsumedWatts": 210 }] }).to_string(),
        ),
        ("POST", RESET_TARGET) => (200, String::new()),
        _ => (404, json!({ "error": { "message": "not found" } }).to_string()),
    }
}

/// Starts a healthy controller and configures the agent to talk to it.
async fn healthy_bmc() -> (Fake, String) {
    let bmc = Fake::start(Arc::new(healthy)).await;
    write_config(&config_with_bmc(&bmc.base, SOME_PIN));
    (bmc, SOME_PIN.to_string())
}

async fn serve<S>(mut socket: S, answer: Answer, recorded: Arc<Mutex<Vec<Recorded>>>)
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let Some(request) = read_request(&mut socket).await else {
        return;
    };
    let (status, body) = answer(&request);
    // The session's token travels in a header, which an answer of "a status and
    // a body" cannot express. Emitted here for the one path that answers with
    // one: what the tests assert is the client *reading* it and sending it back
    // on the reads that follow, and a fake that handed out no token would fail
    // every one of them for a reason that is not the subject.
    let token = (200..300).contains(&status)
        && request.method == "POST"
        && request.path.ends_with("/Sessions");
    recorded.lock().unwrap().push(request);

    let reason = match status {
        200 => "OK",
        201 => "Created",
        204 => "No Content",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        404 => "Not Found",
        _ => "Error",
    };
    let extra = if token {
        format!("x-auth-token: {TOKEN}\r\n")
    } else {
        String::new()
    };
    let head = format!(
        "HTTP/1.1 {status} {reason}\r\ncontent-type: application/json\r\n{extra}\
         content-length: {}\r\nconnection: close\r\n\r\n",
        body.len()
    );
    let _ = socket.write_all(head.as_bytes()).await;
    let _ = socket.write_all(body.as_bytes()).await;
    let _ = socket.shutdown().await;
}

/// Reads one request off the socket, heads and body.
///
/// The body is consumed rather than ignored — the login's JSON is one of the
/// things asserted — and because a client still writing when the connection
/// closes reads as a send failure.
async fn read_request(socket: &mut (impl AsyncRead + Unpin)) -> Option<Recorded> {
    let mut seen = Vec::new();
    let mut buf = [0u8; 8192];
    let end = loop {
        match socket.read(&mut buf).await {
            Ok(0) | Err(_) => return None,
            Ok(n) => seen.extend_from_slice(&buf[..n]),
        }
        if let Some(end) = find(&seen, b"\r\n\r\n") {
            let head = String::from_utf8_lossy(&seen[..end]).to_lowercase();
            let want: usize = head
                .lines()
                .find_map(|line| line.strip_prefix("content-length:"))
                .and_then(|value| value.trim().parse().ok())
                .unwrap_or(0);
            if seen.len() >= end + 4 + want {
                break end;
            }
        }
    };

    let head = String::from_utf8_lossy(&seen[..end]).to_string();
    let mut lines = head.lines();
    let mut request_line = lines.next().unwrap_or_default().split_whitespace();
    let method = request_line.next().unwrap_or_default().to_string();
    let path = request_line.next().unwrap_or_default().to_string();
    let headers = lines
        .filter_map(|line| line.split_once(':'))
        .map(|(key, value)| (key.trim().to_lowercase(), value.trim().to_string()))
        .collect();
    let body = String::from_utf8_lossy(&seen[end + 4..]).to_string();

    Some(Recorded {
        method,
        path,
        headers,
        body,
    })
}

fn find(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack
        .windows(needle.len())
        .position(|window| window == needle)
}

// ------------------------------------------------------------- the tests

#[ntex::test]
async fn the_panel_is_answered_with_the_machines_own_readings() {
    let _dir = workspace().await;
    let (bmc, _pin) = healthy_bmc().await;
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let body = get(&srv, "/api/v1/bmc").await.expect("a reading");

    assert_eq!(body["version"], "1.18.0");
    assert_eq!(body["vendor"], "Dell");
    assert_eq!(body["editable"], true);
    assert_eq!(body["system"]["power_state"], "on");
    assert_eq!(body["system"]["serial"], "CN12345678");
    assert_eq!(body["system"]["bios_version"], "1.9.2");
    assert_eq!(body["system"]["health"], "OK");
    assert_eq!(body["chassis"]["name"], "Chassis");

    // The units are the service's and are passed through unchanged: a fan in
    // `Percent` and one in `RPM` are different numbers, and rewriting either
    // into the other would invent data.
    assert_eq!(body["sensors"]["temperatures"][0]["name"], "CPU1 Temp");
    assert_eq!(body["sensors"]["temperatures"][0]["value"], 42.0);
    assert_eq!(body["sensors"]["temperatures"][0]["unit"], "Cel");
    // The unreadable one is a gap, not a reading of 0 °C.
    assert_eq!(body["sensors"]["temperatures"].as_array().unwrap().len(), 1);
    assert_eq!(body["sensors"]["fans"][0]["value"], 4680.0);
    assert_eq!(body["sensors"]["fans"][0]["unit"], "RPM");
    assert_eq!(body["sensors"]["watts"], 210.0);
    assert_eq!(body["sensors_read"], true);
    assert_eq!(body["sensors_truncated"], false);

    // Every intent the service advertises is offered, with the `ResetType`
    // behind it, so the page can say what pressing a button does.
    assert_eq!(
        body["intents"],
        json!([
            "on",
            "gracefulShutdown",
            "forceOff",
            "restart",
            "powerCycle"
        ])
    );
    let restart = body["reset_types"]
        .as_array()
        .unwrap()
        .iter()
        .find(|entry| entry["intent"] == "restart")
        .expect("restart is offered");
    assert_eq!(
        restart["reset_type"], "GracefulRestart",
        "the polite form is preferred where the service offers it"
    );

    // One login per request, and it is a login: the root is read without one,
    // the credential is spent on a session, and every read that follows carries
    // the token rather than the password.
    let login = bmc.request("POST", "/redfish/v1/SessionService/Sessions");
    assert_eq!(login.json()["UserName"], "root");
    assert_eq!(login.json()["Password"], PASSWORD);
    assert!(login.header("x-auth-token").is_none());
    for path in [
        "/redfish/v1/Systems",
        "/redfish/v1/Systems/1",
        "/redfish/v1/Chassis",
        "/redfish/v1/Chassis/1/Thermal",
    ] {
        assert_eq!(
            bmc.request("GET", path).header("x-auth-token"),
            Some(TOKEN),
            "{path} was read without the session's token",
        );
    }
    assert!(
        bmc.request("GET", "/redfish/v1/").header("x-auth-token").is_none(),
        "the service root is read without a credential",
    );

    // And the session is handed back: a BMC keeps a handful of them, and the
    // operator's own browser is usually holding one.
    let closed = bmc.request("DELETE", SESSION);
    assert_eq!(closed.header("x-auth-token"), Some(TOKEN));
}

#[ntex::test]
async fn the_password_reaches_the_bmc_and_never_the_panel() {
    let _dir = workspace().await;
    let (bmc, _pin) = healthy_bmc().await;
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let (status, text) = get_raw(&srv, "/api/v1/bmc/settings").await;
    assert_eq!(status, 200);
    assert!(
        !text.contains(PASSWORD),
        "the settings response carried the password: {text}"
    );
    let body: Value = serde_json::from_str(&text).unwrap();
    // Present as `null`, not omitted: a client round-trips this body, and an
    // absent key would be read as "clear it" by a client that fills it in.
    assert!(body.get("secret").is_some(), "the key is present");
    assert!(body["secret"].is_null());
    assert_eq!(body["secret_set"], true);
    assert_eq!(body["username"], "root");
    assert_eq!(body["fingerprint"], SOME_PIN);
    assert_eq!(body["configured"], true);

    // The same for the page that reads the machine, whose bytes are the other
    // thing a browser gets to see.
    let (status, text) = get_raw(&srv, "/api/v1/bmc").await;
    assert_eq!(status, 200);
    assert!(!text.contains(PASSWORD), "the reading carried the password");

    // And it did reach the machine, which is the half that matters.
    assert_eq!(
        bmc.paths(),
        [
            "/redfish/v1/",
            "/redfish/v1/SessionService/Sessions",
            "/redfish/v1/Systems",
            "/redfish/v1/Systems/1",
            "/redfish/v1/Chassis",
            "/redfish/v1/Chassis/1",
            "/redfish/v1/Chassis/1/Thermal",
            "/redfish/v1/Chassis/1/Power",
            SESSION,
        ],
        "the root, the login, one read per resource, and the session handed back",
    );
}

#[ntex::test]
async fn a_save_keeps_the_password_it_was_not_given() {
    let _dir = workspace().await;
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    // Nothing to dial, so the address is never reached; what this asserts is
    // the file.
    write_config(&config_with_bmc("http://127.0.0.1:1", SOME_PIN));

    // Absent: kept.
    put(
        &srv,
        json!({ "url": "http://127.0.0.1:2", "username": "admin", "fingerprint": SOME_PIN }),
    )
    .await
    .expect("a save");
    let stored = bmc_on_disk().get_bmc();
    assert_eq!(stored.secret.as_deref(), Some(PASSWORD), "kept");
    assert_eq!(stored.username, "admin");
    assert_eq!(stored.url, "http://127.0.0.1:2");

    // An explicit null is the same as absent, which is what a client that got
    // the settings and sent them back does.
    put(
        &srv,
        json!({
            "url": "http://127.0.0.1:3",
            "username": "admin",
            "fingerprint": SOME_PIN,
            "secret": null,
        }),
    )
    .await
    .expect("a save");
    assert_eq!(bmc_on_disk().get_bmc().secret.as_deref(), Some(PASSWORD));

    // Empty: cleared. Without this there is no way to take a password back out
    // from the panel.
    let body = put(
        &srv,
        json!({
            "url": "http://127.0.0.1:3",
            "username": "admin",
            "fingerprint": SOME_PIN,
            "secret": "",
        }),
    )
    .await
    .expect("a save");
    assert_eq!(bmc_on_disk().get_bmc().secret, None);
    assert_eq!(body["secret_set"], false);
    assert!(body["secret"].is_null());

    // A value: replaced.
    put(
        &srv,
        json!({
            "url": "http://127.0.0.1:3",
            "username": "admin",
            "fingerprint": SOME_PIN,
            "secret": "another-one",
        }),
    )
    .await
    .expect("a save");
    assert_eq!(bmc_on_disk().get_bmc().secret.as_deref(), Some("another-one"));
}

#[ntex::test]
async fn a_save_a_controller_cannot_be_read_through_is_refused() {
    let _dir = workspace().await;
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    write_config(&config_with_bmc("http://127.0.0.1:1", SOME_PIN));
    let before = std::fs::read_to_string("config.toml").unwrap();

    for (body, expected) in [
        // A scheme reqwest cannot dial.
        (
            json!({ "url": "bmc.local", "username": "root", "fingerprint": SOME_PIN }),
            "invalidUrl",
        ),
        // An address with no account is not one this agent can log in to.
        (
            json!({ "url": "http://127.0.0.1:1", "username": "  ", "fingerprint": SOME_PIN }),
            "missingUsername",
        ),
        // And an address with no certificate reviewed is one nothing can be
        // read through: the request that would find that out carries the
        // password, so the save is refused and the operator probes first.
        (
            json!({ "url": "http://127.0.0.1:1", "username": "root", "fingerprint": "" }),
            "missingFingerprint",
        ),
        (
            json!({ "url": "http://127.0.0.1:1", "username": "root", "fingerprint": "nonsense" }),
            "missingFingerprint",
        ),
    ] {
        assert_eq!(put(&srv, body.clone()).await.unwrap_err(), (400, expected.to_string()), "{body}");
        assert_eq!(
            std::fs::read_to_string("config.toml").unwrap(),
            before,
            "a refused save changed the file",
        );
    }

    // Clearing is not a mistake: it is how the credential is taken back out.
    put(&srv, json!({ "url": "", "fingerprint": "" }))
        .await
        .expect("clearing");
    let stored = bmc_on_disk().get_bmc();
    assert!(!stored.is_configured());
    assert_eq!(
        stored.secret.as_deref(),
        Some(PASSWORD),
        "clearing the address keeps the password, which is why clearing is not a save that needs a pin",
    );
}

#[ntex::test]
async fn a_certificate_nobody_reviewed_is_refused() {
    let _dir = workspace().await;
    let (bmc, pin) = Fake::start_tls(Arc::new(healthy)).await;
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    // An address, an account, and nothing pinned — which is what a config
    // written by hand or left over from before a certificate changed looks
    // like. Nothing reviewed means nothing accepted.
    write_config(&config_without_a_pin(&bmc.base));
    assert_eq!(
        get(&srv, "/api/v1/bmc").await.unwrap_err(),
        (400, "certificateRejected".to_string()),
    );
    assert!(
        bmc.paths().is_empty(),
        "a request was made to a certificate nobody reviewed: {:?}",
        bmc.paths()
    );

    // The same address with a pin that is not this certificate's is the same
    // refusal: a fingerprint that is simply wrong is not a near miss.
    let wrong = format!("{}0", &pin[..63]);
    write_config(&config_with_bmc(&bmc.base, &wrong));
    assert_eq!(
        get(&srv, "/api/v1/bmc").await.unwrap_err(),
        (400, "certificateRejected".to_string()),
    );

    // And the reviewed one is the only one accepted.
    write_config(&config_with_bmc(&bmc.base, &pin));
    let body = get(&srv, "/api/v1/bmc").await.expect("the reviewed one");
    assert_eq!(body["system"]["power_state"], "on");
}

#[ntex::test]
async fn the_probe_reads_the_certificate_without_sending_anything() {
    let _dir = workspace().await;
    let (bmc, pin) = Fake::start_tls(Arc::new(healthy)).await;
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    // Not configured at all: the probe is the first step, and it takes the
    // address in the request so nothing has to be saved to ask.
    write_config(CONFIG_WITHOUT_BMC);

    let body = probe(&srv, &bmc.base).await.expect("a certificate");

    assert_eq!(body["fingerprint"], pin);
    // The form a BMC's own interface prints, which is what an operator compares
    // against the page they are looking at.
    let pretty = body["fingerprint_pretty"].as_str().expect("a pretty form");
    assert_eq!(pretty.len(), 95, "64 hex digits in 32 pairs");
    assert!(pretty.starts_with(&pin[..2].to_uppercase()));
    assert_eq!(&pretty[2..3], ":");

    // Nothing was sent: the handshake is meant to fail, and a probe that went
    // through would mean the certificate was accepted rather than reviewed.
    assert!(
        bmc.paths().is_empty(),
        "the probe sent a request: {:?}",
        bmc.paths()
    );

    // A pin the operator pasted from that page is normalized rather than
    // refused — colons, spaces, dashes and either case.
    let pasted = pretty.to_lowercase().replace(':', " ");
    let body = probe(&srv, &bmc.base).await.expect("a certificate");
    assert_eq!(body["fingerprint"], pin);
    put(
        &srv,
        section(&bmc.base, &pasted),
    )
    .await
    .expect("a save with what the page printed");
    assert_eq!(bmc_on_disk().get_bmc().fingerprint, pin);
}

#[ntex::test]
async fn a_reset_goes_to_the_target_the_service_named() {
    let _dir = workspace().await;
    let (bmc, _pin) = healthy_bmc().await;
    let (state, db) = app_state(true).await;
    let srv = test_server(state).await;

    let body = control(&srv, json!({ "intent": "gracefulShutdown" }))
        .await
        .expect("a reset");

    assert_eq!(body["reset_type"], "GracefulShutdown");
    // What the machine is moving *from*: the request is not held open for the
    // two minutes a shutdown takes, so the page re-reads until it changes.
    assert_eq!(body["power_state"], "on");

    let sent = bmc.request("POST", RESET_TARGET);
    assert_eq!(sent.json(), json!({ "ResetType": "GracefulShutdown" }));
    // The action is addressed at the target the service gave, never
    // `{system}/Actions/...` built by concatenation.
    assert_eq!(sent.header("x-auth-token"), Some(TOKEN));

    let (kind, action, result, subject): (String, String, String, Option<String>) = sqlx::query_as(
        "SELECT kind, action, result, subject FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();
    assert_eq!((kind.as_str(), action.as_str(), result.as_str()), ("bmc", "write", "ok"));
    assert_eq!(subject.as_deref(), Some("gracefulShutdown"));

    // `restart` prefers the polite form where the service offers one, which is
    // the difference between a machine that reboots and one that loses power.
    let body = control(&srv, json!({ "intent": "restart" }))
        .await
        .expect("a restart");
    assert_eq!(body["reset_type"], "GracefulRestart");
}

#[ntex::test]
async fn an_intent_nothing_satisfies_is_not_substituted() {
    let _dir = workspace().await;
    // A service that does not implement a graceful shutdown. `ForceOff` is not
    // a shutdown, and quietly substituting it would take a machine down hard
    // when someone asked for the polite thing.
    let bmc = Fake::start(Arc::new(|request: &Recorded| {
        match (request.method.as_str(), request.path.as_str()) {
            ("GET", "/redfish/v1/Systems/1") => (
                200,
                system(&["On", "ForceOff", "ForceRestart"]).to_string(),
            ),
            other => healthy(&Recorded {
                method: other.0.to_string(),
                path: other.1.to_string(),
                headers: Vec::new(),
                body: String::new(),
            }),
        }
    }))
    .await;
    write_config(&config_with_bmc(&bmc.base, SOME_PIN));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    // Offered: nothing behind it is offered, and the page says so rather than
    // showing a button that fails.
    let body = get(&srv, "/api/v1/bmc").await.expect("a reading");
    assert_eq!(
        body["intents"],
        json!(["on", "forceOff", "restart", "powerCycle"]),
        "a graceful shutdown is the one with nothing behind it here and is not \
         offered; `powerCycle` is, through the `ForceRestart` the model falls \
         back to",
    );

    // Asked for anyway: answered as such, and nothing was sent.
    assert_eq!(
        control(&srv, json!({ "intent": "gracefulShutdown" }))
            .await
            .unwrap_err(),
        (400, "unsupportedIntent".to_string()),
    );
    assert!(
        !bmc.paths().iter().any(|p| p == RESET_TARGET),
        "a reset was sent for an intent the service does not implement",
    );
}

#[ntex::test]
async fn an_unknown_intent_is_refused_before_anything_is_dialed() {
    let _dir = workspace().await;
    let (bmc, _pin) = healthy_bmc().await;
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    assert_eq!(
        control(&srv, json!({ "intent": "nuke" })).await.unwrap_err(),
        (400, "invalidIntent".to_string()),
    );
    // A misspelling is the caller's mistake, and the login it would have spent
    // is a request the machine never needed to see.
    assert!(bmc.paths().is_empty(), "dialed anyway: {:?}", bmc.paths());
}

#[ntex::test]
async fn something_that_is_not_a_service_is_told_apart_from_an_unreachable_one() {
    let _dir = workspace().await;
    // A static host answering every path with its index page, which is what a
    // mistyped address usually is.
    let host = Fake::start(Arc::new(|_: &Recorded| {
        (200, json!({ "title": "ServerBox" }).to_string())
    }))
    .await;
    write_config(&config_with_bmc(&host.base, SOME_PIN));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    assert_eq!(
        get(&srv, "/api/v1/bmc").await.unwrap_err(),
        (400, "notAService".to_string()),
    );

    // A port nothing is listening on is a transport failure, and is answered as
    // a bad gateway rather than as something about the request.
    let listener = TcpListener::bind("127.0.0.1:0").await.unwrap();
    let addr = listener.local_addr().unwrap();
    drop(listener);
    write_config(&config_with_bmc(&format!("http://{addr}"), SOME_PIN));
    assert_eq!(
        get(&srv, "/api/v1/bmc").await.unwrap_err(),
        (502, "unreachable".to_string()),
    );
}

#[ntex::test]
async fn an_upstream_refusal_is_never_this_agents_own_status() {
    let _dir = workspace().await;
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    // A wrong password. 401 here would log the operator out of the panel, and
    // it is the *agent's* credential to a machine the operator is not signed in
    // to that was refused.
    let refused = Fake::start(Arc::new(|request: &Recorded| {
        if request.path == "/redfish/v1/" {
            return (200, root().to_string());
        }
        (401, json!({ "error": { "message": "bad credentials" } }).to_string())
    }))
    .await;
    write_config(&config_with_bmc(&refused.base, SOME_PIN));
    let (status, code) = get(&srv, "/api/v1/bmc").await.unwrap_err();
    assert_eq!((status, code.as_str()), (400, "unauthorized"));
    assert_ne!(status, 401, "the panel's client logs out on this agent's 401");

    // A licence-gated resource is its own code: what to fix is not the password.
    let gated = Fake::start(Arc::new(|request: &Recorded| {
        if request.path == "/redfish/v1/" {
            return (200, root().to_string());
        }
        if request.method == "POST" {
            return (201, json!({ "@odata.id": SESSION }).to_string());
        }
        (403, json!({ "error": { "message": "licence required" } }).to_string())
    }))
    .await;
    write_config(&config_with_bmc(&gated.base, SOME_PIN));
    assert_eq!(
        get(&srv, "/api/v1/bmc").await.unwrap_err(),
        (400, "forbidden".to_string()),
    );

    // And nothing the service said is echoed: its error document is not this
    // agent's to pass on.
    let (_, text) = get_raw(&srv, "/api/v1/bmc").await;
    assert!(!text.contains("licence"), "the service's words came through: {text}");
}

#[ntex::test]
async fn a_chassis_that_cannot_be_read_loses_only_the_sensors() {
    let _dir = workspace().await;
    // A service that answers the system and denies the chassis, which happens
    // on its own permissions.
    let bmc = Fake::start(Arc::new(|request: &Recorded| {
        if request.path == "/redfish/v1/Chassis" {
            return (403, json!({ "error": { "message": "denied" } }).to_string());
        }
        healthy(request)
    }))
    .await;
    write_config(&config_with_bmc(&bmc.base, SOME_PIN));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let body = get(&srv, "/api/v1/bmc").await.expect("the machine, less its chassis");

    assert_eq!(body["system"]["power_state"], "on");
    assert!(body.get("chassis").is_none(), "no chassis was read");
    // `sensors_read: false` with an empty reading is the honest pair: an empty
    // reading alone reads as a machine with no fans.
    assert_eq!(body["sensors_read"], false);
    assert!(body["sensors"]["temperatures"].as_array().unwrap().is_empty());
    assert!(body["sensors"]["watts"].is_null());
}

#[ntex::test]
async fn a_controller_with_no_session_endpoint_is_presented_with_the_account() {
    let _dir = workspace().await;
    // A service that names no session endpoint, which is what the model says
    // an absent `sessions` means: Basic is the only way in.
    let bmc = Fake::start(Arc::new(|request: &Recorded| {
        if request.path == "/redfish/v1/" {
            let mut root = root();
            root.as_object_mut().unwrap().remove("Links");
            return (200, root.to_string());
        }
        healthy(request)
    }))
    .await;
    write_config(&config_with_bmc(&bmc.base, SOME_PIN));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let body = get(&srv, "/api/v1/bmc").await.expect("a reading");
    assert_eq!(body["system"]["power_state"], "on");

    assert!(
        !bmc.paths().iter().any(|p| p.contains("Sessions")),
        "a session was created at an endpoint the service never named",
    );
    let read = bmc.request("GET", "/redfish/v1/Systems");
    let auth = read.header("authorization").expect("the account");
    assert!(auth.starts_with("Basic "), "{auth}");
    // `base64("root:<password>")`, which is what every implementation agrees on
    // — asserted through the decode rather than against a string this test
    // would have copied out of the implementation.
    let decoded = String::from_utf8(
        base64_decode(auth.trim_start_matches("Basic ")).expect("valid base64"),
    )
    .unwrap();
    assert_eq!(decoded, format!("root:{PASSWORD}"));
}

/// Base64 decoding, as RFC 4648 fixes it. Here rather than in the crate: the
/// crate encodes and only the test decodes, and a decoder in the crate would be
/// a second implementation nothing uses.
fn base64_decode(input: &str) -> Option<Vec<u8>> {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let mut out = Vec::with_capacity(input.len() / 4 * 3);
    let mut buffer: u32 = 0;
    let mut bits = 0;
    for byte in input.bytes().filter(|b| *b != b'=') {
        let value = ALPHABET.iter().position(|c| *c == byte)? as u32;
        buffer = buffer << 6 | value;
        bits += 6;
        if bits >= 8 {
            bits -= 8;
            out.push((buffer >> bits) as u8);
        }
    }
    Some(out)
}

#[ntex::test]
async fn nothing_is_configured_yet_but_the_settings_still_read() {
    let _dir = workspace().await;
    write_config(CONFIG_WITHOUT_BMC);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    // The page has to be able to open and say "nothing is set up", which a
    // refusal to answer would not let it do.
    let body = get(&srv, "/api/v1/bmc/settings").await.expect("settings");
    assert_eq!(body["configured"], false);
    assert_eq!(body["secret_set"], false);
    assert_eq!(body["fingerprint_set"], false);

    assert_eq!(
        get(&srv, "/api/v1/bmc").await.unwrap_err(),
        (400, "notConfigured".to_string()),
    );
    assert_eq!(
        probe(&srv, "").await.unwrap_err(),
        (400, "notConfigured".to_string()),
    );
}

#[ntex::test]
async fn saving_and_resetting_are_refused_without_the_shell_grant() {
    let _dir = workspace().await;
    let (bmc, _pin) = healthy_bmc().await;
    let (state, db) = app_state(false).await;
    let srv = test_server(state).await;

    // A caller who may only read can still read: the panel opens read-only
    // rather than failing on the first press.
    let body = get(&srv, "/api/v1/bmc").await.expect("a reading");
    assert_eq!(body["editable"], false);
    assert_eq!(
        get(&srv, "/api/v1/bmc/settings").await.expect("settings")["editable"],
        false,
    );

    assert_eq!(
        put(&srv, section(&bmc.base, SOME_PIN)).await.unwrap_err().0,
        403,
    );
    assert_eq!(
        control(&srv, json!({ "intent": "forceOff" })).await.unwrap_err().0,
        403,
    );

    // A refusal is what someone reading this table is looking for, and a
    // refusal has no subject: nothing was named.
    for _ in 0..2 {
        let (kind, action, result, subject): (String, String, String, Option<String>) =
            sqlx::query_as(
                "SELECT kind, action, result, subject FROM access_log ORDER BY id DESC LIMIT 1",
            )
            .fetch_one(&db)
            .await
            .unwrap();
        assert_eq!((kind.as_str(), action.as_str(), result.as_str()), ("bmc", "denied", "denied"));
        assert_eq!(subject, None);
        sqlx::query("DELETE FROM access_log WHERE id = (SELECT MAX(id) FROM access_log)")
            .execute(&db)
            .await
            .unwrap();
    }

    // And nothing was sent to the machine.
    assert!(
        !bmc.paths().iter().any(|p| p == RESET_TARGET),
        "a refused request reached the machine",
    );
}

#[ntex::test]
async fn capabilities_say_this_agent_serves_bmc() {
    let _dir = workspace().await;
    let (state, _db) = app_state(false).await;
    let srv = test_server(state).await;

    let resp = srv
        .get("/api/v1/capabilities")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send()
        .await
        .unwrap();
    let body: Value = resp.json().await.unwrap();

    // Served is not a grant: the field says the endpoint is here, and
    // `editable` in each response says what this caller may do with it.
    assert_eq!(body["remote_access"]["bmc"], true);
    assert_eq!(body["remote_access"]["full_access"], false);
}
