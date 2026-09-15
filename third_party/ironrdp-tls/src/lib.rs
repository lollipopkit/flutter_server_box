#![cfg_attr(doc, doc = include_str!("../README.md"))]
#![doc(html_logo_url = "https://cdnweb.devolutions.net/images/projects/devolutions/logos/devolutions-icon-shadow.svg")]

#[cfg(feature = "rustls-no-provider")]
#[path = "rustls.rs"]
mod impl_;

#[cfg(feature = "native-tls")]
#[path = "native_tls.rs"]
mod impl_;

#[cfg(feature = "stub")]
#[path = "stub.rs"]
mod impl_;

#[cfg(any(
    not(any(feature = "stub", feature = "native-tls", feature = "rustls-no-provider")),
    all(feature = "stub", feature = "native-tls"),
    all(feature = "stub", feature = "rustls-no-provider"),
    all(feature = "rustls-no-provider", feature = "native-tls"),
))]
compile_error!(
    "a TLS backend must be selected by enabling a single feature out of: `rustls`, `native-tls`, `stub` (the rustls crypto provider is chosen via `rustls`/`rustls-aws-lc-rs`/`rustls-ring`/`rustls-no-provider`)"
);

// The whole public API of this crate.
#[cfg(any(feature = "stub", feature = "native-tls", feature = "rustls-no-provider"))]
pub use impl_::{TlsStream, negotiated, upgrade, upgrade_with_identity};

/// The leaf certificate and whether platform trust roots accepted it for the
/// requested server name.
pub struct TlsServerIdentity {
    pub certificate: x509_cert::Certificate,
    pub system_trusted: bool,
}

/// TLS parameters negotiated during the handshake, to the extent the active
/// backend exposes them.
///
/// The `rustls` backend reports both fields. The `native-tls` and `stub`
/// backends cannot introspect the negotiated parameters, so both are `None`
/// there.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct NegotiatedTls {
    /// Negotiated protocol version, e.g. `"TLSv1_3"`.
    pub version: Option<String>,
    /// Negotiated cipher suite, e.g. `"TLS13_AES_256_GCM_SHA384"`.
    pub cipher_suite: Option<String>,
}

pub fn extract_tls_server_public_key(cert: &x509_cert::Certificate) -> Option<&[u8]> {
    cert.tbs_certificate
        .subject_public_key_info
        .subject_public_key
        .as_bytes()
}
