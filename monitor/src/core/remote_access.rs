//! Settings for the two WebSocket endpoints that reach the local sshd: the
//! app's SSH-over-HTTPS tunnel and the panel's in-browser terminal.
//!
//! Both are **off by default**. Turning them on is a decision about exposing
//! shell access through the panel's HTTP surface, so it has to be made
//! deliberately, in the config file — this section is intentionally absent
//! from `PUT /api/v1/settings`, which only requires the panel password.
//!
//! Two shapes live here:
//!
//! - [`RemoteAccessConfig`] is what `config.toml` holds. Capacity fields are
//!   `Option` so "unset" stays distinguishable from "set to something small".
//! - [`RemoteAccess`] is the runtime form, with every capacity resolved.
//!
//! Capacities are not constants because monitor runs on everything from a
//! 512 MiB VPS to a 256 GiB server, and any single number is simultaneously
//! wasteful on one and crippling on the other. Unset capacities are derived
//! from physical memory by [`RemoteAccessConfig::resolve`]; an explicit value
//! in the file always wins.

use std::time::Duration;

use serde::{Deserialize, Serialize};

use super::fs_roots::FsRoots;

/// Where both endpoints connect. Not client-selectable: the tunnel takes no
/// target parameter at all, which is what keeps it from being usable as an
/// SSRF pivot into the network the agent sits in. Reaching another host is
/// still possible and is the SSH layer's job — configure that host with a
/// jump server pointing at this one, so its sshd authorises the hop.
fn default_ssh_addr() -> String {
    "127.0.0.1:22".to_string()
}

