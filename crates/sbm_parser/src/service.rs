//! Service units — the model, the manager detector and the three backends.
//!
//! Ported from the app's `lib/data/service/{detector,systemd,procd,openrc,
//! service_manager}.dart` and `lib/data/model/server/service.dart`; the Dart
//! implementation stays until this one is asserted identical against the same
//! fixtures.
//!
//! Pure like the rest of this crate: a parser takes the text commands printed
//! and returns units, and a command builder takes a unit and returns the text
//! to run. Nothing here runs anything or reads a clock, so the app reaches it
//! over SSH and the agent reaches it over a local shell and both read one
//! implementation.
//!
//! ## Three managers, one model
//!
//! Which manager a machine runs is a question the machine answers
//! ([`DETECT_SCRIPT`], [`parse_probe`]); the listing is then assembled from
//! that manager's own commands. systemd is four calls (a listing and a details
//! sweep, each in both scopes), Procd is a walk of `/etc/init.d` plus a `ubus`
//! dump, OpenRC is a catalog plus `rc-status` plus `rc-update show`. All three
//! arrive as [`ServiceUnit`]s, so a client draws one list.
//!
//! ## What is deliberately not here
//!
//! **The clock shift.** The Dart port moves every timestamp it reads onto the
//! device's clock by the difference between the server's `date +%s` and its
//! own, so a `DateTime.now()` difference taken later is right. This returns the
//! instant as written — an exact epoch millisecond, since the command forces
//! `TZ=UTC` — and the server's own clock beside it ([`SystemdDetails::
//! sampled_at_millis`]). Each consumer does the arithmetic on the clock it has:
//! the app's is the one that asked, and the panel's is a third one that the
//! agent's shift would not have reached either.
//!
//! **Localised text.** A [`ServiceUnit`] carries no display string: which word
//! a state is drawn as is the client's, and [`ServiceAction::as_str`] is the
//! shell's word rather than a label.
//!
//! **A unit's description, where the manager does not print one.** Procd and
//! OpenRC list names and nothing else, so those units carry `None` rather than
//! a name used as a description.
//!
//! ## Privilege
//!
//! Nothing here runs anything, so nothing here may decide whether a command
//! needs root — but the answer is a property of the unit, which is here:
//! [`ServiceManagerType::needs_root`]. The caller wraps with sudo, and a
//! systemd *user* unit is the one that must not be wrapped: `sudo systemctl
//! --user` talks to root's user manager rather than this account's.

use std::collections::{BTreeMap, BTreeSet, HashMap};
use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

use crate::common::single_quote;

// ---------------------------------------------------------------------------
// The model
// ---------------------------------------------------------------------------

/// Which service manager a machine runs.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ServiceManagerType {
    Systemd,
    Procd,
    Openrc,
}

impl ServiceManagerType {
    /// The one the clients draw. Not the detected word, which for an
    /// unsupported manager is that manager's own name.
    pub fn display_name(self) -> &'static str {
        match self {
            Self::Systemd => "systemd",
            Self::Procd => "procd",
            Self::Openrc => "OpenRC",
        }
    }

    /// Whether this manager has a per-account scope at all. Only systemd does,
    /// and it is the reason the listing carries a notice: a user scope that
    /// cannot be reached is normal on a machine with no user session.
    pub fn supports_user_scope(self) -> bool {
        self == Self::Systemd
    }
}

/// What a unit is. A `.target` is not one of these, which is how
/// `list-units`'s other rows are dropped.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ServiceUnitType {
    Service,
    Socket,
    Mount,
    Timer,
}

impl ServiceUnitType {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Service => "service",
            Self::Socket => "socket",
            Self::Mount => "mount",
            Self::Timer => "timer",
        }
    }

    /// `None` for a suffix this model does not carry — the caller drops the
    /// row rather than inventing a type for it.
    pub fn parse(value: &str) -> Option<Self> {
        match value.to_ascii_lowercase().as_str() {
            "service" => Some(Self::Service),
            "socket" => Some(Self::Socket),
            "mount" => Some(Self::Mount),
            "timer" => Some(Self::Timer),
            _ => None,
        }
    }
}

/// Whose unit it is. systemd's `--user` scope is the only one that exists.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ServiceScope {
    System,
    User,
}

impl ServiceScope {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::System => "system",
            Self::User => "user",
        }
    }
}

/// Where a unit is.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ServiceState {
    Running,
    Stopped,
    Failed,
    Starting,
    Stopping,
    /// The manager did not say. Not the same as stopped, and not drawn as a
    /// state at all.
    Unknown,
}

impl ServiceState {
    /// Failed, or on its way somewhere. What a list shows first.
    pub fn needs_attention(self) -> bool {
        matches!(self, Self::Failed | Self::Starting | Self::Stopping)
    }

    /// systemd's `ActiveState`, which is one of five words or something this
    /// model does not carry.
    fn from_systemd_active(active: &str) -> Option<Self> {
        match active {
            "active" => Some(Self::Running),
            "inactive" => Some(Self::Stopped),
            "failed" => Some(Self::Failed),
            "activating" => Some(Self::Starting),
            "deactivating" => Some(Self::Stopping),
            _ => None,
        }
    }

    /// OpenRC's own words, which name the same states differently and add
    /// `crashed` for a failure and `inactive` for a stop. An unrecognised one
    /// is [`ServiceState::Unknown`] rather than dropped: OpenRC reports a state
    /// for exactly the services it knows about, and a row missing from the list
    /// would read as a service that does not exist.
    fn from_openrc(raw: &str) -> Self {
        let raw = raw.trim().to_ascii_lowercase();
        if raw.starts_with("started") {
            Self::Running
        } else if raw.starts_with("stopped") || raw.starts_with("inactive") {
            Self::Stopped
        } else if raw.starts_with("crashed") || raw.starts_with("failed") {
            Self::Failed
        } else if raw.starts_with("starting") {
            Self::Starting
        } else if raw.starts_with("stopping") {
            Self::Stopping
        } else {
            Self::Unknown
        }
    }
}

/// Something to do to a unit.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ServiceAction {
    Start,
    Stop,
    Restart,
    Enable,
    Disable,
}

impl ServiceAction {
    /// The word the manager takes. The shell's word rather than a label: an
    /// audit row naming the action is then the same vocabulary, and no client
    /// spells its own.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Start => "start",
            Self::Stop => "stop",
            Self::Restart => "restart",
            Self::Enable => "enable",
            Self::Disable => "disable",
        }
    }

    /// Whether taking it can interrupt something that is working. Asked before
    /// it runs; starting or enabling a unit is not.
    pub fn destructive(self) -> bool {
        matches!(self, Self::Stop | Self::Restart | Self::Disable)
    }
}

