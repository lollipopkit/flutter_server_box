//! libvirt command layer FFI (sbm_virt::libvirt)
//!
//! Scripts are POSIX `sh` for `CommandExec.run(script, entry: 'sh')` (or the
//! sudo entry of `PrivilegedExec`). Parsed results are `sbm_virt`'s models,
//! mirrored ([`super::virt_libvirt`], [`super::virt_view`]); a failure crosses
//! as [`VirtFfiError`], whose `kind` is what the app branches
//! on (retry with sudo on `PermissionDenied`).

use sbm_virt::libvirt::{self, manage, net, snapshot};

use super::virt_libvirt::{
    FirmwareDescriptor, VirtCloneSpec, VirtCloudInit, VirtCreateHost, VirtCreateSpec, VirtCreateVolumes, VirtCreated, VirtDomainDetail,
    VirtHardwareInfo, VirtHostDevices, VirtHostProbe, VirtHwChange, VirtHwOutcome, VirtResourceOp, VirtSeedRead, VirtStorage,
    VirtVncConsoleInfo,
};
use super::exec_session::SudoEntry;
use super::virt_view::{Chain, Diff, Snapshot, VirtGuestDetailReport, VirtHostReport};

/// Power actions (mirrors sbm_virt::libvirt::VirtAction)
pub enum VirtActionKind {
    Start,
    /// ACPI shutdown request
    Shutdown,
    /// ACPI reboot request
    Reboot,
    /// `virsh destroy`
    ForceStop,
    /// Pause vCPUs
    Suspend,
    Resume,
}

impl From<VirtActionKind> for libvirt::VirtAction {
    fn from(kind: VirtActionKind) -> Self {
        match kind {
            VirtActionKind::Start => libvirt::VirtAction::Start,
            VirtActionKind::Shutdown => libvirt::VirtAction::Shutdown,
            VirtActionKind::Reboot => libvirt::VirtAction::Reboot,
            VirtActionKind::ForceStop => libvirt::VirtAction::ForceStop,
            VirtActionKind::Suspend => libvirt::VirtAction::Suspend,
            VirtActionKind::Resume => libvirt::VirtAction::Resume,
        }
    }
}

/// Classes of [`VirtFfiError`] (mirrors sbm_virt::libvirt::VirtError)
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VirtErrorKind {
    /// `virsh` is not on PATH
    NotInstalled,
    /// The daemon refused this user; retrying as root is the fix
    PermissionDenied,
    /// The daemon could not be reached
    ConnectFailed,
    DomainNotFound,
    /// The domain's state does not allow the operation
    InvalidState,
    /// A domain or volume of that name is there already
    Exists,
    /// The definition changed since it was read
    Conflict,
    /// Any other virsh failure
    Command,
    /// Output cut off or not what the script prints
    Malformed,
}

/// A classified virsh failure; `message` is virsh's own error text.
#[derive(Debug, Clone)]
pub struct VirtFfiError {
    pub kind: VirtErrorKind,
    pub message: String,
}

impl From<libvirt::VirtError> for VirtFfiError {
    fn from(e: libvirt::VirtError) -> Self {
        use libvirt::VirtError as E;
        let kind = match &e {
            E::NotInstalled => VirtErrorKind::NotInstalled,
            E::PermissionDenied { .. } => VirtErrorKind::PermissionDenied,
            E::ConnectFailed { .. } => VirtErrorKind::ConnectFailed,
            E::DomainNotFound { .. } => VirtErrorKind::DomainNotFound,
            E::InvalidState { .. } => VirtErrorKind::InvalidState,
            E::Exists { .. } => VirtErrorKind::Exists,
            E::Conflict { .. } => VirtErrorKind::Conflict,
            E::Command { .. } => VirtErrorKind::Command,
            E::Malformed { .. } => VirtErrorKind::Malformed,
        };
        VirtFfiError { kind, message: e.message() }
    }
}

