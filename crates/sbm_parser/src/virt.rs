//! libvirt (`virsh`) command layer: command scripts and output parsers.
//!
//! Pure, no I/O. The caller runs a script through whatever reaches the machine
//! (SSH, a monitor agent's `/exec`, a local process) and hands the combined
//! output back here. Every script is POSIX `sh` meant to be fed to `sh` on
//! stdin (the app's `ServerExec.run(script, entry: 'sh')`, or
//! `sudo -S -p '' sh` for the permission retry), never run as the login
//! shell's command line — that may be fish.
//!
//! # Output format
//!
//! Scripts print sections with the status script's own markers
//! ([`script::cmd_marker`], split by [`script::parse_script_segments`]), so
//! one protocol serves both. Each `virsh` call prints its stdout and stderr
//! into its section, followed by a line `SbVirtRc=<exit status>`, so a failed
//! call is told apart from one that printed nothing. The script exports
//! `LC_ALL=C` so error text is English and matchable, and every `virsh` reads
//! `/dev/null`: `sh` is reading the script itself from stdin, and a child that
//! read stdin would consume the rest of it.
//!
//! # Numbers
//!
//! Parsers emit raw counters (CPU time in ns, block/net bytes, balloon KiB).
//! Rates are the caller's: it keeps the previous sample and diffs.
//!
//! # State mapping
//!
//! `domstats --state` reports `virDomainState` and its reason as integers,
//! which are locale-free and more precise than `domstate`'s text. See
//! [`VirtState::from_libvirt`] for the mapping.
//!
//! # Joining list and stats
//!
//! `domstats` names domains, `list --uuid --name` pairs names with UUIDs. Names
//! are unique per connection, so the join is by name. libvirt < 7.0 printed
//! that list as `%-36s %-30s` (right-padded name), 7.0+ as `uuid name`; a
//! name is matched exactly first and then with trailing whitespace ignored,
//! so a name that itself ends in spaces is only ambiguous on libvirt < 7.0.

use crate::script::{self, shell_quote_unix};
use serde::{Deserialize, Serialize};

/// Connection URI every command uses. Session (`qemu:///session`) guests are
/// per user and not what a server manager is looking for.
pub const CONNECT_URI: &str = "qemu:///system";

/// Last line of every `virsh` call's section: the call's exit status.
pub const RC_PREFIX: &str = "SbVirtRc=";

/// Section keys (wire format: they are encoded into the markers).
pub const KEY_MISSING: &str = "virt.missing";
pub const KEY_VERSION: &str = "virt.version";
pub const KEY_PVE: &str = "virt.pve";
pub const KEY_CONTAINER: &str = "virt.container";
pub const KEY_LIST: &str = "virt.list";
pub const KEY_AUTOSTART: &str = "virt.autostart";
pub const KEY_PERSISTENT: &str = "virt.persistent";
pub const KEY_STATS: &str = "virt.stats";
pub const KEY_DISPLAY: &str = "virt.display";
pub const KEY_XML: &str = "virt.xml";
pub const KEY_ACTION: &str = "virt.action";

/// `domstats` groups the overview asks for. Explicit rather than "all" so a
/// newer libvirt's extra groups (perf, dirtyrate, vm) are not collected on
/// every poll; `--nowait` skips a domain's stats that would wait on a running
/// job instead of blocking the whole call behind it.
const DOMSTATS_ARGS: &str = "domstats --raw --nowait --state --cpu-total --balloon --vcpu --interface --block";

// ---------------------------------------------------------------------------
// Scripts
// ---------------------------------------------------------------------------

/// Preamble shared by every script: C locale, the missing-`virsh` section, and
/// the `V` wrapper that appends the exit status.
fn prelude() -> String {
    format!(
        "export LC_ALL=C\n\
         if ! command -v virsh >/dev/null 2>&1; then echo '{missing}'; exit 0; fi\n\
         V() {{ virsh --connect {uri} -q \"$@\" </dev/null 2>&1; printf '\\n{rc}%s\\n' \"$?\"; }}\n",
        missing = script::cmd_marker(KEY_MISSING),
        uri = CONNECT_URI,
        rc = RC_PREFIX,
    )
}

fn section(key: &str, virsh_args: &str) -> String {
    format!("echo '{}'\nV {virsh_args}\n", script::cmd_marker(key))
}

/// Host probe: whether this server is Proxmox VE, a container, and whether
/// `virsh` exists and the daemon answers this user. Parse with
/// [`parse_probe`].
///
/// PVE is asked first and ends the script: a PVE host is managed through its
/// HTTP API, so its `virsh` (there is none by default) is not the question.
/// The container checks need no root: `systemd-detect-virt` and
/// `/run/systemd/container` on systemd, `openrc --sys` on OpenRC (Alpine),
/// then `/proc/1/environ` (root only) and the Docker/Podman marker files.
/// Each may print nothing or `none`; the parser takes the first container
/// name it knows.
pub fn probe_script() -> String {
    let mut s = format!(
        "export LC_ALL=C\n\
         if command -v pveversion >/dev/null 2>&1; then echo '{pve}'; pveversion 2>/dev/null </dev/null; exit 0; fi\n\
         echo '{container}'\n\
         systemd-detect-virt -c 2>/dev/null </dev/null\n\
         cat /run/systemd/container 2>/dev/null; echo\n\
         command -v openrc >/dev/null 2>&1 && openrc --sys 2>/dev/null </dev/null\n\
         {{ tr '\\0' '\\n' </proc/1/environ; }} 2>/dev/null | sed -n 's/^container=//p'\n\
         [ -f /.dockerenv ] && echo docker\n\
         [ -f /run/.containerenv ] && echo podman\n",
        pve = script::cmd_marker(KEY_PVE),
        container = script::cmd_marker(KEY_CONTAINER),
    );
    s.push_str(&prelude());
    s.push_str(&section(KEY_VERSION, "version"));
    s
}

/// One round trip for the guest list: versions, domains with UUIDs,
/// autostart and persistent sets, and `domstats`. Five `virsh` calls however
/// many guests there are. Parse with [`parse_overview`].
pub fn overview_script() -> String {
    let mut s = prelude();
    s.push_str(&section(KEY_VERSION, "version"));
    s.push_str(&section(KEY_LIST, "list --all --uuid --name"));
    s.push_str(&section(KEY_AUTOSTART, "list --all --uuid --autostart"));
    s.push_str(&section(KEY_PERSISTENT, "list --all --uuid --persistent"));
    // `--vcpu` is only here for `vcpu.current`/`vcpu.maximum`, but it also
    // prints every vCPU's own counters — about 65 lines per vCPU on libvirt
    // 11.3 / QEMU 10.0 (KVM's `*.sum` statistics), polled every few seconds.
    // The per-vCPU lines are dropped on the host; the status line passes
    // through the filter since `V` prints it inside the pipe.
    s.push_str(&format!(
        "echo '{}'\nV {DOMSTATS_ARGS} | grep -v '^ *vcpu\\.[0-9]'\n",
        script::cmd_marker(KEY_STATS)
    ));
    s
}

/// `--domain <quoted>`: the flag keeps a name starting with `-` from being read
/// as an option, the quoting keeps any name a single literal argument.
fn domain_arg(domain: &str) -> String {
    format!("--domain {}", shell_quote_unix(domain))
}

/// Display URI and XML for one domain. `domain` is a UUID (preferred) or a
/// name. Parse with [`parse_domain_detail`].
pub fn domain_detail_script(domain: &str) -> String {
    let d = domain_arg(domain);
    let mut s = prelude();
    s.push_str(&section(KEY_DISPLAY, &format!("domdisplay {d}")));
    s.push_str(&section(KEY_XML, &format!("dumpxml {d}")));
    s
}

/// Power actions.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VirtAction {
    Start,
    /// ACPI shutdown request; the guest may ignore it
    Shutdown,
    /// ACPI reboot request
    Reboot,
    /// `virsh destroy`: stops the QEMU process immediately, like pulling the plug
    ForceStop,
    /// Pause vCPUs (`virsh suspend`), memory stays allocated
    Suspend,
    /// Resume a paused domain. Does not wake a `pmsuspended` one, which needs
    /// `dompmwakeup`.
    Resume,
}

impl VirtAction {
    pub fn virsh_command(self) -> &'static str {
        match self {
            VirtAction::Start => "start",
            VirtAction::Shutdown => "shutdown",
            VirtAction::Reboot => "reboot",
            VirtAction::ForceStop => "destroy",
            VirtAction::Suspend => "suspend",
            VirtAction::Resume => "resume",
        }
    }
}

/// Script running one power action. Parse with [`parse_action`].
pub fn action_script(action: VirtAction, domain: &str) -> String {
    let mut s = prelude();
    s.push_str(&section(
        KEY_ACTION,
        &format!("{} {}", action.virsh_command(), domain_arg(domain)),
    ));
    s
}

/// Command line for an interactive serial console, for a terminal session
/// (not a `sh` script: it needs the PTY). Single-quoted arguments only, which
/// POSIX shells and fish read the same way.
pub fn console_command(domain: &str) -> String {
    format!(
        "virsh --connect {CONNECT_URI} console --force {}",
        domain_arg(domain)
    )
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

/// Why a `virsh` call failed, classified so the caller can act on it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "kind", rename_all = "snake_case")]
pub enum VirtError {
    /// `virsh` is not on `PATH`
    NotInstalled,
    /// The daemon refused this user: socket permissions, polkit, or libvirt's
    /// ACL. Retrying as root (sudo) is the fix.
    PermissionDenied { message: String },
    /// The daemon could not be reached: not running, socket missing
    ConnectFailed { message: String },
    /// The named domain does not exist (any more)
    DomainNotFound { message: String },
    /// The domain is in a state that does not allow the operation
    InvalidState { message: String },
    /// A domain or volume of that name is there already
    Exists { message: String },
    /// Any other `virsh` failure, with its error text
    Command { message: String },
    /// Output that is not what the script prints: truncated, or a section
    /// missing
    Malformed { message: String },
}

impl std::fmt::Display for VirtError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            VirtError::NotInstalled => f.write_str("virsh not found"),
            VirtError::PermissionDenied { message }
            | VirtError::ConnectFailed { message }
            | VirtError::DomainNotFound { message }
            | VirtError::InvalidState { message }
            | VirtError::Exists { message }
            | VirtError::Command { message }
            | VirtError::Malformed { message } => f.write_str(message),
        }
    }
}

impl std::error::Error for VirtError {}

impl VirtError {
    pub fn message(&self) -> String {
        self.to_string()
    }
}

/// Classify `virsh` error text.
///
/// Permission is checked first: a refused connection prints
/// `failed to connect to the hypervisor` *and* the reason on the next line,
/// and the reason is what decides whether sudo helps.
pub fn classify_error(text: &str) -> VirtError {
    let errors: Vec<&str> = text
        .lines()
        .map(str::trim)
        .filter_map(|l| l.strip_prefix("error:").map(str::trim))
        .filter(|l| !l.is_empty())
        .collect();
    let message = if errors.is_empty() {
        text.trim().to_string()
    } else {
        errors.join("\n")
    };
    let lower = message.to_ascii_lowercase();
    let has = |needles: &[&str]| needles.iter().any(|n| lower.contains(n));

    if has(&[
        "permission denied",
        "authentication unavailable",
        "authentication failed",
        "access denied",
        "not authorized",
        "operation not permitted",
        "polkit",
    ]) {
        VirtError::PermissionDenied { message }
    } else if has(&[
        "failed to connect",
        "no such file or directory",
        "connection refused",
        "cannot recv data",
        "unable to connect",
    ]) {
        VirtError::ConnectFailed { message }
    } else if has(&[
        "failed to get domain",
        "domain not found",
        "no domain with matching",
    ]) {
        VirtError::DomainNotFound { message }
    } else if has(&[
        "requested operation is not valid",
        "domain is not running",
        "domain is already running",
        // `start` on a running domain (libvirt 11.3, captured)
        "is already active",
        "not paused",
    ]) {
        VirtError::InvalidState { message }
    } else if has(&["already exists"]) {
        VirtError::Exists { message }
    } else {
        VirtError::Command { message }
    }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

/// One `virsh` call's section: its output and exit status.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Section {
    pub body: String,
    /// `None` when the status line is missing: the output was cut off
    pub rc: Option<i32>,
}

