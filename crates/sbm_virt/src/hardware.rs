//! A guest's hardware and settings, for either backend: what the Hardware
//! and Settings views show and edit ([`Hardware`]), the changes a client
//! asks for ([`Change`]), the rules a change is checked by before anything
//! is sent ([`issue`]), a guest's cloud-init settings ([`CloudInitState`],
//! [`CloudInitEdit`]) and the host devices a guest can be given
//! ([`HostDevices`]).
//!
//! **The definition the next start gets**: every value has its pending
//! changes applied, so an edit starts from what was last saved rather than
//! from what the guest happens to run with. What the running guest has
//! instead is in [`Hardware::pending`].
//!
//! A change names a pool, a volume and a network by id; what the host lists
//! at the moment of the change is what it is checked against and made with.
//! It is made from the read whose [`Hardware::revision`] it carries, and
//! refused as [`ErrorKind::Conflict`] once the guest changed since.
//!
//! PVE: [`crate::pve::hardware`] (the configuration read) and
//! [`crate::pve::client::Client::change_hardware`]; libvirt:
//! [`crate::libvirt::hardware`]. Ported from the app's
//! `lib/data/model/virt/virt_hardware.dart`.

use serde::{Deserialize, Serialize};

use crate::create::{CloudInit, VolumeRef};
use crate::error::{Detail, Error, ErrorKind};
use crate::model::{GuestKind, HostKind};
use crate::resource::{Network, Pool, Volume};

fn yes() -> bool {
    true
}

/// A guest's hardware as the Hardware and Settings views edit it.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Hardware {
    pub kind: GuestKind,
    /// There is a running definition too: a change it cannot take waits for
    /// the next start, and shows in `pending` until then.
    pub running: bool,
    pub cpu: Cpu,
    pub memory: Memory,
    #[serde(default)]
    pub disks: Vec<HwDisk>,
    #[serde(default)]
    pub nics: Vec<HwNic>,
    /// Boot devices in order, by disk or NIC key. None where there is no
    /// order to set (a container).
    #[serde(default)]
    pub boot: Option<Vec<String>>,
    #[serde(default)]
    pub autostart: bool,
    /// A VM's `name` or a container's `hostname` on PVE, the domain's name
    /// on libvirt.
    #[serde(default)]
    pub name: Option<String>,
    /// The note kept with the guest; None for none.
    #[serde(default)]
    pub description: Option<String>,
    /// PVE's `protection`; None where the host has no such setting.
    #[serde(default)]
    pub protection: Option<bool>,
    /// The name can change while the guest runs: PVE's can (a container's
    /// waits for a restart), libvirt's `domrename` takes only a domain that
    /// is not running.
    #[serde(default = "yes")]
    pub rename_running: bool,
    #[serde(default)]
    pub pending: Vec<PendingField>,
    /// What an edit is made from, sent back with it: PVE's `digest`; on
    /// libvirt the SHA-256 of the persistent definition as read (which
    /// carries the display passwords, and so never leaves the host's side).
    #[serde(default)]
    pub revision: Option<String>,
    #[serde(default)]
    pub limits: Limits,
    /// PVE: the CPU models the node offers.
    #[serde(default)]
    pub cpu_types: Vec<String>,
    /// The configuration as the host writes it, for a view to show: `qm
    /// config`'s lines, the persistent XML without its secrets.
    #[serde(default)]
    pub config_text: Option<String>,
    /// None for a container, which has neither.
    #[serde(default)]
    pub firmware: Option<Firmware>,
    /// The console and video card; None for a container.
    #[serde(default)]
    pub display: Option<Display>,
    /// Host USB and PCI devices given to the guest, and its TPM.
    #[serde(default)]
    pub devices: Vec<HwDevice>,
    /// What this guest can be changed to, on this host.
    #[serde(default)]
    pub support: Support,
}

impl std::fmt::Debug for Hardware {
    /// Without the revision and the configuration: they reach logs.
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Hardware")
            .field("kind", &self.kind)
            .field("name", &self.name)
            .field("running", &self.running)
            .field("disks", &self.disks.len())
            .field("nics", &self.nics.len())
            .finish_non_exhaustive()
    }
}

