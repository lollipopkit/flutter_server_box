//! The HTTP client one Redfish request is sent through.
//!
//! **One login per request, and the session is deleted again.** A BMC keeps a
//! small, fixed number of concurrent sessions — a handful on most firmware, and
//! the operator's own browser is usually holding one — so a token cached across
//! requests is a session leaked between page refreshes, and the day it runs out
//! is the day the operator cannot log in to their own machine. The cost is one
//! extra request per page.
//!
//! **The certificate is pinned.** A BMC answers on its own certificate,
//! self-signed unless the operator replaced it, so the choice is between
//! refusing everything and accepting anything — and accepting anything hands
//! the password to whatever answered on that address. What is stored is the
//! SHA-256 of one certificate's DER, and it is the *whole* of the trust: a
//! chain a public CA signed is not accepted either, because a BMC that presents
//! one was not the BMC this agent was told to talk to. Nothing reviewed means
//! nothing accepted — see [`sbm_parser::redfish::fingerprint_matches`].
//!
//! **No upstream status becomes our status.** A BMC answering 401 does not make
//! this agent answer 401: the panel's client logs the operator out on that, and
//! what failed here is the *agent's* credential to a machine the operator is
//! not logged in to. Every upstream failure is answered as an agent-side code
//! instead — see [`BmcFailure`]. Neither is the upstream's *body* carried: a
//! Redfish error document is not needed to phrase any of these, and the login
//! body is a document about a credential.

use std::sync::{Arc, Mutex};
use std::time::Duration;

use reqwest::Client;
use reqwest::header::{HeaderMap, HeaderValue};
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::crypto::{WebPkiSupportedAlgorithms, verify_tls12_signature, verify_tls13_signature};
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{
    CertificateError, ClientConfig, DigitallySignedStruct, Error as TlsError, SignatureScheme,
};
use serde_json::Value;
use sha2::{Digest, Sha256};

use sbm_parser::redfish::{
    BmcSensors, MAX_SENSOR_MEMBERS, RedfishChassis, RedfishFailure, RedfishRoot, RedfishSystem,
    ResetRequest, TOKEN_HEADER, basic_header, collection_members, fingerprint_matches, is_safe_path,
    sensor_paths,
};

use crate::core::config::BmcConfig;

/// How long a connection may take to open. A BMC answers in seconds when it
/// answers at all — the firmware behind its web server is not fast, and a
/// chassis with its management controller still booting takes most of this.
const CONNECT_TIMEOUT: Duration = Duration::from_secs(10);

/// How long one request may take. Reading a `Sensors` collection is one request
/// per member and they are made one at a time, so this bounds each of them.
const REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

/// The most of one response this agent will read.
///
/// A bound on what a mistyped address can make the agent buffer. Smaller than
/// [`crate::api::pve::client::MAX_BODY`] because Redfish answers many small
/// documents rather than one large one: the largest single response here is a
/// systems or chassis collection, which is kilobytes even on a blade
/// enclosure, and the sensor fan-out is bounded by
/// [`MAX_SENSOR_MEMBERS`] rather than by this.
pub const MAX_BODY: usize = 1024 * 1024;

/// Why a request could not be carried out.
///
/// Two halves in one type because a caller answers both the same way — a code
/// and a status — and only the second half is a vocabulary this crate shares
/// with the app.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BmcFailure {
    /// A mistake this agent can name without dialing: a mistyped address, a
    /// missing field, an intent nothing can satisfy.
    Refused(&'static str),
    /// The BMC's own vocabulary, from [`sbm_parser::redfish`], so a panel
    /// phrases it without a second table of names.
    Redfish(RedfishFailure),
}

impl BmcFailure {
    pub fn code(self) -> &'static str {
        match self {
            Self::Refused(code) => code,
            Self::Redfish(failure) => failure.as_str(),
        }
    }

    /// Whether this is the agent failing to reach the machine rather than an
    /// answer about it: a transport failure is a 502, everything else is a 400.
    pub fn is_transport(self) -> bool {
        match self {
            Self::Refused(_) => false,
            Self::Redfish(failure) => failure.is_transport(),
        }
    }
}