/// Host probe: Proxmox VE, a container, or `virsh` answering this user
#[flutter_rust_bridge::frb(sync)]
pub fn virt_probe_script() -> String {
    libvirt::probe_script()
}

/// Guest list, state, and raw counters in one round trip
#[flutter_rust_bridge::frb(sync)]
pub fn virt_overview_script() -> String {
    libvirt::overview_script()
}

/// Display URI and XML for one domain (`domain`: UUID preferred, or name)
#[flutter_rust_bridge::frb(sync)]
pub fn virt_domain_detail_script(domain: String) -> String {
    libvirt::domain_detail_script(&domain)
}

/// One power action on one domain
#[flutter_rust_bridge::frb(sync)]
pub fn virt_action_script(action: VirtActionKind, domain: String) -> String {
    libvirt::action_script(action.into(), &domain)
}

/// Command line for an interactive serial console in a terminal session
#[flutter_rust_bridge::frb(sync)]
pub fn virt_console_command(domain: String) -> String {
    libvirt::console_command(&domain)
}

/// [`virt_probe_script`]'s output as `VirtHostProbe`
pub fn virt_libvirt_probe(raw: String) -> Result<VirtHostProbe, VirtFfiError> {
    Ok(libvirt::parse_probe(&raw)?)
}

/// The overview read into one host view (`sbm_virt::model::HostView`),
/// with usage diffed against the previous one (sbm_virt::libvirt::host). One
/// per host: it holds each guest's last counters.
#[flutter_rust_bridge::frb(opaque)]
pub struct LibvirtRates(sbm_virt::rates::RateTracker);

impl LibvirtRates {
    #[flutter_rust_bridge::frb(sync)]
    pub fn new() -> LibvirtRates {
        LibvirtRates(sbm_virt::rates::RateTracker::new(false))
    }

    /// `raw` is [`virt_overview_script`]'s output, `at_ms` when it was read.
    /// `pool_types` is [`parse_virt_pool_types`]'s answer; `upload` whether
    /// the channel carries bytes for `vol-upload`.
    #[flutter_rust_bridge::frb(sync)]
    pub fn view(&mut self, raw: String, at_ms: i64, pool_types: Option<Vec<String>>, upload: bool) -> Result<VirtHostReport, VirtFfiError> {
        let overview = libvirt::parse_overview(&raw)?;
        Ok(libvirt::host::view_of(&overview, &mut self.0, at_ms, pool_types.as_deref(), upload).into())
    }

    /// Forgets every guest's counters: the next view has no rates.
    #[flutter_rust_bridge::frb(sync)]
    pub fn clear(&mut self) {
        self.0.clear();
    }
}

/// [`virt_overview_script`]'s output checked as [`LibvirtRates::view`] reads
/// it, without touching any counters: what tells a refusal from a listing.
pub fn virt_overview_check(raw: String) -> Result<(), VirtFfiError> {
    libvirt::parse_overview(&raw)?;
    Ok(())
}

/// [`virt_domain_detail_script`]'s output read into
/// `sbm_virt::model::GuestDetail` (sbm_virt::libvirt::host).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_guest_detail(raw: String) -> Result<VirtGuestDetailReport, VirtFfiError> {
    Ok(libvirt::host::detail_of(&libvirt::parse_domain_detail(&raw)?).into())
}

// --- Snapshots (sbm_virt::snapshot, sbm_virt::libvirt::host) ---

/// A libvirt pool as a snapshot's chain needs it (mirrors the fields of
/// sbm_virt::libvirt::VirtPool it reads).
pub struct LibvirtPoolRef {
    pub name: String,
    pub pool_type: Option<String>,
    pub active: bool,
    /// The pool's target: a directory for a pool of files.
    pub target: Option<String>,
}

