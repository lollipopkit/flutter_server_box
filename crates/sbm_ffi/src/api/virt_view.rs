//! The virtualization views both backends read into (`sbm_virt::model`,
//! `sbm_virt::snapshot`): a host, its guests and their usage, one guest's
//! detail, its snapshots and the chain of its disks. The models are
//! `sbm_virt`'s own, mirrored; those holding a set or an ordered map — what
//! FRB carries no form of — cross in a type of this layer, the set as a list
//! in its order.

use flutter_rust_bridge::frb;
pub use sbm_virt::model::{Capabilities, ConsoleKind, Display, GuestKind, GuestState, Graphics, Host, HostKind, Nic, Node, PowerAction, Stats};
pub use sbm_virt::snapshot::{Chain, ChainDisk, ChainFile, Diff, DiffGroup, Snapshot, SnapshotLayer};
use sbm_virt::model;

// --- Mirrors -----------------------------------------------------------------

#[frb(mirror(HostKind))]
pub enum _HostKind {
    Pve,
    Libvirt,
}

#[frb(mirror(GuestKind))]
pub enum _GuestKind {
    Qemu,
    Lxc,
}

#[frb(mirror(GuestState))]
pub enum _GuestState {
    Running,
    Paused,
    Stopped,
    Starting,
    Stopping,
    Rebooting,
    Migrating,
    Backup,
    Unknown,
}

#[frb(mirror(PowerAction))]
pub enum _PowerAction {
    Start,
    Shutdown,
    Reboot,
    ForceStop,
    Suspend,
    Resume,
}

#[frb(mirror(Node))]
pub struct _Node {
    pub name: String,
    pub online: bool,
    pub cpu: Option<f64>,
    pub max_cpu: Option<u32>,
    pub mem_used: Option<u64>,
    pub mem_total: Option<u64>,
    pub uptime: Option<u64>,
}

#[frb(mirror(Host))]
pub struct _Host {
    pub kind: HostKind,
    pub version: Option<String>,
    pub hypervisor: Option<String>,
    pub nodes: Vec<Node>,
}

#[frb(mirror(Stats))]
pub struct _Stats {
    pub at: i64,
    pub cpu: Option<f64>,
    pub mem_used: Option<u64>,
    pub mem_total: Option<u64>,
    pub disk_used: Option<u64>,
    pub disk_total: Option<u64>,
    pub disk_read: Option<f64>,
    pub disk_write: Option<f64>,
    pub net_in: Option<f64>,
    pub net_out: Option<f64>,
}

#[frb(mirror(Capabilities))]
pub struct _Capabilities {
    pub lxc: bool,
    pub pause: bool,
    pub snapshots: bool,
    pub snapshot_memory_required: bool,
    pub snapshot_external: bool,
    pub snapshot_supported: bool,
    pub storage: bool,
    pub network: bool,
    pub backup: bool,
    pub clone: bool,
    pub linked_clone: bool,
    pub template: bool,
    pub clone_target: bool,
    pub backup_jobs: bool,
    pub cluster: bool,
    pub serial_console: bool,
    pub vnc_console: bool,
    pub term_console: bool,
    pub stored_history: bool,
    pub create: bool,
    pub delete_keeps_disks: bool,
    pub hardware: bool,
    pub hardware_revert: bool,
    pub hardware_revert_pending: bool,
    pub storage_edit: bool,
    pub pool_types: Vec<String>,
    pub pool_autostart: bool,
    pub pool_delete_storage: bool,
    pub volume_resize: bool,
    pub volume_clone: bool,
    pub upload: bool,
    pub network_edit: bool,
    pub network_modes: Vec<String>,
    pub network_start: bool,
    pub network_apply: bool,
    pub network_edit_existing: bool,
    pub network_restart: bool,
}

#[frb(mirror(ConsoleKind))]
pub enum _ConsoleKind {
    Text,
    Vnc,
}

#[frb(mirror(Nic))]
pub struct _Nic {
    pub kind: String,
    pub mac: Option<String>,
    pub source: Option<String>,
    pub model: Option<String>,
    pub target: Option<String>,
}

#[frb(mirror(Graphics))]
pub struct _Graphics {
    pub kind: String,
    pub port: Option<u16>,
    pub tls_port: Option<u16>,
    pub autoport: bool,
    pub listen: Option<String>,
    pub socket: Option<String>,
}

#[frb(mirror(Display))]
pub struct _Display {
    pub uri: String,
    pub protocol: String,
    pub host: Option<String>,
    pub port: Option<u16>,
    pub tls_port: Option<u16>,
    pub socket: Option<String>,
}

#[frb(mirror(Snapshot))]
pub struct _Snapshot {
    pub name: String,
    pub parent: Option<String>,
    pub description: Option<String>,
    pub created_at: Option<i64>,
    pub current: bool,
    pub with_memory: bool,
    pub external: bool,
    pub layers: Vec<SnapshotLayer>,
}

