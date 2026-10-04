//! What a virtualization host is, for either backend: its nodes, its guests,
//! what each guest offers and what the host supports.
//!
//! Ported from the app's `lib/data/model/virt/virt.dart`. Both backends build
//! these — [`crate::pve`] from the PVE API, [`crate::libvirt::host`] from
//! `virsh` — so the agent's panel and the app show one model. Serialized with
//! serde's snake_case, the agent's wire format.

use std::collections::{BTreeMap, BTreeSet};

use serde::{Deserialize, Serialize};

/// Which kind of hypervisor manager a host is reached as.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HostKind {
    /// Proxmox VE, through its HTTP API (`/api2/json`).
    Pve,
    /// libvirt, through `virsh` run on the server.
    Libvirt,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GuestKind {
    Qemu,
    Lxc,
}

impl GuestKind {
    /// The kind's name in PVE paths (`/nodes/{node}/qemu/{vmid}`).
    pub fn as_str(self) -> &'static str {
        match self {
            GuestKind::Qemu => "qemu",
            GuestKind::Lxc => "lxc",
        }
    }
}

/// A guest's state as the Virtualization view shows it.
///
/// Mapped from PVE's `status` + `lock` ([`crate::pve::resources::state_of`])
/// and from libvirt's state + reason ([`crate::libvirt::host::guest_of`]).
/// [`GuestState::Rebooting`] is never reported by either: it is what a guest
/// reads as while a client has a reboot in flight.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum GuestState {
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

impl GuestState {
    /// The wire name, which is also each backend's own word for the state
    /// where they share one (`running`, `stopped`, `paused`).
    pub fn as_str(self) -> &'static str {
        use GuestState::*;
        match self {
            Running => "running",
            Paused => "paused",
            Stopped => "stopped",
            Starting => "starting",
            Stopping => "stopping",
            Rebooting => "rebooting",
            Migrating => "migrating",
            Backup => "backup",
            Unknown => "unknown",
        }
    }

    /// Something is running: the guest holds CPU and memory on the host.
    pub fn is_active(self) -> bool {
        use GuestState::*;
        matches!(self, Running | Paused | Starting | Stopping | Rebooting | Migrating)
    }

    /// In the middle of a change; a view shows progress rather than actions.
    pub fn is_transient(self) -> bool {
        use GuestState::*;
        matches!(self, Starting | Stopping | Rebooting | Migrating | Backup)
    }
}

/// Power actions. Which of them a guest offers is [`Guest::actions`], decided
/// by the backend from its state and the host's [`Capabilities`].
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PowerAction {
    Start,
    /// ACPI shutdown request; the guest may ignore it.
    Shutdown,
    /// ACPI reboot request.
    Reboot,
    /// Stops the guest at once, like pulling the plug (PVE `stop`, libvirt
    /// `destroy`).
    ForceStop,
    /// Pauses the vCPUs; memory stays allocated.
    Suspend,
    Resume,
}

impl PowerAction {
    /// Loses the guest's unsaved state, so a client asks more insistently.
    pub fn destructive(self) -> bool {
        self == PowerAction::ForceStop
    }

    /// The state a guest reads as while this action is in flight.
    pub fn transient_state(self) -> GuestState {
        match self {
            PowerAction::Start | PowerAction::Resume => GuestState::Starting,
            PowerAction::Shutdown | PowerAction::ForceStop | PowerAction::Suspend => GuestState::Stopping,
            PowerAction::Reboot => GuestState::Rebooting,
        }
    }

    /// What a guest in `state` offers.
    ///
    /// `pause` is whether suspend and resume exist for this guest at all (the
    /// host's [`Capabilities::pause`], and not PVE containers). `resumable`
    /// false is a paused guest that `resume` does not wake — libvirt's
    /// `pmsuspended`, which needs `dompmwakeup`. A guest in the middle of a
    /// transition can still be force-stopped, which is the way out of a
    /// shutdown the guest ignores; one held by a backup or a migration offers
    /// nothing.
    pub fn offered(state: GuestState, pause: bool, resumable: bool) -> BTreeSet<PowerAction> {
        use PowerAction::*;
        let mut set = BTreeSet::new();
        match state {
            GuestState::Running => {
                set.extend([Shutdown, Reboot, ForceStop]);
                if pause {
                    set.insert(Suspend);
                }
            }
            GuestState::Paused => {
                if pause && resumable {
                    set.insert(Resume);
                }
                set.insert(ForceStop);
            }
            GuestState::Stopped => {
                set.insert(Start);
            }
            GuestState::Starting | GuestState::Stopping | GuestState::Rebooting => {
                set.insert(ForceStop);
            }
            GuestState::Migrating | GuestState::Backup | GuestState::Unknown => {}
        }
        set
    }
}

