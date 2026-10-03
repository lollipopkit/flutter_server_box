//! The one part of this crate that touches the network.
//!
//! Everything it decides is decided elsewhere and tested there: which
//! certificate to accept is [`crate::cert::PinnedCert`], where to look next is
//! [`crate::discover`], which reset type to send is
//! [`crate::model::ResetRequest`]. What is left here is what only a live
//! connection has — a TLS handshake, and a session that has to be given back.
//!
//! Ported from the Dart package `redfish` (`client.dart`), removed with this port. Where it is stricter,
//! the note on the item says so; in short:
//!
//! - **Redirects are not followed.** dio followed them; a 3xx is now an
//!   [`Failure::Unreachable`] answer, since following one is the request — and
//!   its credential — going somewhere nobody configured.
//! - **Every path is checked before it is sent** ([`Client::resolve`]). dio
//!   took an absolute URL in a response at face value.
//! - **The pin is enforced in the handshake, always.** Dart's
//!   `badCertificateCallback` only ran for a chain the platform rejected; a
//!   CA-valid certificate went through, and was refused after the response.
//! - **A 401 on a session re-logs in once** ([`Client::get`]). Dart reported
//!   it as `unauthorized` until the client was rebuilt.
//! - **Bodies are bounded** by [`MAX_BODY`].

use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

use base64::Engine as _;
use reqwest::header::{HeaderMap, HeaderValue};
use reqwest::{Method, StatusCode};
use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::cert::{PinnedCert, PinnedVerifier};
use crate::error::{Error, Failure};
use crate::model::{RedfishTask, odata_id, session_link};

/// The service root. Always appended, never configured.
pub const ROOT_PATH: &str = "/redfish/v1/";

/// How long a connection may take to open. A BMC answers in seconds when it
/// answers at all, and one whose controller is still booting takes most of
/// this.
pub const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

/// The default ceiling on one request — not on a fetch: discovery makes
/// several, and a modern sensor sweep up to [`crate::MAX_SENSOR_MEMBERS`] more.
pub const DEFAULT_TIMEOUT: Duration = Duration::from_secs(30);

/// The most of one response this client reads.
///
/// A bound on what a mistyped address can make the caller buffer. Redfish
/// answers many small documents rather than one large one; the largest here is
/// a collection, which is kilobytes even on a blade enclosure.
pub const MAX_BODY: usize = 1024 * 1024;

/// The longest path that will be sent a request.
pub const MAX_PATH: usize = 1024;

/// How a client proves who it is.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Auth {
    /// One login, a token on every request, and a `DELETE` at the end. What
    /// the specification prefers and what a poll wants: several requests, one
    /// credential exchange. Falls back to [`Auth::Basic`] on its own when the
    /// service root offers no session collection — a service which has no
    /// sessions, not one whose path must be guessed at.
    #[default]
    Session,
    /// The credential on every request. No session to leak and none to run out
    /// of — the only option on some older firmware.
    Basic,
}

/// What a client is pointed at and how it signs in.
#[derive(Clone)]
pub struct ClientConfig {
    /// Scheme, host and port of the service, e.g. `https://10.0.0.9`, plus any
    /// prefix a reverse proxy puts in front of it. The service root is
    /// appended. `https` only: see [`Failure::InvalidUrl`].
    pub base_url: String,
    pub user: String,
    /// Sent as given; `None` is sent as an empty password, as Dart did.
    pub password: Option<String>,
    /// SHA-256 of the DER of the certificate the caller reviewed, in any
    /// spelling [`crate::cert::normalize_fingerprint`] reduces. `None` refuses
    /// every certificate: the alternative is trusting whatever answers the
    /// first time a request is made, and by then the request carries a
    /// password. Obtain one with [`crate::cert::fetch_server_cert`].
    pub pinned_sha256: Option<String>,
    /// Refuse to build a client at all without a pin
    /// ([`Failure::CertNotReviewed`]), rather than build one whose every
    /// handshake fails ([`Failure::CertificateRejected`], Dart's behaviour).
    /// The agent sets it; the app reports the unreviewed certificate through
    /// the handshake like before.
    pub require_pin: bool,
    pub auth: Auth,
    /// The ceiling on one request. Connecting is bounded separately, by
    /// [`CONNECT_TIMEOUT`].
    pub timeout: Duration,
}

