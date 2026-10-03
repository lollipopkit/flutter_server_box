//! The Redfish resources this crate reads, and nothing about how they arrive.
//!
//! Pure on purpose: every vendor difference worth getting right lives here,
//! and none of it needs a BMC to test. Ported from the Dart package `redfish` (removed with this port)
//! (`resources.dart`, `sensors.dart`, `task.dart`, the topology half of
//! `discovery.dart`) and from the app's `BmcNotifier._awaitPowerChange`.
//!
//! The rule throughout is that nothing about the resource layout is assumed.
//! Ids differ per vendor, sensor models differ per firmware generation, and a
//! reset type being advertised is not the same as it being implemented — so
//! each is read from what the service said rather than built from a template.
//!
//! **Each field is read on its own.** A field of the wrong type is read as
//! absent, and never fails the resource around it. That is one place this
//! differs from the Dart model, whose `as String?` casts threw on, say, a
//! numeric `Model` and took the whole system with it. What counts as a value
//! is otherwise the same: a reading is a JSON number and only a number, so
//! `"42"` is no reading, exactly as Dart's `_num` had it.

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

/// A `@odata.id` reference, which is how Redfish links everything.
///
/// Kept as the raw path rather than resolved against a base: the service root
/// is already absolute in every response, and joining would only invent a way
/// to be wrong. An empty id is no id.
pub fn odata_id(json: &Value) -> Option<&str> {
    let id = json.get("@odata.id")?.as_str()?;
    (!id.is_empty()).then_some(id)
}

/// The `Members` of a Redfish collection, as paths.
///
/// An absent or malformed `Members` yields an empty list rather than an error:
/// a service that offers no systems is a service there is nothing to show for,
/// which is a state to report and not a parse failure.
pub fn collection_members(json: &Value) -> Vec<String> {
    json.get("Members")
        .and_then(Value::as_array)
        .map(|members| {
            members
                .iter()
                .filter_map(odata_id)
                .map(str::to_string)
                .collect()
        })
        .unwrap_or_default()
}

/// A string field, verbatim. Anything else is absent.
fn text(json: &Value, key: &str) -> Option<String> {
    json.get(key).and_then(Value::as_str).map(str::to_string)
}

/// The `odata_id` of a field, as an owned path.
fn link(json: &Value, key: &str) -> Option<String> {
    json.get(key).and_then(odata_id).map(str::to_string)
}

// --- The service root ---

/// What `GET /redfish/v1/` said.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct RedfishRoot {
    /// Collection paths, absent on a service that offers neither — which is
    /// how something that answers on the address but is not a BMC looks.
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
    pub fn from_json(json: &Value) -> Self {
        Self {
            systems: link(json, "Systems"),
            chassis: link(json, "Chassis"),
            sessions: session_link(json),
            version: text(json, "RedfishVersion"),
            product: text(json, "Product"),
            vendor: text(json, "Vendor"),
        }
    }

    /// Whether this looks like a Redfish service at all.
    ///
    /// A static host answers every path with its index page, and a JSON body
    /// that parses but has none of this is exactly what that looks like.
    pub fn is_service(&self) -> bool {
        self.systems.is_some() || self.chassis.is_some()
    }
}

/// Where sessions are created, from the service root.
///
/// `Links.Sessions` is where the specification puts it; `SessionService` at the
/// top level is where it can also be found, and some services fill in only one.
pub(crate) fn session_link(root: &Value) -> Option<String> {
    root.get("Links")
        .and_then(|links| links.get("Sessions"))
        .and_then(odata_id)
        .or_else(|| root.get("SessionService").and_then(odata_id))
        .map(str::to_string)
}

// --- Power ---

/// The power states Redfish defines. `Unknown` covers a service that reported
/// something newer than this, which is a thing to display rather than fail on.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PowerState {
    On,
    Off,
    PoweringOn,
    PoweringOff,
    Paused,
    Unknown,
}

impl PowerState {
    pub const ALL: [PowerState; 6] = [
        PowerState::On,
        PowerState::Off,
        PowerState::PoweringOn,
        PowerState::PoweringOff,
        PowerState::Paused,
        PowerState::Unknown,
    ];

