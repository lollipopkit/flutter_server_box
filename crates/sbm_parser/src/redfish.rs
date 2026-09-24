//! Redfish: what a baseboard management controller says about itself, and the
//! one request that changes it.
//!
//! A BMC is reached by the app over the network directly
//! (`packages/redfish`), and by an agent from the machine it already runs on.
//! Both read the same service, so the model is here and the transport is the
//! caller's — `pve`'s arrangement, for `pve`'s reason.
//!
//! The rule throughout is that **nothing about the resource layout is
//! assumed**. Ids differ per vendor (`1`, `System.Embedded.1`, `system`), the
//! sensor model differs by firmware generation, and a reset type being
//! advertised is not the same as it being implemented. Every path here comes
//! from what the service said rather than from a template, which is also why
//! nothing in this module builds a URL out of a caller's string.
//!
//! **What is not here yet.** Four parts of the Dart package are unused by the
//! app's own page and have no endpoint: `log` (the SEL), `manager` (the
//! controller's own firmware and reset), `boot` (one-shot boot overrides) and
//! `components`/`task` (inventory and the `PercentComplete` of an accepted
//! reset). TODO(migration): port them when something serves them, rather than
//! describing shapes no endpoint answers for.
//!
//! `packages/redfish` is a submodule, so the vendor documents under test here
//! are transcribed from its suite (`test/resources_test.dart`,
//! `test/sensors_test.dart`) rather than read from a fixture both sides share —
//! the arrangement `test/fixtures/pve/` has. TODO(migration): once that
//! package's model is deleted, move those documents to `test/fixtures/bmc/` and
//! read them from both sides for one commit.
//!
//! Units are the service's: temperatures in `Cel`, fans in whatever the member
//! said (`RPM` or `Percent`), power in watts. They are passed through
//! unchanged, since the client that draws them is the one that knows the
//! format.

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

/// The service root, which Redfish leaves unauthenticated — what makes it the
/// place to ask whether anything is there at all.
pub const ROOT_PATH: &str = "/redfish/v1/";

/// How many members of a `Sensors` collection are read.
///
/// A bound on fetching, not on the model: each member is its own request to a
/// device that answers in seconds, and a chassis that publishes more than this
/// has its readings truncated rather than the page never arriving. The
/// truncation is reported — a silently short list of fans reads as a machine
/// that lost one.
pub const MAX_SENSOR_MEMBERS: usize = 64;

/// The longest path that will be sent a request.
pub const MAX_PATH: usize = 1024;

/// The SHA-256 fingerprint of a certificate, as hex.
pub const FINGERPRINT_LEN: usize = 64;

// --- Reading a document ---

/// A `@odata.id` reference, which is how Redfish links everything.
///
/// Kept as the raw path rather than resolved against a base: the service root
/// is already absolute in every response, and joining would only invent a way
/// to be wrong.
pub fn odata_id(value: &Value) -> Option<&str> {
    let id = value.get("@odata.id")?.as_str()?;
    (!id.is_empty()).then_some(id)
}

/// The `Members` of a Redfish collection, as paths.
///
/// An absent or malformed `Members` yields an empty list rather than an error:
/// a service that offers no systems is one there is nothing to show for, which
/// is a state to report and not a parse failure.
pub fn collection_members(body: &Value) -> Vec<&str> {
    let Some(members) = body.get("Members").and_then(Value::as_array) else {
        return Vec::new();
    };
    members.iter().filter_map(odata_id).collect()
}

/// A JSON array as a list, with anything that is not one read as empty.
fn list(raw: Option<&Value>) -> impl Iterator<Item = &Value> {
    raw.and_then(Value::as_array)
        .map(|a| a.iter())
        .into_iter()
        .flatten()
}

/// A JSON number, and only a number. A service that sends `"42"` is sending a
/// shape this does not read, and reading it as 42 would be inventing what it
/// meant.
fn number(raw: Option<&Value>) -> Option<f64> {
    raw.and_then(Value::as_f64).filter(|v| v.is_finite())
}

/// The name of a sensor member: its own, its id, or a placeholder.
fn member_name(member: &Value) -> &str {
    member
        .get("Name")
        .and_then(Value::as_str)
        .or_else(|| member.get("MemberId").and_then(Value::as_str))
        .unwrap_or("?")
}

/// A string field, empty read as absent.
fn text(value: &Value, key: &str) -> Option<String> {
    value
        .get(key)
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .map(str::to_string)
}

// --- The service root ---

/// What `GET /redfish/v1/` said.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedfishRoot {
    /// Collection paths, absent on a service that offers neither — which is
    /// what something answering on the address but not a BMC looks like.
    pub systems: Option<String>,
    pub chassis: Option<String>,
    /// Where a session is created. Absent means Basic auth is the only way in.
    pub sessions: Option<String>,
    pub version: Option<String>,
    /// Free text, and the only hint of who made this. Reported, never branched
    /// on: the vendor name is not what decides which resources exist.
    pub product: Option<String>,
    pub vendor: Option<String>,
}

impl RedfishRoot {
    /// Reads a root. Lenient: a body that parses but carries none of this is
    /// how a static host answering every path with its index page looks, and
    /// that is `is_service`'s answer rather than a parse failure.
    pub fn parse(body: &Value) -> Self {
        Self {
            systems: body.get("Systems").and_then(odata_id).map(str::to_string),
            chassis: body.get("Chassis").and_then(odata_id).map(str::to_string),
            // `Links.Sessions` is where the specification puts it;
            // `SessionService` at the top level is where it can also be found,
            // and some services fill in only one.
            sessions: body
                .get("Links")
                .and_then(|links| links.get("Sessions"))
                .and_then(odata_id)
                .or_else(|| body.get("SessionService").and_then(odata_id))
                .map(str::to_string),
            version: text(body, "RedfishVersion"),
            product: text(body, "Product"),
            vendor: text(body, "Vendor"),
        }
    }

    /// Whether this looks like a Redfish service at all.
    pub fn is_service(&self) -> bool {
        self.systems.is_some() || self.chassis.is_some()
    }
}

// --- Power state ---

/// The power states Redfish defines. `Unknown` covers a service that reported
/// something newer than this, which is a thing to display rather than fail on.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PowerState {
    On,
    Off,
    PoweringOn,
    PoweringOff,
    Paused,
    #[default]
    Unknown,
}

impl PowerState {
    /// Redfish's own spelling, which is what this is read *from* and what a
    /// log line should say.
    ///
    /// Not what a client receives: the enum's serde form is this module's
    /// camelCase convention (`on`, `poweringOn`), shared with `PowerIntent` and
    /// `RedfishFailure`, so a client has one casing to read rather than a
    /// different one per enum. `parse` accepts what the service sent.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::On => "On",
            Self::Off => "Off",
            Self::PoweringOn => "PoweringOn",
            Self::PoweringOff => "PoweringOff",
            Self::Paused => "Paused",
            Self::Unknown => "Unknown",
        }
    }

    pub fn parse(raw: Option<&str>) -> Self {
        match raw {
            Some("On") => Self::On,
            Some("Off") => Self::Off,
            Some("PoweringOn") => Self::PoweringOn,
            Some("PoweringOff") => Self::PoweringOff,
            Some("Paused") => Self::Paused,
            _ => Self::Unknown,
        }
    }

    /// Whether the machine is settling into this rather than resting in it —
    /// what a poll after a reset is waiting to get past. Reporting
    /// `PoweringOff` as the result would be reporting the request back.
    pub fn is_transitional(self) -> bool {
        matches!(self, Self::PoweringOn | Self::PoweringOff)
    }
}

