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

/// A domain's detail as the model has it: the consoles are a serial device
/// (text) and a VNC display, configured or running.
pub fn detail_of(d: &crate::libvirt::VirtDomainDetail) -> crate::model::GuestDetail {
    use crate::model::{ConsoleKind, Disk, Display, Graphics, GuestDetail, Nic};
    let xml = &d.xml;
    let vnc = d.display.as_ref().is_some_and(|d| d.protocol == "vnc") || xml.graphics.iter().any(|g| g.kind == "vnc");
    let mut consoles = std::collections::BTreeSet::new();
    if xml.has_serial_console {
        consoles.insert(ConsoleKind::Text);
    }
    if vnc {
        consoles.insert(ConsoleKind::Vnc);
    }
    GuestDetail {
        disks: xml
            .disks
            .iter()
            .map(|x| Disk {
                device: x.device.clone(),
                source_type: x.source_type.clone(),
                source: x.source.clone(),
                target: x.target.clone(),
                bus: x.bus.clone(),
                format: x.format.clone(),
                readonly: x.readonly,
                size: None,
            })
            .collect(),
        nics: xml
            .nics
            .iter()
            .map(|n| Nic {
                kind: n.kind.clone(),
                mac: n.mac.clone(),
                source: n.source.clone(),
                model: n.model.clone(),
                target: n.target.clone(),
            })
            .collect(),
        graphics: xml
            .graphics
            .iter()
            .map(|g| Graphics {
                kind: g.kind.clone(),
                port: g.port,
                tls_port: g.tls_port,
                autoport: g.autoport,
                listen: g.listen.clone(),
                socket: g.socket.clone(),
            })
            .collect(),
        display: d.display.as_ref().map(|x| Display {
            uri: x.uri.clone(),
            protocol: x.protocol.clone(),
            host: x.host.clone(),
            port: x.port,
            tls_port: x.tls_port,
            socket: x.socket.clone(),
        }),
        consoles,
        description: xml.description.clone(),
        arch: xml.arch.clone(),
        machine: xml.machine.clone(),
    }
}

/// Where a running domain's VNC display is reached from the hypervisor, and
/// its password for this one connection. Never printed.
#[derive(Clone, PartialEq, Eq)]
pub struct VncTarget {
    pub host: String,
    pub port: u16,
    pub password: Option<String>,
    /// Whether the password could be read; false: the display may still ask
    /// for one nobody here could read.
    pub password_known: bool,
}

impl std::fmt::Debug for VncTarget {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "VncTarget({}:{})", self.host, self.port)
    }
}

/// [`super::parse_vnc_console`]'s answer as something to dial, or why not.
pub fn vnc_target(info: &crate::libvirt::VirtVncConsoleInfo, name: &str) -> Result<VncTarget, Error> {
    let Some(display) = &info.display else {
        return Err(Error::msg(ErrorKind::Unsupported, format!("No VNC display while {name} is not running")));
    };
    match (display.protocol.as_str(), display.port) {
        ("vnc", Some(port)) => Ok(VncTarget {
            host: dial_host(display.host.as_deref()),
            port,
            password: info.password.clone(),
            password_known: info.password_known,
        }),
        _ => Err(Error::msg(ErrorKind::Unsupported, format!("The display is {}, not a VNC port", display.uri))),
    }
}

/// A listen address as something to dial from the hypervisor: a wildcard is
/// the hypervisor itself.
pub fn dial_host(host: Option<&str>) -> String {
    match host {
        None | Some("" | "0.0.0.0" | "::" | "[::]") => "127.0.0.1".to_owned(),
        Some(h) => h.to_owned(),
    }
}

