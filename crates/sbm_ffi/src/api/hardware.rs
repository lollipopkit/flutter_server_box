//! A guest's hardware, settings, cloud-init and host devices FFI
//! (sbm_virt::hardware, sbm_virt::libvirt::hardware)
//!
//! The rules a change is checked by, and libvirt's reads mapped onto the
//! model and a change onto the `virsh` step that makes it. The models are
//! `sbm_virt`'s own, mirrored ([`super::virt_model`], [`super::virt_libvirt`]);
//! a refusal is [`PveError`] (`sbm_virt::error::Error`, its `detail`
//! saying which rule), an issue its [`HwIssue`].
//!
//! PVE's calls are [`super::pve::PveSession`]'s.

use flutter_rust_bridge::frb;
use sbm_virt::hardware::{self, Listing};
use sbm_virt::libvirt::hardware as lh;
use sbm_virt::model::HostKind;

use super::pve::PveError;
use super::virt_libvirt::{VirtCloudInit, VirtHardwareInfo, VirtHostDevices, VirtHwChange, VirtSeedRead};
use super::virt_model::{CloudInitEdit, CloudInitState, Hardware, HostDevice, HostDevices, HwChange, HwDisk, HwIssue, Network, ResourcePool, Volume};

fn host(pve: bool) -> HostKind {
    if pve { HostKind::Pve } else { HostKind::Libvirt }
}

/// Why `change` cannot be made to `hardware`, or None when it can. The lists
/// are the pools and networks of the guest's host (PVE: its node's), and the
/// volumes the change names.
#[frb(sync)]
pub fn virt_hw_issue(
    hardware: Hardware,
    change: HwChange,
    pve: bool,
    pools: Vec<ResourcePool>,
    networks: Vec<Network>,
    volumes: Vec<Volume>,
) -> Option<HwIssue> {
    hardware::issue(&hardware, &change, host(pve), Listing { pools: &pools, networks: &networks, volumes: &volumes })
}

/// A unicast MAC: six octets, the first even, not all zero.
#[frb(sync)]
pub fn virt_is_unicast_mac(mac: String) -> bool {
    hardware::is_unicast_mac(&mac)
}

/// A container mount point PVE takes.
#[frb(sync)]
pub fn virt_mount_point_ok(path: String) -> bool {
    hardware::mount_point_ok(&path)
}

/// Whether `disk` can be grown from here.
#[frb(sync)]
pub fn virt_hw_disk_growable(disk: HwDisk) -> bool {
    hardware::disk_growable(&disk)
}

/// The address `device` is given by on a host of the kind; None where the
/// host said nothing of where it sits.
#[frb(sync)]
pub fn virt_usb_address(device: HostDevice, pve: bool) -> Option<String> {
    device.usb_address(host(pve))
}

// --- libvirt ---

/// The read ([`super::virt::virt_libvirt_hardware_read`]) as the model has
/// it, for the domain `name`.
#[frb(sync)]
pub fn virt_libvirt_hardware(info: VirtHardwareInfo, name: String) -> Hardware {
    lh::hardware_of(&info, Some(&name))
}

/// `change` as the step [`super::virt::virt_hardware_change_script`]
/// makes, checked first against the read `info` (whose revision is
/// `revision`) and the host's lists.
#[frb(sync)]
pub fn virt_libvirt_hw_change(
    info: VirtHardwareInfo,
    name: String,
    revision: Option<String>,
    change: HwChange,
    pools: Vec<ResourcePool>,
    networks: Vec<Network>,
    volumes: Vec<Volume>,
) -> Result<VirtHwChange, PveError> {
    let list = Listing { pools: &pools, networks: &networks, volumes: &volumes };
    Ok(lh::change_of(&info, &name, revision.as_deref(), &change, list)?)
}

/// Every pending change discarded: the step that writes the definition again
/// from what the domain runs.
#[frb(sync)]
pub fn virt_libvirt_hw_revert(info: VirtHardwareInfo, revision: Option<String>) -> Result<VirtHwChange, PveError> {
    Ok(lh::revert_of(&info, revision.as_deref())?)
}

/// The seed's read as the model has it; `macs` are the domain's NICs.
#[frb(sync)]
pub fn virt_libvirt_cloud_init_state(read: VirtSeedRead, macs: Vec<String>) -> CloudInitState {
    lh::cloud_init_state_of(&read, &macs)
}

/// The seed `edit` writes, for [`super::virt::virt_seed_update_script`], made
/// from the seed as read now (`read`) — refused once it changed since the
/// edit's read.
#[frb(sync)]
pub fn virt_libvirt_cloud_init_update(read: VirtSeedRead, name: String, macs: Vec<String>, edit: CloudInitEdit) -> Result<VirtCloudInit, PveError> {
    Ok(lh::cloud_init_update(&read, &name, &macs, &edit)?)
}

/// The host's devices as the model has them.
#[frb(sync)]
pub fn virt_libvirt_host_devices(devices: VirtHostDevices) -> HostDevices {
    lh::host_devices_of(&devices)
}
