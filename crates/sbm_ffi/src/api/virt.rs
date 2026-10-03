//! libvirt command layer FFI (sbm_virt::libvirt)
//!
//! Scripts are POSIX `sh` for `ServerExec.run(script, entry: 'sh')` (or the
//! sudo entry of `PrivilegedExec`). Parsed results cross as `sbm_virt`'s
//! serde JSON, like `parse_status_json`, so the monitor can serve the same
//! shape later; a failure crosses as [`VirtFfiError`], whose `kind` is what
//! the app branches on (retry with sudo on `PermissionDenied`).

use sbm_virt::libvirt::{self, manage, net, snapshot};

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

fn json_err(e: serde_json::Error) -> VirtFfiError {
    VirtFfiError {
        kind: VirtErrorKind::Malformed,
        message: e.to_string(),
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

/// [`virt_probe_script`]'s output → `VirtHostProbe` JSON
pub fn parse_virt_probe_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_probe(&raw)?).map_err(json_err)
}

/// [`virt_overview_script`]'s output → `VirtOverview` JSON
pub fn parse_virt_overview_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_overview(&raw)?).map_err(json_err)
}

/// The overview read into one host view (`sbm_virt::model::HostView` JSON),
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
    pub fn view(&mut self, raw: String, at_ms: i64, pool_types: Option<Vec<String>>, upload: bool) -> Result<String, VirtFfiError> {
        let overview = libvirt::parse_overview(&raw)?;
        let view = libvirt::host::view_of(&overview, &mut self.0, at_ms, pool_types.as_deref(), upload);
        serde_json::to_string(&view).map_err(json_err)
    }

    /// Forgets every guest's counters: the next view has no rates.
    #[flutter_rust_bridge::frb(sync)]
    pub fn clear(&mut self) {
        self.0.clear();
    }
}

/// [`virt_domain_detail_script`]'s output read into
/// `sbm_virt::model::GuestDetail` JSON (sbm_virt::libvirt::host).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_guest_detail(raw: String) -> Result<String, VirtFfiError> {
    let detail = libvirt::parse_domain_detail(&raw)?;
    serde_json::to_string(&libvirt::host::detail_of(&detail)).map_err(json_err)
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

/// [`virt_snapshots_script`]'s output as `sbm_virt::snapshot::Snapshot`
/// JSON.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_snapshots(raw: String) -> Result<String, VirtFfiError> {
    let list: Vec<_> = libvirt::parse_snapshots(&raw)?.iter().map(libvirt::host::snapshot_of).collect();
    serde_json::to_string(&list).map_err(json_err)
}

/// [`virt_snap_chain_script`]'s output as `sbm_virt::snapshot::Chain` JSON:
/// each layer named for the snapshot (`snapshots_json`, from
/// [`virt_libvirt_snapshots`]) that left the disk on it, each disk's pool.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_chain(chain_raw: String, snapshots_json: String, pools: Vec<LibvirtPoolRef>) -> Result<String, VirtFfiError> {
    let chain = snapshot::parse_snap_chain(&chain_raw)?;
    let snaps: Vec<sbm_virt::snapshot::Snapshot> = serde_json::from_str(&snapshots_json).map_err(json_err)?;
    let pools: Vec<libvirt::VirtPool> = pools.into_iter().map(Into::into).collect();
    serde_json::to_string(&libvirt::host::chain_of(&chain, &snaps, &pools)).map_err(json_err)
}

pub struct VirtOverlay {
    pub target: String,
    pub path: String,
}

/// Where an external snapshot `name` puts each disk's overlay in `dir`; none
/// without one (libvirt names them beside each disk).
#[flutter_rust_bridge::frb(sync)]
pub fn virt_libvirt_overlays(chain_raw: String, name: String, dir: Option<String>) -> Result<Vec<VirtOverlay>, VirtFfiError> {
    let chain = snapshot::parse_snap_chain(&chain_raw)?;
    Ok(libvirt::host::overlays(&chain, &name, dir.as_deref())
        .into_iter()
        .map(|(target, path)| VirtOverlay { target, path })
        .collect())
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

/// [`virt_vnc_console_script`]'s output → `VirtVncConsoleInfo` JSON. Holds
/// the password: never logged.
pub fn parse_virt_vnc_console_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_vnc_console(&raw)?).map_err(json_err)
}

/// [`virt_domain_detail_script`]'s output → `VirtDomainDetail` JSON
pub fn parse_virt_domain_detail_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_domain_detail(&raw)?).map_err(json_err)
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

/// [`virt_snapshots_script`]'s output → `Vec<VirtSnapshotInfo>` JSON
pub fn parse_virt_snapshots_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_snapshots(&raw)?).map_err(json_err)
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

/// [`virt_snap_chain_script`]'s output → `VirtSnapChain` JSON
pub fn parse_virt_snap_chain_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&snapshot::parse_snap_chain(&raw)?).map_err(json_err)
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
/// [`parse_virt_snap_diff_json`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snap_diff_script(domain: String, name: String) -> String {
    snapshot::snap_diff_script(&domain, &name)
}

