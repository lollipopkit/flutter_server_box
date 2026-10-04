//! Proxmox VE through its HTTP API (`/api2/json`).
//!
//! [`Client`] holds one host's session — login, TOTP, ticket renewal,
//! certificate pinning — and answers in [`crate::model`] terms. The agent
//! uses it directly; the app through FFI, over a byte stream of its own
//! ([`http::LoopbackDial`]). Ported from the app's `PveBackend`.

pub mod client;
pub mod create;
pub mod http;
pub mod net;
pub mod resources;
pub mod termproxy;

pub use client::{Client, Clock, Options, SystemClock};
/// The websocket types a console's socket ([`client::ConsoleSocket`]) carries.
pub use tokio_tungstenite::tungstenite;

use crate::error::{Detail, Error, ErrorKind};

/// How the client logs in.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Auth {
    /// `POST /access/ticket` for `user` (`name` in the PAM realm, or
    /// `name@realm`); a TOTP code when the account has one.
    Password { user: String, password: String },
    /// `Authorization: PVEAPIToken=<id>=<secret>`. No ticket, no CSRF token,
    /// no TOTP; the permissions are the token's. `id` is
    /// `user@realm!tokenid`.
    Token { id: String, secret: String },
}

/// One host's configuration.
#[derive(Clone, PartialEq, Eq)]
pub struct Config {
    /// The API's base URL, e.g. `https://127.0.0.1:8006`, resolved on the far
    /// end of the byte stream.
    pub addr: String,
    pub auth: Auth,
    /// SHA-256 of the DER certificate confirmed, lowercase hex. None: none
    /// has been, and a certificate no CA vouches for is shown for review.
    pub cert_sha256: Option<String>,
}

/// No secret in it: this reaches logs.
impl std::fmt::Debug for Config {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let auth = match &self.auth {
            Auth::Password { user, .. } => format!("password({user})"),
            Auth::Token { id, .. } => format!("token({id})"),
        };
        f.debug_struct("Config")
            .field("addr", &self.addr)
            .field("auth", &auth)
            .field("pinned", &self.cert_sha256.is_some())
            .finish()
    }
}

impl Config {
    /// The API on the server itself, through whichever stream reaches it.
    pub const LOCAL_ADDR: &str = "https://127.0.0.1:8006";

    /// [`Config::addr`] as a URI with no path: scheme and authority.
    pub fn base_uri(&self) -> Result<hyper::Uri, Error> {
        let addr = self.addr.trim().trim_end_matches('/');
        let invalid = || Error::msg(ErrorKind::NotConfigured, format!("not an http(s) address: {addr}"));
        let uri: hyper::Uri = addr.parse().map_err(|_| invalid())?;
        match (uri.scheme_str(), uri.authority()) {
            (Some("https" | "http"), Some(authority)) => {
                format!("{}://{}", uri.scheme_str().unwrap(), authority).parse().map_err(|_| invalid())
            }
            _ => Err(invalid()),
        }
    }

    /// The account in the form `pveum` names it: the token id, or the user
    /// with its realm.
    pub(crate) fn account(&self) -> (bool, String) {
        match &self.auth {
            Auth::Token { id, .. } => (true, id.clone()),
            Auth::Password { user, .. } => {
                let user = user.trim();
                (false, if user.contains('@') { user.to_owned() } else { format!("{user}@pam") })
            }
        }
    }

    pub(crate) fn check(&self) -> Result<(), Error> {
        match &self.auth {
            Auth::Token { id, secret } if id.trim().is_empty() || secret.is_empty() => {
                Err(Error::detail(ErrorKind::NotConfigured, Detail::TokenIncomplete))
            }
            Auth::Password { user, .. } if user.trim().is_empty() => {
                Err(Error::detail(ErrorKind::NotConfigured, Detail::NoUser))
            }
            Auth::Password { password, .. } if password.is_empty() => {
                Err(Error::detail(ErrorKind::NotConfigured, Detail::PasswordRequired))
            }
            _ => Ok(()),
        }
    }
}