// --- A ComputerSystem ---

/// A `ComputerSystem`, and the action on it.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedfishSystem {
    pub power_state: PowerState,
    pub model: Option<String>,
    pub manufacturer: Option<String>,
    pub serial: Option<String>,
    pub bios_version: Option<String>,
    pub health: Option<String>,
    /// Where to POST a reset, as the service gave it.
    ///
    /// Taken from the action rather than built from the system's own path: the
    /// two agree on every service seen, but only one of them is what the
    /// service said, and the other is a guess that happens to be right.
    pub reset_target: Option<String>,
    /// `ResetType@Redfish.AllowableValues`, verbatim.
    ///
    /// Advertised is not implemented — `Nmi` and `PowerCycle` in particular are
    /// commonly listed and unimplemented or licence-gated — but it is the only
    /// statement the service makes, and acting outside it is certainly wrong.
    pub reset_types: Vec<String>,
}

impl RedfishSystem {
    pub fn parse(body: &Value) -> Self {
        let reset = body.get("Actions").and_then(|a| a.get("#ComputerSystem.Reset"));
        let status = body.get("Status");
        Self {
            power_state: PowerState::parse(body.get("PowerState").and_then(Value::as_str)),
            model: text(body, "Model"),
            manufacturer: text(body, "Manufacturer"),
            serial: text(body, "SerialNumber"),
            bios_version: text(body, "BiosVersion"),
            // `HealthRollup` where present — it accounts for the subsystems,
            // which is the question someone looking at one line wants answered.
            health: status
                .and_then(|s| s.get("HealthRollup").or_else(|| s.get("Health")))
                .and_then(Value::as_str)
                .map(str::to_string),
            reset_target: reset
                .and_then(|r| r.get("target"))
                .and_then(Value::as_str)
                .map(str::to_string),
            reset_types: reset
                .and_then(|r| r.get("ResetType@Redfish.AllowableValues"))
                .and_then(Value::as_array)
                .map(|values| {
                    values
                        .iter()
                        .filter_map(Value::as_str)
                        .map(str::to_string)
                        .collect()
                })
                .unwrap_or_default(),
        }
    }

    /// Whether this system can be asked for anything at all.
    ///
    /// An action with no allowable values is not usable: some services omit the
    /// annotation entirely, and guessing from the specification's enum would
    /// mean sending something the service never claimed to take.
    pub fn can_reset(&self) -> bool {
        self.reset_target.is_some() && !self.reset_types.is_empty()
    }

    /// The request that would carry out `intent`, or `None` when the service
    /// allows nothing for it.
    ///
    /// `None` is a real answer and a caller has to show it as one: an intent
    /// with nothing behind it is not offered, rather than offered and failing
    /// when pressed.
    pub fn reset_request(&self, intent: PowerIntent) -> Option<ResetRequest> {
        let target = self.reset_target.as_deref()?;
        // The target is a path this agent will send with its own credential.
        // A service that names an origin for it is naming somewhere the
        // credential was not configured for, and nothing here resolves one
        // against a base URL to find out whether it happens to be the same
        // host. TODO: if a vendor turns out to emit an absolute URI pointing
        // at itself, resolve it against the configured address here rather
        // than dropping the intent.
        if !is_safe_path(target) {
            return None;
        }
        let reset_type = resolve_reset_type(intent, &self.reset_types)?;
        Some(ResetRequest {
            target: target.to_string(),
            reset_type,
        })
    }
}

/// A path this crate will send a request to.
///
/// Relative and rooted, with no scheme, no authority and no traversal: the one
/// thing all three would do is address a host other than the one the operator
/// configured, and the request carries the BMC's own credential.
pub fn is_safe_path(path: &str) -> bool {
    path.len() <= MAX_PATH
        && path.starts_with('/')
        && !path.contains("//")
        && !path.contains("..")
        && !path.contains('\\')
        && !path.contains(char::is_whitespace)
        && !path.chars().any(char::is_control)
}

// --- Power intents ---

/// What the user is asking for, as opposed to what Redfish calls it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PowerIntent {
    On,
    GracefulShutdown,
    ForceOff,
    Restart,
    PowerCycle,
}

impl PowerIntent {
    /// Every intent, in the order a form offers them: the two that reach a
    /// running machine, then the three that end or restart it.
    pub const ALL: [Self; 5] = [
        Self::On,
        Self::GracefulShutdown,
        Self::ForceOff,
        Self::Restart,
        Self::PowerCycle,
    ];

    pub fn as_str(self) -> &'static str {
        match self {
            Self::On => "on",
            Self::GracefulShutdown => "gracefulShutdown",
            Self::ForceOff => "forceOff",
            Self::Restart => "restart",
            Self::PowerCycle => "powerCycle",
        }
    }

    /// Reads the spelling a caller sent. An intent nobody understands is not
    /// silently read as the nearest one.
    pub fn parse(raw: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|i| i.as_str() == raw)
    }

    /// The `ResetType` values that satisfy this intent, best first.
    ///
    /// A chain rather than a single value because services differ in which they
    /// implement, and because the polite form of an operation is worth
    /// preferring where it exists. `restart` falling back to `ForceRestart` is
    /// the one that matters in practice — Dell has no `GracefulRestart`.
    pub fn candidates(self) -> &'static [&'static str] {
        match self {
            Self::On => &["On", "ForceOn"],
            Self::GracefulShutdown => &["GracefulShutdown"],
            Self::ForceOff => &["ForceOff"],
            Self::Restart => &["GracefulRestart", "ForceRestart"],
            // `ForcePowerCycle` is not in the Redfish `ResetType` enum, but an
            // H3C R5350 G6 advertises it and nothing else that power-cycles.
            // Without it the intent fell through to `ForceRestart`, which is a
            // different operation — the machine restarts instead of losing
            // power, under a button that said power cycle.
            Self::PowerCycle => &["PowerCycle", "ForcePowerCycle", "ForceRestart"],
        }
    }
}

/// The `ResetType` to send for `intent`, or `None` when nothing satisfies it.
///
/// A graceful shutdown has no fallback by design: `ForceOff` is not a shutdown,
/// and quietly substituting it would take a machine down hard when someone
/// asked for the polite thing.
pub fn resolve_reset_type(intent: PowerIntent, allowed: &[String]) -> Option<String> {
    intent
        .candidates()
        .iter()
        .find(|c| allowed.iter().any(|a| a == *c))
        .map(|c| (*c).to_string())
}

/// What would be sent to a system's reset action.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResetRequest {
    pub target: String,
    pub reset_type: String,
}

impl ResetRequest {
    /// The body, which carries the `ResetType` and nothing else.
    pub fn body(&self) -> Value {
        json!({ "ResetType": self.reset_type })
    }
}

// --- A Chassis, and which sensors it has ---

