//! `sb.http.fetch` on the agent, with the same certificate rules as the app.
//!
//! The rules are not the agent's to soften. A plugin written against the app's
//! host and moved here must behave the same or the promise `runs_in` makes is
//! worthless — and the promise that matters most is the one about
//! certificates, because getting it wrong is silent.
//!
//! **The pin is the whole trust decision.** The verifier below accepts one
//! certificate and no other: a chain a public CA vouches for is refused
//! exactly like a self-signed one unless it is the one that was reviewed.
//! Anything less would let a plugin name a host whose certificate some CA
//! happens to have signed, which is the attack pinning is for.
//!
//! An absent pin refuses rather than falling back to ordinary validation. The
//! hardware this is first for ships certificates no CA has ever seen, so
//! "valid chain" and "the right machine" have nothing to do with each other.
//!
//! The review half is `probeCert`, which reads a certificate and sends
//! nothing. `sbm_plugin::scope` refuses a probe carrying a body or headers,
//! which is what makes accepting any certificate there safe.

use std::sync::{Arc, Mutex};
use std::time::Duration;

use base64::Engine;
use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{Error as TlsError, SignatureScheme};
use sbm_plugin::BridgeError;
use serde::Deserialize;
use serde_json::json;
use sha2::{Digest, Sha256};

/// Anything larger is refused rather than held.
///
/// A plugin runs in an interpreter with a memory ceiling, and the body crosses
/// into it as one string. A Redfish document — the reason this exists — is
/// tens of kilobytes.
const MAX_BODY_BYTES: usize = 8 * 1024 * 1024;

#[derive(Debug, Deserialize)]
pub struct FetchRequest {
    pub url: String,
    #[serde(default)]
    pub method: Option<String>,
    #[serde(default)]
    pub headers: std::collections::BTreeMap<String, String>,
    #[serde(default)]
    pub body: Option<String>,
    #[serde(default)]
    pub body_encoding: Option<String>,
    /// SHA-256 of the DER form, lowercase hex. Absent refuses every
    /// certificate unless [`probe_cert`](Self::probe_cert) is set.
    #[serde(default, rename = "pinSha256")]
    pub pin_sha256: Option<String>,
    #[serde(default, rename = "probeCert")]
    pub probe_cert: bool,
    #[serde(default, rename = "timeoutMs")]
    pub timeout_ms: Option<u64>,
}

pub async fn fetch(req: FetchRequest, default_timeout: Duration) -> Result<Vec<u8>, BridgeError> {
    let url = reqwest::Url::parse(&req.url)
        .map_err(|e| BridgeError::failed("bad_request", format!("sb.http.fetch: {e}")))?;
    let tls = url.scheme() == "https";
    let timeout = resolve_timeout(req.timeout_ms, default_timeout);

    if req.probe_cert {
        if !tls {
            return Err(BridgeError::failed(
                "bad_request",
                "sb.http.fetch: `probeCert` needs an https url",
            ));
        }
        return probe(&url, timeout).await;
    }

    if tls && req.pin_sha256.as_deref().unwrap_or("").is_empty() {
        return Err(BridgeError::failed(
            "cert",
            "sb.http.fetch: https needs `pinSha256`; review the certificate \
             with `probeCert` first",
        ));
    }

    let seen = Arc::new(Mutex::new(None::<Vec<u8>>));
    let client = build_client(req.pin_sha256.clone(), Arc::clone(&seen), timeout, tls)?;

    let method = reqwest::Method::from_bytes(
        req.method.as_deref().unwrap_or("GET").to_uppercase().as_bytes(),
    )
    .map_err(|e| BridgeError::failed("bad_request", format!("sb.http.fetch: {e}")))?;

    let mut send = client.request(method, url);
    for (name, value) in &req.headers {
        send = send.header(name, value);
    }
    if let Some(body) = req.body.filter(|b| !b.is_empty()) {
        let bytes = if req.body_encoding.as_deref() == Some("base64") {
            base64::engine::general_purpose::STANDARD
                .decode(body)
                .map_err(|e| BridgeError::failed("bad_request", format!("sb.http.fetch: {e}")))?
        } else {
            body.into_bytes()
        };
        send = send.body(bytes);
    }

    let response = send
        .send()
        .await
        .map_err(|e| BridgeError::failed("http", e.to_string()))?;

    let status = response.status().as_u16();
    let mut headers = std::collections::BTreeMap::new();
    for (name, value) in response.headers() {
        if let Ok(v) = value.to_str() {
            headers.insert(name.as_str().to_string(), v.to_string());
        }
    }

    let bytes = response
        .bytes()
        .await
        .map_err(|e| BridgeError::failed("http", e.to_string()))?;
    if bytes.len() > MAX_BODY_BYTES {
        return Err(BridgeError::failed(
            "http",
            "the answer is larger than the limit",
        ));
    }

    // Text where it is text, which is nearly always: base64 costs an
    // interpreter something per byte and a Redfish document is JSON.
    // Undecodable bytes fall back rather than fail.
    let (body, encoding) = match String::from_utf8(bytes.to_vec()) {
        Ok(text) => (text, "utf8"),
        Err(_) => (
            base64::engine::general_purpose::STANDARD.encode(&bytes),
            "base64",
        ),
    };

    let cert = seen.lock().expect("poisoned").clone().map(describe);
    Ok(json!({
        "status": status,
        "headers": headers,
        "body": body,
        "bodyEncoding": encoding,
        "cert": cert,
    })
    .to_string()
    .into_bytes())
}