/// A snapshot as the model has it.
pub fn snapshot_of(s: &crate::libvirt::VirtSnapshotInfo) -> crate::snapshot::Snapshot {
    crate::snapshot::Snapshot {
        name: s.name.clone(),
        parent: s.parent.clone(),
        description: s.description.clone(),
        created_at: s.creation_time,
        current: s.current,
        with_memory: s.memory,
        external: s.external,
        layers: s
            .layers
            .iter()
            .map(|l| crate::snapshot::SnapshotLayer {
                target: l.target.clone(),
                file: l.file.clone(),
                external: l.snapshot.as_deref() == Some("external"),
            })
            .collect(),
    }
}

/// Pool types whose volumes are files in the pool's target directory. The
/// rest hold block devices or objects: a file written to their target is
/// not a volume of the pool.
const FILE_POOL_TYPES: &[&str] = &["dir", "fs", "netfs"];

fn is_file_pool(p: &crate::libvirt::VirtPool) -> bool {
    p.pool_type.as_deref().is_some_and(|t| FILE_POOL_TYPES.contains(&t))
        && p.target.as_deref().is_some_and(|t| t.starts_with('/'))
}

/// An active pool of files: where an overlay can go.
pub fn pool_holds_files(p: &crate::libvirt::VirtPool) -> bool {
    p.active && is_file_pool(p)
}

/// The pool of files whose directory holds `file` itself.
pub fn pool_of_file<'a>(pools: &'a [crate::libvirt::VirtPool], file: &str) -> Option<&'a crate::libvirt::VirtPool> {
    let at = file.rfind('/')?;
    // A file right under the root is in the pool whose target is `/`.
    let dir = if at == 0 { "/" } else { &file[..at] };
    pools.iter().find(|p| {
        is_file_pool(p) && {
            let t = p.target.as_deref().unwrap_or_default();
            (if t.len() > 1 { t.trim_end_matches('/') } else { t }) == dir
        }
    })
}

/// The disk chain as the model has it: each layer named for the snapshot
/// that left the guest on it, each disk's pool, and where an overlay can go.
///
/// A snapshot records the file it left a disk on; that file is what the
/// guest wrote to until the next snapshot moved it on. The topmost layer is
/// the one in use, the current external snapshot's.
pub fn chain_of(
    chain: &crate::libvirt::snapshot::VirtSnapChain,
    snapshots: &[crate::snapshot::Snapshot],
    pools: &[crate::libvirt::VirtPool],
) -> crate::snapshot::Chain {
    use crate::snapshot::{Chain, ChainDisk, ChainFile};
    let mut owner = std::collections::HashMap::new();
    for s in snapshots {
        for l in &s.layers {
            if let Some(f) = &l.file {
                owner.insert(f.clone(), s.name.clone());
            }
        }
    }
    if let Some(current) = snapshots.iter().find(|s| s.current && s.external) {
        for d in chain.disks_iter() {
            if let Some(top) = d.files.first() {
                owner.entry(top.path.clone()).or_insert_with(|| current.name.clone());
            }
        }
    }
    Chain {
        pools: pools.iter().filter(|p| pool_holds_files(p)).map(|p| p.name.clone()).collect(),
        disks: chain
            .disks_iter()
            .map(|d| ChainDisk {
                target: d.target.clone(),
                pool: d.files.first().and_then(|top| pool_of_file(pools, &top.path)).map(|p| p.name.clone()),
                error: d.error.clone(),
                files: d
                    .files
                    .iter()
                    .enumerate()
                    .map(|(i, f)| ChainFile {
                        path: f.path.clone(),
                        format: f.format.clone(),
                        allocation: f.allocation,
                        backing: f.backing.clone(),
                        snap: owner.get(&f.path).cloned(),
                        active: i == 0,
                    })
                    .collect(),
            })
            .collect(),
        refusal: crate::libvirt::snapshot::snapshot_refusal(chain),
        external_refusal: crate::libvirt::snapshot::external_snapshot_refusal(chain),
    }
}

