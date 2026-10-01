//! The machine side of remote access: where sshd is, what the file API may
//! reach, how big a terminal or a command may get, and whether plaintext is
//! tolerated.
//!
//! *Who* may use any of it is not here. That is a role's grants, in the
//! database (`core::permissions`, issue #1610). The switches that used to say
//! it for every login at once — `full_access`, `listen_public`,
//! `terminal.enabled`, `fs.enabled` — are still parsed so an old file loads,
//! and read exactly once: when an upgraded agent first decides what its admin
//! role holds (`db::bootstrap::ensure_roles`). After that they are ignored.
//! TODO: remove them once no agent can still be upgrading from before roles.
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
use super::permissions::Grant;

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

    /// Serve everything beyond reading the numbers to callers on a plaintext
    /// network link.
    ///
    /// One rule for every grant: TLS, or a loopback peer (a same-host reverse
    /// proxy), unless this is on. A private source address does not prove a
    /// path is encrypted, so it is off by default and only an operator editing
    /// this file can turn it on; the app has a second, per-server opt-in
    /// before it will send anything over HTTP.
    ///
    /// The two keys that came before it still count, each for what it used to
    /// cover and no further: `terminal.allow_insecure` for the grants that
    /// were behind the terminal switch (`shell`, `ssh_terminal`, `connect`,
    /// `listen`), `fs.allow_insecure` for `files`. Folded into one, an old
    /// file that let the file API onto a trusted plaintext link would have
    /// put a shell on it after the upgrade.
    #[serde(default)]
    pub allow_insecure: bool,

    /// Legacy: moved to the roles. See the module documentation.
    ///
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

    /// Legacy: moved to the roles (`listen.public`). See the module docs.
    ///
    /// Let a remote forward listen on an address other than loopback.
    ///
    /// sshd's `GatewayPorts`, and off for the same reason: a forward the app
    /// opens is for the app's user, and one bound to `0.0.0.0` hands the port
    /// to everyone who can reach this machine. Off, `/api/v1/listen/ws` binds
    /// loopback only.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub listen_public: Option<bool>,

    #[serde(default)]
    pub terminal: TerminalConfig,

    #[serde(default)]
    pub fs: FsConfig,

    #[serde(default)]
    pub exec: ExecConfig,
}

/// Hand-written rather than derived: `ssh_addr` has a default that is not the
/// empty string, and deriving it would point every unconfigured agent at
/// nothing.
impl Default for RemoteAccessConfig {
    fn default() -> Self {
        Self {
            ssh_addr: default_ssh_addr(),
            allow_insecure: false,
            full_access: None,
            listen_public: None,
            terminal: TerminalConfig::default(),
            fs: FsConfig::default(),
            exec: ExecConfig::default(),
        }
    }
}

/// `[remote_access.terminal]` — the panel's in-browser terminal.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalConfig {
    /// Legacy: moved to the roles (`ssh_terminal`). See the module docs.
    ///
    /// An `Option` so that a file which says `false` is told apart from one
    /// that does not mention it — see [`RemoteAccessConfig::legacy_present`].
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub enabled: Option<bool>,

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

    /// Read as [`RemoteAccessConfig::allow_insecure`]. TODO: remove.
    #[serde(default)]
    pub allow_insecure: bool,
}