/// The pin as a configured address is turned into: `scheme://host[:port]` plus
/// whatever prefix the operator's deployment puts in front of the service root.
///
/// A path is kept rather than refused, because a BMC behind a reverse proxy is
/// a real deployment and its resources are addressed from the proxy's prefix.
/// The one path this strips is the service root itself: an operator who pasted
/// the URL out of a BMC's own web interface arrives with `/redfish/v1/` on the
/// end, and that is the address of the thing this agent addresses resources
/// *within*.
pub fn validate_url(input: &str) -> Result<String, BmcFailure> {
    let parsed = reqwest::Url::parse(input.trim()).map_err(|_| BmcFailure::Refused("invalidUrl"))?;
    if !matches!(parsed.scheme(), "http" | "https") {
        return Err(BmcFailure::Refused("invalidUrl"));
    }
    if parsed.host_str().is_none_or(str::is_empty) {
        return Err(BmcFailure::Refused("invalidUrl"));
    }
    if parsed.query().is_some() || parsed.fragment().is_some() {
        return Err(BmcFailure::Refused("invalidUrl"));
    }

    let mut path = parsed.path().to_string();
    for suffix in ["/redfish/v1/", "/redfish/v1"] {
        if let Some(stripped) = path.strip_suffix(suffix) {
            path = stripped.to_string();
            break;
        }
    }
    let prefix = path.trim_end_matches('/');
    if !prefix.is_empty() && !is_safe_path(prefix) {
        return Err(BmcFailure::Refused("invalidUrl"));
    }

    let mut base = format!(
        "{}://{}",
        parsed.scheme(),
        parsed.host_str().unwrap_or_default()
    );
    if let Some(port) = parsed.port() {
        base.push_str(&format!(":{port}"));
    }
    base.push_str(prefix);
    Ok(base)
}

/// A verifier that accepts exactly one certificate and nothing else.
///
/// Both halves of what a `ServerCertVerifier` is asked are answered here: the
/// certificate is the pin, and the signatures over the handshake are checked by
/// the same ring provider everything else in this binary uses — a certificate
/// this agent accepted still has to prove it holds the key.
struct PinnedVerifier {
    pin: Option<String>,
    algorithms: WebPkiSupportedAlgorithms,
    /// Set when a certificate was refused.
    ///
    /// The reason it is recorded rather than recovered from the error: reqwest
    /// reports a refused handshake and an address nothing answers the same way —
    /// `is_connect` is true for both — and the panel needs the two told apart,
    /// because one is "look at the certificate" and the other is "look at the
    /// address". The verifier is the only place that knows which happened.
    refused: Arc<Mutex<bool>>,
}

impl std::fmt::Debug for PinnedVerifier {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // The pin is not a secret — it is on screen and in a config file — but
        // there is nothing else here worth printing.
        f.debug_struct("PinnedVerifier").finish_non_exhaustive()
    }
}

impl ServerCertVerifier for PinnedVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, TlsError> {
        // Deliberately the whole of the check: no chain is walked, and no
        // notBefore/notAfter is read. A BMC's certificate is expired as often as
        // not, and refusing it on the clock would leave the operator with no way
        // in that does not involve reissuing it. What is trusted is that this is
        // the certificate that was reviewed.
        let actual = hex::encode(Sha256::digest(end_entity.as_ref()));
        if fingerprint_matches(self.pin.as_deref(), &actual) {
            Ok(ServerCertVerified::assertion())
        } else {
            if let Ok(mut refused) = self.refused.lock() {
                *refused = true;
            }
            Err(TlsError::InvalidCertificate(
                CertificateError::ApplicationVerificationFailure,
            ))
        }
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, TlsError> {
        verify_tls12_signature(message, cert, dss, &self.algorithms)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, TlsError> {
        verify_tls13_signature(message, cert, dss, &self.algorithms)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.algorithms.supported_schemes()
    }
}

/// A verifier that records the certificate it was shown and then refuses it.
///
/// What `POST /api/v1/bmc/probe` runs on. The handshake necessarily fails, so
/// the request that triggered it never carries anything — which is the whole
/// point: the operator reviews a certificate *before* a password is sent to
/// whatever is presenting it. Reading the leaf this way needs no second TLS
/// stack and no second parser for the DER, because the fingerprint is over the
/// DER itself.
#[derive(Debug)]
struct CapturingVerifier {
    seen: Mutex<Option<Vec<u8>>>,
    algorithms: WebPkiSupportedAlgorithms,
}

impl CapturingVerifier {
    fn take(&self) -> Option<Vec<u8>> {
        self.seen.lock().ok().and_then(|mut slot| slot.take())
    }
}

impl ServerCertVerifier for CapturingVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, TlsError> {
        if let Ok(mut slot) = self.seen.lock() {
            *slot = Some(end_entity.as_ref().to_vec());
        }
        Err(TlsError::InvalidCertificate(
            CertificateError::ApplicationVerificationFailure,
        ))
    }

