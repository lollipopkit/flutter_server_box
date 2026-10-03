//! Trust-on-review for a BMC's TLS certificate, in two halves.
//!
//! - [`fetch_server_cert`] is the *review* step, driven by a person. It opens a
//!   socket for no purpose but to read the certificate, and sends nothing but
//!   a TLS hello.
//! - [`PinnedCert::accepts`] is the *enforcement* step, run inside every
//!   handshake the client makes, with no interaction at all. An unreviewed or
//!   changed certificate is refused, not queried — by then there is a request
//!   waiting to go out, and it carries a password.
//!
//! Ported from the Dart package `redfish` (`cert_pin.dart`), removed with this port. The stored form of a
//! fingerprint is Dart's `certFingerprint`: SHA-256 of the DER, lowercase hex,
//! no separators. Existing installs hold pins in exactly that form, so it is
//! what [`fingerprint`] produces and what [`normalize_fingerprint`] reduces any
//! pasted spelling to.

use std::sync::{Arc, Mutex};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use rustls::client::danger::{HandshakeSignatureValid, ServerCertVerified, ServerCertVerifier};
use rustls::crypto::WebPkiSupportedAlgorithms;
use rustls::pki_types::{CertificateDer, ServerName, UnixTime};
use rustls::{CertificateError, DigitallySignedStruct, SignatureScheme};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tokio::net::TcpStream;
use x509_cert::der::asn1::{Ia5StringRef, PrintableStringRef, TeletexStringRef, Utf8StringRef};
use x509_cert::der::{Decode, Tag, Tagged};

use crate::error::{Error, Failure};

/// Length of a stored fingerprint: SHA-256, as hex.
pub const FINGERPRINT_LEN: usize = 64;

/// SHA-256 of a certificate's DER form, lowercase hex — Dart's
/// `certFingerprint`, byte for byte.
pub fn fingerprint(der: &[u8]) -> String {
    let digest = Sha256::digest(der);
    let mut out = String::with_capacity(FINGERPRINT_LEN);
    for byte in digest.iter() {
        out.push_str(&format!("{byte:02x}"));
    }
    out
}

/// A fingerprint as it is stored and compared: lowercase, with the separators
/// a person pastes (`:`, spaces, `-`) removed.
///
/// Nothing else is changed, so a string that is not a fingerprint stays one
/// that can only fail to match — check [`is_fingerprint`] before storing.
/// Dart compared `pin.toLowerCase()` and nothing more; every pin it stored is
/// already in this form and comes out unchanged.
pub fn normalize_fingerprint(input: &str) -> String {
    input
        .chars()
        .filter(|c| !matches!(c, ':' | ' ' | '-'))
        .flat_map(char::to_lowercase)
        .collect()
}

/// Whether `input`, normalized, is a SHA-256 fingerprint: 64 hex digits.
pub fn is_fingerprint(input: &str) -> bool {
    let normalized = normalize_fingerprint(input);
    normalized.len() == FINGERPRINT_LEN && normalized.bytes().all(|b| b.is_ascii_hexdigit())
}

/// The fingerprint in the colon-separated, upper-case form fingerprints are
/// usually printed in, which is how a BMC's own web UI shows it. Pairs of
/// whatever is given, as Dart's `prettyFingerprint` did; an odd trailing digit
/// is dropped there too.
pub fn pretty_fingerprint(fingerprint: &str) -> String {
    let chars: Vec<char> = fingerprint.chars().collect();
    let (pairs, _) = chars.as_chunks::<2>();
    pairs
        .iter()
        .map(|pair| pair.iter().collect::<String>())
        .collect::<Vec<_>>()
        .join(":")
        .to_uppercase()
}

/// The decision half: does this certificate match what was reviewed.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PinnedCert {
    /// What the user accepted, normalized, or `None` if nothing was reviewed.
    fingerprint: Option<String>,
}

impl PinnedCert {
    pub fn new(fingerprint: Option<&str>) -> Self {
        Self {
            fingerprint: fingerprint
                .map(normalize_fingerprint)
                .filter(|f| !f.is_empty()),
        }
    }

    pub fn has_pin(&self) -> bool {
        self.fingerprint.is_some()
    }

    /// Whether `der` is the certificate that was pinned.
    ///
    /// False when nothing is pinned, deliberately. The alternative — trusting
    /// whatever appears the first time a request happens to be made — is
    /// trust-on-first-*use*, where the use is a request already carrying a
    /// password. `None` (no certificate obtained) is also false: "no
    /// certificate" must never read as "matches".
    pub fn accepts(&self, der: Option<&[u8]>) -> bool {
        match (&self.fingerprint, der) {
            (Some(pinned), Some(der)) => constant_time_eq(pinned.as_bytes(), fingerprint(der).as_bytes()),
            _ => false,
        }
    }
}

