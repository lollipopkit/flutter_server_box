//! The machine side of remote access: where sshd is, how big a terminal, a
//! command or a file write may get, and whether plaintext is tolerated.
//!
//! Who may use any of it is not a question here: the agent's one account
//! may do what the system account it runs as may do (`api::authz`).
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
//!
//! Keys of the model before (`full_access`, `listen_public`,
//! `terminal.enabled`, `fs.enabled`, `fs.roots`) restrict nothing any more;
//! they are read only to warn at startup that they no longer do, and the next
//! save drops them. TODO: remove with [`RemoteAccessConfig::retired_keys`].

use std::time::Duration;

use serde::{Deserialize, Serialize};

use super::fs_roots::FsRoots;

/// The machine's SSH server: the firewall page keeps a way in to it open.
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
    /// TLS, or a loopback peer (a same-host reverse proxy), unless this is on.
    /// A private source address does not prove a path is encrypted, so it is
    /// off by default and only an operator editing this file can turn it on;
    /// the app has a second, per-server opt-in before it will send anything
    /// over HTTP.
    #[serde(default)]
    pub allow_insecure: bool,

    #[serde(default)]
    pub terminal: TerminalConfig,

    #[serde(default)]
    pub fs: FsConfig,

    #[serde(default)]
    pub exec: ExecConfig,

    /// Retired keys, see [`Self::retired_keys`]. TODO: remove.
    #[serde(default, skip_serializing)]
    full_access: Option<serde::de::IgnoredAny>,
    /// TODO: remove with `full_access`.
    #[serde(default, skip_serializing)]
    listen_public: Option<serde::de::IgnoredAny>,
}

/// Hand-written rather than derived: `ssh_addr` has a default that is not the
/// empty string, and deriving it would point every unconfigured agent at
/// nothing.
impl Default for RemoteAccessConfig {
    fn default() -> Self {
        Self {
            ssh_addr: default_ssh_addr(),
            allow_insecure: false,
            terminal: TerminalConfig::default(),
            fs: FsConfig::default(),
            exec: ExecConfig::default(),
            full_access: None,
            listen_public: None,
        }
    }
}

impl RemoteAccessConfig {
    /// The keys of the model before one account that this file still sets:
    /// each used to narrow what a signed-in caller reached, and none does now,
    /// so an operator who relied on one is told at startup. TODO: remove once
    /// no config.toml can still carry them.
    pub fn retired_keys(&self) -> Vec<&'static str> {
        [
            (self.full_access.is_some(), "full_access"),
            (self.listen_public.is_some(), "listen_public"),
            (self.terminal.enabled.is_some(), "terminal.enabled"),
            (self.fs.enabled.is_some(), "fs.enabled"),
            (self.fs.roots.is_some(), "fs.roots"),
        ]
        .into_iter()
        .filter_map(|(set, key)| set.then_some(key))
        .collect()
    }
}

/// `[remote_access.terminal]` — the terminal's capacities (the app's and the panel's).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalConfig {
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

    /// The key before `[remote_access] allow_insecure`, which it still counts
    /// as. TODO: remove once no config.toml can still carry it.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
    pub allow_insecure: bool,

    /// Retired, see [`RemoteAccessConfig::retired_keys`]. TODO: remove.
    #[serde(default, skip_serializing)]
    enabled: Option<serde::de::IgnoredAny>,
}

impl Default for TerminalConfig {
    fn default() -> Self {
        Self {
            max_sessions: None,
            scrollback_bytes: None,
            detached_timeout_secs: default_detached_timeout_secs(),
            allow_insecure: false,
            enabled: None,
        }
    }
}

/// `[remote_access.fs]` — the file API, `/api/v1/fs/*`.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct FsConfig {
    /// The key before `[remote_access] allow_insecure`, which it still counts
    /// as. TODO: remove once no config.toml can still carry it.
    #[serde(default, skip_serializing_if = "std::ops::Not::not")]
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

    /// Retired, see [`RemoteAccessConfig::retired_keys`]. TODO: remove.
    #[serde(default, skip_serializing)]
    enabled: Option<serde::de::IgnoredAny>,
    /// Retired, see [`RemoteAccessConfig::retired_keys`]. TODO: remove.
    #[serde(default, skip_serializing)]
    roots: Option<serde::de::IgnoredAny>,
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
/// reads them.
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
            allow_insecure: self.allow_insecure
                || self.terminal.allow_insecure
                || self.fs.allow_insecure,
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
                roots: FsRoots::whole_filesystem(),
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
    /// Whether anything beyond reading the numbers may be served over
    /// plaintext — see [`RemoteAccessConfig::allow_insecure`].
    pub allow_insecure: bool,
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
/// terminal.
#[derive(Debug, Clone)]
pub struct Terminal {
    pub max_sessions: usize,
    pub scrollback_bytes: usize,
    pub detached_timeout: Duration,
}

