//! The system's drives (`Storage`, or `SimpleStorage` on firmware before it):
//! what each is and whether it is failing.

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::model::{Topology, collection_members, odata_id};
use crate::{Error, Transport};

/// How many drives one read fetches, each a request of its own.
pub const MAX_DRIVES: usize = 64;

/// One drive.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Drive {
    pub name: Option<String>,
    pub model: Option<String>,
    pub serial: Option<String>,
    pub capacity_bytes: Option<u64>,
    /// `HDD` or `SSD`.
    pub media_type: Option<String>,
    /// `SATA`, `SAS`, `NVMe`, …
    pub protocol: Option<String>,
    /// `Status.Health`: `OK`, `Warning`, `Critical`.
    pub health: Option<String>,
    /// `Status.State`: `Enabled`, `Absent`, …
    pub state: Option<String>,
    /// The drive's own prediction that it will fail.
    pub failure_predicted: Option<bool>,
    pub life_left_percent: Option<f64>,
    /// Which controller it hangs off, by the controller's name.
    pub controller: Option<String>,
}

impl Drive {
    pub fn from_json(json: &Value) -> Self {
        let text = |key: &str| json.get(key).and_then(Value::as_str).map(str::to_string);
        let status = json.get("Status");
        Self {
            name: text("Name"),
            model: text("Model"),
            serial: text("SerialNumber"),
            capacity_bytes: json.get("CapacityBytes").and_then(Value::as_u64),
            media_type: text("MediaType"),
            protocol: text("Protocol"),
            health: status.and_then(|s| s.get("Health")).and_then(Value::as_str).map(str::to_string),
            state: status.and_then(|s| s.get("State")).and_then(Value::as_str).map(str::to_string),
            failure_predicted: json.get("FailurePredicted").and_then(Value::as_bool),
            life_left_percent: json.get("PredictedMediaLifeLeftPercent").and_then(Value::as_f64),
            controller: None,
        }
    }

    /// Whether this drive is one to look at: failing, predicted to, or said
    /// not to be OK.
    pub fn needs_attention(&self) -> bool {
        self.failure_predicted == Some(true) || self.health.as_deref().is_some_and(|h| h != "OK")
    }
}

/// A system's drives.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct StorageReport {
    pub drives: Vec<Drive>,
    /// More drives were listed than [`MAX_DRIVES`].
    pub truncated: bool,
    /// The service lists no storage at all, as opposed to listing none.
    pub unsupported: bool,
}

/// Every drive the system lists. A collection that cannot be read is the
/// answer; past it, best effort: a controller or a drive that cannot be read
/// is skipped, never the rest. `Storage` that names no drive falls back to
/// `SimpleStorage`, which firmware in between keeps them in.
pub async fn storage<T: Transport>(client: &T, topology: &Topology) -> Result<StorageReport, Error> {
    let unsupported = StorageReport { unsupported: true, ..Default::default() };
    let Some(system) = topology.system.as_ref() else {
        return Ok(unsupported);
    };
    if let Some(collection) = &system.storage {
        let report = from_storage(client, collection).await?;
        match &system.simple_storage {
            Some(simple) if report.drives.is_empty() => {
                return Ok(from_simple_storage(client, simple).await.unwrap_or(report));
            }
            _ => return Ok(report),
        }
    }
    match &system.simple_storage {
        Some(collection) => from_simple_storage(client, collection).await,
        None => Ok(unsupported),
    }
}

async fn from_storage<T: Transport>(client: &T, collection: &str) -> Result<StorageReport, Error> {
    let mut report = StorageReport::default();
    let listing = client.get(collection).await?;
    for path in collection_members(&listing) {
        let Ok(storage) = client.get(&path).await else { continue };
        let controller = storage.get("Name").and_then(Value::as_str).map(str::to_string);
        let links = storage
            .get("Drives")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(odata_id);
        for drive in links {
            if report.drives.len() == MAX_DRIVES {
                report.truncated = true;
                return Ok(report);
            }
            if let Ok(json) = client.get(drive).await {
                report.drives.push(Drive {
                    controller: controller.clone(),
                    ..Drive::from_json(&json)
                });
            }
        }
    }
    Ok(report)
}

/// `SimpleStorage`: the devices inline, with less said about each.
async fn from_simple_storage<T: Transport>(client: &T, collection: &str) -> Result<StorageReport, Error> {
    let mut report = StorageReport::default();
    let listing = client.get(collection).await?;
    for path in collection_members(&listing) {
        let Ok(simple) = client.get(&path).await else { continue };
        let controller = simple.get("Name").and_then(Value::as_str).map(str::to_string);
        for device in simple
            .get("Devices")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter(|d| d.is_object())
        {
            if report.drives.len() == MAX_DRIVES {
                report.truncated = true;
                return Ok(report);
            }
            report.drives.push(Drive {
                controller: controller.clone(),
                ..Drive::from_json(device)
            });
        }
    }
    Ok(report)
}