/// Compared without an early exit, after a length check, so a pin that is a
/// prefix of the real fingerprint does not match. A fingerprint is public;
/// this keeps the habit in the one place whose subject is what to trust.
fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    a.iter().zip(b).fold(0u8, |diff, (x, y)| diff | (x ^ y)) == 0
}

/// A certificate as it is shown to someone deciding whether to trust it.
///
/// The fingerprint alone is unreadable, and a person asked to compare one
/// against a BMC's web UI needs the rest to know they are looking at the same
/// thing.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CertInfo {
    pub fingerprint: String,
    /// OpenSSL's one-line form (`/CN=bmc/O=Vendor`), which is what Dart's
    /// `X509Certificate.subject` printed.
    pub subject: String,
    pub issuer: String,
    /// Unix seconds.
    pub not_before: i64,
    pub not_after: i64,
}

impl CertInfo {
    /// Reads a DER certificate. `None` when it does not parse — a certificate
    /// rustls accepted for a handshake but `x509-cert` cannot read is not one
    /// to put in front of a person.
    pub fn from_der(der: &[u8]) -> Option<Self> {
        let cert = x509_cert::Certificate::from_der(der).ok()?;
        let tbs = cert.tbs_certificate();
        let validity = tbs.validity();
        Some(Self {
            fingerprint: fingerprint(der),
            subject: oneline(tbs.subject()),
            issuer: oneline(tbs.issuer()),
            not_before: unix(validity.not_before.to_unix_duration()),
            not_after: unix(validity.not_after.to_unix_duration()),
        })
    }

    /// Whether the certificate is outside its own validity window.
    ///
    /// Worth showing rather than acting on: BMCs are frequently shipped with
    /// certificates that expired years ago, and refusing those would refuse
    /// most of the hardware this is for. The user is told and decides.
    pub fn is_expired(&self) -> bool {
        self.is_expired_at(now_unix())
    }

    pub fn is_expired_at(&self, unix_seconds: i64) -> bool {
        unix_seconds < self.not_before || unix_seconds > self.not_after
    }

    pub fn pretty_fingerprint(&self) -> String {
        pretty_fingerprint(&self.fingerprint)
    }
}

fn unix(d: Duration) -> i64 {
    i64::try_from(d.as_secs()).unwrap_or(i64::MAX)
}

fn now_unix() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_or(0, unix)
}

/// A distinguished name in OpenSSL's `X509_NAME_oneline` form, in encoding
/// order: `/C=US/O=Vendor/CN=bmc`.
fn oneline(name: &x509_cert::name::Name) -> String {
    let mut out = String::new();
    for rdn in name.iter_rdn() {
        for atv in rdn.iter() {
            let key = match atv.oid.to_string().as_str() {
                "2.5.4.3" => Some("CN"),
                "2.5.4.5" => Some("serialNumber"),
                "2.5.4.6" => Some("C"),
                "2.5.4.7" => Some("L"),
                "2.5.4.8" => Some("ST"),
                "2.5.4.10" => Some("O"),
                "2.5.4.11" => Some("OU"),
                "1.2.840.113549.1.9.1" => Some("emailAddress"),
                "0.9.2342.19200300.100.1.25" => Some("DC"),
                _ => None,
            };
            let value = match atv.value.tag() {
                Tag::PrintableString => PrintableStringRef::try_from(&atv.value).ok().map(|s| String::from(s.as_str())),
                Tag::Utf8String => Utf8StringRef::try_from(&atv.value).ok().map(|s| String::from(s.as_str())),
                Tag::Ia5String => Ia5StringRef::try_from(&atv.value).ok().map(|s| String::from(s.as_str())),
                Tag::TeletexString => TeletexStringRef::try_from(&atv.value).ok().map(|s| String::from(s.as_str())),
                _ => None,
            };
            out.push('/');
            match (key, value) {
                (Some(key), Some(value)) => {
                    out.push_str(key);
                    out.push('=');
                    out.push_str(&value);
                }
                // An attribute this does not name: x509-cert's RFC 4514 form.
                _ => out.push_str(&atv.to_string()),
            }
        }
    }
    out
}

