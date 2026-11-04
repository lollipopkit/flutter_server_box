//! Making, copying and deleting guests FFI (sbm_virt::create,
//! sbm_virt::libvirt::create)
//!
//! The rules a new guest and a copy are checked by, what a form offers, and
//! libvirt's steps decided from what the app read. The models are
//! `sbm_virt`'s own, mirrored ([`super::virt_model`], [`super::virt_libvirt`]);
//! a refusal crosses as [`PveError`] (`sbm_virt::error::Error`, its
//! `detail_json` saying which rule), an issue as its [`CreateIssue`].
//!
//! PVE's calls are [`super::pve::PveSession`]'s.

use flutter_rust_bridge::frb;
use sbm_virt::create::{self, CreateListing};
use sbm_virt::libvirt::create as lc;
use sbm_virt::libvirt::host::error_of;
use sbm_virt::libvirt::snapshot::parse_snap_chain;
use sbm_virt::model::{Guest, GuestKind, HostKind};

use super::pve::PveError;
use super::virt_libvirt::{FirmwareDescriptor, VirtCiNetwork, VirtCloneSpec, VirtCloudInit, VirtCreateHost, VirtCreateSpec, VirtCreateVolumes, VirtCreated, VirtDomainDetail, VirtHardwareInfo, VirtStorage};
use super::virt_model::{CloneRequest, CloudInit, CreateIssue, CreateOptions, CreateSpec, Created, Network, ResourcePool, Volume};
use super::virt_view::{Node, Snapshot, VirtGuestReport};

fn host(pve: bool) -> HostKind {
    if pve { HostKind::Pve } else { HostKind::Libvirt }
}

fn kind(lxc: bool) -> GuestKind {
    if lxc { GuestKind::Lxc } else { GuestKind::Qemu }
}

fn ids(pools: Vec<&ResourcePool>) -> Vec<String> {
    pools.into_iter().map(|p| p.id.clone()).collect()
}

fn guests_of(guests: Vec<VirtGuestReport>) -> Vec<Guest> {
    guests.into_iter().map(Into::into).collect()
}

/// Why `spec` cannot be created, or None when it can. The lists are the
/// host's; `media` and `image` the volumes the spec names, as their pools
/// list them (None where they do not); `options` what the host offers a new
/// VM.
#[allow(clippy::too_many_arguments)]
#[frb(sync)]
pub fn virt_create_issue(
    spec: CreateSpec,
    pve: bool,
    guests: Vec<VirtGuestReport>,
    nodes: Vec<Node>,
    pools: Vec<ResourcePool>,
    networks: Vec<Network>,
    media: Option<Volume>,
    image: Option<Volume>,
    options: CreateOptions,
) -> Option<CreateIssue> {
    let guests = guests_of(guests);
    let list = CreateListing {
        guests: &guests,
        nodes: &nodes,
        pools: &pools,
        networks: &networks,
        media: media.as_ref(),
        image: image.as_ref(),
        options: &options,
    };
    create::create_issue(&spec, host(pve), list)
}

/// Why `ci` cannot be written, or None when it can. `keeps_password`: the
/// account has a password already, which stays.
#[frb(sync)]
pub fn virt_cloud_init_issue(ci: CloudInit, pve: bool, keeps_password: bool) -> Option<CreateIssue> {
    create::cloud_init_issue(&ci, host(pve), keeps_password)
}

/// Why a clone cannot go to `storage` on `target_node`; `storages` are the
/// source node's pools.
#[frb(sync)]
pub fn virt_clone_storage_issue(
    storages: Vec<ResourcePool>,
    storage: Option<String>,
    full: bool,
    lxc: bool,
    target_node: Option<String>,
) -> Option<CreateIssue> {
    let refs: Vec<&ResourcePool> = storages.iter().collect();
    create::clone_storage_issue(&refs, storage.as_deref(), full, kind(lxc), target_node.as_deref())
}

/// Why `target_node` cannot be a clone's node.
#[frb(sync)]
pub fn virt_clone_node_issue(nodes: Vec<Node>, target_node: Option<String>, source_node: Option<String>) -> Option<CreateIssue> {
    create::clone_node_issue(&nodes, target_node.as_deref(), source_node.as_deref())
}

/// Whether `name` is a guest's name a host of the kind takes.
#[frb(sync)]
pub fn virt_guest_name_ok(name: String, pve: bool) -> bool {
    create::name_ok(&name, host(pve))
}

/// The ids of the pools a new guest's disk can go in.
#[frb(sync)]
pub fn virt_disk_storages(pools: Vec<ResourcePool>, pve: bool, lxc: bool, node: Option<String>) -> Vec<String> {
    ids(create::disk_storages(&pools, host(pve), kind(lxc), node.as_deref()))
}

/// The ids of the pools install media (a VM) or templates (a container)
/// are found in.
#[frb(sync)]
pub fn virt_media_storages(pools: Vec<ResourcePool>, pve: bool, lxc: bool, node: Option<String>) -> Vec<String> {
    ids(create::media_storages(&pools, host(pve), kind(lxc), node.as_deref()))
}

/// The ids of the pools cloud images are found in.
#[frb(sync)]
pub fn virt_image_storages(pools: Vec<ResourcePool>, pve: bool, node: Option<String>) -> Vec<String> {
    ids(create::image_storages(&pools, host(pve), node.as_deref()))
}

/// The ids of the networks a new guest's NIC can be on.
#[frb(sync)]
pub fn virt_create_networks(networks: Vec<Network>, pve: bool, node: Option<String>) -> Vec<String> {
    create::create_networks(&networks, host(pve), node.as_deref()).into_iter().map(|n| n.id.clone()).collect()
}