/// A `Chassis`, and where its readings are.
///
/// Redfish 2020.4 deprecated `Thermal` and `Power` for `ThermalSubsystem`,
/// `PowerSubsystem` and one `Sensors` collection. Firmware follows unevenly —
/// Supermicro switched at X14, so X11 through X13 are still on the old one —
/// and transitional firmware carries **both**.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct RedfishChassis {
    pub thermal: Option<String>,
    pub power: Option<String>,
    pub thermal_subsystem: Option<String>,
    pub power_subsystem: Option<String>,
    pub sensors: Option<String>,
    pub name: Option<String>,
}

impl RedfishChassis {
    pub fn parse(body: &Value) -> Self {
        Self {
            thermal: body.get("Thermal").and_then(odata_id).map(str::to_string),
            power: body.get("Power").and_then(odata_id).map(str::to_string),
            thermal_subsystem: body
                .get("ThermalSubsystem")
                .and_then(odata_id)
                .map(str::to_string),
            power_subsystem: body
                .get("PowerSubsystem")
                .and_then(odata_id)
                .map(str::to_string),
            sensors: body.get("Sensors").and_then(odata_id).map(str::to_string),
            name: text(body, "Name"),
        }
    }

    /// Whether the new model is available here.
    ///
    /// `Sensors` is what carries the readings in it, so a chassis advertising
    /// `ThermalSubsystem` without one has nothing readable through the new path
    /// and is treated as old.
    pub fn has_modern_sensors(&self) -> bool {
        self.sensors.is_some() && (self.thermal_subsystem.is_some() || self.power_subsystem.is_some())
    }

    /// Whether the deprecated pair is available.
    pub fn has_legacy_sensors(&self) -> bool {
        self.thermal.is_some() || self.power.is_some()
    }

    /// Which to read. The new model wins where both are present — that is what
    /// the deprecation means, and transitional firmware is where both appear.
    pub fn sensor_model(&self) -> SensorModel {
        if self.has_modern_sensors() {
            SensorModel::Modern
        } else if self.has_legacy_sensors() {
            SensorModel::Legacy
        } else {
            SensorModel::None
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SensorModel {
    Modern,
    Legacy,
    None,
}

impl SensorModel {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Modern => "modern",
            Self::Legacy => "legacy",
            Self::None => "none",
        }
    }

    pub fn parse(raw: &str) -> Option<Self> {
        match raw {
            "modern" => Some(Self::Modern),
            "legacy" => Some(Self::Legacy),
            "none" => Some(Self::None),
            _ => None,
        }
    }
}

/// Which resources to fetch for a chassis, given what it linked.
///
/// Returned as paths rather than fetched, so the decision is testable and the
/// fetching stays in one place.
pub fn sensor_paths(chassis: &RedfishChassis) -> Vec<&str> {
    match chassis.sensor_model() {
        SensorModel::Modern => chassis.sensors.as_deref().into_iter().collect(),
        SensorModel::Legacy => [chassis.thermal.as_deref(), chassis.power.as_deref()]
            .into_iter()
            .flatten()
            .collect(),
        SensorModel::None => Vec::new(),
    }
}

// --- Readings ---

/// One thing a BMC measured.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BmcReading {
    pub name: String,
    pub value: f64,
    /// As the service labelled it, or what the model implies. Kept rather than
    /// normalised: a fan reported in `Percent` and one in `RPM` are different
    /// numbers, and rewriting either into the other would invent data.
    pub unit: Option<String>,
}

/// What a chassis had to say about itself.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct BmcSensors {
    pub temperatures: Vec<BmcReading>,
    pub fans: Vec<BmcReading>,
    /// Input power for the whole chassis, where the service reports one.
    pub watts: Option<f64>,
}

/// Colder than absolute zero, or hotter than anything that would still be a
/// chassis.
const TEMPERATURE_MIN: f64 = -273.15;
const TEMPERATURE_MAX: f64 = 1000.0;

/// A fan reading is RPM or a percentage; neither is ever negative, and no fan
/// in a server turns this fast.
const FAN_MAX: f64 = 100_000.0;

/// A chassis drawing more than this is not one.
const WATTS_MAX: f64 = 100_000.0;

impl BmcSensors {
    pub fn is_empty(&self) -> bool {
        self.temperatures.is_empty() && self.fans.is_empty() && self.watts.is_none()
    }

    /// The deprecated pair: `Chassis/{id}/Thermal` and `/Power`.
    ///
    /// Either may be absent — they are separate resources with separate
    /// permissions — so both are optional and what is missing is simply missing.
    pub fn from_legacy(thermal: Option<&Value>, power: Option<&Value>) -> Self {
        let mut temperatures = Vec::new();
        let mut fans = Vec::new();
        let mut watts = None;

        for entry in list(thermal.and_then(|t| t.get("Temperatures"))) {
            // A sensor that is present but has nothing to say reports null or a
            // sentinel — see `reading`. A reading of 0 °C would be a lie rather
            // than a gap, so neither is turned into one.
            let Some(value) = reading(
                entry.get("ReadingCelsius"),
                TEMPERATURE_MIN,
                TEMPERATURE_MAX,
            ) else {
                continue;
            };
            temperatures.push(BmcReading {
                name: member_name(entry).to_string(),
                value,
                unit: Some("Cel".to_string()),
            });
        }

        for entry in list(thermal.and_then(|t| t.get("Fans"))) {
            // `Reading` is current; `ReadingRPM` is what older services called it
            let value = reading(entry.get("Reading"), 0.0, FAN_MAX)
                .or_else(|| reading(entry.get("ReadingRPM"), 0.0, FAN_MAX));
            let Some(value) = value else { continue };
            fans.push(BmcReading {
                name: member_name(entry).to_string(),
                value,
                unit: Some(
                    entry
                        .get("ReadingUnits")
                        .and_then(Value::as_str)
                        .unwrap_or("RPM")
                        .to_string(),
                ),
            });
        }

        // The first readable rail, not the largest: this is the deprecated
        // shape and its `PowerControl` holds one entry per service seen, where
        // the modern model's several rails are where the maximum is the one
        // about the whole machine.
        for entry in list(power.and_then(|p| p.get("PowerControl"))) {
            if watts.is_none() {
                watts = reading(entry.get("PowerConsumedWatts"), 0.0, WATTS_MAX);
            }
        }

        Self {
            temperatures,
            fans,
            watts,
        }
    }

    /// The current model: one `Sensors` collection, each member typed.
    ///
    /// Takes the members already fetched rather than a collection to walk,
    /// because how many of them to fetch is a decision about a slow device and
    /// belongs to the caller rather than to a parser.
    pub fn from_sensors(members: &[Value]) -> Self {
        let mut temperatures = Vec::new();
        let mut fans = Vec::new();
        let mut watts = None;

        for member in members {
            let name = member_name(member);
            let unit = member.get("ReadingUnits").and_then(Value::as_str);
            let kind = member.get("ReadingType").and_then(Value::as_str).unwrap_or("");
            // The bound depends on what is being measured, so the reading is
            // taken per type rather than once up front.
            let raw = member.get("Reading");
            match kind {
                "Temperature" => {
                    let Some(value) = reading(raw, TEMPERATURE_MIN, TEMPERATURE_MAX) else {
                        continue;
                    };
                    temperatures.push(BmcReading {
                        name: name.to_string(),
                        value,
                        unit: Some(unit.unwrap_or("Cel").to_string()),
                    });
                }
                // A fan reported as a percentage is still a fan. What makes it
                // one is the type together with the name, since `Percent` alone
                // describes a CPU utilisation just as well.
                "Rotational" => {
                    let Some(value) = reading(raw, 0.0, FAN_MAX) else {
                        continue;
                    };
                    fans.push(BmcReading {
                        name: name.to_string(),
                        value,
                        unit: Some(unit.unwrap_or("RPM").to_string()),
                    });
                }
                "Percent" if name.to_lowercase().contains("fan") => {
                    let Some(value) = reading(raw, 0.0, FAN_MAX) else {
                        continue;
                    };
                    fans.push(BmcReading {
                        name: name.to_string(),
                        value,
                        unit: Some(unit.unwrap_or("RPM").to_string()),
                    });
                }
                "Power" => {
                    let Some(value) = reading(raw, 0.0, WATTS_MAX) else {
                        continue;
                    };
                    // The chassis total, not every rail: a service reports
                    // several, and the largest is the one about the whole
                    // machine.
                    if watts.is_none_or(|w| value > w) {
                        watts = Some(value);
                    }
                }
                // An unfamiliar type is ignored rather than guessed at.
                _ => {}
            }
        }

        Self {
            temperatures,
            fans,
            watts,
        }
    }
}

