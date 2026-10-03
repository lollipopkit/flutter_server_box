//! BMC (Redfish) FFI (sbm_redfish)
//!
//! The client the monitor agent uses, so the app and the panel discover,
//! read and power a machine by one set of rules. The app keeps only state and
//! timing: how often to poll, how long to watch a power change — whether that
//! change landed is [`PowerWatch`]'s answer.
//!
//! The model crosses as plain structs mirroring `sbm_redfish::model` field
//! for field, converted both ways because a [`RedfishTopology`] the app holds
//! comes back on every poll. A failure crosses as [`BmcError`], whose
//! [`RedfishFailure`] the app phrases. `detail` never carries a credential or
//! a response body (see `sbm_redfish::Error`).

use std::time::Duration;

use sbm_redfish::{
    cert,
    client::{Client, ClientConfig},
    model,
};

/// How long reading a certificate for review may take — what the Dart
/// `fetchServerCert` waited.
const CERT_FETCH_TIMEOUT: Duration = Duration::from_secs(10);

// --- Failure ---

/// Why a service could not be read (mirrors sbm_redfish::Failure).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RedfishFailure {
    /// Answered, but is not a Redfish service
    NotAService,
    /// A service, but offers no system to read
    NoSystem,
    /// A sub-resource was refused (licensing gates parts of some services)
    Forbidden,
    /// The certificate was not the one reviewed, or none was reviewed
    CertificateRejected,
    /// The account was refused
    Unauthorized,
    /// No account to log in with; never produced by the client, but the
    /// caller that looks the account up reports it in the same terms
    NoCredential,
    /// A missing or stale `If-Match`; retrying after a fresh read is the fix
    PreconditionRequired,
    /// Nothing answered, or not with a resource
    Unreachable,
    /// The service allows nothing that satisfies the intent; nothing was sent
    NotSupported,
    /// No certificate reviewed and one was required
    CertNotReviewed,
    /// Too large, or naming a path outside the service
    InvalidResponse,
    /// The configured address is not a usable `https://` URL
    InvalidUrl,
    /// The client was closed
    Closed,
}

impl From<sbm_redfish::Failure> for RedfishFailure {
    fn from(f: sbm_redfish::Failure) -> Self {
        use sbm_redfish::Failure as F;
        match f {
            F::NotAService => Self::NotAService,
            F::NoSystem => Self::NoSystem,
            F::Forbidden => Self::Forbidden,
            F::CertificateRejected => Self::CertificateRejected,
            F::Unauthorized => Self::Unauthorized,
            F::NoCredential => Self::NoCredential,
            F::PreconditionRequired => Self::PreconditionRequired,
            F::Unreachable => Self::Unreachable,
            F::NotSupported => Self::NotSupported,
            F::CertNotReviewed => Self::CertNotReviewed,
            F::InvalidResponse => Self::InvalidResponse,
            F::InvalidUrl => Self::InvalidUrl,
            F::Closed => Self::Closed,
        }
    }
}

/// A [`RedfishFailure`] and where it happened. `detail` is safe to log and
/// show: a path, a status code, a transport error's kind.
#[derive(Debug, Clone)]
pub struct BmcError {
    pub failure: RedfishFailure,
    pub detail: Option<String>,
}

impl From<sbm_redfish::Error> for BmcError {
    fn from(e: sbm_redfish::Error) -> Self {
        Self {
            failure: e.failure.into(),
            detail: e.detail,
        }
    }
}

// --- Power ---

/// Redfish power states (mirrors sbm_redfish::model::PowerState).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PowerState {
    On,
    Off,
    PoweringOn,
    PoweringOff,
    Paused,
    /// Something newer than this client knows, or not read yet
    Unknown,
}

impl From<model::PowerState> for PowerState {
    fn from(s: model::PowerState) -> Self {
        use model::PowerState as S;
        match s {
            S::On => Self::On,
            S::Off => Self::Off,
            S::PoweringOn => Self::PoweringOn,
            S::PoweringOff => Self::PoweringOff,
            S::Paused => Self::Paused,
            S::Unknown => Self::Unknown,
        }
    }
}

impl From<PowerState> for model::PowerState {
    fn from(s: PowerState) -> Self {
        use model::PowerState as S;
        match s {
            PowerState::On => S::On,
            PowerState::Off => S::Off,
            PowerState::PoweringOn => S::PoweringOn,
            PowerState::PoweringOff => S::PoweringOff,
            PowerState::Paused => S::Paused,
            PowerState::Unknown => S::Unknown,
        }
    }
}

/// What the user asks of a machine (mirrors sbm_redfish::model::PowerIntent),
/// in the order a UI offers them.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PowerIntent {
    On,
    GracefulShutdown,
    ForceOff,
    Restart,
    PowerCycle,
}

