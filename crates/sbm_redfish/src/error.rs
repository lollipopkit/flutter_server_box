//! Why a service could not be read, in the vocabulary both clients phrase.

use std::fmt;

use serde::{Deserialize, Serialize};

/// Why a service could not be read.
///
/// The first eight are the Dart `RedfishFailure` enum, with the same names as
/// codes ([`Failure::as_str`]), so a client that already phrases those needs
/// no second table. The rest are answers only this crate gives, each for a
/// check the Dart client did not make; see their own notes.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Failure {
    /// Answered, but is not a Redfish service — a static host serving its
    /// index page for every path looks exactly like this.
    NotAService,

    /// Reachable and a service, but offers no system to read.
    NoSystem,

    /// A sub-resource was refused. Licensing gates parts of some services
    /// (Supermicro's keys), so this is an ordinary answer about *that
    /// resource* and not a reason to call the whole service unusable.
    Forbidden,

    /// The certificate was not the one that was reviewed, or nothing has been
    /// reviewed yet. Distinct from [`Failure::Unreachable`] because the fix is
    /// a person looking at a fingerprint, not a network.
    CertificateRejected,

    /// The account was refused.
    Unauthorized,

    /// No account to log in with. Never produced by this crate — a client
    /// always has a user — but part of the shared vocabulary, since the
    /// caller that looks the account up reports it in the same terms.
    NoCredential,

    /// The service requires an `If-Match` and none was sent, or the one sent
    /// no longer matches. Retrying after a fresh read is the fix.
    PreconditionRequired,

    /// Nothing answered, or answered with something that is not a resource.
    Unreachable,

    /// Rust only. The service allows nothing that satisfies the intent, so
    /// nothing was sent — the app's `BmcPowerResult.notSupported`.
    NotSupported,

    /// Rust only. No certificate has been reviewed and the caller asked for
    /// one to be required ([`crate::client::ClientConfig::require_pin`]), so
    /// no connection was opened. The unrequired case is still refused, at the
    /// handshake, as [`Failure::CertificateRejected`] — what Dart does.
    CertNotReviewed,

    /// Rust only. An answer this client will not act on: larger than
    /// [`crate::client::MAX_BODY`], or naming a path that leaves the service
    /// (another origin, traversal, outside `/redfish/v1/`). The Dart client
    /// buffered any size and followed any link.
    InvalidResponse,

    /// Rust only. The configured address is not an `https://` URL this client
    /// can use. Dart accepted any string and failed every request on it.
    InvalidUrl,

    /// Rust only. The client was closed; the Dart client threw a
    /// `StateError` here.
    Closed,
}

impl Failure {
    pub const ALL: [Failure; 13] = [
        Failure::NotAService,
        Failure::NoSystem,
        Failure::Forbidden,
        Failure::CertificateRejected,
        Failure::Unauthorized,
        Failure::NoCredential,
        Failure::PreconditionRequired,
        Failure::Unreachable,
        Failure::NotSupported,
        Failure::CertNotReviewed,
        Failure::InvalidResponse,
        Failure::InvalidUrl,
        Failure::Closed,
    ];

    /// The code a client phrases: the Dart enum's name where there is one.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::NotAService => "notAService",
            Self::NoSystem => "noSystem",
            Self::Forbidden => "forbidden",
            Self::CertificateRejected => "certificateRejected",
            Self::Unauthorized => "unauthorized",
            Self::NoCredential => "noCredential",
            Self::PreconditionRequired => "preconditionRequired",
            Self::Unreachable => "unreachable",
            Self::NotSupported => "notSupported",
            Self::CertNotReviewed => "certNotReviewed",
            Self::InvalidResponse => "invalidResponse",
            Self::InvalidUrl => "invalidUrl",
            Self::Closed => "closed",
        }
    }

    pub fn parse(raw: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|f| f.as_str() == raw)
    }
}

impl fmt::Display for Failure {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

/// A [`Failure`] and what is known about where it happened.
///
/// `detail` is safe to log and to show: a path, a status code, a transport
/// error's kind. It never carries the password, a session token or any part of
/// a response body — a Redfish error document is not needed to phrase any
/// failure here, and the login's answer is a document about a credential.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Error {
    pub failure: Failure,
    pub detail: Option<String>,
}

impl Error {
    pub fn new(failure: Failure) -> Self {
        Self {
            failure,
            detail: None,
        }
    }

    pub fn with(failure: Failure, detail: impl Into<String>) -> Self {
        Self {
            failure,
            detail: Some(detail.into()),
        }
    }
}

impl From<Failure> for Error {
    fn from(failure: Failure) -> Self {
        Self::new(failure)
    }
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match &self.detail {
            Some(detail) => write!(f, "{}: {detail}", self.failure.as_str()),
            None => f.write_str(self.failure.as_str()),
        }
    }
}

impl std::error::Error for Error {}