/// A reading, or `None` when the service is saying it has none.
///
/// `null` is what the specification suggests for a sensor with nothing to
/// report, and some firmware does that. Others send a sentinel: an H3C R5350 G6
/// reports `4294967295` — `0xFFFFFFFF`, unsigned -1 — for every temperature it
/// cannot read, which was 18 of its 20. Taken at face value that reaches a card
/// as `4294967295 Cel`.
///
/// Filtered by plausibility rather than by matching known sentinels: the next
/// vendor's is `65535` or `-1` or `127`, and a list of them is a list that is
/// always one short. Nothing real falls in these gaps — a chassis sensor below
/// absolute zero or above a thousand degrees is not a reading, and neither is a
/// fan at four billion RPM.
///
/// The gap stays narrow on purpose. `-1` is a sentinel in some firmware and is
/// also what a cold inlet reads, so it is kept: a filter that dropped it would
/// delete a real measurement to hide a fake one, and only one of those two
/// mistakes is visible to the person looking.
fn reading(raw: Option<&Value>, min: f64, max: f64) -> Option<f64> {
    let value = number(raw)?;
    (min..=max).contains(&value).then_some(value)
}

// --- Certificate pinning ---

/// A fingerprint as this crate stores and compares it: lowercase hex, no
/// separators.
///
/// Accepts what a person pastes — colons, spaces, dashes, either case — and
/// refuses anything that is not a fingerprint, so a stored pin is never a
/// string that can only fail to match.
pub fn normalize_fingerprint(input: &str) -> Option<String> {
    let mut out = String::with_capacity(FINGERPRINT_LEN);
    for c in input.chars() {
        match c {
            ':' | ' ' | '-' => continue,
            c if c.is_ascii_hexdigit() => out.push(c.to_ascii_lowercase()),
            _ => return None,
        }
    }
    (out.len() == FINGERPRINT_LEN).then_some(out)
}

/// Whether anything has been reviewed, which is not the same as whether what
/// was reviewed is what turned up.
pub fn is_pinned(pinned: Option<&str>) -> bool {
    pinned.and_then(normalize_fingerprint).is_some()
}

/// A fingerprint the way a BMC's own web interface prints it.
pub fn pretty_fingerprint(fingerprint: &str) -> Option<String> {
    let normalized = normalize_fingerprint(fingerprint)?;
    let mut out = String::with_capacity(FINGERPRINT_LEN + FINGERPRINT_LEN / 2);
    for (i, c) in normalized.chars().enumerate() {
        if i > 0 && i % 2 == 0 {
            out.push(':');
        }
        out.push(c.to_ascii_uppercase());
    }
    Some(out)
}

/// Whether a certificate matches the pin.
///
/// **Nothing reviewed means nothing accepted.** This is not trust on first use:
/// the first use is a request already carrying a password, so accepting
/// whatever turns up there would hand it to whatever turned up. A pin that is
/// absent, empty or unreadable therefore refuses every certificate, which is the
/// answer that stops the credential leaving.
///
/// The comparison itself is length-checked first and then runs without an early
/// exit, so a pin that is a prefix of the real fingerprint does not match. A
/// fingerprint is public — it is on screen and in a config file — so this guards
/// no secret, and what it is for is that no *near* match is ever a match.
pub fn fingerprint_matches(pinned: Option<&str>, actual: &str) -> bool {
    let Some(pinned) = pinned.and_then(normalize_fingerprint) else {
        return false;
    };
    let Some(actual) = normalize_fingerprint(actual) else {
        return false;
    };
    let mut diff = 0u8;
    for (a, b) in pinned.bytes().zip(actual.bytes()) {
        diff |= a ^ b;
    }
    diff == 0
}

// --- Authenticating ---

/// The header a created session's token is answered in and sent back in.
///
/// The specification's spelling. A service that answers only a `Set-Cookie` is
/// not one a caller can use, and this is the one place that says so.
pub const TOKEN_HEADER: &str = "x-auth-token";

/// The header a service that offers no session endpoint is presented instead.
///
/// Written as a function rather than left to the caller for `pve::token_header`'s
/// reason: it is the protocol's own spelling of a credential, and two callers
/// composing it would be two places to get the encoding wrong. The encoding is
/// `base64(user:password)`, fixed by RFC 7617 — no charset is appended, since
/// services differ on whether they accept one and the basic form is what they
/// all read.
pub fn basic_header(username: &str, password: &str) -> String {
    use base64::Engine as _;
    let raw = format!("{}:{password}", username.trim());
    let encoded = base64::engine::general_purpose::STANDARD.encode(raw.as_bytes());
    format!("Basic {encoded}")
}

// --- Failures ---

/// Why a BMC request could not be carried out.
///
/// One vocabulary for both callers, and the spellings are the app's own
/// (`lib/view/page/server/detail/bmc.dart` phrases each one today), so a panel
/// can answer a code without a second table of names.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum RedfishFailure {
    /// The address answers, and is not a Redfish service.
    NotAService,
    /// A service with no system in it. A blade enclosure with every node
    /// powered out is one of these, and so is a host answering on a BMC's port.
    NoSystem,
    /// The account is not allowed to read this resource. Licensing gates parts
    /// of some services.
    Forbidden,
    /// The certificate is not the one that was reviewed, or nothing was
    /// reviewed yet. Never a transient failure: it stays until someone looks.
    CertificateRejected,
    /// The account was refused.
    Unauthorized,
    /// Nothing stored to authenticate with.
    NoCredential,
    /// No address stored, so there is nothing to reach.
    NotConfigured,
    /// The service requires a precondition (an `ETag`) that was not sent.
    PreconditionRequired,
    /// The service allows nothing that satisfies the intent asked for.
    UnsupportedIntent,
    /// The answer was not a Redfish document.
    InvalidResponse,
    /// The service could not be reached at all.
    Unreachable,
}