    pub fn parse(raw: Option<&Value>) -> Self {
        match raw.and_then(Value::as_str) {
            Some("On") => Self::On,
            Some("Off") => Self::Off,
            Some("PoweringOn") => Self::PoweringOn,
            Some("PoweringOff") => Self::PoweringOff,
            Some("Paused") => Self::Paused,
            _ => Self::Unknown,
        }
    }

    /// The Dart enum's name, which is also how this serializes.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::On => "on",
            Self::Off => "off",
            Self::PoweringOn => "poweringOn",
            Self::PoweringOff => "poweringOff",
            Self::Paused => "paused",
            Self::Unknown => "unknown",
        }
    }

    /// Whether this is a state the machine is settling into rather than
    /// resting in — what a poll after a reset is waiting to get past.
    pub fn is_transitional(self) -> bool {
        matches!(self, Self::PoweringOn | Self::PoweringOff)
    }
}

/// A `ComputerSystem`, and the action on it.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
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
    /// Advertised is not implemented — `Nmi` and `PowerCycle` in particular
    /// are commonly listed and unimplemented or license-gated — but it is the
    /// only statement the service makes, and acting outside it is certainly
    /// wrong.
    pub reset_types: Vec<String>,
}

impl RedfishSystem {
    pub fn from_json(json: &Value) -> Self {
        let reset = json
            .get("Actions")
            .and_then(|a| a.get("#ComputerSystem.Reset"))
            .filter(|r| r.is_object());
        let status = json.get("Status").filter(|s| s.is_object());
        Self {
            power_state: PowerState::parse(json.get("PowerState")),
            model: text(json, "Model"),
            manufacturer: text(json, "Manufacturer"),
            serial: text(json, "SerialNumber"),
            bios_version: text(json, "BiosVersion"),
            // `HealthRollup` where present — it accounts for the subsystems,
            // which is the question someone looking at one line wants answered
            health: status.and_then(|s| text(s, "HealthRollup").or_else(|| text(s, "Health"))),
            reset_target: reset.and_then(|r| text(r, "target")),
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

    /// Where the reset action's `ActionInfo` is, when the service states its
    /// allowable values there rather than inline. OpenBMC's bmcweb does, and
    /// lists nothing inline: read only the inline form and an OpenBMC system
    /// offers no power action at all.
    pub fn reset_action_info(json: &Value) -> Option<String> {
        json.get("Actions")
            .and_then(|a| a.get("#ComputerSystem.Reset"))
            .and_then(|r| text(r, "@Redfish.ActionInfo"))
    }

    pub fn can_reset(&self) -> bool {
        self.reset_target.is_some() && !self.reset_types.is_empty()
    }
}

/// What the user is asking for, as opposed to what Redfish calls it.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum PowerIntent {
    On,
    GracefulShutdown,
    ForceOff,
    Restart,
    PowerCycle,
}

impl PowerIntent {
    /// In the Dart enum's order, which is the order a UI offers them in.
    pub const ALL: [PowerIntent; 5] = [
        PowerIntent::On,
        PowerIntent::GracefulShutdown,
        PowerIntent::ForceOff,
        PowerIntent::Restart,
        PowerIntent::PowerCycle,
    ];

    /// The Dart enum's name, which is also how this serializes.
    pub fn as_str(self) -> &'static str {
        match self {
            Self::On => "on",
            Self::GracefulShutdown => "gracefulShutdown",
            Self::ForceOff => "forceOff",
            Self::Restart => "restart",
            Self::PowerCycle => "powerCycle",
        }
    }

    pub fn parse(raw: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|i| i.as_str() == raw)
    }

    /// The `ResetType` values that satisfy this intent, best first.
    ///
    /// A chain rather than a single value because services differ in which
    /// they implement, and because the polite form of an operation is worth
    /// preferring where it exists. `Restart` falling back to `ForceRestart` is
    /// the one that matters in practice.
    pub fn candidates(self) -> &'static [&'static str] {
        match self {
            Self::On => &["On", "ForceOn"],
            Self::GracefulShutdown => &["GracefulShutdown"],
            Self::ForceOff => &["ForceOff"],
            Self::Restart => &["GracefulRestart", "ForceRestart"],
            // `ForcePowerCycle` is not in the Redfish `ResetType` enum, but an
            // H3C R5350 G6 advertises it and nothing else that power-cycles.
            // Without it the intent fell through to `ForceRestart`, which is a
            // different operation.
            Self::PowerCycle => &["PowerCycle", "ForcePowerCycle", "ForceRestart"],
        }
    }

    /// Where this intent should leave the machine.
    ///
    /// `Restart` and `PowerCycle` end where they started, which is why the
    /// arrival test in [`PowerWatch`] cannot be "the state differs from
    /// before".
    pub fn expected(self) -> PowerState {
        match self {
            Self::On | Self::Restart | Self::PowerCycle => PowerState::On,
            Self::GracefulShutdown | Self::ForceOff => PowerState::Off,
        }
    }
}