    /// Never reached: the certificate is refused above, and a certificate
    /// verification failure ends the handshake before any signature is checked.
    /// Asserted rather than verified for that reason — nothing is trusted by
    /// this verifier, and nothing is sent by anything that uses it.
    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, TlsError> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, TlsError> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.algorithms.supported_schemes()
    }
}

/// The process's TLS provider, installed if it is not already.
///
/// reqwest is built without a crypto provider of its own, so one has to be the
/// process default before a `ClientConfig` is built — otherwise the first TLS
/// handshake panics inside rustls rather than failing as a request error.
/// `ring`, matching every other TLS user in this binary;
/// `monitoring::push::http_client` and `api::pve::client` install the same one,
/// and a second call answers `Err` rather than replacing it.
fn provider() -> rustls::crypto::CryptoProvider {
    let _ = rustls::crypto::ring::default_provider().install_default();
    rustls::crypto::ring::default_provider()
}

/// A reqwest client whose only trust is `pin`, and the flag its verifier sets
/// when it refuses one.
fn pinned_client(pin: Option<String>) -> Result<(Client, Arc<Mutex<bool>>), BmcFailure> {
    let provider = provider();
    let refused = Arc::new(Mutex::new(false));
    let verifier = Arc::new(PinnedVerifier {
        pin,
        algorithms: provider.signature_verification_algorithms,
        refused: refused.clone(),
    });
    let tls = ClientConfig::builder_with_provider(Arc::new(provider))
        .with_safe_default_protocol_versions()
        .map_err(|_| BmcFailure::Redfish(RedfishFailure::Unreachable))?
        .dangerous()
        .with_custom_certificate_verifier(verifier)
        .with_no_client_auth();
    // Bare, not `Some(tls)`: reqwest's own `Some` wrapper is the thing it
    // downcasts, and a second one makes the type it looks for unreachable —
    // which does not fail as a type error but as `builder error` on the first
    // request.
    let client = builder().tls_backend_preconfigured(tls).build().map_err(|e| {
        tracing::warn!("bmc: could not build the http client: {e}");
        BmcFailure::Redfish(RedfishFailure::Unreachable)
    })?;
    Ok((client, refused))
}

/// The shared half of the builder. `no_proxy` under test, or an ambient
/// `HTTP_PROXY` in the test environment swallows the loopback fake.
fn builder() -> reqwest::ClientBuilder {
    let builder = Client::builder()
        .connect_timeout(CONNECT_TIMEOUT)
        .timeout(REQUEST_TIMEOUT)
        .pool_idle_timeout(Duration::from_secs(60));
    #[cfg(test)]
    let builder = builder.no_proxy();
    builder
}

/// One answer: its status, its document, and the two headers that carry
/// something this client needs.
///
/// The headers are read here rather than by the caller because a `Response`
/// cannot be asked for them after its body has been taken — and the token is
/// only ever in a header, never in the document.
struct Reply {
    status: u16,
    value: Option<Value>,
    /// `X-Auth-Token`, when the answer carried one.
    token: Option<String>,
    /// `Location`, which is where a created session says it lives.
    location: Option<String>,
}

/// One response header as a string, or `None` when absent or empty.
fn header_of(response: &reqwest::Response, name: &str) -> Option<String> {
    response
        .headers()
        .get(name)
        .and_then(|value| value.to_str().ok())
        .filter(|value| !value.is_empty())
        .map(str::to_string)
}