impl Default for ClientConfig {
    fn default() -> Self {
        Self {
            base_url: String::new(),
            user: String::new(),
            password: None,
            pinned_sha256: None,
            require_pin: false,
            auth: Auth::Session,
            timeout: DEFAULT_TIMEOUT,
        }
    }
}

impl std::fmt::Debug for ClientConfig {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("ClientConfig")
            .field("base_url", &self.base_url)
            .field("user", &self.user)
            .field("password", &self.password.as_ref().map(|_| "<redacted>"))
            .field("pinned_sha256", &self.pinned_sha256)
            .field("require_pin", &self.require_pin)
            .field("auth", &self.auth)
            .field("timeout", &self.timeout)
            .finish()
    }
}

/// What a modifying request produced.
///
/// A pair rather than a unit, so a caller that ignores the difference has to
/// do so visibly: `202` means the work is happening somewhere else, and
/// reporting it as done is the same mistake as trusting a `204` from a
/// graceful shutdown.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", content = "path", rename_all = "camelCase")]
pub enum Outcome {
    /// The service did the work before answering — or answered `202` with
    /// nowhere to look, which leaves nothing to wait on.
    Done,
    /// The service took the request and is doing it at this path, from
    /// `Location` or the body's own `@odata.id`.
    Accepted(String),
}

/// A resource and the `ETag` it was served with, for a [`Client::patch`].
#[derive(Debug, Clone, PartialEq)]
pub struct Resource {
    pub json: Value,
    /// `None` where the service does not version this resource, which is
    /// allowed and common. A patch then goes unconditional.
    pub etag: Option<String>,
}

/// The credential a request goes out with.
#[derive(Clone)]
enum Credential {
    Token(String),
    Basic(String),
}

/// The session, once there is one.
#[derive(Default)]
struct Session {
    /// What the service turned out to accept, once known. Differs from the
    /// configured [`Auth`] only where a session was asked for and the service
    /// offers none.
    resolved: Option<Auth>,
    token: Option<String>,
    /// Where the session lives, so [`Client::close`] can end it.
    path: Option<String>,
}

/// One answer, with the headers this client reads taken off before the body.
struct Reply {
    status: StatusCode,
    token: Option<String>,
    location: Option<String>,
    etag: Option<String>,
    response: reqwest::Response,
}

/// Reaches one BMC's Redfish service.
///
/// Holds a session, so it is worth keeping and it must be [`Client::close`]d:
/// BMCs allow a handful of sessions, and one nobody gives back stays until it
/// times out.
pub struct Client {
    http: reqwest::Client,
    /// `scheme://host[:port]`, what a same-origin link must match.
    origin: String,
    /// The reverse-proxy prefix, without a trailing slash; usually empty.
    prefix: String,
    user: String,
    password: String,
    auth: Auth,
    /// Held across a login, so concurrent requests share one: without it a
    /// page that fetches two resources at once creates two sessions and gives
    /// back one. And held by [`Client::close`], which therefore waits for a
    /// login in flight instead of missing the session it is about to create.
    session: tokio::sync::Mutex<Session>,
    closed: AtomicBool,
}

impl std::fmt::Debug for Client {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Client")
            .field("origin", &self.origin)
            .field("prefix", &self.prefix)
            .field("user", &self.user)
            .field("auth", &self.auth)
            .finish_non_exhaustive()
    }
}

