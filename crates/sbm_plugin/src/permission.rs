//! What a plugin asked for, and what that lets it reach.
//!
//! PLUGINS.md section 6. Everything decidable at link time is decided there:
//! a host function the manifest did not ask for is not a check inside a working
//! implementation, it is a different function — one that traps.

use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

/// The permission list. Section 6.1.
///
/// Serialized by name and stored that way (`plugin_install.granted`), so the
/// order of this enum carries no meaning and a case may be inserted anywhere.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Permission {
    /// Execute a command on the server a host-issued handle points at.
    #[serde(rename = "server.exec")]
    ServerExec,

    /// Open a TCP connection through that server's SSH connection.
    #[serde(rename = "server.stream")]
    ServerStream,

    /// Enumerate the user's servers, as handles and display names.
    ///
    /// Separate from [`ServerExec`](Self::ServerExec), and strictly more:
    /// exec acts on a server the *user* pointed at — the one a surface is
    /// bound to, or one picked in `sb.ui.pickServer` — while this hands over
    /// the whole list without anybody choosing. What a fleet-wide surface
    /// needs, and what a plugin that only draws a card for the machine in
    /// front of you must not have.
    ///
    /// Names and handles only. An address, a user name and a credential are
    /// not in it, and no permission grants them.
    #[serde(rename = "server.list")]
    ServerList,

    /// Reach an address directly over HTTP. Scoped by [`Grants::http_patterns`].
    #[serde(rename = "net.http")]
    NetHttp,

    /// Raise a dialog and wait for an answer.
    #[serde(rename = "ui.dialog")]
    UiDialog,

    /// Read and write the system clipboard.
    #[serde(rename = "clipboard")]
    Clipboard,

    /// Let this plugin's key-value namespace take part in backup sync.
    ///
    /// Unlike the others this grants no host function — it is read by the
    /// storage layer, and appears here because it is a thing the user consents
    /// to at install time.
    #[serde(rename = "storage.sync")]
    StorageSync,
}

impl Permission {
    /// The name in a manifest and in `plugin_install.granted`.
    pub const fn name(self) -> &'static str {
        match self {
            Self::ServerExec => "server.exec",
            Self::ServerStream => "server.stream",
            Self::ServerList => "server.list",
            Self::NetHttp => "net.http",
            Self::UiDialog => "ui.dialog",
            Self::Clipboard => "clipboard",
            Self::StorageSync => "storage.sync",
        }
    }

    pub const ALL: &'static [Permission] = &[
        Self::ServerExec,
        Self::ServerStream,
        Self::ServerList,
        Self::NetHttp,
        Self::UiDialog,
        Self::Clipboard,
        Self::StorageSync,
    ];

    pub fn parse(s: &str) -> Option<Self> {
        Self::ALL.iter().copied().find(|p| p.name() == s)
    }
}

/// What the user agreed to, resolved against what the manifest asked for.
///
/// Built by the host from `plugin_install.granted`, never from the manifest
/// alone: a manifest is what the plugin wants, and an update that adds a
/// permission must not start using it before the user has seen it.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct Grants {
    granted: BTreeSet<Permission>,
    /// Host patterns `http.request` may reach, from `net.http: [...]`.
    ///
    /// Empty with [`Permission::NetHttp`] granted means the plugin declared the
    /// permission and named nothing — which reaches nothing. A plugin that
    /// wants everything says so with `*`.
    http_patterns: Vec<HostPattern>,
}

impl Grants {
    pub fn new(granted: impl IntoIterator<Item = Permission>) -> Self {
        Self { granted: granted.into_iter().collect(), http_patterns: Vec::new() }
    }

    pub fn with_http_patterns(mut self, patterns: impl IntoIterator<Item = String>) -> Self {
        self.http_patterns = patterns.into_iter().map(HostPattern::new).collect();
        self
    }

    pub fn allows(&self, permission: Permission) -> bool {
        self.granted.contains(&permission)
    }

    pub fn granted(&self) -> impl Iterator<Item = Permission> + '_ {
        self.granted.iter().copied()
    }

    pub fn http_patterns(&self) -> &[HostPattern] {
        &self.http_patterns
    }

    /// Whether `url` is inside the `net.http` grant.
    ///
    /// Scheme and host are compared; a port narrows the pattern when it names
    /// one and is ignored when it does not, because most of these addresses are
    /// typed by the user into a config field and a BMC on 8443 is the same
    /// device as one on 443.
    pub fn allows_url(&self, url: &str) -> bool {
        if !self.allows(Permission::NetHttp) {
            return false;
        }
        let Some(target) = UrlTarget::parse(url) else { return false };
        self.http_patterns.iter().any(|p| p.matches(&target))
    }
}

/// One entry of `net.http`.
///
/// Three forms, all of them a host and optionally a port:
/// - `*` — anything. The plugin is saying it is a general HTTP client.
/// - `*.example.com` — that domain and its subdomains.
/// - `10.0.0.9:8443` — one address.
///
/// A `$config.<key>` entry from the manifest is **not** a pattern: the host
/// resolves it against the bound server's config before building [`Grants`],
/// so what arrives here is always a literal. See `Manifest::resolve_http`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HostPattern {
    host: String,
    port: Option<u16>,
}

