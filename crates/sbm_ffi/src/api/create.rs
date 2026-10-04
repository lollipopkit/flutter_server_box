//! Making, copying and deleting guests FFI (sbm_virt::create,
//! sbm_virt::libvirt::create)
//!
//! The rules a new guest and a copy are checked by, what a form offers, and
//! libvirt's steps decided from what the app read. A spec, a guest, a pool,
//! a volume and a network cross as their `sbm_virt` JSON (snake_case, the
//! agent's wire format); a refusal crosses as [`PveError`]
//! (`sbm_virt::error::Error`, its `detail_json` saying which rule), an
//! issue as its name (`name_taken`).
//!
//! PVE's calls are [`super::pve::PveSession`]'s.

use sbm_virt::create::{self, CloneRequest, CloudInit, CreateListing, CreateOptions, CreateSpec, Issue};
use sbm_virt::error::{Error, ErrorKind};
use sbm_virt::libvirt::{self, create as lc};
use sbm_virt::model::{Guest, GuestKind, HostKind, Node};
use sbm_virt::resource::{Network, Pool, Volume};
use serde::de::DeserializeOwned;

use super::pve::PveError;

fn read<T: DeserializeOwned>(json: &str) -> Result<T, PveError> {
    serde_json::from_str(json).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
}

fn read_opt<T: DeserializeOwned>(json: &Option<String>) -> Result<Option<T>, PveError> {
    json.as_deref().map(read).transpose()
}

fn write<T: serde::Serialize>(value: &T) -> Result<String, PveError> {
    serde_json::to_string(value).map_err(|e| Error::msg(ErrorKind::InvalidResponse, e.to_string()).into())
}

fn host(pve: bool) -> HostKind {
    if pve { HostKind::Pve } else { HostKind::Libvirt }
}

fn kind(lxc: bool) -> GuestKind {
    if lxc { GuestKind::Lxc } else { GuestKind::Qemu }
}

fn issue_name(issue: Issue) -> String {
    serde_json::to_value(issue).ok().and_then(|v| v.as_str().map(str::to_owned)).unwrap_or_default()
}

fn ids(pools: Vec<&Pool>) -> Vec<String> {
    pools.into_iter().map(|p| p.id.clone()).collect()
}

/// Why `spec_json` (a `CreateSpec`) cannot be created, as an `Issue`'s
/// name; None when it can. The lists are the host's; `media_json` and
/// `image_json` the volumes the spec names, as their pools list them (None
/// where they do not); `options_json` what the host offers a new VM.
#[allow(clippy::too_many_arguments)]
#[flutter_rust_bridge::frb(sync)]
pub fn virt_create_issue(
    spec_json: String,
    pve: bool,
    guests_json: String,
    nodes_json: String,
    pools_json: String,
    networks_json: String,
    media_json: Option<String>,
    image_json: Option<String>,
    options_json: String,
) -> Result<Option<String>, PveError> {
    let spec: CreateSpec = read(&spec_json)?;
    let guests: Vec<Guest> = read(&guests_json)?;
    let nodes: Vec<Node> = read(&nodes_json)?;
    let pools: Vec<Pool> = read(&pools_json)?;
    let networks: Vec<Network> = read(&networks_json)?;
    let media: Option<Volume> = read_opt(&media_json)?;
    let image: Option<Volume> = read_opt(&image_json)?;
    let options: CreateOptions = read(&options_json)?;
    let list = CreateListing {
        guests: &guests,
        nodes: &nodes,
        pools: &pools,
        networks: &networks,
        media: media.as_ref(),
        image: image.as_ref(),
        options: &options,
    };
    Ok(create::create_issue(&spec, host(pve), list).map(issue_name))
}

/// Why `ci_json` (a `CloudInit`) cannot be written, as an `Issue`'s name;
/// None when it can. `keeps_password`: the account has a password already,
/// which stays.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_cloud_init_issue(ci_json: String, pve: bool, keeps_password: bool) -> Result<Option<String>, PveError> {
    let ci: CloudInit = read(&ci_json)?;
    Ok(create::cloud_init_issue(&ci, host(pve), keeps_password).map(issue_name))
}

/// Why a clone cannot go to `storage` on `target_node`, as an `Issue`'s
/// name; `storages_json` are the source node's pools.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_clone_storage_issue(
    storages_json: String,
    storage: Option<String>,
    full: bool,
    lxc: bool,
    target_node: Option<String>,
) -> Result<Option<String>, PveError> {
    let pools: Vec<Pool> = read(&storages_json)?;
    let refs: Vec<&Pool> = pools.iter().collect();
    Ok(create::clone_storage_issue(&refs, storage.as_deref(), full, kind(lxc), target_node.as_deref()).map(issue_name))
}

/// Why `target_node` cannot be a clone's node, as an `Issue`'s name.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_clone_node_issue(
    nodes_json: String,
    target_node: Option<String>,
    source_node: Option<String>,
) -> Result<Option<String>, PveError> {
    let nodes: Vec<Node> = read(&nodes_json)?;
    Ok(create::clone_node_issue(&nodes, target_node.as_deref(), source_node.as_deref()).map(issue_name))
}