/// How this agent is authenticated to a service for the length of one request.
pub enum Credential {
    /// A session created at the service's own session endpoint.
    Session {
        token: String,
        /// Where to delete it. `None` when the login answer named neither a
        /// `Location` nor an `@odata.id`, which is a service that will collect
        /// the session on its own timeout — reported to nobody, since the
        /// request itself succeeded.
        path: Option<String>,
    },
    /// The service offered no session endpoint, so the account is presented on
    /// every request instead. `sbm_parser::redfish::RedfishRoot::sessions`
    /// documents when this happens.
    Basic(String),
}

/// What the panel's page is drawn from.
pub struct BmcState {
    pub root: RedfishRoot,
    pub system: RedfishSystem,
    /// Absent when the chassis could not be read. Its own field rather than an
    /// error: a service can deny the chassis while answering the system, and
    /// losing the sensors is not losing the power state.
    pub chassis: Option<RedfishChassis>,
    pub sensors: BmcSensors,
    /// Whether the sensors were read at all. `false` with an empty `sensors` is
    /// the honest pair; an empty reading alone reads as a machine with no fans.
    pub sensors_read: bool,
    /// Whether more members were published than [`MAX_SENSOR_MEMBERS`].
    pub sensors_truncated: bool,
}

pub struct BmcClient {
    http: Client,
    config: BmcConfig,
    base: String,
    /// Set by the TLS verifier when it refused a certificate — see
    /// [`PinnedVerifier::refused`].
    refused: Arc<Mutex<bool>>,
}

impl BmcClient {
    pub fn new(config: &BmcConfig) -> Result<Self, BmcFailure> {
        let base = validate_url(&config.url)?;
        let (http, refused) = pinned_client(config.pin())?;
        Ok(Self {
            http,
            config: config.clone(),
            base,
            refused,
        })
    }

    /// A request that could not be made at all.
    ///
    /// The one place a refused certificate is told apart from an address
    /// nothing answers: reqwest reports both as a connect error, and the two
    /// have different remedies — look at the certificate, or look at the
    /// address.
    fn transport(&self, error: reqwest::Error) -> BmcFailure {
        if self.refused.lock().is_ok_and(|refused| *refused) {
            tracing::warn!("bmc: the certificate is not the one that was reviewed");
            return BmcFailure::Redfish(RedfishFailure::CertificateRejected);
        }
        tracing::debug!("bmc: {error}");
        BmcFailure::Redfish(RedfishFailure::Unreachable)
    }

    fn url(&self, path: &str) -> String {
        format!("{}{path}", self.base)
    }

    fn secret(&self) -> Result<&str, BmcFailure> {
        match self.config.secret.as_deref() {
            Some(secret) if !secret.is_empty() => Ok(secret),
            _ => Err(BmcFailure::Redfish(RedfishFailure::NoCredential)),
        }
    }

    /// One request, with the caller's credential or none at all.
    ///
    /// A path the service named is refused rather than sent when it is not a
    /// rooted, traversal-free one: this request carries the BMC's own
    /// credential, and a link that addresses another host is the one thing that
    /// would hand it over. `docs` for the service root are always safe.
    async fn send(
        &self,
        method: reqwest::Method,
        path: &str,
        credential: Option<&Credential>,
        body: Option<Value>,
    ) -> Result<Reply, BmcFailure> {
        if !is_safe_path(path) {
            tracing::warn!("bmc: refusing a path the service named");
            return Err(BmcFailure::Redfish(RedfishFailure::InvalidResponse));
        }

        let mut headers = HeaderMap::new();
        if let Some(credential) = credential {
            match credential {
                Credential::Session { token, .. } => {
                    let value = HeaderValue::from_str(token).map_err(|_| {
                        BmcFailure::Redfish(RedfishFailure::InvalidResponse)
                    })?;
                    headers.insert(reqwest::header::HeaderName::from_static(TOKEN_HEADER), value);
                }
                Credential::Basic(header) => {
                    let value = HeaderValue::from_str(header).map_err(|_| {
                        BmcFailure::Redfish(RedfishFailure::InvalidResponse)
                    })?;
                    headers.insert(reqwest::header::AUTHORIZATION, value);
                }
            }
        }

        let mut request = self
            .http
            .request(method, self.url(path))
            .headers(headers)
            .header(reqwest::header::ACCEPT, "application/json");
        if let Some(body) = body {
            request = request.json(&body);
        }

        let response = request.send().await.map_err(|e| self.transport(e))?;
        let status = response.status().as_u16();
        // Before the body: a `Response` cannot be asked for its headers once
        // its body has been taken, and the session token is only ever in one.
        let token = header_of(&response, TOKEN_HEADER);
        let location = header_of(&response, "location");
        let text = response.text().await.map_err(|e| self.transport(e))?;
        if text.len() > MAX_BODY {
            tracing::warn!("bmc: an answer was larger than this agent reads");
            return Err(BmcFailure::Redfish(RedfishFailure::InvalidResponse));
        }
        // An empty body is a real answer — a reset action answers 200 with
        // nothing, and `DELETE` of a session answers 204.
        let value = if text.trim().is_empty() {
            None
        } else {
            match serde_json::from_str::<Value>(&text) {
                Ok(value) => Some(value),
                Err(_) => {
                    if status >= 400 {
                        None
                    } else {
                        tracing::warn!("bmc: the service answered something that is not JSON");
                        return Err(BmcFailure::Redfish(RedfishFailure::InvalidResponse));
                    }
                }
            }
        };
        Ok(Reply {
            status,
            value,
            token,
            location,
        })
    }

