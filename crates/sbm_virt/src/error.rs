//! Why a host could not be read or an action did not happen, for either
//! backend. Mirrors the app's `VirtErrType`.

use sbm_redfish::cert::CertInfo;
use serde::{Deserialize, Serialize};

/// What a client branches on.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorKind {
    /// The host could not be reached: the transport failed, or the API did
    /// not answer.
    Unreachable,
    /// No usable configuration: no address, no password or token to log in
    /// with.
    NotConfigured,
    /// PVE refused the login, the session or the token (HTTP 401), or its
    /// permission check refused this account something a listing needs (HTTP
    /// 403 outside a guest action, which keeps the session).
    AuthFailed,
    /// PVE wants a TOTP code: [`crate::pve::Client::submit_tfa`].
    NeedTfa,
    /// The certificate is not signed by a trusted CA and none has been
    /// confirmed: [`Error::cert`] is what the server presented.
    CertUnconfirmed,
    /// The certificate is not the one confirmed before:
    /// [`Error::previous_fingerprint`] was pinned, [`Error::cert`] presented.
    CertChanged,
    /// The account may see nothing at all; [`Detail`] says what to grant.
    PermissionDenied,
    /// The host answered with something this cannot read.
    InvalidResponse,
    /// An action was refused or its task ended in an error; the message is
    /// the host's own text.
    ActionFailed,
    /// Not offered for this guest or host.
    Unsupported,
    /// A name (or PVE VMID, or volume) is taken on the host.
    Exists,
    /// The configuration changed since it was read.
    Conflict,
    /// The client was closed.
    Closed,
}

/// What a client phrases itself, in its own language, when no host text
/// says it. The values it needs travel with it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "code", rename_all = "snake_case")]
pub enum Detail {
    /// A password login with no user name.
    NoUser,
    /// A password login with no password.
    PasswordRequired,
    /// A token login with no id or no secret.
    TokenIncomplete,
    /// The account has TOTP: a code is needed.
    OtpRequired,
    /// The code submitted was empty.
    OtpEmpty,
    /// PVE refused the code (wrong, or already used).
    OtpRejected,
    /// The body was not a JSON object.
    InvalidBody,
    /// The body's `data` was not what the call returns.
    InvalidData,
    /// A login answered without a ticket.
    MissingTicket,
    /// May audit nothing; `command` is the `pveum` line that grants it.
    NoPrivileges { token: bool, account: String, command: String },
    /// The action is not among the guest's.
    NotOffered,
    /// A task still running at the deadline, on `node`.
    TaskStillRunning { node: String, upid: String, minutes: u64 },
    /// The certificate to pin is not the one the server presented.
    CertNotPresented,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Error {
    pub kind: ErrorKind,
    /// The host's own words, or the transport's. Never a credential.
    pub message: Option<String>,
    pub detail: Option<Box<Detail>>,
    /// The certificate presented, for the two certificate kinds.
    pub cert: Option<Box<CertInfo>>,
    /// The fingerprint that was pinned, for [`ErrorKind::CertChanged`].
    pub previous_fingerprint: Option<String>,
    /// The HTTP status the host answered with, when it was one.
    pub status: Option<u16>,
}

impl Error {
    pub fn new(kind: ErrorKind) -> Self {
        Self { kind, message: None, detail: None, cert: None, previous_fingerprint: None, status: None }
    }

    pub fn msg(kind: ErrorKind, message: impl Into<String>) -> Self {
        Self { message: Some(message.into()), ..Self::new(kind) }
    }

    pub fn detail(kind: ErrorKind, detail: Detail) -> Self {
        Self { detail: Some(Box::new(detail)), ..Self::new(kind) }
    }

    pub(crate) fn with_status(mut self, status: u16) -> Self {
        self.status = Some(status);
        self
    }

    /// Needs the user's input before anything is retried; automatic
    /// refreshes stop on it rather than repeating the same refusal.
    pub fn needs_input(&self) -> bool {
        matches!(
            self.kind,
            ErrorKind::NeedTfa
                | ErrorKind::CertUnconfirmed
                | ErrorKind::CertChanged
                | ErrorKind::AuthFailed
                | ErrorKind::NotConfigured
        )
    }
}

impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:?}", self.kind)?;
        if let Some(m) = &self.message {
            write!(f, ": {m}")?;
        }
        if let Some(d) = &self.detail {
            write!(f, " ({d:?})")?;
        }
        Ok(())
    }
}

impl std::error::Error for Error {}

pub type Result<T> = std::result::Result<T, Error>;