impl Hardware {
    pub fn disk(&self, key: &str) -> Option<&HwDisk> {
        self.disks.iter().find(|d| d.key == key)
    }

    pub fn nic(&self, key: &str) -> Option<&HwNic> {
        self.nics.iter().find(|n| n.key == key)
    }

    pub fn has_tpm(&self) -> bool {
        self.devices.iter().any(|d| d.kind == DeviceKind::Tpm)
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Cpu {
    pub sockets: u32,
    pub cores: u32,
    /// libvirt's threads per core (and its dies and clusters), kept as they
    /// are; 1 on PVE.
    #[serde(default = "one")]
    pub threads: u32,
    /// vCPUs online: PVE's `vcpus`, libvirt's `current`. None for all.
    #[serde(default)]
    pub online: Option<u32>,
    /// PVE's CPU model; None where the host decides.
    #[serde(default, rename = "type")]
    pub cpu_type: Option<String>,
}

fn one() -> u32 {
    1
}

impl Cpu {
    pub fn total(&self) -> u32 {
        self.sockets * self.cores * self.threads
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Memory {
    pub mib: u64,
    /// The balloon's floor (PVE `balloon`, 0 turning it off) or target
    /// (libvirt `currentMemory`). None where there is none to set.
    #[serde(default)]
    pub min_mib: Option<u64>,
    /// There is a balloon device, so `min_mib` can be set.
    #[serde(default)]
    pub balloon: bool,
    /// A container's swap.
    #[serde(default)]
    pub swap_mib: Option<u64>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DiskKind {
    Disk,
    Cdrom,
    /// A container's root filesystem.
    Rootfs,
    /// A container's mount point.
    Mount,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HwDisk {
    /// PVE option (`scsi0`, `rootfs`, `mp0`), libvirt target (`vda`).
    pub key: String,
    pub kind: DiskKind,
    /// PVE volume id, libvirt path; None for an empty drive.
    #[serde(default)]
    pub source: Option<String>,
    /// Bytes, where known.
    #[serde(default)]
    pub size: Option<u64>,
    /// PVE storage the volume is on.
    #[serde(default)]
    pub storage: Option<String>,
    /// A mount point's path in the container.
    #[serde(default)]
    pub mount_point: Option<String>,
    #[serde(default)]
    pub bus: Option<String>,
    #[serde(default)]
    pub format: Option<String>,
    #[serde(default)]
    pub readonly: bool,
    /// The cache mode; None for the host's default.
    #[serde(default)]
    pub cache: Option<String>,
    /// A CD-ROM holding the guest's cloud-init data (PVE's `cloudinit`
    /// drive, the seed this app made on libvirt): not install media.
    #[serde(default)]
    pub cloud_init: bool,
    /// The backend has a way to grow it ([`disk_growable`]).
    #[serde(default = "yes")]
    pub resizable: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct HwNic {
    /// PVE option (`net0`), libvirt MAC.
    pub key: String,
    #[serde(default)]
    pub mac: Option<String>,
    /// libvirt's interface type (`network`, `bridge`); None on PVE.
    #[serde(default, rename = "type")]
    pub nic_type: Option<String>,
    /// Bridge (PVE, libvirt `bridge`) or network (libvirt `network`).
    #[serde(default)]
    pub source: Option<String>,
    #[serde(default)]
    pub model: Option<String>,
    #[serde(default = "yes")]
    pub link_up: bool,
    /// PVE's firewall on this interface; None where there is none.
    #[serde(default)]
    pub firewall: Option<bool>,
    /// A container's interface name (`eth0`).
    #[serde(default)]
    pub name: Option<String>,
}

/// One setting the running guest has differently from its next start.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct PendingField {
    /// PVE's option name; libvirt: `cpu`, `memory`, `boot`, `firmware`,
    /// `display`, a disk target, a NIC's MAC or a device key.
    pub key: String,
    #[serde(default)]
    pub current: Option<String>,
    #[serde(default)]
    pub pending: Option<String>,
    /// Goes at the next start.
    #[serde(default)]
    pub delete: bool,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Firmware {
    pub uefi: bool,
    #[serde(default)]
    pub secure_boot: bool,
    /// PVE: the storage the EFI variables disk is on; None without one.
    #[serde(default)]
    pub vars_storage: Option<String>,
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Display {
    /// `vnc`, `spice`; None where the host decides.
    #[serde(default)]
    pub protocol: Option<String>,
    /// The address the console listens on (libvirt); None for the default.
    #[serde(default)]
    pub listen: Option<String>,
    /// The video card: libvirt's model, PVE's `vga` type.
    #[serde(default)]
    pub gpu: Option<String>,
    #[serde(default)]
    pub port: Option<i32>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DeviceKind {
    Usb,
    Pci,
    Tpm,
}

/// A host device given to the guest, or its TPM.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HwDevice {
    /// PVE option (`usb0`, `hostpci0`, `tpmstate0`); libvirt
    /// `usb:0bda:b023`, `usb@1.4`, `pci:0000:01:00.0`, `tpm`.
    pub key: String,
    pub kind: DeviceKind,
    /// `0bda:b023`, `0000:01:00.0`, a PVE mapping's name, or the TPM's
    /// model and version.
    #[serde(default)]
    pub detail: Option<String>,
    /// Given through a PVE resource mapping rather than by address.
    #[serde(default)]
    pub mapping: bool,
}

/// What a guest's hardware can be changed to, on its host.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Support {
    /// Disk buses; empty: the bus is not changed here.
    #[serde(default)]
    pub buses: Vec<String>,
    #[serde(default)]
    pub caches: Vec<String>,
    #[serde(default)]
    pub nic_models: Vec<String>,
    /// A NIC's MAC can be set.
    #[serde(default)]
    pub mac: bool,
    /// Console protocols to choose from; empty where the host has one.
    #[serde(default)]
    pub protocols: Vec<String>,
    /// The console's listen address can be set (libvirt).
    #[serde(default)]
    pub listen: bool,
    #[serde(default)]
    pub gpus: Vec<String>,
    #[serde(default)]
    pub uefi: bool,
    #[serde(default)]
    pub secure_boot: bool,
    #[serde(default)]
    pub tpm: bool,
    #[serde(default)]
    pub usb: bool,
    #[serde(default)]
    pub pci: bool,
}

/// The host's bounds on what a guest can use.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Limits {
    #[serde(default)]
    pub host_cpus: Option<u32>,
    #[serde(default)]
    pub host_memory_bytes: Option<u64>,
}

/// How a USB device is named when it is given to a guest.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UsbNaming {
    /// By vendor and product: the device wherever it is plugged in.
    #[default]
    VendorProduct,
    /// By where it sits: the slot keeps the device, whatever fills it.
    Address,
}

/// One host device a guest can be given, named the way its backend does:
/// PCI `0000:01:00.0`; USB the vendor and product pair (`0bda:b023`) in
/// `id`, with where it sits in `usb_bus`, `usb_device` and `usb_port`; a
/// PVE resource mapping by its name.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostDevice {
    pub id: String,
    pub label: String,
    #[serde(default)]
    pub detail: Option<String>,
    /// A PVE resource mapping rather than a raw device.
    #[serde(default)]
    pub mapping: bool,
    /// USB: the bus it is on, and the port chain it sits at (`4`, or `1.2`
    /// behind a hub).
    #[serde(default)]
    pub usb_bus: Option<u32>,
    #[serde(default)]
    pub usb_port: Option<String>,
    /// USB: the device number on that bus, where the host reports one
    /// (libvirt; PVE names a device by its port).
    #[serde(default)]
    pub usb_device: Option<u32>,
    #[serde(default)]
    pub iommu_group: Option<u32>,
    /// Devices sharing its IOMMU group, itself included: they all go to the
    /// guest together.
    #[serde(default)]
    pub group_size: u32,
}

impl HostDevice {
    /// The host said where it sits.
    pub fn has_address(&self) -> bool {
        self.usb_bus.is_some() && (self.usb_port.is_some() || self.usb_device.is_some())
    }

    /// The address it is given by: libvirt's bus and device number (`1:4`,
    /// what `usbaddress` takes), PVE's bus and port chain (`1-1.2`, what its
    /// web UI writes and a mapping stores).
    pub fn usb_address(&self, host: HostKind) -> Option<String> {
        let bus = self.usb_bus?;
        match host {
            HostKind::Pve => Some(format!("{bus}-{}", self.usb_port.as_deref()?)),
            HostKind::Libvirt => Some(format!("{bus}:{}", self.usb_device?)),
        }
    }
}

/// The host devices a guest can be given, and why there may be none.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct HostDevices {
    #[serde(default)]
    pub usb: Vec<HostDevice>,
    #[serde(default)]
    pub pci: Vec<HostDevice>,
    /// The host has an IOMMU on; false: a PCI device given to a guest keeps
    /// it from starting.
    #[serde(default = "yes")]
    pub iommu: bool,
    /// PVE: this login may only use resource mappings (only root@pam gives
    /// a guest a raw device).
    #[serde(default)]
    pub mappings_only: bool,
}

/// One change to a guest's hardware or settings.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum Change {
    SetCpu {
        sockets: u32,
        cores: u32,
        /// None for all of them.
        #[serde(default)]
        online: Option<u32>,
        /// PVE only; None keeps it.
        #[serde(default, rename = "type")]
        cpu_type: Option<String>,
    },
    SetMemory {
        mib: u64,
        /// None: none (PVE the default, the same as `mib`; libvirt all of
        /// `mib`).
        #[serde(default)]
        min_mib: Option<u64>,
        #[serde(default)]
        swap_mib: Option<u64>,
    },
    /// Grows a disk to `bytes`; never less than it has.
    GrowDisk { key: String, bytes: u64 },
    /// A new disk of `gib` in `pool` (by id); a container's at `mount_point`.
    AddDisk {
        pool: String,
        gib: u64,
        #[serde(default)]
        mount_point: Option<String>,
    },
    /// An existing volume attached as a new disk, on the bus the guest's
    /// first disk is on.
    AttachVolume {
        volume: VolumeRef,
        #[serde(default)]
        mount_point: Option<String>,
    },
    RemoveDisk {
        key: String,
        /// Deletes the volume as well, once nothing uses it.
        #[serde(default)]
        delete_volume: bool,
    },
    /// A new CD-ROM drive, empty or with `media` in it.
    AddCdrom {
        #[serde(default)]
        media: Option<VolumeRef>,
    },
    /// Inserts `media`, or ejects with None.
    SetMedia {
        key: String,
        #[serde(default)]
        media: Option<VolumeRef>,
    },
    AddNic {
        /// The network's id.
        network: String,
        #[serde(default)]
        model: Option<String>,
    },
    RemoveNic { key: String },
    UpdateNic {
        key: String,
        /// None keeps it.
        #[serde(default)]
        network: Option<String>,
        link_up: bool,
        /// PVE only; None keeps it.
        #[serde(default)]
        firewall: Option<bool>,
    },
    SetBoot { order: Vec<String> },
    SetAutostart { on: bool },
    SetName { name: String },
    /// Empty clears it.
    SetDescription { text: String },
    /// PVE's `protection`.
    SetProtection { on: bool },
    /// A disk's bus and cache mode (`default` for the host's); None keeps
    /// it. A new bus waits for the guest to be stopped.
    UpdateDisk {
        key: String,
        #[serde(default)]
        bus: Option<String>,
        #[serde(default)]
        cache: Option<String>,
    },
    SetNicHardware {
        key: String,
        #[serde(default)]
        model: Option<String>,
        #[serde(default)]
        mac: Option<String>,
    },
    SetFirmware {
        uefi: bool,
        #[serde(default)]
        secure_boot: bool,
        /// PVE: the pool (by id) a new EFI variables disk goes on.
        #[serde(default)]
        storage: Option<String>,
    },
    SetDisplay {
        #[serde(default)]
        protocol: Option<String>,
        #[serde(default)]
        listen: Option<String>,
        #[serde(default)]
        gpu: Option<String>,
    },
    AddDevice {
        kind: DeviceKind,
        /// The device, for USB and PCI.
        #[serde(default)]
        host: Option<HostDevice>,
        /// PVE: the pool (by id) the TPM's state goes on.
        #[serde(default)]
        storage: Option<String>,
        #[serde(default)]
        usb_naming: UsbNaming,
    },
    RemoveDevice { key: String },
    /// PVE: drops the pending changes to `keys`.
    Revert { keys: Vec<String> },
}

impl Change {
    /// One line for an audit log.
    pub fn describe(&self) -> String {
        let op = serde_json::to_value(self)
            .ok()
            .and_then(|v| v.get("op").and_then(|o| o.as_str().map(str::to_owned)))
            .unwrap_or_default();
        match self {
            Change::GrowDisk { key, .. }
            | Change::RemoveDisk { key, .. }
            | Change::SetMedia { key, .. }
            | Change::RemoveNic { key }
            | Change::UpdateNic { key, .. }
            | Change::UpdateDisk { key, .. }
            | Change::SetNicHardware { key, .. }
            | Change::RemoveDevice { key } => format!("{op} {key}"),
            Change::SetName { name } => format!("{op} {name}"),
            _ => op,
        }
    }
}

/// What a change came to, beyond succeeding.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Outcome {
    /// The running guest refused its half, in the host's words: the next
    /// start gets the change.
    #[serde(default)]
    pub live_error: Option<String>,
    /// A disk was to be deleted, but the running guest still has it: kept.
    #[serde(default)]
    pub volume_kept: bool,
}

/// Why a change cannot be made. The first that applies wins.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Issue {
    /// Fewer than one, or more vCPUs than the host has.
    CpuCount,
    /// Online vCPUs outside 1..total.
    CpuOnline,
    Memory,
    /// A balloon floor above the memory.
    MemoryMin,
    /// Smaller than the disk is: disks only grow.
    DiskShrink,
    DiskSize,
    /// More than the storage has free.
    StorageSpace,
    MountPoint,
    BootEmpty,
    NameInvalid,
    /// libvirt renames only a guest that is not running.
    NameRunning,
    /// Longer than a note is kept, or with control characters in it.
    Description,
    /// Not a unicast MAC.
    Mac,
    /// A disk moves to another bus, or the firmware changes, only while the
    /// guest is stopped.
    StopFirst,
    /// A TPM or an EFI disk needs a storage to go on.
    StorageMissing,
    /// No device picked, or a second TPM.
    Device,
    /// The volume is another guest's disk already, or a volume is made on
    /// it.
    VolumeInUse,
    /// Not install media.
    Media,
    /// Not something the host offers this guest.
    NotOffered,
    /// The disk, NIC, pool, volume or network is not (or no longer) there.
    NotFound,
    Unsupported,
}