/// Whether `volume` is install media (a VM) or a template (a container).
#[frb(sync)]
pub fn virt_is_media(volume: Volume, lxc: bool) -> bool {
    create::is_media(&volume, kind(lxc))
}

/// Whether `volume` is a disk image a new VM can be a copy of.
#[frb(sync)]
pub fn virt_is_cloud_image(volume: Volume, pve: bool) -> bool {
    create::is_cloud_image(&volume, host(pve))
}

/// The image format a libvirt pool of `pool_type` takes.
#[frb(sync)]
pub fn virt_libvirt_disk_format(pool_type: String) -> String {
    create::libvirt_disk_format(&pool_type).to_owned()
}

// --- libvirt ---

/// What a new domain can be given, from the host's read and its firmware
/// descriptors.
#[frb(sync)]
pub fn virt_libvirt_create_options(host: VirtCreateHost, firmware: Vec<FirmwareDescriptor>) -> CreateOptions {
    lc::options_of(&host, &firmware)
}

/// `spec` as the scripts' spec, checked first: what
/// [`super::virt::virt_create_volume_script`] makes the disk and seed from.
/// A cloud-init password leaves as its SHA-512 crypt hash only.
/// `seed_tools` narrows the ISO tools tried (the end-to-end tests).
#[allow(clippy::too_many_arguments)]
#[frb(sync)]
pub fn virt_libvirt_create_spec(
    spec: CreateSpec,
    host: VirtCreateHost,
    firmware: Vec<FirmwareDescriptor>,
    guests: Vec<VirtGuestReport>,
    pools: Vec<ResourcePool>,
    networks: Vec<Network>,
    media: Option<Volume>,
    image: Option<Volume>,
    seed_tools: Option<Vec<String>>,
) -> Result<VirtCreateSpec, PveError> {
    let guests = guests_of(guests);
    let on = lc::CreateHost {
        host: &host,
        firmware: &firmware,
        guests: &guests,
        pools: &pools,
        networks: &networks,
        media: media.as_ref(),
        image: image.as_ref(),
    };
    Ok(lc::spec_of(&spec, on, seed_tools)?)
}

/// `spec` on the paths the volume step made: what
/// [`super::virt::virt_define_script`] defines the domain from.
#[frb(sync)]
pub fn virt_libvirt_with_volumes(spec: VirtCreateSpec, made: VirtCreateVolumes) -> VirtCreateSpec {
    lc::with_volumes(spec, &made)
}

/// What creating came to, from the spec, the volumes made and the define
/// step's answer.
#[frb(sync)]
pub fn virt_libvirt_created(spec: VirtCreateSpec, made: VirtCreateVolumes, created: VirtCreated) -> Created {
    lc::created_of(&spec, &made, created)
}

/// `ci` as the seed for the domain `name`: the password as its hash (or
/// `keep_hash` where none was typed), a new instance ID, the NIC by `mac`;
/// `extra_networks` the seed's NICs after the first, as read.
#[frb(sync)]
pub fn virt_libvirt_cloud_init(
    ci: CloudInit,
    name: String,
    mac: Option<String>,
    keep_hash: Option<String>,
    extra_networks: Vec<VirtCiNetwork>,
    password_expire: bool,
) -> Result<VirtCloudInit, PveError> {
    Ok(lc::cloud_init_of(&ci, &name, mac.as_deref(), keep_hash, extra_networks, password_expire)?)
}

/// A MAC in QEMU's range, for a new NIC.
#[frb(sync)]
pub fn virt_new_mac() -> Result<String, PveError> {
    Ok(lc::new_mac()?)
}

/// Whether deleting with the disks needs the disks' chains read: the
/// domain's snapshots have external ones.
#[frb(sync)]
pub fn virt_libvirt_delete_needs_chain(snapshots: Vec<Snapshot>) -> bool {
    lc::delete_needs_chain(&snapshots)
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

/// One active pool's volumes, for [`virt_libvirt_delete_plan`].
pub struct VirtPoolVolumes {
    pub pool: String,
    pub volumes: Vec<Volume>,
}

/// What goes with domain `id` (`name`) when its disks do: from its detail,
/// the host's storage, each active pool's volumes, its snapshots, and the
/// disks' chain script output where [`virt_libvirt_delete_needs_chain`] says.
#[frb(sync)]
pub fn virt_libvirt_delete_plan(
    id: String,
    name: String,
    detail: VirtDomainDetail,
    storage: VirtStorage,
    volumes: Vec<VirtPoolVolumes>,
    snapshots: Vec<Snapshot>,
    chain_raw: Option<String>,
) -> Result<VirtDeletePlan, PveError> {
    let volumes: Vec<(String, Vec<Volume>)> = volumes.into_iter().map(|p| (p.pool, p.volumes)).collect();
    let chain = match chain_raw {
        Some(raw) => Some(parse_snap_chain(&raw).map_err(|e| error_of(&e, false))?),
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

/// A copy of `guest` as [`super::virt::virt_clone_volumes_script`]'s spec,
/// checked first, from its hardware read, the host's guests and storage.
#[frb(sync)]
pub fn virt_libvirt_clone_spec(
    guest: VirtGuestReport,
    hardware: VirtHardwareInfo,
    request: CloneRequest,
    guests: Vec<VirtGuestReport>,
    storage: VirtStorage,
) -> Result<VirtCloneSpec, PveError> {
    let guest: Guest = guest.into();
    Ok(lc::clone_spec_of(&guest, &hardware.config, &request, &guests_of(guests), &storage.pools)?)
}

/// The copy's disks for [`super::virt::virt_clone_define_script`]: each
/// target of `spec` with the path made for it.
#[frb(sync)]
pub fn virt_libvirt_clone_disks(spec: VirtCloneSpec, paths: Vec<String>) -> Vec<(String, String)> {
    lc::clone_disks(&spec, &paths)
}