/// What to offer for a unit in one state.
///
/// Derived rather than taken from the client, because it is a rule about a
/// manager and a state and a client that worked it out would be a second
/// implementation of it. `enabled` is the startup registration: `Some(true)`
/// adds a way to turn it off, `Some(false)` a way to turn it on, and `None`
/// adds neither — a manager that cannot report it, or a unit that is neither.
pub fn service_actions(state: ServiceState, enabled: Option<bool>) -> Vec<ServiceAction> {
    let mut actions = match state {
        ServiceState::Running => vec![ServiceAction::Stop, ServiceAction::Restart],
        ServiceState::Stopped => vec![ServiceAction::Start],
        ServiceState::Failed => vec![ServiceAction::Restart],
        ServiceState::Starting => vec![ServiceAction::Stop],
        ServiceState::Stopping => vec![ServiceAction::Start],
        ServiceState::Unknown => vec![ServiceAction::Start, ServiceAction::Restart],
    };
    match enabled {
        Some(true) => actions.push(ServiceAction::Disable),
        Some(false) => actions.push(ServiceAction::Enable),
        None => {}
    }
    actions
}

/// One unit, as both clients draw it.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct ServiceUnit {
    /// Without the type suffix: `sshd`, not `sshd.service`.
    pub name: String,
    /// `name` with the type suffix, which is what every command names.
    pub full_name: String,
    #[serde(rename = "type")]
    pub unit_type: ServiceUnitType,
    pub scope: ServiceScope,
    pub state: ServiceState,
    /// What the manager says the unit is for, where it says anything.
    pub description: Option<String>,
    /// Startup registration. `None` where the manager cannot report it: a
    /// `Some(false)` is a manager that did report "not registered".
    pub enabled: Option<bool>,
    /// systemd's own word for startup registration, which says more than
    /// [`enabled`](Self::enabled) can: a `static` or `masked` unit cannot be
    /// enabled at all, and offering to would fail.
    pub unit_file_state: Option<String>,
    /// systemd's finer state: `running`, `exited`, `dead`, `start-pre`.
    pub sub_state: Option<String>,
    /// Why the last run ended, where systemd says: `exit-code`, `signal`,
    /// `timeout`. `success` is not kept — it explains nothing.
    pub result: Option<String>,
    /// The main process's exit status, kept only where [`result`] is
    /// `exit-code`: otherwise it is a zero, or the number of a signal already
    /// named there.
    ///
    /// [`result`]: ServiceUnit::result
    pub exit_status: Option<i32>,
    pub memory_bytes: Option<i64>,
    /// When the unit entered its current state, in Unix milliseconds as the
    /// machine reported it. See the module note on the clock shift.
    pub since_millis: Option<i64>,
    /// When a timer next fires, in Unix milliseconds.
    pub next_elapse_millis: Option<i64>,
    /// What may be done to it, derived from the state and `enabled` above —
    /// never passed in, so a unit cannot be built with a set that disagrees
    /// with them.
    pub actions: Vec<ServiceAction>,
}

impl ServiceUnit {
    pub fn new(
        name: impl Into<String>,
        unit_type: ServiceUnitType,
        scope: ServiceScope,
        state: ServiceState,
    ) -> Self {
        let name = name.into();
        Self {
            full_name: format!("{name}.{}", unit_type.as_str()),
            name,
            unit_type,
            scope,
            state,
            description: None,
            enabled: None,
            unit_file_state: None,
            sub_state: None,
            result: None,
            exit_status: None,
            memory_bytes: None,
            since_millis: None,
            next_elapse_millis: None,
            actions: service_actions(state, None),
        }
    }

    /// Tells apart a system and a user unit of the same name.
    ///
    /// Public and derived rather than spelled by each caller: a client keys a
    /// list by it, and two spellings of the same key are two entries.
    pub fn key(&self) -> String {
        format!("{}:{}", self.scope.as_str(), self.full_name)
    }

    /// [`unit_file_state`](Self::unit_file_state) where the manager has one,
    /// [`enabled`](Self::enabled) in the same words where it does not.
    pub fn startup(&self) -> Option<&str> {
        self.unit_file_state.as_deref().or(match self.enabled {
            Some(true) => Some("enabled"),
            Some(false) => Some("disabled"),
            None => None,
        })
    }

    /// Sets the startup registration and the actions together, so the two
    /// cannot be left disagreeing.
    pub fn set_enabled(&mut self, enabled: Option<bool>) {
        self.enabled = enabled;
        self.actions = service_actions(self.state, enabled);
    }
}

/// A list's order: the account's own units first, then what is running, then
/// by name.
///
/// The user scope leads because it is the short one and the one a person is
/// usually looking for; running before stopped because a page is opened to see
/// what is up.
pub fn compare_services(a: &ServiceUnit, b: &ServiceUnit) -> std::cmp::Ordering {
    use std::cmp::Ordering;
    if a.scope != b.scope {
        return if a.scope == ServiceScope::User {
            Ordering::Less
        } else {
            Ordering::Greater
        };
    }
    if a.state != b.state {
        if a.state == ServiceState::Running {
            return Ordering::Less;
        }
        if b.state == ServiceState::Running {
            return Ordering::Greater;
        }
    }
    a.name.cmp(&b.name)
}

/// What a listing could not be read at all as.
///
/// Its own type rather than a string, so a caller cannot pass a notice's
/// detail where a failure belongs: the two read the same from the machine and
/// mean opposite things about the page.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ServiceLoadError {
    /// What the machine said, verbatim. The only thing that distinguishes one
    /// failure from another.
    pub detail: String,
}

impl std::fmt::Display for ServiceLoadError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.detail)
    }
}

impl std::error::Error for ServiceLoadError {}

/// A part of the listing that is missing, with the whole list still readable.
///
/// A notice rather than an error: a machine with no user session has no user
/// units, and every other unit is still there to show.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ServiceListingNotice {
    /// systemd's user scope could not be reached at all.
    UserScopeUnavailable,
    /// The units are listed but not described: the details call failed, the
    /// startup registration could not be read, or an init-script walk did not
    /// finish.
    DetailsUnavailable,
}

/// One manager's answer about every unit it has.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct ServiceListing {
    pub units: Vec<ServiceUnit>,
    pub notice: Option<ServiceListingNotice>,
    /// What the machine said about the notice, verbatim.
    pub detail: Option<String>,
}

// ---------------------------------------------------------------------------
// Reading one command's output
// ---------------------------------------------------------------------------

/// What one command printed, and whether it succeeded.
///
/// The three parts are kept apart rather than flattened into one string
/// because a failure's detail is `stderr` and a success's payload is `stdout`:
/// the Dart port reads a listing out of `stdout` and reports `combined`, and
/// one field could not do both.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CommandOutput {
    pub stdout: String,
    pub stderr: String,
    /// Whether the command exited zero.
    pub succeeded: bool,
}