/// The `ResetType` to send for `intent`, or `None` when the service allows
/// none.
///
/// `None` is a real answer and the caller has to show it as one: an intent with
/// nothing behind it is not offered, rather than offered and failing when
/// pressed.
pub fn resolve_reset_type(intent: PowerIntent, allowed: &[String]) -> Option<String> {
    intent
        .candidates()
        .iter()
        .find(|c| allowed.iter().any(|a| a == *c))
        .map(|c| (*c).to_string())
}

/// The request a power operation becomes, worked out without sending it.
///
/// Returned rather than performed so that the decision — which reset type, to
/// which path — can be asserted in a test, while the only code that actually
/// resets a machine stays somewhere no test calls.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResetRequest {
    pub target: String,
    pub reset_type: String,
}

impl ResetRequest {
    /// The request for `intent` against `system`, or `None` if the service
    /// allows nothing that satisfies it.
    pub fn build(system: &RedfishSystem, intent: PowerIntent) -> Option<Self> {
        let target = system.reset_target.clone()?;
        let reset_type = resolve_reset_type(intent, &system.reset_types)?;
        Some(Self { target, reset_type })
    }

    pub fn body(&self) -> Value {
        json!({ "ResetType": self.reset_type })
    }
}

/// Whether a power operation has landed, decided one observation at a time.
///
/// The HTTP status is not the answer: HPE documents that `GracefulShutdown`
/// and `GracefulRestart` depend on the OS and that iLO does not distinguish
/// them at that level, so a `204` means the request was accepted and nothing
/// more. What happened is in `PowerState`, read again until it says.
///
/// The decision of the app's `BmcNotifier._awaitPowerChange`, without its
/// clock: the caller polls (the app every 5 s for 2 min) and feeds each state
/// it reads to [`PowerWatch::observe`]. A read that fails is simply not fed —
/// a machine on its way down stops answering, which is not an answer about
/// whether it got there.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PowerWatch {
    before: PowerState,
    intent: PowerIntent,
    /// Whether the machine was ever seen anywhere other than where it started.
    /// For an intent that ends where it began, this is the whole of the
    /// evidence; for the others it is redundant with the state itself.
    moved: bool,
}

impl PowerWatch {
    pub fn new(before: PowerState, intent: PowerIntent) -> Self {
        Self {
            before,
            intent,
            moved: before != intent.expected(),
        }
    }

    /// Records one reading; `true` once the machine has both moved and arrived
    /// where the intent means it to be.
    ///
    /// A transitional state does not count as arrival — `PoweringOff` is the
    /// machine on its way — but it does count as having moved, which is the
    /// only evidence an operation ending where it began can leave.
    pub fn observe(&mut self, now: PowerState) -> bool {
        if now.is_transitional() {
            self.moved = true;
            return false;
        }
        if now != self.before {
            self.moved = true;
        }
        self.moved && now == self.intent.expected()
    }
}

// --- Chassis and sensors ---

/// Which sensor model a chassis presents.
///
/// Redfish 2020.4 deprecated `Thermal` and `Power` for `ThermalSubsystem`,
/// `PowerSubsystem` and a unified `Sensors` collection. Firmware follows
/// unevenly — Supermicro switched at X14 — and transitional firmware carries
/// **both**.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum SensorModel {
    Modern,
    Legacy,
    None,
}

/// A `Chassis`, as far as finding its readings goes.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct RedfishChassis {
    pub thermal: Option<String>,
    pub power: Option<String>,
    pub thermal_subsystem: Option<String>,
    pub power_subsystem: Option<String>,
    pub sensors: Option<String>,
    pub name: Option<String>,
}