impl Section {
    /// Split the trailing `SbVirtRc=` line off a section's text.
    pub fn parse(raw: &str) -> Section {
        let trimmed = raw.trim_end();
        let (head, last) = match trimmed.rfind('\n') {
            Some(at) => (&trimmed[..at], &trimmed[at + 1..]),
            None => ("", trimmed),
        };
        match last
            .trim()
            .strip_prefix(RC_PREFIX)
            .and_then(|n| n.trim().parse().ok())
        {
            Some(rc) => Section {
                body: head.to_string(),
                rc: Some(rc),
            },
            None => Section {
                body: raw.to_string(),
                rc: None,
            },
        }
    }

    /// The body when the call succeeded, the classified error otherwise.
    pub fn ok(&self) -> Result<&str, VirtError> {
        match self.rc {
            Some(0) => Ok(&self.body),
            Some(_) => Err(classify_error(&self.body)),
            None => Err(VirtError::Malformed {
                message: format!("virsh output was cut off: {}", self.body.trim()),
            }),
        }
    }
}

/// The sections of a script's output, keyed by section key. `Err` when the
/// script found no `virsh`.
fn sections(raw: &str) -> Result<Vec<(String, Section)>, VirtError> {
    let segs = script::parse_script_segments(raw);
    if segs.iter().any(|(k, _)| k == KEY_MISSING) {
        return Err(VirtError::NotInstalled);
    }
    Ok(segs
        .into_iter()
        .map(|(k, v)| (k, Section::parse(&v)))
        .collect())
}

fn take<'a>(secs: &'a [(String, Section)], key: &str, raw: &str) -> Result<&'a Section, VirtError> {
    secs.iter()
        .find(|(k, _)| k == key)
        .map(|(_, s)| s)
        .ok_or_else(|| {
            // No section at all is usually the shell itself failing (no
            // `sh`, sudo refusing) and its own message is the useful part.
            let text = raw.trim();
            if text.is_empty() {
                VirtError::Malformed {
                    message: format!("no {key} section in output"),
                }
            } else {
                match classify_error(text) {
                    VirtError::Command { message } => VirtError::Malformed { message },
                    other => other,
                }
            }
        })
}

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// Guest state as the app shows it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum VirtState {
    Running,
    Paused,
    Stopped,
    Starting,
    Stopping,
    Unknown,
}

impl VirtState {
    /// From `virDomainState` + reason (`state.state`, `state.reason`).
    ///
    /// - `RUNNING` (1) and `BLOCKED` (2, waiting on a resource) → running
    /// - `PAUSED` (3) → paused, except reason `STARTING_UP` (11) → starting
    ///   and `SHUTTING_DOWN` (8) → stopping: libvirt holds a domain paused
    ///   around both transitions
    /// - `SHUTDOWN` (4, shutdown in progress) → stopping
    /// - `SHUTOFF` (5) → stopped
    /// - `CRASHED` (6) → stopped. The guest is not running; with
    ///   `on_crash=preserve` the QEMU process is kept and must be destroyed
    ///   before the domain starts again — `state_code` says which.
    /// - `PMSUSPENDED` (7, guest suspended to RAM) → paused. It is woken with
    ///   `dompmwakeup`, not `resume`; `state_code` says which.
    /// - `NOSTATE` (0) and anything newer → unknown
    pub fn from_libvirt(state: i32, reason: i32) -> VirtState {
        match (state, reason) {
            (1 | 2, _) => VirtState::Running,
            (3, 11) => VirtState::Starting,
            (3, 8) => VirtState::Stopping,
            (3, _) | (7, _) => VirtState::Paused,
            (4, _) => VirtState::Stopping,
            (5 | 6, _) => VirtState::Stopped,
            _ => VirtState::Unknown,
        }
    }
}

/// libvirt's name for a state reason, as `virsh domstate --reason` prints it
/// (snake_case). `unknown` for a code this build does not know.
pub fn reason_name(state: i32, reason: i32) -> &'static str {
    const RUNNING: &[&str] = &[
        "unknown",
        "booted",
        "migrated",
        "restored",
        "from_snapshot",
        "unpaused",
        "migration_canceled",
        "save_canceled",
        "wakeup",
        "crashed",
        "postcopy",
        "postcopy_failed",
    ];
    const PAUSED: &[&str] = &[
        "unknown",
        "user",
        "migration",
        "save",
        "dump",
        "ioerror",
        "watchdog",
        "from_snapshot",
        "shutting_down",
        "snapshot",
        "crashed",
        "starting_up",
        "postcopy",
        "postcopy_failed",
        "api_error",
    ];
    const SHUTDOWN: &[&str] = &["unknown", "user"];
    const SHUTOFF: &[&str] = &[
        "unknown",
        "shutdown",
        "destroyed",
        "crashed",
        "migrated",
        "saved",
        "failed",
        "from_snapshot",
        "daemon",
    ];
    const CRASHED: &[&str] = &["unknown", "panicked"];
    let table: &[&str] = match state {
        1 => RUNNING,
        3 => PAUSED,
        4 => SHUTDOWN,
        5 => SHUTOFF,
        6 => CRASHED,
        _ => &[],
    };
    usize::try_from(reason)
        .ok()
        .and_then(|i| table.get(i))
        .copied()
        .unwrap_or("unknown")
}

/// `virsh version`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtVersion {
    /// `Using library: libvirt X`
    pub libvirt: Option<String>,
    /// `Running hypervisor: <name> X` — name, e.g. `QEMU`
    pub hypervisor: Option<String>,
    pub hypervisor_version: Option<String>,
}

/// What [`probe_script`] found on a server.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtHostProbe {
    /// `pveversion`'s line (`pve-manager/9.2.2/…`) on a Proxmox VE host.
    /// Empty when the command printed nothing. When set, nothing else was
    /// asked.
    pub pve: Option<String>,
    /// The container this server runs in (`lxc`, `docker`, …), when it is
    /// one: a guest of some other host rather than a host.
    pub container: Option<String>,
    /// `virsh version`, when `virsh` is installed and answered.
    pub libvirt: Option<VirtVersion>,
}

/// One disk in `domstats --block`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtBlockStats {
    /// Target name, e.g. `vda`
    pub name: String,
    pub path: Option<String>,
    pub rd_bytes: Option<u64>,
    pub wr_bytes: Option<u64>,
    pub rd_reqs: Option<u64>,
    pub wr_reqs: Option<u64>,
    /// Bytes
    pub capacity: Option<u64>,
    pub allocation: Option<u64>,
    pub physical: Option<u64>,
}

/// One interface in `domstats --interface`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtNetStats {
    /// Host-side device name, e.g. `vnet3`
    pub name: String,
    pub rx_bytes: Option<u64>,
    pub tx_bytes: Option<u64>,
    pub rx_pkts: Option<u64>,
    pub tx_pkts: Option<u64>,
}

/// Raw counters from `domstats`. All cumulative; absent for an inactive domain.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtCounters {
    /// Nanoseconds
    pub cpu_time_ns: Option<u64>,
    pub cpu_user_ns: Option<u64>,
    pub cpu_system_ns: Option<u64>,
    /// KiB of host memory the QEMU process uses
    pub balloon_rss_kib: Option<u64>,
    /// KiB, as the guest's balloon driver reports (needs the driver)
    pub balloon_available_kib: Option<u64>,
    pub balloon_unused_kib: Option<u64>,
    pub balloon_usable_kib: Option<u64>,
    pub blocks: Vec<VirtBlockStats>,
    pub nets: Vec<VirtNetStats>,
}

/// One `Domain: '<name>'` record of `domstats --raw`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtStatsRecord {
    pub name: String,
    pub state_code: Option<i32>,
    pub reason_code: Option<i32>,
    pub vcpu_current: Option<u32>,
    pub vcpu_max: Option<u32>,
    /// KiB
    pub mem_current_kib: Option<u64>,
    /// KiB
    pub mem_max_kib: Option<u64>,
    pub counters: VirtCounters,
}

/// One guest in the overview.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtDomain {
    pub uuid: String,
    pub name: String,
    pub state: VirtState,
    /// Raw `virDomainState`; -1 when `domstats` did not report the domain
    pub state_code: i32,
    pub reason_code: i32,
    /// [`reason_name`] of the two above
    pub reason: String,
    pub autostart: bool,
    /// Defined (survives shutdown), as opposed to transient
    pub persistent: bool,
    pub vcpu_current: Option<u32>,
    pub vcpu_max: Option<u32>,
    /// Current balloon size, KiB
    pub mem_current_kib: Option<u64>,
    /// Maximum memory, KiB
    pub mem_max_kib: Option<u64>,
    pub counters: VirtCounters,
}

/// What [`overview_script`] yields.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtOverview {
    /// `None` when `virsh version` failed while the listing did not
    pub version: Option<VirtVersion>,
    /// In `virsh list` order: running ones by ID, then the rest by name
    pub domains: Vec<VirtDomain>,
}

/// `<disk>` in the domain XML.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtDisk {
    /// `disk`, `cdrom`, `floppy`, `lun`
    pub device: String,
    /// Source kind: `file`, `block`, `network`, `volume`, ...
    pub source_type: Option<String>,
    /// File path, block device, `pool/volume`, or `protocol:name` for network
    /// disks; `None` for an empty drive
    pub source: Option<String>,
    pub target: Option<String>,
    pub bus: Option<String>,
    /// Image format from `<driver type=…>`, e.g. `qcow2`
    pub format: Option<String>,
    pub readonly: bool,
}

/// `<interface>` in the domain XML.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtNic {
    /// `network`, `bridge`, `direct`, `user`, ...
    pub kind: String,
    pub mac: Option<String>,
    /// Network name, bridge name, or host device, by `kind`
    pub source: Option<String>,
    pub model: Option<String>,
    /// Host-side device (`vnetN`) while running: the name `domstats` uses
    pub target: Option<String>,
}

/// `<graphics>` in the domain XML.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtGraphics {
    /// `vnc`, `spice`, `rdp`, `dbus`, ...
    pub kind: String,
    /// TCP port; `None` while not running with autoport (`-1`) or when it
    /// listens on a socket
    pub port: Option<u16>,
    pub tls_port: Option<u16>,
    pub autoport: bool,
    /// `listen=` or `<listen address=…>`
    pub listen: Option<String>,
    /// `<listen type='socket' socket=…>`
    pub socket: Option<String>,
}

/// The part of `dumpxml` the app shows.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtDomainXml {
    pub name: Option<String>,
    pub uuid: Option<String>,
    pub title: Option<String>,
    pub description: Option<String>,
    /// `<os><type arch=…>`
    pub arch: Option<String>,
    /// `<os><type machine=…>`
    pub machine: Option<String>,
    pub disks: Vec<VirtDisk>,
    pub nics: Vec<VirtNic>,
    pub graphics: Vec<VirtGraphics>,
    /// A `<serial>` or `<console>` device exists, so `virsh console` has
    /// something to attach to
    pub has_serial_console: bool,
}

/// `domdisplay` URI, parsed.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtDisplay {
    /// As printed, e.g. `vnc://localhost:0`
    pub uri: String,
    /// `vnc`, `spice`, `rdp`, `dbus`
    pub protocol: String,
    /// Host on the hypervisor's side; `localhost` means the hypervisor itself
    pub host: Option<String>,
    /// TCP port. virsh prints a VNC *display* number, converted back here
    pub port: Option<u16>,
    pub tls_port: Option<u16>,
    /// `vnc+unix://` / `spice+unix://`
    pub socket: Option<String>,
}

/// What [`domain_detail_script`] yields.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtDomainDetail {
    /// `None` when the domain is not running or has no graphics
    pub display: Option<VirtDisplay>,
    pub xml: VirtDomainXml,
}