impl CommandOutput {
    /// A command that ran and exited zero.
    pub fn ok(stdout: impl Into<String>) -> Self {
        Self {
            stdout: stdout.into(),
            stderr: String::new(),
            succeeded: true,
        }
    }

    /// A command that ran and did not exit zero.
    pub fn failed(stderr: impl Into<String>) -> Self {
        Self {
            stdout: String::new(),
            stderr: stderr.into(),
            succeeded: false,
        }
    }

    pub fn new(stdout: impl Into<String>, stderr: impl Into<String>, succeeded: bool) -> Self {
        Self {
            stdout: stdout.into(),
            stderr: stderr.into(),
            succeeded,
        }
    }

    /// Both streams in the order a terminal would have shown them.
    ///
    /// Both, not `stderr` alone: a command that printed a partial listing and
    /// then failed has that listing in `stdout`, and it is what the failure's
    /// detail is read beside.
    pub fn combined(&self) -> String {
        if self.stderr.is_empty() {
            self.stdout.clone()
        } else {
            format!("{}{}", self.stdout, self.stderr)
        }
    }

    /// [`combined`](Self::combined), trimmed — what a notice's detail is.
    pub fn detail(&self) -> Option<String> {
        let detail = self.combined();
        let trimmed = detail.trim();
        (!trimmed.is_empty()).then(|| trimmed.to_string())
    }
}

// ---------------------------------------------------------------------------
// Detecting the manager
// ---------------------------------------------------------------------------

/// Asks the machine which service manager it runs.
///
/// One script rather than a probe per manager: the order matters — a machine
/// with both `systemctl` and `/etc/init.d` is a systemd machine, and Procd
/// must be recognised before the generic `/etc/init.d` fallback or every
/// OpenWrt box reads as sysvinit. Handed to `sh` rather than run as a command,
/// because what it is made of is `[` and `command -v`.
pub const DETECT_SCRIPT: &str = r#"
if [ -r /etc/os-release ]; then . /etc/os-release; fi
pid1=$(cat /proc/1/comm 2>/dev/null)
if [ -z "$pid1" ]; then pid1=$(ps -p 1 -o comm= 2>/dev/null); fi
pid1=$(printf '%s' "$pid1" | tr -d '[:space:]')

if command -v systemctl >/dev/null 2>&1 &&
   { [ "$pid1" = systemd ] || [ -d /run/systemd/system ]; }; then
  manager=systemd
elif [ "$pid1" = procd ] ||
     { [ -x /sbin/procd ] && command -v ubus >/dev/null 2>&1; }; then
  manager=procd
elif command -v rc-status >/dev/null 2>&1 &&
     command -v rc-service >/dev/null 2>&1; then
  manager=openrc
elif command -v s6-rc >/dev/null 2>&1; then manager=s6
elif command -v sv >/dev/null 2>&1 && [ -d /etc/service ]; then manager=runit
elif command -v initctl >/dev/null 2>&1; then manager=upstart
elif [ "$pid1" = launchd ]; then manager=launchd
elif [ -d /etc/init.d ]; then manager=sysvinit
else manager=${pid1:-unknown}
fi

printf '%s\t%s' "$manager" "${PRETTY_NAME:-}"
"#;

/// What [`DETECT_SCRIPT`] answered.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ServiceManagerProbe {
    /// `None` where the machine runs a manager this app cannot list. The
    /// detected name is still reported, so a page can say what it found
    /// instead of leaving the reader with an empty list.
    pub manager_type: Option<ServiceManagerType>,
    /// What the machine called it.
    pub detected_name: String,
    pub os_name: String,
    /// The script's own output, verbatim.
    pub raw: String,
}

impl ServiceManagerProbe {
    /// `systemd (Debian GNU/Linux)`. The name alone where there is no OS name,
    /// and the OS name alone where the manager is unrecognised.
    pub fn description(&self) -> String {
        if self.detected_name.is_empty() {
            return self.os_name.clone();
        }
        if self.os_name.is_empty() {
            return self.detected_name.clone();
        }
        format!("{} ({})", self.detected_name, self.os_name)
    }
}

/// The script's `manager\tPRETTY_NAME`, lower-cased on the manager.
pub fn parse_probe(raw: &str) -> ServiceManagerProbe {
    let trimmed = raw.trim();
    let (id, os) = match trimmed.split_once('\t') {
        Some((id, rest)) => (id.trim(), rest.trim()),
        None => (trimmed, ""),
    };
    let id = id.to_ascii_lowercase();
    let manager_type = match id.as_str() {
        "systemd" => Some(ServiceManagerType::Systemd),
        "procd" => Some(ServiceManagerType::Procd),
        "openrc" => Some(ServiceManagerType::Openrc),
        _ => None,
    };
    let detected_name = match id.as_str() {
        "openrc" => "OpenRC".to_string(),
        // Nothing was detected, and `unknown` is the script's word for that
        // rather than a manager's name.
        "unknown" | "" => String::new(),
        other => other.to_string(),
    };
    ServiceManagerProbe {
        manager_type,
        detected_name,
        os_name: os.to_string(),
        raw: raw.to_string(),
    }
}

// ---------------------------------------------------------------------------
// systemd
// ---------------------------------------------------------------------------

const SYSTEMD_TYPES: &str = "service,socket,mount,timer";

/// What the list needs beyond `list-units`' four columns. Read in one call per
/// scope rather than one per unit: a machine has a few hundred.
const SYSTEMD_DETAIL_PROPERTIES: &[&str] = &[
    "Id",
    "UnitFileState",
    "SubState",
    "Result",
    "ExecMainStatus",
    "MemoryCurrent",
    "ActiveEnterTimestamp",
    "ActiveExitTimestamp",
    "InactiveEnterTimestamp",
    "InactiveExitTimestamp",
    "NextElapseUSecRealtime",
];