impl Client {
    /// Builds a client. Nothing is sent until the first request.
    pub fn new(config: ClientConfig) -> Result<Self, Error> {
        let (origin, prefix) = parse_base(&config.base_url)?;

        let pin = PinnedCert::new(config.pinned_sha256.as_deref());
        if config.require_pin && !pin.has_pin() {
            return Err(Error::new(Failure::CertNotReviewed));
        }

        let provider = Arc::new(rustls::crypto::ring::default_provider());
        let verifier = Arc::new(PinnedVerifier {
            pin,
            algorithms: provider.signature_verification_algorithms,
        });
        let tls = rustls::ClientConfig::builder_with_provider(provider)
            .with_safe_default_protocol_versions()
            .map_err(|e| Error::with(Failure::Unreachable, format!("TLS setup: {e}")))?
            .dangerous()
            .with_custom_certificate_verifier(verifier)
            .with_no_client_auth();

        let http = reqwest::Client::builder()
            // Bare, not `Some(tls)`: reqwest downcasts to `Option<ClientConfig>`
            // after wrapping it itself.
            .tls_backend_preconfigured(tls)
            .redirect(reqwest::redirect::Policy::none())
            // A BMC is on the management network. Dart's `HttpClient` used no
            // proxy unless told to, and an ambient `HTTPS_PROXY` would be
            // handed the BMC's credential.
            .no_proxy()
            .connect_timeout(CONNECT_TIMEOUT)
            .timeout(config.timeout)
            .build()
            .map_err(|e| Error::with(Failure::Unreachable, format!("HTTP client setup: {e}")))?;

        Ok(Self {
            http,
            origin,
            prefix,
            user: config.user,
            password: config.password.unwrap_or_default(),
            auth: config.auth,
            session: tokio::sync::Mutex::new(Session::default()),
            closed: AtomicBool::new(false),
        })
    }

    /// The path a request to `raw` is sent to, or why it is not sent.
    ///
    /// Every path this client follows came from a response, and every request
    /// it sends may carry the BMC's credential — so a link that leaves the
    /// service is the one thing that would hand it over. Accepted: a rooted
    /// path under `/redfish/v1/`, or an absolute URL of this client's own
    /// origin (some firmware answers `Location` that way). Refused: another
    /// origin, `..`, `//`, a backslash, an encoded dot, slash or backslash,
    /// whitespace or control characters, a query or fragment, or more than
    /// [`MAX_PATH`] bytes.
    pub fn resolve(&self, raw: &str) -> Result<String, Error> {
        let refuse = || Error::with(Failure::InvalidResponse, "a path outside the service");
        let mut path = raw;
        let lower = raw.to_ascii_lowercase();
        if lower.starts_with("https://") || lower.starts_with("http://") {
            // Compared as text rather than through `Url`, which would normalize
            // a `..` away before it could be seen. The origin is ASCII (a host
            // is serialized punycoded), so its length is a byte offset in `raw`.
            let origin = self.origin.to_ascii_lowercase();
            let rest = lower
                .strip_prefix(origin.as_str())
                .filter(|rest| rest.starts_with('/'))
                .map(|_| &raw[origin.len()..])
                .ok_or_else(refuse)?;
            path = rest.strip_prefix(self.prefix.as_str()).ok_or_else(refuse)?;
        }
        if is_safe_path(path) {
            Ok(path.to_string())
        } else {
            Err(refuse())
        }
    }

    fn url(&self, path: &str) -> String {
        format!("{}{}{path}", self.origin, self.prefix)
    }

    fn check_open(&self) -> Result<(), Error> {
        if self.closed.load(Ordering::SeqCst) {
            Err(Error::new(Failure::Closed))
        } else {
            Ok(())
        }
    }

    // --- Reading ---

    /// Whether there is a Redfish service here at all, without logging in.
    ///
    /// The service root is unauthenticated by specification, so this costs no
    /// session — which is the point. Answering "is this a BMC" should not leave
    /// anything behind on a device that allows four of them.
    pub async fn probe(&self) -> Result<Value, Error> {
        Ok(self.read(ROOT_PATH, false).await?.json)
    }