// ---------------------------------------------------------------------------
// Parsers: individual commands
// ---------------------------------------------------------------------------

/// `virsh version`.
pub fn parse_version(raw: &str) -> Option<VirtVersion> {
    let mut v = VirtVersion::default();
    for line in raw.lines() {
        let Some((key, value)) = line.split_once(':') else {
            continue;
        };
        let mut words = value.split_whitespace();
        match key.trim() {
            "Using library" => {
                // `libvirt 10.0.0`
                v.libvirt = words.nth(1).map(str::to_string);
            }
            "Running hypervisor" => {
                let parts: Vec<&str> = words.collect();
                if let Some((ver, name)) = parts.split_last() {
                    v.hypervisor_version = Some((*ver).to_string());
                    if !name.is_empty() {
                        v.hypervisor = Some(name.join(" "));
                    }
                }
            }
            _ => {}
        }
    }
    (v != VirtVersion::default()).then_some(v)
}

fn is_uuid(s: &str) -> bool {
    s.len() == 36
        && s.bytes().enumerate().all(|(i, b)| match i {
            8 | 13 | 18 | 23 => b == b'-',
            _ => b.is_ascii_hexdigit(),
        })
}

/// `list --uuid --name`: `(uuid, name)` in order. The name is everything
/// after the separating space, trailing padding included (libvirt < 7.0
/// padded it — see the module docs on joining).
pub fn parse_uuid_names(raw: &str) -> Vec<(String, String)> {
    raw.lines()
        .filter_map(|line| {
            let line = line.strip_suffix('\r').unwrap_or(line);
            let uuid = line.get(..36)?;
            if !is_uuid(uuid) {
                return None;
            }
            let name = line[36..].strip_prefix(' ')?;
            (!name.trim().is_empty()).then(|| (uuid.to_ascii_lowercase(), name.to_string()))
        })
        .collect()
}

/// `list --uuid`: one UUID per line.
pub fn parse_uuids(raw: &str) -> Vec<String> {
    raw.lines()
        .map(str::trim)
        .filter(|l| is_uuid(l))
        .map(str::to_ascii_lowercase)
        .collect()
}

/// `domstats --raw`.
pub fn parse_domstats(raw: &str) -> Vec<VirtStatsRecord> {
    let mut out: Vec<VirtStatsRecord> = Vec::new();
    for line in raw.lines() {
        let line = line.strip_suffix('\r').unwrap_or(line);
        if let Some(rest) = line.strip_prefix("Domain: '") {
            // The name is printed unescaped, so it may contain quotes; only
            // the last one closes it
            let name = rest.strip_suffix('\'').unwrap_or(rest);
            out.push(VirtStatsRecord {
                name: name.to_string(),
                ..Default::default()
            });
            continue;
        }
        let Some(rec) = out.last_mut() else { continue };
        let Some((key, value)) = line.trim().split_once('=') else {
            continue;
        };
        apply_stat(rec, key, value);
    }
    out
}

fn apply_stat(rec: &mut VirtStatsRecord, key: &str, value: &str) {
    let u = || value.trim().parse::<u64>().ok();
    let c = &mut rec.counters;
    match key {
        "state.state" => rec.state_code = value.trim().parse().ok(),
        "state.reason" => rec.reason_code = value.trim().parse().ok(),
        "cpu.time" => c.cpu_time_ns = u(),
        "cpu.user" => c.cpu_user_ns = u(),
        "cpu.system" => c.cpu_system_ns = u(),
        "balloon.current" => rec.mem_current_kib = u(),
        "balloon.maximum" => rec.mem_max_kib = u(),
        "balloon.rss" => c.balloon_rss_kib = u(),
        "balloon.available" => c.balloon_available_kib = u(),
        "balloon.unused" => c.balloon_unused_kib = u(),
        "balloon.usable" => c.balloon_usable_kib = u(),
        "vcpu.current" => rec.vcpu_current = value.trim().parse().ok(),
        "vcpu.maximum" => rec.vcpu_max = value.trim().parse().ok(),
        _ => {
            if let Some(rest) = key.strip_prefix("block.") {
                if let Some((i, field)) = indexed(rest) {
                    let b = slot(&mut c.blocks, i);
                    match field {
                        "name" => b.name = value.to_string(),
                        "path" => b.path = Some(value.to_string()),
                        "rd.bytes" => b.rd_bytes = u(),
                        "wr.bytes" => b.wr_bytes = u(),
                        "rd.reqs" => b.rd_reqs = u(),
                        "wr.reqs" => b.wr_reqs = u(),
                        "capacity" => b.capacity = u(),
                        "allocation" => b.allocation = u(),
                        "physical" => b.physical = u(),
                        _ => {}
                    }
                }
            } else if let Some(rest) = key.strip_prefix("net.")
                && let Some((i, field)) = indexed(rest)
            {
                let n = slot(&mut c.nets, i);
                match field {
                    "name" => n.name = value.to_string(),
                    "rx.bytes" => n.rx_bytes = u(),
                    "tx.bytes" => n.tx_bytes = u(),
                    "rx.pkts" => n.rx_pkts = u(),
                    "tx.pkts" => n.tx_pkts = u(),
                    _ => {}
                }
            }
        }
    }
}

/// `3.rd.bytes` → `(3, "rd.bytes")`; `count` and other non-indexed keys → None.
fn indexed(rest: &str) -> Option<(usize, &str)> {
    let (i, field) = rest.split_once('.')?;
    // An absurd index would allocate that many slots
    i.parse().ok().filter(|&i| i < 4096).map(|i| (i, field))
}

fn slot<T: Default>(v: &mut Vec<T>, i: usize) -> &mut T {
    if v.len() <= i {
        v.resize_with(i + 1, T::default);
    }
    &mut v[i]
}

/// `domdisplay` output. `None` for anything that is not a display URI.
pub fn parse_display(raw: &str) -> Option<VirtDisplay> {
    let uri = raw.lines().map(str::trim).find(|l| l.contains("://"))?;
    let (scheme, rest) = uri.split_once("://")?;
    let (protocol, unix) = match scheme.strip_suffix("+unix") {
        Some(p) => (p, true),
        None => (scheme, false),
    };
    let (addr, query) = rest.split_once('?').unwrap_or((rest, ""));
    let tls_port = query
        .split('&')
        .find_map(|kv| kv.strip_prefix("tls-port="))
        .and_then(|p| p.parse().ok());
    let mut display = VirtDisplay {
        uri: uri.to_string(),
        protocol: protocol.to_string(),
        tls_port,
        ..Default::default()
    };
    if unix {
        display.socket = Some(addr.to_string()).filter(|s| !s.is_empty());
        return Some(display);
    }
    // A VNC password is printed as `:<pw>@` only with --include-password,
    // which these scripts never pass; drop it regardless
    let addr = addr.rsplit_once('@').map_or(addr, |(_, a)| a);
    let (host, port) = if let Some(v6) = addr.strip_prefix('[') {
        let (h, tail) = v6.split_once(']')?;
        (h, tail.strip_prefix(':'))
    } else {
        match addr.rsplit_once(':') {
            Some((h, p)) => (h, Some(p)),
            None => (addr, None),
        }
    };
    display.host = Some(host.to_string()).filter(|h| !h.is_empty());
    display.port = port.and_then(|p| p.parse::<i32>().ok()).and_then(|p| {
        // virsh prints `port - 5900` for VNC
        let p = if protocol == "vnc" { p + 5900 } else { p };
        u16::try_from(p).ok().filter(|&p| p > 0)
    });
    Some(display)
}

/// `dumpxml` subset.
pub fn parse_domain_xml(raw: &str) -> Result<VirtDomainXml, VirtError> {
    let start = raw.find("<domain").ok_or_else(|| VirtError::Malformed {
        message: "no <domain> element in dumpxml output".into(),
    })?;
    let doc = roxmltree::Document::parse(raw[start..].trim_end()).map_err(|e| {
        VirtError::Malformed {
            message: format!("dumpxml: {e}"),
        }
    })?;
    let root = doc.root_element();
    let text = |name: &str| {
        child(root, name)
            .and_then(|n| n.text())
            .map(|t| t.trim().to_string())
            .filter(|t| !t.is_empty())
    };
    let attr = |n: roxmltree::Node<'_, '_>, a: &str| n.attribute(a).map(str::to_string);

    let mut xml = VirtDomainXml {
        name: text("name"),
        uuid: text("uuid"),
        title: text("title"),
        description: text("description"),
        ..Default::default()
    };
    if let Some(ty) = child(root, "os").and_then(|os| child(os, "type")) {
        xml.arch = attr(ty, "arch");
        xml.machine = attr(ty, "machine");
    }
    let Some(devices) = child(root, "devices") else {
        return Ok(xml);
    };
    for dev in devices.children().filter(|n| n.is_element()) {
        match dev.tag_name().name() {
            "disk" => {
                let source_type = attr(dev, "type");
                let source = child(dev, "source").and_then(|s| {
                    s.attribute("file")
                        .or_else(|| s.attribute("dev"))
                        .or_else(|| s.attribute("dir"))
                        .map(str::to_string)
                        .or_else(|| {
                            let pool = s.attribute("pool")?;
                            let vol = s.attribute("volume")?;
                            Some(format!("{pool}/{vol}"))
                        })
                        .or_else(|| {
                            let name = s.attribute("name")?;
                            Some(match s.attribute("protocol") {
                                Some(p) => format!("{p}:{name}"),
                                None => name.to_string(),
                            })
                        })
                });
                let target = child(dev, "target");
                xml.disks.push(VirtDisk {
                    device: attr(dev, "device").unwrap_or_else(|| "disk".into()),
                    source_type,
                    source,
                    target: target.and_then(|t| attr(t, "dev")),
                    bus: target.and_then(|t| attr(t, "bus")),
                    format: child(dev, "driver").and_then(|d| attr(d, "type")),
                    readonly: child(dev, "readonly").is_some(),
                });
            }
            "interface" => {
                let source = child(dev, "source").and_then(|s| {
                    s.attribute("network")
                        .or_else(|| s.attribute("bridge"))
                        .or_else(|| s.attribute("dev"))
                        .map(str::to_string)
                });
                xml.nics.push(VirtNic {
                    kind: attr(dev, "type").unwrap_or_default(),
                    mac: child(dev, "mac").and_then(|m| attr(m, "address")),
                    source,
                    model: child(dev, "model").and_then(|m| attr(m, "type")),
                    target: child(dev, "target").and_then(|t| attr(t, "dev")),
                });
            }
            "graphics" => {
                let listen_el = child(dev, "listen");
                let port = |a: &str| {
                    dev.attribute(a)
                        .and_then(|p| p.parse::<i32>().ok())
                        .and_then(|p| u16::try_from(p).ok())
                        .filter(|&p| p > 0)
                };
                xml.graphics.push(VirtGraphics {
                    kind: attr(dev, "type").unwrap_or_default(),
                    port: port("port"),
                    tls_port: port("tlsPort"),
                    autoport: dev.attribute("autoport") == Some("yes"),
                    listen: attr(dev, "listen")
                        .or_else(|| listen_el.and_then(|l| attr(l, "address"))),
                    socket: attr(dev, "socket").or_else(|| {
                        listen_el
                            .filter(|l| l.attribute("type") == Some("socket"))
                            .and_then(|l| attr(l, "socket"))
                    }),
                });
            }
            "serial" | "console" => xml.has_serial_console = true,
            _ => {}
        }
    }
    Ok(xml)
}

fn child<'a, 'i>(parent: roxmltree::Node<'a, 'i>, name: &str) -> Option<roxmltree::Node<'a, 'i>> {
    parent
        .children()
        .find(|n| n.is_element() && n.tag_name().name() == name)
}

// ---------------------------------------------------------------------------
// Parsers: script output
// ---------------------------------------------------------------------------

/// Container types [`parse_probe`] reports, as the detectors print them
/// (lowercased). Anything else they may print — `none`, a hypervisor name
/// from `openrc --sys` such as `xen0` — is not a container.
const CONTAINER_KINDS: &[&str] = &[
    "lxc",
    "lxc-libvirt",
    "docker",
    "podman",
    "systemd-nspawn",
    "openvz",
    "rkt",
    "wsl",
    "proot",
    "container-other",
];