impl ServiceManagerType {
    fn systemctl(scope: ServiceScope) -> &'static str {
        match scope {
            ServiceScope::System => "systemctl",
            ServiceScope::User => "systemctl --user",
        }
    }

    fn journalctl(scope: ServiceScope) -> &'static str {
        match scope {
            ServiceScope::System => "journalctl",
            ServiceScope::User => "journalctl --user",
        }
    }

    /// The command that lists the units of one scope.
    pub fn list_command(self, scope: ServiceScope) -> Option<String> {
        (self == Self::Systemd).then(|| {
            format!(
                "{} list-units --all --no-legend --no-pager --plain --type={SYSTEMD_TYPES}",
                Self::systemctl(scope)
            )
        })
    }

    /// `systemctl show` for every loaded unit of the four types, preceded by
    /// the server's clock.
    ///
    /// Timestamps are printed in UTC and the C locale, which makes them one
    /// fixed format: in the server's own zone they end in an abbreviation like
    /// `CST`, which names three different offsets. `--timestamp=unix` would
    /// avoid parsing at all but arrived in systemd 251, after Debian 11 and
    /// RHEL 8. `env` rather than a `TZ=` prefix, because this runs in the
    /// account's login shell and that may not be a POSIX one.
    ///
    /// The server's clock comes along because a duration is only right on the
    /// clock the timestamps were taken on.
    pub fn details_command(self, scope: ServiceScope) -> Option<String> {
        (self == Self::Systemd).then(|| {
            let patterns = SYSTEMD_TYPES
                .split(',')
                .map(|unit_type| format!("'*.{unit_type}'"))
                .collect::<Vec<_>>()
                .join(" ");
            format!(
                "date +%s; env TZ=UTC LC_ALL=C {} show --no-pager --property={} -- {patterns}",
                Self::systemctl(scope),
                SYSTEMD_DETAIL_PROPERTIES.join(","),
            )
        })
    }

    /// The command that performs one action on a unit, without `sudo`.
    ///
    /// Whether the caller wraps it is [`needs_root`](Self::needs_root)'s
    /// answer: a command run through the agent goes through its privileged
    /// path, and one typed into a terminal gets the prefix from
    /// [`terminal_command`].
    pub fn command_for(self, unit: &ServiceUnit, action: ServiceAction) -> String {
        match self {
            Self::Systemd => format!(
                "{} {} {}",
                Self::systemctl(unit.scope),
                action.as_str(),
                single_quote(&unit.full_name)
            ),
            Self::Procd => format!(
                "{} {}",
                single_quote(&format!("/etc/init.d/{}", unit.name)),
                action.as_str()
            ),
            Self::Openrc => {
                let name = single_quote(&unit.name);
                match action {
                    // `enable` and `disable` are not `rc-service` verbs: a
                    // service is registered for startup by its runlevel.
                    ServiceAction::Enable => format!("rc-update add {name} default"),
                    ServiceAction::Disable => format!("rc-update --all delete {name}"),
                    _ => format!("rc-service {name} {}", action.as_str()),
                }
            }
        }
    }

    /// Whether [`command_for`](Self::command_for) must run as root.
    ///
    /// A systemd user unit is the one that must not: `sudo systemctl --user`
    /// talks to root's user manager rather than this account's.
    pub fn needs_root(self, unit: &ServiceUnit) -> bool {
        match self {
            Self::Systemd => unit.scope == ServiceScope::System,
            Self::Procd | Self::Openrc => true,
        }
    }

    /// The last `lines` of a unit's log, where the manager keeps a log that can
    /// be read by unit name. Read as this account and never through sudo: it
    /// runs when a unit is opened rather than because the user asked for
    /// anything, and a password prompt belongs to an action the user took.
    pub fn recent_log_command(self, unit: &ServiceUnit, lines: u32) -> Option<String> {
        match self {
            Self::Systemd => Some(format!(
                "{} --no-pager --output=short-iso -n {lines} -u {}",
                Self::journalctl(unit.scope),
                single_quote(&unit.full_name)
            )),
            Self::Procd => Some(format!(
                "logread -e {} | tail -n {lines}",
                single_quote(&unit.name)
            )),
            // OpenRC hands a service's output to whatever it was configured to
            // log to, and there is no one place to read it back from by name.
            Self::Openrc => None,
        }
    }

    /// A command that reads the whole log in a terminal, `None` with no such
    /// log.
    pub fn log_command(self, unit: &ServiceUnit) -> Option<String> {
        match self {
            Self::Systemd => Some(format!(
                "{} -e -u {}",
                Self::journalctl(unit.scope),
                single_quote(&unit.full_name)
            )),
            Self::Procd => Some(format!("logread -e {}", single_quote(&unit.name))),
            Self::Openrc => None,
        }
    }

    /// A command that prints the unit's definition.
    pub fn definition_command(self, unit: &ServiceUnit) -> String {
        match self {
            Self::Systemd => format!(
                "{} cat {}",
                Self::systemctl(unit.scope),
                single_quote(&unit.full_name)
            ),
            Self::Procd | Self::Openrc => {
                format!("cat {}", single_quote(&format!("/etc/init.d/{}", unit.name)))
            }
        }
    }

    /// What the manager itself says about the unit. For OpenRC this is the only
    /// thing a unit has to read: it keeps no log by name.
    pub fn unit_status_command(self, unit: &ServiceUnit) -> String {
        match self {
            Self::Systemd => format!(
                "{} status --no-pager --full {}",
                Self::systemctl(unit.scope),
                single_quote(&unit.full_name)
            ),
            Self::Procd => format!(
                "{} status",
                single_quote(&format!("/etc/init.d/{}", unit.name))
            ),
            Self::Openrc => format!("rc-service {} status", single_quote(&unit.name)),
        }
    }
}

/// [`command_for`](ServiceManagerType::command_for) as typed into a terminal:
/// prefixed with `sudo` where it needs root and the account is not root, so the
/// terminal asks for the password.
///
/// For the app's service page, which opens a terminal rather than running the
/// action itself. The agent does not use it — its privileged path takes the
/// un-prefixed text and supplies the password on stdin.
pub fn terminal_command(command: &str, needs_root: bool, is_root: bool) -> String {
    if needs_root && !is_root {
        format!("sudo {command}")
    } else {
        command.to_string()
    }
}

/// The four commands a systemd listing is assembled from — a listing and a
/// details sweep, in each of the two scopes.
pub struct SystemdOutputs<'a> {
    pub system_list: &'a CommandOutput,
    pub system_details: &'a CommandOutput,
    pub user_list: &'a CommandOutput,
    pub user_details: &'a CommandOutput,
}

/// One listing of the machine's units, or the reason there is none.
pub fn parse_systemd_listing(
    outputs: &SystemdOutputs<'_>,
) -> Result<ServiceListing, ServiceLoadError> {
    // The system listing is the page: without it there is nothing to show.
    if !outputs.system_list.succeeded {
        return Err(ServiceLoadError {
            detail: outputs.system_list.combined().trim().to_string(),
        });
    }
    let system_units = parse_list_units(&outputs.system_list.stdout, ServiceScope::System);

    // The user scope is optional, and missing it has a notice of its own
    // whether the command failed or could not be run at all.
    let user_failed = !outputs.user_list.succeeded;
    let user_units = if user_failed {
        Vec::new()
    } else {
        parse_list_units(&outputs.user_list.stdout, ServiceScope::User)
    };

    let mut details_failed = false;
    let mut by_key: HashMap<String, SystemdUnitDetails> = HashMap::new();
    for (scope, output) in [
        (ServiceScope::System, outputs.system_details),
        (ServiceScope::User, outputs.user_details),
    ] {
        if !output.succeeded {
            // The user scope's details fail for the same reason its listing
            // does, which already has a notice of its own.
            if scope == ServiceScope::System || !user_failed {
                details_failed = true;
            }
            continue;
        }
        for (id, detail) in parse_details(&output.stdout).units {
            by_key.insert(format!("{}:{id}", scope.as_str()), detail);
        }
    }

    let mut units: Vec<ServiceUnit> = user_units
        .iter()
        .chain(system_units.iter())
        .map(|unit| with_details(unit, by_key.get(&unit.key())))
        .collect();
    units.sort_by(compare_services);

    Ok(ServiceListing {
        units,
        notice: if user_failed {
            Some(ServiceListingNotice::UserScopeUnavailable)
        } else if details_failed {
            Some(ServiceListingNotice::DetailsUnavailable)
        } else {
            None
        },
        detail: if user_failed {
            outputs.user_list.detail()
        } else {
            None
        },
    })
}

