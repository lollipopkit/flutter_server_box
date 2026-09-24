//! `GET/PUT /api/v1/pve/*` end to end: the real route table, a real
//! `config.toml`, and a fake cluster this test owns on loopback.
//!
//! The fake is routed by path and records what it was asked for, so what is
//! asserted is the request the agent *composed* — the path a control was
//! addressed at, the form a login was sent as, the cookie and the CSRF header a
//! write carries — rather than a shape a helper agreed with itself about.
//! `tests/ai_api.rs` does the same for the model endpoint.
//!
//! Four things here cannot be shown by the module's own unit tests, because
//! each is a decision that spans the wire:
//!
//! - **No upstream status is answered as itself.** PVE answering 401 is a 400
//!   with `loginFailed`; `frontend/src/lib/api.ts` logs the operator out on a
//!   401, and what failed is the *agent's* credential to a machine the operator
//!   is not signed in to. The test asserts the status is not 401 by name.
//! - **The secret reaches PVE and never the panel.** The login's form carries
//!   it, a `GET /pve/settings` answers `null` with `secret_set` beside it, and
//!   the response bytes are searched for the plaintext.
//! - **A save keeps the secret it was not given.** The test reads the file for
//!   that, not the answer, since the answer is built from the request.
//! - **Saving is `full_access`.** A `PUT` that sends `secret: null` keeps what
//!   is stored while the address changes, so a caller with less could point
//!   this agent at a cluster of their own and read the credential out of the
//!   login it then makes.
//!
//! `config_file::CONFIG_PATH` is relative to the process working directory on
//! purpose, so this file chdirs into a temp directory — once, since cargo gives
//! each integration test file its own process — and serialises its tests, which
//! all write the same `config.toml`.

use std::path::PathBuf;
use std::sync::{Arc, Mutex, Once, OnceLock};

use ntex::web::App;
use ntex::web::test::{self as web_test, TestServer};
use percent_encoding::percent_decode_str;
use rcgen::{CertifiedKey, generate_simple_self_signed};
use rustls::ServerConfig;
use rustls::crypto::ring;
use rustls::pki_types::{CertificateDer, PrivateKeyDer, PrivatePkcs8KeyDer};
use serde_json::{Value, json};
use server_box_monitor::api::auth::generate_token;
use server_box_monitor::api::server::{AppState, configure_api};
use server_box_monitor::core::config::Config;
use tokio::io::{AsyncRead, AsyncReadExt, AsyncWrite, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::{Mutex as AsyncMutex, MutexGuard};
use tokio_rustls::TlsAcceptor;

const SECRET: &str = "test-secret-that-is-long-enough-32ch";

/// The listing both halves of this feature assert against — the app's Dart
/// model, `crates/sbm_parser/tests/pve_compat.rs`, and here — so "the panel
/// sees what the app sees" is a claim about the same bytes.
///
/// TODO(migration): move into this crate when the Dart half is deleted; the
/// fixture lives at the repository root because that is where the app reads it.
const CLUSTER_RESOURCES: &str = concat!(
    env!("CARGO_MANIFEST_DIR"),
    "/../test/fixtures/pve/cluster_resources.json"
);

/// What the fake cluster answers a login with. Opaque strings: what is asserted
/// is that they come back on the requests that follow, not what they say.
const TICKET: &str = "PVE:root@pam:ABC123";
const CSRF: &str = "csrf-token-xyz";
const UPID: &str = "UPID:pve:0000ABCD:00000000:00000000:qmstart:101:root@pam:";

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
        let dir = std::env::temp_dir().join(format!("sbm-pve-api-{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        std::env::set_current_dir(&dir).unwrap();
        AsyncMutex::new(dir)
    });
    dir.lock().await
}

fn write_config(contents: &str) {
    std::fs::write("config.toml", contents).unwrap();
}

/// The `[pve]` section **as the file holds it**, which is what a save is judged
/// on rather than what a response said about it.
fn pve_on_disk() -> Config {
    toml::from_str(&std::fs::read_to_string("config.toml").unwrap()).unwrap()
}