    /// The resource at `path`, as a JSON object.
    pub async fn get(&self, path: &str) -> Result<Value, Error> {
        Ok(self.read(path, true).await?.json)
    }

    /// The resource at `path`, with the `ETag` it was served with.
    pub async fn fetch(&self, path: &str) -> Result<Resource, Error> {
        self.read(path, true).await
    }

    async fn read(&self, raw: &str, authenticated: bool) -> Result<Resource, Error> {
        self.check_open()?;
        let path = self.resolve(raw)?;
        let reply = if authenticated {
            self.authenticated(Method::GET, &path, None, None).await?
        } else {
            self.send(Method::GET, &path, None, None, None).await?
        };
        into_resource(reply, &path).await
    }

    // --- Modifying ---

    /// Sends `body` to `path`. Used for actions.
    pub async fn post(&self, path: &str, body: Value) -> Result<Outcome, Error> {
        self.modify(Method::POST, path, body, None).await
    }

    /// Modifies the resource at `path`.
    ///
    /// `etag` is what [`Client::fetch`] returned for it. Sending it as
    /// `If-Match` is what stops this from overwriting a change someone made in
    /// between; a service that requires one answers 428 without it, which
    /// arrives as [`Failure::PreconditionRequired`].
    pub async fn patch(&self, path: &str, body: Value, etag: Option<&str>) -> Result<Outcome, Error> {
        self.modify(Method::PATCH, path, body, etag).await
    }

    async fn modify(&self, method: Method, raw: &str, body: Value, etag: Option<&str>) -> Result<Outcome, Error> {
        self.check_open()?;
        let path = self.resolve(raw)?;
        let reply = self.authenticated(method, &path, Some(&body), etag).await?;
        throw_for_status(reply.status, &path)?;
        if reply.status != StatusCode::ACCEPTED {
            return Ok(Outcome::Done);
        }
        // `202` means the work is happening somewhere else.
        if let Some(location) = reply.location.clone() {
            return Ok(Outcome::Accepted(location));
        }
        let body = read_body(reply.response, &path).await.unwrap_or_default();
        Ok(match parse_object(&body).as_ref().and_then(odata_id) {
            Some(id) => Outcome::Accepted(id.to_string()),
            // Accepted with nowhere to look: nothing can be waited on.
            None => Outcome::Done,
        })
    }

    /// Polls the task at `path` until the service stops working on it.
    ///
    /// Returns the last state seen. A task still running when `timeout`
    /// expires comes back as it was — running — rather than as a failure: the
    /// work has not stopped, only the watching has. Dart's defaults were ten
    /// minutes and three seconds.
    pub async fn await_task(&self, path: &str, timeout: Duration, interval: Duration) -> Result<RedfishTask, Error> {
        let deadline = tokio::time::Instant::now() + timeout;
        let mut last = RedfishTask::unknown();
        while tokio::time::Instant::now() < deadline {
            last = RedfishTask::from_json(&self.get(path).await?);
            if !last.state.is_running() {
                return Ok(last);
            }
            tokio::time::sleep(interval).await;
        }
        Ok(last)
    }

    // --- Authentication ---

    /// One request with the credential, logging in first if need be.
    ///
    /// A 401 on a session token is the session gone — expired, or reaped by a
    /// BMC that holds few — and is answered by one fresh login and one retry.
    /// The old session is given back first in case it was not gone after all.
    /// A second 401, or a 401 at the login itself, is [`Failure::Unauthorized`]:
    /// retrying a password the BMC rejects is how a BMC locks an account.
    async fn authenticated(
        &self,
        method: Method,
        path: &str,
        body: Option<&Value>,
        etag: Option<&str>,
    ) -> Result<Reply, Error> {
        let credential = self.credential().await?;
        let reply = self
            .send(method.clone(), path, Some(&credential), body, etag)
            .await?;
        let Credential::Token(token) = credential else {
            return Ok(reply);
        };
        if reply.status != StatusCode::UNAUTHORIZED {
            return Ok(reply);
        }
        self.drop_session(&token).await;
        let credential = self.credential().await?;
        self.send(method, path, Some(&credential), body, etag).await
    }