/// Resolved [`FsConfig`].
#[derive(Debug, Clone)]
pub struct Fs {
    /// Where paths resolve: the whole filesystem, never the agent's own
    /// state — see [`FsRoots`].
    pub roots: FsRoots,
    pub max_write_bytes: u64,
}

impl RemoteAccess {
    /// Whether anything beyond reading the numbers may be served over a link
    /// that is [`secure`] or not — see `api::ws::is_secure_transport` for what
    /// counts. A terminal is a shell, a file read is the file, a relay is
    /// whatever it relays, and all of them ride on a bearer token that a
    /// plaintext link hands to anyone on the path.
    pub fn transport_ok(&self, secure: bool) -> bool {
        secure || self.allow_insecure
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
        if self.allow_insecure && !tls_active {
            tracing::warn!(
                "remote_access.allow_insecure is on and this agent has no TLS: \
                 terminals, commands, files and relays are served over plaintext to \
                 anyone on the network path. Keep this to a network whose transport \
                 security you control."
            );
        }
    }
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
        // There is no switch to disable a terminal; a zero capacity would
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
    fn plaintext_is_refused_by_default() {
        let r = resolved(None);
        assert!(r.transport_ok(true));
        assert!(!r.transport_ok(false));
    }

    #[test]
    fn each_allow_insecure_key_allows_plaintext() {
        // TODO: the two older keys go with their fields.
        for config in [
            "allow_insecure = true\n",
            "[terminal]\nallow_insecure = true\n",
            "[fs]\nallow_insecure = true\n",
        ] {
            let parsed: RemoteAccessConfig = toml::from_str(config).unwrap();
            assert!(parsed.resolve(None).transport_ok(false), "{config}");
            // And kept on save.
            let saved: RemoteAccessConfig = toml::from_str(&toml::to_string(&parsed).unwrap()).unwrap();
            assert!(saved.resolve(None).transport_ok(false), "{config}");
        }
    }

    #[test]
    fn keys_of_the_model_before_are_skipped() {
        let parsed: RemoteAccessConfig = toml::from_str(
            "full_access = true\nlisten_public = true\n[terminal]\nenabled = true\n[fs]\nenabled = true\nroots = [\"/srv\"]\n",
        )
        .unwrap();
        let saved = toml::to_string(&parsed).unwrap();
        for key in ["full_access", "listen_public", "enabled", "roots"] {
            assert!(!saved.contains(key), "{key}");
        }
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
        assert!(!parsed.allow_insecure);
        assert_eq!(
            parsed.terminal.detached_timeout_secs,
            default_detached_timeout_secs()
        );
    }

    #[test]
    fn a_subsection_that_names_one_field_keeps_the_others_defaulted() {
        // `#[serde(default)]` on the subsection makes the *section* optional;
        // the field defaults inside it are what make a partial one work.
        let parsed: RemoteAccessConfig =
            toml::from_str("[terminal]\nmax_sessions = 3\n").unwrap();
        assert_eq!(parsed.terminal.max_sessions, Some(3));
        assert_eq!(
            parsed.terminal.detached_timeout_secs,
            default_detached_timeout_secs()
        );
        assert_eq!(parsed.ssh_addr, default_ssh_addr());
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

    #[test]
    fn retired_keys_are_named_and_not_written_back() {
        let config: RemoteAccessConfig = toml::from_str(
            "full_access = false\n[terminal]\nenabled = false\n[fs]\nenabled = true\nroots = [\"/srv\"]\n",
        )
        .unwrap();
        assert_eq!(config.retired_keys(), ["full_access", "terminal.enabled", "fs.enabled", "fs.roots"]);
        let written = toml::to_string(&config).unwrap();
        for key in ["full_access", "enabled", "roots"] {
            assert!(!written.contains(key), "{written}");
        }
        assert!(RemoteAccessConfig::default().retired_keys().is_empty());
    }
}