/// A cluster configured with a password credential, which is what the login
/// tests dial.
fn config_with_password(url: &str, secret: &str) -> String {
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

[pve]
url = "{url}"
auth = "password"
username = "root"
realm = "pam"
secret = "{secret}"
"#
    )
}

fn config_with_token(url: &str) -> String {
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

[pve]
url = "{url}"
auth = "token"
username = "root"
realm = "pam"
token_id = "automation"
secret = "token-secret"
"#
    )
}

/// An install that has never been pointed at a cluster.
const CONFIG_WITHOUT_PVE: &str = r#"
[server]
host = "127.0.0.1"
port = 3770
name = "test"

[remote_access]
full_access = true

[remote_access.terminal]
enabled = true
"#;

/// The same with the shell grant switched off, so the panel may read the
/// cluster and may neither save the credential nor act on a guest.
fn without_full_access() -> String {
    config_with_password("http://127.0.0.1:1", "hunter2").replace("full_access = true", "full_access = false")
}

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
/// property of [`configure_api`], and this endpoint is three lines in it.
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
        .put("/api/v1/pve/settings")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&section)
        .await
        .unwrap();
    let status = resp.status().as_u16();
    let body: Value = resp.json().await.unwrap();
    if !(200..300).contains(&status) {
        return Err((status, error_code(&body)));
    }
    Ok(body)
}

async fn control(srv: &TestServer, request: Value) -> Result<Value, (u16, String)> {
    let resp = srv
        .post("/api/v1/pve/control")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&request)
        .await
        .unwrap();
    let status = resp.status().as_u16();
    let body: Value = resp.json().await.unwrap();
    if !(200..300).contains(&status) {
        return Err((status, error_code(&body)));
    }
    Ok(body)
}

// ------------------------------------------------------- a fake cluster

/// One request as the fake cluster read it.
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

    /// One field of a form body, decoded. The values the tests send are plain
    /// enough to read back undecoded, which is why this is here at all — the
    /// assertion is that the *password* arrived, and it arrives percent-encoded
    /// like every other form value.
    fn form(&self, name: &str) -> Option<String> {
        self.body.split('&').find_map(|pair| {
            let (key, value) = pair.split_once('=')?;
            (key == name).then(|| {
                percent_decode_str(&value.replace('+', " "))
                    .decode_utf8_lossy()
                    .to_string()
            })
        })
    }
}

type Answer = Arc<dyn Fn(&Recorded) -> (u16, String) + Send + Sync>;

/// A fake PVE API on loopback, answering one request per connection.
#[derive(Clone)]
struct Fake {
    base: String,
    seen: Arc<Mutex<Vec<Recorded>>>,
}

impl Fake {
    /// Starts one over plain HTTP and answers the address to configure. Plain
    /// rather than TLS: a real install answers on TLS, but nothing this
    /// endpoint composes depends on the scheme, and `ignore_cert` has a test
    /// of its own below.
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

    /// Starts one behind a certificate nothing trusts, which is what a default
    /// PVE install presents.
    async fn start_tls(answer: Answer) -> Fake {
        ensure_crypto_provider();
        let CertifiedKey { cert, signing_key } =
            generate_simple_self_signed(vec!["localhost".into()]).expect("a certificate");
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
                    // A refused handshake is the answer this test is about, so
                    // the connection is simply dropped.
                    let Ok(socket) = acceptor.accept(socket).await else {
                        return;
                    };
                    serve(socket, answer, recorded).await;
                });
            }
        });
        Fake {
            base: format!("https://localhost:{}", addr.port()),
            seen,
        }
    }

    /// What was asked for, oldest first.
    fn requests(&self) -> Vec<Recorded> {
        self.seen.lock().unwrap().clone()
    }

    fn paths(&self) -> Vec<String> {
        self.requests().into_iter().map(|r| r.path).collect()
    }
}

