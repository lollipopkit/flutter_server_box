//! Virtual media: an image on a web or file server, presented to the machine
//! as a CD or USB drive — how an OS is installed on a machine nobody is
//! standing next to.
//!
//! Under the manager on most firmware, under the system on newer (Redfish
//! 2021.1 moved it); both are read, the system's first.

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::model::{Topology, collection_paths};
use crate::{Error, Failure, Outcome, Transport};

/// One slot an image can be put in.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct MediaSlot {
    pub path: String,
    pub id: Option<String>,
    pub name: Option<String>,
    /// `CD`, `DVD`, `USBStick`, `Floppy`, …
    pub media_types: Vec<String>,
    pub inserted: bool,
    /// The image in it, as the service reports it.
    pub image: Option<String>,
    pub write_protected: Option<bool>,
    pub insert_target: Option<String>,
    pub eject_target: Option<String>,
}

impl MediaSlot {
    pub fn from_json(path: &str, json: &Value) -> Self {
        let text = |key: &str| json.get(key).and_then(Value::as_str).map(str::to_string);
        let action = |name: &str| {
            json.get("Actions")
                .and_then(|a| a.get(name))
                .and_then(|a| a.get("target"))
                .and_then(Value::as_str)
                .map(str::to_string)
        };
        Self {
            path: path.to_string(),
            id: text("Id"),
            name: text("Name"),
            media_types: json
                .get("MediaTypes")
                .and_then(Value::as_array)
                .map(|v| v.iter().filter_map(Value::as_str).map(str::to_string).collect())
                .unwrap_or_default(),
            inserted: json.get("Inserted").and_then(Value::as_bool).unwrap_or(false),
            image: text("Image").filter(|i| !i.is_empty()),
            write_protected: json.get("WriteProtected").and_then(Value::as_bool),
            insert_target: action("#VirtualMedia.InsertMedia"),
            eject_target: action("#VirtualMedia.EjectMedia"),
        }
    }
}

/// Every slot, the system's then the manager's. A slot that cannot be read
/// is left out, a collection that cannot be read leaves the other; only when
/// every collection fails is that the answer.
pub async fn media_slots<T: Transport>(client: &T, topology: &Topology) -> Result<Vec<MediaSlot>, Error> {
    let system = topology.system.as_ref().and_then(|s| s.virtual_media.clone());
    let manager = topology.manager.as_ref().and_then(|m| m.virtual_media.clone());
    let mut slots = Vec::new();
    let mut failure = None;
    let mut read_any = false;
    for collection in [system, manager].into_iter().flatten() {
        let paths = match collection_paths(client, &collection).await {
            Ok((paths, _)) => paths,
            Err(e) => {
                failure = Some(e);
                continue;
            }
        };
        read_any = true;
        for path in paths {
            // Redfish 2021.1 moved the slots under the system and some
            // firmware still lists them under both: the same slot twice would
            // be offered twice, and one eject would look like it did nothing.
            if slots.iter().any(|s: &MediaSlot| s.path == path) {
                continue;
            }
            if let Ok(json) = client.get(&path).await {
                slots.push(MediaSlot::from_json(&path, &json));
            }
        }
    }
    match failure.filter(|_| !read_any) {
        Some(e) => Err(e),
        None => Ok(slots),
    }
}

/// Whether `image` is an address a BMC fetches an image from: `http(s)`,
/// `nfs` or `cifs`/`smb`, with a host and a path, no credentials in it and
/// nothing a shell or a log would read differently.
pub fn is_image_url(image: &str) -> bool {
    let Some((scheme, rest)) = image.split_once("://") else {
        return false;
    };
    let scheme_ok = matches!(
        scheme.to_ascii_lowercase().as_str(),
        "http" | "https" | "nfs" | "cifs" | "smb"
    );
    let Some((authority, path)) = rest.split_once('/') else {
        return false;
    };
    scheme_ok
        && !authority.is_empty()
        && !authority.contains('@')
        && !path.is_empty()
        && image.len() <= 2048
        && !image.chars().any(|c| c.is_whitespace() || c.is_control())
}

/// Puts `image` in `slot`, read-only: by `InsertMedia` where the slot has
/// it, otherwise by setting `Image` and `Inserted`, which is how VirtualMedia
/// before 1.1 (2018) took one.
pub async fn insert_media<T: Transport>(client: &T, slot: &MediaSlot, image: &str) -> Result<Outcome, Error> {
    if !is_image_url(image) {
        return Err(Error::with(Failure::NotSupported, "not an image address"));
    }
    let body = json!({ "Image": image, "Inserted": true, "WriteProtected": true });
    match &slot.insert_target {
        Some(target) => client.post(target, body).await,
        None => patch_slot(client, slot, body).await,
    }
}

/// Takes the image out of `slot`, by `EjectMedia` or by clearing `Image`.
pub async fn eject_media<T: Transport>(client: &T, slot: &MediaSlot) -> Result<Outcome, Error> {
    match &slot.eject_target {
        Some(target) => client.post(target, json!({})).await,
        None => patch_slot(client, slot, json!({ "Image": null, "Inserted": false })).await,
    }
}

async fn patch_slot<T: Transport>(client: &T, slot: &MediaSlot, body: Value) -> Result<Outcome, Error> {
    let current = client.fetch(&slot.path).await?;
    client.patch(&slot.path, body, current.etag.as_deref()).await
}