impl RedfishChassis {
    pub fn from_json(json: &Value) -> Self {
        Self {
            thermal: link(json, "Thermal"),
            power: link(json, "Power"),
            thermal_subsystem: link(json, "ThermalSubsystem"),
            power_subsystem: link(json, "PowerSubsystem"),
            sensors: link(json, "Sensors"),
            name: text(json, "Name"),
        }
    }

    /// Whether the new model is available here.
    ///
    /// `Sensors` is what carries the readings in it, so a chassis advertising
    /// `ThermalSubsystem` without one has nothing readable through the new
    /// path and is treated as old.
    pub fn has_modern_sensors(&self) -> bool {
        self.sensors.is_some() && (self.thermal_subsystem.is_some() || self.power_subsystem.is_some())
    }

    /// Whether the deprecated pair is available.
    pub fn has_legacy_sensors(&self) -> bool {
        self.thermal.is_some() || self.power.is_some()
    }

    /// Which to read. The new model wins where both are present — that is what
    /// the deprecation means.
    pub fn model(&self) -> SensorModel {
        if self.has_modern_sensors() {
            SensorModel::Modern
        } else if self.has_legacy_sensors() {
            SensorModel::Legacy
        } else {
            SensorModel::None
        }
    }
}

/// Which resources to fetch for a chassis, given what it linked.
///
/// Returned as paths rather than fetched, so the decision is testable and the
/// fetching stays in one place.
pub fn sensor_paths(chassis: &RedfishChassis) -> Vec<String> {
    match chassis.model() {
        SensorModel::Modern => chassis.sensors.iter().cloned().collect(),
        SensorModel::Legacy => chassis
            .thermal
            .iter()
            .chain(chassis.power.iter())
            .cloned()
            .collect(),
        SensorModel::None => Vec::new(),
    }
}

/// One thing a BMC measured.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BmcReading {
    pub name: String,
    pub value: f64,
    /// As the service labelled it, or the model's implied unit. Kept rather
    /// than normalised: a fan reported in `Percent` and one in `RPM` are
    /// different numbers, and rewriting either into the other would invent
    /// data.
    pub unit: Option<String>,
}

impl BmcReading {
    fn new(name: String, value: f64, unit: impl Into<String>) -> Self {
        Self {
            name,
            value,
            unit: Some(unit.into()),
        }
    }
}

/// Colder than absolute zero, or hotter than anything that would still be a
/// chassis.
const TEMP_MIN: f64 = -273.15;
const TEMP_MAX: f64 = 1000.0;
/// A fan reading is RPM or a percentage; neither is ever negative, and no fan
/// in a server turns this fast.
const FAN_MAX: f64 = 100_000.0;
/// A chassis drawing more than this is not one.
const WATTS_MAX: f64 = 100_000.0;

/// What a chassis had to say about itself.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct BmcSensors {
    pub temperatures: Vec<BmcReading>,
    pub fans: Vec<BmcReading>,
    /// Input power for the whole chassis, where the service reports one.
    pub watts: Option<f64>,
}

impl BmcSensors {
    pub fn is_empty(&self) -> bool {
        self.temperatures.is_empty() && self.fans.is_empty() && self.watts.is_none()
    }

    /// The deprecated pair: `Chassis/{id}/Thermal` and `/Power`.
    ///
    /// Either may be absent — they are separate resources and separate
    /// permissions — so both are optional and what is missing is simply
    /// missing.
    pub fn from_legacy(thermal: Option<&Value>, power: Option<&Value>) -> Self {
        let mut out = Self::default();

        for entry in objects(thermal.and_then(|t| t.get("Temperatures"))) {
            // A sensor that is present but has nothing to say reports null or
            // a sentinel — see `reading`. A reading of 0 °C would be a lie
            // rather than a gap, so neither is turned into one.
            if let Some(value) = reading(entry.get("ReadingCelsius"), TEMP_MIN, TEMP_MAX) {
                out.temperatures.push(BmcReading::new(name(entry), value, "Cel"));
            }
        }

        for entry in objects(thermal.and_then(|t| t.get("Fans"))) {
            // `Reading` is current; `ReadingRPM` is what older services called it
            let value = reading(entry.get("Reading"), 0.0, FAN_MAX)
                .or_else(|| reading(entry.get("ReadingRPM"), 0.0, FAN_MAX));
            if let Some(value) = value {
                let unit = text(entry, "ReadingUnits").unwrap_or_else(|| "RPM".into());
                out.fans.push(BmcReading::new(name(entry), value, unit));
            }
        }

        // The first control that reports a plausible figure.
        out.watts = objects(power.and_then(|p| p.get("PowerControl")))
            .find_map(|entry| reading(entry.get("PowerConsumedWatts"), 0.0, WATTS_MAX));

        out
    }