/// The overlays an external snapshot named `name` puts each disk on, in the
/// pool directory `dir`. None picked: no `--diskspec` at all, and libvirt
/// names each `<disk>.<snapshot>` beside the disk it backs.
pub fn overlays(chain: &crate::libvirt::snapshot::VirtSnapChain, name: &str, dir: Option<&str>) -> Vec<(String, String)> {
    let Some(dir) = dir else { return Vec::new() };
    chain
        .disks_iter()
        .filter_map(|d| {
            let top = d.files.first()?;
            Some((d.target.clone(), crate::snapshot::overlay_path(&top.path, name, Some(dir))))
        })
        .collect()
}

// ---------------------------------------------------------------------------
// Storage and networks
// ---------------------------------------------------------------------------

/// A pool as [`crate::resource`] has it. An inactive pool reports 0 for
/// everything: unknown, not empty.
pub fn pool_of(p: &crate::libvirt::VirtPool) -> crate::resource::Pool {
    let known = p.active && p.capacity.is_some_and(|c| c > 0);
    crate::resource::Pool {
        id: p.name.clone(),
        name: p.name.clone(),
        node: None,
        pool_type: p.pool_type.clone().unwrap_or_default(),
        path: p.target.clone(),
        source: p.source.clone(),
        capacity: if known { p.capacity } else { None },
        used: if known { p.allocation } else { None },
        available: if known { p.available } else { None },
        active: p.active,
        autostart: Some(p.autostart),
        enabled: None,
        shared: None,
        content: Vec::new(),
        volume_count: p.volumes.as_ref().map(|v| v.len() as u64),
    }
}

/// A volume of `pool`, with the domains whose disks are it: by path, or a
/// `type='volume'` disk naming its pool and volume instead.
pub fn volume_of(v: &crate::libvirt::VirtVolume, pool: &str, disks: &[crate::libvirt::VirtDiskUse]) -> crate::resource::Volume {
    let uses = |d: &crate::libvirt::VirtDiskUse| match &d.source {
        None => false,
        Some(source) => {
            v.path.as_deref() == Some(source.as_str())
                || (d.kind == "volume" && (source == &format!("{pool}/{}", v.name) || source == &v.name))
        }
    };
    crate::resource::Volume {
        id: v.name.clone(),
        name: v.name.clone(),
        path: v.path.clone(),
        format: v.format.clone(),
        content: None,
        capacity: v.capacity,
        allocation: v.allocation,
        backing: v.backing.clone(),
        created_at: None,
        users: disks
            .iter()
            .filter(|d| uses(d))
            .map(|d| crate::resource::GuestRef { guest_id: Some(d.domain.clone()), device: Some(d.target.clone()), ..Default::default() })
            .collect(),
        backs: Vec::new(),
    }
}

/// `volumes` with what is made on each — the volumes in `every` (any active
/// pool's) whose backing file it is. A base image is attached to nothing,
/// and its clones may be in another pool.
pub fn with_backs(mut volumes: Vec<crate::resource::Volume>, every: &[crate::resource::Volume]) -> Vec<crate::resource::Volume> {
    for v in &mut volumes {
        let Some(path) = v.path.as_deref() else { continue };
        v.backs = every
            .iter()
            .filter(|o| o.backing.as_deref() == Some(path))
            .filter_map(|o| o.path.clone())
            .collect();
    }
    volumes
}