/// [`virt_snap_diff_script`]'s output → `Vec<VirtSnapDiff>` JSON
pub fn parse_virt_snap_diff_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&snapshot::parse_snap_diff(&raw)?).map_err(json_err)
}

/// Why an external snapshot cannot be taken, from a `VirtSnapChain` JSON
#[flutter_rust_bridge::frb(sync)]
pub fn virt_external_snapshot_refusal(chain_json: String) -> Result<Option<String>, VirtFfiError> {
    let chain: snapshot::VirtSnapChain =
        serde_json::from_str(&chain_json).map_err(json_err)?;
    Ok(snapshot::external_snapshot_refusal(&chain))
}

/// Why no snapshot at all can be taken, from a `VirtSnapChain` JSON
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_refusal(chain_json: String) -> Result<Option<String>, VirtFfiError> {
    let chain: snapshot::VirtSnapChain =
        serde_json::from_str(&chain_json).map_err(json_err)?;
    Ok(snapshot::snapshot_refusal(&chain))
}

/// Pools, volume names and every domain's disks
#[flutter_rust_bridge::frb(sync)]
pub fn virt_storage_script() -> String {
    libvirt::storage_script()
}

/// [`virt_storage_script`]'s output → `VirtStorage` JSON
pub fn parse_virt_storage_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_storage(&raw)?).map_err(json_err)
}

/// What each of `names` in `pool` is: format and sizes
#[flutter_rust_bridge::frb(sync)]
pub fn virt_volumes_script(pool: String, names: Vec<String>) -> String {
    libvirt::volumes_script(&pool, &names)
}

/// [`virt_volumes_script`]'s output → `Vec<VirtVolume>` JSON
pub fn parse_virt_volumes_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_volumes(&raw)?).map_err(json_err)
}

/// Networks, DHCP leases and every domain's interfaces
#[flutter_rust_bridge::frb(sync)]
pub fn virt_networks_script() -> String {
    libvirt::networks_script()
}

/// [`virt_networks_script`]'s output → `VirtNetworks` JSON
pub fn parse_virt_networks_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_networks(&raw)?).map_err(json_err)
}

/// Editing an existing network (phase 10): `op_json` is a
/// `sbm_virt::libvirt::net::VirtNetOp`. Parse with [`parse_virt_net_change`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_net_change_script(op_json: String) -> Result<String, VirtFfiError> {
    let op: net::VirtNetOp = serde_json::from_str(&op_json).map_err(json_err)?;
    Ok(net::net_change_script(&op)?)
}

/// [`virt_net_change_script`]'s output: `Ok` once the definition (and, when
/// asked for, the running network) has the change
pub fn parse_virt_net_change(raw: String) -> Result<(), VirtFfiError> {
    Ok(net::parse_net_change(&raw)?)
}

fn spec_of(json: &str) -> Result<libvirt::VirtCreateSpec, VirtFfiError> {
    serde_json::from_str(json).map_err(json_err)
}

/// What the host can run a new domain as (`domcapabilities`)
#[flutter_rust_bridge::frb(sync)]
pub fn virt_create_host_script() -> String {
    libvirt::create_host_script()
}

/// [`virt_create_host_script`]'s output → `VirtCreateHost` JSON
pub fn parse_virt_create_host_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_create_host(&raw)?).map_err(json_err)
}

/// A new domain's disk (empty, or a copy of a cloud image) and its
/// cloud-init seed; `spec_json` is a `VirtCreateSpec`
#[flutter_rust_bridge::frb(sync)]
pub fn virt_create_volume_script(spec_json: String) -> Result<String, VirtFfiError> {
    Ok(libvirt::create_volume_script(&spec_of(&spec_json)?)?)
}

/// [`virt_create_volume_script`]'s output → `VirtCreateVolumes` JSON (the
/// disk's and the seed's paths)
pub fn parse_virt_create_volumes_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_create_volumes(&raw)?).map_err(json_err)
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

/// A clone's disks (`VirtCloneSpec` JSON), each copied or made empty in
/// its source's pool
#[flutter_rust_bridge::frb(sync)]
pub fn virt_clone_volumes_script(spec_json: String) -> Result<String, VirtFfiError> {
    let spec: libvirt::VirtCloneSpec = serde_json::from_str(&spec_json).map_err(json_err)?;
    Ok(libvirt::clone_volumes_script(&spec)?)
}

/// [`virt_clone_volumes_script`]'s output: the new volumes' paths, in order
pub fn parse_virt_clone_volumes(raw: String) -> Result<Vec<String>, VirtFfiError> {
    Ok(libvirt::parse_clone_volumes(&raw)?)
}