    /// The current model: one `Sensors` collection, each member typed.
    ///
    /// Takes the members already fetched rather than a collection to walk,
    /// because how many of them to fetch is a decision about a slow device and
    /// belongs to the caller, not to a parser.
    pub fn from_sensors(sensors: &[Value]) -> Self {
        let mut out = Self::default();

        for s in sensors {
            let name = name(s);
            let unit = text(s, "ReadingUnits");
            // The bound depends on what is being measured, so the reading is
            // taken per type rather than once up front.
            let raw = s.get("Reading");
            match s.get("ReadingType").and_then(Value::as_str) {
                Some("Temperature") => {
                    if let Some(value) = reading(raw, TEMP_MIN, TEMP_MAX) {
                        out.temperatures
                            .push(BmcReading::new(name, value, unit.unwrap_or_else(|| "Cel".into())));
                    }
                }
                Some("Rotational") => push_fan(&mut out.fans, name, raw, unit),
                Some("Percent") if name.to_lowercase().contains("fan") => {
                    push_fan(&mut out.fans, name, raw, unit)
                }
                Some("Power") => {
                    // The chassis total, not every rail: a service reports
                    // several, and the largest is the one that is about the
                    // whole machine
                    if let Some(value) = reading(raw, 0.0, WATTS_MAX)
                        && out.watts.is_none_or(|w| value > w)
                    {
                        out.watts = Some(value);
                    }
                }
                _ => {}
            }
        }

        out
    }
}

fn push_fan(fans: &mut Vec<BmcReading>, name: String, raw: Option<&Value>, unit: Option<String>) {
    if let Some(value) = reading(raw, 0.0, FAN_MAX) {
        fans.push(BmcReading::new(name, value, unit.unwrap_or_else(|| "RPM".into())));
    }
}

/// The objects of a JSON array; anything else, inside or instead, is skipped.
fn objects(raw: Option<&Value>) -> impl Iterator<Item = &Value> {
    raw.and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter(|e| e.is_object())
}

/// The name of a sensor entry: its own, its id, or a placeholder.
fn name(entry: &Value) -> String {
    text(entry, "Name")
        .or_else(|| text(entry, "MemberId"))
        .unwrap_or_else(|| "?".into())
}

/// A reading, or `None` when the service is saying it has none.
///
/// `null` is what the specification suggests for a sensor with nothing to
/// report, and some firmware does that. Others send a sentinel: an H3C R5350 G6
/// reports `4294967295` — `0xFFFFFFFF`, unsigned -1 — for every temperature it
/// cannot read, which was 18 of its 20.
///
/// Filtered by plausibility rather than by matching known sentinels: the next
/// vendor's is `65535` or `-1` or `127`, and a list of them is a list that is
/// always one short. The bounds are inclusive, as Dart's `value < min ||
/// value > max` had them.
fn reading(raw: Option<&Value>, min: f64, max: f64) -> Option<f64> {
    let value = raw?.as_f64()?;
    (value.is_finite() && (min..=max).contains(&value)).then_some(value)
}

// --- Tasks ---

/// Where a task has got to.
///
/// `Unknown` covers a state this crate has not been taught, which is a thing to
/// report rather than to guess about: treating an unrecognised state as
/// finished would end a poll while the work continues.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum TaskState {
    /// Created, not started. `news` because that is the Dart name (`new` is a
    /// keyword there), and the name is the wire format.
    #[serde(rename = "news")]
    New,
    Starting,
    Running,
    Suspended,
    Interrupted,
    Pending,
    Stopping,
    Completed,
    Killed,
    Exception,
    Cancelled,
    Unknown,
}