/// `list-units`' four columns, one unit per line.
///
/// A row whose type is not one of the four, whose state systemd does not name
/// in [`ServiceState`], or that has fewer than four columns is dropped rather
/// than guessed at — the listing printed it for a reason this model does not
/// carry, and a row with an invented state would be an action offered on a
/// guess.
pub fn parse_list_units(output: &str, scope: ServiceScope) -> Vec<ServiceUnit> {
    let mut units = Vec::new();
    for line in output.split('\n') {
        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }
        let parts: Vec<&str> = trimmed.split_whitespace().collect();
        if parts.len() < 4 {
            continue;
        }
        let full_name = parts[0];
        // `<= 0` rather than `None`: a name that is nothing but a suffix names
        // no unit.
        let Some(last_dot) = full_name.rfind('.').filter(|index| *index > 0) else {
            continue;
        };
        let Some(unit_type) = ServiceUnitType::parse(&full_name[last_dot + 1..]) else {
            continue;
        };
        let Some(state) = ServiceState::from_systemd_active(&parts[2].to_ascii_lowercase()) else {
            continue;
        };

        let mut unit = ServiceUnit::new(&full_name[..last_dot], unit_type, scope, state);
        unit.sub_state = (!parts[3].is_empty()).then(|| parts[3].to_string());
        // The remaining columns are one description: `split_whitespace` broke
        // it apart, and what systemd printed was a sentence.
        unit.description = (parts.len() > 4).then(|| parts[4..].join(" "));
        units.push(unit);
    }
    units
}

/// What `systemctl show` said about one unit.
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize)]
pub struct SystemdUnitDetails {
    pub unit_file_state: Option<String>,
    pub sub_state: Option<String>,
    pub result: Option<String>,
    pub exit_status: Option<i32>,
    pub memory_bytes: Option<i64>,
    pub active_enter_millis: Option<i64>,
    pub active_exit_millis: Option<i64>,
    pub inactive_enter_millis: Option<i64>,
    pub inactive_exit_millis: Option<i64>,
    pub next_elapse_millis: Option<i64>,
}

/// Every unit `systemctl show` described, keyed by `Id`.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct SystemdDetails {
    /// The server's own clock, from the first line of the details command —
    /// `date +%s`. `None` where that line was absent, which is how a caller
    /// knows a duration worked out against it is not anchored.
    pub sampled_at_millis: Option<i64>,
    pub units: HashMap<String, SystemdUnitDetails>,
}

/// Blocks of `Key=value` lines separated by blank ones, keyed by `Id`.
///
/// The first line is the server's `date +%s`; without it the timestamps are
/// taken as they are.
pub fn parse_details(output: &str) -> SystemdDetails {
    let lines: Vec<&str> = output.split('\n').collect();
    let (sampled_at_millis, start) = match lines.first() {
        Some(first) => match first.trim().parse::<i64>() {
            Ok(seconds) => (Some(seconds * 1000), 1),
            Err(_) => (None, 0),
        },
        None => (None, 0),
    };

    let mut details = SystemdDetails {
        sampled_at_millis,
        units: HashMap::new(),
    };
    let mut block: HashMap<&str, &str> = HashMap::new();
    let mut flush = |block: &mut HashMap<&str, &str>| {
        // A block with no `Id` describes no unit.
        let id = block.get("Id").filter(|id| !id.is_empty()).map(|id| id.to_string());
        if let Some(id) = id {
            details.units.insert(id, details_from_block(block));
        }
        block.clear();
    };

    for line in lines.into_iter().skip(start) {
        if line.trim().is_empty() {
            flush(&mut block);
            continue;
        }
        // `<= 0`: a line that begins with `=` has no key, and a line without
        // one is not a property.
        if let Some(eq) = line.find('=').filter(|index| *index > 0) {
            block.insert(&line[..eq], line[eq + 1..].trim());
        }
    }
    flush(&mut block);
    details
}

fn details_from_block(block: &HashMap<&str, &str>) -> SystemdUnitDetails {
    let text = |key: &str| -> Option<String> {
        block
            .get(key)
            .map(|value| value.trim())
            .filter(|value| !value.is_empty())
            .map(str::to_string)
    };
    let time = |key: &str| -> Option<i64> {
        block
            .get(key)
            .and_then(|value| parse_timestamp(value))
    };

    let result = text("Result");
    SystemdUnitDetails {
        unit_file_state: text("UnitFileState"),
        sub_state: text("SubState"),
        // `success` is not kept: it explains nothing.
        result: result.filter(|value| value != "success"),
        exit_status: block
            .get("ExecMainStatus")
            .and_then(|value| value.trim().parse::<i32>().ok()),
        memory_bytes: block
            .get("MemoryCurrent")
            .and_then(|value| parse_memory(value)),
        active_enter_millis: time("ActiveEnterTimestamp"),
        active_exit_millis: time("ActiveExitTimestamp"),
        inactive_enter_millis: time("InactiveEnterTimestamp"),
        inactive_exit_millis: time("InactiveExitTimestamp"),
        next_elapse_millis: time("NextElapseUSecRealtime"),
    }
}

/// `Wed 2026-09-16 04:04:31 UTC`, as an instant in Unix milliseconds.
///
/// `None` for the empty value systemd prints for "never", for `n/a`, and for
/// anything not in UTC: a zone abbreviation names three different offsets, so a
/// value carrying one is not an instant.
pub fn parse_timestamp(value: &str) -> Option<i64> {
    static TIMESTAMP: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2}) UTC$")
            .expect("timestamp regex")
    });
    let captures = TIMESTAMP.captures(value.trim())?;
    let part = |index: usize| captures[index].parse::<i64>().unwrap_or_default();
    let (year, month, day) = (
        part(1) as i32,
        part(2) as u32,
        part(3) as u32,
    );
    Some(crate::cron::utc_millis(
        year,
        month,
        day,
        part(4) as u32,
        part(5) as u32,
        part(6) as u32,
    ))
}