/// One machine of a host: a PVE cluster node, or the libvirt host itself.
///
/// Every figure is optional: libvirt's overview does not read the host's own
/// CPU and memory (the server's status has them), and PVE omits them for an
/// offline node.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Node {
    pub name: String,
    pub online: bool,
    /// Fraction of [`Node::max_cpu`] in use, 0..1.
    pub cpu: Option<f64>,
    pub max_cpu: Option<u32>,
    pub mem_used: Option<u64>,
    pub mem_total: Option<u64>,
    /// Seconds.
    pub uptime: Option<u64>,
}

/// A virtualization host: one server, and what manages its guests.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Host {
    pub kind: HostKind,
    /// PVE's release (`8.2`), or libvirt's library version (`10.0.0`).
    pub version: Option<String>,
    /// The hypervisor as the host names it, e.g. `QEMU 8.2.2`. libvirt only.
    pub hypervisor: Option<String>,
    pub nodes: Vec<Node>,
}

/// One VM or container.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Guest {
    /// Stable within the host: PVE `qemu/100`, libvirt the domain's UUID.
    pub id: String,
    pub name: String,
    pub kind: GuestKind,
    pub state: GuestState,
    /// The raw detail behind [`Guest::state`], for display and for decisions
    /// the state alone cannot make: PVE's `lock` (`backup`, `snapshot`, ...)
    /// or QEMU status (`prelaunch`, `io-error`), libvirt's reason (`crashed`,
    /// `pmsuspended`, `user`, ...). None when there is nothing to add.
    pub state_reason: Option<String>,
    /// PVE's numeric id.
    pub vmid: Option<u32>,
    /// The PVE node the guest is on.
    pub node: Option<String>,
    pub vcpu: Option<u32>,
    /// Memory assigned to the guest, bytes.
    pub mem_bytes: Option<u64>,
    /// Seconds.
    pub uptime: Option<u64>,
    pub tags: Vec<String>,
    /// A PVE template: not a guest that runs, and offers no actions.
    pub template: bool,
    /// Starts with the host (libvirt autostart; PVE's `onboot` is not in the
    /// resource list and is left None).
    pub autostart: Option<bool>,
    /// The power actions this guest offers now.
    pub actions: BTreeSet<PowerAction>,
}

/// One reading of a guest's usage. Throughputs are rates, bytes per second.
///
/// None means "not measured": a stopped guest, a first sample with nothing
/// to diff against, a counter the host does not report. Never read as zero.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Stats {
    /// Unix milliseconds.
    pub at: i64,
    /// Percent of the guest's own vCPUs, 0..100.
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

/// What a client can do with a host. A view shows or hides by these, never by
/// [`HostKind`].
///
/// They describe what is supported, not the hypervisor's abilities in
/// general. Field meanings are the app's `VirtCapabilities`.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(default)]
pub struct Capabilities {
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

/// What one load of a host yields.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct HostView {
    pub host: Host,
    pub guests: Vec<Guest>,
    /// By [`Guest::id`]. A guest missing here has nothing measured yet.
    pub stats: BTreeMap<String, Stats>,
    pub capabilities: Capabilities,
}

/// The consoles a guest offers.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ConsoleKind {
    /// PVE `termproxy` (a container's shell, a VM's serial port), or
    /// libvirt's `virsh console` on the serial device.
    Text,
    /// VNC.
    Vnc,
}

/// A disk, CD drive or container volume.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Disk {
    /// `disk`, `cdrom`, `floppy`, `lun`; PVE containers: `rootfs`, `mp`.
    pub device: String,
    /// libvirt's source kind (`file`, `block`, `network`, `volume`).
    pub source_type: Option<String>,
    /// Path, `pool/volume`, PVE `storage:volume`; None for an empty drive.
    pub source: Option<String>,
    /// libvirt target (`vda`) or PVE key (`scsi0`, `rootfs`, `mp0`).
    pub target: Option<String>,
    pub bus: Option<String>,
    pub format: Option<String>,
    pub readonly: bool,
    /// Bytes, where the configuration says (PVE `size=`).
    pub size: Option<u64>,
}