impl From<LibvirtPoolRef> for libvirt::VirtPool {
    fn from(p: LibvirtPoolRef) -> Self {
        libvirt::VirtPool { name: p.name, pool_type: p.pool_type, active: p.active, target: p.target, ..Default::default() }
    }
}

/// An active pool of files: where an overlay can go.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_pool_holds_files(pool: LibvirtPoolRef) -> bool {
    libvirt::host::pool_holds_files(&pool.into())
}

/// The pool of files whose directory holds `file` itself, by name.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_pool_of_file(pools: Vec<LibvirtPoolRef>, file: String) -> Option<String> {
    let pools: Vec<libvirt::VirtPool> = pools.into_iter().map(Into::into).collect();
    libvirt::host::pool_of_file(&pools, &file).map(|p| p.name.clone())
}

/// [`virt_snapshots_script`]'s output as `sbm_virt::snapshot::Snapshot`s.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_snapshots(raw: String) -> Result<Vec<Snapshot>, VirtFfiError> {
    Ok(libvirt::parse_snapshots(&raw)?.iter().map(libvirt::host::snapshot_of).collect())
}

/// [`virt_snap_chain_script`]'s output as `sbm_virt::snapshot::Chain`: each
/// layer named for the snapshot (`snapshots`, from [`virt_libvirt_snapshots`])
/// that left the disk on it, each disk's pool.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_chain(chain_raw: String, snapshots: Vec<Snapshot>, pools: Vec<LibvirtPoolRef>) -> Result<Chain, VirtFfiError> {
    let chain = snapshot::parse_snap_chain(&chain_raw)?;
    let pools: Vec<libvirt::VirtPool> = pools.into_iter().map(Into::into).collect();
    Ok(libvirt::host::chain_of(&chain, &snapshots, &pools))
}

pub struct VirtOverlay {
    pub target: String,
    pub path: String,
}

/// An external snapshot as one read of the chain decides it: why it cannot
/// be taken, or each disk's overlay.
pub struct VirtExternalSnapshot {
    pub refusal: Option<String>,
    pub overlays: Vec<VirtOverlay>,
}

/// The external snapshot `name` from [`virt_snap_chain_script`]'s output:
/// its overlays in `dir`, or none named without one (libvirt puts them
/// beside each disk).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_external_snapshot(chain_raw: String, name: String, dir: Option<String>) -> Result<VirtExternalSnapshot, VirtFfiError> {
    let chain = snapshot::parse_snap_chain(&chain_raw)?;
    if let Some(why) = snapshot::external_snapshot_refusal(&chain) {
        return Ok(VirtExternalSnapshot { refusal: Some(why), overlays: Vec::new() });
    }
    let overlays = libvirt::host::overlays(&chain, &name, dir.as_deref())
        .into_iter()
        .map(|(target, path)| VirtOverlay { target, path })
        .collect();
    Ok(VirtExternalSnapshot { refusal: None, overlays })
}

/// Why a name cannot be a new snapshot's (mirrors sbm_virt::snapshot::NameIssue).
pub enum SnapshotNameIssue {
    Empty,
    Invalid,
    Taken,
}

#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_name_issue(name: String, existing: Vec<String>) -> Option<SnapshotNameIssue> {
    use sbm_virt::snapshot::NameIssue;
    sbm_virt::snapshot::name_issue(&name, existing.iter().map(String::as_str)).map(|i| match i {
        NameIssue::Empty => SnapshotNameIssue::Empty,
        NameIssue::Invalid => SnapshotNameIssue::Invalid,
        NameIssue::Taken => SnapshotNameIssue::Taken,
    })
}

/// Where a snapshot may take memory from (mirrors sbm_virt::snapshot::Memory).
pub enum SnapshotMemoryKind {
    None,
    Optional,
    Always,
}