/// `issue` as the error a client answers a refused change with:
/// [`ErrorKind::Unsupported`] with [`Detail::HardwareRefused`].
pub fn refusal(issue: Issue) -> Error {
    Error::detail(ErrorKind::Unsupported, Detail::HardwareRefused { issue })
}

/// The read is not the one the change was made from.
pub fn conflict() -> Error {
    Error::msg(ErrorKind::Conflict, "Read the hardware again")
}

/// The longest note kept with a guest: PVE caps `description` at 8 KiB;
/// libvirt's is held to the same. UTF-8 bytes.
pub const DESCRIPTION_MAX: usize = 8192;

/// The least memory a guest is given.
pub const MIN_MEMORY_MIB: u64 = 16;

/// Whether `disk` can be grown: not a host block device (a logical
/// volume, a disk given by its `/dev` path), which neither libvirt nor
/// PVE's resize grows.
pub fn disk_growable(disk: &HwDisk) -> bool {
    disk.resizable && !disk.source.as_deref().is_some_and(|s| s.starts_with("/dev/"))
}

/// A unicast MAC: six octets, the first even, not all zero.
pub fn is_unicast_mac(mac: &str) -> bool {
    let parts: Vec<&str> = mac.split(':').collect();
    if parts.len() != 6 || !parts.iter().all(|p| p.len() == 2 && p.bytes().all(|b| b.is_ascii_hexdigit())) {
        return false;
    }
    u8::from_str_radix(parts[0], 16).is_ok_and(|b| b & 1 == 0) && parts.iter().any(|p| *p != "00")
}

