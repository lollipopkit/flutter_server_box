//! Settings for the panel's WebSocket terminal and the app's file API.
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

/// The SSH server the panel's terminal connects to.
fn default_ssh_addr() -> String {
    "127.0.0.1:22".to_string()
}

/// How long a terminal session outlives the WebSocket that was driving it,
/// so a phone changing networks reattaches to the same shell instead of
/// losing it.
fn default_detached_timeout_secs() -> u64 {
    300
}

/// `[remote_access]` — what the section holds itself, plus one subsection per
/// endpoint.
///
/// Grouped by the endpoint a setting acts on rather than by a shared name
/// prefix: `allow_insecure` lives under `terminal` because the terminal is the
/// only thing it has ever gated, and a reader should not have to find that out
/// from a doc comment. What stays at this level is what more than one endpoint
/// reads.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RemoteAccessConfig {
    #[serde(default = "default_ssh_addr")]
    pub ssh_addr: String,

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
    ///
    /// At this level rather than under `terminal`: it also gates `POST
    /// /api/v1/exec`, so scoping it to one endpoint would misname it.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub full_access: Option<bool>,

    #[serde(default)]
    pub terminal: TerminalConfig,

    #[serde(default)]
    pub fs: FsConfig,
}

/// Hand-written rather than derived: `ssh_addr` has a default that is not the
/// empty string, and deriving it would point every unconfigured agent at
/// nothing.
impl Default for RemoteAccessConfig {
    fn default() -> Self {
        Self {
            ssh_addr: default_ssh_addr(),
            full_access: None,
            terminal: TerminalConfig::default(),
            fs: FsConfig::default(),
        }
    }
}

/// `[remote_access.terminal]` — the panel's in-browser terminal.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalConfig {
    #[serde(default)]
    pub enabled: bool,

    /// `None` = derive from physical memory.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max_sessions: Option<usize>,

    /// Bytes of PTY output retained per session for reattach. `None` =
    /// derive from physical memory. Larger buffers mean longer outages can
    /// be recovered without clearing the screen — see the incremental replay
    /// in `api::ws::terminal`.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub scrollback_bytes: Option<usize>,

    #[serde(default = "default_detached_timeout_secs")]
    pub detached_timeout_secs: u64,

    /// Whether to serve this endpoint over a plaintext listener.
    ///
    /// Its opening frame carries an SSH password and everything after it is
    /// cleartext PTY traffic, so without TLS the credentials are on the wire.
    #[serde(default)]
    pub allow_insecure: bool,
}

impl Default for TerminalConfig {
    fn default() -> Self {
        Self {
            enabled: false,
            max_sessions: None,
            scrollback_bytes: None,
            detached_timeout_secs: default_detached_timeout_secs(),
            allow_insecure: false,
        }
    }
}