/// Whether `name` is a guest's name a host of the kind takes.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_guest_name_ok(name: String, pve: bool) -> bool {
    create::name_ok(&name, host(pve))
}

/// The ids of the pools a new guest's disk can go in.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_disk_storages(pools_json: String, pve: bool, lxc: bool, node: Option<String>) -> Result<Vec<String>, PveError> {
    let pools: Vec<Pool> = read(&pools_json)?;
    Ok(ids(create::disk_storages(&pools, host(pve), kind(lxc), node.as_deref())))
}

/// The ids of the pools install media (a VM) or templates (a container)
/// are found in.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_media_storages(pools_json: String, pve: bool, lxc: bool, node: Option<String>) -> Result<Vec<String>, PveError> {
    let pools: Vec<Pool> = read(&pools_json)?;
    Ok(ids(create::media_storages(&pools, host(pve), kind(lxc), node.as_deref())))
}

/// The ids of the pools cloud images are found in.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_image_storages(pools_json: String, pve: bool, node: Option<String>) -> Result<Vec<String>, PveError> {
    let pools: Vec<Pool> = read(&pools_json)?;
    Ok(ids(create::image_storages(&pools, host(pve), node.as_deref())))
}

/// The ids of the networks a new guest's NIC can be on.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_create_networks(networks_json: String, pve: bool, node: Option<String>) -> Result<Vec<String>, PveError> {
    let networks: Vec<Network> = read(&networks_json)?;
    Ok(create::create_networks(&networks, host(pve), node.as_deref()).into_iter().map(|n| n.id.clone()).collect())
}

/// Whether `volume_json` is install media (a VM) or a template (a
/// container).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_is_media(volume_json: String, lxc: bool) -> Result<bool, PveError> {
    Ok(create::is_media(&read(&volume_json)?, kind(lxc)))
}

/// Whether `volume_json` is a disk image a new VM can be a copy of.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_is_cloud_image(volume_json: String, pve: bool) -> Result<bool, PveError> {
    Ok(create::is_cloud_image(&read(&volume_json)?, host(pve)))
}

/// The image format a libvirt pool of `pool_type` takes.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_disk_format(pool_type: String) -> String {
    create::libvirt_disk_format(&pool_type).to_owned()
}

// --- libvirt ---

/// What a new domain can be given, `CreateOptions` JSON, from
/// [`super::virt::parse_virt_create_host_json`]'s host and
/// [`super::virt::parse_virt_firmware_json`]'s descriptors.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_create_options(host_json: String, firmware_json: String) -> Result<String, PveError> {
    let host: libvirt::VirtCreateHost = read(&host_json)?;
    let firmware: Vec<libvirt::FirmwareDescriptor> = read(&firmware_json)?;
    write(&lc::options_of(&host, &firmware))
}

/// `spec_json` as the scripts' `VirtCreateSpec` JSON, checked first: what
/// [`super::virt::virt_create_volume_script`] makes the disk and seed from.
/// A cloud-init password leaves as its SHA-512 crypt hash only.
/// `seed_tools` narrows the ISO tools tried (the end-to-end tests).
#[allow(clippy::too_many_arguments)]
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_create_spec(
    spec_json: String,
    host_json: String,
    firmware_json: String,
    guests_json: String,
    pools_json: String,
    networks_json: String,
    media_json: Option<String>,
    image_json: Option<String>,
    seed_tools: Option<Vec<String>>,
) -> Result<String, PveError> {
    let spec: CreateSpec = read(&spec_json)?;
    let host: libvirt::VirtCreateHost = read(&host_json)?;
    let firmware: Vec<libvirt::FirmwareDescriptor> = read(&firmware_json)?;
    let guests: Vec<Guest> = read(&guests_json)?;
    let pools: Vec<Pool> = read(&pools_json)?;
    let networks: Vec<Network> = read(&networks_json)?;
    let media: Option<Volume> = read_opt(&media_json)?;
    let image: Option<Volume> = read_opt(&image_json)?;
    let on = lc::CreateHost {
        host: &host,
        firmware: &firmware,
        guests: &guests,
        pools: &pools,
        networks: &networks,
        media: media.as_ref(),
        image: image.as_ref(),
    };
    write(&lc::spec_of(&spec, on, seed_tools)?)
}

/// `spec_json` (a `VirtCreateSpec`) on the paths
/// [`super::virt::parse_virt_create_volumes_json`] read (`made_json`): what
/// [`super::virt::virt_define_script`] defines the domain from.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_with_volumes(spec_json: String, made_json: String) -> Result<String, PveError> {
    write(&lc::with_volumes(read(&spec_json)?, &read(&made_json)?))
}

