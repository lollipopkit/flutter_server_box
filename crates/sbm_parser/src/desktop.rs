//! What a saved remote desktop route may hold: the rules the app's profile
//! editor (through `sbm_ffi::api::desktop`) and the agent's `/desktops`
//! endpoint both apply, so a route one accepts the other does too.
//!
//! Ported from the app's `validateRemoteDesktopProfileInput`
//! (`lib/view/page/remote_desktop/profile_edit.dart`) and the agent's own
//! row checks, which had drifted apart: the app did not bound a name or look
//! inside a host, and the agent did not require an RDP user name.

use serde::Deserialize;

/// The protocols a route may name, and the port each gets by default.
pub const PROTOCOLS: [(&str, u16); 2] = [("vnc", 5900), ("rdp", 3389)];

/// A name is a row's label and a subject in the agent's audit log.
pub const MAX_NAME: usize = 64;
/// A DNS name's own limit.
pub const MAX_HOST: usize = 253;
/// A user name or a domain.
pub const MAX_IDENT: usize = 256;
/// Classic VNC authentication is DES keyed by the first eight bytes.
pub const MAX_VNC_PASSWORD: usize = 8;

/// The fields of a route that have rules. The port is an `i64` so a form can
/// pass what was typed, out of range included, and be told so.
#[derive(Debug, Clone, Deserialize)]
pub struct ProfileInput {
    pub name: String,
    pub protocol: String,
    pub host: String,
    pub port: Option<i64>,
    #[serde(default)]
    pub username: Option<String>,
    #[serde(default)]
    pub domain: Option<String>,
}

/// Why a route cannot be saved. A stable code for each client to phrase.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProfileError {
    NameRequired,
    /// Longer than [`MAX_NAME`] or holding a control character.
    InvalidName,
    /// Not one of [`PROTOCOLS`].
    InvalidProtocol,
    HostRequired,
    /// Longer than [`MAX_HOST`], or holding whitespace or a control
    /// character: the agent dials it, so it has to be something that could be
    /// an address.
    InvalidHost,
    /// Missing, or outside 1–65535.
    InvalidPort,
    /// RDP signs in, so a route without a user name cannot open a session.
    UsernameRequired,
    /// A user name or domain longer than [`MAX_IDENT`] or holding a control
    /// character.
    InvalidCredential,
}

impl ProfileError {
    pub fn as_str(self) -> &'static str {
        match self {
            ProfileError::NameRequired => "nameRequired",
            ProfileError::InvalidName => "invalidName",
            ProfileError::InvalidProtocol => "invalidProtocol",
            ProfileError::HostRequired => "hostRequired",
            ProfileError::InvalidHost => "invalidHost",
            ProfileError::InvalidPort => "invalidPort",
            ProfileError::UsernameRequired => "usernameRequired",
            ProfileError::InvalidCredential => "invalidCredential",
        }
    }
}

/// Why a classic VNC password would not work.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VncPasswordError {
    TooLong,
    NotAscii,
}

impl VncPasswordError {
    pub fn as_str(self) -> &'static str {
        match self {
            VncPasswordError::TooLong => "vncPasswordLength",
            VncPasswordError::NotAscii => "vncPasswordAscii",
        }
    }
}

pub fn default_port(protocol: &str) -> Option<u16> {
    PROTOCOLS
        .iter()
        .find(|(id, _)| *id == protocol)
        .map(|(_, port)| *port)
}

fn has_control(value: &str) -> bool {
    value.chars().any(char::is_control)
}

