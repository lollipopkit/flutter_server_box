//! libvirt command layer FFI (sbm_parser::virt)
//!
//! Scripts are POSIX `sh` for `ServerExec.run(script, entry: 'sh')` (or the
//! sudo entry of `PrivilegedExec`). Parsed results cross as `sbm_parser`'s
//! serde JSON, like `parse_status_json`, so the monitor can serve the same
//! shape later; a failure crosses as [`VirtFfiError`], whose `kind` is what
//! the app branches on (retry with sudo on `PermissionDenied`).

use sbm_parser::{virt, virt_manage};

/// Power actions (mirrors sbm_parser::virt::VirtAction)
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

impl From<VirtActionKind> for virt::VirtAction {
    fn from(kind: VirtActionKind) -> Self {
        match kind {
            VirtActionKind::Start => virt::VirtAction::Start,
            VirtActionKind::Shutdown => virt::VirtAction::Shutdown,
            VirtActionKind::Reboot => virt::VirtAction::Reboot,
            VirtActionKind::ForceStop => virt::VirtAction::ForceStop,
            VirtActionKind::Suspend => virt::VirtAction::Suspend,
            VirtActionKind::Resume => virt::VirtAction::Resume,
        }
    }
}

/// Classes of [`VirtFfiError`] (mirrors sbm_parser::virt::VirtError)
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

impl From<virt::VirtError> for VirtFfiError {
    fn from(e: virt::VirtError) -> Self {
        use virt::VirtError as E;
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
    virt::probe_script()
}

/// Guest list, state, and raw counters in one round trip
#[flutter_rust_bridge::frb(sync)]
pub fn virt_overview_script() -> String {
    virt::overview_script()
}

/// Display URI and XML for one domain (`domain`: UUID preferred, or name)
#[flutter_rust_bridge::frb(sync)]
pub fn virt_domain_detail_script(domain: String) -> String {
    virt::domain_detail_script(&domain)
}

/// One power action on one domain
#[flutter_rust_bridge::frb(sync)]
pub fn virt_action_script(action: VirtActionKind, domain: String) -> String {
    virt::action_script(action.into(), &domain)
}

/// Command line for an interactive serial console in a terminal session
#[flutter_rust_bridge::frb(sync)]
pub fn virt_console_command(domain: String) -> String {
    virt::console_command(&domain)
}

/// [`virt_probe_script`]'s output → `VirtHostProbe` JSON
pub fn parse_virt_probe_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_probe(&raw)?).map_err(json_err)
}

/// [`virt_overview_script`]'s output → `VirtOverview` JSON
pub fn parse_virt_overview_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_overview(&raw)?).map_err(json_err)
}

/// Display and VNC password, for opening a graphical console
#[flutter_rust_bridge::frb(sync)]
pub fn virt_vnc_console_script(domain: String) -> String {
    virt::vnc_console_script(&domain)
}

/// [`virt_vnc_console_script`]'s output → `VirtVncConsoleInfo` JSON. Holds
/// the password: never logged.
pub fn parse_virt_vnc_console_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_vnc_console(&raw)?).map_err(json_err)
}

/// [`virt_domain_detail_script`]'s output → `VirtDomainDetail` JSON
pub fn parse_virt_domain_detail_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_domain_detail(&raw)?).map_err(json_err)
}

/// [`virt_action_script`]'s output: `Ok` when virsh accepted the action
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_action(raw: String) -> Result<(), VirtFfiError> {
    Ok(virt::parse_action(&raw)?)
}

/// Every snapshot of one domain
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshots_script(domain: String) -> String {
    virt::snapshots_script(&domain)
}

/// [`virt_snapshots_script`]'s output → `Vec<VirtSnapshotInfo>` JSON
pub fn parse_virt_snapshots_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_snapshots(&raw)?).map_err(json_err)
}

/// An internal snapshot; with memory when the domain is active. Parse with
/// [`parse_virt_action`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_create_script(
    domain: String,
    name: String,
    description: Option<String>,
) -> String {
    virt::snapshot_create_script(&domain, &name, description.as_deref())
}

/// Revert to a snapshot; `running` starts the domain afterwards. Parse with
/// [`parse_virt_action`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_revert_script(domain: String, name: String, running: bool) -> String {
    virt::snapshot_revert_script(&domain, &name, running)
}