/// [`sbm_virt::snapshot::memory`] for a guest that is `lxc` or not, running
/// or paused (`active`), on a host whose internal snapshot of an active
/// guest always holds memory (`memory_required`).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_memory(lxc: bool, active: bool, memory_required: bool) -> SnapshotMemoryKind {
    use sbm_virt::model::{Capabilities, Guest, GuestKind, GuestState};
    let caps = Capabilities { snapshot_memory_required: memory_required, ..Default::default() };
    let guest = Guest {
        id: String::new(),
        name: String::new(),
        kind: if lxc { GuestKind::Lxc } else { GuestKind::Qemu },
        state: if active { GuestState::Running } else { GuestState::Stopped },
        state_reason: None,
        vmid: None,
        node: None,
        vcpu: None,
        mem_bytes: None,
        uptime: None,
        tags: Vec::new(),
        template: false,
        autostart: None,
        actions: Default::default(),
    };
    match sbm_virt::snapshot::memory(&caps, &guest) {
        sbm_virt::snapshot::Memory::None => SnapshotMemoryKind::None,
        sbm_virt::snapshot::Memory::Optional => SnapshotMemoryKind::Optional,
        sbm_virt::snapshot::Memory::Always => SnapshotMemoryKind::Always,
    }
}

/// The `virsh` actions that carry out `action` on a guest the last view read
/// with `state_reason` and `offered`; None when it does not offer it. A
/// crashed domain's start is a destroy first (sbm_virt::libvirt::host).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_power_plan(
    state_reason: Option<String>,
    offered: Vec<VirtActionKind>,
    action: VirtActionKind,
) -> Option<Vec<VirtActionKind>> {
    use sbm_virt::model::{Guest, GuestKind, GuestState, PowerAction};
    let model = |k: &VirtActionKind| match k {
        VirtActionKind::Start => PowerAction::Start,
        VirtActionKind::Shutdown => PowerAction::Shutdown,
        VirtActionKind::Reboot => PowerAction::Reboot,
        VirtActionKind::ForceStop => PowerAction::ForceStop,
        VirtActionKind::Suspend => PowerAction::Suspend,
        VirtActionKind::Resume => PowerAction::Resume,
    };
    let guest = Guest {
        id: String::new(),
        name: String::new(),
        kind: GuestKind::Qemu,
        state: GuestState::Unknown,
        state_reason,
        vmid: None,
        node: None,
        vcpu: None,
        mem_bytes: None,
        uptime: None,
        tags: Vec::new(),
        template: false,
        autostart: None,
        actions: offered.iter().map(model).collect(),
    };
    let plan = libvirt::host::power_plan(&guest, model(&action))?;
    Some(
        plan.into_iter()
            .map(|a| match a {
                libvirt::VirtAction::Start => VirtActionKind::Start,
                libvirt::VirtAction::Shutdown => VirtActionKind::Shutdown,
                libvirt::VirtAction::Reboot => VirtActionKind::Reboot,
                libvirt::VirtAction::ForceStop => VirtActionKind::ForceStop,
                libvirt::VirtAction::Suspend => VirtActionKind::Suspend,
                libvirt::VirtAction::Resume => VirtActionKind::Resume,
            })
            .collect(),
    )
}

/// Display and VNC password, for opening a graphical console
#[flutter_rust_bridge::frb(sync)]
pub fn virt_vnc_console_script(domain: String) -> String {
    libvirt::vnc_console_script(&domain)
}

/// [`virt_vnc_console_script`]'s output as `VirtVncConsoleInfo`. Holds
/// the password: never logged.
pub fn virt_libvirt_vnc_console(raw: String) -> Result<VirtVncConsoleInfo, VirtFfiError> {
    Ok(libvirt::parse_vnc_console(&raw)?)
}

/// [`virt_domain_detail_script`]'s output as `VirtDomainDetail`
pub fn virt_libvirt_domain_detail(raw: String) -> Result<VirtDomainDetail, VirtFfiError> {
    Ok(libvirt::parse_domain_detail(&raw)?)
}