/// What creating came to, `Created` JSON, from the spec, the volumes made
/// and [`super::virt::parse_virt_create_json`]'s answer.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_created(spec_json: String, made_json: String, created_json: String) -> Result<String, PveError> {
    let spec: libvirt::VirtCreateSpec = read(&spec_json)?;
    write(&lc::created_of(&spec, &read(&made_json)?, read(&created_json)?))
}

/// `ci_json` (a `CloudInit`) as the seed's `VirtCloudInit` JSON for the
/// domain `name`: the password as its hash (or `keep_hash` where none was
/// typed), a new instance ID, the NIC by `mac`; `extra_networks_json` the
/// seed's NICs after the first, as read.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_cloud_init(
    ci_json: String,
    name: String,
    mac: Option<String>,
    keep_hash: Option<String>,
    extra_networks_json: String,
    password_expire: bool,
) -> Result<String, PveError> {
    let ci: CloudInit = read(&ci_json)?;
    let extra: Vec<libvirt::cloud_init::VirtCiNetwork> = read(&extra_networks_json)?;
    write(&lc::cloud_init_of(&ci, &name, mac.as_deref(), keep_hash, extra, password_expire)?)
}

/// A MAC in QEMU's range, for a new NIC.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_new_mac() -> Result<String, PveError> {
    Ok(lc::new_mac()?)
}

/// Whether deleting with the disks needs the disks' chains read:
/// `snapshots_json` (the domain's `Snapshot`s) has external ones.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_delete_needs_chain(snapshots_json: String) -> Result<bool, PveError> {
    let snapshots: Vec<sbm_virt::snapshot::Snapshot> = read(&snapshots_json)?;
    Ok(lc::delete_needs_chain(&snapshots))
}

/// What goes with a deleted domain: [`super::virt::virt_undefine_script`]'s
/// arguments, and what stays, said for a log.
pub struct VirtDeletePlan {
    pub targets: Vec<String>,
    pub seed: Option<String>,
    pub pools: Vec<String>,
    pub files: Vec<String>,
    pub kept: Vec<String>,
}

/// What goes with domain `id` (`name`) when its disks do. `detail_json` is
/// [`super::virt::parse_virt_domain_detail_json`]'s; `storage_json`
/// [`super::virt::parse_virt_storage_json`]'s; `volumes_json` each active
/// pool's `Volume`s, `[[pool, [volume, ...]], ...]`; `snapshots_json` the
/// domain's `Snapshot`s; `chain_raw` the disks' chain script output, where
/// [`virt_libvirt_delete_needs_chain`] says.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_delete_plan(
    id: String,
    name: String,
    detail_json: String,
    storage_json: String,
    volumes_json: String,
    snapshots_json: String,
    chain_raw: Option<String>,
) -> Result<VirtDeletePlan, PveError> {
    let detail: libvirt::VirtDomainDetail = read(&detail_json)?;
    let storage: libvirt::VirtStorage = read(&storage_json)?;
    let volumes: Vec<(String, Vec<Volume>)> = read(&volumes_json)?;
    let snapshots: Vec<sbm_virt::snapshot::Snapshot> = read(&snapshots_json)?;
    let chain = match chain_raw {
        Some(raw) => {
            Some(libvirt::snapshot::parse_snap_chain(&raw).map_err(|e| sbm_virt::libvirt::host::error_of(&e, false))?)
        }
        None => None,
    };
    let plan = lc::delete_plan(lc::DeleteInputs {
        id: &id,
        name: &name,
        xml: &detail.xml,
        disks: &storage.disks,
        pools: &storage.pools,
        volumes: &volumes,
        snapshots: &snapshots,
        chain: chain.as_ref(),
    });
    Ok(VirtDeletePlan { targets: plan.targets, seed: plan.seed, pools: plan.pools, files: plan.files, kept: plan.kept })
}

/// A copy of `guest_json` as [`super::virt::virt_clone_volumes_script`]'s
/// `VirtCloneSpec` JSON, checked first. `hardware_json` is
/// [`super::virt::parse_virt_hardware_json`]'s; `guests_json` the host's;
/// `storage_json` [`super::virt::parse_virt_storage_json`]'s.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_clone_spec(
    guest_json: String,
    hardware_json: String,
    request_json: String,
    guests_json: String,
    storage_json: String,
) -> Result<String, PveError> {
    let guest: Guest = read(&guest_json)?;
    let info: libvirt::VirtHardwareInfo = read(&hardware_json)?;
    let request: CloneRequest = read(&request_json)?;
    let guests: Vec<Guest> = read(&guests_json)?;
    let storage: libvirt::VirtStorage = read(&storage_json)?;
    write(&lc::clone_spec_of(&guest, &info.config, &request, &guests, &storage.pools)?)
}

/// The copy's disks for [`super::virt::virt_clone_define_script`]: each
/// target of `spec_json` with the path made for it, `[[target, path], ...]`.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_clone_disks(spec_json: String, paths: Vec<String>) -> Result<String, PveError> {
    let spec: libvirt::VirtCloneSpec = read(&spec_json)?;
    write(&lc::clone_disks(&spec, &paths))
}