/// The first problem with a route, in the order a form lays its fields out.
/// Whitespace around a value is the form's to trim; a name or host that is
/// only whitespace is empty.
pub fn validate_profile(input: &ProfileInput) -> Result<(), ProfileError> {
    let name = input.name.trim();
    if name.is_empty() {
        return Err(ProfileError::NameRequired);
    }
    if name.chars().count() > MAX_NAME || has_control(name) {
        return Err(ProfileError::InvalidName);
    }
    if default_port(&input.protocol).is_none() {
        return Err(ProfileError::InvalidProtocol);
    }
    let host = input.host.trim();
    if host.is_empty() {
        return Err(ProfileError::HostRequired);
    }
    if host.len() > MAX_HOST || host.chars().any(|c| c.is_whitespace() || c.is_control()) {
        return Err(ProfileError::InvalidHost);
    }
    if !matches!(input.port, Some(1..=65535)) {
        return Err(ProfileError::InvalidPort);
    }
    let username = input.username.as_deref().map(str::trim).unwrap_or("");
    if input.protocol == "rdp" && username.is_empty() {
        return Err(ProfileError::UsernameRequired);
    }
    for value in [input.username.as_deref(), input.domain.as_deref()].into_iter().flatten() {
        if value.chars().count() > MAX_IDENT || has_control(value) {
            return Err(ProfileError::InvalidCredential);
        }
    }
    Ok(())
}

/// Classic VNC authentication: at most eight bytes, ASCII only. Counted in
/// UTF-16 units first, as the Dart editor did, so a long non-ASCII password
/// is reported as too long rather than as non-ASCII.
pub fn validate_vnc_password(password: &str) -> Result<(), VncPasswordError> {
    if password.encode_utf16().count() > MAX_VNC_PASSWORD {
        return Err(VncPasswordError::TooLong);
    }
    if !password.is_ascii() {
        return Err(VncPasswordError::NotAscii);
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn route(protocol: &str) -> ProfileInput {
        ProfileInput {
            name: "Desktop".into(),
            protocol: protocol.into(),
            host: "127.0.0.1".into(),
            port: default_port(protocol).map(i64::from),
            username: Some("lk".into()),
            domain: None,
        }
    }

    #[test]
    fn a_well_formed_route_is_accepted() {
        assert_eq!(validate_profile(&route("vnc")), Ok(()));
        assert_eq!(validate_profile(&route("rdp")), Ok(()));
        // VNC signs in with a password alone.
        assert_eq!(validate_profile(&ProfileInput { username: None, ..route("vnc") }), Ok(()));
    }

    #[test]
    fn each_field_is_refused_with_its_own_code() {
        let cases = [
            (ProfileInput { name: "  ".into(), ..route("vnc") }, ProfileError::NameRequired),
            (ProfileInput { name: "n".repeat(MAX_NAME + 1), ..route("vnc") }, ProfileError::InvalidName),
            (ProfileInput { name: "a\nb".into(), ..route("vnc") }, ProfileError::InvalidName),
            (ProfileInput { protocol: "spice".into(), ..route("vnc") }, ProfileError::InvalidProtocol),
            (ProfileInput { host: " ".into(), ..route("vnc") }, ProfileError::HostRequired),
            (ProfileInput { host: "a b".into(), ..route("vnc") }, ProfileError::InvalidHost),
            (ProfileInput { host: "h".repeat(MAX_HOST + 1), ..route("vnc") }, ProfileError::InvalidHost),
            (ProfileInput { port: None, ..route("vnc") }, ProfileError::InvalidPort),
            (ProfileInput { port: Some(0), ..route("vnc") }, ProfileError::InvalidPort),
            (ProfileInput { port: Some(65536), ..route("vnc") }, ProfileError::InvalidPort),
            (ProfileInput { username: Some(" ".into()), ..route("rdp") }, ProfileError::UsernameRequired),
            (ProfileInput { username: None, ..route("rdp") }, ProfileError::UsernameRequired),
            (ProfileInput { domain: Some("a\tb".into()), ..route("rdp") }, ProfileError::InvalidCredential),
        ];
        for (input, error) in cases {
            assert_eq!(validate_profile(&input), Err(error), "{input:?}");
        }
    }

    #[test]
    fn the_codes_are_the_ones_clients_phrase() {
        assert_eq!(ProfileError::UsernameRequired.as_str(), "usernameRequired");
        assert_eq!(VncPasswordError::TooLong.as_str(), "vncPasswordLength");
    }
}