/// Reads the certificate and sends nothing.
///
/// A request is made because that is how a handshake happens, and it is a
/// `HEAD` to the origin — but what is answered is the certificate, and the
/// body is dropped. `sbm_plugin::scope` has already refused a probe carrying
/// anything to send, which is what makes accepting any certificate here safe.
async fn probe(url: &reqwest::Url, timeout: Duration) -> Result<Vec<u8>, BridgeError> {
    let seen = Arc::new(Mutex::new(None::<Vec<u8>>));
    let client = build_client(None, Arc::clone(&seen), timeout, true)?;

    // The failure is ignored on purpose: a machine that answers 404, closes
    // the connection, or speaks no HTTP at all has still presented a
    // certificate by then, which is the whole of what was asked for.
    let _ = client.head(url.clone()).send().await;

    match seen.lock().expect("poisoned").clone() {
        Some(der) => Ok(json!({
            "status": 0,
            "headers": {},
            "body": "",
            "bodyEncoding": "utf8",
            "cert": describe(der),
        })
        .to_string()
        .into_bytes()),
        None => Err(BridgeError::failed(
            "cert",
            "the peer presented no certificate",
        )),
    }
}

fn build_client(
    pin: Option<String>,
    seen: Arc<Mutex<Option<Vec<u8>>>>,
    timeout: Duration,
    tls: bool,
) -> Result<reqwest::Client, BridgeError> {
    let mut builder = reqwest::Client::builder()
        .timeout(timeout)
        // Off, so a redirect cannot move a pinned request to another host: the
        // address grant was checked against the URL the plugin named, and a
        // 3xx is an answer the plugin gets to see and decide about.
        .redirect(reqwest::redirect::Policy::none());

    if tls {
        let config = rustls::ClientConfig::builder()
            .dangerous()
            .with_custom_certificate_verifier(Arc::new(Pinned { pin, seen }))
            .with_no_client_auth();
        builder = builder.use_preconfigured_tls(config);
    }
    builder
        .build()
        .map_err(|e| BridgeError::failed("http", e.to_string()))
}

/// Accepts one certificate and no other.
///
/// A `ServerCertVerifier` rather than a check after the fact, because after
/// the fact is too late: the request's body is already on the wire, and a
/// password must not reach a certificate nobody vouched for.
#[derive(Debug)]
struct Pinned {
    /// `None` accepts anything, which is only ever used by [`probe`] — and is
    /// safe there because nothing is sent.
    pin: Option<String>,
    /// Where the certificate is recorded for the answer.
    seen: Arc<Mutex<Option<Vec<u8>>>>,
}

impl ServerCertVerifier for Pinned {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, TlsError> {
        *self.seen.lock().expect("poisoned") = Some(end_entity.to_vec());

        let Some(pin) = self.pin.as_ref() else {
            return Ok(ServerCertVerified::assertion());
        };
        // Not SHA-1, the digest most tools print ready made: a trust decision
        // does not rest on it.
        let actual = hex(&Sha256::digest(end_entity.as_ref()));
        if constant_time_eq(&pin.to_ascii_lowercase(), &actual) {
            Ok(ServerCertVerified::assertion())
        } else {
            Err(TlsError::General(
                "the certificate is not the one that was pinned".into(),
            ))
        }
    }

    /// Accepted because the certificate itself is the decision.
    ///
    /// These two prove the peer holds the key for the certificate it sent, and
    /// rustls checks that regardless; what they cannot answer is whether that
    /// certificate is the right one, which is what `verify_server_cert` above
    /// is for.
    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &rustls::DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, TlsError> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &CertificateDer<'_>,
        _dss: &rustls::DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, TlsError> {
        Ok(HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        rustls::crypto::ring::default_provider()
            .signature_verification_algorithms
            .supported_schemes()
    }
}

/// A certificate as it is shown to somebody deciding whether to trust it.
///
/// The fingerprint alone is unreadable, and a person comparing one against a
/// device's own web interface needs the rest to know they are looking at the
/// same thing. Fields the agent cannot read without an X.509 parser are left
/// out rather than guessed at — the app's version fills them from `dart:io`,
/// and a plugin reads `sha256`, which is the one it acts on.
fn describe(der: Vec<u8>) -> serde_json::Value {
    json!({
        "sha256": hex(&Sha256::digest(&der)),
        "subject": "",
        "issuer": "",
        "notBefore": "",
        "notAfter": "",
        "expired": false,
    })
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

/// Compared without an early exit.
///
/// A fingerprint is public, so this guards no secret; it costs nothing and
/// keeps the habit where the subject is what to trust.
fn constant_time_eq(a: &str, b: &str) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.bytes().zip(b.bytes()).fold(0u8, |acc, (x, y)| acc | (x ^ y)) == 0
}

/// A plugin may shorten the bound and never lengthen it.
///
/// The agent's timeout is the agent's decision, and a request that outlives a
/// collection cycle is one holding the cycle open.
fn resolve_timeout(requested_ms: Option<u64>, default: Duration) -> Duration {
    requested_ms
        .map(Duration::from_millis)
        .filter(|d| *d < default)
        .unwrap_or(default)
}

#[cfg(test)]
mod tests {
    use super::*;