impl From<PowerIntent> for model::PowerIntent {
    fn from(i: PowerIntent) -> Self {
        use model::PowerIntent as I;
        match i {
            PowerIntent::On => I::On,
            PowerIntent::GracefulShutdown => I::GracefulShutdown,
            PowerIntent::ForceOff => I::ForceOff,
            PowerIntent::Restart => I::Restart,
            PowerIntent::PowerCycle => I::PowerCycle,
        }
    }
}

/// The request an intent becomes, worked out without sending it
/// (mirrors sbm_redfish::model::ResetRequest).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ResetRequest {
    pub target: String,
    /// The `ResetType` actually chosen, which is worth showing before
    /// agreeing: a restart is `ForceRestart` on hardware without a graceful one
    pub reset_type: String,
}

/// The request `intent` becomes on `system`, or `None` when the service allows
/// nothing that satisfies it — such an intent is not offered.
#[flutter_rust_bridge::frb(sync)]
pub fn bmc_plan(system: RedfishSystem, intent: PowerIntent) -> Option<ResetRequest> {
    model::ResetRequest::build(&system.into(), intent.into()).map(|r| ResetRequest {
        target: r.target,
        reset_type: r.reset_type,
    })
}

/// Whether a power operation has landed, one observation at a time
/// (sbm_redfish::model::PowerWatch). The caller polls and feeds each state it
/// reads; a failed read is not fed.
#[flutter_rust_bridge::frb(opaque)]
pub struct PowerWatch(model::PowerWatch);

impl PowerWatch {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(before: PowerState, intent: PowerIntent) -> PowerWatch {
        PowerWatch(model::PowerWatch::new(before.into(), intent.into()))
    }

    /// `true` once the machine has both moved and arrived where the intent
    /// means it to be.
    #[flutter_rust_bridge::frb(sync)]
    pub fn observe(&mut self, now: PowerState) -> bool {
        self.0.observe(now.into())
    }
}

// --- Resources ---

/// What `GET /redfish/v1/` said (mirrors sbm_redfish::model::RedfishRoot).
#[derive(Debug, Clone, PartialEq)]
pub struct RedfishRoot {
    pub systems: Option<String>,
    pub chassis: Option<String>,
    pub sessions: Option<String>,
    pub version: Option<String>,
    pub product: Option<String>,
    pub vendor: Option<String>,
}

impl From<model::RedfishRoot> for RedfishRoot {
    fn from(r: model::RedfishRoot) -> Self {
        Self {
            systems: r.systems,
            chassis: r.chassis,
            sessions: r.sessions,
            version: r.version,
            product: r.product,
            vendor: r.vendor,
        }
    }
}

impl From<RedfishRoot> for model::RedfishRoot {
    fn from(r: RedfishRoot) -> Self {
        Self {
            systems: r.systems,
            chassis: r.chassis,
            sessions: r.sessions,
            version: r.version,
            product: r.product,
            vendor: r.vendor,
        }
    }
}

/// A `ComputerSystem` (mirrors sbm_redfish::model::RedfishSystem).
#[derive(Debug, Clone, PartialEq)]
pub struct RedfishSystem {
    pub power_state: PowerState,
    pub model: Option<String>,
    pub manufacturer: Option<String>,
    pub serial: Option<String>,
    pub bios_version: Option<String>,
    pub health: Option<String>,
    pub reset_target: Option<String>,
    pub reset_types: Vec<String>,
}

impl From<model::RedfishSystem> for RedfishSystem {
    fn from(s: model::RedfishSystem) -> Self {
        Self {
            power_state: s.power_state.into(),
            model: s.model,
            manufacturer: s.manufacturer,
            serial: s.serial,
            bios_version: s.bios_version,
            health: s.health,
            reset_target: s.reset_target,
            reset_types: s.reset_types,
        }
    }
}

impl From<RedfishSystem> for model::RedfishSystem {
    fn from(s: RedfishSystem) -> Self {
        Self {
            power_state: s.power_state.into(),
            model: s.model,
            manufacturer: s.manufacturer,
            serial: s.serial,
            bios_version: s.bios_version,
            health: s.health,
            reset_target: s.reset_target,
            reset_types: s.reset_types,
        }
    }
}

/// A `Chassis`, as far as finding its readings goes
/// (mirrors sbm_redfish::model::RedfishChassis).
#[derive(Debug, Clone, PartialEq)]
pub struct RedfishChassis {
    pub thermal: Option<String>,
    pub power: Option<String>,
    pub thermal_subsystem: Option<String>,
    pub power_subsystem: Option<String>,
    pub sensors: Option<String>,
    pub name: Option<String>,
}

