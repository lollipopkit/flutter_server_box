//! A Redfish client for baseboard management controllers: discovery, power,
//! sensors and certificate pinning, for the monitor agent and (through FFI)
//! the app.
//!
//! Ported from the Dart package `redfish` (removed with this port) and the non-state half of the app's
//! `lib/data/provider/bmc/bmc.dart`, whose behaviour is the specification: the
//! Dart tests and vendor fixtures are ported under `tests/`. The split that
//! matters is the same as there. [`model`] and [`cert`]'s decisions are pure —
//! they take decoded JSON or DER and answer — so every vendor difference worth
//! getting right is tested against a saved response; [`client`] is the only
//! thing that opens a socket, and the walks here ([`discover`], [`snapshot`])
//! run against the [`Transport`] seam so they can be driven by recorded
//! documents too.
//!
//! Firmware differs from the specification in ways no amount of reading finds
//! (`doc/vendors.md`), and the only way to keep those
//! differences honest is to be able to reproduce them without the hardware.

pub mod cert;
pub mod client;
mod error;
pub mod model;

use std::future::Future;

use serde::{Deserialize, Serialize};
use serde_json::Value;

pub use client::{Client, Outcome, ROOT_PATH};
pub use error::{Error, Failure};
use model::{
    BmcSensors, PowerIntent, RedfishChassis, RedfishRoot, RedfishSystem, ResetRequest, SensorModel, Topology,
    collection_members,
};

/// How many members of a `Sensors` collection are read.
///
/// The new model puts every reading in its own resource, so a chassis with a
/// hundred sensors is a hundred requests to a device that answers in seconds.
/// A cap is the only thing that keeps one poll from outlasting the next, and
/// [`Snapshot::sensors_truncated`] says when one was applied — a silent cap
/// reads as "this machine has 64 sensors".
pub const MAX_SENSOR_MEMBERS: usize = 64;

/// Reading and acting on resources: what the walks below need of a service.
///
/// One real implementation, [`Client`]; the seam exists so discovery can be
/// driven by recorded responses, as the Dart `RedfishTransport` was.
pub trait Transport: Sync {
    /// The resource at `path`, as a JSON object.
    fn get(&self, path: &str) -> impl Future<Output = Result<Value, Error>> + Send;
    /// Sends `body` to `path`.
    fn post(&self, path: &str, body: Value) -> impl Future<Output = Result<Outcome, Error>> + Send;
}

impl Transport for Client {
    fn get(&self, path: &str) -> impl Future<Output = Result<Value, Error>> + Send {
        Client::get(self, path)
    }

    fn post(&self, path: &str, body: Value) -> impl Future<Output = Result<Outcome, Error>> + Send {
        Client::post(self, path, body)
    }
}

/// Reads the service root and the first system and chassis under it.
///
/// Every path here comes from the previous response. Nothing is built by
/// concatenation: `Systems/1`, `Systems/System.Embedded.1` and
/// `Systems/system` are all correct, and none can be derived from the others.
pub async fn discover<T: Transport>(client: &T) -> Result<Topology, Error> {
    let root = RedfishRoot::from_json(&client.get(ROOT_PATH).await?);
    if !root.is_service() {
        return Err(Error::new(Failure::NotAService));
    }

    // Independent GETs against a device where one takes seconds, so they are
    // not made to wait for each other.
    let (systems, chassis_paths) = tokio::join!(
        members(client, root.systems.as_deref()),
        members(client, root.chassis.as_deref()),
    );
    let Some(system_path) = systems.first().cloned() else {
        return Err(Error::new(Failure::NoSystem));
    };
    let chassis_path = chassis_paths.first().cloned();

    let system = system_at(client, &system_path).await?;

    // A chassis that cannot be read costs the sensor half and nothing else, so
    // it is not allowed to take the power half down with it
    let chassis = match &chassis_path {
        Some(path) => client.get(path).await.ok().map(|c| RedfishChassis::from_json(&c)),
        None => None,
    };

    Ok(Topology {
        root,
        system_path: Some(system_path),
        chassis_path,
        system: Some(system),
        chassis,
        has_multiple_systems: systems.len() > 1,
    })
}

/// Every member of a collection, or empty when it cannot be read.
///
/// The whole list rather than the first of it, because how many there are is
/// itself an answer: a blade chassis publishes one system per node.
async fn members<T: Transport>(client: &T, collection: Option<&str>) -> Vec<String> {
    match collection {
        Some(path) => client
            .get(path)
            .await
            .map(|json| collection_members(&json))
            .unwrap_or_default(),
        None => Vec::new(),
    }
}

