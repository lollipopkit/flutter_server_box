//! libvirt command layer FFI (sbm_parser::virt)
//!
//! Scripts are POSIX `sh` for `ServerExec.run(script, entry: 'sh')` (or the
//! sudo entry of `PrivilegedExec`). Parsed results cross as `sbm_parser`'s
//! serde JSON, like `parse_status_json`, so the monitor can serve the same
//! shape later; a failure crosses as [`VirtFfiError`], whose `kind` is what
//! the app branches on (retry with sudo on `PermissionDenied`).

use sbm_parser::virt;

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

/// Host probe: `virsh` present and the daemon answering this user
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

/// [`virt_probe_script`]'s output → `VirtVersion` JSON
pub fn parse_virt_probe_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_probe(&raw)?).map_err(json_err)
}

/// [`virt_overview_script`]'s output → `VirtOverview` JSON
pub fn parse_virt_overview_json(raw: String) -> Result<String, VirtFfiError> {
    serde_json::to_string(&virt::parse_overview(&raw)?).map_err(json_err)
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