impl From<model::RedfishChassis> for RedfishChassis {
    fn from(c: model::RedfishChassis) -> Self {
        Self {
            thermal: c.thermal,
            power: c.power,
            thermal_subsystem: c.thermal_subsystem,
            power_subsystem: c.power_subsystem,
            sensors: c.sensors,
            name: c.name,
        }
    }
}

impl From<RedfishChassis> for model::RedfishChassis {
    fn from(c: RedfishChassis) -> Self {
        Self {
            thermal: c.thermal,
            power: c.power,
            thermal_subsystem: c.thermal_subsystem,
            power_subsystem: c.power_subsystem,
            sensors: c.sensors,
            name: c.name,
        }
    }
}

/// What a service turned out to be, discovered once and passed back on every
/// poll (mirrors sbm_redfish::model::Topology).
#[derive(Debug, Clone, PartialEq)]
pub struct RedfishTopology {
    pub root: RedfishRoot,
    pub system_path: Option<String>,
    pub chassis_path: Option<String>,
    pub system: Option<RedfishSystem>,
    pub chassis: Option<RedfishChassis>,
    /// Only the first system is shown; the UI says so
    pub has_multiple_systems: bool,
}

impl From<model::Topology> for RedfishTopology {
    fn from(t: model::Topology) -> Self {
        Self {
            root: t.root.into(),
            system_path: t.system_path,
            chassis_path: t.chassis_path,
            system: t.system.map(Into::into),
            chassis: t.chassis.map(Into::into),
            has_multiple_systems: t.has_multiple_systems,
        }
    }
}

impl From<RedfishTopology> for model::Topology {
    fn from(t: RedfishTopology) -> Self {
        Self {
            root: t.root.into(),
            system_path: t.system_path,
            chassis_path: t.chassis_path,
            system: t.system.map(Into::into),
            chassis: t.chassis.map(Into::into),
            has_multiple_systems: t.has_multiple_systems,
        }
    }
}

/// One measurement (mirrors sbm_redfish::model::BmcReading).
#[derive(Debug, Clone, PartialEq)]
pub struct BmcReading {
    pub name: String,
    pub value: f64,
    /// As the service labelled it (`Cel`, `RPM`, `Percent`, …)
    pub unit: Option<String>,
}

/// A chassis's readings (mirrors sbm_redfish::model::BmcSensors).
#[derive(Debug, Clone, PartialEq)]
pub struct BmcSensors {
    pub temperatures: Vec<BmcReading>,
    pub fans: Vec<BmcReading>,
    /// Input power for the whole chassis, where reported
    pub watts: Option<f64>,
}

fn readings(list: Vec<model::BmcReading>) -> Vec<BmcReading> {
    list.into_iter()
        .map(|r| BmcReading {
            name: r.name,
            value: r.value,
            unit: r.unit,
        })
        .collect()
}

impl From<model::BmcSensors> for BmcSensors {
    fn from(s: model::BmcSensors) -> Self {
        Self {
            temperatures: readings(s.temperatures),
            fans: readings(s.fans),
            watts: s.watts,
        }
    }
}

/// One read of a machine (mirrors sbm_redfish::Snapshot).
#[derive(Debug, Clone, PartialEq)]
pub struct BmcSnapshot {
    pub topology: RedfishTopology,
    pub sensors: BmcSensors,
    /// The `Sensors` collection had more than `sbm_redfish::MAX_SENSOR_MEMBERS`
    pub sensors_truncated: bool,
}

/// What a modifying request produced (mirrors sbm_redfish::Outcome): the
/// request being taken, never the machine having done it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BmcOutcome {
    /// Where the service is doing the work (`202`), or `None` when it answered
    /// done
    pub task: Option<String>,
}

impl From<sbm_redfish::Outcome> for BmcOutcome {
    fn from(o: sbm_redfish::Outcome) -> Self {
        match o {
            sbm_redfish::Outcome::Done => Self { task: None },
            sbm_redfish::Outcome::Accepted(path) => Self { task: Some(path) },
        }
    }
}

// --- Client ---

/// One BMC's Redfish service. Holds a session on a device that allows few, so
/// it must be [`BmcClient::close`]d.
#[flutter_rust_bridge::frb(opaque)]
pub struct BmcClient(Client);

impl BmcClient {
    /// Builds a client; nothing is sent until the first request. Without a
    /// pin every handshake is refused as `certificateRejected`, which the app
    /// answers by offering the certificate for review.
    #[flutter_rust_bridge::frb(sync)]
    pub fn new(
        base_url: String,
        user: String,
        password: Option<String>,
        pinned_sha256: Option<String>,
    ) -> Result<BmcClient, BmcError> {
        let client = Client::new(ClientConfig {
            base_url,
            user,
            password,
            pinned_sha256,
            require_pin: false,
            ..ClientConfig::default()
        })?;
        Ok(BmcClient(client))
    }