/// Delete one snapshot. Parse with [`parse_virt_action`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_snapshot_delete_script(domain: String, name: String) -> String {
    virt::snapshot_delete_script(&domain, &name)
}

/// Pools, volume names and every domain's disks
#[flutter_rust_bridge::frb(sync)]
pub fn virt_storage_script() -> String {
    virt::storage_script()
}

/// [`virt_storage_script`]'s output → `VirtStorage` JSON
pub fn parse_virt_storage_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_storage(&raw)?).map_err(json_err)
}

/// What each of `names` in `pool` is: format and sizes
#[flutter_rust_bridge::frb(sync)]
pub fn virt_volumes_script(pool: String, names: Vec<String>) -> String {
    virt::volumes_script(&pool, &names)
}

/// [`virt_volumes_script`]'s output → `Vec<VirtVolume>` JSON
pub fn parse_virt_volumes_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_volumes(&raw)?).map_err(json_err)
}

/// Networks, DHCP leases and every domain's interfaces
#[flutter_rust_bridge::frb(sync)]
pub fn virt_networks_script() -> String {
    virt::networks_script()
}

/// [`virt_networks_script`]'s output → `VirtNetworks` JSON
pub fn parse_virt_networks_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_networks(&raw)?).map_err(json_err)
}

fn spec_of(json: &str) -> Result<virt::VirtCreateSpec, VirtFfiError> {
    serde_json::from_str(json).map_err(json_err)
}

/// What the host can run a new domain as (`domcapabilities`)
#[flutter_rust_bridge::frb(sync)]
pub fn virt_create_host_script() -> String {
    virt::create_host_script()
}

/// [`virt_create_host_script`]'s output → `VirtCreateHost` JSON
pub fn parse_virt_create_host_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_create_host(&raw)?).map_err(json_err)
}

/// A new domain's disk (empty, or a copy of a cloud image) and its
/// cloud-init seed; `spec_json` is a `VirtCreateSpec`
#[flutter_rust_bridge::frb(sync)]
pub fn virt_create_volume_script(spec_json: String) -> Result<String, VirtFfiError> {
    Ok(virt::create_volume_script(&spec_of(&spec_json)?)?)
}

/// [`virt_create_volume_script`]'s output → `VirtCreateVolumes` JSON (the
/// disk's and the seed's paths)
pub fn parse_virt_create_volumes_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_create_volumes(&raw)?).map_err(json_err)
}

/// `$6$<salt>$…`: a cloud-init password as SHA-512 crypt, so only the hash
/// ever leaves the app. `salt` is up to 16 of `./0-9A-Za-z`, drawn from a
/// secure source by the caller.
#[flutter_rust_bridge::frb(sync)]
pub fn virt_hash_password(password: String, salt: String) -> Result<String, VirtFfiError> {
    Ok(sbm_parser::virt_cloud_init::sha512_crypt(&password, &salt)?)
}

/// A clone's disks (`VirtCloneSpec` JSON), each copied or made empty in
/// its source's pool
#[flutter_rust_bridge::frb(sync)]
pub fn virt_clone_volumes_script(spec_json: String) -> Result<String, VirtFfiError> {
    let spec: virt::VirtCloneSpec = serde_json::from_str(&spec_json).map_err(json_err)?;
    Ok(virt::clone_volumes_script(&spec)?)
}

/// [`virt_clone_volumes_script`]'s output: the new volumes' paths, in order
pub fn parse_virt_clone_volumes(raw: String) -> Result<Vec<String>, VirtFfiError> {
    Ok(virt::parse_clone_volumes(&raw)?)
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
    Ok(virt::clone_define_script(&base_xml, &name, &disks)?)
}

/// Defines (and optionally starts) the domain on that disk
#[flutter_rust_bridge::frb(sync)]
pub fn virt_define_script(spec_json: String) -> Result<String, VirtFfiError> {
    Ok(virt::define_script(&spec_of(&spec_json)?)?)
}

/// [`virt_define_script`]'s output → `VirtCreated` JSON
pub fn parse_virt_create_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_create(&raw)?).map_err(json_err)
}

/// `undefine`, with the volumes of the disk targets in `storage` (none keeps
/// them all), and the domain's own cloud-init `seed` after it. Parse with
/// [`parse_virt_undefine`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_undefine_script(
    domain: String,
    storage: Vec<String>,
    seed: Option<String>,
) -> Result<String, VirtFfiError> {
    Ok(virt::undefine_script(&domain, &storage, seed.as_deref())?)
}