/// The number of bytes systemd says a unit is using.
///
/// `None` for `[not set]` — which is not zero bytes — and for the all-ones
/// value older systemd prints when a unit has no memory accounting,
/// `18446744073709551615`. That value is what a signed 64-bit parse rejects,
/// which is the whole of the reason it is read as signed: no unit is using
/// nine exabytes, and the type is the check.
pub fn parse_memory(value: &str) -> Option<i64> {
    value
        .trim()
        .parse::<i64>()
        .ok()
        .filter(|bytes| *bytes >= 0)
}

/// One listed unit with what the details sweep said about it.
///
/// The state stays the listing's: `show` reports `ActiveState` in its own
/// spelling and the listing already read it, so a second reading would be a
/// second opinion about the same word.
pub fn with_details(unit: &ServiceUnit, details: Option<&SystemdUnitDetails>) -> ServiceUnit {
    let Some(details) = details else {
        return unit.clone();
    };
    let enabled = match details.unit_file_state.as_deref() {
        Some("enabled" | "enabled-runtime") => Some(true),
        Some("disabled") => Some(false),
        _ => None,
    };
    let failed = unit.state == ServiceState::Failed;
    let mut merged = unit.clone();
    merged.sub_state = details
        .sub_state
        .clone()
        .or_else(|| unit.sub_state.clone());
    merged.unit_file_state = details.unit_file_state.clone();
    merged.set_enabled(enabled);
    merged.result = failed.then(|| details.result.clone()).flatten();
    merged.exit_status = (failed && details.result.as_deref() == Some("exit-code"))
        .then_some(details.exit_status)
        .flatten();
    merged.memory_bytes = details.memory_bytes;
    merged.since_millis = match unit.state {
        ServiceState::Running => details.active_enter_millis,
        ServiceState::Stopped | ServiceState::Failed => details.inactive_enter_millis,
        ServiceState::Starting => details.inactive_exit_millis,
        ServiceState::Stopping => details.active_exit_millis,
        ServiceState::Unknown => None,
    };
    merged.next_elapse_millis = (unit.unit_type == ServiceUnitType::Timer)
        .then_some(details.next_elapse_millis)
        .flatten();
    merged
}

/// `2026-09-16T21:09:58+0800 host nginx[8840]: message`, without the date and
/// the host: the date is almost always today's, and every line of one machine's
/// log has the same host.
///
/// Newlines are normalized first, the way [`crate::cron`] and the users module
/// do. The reason differs from the Dart port's: Rust's `.` matches a carriage
/// return, so without this the whole `\r` would end up inside the captured
/// message rather than keeping the line from matching at all. Either way the
/// line is not what it should be.
pub fn parse_journal(stdout: &str, stderr: &str) -> ServiceLog {
    static JOURNAL_LINE: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"^\d{4}-\d{2}-\d{2}T(\d{2}:\d{2}:\d{2})\S* \S+ (.*)$")
            .expect("journal regex")
    });
    let normalized = stdout.replace("\r\n", "\n").replace('\r', "\n");
    let lines = normalized
        .split('\n')
        .filter(|line| !line.trim().is_empty() && !line.starts_with("-- "))
        .map(|line| match JOURNAL_LINE.captures(line) {
            Some(captures) => ServiceLogLine {
                time: Some(captures[1].to_string()),
                text: captures[2].to_string(),
            },
            None => ServiceLogLine {
                time: None,
                text: line.to_string(),
            },
        })
        .collect::<Vec<_>>();

    // An empty log is a unit that has never run; this account being unable to
    // read one is not the same, and journald says which it is on stderr.
    let unreadable = lines.is_empty()
        && (stderr.contains("insufficient permissions")
            || stderr.contains("not seeing messages from other users"));
    ServiceLog { lines, unreadable }
}

// ---------------------------------------------------------------------------
// Procd
// ---------------------------------------------------------------------------

/// Every executable init script, and whether `/etc/rc.d` has a startup link
/// for it.
///
/// Handed to `sh`: it is a `for` loop over a glob, and the `S??` prefix is what
/// OpenWrt's own boot uses to order the links.
pub const PROCD_CATALOG_SCRIPT: &str = r#"
if [ ! -d /etc/init.d ]; then exit 1; fi
for path in /etc/init.d/*; do
  [ -f "$path" ] && [ -x "$path" ] || continue
  name=${path##*/}
  enabled=0
  for link in /etc/rc.d/S??"$name"; do
    if [ -e "$link" ]; then enabled=1; break; fi
  done
  printf '%s\t%s\n' "$name" "$enabled"
done
"#;

pub const PROCD_STATUS_COMMAND: &str = "ubus call service list";

/// The two commands a Procd listing is assembled from.
pub struct ProcdOutputs<'a> {
    pub catalog: &'a CommandOutput,
    pub status: &'a CommandOutput,
}

pub fn parse_procd_listing(outputs: &ProcdOutputs<'_>) -> Result<ServiceListing, ServiceLoadError> {
    if !outputs.catalog.succeeded {
        return Err(ServiceLoadError {
            detail: outputs.catalog.combined().trim().to_string(),
        });
    }
    let enabled_by_name = parse_procd_catalog(&outputs.catalog.stdout);

    let mut detail = None;
    let mut states = HashMap::new();
    if outputs.status.succeeded {
        // A `ubus` that answered something this parser does not read leaves
        // every unit unknown rather than failing the page: the scripts are
        // there, and only the states are missing.
        match parse_procd_states(&outputs.status.stdout) {
            Ok(parsed) => states = parsed,
            Err(error) => detail = Some(error.to_string()),
        }
    } else {
        detail = outputs.status.detail();
    }

    // Only init scripts are actionable. `ubus` also exposes transient
    // instances with no `/etc/init.d` entry, and showing an action for one
    // would manufacture a path from remote JSON that does not exist.
    let units = enabled_by_name
        .iter()
        .map(|(name, enabled)| {
            let state = states.get(name).copied().unwrap_or(ServiceState::Unknown);
            let mut unit =
                ServiceUnit::new(name, ServiceUnitType::Service, ServiceScope::System, state);
            unit.set_enabled(Some(*enabled));
            unit
        })
        .collect::<Vec<_>>();

    let mut units = units;
    units.sort_by(compare_services);
    Ok(ServiceListing {
        units,
        notice: detail
            .as_ref()
            .map(|_| ServiceListingNotice::DetailsUnavailable),
        detail,
    })
}

/// `name\tenabled` per line, where `enabled` is OpenWrt's own `0` or `1`.
pub fn parse_procd_catalog(output: &str) -> BTreeMap<String, bool> {
    let mut services = BTreeMap::new();
    for line in output.split('\n') {
        let parts: Vec<&str> = line.trim().split('\t').collect();
        if parts.len() != 2 || parts[0].is_empty() {
            continue;
        }
        services.insert(parts[0].to_string(), parts[1] == "1");
    }
    services
}