/// Defines the clone of `base_xml` called `name` on `disks_json`
/// (`[[target, path], ...]`); parse with [`parse_virt_create_json`]
#[flutter_rust_bridge::frb(sync)]
pub fn virt_clone_define_script(
    base_xml: String,
    name: String,
    disks_json: String,
) -> Result<String, VirtFfiError> {
    let disks: Vec<(String, String)> = serde_json::from_str(&disks_json).map_err(json_err)?;
    Ok(libvirt::clone_define_script(&base_xml, &name, &disks)?)
}

/// Defines (and optionally starts) the domain on that disk
#[flutter_rust_bridge::frb(sync)]
pub fn virt_define_script(spec_json: String) -> Result<String, VirtFfiError> {
    Ok(libvirt::define_script(&spec_of(&spec_json)?)?)
}

/// [`virt_define_script`]'s output → `VirtCreated` JSON
pub fn parse_virt_create_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_create(&raw)?).map_err(json_err)
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
/// [`parse_virt_seed_read_json`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_seed_read_script(seed: String) -> Result<String, VirtFfiError> {
    Ok(sbm_virt::libvirt::cloud_init::seed_read_script(&seed)?)
}

/// [`virt_seed_read_script`]'s output → `VirtSeedRead` JSON: what the seed
/// says (its password as the hash in it), whether it holds more than the
/// app writes, and its revision
pub fn parse_virt_seed_read_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&sbm_virt::libvirt::cloud_init::parse_seed_read(&raw)?).map_err(json_err)
}

/// The seed at `seed` rewritten in place from `cloud_init_json` (a
/// `VirtCloudInit`), made from the read of `revision`; `tools` narrows the
/// ISO tools tried (none: all, in their order). Parse with
/// [`parse_virt_seed_update`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_seed_update_script(
    seed: String,
    revision: String,
    cloud_init_json: String,
    tools: Option<Vec<String>>,
) -> Result<String, VirtFfiError> {
    use sbm_virt::libvirt::cloud_init as ci;
    let c: ci::VirtCloudInit = serde_json::from_str(&cloud_init_json).map_err(json_err)?;
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

/// [`virt_hardware_script`]'s output → `VirtHardwareInfo` JSON
pub fn parse_virt_hardware_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_hardware(&raw)?).map_err(json_err)
}

/// One hardware change; `change_json` is a `VirtHwChange`, `base_xml` the
/// persistent definition it was made from. Parse with
/// [`parse_virt_hardware_change_json`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_hardware_change_script(
    domain: String,
    running: bool,
    base_xml: Option<String>,
    change_json: String,
) -> Result<String, VirtFfiError> {
    let change: libvirt::VirtHwChange = serde_json::from_str(&change_json).map_err(json_err)?;
    Ok(libvirt::hardware_change_script(&domain, running, base_xml.as_deref(), &change)?)
}

/// [`virt_hardware_change_script`]'s output → `VirtHwOutcome` JSON
pub fn parse_virt_hardware_change_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_hardware_change(&raw)?).map_err(json_err)
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
/// [`parse_virt_firmware_json`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_firmware_script() -> String {
    libvirt::firmware_script()
}

/// [`virt_firmware_script`]'s output → `Vec<FirmwareDescriptor>` JSON
pub fn parse_virt_firmware_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_firmware_descriptors(&raw)).map_err(json_err)
}

/// The host's USB and PCI devices, for passing one to a guest
#[flutter_rust_bridge::frb(sync)]
pub fn virt_host_devices_script() -> String {
    libvirt::host_devices_script()
}

/// [`virt_host_devices_script`]'s output → `VirtHostDevices` JSON
pub fn parse_virt_host_devices_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&libvirt::parse_host_devices(&raw)?).map_err(json_err)
}

/// How the upload command reaches the daemon (mirrors
/// sbm_virt::libvirt::manage::VirtUploadEntry)
pub enum VirtUploadEntryKind {
    /// As this account
    Direct,
    /// `sudo -n`
    SudoNoPassword,
    /// `sudo -S`, the password first on stdin
    SudoPassword,
}

impl From<VirtUploadEntryKind> for manage::VirtUploadEntry {
    fn from(kind: VirtUploadEntryKind) -> Self {
        match kind {
            VirtUploadEntryKind::Direct => manage::VirtUploadEntry::Direct,
            VirtUploadEntryKind::SudoNoPassword => manage::VirtUploadEntry::SudoNoPassword,
            VirtUploadEntryKind::SudoPassword => manage::VirtUploadEntry::SudoPassword,
        }
    }
}

/// One change to the host's storage or networks; `op_json` is a
/// `VirtResourceOp`. Parse with [`parse_virt_resource`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_resource_script(op_json: String) -> Result<String, VirtFfiError> {
    let op: manage::VirtResourceOp = serde_json::from_str(&op_json).map_err(json_err)?;
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
    entry: VirtUploadEntryKind,
) -> Result<String, VirtFfiError> {
    Ok(manage::vol_upload_command(&pool, &name, entry.into())?)
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