    /// The credential to send, logging in once if this is a session client
    /// that has not yet.
    ///
    /// A *failed* login is not remembered: the next request tries again. The
    /// client is held across polls, and keeping a failure made the first one
    /// permanent — one timeout on a device that takes seconds to answer was
    /// enough.
    async fn credential(&self) -> Result<Credential, Error> {
        let mut session = self.session.lock().await;
        // Again under the lock: `close` may have run while this waited for a
        // login in flight, and resuming would send a released token.
        self.check_open()?;
        if self.auth == Auth::Basic || session.resolved == Some(Auth::Basic) {
            session.resolved = Some(Auth::Basic);
            return Ok(Credential::Basic(self.basic()));
        }
        if let Some(token) = &session.token {
            return Ok(Credential::Token(token.clone()));
        }
        self.login(&mut session).await?;
        // `close` ran during the login: the session is in place for it to
        // give back, and this request is not to use it.
        self.check_open()?;
        Ok(match &session.token {
            Some(token) => Credential::Token(token.clone()),
            None => Credential::Basic(self.basic()),
        })
    }

    fn basic(&self) -> String {
        let raw = format!("{}:{}", self.user, self.password);
        format!(
            "Basic {}",
            base64::engine::general_purpose::STANDARD.encode(raw.as_bytes())
        )
    }

    /// Logs in at the session collection the service root names, and
    /// remembers where the session lives so [`Client::close`] can end it.
    async fn login(&self, session: &mut Session) -> Result<(), Error> {
        // Not `read`, which would be this function calling itself through
        // `authenticated` as far as the compiler can tell.
        let reply = self.send(Method::GET, ROOT_PATH, None, None, None).await?;
        let root = into_resource(reply, ROOT_PATH).await?.json;
        let Some(sessions) = session_link(&root) else {
            // Not a failure. The service has no sessions, so every request
            // carries the credential instead; inventing
            // `SessionService/Sessions` produced a 404 reported as a login
            // failure.
            session.resolved = Some(Auth::Basic);
            return Ok(());
        };
        let sessions = self.resolve(&sessions)?;
        let body = json!({ "UserName": self.user, "Password": self.password });
        let reply = self
            .send(Method::POST, &sessions, None, Some(&body), None)
            .await?;

        let code = reply.status.as_u16();
        if code == 401 || code == 403 {
            return Err(Error::new(Failure::Unauthorized));
        }
        // Anything else that is not a success is the service's problem, not
        // the account's: reporting a 500 as `unauthorized` sends the user to
        // change a password that was fine.
        if code >= 300 {
            return Err(Error::with(Failure::Unreachable, format!("HTTP {code} at login")));
        }
        let Some(token) = reply.token.clone() else {
            return Err(Error::with(
                Failure::Unreachable,
                format!("the service returned no token (HTTP {code})"),
            ));
        };
        // `Location` is where the session resource is; the body's own
        // `@odata.id` because some services fill in only one of the two.
        let path = match reply.location.clone() {
            Some(location) => Some(location),
            None => {
                let body = read_body(reply.response, &sessions).await.unwrap_or_default();
                parse_object(&body)
                    .as_ref()
                    .and_then(odata_id)
                    .map(str::to_string)
            }
        };
        session.resolved = Some(Auth::Session);
        session.token = Some(token);
        session.path = path;
        Ok(())
    }

    /// Forgets a session the service refused, giving it back on the way in
    /// case it was alive. Only if it is still the current one: a concurrent
    /// request may already have replaced it.
    async fn drop_session(&self, token: &str) {
        let mut session = self.session.lock().await;
        if session.token.as_deref() != Some(token) {
            return;
        }
        let path = session.path.take();
        session.token = None;
        if let Some(path) = path {
            self.delete_session(&path, token).await;
        }
    }