/// [`virt_action_script`]'s output: `Ok` when virsh accepted the action
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_action(raw: String) -> Result<(), VirtFfiError> {
    Ok(libvirt::parse_action(&raw)?)
}

/// Every snapshot of one domain
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshots_script(domain: String) -> String {
    libvirt::snapshots_script(&domain)
}

/// An internal snapshot; with memory when the domain is active. Parse with
/// [`parse_virt_action`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_create_script(
    domain: String,
    name: String,
    description: Option<String>,
) -> String {
    libvirt::snapshot_create_script(&domain, &name, description.as_deref())
}

/// Revert to a snapshot; `running` starts the domain afterwards. Parse with
/// [`parse_virt_action`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_revert_script(domain: String, name: String, running: bool) -> String {
    libvirt::snapshot_revert_script(&domain, &name, running)
}

/// Delete one snapshot, then the files libvirt leaves behind
/// ([`parse_virt_snap_delete_leftovers`]) through their `pools`. Parse with
/// [`parse_virt_snapshot_delete`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_delete_script(
    domain: String,
    name: String,
    pools: Vec<String>,
    leftovers: Vec<String>,
) -> Result<String, VirtFfiError> {
    Ok(libvirt::snapshot_delete_script(&domain, &name, &pools, &leftovers)?)
}

/// [`virt_snapshot_delete_script`]'s output: `Ok` once the snapshot is gone;
/// a file it left that could not be deleted is an error naming it
pub fn parse_virt_snapshot_delete(raw: String) -> Result<(), VirtFfiError> {
    Ok(libvirt::parse_snapshot_delete(&raw)?)
}

/// The disk chain of a domain (external snapshots): the definition, where
/// each device is now, and each one's chain as QEMU resolves it
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snap_chain_script(domain: String) -> String {
    snapshot::snap_chain_script(&domain)
}

/// [`virt_snap_chain_script`]'s output checked: the error it reports, if any.
pub fn virt_snap_chain_check(raw: String) -> Result<(), VirtFfiError> {
    snapshot::parse_snap_chain(&raw)?;
    Ok(())
}

/// What deciding whether the host would refuse deleting or reverting to
/// snapshot `name` needs: its layers, the chain, the security model and the
/// AppArmor profile's `deny` lines. Parse with
/// [`parse_virt_snap_delete_refusal`] or [`parse_virt_snap_revert_refusal`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snap_check_script(domain: String, name: String) -> String {
    snapshot::snap_check_script(&domain, &name)
}

/// [`virt_snap_check_script`]'s output → why the host would refuse the
/// delete (AppArmor denying the commit), or `None`
pub fn parse_virt_snap_delete_refusal(raw: String) -> Result<Option<String>, VirtFfiError> {
    Ok(snapshot::snap_delete_refusal(&raw)?)
}

/// [`virt_snap_check_script`]'s output → the files deleting the snapshot
/// leaves behind (its overlays off the current chain), for
/// [`virt_snapshot_delete_script`] to delete
pub fn parse_virt_snap_delete_leftovers(raw: String) -> Result<Vec<String>, VirtFfiError> {
    Ok(snapshot::snap_delete_leftovers(&raw)?)
}

/// [`virt_snap_check_script`]'s output → why a revert would leave the guest
/// unable to start (AppArmor's helper refused the new overlay), or `None`
pub fn parse_virt_snap_revert_refusal(raw: String) -> Result<Option<String>, VirtFfiError> {
    Ok(snapshot::snap_revert_refusal(&raw)?)
}

/// An external snapshot (disks only, `--atomic`), `overlays` being
/// `(target, path)` per disk. Parse with [`parse_virt_action`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_external_script(
    domain: String,
    name: String,
    description: Option<String>,
    overlays: Vec<(String, String)>,
) -> String {
    snapshot::snapshot_external_script(&domain, &name, description.as_deref(), &overlays)
}