impl Default for TerminalConfig {
    fn default() -> Self {
        Self {
            enabled: None,
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
    /// Legacy: moved to the roles (`files`). See the module docs. An
    /// `Option` for the reason [`TerminalConfig::enabled`] is.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub enabled: Option<bool>,

    /// The directories the file API may reach; an empty list serves nothing,
    /// whatever a role grants. Machine-level rather than per role: what is on
    /// this disk worth reaching is the operator's to say.
    ///
    /// `["/"]` is how "the whole machine" is said, and it is a real decision
    /// rather than a default: at that setting the panel password is worth a
    /// shell, because anyone who can write `~/.ssh/authorized_keys` has one.
    /// It is warned about at startup for the same reason `full_access` is.
    #[serde(default)]
    pub roots: Vec<String>,

    /// Read as [`RemoteAccessConfig::allow_insecure`]. TODO: remove.
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

/// `[remote_access.exec]` — `POST /api/v1/exec`.
///
/// Every field here is a bound on one request, and every one of them used to be
/// a constant. They are configurable because what a reasonable command is
/// differs by what the agent is being asked to do: 60 seconds covers a package
/// listing and refuses to cover a benchmark, a filesystem scan or a backup, and
/// an operator who wants those has no way to ask for them from the app side —
/// the limits are the agent's decision, not the caller's, so a request cannot
/// raise them.
///
/// Under `exec` because these describe one endpoint's bounds and nothing else
/// reads them; *whether* commands run at all is the `shell` grant.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ExecConfig {
    /// How long a command may run before the agent kills it and answers
    /// `timed_out`. `None` = [`DEFAULT_EXEC_TIMEOUT_SECS`].
    ///
    /// Raising this holds a worker for as long as it says, so it is a trade
    /// against the agent's own responsiveness rather than a free knob. A caller
    /// that needs to outlive any value here should start the work detached and
    /// poll it, which costs one short request per check instead.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub timeout_secs: Option<u64>,

    /// Bytes retained per output stream; past this the response says
    /// `truncated`. `None` = derive from physical memory.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max_output_bytes: Option<usize>,

    /// Largest request body accepted — the command, its `stdin` and its `env`.
    /// `None` = derive from physical memory.
    ///
    /// The app sends a script on `stdin` here, so this is what decides whether
    /// a large one can be installed at all; over it, ntex answers 413 before
    /// the handler sees the request.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub max_request_bytes: Option<usize>,
}

/// What [`ExecConfig::timeout_secs`] means when unset: long enough for a
/// package listing on a slow disk, short enough that a command waiting on input
/// nobody will type does not hold a worker forever.
pub const DEFAULT_EXEC_TIMEOUT_SECS: u64 = 60;

/// Whether access without SSH is the right default for this platform.
///
/// Split out so the rule is stated once and can be asserted in a test on
/// every target, rather than being buried in a `cfg!` inside `resolve`.
pub const fn full_access_default() -> bool {
    cfg!(target_os = "linux")
}

/// Reads the `SBM_FULL_ACCESS` override.
///
/// Env normally beats the config file, matching how the rest of monitor's
/// settings behave for container deployments where editing a file is awkward.
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

/// TODO: remove with [`RemoteAccessConfig::legacy_full_access`].
fn resolve_full_access(configured: Option<bool>, from_env: Option<bool>) -> bool {
    // An explicit file-level denial is sticky because the panel's disable
    // endpoint can only persist to that file. Environment may still disable a
    // configured grant, but it cannot silently reopen access the user closed.
    if configured == Some(false) {
        false
    } else {
        from_env.or(configured).unwrap_or_else(full_access_default)
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
/// The flat cap both exec bounds carried before they were derived. Kept as the
/// floor so no machine gets *less* than it did, whatever it reports for memory:
/// the derivation is only allowed to be generous.
const MIN_EXEC_BYTES: usize = 1024 * 1024;
const MAX_EXEC_BYTES: usize = 64 * 1024 * 1024;

impl RemoteAccessConfig {
    /// What `full_access` resolved to before roles: the platform default,
    /// `SBM_FULL_ACCESS`, and the file, the way the old agent combined them.
    /// Only the upgrade to roles reads it. TODO: remove with the key.
    pub fn legacy_full_access(&self) -> bool {
        resolve_full_access(self.full_access, full_access_from_env())
    }

    /// The moved keys this file still sets, for the log line that says they
    /// are no longer read.
    pub fn legacy_keys_set(&self) -> Vec<&'static str> {
        let mut keys = Vec::new();
        if self.full_access.is_some() {
            keys.push("remote_access.full_access");
        }
        if std::env::var_os("SBM_FULL_ACCESS").is_some() {
            keys.push("SBM_FULL_ACCESS");
        }
        if self.listen_public.is_some() {
            keys.push("remote_access.listen_public");
        }
        if self.terminal.enabled.is_some() {
            keys.push("remote_access.terminal.enabled");
        }
        if self.fs.enabled.is_some() {
            keys.push("remote_access.fs.enabled");
        }
        keys
    }

    /// Whether this configuration was written for the model before roles, so
    /// that a fresh install must not grant more than it said: any moved key
    /// written into the file, whatever its value, or `SBM_FULL_ACCESS` set
    /// to false. [env] is that variable as read.
    ///
    /// Presence rather than value because an absent key and `false` meant the
    /// same thing then and do not now: a declarative deployment that wrote
    /// `full_access = false` and starts on a new database must not come up
    /// with a shell.
    pub fn legacy_present(&self, env: Option<bool>) -> bool {
        self.full_access.is_some()
            || self.listen_public.is_some()
            || self.terminal.enabled.is_some()
            || self.fs.enabled.is_some()
            || env == Some(false)
    }

    /// What the moved keys effectively granted every login before roles —
    /// [`Grants::from_legacy`] over this file and `SBM_FULL_ACCESS`.
    /// TODO: remove with the keys.
    pub fn legacy_grants(&self) -> super::permissions::Grants {
        let files_usable =
            self.fs.enabled == Some(true) && !FsRoots::resolve(&self.fs.roots).is_empty();
        super::permissions::Grants::from_legacy(
            self.terminal.enabled == Some(true),
            self.legacy_full_access(),
            self.listen_public == Some(true),
            files_usable,
        )
    }

    /// `SBM_FULL_ACCESS` as a boolean, for [`Self::legacy_present`].
    pub fn legacy_env() -> Option<bool> {
        full_access_from_env()
    }

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
        // One request at a time rather than one per session, so this can be
        // freer than the scrollback above: 1 MiB up to 512 MiB of RAM, 16 MiB
        // at 8 GiB, the cap from 32 GiB up.
        let exec_bytes = ((mem / 512) as usize).clamp(MIN_EXEC_BYTES, MAX_EXEC_BYTES);

        RemoteAccess {
            ssh_addr: self.ssh_addr.clone(),
            insecure_shell: self.allow_insecure || self.terminal.allow_insecure,
            insecure_files: self.allow_insecure || self.fs.allow_insecure,
            insecure_rest: self.allow_insecure,
            terminal: Terminal {
                max_sessions: self.terminal.max_sessions.filter(|&n| n > 0).unwrap_or(slots),
                scrollback_bytes: self
                    .terminal
                    .scrollback_bytes
                    .filter(|&n| n > 0)
                    .unwrap_or(scrollback),
                detached_timeout: Duration::from_secs(self.terminal.detached_timeout_secs),
            },
            fs: Fs {
                roots: FsRoots::resolve(&self.fs.roots),
                // A quarter of RAM, floored and capped: big enough for the
                // config files and archives people actually move, small enough
                // that one request cannot fill a small VPS's disk.
                max_write_bytes: self
                    .fs
                    .max_write_bytes
                    .filter(|&n| n > 0)
                    .unwrap_or_else(|| (mem / 4).clamp(MIN_WRITE_BYTES, MAX_WRITE_BYTES)),
            },
            exec: Exec {
                timeout: Duration::from_secs(
                    self.exec
                        .timeout_secs
                        .filter(|&n| n > 0)
                        .unwrap_or(DEFAULT_EXEC_TIMEOUT_SECS),
                ),
                max_output_bytes: self
                    .exec
                    .max_output_bytes
                    .filter(|&n| n > 0)
                    .unwrap_or(exec_bytes),
                max_request_bytes: self
                    .exec
                    .max_request_bytes
                    .filter(|&n| n > 0)
                    .unwrap_or(exec_bytes),
            },
        }
    }
}

/// [`RemoteAccessConfig`] with every capacity resolved. Built once at startup
/// and shared through `AppState`.
#[derive(Debug, Clone)]
pub struct RemoteAccess {
    pub ssh_addr: String,
    /// Whether `shell`, `ssh_terminal`, `connect` and `listen` may be used over
    /// plaintext: [`RemoteAccessConfig::allow_insecure`] or the terminal's
    /// legacy key.
    pub insecure_shell: bool,
    /// Whether `files` may be: [`RemoteAccessConfig::allow_insecure`] or the
    /// file API's legacy key.
    pub insecure_files: bool,
    /// Whether a grant newer than both legacy keys (`virt`) may be:
    /// [`RemoteAccessConfig::allow_insecure`] alone. Neither old key ever
    /// covered it, so neither can open it.
    pub insecure_rest: bool,
    pub terminal: Terminal,
    pub fs: Fs,
    pub exec: Exec,
}

/// Resolved [`ExecConfig`].
#[derive(Debug, Clone)]
pub struct Exec {
    pub timeout: Duration,
    pub max_output_bytes: usize,
    pub max_request_bytes: usize,
}

/// Resolved [`TerminalConfig`]: the capacities, which apply to every
/// terminal whichever grant opened it.
#[derive(Debug, Clone)]
pub struct Terminal {
    pub max_sessions: usize,
    pub scrollback_bytes: usize,
    pub detached_timeout: Duration,
}

/// Resolved [`FsConfig`].
#[derive(Debug, Clone)]
pub struct Fs {
    /// Canonicalised at startup — see [`FsRoots`].
    pub roots: FsRoots,
    pub max_write_bytes: u64,
}

impl Fs {
    /// Whether the file API has anywhere to serve. A role can grant `files`
    /// on a machine with no roots; that grant answers `not_configured`
    /// rather than serving the whole filesystem, which would be the worst
    /// possible reading of a half-finished configuration.
    pub fn configured(&self) -> bool {
        !self.roots.is_empty()
    }
}

impl RemoteAccess {
    /// Whether anything beyond reading the numbers may be served over a link
    /// that is [`secure`] or not — see `api::ws::is_secure_transport` for what
    /// counts.
    ///
    /// One rule for every grant. A terminal's first frame can carry an SSH
    /// password, a file read is the file, a relay is whatever it relays, and
    /// all of them ride on a bearer token that a plaintext link hands to
    /// anyone on the path. Which opt-out applies depends on [grant] only
    /// because of the legacy keys — see [`RemoteAccessConfig::allow_insecure`].
    pub fn transport_ok(&self, grant: Grant, secure: bool) -> bool {
        secure
            || match grant {
                Grant::Files => self.insecure_files,
                Grant::Shell | Grant::SshTerminal | Grant::Connect | Grant::Listen => {
                    self.insecure_shell
                }
                Grant::Virt => self.insecure_rest,
            }
    }

    /// Logs the resolved limits once at startup.
    ///
    /// Worth the noise: the capacities are derived rather than written down
    /// anywhere, and "why did my sixth terminal get refused" should be
    /// answerable from the log instead of from this source file.
    pub fn log_summary(&self, tls_active: bool) {
        tracing::info!(
            "Remote access limits: {} terminal sessions, {} KiB scrollback, {}s detached timeout; \
             exec {}s timeout, {} MiB output, {} MiB request; sshd at {}",
            self.terminal.max_sessions,
            self.terminal.scrollback_bytes / 1024,
            self.terminal.detached_timeout.as_secs(),
            self.exec.timeout.as_secs(),
            self.exec.max_output_bytes / (1024 * 1024),
            self.exec.max_request_bytes / (1024 * 1024),
            self.ssh_addr,
        );
        if self.fs.configured() {
            tracing::info!(
                "File API roots: {:?}, max write {} MiB",
                self.fs.roots.as_slice(),
                self.fs.max_write_bytes / (1024 * 1024),
            );
        }
        if self.fs.configured() && self.fs.roots.is_unrestricted() {
            tracing::warn!(
                "The file API's roots are the whole filesystem. For a role holding \
                 `files` that is a shell as {}: it can read any file that account can \
                 read and, with mode = \"write\", write any file it can write, including \
                 ~/.ssh/authorized_keys. Narrow remote_access.fs.roots to the \
                 directories that actually need to be reachable.",
                whoami()
            );
        }
        if (self.insecure_shell || self.insecure_files) && !tls_active {
            tracing::warn!(
                "remote_access.allow_insecure is on and this agent has no TLS: \
                 terminals, commands, files and relays are served over plaintext to \
                 anyone on the network path. Keep this to a network whose transport \
                 security you control."
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
    fn plaintext_is_refused_and_no_roots_are_served_by_default() {
        let r = resolved(None);
        for grant in Grant::ALL {
            assert!(r.transport_ok(grant, true));
            assert!(!r.transport_ok(grant, false));
        }
        assert!(!r.fs.configured());
    }

    #[test]
    fn each_old_allow_insecure_key_covers_what_it_used_to_and_no_more() {
        let shellish = [Grant::Shell, Grant::SshTerminal, Grant::Connect, Grant::Listen];

        // The new key: everything.
        let all = RemoteAccessConfig {
            allow_insecure: true,
            ..Default::default()
        }
        .resolve(None);
        for grant in Grant::ALL {
            assert!(all.transport_ok(grant, false), "{grant:?}");
        }

        // The terminal's: what was behind the terminal switch, not files.
        let terminal = RemoteAccessConfig {
            terminal: TerminalConfig {
                allow_insecure: true,
                ..Default::default()
            },
            ..Default::default()
        }
        .resolve(None);
        for grant in shellish {
            assert!(terminal.transport_ok(grant, false), "{grant:?}");
        }
        assert!(!terminal.transport_ok(Grant::Files, false));
        assert!(!terminal.transport_ok(Grant::Virt, false));

        // The file API's: files, and never a shell — which is what an old
        // config that trusted a plaintext link with its files would otherwise
        // have handed out on upgrade.
        let fs = RemoteAccessConfig {
            fs: FsConfig {
                allow_insecure: true,
                ..Default::default()
            },
            ..Default::default()
        }
        .resolve(None);
        assert!(fs.transport_ok(Grant::Files, false));
        assert!(!fs.transport_ok(Grant::Virt, false));
        for grant in shellish {
            assert!(!fs.transport_ok(grant, false), "{grant:?}");
        }
    }

    #[test]
    fn explicit_file_denial_cannot_be_reopened_by_the_environment() {
        assert!(!resolve_full_access(Some(false), Some(true)));
        assert!(!resolve_full_access(Some(true), Some(false)));
        assert!(resolve_full_access(Some(true), None));
    }

    #[test]
    fn roots_are_what_makes_the_file_api_configured() {
        let root = std::env::temp_dir().to_string_lossy().into_owned();
        let configured = RemoteAccessConfig {
            fs: FsConfig {
                roots: vec![root],
                ..Default::default()
            },
            ..Default::default()
        }
        .resolve(None);
        assert!(configured.fs.configured());
    }

    #[test]
    fn a_moved_key_counts_whatever_its_value_and_absence_does_not() {
        let old: RemoteAccessConfig = toml::from_str("full_access = false\n").unwrap();
        assert!(old.legacy_present(None));
        let off: RemoteAccessConfig = toml::from_str("[terminal]\nenabled = false\n").unwrap();
        assert!(off.legacy_present(None));
        let new: RemoteAccessConfig = toml::from_str("allow_insecure = false\n").unwrap();
        assert!(!new.legacy_present(None));
        // The environment counts only when it says no.
        assert!(new.legacy_present(Some(false)));
        assert!(!new.legacy_present(Some(true)));
        // And an absent key is not written back on save.
        assert!(!toml::to_string(&new).unwrap().contains("enabled"));
    }

    #[test]
    fn the_moved_keys_are_named_for_the_log() {
        let config: RemoteAccessConfig = toml::from_str(
            "full_access = true\nlisten_public = true\n[terminal]\nenabled = true\n",
        )
        .unwrap();
        let keys = config.legacy_keys_set();
        assert!(keys.contains(&"remote_access.full_access"));
        assert!(keys.contains(&"remote_access.listen_public"));
        assert!(keys.contains(&"remote_access.terminal.enabled"));
        assert!(!keys.contains(&"remote_access.fs.enabled"));
    }

    #[test]
    fn exec_bounds_default_to_at_least_what_the_flat_caps_were() {
        // The derivation replaced two 1 MiB constants. Whatever it computes,
        // no machine may end up with a smaller bound than it shipped with.
        for mem in [64 * 1024 * 1024, 512 * 1024 * 1024, 2 * GIB, 256 * GIB] {
            let r = resolved(Some(mem));
            assert!(r.exec.max_output_bytes >= MIN_EXEC_BYTES, "output at {mem}");
            assert!(r.exec.max_request_bytes >= MIN_EXEC_BYTES, "request at {mem}");
            assert!(r.exec.max_output_bytes <= MAX_EXEC_BYTES, "output cap at {mem}");
        }
        assert_eq!(
            resolved(None).exec.timeout,
            Duration::from_secs(DEFAULT_EXEC_TIMEOUT_SECS)
        );
    }

    #[test]
    fn explicit_exec_bounds_win_over_derivation() {
        let config = RemoteAccessConfig {
            exec: ExecConfig {
                timeout_secs: Some(1800),
                max_output_bytes: Some(4096),
                max_request_bytes: Some(8192),
            },
            ..Default::default()
        };
        let r = config.resolve(Some(64 * GIB));
        assert_eq!(r.exec.timeout, Duration::from_secs(1800));
        // Below the derivation floor on purpose: an explicit number is the
        // operator's decision, and clamping it would silently overrule them.
        assert_eq!(r.exec.max_output_bytes, 4096);
        assert_eq!(r.exec.max_request_bytes, 8192);
    }

    #[test]
    fn zero_exec_bounds_are_unset_rather_than_a_hard_disable() {
        // Same rule as the terminal capacities: zero would leave the endpoint
        // on with every request failing, which nobody means by writing 0.
        let config = RemoteAccessConfig {
            exec: ExecConfig {
                timeout_secs: Some(0),
                max_output_bytes: Some(0),
                max_request_bytes: Some(0),
            },
            ..Default::default()
        };
        let r = config.resolve(Some(8 * GIB));
        let derived = resolved(Some(8 * GIB));
        assert_eq!(r.exec.timeout, derived.exec.timeout);
        assert_eq!(r.exec.max_output_bytes, derived.exec.max_output_bytes);
        assert_eq!(r.exec.max_request_bytes, derived.exec.max_request_bytes);
    }

    #[test]
    fn an_empty_section_parses_to_the_defaults() {
        let parsed: RemoteAccessConfig = toml::from_str("").unwrap();
        assert_eq!(parsed.ssh_addr, default_ssh_addr());
        assert_eq!(parsed.terminal.enabled, None);
        assert_eq!(parsed.fs.enabled, None);
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
        assert_eq!(parsed.terminal.enabled, Some(true));
        assert_eq!(
            parsed.terminal.detached_timeout_secs,
            default_detached_timeout_secs()
        );
        assert_eq!(parsed.ssh_addr, default_ssh_addr());
        assert_eq!(parsed.fs.roots, vec!["/srv".to_string()]);
    }

    #[test]
    fn the_exec_section_parses_from_the_file() {
        let parsed: RemoteAccessConfig =
            toml::from_str("[exec]\ntimeout_secs = 1800\nmax_output_bytes = 8388608\n").unwrap();
        assert_eq!(parsed.exec.timeout_secs, Some(1800));
        assert_eq!(parsed.exec.max_output_bytes, Some(8 * 1024 * 1024));
        // Naming one key must not zero the others — see the subsection test
        // above for why this is worth asserting per section.
        assert_eq!(parsed.exec.max_request_bytes, None);
    }
}