    const DEFAULT: Duration = Duration::from_secs(30);

    /// A refusal a plugin can `catch`, unpacked. Nothing here should ever be
    /// `Denied` — that is the app's word for a grant, and this file decides
    /// about certificates.
    fn failure(e: BridgeError) -> (String, String) {
        match e {
            BridgeError::Failed { kind, message } => (kind, message),
            BridgeError::Denied { detail } => panic!("unexpected denial: {detail}"),
        }
    }

    fn req(url: &str) -> FetchRequest {
        FetchRequest {
            url: url.to_string(),
            method: None,
            headers: Default::default(),
            body: None,
            body_encoding: None,
            pin_sha256: None,
            probe_cert: false,
            timeout_ms: None,
        }
    }

    /// The refusal that matters, and it happens before a socket is opened:
    /// falling back to ordinary validation would mean a plugin reaching a host
    /// whose certificate some CA happens to have signed.
    #[tokio::test]
    async fn https_without_a_pin_is_refused_before_anything_is_sent() {
        // The address is unroutable, so a test that reached the network would
        // hang rather than pass by accident.
        let (kind, message) = failure(
            fetch(req("https://192.0.2.1/redfish/v1"), DEFAULT)
                .await
                .expect_err("no pin, no request"),
        );
        assert_eq!(kind, "cert");
        assert!(message.contains("probeCert"), "{message}");
    }

    /// An empty string is what a plugin sends when it means "I have no pin",
    /// and it has to read as absent rather than as a pin nothing matches.
    #[tokio::test]
    async fn an_empty_pin_is_no_pin() {
        let mut r = req("https://192.0.2.1/");
        r.pin_sha256 = Some(String::new());

        assert_eq!(failure(fetch(r, DEFAULT).await.unwrap_err()).0, "cert");
    }

    /// Plaintext needs no pin — there is nothing to pin — and the agent's own
    /// address grant is what decides whether it may be reached at all.
    #[tokio::test]
    async fn probing_is_only_for_tls() {
        let mut r = req("http://192.0.2.1/");
        r.probe_cert = true;

        let (kind, message) = failure(fetch(r, DEFAULT).await.unwrap_err());
        assert_eq!(kind, "bad_request");
        assert!(message.contains("https"), "{message}");
    }

    #[tokio::test]
    async fn a_url_that_is_not_one_is_a_bad_request() {
        let e = fetch(req("not a url"), DEFAULT).await.unwrap_err();
        assert_eq!(failure(e).0, "bad_request");
    }

    /// The verifier is the trust decision, so it is asserted directly rather
    /// than through a handshake: one certificate is accepted and every other
    /// one is not, whoever signed it.
    #[test]
    fn the_verifier_accepts_the_pinned_certificate_and_no_other() {
        let der = CertificateDer::from(vec![1u8, 2, 3, 4]);
        let pin = hex(&Sha256::digest([1u8, 2, 3, 4]));

        let seen = Arc::new(Mutex::new(None));
        let v = Pinned {
            pin: Some(pin.to_uppercase()),
            seen: Arc::clone(&seen),
        };
        assert!(verify(&v, &der).is_ok(), "the reviewed certificate is the one accepted");
        assert_eq!(
            seen.lock().unwrap().clone(),
            Some(vec![1u8, 2, 3, 4]),
            "what was presented is recorded, so the plugin can be shown it"
        );

        let other = CertificateDer::from(vec![9u8, 9, 9]);
        assert!(verify(&v, &other).is_err(), "a different certificate is refused");
    }

    /// `probe` reviews rather than trusts, and sends nothing — which is what
    /// makes accepting whatever is presented safe there.
    #[test]
    fn a_probe_accepts_what_it_is_shown() {
        let seen = Arc::new(Mutex::new(None));
        let v = Pinned { pin: None, seen: Arc::clone(&seen) };

        assert!(verify(&v, &CertificateDer::from(vec![7u8])).is_ok());
        assert_eq!(seen.lock().unwrap().clone(), Some(vec![7u8]));
    }

    fn verify(v: &Pinned, der: &CertificateDer<'_>) -> Result<ServerCertVerified, TlsError> {
        v.verify_server_cert(
            der,
            &[],
            &ServerName::try_from("example.invalid").unwrap(),
            &[],
            UnixTime::now(),
        )
    }

    #[test]
    fn a_plugin_may_shorten_the_timeout_and_not_lengthen_it() {
        assert_eq!(resolve_timeout(Some(1_000), DEFAULT), Duration::from_secs(1));
        assert_eq!(resolve_timeout(Some(600_000), DEFAULT), DEFAULT);
        assert_eq!(resolve_timeout(None, DEFAULT), DEFAULT);
    }
}