/// [`probe_script`]'s output.
///
/// `Err` only for what stops libvirt being asked on a server that has it —
/// the daemon refusing this user, or not answering — so the caller can
/// retry with sudo. No `virsh` is `Ok` with [`VirtHostProbe::libvirt`] unset.
pub fn parse_probe(raw: &str) -> Result<VirtHostProbe, VirtError> {
    let segs = script::parse_script_segments(raw);
    let body = |key: &str| segs.iter().find(|(k, _)| k == key).map(|(_, v)| v.as_str());
    if let Some(pve) = body(KEY_PVE) {
        let line = pve.lines().map(str::trim).find(|l| !l.is_empty());
        return Ok(VirtHostProbe {
            pve: Some(line.unwrap_or_default().to_string()),
            ..Default::default()
        });
    }
    let container = body(KEY_CONTAINER).and_then(|b| {
        b.lines()
            .map(|l| l.trim().to_ascii_lowercase())
            .find(|l| CONTAINER_KINDS.contains(&l.as_str()))
    });
    let libvirt = match sections(raw) {
        Err(VirtError::NotInstalled) => None,
        Err(e) => return Err(e),
        Ok(secs) => {
            let body = take(&secs, KEY_VERSION, raw)?.ok()?;
            Some(parse_version(body).ok_or_else(|| VirtError::Malformed {
                message: format!("unrecognised virsh version output: {}", body.trim()),
            })?)
        }
    };
    Ok(VirtHostProbe {
        pve: None,
        container,
        libvirt,
    })
}

/// [`overview_script`]'s output.
pub fn parse_overview(raw: &str) -> Result<VirtOverview, VirtError> {
    let secs = sections(raw)?;
    let list = parse_uuid_names(take(&secs, KEY_LIST, raw)?.ok()?);
    let autostart = parse_uuids(take(&secs, KEY_AUTOSTART, raw)?.ok()?);
    let persistent = parse_uuids(take(&secs, KEY_PERSISTENT, raw)?.ok()?);
    let stats = parse_domstats(take(&secs, KEY_STATS, raw)?.ok()?);
    let version = secs
        .iter()
        .find(|(k, _)| k == KEY_VERSION)
        .and_then(|(_, s)| s.ok().ok())
        .and_then(parse_version);

    let domains = list
        .into_iter()
        .map(|(uuid, listed)| {
            let rec = stats
                .iter()
                .find(|r| r.name == listed)
                .or_else(|| stats.iter().find(|r| r.name.trim_end() == listed.trim_end()));
            let name = rec.map_or_else(|| listed.trim_end().to_string(), |r| r.name.clone());
            let (state_code, reason_code) = rec
                .and_then(|r| Some((r.state_code?, r.reason_code.unwrap_or(0))))
                .unwrap_or((-1, 0));
            VirtDomain {
                autostart: autostart.contains(&uuid),
                persistent: persistent.contains(&uuid),
                uuid,
                name,
                state: VirtState::from_libvirt(state_code, reason_code),
                state_code,
                reason_code,
                reason: reason_name(state_code, reason_code).to_string(),
                vcpu_current: rec.and_then(|r| r.vcpu_current),
                vcpu_max: rec.and_then(|r| r.vcpu_max),
                mem_current_kib: rec.and_then(|r| r.mem_current_kib),
                mem_max_kib: rec.and_then(|r| r.mem_max_kib),
                counters: rec.map(|r| r.counters.clone()).unwrap_or_default(),
            }
        })
        .collect();
    Ok(VirtOverview { version, domains })
}

/// [`domain_detail_script`]'s output.
pub fn parse_domain_detail(raw: &str) -> Result<VirtDomainDetail, VirtError> {
    let secs = sections(raw)?;
    let xml = parse_domain_xml(take(&secs, KEY_XML, raw)?.ok()?)?;
    // A shut-off domain or one without graphics fails `domdisplay`; that is
    // "no display", not a failure. Anything that is a real failure has failed
    // `dumpxml` above as well.
    let display = match take(&secs, KEY_DISPLAY, raw)?.ok() {
        Ok(body) => parse_display(body),
        Err(VirtError::PermissionDenied { message }) => {
            return Err(VirtError::PermissionDenied { message });
        }
        Err(_) => None,
    };
    Ok(VirtDomainDetail { display, xml })
}

/// [`action_script`]'s output.
pub fn parse_action(raw: &str) -> Result<(), VirtError> {
    let secs = sections(raw)?;
    take(&secs, KEY_ACTION, raw)?.ok().map(|_| ())
}

// ---------------------------------------------------------------------------
// Loops over what virsh lists
// ---------------------------------------------------------------------------

/// Runs `body` once per line `virsh <list_args>` prints, with the line in
/// `$<var>`. The listing's own failure is reported by a section of its own
/// elsewhere in the script, so it is silent here. Every name reaches `body`
/// as one line: libvirt names cannot contain a newline.
fn each(list_args: &str, var: &str, body: &str) -> String {
    format!(
        "virsh --connect {CONNECT_URI} -q {list_args} </dev/null 2>/dev/null | \
         while IFS= read -r {var}; do [ -n \"${var}\" ] || continue\n{body}done\n"
    )
}

/// A section for one item of a loop: the marker, the item on the section's
/// first line, then the `virsh` call. The first line is how the parser knows
/// which item the output is about.
fn item_section(key: &str, var: &str, virsh_args: &str) -> String {
    format!(
        "echo '{}'\nprintf '%s\\n' \"${var}\"\nV {virsh_args}\n",
        script::cmd_marker(key)
    )
}

/// Splits an [`item_section`]'s body into its item and the `virsh` output.
fn split_item(body: &str) -> (&str, &str) {
    match body.split_once('\n') {
        Some((item, rest)) => (item.strip_suffix('\r').unwrap_or(item), rest),
        None => (body, ""),
    }
}

/// `--name` listings: one name per line, empty lines dropped.
pub fn parse_names(raw: &str) -> Vec<String> {
    raw.lines()
        .map(|l| l.strip_suffix('\r').unwrap_or(l))
        .filter(|l| !l.trim().is_empty())
        .map(str::to_string)
        .collect()
}

fn all_items<'a>(secs: &'a [(String, Section)], key: &str) -> impl Iterator<Item = &'a Section> {
    secs.iter().filter(move |(k, _)| k == key).map(|(_, s)| s)
}

/// A value element with `unit='bytes'` (what libvirt prints for pools and
/// volumes), or another unit converted to bytes.
fn bytes_of(node: Option<roxmltree::Node<'_, '_>>) -> Option<u64> {
    let node = node?;
    let n: u64 = node.text()?.trim().parse().ok()?;
    let mul: u64 = match node.attribute("unit").unwrap_or("bytes") {
        "b" | "bytes" => 1,
        "KB" => 1_000,
        "k" | "KiB" => 1 << 10,
        "MB" => 1_000_000,
        "M" | "MiB" => 1 << 20,
        "GB" => 1_000_000_000,
        "G" | "GiB" => 1 << 30,
        "TB" => 1_000_000_000_000,
        "T" | "TiB" => 1 << 40,
        _ => return None,
    };
    n.checked_mul(mul)
}

fn parse_xml_doc<'i>(raw: &'i str, root: &str, what: &str) -> Result<roxmltree::Document<'i>, VirtError> {
    let start = raw.find(&format!("<{root}")).ok_or_else(|| VirtError::Malformed {
        message: format!("no <{root}> element in {what} output"),
    })?;
    roxmltree::Document::parse(raw[start..].trim_end()).map_err(|e| VirtError::Malformed {
        message: format!("{what}: {e}"),
    })
}

fn text_of(parent: roxmltree::Node<'_, '_>, name: &str) -> Option<String> {
    child(parent, name)
        .and_then(|n| n.text())
        .map(|t| t.trim().to_string())
        .filter(|t| !t.is_empty())
}

// ---------------------------------------------------------------------------
// Snapshots
// ---------------------------------------------------------------------------

pub const KEY_SNAP_CURRENT: &str = "virt.snap.current";
pub const KEY_SNAP_LIST: &str = "virt.snap.list";
pub const KEY_SNAP_XML: &str = "virt.snap.xml";

/// One snapshot of a domain, from `snapshot-dumpxml`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtSnapshotInfo {
    pub name: String,
    pub description: Option<String>,
    pub parent: Option<String>,
    /// The domain's state when it was taken: `running`, `paused`, `shutoff`,
    /// or `disk-snapshot` for an external disk-only one
    pub state: Option<String>,
    /// Seconds since the epoch
    pub creation_time: Option<i64>,
    /// Holds the guest's memory, so reverting resumes it where it was
    pub memory: bool,
    /// Any part of it is kept outside the disk image (`snapshot='external'`)
    pub external: bool,
    /// The snapshot the domain's disks were last created from or reverted to
    pub current: bool,
}

/// Every snapshot of one domain, as [`snapshots_script`] reads them.
pub fn snapshots_script(domain: &str) -> String {
    let d = domain_arg(domain);
    let mut s = prelude();
    s.push_str(&section(KEY_SNAP_CURRENT, &format!("snapshot-current {d} --name")));
    s.push_str(&section(KEY_SNAP_LIST, &format!("snapshot-list {d} --name")));
    s.push_str(&each(
        &format!("snapshot-list {d} --name"),
        "s",
        &item_section(KEY_SNAP_XML, "s", &format!("snapshot-dumpxml {d} --snapshotname \"$s\"")),
    ));
    s
}

/// `snapshot-create-as`: an internal snapshot, which on a running or paused
/// domain includes its memory (QEMU refuses an internal one without it) and
/// on a shut-off one holds the disks only. Every writable disk must be qcow2.
/// Parse with [`parse_action`].
pub fn snapshot_create_script(domain: &str, name: &str, description: Option<&str>) -> String {
    let mut args = format!(
        "snapshot-create-as {} --name {}",
        domain_arg(domain),
        shell_quote_unix(name)
    );
    if let Some(desc) = description.filter(|d| !d.trim().is_empty()) {
        args.push_str(&format!(" --description {}", shell_quote_unix(desc)));
    }
    let mut s = prelude();
    s.push_str(&section(KEY_ACTION, &args));
    s
}

/// `snapshot-revert`. A snapshot without memory leaves the domain shut off
/// (a running one is stopped); `running` starts it afterwards instead.
/// Parse with [`parse_action`].
pub fn snapshot_revert_script(domain: &str, name: &str, running: bool) -> String {
    let mut s = prelude();
    s.push_str(&section(
        KEY_ACTION,
        &format!(
            "snapshot-revert {} --snapshotname {}{}",
            domain_arg(domain),
            shell_quote_unix(name),
            if running { " --running" } else { "" }
        ),
    ));
    s
}

/// `snapshot-delete`: the snapshot only; its children move up to its parent.
/// Parse with [`parse_action`].
pub fn snapshot_delete_script(domain: &str, name: &str) -> String {
    let mut s = prelude();
    s.push_str(&section(
        KEY_ACTION,
        &format!(
            "snapshot-delete {} --snapshotname {}",
            domain_arg(domain),
            shell_quote_unix(name)
        ),
    ));
    s
}

/// `snapshot-dumpxml`. The embedded `<domain>` is ignored.
pub fn parse_snapshot_xml(raw: &str) -> Result<VirtSnapshotInfo, VirtError> {
    let doc = parse_xml_doc(raw, "domainsnapshot", "snapshot-dumpxml")?;
    let root = doc.root_element();
    let name = text_of(root, "name").ok_or_else(|| VirtError::Malformed {
        message: "snapshot without a name".into(),
    })?;
    let state = text_of(root, "state");
    let memory_attr = child(root, "memory").and_then(|m| m.attribute("snapshot"));
    let disks: Vec<&str> = child(root, "disks")
        .map(|d| {
            d.children()
                .filter(|n| n.is_element() && n.tag_name().name() == "disk")
                .filter_map(|n| n.attribute("snapshot"))
                .collect()
        })
        .unwrap_or_default();
    // Before `<memory>` existed (libvirt < 1.0.1) a snapshot of an active
    // domain always held its memory.
    let memory = match memory_attr {
        Some(m) => m != "no",
        None => matches!(state.as_deref(), Some("running" | "paused" | "blocked")),
    };
    Ok(VirtSnapshotInfo {
        description: text_of(root, "description"),
        parent: child(root, "parent").and_then(|p| text_of(p, "name")),
        creation_time: text_of(root, "creationTime").and_then(|t| t.parse().ok()),
        external: memory_attr == Some("external") || disks.contains(&"external"),
        memory,
        state,
        name,
        current: false,
    })
}