/// A container mount point: absolute, and nothing PVE's option syntax would
/// read as the next option.
pub fn mount_point_ok(p: &str) -> bool {
    p.len() > 1
        && p.starts_with('/')
        && !p.ends_with('/')
        && !p.chars().any(|c| c == ',' || c == '=' || c.is_whitespace())
}

/// A note: lines and tabs, no other control characters, bounded.
pub fn description_ok(text: &str) -> bool {
    text.len() <= DESCRIPTION_MAX
        && !text.chars().any(|c| {
            let r = c as u32;
            (r < 0x20 && c != '\n' && c != '\t') || (0x7f..=0x9f).contains(&r)
        })
}

/// What a change is checked against: the pools and networks of the guest's
/// host (on PVE, its node's), and the volumes it names (as their pools list
/// them now).
#[derive(Debug, Clone, Copy, Default)]
pub struct Listing<'a> {
    pub pools: &'a [Pool],
    pub networks: &'a [Network],
    pub volumes: &'a [Volume],
}

impl<'a> Listing<'a> {
    pub fn pool(&self, id: &str) -> Option<&'a Pool> {
        self.pools.iter().find(|p| p.id == id)
    }

    pub fn volume(&self, r: &VolumeRef) -> Option<&'a Volume> {
        self.volumes.iter().find(|v| v.id == r.volume)
    }

    pub fn network(&self, id: &str) -> Option<&'a Network> {
        self.networks.iter().find(|n| n.id == id)
    }
}