    /// The answer to a request that must have succeeded, or why it did not.
    async fn value(
        &self,
        path: &str,
        credential: Option<&Credential>,
    ) -> Result<Value, BmcFailure> {
        let reply = self.send(reqwest::Method::GET, path, credential, None).await?;
        if !(200..300).contains(&reply.status) {
            return Err(status_failure(reply.status));
        }
        reply
            .value
            .ok_or(BmcFailure::Redfish(RedfishFailure::InvalidResponse))
    }

    /// Reads the unauthenticated service root and authenticates with it.
    ///
    /// One root read serves both: it is where the session endpoint is named and
    /// it is what a service that is not Redfish fails to answer. Returned to the
    /// caller as well, since the page shows what the service said it is.
    pub async fn authenticate(&self) -> Result<(Credential, RedfishRoot), BmcFailure> {
        let root = RedfishRoot::parse(
            &self
                .value(sbm_parser::redfish::ROOT_PATH, None)
                .await?,
        );
        if !root.is_service() {
            return Err(BmcFailure::Redfish(RedfishFailure::NotAService));
        }

        // No session endpoint means Basic is the only way in, which is what the
        // model says an absent `sessions` means.
        let Some(sessions) = root.sessions.as_deref() else {
            let secret = self.secret()?;
            let header = basic_header(&self.config.username, secret);
            return Ok((Credential::Basic(header), root));
        };

        let secret = self.secret()?;
        let body = serde_json::json!({
            "UserName": self.config.username.trim(),
            // Always present, at least empty. A service that answers 400 for a
            // missing field is one this agent cannot tell from a wrong password.
            "Password": secret,
        });
        let reply = self
            .send(reqwest::Method::POST, sessions, None, Some(body))
            .await?;
        if !(200..300).contains(&reply.status) {
            return Err(match reply.status {
                401 | 403 => BmcFailure::Redfish(RedfishFailure::Unauthorized),
                status => {
                    tracing::warn!("bmc: the login answered {status}");
                    BmcFailure::Redfish(RedfishFailure::InvalidResponse)
                }
            });
        }

        // The token travels in a header. A service that answers with a
        // `Set-Cookie` and no token is one the specification does not describe,
        // and reading a cookie the client library does not manage would be
        // inventing an authentication scheme.
        let token = reply
            .token
            .clone()
            .ok_or(BmcFailure::Redfish(RedfishFailure::Unauthorized))?;

        Ok((
            Credential::Session {
                token,
                path: session_path(&reply, sessions),
            },
            root,
        ))
    }

    /// Ends a session this agent opened. Best effort and never a failure: the
    /// request it follows has already been answered, and a session left behind
    /// expires on the service's own timeout.
    pub async fn close(&self, credential: &Credential) {
        let Credential::Session {
            path: Some(path), ..
        } = credential
        else {
            return;
        };
        if !is_safe_path(path) {
            return;
        }
        if let Err(e) = self
            .send(reqwest::Method::DELETE, path, Some(credential), None)
            .await
        {
            tracing::debug!("bmc: the session was not deleted: {}", e.code());
        }
    }