/// [`snapshots_script`]'s output, in `snapshot-list` order.
///
/// A snapshot deleted between the listing and its `snapshot-dumpxml` is left
/// out rather than failing the rest.
pub fn parse_snapshots(raw: &str) -> Result<Vec<VirtSnapshotInfo>, VirtError> {
    let secs = sections(raw)?;
    let names = parse_names(take(&secs, KEY_SNAP_LIST, raw)?.ok()?);
    // "the domain does not have a current snapshot" is a failure of its own,
    // and means none.
    let current = secs
        .iter()
        .find(|(k, _)| k == KEY_SNAP_CURRENT)
        .and_then(|(_, s)| s.ok().ok())
        .map(|b| b.trim().to_string())
        .filter(|b| !b.is_empty());
    let mut infos: Vec<VirtSnapshotInfo> = Vec::new();
    for sec in all_items(&secs, KEY_SNAP_XML) {
        let body = match sec.ok() {
            Ok(b) => split_item(b).1,
            Err(e @ VirtError::PermissionDenied { .. }) => return Err(e),
            Err(_) => continue,
        };
        if let Ok(info) = parse_snapshot_xml(body) {
            infos.push(info);
        }
    }
    let mut out = Vec::with_capacity(names.len());
    for name in names {
        let Some(at) = infos.iter().position(|i| i.name == name) else {
            continue;
        };
        let mut info = infos.swap_remove(at);
        info.current = current.as_deref() == Some(info.name.as_str());
        out.push(info);
    }
    Ok(out)
}

// ---------------------------------------------------------------------------
// Storage pools and volumes
// ---------------------------------------------------------------------------

pub const KEY_POOLS: &str = "virt.pools";
pub const KEY_POOLS_ACTIVE: &str = "virt.pools.active";
pub const KEY_POOLS_AUTOSTART: &str = "virt.pools.autostart";
pub const KEY_POOL_XML: &str = "virt.pool.xml";
pub const KEY_POOL_VOLS: &str = "virt.pool.vols";
pub const KEY_DOMAINS: &str = "virt.domains";
pub const KEY_BLKLIST: &str = "virt.blklist";
pub const KEY_VOL_XML: &str = "virt.vol.xml";

/// A volume as `vol-list` names it.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtVolumeRef {
    pub name: String,
    pub path: Option<String>,
}

/// One storage pool.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtPool {
    pub name: String,
    pub uuid: Option<String>,
    /// `dir`, `fs`, `netfs`, `logical`, `disk`, `iscsi`, `rbd`, `zfs`, ...
    pub pool_type: Option<String>,
    pub active: bool,
    pub autostart: bool,
    /// Bytes. An inactive pool reports what it last knew, often 0
    pub capacity: Option<u64>,
    pub allocation: Option<u64>,
    pub available: Option<u64>,
    /// `<target><path>`: the directory or device directory volumes are in
    pub target: Option<String>,
    /// Where the pool comes from: `host:/dir` for NFS, the device, the volume
    /// group or the Ceph pool
    pub source: Option<String>,
    /// `None` when the volumes could not be listed (an inactive pool)
    pub volumes: Option<Vec<VirtVolumeRef>>,
}

/// One disk of one domain, from `domblklist --details`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtDiskUse {
    pub domain: String,
    /// `file`, `block`, `network`, `volume`
    pub kind: String,
    /// `disk`, `cdrom`, ...
    pub device: String,
    pub target: String,
    /// `None` for an empty drive
    pub source: Option<String>,
}

/// What [`storage_script`] yields.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtStorage {
    pub pools: Vec<VirtPool>,
    /// Every domain's disks, for "which guest uses this volume"
    pub disks: Vec<VirtDiskUse>,
}

/// One volume, from `vol-dumpxml`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtVolume {
    pub name: String,
    /// `file`, `block`, `dir`, `network`, ...
    pub vol_type: Option<String>,
    pub path: Option<String>,
    /// `qcow2`, `raw`, `iso`, ...
    pub format: Option<String>,
    /// Bytes: the size the guest sees
    pub capacity: Option<u64>,
    /// Bytes the volume takes on the host
    pub allocation: Option<u64>,
    /// A qcow2 overlay's backing file
    pub backing: Option<String>,
}

/// `vol-list` with its header line, not `-q`: the header is where the Path
/// column starts, which is the only way to tell a name containing spaces from
/// the path after it.
fn vol_list_prelude() -> String {
    format!(
        "L() {{ virsh --connect {CONNECT_URI} \"$@\" </dev/null 2>&1; printf '\\n{RC_PREFIX}%s\\n' \"$?\"; }}\n"
    )
}

/// Pools, their volumes' names, and every domain's disks, in one round trip.
/// Parse with [`parse_storage`]. What each volume is — its format and sizes —
/// is [`volumes_script`]'s, asked for one pool at a time.
pub fn storage_script() -> String {
    let mut s = prelude();
    s.push_str(&vol_list_prelude());
    s.push_str(&section(KEY_POOLS, "pool-list --all --name"));
    s.push_str(&section(KEY_POOLS_ACTIVE, "pool-list --name"));
    s.push_str(&section(KEY_POOLS_AUTOSTART, "pool-list --all --autostart --name"));
    s.push_str(&each(
        "pool-list --all --name",
        "p",
        &format!(
            "{}echo '{}'\nprintf '%s\\n' \"$p\"\nL vol-list --pool \"$p\"\n",
            item_section(KEY_POOL_XML, "p", "pool-dumpxml --pool \"$p\""),
            script::cmd_marker(KEY_POOL_VOLS),
        ),
    ));
    s.push_str(&section(KEY_DOMAINS, "list --all --uuid"));
    s.push_str(&each(
        "list --all --uuid",
        "d",
        &item_section(KEY_BLKLIST, "d", "domblklist --details --domain \"$d\""),
    ));
    s
}

/// `vol-dumpxml` for each of `names` in `pool`. Parse with [`parse_volumes`].
pub fn volumes_script(pool: &str, names: &[String]) -> String {
    let p = shell_quote_unix(pool);
    let mut s = prelude();
    for name in names {
        s.push_str(&format!(
            "echo '{}'\nprintf '%s\\n' {n}\nV vol-dumpxml --pool {p} --vol {n}\n",
            script::cmd_marker(KEY_VOL_XML),
            n = shell_quote_unix(name),
        ));
    }
    s
}

/// `pool-dumpxml`.
pub fn parse_pool_xml(raw: &str) -> Result<VirtPool, VirtError> {
    let doc = parse_xml_doc(raw, "pool", "pool-dumpxml")?;
    let root = doc.root_element();
    let source = child(root, "source").and_then(|src| {
        let host = child(src, "host").and_then(|h| h.attribute("name"));
        let dir = child(src, "dir").and_then(|d| d.attribute("path"));
        let device = child(src, "device").and_then(|d| d.attribute("path"));
        let name = text_of(src, "name");
        match (host, dir) {
            (Some(h), Some(d)) => Some(format!("{h}:{d}")),
            (Some(h), None) => Some(match &name {
                Some(n) => format!("{h}/{n}"),
                None => h.to_string(),
            }),
            (None, Some(d)) => Some(d.to_string()),
            (None, None) => name.or_else(|| device.map(str::to_string)),
        }
    });
    Ok(VirtPool {
        name: text_of(root, "name").unwrap_or_default(),
        uuid: text_of(root, "uuid"),
        pool_type: root.attribute("type").map(str::to_string),
        capacity: bytes_of(child(root, "capacity")),
        allocation: bytes_of(child(root, "allocation")),
        available: bytes_of(child(root, "available")),
        target: child(root, "target").and_then(|t| text_of(t, "path")),
        source,
        ..Default::default()
    })
}

/// `vol-list` output with its header (not `-q`).
///
/// virsh pads the Name column to its widest entry, so the Path column starts
/// where the header's `Path` does, on every line. Measured in characters,
/// which is virsh's own measure for anything but double-width script.
pub fn parse_vol_list(raw: &str) -> Vec<VirtVolumeRef> {
    let mut lines = raw.lines().map(|l| l.strip_suffix('\r').unwrap_or(l));
    let Some(header) = lines.by_ref().find(|l| l.trim_start().starts_with("Name")) else {
        return Vec::new();
    };
    let col = header.find("Path").map(|b| header[..b].chars().count());
    let mut out = Vec::new();
    for line in lines {
        if line.trim().is_empty() || line.trim_start().starts_with("---") {
            continue;
        }
        let chars: Vec<char> = line.chars().collect();
        let (name, path) = match col {
            // The column boundary falls on the padding: split there
            Some(c) if c <= chars.len() && (c == 0 || chars[c - 1] == ' ') => {
                let name: String = chars[..c].iter().collect();
                let path: String = chars[c..].iter().collect();
                (name.trim().to_string(), path.trim().to_string())
            }
            // Wider characters moved it: the last run of 2+ spaces instead
            _ => match line.trim().rsplit_once("  ") {
                Some((n, p)) => (n.trim().to_string(), p.trim().to_string()),
                None => (line.trim().to_string(), String::new()),
            },
        };
        if name.is_empty() {
            continue;
        }
        out.push(VirtVolumeRef {
            name,
            path: Some(path).filter(|p| !p.is_empty() && p != "-"),
        });
    }
    out
}

/// `domblklist --details` (with `-q`): `type device target source`, the
/// source last so it may contain spaces; `-` for an empty drive.
pub fn parse_blklist(domain: &str, raw: &str) -> Vec<VirtDiskUse> {
    raw.lines()
        .filter_map(|line| {
            let (fields, rest) = split_fields(line, 3);
            let [kind, device, target] = fields[..] else {
                return None;
            };
            Some(VirtDiskUse {
                domain: domain.to_string(),
                kind: kind.to_string(),
                device: device.to_string(),
                target: target.to_string(),
                source: Some(rest.to_string()).filter(|s| !s.is_empty() && s != "-"),
            })
        })
        .collect()
}

/// The first `n` whitespace-separated fields of `line`, and the rest of it
/// trimmed (which may itself contain spaces).
fn split_fields(line: &str, n: usize) -> (Vec<&str>, &str) {
    let mut fields = Vec::with_capacity(n);
    let mut rest = line.trim();
    while fields.len() < n && !rest.is_empty() {
        let end = rest.find(char::is_whitespace).unwrap_or(rest.len());
        fields.push(&rest[..end]);
        rest = rest[end..].trim_start();
    }
    (fields, rest.trim_end())
}

