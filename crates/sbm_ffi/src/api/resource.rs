//! Storage and networks FFI (sbm_virt::resource, sbm_virt::libvirt::host)
//!
//! The rules a change is checked by before it is sent, what a form offers
//! for a pool, and libvirt's listings mapped onto `sbm_virt::resource`. The
//! models are `sbm_virt`'s own, mirrored ([`super::virt_model`]); a refusal
//! crosses as [`PveError`] (`sbm_virt::error::Error`, its `detail_json`
//! saying which rule), an issue as its [`ResourceIssue`].
//!
//! PVE's listings and changes are [`super::pve::PveSession`]'s.

use flutter_rust_bridge::frb;
use sbm_virt::libvirt::{self, host};
use sbm_virt::model::HostKind;
use sbm_virt::resource::{self, Listing};

use super::pve::PveError;
use super::virt::VirtFfiError;
use super::virt_libvirt::VirtStorage;
use super::virt_model::{Network, ResourceChange, ResourceIssue, ResourcePool, Volume};

fn kind(pve: bool) -> HostKind {
    if pve { HostKind::Pve } else { HostKind::Libvirt }
}

/// Why `change` cannot be made on the host, or None when it can. The lists
/// are the host's: its pools and networks, and the volumes of the pool the
/// change is to.
#[frb(sync)]
pub fn virt_resource_issue(
    change: ResourceChange,
    pve: bool,
    pools: Vec<ResourcePool>,
    networks: Vec<Network>,
    volumes: Vec<Volume>,
) -> Option<ResourceIssue> {
    resource::issue(&change, kind(pve), Listing { pools: &pools, networks: &networks, volumes: &volumes })
}

/// Why an upload of `name` into `pool` cannot start, or None when it can.
#[frb(sync)]
pub fn virt_upload_issue(pool: ResourcePool, name: String, size: u64, volumes: Vec<Volume>) -> Option<ResourceIssue> {
    resource::upload_issue(&pool, &name, size, &volumes)
}

#[frb(sync)]
pub fn virt_pool_takes_media(pool: ResourcePool) -> bool {
    resource::pool_takes_media(&pool)
}

/// The formats a new volume in the pool can have, the first the default.
#[frb(sync)]
pub fn virt_volume_formats(pool: ResourcePool) -> Vec<String> {
    resource::volume_formats(&pool).iter().map(|f| (*f).to_owned()).collect()
}

/// PVE: the file a new volume is given, the format as its extension on a
/// storage of files.
#[frb(sync)]
pub fn virt_volume_file_name(pool: ResourcePool, name: String, format: String) -> String {
    resource::volume_file_name(&pool, &name, &format)
}

/// Whether a volume of the pool is grown on its own.
#[frb(sync)]
pub fn virt_volume_resizable(pool: ResourcePool, pve: bool) -> bool {
    resource::volume_resizable(&pool, kind(pve))
}

/// The VMID a PVE volume name belongs to (`vm-105-disk-0`).
#[frb(sync)]
pub fn virt_pve_volume_vmid(name: String) -> Option<u32> {
    resource::pve_volume_vmid(&name)
}

/// The DHCP range a form offers for `cidr`, its two ends; None when `cidr`
/// is not a usable one.
#[frb(sync)]
pub fn virt_default_dhcp_range(cidr: String) -> Option<Vec<String>> {
    resource::ipv4::default_dhcp_range(&cidr).map(|(a, b)| vec![a, b])
}

/// What a PVE node is asked about the interfaces it is using
/// (`sbm_virt::pve::net::LIVE_NET_SCRIPT`), run on the server; its output
/// goes to [`super::pve::PveSession::networks`] and `manage` as it is.
#[frb(sync)]
pub fn virt_pve_live_net_script() -> String {
    sbm_virt::pve::net::LIVE_NET_SCRIPT.to_owned()
}

// --- libvirt ---

/// The storage read as the host's pools.
#[frb(sync)]
pub fn virt_libvirt_pools(storage: VirtStorage) -> Vec<ResourcePool> {
    storage.pools.iter().map(host::pool_of).collect()
}

/// [`super::virt::virt_volumes_script`]'s output for `pool`, with the
/// domains whose disks each is (from `storage`).
#[frb(sync)]
pub fn virt_libvirt_volumes(raw: String, pool: String, storage: VirtStorage) -> Result<Vec<Volume>, VirtFfiError> {
    Ok(libvirt::parse_volumes(&raw)?.iter().map(|v| host::volume_of(v, &pool, &storage.disks)).collect())
}

/// `volumes` with what is made on each: the volumes in `every` (every active
/// pool's) whose backing file it is.
#[frb(sync)]
pub fn virt_libvirt_with_backs(volumes: Vec<Volume>, every: Vec<Volume>) -> Vec<Volume> {
    host::with_backs(volumes, &every)
}

/// [`super::virt::virt_networks_script`]'s output as the host's networks.
#[frb(sync)]
pub fn virt_libvirt_networks(raw: String) -> Result<Vec<Network>, VirtFfiError> {
    let all = libvirt::parse_networks(&raw)?;
    Ok(all.networks.iter().map(|n| host::network_of(n, &all)).collect())
}

/// The script a change runs as on a libvirt host.
pub struct VirtResourceScript {
    pub script: String,
    /// An existing network's edit or restart: read its output with
    /// [`super::virt::parse_virt_net_change`]; otherwise
    /// [`super::virt::parse_virt_resource`].
    pub net: bool,
}

/// `change` as the script that makes it, checked first against the host's
/// lists, read for this change.
#[frb(sync)]
pub fn virt_libvirt_resource_script(
    change: ResourceChange,
    pools: Vec<ResourcePool>,
    networks: Vec<Network>,
    volumes: Vec<Volume>,
) -> Result<VirtResourceScript, PveError> {
    let script = host::resource_script(&change, Listing { pools: &pools, networks: &networks, volumes: &volumes })?;
    let text = script.script().map_err(|e| host::error_of(&e, true))?;
    Ok(VirtResourceScript { script: text, net: matches!(script, host::ResourceScript::Net(_)) })
}