/// A snapshot's configuration and the guest's current one. Parse with
/// [`virt_libvirt_snap_diff`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snap_diff_script(domain: String, name: String) -> String {
    snapshot::snap_diff_script(&domain, &name)
}

/// [`virt_snap_diff_script`]'s output as `Vec<VirtSnapDiff>`
pub fn virt_libvirt_snap_diff(raw: String) -> Result<Vec<Diff>, VirtFfiError> {
    Ok(snapshot::parse_snap_diff(&raw)?.iter().map(libvirt::host::diff_of).collect())
}

/// Pools, volume names and every domain's disks
#[flutter_rust_bridge::frb(sync)]
pub fn virt_storage_script() -> String {
    libvirt::storage_script()
}

/// [`virt_storage_script`]'s output as `VirtStorage`
pub fn virt_libvirt_storage(raw: String) -> Result<VirtStorage, VirtFfiError> {
    Ok(libvirt::parse_storage(&raw)?)
}

/// What each of `names` in `pool` is: format and sizes. Read with
/// [`super::resource::virt_libvirt_volumes`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_volumes_script(pool: String, names: Vec<String>) -> String {
    libvirt::volumes_script(&pool, &names)
}

/// Networks, DHCP leases and every domain's interfaces. Read with
/// [`super::resource::virt_libvirt_networks`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_networks_script() -> String {
    libvirt::networks_script()
}

/// An existing network's edit or restart
/// ([`super::resource::virt_libvirt_resource_script`], `net`): `Ok` once the
/// definition (and, when asked for, the running network) has the change
pub fn parse_virt_net_change(raw: String) -> Result<(), VirtFfiError> {
    Ok(net::parse_net_change(&raw)?)
}

/// What the host can run a new domain as (`domcapabilities`)
#[flutter_rust_bridge::frb(sync)]
pub fn virt_create_host_script() -> String {
    libvirt::create_host_script()
}

/// [`virt_create_host_script`]'s output as `VirtCreateHost`
pub fn virt_libvirt_create_host(raw: String) -> Result<VirtCreateHost, VirtFfiError> {
    Ok(libvirt::parse_create_host(&raw)?)
}

/// A new domain's disk (empty, or a copy of a cloud image) and its
/// cloud-init seed
#[flutter_rust_bridge::frb(sync)]
pub fn virt_create_volume_script(spec: VirtCreateSpec) -> Result<String, VirtFfiError> {
    Ok(libvirt::create_volume_script(&spec)?)
}

/// [`virt_create_volume_script`]'s output as `VirtCreateVolumes` (the
/// disk's and the seed's paths)
pub fn virt_libvirt_create_volumes(raw: String) -> Result<VirtCreateVolumes, VirtFfiError> {
    Ok(libvirt::parse_create_volumes(&raw)?)
}

/// `$6$<salt>$…`: a cloud-init password as SHA-512 crypt, so only the hash
/// ever leaves the app. `salt` is up to 16 of `./0-9A-Za-z`, drawn from a
/// secure source by the caller. Synchronous: the password is at most
/// `PASSWORD_MAX` (1 KiB) bytes, which bounds the hashing to milliseconds;
/// a longer one is refused.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_hash_password(password: String, salt: String) -> Result<String, VirtFfiError> {
    Ok(sbm_virt::libvirt::cloud_init::sha512_crypt(&password, &salt)?)
}

/// A clone's disks, each copied or made empty in
/// its source's pool
#[flutter_rust_bridge::frb(sync)]
pub fn virt_clone_volumes_script(spec: VirtCloneSpec) -> Result<String, VirtFfiError> {
    Ok(libvirt::clone_volumes_script(&spec)?)
}

/// [`virt_clone_volumes_script`]'s output: the new volumes' paths, in order
pub fn parse_virt_clone_volumes(raw: String) -> Result<Vec<String>, VirtFfiError> {
    Ok(libvirt::parse_clone_volumes(&raw)?)
}