    /// The system, its chassis and the chassis' readings.
    pub async fn state(&self, credential: &Credential) -> Result<BmcState, BmcFailure> {
        let root = RedfishRoot::parse(
            &self.value(sbm_parser::redfish::ROOT_PATH, None).await?,
        );
        self.state_of(&root, credential).await
    }

    /// The same, with a root the caller already read — the handlers read it
    /// once, when they authenticated.
    pub async fn state_of(
        &self,
        root: &RedfishRoot,
        credential: &Credential,
    ) -> Result<BmcState, BmcFailure> {
        let system = self.first_member(root.systems.as_deref(), credential).await?;
        let system = RedfishSystem::parse(&self.value(&system, Some(credential)).await?);

        // A chassis read that fails is not a failed page: the power state and
        // the machine's identity came from the system, and a service may deny
        // the chassis on its own. The sensors go with it, which is why
        // `sensors_read` is reported rather than implied.
        let chassis = self.chassis(root, credential).await;
        let (sensors, sensors_read, sensors_truncated) = match &chassis {
            Some(chassis) => self.sensors(chassis, credential).await,
            None => (BmcSensors::default(), false, false),
        };

        Ok(BmcState {
            root: root.clone(),
            system,
            chassis,
            sensors,
            sensors_read,
            sensors_truncated,
        })
    }

    /// The first member of a collection the service named.
    async fn first_member(
        &self,
        collection: Option<&str>,
        credential: &Credential,
    ) -> Result<String, BmcFailure> {
        let Some(collection) = collection else {
            return Err(BmcFailure::Redfish(RedfishFailure::NoSystem));
        };
        let body = self.value(collection, Some(credential)).await?;
        // First come, and never derived: an id is `1` on one service,
        // `System.Embedded.1` on another and `system` on a third, and the
        // collection is the only thing that knows which.
        collection_members(&body)
            .first()
            .map(|member| (*member).to_string())
            .ok_or(BmcFailure::Redfish(RedfishFailure::NoSystem))
    }

    async fn chassis(
        &self,
        root: &RedfishRoot,
        credential: &Credential,
    ) -> Option<RedfishChassis> {
        let collection = root.chassis.as_deref()?;
        let body = self.value(collection, Some(credential)).await.ok()?;
        let member = collection_members(&body).first().copied()?.to_string();
        let body = self.value(&member, Some(credential)).await.ok()?;
        Some(RedfishChassis::parse(&body))
    }

    /// The readings, in whichever model this chassis publishes.
    ///
    /// Every failure here is a failure of the readings alone. `sensors_read` is
    /// what a page needs to tell "no fans" from "could not ask".
    async fn sensors(
        &self,
        chassis: &RedfishChassis,
        credential: &Credential,
    ) -> (BmcSensors, bool, bool) {
        let paths = sensor_paths(chassis);
        let empty = (BmcSensors::default(), false, false);
        match chassis.sensor_model() {
            sbm_parser::redfish::SensorModel::None => empty,
            sbm_parser::redfish::SensorModel::Legacy => {
                let mut documents = Vec::new();
                for path in paths {
                    match self.value(path, Some(credential)).await {
                        Ok(document) => documents.push(document),
                        Err(e) => {
                            // One of the pair may be denied on its own — they
                            // are separate resources with separate permissions —
                            // so a missing half is a missing half.
                            tracing::debug!("bmc: a legacy sensor document was refused: {}", e.code());
                            documents.push(Value::Null);
                        }
                    }
                }
                let thermal = documents.first().filter(|d| !d.is_null());
                let power = documents.get(1).filter(|d| !d.is_null());
                if thermal.is_none() && power.is_none() {
                    return empty;
                }
                (
                    BmcSensors::from_legacy(thermal, power),
                    true,
                    false,
                )
            }
            sbm_parser::redfish::SensorModel::Modern => {
                let Some(collection) = paths.first() else {
                    return empty;
                };
                let body = match self.value(collection, Some(credential)).await {
                    Ok(body) => body,
                    Err(e) => {
                        tracing::debug!("bmc: the sensor collection was refused: {}", e.code());
                        return empty;
                    }
                };
                let members = collection_members(&body);
                let truncated = members.len() > MAX_SENSOR_MEMBERS;
                let mut documents = Vec::new();
                // One at a time, not all at once: a service answers these from
                // one small web server, and a chassis publishing sixty-four
                // readings is sixty-four requests it has to serve either way.
                for member in members.iter().take(MAX_SENSOR_MEMBERS) {
                    match self.value(member, Some(credential)).await {
                        Ok(document) => documents.push(document),
                        Err(e) => {
                            tracing::debug!("bmc: a sensor member was refused: {}", e.code());
                            return empty;
                        }
                    }
                }
                (BmcSensors::from_sensors(&documents), true, truncated)
            }
        }
    }