/// A healthy cluster: a ticket, a release, the captured listing, and a UPID for
/// a status change.
fn healthy(request: &Recorded) -> (u16, String) {
    match (request.method.as_str(), request.path.as_str()) {
        ("POST", "/api2/json/access/ticket") => (
            200,
            json!({"data": {
                "ticket": TICKET,
                "CSRFPreventionToken": CSRF,
                "username": "root@pam",
            }})
            .to_string(),
        ),
        ("GET", "/api2/json/version") => (200, json!({"data": {"release": "8.2.4"}}).to_string()),
        ("GET", "/api2/json/cluster/resources") => (
            200,
            std::fs::read_to_string(CLUSTER_RESOURCES).expect("the captured listing"),
        ),
        (_, path) if path.contains("/status/") => {
            (200, json!({"data": UPID}).to_string())
        }
        _ => (404, json!({"data": null}).to_string()),
    }
}

/// The same cluster, answering `status` to everything — which is how a refusal
/// of PVE's own is produced.
fn always(status: u16, body: Value) -> Answer {
    Arc::new(move |_| (status, body.to_string()))
}

async fn serve<S>(mut socket: S, answer: Answer, recorded: Arc<Mutex<Vec<Recorded>>>)
where
    S: AsyncRead + AsyncWrite + Unpin,
{
    let Some(request) = read_request(&mut socket).await else {
        return;
    };
    let (status, body) = answer(&request);
    recorded.lock().unwrap().push(request);

    let reason = match status {
        200 => "OK",
        400 => "Bad Request",
        401 => "Unauthorized",
        403 => "Forbidden",
        500 => "Internal Server Error",
        _ => "Error",
    };
    let head = format!(
        "HTTP/1.1 {status} {reason}\r\ncontent-type: application/json\r\n\
         content-length: {}\r\nconnection: close\r\n\r\n",
        body.len()
    );
    let _ = socket.write_all(head.as_bytes()).await;
    let _ = socket.write_all(body.as_bytes()).await;
    let _ = socket.shutdown().await;
}