#[frb(mirror(SnapshotLayer))]
pub struct _SnapshotLayer {
    pub target: String,
    pub file: Option<String>,
    pub external: bool,
}

#[frb(mirror(ChainFile))]
pub struct _ChainFile {
    pub path: String,
    pub format: Option<String>,
    pub allocation: Option<u64>,
    pub backing: Option<String>,
    pub snap: Option<String>,
    pub active: bool,
}

#[frb(mirror(ChainDisk))]
pub struct _ChainDisk {
    pub target: String,
    pub files: Vec<ChainFile>,
    pub pool: Option<String>,
    pub error: Option<String>,
}

#[frb(mirror(Chain))]
pub struct _Chain {
    pub disks: Vec<ChainDisk>,
    pub refusal: Option<String>,
    pub external_refusal: Option<String>,
    pub pools: Vec<String>,
}

#[frb(mirror(DiffGroup))]
pub enum _DiffGroup {
    Cpu,
    Memory,
    Disks,
    Nics,
    Firmware,
    Boot,
    Other,
}

#[frb(mirror(Diff))]
pub struct _Diff {
    pub group: DiffGroup,
    pub key: String,
    pub before: Option<String>,
    pub after: Option<String>,
}

// --- Types of this layer -----------------------------------------------------

/// `sbm_virt::model::HostView`; each guest's usage beside it, by guest id.
pub struct VirtHostReport {
    pub host: Host,
    pub guests: Vec<VirtGuestReport>,
    pub stats: Vec<(String, Stats)>,
    pub capabilities: Capabilities,
}

/// `sbm_virt::model::Guest`; what may be done to it in its set's order.
pub struct VirtGuestReport {
    pub id: String,
    pub name: String,
    pub kind: GuestKind,
    pub state: GuestState,
    pub state_reason: Option<String>,
    pub vmid: Option<u32>,
    pub node: Option<String>,
    pub vcpu: Option<u32>,
    pub mem_bytes: Option<u64>,
    pub uptime: Option<u64>,
    pub tags: Vec<String>,
    pub template: bool,
    pub autostart: Option<bool>,
    pub actions: Vec<PowerAction>,
}

/// `sbm_virt::model::Disk`, under a name no other mirror has.
pub struct VirtDiskReport {
    pub device: String,
    pub source_type: Option<String>,
    pub source: Option<String>,
    pub target: Option<String>,
    pub bus: Option<String>,
    pub format: Option<String>,
    pub readonly: bool,
    pub size: Option<u64>,
}

/// `sbm_virt::model::GuestDetail`; its consoles in their set's order.
pub struct VirtGuestDetailReport {
    pub disks: Vec<VirtDiskReport>,
    pub nics: Vec<Nic>,
    pub graphics: Vec<Graphics>,
    pub display: Option<Display>,
    pub consoles: Vec<ConsoleKind>,
    pub description: Option<String>,
    pub arch: Option<String>,
    pub machine: Option<String>,
}

impl From<model::Guest> for VirtGuestReport {
    fn from(g: model::Guest) -> Self {
        VirtGuestReport {
            id: g.id,
            name: g.name,
            kind: g.kind,
            state: g.state,
            state_reason: g.state_reason,
            vmid: g.vmid,
            node: g.node,
            vcpu: g.vcpu,
            mem_bytes: g.mem_bytes,
            uptime: g.uptime,
            tags: g.tags,
            template: g.template,
            autostart: g.autostart,
            actions: g.actions.into_iter().collect(),
        }
    }
}

impl From<model::HostView> for VirtHostReport {
    fn from(v: model::HostView) -> Self {
        VirtHostReport {
            host: v.host,
            guests: v.guests.into_iter().map(Into::into).collect(),
            stats: v.stats.into_iter().collect(),
            capabilities: v.capabilities,
        }
    }
}

impl From<model::GuestDetail> for VirtGuestDetailReport {
    fn from(d: model::GuestDetail) -> Self {
        VirtGuestDetailReport {
            disks: d
                .disks
                .into_iter()
                .map(|k| VirtDiskReport {
                    device: k.device,
                    source_type: k.source_type,
                    source: k.source,
                    target: k.target,
                    bus: k.bus,
                    format: k.format,
                    readonly: k.readonly,
                    size: k.size,
                })
                .collect(),
            nics: d.nics,
            graphics: d.graphics,
            display: d.display,
            consoles: d.consoles.into_iter().collect(),
            description: d.description,
            arch: d.arch,
            machine: d.machine,
        }
    }
}

impl From<VirtGuestReport> for model::Guest {
    fn from(g: VirtGuestReport) -> Self {
        model::Guest {
            id: g.id,
            name: g.name,
            kind: g.kind,
            state: g.state,
            state_reason: g.state_reason,
            vmid: g.vmid,
            node: g.node,
            vcpu: g.vcpu,
            mem_bytes: g.mem_bytes,
            uptime: g.uptime,
            tags: g.tags,
            template: g.template,
            autostart: g.autostart,
            actions: g.actions.into_iter().collect(),
        }
    }
}