/// Defines the clone of `base_xml` called `name` on `disks`
/// (`[[target, path], ...]`); parse with [`virt_libvirt_define_result`]
#[flutter_rust_bridge::frb(sync)]
pub fn virt_clone_define_script(
    base_xml: String,
    name: String,
    disks: Vec<(String, String)>,
) -> Result<String, VirtFfiError> {
    Ok(libvirt::clone_define_script(&base_xml, &name, &disks)?)
}

/// Defines (and optionally starts) the domain on that disk
#[flutter_rust_bridge::frb(sync)]
pub fn virt_define_script(spec: VirtCreateSpec) -> Result<String, VirtFfiError> {
    Ok(libvirt::define_script(&spec)?)
}

/// [`virt_define_script`]'s output as `VirtCreated`
pub fn virt_libvirt_define_result(raw: String) -> Result<VirtCreated, VirtFfiError> {
    Ok(libvirt::parse_create(&raw)?)
}

/// `undefine`, with the volumes of the disk targets in `storage` (none keeps
/// them all), and the domain's own cloud-init `seed` and the `chain` files
/// its external snapshots left (after refreshing `pools`) after it. Parse
/// with [`parse_virt_undefine`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_undefine_script(
    domain: String,
    storage: Vec<String>,
    seed: Option<String>,
    pools: Vec<String>,
    chain: Vec<String>,
) -> Result<String, VirtFfiError> {
    Ok(libvirt::undefine_script(&domain, &storage, seed.as_deref(), &pools, &chain)?)
}

/// [`virt_undefine_script`]'s output: `Ok` once the domain (and its seed)
/// are gone
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_undefine(raw: String) -> Result<(), VirtFfiError> {
    Ok(libvirt::parse_undefine(&raw)?)
}

/// A domain's cloud-init seed at `seed` (its path, as the domain's metadata
/// names it), read back from its volume. Parse with
/// [`virt_libvirt_seed_read`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_seed_read_script(seed: String) -> Result<String, VirtFfiError> {
    Ok(sbm_virt::libvirt::cloud_init::seed_read_script(&seed)?)
}

/// [`virt_seed_read_script`]'s output as `VirtSeedRead`: what the seed
/// says (its password as the hash in it), whether it holds more than the
/// app writes, and its revision
pub fn virt_libvirt_seed_read(raw: String) -> Result<VirtSeedRead, VirtFfiError> {
    Ok(sbm_virt::libvirt::cloud_init::parse_seed_read(&raw)?)
}

/// The seed at `seed` rewritten in place from `cloud_init`, made from the read of `revision`; `tools` narrows the
/// ISO tools tried (none: all, in their order). Parse with
/// [`parse_virt_seed_update`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_seed_update_script(
    seed: String,
    revision: String,
    cloud_init: VirtCloudInit,
    tools: Option<Vec<String>>,
) -> Result<String, VirtFfiError> {
    use sbm_virt::libvirt::cloud_init as ci;
    let c = cloud_init;
    // Checked by the script builder itself.
    let tools: Vec<&str> = match &tools {
        Some(t) => t.iter().map(String::as_str).collect(),
        None => ci::SEED_TOOLS.to_vec(),
    };
    Ok(ci::seed_update_script(&seed, &revision, &c, &tools)?)
}

/// [`virt_seed_update_script`]'s output: `Ok` once the new seed is in
/// place; `Conflict` when the seed changed since it was read
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_seed_update(raw: String) -> Result<(), VirtFfiError> {
    Ok(sbm_virt::libvirt::cloud_init::parse_seed_update(&raw)?)
}

/// A domain's hardware, persistent and running, in one round trip
#[flutter_rust_bridge::frb(sync)]
pub fn virt_hardware_script(domain: String) -> String {
    libvirt::hardware_script(&domain)
}