/// One read of a machine: what it is, its power, and its readings.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Snapshot {
    pub topology: Topology,
    pub sensors: BmcSensors,
    /// Set when the `Sensors` collection had more than [`MAX_SENSOR_MEMBERS`]
    /// and only that many were read.
    pub sensors_truncated: bool,
}

/// Reads the machine once.
///
/// Discovery runs only when `known` is `None`: which ids and which sensor
/// model do not change while a connection lives, and re-deriving them is
/// several round trips this device can least afford. The system is re-read
/// every time a known topology is passed — power state is the point of this.
/// (After a fresh discovery it is not read a second time; the app's notifier
/// did, a moment after discovery had just read it.)
///
/// Sensors are best effort: a failure there costs the readings, never the
/// snapshot. Closes nothing — the caller owns the client.
pub async fn snapshot<T: Transport>(client: &T, known: Option<&Topology>) -> Result<Snapshot, Error> {
    let topology = match known {
        Some(known) => known.with_system(read_system(client, known).await?),
        None => discover(client).await?,
    };
    let (sensors, sensors_truncated) = read_sensors(client, topology.chassis.as_ref()).await;
    Ok(Snapshot {
        topology,
        sensors,
        sensors_truncated,
    })
}

/// Re-reads the system a topology names — what a poll after a power action
/// feeds to [`model::PowerWatch`].
pub async fn read_system<T: Transport>(client: &T, topology: &Topology) -> Result<RedfishSystem, Error> {
    let path = topology
        .system_path
        .as_deref()
        .ok_or_else(|| Error::new(Failure::NoSystem))?;
    system_at(client, path).await
}

/// The system at `path`, with its reset types read from the action's
/// `ActionInfo` when the action lists none inline. An `ActionInfo` that cannot
/// be read leaves the list empty — no power action offered — rather than
/// failing the read, whose power state is still worth having.
async fn system_at<T: Transport>(client: &T, path: &str) -> Result<RedfishSystem, Error> {
    let json = client.get(path).await?;
    let mut system = RedfishSystem::from_json(&json);
    if system.reset_types.is_empty()
        && let Some(info) = RedfishSystem::reset_action_info(&json)
        && let Ok(info) = client.get(&info).await
    {
        system.reset_types = model::action_info_allowable(&info, "ResetType");
    }
    Ok(system)
}

/// Asks the machine to change state.
///
/// What came back is the request being taken, not the machine having done it:
/// confirm with [`read_system`] and [`model::PowerWatch`]. Nothing is sent when
/// the service allows nothing that satisfies `intent`
/// ([`Failure::NotSupported`]).
pub async fn power<T: Transport>(client: &T, topology: &Topology, intent: PowerIntent) -> Result<Outcome, Error> {
    let system = topology
        .system
        .as_ref()
        .ok_or_else(|| Error::new(Failure::NoSystem))?;
    let request = ResetRequest::build(system, intent)
        .ok_or_else(|| Error::with(Failure::NotSupported, intent.as_str()))?;
    client.post(&request.target, request.body()).await
}

/// Sensors, by whichever model this chassis presents, and whether the list was
/// cut to [`MAX_SENSOR_MEMBERS`].
///
/// Never fatal, as in the app: any member that cannot be read costs all the
/// readings, and the power state is already in hand. One request at a time —
/// a BMC serves these from one small web server.
pub async fn read_sensors<T: Transport>(client: &T, chassis: Option<&RedfishChassis>) -> (BmcSensors, bool) {
    let Some(chassis) = chassis else {
        return (BmcSensors::default(), false);
    };
    let read = async {
        match chassis.model() {
            SensorModel::Legacy => {
                let thermal = match &chassis.thermal {
                    Some(path) => Some(client.get(path).await?),
                    None => None,
                };
                let power = match &chassis.power {
                    Some(path) => Some(client.get(path).await?),
                    None => None,
                };
                Ok::<_, Error>((BmcSensors::from_legacy(thermal.as_ref(), power.as_ref()), false))
            }
            SensorModel::Modern => {
                let Some(collection) = &chassis.sensors else {
                    return Ok((BmcSensors::default(), false));
                };
                let members = collection_members(&client.get(collection).await?);
                let truncated = members.len() > MAX_SENSOR_MEMBERS;
                let mut fetched = Vec::with_capacity(members.len().min(MAX_SENSOR_MEMBERS));
                for path in members.iter().take(MAX_SENSOR_MEMBERS) {
                    fetched.push(client.get(path).await?);
                }
                Ok((BmcSensors::from_sensors(&fetched), truncated))
            }
            SensorModel::None => Ok((BmcSensors::default(), false)),
        }
    };
    read.await.unwrap_or_default()
}