/// [`storage_script`]'s output.
pub fn parse_storage(raw: &str) -> Result<VirtStorage, VirtError> {
    let secs = sections(raw)?;
    let names = parse_names(take(&secs, KEY_POOLS, raw)?.ok()?);
    let set = |key: &str| -> Vec<String> {
        secs.iter()
            .find(|(k, _)| k == key)
            .and_then(|(_, s)| s.ok().ok())
            .map(parse_names)
            .unwrap_or_default()
    };
    let active = set(KEY_POOLS_ACTIVE);
    let autostart = set(KEY_POOLS_AUTOSTART);

    let mut xmls: Vec<(String, VirtPool)> = Vec::new();
    for sec in all_items(&secs, KEY_POOL_XML) {
        let (item, _) = split_item(&sec.body);
        if let Ok(body) = sec.ok()
            && let Ok(pool) = parse_pool_xml(split_item(body).1)
        {
            xmls.push((item.to_string(), pool));
        }
    }
    let mut vols: Vec<(String, Vec<VirtVolumeRef>)> = Vec::new();
    for sec in all_items(&secs, KEY_POOL_VOLS) {
        let (item, _) = split_item(&sec.body);
        if let Ok(body) = sec.ok() {
            vols.push((item.to_string(), parse_vol_list(split_item(body).1)));
        }
    }

    let pools = names
        .into_iter()
        .map(|name| {
            let mut pool = xmls
                .iter()
                .find(|(n, _)| *n == name)
                .map(|(_, p)| p.clone())
                .unwrap_or_default();
            pool.active = active.contains(&name);
            pool.autostart = autostart.contains(&name);
            pool.volumes = vols
                .iter()
                .find(|(n, _)| *n == name)
                .map(|(_, v)| v.clone());
            pool.name = name;
            pool
        })
        .collect();

    let mut disks = Vec::new();
    for sec in all_items(&secs, KEY_BLKLIST) {
        let (domain, _) = split_item(&sec.body);
        if let Ok(body) = sec.ok() {
            disks.extend(parse_blklist(&domain.to_ascii_lowercase(), split_item(body).1));
        }
    }
    Ok(VirtStorage { pools, disks })
}

/// `vol-dumpxml`.
pub fn parse_volume_xml(raw: &str) -> Result<VirtVolume, VirtError> {
    let doc = parse_xml_doc(raw, "volume", "vol-dumpxml")?;
    let root = doc.root_element();
    let target = child(root, "target");
    Ok(VirtVolume {
        name: text_of(root, "name").unwrap_or_default(),
        vol_type: root.attribute("type").map(str::to_string),
        path: target
            .and_then(|t| text_of(t, "path"))
            .or_else(|| text_of(root, "key")),
        format: target
            .and_then(|t| child(t, "format"))
            .and_then(|f| f.attribute("type"))
            .map(str::to_string),
        capacity: bytes_of(child(root, "capacity")),
        allocation: bytes_of(child(root, "allocation")),
        backing: child(root, "backingStore").and_then(|b| text_of(b, "path")),
    })
}

/// [`volumes_script`]'s output, in the order asked. A volume gone since the
/// listing is left out.
pub fn parse_volumes(raw: &str) -> Result<Vec<VirtVolume>, VirtError> {
    let segs = script::parse_script_segments(raw);
    if segs.iter().any(|(k, _)| k == KEY_MISSING) {
        return Err(VirtError::NotInstalled);
    }
    if segs.is_empty() && !raw.trim().is_empty() {
        return Err(match classify_error(raw.trim()) {
            VirtError::Command { message } => VirtError::Malformed { message },
            other => other,
        });
    }
    let mut out = Vec::new();
    for (key, body) in segs {
        if key != KEY_VOL_XML {
            continue;
        }
        let sec = Section::parse(&body);
        match sec.ok() {
            Ok(b) => {
                if let Ok(v) = parse_volume_xml(split_item(b).1) {
                    out.push(v);
                }
            }
            Err(e @ VirtError::PermissionDenied { .. }) => return Err(e),
            Err(_) => {}
        }
    }
    Ok(out)
}

// ---------------------------------------------------------------------------
// Networks
// ---------------------------------------------------------------------------

pub const KEY_NETS: &str = "virt.nets";
pub const KEY_NETS_ACTIVE: &str = "virt.nets.active";
pub const KEY_NETS_AUTOSTART: &str = "virt.nets.autostart";
pub const KEY_NET_XML: &str = "virt.net.xml";
pub const KEY_LEASES: &str = "virt.net.leases";
pub const KEY_IFLIST: &str = "virt.iflist";

/// One `<ip>` of a network.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtNetIp {
    /// `ipv4` or `ipv6`
    pub family: String,
    /// The host's address on the network with its prefix, e.g.
    /// `192.168.122.1/24`
    pub cidr: String,
    /// `start-end` of each DHCP range
    pub dhcp_ranges: Vec<String>,
}

/// One libvirt virtual network.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtNetworkInfo {
    pub name: String,
    pub uuid: Option<String>,
    pub active: bool,
    pub autostart: bool,
    /// `<forward mode>`: `nat`, `route`, `open`, `bridge`, `passthrough`,
    /// `private`, `vepa`, `hostdev`; `isolated` when there is no `<forward>`
    pub mode: String,
    /// The bridge device: libvirt's own (`virbr0`), or the host bridge a
    /// `bridge`-mode network hands guests to
    pub bridge: Option<String>,
    /// Host devices traffic leaves through (`<forward dev>` / `<interface>`)
    pub forward_devs: Vec<String>,
    pub ips: Vec<VirtNetIp>,
    /// Interfaces attached now (`connections=`), while active
    pub connections: Option<u32>,
}

/// One interface of one domain, from `domiflist`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtIfaceUse {
    pub domain: String,
    /// Host-side device, `None` while the domain is not running
    pub interface: Option<String>,
    /// `network`, `bridge`, `direct`, `user`, ...
    pub kind: String,
    /// Network name, bridge or host device, by `kind`
    pub source: Option<String>,
    pub model: Option<String>,
    pub mac: Option<String>,
}

/// One DHCP lease of a network.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtLease {
    pub network: String,
    pub mac: String,
    /// With its prefix, as virsh prints it
    pub ip: String,
    pub hostname: Option<String>,
}

/// What [`networks_script`] yields.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtNetworks {
    pub networks: Vec<VirtNetworkInfo>,
    pub ifaces: Vec<VirtIfaceUse>,
    pub leases: Vec<VirtLease>,
}

/// Networks, their DHCP leases and every domain's interfaces, in one round
/// trip. Parse with [`parse_networks`].
pub fn networks_script() -> String {
    let mut s = prelude();
    s.push_str(&section(KEY_NETS, "net-list --all --name"));
    s.push_str(&section(KEY_NETS_ACTIVE, "net-list --name"));
    s.push_str(&section(KEY_NETS_AUTOSTART, "net-list --all --autostart --name"));
    s.push_str(&each(
        "net-list --all --name",
        "n",
        &item_section(KEY_NET_XML, "n", "net-dumpxml --network \"$n\""),
    ));
    s.push_str(&each(
        "net-list --name",
        "n",
        &item_section(KEY_LEASES, "n", "net-dhcp-leases --network \"$n\""),
    ));
    s.push_str(&each(
        "list --all --uuid",
        "d",
        &item_section(KEY_IFLIST, "d", "domiflist --domain \"$d\""),
    ));
    s
}

fn prefix_of_netmask(mask: &str) -> Option<u32> {
    let octets: Vec<u8> = mask.split('.').map(|o| o.parse().ok()).collect::<Option<_>>()?;
    if octets.len() != 4 {
        return None;
    }
    let n = u32::from_be_bytes([octets[0], octets[1], octets[2], octets[3]]);
    // Contiguous ones only
    (n.leading_ones() + n.trailing_zeros() == 32).then_some(n.leading_ones())
}

/// `net-dumpxml`.
pub fn parse_network_xml(raw: &str) -> Result<VirtNetworkInfo, VirtError> {
    let doc = parse_xml_doc(raw, "network", "net-dumpxml")?;
    let root = doc.root_element();
    let forward = child(root, "forward");
    let mode = match forward {
        None => "isolated".to_string(),
        Some(f) => f.attribute("mode").unwrap_or("nat").to_string(),
    };
    let mut forward_devs: Vec<String> = Vec::new();
    if let Some(f) = forward {
        if let Some(dev) = f.attribute("dev") {
            forward_devs.push(dev.to_string());
        }
        for i in f.children().filter(|n| n.is_element() && n.tag_name().name() == "interface") {
            if let Some(dev) = i.attribute("dev")
                && !forward_devs.iter().any(|d| d == dev)
            {
                forward_devs.push(dev.to_string());
            }
        }
    }
    let ips = root
        .children()
        .filter(|n| n.is_element() && n.tag_name().name() == "ip")
        .filter_map(|ip| {
            let addr = ip.attribute("address")?;
            let family = ip.attribute("family").unwrap_or(if addr.contains(':') {
                "ipv6"
            } else {
                "ipv4"
            });
            let prefix = ip
                .attribute("prefix")
                .and_then(|p| p.parse::<u32>().ok())
                .or_else(|| ip.attribute("netmask").and_then(prefix_of_netmask));
            let dhcp_ranges = child(ip, "dhcp")
                .map(|d| {
                    d.children()
                        .filter(|n| n.is_element() && n.tag_name().name() == "range")
                        .filter_map(|r| Some(format!("{}-{}", r.attribute("start")?, r.attribute("end")?)))
                        .collect()
                })
                .unwrap_or_default();
            Some(VirtNetIp {
                family: family.to_string(),
                cidr: match prefix {
                    Some(p) => format!("{addr}/{p}"),
                    None => addr.to_string(),
                },
                dhcp_ranges,
            })
        })
        .collect();
    Ok(VirtNetworkInfo {
        name: text_of(root, "name").unwrap_or_default(),
        uuid: text_of(root, "uuid"),
        mode,
        bridge: child(root, "bridge").and_then(|b| b.attribute("name")).map(str::to_string),
        forward_devs,
        ips,
        connections: root.attribute("connections").and_then(|c| c.parse().ok()),
        ..Default::default()
    })
}

/// `domiflist` (with `-q`): `interface type source model mac`, `-` where a
/// value is missing (the interface of a shut-off domain).
pub fn parse_iflist(domain: &str, raw: &str) -> Vec<VirtIfaceUse> {
    let opt = |s: &str| Some(s.to_string()).filter(|s| !s.is_empty() && s != "-");
    raw.lines()
        .filter_map(|line| {
            let t: Vec<&str> = line.split_whitespace().collect();
            if t.len() < 5 {
                return None;
            }
            // A source with spaces in it is everything between type and model
            let source = t[2..t.len() - 2].join(" ");
            Some(VirtIfaceUse {
                domain: domain.to_string(),
                interface: opt(t[0]),
                kind: t[1].to_string(),
                source: opt(&source),
                model: opt(t[t.len() - 2]),
                mac: opt(t[t.len() - 1]).map(|m| m.to_ascii_lowercase()),
            })
        })
        .collect()
}

/// `net-dhcp-leases` (with `-q`): `date time mac protocol ip hostname
/// client-id`.
pub fn parse_leases(network: &str, raw: &str) -> Vec<VirtLease> {
    raw.lines()
        .filter_map(|line| {
            let t: Vec<&str> = line.split_whitespace().collect();
            if t.len() < 6 || !t[2].contains(':') {
                return None;
            }
            Some(VirtLease {
                network: network.to_string(),
                mac: t[2].to_ascii_lowercase(),
                ip: t[4].to_string(),
                hostname: Some(t[5].to_string()).filter(|h| h != "-"),
            })
        })
        .collect()
}

/// [`networks_script`]'s output.
pub fn parse_networks(raw: &str) -> Result<VirtNetworks, VirtError> {
    let secs = sections(raw)?;
    let names = parse_names(take(&secs, KEY_NETS, raw)?.ok()?);
    let set = |key: &str| -> Vec<String> {
        secs.iter()
            .find(|(k, _)| k == key)
            .and_then(|(_, s)| s.ok().ok())
            .map(parse_names)
            .unwrap_or_default()
    };
    let active = set(KEY_NETS_ACTIVE);
    let autostart = set(KEY_NETS_AUTOSTART);
    let mut xmls: Vec<(String, VirtNetworkInfo)> = Vec::new();
    for sec in all_items(&secs, KEY_NET_XML) {
        let (item, _) = split_item(&sec.body);
        if let Ok(body) = sec.ok()
            && let Ok(net) = parse_network_xml(split_item(body).1)
        {
            xmls.push((item.to_string(), net));
        }
    }
    let networks = names
        .into_iter()
        .map(|name| {
            let mut net = xmls
                .iter()
                .find(|(n, _)| *n == name)
                .map(|(_, x)| x.clone())
                .unwrap_or_else(|| VirtNetworkInfo {
                    mode: "isolated".into(),
                    ..Default::default()
                });
            net.active = active.contains(&name);
            net.autostart = autostart.contains(&name);
            if !net.active {
                net.connections = None;
            }
            net.name = name;
            net
        })
        .collect();
    let mut leases = Vec::new();
    for sec in all_items(&secs, KEY_LEASES) {
        let (item, _) = split_item(&sec.body);
        if let Ok(body) = sec.ok() {
            leases.extend(parse_leases(item, split_item(body).1));
        }
    }
    let mut ifaces = Vec::new();
    for sec in all_items(&secs, KEY_IFLIST) {
        let (domain, _) = split_item(&sec.body);
        if let Ok(body) = sec.ok() {
            ifaces.extend(parse_iflist(&domain.to_ascii_lowercase(), split_item(body).1));
        }
    }
    Ok(VirtNetworks {
        networks,
        ifaces,
        leases,
    })
}