    async fn delete_session(&self, raw: &str, token: &str) {
        // A session path is a link like any other.
        if let Ok(path) = self.resolve(raw) {
            let credential = Credential::Token(token.to_string());
            let _ = self
                .send(Method::DELETE, &path, Some(&credential), None, None)
                .await;
        }
    }

    /// Ends the session and stops the client.
    ///
    /// Best effort, and never fails: it runs on the failure path as much as
    /// the normal one. A login still in flight is a session about to exist, so
    /// this waits for it rather than missing it — on a device that allows
    /// about four. Safe to call twice; every request after it is
    /// [`Failure::Closed`].
    pub async fn close(&self) {
        if self.closed.swap(true, Ordering::SeqCst) {
            return;
        }
        let mut session = self.session.lock().await;
        let token = session.token.take();
        let path = session.path.take();
        if let (Some(token), Some(path)) = (token, path) {
            self.delete_session(&path, &token).await;
        }
    }

    // --- The wire ---

    async fn send(
        &self,
        method: Method,
        path: &str,
        credential: Option<&Credential>,
        body: Option<&Value>,
        etag: Option<&str>,
    ) -> Result<Reply, Error> {
        let mut headers = HeaderMap::new();
        headers.insert(reqwest::header::ACCEPT, HeaderValue::from_static("application/json"));
        if let Some(credential) = credential {
            let (name, raw) = match credential {
                Credential::Token(token) => ("x-auth-token", token.as_str()),
                Credential::Basic(header) => ("authorization", header.as_str()),
            };
            let mut value = HeaderValue::from_str(raw)
                .map_err(|_| Error::with(Failure::Unreachable, "the session token is not a header value"))?;
            value.set_sensitive(true);
            headers.insert(name, value);
        }
        if let Some(etag) = etag {
            let value = HeaderValue::from_str(etag)
                .map_err(|_| Error::with(Failure::InvalidResponse, "the ETag is not a header value"))?;
            headers.insert(reqwest::header::IF_MATCH, value);
        }

        let mut request = self.http.request(method, self.url(path)).headers(headers);
        if let Some(body) = body {
            request = request.json(body);
        }
        let response = request.send().await.map_err(|e| transport_error(&e, path))?;
        let header = |name: &str| {
            response
                .headers()
                .get(name)
                .and_then(|v| v.to_str().ok())
                .filter(|v| !v.is_empty())
                .map(str::to_string)
        };
        Ok(Reply {
            status: response.status(),
            token: header("x-auth-token"),
            location: header("location"),
            etag: header("etag"),
            response,
        })
    }
}

/// The origin and proxy prefix of a configured address.
fn parse_base(input: &str) -> Result<(String, String), Error> {
    let invalid = |why: &str| Error::with(Failure::InvalidUrl, why.to_string());
    let url = reqwest::Url::parse(input.trim()).map_err(|_| invalid("not a URL"))?;
    // Dart accepted `http://` and then refused every request on it, since a
    // plain connection has no certificate to match the pin. Said up front.
    if url.scheme() != "https" {
        return Err(invalid("only https is supported"));
    }
    if url.host_str().is_none_or(str::is_empty) {
        return Err(invalid("no host"));
    }
    if url.query().is_some() || url.fragment().is_some() || !url.username().is_empty() || url.password().is_some() {
        return Err(invalid("a query, fragment or credential in the address"));
    }
    let prefix = url.path().trim_end_matches('/').to_string();
    if !prefix.is_empty() && (prefix.contains("..") || prefix.contains("//")) {
        return Err(invalid("an unusable path"));
    }
    Ok((url.origin().ascii_serialization(), prefix))
}