/// What `ubus call service list` said about every service it knows.
///
/// A service with no running instance is stopped, and one `ubus` printed no
/// object for at all is not mentioned here — the caller reads that as
/// [`ServiceState::Unknown`], which is a script that exists and whose state is
/// not known.
pub fn parse_procd_states(output: &str) -> Result<HashMap<String, ServiceState>, serde_json::Error> {
    let decoded: serde_json::Value = serde_json::from_str(output)?;
    let Some(services) = decoded.as_object() else {
        return Err(serde_json::Error::io(std::io::Error::new(
            std::io::ErrorKind::InvalidData,
            "procd service list is not an object",
        )));
    };

    let mut states = HashMap::new();
    for (name, service) in services {
        let Some(service) = service.as_object() else {
            states.insert(name.clone(), ServiceState::Unknown);
            continue;
        };
        // No instance at all, and no instance running, are the same answer
        // here: a service `ubus` printed and is not running is stopped. Only a
        // service it printed nothing for is unknown, and that is the `None`
        // arm above.
        let running = service
            .get("instances")
            .and_then(|instances| instances.as_object())
            .is_some_and(|instances| {
                instances
                    .values()
                    .any(|instance| instance.get("running") == Some(&serde_json::Value::Bool(true)))
            });
        states.insert(
            name.clone(),
            if running {
                ServiceState::Running
            } else {
                ServiceState::Stopped
            },
        );
    }
    Ok(states)
}

/// `Wed Sep 16 21:09:58 2026 daemon.err dnsmasq[1234]: message`.
pub fn parse_logread(output: &str) -> Vec<ServiceLogLine> {
    static LOGREAD_LINE: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"^\w{3} \w{3} +\d+ (\d{2}:\d{2}:\d{2}) \d{4} \S+ (.*)$")
            .expect("logread regex")
    });
    let normalized = output.replace("\r\n", "\n").replace('\r', "\n");
    normalized
        .split('\n')
        .filter(|line| !line.trim().is_empty())
        .map(|line| match LOGREAD_LINE.captures(line) {
            Some(captures) => ServiceLogLine {
                time: Some(captures[1].to_string()),
                text: captures[2].to_string(),
            },
            None => ServiceLogLine {
                time: None,
                text: line.to_string(),
            },
        })
        .collect()
}

// ---------------------------------------------------------------------------
// OpenRC
// ---------------------------------------------------------------------------

/// Every executable init script of both directories OpenRC reads.
pub const OPENRC_CATALOG_SCRIPT: &str = r#"
for directory in /etc/init.d /usr/local/etc/init.d; do
  [ -d "$directory" ] || continue
  for path in "$directory"/*; do
    [ -f "$path" ] && [ -x "$path" ] || continue
    printf '%s\n' "${path##*/}"
  done
done
"#;

/// `rc-status`'s own listing, without the live-service table: the states are
/// what this is for, and `-C` is what asks for them in the stable form.
pub const OPENRC_STATUS_COMMAND: &str = "rc-status -s -C";
pub const OPENRC_STARTUP_COMMAND: &str = "rc-update show";

/// The three commands an OpenRC listing is assembled from.
pub struct OpenRcOutputs<'a> {
    pub catalog: &'a CommandOutput,
    pub status: &'a CommandOutput,
    pub startup: &'a CommandOutput,
}

pub fn parse_openrc_listing(outputs: &OpenRcOutputs<'_>) -> Result<ServiceListing, ServiceLoadError> {
    // The statuses are the page, as systemd's listing is: a list of names with
    // no state has nothing to offer.
    if !outputs.status.succeeded {
        return Err(ServiceLoadError {
            detail: outputs.status.combined().trim().to_string(),
        });
    }
    let states = parse_openrc_status(&outputs.status.stdout);

    let can_report_startup = outputs.startup.succeeded;
    let enabled_names = if can_report_startup {
        parse_openrc_enabled(&outputs.startup.stdout)
    } else {
        BTreeSet::new()
    };
    let catalog = if outputs.catalog.succeeded {
        parse_openrc_catalog(&outputs.catalog.stdout)
    } else {
        BTreeSet::new()
    };

    // Every name either source knows: a script with no state is still a
    // service, and a state with no script is one whose file this account
    // cannot list.
    let names: BTreeSet<&String> = catalog.iter().chain(states.keys()).collect();
    let detail = [
        (!outputs.catalog.succeeded).then(|| outputs.catalog.combined().trim().to_string()),
        (!can_report_startup).then(|| outputs.startup.combined().trim().to_string()),
    ]
    .into_iter()
    .flatten()
    .filter(|part| !part.is_empty())
    .collect::<Vec<_>>()
    .join("\n");

    let mut units = names
        .into_iter()
        .map(|name| {
            let state = states.get(name).copied().unwrap_or(ServiceState::Unknown);
            let mut unit = ServiceUnit::new(
                name.as_str(),
                ServiceUnitType::Service,
                ServiceScope::System,
                state,
            );
            // Cannot report it is not the same as "not registered", and a
            // false would offer to enable what may already be enabled.
            unit.set_enabled(can_report_startup.then(|| enabled_names.contains(name)));
            unit
        })
        .collect::<Vec<_>>();
    units.sort_by(compare_services);

    let complete = can_report_startup && outputs.catalog.succeeded;
    Ok(ServiceListing {
        units,
        notice: (!complete).then_some(ServiceListingNotice::DetailsUnavailable),
        detail: (!detail.is_empty()).then_some(detail),
    })
}

pub fn parse_openrc_catalog(output: &str) -> BTreeSet<String> {
    output
        .split('\n')
        .map(str::trim)
        .filter(|line| !line.is_empty())
        .map(str::to_string)
        .collect()
}

/// `acpid  [  started  ]` per line — `rc-status -s`'s own table.
pub fn parse_openrc_status(output: &str) -> HashMap<String, ServiceState> {
    static STATUS_LINE: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"^\s*(\S+)\s+\[\s*([^\]]+)\]\s*$").expect("rc-status regex")
    });
    let normalized = output.replace("\r\n", "\n").replace('\r', "\n");
    let mut states = HashMap::new();
    for line in normalized.split('\n') {
        let Some(captures) = STATUS_LINE.captures(line) else {
            continue;
        };
        states.insert(
            captures[1].to_string(),
            ServiceState::from_openrc(&captures[2]),
        );
    }
    states
}