/// `raw`'s leading `major[.minor[.patch]]`, as the app's `parseVersionParts`.
fn version_parts(raw: &str) -> Option<[u32; 3]> {
    let start = raw.find(|c: char| c.is_ascii_digit())?;
    let mut parts = [0u32; 3];
    let mut rest = &raw[start..];
    for (i, part) in parts.iter_mut().enumerate() {
        let len = rest.find(|c: char| !c.is_ascii_digit()).unwrap_or(rest.len());
        if len == 0 {
            break;
        }
        *part = rest[..len].parse().ok()?;
        rest = &rest[len..];
        if i < 2 {
            match rest.strip_prefix('.') {
                Some(r) if r.starts_with(|c: char| c.is_ascii_digit()) => rest = r,
                _ => break,
            }
        }
    }
    Some(parts)
}

/// Whether `raw` is older than `minimum`; false for a version that cannot be
/// read, which says nothing either way.
pub fn version_less_than(raw: &str, minimum: &[u32]) -> bool {
    let Some(v) = version_parts(raw) else { return false };
    for (i, min) in minimum.iter().enumerate() {
        let cur = v.get(i).copied().unwrap_or(0);
        if cur != *min {
            return cur < *min;
        }
    }
    false
}

/// `Uri.encodeComponent`: everything but `A-Za-z0-9-_.!~*'()` percent-encoded.
pub(crate) fn seg(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for b in s.bytes() {
        if b.is_ascii_alphanumeric() || b"-_.!~*'()".contains(&b) {
            out.push(b as char);
        } else {
            out.push_str(&format!("%{b:02X}"));
        }
    }
    out
}

/// `application/x-www-form-urlencoded`, spaces as `+`.
pub(crate) fn form(pairs: &[(&str, &str)]) -> String {
    let enc = |s: &str| {
        let mut out = String::with_capacity(s.len());
        for b in s.bytes() {
            match b {
                b' ' => out.push('+'),
                b if b.is_ascii_alphanumeric() || b"*-._".contains(&b) => out.push(b as char),
                b => out.push_str(&format!("%{b:02X}")),
            }
        }
        out
    };
    pairs.iter().map(|(k, v)| format!("{}={}", enc(k), enc(v))).collect::<Vec<_>>().join("&")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn versions() {
        assert!(!version_less_than("9.2.2", &[8, 1]));
        assert!(!version_less_than("8.1.3", &[8, 1]));
        assert!(version_less_than("8.0.4", &[8, 1]));
        assert!(version_less_than("7.4-3", &[8, 1]));
        assert!(!version_less_than("pve-manager", &[8, 1]), "unreadable says nothing");
        assert_eq!(version_parts("pve-manager/8.2.4/faa83925c9641325"), Some([8, 2, 4]));
    }

    #[test]
    fn encodings() {
        assert_eq!(seg("UPID:pve:00001:x:"), "UPID%3Apve%3A00001%3Ax%3A");
        assert_eq!(form(&[("password", " pw "), ("otp", "totp:1")]), "password=+pw+&otp=totp%3A1");
    }

    #[test]
    fn addresses() {
        let cfg = |addr: &str| Config {
            addr: addr.into(),
            auth: Auth::Token { id: "a@pam!t".into(), secret: "s3cret".into() },
            cert_sha256: None,
        };
        assert_eq!(cfg("https://pve.lan:8006/").base_uri().unwrap().to_string(), "https://pve.lan:8006/");
        assert_eq!(cfg(" https://[::1]:8006 ").base_uri().unwrap().to_string(), "https://[::1]:8006/");
        assert!(cfg("pve.lan:8006").base_uri().is_err());
        assert!(!format!("{:?}", cfg("https://h")).contains("s3cret"), "no secret in Debug");
    }
}