/// [`virt_hardware_script`]'s output as `VirtHardwareInfo`
pub fn virt_libvirt_hardware_read(raw: String) -> Result<VirtHardwareInfo, VirtFfiError> {
    Ok(libvirt::parse_hardware(&raw)?)
}

/// One hardware change; `base_xml` the
/// persistent definition it was made from. Parse with
/// [`virt_libvirt_hardware_outcome`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_hardware_change_script(
    domain: String,
    running: bool,
    base_xml: Option<String>,
    change: VirtHwChange,
) -> Result<String, VirtFfiError> {
    Ok(libvirt::hardware_change_script(&domain, running, base_xml.as_deref(), &change)?)
}

/// [`virt_hardware_change_script`]'s output as `VirtHwOutcome`
pub fn virt_libvirt_hardware_outcome(raw: String) -> Result<VirtHwOutcome, VirtFfiError> {
    Ok(libvirt::parse_hardware_change(&raw)?)
}

/// Which pool types the daemon has a backend for (`pool-capabilities`).
/// Parse with [`parse_virt_pool_types`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_pool_types_script() -> String {
    libvirt::pool_types_script()
}

/// [`virt_pool_types_script`]'s output → the pool types this app makes that
/// the host supports, in the order offered; `None` where it could not say
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_pool_types(raw: String) -> Option<Vec<String>> {
    libvirt::parse_pool_types(&raw)
}

/// The host's firmware descriptors (`/usr/share/qemu/firmware/*.json`), for
/// what a new domain can boot with. Parse with
/// [`virt_libvirt_firmware`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_firmware_script() -> String {
    libvirt::firmware_script()
}

/// [`virt_firmware_script`]'s output as `Vec<FirmwareDescriptor>`
pub fn virt_libvirt_firmware(raw: String) -> Vec<FirmwareDescriptor> {
    libvirt::parse_firmware_descriptors(&raw)
}

/// The host's USB and PCI devices, for passing one to a guest
#[flutter_rust_bridge::frb(sync)]
pub fn virt_host_devices_script() -> String {
    libvirt::host_devices_script()
}

/// [`virt_host_devices_script`]'s output as `VirtHostDevices`
pub fn virt_libvirt_host_devices_read(raw: String) -> Result<VirtHostDevices, VirtFfiError> {
    Ok(libvirt::parse_host_devices(&raw)?)
}

/// One change to the host's storage or networks. Parse with [`parse_virt_resource`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_resource_script(op: VirtResourceOp) -> Result<String, VirtFfiError> {
    Ok(manage::resource_script(&op)?)
}

/// [`virt_resource_script`]'s output: `Ok` when every step ran
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_resource(raw: String) -> Result<(), VirtFfiError> {
    Ok(manage::parse_resource(&raw)?)
}

/// The command writing its stdin into a volume, for a channel that carries
/// bytes; see `sbm_virt::libvirt::manage::vol_upload_command` for what goes
/// on stdin, in which order
#[flutter_rust_bridge::frb(sync)]
pub fn virt_vol_upload_command(
    pool: String,
    name: String,
    entry: SudoEntry,
) -> Result<String, VirtFfiError> {
    Ok(manage::vol_upload_command(&pool, &name, entry)?)
}

/// [`virt_vol_upload_command`]'s output: `true` uploaded, `false` stopped
/// before virsh because the first line was not the go line
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_vol_upload(raw: String) -> Result<bool, VirtFfiError> {
    Ok(manage::parse_vol_upload(&raw)?)
}

/// The line sent before an upload's bytes
#[flutter_rust_bridge::frb(sync)]
pub fn virt_upload_go_line() -> String {
    manage::UPLOAD_GO.to_string()
}

/// What the upload command prints once the bytes may follow
#[flutter_rust_bridge::frb(sync)]
pub fn virt_upload_ready_marker() -> String {
    manage::UPLOAD_READY.to_string()
}