/// `rc-update show`'s `name | runlevel ...` table — the services registered for
/// startup.
///
/// The header row's own first column is the word `service`, and a service named
/// that would be indistinguishable from it; the runlevel column being empty is
/// what says a row carries nothing.
pub fn parse_openrc_enabled(output: &str) -> BTreeSet<String> {
    static STARTUP_LINE: LazyLock<Regex> = LazyLock::new(|| {
        Regex::new(r"^\s*([^\s|]+)\s*\|\s*(.+)$").expect("rc-update regex")
    });
    let normalized = output.replace("\r\n", "\n").replace('\r', "\n");
    let mut services = BTreeSet::new();
    for line in normalized.split('\n') {
        let Some(captures) = STARTUP_LINE.captures(line) else {
            continue;
        };
        let name = &captures[1];
        if name.eq_ignore_ascii_case("service") {
            continue;
        }
        if !captures[2].trim().is_empty() {
            services.insert(name.to_string());
        }
    }
    services
}

// ---------------------------------------------------------------------------
// A unit's log
// ---------------------------------------------------------------------------

/// One line of a unit's log.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ServiceLogLine {
    /// `HH:MM:SS` as the server printed it, in the server's time zone.
    pub time: Option<String>,
    pub text: String,
}

/// What a unit last said.
#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize)]
pub struct ServiceLog {
    pub lines: Vec<ServiceLogLine>,
    /// This account may not read the log it asked for. Not the same as an
    /// empty log, which a unit that has never run has.
    pub unreadable: bool,
}

#[cfg(test)]
mod tests {
    use super::*;

    fn unit(name: &str, state: ServiceState) -> ServiceUnit {
        ServiceUnit::new(name, ServiceUnitType::Service, ServiceScope::System, state)
    }

    #[test]
    fn the_probe_reads_the_manager_and_the_os() {
        assert_eq!(
            parse_probe("systemd\tDebian GNU/Linux").manager_type,
            Some(ServiceManagerType::Systemd)
        );
        assert_eq!(
            parse_probe("procd\tiStoreOS 25.12.5").manager_type,
            Some(ServiceManagerType::Procd)
        );
        assert_eq!(
            parse_probe("openrc\tAlpine Linux").manager_type,
            Some(ServiceManagerType::Openrc)
        );

        let unsupported = parse_probe("runit\tVoid Linux");
        assert_eq!(unsupported.manager_type, None);
        assert_eq!(unsupported.detected_name, "runit");
        assert_eq!(unsupported.description(), "runit (Void Linux)");

        // Nothing was detected: `unknown` is the script's word for that, not a
        // manager's name.
        let nothing = parse_probe("unknown\t");
        assert_eq!(nothing.detected_name, "");
        assert_eq!(nothing.os_name, "");
    }

    #[test]
    fn procd_is_tried_before_the_generic_init_d_fallback() {
        let procd = DETECT_SCRIPT.find("manager=procd").expect("procd branch");
        let sysvinit = DETECT_SCRIPT.find("manager=sysvinit").expect("sysvinit branch");
        assert!(procd < sysvinit);
    }

    #[test]
    fn a_listing_row_carries_type_state_and_description() {
        let output = "\
sshd.service loaded active running OpenSSH server daemon
nginx.service loaded inactive dead A high performance web server
broken.service loaded failed failed Broken unit description
dbus.socket loaded active running D-Bus System Message Bus Socket
backup.timer loaded active waiting Daily backup timer
unsupported.target loaded active active A target
";
        let units = parse_list_units(output, ServiceScope::System);
        assert_eq!(units.len(), 5);

        let sshd = &units[0];
        assert_eq!(sshd.name, "sshd");
        assert_eq!(sshd.full_name, "sshd.service");
        assert_eq!(sshd.key(), "system:sshd.service");
        assert_eq!(sshd.unit_type, ServiceUnitType::Service);
        assert_eq!(sshd.state, ServiceState::Running);
        assert_eq!(sshd.scope, ServiceScope::System);
        assert_eq!(sshd.description.as_deref(), Some("OpenSSH server daemon"));
        assert_eq!(sshd.sub_state.as_deref(), Some("running"));
        assert_eq!(units[1].state, ServiceState::Stopped);
        assert_eq!(units[2].state, ServiceState::Failed);
        assert_eq!(units[3].unit_type, ServiceUnitType::Socket);
        assert_eq!(units[4].unit_type, ServiceUnitType::Timer);
    }

    #[test]
    fn actions_follow_the_state_and_the_startup_registration() {
        assert_eq!(
            service_actions(ServiceState::Running, None),
            [ServiceAction::Stop, ServiceAction::Restart]
        );
        assert_eq!(
            service_actions(ServiceState::Stopped, None),
            [ServiceAction::Start]
        );
        assert_eq!(
            service_actions(ServiceState::Failed, Some(true)),
            [ServiceAction::Restart, ServiceAction::Disable]
        );
        assert_eq!(
            service_actions(ServiceState::Unknown, Some(false)),
            [
                ServiceAction::Start,
                ServiceAction::Restart,
                ServiceAction::Enable
            ]
        );
        // Neither enabled nor disabled: neither is offered.
        assert_eq!(
            service_actions(ServiceState::Starting, None),
            [ServiceAction::Stop]
        );
        assert_eq!(
            service_actions(ServiceState::Stopping, None),
            [ServiceAction::Start]
        );
        assert!(ServiceAction::Stop.destructive());
        assert!(ServiceAction::Restart.destructive());
        assert!(ServiceAction::Disable.destructive());
        assert!(!ServiceAction::Start.destructive());
        assert!(!ServiceAction::Enable.destructive());
    }

    #[test]
    fn the_user_scope_leads_a_list_and_running_follows_it() {
        let mut user_stopped =
            ServiceUnit::new("a", ServiceUnitType::Service, ServiceScope::User, ServiceState::Stopped);
        let mut system_running = unit("z", ServiceState::Running);
        let system_stopped = unit("b", ServiceState::Stopped);
        let mut units = [
            system_stopped.clone(),
            system_running.clone(),
            user_stopped.clone(),
        ];
        units.sort_by(compare_services);
        assert_eq!(
            units.iter().map(|unit| unit.name.as_str()).collect::<Vec<_>>(),
            ["a", "z", "b"]
        );

        // Within one scope the state decides first, then the name.
        user_stopped.state = ServiceState::Running;
        system_running.state = ServiceState::Stopped;
        let mut pair = [system_running, user_stopped];
        pair.sort_by(compare_services);
        assert_eq!(pair[0].name, "a");
    }

    #[test]
    fn a_unit_is_only_as_enabled_as_the_manager_said() {
        let mut listed = unit("sshd", ServiceState::Running);
        assert_eq!(listed.enabled, None);
        assert_eq!(listed.startup(), None);

        listed.set_enabled(Some(false));
        assert_eq!(listed.startup(), Some("disabled"));
        assert!(listed.actions.contains(&ServiceAction::Enable));

        // systemd's own word wins over the boolean, which cannot say `static`.
        listed.unit_file_state = Some("static".to_string());
        assert_eq!(listed.startup(), Some("static"));
    }
}