/// See [`Client::resolve`].
pub fn is_safe_path(path: &str) -> bool {
    let lower = path.to_ascii_lowercase();
    path.len() <= MAX_PATH
        && (path.starts_with(ROOT_PATH) || path == "/redfish/v1")
        && !path.contains("//")
        && !path.contains("..")
        && !path.contains(['\\', '?', '#'])
        && !path.chars().any(|c| c.is_whitespace() || c.is_control())
        && !["%2e", "%2f", "%5c"].iter().any(|e| lower.contains(e))
}

/// What a status means, in the terms the rest of the crate uses.
fn throw_for_status(status: StatusCode, path: &str) -> Result<(), Error> {
    let code = status.as_u16();
    match code {
        401 => Err(Error::new(Failure::Unauthorized)),
        // Licensing gates parts of some services, so this is an answer about
        // this resource and the caller decides what it costs
        403 => Err(Error::with(Failure::Forbidden, path)),
        // 428 is the service asking for an `If-Match`; 412 is one that no
        // longer matches. Both mean "read it again and retry".
        412 | 428 => Err(Error::with(Failure::PreconditionRequired, path)),
        300..=399 => Err(Error::with(
            Failure::Unreachable,
            format!("HTTP {code} at {path} (redirects are not followed)"),
        )),
        _ if code >= 400 => Err(Error::with(Failure::Unreachable, format!("HTTP {code} at {path}"))),
        _ => Ok(()),
    }
}

/// A transport failure, with a rejected certificate named.
///
/// reqwest reports a refused handshake and an address nothing answers alike;
/// the rustls error underneath is what tells them apart, and the fix for one
/// is a person looking at a fingerprint rather than a network.
fn transport_error(error: &reqwest::Error, path: &str) -> Error {
    // `io::Error::source` skips the error it wraps — it answers that error's
    // own source — so an `io::Error` is descended through `get_ref`, and the
    // rustls error under hyper's two layers of them is found.
    let mut source: Option<&(dyn std::error::Error + 'static)> = Some(error);
    while let Some(e) = source {
        match e.downcast_ref::<rustls::Error>() {
            Some(rustls::Error::InvalidCertificate(_)) => return Error::new(Failure::CertificateRejected),
            Some(other) => return Error::with(Failure::Unreachable, format!("TLS at {path}: {other}")),
            None => {}
        }
        source = match e.downcast_ref::<std::io::Error>().and_then(std::io::Error::get_ref) {
            Some(inner) => Some(inner as &(dyn std::error::Error + 'static)),
            None => e.source(),
        };
    }
    let kind = if error.is_timeout() {
        "timed out"
    } else if error.is_connect() {
        "could not connect"
    } else if error.is_body() || error.is_decode() {
        "the answer broke off"
    } else {
        "request failed"
    };
    Error::with(Failure::Unreachable, format!("{kind} at {path}"))
}

/// A read's answer as a resource, or what its status means.
async fn into_resource(reply: Reply, path: &str) -> Result<Resource, Error> {
    throw_for_status(reply.status, path)?;
    let etag = reply.etag.clone();
    let body = read_body(reply.response, path).await?;
    let json = parse_object(&body).ok_or_else(|| Error::with(Failure::NotAService, format!("no JSON at {path}")))?;
    Ok(Resource { json, etag })
}

/// A response body, up to [`MAX_BODY`].
async fn read_body(mut response: reqwest::Response, path: &str) -> Result<Vec<u8>, Error> {
    let too_large = || Error::with(Failure::InvalidResponse, format!("an answer over {MAX_BODY} bytes at {path}"));
    if response.content_length().is_some_and(|n| n > MAX_BODY as u64) {
        return Err(too_large());
    }
    let mut body = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(|e| transport_error(&e, path))? {
        if body.len() + chunk.len() > MAX_BODY {
            return Err(too_large());
        }
        body.extend_from_slice(&chunk);
    }
    Ok(body)
}

/// A body as a JSON object, or `None`. Whatever else it was is not carried:
/// see [`Error`] on bodies.
fn parse_object(body: &[u8]) -> Option<Value> {
    serde_json::from_slice::<Value>(body)
        .ok()
        .filter(Value::is_object)
}