impl HostPattern {
    pub fn new(raw: impl AsRef<str>) -> Self {
        let raw = raw.as_ref().trim();
        // Anything with a scheme is reduced to its authority: a pattern is
        // about which machine, and the scheme is decided by the request.
        let rest = raw.split_once("://").map(|(_, r)| r).unwrap_or(raw);
        let rest = rest.split('/').next().unwrap_or(rest);
        match split_host_port(rest) {
            (host, port) => Self { host: host.to_ascii_lowercase(), port },
        }
    }

    fn matches(&self, target: &UrlTarget) -> bool {
        if let Some(port) = self.port {
            if port != target.port {
                return false;
            }
        }
        if self.host == "*" {
            return true;
        }
        if let Some(suffix) = self.host.strip_prefix("*.") {
            return target.host == suffix || target.host.ends_with(&format!(".{suffix}"));
        }
        self.host == target.host
    }
}

#[derive(Debug)]
struct UrlTarget {
    host: String,
    port: u16,
}

impl UrlTarget {
    fn parse(url: &str) -> Option<Self> {
        let (scheme, rest) = url.split_once("://")?;
        let default_port = match scheme.to_ascii_lowercase().as_str() {
            "https" => 443,
            "http" => 80,
            _ => return None,
        };
        let authority = rest.split(['/', '?', '#']).next()?;
        // Credentials in a URL are not a host. Refused rather than stripped:
        // `https://evil.com@10.0.0.9/` is a shape whose only use here is
        // getting past a pattern.
        if authority.contains('@') {
            return None;
        }
        let (host, port) = split_host_port(authority);
        if host.is_empty() || host == "*" {
            return None;
        }
        Some(Self { host: host.to_ascii_lowercase(), port: port.unwrap_or(default_port) })
    }
}

/// Splits `host:port`, leaving a bracketed IPv6 literal intact.
fn split_host_port(s: &str) -> (&str, Option<u16>) {
    if let Some(rest) = s.strip_prefix('[') {
        return match rest.split_once(']') {
            Some((host, after)) => (host, after.strip_prefix(':').and_then(|p| p.parse().ok())),
            None => (s, None),
        };
    }
    match s.rsplit_once(':') {
        Some((host, port)) => match port.parse() {
            Ok(port) => (host, Some(port)),
            // Not a port, so the colon was part of a bare IPv6 literal.
            Err(_) => (s, None),
        },
        None => (s, None),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn grants(patterns: &[&str]) -> Grants {
        Grants::new([Permission::NetHttp])
            .with_http_patterns(patterns.iter().map(|s| s.to_string()))
    }

    #[test]
    fn wildcard_matches_anything() {
        let g = grants(&["*"]);
        assert!(g.allows_url("https://example.com/redfish/v1/"));
        assert!(g.allows_url("http://10.0.0.9:8443/"));
    }

    #[test]
    fn no_pattern_reaches_nothing() {
        let g = grants(&[]);
        assert!(!g.allows_url("https://example.com/"));
    }

    #[test]
    fn without_the_permission_no_pattern_helps() {
        let g = Grants::default().with_http_patterns(["*".to_string()]);
        assert!(!g.allows_url("https://example.com/"));
    }

    #[test]
    fn subdomain_wildcard_does_not_match_a_suffix_of_a_label() {
        let g = grants(&["*.example.com"]);
        assert!(g.allows_url("https://bmc.example.com/"));
        assert!(g.allows_url("https://example.com/"));
        assert!(!g.allows_url("https://notexample.com/"));
        assert!(!g.allows_url("https://example.com.evil.net/"));
    }

    #[test]
    fn a_named_port_narrows_and_an_unnamed_one_does_not() {
        assert!(grants(&["10.0.0.9:8443"]).allows_url("https://10.0.0.9:8443/"));
        assert!(!grants(&["10.0.0.9:8443"]).allows_url("https://10.0.0.9/"));
        assert!(grants(&["10.0.0.9"]).allows_url("https://10.0.0.9:8443/"));
    }

    #[test]
    fn scheme_and_path_in_a_pattern_are_reduced_to_the_authority() {
        let g = grants(&["https://10.0.0.9/redfish/v1/"]);
        assert!(g.allows_url("https://10.0.0.9/redfish/v1/Systems"));
        assert!(g.allows_url("http://10.0.0.9/anything"));
    }

    #[test]
    fn userinfo_is_refused_rather_than_stripped() {
        let g = grants(&["10.0.0.9"]);
        assert!(!g.allows_url("https://10.0.0.9@evil.com/"));
        assert!(!g.allows_url("https://evil.com@10.0.0.9/"));
    }

    #[test]
    fn ipv6_literals_keep_their_colons() {
        let g = grants(&["[fd00::1]:8443"]);
        assert!(g.allows_url("https://[fd00::1]:8443/redfish/v1/"));
        assert!(!g.allows_url("https://[fd00::1]/redfish/v1/"));
        assert!(grants(&["[fd00::1]"]).allows_url("https://[fd00::1]/"));
    }

    #[test]
    fn only_http_schemes() {
        let g = grants(&["*"]);
        assert!(!g.allows_url("file:///etc/passwd"));
        assert!(!g.allows_url("ftp://example.com/"));
        assert!(!g.allows_url("not a url"));
    }

    #[test]
    fn host_comparison_is_case_insensitive() {
        assert!(grants(&["BMC.Example.COM"]).allows_url("https://bmc.example.com/"));
    }

    #[test]
    fn permission_names_round_trip() {
        for p in Permission::ALL {
            assert_eq!(Permission::parse(p.name()), Some(*p));
            let json = serde_json::to_string(p).unwrap();
            assert_eq!(json, format!("\"{}\"", p.name()));
        }
    }
}
