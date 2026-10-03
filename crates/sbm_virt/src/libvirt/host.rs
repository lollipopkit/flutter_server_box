//! A libvirt host as [`crate::model`] has it: the overview read into guests,
//! their usage and what the host supports.
//!
//! Pure, like the rest of [`crate::libvirt`]: the caller runs
//! [`super::overview_script`] (and [`super::pool_types_script`] once) and keeps
//! the [`RateTracker`] between loads. Ported from the app's `LibvirtBackend`
//! (`load`, `guestOf`, `sampleOf`).

use crate::error::{Error, ErrorKind};
use crate::libvirt::{POOL_TYPES, VirtAction, VirtDomain, VirtError, VirtOverview, VirtState};
use crate::model::{Capabilities, Guest, GuestKind, GuestState, Host, HostKind, HostView, PowerAction};
use crate::rates::{CounterSample, RateTracker};

/// libvirt's `VIR_DOMAIN_CRASHED`: stopped, with the QEMU process kept by
/// `on_crash=preserve`.
pub const STATE_CRASHED: i32 = 6;

/// libvirt's `VIR_DOMAIN_PMSUSPENDED`: paused, and not woken by `resume`.
pub const STATE_PMSUSPENDED: i32 = 7;

/// The host, its guests and their usage at `at` (Unix ms).
///
/// `pool_types` is [`super::parse_pool_types`]'s answer, None where it could
/// not say (every type is offered then). `upload` is whether the caller's
/// channel carries bytes for `vol-upload` (SSH, a local process), which a
/// monitor agent's `/exec` does not.
pub fn view_of(
    overview: &VirtOverview,
    rates: &mut RateTracker,
    at: i64,
    pool_types: Option<&[String]>,
    upload: bool,
) -> HostView {
    let mut guests = Vec::with_capacity(overview.domains.len());
    let mut stats = std::collections::BTreeMap::new();
    for d in &overview.domains {
        guests.push(guest_of(d));
        stats.insert(d.uuid.clone(), rates.add(&d.uuid, sample_of(d, at)));
    }
    rates.retain(overview.domains.iter().map(|d| d.uuid.as_str()));
    let version = overview.version.as_ref();
    let hypervisor = [
        version.and_then(|v| v.hypervisor.as_deref()),
        version.and_then(|v| v.hypervisor_version.as_deref()),
    ]
    .into_iter()
    .flatten()
    .collect::<Vec<_>>()
    .join(" ");
    HostView {
        host: Host {
            kind: HostKind::Libvirt,
            version: version.and_then(|v| v.libvirt.clone()),
            hypervisor: (!hypervisor.is_empty()).then_some(hypervisor),
            nodes: Vec::new(),
        },
        guests,
        stats,
        capabilities: capabilities(pool_types, upload),
    }
}

/// What this build does with a libvirt host.
pub fn capabilities(pool_types: Option<&[String]>, upload: bool) -> Capabilities {
    Capabilities {
        pause: true,
        snapshots: true,
        snapshot_memory_required: true,
        snapshot_external: true,
        storage: true,
        network: true,
        serial_console: true,
        vnc_console: true,
        create: true,
        delete_keeps_disks: true,
        hardware: true,
        hardware_revert_pending: true,
        clone: true,
        clone_target: true,
        storage_edit: true,
        pool_types: match pool_types {
            Some(types) => types.to_vec(),
            None => POOL_TYPES.iter().map(|t| (*t).to_owned()).collect(),
        },
        pool_autostart: true,
        pool_delete_storage: true,
        volume_resize: true,
        volume_clone: true,
        upload,
        network_edit: true,
        network_edit_existing: true,
        network_restart: true,
        network_modes: ["nat", "route", "isolated", "bridge"].map(str::to_owned).to_vec(),
        network_start: true,
        ..Capabilities::default()
    }
}

/// One overview domain as a guest.
///
/// Two libvirt states read differently from what [`GuestState`] alone says:
/// `pmsuspended` is paused but not woken by `resume`, so resume is not
/// offered; `crashed` is stopped, with the QEMU process kept, so
/// [`power_plan`] destroys it before starting and force stop is offered.
pub fn guest_of(d: &VirtDomain) -> Guest {
    let state = match d.state {
        VirtState::Running => GuestState::Running,
        VirtState::Paused => GuestState::Paused,
        VirtState::Stopped => GuestState::Stopped,
        VirtState::Starting => GuestState::Starting,
        VirtState::Stopping => GuestState::Stopping,
        VirtState::Unknown => GuestState::Unknown,
    };
    let pm_suspended = d.state_code == STATE_PMSUSPENDED;
    let crashed = d.state_code == STATE_CRASHED;
    // Migration holds a domain paused with reason `migration` (2) on the
    // source.
    let migrating = d.state_code == 3 && d.reason_code == 2;
    let shown = if migrating { GuestState::Migrating } else { state };
    let mut actions = PowerAction::offered(shown, true, !pm_suspended);
    if crashed {
        actions.insert(PowerAction::ForceStop);
    }
    let state_reason = if pm_suspended {
        Some("pmsuspended".to_owned())
    } else if crashed {
        Some("crashed".to_owned())
    } else if d.reason == "unknown" {
        None
    } else {
        Some(d.reason.clone())
    };
    Guest {
        id: d.uuid.clone(),
        name: d.name.clone(),
        kind: GuestKind::Qemu,
        state: shown,
        state_reason,
        vmid: None,
        node: None,
        vcpu: d.vcpu_current.or(d.vcpu_max),
        mem_bytes: kib(d.mem_max_kib.or(d.mem_current_kib)),
        uptime: None,
        tags: Vec::new(),
        template: false,
        autostart: Some(d.autostart),
        actions,
    }
}