/// Why `change` cannot be made to `hw` on a host of `host`; None when it
/// can.
pub fn issue(hw: &Hardware, change: &Change, host: HostKind, list: Listing<'_>) -> Option<Issue> {
    let lxc = hw.kind == GuestKind::Lxc;
    let pve = host == HostKind::Pve;
    let limits = &hw.limits;
    match change {
        Change::SetCpu { sockets, cores, online, cpu_type } => {
            if *sockets < 1 || *cores < 1 {
                return Some(Issue::CpuCount);
            }
            let total = sockets * cores * hw.cpu.threads;
            if total > limits.host_cpus.unwrap_or(4096) {
                return Some(Issue::CpuCount);
            }
            if online.is_some_and(|o| o < 1 || o > total) {
                return Some(Issue::CpuOnline);
            }
            if cpu_type.as_ref().is_some_and(|t| !pve || (!hw.cpu_types.is_empty() && !hw.cpu_types.contains(t))) {
                return Some(Issue::NotOffered);
            }
        }
        Change::SetMemory { mib, min_mib, swap_mib } => {
            if *mib < MIN_MEMORY_MIB || limits.host_memory_bytes.is_some_and(|h| mib.saturating_mul(1 << 20) > h) {
                return Some(Issue::Memory);
            }
            if min_mib.is_some_and(|m| m > *mib) {
                return Some(Issue::MemoryMin);
            }
            if swap_mib.is_some() && !lxc {
                return Some(Issue::Unsupported);
            }
        }
        Change::GrowDisk { key, bytes } => {
            let Some(disk) = hw.disk(key).filter(|d| disk_growable(d)) else {
                return Some(Issue::DiskSize);
            };
            if disk.size.is_some_and(|s| *bytes <= s) {
                return Some(Issue::DiskShrink);
            }
            if *bytes > 1 << 50 {
                return Some(Issue::DiskSize);
            }
        }
        Change::AddDisk { pool, gib, mount_point } => {
            let Some(pool) = list.pool(pool) else { return Some(Issue::NotFound) };
            if !(1..=65536).contains(gib) {
                return Some(Issue::DiskSize);
            }
            if !crate::create::disk_storages(std::slice::from_ref(pool), host, hw.kind, pool.node.as_deref()).iter().any(|p| p.id == pool.id) {
                return Some(Issue::NotOffered);
            }
            if pool.available.is_some_and(|free| gib << 30 > free) {
                return Some(Issue::StorageSpace);
            }
            if lxc && !mount_point.as_deref().is_some_and(mount_point_ok) {
                return Some(Issue::MountPoint);
            }
        }
        Change::AttachVolume { volume, mount_point } => {
            let Some(v) = list.volume(volume) else { return Some(Issue::NotFound) };
            // A base image too: a guest writing to it corrupts what is made
            // on it.
            if v.in_use() {
                return Some(Issue::VolumeInUse);
            }
            if lxc && !mount_point.as_deref().is_some_and(mount_point_ok) {
                return Some(Issue::MountPoint);
            }
        }
        Change::RemoveDisk { key, .. } => {
            if hw.disk(key).is_none() {
                return Some(Issue::NotFound);
            }
        }
        Change::AddCdrom { media } | Change::SetMedia { media, .. } => {
            if lxc {
                return Some(Issue::Unsupported);
            }
            if let Change::SetMedia { key, .. } = change
                && hw.disk(key).is_none_or(|d| d.kind != DiskKind::Cdrom || d.cloud_init)
            {
                return Some(Issue::NotFound);
            }
            if let Some(r) = media {
                let Some(v) = list.volume(r) else { return Some(Issue::NotFound) };
                if !crate::create::is_media(v, GuestKind::Qemu) {
                    return Some(Issue::Media);
                }
            }
        }
        Change::AddNic { network, model } => {
            if list.network(network).is_none() {
                return Some(Issue::NotFound);
            }
            if model.as_ref().is_some_and(|m| lxc || !hw.support.nic_models.contains(m)) {
                return Some(Issue::NotOffered);
            }
        }
        Change::RemoveNic { key } => {
            if hw.nic(key).is_none() {
                return Some(Issue::NotFound);
            }
        }
        Change::UpdateNic { key, network, firewall, .. } => {
            if hw.nic(key).is_none() || network.as_ref().is_some_and(|n| list.network(n).is_none()) {
                return Some(Issue::NotFound);
            }
            if firewall.is_some() && !pve {
                return Some(Issue::Unsupported);
            }
        }
        Change::SetBoot { order } => {
            if order.is_empty() {
                return Some(Issue::BootEmpty);
            }
            if hw.boot.is_none() {
                return Some(Issue::Unsupported);
            }
            if order.iter().any(|k| hw.disk(k).is_none() && hw.nic(k).is_none()) {
                return Some(Issue::NotFound);
            }
        }
        Change::SetName { name } => {
            if !crate::create::name_ok(name, host) {
                return Some(Issue::NameInvalid);
            }
            if hw.running && !hw.rename_running {
                return Some(Issue::NameRunning);
            }
        }
        Change::SetDescription { text } => {
            if !description_ok(text) {
                return Some(Issue::Description);
            }
        }
        Change::SetProtection { .. } | Change::Revert { .. } => {
            if !pve {
                return Some(Issue::Unsupported);
            }
        }
        Change::UpdateDisk { key, bus, cache } => {
            let Some(disk) = hw.disk(key) else { return Some(Issue::NotFound) };
            let offered = |v: &Option<String>, all: &[String]| v.as_ref().is_none_or(|v| all.contains(v));
            if lxc || !offered(bus, &hw.support.buses) || !offered(cache, &hw.support.caches) {
                return Some(Issue::NotOffered);
            }
            if bus.as_ref().is_some_and(|b| disk.bus.as_ref() != Some(b)) && hw.running {
                return Some(Issue::StopFirst);
            }
        }
        Change::SetNicHardware { key, model, mac } => {
            if hw.nic(key).is_none() {
                return Some(Issue::NotFound);
            }
            if mac.as_deref().is_some_and(|m| !is_unicast_mac(m)) {
                return Some(Issue::Mac);
            }
            if model.as_ref().is_some_and(|m| lxc || !hw.support.nic_models.contains(m)) {
                return Some(Issue::NotOffered);
            }
        }
        Change::SetFirmware { uefi, secure_boot, storage } => {
            // Secure Boot goes with UEFI: BIOS asked for with the flag still
            // set is made as BIOS (both backends drop it), not refused.
            if lxc || (*uefi && !hw.support.uefi) || (*uefi && *secure_boot && !hw.support.secure_boot) {
                return Some(Issue::NotOffered);
            }
            if hw.running {
                return Some(Issue::StopFirst);
            }
            if pve && *uefi {
                match storage {
                    None if hw.firmware.as_ref().and_then(|f| f.vars_storage.as_ref()).is_none() => {
                        return Some(Issue::StorageMissing);
                    }
                    Some(id) if list.pool(id).is_none() => return Some(Issue::NotFound),
                    _ => {}
                }
            }
        }
        Change::SetDisplay { protocol, listen, gpu } => {
            let offered = |v: &Option<String>, all: &[String]| v.as_ref().is_none_or(|v| all.contains(v));
            if lxc || !offered(protocol, &hw.support.protocols) || !offered(gpu, &hw.support.gpus) || (listen.is_some() && !hw.support.listen) {
                return Some(Issue::NotOffered);
            }
        }
        Change::AddDevice { kind, host: device, storage, usb_naming } => match kind {
            DeviceKind::Tpm => {
                if !hw.support.tpm {
                    return Some(Issue::NotOffered);
                }
                if hw.has_tpm() {
                    return Some(Issue::Device);
                }
                if pve {
                    match storage {
                        None => return Some(Issue::StorageMissing),
                        Some(id) if list.pool(id).is_none() => return Some(Issue::NotFound),
                        _ => {}
                    }
                }
            }
            DeviceKind::Usb | DeviceKind::Pci => {
                let Some(d) = device else { return Some(Issue::Device) };
                let offered = if *kind == DeviceKind::Usb { hw.support.usb } else { hw.support.pci };
                if !offered {
                    return Some(Issue::NotOffered);
                }
                if *kind == DeviceKind::Usb && *usb_naming == UsbNaming::Address && !d.mapping && d.usb_address(host).is_none() {
                    return Some(Issue::Device);
                }
            }
        },
        Change::RemoveDevice { key } => {
            if !hw.devices.iter().any(|d| &d.key == key) {
                return Some(Issue::NotFound);
            }
        }
        Change::SetAutostart { .. } => {}
    }
    None
}