/// Reads the certificate `host`:`port` presents, without making a request.
///
/// The verifier records the leaf and refuses it, which is the whole point:
/// this is the step whose *job* is to look at a certificate no CA vouches for,
/// and refusing it ends the handshake before anything but the hello has been
/// sent. Dart accepted the certificate and destroyed the socket afterwards;
/// either way no credential reaches whatever answered.
///
/// [`Failure::Unreachable`] for anything else: a BMC that is off, unreachable
/// or not speaking TLS is a different problem from one whose certificate is
/// unknown, and the caller has to be able to say which.
pub async fn fetch_server_cert(host: &str, port: u16, timeout: Duration) -> Result<CertInfo, Error> {
    let provider = rustls::crypto::ring::default_provider();
    let verifier = Arc::new(CapturingVerifier {
        seen: Mutex::new(None),
        algorithms: provider.signature_verification_algorithms,
    });
    let config = rustls::ClientConfig::builder_with_provider(Arc::new(provider))
        .with_safe_default_protocol_versions()
        .map_err(|e| Error::with(Failure::Unreachable, format!("TLS setup: {e}")))?
        .dangerous()
        .with_custom_certificate_verifier(verifier.clone())
        .with_no_client_auth();
    let connector = tokio_rustls::TlsConnector::from(Arc::new(config));
    // A bracketed IPv6 literal, as it appears in a URL, is still an address.
    let bare = host.trim_start_matches('[').trim_end_matches(']');
    let server_name = ServerName::try_from(bare.to_string())
        .map_err(|_| Error::with(Failure::InvalidUrl, "not a host name or address"))?;

    let handshake = async {
        let tcp = TcpStream::connect((bare, port))
            .await
            .map_err(|e| Error::with(Failure::Unreachable, format!("connect: {}", e.kind())))?;
        // Expected to fail: the verifier refuses what it records.
        let _ = connector.connect(server_name, tcp).await;
        Ok::<_, Error>(())
    };
    tokio::time::timeout(timeout, handshake)
        .await
        .map_err(|_| Error::with(Failure::Unreachable, "timed out"))??;

    let der = verifier
        .take()
        .ok_or_else(|| Error::with(Failure::Unreachable, "the server presented no certificate"))?;
    CertInfo::from_der(&der).ok_or_else(|| Error::with(Failure::Unreachable, "the certificate does not parse"))
}

/// Records the certificate it was shown, then refuses it.
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
    ) -> Result<ServerCertVerified, rustls::Error> {
        if let Ok(mut slot) = self.seen.lock() {
            *slot = Some(end_entity.as_ref().to_vec());
        }
        Err(rustls::Error::InvalidCertificate(
            CertificateError::ApplicationVerificationFailure,
        ))
    }

    // Never reached: the certificate is refused above, and that ends the
    // handshake before any signature is checked. Verified anyway, so nothing
    // in this type ever answers "valid" without having looked.
    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls12_signature(message, cert, dss, &self.algorithms)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls13_signature(message, cert, dss, &self.algorithms)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.algorithms.supported_schemes()
    }
}

/// Accepts exactly the pinned leaf, and nothing else — the client's verifier.
///
/// No chain is walked and no validity date is read: a BMC's certificate is
/// expired as often as not, and what is trusted is that this is the
/// certificate that was reviewed. A CA-signed chain is not accepted either
/// unless it is that certificate; the Dart client let one through the
/// handshake and refused it only after the response, by which time a login
/// had already carried the password. The handshake signatures are still
/// checked, so a certificate this accepts must also be proven by its key.
#[derive(Debug)]
pub(crate) struct PinnedVerifier {
    pub(crate) pin: PinnedCert,
    pub(crate) algorithms: WebPkiSupportedAlgorithms,
}

impl ServerCertVerifier for PinnedVerifier {
    fn verify_server_cert(
        &self,
        end_entity: &CertificateDer<'_>,
        _intermediates: &[CertificateDer<'_>],
        _server_name: &ServerName<'_>,
        _ocsp_response: &[u8],
        _now: UnixTime,
    ) -> Result<ServerCertVerified, rustls::Error> {
        if self.pin.accepts(Some(end_entity.as_ref())) {
            Ok(ServerCertVerified::assertion())
        } else {
            Err(rustls::Error::InvalidCertificate(
                CertificateError::ApplicationVerificationFailure,
            ))
        }
    }

    fn verify_tls12_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls12_signature(message, cert, dss, &self.algorithms)
    }

    fn verify_tls13_signature(
        &self,
        message: &[u8],
        cert: &CertificateDer<'_>,
        dss: &DigitallySignedStruct,
    ) -> Result<HandshakeSignatureValid, rustls::Error> {
        rustls::crypto::verify_tls13_signature(message, cert, dss, &self.algorithms)
    }

    fn supported_verify_schemes(&self) -> Vec<SignatureScheme> {
        self.algorithms.supported_schemes()
    }
}