/// One overview domain's counters, for the [`RateTracker`].
pub fn sample_of(d: &VirtDomain, at: i64) -> CounterSample {
    let c = &d.counters;
    fn sum(values: impl Iterator<Item = Option<u64>>) -> Option<u64> {
        values.flatten().reduce(|a, b| a + b)
    }
    // Used memory as the guest sees it, when its balloon driver reports;
    // otherwise what the QEMU process holds on the host.
    let used = match (c.balloon_available_kib, c.balloon_unused_kib) {
        (Some(available), Some(unused)) => Some(available.saturating_sub(unused)),
        _ => c.balloon_rss_kib,
    };
    let disks = || c.blocks.iter().filter(|b| b.capacity.is_some());
    CounterSample {
        at,
        cpu_time_ns: c.cpu_time_ns,
        cpu_percent: None,
        vcpus: d.vcpu_current.or(d.vcpu_max),
        mem_used: kib(used),
        mem_total: kib(c.balloon_available_kib.or(d.mem_current_kib).or(d.mem_max_kib)),
        disk_used: sum(disks().map(|b| b.allocation)),
        disk_total: sum(disks().map(|b| b.capacity)),
        disk_read: sum(c.blocks.iter().map(|b| b.rd_bytes)),
        disk_write: sum(c.blocks.iter().map(|b| b.wr_bytes)),
        net_in: sum(c.nets.iter().map(|n| n.rx_bytes)),
        net_out: sum(c.nets.iter().map(|n| n.tx_bytes)),
    }
}

/// The `virsh` actions that carry out `action` on `guest`, in order, or None
/// when the guest does not offer it.
///
/// A crashed domain's start is a `destroy` first: its process is still
/// there, and `start` refuses a domain that has one. That `destroy` failing
/// with [`super::VirtError::InvalidState`] means it is already gone, and the
/// start goes on.
pub fn power_plan(guest: &Guest, action: PowerAction) -> Option<Vec<VirtAction>> {
    if !guest.actions.contains(&action) {
        return None;
    }
    let virsh = virsh_action(action);
    let crashed = guest.state_reason.as_deref() == Some("crashed");
    Some(if action == PowerAction::Start && crashed {
        vec![VirtAction::ForceStop, virsh]
    } else {
        vec![virsh]
    })
}

pub fn virsh_action(action: PowerAction) -> VirtAction {
    match action {
        PowerAction::Start => VirtAction::Start,
        PowerAction::Shutdown => VirtAction::Shutdown,
        PowerAction::Reboot => VirtAction::Reboot,
        PowerAction::ForceStop => VirtAction::ForceStop,
        PowerAction::Suspend => VirtAction::Suspend,
        PowerAction::Resume => VirtAction::Resume,
    }
}

fn kib(v: Option<u64>) -> Option<u64> {
    v.map(|k| k * 1024)
}

/// A `virsh` failure as the shared error. `action` marks a call that changes
/// something, whose refusal in the host's words is [`ErrorKind::ActionFailed`].
pub fn error_of(e: &VirtError, action: bool) -> Error {
    let refused = if action { ErrorKind::ActionFailed } else { ErrorKind::Unknown };
    let (kind, message) = match e {
        VirtError::NotInstalled => (ErrorKind::NotInstalled, None),
        VirtError::PermissionDenied { message } => (ErrorKind::PermissionDenied, Some(message)),
        VirtError::ConnectFailed { message } => (ErrorKind::Unreachable, Some(message)),
        VirtError::Malformed { message } => (ErrorKind::InvalidResponse, Some(message)),
        VirtError::Conflict { message } => (ErrorKind::Conflict, Some(message)),
        // `exists` too: a snapshot name taken is the action refused, with the
        // host's words. Creating a guest tells it apart itself.
        VirtError::DomainNotFound { message }
        | VirtError::InvalidState { message }
        | VirtError::Exists { message }
        | VirtError::Command { message } => (refused, Some(message)),
    };
    let mut err = Error::new(kind);
    err.message = message.filter(|m| !m.is_empty()).cloned();
    err
}

/// What a script run through `sudo` came to, when sudo itself refused: no
/// password and one is needed, or the one given was wrong. None when sudo
/// let the script run.
pub fn sudo_refusal(stderr: &str, had_password: bool) -> Option<Error> {
    if !sbm_parser::script::sudo_password_rejected(stderr) {
        return None;
    }
    Some(Error::new(if had_password { ErrorKind::SudoPasswordRejected } else { ErrorKind::SudoPasswordRequired }))
}