/// A network interface.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Nic {
    /// libvirt `network`/`bridge`/`direct`/...; PVE `net0`, `net1`, ...
    pub kind: String,
    pub mac: Option<String>,
    /// Network, bridge or host device.
    pub source: Option<String>,
    /// NIC model (`virtio`, `e1000e`), or `veth` for a container.
    pub model: Option<String>,
    /// Host-side device while running (libvirt `vnetN`), or a container's
    /// interface name (`eth0`).
    pub target: Option<String>,
}

/// A graphics device in the guest's configuration.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Graphics {
    /// `vnc`, `spice`, ...; PVE's `vga` type (`std`, `qxl`, `serial0`).
    pub kind: String,
    pub port: Option<u16>,
    pub tls_port: Option<u16>,
    pub autoport: bool,
    pub listen: Option<String>,
    pub socket: Option<String>,
}

/// Where a running libvirt guest's display listens (`virsh domdisplay`).
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Display {
    pub uri: String,
    pub protocol: String,
    /// On the hypervisor's side; `localhost` is the hypervisor itself.
    pub host: Option<String>,
    pub port: Option<u16>,
    pub tls_port: Option<u16>,
    pub socket: Option<String>,
}

/// A guest's disks, NICs, display and the consoles it opens.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct GuestDetail {
    pub disks: Vec<Disk>,
    pub nics: Vec<Nic>,
    pub graphics: Vec<Graphics>,
    /// libvirt, while running with graphics.
    pub display: Option<Display>,
    pub consoles: BTreeSet<ConsoleKind>,
    pub description: Option<String>,
    pub arch: Option<String>,
    /// libvirt machine type, or PVE `ostype`.
    pub machine: Option<String>,
}

/// How far back a stored history reaches, in PVE `rrddata` terms.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HistoryWindow {
    Hour,
    Day,
    Week,
}

impl HistoryWindow {
    pub fn as_str(self) -> &'static str {
        match self {
            HistoryWindow::Hour => "hour",
            HistoryWindow::Day => "day",
            HistoryWindow::Week => "week",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use PowerAction::*;

    fn set(actions: &[PowerAction]) -> BTreeSet<PowerAction> {
        actions.iter().copied().collect()
    }

    #[test]
    fn offered_by_state() {
        assert_eq!(
            PowerAction::offered(GuestState::Running, true, true),
            set(&[Shutdown, Reboot, ForceStop, Suspend])
        );
        assert_eq!(PowerAction::offered(GuestState::Running, false, true), set(&[Shutdown, Reboot, ForceStop]));
        assert_eq!(PowerAction::offered(GuestState::Paused, true, true), set(&[Resume, ForceStop]));
        // pmsuspended: paused, and resume does not wake it
        assert_eq!(PowerAction::offered(GuestState::Paused, true, false), set(&[ForceStop]));
        assert_eq!(PowerAction::offered(GuestState::Stopped, true, true), set(&[Start]));
        for s in [GuestState::Starting, GuestState::Stopping, GuestState::Rebooting] {
            assert_eq!(PowerAction::offered(s, true, true), set(&[ForceStop]), "{s:?}");
        }
        for s in [GuestState::Migrating, GuestState::Backup, GuestState::Unknown] {
            assert!(PowerAction::offered(s, true, true).is_empty(), "{s:?}");
        }
    }

    #[test]
    fn transient_states() {
        assert_eq!(Start.transient_state(), GuestState::Starting);
        assert_eq!(Resume.transient_state(), GuestState::Starting);
        assert_eq!(Suspend.transient_state(), GuestState::Stopping);
        assert_eq!(Reboot.transient_state(), GuestState::Rebooting);
        assert!(ForceStop.destructive() && !Shutdown.destructive());
        assert!(GuestState::Paused.is_active() && !GuestState::Paused.is_transient());
        assert!(GuestState::Backup.is_transient() && !GuestState::Backup.is_active());
    }

    #[test]
    fn wire_names_are_snake_case() {
        assert_eq!(serde_json::to_value(ForceStop).unwrap(), "force_stop");
        assert_eq!(serde_json::to_value(HostKind::Libvirt).unwrap(), "libvirt");
        assert_eq!(serde_json::to_value(GuestState::Rebooting).unwrap(), "rebooting");
    }
}