/// How long a terminal session outlives the WebSocket that was driving it,
/// so a phone changing networks reattaches to the same shell instead of
/// losing it.
fn default_detached_timeout_secs() -> u64 {
    300
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteAccessConfig {
    #[serde(default = "default_ssh_addr")]
    pub ssh_addr: String,

    /// Whether to serve the **terminal** endpoint over a plaintext listener.
    ///
    /// Only the terminal: its opening frame carries an SSH password and
    /// everything after it is cleartext PTY traffic, so without TLS the
    /// credentials are on the wire. The tunnel is unaffected — what it
    /// carries is the SSH wire protocol itself, already end-to-end encrypted
    /// with the app verifying the host key, so a plaintext outer layer
    /// leaks traffic shape and nothing else.
    #[serde(default)]
    pub allow_insecure: bool,

    #[serde(default)]
    pub tunnel_enabled: bool,
    /// `None` = derive from physical memory.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub tunnel_max_conns: Option<usize>,

    #[serde(default)]
    pub terminal_enabled: bool,
    /// `None` = derive from physical memory.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub terminal_max_sessions: Option<usize>,
    /// Bytes of PTY output retained per session for reattach. `None` =
    /// derive from physical memory. Larger buffers mean longer outages can
    /// be recovered without clearing the screen — see the incremental replay
    /// in `api::ws::terminal`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub terminal_scrollback_bytes: Option<usize>,

    #[serde(default = "default_detached_timeout_secs")]
    pub terminal_detached_timeout_secs: u64,

    /// Open a shell straight from a panel login, with no SSH credentials.
    ///
    /// `None` follows the platform: on by default on Linux, off on macOS and
    /// Windows. A server is where an operator expects the panel to be the way
    /// in; a desktop is somewhere a shell appearing behind one password is a
    /// surprise.
    ///
    /// **This makes the panel password equivalent to a shell as whatever user
    /// the agent runs as.** That is the trade being made deliberately: the
    /// SSH path stays available alongside it for anyone who wants sshd's
    /// authentication, logging and second factor instead. `install.sh`
    /// installs a *user* service by default so that identity is an ordinary
    /// account rather than root.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub full_access: Option<bool>,

    /// Serve `/api/v1/fs/*`: list, read, write, rename, delete, chmod.
    ///
    /// Off by default, and config-file only, like everything else here. What
    /// makes it a separate switch from [`Self::full_access`] rather than part
    /// of it is [`Self::fs_roots`]: an API confined to `/srv/backups` is
    /// genuinely less than a shell, and a grant that could only be "all or
    /// nothing" would push people to the wider one.
    #[serde(default)]
    pub fs_enabled: bool,

    /// The directories the file API may reach. Required when
    /// [`Self::fs_enabled`] is on; an empty list serves nothing.
    ///
    /// `["/"]` is how "the whole machine" is said, and it is a real decision
    /// rather than a default: at that setting the panel password is worth a
    /// shell, because anyone who can write `~/.ssh/authorized_keys` has one.
    /// It is warned about at startup for the same reason `full_access` is.
    #[serde(default)]
    pub fs_roots: Vec<String>,

    /// Largest single file the API will accept on a write. `None` = derive
    /// from physical memory.
    ///
    /// A bound rather than none at all: the body is streamed to disk and never
    /// buffered whole, so this is about the disk rather than about memory —
    /// but an agent that will write an unbounded file on one authenticated
    /// request is a way to fill the disk it is supposed to be monitoring.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub fs_max_write_bytes: Option<u64>,
}

impl Default for RemoteAccessConfig {
    fn default() -> Self {
        Self {
            ssh_addr: default_ssh_addr(),
            allow_insecure: false,
            tunnel_enabled: false,
            tunnel_max_conns: None,
            terminal_enabled: false,
            terminal_max_sessions: None,
            terminal_scrollback_bytes: None,
            terminal_detached_timeout_secs: default_detached_timeout_secs(),
            full_access: None,
            fs_enabled: false,
            fs_roots: Vec::new(),
            fs_max_write_bytes: None,
        }
    }
}

/// Whether access without SSH is the right default for this platform.
///
/// Split out so the rule is stated once and can be asserted in a test on
/// every target, rather than being buried in a `cfg!` inside `resolve`.
pub const fn full_access_default() -> bool {
    cfg!(target_os = "linux")
}

/// Reads the `SBM_FULL_ACCESS` override.
///
/// Env beats the config file, matching how the rest of monitor's settings
/// behave for container deployments where editing a file is awkward.
fn full_access_from_env() -> Option<bool> {
    match std::env::var("SBM_FULL_ACCESS").ok()?.trim().to_ascii_lowercase().as_str() {
        "1" | "true" | "yes" | "on" => Some(true),
        "0" | "false" | "no" | "off" => Some(false),
        other => {
            tracing::warn!(
                "Ignoring SBM_FULL_ACCESS={other:?}: expected a boolean"
            );
            None
        }
    }
}

/// What physical memory to assume when the platform can't report it. Matches
/// the "2 GiB" column of the derivation table — deliberately conservative,
/// since guessing high on a small machine is the harmful direction.
const ASSUMED_MEMORY: u64 = 2 * 1024 * 1024 * 1024;

const MIN_SCROLLBACK: usize = 64 * 1024;
const MAX_SCROLLBACK: usize = 2 * 1024 * 1024;
const MIN_SLOTS: usize = 2;
const MAX_SLOTS: usize = 16;
const MIN_WRITE_BYTES: u64 = 64 * 1024 * 1024;
const MAX_WRITE_BYTES: u64 = 4 * 1024 * 1024 * 1024;

impl RemoteAccessConfig {
    /// Fills in every unset capacity from `total_memory` (bytes).
    ///
    /// Takes the memory as a parameter rather than reading the host, so the
    /// derivation is testable across machine sizes.
    pub fn resolve(&self, total_memory: Option<u64>) -> RemoteAccess {
        let mem = total_memory.unwrap_or(ASSUMED_MEMORY);

        // ~0.02% of RAM per session: 128 KiB at 512 MiB, 2 MiB from 8 GiB up.
        let scrollback = ((mem / 4096) as usize).clamp(MIN_SCROLLBACK, MAX_SCROLLBACK);
        // One slot per GiB. The floor keeps a tiny VPS usable (a single slot
        // would make reattach impossible — takeover needs the old session to
        // still exist while the new connection is being set up).
        let slots = ((mem / (1024 * 1024 * 1024)) as usize).clamp(MIN_SLOTS, MAX_SLOTS);

        RemoteAccess {
            ssh_addr: self.ssh_addr.clone(),
            allow_insecure: self.allow_insecure,
            tunnel_enabled: self.tunnel_enabled,
            tunnel_max_conns: self.tunnel_max_conns.filter(|&n| n > 0).unwrap_or(slots),
            terminal_enabled: self.terminal_enabled,
            terminal_max_sessions: self.terminal_max_sessions.filter(|&n| n > 0).unwrap_or(slots),
            terminal_scrollback_bytes: self
                .terminal_scrollback_bytes
                .filter(|&n| n > 0)
                .unwrap_or(scrollback),
            terminal_detached_timeout: Duration::from_secs(self.terminal_detached_timeout_secs),
            full_access: full_access_from_env()
                .or(self.full_access)
                .unwrap_or_else(full_access_default),
            fs_enabled: self.fs_enabled,
            fs_roots: FsRoots::resolve(&self.fs_roots),
            // A quarter of RAM, floored and capped: big enough for the config
            // files and archives people actually move, small enough that one
            // request cannot fill a small VPS's disk.
            fs_max_write_bytes: self
                .fs_max_write_bytes
                .filter(|&n| n > 0)
                .unwrap_or_else(|| (mem / 4).clamp(MIN_WRITE_BYTES, MAX_WRITE_BYTES)),
        }
    }
}

/// [`RemoteAccessConfig`] with every capacity resolved. Built once at startup
/// and shared through `AppState`.
#[derive(Debug, Clone)]
pub struct RemoteAccess {
    pub ssh_addr: String,
    pub allow_insecure: bool,
    pub tunnel_enabled: bool,
    pub tunnel_max_conns: usize,
    pub terminal_enabled: bool,
    pub terminal_max_sessions: usize,
    pub terminal_scrollback_bytes: usize,
    pub terminal_detached_timeout: Duration,
    /// See [`RemoteAccessConfig::full_access`].
    pub full_access: bool,
    pub fs_enabled: bool,
    /// Canonicalised at startup — see [`FsRoots`].
    pub fs_roots: FsRoots,
    pub fs_max_write_bytes: u64,
}

impl RemoteAccess {
    /// Whether anything here is switched on, i.e. whether the startup summary
    /// and the `ssh_addr` resolution check are worth running at all.
    pub fn any_enabled(&self) -> bool {
        self.tunnel_enabled || self.terminal_enabled || self.fs_available()
    }

    /// Whether the file API will answer.
    ///
    /// Enabled *and* pointed somewhere: switching it on without roots is a
    /// half-finished configuration, and serving the whole filesystem would be
    /// the worst possible reading of it.
    ///
    /// Not gated on transport security, unlike the terminal. What travels here
    /// is file contents, which are exactly as sensitive as the files — the
    /// terminal's extra check exists because its opening frame carries an SSH
    /// password, and this endpoint has no credential of its own to leak beyond
    /// the JWT every other endpoint already carries.
    pub fn fs_available(&self) -> bool {
        self.fs_enabled && !self.fs_roots.is_empty()
    }

    /// Whether the terminal may run given how the server is listening.
    ///
    /// See [`RemoteAccessConfig::allow_insecure`] for why only the terminal
    /// is gated on transport security.
    pub fn terminal_available(&self, tls_active: bool) -> bool {
        self.terminal_enabled && (tls_active || self.allow_insecure)
    }

    /// Whether a client may reach this machine without presenting SSH
    /// credentials — a shell, a command, a forwarded port.
    ///
    /// One answer for all of them. Anyone who can open a shell can run
    /// anything in it and connect anywhere from it, so granting the shell and
    /// withholding the rest withholds nothing; it only makes the app pretend.
    ///
    /// Gated on the terminal being available at all, so turning the terminal
    /// off can never leave a door open behind it.
    pub fn full_access_available(&self, tls_active: bool) -> bool {
        self.terminal_available(tls_active) && self.full_access
    }

    /// Logs the resolved limits once at startup.
    ///
    /// Worth the noise: the capacities are derived rather than written down
    /// anywhere, and "why did my sixth terminal get refused" should be
    /// answerable from the log instead of from this source file.
    pub fn log_summary(&self, tls_active: bool) {
        if !self.any_enabled() {
            return;
        }
        tracing::info!(
            "Remote access: tunnel={} (max {} conns), terminal={} (max {} sessions, {} KiB scrollback, {}s detached timeout), full_access={}, target={}",
            self.tunnel_enabled,
            self.tunnel_max_conns,
            self.terminal_enabled,
            self.terminal_max_sessions,
            self.terminal_scrollback_bytes / 1024,
            self.terminal_detached_timeout.as_secs(),
            self.full_access,
            self.ssh_addr,
        );
        if self.fs_available() {
            tracing::info!(
                "File API: roots={:?}, max write {} MiB",
                self.fs_roots.as_slice(),
                self.fs_max_write_bytes / (1024 * 1024),
            );
        }
        if self.terminal_enabled && self.full_access {
            tracing::warn!(
                "Access without SSH is on: anyone who can log into the panel gets a \
                 shell as {}, can run any command as that account, and can reach any \
                 address this machine can reach — with no SSH authentication in \
                 between. The panel password is the only thing in the way. Turn it \
                 off with remote_access.full_access = false or SBM_FULL_ACCESS=0.",
                whoami()
            );
        }
        if self.fs_enabled && self.fs_roots.is_empty() {
            tracing::warn!(
                "remote_access.fs_enabled is on but fs_roots names nothing usable, \
                 so the file API will refuse every request. Name the directories \
                 it may reach, e.g. fs_roots = [\"/srv/data\"]."
            );
        }
        if self.fs_available() && self.fs_roots.is_unrestricted() {
            tracing::warn!(
                "The file API is serving the whole filesystem. At that setting it is \
                 equivalent to a shell as {}: anyone who can log into the panel can \
                 read any file that account can read and write any file it can write, \
                 including ~/.ssh/authorized_keys. Narrow remote_access.fs_roots to \
                 the directories that actually need to be reachable.",
                whoami()
            );
        }
        if self.terminal_enabled && !tls_active {
            if self.allow_insecure {
                tracing::warn!(
                    "Terminal is enabled on a plaintext listener with allow_insecure=true: \
                     SSH credentials and all terminal output travel unencrypted"
                );
            } else {
                // Deliberately not "it will refuse connections": the check is
                // per request, and a loopback peer — this host's browser, or a
                // reverse proxy on the same machine — still counts as secure.
                // Saying otherwise sends someone testing locally hunting for a
                // problem that isn't there.
                tracing::warn!(
                    "Terminal is enabled without TLS: it will serve clients on loopback \
                     (including a same-host reverse proxy) but refuse anything arriving \
                     over the network; configure TLS or set remote_access.allow_insecure"
                );
            }
        }
        if self.tunnel_enabled && !tls_active {
            tracing::warn!(
                "Tunnel is enabled on a plaintext listener: the SSH stream inside stays \
                 end-to-end encrypted, but connection metadata is visible on the network"
            );
        }
    }
}

/// The account the agent runs as, for the warning above. Best effort: this is
/// diagnostic text, not something a decision hangs on.
fn whoami() -> String {
    std::env::var("USER")
        .or_else(|_| std::env::var("USERNAME"))
        .unwrap_or_else(|_| "the agent's user".to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    const GIB: u64 = 1024 * 1024 * 1024;

    fn resolved(mem: Option<u64>) -> RemoteAccess {
        RemoteAccessConfig::default().resolve(mem)
    }

    #[test]
    fn capacities_track_the_documented_table() {
        let table = [
            (512 * 1024 * 1024, 128 * 1024, 2),
            (2 * GIB, 512 * 1024, 2),
            (8 * GIB, 2 * 1024 * 1024, 8),
            (16 * GIB, 2 * 1024 * 1024, 16),
            (256 * GIB, 2 * 1024 * 1024, 16),
        ];
        for (mem, scrollback, slots) in table {
            let r = resolved(Some(mem));
            assert_eq!(r.terminal_scrollback_bytes, scrollback, "scrollback at {mem} bytes");
            assert_eq!(r.terminal_max_sessions, slots, "sessions at {mem} bytes");
            assert_eq!(r.tunnel_max_conns, slots, "tunnel conns at {mem} bytes");
        }
    }

    #[test]
    fn unknown_memory_falls_back_to_the_conservative_column() {
        assert_eq!(
            resolved(None).terminal_scrollback_bytes,
            resolved(Some(ASSUMED_MEMORY)).terminal_scrollback_bytes
        );
        assert_eq!(
            resolved(None).terminal_max_sessions,
            resolved(Some(ASSUMED_MEMORY)).terminal_max_sessions
        );
    }

    #[test]
    fn a_tiny_machine_still_gets_room_to_reattach() {
        // Takeover needs the old session to exist while the new connection is
        // set up, so one slot would make reconnecting impossible.
        assert!(resolved(Some(64 * 1024 * 1024)).terminal_max_sessions >= 2);
    }

    #[test]
    fn explicit_values_win_over_derivation() {
        let config = RemoteAccessConfig {
            terminal_max_sessions: Some(1),
            terminal_scrollback_bytes: Some(4096),
            tunnel_max_conns: Some(64),
            ..Default::default()
        };
        let r = config.resolve(Some(64 * GIB));
        assert_eq!(r.terminal_max_sessions, 1);
        assert_eq!(r.terminal_scrollback_bytes, 4096);
        assert_eq!(r.tunnel_max_conns, 64);
    }

    #[test]
    fn zero_is_treated_as_unset_rather_than_as_a_hard_disable() {
        // Disabling is what `*_enabled = false` is for; a zero capacity would
        // otherwise leave the feature on but every request refused.
        let config = RemoteAccessConfig {
            terminal_max_sessions: Some(0),
            ..Default::default()
        };
        assert_eq!(
            config.resolve(Some(8 * GIB)).terminal_max_sessions,
            resolved(Some(8 * GIB)).terminal_max_sessions
        );
    }

    #[test]
    fn everything_is_off_by_default() {
        let r = resolved(None);
        assert!(!r.tunnel_enabled);
        assert!(!r.terminal_enabled);
        assert!(!r.allow_insecure);
        assert!(!r.any_enabled());
    }

    #[test]
    fn terminal_needs_tls_unless_explicitly_allowed() {
        let enabled = RemoteAccessConfig {
            terminal_enabled: true,
            ..Default::default()
        }
        .resolve(None);
        assert!(enabled.terminal_available(true));
        assert!(!enabled.terminal_available(false));

        let insecure = RemoteAccessConfig {
            terminal_enabled: true,
            allow_insecure: true,
            ..Default::default()
        }
        .resolve(None);
        assert!(insecure.terminal_available(false));

        let disabled = resolved(None);
        assert!(!disabled.terminal_available(true));
    }

    #[test]
    fn an_empty_section_parses_to_the_defaults() {
        let parsed: RemoteAccessConfig = toml::from_str("").unwrap();
        assert_eq!(parsed.ssh_addr, default_ssh_addr());
        assert!(!parsed.tunnel_enabled);
        assert!(!parsed.terminal_enabled);
        assert_eq!(
            parsed.terminal_detached_timeout_secs,
            default_detached_timeout_secs()
        );
    }
}