    /// The service root and the first system and chassis under it.
    pub async fn discover(&self) -> Result<RedfishTopology, BmcError> {
        Ok(sbm_redfish::discover(&self.0).await?.into())
    }

    /// Reads the machine once: discovery only when `known` is `None`, the
    /// system every time, sensors best effort.
    pub async fn snapshot(&self, known: Option<RedfishTopology>) -> Result<BmcSnapshot, BmcError> {
        let known = known.map(model::Topology::from);
        let snapshot = sbm_redfish::snapshot(&self.0, known.as_ref()).await?;
        Ok(BmcSnapshot {
            topology: snapshot.topology.into(),
            sensors: snapshot.sensors.into(),
            sensors_truncated: snapshot.sensors_truncated,
        })
    }

    /// Re-reads the system `topology` names — what a poll after a power
    /// action feeds to [`PowerWatch::observe`].
    pub async fn read_system(&self, topology: RedfishTopology) -> Result<RedfishSystem, BmcError> {
        let topology = model::Topology::from(topology);
        Ok(sbm_redfish::read_system(&self.0, &topology).await?.into())
    }

    /// Asks the machine to change state. `notSupported` without sending
    /// anything when the service allows nothing for `intent`.
    pub async fn power(&self, topology: RedfishTopology, intent: PowerIntent) -> Result<BmcOutcome, BmcError> {
        let topology = model::Topology::from(topology);
        Ok(sbm_redfish::power(&self.0, &topology, intent.into()).await?.into())
    }

    /// Ends the session. Never fails; safe to call twice.
    pub async fn close(&self) {
        self.0.close().await;
    }
}

// --- Certificates ---

/// A certificate as shown to someone deciding whether to trust it
/// (mirrors sbm_redfish::cert::CertInfo).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CertInfo {
    /// SHA-256 of the DER, lowercase hex: the stored pin form
    pub fingerprint: String,
    /// OpenSSL's one-line form, `/CN=bmc/O=Vendor`
    pub subject: String,
    pub issuer: String,
    /// Unix seconds
    pub not_before: i64,
    pub not_after: i64,
}

impl From<cert::CertInfo> for CertInfo {
    fn from(c: cert::CertInfo) -> Self {
        Self {
            fingerprint: c.fingerprint,
            subject: c.subject,
            issuer: c.issuer,
            not_before: c.not_before,
            not_after: c.not_after,
        }
    }
}

impl From<CertInfo> for cert::CertInfo {
    fn from(c: CertInfo) -> Self {
        Self {
            fingerprint: c.fingerprint,
            subject: c.subject,
            issuer: c.issuer,
            not_before: c.not_before,
            not_after: c.not_after,
        }
    }
}

impl CertInfo {
    /// Outside its own validity window. Shown, never acted on: BMCs often
    /// ship certificates that expired years ago.
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn is_expired(&self) -> bool {
        cert::CertInfo::from(self.clone()).is_expired()
    }

    /// Colon-separated upper case, how a BMC's own web UI prints it.
    #[flutter_rust_bridge::frb(sync, getter)]
    pub fn pretty_fingerprint(&self) -> String {
        cert::pretty_fingerprint(&self.fingerprint)
    }
}

/// Reads the certificate `host`:`port` presents, sending nothing but a TLS
/// hello. `unreachable` for a host that is off or not speaking TLS.
pub async fn bmc_fetch_server_cert(host: String, port: u16) -> Result<CertInfo, BmcError> {
    Ok(cert::fetch_server_cert(&host, port, CERT_FETCH_TIMEOUT).await?.into())
}

/// A DER certificate as shown for review, or `None` when it does not parse.
#[flutter_rust_bridge::frb(sync)]
pub fn cert_info_from_der(der: Vec<u8>) -> Option<CertInfo> {
    cert::CertInfo::from_der(&der).map(Into::into)
}

/// SHA-256 of a DER certificate, lowercase hex — the stored pin form.
#[flutter_rust_bridge::frb(sync)]
pub fn cert_fingerprint(der: Vec<u8>) -> String {
    cert::fingerprint(&der)
}

/// A pasted fingerprint in the stored form: lowercase, separators removed. A
/// pin already stored comes out unchanged.
#[flutter_rust_bridge::frb(sync)]
pub fn cert_normalize_fingerprint(input: String) -> String {
    cert::normalize_fingerprint(&input)
}

/// Whether `der` is the pinned certificate. `false` when nothing is pinned:
/// reviewing is a step someone takes, not a side effect of a request.
#[flutter_rust_bridge::frb(sync)]
pub fn cert_pin_accepts(pin: Option<String>, der: Vec<u8>) -> bool {
    cert::PinnedCert::new(pin.as_deref()).accepts(Some(&der))
}