/// A network with the domains that have a NIC on it — by network name, or on
/// its bridge directly — and their addresses from its DHCP leases.
pub fn network_of(n: &crate::libvirt::VirtNetworkInfo, all: &crate::libvirt::VirtNetworks) -> crate::resource::Network {
    let on = |i: &crate::libvirt::VirtIfaceUse| match i.kind.as_str() {
        "network" => i.source.as_deref() == Some(n.name.as_str()),
        "bridge" => n.bridge.is_some() && i.source == n.bridge,
        _ => false,
    };
    crate::resource::Network {
        id: n.name.clone(),
        name: n.name.clone(),
        node: None,
        mode: n.mode.clone(),
        bridge: n.bridge.clone(),
        cidrs: n.ips.iter().map(|ip| ip.cidr.clone()).collect(),
        gateway: None,
        dhcp_ranges: n.ips.iter().flat_map(|ip| ip.dhcp_ranges.iter().cloned()).collect(),
        ports: n.forward_devs.clone(),
        vlan_aware: None,
        vlan_id: None,
        vlan_device: None,
        bond_mode: None,
        active: n.active,
        autostart: Some(n.autostart),
        comment: None,
        hosts: n.hosts.clone(),
        xml: n.xml.clone(),
        pending_restart: n.pending_restart,
        management_editable: true,
        users: all
            .ifaces
            .iter()
            .filter(|i| on(i))
            .map(|i| crate::resource::GuestRef {
                guest_id: Some(i.domain.clone()),
                vmid: None,
                device: i.interface.clone(),
                mac: i.mac.clone(),
                // The leases are every network's: one MAC can be on two
                // isolated networks with an address on each.
                ip: all
                    .leases
                    .iter()
                    .find(|l| l.network == n.name && i.mac.as_deref() == Some(l.mac.as_str()))
                    .map(|l| l.ip.clone()),
            })
            .collect(),
    }
}

/// What a change runs as on a libvirt host: one of the resource scripts, or
/// an existing network's edit ([`crate::libvirt::net`]), which rewrites the
/// definition and, when told to, restarts the network on it with the
/// rollback that keeps it up.
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(tag = "script", content = "op", rename_all = "snake_case")]
pub enum ResourceScript {
    Resource(crate::libvirt::manage::VirtResourceOp),
    Net(crate::libvirt::net::VirtNetOp),
}

impl ResourceScript {
    /// The script, or why it cannot be written.
    pub fn script(&self) -> Result<String, VirtError> {
        match self {
            ResourceScript::Resource(op) => crate::libvirt::manage::resource_script(op),
            ResourceScript::Net(op) => crate::libvirt::net::net_change_script(op),
        }
    }

    /// What the script printed, as the change made or the host's refusal.
    pub fn parse(&self, raw: &str) -> Result<(), VirtError> {
        match self {
            ResourceScript::Resource(_) => crate::libvirt::manage::parse_resource(raw),
            ResourceScript::Net(_) => crate::libvirt::net::parse_net_change(raw),
        }
    }
}