impl RedfishFailure {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::NotAService => "notAService",
            Self::NoSystem => "noSystem",
            Self::Forbidden => "forbidden",
            Self::CertificateRejected => "certificateRejected",
            Self::Unauthorized => "unauthorized",
            Self::NoCredential => "noCredential",
            Self::NotConfigured => "notConfigured",
            Self::PreconditionRequired => "preconditionRequired",
            Self::UnsupportedIntent => "unsupportedIntent",
            Self::InvalidResponse => "invalidResponse",
            Self::Unreachable => "unreachable",
        }
    }

    pub fn parse(raw: &str) -> Option<Self> {
        const ALL: [RedfishFailure; 11] = [
            RedfishFailure::NotAService,
            RedfishFailure::NoSystem,
            RedfishFailure::Forbidden,
            RedfishFailure::CertificateRejected,
            RedfishFailure::Unauthorized,
            RedfishFailure::NoCredential,
            RedfishFailure::NotConfigured,
            RedfishFailure::PreconditionRequired,
            RedfishFailure::UnsupportedIntent,
            RedfishFailure::InvalidResponse,
            RedfishFailure::Unreachable,
        ];
        ALL.into_iter().find(|f| f.as_str() == raw)
    }

    /// Whether this is a failure of the transport rather than of the request.
    ///
    /// What a caller turns into a bad-gateway: the machine could not be reached,
    /// or could not be read. Everything else is about the caller's request or
    /// the stored credential, which the operator can act on — and one of them is
    /// a certificate nobody has reviewed.
    pub fn is_transport(self) -> bool {
        matches!(self, Self::Unreachable | Self::InvalidResponse)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn allowed(values: &[&str]) -> Vec<String> {
        values.iter().map(|v| (*v).to_string()).collect()
    }

    fn system_offering(values: &[&str], target: &str) -> RedfishSystem {
        RedfishSystem::parse(&json!({
            "PowerState": "On",
            "Actions": {
                "#ComputerSystem.Reset": {
                    "target": target,
                    "ResetType@Redfish.AllowableValues": values,
                },
            },
        }))
    }

    #[test]
    fn a_malformed_members_list_is_empty_rather_than_an_error() {
        assert!(collection_members(&json!({ "Members": "nope" })).is_empty());
        assert!(collection_members(&json!({})).is_empty());
        assert_eq!(
            collection_members(&json!({
                "Members": [{ "no-odata-id": 1 }, { "@odata.id": "/ok" }],
            })),
            vec!["/ok"]
        );
    }

    #[test]
    fn a_static_host_answering_every_path_is_not_a_service() {
        let root = RedfishRoot::parse(&json!({ "title": "ServerBox" }));
        assert!(!root.is_service());
        assert_eq!(root.sessions, None);
    }

    #[test]
    fn the_session_endpoint_is_read_from_either_place_it_is_put() {
        let dell = RedfishRoot::parse(&json!({
            "Systems": { "@odata.id": "/redfish/v1/Systems" },
            "Links": { "Sessions": { "@odata.id": "/redfish/v1/Sessions" } },
        }));
        assert_eq!(dell.sessions.as_deref(), Some("/redfish/v1/Sessions"));
        assert!(dell.is_service());

        // Supermicro fills in SessionService and no Links.Sessions
        let supermicro = RedfishRoot::parse(&json!({
            "SessionService": { "@odata.id": "/redfish/v1/SessionService" },
        }));
        assert_eq!(
            supermicro.sessions.as_deref(),
            Some("/redfish/v1/SessionService")
        );
    }

    #[test]
    fn the_root_keeps_the_vendor_text_without_branching_on_it() {
        let root = RedfishRoot::parse(&json!({
            "RedfishVersion": "1.13.0",
            "Product": "Integrated Dell Remote Access Controller",
            "Vendor": "Dell",
        }));
        assert_eq!(root.version.as_deref(), Some("1.13.0"));
        assert_eq!(root.vendor.as_deref(), Some("Dell"));
    }

    #[test]
    fn health_prefers_the_rollup_which_accounts_for_the_subsystems() {
        let system = RedfishSystem::parse(&json!({
            "Status": { "Health": "OK", "HealthRollup": "Warning" },
        }));
        assert_eq!(system.health.as_deref(), Some("Warning"));

        // and the plain one where a service has only that
        let system = RedfishSystem::parse(&json!({ "Status": { "Health": "OK" } }));
        assert_eq!(system.health.as_deref(), Some("OK"));
    }

    #[test]
    fn an_unfamiliar_power_state_is_shown_rather_than_rejected() {
        assert_eq!(
            RedfishSystem::parse(&json!({ "PowerState": "Hibernating" })).power_state,
            PowerState::Unknown
        );
        assert_eq!(PowerState::parse(None), PowerState::Unknown);
    }

    #[test]
    fn a_transitional_state_is_not_arrival() {
        assert!(PowerState::PoweringOff.is_transitional());
        assert!(PowerState::PoweringOn.is_transitional());
        assert!(!PowerState::Off.is_transitional());
        assert!(!PowerState::On.is_transitional());
        assert!(!PowerState::Unknown.is_transitional());
    }

    #[test]
    fn the_power_state_spellings_are_the_wire_ones() {
        for state in [
            PowerState::On,
            PowerState::Off,
            PowerState::PoweringOn,
            PowerState::PoweringOff,
            PowerState::Paused,
            PowerState::Unknown,
        ] {
            assert_eq!(PowerState::parse(Some(state.as_str())), state);
        }
    }

    #[test]
    fn an_action_with_no_allowable_values_is_not_usable() {
        // Some services omit the annotation entirely. Guessing from the
        // specification's enum would mean sending something the service never
        // claimed to take.
        let system = RedfishSystem::parse(&json!({
            "Actions": { "#ComputerSystem.Reset": { "target": "/t" } },
        }));
        assert!(!system.can_reset());
        assert_eq!(system.reset_request(PowerIntent::ForceOff), None);
    }

    #[test]
    fn a_system_with_no_reset_action_offers_nothing() {
        let system = RedfishSystem::parse(&json!({ "PowerState": "On" }));
        assert!(!system.can_reset());
        for intent in PowerIntent::ALL {
            assert_eq!(system.reset_request(intent), None);
        }
    }

    #[test]
    fn an_intent_with_nothing_behind_it_is_not_offered() {
        // A button that fails when pressed is worse than one that was never
        // there, and `Nmi` and `PowerCycle` are advertised-but-unimplemented
        // often enough that this is not hypothetical.
        let system = system_offering(&["On", "ForceOff"], "/reset");
        let offered: Vec<PowerIntent> = PowerIntent::ALL
            .into_iter()
            .filter(|i| system.reset_request(*i).is_some())
            .collect();
        assert_eq!(offered, vec![PowerIntent::On, PowerIntent::ForceOff]);
    }

    #[test]
    fn restart_prefers_the_graceful_one_and_falls_back_where_it_is_absent() {
        // Supermicro has it, so the polite one is used
        assert_eq!(
            resolve_reset_type(
                PowerIntent::Restart,
                &allowed(&["GracefulRestart", "ForceRestart"]),
            )
            .as_deref(),
            Some("GracefulRestart")
        );
        // Dell has no GracefulRestart
        assert_eq!(
            resolve_reset_type(
                PowerIntent::Restart,
                &allowed(&["ForceRestart", "ForceOff", "On"]),
            )
            .as_deref(),
            Some("ForceRestart")
        );
    }

    #[test]
    fn a_graceful_shutdown_has_no_fallback_by_design() {
        // `ForceOff` is not a shutdown, and quietly substituting it would take
        // a machine down hard when someone asked for the polite thing.
        assert_eq!(
            resolve_reset_type(PowerIntent::GracefulShutdown, &allowed(&["ForceOff"])),
            None
        );
    }

    #[test]
    fn the_other_fallbacks_are_the_ones_that_were_needed() {
        assert_eq!(
            resolve_reset_type(PowerIntent::On, &allowed(&["ForceOn"])).as_deref(),
            Some("ForceOn")
        );
        assert_eq!(
            resolve_reset_type(PowerIntent::PowerCycle, &allowed(&["ForceRestart"])).as_deref(),
            Some("ForceRestart")
        );
    }

    #[test]
    fn an_h3c_offering_force_power_cycle_gets_a_power_cycle_not_a_restart() {
        // Read off an R5350 G6. `ForcePowerCycle` is not in the Redfish
        // `ResetType` enum, so it was not a candidate and the intent fell
        // through to `ForceRestart` — a different operation, under a button
        // that said power cycle.
        let h3c = allowed(&[
            "ForceOff",
            "ForcePowerCycle",
            "ForceRestart",
            "GracefulShutdown",
            "Nmi",
            "On",
        ]);
        assert_eq!(
            resolve_reset_type(PowerIntent::PowerCycle, &h3c).as_deref(),
            Some("ForcePowerCycle")
        );
        assert_eq!(
            resolve_reset_type(PowerIntent::On, &h3c).as_deref(),
            Some("On")
        );
        assert_eq!(
            resolve_reset_type(PowerIntent::GracefulShutdown, &h3c).as_deref(),
            Some("GracefulShutdown")
        );
        assert_eq!(
            resolve_reset_type(PowerIntent::ForceOff, &h3c).as_deref(),
            Some("ForceOff")
        );
        assert_eq!(
            resolve_reset_type(PowerIntent::Restart, &h3c).as_deref(),
            Some("ForceRestart")
        );
    }

    #[test]
    fn the_standard_name_wins_where_a_service_has_both() {
        assert_eq!(
            resolve_reset_type(
                PowerIntent::PowerCycle,
                &allowed(&["ForcePowerCycle", "PowerCycle", "ForceRestart"]),
            )
            .as_deref(),
            Some("PowerCycle"),
        );
    }

    #[test]
    fn an_intent_is_read_back_from_its_own_spelling_and_nothing_else() {
        for intent in PowerIntent::ALL {
            assert_eq!(PowerIntent::parse(intent.as_str()), Some(intent));
        }
        assert_eq!(PowerIntent::parse("ForcePowerCycle"), None);
        assert_eq!(PowerIntent::parse(""), None);
    }

    #[test]
    fn the_request_goes_to_the_target_the_service_named() {
        // The two agree everywhere seen, but only one of them is what the
        // service said.
        let system = system_offering(&["ForceOff"], "/somewhere/else/entirely");
        let request = system.reset_request(PowerIntent::ForceOff).unwrap();
        assert_eq!(request.target, "/somewhere/else/entirely");
        assert_eq!(request.body(), json!({ "ResetType": "ForceOff" }));
        assert_eq!(request.body().as_object().unwrap().len(), 1);
    }

    #[test]
    fn a_target_that_is_not_a_path_on_this_host_is_not_a_target() {
        // The request carries the BMC's own credential, so a target naming an
        // origin is one the credential was not configured for.
        for target in [
            "https://elsewhere.example/redfish/v1/Reset",
            "//elsewhere.example/redfish/v1/Reset",
            "/redfish/v1/../../elsewhere",
            "/redfish/v1/Reset?x=1 2",
            "redfish/v1/Reset",
        ] {
            let system = system_offering(&["ForceOff"], target);
            assert_eq!(
                system.reset_request(PowerIntent::ForceOff),
                None,
                "target {target}"
            );
        }
        assert!(is_safe_path(
            "/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset"
        ));
    }

    #[test]
    fn the_legacy_triple_is_read_as_the_service_labelled_it() {
        let sensors = BmcSensors::from_legacy(
            Some(&json!({
                "Temperatures": [
                    { "Name": "CPU1 Temp", "ReadingCelsius": 47 },
                    { "Name": "Inlet Temp", "ReadingCelsius": 21.5 },
                ],
                "Fans": [{ "Name": "FAN1", "Reading": 4800, "ReadingUnits": "RPM" }],
            })),
            Some(&json!({ "PowerControl": [{ "PowerConsumedWatts": 210 }] })),
        );

        assert_eq!(
            sensors.temperatures,
            vec![
                BmcReading {
                    name: "CPU1 Temp".into(),
                    value: 47.0,
                    unit: Some("Cel".into()),
                },
                BmcReading {
                    name: "Inlet Temp".into(),
                    value: 21.5,
                    unit: Some("Cel".into()),
                },
            ]
        );
        assert_eq!(sensors.fans[0].value, 4800.0);
        assert_eq!(sensors.watts, Some(210.0));
        assert!(!sensors.is_empty());
    }

    #[test]
    fn a_sensor_with_nothing_to_say_is_absent_rather_than_zero() {
        // Present-but-null is how a BMC reports a sensor it cannot read right
        // now. 0 °C would be a lie, and a lie that looks like data.
        let sensors = BmcSensors::from_legacy(
            Some(&json!({
                "Temperatures": [
                    { "Name": "CPU2 Temp", "ReadingCelsius": null },
                    { "Name": "CPU1 Temp", "ReadingCelsius": 40 },
                ],
            })),
            None,
        );
        assert_eq!(sensors.temperatures.len(), 1);
        assert_eq!(sensors.temperatures[0].name, "CPU1 Temp");
    }

    #[test]
    fn an_older_service_calling_it_reading_rpm_is_still_read() {
        let sensors = BmcSensors::from_legacy(
            Some(&json!({ "Fans": [{ "Name": "FAN1", "ReadingRPM": 3000 }] })),
            None,
        );
        assert_eq!(sensors.fans[0].value, 3000.0);
        assert_eq!(sensors.fans[0].unit.as_deref(), Some("RPM"));
    }

    #[test]
    fn the_unit_is_kept_rather_than_normalised() {
        // A fan reported in Percent and one in RPM are different numbers, and
        // rewriting either into the other would invent data.
        let sensors = BmcSensors::from_legacy(
            Some(&json!({
                "Fans": [{ "Name": "FAN1", "Reading": 38, "ReadingUnits": "Percent" }],
            })),
            None,
        );
        assert_eq!(sensors.fans[0].unit.as_deref(), Some("Percent"));
    }

    #[test]
    fn either_half_of_the_legacy_pair_may_be_missing_on_its_own() {
        // They are separate resources with separate permissions.
        let no_power = BmcSensors::from_legacy(
            Some(&json!({ "Temperatures": [{ "Name": "T", "ReadingCelsius": 30 }] })),
            None,
        );
        assert_eq!(no_power.watts, None);
        assert_eq!(no_power.temperatures.len(), 1);

        assert!(BmcSensors::from_legacy(None, None).is_empty());
    }

    #[test]
    fn the_sensors_collection_sorts_members_by_their_reading_type() {
        let sensors = BmcSensors::from_sensors(&[
            json!({ "Name": "CPU", "ReadingType": "Temperature", "Reading": 52.0 }),
            json!({
                "Name": "FAN0",
                "ReadingType": "Rotational",
                "Reading": 5200,
                "ReadingUnits": "RPM",
            }),
            json!({ "Name": "Total Power", "ReadingType": "Power", "Reading": 180 }),
        ]);

        assert_eq!(sensors.temperatures[0].name, "CPU");
        assert_eq!(sensors.temperatures[0].unit.as_deref(), Some("Cel"));
        assert_eq!(sensors.fans[0].value, 5200.0);
        assert_eq!(sensors.watts, Some(180.0));
    }

    #[test]
    fn the_largest_power_reading_is_the_one_about_the_whole_machine() {
        // Services report several rails; the chassis total is what a card shows.
        let sensors = BmcSensors::from_sensors(&[
            json!({ "Name": "PSU1 Input", "ReadingType": "Power", "Reading": 90 }),
            json!({ "Name": "Chassis Total", "ReadingType": "Power", "Reading": 175 }),
            json!({ "Name": "PSU2 Input", "ReadingType": "Power", "Reading": 85 }),
        ]);
        assert_eq!(sensors.watts, Some(175.0));
    }

    #[test]
    fn a_fan_reported_as_a_percentage_is_still_a_fan() {
        let sensors = BmcSensors::from_sensors(&[
            json!({
                "Name": "Fan 1 PWM",
                "ReadingType": "Percent",
                "Reading": 42,
                "ReadingUnits": "Percent",
            }),
            json!({ "Name": "CPU Utilisation", "ReadingType": "Percent", "Reading": 12 }),
        ]);
        // The second is a percentage of something else entirely, and belongs on
        // no fan row.
        assert_eq!(sensors.fans.len(), 1);
        assert_eq!(sensors.fans[0].name, "Fan 1 PWM");
    }

    #[test]
    fn a_member_with_no_reading_is_skipped_and_an_unfamiliar_type_is_ignored() {
        let sensors = BmcSensors::from_sensors(&[
            json!({ "Name": "CPU", "ReadingType": "Temperature", "Reading": null }),
            json!({ "Name": "Airflow", "ReadingType": "AirFlowCFM", "Reading": 30 }),
        ]);
        assert!(sensors.is_empty());
    }

    #[test]
    fn an_h3c_sentinel_is_no_reading_rather_than_four_billion_degrees() {
        // 18 of this machine's 20 temperature sensors read like this
        let sensors = BmcSensors::from_legacy(
            Some(&json!({
                "Temperatures": [
                    { "Name": "Inlet_Temp", "ReadingCelsius": 4294967295u32 },
                    { "Name": "CPU1_Temp", "ReadingCelsius": 4294967295u32 },
                    { "Name": "OCP_Temp", "ReadingCelsius": 59 },
                ],
                "Fans": [
                    { "Name": "Fan1", "Reading": 1050, "ReadingUnits": "RPM" },
                    { "Name": "Fan9", "Reading": 4294967295u32, "ReadingUnits": "RPM" },
                ],
            })),
            None,
        );

        assert_eq!(sensors.temperatures.len(), 1);
        assert_eq!(sensors.temperatures[0].name, "OCP_Temp");
        assert_eq!(sensors.temperatures[0].value, 59.0);
        assert_eq!(sensors.fans.len(), 1);
        assert_eq!(sensors.fans[0].name, "Fan1");
    }

    #[test]
    fn the_other_sentinels_go_the_same_way_and_real_readings_do_not() {
        // Filtered by plausibility rather than by a list of known sentinels,
        // which is always one vendor short.
        for sentinel in [4294967295u32, 65535, 0x7FFF_FFFF] {
            let sensors = BmcSensors::from_legacy(
                Some(&json!({ "Temperatures": [{ "Name": "t", "ReadingCelsius": sentinel }] })),
                None,
            );
            assert!(sensors.temperatures.is_empty(), "sentinel {sentinel}");
        }

        // The gap has to stay narrow enough to keep everything real. `-1` is a
        // sentinel in some firmware and is also what a cold inlet reads.
        for real in [-40, -1, 0, 4, 59, 105] {
            let sensors = BmcSensors::from_legacy(
                Some(&json!({ "Temperatures": [{ "Name": "t", "ReadingCelsius": real }] })),
                None,
            );
            assert_eq!(sensors.temperatures[0].value, real as f64, "real {real}");
        }
    }

    #[test]
    fn a_sentinel_wattage_is_not_a_four_gigawatt_chassis() {
        let legacy = BmcSensors::from_legacy(
            None,
            Some(&json!({ "PowerControl": [{ "PowerConsumedWatts": 4294967295u32 }] })),
        );
        assert_eq!(legacy.watts, None);

        // and the modern model filters the same way
        let modern = BmcSensors::from_sensors(&[
            json!({ "Name": "a", "ReadingType": "Temperature", "Reading": 4294967295u32 }),
            json!({ "Name": "b", "ReadingType": "Temperature", "Reading": 42 }),
            json!({ "Name": "Fan1", "ReadingType": "Rotational", "Reading": 4294967295u32 }),
            json!({ "Name": "Fan2", "ReadingType": "Rotational", "Reading": 900 }),
            json!({ "Name": "p", "ReadingType": "Power", "Reading": 4294967295u32 }),
        ]);
        assert_eq!(modern.temperatures.len(), 1);
        assert_eq!(modern.temperatures[0].name, "b");
        assert_eq!(modern.fans.len(), 1);
        assert_eq!(modern.fans[0].name, "Fan2");
        assert_eq!(modern.watts, None);
    }

    #[test]
    fn a_sensor_with_no_name_at_all_still_has_one_row() {
        let sensors = BmcSensors::from_sensors(&[
            json!({ "MemberId": "0", "ReadingType": "Temperature", "Reading": 30 }),
            json!({ "ReadingType": "Temperature", "Reading": 31 }),
        ]);
        assert_eq!(sensors.temperatures[0].name, "0");
        assert_eq!(sensors.temperatures[1].name, "?");
    }

    #[test]
    fn the_sensor_model_is_read_from_the_links_rather_than_the_vendor() {
        let legacy = RedfishChassis::parse(&json!({
            "Thermal": { "@odata.id": "/t" },
            "Power": { "@odata.id": "/p" },
        }));
        assert_eq!(legacy.sensor_model(), SensorModel::Legacy);
        assert_eq!(sensor_paths(&legacy), vec!["/t", "/p"]);

        let modern = RedfishChassis::parse(&json!({
            "ThermalSubsystem": { "@odata.id": "/ts" },
            "PowerSubsystem": { "@odata.id": "/ps" },
            "Sensors": { "@odata.id": "/s" },
        }));
        assert_eq!(modern.sensor_model(), SensorModel::Modern);
        assert_eq!(sensor_paths(&modern), vec!["/s"]);
    }

    #[test]
    fn transitional_firmware_carries_both_and_the_new_model_wins() {
        // Which is what deprecation means; a service offering both is mid-move.
        let chassis = RedfishChassis::parse(&json!({
            "Thermal": { "@odata.id": "/t" },
            "Power": { "@odata.id": "/p" },
            "ThermalSubsystem": { "@odata.id": "/ts" },
            "Sensors": { "@odata.id": "/s" },
        }));
        assert!(chassis.has_legacy_sensors());
        assert!(chassis.has_modern_sensors());
        assert_eq!(chassis.sensor_model(), SensorModel::Modern);
        assert_eq!(sensor_paths(&chassis), vec!["/s"]);
    }

    #[test]
    fn a_subsystem_without_sensors_has_nothing_readable_in_it() {
        // The readings live in `Sensors` under the new model, so the links alone
        // are not a path to anything.
        let chassis = RedfishChassis::parse(&json!({
            "ThermalSubsystem": { "@odata.id": "/ts" },
        }));
        assert_eq!(chassis.sensor_model(), SensorModel::None);
        assert!(sensor_paths(&chassis).is_empty());
        assert!(sensor_paths(&RedfishChassis::default()).is_empty());
    }

    #[test]
    fn the_sensor_model_names_round_trip() {
        for model in [SensorModel::Modern, SensorModel::Legacy, SensorModel::None] {
            assert_eq!(SensorModel::parse(model.as_str()), Some(model));
        }
        assert_eq!(SensorModel::parse("Modern"), None);
    }

    #[test]
    fn a_fingerprint_is_sha256_hex_and_reads_what_a_person_pastes() {
        let plain = "a".repeat(64);
        assert_eq!(normalize_fingerprint(&plain).as_deref(), Some(plain.as_str()));

        let pretty = "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:\
                      AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";
        assert_eq!(
            normalize_fingerprint(pretty).as_deref(),
            Some("aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899")
        );
        assert_eq!(
            normalize_fingerprint(&pretty.replace(':', " ")).as_deref(),
            normalize_fingerprint(pretty).as_deref()
        );

        // Anything that is not a fingerprint is not stored as one
        assert_eq!(normalize_fingerprint(""), None);
        assert_eq!(normalize_fingerprint(&"a".repeat(63)), None);
        assert_eq!(normalize_fingerprint(&"a".repeat(65)), None);
        assert_eq!(normalize_fingerprint(&"g".repeat(64)), None);
    }

    #[test]
    fn a_fingerprint_prints_the_way_a_bmc_web_interface_does() {
        assert_eq!(
            pretty_fingerprint("abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234abcd1234")
                .as_deref(),
            Some(
                "AB:CD:12:34:AB:CD:12:34:AB:CD:12:34:AB:CD:12:34:\
                 AB:CD:12:34:AB:CD:12:34:AB:CD:12:34:AB:CD:12:34"
            )
        );
        assert_eq!(pretty_fingerprint("abcd"), None);
    }

    /// The basic credential's encoding, which is RFC 7617's and nothing this
    /// crate chose: a service that offers no session endpoint is presented with
    /// `base64(user:password)`, and every implementation agrees on it.
    #[test]
    fn the_basic_credential_is_the_encoding_the_rfc_fixes() {
        assert_eq!(basic_header("root", "calvin"), "Basic cm9vdDpjYWx2aW4=");
        // The padding cases, since the alphabet and the `=` are all this has to
        // get right: one byte over, two bytes over, and exactly on a boundary.
        assert_eq!(basic_header("a", "b"), "Basic YTpi");
        assert_eq!(basic_header("ab", "cd"), "Basic YWI6Y2Q=");
        assert_eq!(basic_header("abc", "def"), "Basic YWJjOmRlZg==");
        // A password containing the separator is not escaped, escaped or split:
        // the first colon is the separator and the rest is the password.
        assert_eq!(
            base64::Engine::decode(
                &base64::engine::general_purpose::STANDARD,
                basic_header("admin", "a:b:c").trim_start_matches("Basic ")
            )
            .expect("decode"),
            b"admin:a:b:c"
        );
        // Trimmed, because a form field arrives with whatever was pasted.
        assert_eq!(basic_header("  root ", "x"), basic_header("root", "x"));
    }

    #[test]
    fn the_reviewed_certificate_is_the_only_one_accepted() {
        let a = "1".repeat(64);
        let b = format!("{}2", "1".repeat(63));

        assert!(fingerprint_matches(Some(&a), &a));
        assert!(!fingerprint_matches(Some(&a), &b));

        // Case-insensitively, since the pin is stored as text and pasted by a
        // person.
        assert!(fingerprint_matches(Some(&a.to_uppercase()), &a));

        // A pin that is a prefix of the real fingerprint must not pass
        assert!(!fingerprint_matches(Some(&a[..32]), &a));
    }

    #[test]
    fn nothing_reviewed_accepts_nothing() {
        // Not trust-on-first-*use*: the first use is a request already carrying
        // a password, so accepting whatever turns up there would hand it to
        // whatever turned up.
        let a = "1".repeat(64);
        assert!(!fingerprint_matches(None, &a));
        assert!(!fingerprint_matches(Some(""), &a));
        assert!(!fingerprint_matches(Some("not a fingerprint"), &a));

        // "Could not obtain one" must never read as "matches"
        assert!(!fingerprint_matches(Some(&a), ""));

        assert!(!is_pinned(None));
        assert!(!is_pinned(Some("")));
        assert!(is_pinned(Some(&a)));
    }

    #[test]
    fn a_failure_code_round_trips_and_says_whether_it_is_the_transport() {
        let all = [
            RedfishFailure::NotAService,
            RedfishFailure::NoSystem,
            RedfishFailure::Forbidden,
            RedfishFailure::CertificateRejected,
            RedfishFailure::Unauthorized,
            RedfishFailure::NoCredential,
            RedfishFailure::NotConfigured,
            RedfishFailure::PreconditionRequired,
            RedfishFailure::UnsupportedIntent,
            RedfishFailure::InvalidResponse,
            RedfishFailure::Unreachable,
        ];
        for failure in all {
            assert_eq!(RedfishFailure::parse(failure.as_str()), Some(failure));
            assert!(
                serde_json::to_value(failure).unwrap() == json!(failure.as_str()),
                "serde spelling of {}",
                failure.as_str()
            );
        }

        // A pin nobody reviewed and an unreachable service are not the same
        // kind of answer, and only one of them is about the network.
        assert!(RedfishFailure::Unreachable.is_transport());
        assert!(RedfishFailure::InvalidResponse.is_transport());
        assert!(!RedfishFailure::CertificateRejected.is_transport());
        assert!(!RedfishFailure::Unauthorized.is_transport());
        assert!(!RedfishFailure::UnsupportedIntent.is_transport());
    }

    #[test]
    fn what_a_client_receives_keeps_these_names() {
        // The panel reads these field names out of the overview document, so a
        // rename is a panel that draws blanks.
        let system = RedfishSystem::parse(&json!({
            "PowerState": "On",
            "SerialNumber": "ABCDEF1",
            "BiosVersion": "2.19.0",
        }));
        let value = serde_json::to_value(&system).unwrap();
        assert_eq!(value["power_state"], json!("on"));
        assert_eq!(value["serial"], json!("ABCDEF1"));
        assert_eq!(value["bios_version"], json!("2.19.0"));
        assert_eq!(value["reset_types"], json!([]));

        let sensors = BmcSensors::from_sensors(&[
            json!({ "Name": "CPU", "ReadingType": "Temperature", "Reading": 52 }),
        ]);
        let value = serde_json::to_value(&sensors).unwrap();
        assert_eq!(value["temperatures"][0]["name"], json!("CPU"));
        assert_eq!(value["temperatures"][0]["value"], json!(52.0));
        assert_eq!(value["temperatures"][0]["unit"], json!("Cel"));
        assert_eq!(value["watts"], json!(null));
        assert_eq!(value["fans"], json!([]));
    }
}
