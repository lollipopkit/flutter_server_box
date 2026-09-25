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

/// Host probe: whether `virsh` exists and the daemon answers this user.
/// Parse with [`parse_probe`].
pub fn probe_script() -> String {
    let mut s = prelude();
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

/// [`probe_script`]'s output: the versions when this user can reach the
/// daemon.
pub fn parse_probe(raw: &str) -> Result<VirtVersion, VirtError> {
    let secs = sections(raw)?;
    let body = take(&secs, KEY_VERSION, raw)?.ok()?;
    parse_version(body).ok_or_else(|| VirtError::Malformed {
        message: format!("unrecognised virsh version output: {}", body.trim()),
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