/// Reads one request off the socket, heads and body.
///
/// The body is consumed rather than ignored — the login's form is one of the
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
async fn the_panel_is_answered_with_the_clusters_own_listing() {
    let _dir = workspace().await;
    let cluster = Fake::start(Arc::new(healthy)).await;
    write_config(&config_with_password(&cluster.base, "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let body = get(&srv, "/api/v1/pve/resources").await.expect("a listing");

    assert_eq!(body["release"], "8.2.4");
    assert_eq!(body["editable"], true);

    let resources = body["resources"].as_array().expect("an array").clone();
    assert_eq!(resources.len(), 8, "the captured cluster");
    // Sorted by kind and then by name, which is the parser's decision and not
    // the cluster's: two refreshes of one page show the same rows in the same
    // places whatever order PVE answered in.
    let ids: Vec<&str> = resources.iter().map(|r| r["id"].as_str().unwrap()).collect();
    assert_eq!(
        ids,
        [
            "node/pve",
            "qemu/101",
            "qemu/102",
            "lxc/100",
            "storage/pve/DSM",
            "storage/pve/hard",
            "storage/pve/local",
            "sdn/pve/localnetwork",
        ]
    );
    assert_eq!(resources[0]["type"], "node");
    assert_eq!(resources[0]["status"], "online");
    assert_eq!(resources[1]["status"], "stopped");
    // Units are PVE's and passed through unchanged: bytes, and `cpu` as a
    // fraction. A panel that showed 0.054 as a percentage would be off by 100.
    assert_eq!(resources[1]["maxmem"], 6442450944u64);
    assert_eq!(resources[2]["name"], "win");
    assert_eq!(resources[2]["type"], "qemu");
    assert_eq!(resources[3]["name"], "Jellyfin");
    assert_eq!(resources[3]["type"], "lxc");
    assert_eq!(
        resources[6]["content"], "backup,images,iso,rootdir,snippets,vztmpl",
        "content is sorted, not handed on as PVE listed it"
    );

    // One login per request, and it is a login: the credential is spent on a
    // ticket, and the two reads that follow carry it rather than the password.
    assert_eq!(
        cluster.paths(),
        [
            "/api2/json/access/ticket",
            "/api2/json/cluster/resources",
            "/api2/json/version",
        ]
    );
}

#[ntex::test]
async fn a_password_is_spent_on_a_ticket_the_following_requests_carry() {
    let _dir = workspace().await;
    let cluster = Fake::start(Arc::new(healthy)).await;
    write_config(&config_with_password(&cluster.base, "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    get(&srv, "/api/v1/pve/resources").await.expect("a listing");

    let requests = cluster.requests();
    let login = &requests[0];
    assert_eq!(login.method, "POST");
    assert_eq!(login.form("username").as_deref(), Some("root"));
    assert_eq!(login.form("realm").as_deref(), Some("pam"));
    assert_eq!(login.form("password").as_deref(), Some("hunter2"));
    // PVE ≥ 6 answers the newer shape with this; without it an account with
    // two-factor authentication on is not told that it is.
    assert_eq!(login.form("new-format").as_deref(), Some("1"));

    // The ticket is presented as the cookie PVE reads, and the CSRF token
    // beside it — a read needs the cookie, a write needs both.
    let listing = &requests[1];
    assert_eq!(
        listing.header("cookie"),
        Some(format!("PVEAuthCookie={TICKET}").as_str())
    );
    assert_eq!(listing.header("csrfpreventiontoken"), Some(CSRF));
}

#[ntex::test]
async fn a_token_is_presented_as_a_header_and_no_ticket_is_asked_for() {
    let _dir = workspace().await;
    let cluster = Fake::start(Arc::new(healthy)).await;
    write_config(&config_with_token(&cluster.base));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    get(&srv, "/api/v1/pve/resources").await.expect("a listing");

    let requests = cluster.requests();
    assert!(
        !requests.iter().any(|r| r.path.contains("/access/ticket")),
        "a token authenticates without a ticket: {:?}",
        cluster.paths()
    );
    for request in &requests {
        assert_eq!(
            request.header("authorization"),
            Some("PVEAPIToken=root@pam!automation=token-secret"),
            "every request carries the token, at {}",
            request.path
        );
    }
}

#[ntex::test]
async fn a_secret_the_agent_holds_is_never_in_an_answer() {
    let _dir = workspace().await;
    let cluster = Fake::start(Arc::new(healthy)).await;
    write_config(&config_with_password(&cluster.base, "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let (status, text) = get_raw(&srv, "/api/v1/pve/settings").await;
    assert_eq!(status, 200);
    // The bytes, not a field: a value smuggled into a detail would otherwise
    // pass a check that only looked where it expected it.
    assert!(!text.contains("hunter2"), "the panel was told the secret: {text}");

    let body: Value = serde_json::from_str(&text).unwrap();
    // `null` rather than absent, so a client that round-trips this view hands
    // back a `null` that means "keep what is stored" instead of omitting a
    // field it never saw.
    assert!(body["secret"].is_null());
    assert_eq!(body["secret_set"], true);
    assert_eq!(body["token_id"], "");
    assert_eq!(body["configured"], true);
    assert_eq!(body["editable"], true);
}

#[ntex::test]
async fn a_control_acts_on_the_guest_the_page_named() {
    let _dir = workspace().await;
    let cluster = Fake::start(Arc::new(healthy)).await;
    write_config(&config_with_password(&cluster.base, "hunter2"));
    let (state, db) = app_state(true).await;
    let srv = test_server(state).await;

    let body = control(
        &srv,
        json!({"node": "pve", "kind": "qemu", "vmid": 101, "action": "shutdown"}),
    )
    .await
    .expect("a status change");
    assert_eq!(body["upid"], UPID);

    let requests = cluster.requests();
    let last = requests.last().unwrap();
    assert_eq!(last.method, "POST");
    assert_eq!(last.path, "/api2/json/nodes/pve/qemu/101/status/shutdown");
    // A write carries the CSRF token as well as the cookie.
    assert_eq!(last.header("csrfpreventiontoken"), Some(CSRF));

    // The row names the action, the guest and the node. The account the agent
    // dials as and PVE's own error text are not in it.
    let (kind, action, result, subject, detail): (
        String,
        String,
        String,
        Option<String>,
        Option<String>,
    ) = sqlx::query_as(
        "SELECT kind, action, result, subject, detail FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();
    assert_eq!(
        (kind.as_str(), action.as_str(), result.as_str()),
        ("pve", "write", "ok")
    );
    assert_eq!(subject.as_deref(), Some("shutdown qemu/101"));
    assert!(detail.unwrap().starts_with("node=pve upid=UPID:pve:"));
}

#[ntex::test]
async fn an_action_this_build_does_not_have_is_refused_before_the_cluster_is_dialed() {
    let _dir = workspace().await;
    let cluster = Fake::start(Arc::new(healthy)).await;
    write_config(&config_with_password(&cluster.base, "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let cases = [
        (
            json!({"node": "pve", "kind": "docker", "vmid": 101, "action": "start"}),
            "invalidKind",
        ),
        (
            json!({"node": "pve", "kind": "qemu", "vmid": 101, "action": "suspend"}),
            "invalidAction",
        ),
        // The node and the vmid are checked by `sbm_parser::pve`, so a caller
        // cannot reach a path of its own making.
        (
            json!({"node": "pve/../..", "kind": "qemu", "vmid": 101, "action": "start"}),
            "invalidNode",
        ),
        (
            json!({"node": "pve", "kind": "qemu", "vmid": 1, "action": "start"}),
            "invalidVmid",
        ),
    ];
    for (request, code) in cases {
        let (status, answer) = control(&srv, request).await.expect_err("refused");
        assert_eq!(status, 400, "{code} answered {status}");
        assert_eq!(answer, code);
    }
    assert!(
        cluster.requests().is_empty(),
        "a refused action dialed the cluster: {:?}",
        cluster.paths()
    );
}

#[ntex::test]
async fn an_upstream_refusal_is_never_the_panels_own_status() {
    let _dir = workspace().await;

    // PVE refusing the login: the credential is what failed, and the operator
    // is signed in to this panel either way.
    let refusing = Fake::start(always(401, json!({"data": null}))).await;
    write_config(&config_with_password(&refusing.base, "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let (status, code) = get(&srv, "/api/v1/pve/resources")
        .await
        .expect_err("a refused login is not a listing");
    assert_eq!(code, "loginFailed");
    assert_ne!(status, 401, "the panel's client logs out on a 401");
    assert_eq!(status, 400);

    // PVE refusing the account what it asked for. Its own code rather than
    // `loginFailed`: a ticket carries the whole account's rights, an API token
    // has an ACL of its own, and the two are different things to fix.
    let forbidding = Fake::start(Arc::new(|request: &Recorded| {
        if request.path.contains("/access/ticket") {
            healthy(request)
        } else {
            (403, json!({"errors": {"permission": "not allowed"}}).to_string())
        }
    }))
    .await;
    write_config(&config_with_password(&forbidding.base, "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let (status, code) = get(&srv, "/api/v1/pve/resources").await.expect_err("refused");
    assert_eq!((status, code.as_str()), (400, "forbidden"));

    // An address nothing is listening on: the agent could not reach the
    // cluster, which is a different claim from the cluster refusing.
    let _closed = TcpListener::bind("127.0.0.1:0").await.unwrap().local_addr().unwrap();
    write_config(&config_with_password("http://127.0.0.1:1", "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    let (status, code) = get(&srv, "/api/v1/pve/resources").await.expect_err("refused");
    assert_eq!((status, code.as_str()), (502, "unreachable"));

    // A cluster that owes a second factor is told apart from one that refused
    // the password: the operator's next move is a token, not a new password.
    let tfa = Fake::start(Arc::new(|_: &Recorded| {
        (200, json!({"data": {"NeedTFA": 1}}).to_string())
    }))
    .await;
    write_config(&config_with_password(&tfa.base, "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    let (status, code) = get(&srv, "/api/v1/pve/resources").await.expect_err("refused");
    assert_eq!((status, code.as_str()), (400, "needTfa"));
}

#[ntex::test]
async fn something_that_is_not_a_pve_api_is_a_bad_gateway() {
    let _dir = workspace().await;
    // A 200 with a body that is not the documented envelope: an address that
    // answers something, but not a PVE API.
    let stranger = Fake::start(Arc::new(|_: &Recorded| {
        (200, "<html>hello</html>".to_string())
    }))
    .await;
    write_config(&config_with_password(&stranger.base, "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let (status, code) = get(&srv, "/api/v1/pve/resources").await.expect_err("refused");
    assert_eq!((status, code.as_str()), (502, "invalidResponse"));
    // Nothing of it reaches the client: the body is a document that may quote
    // what was sent to it.
    let (_, text) = get_raw(&srv, "/api/v1/pve/resources").await;
    assert!(!text.contains("hello"), "{text}");
}

#[ntex::test]
async fn a_listing_is_refused_until_a_cluster_is_configured() {
    let _dir = workspace().await;
    write_config(CONFIG_WITHOUT_PVE);
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    let (status, code) = get(&srv, "/api/v1/pve/resources").await.expect_err("refused");
    assert_eq!((status, code.as_str()), (400, "notConfigured"));

    // The settings page still opens, and says there is nothing configured —
    // which is what the panel draws the form from rather than failing.
    let body = get(&srv, "/api/v1/pve/settings").await.expect("readable");
    assert_eq!(body["configured"], false);
    assert_eq!(body["secret_set"], false);
    assert_eq!(body["url"], "");
}

#[ntex::test]
async fn a_certificate_nothing_trusts_is_refused_until_ignore_cert_says_otherwise() {
    let _dir = workspace().await;
    let cluster = Fake::start_tls(Arc::new(healthy)).await;
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    // A PVE install answers on its own certificate unless the operator has done
    // PKI for a machine they already trust, so this is the default case and it
    // is a refusal that names the transport rather than a silent success.
    write_config(&config_with_password(&cluster.base, "hunter2"));
    let (status, code) = get(&srv, "/api/v1/pve/resources").await.expect_err("refused");
    assert_eq!((status, code.as_str()), (502, "unreachable"));

    write_config(&format!(
        "{}\nignore_cert = true\n",
        config_with_password(&cluster.base, "hunter2")
    ));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;
    let body = get(&srv, "/api/v1/pve/resources")
        .await
        .expect("an accepted certificate");
    assert_eq!(body["resources"].as_array().unwrap().len(), 8);
}

// ------------------------------------------------------- saving it

/// The section a save sends, with `secret` absent unless the test sets it.
fn section(url: &str) -> Value {
    json!({
        "url": url,
        "auth": "password",
        "username": "root",
        "realm": "pam",
        "token_id": "",
        "ignore_cert": false,
    })
}

#[ntex::test]
async fn a_save_keeps_the_secret_it_was_not_given_and_clears_it_when_told_to() {
    let _dir = workspace().await;
    write_config(&config_with_password("https://pve.example.com:8006", "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    // An address change with no secret: what is on disk survives. This is the
    // push convention, and the reason the save is gated on `full_access`.
    let body = put(&srv, section("https://pve2.example.com:8006"))
        .await
        .expect("saved");
    assert!(body["secret"].is_null());
    assert_eq!(body["secret_set"], true);
    let stored = pve_on_disk().get_pve();
    assert_eq!(stored.secret.as_deref(), Some("hunter2"));
    assert_eq!(stored.url, "https://pve2.example.com:8006");

    // An empty string is how a client clears one.
    let body = put(
        &srv,
        json!({
            "url": "https://pve2.example.com:8006",
            "auth": "password",
            "username": "root",
            "realm": "pam",
            "secret": "",
        }),
    )
    .await
    .expect("saved");
    assert_eq!(body["secret_set"], false);
    assert_eq!(pve_on_disk().get_pve().secret, None);

    // A password the caller typed replaces it.
    let body = put(
        &srv,
        json!({
            "url": "https://pve2.example.com:8006",
            "auth": "password",
            "username": "root",
            "realm": "pam",
            "secret": "hunter3",
        }),
    )
    .await
    .expect("saved");
    assert_eq!(body["secret_set"], true);
    assert_eq!(pve_on_disk().get_pve().secret.as_deref(), Some("hunter3"));
    // And it is nowhere in the answer.
    assert!(body["secret"].is_null());
}

#[ntex::test]
async fn a_save_replaces_the_whole_section_and_a_refusal_touches_nothing() {
    let _dir = workspace().await;
    write_config(&config_with_password("https://pve.example.com:8006", "hunter2"));
    let (state, _db) = app_state(true).await;
    let srv = test_server(state).await;

    // A `PUT` replaces what it names: an empty address is how a section is
    // cleared, and the account goes with it rather than being left behind on a
    // cluster that is no longer configured. This is the convention every other
    // section editor here follows.
    put(&srv, json!({"url": "", "auth": "password"})).await.expect("cleared");
    let stored = pve_on_disk().get_pve();
    assert_eq!(stored.url, "");
    assert_eq!(stored.username, "");
    assert_eq!(stored.realm, "");
    assert!(!stored.is_configured());
    // The secret is not part of "the section": it survives unless the request
    // says otherwise, which is what makes a blank in the form harmless.
    assert_eq!(stored.secret.as_deref(), Some("hunter2"));

    // An address that is not one is refused by name, and the file is untouched.
    let before = std::fs::read_to_string("config.toml").unwrap();
    let (status, code) = put(
        &srv,
        json!({
            "url": "pve.example.com:8006",
            "auth": "password",
            "username": "root",
            "realm": "pam",
        }),
    )
    .await
    .expect_err("refused");
    assert_eq!((status, code.as_str()), (400, "invalidUrl"));
    assert_eq!(std::fs::read_to_string("config.toml").unwrap(), before);

    // The refusals that name a field the caller forgot or misspelled. Each is
    // an answer at the save rather than a page that fails on every refresh a
    // minute later.
    let cases = [
        (
            json!({"url": "https://pve.example.com:8006", "auth": "Token", "username": "root", "realm": "pam"}),
            "invalidAuth",
        ),
        (
            json!({"url": "https://pve.example.com:8006", "auth": "password", "realm": "pam"}),
            "missingUsername",
        ),
        (
            json!({"url": "https://pve.example.com:8006", "auth": "password", "username": "root"}),
            "missingRealm",
        ),
        (
            json!({"url": "https://pve.example.com:8006", "auth": "token", "username": "root", "realm": "pam"}),
            "missingTokenId",
        ),
    ];
    for (body, code) in cases {
        let (status, answer) = put(&srv, body).await.expect_err("refused");
        assert_eq!(status, 400, "{code} answered {status}");
        assert_eq!(answer, code);
    }
    assert_eq!(std::fs::read_to_string("config.toml").unwrap(), before);
}

#[ntex::test]
async fn saving_the_credential_needs_the_shell_grant_and_reading_it_does_not() {
    let _dir = workspace().await;
    write_config(&without_full_access());
    let (state, db) = app_state(false).await;
    let srv = test_server(state).await;

    // Readable, and honest about not being editable: the panel draws the form
    // read-only rather than failing on the first save.
    let body = get(&srv, "/api/v1/pve/settings").await.expect("readable");
    assert_eq!(body["editable"], false);

    let resp = srv
        .put("/api/v1/pve/settings")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&section("https://pve.example.com:8006"))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 403);

    let resp = srv
        .post("/api/v1/pve/control")
        .header("Authorization", format!("Bearer {}", jwt()))
        .send_json(&json!({"node": "pve", "kind": "qemu", "vmid": 101, "action": "start"}))
        .await
        .unwrap();
    assert_eq!(resp.status().as_u16(), 403);

    // A refused write is recorded as denied, and it names no address: the row
    // is the fact that the grant was off, not what was asked for.
    let (kind, action, result, subject): (String, String, String, Option<String>) = sqlx::query_as(
        "SELECT kind, action, result, subject FROM access_log ORDER BY id DESC LIMIT 1",
    )
    .fetch_one(&db)
    .await
    .unwrap();
    assert_eq!(
        (kind.as_str(), action.as_str(), result.as_str()),
        ("pve", "denied", "denied")
    );
    assert_eq!(subject, None);
}

#[ntex::test]
async fn capabilities_say_this_agent_serves_pve() {
    let _dir = workspace().await;
    write_config(CONFIG_WITHOUT_PVE);
    let (state, _db) = app_state(false).await;
    let srv = test_server(state).await;

    let body = get(&srv, "/api/v1/capabilities").await.expect("capabilities");
    // Served, not grantable: the listing needs only the panel login, and a
    // caller who may not act on a guest can still read the cluster and be told
    // why. The grant is each response's own `editable`.
    assert_eq!(body["remote_access"]["pve"], true);
    assert_eq!(body["remote_access"]["full_access"], false);
}