    /// Sends the one request that changes the machine's power state.
    pub async fn reset(
        &self,
        credential: &Credential,
        request: &ResetRequest,
    ) -> Result<(), BmcFailure> {
        let reply = self
            .send(
                reqwest::Method::POST,
                &request.target,
                Some(credential),
                Some(request.body()),
            )
            .await?;
        if (200..300).contains(&reply.status) {
            return Ok(());
        }
        Err(status_failure(reply.status))
    }
}

/// The certificate an address presents, fetched without sending anything.
///
/// The handshake is meant to fail: this agent has nothing pinned yet, and the
/// point of the call is to be told what there is to review. Nothing but the
/// TLS hello leaves the machine.
pub async fn probe_certificate(url: &str) -> Result<String, BmcFailure> {
    let base = validate_url(url)?;
    let provider = provider();
    let verifier = Arc::new(CapturingVerifier {
        seen: Mutex::new(None),
        algorithms: provider.signature_verification_algorithms,
    });
    let tls = ClientConfig::builder_with_provider(Arc::new(provider))
        .with_safe_default_protocol_versions()
        .map_err(|_| BmcFailure::Redfish(RedfishFailure::Unreachable))?
        .dangerous()
        .with_custom_certificate_verifier(verifier.clone())
        .with_no_client_auth();

    let client = builder()
        .tls_backend_preconfigured(tls)
        .build()
        .map_err(|e| {
            tracing::warn!("bmc: could not build the probe client: {e}");
            BmcFailure::Redfish(RedfishFailure::Unreachable)
        })?;
    // The answer does not matter and is not read. Either the handshake fails —
    // which it is meant to — or the certificate happened to be the one already
    // pinned, and this is an unauthenticated GET of the service root.
    let _ = client
        .get(format!("{base}{}", sbm_parser::redfish::ROOT_PATH))
        .send()
        .await;

    let der = verifier
        .take()
        .ok_or(BmcFailure::Redfish(RedfishFailure::Unreachable))?;
    Ok(hex::encode(Sha256::digest(der)))
}

/// Where the login answer said the session lives.
///
/// `Location` first, then the body's own `@odata.id`: both are real, and some
/// services fill in only one. Neither means the request failed — a session the
/// agent cannot name is one the service reaps on its own timeout.
fn session_path(reply: &Reply, sessions: &str) -> Option<String> {
    reply
        .location
        .clone()
        .or_else(|| reply.value.as_ref().and_then(sbm_parser::redfish::odata_id).map(str::to_string))
        .or_else(|| is_safe_path(sessions).then(|| sessions.to_string()))
}

/// The status a failed request is answered as.
///
/// Only the codes the model names, and never the upstream's own number: 401
/// here would log the operator out of the panel, and it is the *agent's*
/// credential that was refused.
fn status_failure(status: u16) -> BmcFailure {
    match status {
        401 => BmcFailure::Redfish(RedfishFailure::Unauthorized),
        403 => BmcFailure::Redfish(RedfishFailure::Forbidden),
        // `428 Precondition Required` is what a service answers when a write
        // needs an `ETag` it was not given, and 412 is the same condition.
        412 | 428 => BmcFailure::Redfish(RedfishFailure::PreconditionRequired),
        _ => {
            tracing::warn!("bmc: the service answered {status}");
            BmcFailure::Redfish(RedfishFailure::InvalidResponse)
        }
    }
}