/// `[remote_access.fs]` — the app's file browser, `/api/v1/fs/*`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct FsConfig {
    /// Serve `/api/v1/fs/*`: list, read, write, rename, delete, chmod.
    ///
    /// Off by default, and config-file only, like everything else here. What
    /// makes it a separate switch from [`RemoteAccessConfig::full_access`]
    /// rather than part of it is [`Self::roots`]: an API confined to
    /// `/srv/backups` is genuinely less than a shell, and a grant that could
    /// only be "all or nothing" would push people to the wider one.
    #[serde(default)]
    pub enabled: bool,

    /// The directories the file API may reach. Required when [`Self::enabled`]
    /// is on; an empty list serves nothing.
    ///
    /// `["/"]` is how "the whole machine" is said, and it is a real decision
    /// rather than a default: at that setting the panel password is worth a
    /// shell, because anyone who can write `~/.ssh/authorized_keys` has one.
    /// It is warned about at startup for the same reason `full_access` is.
    #[serde(default)]
    pub roots: Vec<String>,

    /// Serve files to callers outside loopback without TLS.
    ///
    /// A private source address does not prove a path is encrypted, so this is
    /// off by default and only an operator editing the agent config can enable
    /// it. The app has a second per-server opt-in before it will send HTTP.
    #[serde(default)]
    pub allow_insecure: bool,

    /// Largest single file the API will accept on a write. `None` = derive
    /// from physical memory.
    ///
    /// A bound rather than none at all: the body is streamed to disk and never
    /// buffered whole, so this is about the disk rather than about memory —
    /// but an agent that will write an unbounded file on one authenticated
    /// request is a way to fill the disk it is supposed to be monitoring.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max_write_bytes: Option<u64>,
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
            full_access: full_access_from_env()
                .or(self.full_access)
                .unwrap_or_else(full_access_default),
            terminal: Terminal {
                enabled: self.terminal.enabled,
                max_sessions: self.terminal.max_sessions.filter(|&n| n > 0).unwrap_or(slots),
                scrollback_bytes: self
                    .terminal
                    .scrollback_bytes
                    .filter(|&n| n > 0)
                    .unwrap_or(scrollback),
                detached_timeout: Duration::from_secs(self.terminal.detached_timeout_secs),
                allow_insecure: self.terminal.allow_insecure,
            },
            fs: Fs {
                enabled: self.fs.enabled,
                roots: FsRoots::resolve(&self.fs.roots),
                allow_insecure: self.fs.allow_insecure,
                // A quarter of RAM, floored and capped: big enough for the
                // config files and archives people actually move, small enough
                // that one request cannot fill a small VPS's disk.
                max_write_bytes: self
                    .fs
                    .max_write_bytes
                    .filter(|&n| n > 0)
                    .unwrap_or_else(|| (mem / 4).clamp(MIN_WRITE_BYTES, MAX_WRITE_BYTES)),
            },
        }
    }
}

/// [`RemoteAccessConfig`] with every capacity resolved. Built once at startup
/// and shared through `AppState`. Mirrors the config's shape, so a reader who
/// knows the file knows this.
#[derive(Debug, Clone)]
pub struct RemoteAccess {
    pub ssh_addr: String,
    /// See [`RemoteAccessConfig::full_access`].
    pub full_access: bool,
    pub terminal: Terminal,
    pub fs: Fs,
}

/// Resolved [`TerminalConfig`].
#[derive(Debug, Clone)]
pub struct Terminal {
    pub enabled: bool,
    pub max_sessions: usize,
    pub scrollback_bytes: usize,
    pub detached_timeout: Duration,
    pub allow_insecure: bool,
}

impl Terminal {
    /// Whether the terminal may run given how the server is listening.
    ///
    /// See [`TerminalConfig::allow_insecure`] for why only the terminal is
    /// gated on transport security.
    pub fn available(&self, tls_active: bool) -> bool {
        self.enabled && (tls_active || self.allow_insecure)
    }
}

/// Resolved [`FsConfig`].
#[derive(Debug, Clone)]
pub struct Fs {
    pub enabled: bool,
    /// Canonicalised at startup — see [`FsRoots`].
    pub roots: FsRoots,
    pub allow_insecure: bool,
    pub max_write_bytes: u64,
}

impl Fs {
    /// Whether the file API will answer.
    ///
    /// Enabled *and* pointed somewhere: switching it on without roots is a
    /// half-finished configuration, and serving the whole filesystem would be
    /// the worst possible reading of it.
    ///
    /// File contents and the bearer token are both sensitive, so a direct
    /// network request needs TLS unless the operator explicitly allows
    /// plaintext. A local caller or same-host reverse proxy is safe for the
    /// same reason as the terminal path (see `api::ws`).
    pub fn available(&self, secure: bool) -> bool {
        self.enabled && !self.roots.is_empty() && (secure || self.allow_insecure)
    }
}