/// `change` as the script that makes it, checked first against `list` — the
/// host's pools, networks and the volumes of the pool it is to, read for
/// this change ([`crate::resource::issue`]).
pub fn resource_script(change: &crate::resource::Change, list: crate::resource::Listing<'_>) -> Result<ResourceScript, Error> {
    use crate::libvirt::manage::{VirtNetIpv4, VirtResourceOp as R};
    use crate::libvirt::net::{VirtNetEdit, VirtNetHost, VirtNetOp as N};
    use crate::resource::Change as C;
    if let Some(issue) = crate::resource::issue(change, HostKind::Libvirt, list) {
        return Err(crate::resource::refusal(issue));
    }
    let pool = || change.pool().and_then(|id| list.pools.iter().find(|p| p.id == id)).expect("checked");
    let volume = |id: &str| list.volumes.iter().find(|v| v.id == id).expect("checked");
    let network = || change.network().and_then(|id| list.networks.iter().find(|n| n.id == id)).expect("checked");
    let trimmed = |s: &Option<String>| s.as_deref().map(str::trim).filter(|s| !s.is_empty()).map(str::to_owned);
    let op = match change {
        C::PoolCreate { name, pool_type, source, target, autostart, .. } => R::PoolCreate {
            name: name.clone(),
            pool_type: pool_type.clone(),
            target: match pool_type.as_str() {
                "dir" => Some(source.clone()),
                "netfs" => target.clone(),
                _ => None,
            },
            source: (pool_type != "dir").then(|| source.clone()),
            autostart: *autostart,
        },
        C::PoolSetActive { active: true, .. } => R::PoolStart { name: pool().id.clone() },
        C::PoolSetActive { active: false, .. } => R::PoolStop { name: pool().id.clone() },
        C::PoolSetAutostart { on, .. } => R::PoolAutostart { name: pool().id.clone(), on: *on },
        C::PoolRefresh { .. } => R::PoolRefresh { name: pool().id.clone() },
        C::PoolDelete { delete_storage, .. } => {
            let p = pool();
            R::PoolDelete { name: p.id.clone(), active: p.active, delete_storage: *delete_storage }
        }
        C::VolumeCreate { name, gib, format, .. } => {
            R::VolCreate { pool: pool().id.clone(), name: name.clone(), bytes: gib << 30, format: format.clone() }
        }
        C::VolumeDelete { volume: v, .. } => R::VolDelete { pool: pool().id.clone(), name: volume(v).name.clone() },
        C::VolumeResize { volume: v, bytes, .. } => {
            R::VolResize { pool: pool().id.clone(), name: volume(v).name.clone(), bytes: *bytes }
        }
        C::VolumeClone { volume: v, name, .. } => {
            R::VolClone { pool: pool().id.clone(), name: volume(v).name.clone(), new_name: name.clone() }
        }
        C::NetworkCreate { name, mode, bridge, cidr, dhcp_start, dhcp_end, autostart, .. } => {
            let ipv4 = match trimmed(cidr) {
                Some(c) if mode != "bridge" => {
                    let (address, prefix) = c.split_once('/').unwrap_or((c.as_str(), ""));
                    Some(VirtNetIpv4 {
                        address: address.to_owned(),
                        prefix: prefix.parse().unwrap_or_default(),
                        dhcp_start: dhcp_start.clone(),
                        dhcp_end: dhcp_end.clone(),
                    })
                }
                _ => None,
            };
            R::NetCreate {
                name: name.clone(),
                mode: mode.clone(),
                bridge: if mode == "bridge" { trimmed(bridge) } else { None },
                ipv4,
                autostart: *autostart,
            }
        }
        C::NetworkSetActive { active: true, .. } => R::NetStart { name: network().id.clone() },
        C::NetworkSetActive { active: false, .. } => R::NetStop { name: network().id.clone() },
        C::NetworkSetAutostart { on, .. } => R::NetAutostart { name: network().id.clone(), on: *on },
        C::NetworkDelete { .. } => R::NetDelete { name: network().id.clone() },
        C::NetworkEdit { mode, bridge, address, prefix, dhcp_start, dhcp_end, hosts, restart, base_xml, .. } => {
            let n = network();
            return Ok(ResourceScript::Net(N::Edit {
                name: n.id.clone(),
                edit: VirtNetEdit {
                    mode: mode.clone(),
                    bridge: if mode == "bridge" { trimmed(bridge) } else { None },
                    address: trimmed(address),
                    prefix: *prefix,
                    dhcp_start: trimmed(dhcp_start),
                    dhcp_end: trimmed(dhcp_end),
                    hosts: hosts
                        .iter()
                        .map(|h| VirtNetHost {
                            mac: h.mac.to_ascii_lowercase(),
                            ip: h.ip.clone(),
                            name: h.name.clone().filter(|n| !n.is_empty()),
                        })
                        .collect(),
                },
                base_xml: base_xml.clone().unwrap_or_else(|| n.xml.clone()),
                active: n.active,
                restart: *restart,
                force_restart: false,
            }));
        }
        // Its own op: `net-destroy` then `net-start`, with no definition
        // written either way — what is to be restarted onto is already in it.
        C::NetworkRestart { base_xml, .. } => {
            let n = network();
            return Ok(ResourceScript::Net(N::Restart { name: n.id.clone(), base_xml: base_xml.clone().unwrap_or_else(|| n.xml.clone()) }));
        }
        // Refused by `issue` above: PVE's.
        C::NetworkEditBridge { .. } | C::NetworkApply { .. } | C::NetworkRevert { .. } => {
            return Err(crate::resource::refusal(crate::resource::Issue::Unsupported));
        }
    };
    Ok(ResourceScript::Resource(op))
}