// ---------------------------------------------------------------------------
// Creating and deleting domains
// ---------------------------------------------------------------------------

pub const KEY_CAPS: &str = "virt.caps";
pub const KEY_EXISTS: &str = "virt.exists";
pub const KEY_VOL_CREATE: &str = "virt.vol.create";
pub const KEY_VOL_PATH: &str = "virt.vol.path";
pub const KEY_DEFINE: &str = "virt.define";
pub const KEY_ROLLBACK: &str = "virt.rollback";
pub const KEY_UUID: &str = "virt.uuid";
pub const KEY_START: &str = "virt.start";

/// What the host can run a new domain as, from `domcapabilities`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtCreateHost {
    /// `kvm`, or `qemu` (emulation) where `/dev/kvm` is not usable
    pub domain_type: String,
    /// The canonical machine type, e.g. `pc-q35-10.0`
    pub machine: String,
    pub arch: String,
    /// `<vcpu max=…>` for that machine
    pub max_vcpus: Option<u32>,
}

/// The `domcapabilities` asked for, best first: KVM before emulation, q35
/// (PCIe, SATA) before the default `pc`.
const CAPS_TRIES: &[(&str, Option<&str>)] = &[
    ("kvm", Some("q35")),
    ("kvm", None),
    ("qemu", Some("q35")),
    ("qemu", None),
];

/// `domcapabilities` for each of [`CAPS_TRIES`]. Parse with
/// [`parse_create_host`].
pub fn create_host_script() -> String {
    let mut s = prelude();
    for (virttype, machine) in CAPS_TRIES {
        let machine_arg = machine.map(|m| format!(" --machine {m}")).unwrap_or_default();
        s.push_str(&format!(
            "echo '{}'\nprintf '%s\\n' '{virttype}'\nV domcapabilities --virttype {virttype}{machine_arg}\n",
            script::cmd_marker(KEY_CAPS),
        ));
    }
    s
}

/// [`create_host_script`]'s output: the first combination the host accepts.
pub fn parse_create_host(raw: &str) -> Result<VirtCreateHost, VirtError> {
    let secs = sections(raw)?;
    let mut first_err = None;
    for sec in all_items(&secs, KEY_CAPS) {
        let (_, body) = split_item(&sec.body);
        let body = match (Section { body: body.to_string(), rc: sec.rc }).ok() {
            Ok(b) => b.to_string(),
            Err(e) => {
                first_err.get_or_insert(e);
                continue;
            }
        };
        let doc = parse_xml_doc(&body, "domainCapabilities", "domcapabilities")?;
        let root = doc.root_element();
        let text = |name: &str| text_of(root, name);
        if let (Some(domain_type), Some(machine), Some(arch)) = (text("domain"), text("machine"), text("arch")) {
            let max_vcpus = child(root, "vcpu")
                .and_then(|v| v.attribute("max"))
                .and_then(|m| m.parse().ok());
            return Ok(VirtCreateHost { domain_type, machine, arch, max_vcpus });
        }
    }
    Err(first_err.unwrap_or_else(|| VirtError::Malformed {
        message: "no usable domcapabilities".to_string(),
    }))
}

/// A new domain. `host` is [`parse_create_host`]'s answer.
///
/// Created in two steps: [`create_volume_script`] makes the disk and reads
/// its path, then [`define_script`] defines the domain on that path. Disks
/// are named by path rather than by pool and volume (`type='volume'`): on a
/// Debian host with AppArmor, `virt-aa-helper` did not allow QEMU a volume
/// disk, and the domain failed to start with "Permission denied" on its own
/// image (libvirt 11.3, verified).
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtCreateSpec {
    pub name: String,
    pub vcpus: u32,
    pub memory_mib: u64,
    pub host: VirtCreateHost,
    /// The pool the new disk is created in
    pub disk_pool: String,
    pub disk_gib: u64,
    /// `qcow2`, or `raw` where the pool cannot hold qcow2 (LVM, disks)
    pub disk_format: String,
    /// The new disk's path, as [`parse_create_volume`] read it; needed by
    /// [`define_script`] only
    pub disk_path: Option<String>,
    /// Install media, attached as a read-only CD-ROM: its path
    pub cdrom: Option<String>,
    /// A libvirt network for the one NIC; none for no NIC
    pub network: Option<String>,
    pub start: bool,
}

impl VirtCreateSpec {
    /// The new disk's volume name.
    pub fn volume_name(&self) -> String {
        let ext = if self.disk_format == "qcow2" { "qcow2" } else { "img" };
        format!("{}.{ext}", self.name)
    }

    /// Refuses what the host would refuse later, or what would land in a
    /// place it should not: every value here reaches `virsh` or the XML.
    fn check(&self) -> Result<(), VirtError> {
        // Refused before anything runs: the app checks all of this first, so
        // reaching here is a caller's bug, and the message is for the log.
        let bad = |what: &str| {
            Err(VirtError::Malformed {
                message: format!("invalid create spec: {what}"),
            })
        };
        // A domain name is also a volume name (a file in a directory pool):
        // no path separators, no control characters, not a dot file.
        if self.name.is_empty()
            || self.name.len() > 200
            || self.name.starts_with('.')
            || self.name.starts_with('-')
            || self.name.chars().any(|c| c == '/' || c.is_control())
        {
            return bad("name");
        }
        if self.vcpus == 0 || self.vcpus > 4096 {
            return bad("vcpus");
        }
        if self.memory_mib < 16 {
            return bad("memory");
        }
        if self.disk_gib == 0 || self.disk_gib > 1 << 20 {
            return bad("disk size");
        }
        if self.disk_format != "qcow2" && self.disk_format != "raw" {
            return bad("disk format");
        }
        if self.host.domain_type != "kvm" && self.host.domain_type != "qemu" {
            return bad("domain type");
        }
        let token = |s: &str| {
            !s.is_empty() && s.chars().all(|c| c.is_ascii_alphanumeric() || "._-".contains(c))
        };
        if !token(&self.host.machine) || !token(&self.host.arch) {
            return bad("machine");
        }
        if self.disk_pool.is_empty() || self.disk_pool.chars().any(char::is_control) {
            return bad("pool");
        }
        let path = |p: &Option<String>| {
            p.as_deref()
                .is_some_and(|p| !p.starts_with('/') || p.chars().any(char::is_control))
        };
        if path(&self.disk_path) || path(&self.cdrom) {
            return bad("path");
        }
        Ok(())
    }
}

/// `&`, `<`, `>`, `"` and `'` as entities, for text and attribute values
/// alike. Control characters other than tab and newline have no place in
/// XML 1.0 at all; [`VirtCreateSpec::check`] keeps them out of names.
fn xml_escape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '&' => out.push_str("&amp;"),
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '"' => out.push_str("&quot;"),
            '\'' => out.push_str("&apos;"),
            c => out.push(c),
        }
    }
    out
}

/// The domain XML for `spec`.
///
/// Disks by path (see [`VirtCreateSpec`]); `undefine --storage` still finds
/// the volume by it. A serial console so the text console works before the
/// guest has any network; VNC on loopback only, reached through the app's
/// tunnel.
pub fn domain_xml(spec: &VirtCreateSpec) -> String {
    let e = xml_escape;
    let q35 = spec.host.machine.contains("q35");
    let cdrom_bus = if q35 { "sata" } else { "ide" };
    let mut x = String::new();
    x.push_str(&format!("<domain type='{}'>\n", e(&spec.host.domain_type)));
    x.push_str(&format!("  <name>{}</name>\n", e(&spec.name)));
    x.push_str(&format!("  <memory unit='MiB'>{}</memory>\n", spec.memory_mib));
    x.push_str(&format!("  <vcpu>{}</vcpu>\n", spec.vcpus));
    x.push_str("  <os>\n");
    x.push_str(&format!(
        "    <type arch='{}' machine='{}'>hvm</type>\n",
        e(&spec.host.arch),
        e(&spec.host.machine)
    ));
    x.push_str("    <boot dev='hd'/>\n");
    if spec.cdrom.is_some() {
        x.push_str("    <boot dev='cdrom'/>\n");
    }
    x.push_str("  </os>\n");
    x.push_str("  <features><acpi/><apic/></features>\n");
    if spec.host.domain_type == "kvm" {
        x.push_str("  <cpu mode='host-passthrough'/>\n");
    }
    x.push_str("  <clock offset='utc'/>\n");
    x.push_str("  <on_poweroff>destroy</on_poweroff>\n");
    x.push_str("  <on_reboot>restart</on_reboot>\n");
    x.push_str("  <on_crash>destroy</on_crash>\n");
    x.push_str("  <devices>\n");
    x.push_str("    <disk type='file' device='disk'>\n");
    x.push_str(&format!(
        "      <driver name='qemu' type='{}'/>\n",
        e(&spec.disk_format)
    ));
    x.push_str(&format!(
        "      <source file='{}'/>\n",
        e(spec.disk_path.as_deref().unwrap_or_default())
    ));
    x.push_str("      <target dev='vda' bus='virtio'/>\n");
    x.push_str("    </disk>\n");
    if let Some(cd) = &spec.cdrom {
        x.push_str("    <disk type='file' device='cdrom'>\n");
        x.push_str("      <driver name='qemu' type='raw'/>\n");
        x.push_str(&format!("      <source file='{}'/>\n", e(cd)));
        x.push_str(&format!("      <target dev='sda' bus='{cdrom_bus}'/>\n"));
        x.push_str("      <readonly/>\n");
        x.push_str("    </disk>\n");
    }
    if let Some(net) = &spec.network {
        x.push_str("    <interface type='network'>\n");
        x.push_str(&format!("      <source network='{}'/>\n", e(net)));
        x.push_str("      <model type='virtio'/>\n");
        x.push_str("    </interface>\n");
    }
    x.push_str("    <serial type='pty'><target port='0'/></serial>\n");
    x.push_str("    <console type='pty'><target type='serial' port='0'/></console>\n");
    x.push_str("    <input type='tablet' bus='usb'/>\n");
    x.push_str("    <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>\n");
    x.push_str("      <listen type='address' address='127.0.0.1'/>\n");
    x.push_str("    </graphics>\n");
    x.push_str("    <video><model type='virtio'/></video>\n");
    x.push_str("  </devices>\n");
    x.push_str("</domain>\n");
    x
}

fn run_fn() -> String {
    format!(
        "R() {{ virsh --connect {CONNECT_URI} -q \"$@\" </dev/null 2>&1; r=$?; printf '\\n{RC_PREFIX}%s\\n' \"$r\"; }}\n"
    )
}