/// A guest's cloud-init as it stands, for the Settings view. Never the
/// password: PVE answers it masked, and libvirt's seed holds only its hash,
/// which stays on the host's side.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct CloudInitState {
    pub user: String,
    #[serde(default)]
    pub ssh_keys: Vec<String>,
    /// libvirt: the seed's hostname. None on PVE, whose cloud-init uses the
    /// VM's name.
    #[serde(default)]
    pub hostname: Option<String>,
    /// IPv4 with its prefix; None for DHCP.
    #[serde(default)]
    pub address: Option<String>,
    #[serde(default)]
    pub gateway: Option<String>,
    #[serde(default)]
    pub dns: Vec<String>,
    #[serde(default)]
    pub search_domains: Vec<String>,
    /// How many NICs the settings configure; the first is the one edited.
    #[serde(default)]
    pub nics: u32,
    #[serde(default)]
    pub password_set: bool,
    /// The password expires at the first login (libvirt only).
    #[serde(default)]
    pub password_expires: bool,
    /// The guest has the NIC the address settings apply to.
    #[serde(default)]
    pub network: bool,
    /// libvirt: the seed says more than this app writes; saving writes a
    /// seed of its own instead.
    #[serde(default)]
    pub foreign: bool,
    /// PVE's `digest`, the seed's checksum: an edit made from an older read
    /// is refused as [`ErrorKind::Conflict`].
    pub revision: String,
}

/// A change to a guest's cloud-init: `values` as they are to be. Its
/// `password` is a new one, or None to keep the one set — unless
/// `remove_password`.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CloudInitEdit {
    pub values: CloudInit,
    #[serde(default)]
    pub remove_password: bool,
    /// libvirt only: the password expires at the first login.
    #[serde(default)]
    pub password_expires: bool,
    /// [`CloudInitState::revision`] of the read it is made from.
    pub revision: String,
}

/// Why `edit` cannot be made to `state`; None when it can. An account needs
/// a way in: a password (a new one, or the one set, kept) or a key.
pub fn cloud_init_edit_issue(state: &CloudInitState, edit: &CloudInitEdit, host: HostKind) -> Option<crate::create::Issue> {
    crate::create::cloud_init_issue(&edit.values, host, state.password_set && !edit.remove_password)
}