impl TaskState {
    pub fn parse(raw: Option<&Value>) -> Self {
        match raw.and_then(Value::as_str) {
            Some("New") => Self::New,
            Some("Starting") => Self::Starting,
            Some("Running") => Self::Running,
            Some("Suspended") => Self::Suspended,
            Some("Interrupted") => Self::Interrupted,
            Some("Pending") => Self::Pending,
            Some("Stopping") => Self::Stopping,
            Some("Completed") => Self::Completed,
            Some("Killed") => Self::Killed,
            Some("Exception") => Self::Exception,
            Some("Cancelled") => Self::Cancelled,
            _ => Self::Unknown,
        }
    }

    /// Whether the service is still working on it.
    ///
    /// `Unknown` counts as running: a poll that stops early reports a result
    /// that has not happened, and waiting longer than necessary costs only
    /// time.
    pub fn is_running(self) -> bool {
        !matches!(
            self,
            Self::Completed | Self::Killed | Self::Exception | Self::Cancelled
        )
    }

    /// Whether it finished and did what was asked.
    pub fn is_success(self) -> bool {
        self == Self::Completed
    }
}

/// A `Task` resource as it stands right now.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct RedfishTask {
    pub state: TaskState,
    pub id: Option<String>,
    pub name: Option<String>,
    /// 0–100 where the service reports it. Absent is common and means nothing
    /// about progress.
    pub percent_complete: Option<i64>,
    /// What the service said about it, which on failure is the only
    /// description of what went wrong.
    pub messages: Vec<String>,
}

impl RedfishTask {
    /// What a task is before anything has been read of it.
    pub fn unknown() -> Self {
        Self {
            state: TaskState::Unknown,
            id: None,
            name: None,
            percent_complete: None,
            messages: Vec::new(),
        }
    }

    pub fn from_json(json: &Value) -> Self {
        let percent = json.get("PercentComplete").and_then(|p| {
            // An integer as it is; a fraction rounded, half away from zero as
            // Dart's `round()` does.
            p.as_i64()
                .or_else(|| p.as_f64().filter(|f| f.is_finite()).map(|f| f.round() as i64))
        });
        Self {
            state: TaskState::parse(json.get("TaskState")),
            id: text(json, "Id"),
            name: text(json, "Name"),
            percent_complete: percent,
            messages: objects(json.get("Messages"))
                .filter_map(|m| text(m, "Message"))
                .collect(),
        }
    }
}

// --- Topology ---

/// What a service turned out to be, worked out once.
///
/// Discovery is not free on a BMC — each step is a round trip to a device that
/// takes seconds to answer — and none of it changes while a connection lives.
/// So it happens once and is carried, rather than being re-derived per poll.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Topology {
    pub root: RedfishRoot,
    /// The first member of each collection.
    ///
    /// First rather than "the one named X": the ids differ per vendor, and a
    /// machine with several is not something either client presents yet —
    /// see `has_multiple_systems`.
    pub system_path: Option<String>,
    pub chassis_path: Option<String>,
    pub system: Option<RedfishSystem>,
    pub chassis: Option<RedfishChassis>,
    /// Set when the service offered more than one system, so the UI can say
    /// that only the first is shown rather than quietly showing one of
    /// several.
    pub has_multiple_systems: bool,
}

impl Topology {
    pub fn is_usable(&self) -> bool {
        self.system.is_some()
    }

    /// Which sensor model this chassis presents, or none.
    pub fn sensor_model(&self) -> SensorModel {
        self.chassis
            .as_ref()
            .map_or(SensorModel::None, RedfishChassis::model)
    }

    /// This topology with a freshly read `system`, everything discovery worked
    /// out kept — `has_multiple_systems` included, which a field-by-field
    /// rebuild once reset to false every poll.
    pub fn with_system(&self, system: RedfishSystem) -> Self {
        Self {
            system: Some(system),
            ..self.clone()
        }
    }
}

/// The `AllowableValues` an `ActionInfo` resource states for `parameter`
/// (Redfish `ActionInfo.v1`), verbatim; empty when it states none.
pub fn action_info_allowable(json: &Value, parameter: &str) -> Vec<String> {
    json.get("Parameters")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .find(|p| p.get("Name").and_then(Value::as_str) == Some(parameter))
        .and_then(|p| p.get("AllowableValues"))
        .and_then(Value::as_array)
        .map(|values| values.iter().filter_map(Value::as_str).map(str::to_string).collect())
        .unwrap_or_default()
}