/// The new domain's disk, and its path. Parse with [`parse_create_volume`].
///
/// A name already defined stops it before anything is created, and so does
/// a volume of that name (`vol-create-as` refuses it): nothing of someone
/// else's is reused. A path that cannot be read deletes the volume again.
pub fn create_volume_script(spec: &VirtCreateSpec) -> Result<String, VirtError> {
    spec.check()?;
    let name = shell_quote_unix(&spec.name);
    let pool = shell_quote_unix(&spec.disk_pool);
    let vol = shell_quote_unix(&spec.volume_name());
    let m = script::cmd_marker;
    let mut s = prelude();
    s.push_str(&run_fn());
    s.push_str(&format!(
        "if virsh --connect {CONNECT_URI} -q domuuid --domain {name} </dev/null >/dev/null 2>&1; then echo '{}'; exit 0; fi\n",
        m(KEY_EXISTS),
    ));
    s.push_str(&format!(
        "echo '{}'\nR vol-create-as --pool {pool} --name {vol} --capacity {}G --format {}\n",
        m(KEY_VOL_CREATE),
        spec.disk_gib,
        spec.disk_format,
    ));
    s.push_str("[ \"$r\" = 0 ] || exit 0\n");
    s.push_str(&format!(
        "echo '{}'\nR vol-path --pool {pool} --vol {vol}\n",
        m(KEY_VOL_PATH)
    ));
    s.push_str(&format!(
        "[ \"$r\" = 0 ] || {{ echo '{}'; R vol-delete --pool {pool} --vol {vol}; }}\n",
        m(KEY_ROLLBACK),
    ));
    Ok(s)
}

/// [`create_volume_script`]'s output: the new volume's path. `Exists` for a
/// name already defined or a volume already there.
pub fn parse_create_volume(raw: &str) -> Result<String, VirtError> {
    let secs = sections(raw)?;
    if secs.iter().any(|(k, _)| k == KEY_EXISTS) {
        return Err(VirtError::Exists { message: String::new() });
    }
    take(&secs, KEY_VOL_CREATE, raw)?.ok()?;
    let path = take(&secs, KEY_VOL_PATH, raw)?.ok()?.trim().to_string();
    if !path.starts_with('/') {
        return Err(VirtError::Malformed {
            message: format!("vol-path printed {path:?}"),
        });
    }
    Ok(path)
}

/// Defines the domain on the volume [`create_volume_script`] made, and
/// starts it when asked. Parse with [`parse_create`].
///
/// A define that fails deletes that volume, so a refused domain leaves
/// nothing behind; a start that fails leaves the domain defined. The XML
/// goes through a temporary file, as `virsh define` wants one: the script is
/// on `sh`'s stdin, which no command here may read.
pub fn define_script(spec: &VirtCreateSpec) -> Result<String, VirtError> {
    spec.check()?;
    if spec.disk_path.is_none() {
        return Err(VirtError::Malformed {
            message: "invalid create spec: no disk path".to_string(),
        });
    }
    let name = shell_quote_unix(&spec.name);
    let pool = shell_quote_unix(&spec.disk_pool);
    let vol = shell_quote_unix(&spec.volume_name());
    let xml = shell_quote_unix(&domain_xml(spec));
    let m = script::cmd_marker;
    let mut s = prelude();
    s.push_str(&run_fn());
    s.push_str(&format!(
        "echo '{define}'\nf=$(mktemp 2>&1) || {{ printf '%s\\n{RC_PREFIX}1\\n' \"$f\"; f=; r=1; }}\n\
         if [ -n \"$f\" ]; then printf '%s' {xml} >\"$f\"; R define --file \"$f\"; rm -f \"$f\"; fi\n",
        define = m(KEY_DEFINE),
    ));
    s.push_str(&format!(
        "if [ \"$r\" != 0 ]; then echo '{}'; R vol-delete --pool {pool} --vol {vol}; exit 0; fi\n",
        m(KEY_ROLLBACK),
    ));
    s.push_str(&format!("echo '{}'\nR domuuid --domain {name}\n", m(KEY_UUID)));
    if spec.start {
        s.push_str(&format!("echo '{}'\nR start --domain {name}\n", m(KEY_START)));
    }
    Ok(s)
}

/// What [`define_script`] did.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct VirtCreated {
    /// The new domain's UUID, when `domuuid` answered
    pub uuid: Option<String>,
    /// Defined, but `start` refused, with virsh's words
    pub start_error: Option<String>,
}

/// [`define_script`]'s output. `Err` when nothing was defined; a volume a
/// failed define could not take back is named in the error.
pub fn parse_create(raw: &str) -> Result<VirtCreated, VirtError> {
    let secs = sections(raw)?;
    if let Err(define) = take(&secs, KEY_DEFINE, raw)?.ok() {
        let left = secs
            .iter()
            .find(|(k, _)| k == KEY_ROLLBACK)
            .and_then(|(_, s)| s.ok().err());
        // The volume left behind is worth knowing about: its own error
        // names it.
        return Err(match left {
            // Refused as this user: sudo runs the whole step again.
            _ if matches!(define, VirtError::PermissionDenied { .. }) => define,
            None => define,
            Some(rollback) => VirtError::Command {
                message: format!("{}\n{}", define.message(), rollback.message()),
            },
        });
    }
    let uuid = secs
        .iter()
        .find(|(k, _)| k == KEY_UUID)
        .and_then(|(_, s)| s.ok().ok())
        .map(str::trim)
        .filter(|u| is_uuid(u))
        .map(str::to_string);
    let start_error = secs
        .iter()
        .find(|(k, _)| k == KEY_START)
        .and_then(|(_, s)| s.ok().err())
        .map(|e| e.message());
    Ok(VirtCreated { uuid, start_error })
}

/// `undefine`, with the metadata a domain may hold (snapshots, a managed
/// save) so they do not refuse it. `storage` are the disk targets whose
/// volumes go with it (`vda`, `sdb`), NVRAM included; empty keeps every
/// volume and the NVRAM file. A running domain is not stopped by this —
/// `undefine` would leave it running, transient — so the caller stops it
/// first. Parse with [`parse_action`].
pub fn undefine_script(domain: &str, storage: &[String]) -> Result<String, VirtError> {
    if storage
        .iter()
        .any(|t| t.is_empty() || !t.chars().all(|c| c.is_ascii_alphanumeric()))
    {
        return Err(VirtError::Malformed {
            message: format!("invalid disk target in {storage:?}"),
        });
    }
    let mut args = format!(
        "undefine {} --managed-save --snapshots-metadata",
        domain_arg(domain)
    );
    if storage.is_empty() {
        args.push_str(" --keep-nvram");
    } else {
        args.push_str(&format!(" --nvram --storage {}", storage.join(",")));
    }
    let mut s = prelude();
    s.push_str(&section(KEY_ACTION, &args));
    Ok(s)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn state_mapping() {
        assert_eq!(VirtState::from_libvirt(1, 1), VirtState::Running);
        assert_eq!(VirtState::from_libvirt(2, 0), VirtState::Running);
        assert_eq!(VirtState::from_libvirt(3, 1), VirtState::Paused);
        assert_eq!(VirtState::from_libvirt(3, 11), VirtState::Starting);
        assert_eq!(VirtState::from_libvirt(3, 8), VirtState::Stopping);
        assert_eq!(VirtState::from_libvirt(4, 1), VirtState::Stopping);
        assert_eq!(VirtState::from_libvirt(5, 2), VirtState::Stopped);
        assert_eq!(VirtState::from_libvirt(6, 1), VirtState::Stopped);
        assert_eq!(VirtState::from_libvirt(7, 0), VirtState::Paused);
        assert_eq!(VirtState::from_libvirt(0, 0), VirtState::Unknown);
        assert_eq!(VirtState::from_libvirt(-1, 0), VirtState::Unknown);
        assert_eq!(VirtState::from_libvirt(42, 0), VirtState::Unknown);
    }

    #[test]
    fn reason_names() {
        assert_eq!(reason_name(1, 1), "booted");
        assert_eq!(reason_name(3, 11), "starting_up");
        assert_eq!(reason_name(5, 2), "destroyed");
        assert_eq!(reason_name(5, 99), "unknown");
        assert_eq!(reason_name(-1, 0), "unknown");
        assert_eq!(reason_name(1, -3), "unknown");
    }

    #[test]
    fn section_rc() {
        let s = Section::parse("hello\nworld\n\nSbVirtRc=0\n");
        assert_eq!(s.rc, Some(0));
        assert_eq!(s.body.trim_end(), "hello\nworld");
        assert!(Section::parse("\nSbVirtRc=0").ok().unwrap().is_empty());
        // No trailing newline from the command (domdisplay)
        let s = Section::parse("vnc://localhost:0\nSbVirtRc=0");
        assert_eq!(s.ok().unwrap(), "vnc://localhost:0");
        // Cut off
        assert!(matches!(
            Section::parse("partial").ok(),
            Err(VirtError::Malformed { .. })
        ));
    }

    #[test]
    fn classify() {
        let perm = "error: failed to connect to the hypervisor\n\
                    error: Failed to connect socket to '/var/run/libvirt/libvirt-sock': Permission denied";
        assert!(matches!(classify_error(perm), VirtError::PermissionDenied { .. }));
        let polkit = "error: failed to connect to the hypervisor\n\
                      error: authentication unavailable: no polkit agent available to authenticate action 'org.libvirt.unix.manage'";
        assert!(matches!(classify_error(polkit), VirtError::PermissionDenied { .. }));
        let acl = "error: access denied: 'domain' operation";
        assert!(matches!(classify_error(acl), VirtError::PermissionDenied { .. }));
        let down = "error: failed to connect to the hypervisor\n\
                    error: Failed to connect socket to '/var/run/libvirt/libvirt-sock': No such file or directory";
        match classify_error(down) {
            VirtError::ConnectFailed { message } => {
                assert!(message.starts_with("failed to connect to the hypervisor\n"));
            }
            other => panic!("{other:?}"),
        }
        assert!(matches!(
            classify_error("error: failed to get domain 'nope'"),
            VirtError::DomainNotFound { .. }
        ));
        assert!(matches!(
            classify_error("error: Failed to start domain 'a'\nerror: Requested operation is not valid: domain is already running"),
            VirtError::InvalidState { .. }
        ));
        assert!(matches!(
            classify_error("error: something else"),
            VirtError::Command { .. }
        ));
    }

    #[test]
    fn domain_args_are_quoted() {
        let s = action_script(VirtAction::Start, "it's; rm -rf / #");
        assert!(s.contains("V start --domain 'it'\\''s; rm -rf / #'\n"), "{s}");
        let s = action_script(VirtAction::ForceStop, "-x");
        assert!(s.contains("V destroy --domain '-x'\n"));
        assert_eq!(
            console_command("a b"),
            "virsh --connect qemu:///system console --force --domain 'a b'"
        );
    }

    #[test]
    fn display_uris() {
        let d = parse_display("vnc://localhost:0").unwrap();
        assert_eq!((d.host.as_deref(), d.port), (Some("localhost"), Some(5900)));
        let d = parse_display("spice://127.0.0.1:5901?tls-port=5902").unwrap();
        assert_eq!(d.protocol, "spice");
        assert_eq!((d.port, d.tls_port), (Some(5901), Some(5902)));
        let d = parse_display("vnc://[::1]:3").unwrap();
        assert_eq!((d.host.as_deref(), d.port), (Some("::1"), Some(5903)));
        let d = parse_display("vnc+unix:///run/libvirt/qemu/vnc.sock").unwrap();
        assert_eq!(d.socket.as_deref(), Some("/run/libvirt/qemu/vnc.sock"));
        assert_eq!(d.port, None);
        let d = parse_display("vnc://:secret@localhost:1").unwrap();
        assert_eq!((d.host.as_deref(), d.port), (Some("localhost"), Some(5901)));
        let d = parse_display("spice://localhost?tls-port=5903").unwrap();
        assert_eq!((d.port, d.tls_port), (None, Some(5903)));
        assert!(parse_display("").is_none());
    }

    #[test]
    fn missing_virsh() {
        let raw = format!("{}\n", script::cmd_marker(KEY_MISSING));
        assert_eq!(parse_overview(&raw), Err(VirtError::NotInstalled));
        assert_eq!(parse_action(&raw), Err(VirtError::NotInstalled));
    }

    #[test]
    fn shell_failure_without_sections() {
        assert!(matches!(
            parse_overview("sh: 1: Syntax error"),
            Err(VirtError::Malformed { .. })
        ));
        assert!(matches!(
            parse_overview("sudo: a terminal is required... Permission denied"),
            Err(VirtError::PermissionDenied { .. })
        ));
    }
}
