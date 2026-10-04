//! A guest's hardware, settings, cloud-init and host devices FFI
//! (sbm_virt::hardware, sbm_virt::libvirt::hardware)
//!
//! The rules a change is checked by, and libvirt's reads mapped onto the
//! model and a change onto the `virsh` step that makes it. Everything
//! crosses as its `sbm_virt` JSON (snake_case, the agent's wire format); a
//! refusal as [`PveError`] (`sbm_virt::error::Error`, its `detail_json`
//! saying which rule), an issue as its name (`disk_shrink`).
//!
//! PVE's calls are [`super::pve::PveSession`]'s.

use sbm_virt::error::{Error, ErrorKind};
use sbm_virt::hardware::{self, Change, CloudInitEdit, Hardware, HostDevice, HwDisk, Listing};
use sbm_virt::libvirt::{self, hardware as lh};
use sbm_virt::model::HostKind;
use sbm_virt::resource::{Network, Pool, Volume};
use serde::de::DeserializeOwned;

use super::pve::PveError;

fn read<T: DeserializeOwned>(json: &str) -> Result<T, PveError> {
    serde_json::from_str(json).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
}

fn write<T: serde::Serialize>(value: &T) -> Result<String, PveError> {
    serde_json::to_string(value).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
}

fn host(pve: bool) -> HostKind {
    if pve { HostKind::Pve } else { HostKind::Libvirt }
}

/// Why `change_json` (a `Change`) cannot be made to `hardware_json` (a
/// `Hardware`), as an `Issue`'s name; None when it can. The lists are the
/// pools and networks of the guest's host (PVE: its node's), and the
/// volumes the change names.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_hw_issue(
    hardware_json: String,
    change_json: String,
    pve: bool,
    pools_json: String,
    networks_json: String,
    volumes_json: String,
) -> Result<Option<String>, PveError> {
    let hw: Hardware = read(&hardware_json)?;
    let change: Change = read(&change_json)?;
    let pools: Vec<Pool> = read(&pools_json)?;
    let networks: Vec<Network> = read(&networks_json)?;
    let volumes: Vec<Volume> = read(&volumes_json)?;
    let issue = hardware::issue(&hw, &change, host(pve), Listing { pools: &pools, networks: &networks, volumes: &volumes });
    Ok(issue.and_then(|i| serde_json::to_value(i).ok()).and_then(|v| v.as_str().map(str::to_owned)))
}

/// A unicast MAC: six octets, the first even, not all zero.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_is_unicast_mac(mac: String) -> bool {
    hardware::is_unicast_mac(&mac)
}

/// A container mount point PVE takes.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_mount_point_ok(path: String) -> bool {
    hardware::mount_point_ok(&path)
}

/// Whether `disk_json` (an `HwDisk`) can be grown from here.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_hw_disk_growable(disk_json: String) -> Result<bool, PveError> {
    let disk: HwDisk = read(&disk_json)?;
    Ok(hardware::disk_growable(&disk))
}

/// The address `device_json` (a `HostDevice`) is given by on a host of the
/// kind; None where the host said nothing of where it sits.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_usb_address(device_json: String, pve: bool) -> Result<Option<String>, PveError> {
    let device: HostDevice = read(&device_json)?;
    Ok(device.usb_address(host(pve)))
}

// --- libvirt ---

/// [`super::virt::parse_virt_hardware_json`]'s read as `Hardware` JSON for
/// the domain `name`.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_hardware(info_json: String, name: String) -> Result<String, PveError> {
    let info: libvirt::VirtHardwareInfo = read(&info_json)?;
    write(&lh::hardware_of(&info, Some(&name)))
}

/// `change_json` as the `VirtHwChange` JSON
/// [`super::virt::virt_hardware_change_script`] makes, checked first against
/// the read `info_json` (made from the read whose revision is `revision`)
/// and the host's lists.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_hw_change(
    info_json: String,
    name: String,
    revision: Option<String>,
    change_json: String,
    pools_json: String,
    networks_json: String,
    volumes_json: String,
) -> Result<String, PveError> {
    let info: libvirt::VirtHardwareInfo = read(&info_json)?;
    let change: Change = read(&change_json)?;
    let pools: Vec<Pool> = read(&pools_json)?;
    let networks: Vec<Network> = read(&networks_json)?;
    let volumes: Vec<Volume> = read(&volumes_json)?;
    let list = Listing { pools: &pools, networks: &networks, volumes: &volumes };
    write(&lh::change_of(&info, &name, revision.as_deref(), &change, list)?)
}

/// Every pending change discarded: the `VirtHwChange` JSON that writes the
/// definition again from what the domain runs.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_hw_revert(info_json: String, revision: Option<String>) -> Result<String, PveError> {
    let info: libvirt::VirtHardwareInfo = read(&info_json)?;
    write(&lh::revert_of(&info, revision.as_deref())?)
}

/// [`super::virt::parse_virt_seed_read_json`]'s read as `CloudInitState`
/// JSON; `macs` are the domain's NICs.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_cloud_init_state(read_json: String, macs: Vec<String>) -> Result<String, PveError> {
    let seed: libvirt::cloud_init::VirtSeedRead = read(&read_json)?;
    write(&lh::cloud_init_state_of(&seed, &macs))
}

/// The seed `edit_json` (a `CloudInitEdit`) writes, as `VirtCloudInit` JSON
/// for [`super::virt::virt_seed_update_script`], made from the seed as read
/// now (`read_json`) — refused once it changed since the edit's read.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_cloud_init_update(read_json: String, name: String, macs: Vec<String>, edit_json: String) -> Result<String, PveError> {
    let seed: libvirt::cloud_init::VirtSeedRead = read(&read_json)?;
    let edit: CloudInitEdit = read(&edit_json)?;
    write(&lh::cloud_init_update(&seed, &name, &macs, &edit)?)
}

/// [`super::virt::parse_virt_host_devices_json`]'s devices as `HostDevices`
/// JSON.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_host_devices(devices_json: String) -> Result<String, PveError> {
    let devices: libvirt::VirtHostDevices = read(&devices_json)?;
    write(&lh::host_devices_of(&devices))
}