/// [`virt_undefine_script`]'s output: `Ok` once the domain (and its seed)
/// are gone
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_undefine(raw: String) -> Result<(), VirtFfiError> {
    Ok(virt::parse_undefine(&raw)?)
}

/// A domain's hardware, persistent and running, in one round trip
#[flutter_rust_bridge::frb(sync)]
pub fn virt_hardware_script(domain: String) -> String {
    virt::hardware_script(&domain)
}

/// [`virt_hardware_script`]'s output → `VirtHardwareInfo` JSON
pub fn parse_virt_hardware_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_hardware(&raw)?).map_err(json_err)
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
    let change: virt::VirtHwChange = serde_json::from_str(&change_json).map_err(json_err)?;
    Ok(virt::hardware_change_script(&domain, running, base_xml.as_deref(), &change)?)
}

/// [`virt_hardware_change_script`]'s output → `VirtHwOutcome` JSON
pub fn parse_virt_hardware_change_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_hardware_change(&raw)?).map_err(json_err)
}

/// The host's USB and PCI devices, for passing one to a guest
#[flutter_rust_bridge::frb(sync)]
pub fn virt_host_devices_script() -> String {
    virt::host_devices_script()
}

/// [`virt_host_devices_script`]'s output → `VirtHostDevices` JSON
pub fn parse_virt_host_devices_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_host_devices(&raw)?).map_err(json_err)
}

/// How the upload command reaches the daemon (mirrors
/// sbm_parser::virt_manage::VirtUploadEntry)
pub enum VirtUploadEntryKind {
    /// As this account
    Direct,
    /// `sudo -n`
    SudoNoPassword,
    /// `sudo -S`, the password first on stdin
    SudoPassword,
}

impl From<VirtUploadEntryKind> for virt_manage::VirtUploadEntry {
    fn from(kind: VirtUploadEntryKind) -> Self {
        match kind {
            VirtUploadEntryKind::Direct => virt_manage::VirtUploadEntry::Direct,
            VirtUploadEntryKind::SudoNoPassword => virt_manage::VirtUploadEntry::SudoNoPassword,
            VirtUploadEntryKind::SudoPassword => virt_manage::VirtUploadEntry::SudoPassword,
        }
    }
}

/// One change to the host's storage or networks; `op_json` is a
/// `VirtResourceOp`. Parse with [`parse_virt_resource`].
#[flutter_rust_bridge::frb(sync)]
pub fn virt_resource_script(op_json: String) -> Result<String, VirtFfiError> {
    let op: virt_manage::VirtResourceOp = serde_json::from_str(&op_json).map_err(json_err)?;
    Ok(virt_manage::resource_script(&op)?)
}

/// [`virt_resource_script`]'s output: `Ok` when every step ran
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_resource(raw: String) -> Result<(), VirtFfiError> {
    Ok(virt_manage::parse_resource(&raw)?)
}

/// The command writing its stdin into a volume, for a channel that carries
/// bytes; see `sbm_parser::virt_manage::vol_upload_command` for what goes
/// on stdin, in which order
#[flutter_rust_bridge::frb(sync)]
pub fn virt_vol_upload_command(
    pool: String,
    name: String,
    entry: VirtUploadEntryKind,
) -> Result<String, VirtFfiError> {
    Ok(virt_manage::vol_upload_command(&pool, &name, entry.into())?)
}

/// [`virt_vol_upload_command`]'s output: `true` uploaded, `false` stopped
/// before virsh because the first line was not the go line
#[flutter_rust_bridge::frb(sync)]
pub fn parse_virt_vol_upload(raw: String) -> Result<bool, VirtFfiError> {
    Ok(virt_manage::parse_vol_upload(&raw)?)
}

/// The line sent before an upload's bytes
#[flutter_rust_bridge::frb(sync)]
pub fn virt_upload_go_line() -> String {
    virt_manage::UPLOAD_GO.to_string()
}

/// What the upload command prints once the bytes may follow
#[flutter_rust_bridge::frb(sync)]
pub fn virt_upload_ready_marker() -> String {
    virt_manage::UPLOAD_READY.to_string()
}
