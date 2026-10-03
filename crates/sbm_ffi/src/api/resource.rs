//! Storage and networks FFI (sbm_virt::resource, sbm_virt::libvirt::host)
//!
//! The rules a change is checked by before it is sent, what a form offers
//! for a pool, and libvirt's listings mapped onto `sbm_virt::resource`. A
//! pool, a volume, a network and a change cross as their `sbm_virt` JSON
//! (snake_case, the agent's wire format); a refusal crosses as [`PveError`]
//! (`sbm_virt::error::Error`, its `detail_json` saying which rule).
//!
//! PVE's listings and changes are [`super::pve::PveSession`]'s.

use sbm_virt::error::{Error, ErrorKind};
use sbm_virt::libvirt::{self, host};
use sbm_virt::model::HostKind;
use sbm_virt::resource::{self, Change, Listing, Network, Pool, Volume};
use serde::de::DeserializeOwned;

use super::pve::PveError;
use super::virt::{VirtFfiError, json_err};

fn read<T: DeserializeOwned>(json: &str) -> Result<T, PveError> {
    serde_json::from_str(json).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
}

fn write<T: serde::Serialize>(value: &T) -> Result<String, PveError> {
    serde_json::to_string(value).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
}

fn kind(pve: bool) -> HostKind {
    if pve { HostKind::Pve } else { HostKind::Libvirt }
}

fn issue_name(issue: resource::Issue) -> String {
    serde_json::to_value(issue).ok().and_then(|v| v.as_str().map(str::to_owned)).unwrap_or_default()
}

/// Why `change_json` (a `Change`) cannot be made on the host, as the
/// `Issue`'s name (`in_use`); None when it can. The lists are the host's:
/// its pools and networks, and the volumes of the pool the change is to.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_resource_issue(
    change_json: String,
    pve: bool,
    pools_json: String,
    networks_json: String,
    volumes_json: String,
) -> Result<Option<String>, PveError> {
    let change: Change = read(&change_json)?;
    let pools: Vec<Pool> = read(&pools_json)?;
    let networks: Vec<Network> = read(&networks_json)?;
    let volumes: Vec<Volume> = read(&volumes_json)?;
    Ok(resource::issue(&change, kind(pve), Listing { pools: &pools, networks: &networks, volumes: &volumes }).map(issue_name))
}

/// Why an upload of `name` into `pool_json` cannot start, as an `Issue`'s
/// name; None when it can.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_upload_issue(pool_json: String, name: String, size: u64, volumes_json: String) -> Result<Option<String>, PveError> {
    let pool: Pool = read(&pool_json)?;
    let volumes: Vec<Volume> = read(&volumes_json)?;
    Ok(resource::upload_issue(&pool, &name, size, &volumes).map(issue_name))
}

#[flutter_rust_bridge::frb(sync)]
pub fn virt_pool_takes_media(pool_json: String) -> Result<bool, PveError> {
    Ok(resource::pool_takes_media(&read(&pool_json)?))
}

/// The formats a new volume in the pool can have, the first the default.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_volume_formats(pool_json: String) -> Result<Vec<String>, PveError> {
    let pool: Pool = read(&pool_json)?;
    Ok(resource::volume_formats(&pool).iter().map(|f| (*f).to_owned()).collect())
}

/// PVE: the file a new volume is given, the format as its extension on a
/// storage of files.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_volume_file_name(pool_json: String, name: String, format: String) -> Result<String, PveError> {
    Ok(resource::volume_file_name(&read(&pool_json)?, &name, &format))
}

/// Whether a volume of the pool is grown on its own.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_volume_resizable(pool_json: String, pve: bool) -> Result<bool, PveError> {
    Ok(resource::volume_resizable(&read(&pool_json)?, kind(pve)))
}

/// The VMID a PVE volume name belongs to (`vm-105-disk-0`).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_pve_volume_vmid(name: String) -> Option<u32> {
    resource::pve_volume_vmid(&name)
}

/// The DHCP range a form offers for `cidr`, its two ends; None when `cidr`
/// is not a usable one.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_default_dhcp_range(cidr: String) -> Option<Vec<String>> {
    resource::ipv4::default_dhcp_range(&cidr).map(|(a, b)| vec![a, b])
}

/// What a PVE node is asked about the interfaces it is using
/// (`sbm_virt::pve::net::LIVE_NET_SCRIPT`), run on the server; its output
/// goes to [`super::pve::PveSession::networks`] and `manage` as it is.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_pve_live_net_script() -> String {
    sbm_virt::pve::net::LIVE_NET_SCRIPT.to_owned()
}

// --- libvirt ---

/// [`super::virt::parse_virt_storage_json`]'s storage as the host's pools
/// (`Pool` JSON).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_pools(storage_json: String) -> Result<String, PveError> {
    let storage: libvirt::VirtStorage = read(&storage_json)?;
    write(&storage.pools.iter().map(host::pool_of).collect::<Vec<_>>())
}

/// [`super::virt::virt_volumes_script`]'s output for `pool` as `Volume`
/// JSON, with the domains whose disks each is (from `storage_json`).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_volumes(raw: String, pool: String, storage_json: String) -> Result<String, VirtFfiError> {
    let storage: libvirt::VirtStorage = serde_json::from_str(&storage_json).map_err(json_err)?;
    let read = libvirt::parse_volumes(&raw)?;
    let volumes: Vec<Volume> = read.iter().map(|v| host::volume_of(v, &pool, &storage.disks)).collect();
    serde_json::to_string(&volumes).map_err(json_err)
}

/// `volumes_json` with what is made on each: the volumes in `every_json`
/// (every active pool's) whose backing file it is.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_with_backs(volumes_json: String, every_json: String) -> Result<String, PveError> {
    let volumes: Vec<Volume> = read(&volumes_json)?;
    let every: Vec<Volume> = read(&every_json)?;
    write(&host::with_backs(volumes, &every))
}

/// [`super::virt::virt_networks_script`]'s output as `Network` JSON.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_networks(raw: String) -> Result<String, VirtFfiError> {
    let all = libvirt::parse_networks(&raw)?;
    let networks: Vec<Network> = all.networks.iter().map(|n| host::network_of(n, &all)).collect();
    serde_json::to_string(&networks).map_err(json_err)
}

/// The script a change runs as on a libvirt host.
pub struct VirtResourceScript {
    pub script: String,
    /// An existing network's edit or restart: read its output with
    /// [`super::virt::parse_virt_net_change`]; otherwise
    /// [`super::virt::parse_virt_resource`].
    pub net: bool,
}

/// `change_json` as the script that makes it, checked first against the
/// host's lists, read for this change.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_resource_script(
    change_json: String,
    pools_json: String,
    networks_json: String,
    volumes_json: String,
) -> Result<VirtResourceScript, PveError> {
    let change: Change = read(&change_json)?;
    let pools: Vec<Pool> = read(&pools_json)?;
    let networks: Vec<Network> = read(&networks_json)?;
    let volumes: Vec<Volume> = read(&volumes_json)?;
    let script = host::resource_script(&change, Listing { pools: &pools, networks: &networks, volumes: &volumes })?;
    let text = script.script().map_err(|e| host::error_of(&e, true))?;
    Ok(VirtResourceScript { script: text, net: matches!(script, host::ResourceScript::Net(_)) })
}