impl RemoteAccess {
    /// Whether anything here is switched on, i.e. whether the startup summary
    /// and the `ssh_addr` resolution check are worth running at all.
    pub fn any_enabled(&self) -> bool {
        self.terminal.enabled || self.fs.enabled && !self.fs.roots.is_empty()
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
        self.terminal.available(tls_active) && self.full_access
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
            "Remote access: terminal={} (max {} sessions, {} KiB scrollback, {}s detached timeout), full_access={}, target={}",
            self.terminal.enabled,
            self.terminal.max_sessions,
            self.terminal.scrollback_bytes / 1024,
            self.terminal.detached_timeout.as_secs(),
            self.full_access,
            self.ssh_addr,
        );
        if self.fs.available(tls_active) {
            tracing::info!(
                "File API: roots={:?}, max write {} MiB",
                self.fs.roots.as_slice(),
                self.fs.max_write_bytes / (1024 * 1024),
            );
        }
        if self.terminal.enabled && self.full_access {
            tracing::warn!(
                "Access without SSH is on: anyone who can log into the panel gets a \
                 shell as {}, can run any command as that account, and can reach any \
                 address this machine can reach — with no SSH authentication in \
                 between. The panel password is the only thing in the way. Turn it \
                 off with remote_access.full_access = false or SBM_FULL_ACCESS=0.",
                whoami()
            );
        }
        if self.fs.enabled && self.fs.roots.is_empty() {
            tracing::warn!(
                "remote_access.fs.enabled is on but remote_access.fs.roots names \
                 nothing usable, so the file API will refuse every request. Name \
                 the directories it may reach, e.g. roots = [\"/srv/data\"]."
            );
        }
        if self.fs.enabled && !self.fs.roots.is_empty() && self.fs.roots.is_unrestricted() {
            tracing::warn!(
                "The file API is serving the whole filesystem. At that setting it is \
                 equivalent to a shell as {}: anyone who can log into the panel can \
                 read any file that account can read and write any file it can write, \
                 including ~/.ssh/authorized_keys. Narrow remote_access.fs.roots to \
                 the directories that actually need to be reachable.",
                whoami()
            );
        }
        if self.terminal.enabled && !tls_active {
            if self.terminal.allow_insecure {
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
                     over the network; configure TLS or set \
                     remote_access.terminal.allow_insecure"
                );
            }
        }
        if self.fs.enabled && !self.fs.roots.is_empty() && !tls_active && !self.fs.allow_insecure {
            tracing::warn!(
                "File API is enabled without TLS: it will serve clients on loopback \
                  (including a same-host reverse proxy) but refuse anything arriving \
                  over the network; configure TLS or set remote_access.fs.allow_insecure"
            );
        }
        if self.fs.enabled && !self.fs.roots.is_empty() && self.fs.allow_insecure {
            tracing::warn!(
                "File API permits plaintext network access: bearer tokens and file \
                 contents can be read or changed in transit. Keep this limited to a \
                 network whose transport security you control."
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
            assert_eq!(r.terminal.scrollback_bytes, scrollback, "scrollback at {mem} bytes");
            assert_eq!(r.terminal.max_sessions, slots, "sessions at {mem} bytes");
        }
    }

    #[test]
    fn unknown_memory_falls_back_to_the_conservative_column() {
        assert_eq!(
            resolved(None).terminal.scrollback_bytes,
            resolved(Some(ASSUMED_MEMORY)).terminal.scrollback_bytes
        );
        assert_eq!(
            resolved(None).terminal.max_sessions,
            resolved(Some(ASSUMED_MEMORY)).terminal.max_sessions
        );
    }

    #[test]
    fn a_tiny_machine_still_gets_room_to_reattach() {
        // Takeover needs the old session to exist while the new connection is
        // set up, so one slot would make reconnecting impossible.
        assert!(resolved(Some(64 * 1024 * 1024)).terminal.max_sessions >= 2);
    }

    #[test]
    fn explicit_values_win_over_derivation() {
        let config = RemoteAccessConfig {
            terminal: TerminalConfig {
                max_sessions: Some(1),
                scrollback_bytes: Some(4096),
                ..Default::default()
            },
            ..Default::default()
        };
        let r = config.resolve(Some(64 * GIB));
        assert_eq!(r.terminal.max_sessions, 1);
        assert_eq!(r.terminal.scrollback_bytes, 4096);
    }

    #[test]
    fn zero_is_treated_as_unset_rather_than_as_a_hard_disable() {
        // Disabling is what `enabled = false` is for; a zero capacity would
        // otherwise leave the feature on but every request refused.
        let config = RemoteAccessConfig {
            terminal: TerminalConfig {
                max_sessions: Some(0),
                ..Default::default()
            },
            ..Default::default()
        };
        assert_eq!(
            config.resolve(Some(8 * GIB)).terminal.max_sessions,
            resolved(Some(8 * GIB)).terminal.max_sessions
        );
    }

    #[test]
    fn everything_is_off_by_default() {
        let r = resolved(None);
        assert!(!r.terminal.enabled);
        assert!(!r.terminal.allow_insecure);
        assert!(!r.fs.enabled);
        assert!(!r.fs.allow_insecure);
        assert!(!r.any_enabled());
    }

    #[test]
    fn terminal_needs_tls_unless_explicitly_allowed() {
        let enabled = RemoteAccessConfig {
            terminal: TerminalConfig {
                enabled: true,
                ..Default::default()
            },
            ..Default::default()
        }
        .resolve(None);
        assert!(enabled.terminal.available(true));
        assert!(!enabled.terminal.available(false));

        let insecure = RemoteAccessConfig {
            terminal: TerminalConfig {
                enabled: true,
                allow_insecure: true,
                ..Default::default()
            },
            ..Default::default()
        }
        .resolve(None);
        assert!(insecure.terminal.available(false));

        let disabled = resolved(None);
        assert!(!disabled.terminal.available(true));
    }

    #[test]
    fn file_api_needs_a_secure_transport() {
        let root = std::env::temp_dir().to_string_lossy().into_owned();
        let configured = RemoteAccessConfig {
            fs: FsConfig {
                enabled: true,
                roots: vec![root],
                ..Default::default()
            },
            ..Default::default()
        }
        .resolve(None);
        assert!(configured.fs.available(true));
        assert!(!configured.fs.available(false));
    }

    #[test]
    fn file_api_can_explicitly_allow_plaintext() {
        let root = std::env::temp_dir().to_string_lossy().into_owned();
        let configured = RemoteAccessConfig {
            fs: FsConfig {
                enabled: true,
                roots: vec![root],
                allow_insecure: true,
                ..Default::default()
            },
            ..Default::default()
        }
        .resolve(None);
        assert!(configured.fs.available(false));
    }

    #[test]
    fn an_empty_section_parses_to_the_defaults() {
        let parsed: RemoteAccessConfig = toml::from_str("").unwrap();
        assert_eq!(parsed.ssh_addr, default_ssh_addr());
        assert!(!parsed.terminal.enabled);
        assert!(!parsed.fs.enabled);
        assert_eq!(
            parsed.terminal.detached_timeout_secs,
            default_detached_timeout_secs()
        );
    }

    #[test]
    fn a_subsection_that_names_one_field_keeps_the_others_defaulted() {
        // What the nesting is for: `[remote_access.terminal] enabled = true`
        // must not reset `detached_timeout_secs` to zero on its way through
        // serde. `#[serde(default)]` on the subsection makes the *section*
        // optional; the field defaults inside it are what make a partial one
        // work.
        let parsed: RemoteAccessConfig = toml::from_str(
            "[terminal]\nenabled = true\n[fs]\nenabled = true\nroots = [\"/srv\"]\n",
        )
        .unwrap();
        assert!(parsed.terminal.enabled);
        assert_eq!(
            parsed.terminal.detached_timeout_secs,
            default_detached_timeout_secs()
        );
        assert_eq!(parsed.ssh_addr, default_ssh_addr());
        assert_eq!(parsed.fs.roots, vec!["/srv".to_string()]);
    }
}
