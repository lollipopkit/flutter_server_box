//! A host's storage and networks, for either backend: what a pool, a volume
//! and a network are, the changes a client asks for, and the rules a change
//! is checked by before anything is sent ([`issue`]).
//!
//! libvirt: pools, volumes and networks through `virsh`
//! ([`crate::libvirt::manage`], [`crate::libvirt::net`]); the listings map
//! here in [`crate::libvirt::host`]. PVE: storages (`/storage`), volumes
//! (`/nodes/{node}/storage/{id}/content`) and Linux bridges
//! (`/nodes/{node}/network`), whose changes wait in `interfaces.new` until
//! applied ([`Change::NetworkApply`]) — [`crate::pve::client::Client::manage`].
//!
//! Ported from the app's `lib/data/model/virt/virt_manage.dart`.

pub mod ipv4;

use serde::{Deserialize, Serialize};

use crate::error::{Detail, Error, ErrorKind};
use crate::model::HostKind;

pub use crate::libvirt::net::VirtNetHost as NetHost;

fn yes() -> bool {
    true
}

/// A storage pool (libvirt) or storage (PVE) of one host.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Pool {
    /// Unique on the host: libvirt's pool name, PVE `<node>/<storage>`.
    pub id: String,
    pub name: String,
    /// The PVE node it is listed for; storage is per node there.
    pub node: Option<String>,
    /// `dir`, `logical`, `netfs`, ... (libvirt); `dir`, `lvmthin`,
    /// `zfspool`, `nfs`, ... (PVE).
    #[serde(rename = "type")]
    pub pool_type: String,
    /// Where volumes live: a directory, a volume group, a thin pool.
    pub path: Option<String>,
    /// Where the pool comes from: `host:/export`, a device.
    pub source: Option<String>,
    /// Bytes; None where unknown (an inactive pool).
    pub capacity: Option<u64>,
    pub used: Option<u64>,
    pub available: Option<u64>,
    #[serde(default = "yes")]
    pub active: bool,
    /// Started with the host (libvirt).
    pub autostart: Option<bool>,
    /// Configured on (PVE `enabled`).
    pub enabled: Option<bool>,
    /// Shared between PVE nodes.
    pub shared: Option<bool>,
    /// What PVE allows in it: `images`, `rootdir`, `iso`, `vztmpl`,
    /// `backup`, `snippets`, `import`.
    #[serde(default)]
    pub content: Vec<String>,
    /// Volumes in it, where listing the pools already says.
    pub volume_count: Option<u64>,
}

/// A guest that uses a volume or a network, and how.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct GuestRef {
    /// The guest's id as [`crate::model::Guest::id`] has it, where known.
    pub guest_id: Option<String>,
    pub vmid: Option<u32>,
    /// The disk's target (`vda`, `scsi0`), the NIC's key or host device.
    pub device: Option<String>,
    pub mac: Option<String>,
    pub ip: Option<String>,
}

/// One volume in a pool: a disk image, an ISO, a template, a backup.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Volume {
    /// libvirt's volume name; PVE's `volid` (`local-lvm:vm-100-disk-0`).
    pub id: String,
    pub name: String,
    pub path: Option<String>,
    /// `qcow2`, `raw`, `iso`, `tzst`, ...
    pub format: Option<String>,
    /// PVE's content kind: `images`, `rootdir`, `iso`, `vztmpl`, `backup`.
    pub content: Option<String>,
    /// Bytes the guest sees.
    pub capacity: Option<u64>,
    /// Bytes it takes on the host, where the host says.
    pub allocation: Option<u64>,
    /// A qcow2 overlay's backing file (libvirt).
    pub backing: Option<String>,
    /// Unix seconds.
    pub created_at: Option<i64>,
    #[serde(default)]
    pub users: Vec<GuestRef>,
    /// The volumes made on this one — whose [`Volume::backing`] it is — in
    /// any active pool, by path (libvirt). A base image a guest's disk is a
    /// thin clone of is attached to nothing, and deleting it breaks every
    /// one of them.
    #[serde(default)]
    pub backs: Vec<String>,
}

impl Volume {
    /// Something depends on it: a guest has it, or a volume is made on it.
    pub fn in_use(&self) -> bool {
        !self.users.is_empty() || !self.backs.is_empty()
    }
}

/// A virtual network (libvirt) or a node network interface (PVE).
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Network {
    /// Unique on the host: libvirt's network name, PVE `<node>/<iface>`.
    pub id: String,
    pub name: String,
    pub node: Option<String>,
    /// libvirt's forward mode: `nat`, `isolated`, `route`, `open`,
    /// `bridge`, ...; PVE's interface type: `bridge`, `bond`, `vlan`, `eth`,
    /// `OVSBridge`, ...
    pub mode: String,
    /// libvirt: the bridge device (`virbr0`, or the host bridge a
    /// bridge-mode network uses).
    pub bridge: Option<String>,
    /// Addresses with their prefix, e.g. `192.168.122.1/24`.
    #[serde(default)]
    pub cidrs: Vec<String>,
    pub gateway: Option<String>,
    /// `start-end` of each DHCP range (libvirt).
    #[serde(default)]
    pub dhcp_ranges: Vec<String>,
    /// PVE bridge ports or bond slaves; libvirt forward devices.
    #[serde(default)]
    pub ports: Vec<String>,
    /// PVE `bridge_vlan_aware`.
    pub vlan_aware: Option<bool>,
    /// PVE: the VLAN tag and the device it is on.
    pub vlan_id: Option<u32>,
    pub vlan_device: Option<String>,
    /// PVE bond mode (`active-backup`, `802.3ad`, ...).
    pub bond_mode: Option<String>,
    #[serde(default = "yes")]
    pub active: bool,
    pub autostart: Option<bool>,
    pub comment: Option<String>,
    /// The static DHCP entries it hands out (libvirt).
    #[serde(default)]
    pub hosts: Vec<NetHost>,
    /// libvirt: the definition as saved (`net-dumpxml --inactive`), which an
    /// edit is made from. Empty on PVE.
    #[serde(default)]
    pub xml: String,
    /// libvirt: the running network is on something other than its
    /// definition, and a restart applies it.
    #[serde(default)]
    pub pending_restart: bool,
    /// Whether a client may change it at all. PVE: a bridge, and not an
    /// interface carrying the node's management traffic
    /// ([`crate::pve::net::management_ifaces`]). libvirt: every network.
    #[serde(default = "yes")]
    pub management_editable: bool,
    /// Guests with a NIC on it.
    #[serde(default)]
    pub users: Vec<GuestRef>,
}

impl Network {
    /// The first IPv4 address with its prefix; None where there is none.
    pub fn ipv4_cidr(&self) -> Option<&str> {
        self.cidrs.iter().map(String::as_str).find(|c| !c.contains(':') && c.split('/').count() == 2)
    }
}

/// A node's network configuration waiting to be applied (PVE): the diff of
/// `/etc/network/interfaces` against `interfaces.new`, as PVE shows it.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct NetworkChanges {
    pub node: String,
    pub diff: String,
}

/// One change to a host's storage or networks. A pool, a volume and a
/// network are named by their id, and the one the host lists at the moment
/// of the change is what it is checked against and made to.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
pub enum Change {
    /// A new pool (libvirt) or storage (PVE).
    PoolCreate {
        name: String,
        /// One of [`crate::model::Capabilities::pool_types`].
        #[serde(rename = "type")]
        pool_type: String,
        /// What the type is made from: a directory (`dir`), `host:/export`
        /// (`netfs`, `nfs`), a volume group (`logical`), `vg/thinpool`
        /// (`lvmthin`), a ZFS pool or dataset (`zfspool`).
        source: String,
        /// libvirt `netfs`: where it is mounted.
        #[serde(default)]
        target: Option<String>,
        /// PVE: the node it is made on and limited to.
        #[serde(default)]
        node: Option<String>,
        /// PVE: what it holds; empty for the type's own default.
        #[serde(default)]
        content: Vec<String>,
        /// libvirt: started with the host.
        #[serde(default = "yes")]
        autostart: bool,
    },
    /// libvirt: started or stopped. PVE: enabled or disabled.
    PoolSetActive { pool: String, active: bool },
    PoolSetAutostart { pool: String, on: bool },
    /// libvirt `pool-refresh`: files put in its directory by other means
    /// appear. PVE reads a storage's contents on every listing.
    PoolRefresh { pool: String },
    /// Removes the pool's definition; its volumes stay where they are. With
    /// `delete_storage` (libvirt) what it is on goes too: `pool-delete`
    /// removes an empty directory, never contents.
    PoolDelete {
        pool: String,
        #[serde(default)]
        delete_storage: bool,
    },
    VolumeCreate {
        pool: String,
        /// As typed: PVE's own rule is `vm-<vmid>-…`, and a file-based
        /// storage's name gets the format as its extension
        /// ([`volume_file_name`]).
        name: String,
        gib: u64,
        /// One of [`volume_formats`].
        format: String,
    },
    /// Deletes a volume and its contents; refused while anything uses it.
    VolumeDelete { pool: String, volume: String },
    /// Grows a volume no running guest has open (libvirt `vol-resize`).
    VolumeResize { pool: String, volume: String, bytes: u64 },
    /// Copies a volume within its pool (libvirt `vol-clone`).
    VolumeClone { pool: String, volume: String, name: String },
    /// A libvirt virtual network, or a PVE Linux bridge (pending until
    /// applied).
    NetworkCreate {
        name: String,
        /// One of [`crate::model::Capabilities::network_modes`].
        mode: String,
        /// PVE: the node the bridge is made on.
        #[serde(default)]
        node: Option<String>,
        /// libvirt `bridge` mode: the host bridge guests are handed to.
        /// PVE: the bridge's ports, space-separated.
        #[serde(default)]
        bridge: Option<String>,
        /// The host's address with its prefix.
        #[serde(default)]
        cidr: Option<String>,
        /// libvirt: the DHCP range dnsmasq serves; both or neither.
        #[serde(default)]
        dhcp_start: Option<String>,
        #[serde(default)]
        dhcp_end: Option<String>,
        /// PVE `bridge_vlan_aware`.
        #[serde(default)]
        vlan_aware: bool,
        /// libvirt: started with the host. PVE: `auto`.
        #[serde(default = "yes")]
        autostart: bool,
    },
    /// libvirt: what an existing network is edited to — written into the
    /// definition, applied to the running one only with `restart`, which
    /// cuts off every guest on it meanwhile ([`crate::libvirt::net`]).
    NetworkEdit {
        network: String,
        mode: String,
        #[serde(default)]
        bridge: Option<String>,
        /// The host's address, without its prefix.
        #[serde(default)]
        address: Option<String>,
        #[serde(default)]
        prefix: Option<u8>,
        #[serde(default)]
        dhcp_start: Option<String>,
        #[serde(default)]
        dhcp_end: Option<String>,
        /// The static DHCP entries the network ends up with.
        #[serde(default)]
        hosts: Vec<NetHost>,
        #[serde(default)]
        restart: bool,
        /// The definition the edit was made from, as the client listed it;
        /// a definition changed since is refused. None takes the host's now.
        #[serde(default)]
        base_xml: Option<String>,
    },
    /// PVE: a bridge's configuration written into the node's pending one.
    /// Refused for an interface carrying the node's management traffic.
    NetworkEditBridge {
        network: String,
        /// Space-separated ports; None keeps them, empty clears them.
        #[serde(default)]
        ports: Option<String>,
        /// `a.b.c.d/prefix`; None keeps the address, empty clears it.
        #[serde(default)]
        cidr: Option<String>,
        #[serde(default)]
        gateway: Option<String>,
        #[serde(default)]
        vlan_aware: Option<bool>,
        #[serde(default)]
        autostart: Option<bool>,
    },
    /// libvirt: stops and starts the network so its definition applies.
    NetworkRestart {
        network: String,
        #[serde(default)]
        base_xml: Option<String>,
    },
    NetworkSetActive { network: String, active: bool },
    NetworkSetAutostart { network: String, on: bool },
    /// libvirt: stopped when active, undefined. PVE: removed from the
    /// pending configuration.
    NetworkDelete { network: String },
    /// PVE: makes `node`'s pending network configuration the running one.
    NetworkApply { node: String },
    /// PVE: drops `node`'s pending network configuration.
    NetworkRevert { node: String },
}

impl Change {
    /// What an audit row names: the verb and its target.
    pub fn describe(&self) -> String {
        match self {
            Change::PoolCreate { name, pool_type, .. } => format!("pool create {pool_type} {name}"),
            Change::PoolSetActive { pool, active } => format!("pool {} {pool}", if *active { "start" } else { "stop" }),
            Change::PoolSetAutostart { pool, on } => format!("pool autostart {on} {pool}"),
            Change::PoolRefresh { pool } => format!("pool refresh {pool}"),
            Change::PoolDelete { pool, .. } => format!("pool delete {pool}"),
            Change::VolumeCreate { pool, name, .. } => format!("volume create {pool} {name}"),
            Change::VolumeDelete { pool, volume } => format!("volume delete {pool} {volume}"),
            Change::VolumeResize { pool, volume, .. } => format!("volume resize {pool} {volume}"),
            Change::VolumeClone { pool, volume, name } => format!("volume clone {pool} {volume} {name}"),
            Change::NetworkCreate { name, mode, .. } => format!("network create {mode} {name}"),
            Change::NetworkEdit { network, .. } | Change::NetworkEditBridge { network, .. } => {
                format!("network edit {network}")
            }
            Change::NetworkRestart { network, .. } => format!("network restart {network}"),
            Change::NetworkSetActive { network, active } => {
                format!("network {} {network}", if *active { "start" } else { "stop" })
            }
            Change::NetworkSetAutostart { network, on } => format!("network autostart {on} {network}"),
            Change::NetworkDelete { network } => format!("network delete {network}"),
            Change::NetworkApply { node } => format!("network apply {node}"),
            Change::NetworkRevert { node } => format!("network revert {node}"),
        }
    }

    /// The pool this change is to, where it is to one.
    pub fn pool(&self) -> Option<&str> {
        match self {
            Change::PoolSetActive { pool, .. }
            | Change::PoolSetAutostart { pool, .. }
            | Change::PoolRefresh { pool }
            | Change::PoolDelete { pool, .. }
            | Change::VolumeCreate { pool, .. }
            | Change::VolumeDelete { pool, .. }
            | Change::VolumeResize { pool, .. }
            | Change::VolumeClone { pool, .. } => Some(pool),
            _ => None,
        }
    }

    /// The network this change is to, where it is to an existing one.
    pub fn network(&self) -> Option<&str> {
        match self {
            Change::NetworkEdit { network, .. }
            | Change::NetworkEditBridge { network, .. }
            | Change::NetworkRestart { network, .. }
            | Change::NetworkSetActive { network, .. }
            | Change::NetworkSetAutostart { network, .. }
            | Change::NetworkDelete { network } => Some(network),
            _ => None,
        }
    }

    /// Whether checking it needs the networks listed.
    pub fn is_network(&self) -> bool {
        matches!(
            self,
            Change::NetworkCreate { .. }
                | Change::NetworkEdit { .. }
                | Change::NetworkEditBridge { .. }
                | Change::NetworkRestart { .. }
                | Change::NetworkSetActive { .. }
                | Change::NetworkSetAutostart { .. }
                | Change::NetworkDelete { .. }
                | Change::NetworkApply { .. }
                | Change::NetworkRevert { .. }
        )
    }
}

/// Why a change cannot be made. The first that applies wins.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Issue {
    NameEmpty,
    /// Not a name the host takes.
    NameInvalid,
    NameTaken,
    /// A path that is not absolute, `host:/export` that is not one, a volume
    /// group or ZFS pool name that is not one.
    SourceInvalid,
    /// A netfs mount point that is not an absolute path.
    TargetInvalid,
    /// Not `a.b.c.d/prefix` with a usable host address.
    CidrInvalid,
    /// Outside the network, reversed, or covering the host's own address.
    DhcpInvalid,
    /// Another network of the host's is on an overlapping subnet.
    SubnetTaken,
    /// libvirt bridge mode without a host bridge, or ports that are not
    /// interface names.
    BridgeInvalid,
    Size,
    /// More than the pool has free.
    Space,
    Format,
    /// A guest uses it, or a volume is made on it.
    InUse,
    /// Only a new size larger than the volume's.
    Shrink,
    /// A static DHCP entry with a MAC, an address or a name the host would
    /// refuse, or two entries for one MAC.
    HostInvalid,
    /// The interface carries the node's management traffic: changing it
    /// would cut the host off.
    ManagementIface,
    /// The pool, volume or network is not (or no longer) on the host.
    NotFound,
    /// Not something this kind of host does.
    Unsupported,
}

/// What a change is checked against: the host's pools and networks, and the
/// volumes of the pool the change is to.
#[derive(Debug, Clone, Copy, Default)]
pub struct Listing<'a> {
    pub pools: &'a [Pool],
    pub networks: &'a [Network],
    pub volumes: &'a [Volume],
}

/// libvirt pool types that take a qcow2 file; the rest hold raw only.
const QCOW2_TYPES: [&str; 7] = ["dir", "fs", "netfs", "nfs", "cifs", "glusterfs", "btrfs"];

/// libvirt pools of whole devices or LUNs: nothing is created in them.
const DEVICE_POOLS: [&str; 5] = ["disk", "iscsi", "iscsi-direct", "scsi", "mpath"];

/// The formats a new volume in `pool` can have, the first the default:
/// qcow2 where the pool is a file system, raw where its volumes are block
/// devices or datasets.
pub fn volume_formats(pool: &Pool) -> &'static [&'static str] {
    if QCOW2_TYPES.contains(&pool.pool_type.as_str()) { &["qcow2", "raw"] } else { &["raw"] }
}

/// PVE: the name a new volume is given, with the format as its extension on
/// a file-based storage (PVE refuses one without it there).
pub fn volume_file_name(pool: &Pool, name: &str, format: &str) -> String {
    if !QCOW2_TYPES.contains(&pool.pool_type.as_str()) {
        return name.to_owned();
    }
    let ext = format!(".{format}");
    if name.ends_with(&ext) { name.to_owned() } else { format!("{name}{ext}") }
}

/// Whether a volume of `pool` can be grown on its own: libvirt only for a
/// pool of files (a `logical` pool has no capacity change at all: "storage
/// pool does not support changing of volume capacity", libvirt 11.3); PVE
/// resizes a disk on any storage, through the guest.
pub fn volume_resizable(pool: &Pool, host: HostKind) -> bool {
    host == HostKind::Pve || ["dir", "fs", "netfs"].contains(&pool.pool_type.as_str())
}

/// Whether `pool` takes uploads of install media: PVE by its content kinds
/// (`iso`, `vztmpl`); libvirt pools hold any file, and every active pool
/// whose volumes are files takes one.
pub fn pool_takes_media(pool: &Pool) -> bool {
    if !pool.active {
        return false;
    }
    if pool.node.is_some() {
        return pool.content.iter().any(|c| c == "iso" || c == "vztmpl");
    }
    !DEVICE_POOLS.contains(&pool.pool_type.as_str())
}

/// The VMID a PVE volume name belongs to (`vm-105-disk-0`); None when it is
/// not one.
pub fn pve_volume_vmid(name: &str) -> Option<u32> {
    let rest = name.strip_prefix("vm-").or_else(|| name.strip_prefix("base-"))?;
    let (vmid, tail) = rest.split_once('-')?;
    if vmid.is_empty() || !vmid.bytes().all(|b| b.is_ascii_digit()) || tail.is_empty() || !tail.bytes().all(volume_char) {
        return None;
    }
    vmid.parse().ok()
}

fn volume_char(b: u8) -> bool {
    b.is_ascii_alphanumeric() || matches!(b, b'.' | b'_' | b'-')
}

/// `first` then up to `max - 1` of `rest`, by byte.
fn shaped(s: &str, first: impl Fn(u8) -> bool, rest: impl Fn(u8) -> bool, max: usize) -> bool {
    let b = s.as_bytes();
    !b.is_empty() && b.len() <= max && first(b[0]) && b[1..].iter().all(|&c| rest(c))
}

/// libvirt pool and network names: what [`crate::libvirt::manage`] takes.
pub fn libvirt_resource_name(s: &str) -> bool {
    shaped(s, |c| c.is_ascii_alphanumeric(), |c| c.is_ascii_alphanumeric() || matches!(c, b'.' | b'_' | b'-'), 64)
}

/// libvirt volume names, and what an upload may be called: a file name.
pub fn libvirt_volume_name(s: &str) -> bool {
    shaped(s, |c| c.is_ascii_alphanumeric(), |c| c.is_ascii_alphanumeric() || matches!(c, b'.' | b'_' | b'+' | b'-'), 200)
}

/// PVE storage ids (`pve-storage-id`).
pub fn pve_storage_id(s: &str) -> bool {
    let b = s.as_bytes();
    b.len() >= 2
        && b[0].is_ascii_lowercase()
        && (b[b.len() - 1].is_ascii_lowercase() || b[b.len() - 1].is_ascii_digit())
        && b.iter().all(|&c| c.is_ascii_lowercase() || c.is_ascii_digit() || matches!(c, b'_' | b'.' | b'-'))
}

/// PVE interface names (`pve-iface`), within Linux's 15 characters.
pub fn pve_bridge_name(s: &str) -> bool {
    s.len() >= 2 && shaped(s, |c| c.is_ascii_alphabetic(), |c| c.is_ascii_alphanumeric() || c == b'_', 15)
}

/// A host interface name, as a bridge's port or a host bridge.
fn ifname(s: &str) -> bool {
    shaped(s, |c| c.is_ascii_alphanumeric(), |c| c.is_ascii_alphanumeric() || matches!(c, b'_' | b'.' | b'-'), 15)
}

/// A dnsmasq host name: what libvirt writes into a static entry's `name`.
fn host_name(s: &str) -> bool {
    let word = |c: u8| c.is_ascii_alphanumeric() || c == b'_';
    shaped(s, word, |c| word(c) || c == b'-', 63)
}

fn mac(s: &str) -> bool {
    let parts: Vec<&str> = s.split(':').collect();
    parts.len() == 6 && parts.iter().all(|p| p.len() == 2 && p.bytes().all(|b| b.is_ascii_hexdigit()))
}

/// A volume group, a ZFS pool, a thin pool: one word.
fn token(s: &str) -> bool {
    shaped(s, |c| c.is_ascii_alphanumeric(), |c| c.is_ascii_alphanumeric() || matches!(c, b'+' | b'_' | b'.' | b'-'), usize::MAX)
}

fn absolute(p: &str) -> bool {
    p.starts_with('/') && p.len() > 1 && !p.split('/').any(|c| c == "..") && !p.chars().any(|c| (c as u32) < 0x20)
}

/// `host:/export`, the host a name, an IPv4 address or a bracketed IPv6 one.
fn nfs_source(s: &str) -> bool {
    let Some(at) = s.find(":/") else { return false };
    at > 0
        && s[..at].bytes().all(|c| c.is_ascii_alphanumeric() || matches!(c, b'.' | b':' | b'[' | b']' | b'-'))
        && absolute(&s[at + 1..])
}

/// Why `change` cannot be made on a host of `host`; None when it can.
/// `list` is the host's, for the targets, the names and subnets taken, and
/// what uses what.
pub fn issue(change: &Change, host: HostKind, list: Listing<'_>) -> Option<Issue> {
    let pve = host == HostKind::Pve;
    let pool = |id: &str| list.pools.iter().find(|p| p.id == id);
    let volume = |id: &str| list.volumes.iter().find(|v| v.id == id);
    let network = |id: &str| list.networks.iter().find(|n| n.id == id);
    macro_rules! found {
        ($e:expr) => {
            match $e {
                Some(v) => v,
                None => return Some(Issue::NotFound),
            }
        };
    }
    match change {
        Change::PoolCreate { name, pool_type, source, target, .. } => {
            if name.is_empty() {
                return Some(Issue::NameEmpty);
            }
            if !(if pve { pve_storage_id(name) } else { libvirt_resource_name(name) }) {
                return Some(Issue::NameInvalid);
            }
            // PVE storage ids are the cluster's; libvirt names the host's.
            if list.pools.iter().any(|p| &p.name == name) {
                return Some(Issue::NameTaken);
            }
            let ok = match pool_type.as_str() {
                "dir" => absolute(source),
                "netfs" | "nfs" => nfs_source(source),
                "logical" => token(source),
                "lvmthin" => {
                    let parts: Vec<&str> = source.split('/').collect();
                    parts.len() == 2 && parts.iter().all(|p| token(p))
                }
                "zfspool" => source.split('/').all(token),
                _ => false,
            };
            if !ok {
                return Some(Issue::SourceInvalid);
            }
            if pool_type == "netfs" && !absolute(target.as_deref().unwrap_or_default()) {
                return Some(Issue::TargetInvalid);
            }
        }
        Change::VolumeCreate { pool: id, name, gib, format } => {
            let pool = found!(pool(id));
            if name.is_empty() {
                return Some(Issue::NameEmpty);
            }
            if !(if pve { pve_volume_vmid(name).is_some() } else { libvirt_volume_name(name) }) {
                return Some(Issue::NameInvalid);
            }
            let file = if pve { volume_file_name(pool, name, format) } else { name.clone() };
            if list.volumes.iter().any(|v| v.name == file || &v.name == name) {
                return Some(Issue::NameTaken);
            }
            if !volume_formats(pool).contains(&format.as_str()) {
                return Some(Issue::Format);
            }
            if !(1..=65536).contains(gib) {
                return Some(Issue::Size);
            }
            // A thin volume takes nothing yet — a qcow2 file, or anything in
            // an LVM thin pool, whose only format is raw; a raw file or a
            // plain LV takes it all.
            if format == "raw" && pool.pool_type != "lvmthin" && pool.available.is_some_and(|free| gib << 30 > free) {
                return Some(Issue::Space);
            }
        }
        Change::VolumeDelete { pool: p, volume: v } => {
            found!(pool(p));
            if found!(volume(v)).in_use() {
                return Some(Issue::InUse);
            }
        }
        Change::VolumeResize { pool: p, volume: v, bytes } => {
            let pool = found!(pool(p));
            let volume = found!(volume(v));
            if pve || !volume_resizable(pool, host) {
                // PVE grows a disk through its guest's hardware.
                return Some(Issue::Unsupported);
            }
            if !volume.users.is_empty() {
                return Some(Issue::InUse);
            }
            if *bytes <= volume.capacity.unwrap_or(0) {
                return Some(Issue::Shrink);
            }
            if *bytes > 1 << 50 {
                return Some(Issue::Size);
            }
        }
        Change::VolumeClone { pool: p, volume: v, name } => {
            found!(pool(p));
            found!(volume(v));
            if pve {
                return Some(Issue::Unsupported);
            }
            if name.is_empty() {
                return Some(Issue::NameEmpty);
            }
            if !libvirt_volume_name(name) {
                return Some(Issue::NameInvalid);
            }
            if list.volumes.iter().any(|v| &v.name == name) {
                return Some(Issue::NameTaken);
            }
        }
        Change::PoolSetActive { pool: p, active } => {
            found!(pool(p));
            if !active && list.volumes.iter().any(Volume::in_use) {
                return Some(Issue::InUse);
            }
        }
        Change::PoolDelete { pool: p, .. } => {
            found!(pool(p));
            if list.volumes.iter().any(Volume::in_use) {
                return Some(Issue::InUse);
            }
        }
        Change::PoolSetAutostart { pool: p, .. } | Change::PoolRefresh { pool: p } => {
            found!(pool(p));
            if pve && matches!(change, Change::PoolSetAutostart { .. }) {
                return Some(Issue::Unsupported);
            }
        }
        Change::NetworkCreate { name, mode, node, bridge, cidr, dhcp_start, dhcp_end, .. } => {
            if name.is_empty() {
                return Some(Issue::NameEmpty);
            }
            if !(if pve { pve_bridge_name(name) } else { libvirt_resource_name(name) }) {
                return Some(Issue::NameInvalid);
            }
            if pve && (mode != "bridge" || node.is_none()) {
                return Some(Issue::Unsupported);
            }
            if list.networks.iter().any(|n| &n.name == name && (!pve || &n.node == node)) {
                return Some(Issue::NameTaken);
            }
            let ports = bridge.as_deref().unwrap_or_default().trim();
            if !pve && mode == "bridge" {
                return (!ifname(ports)).then_some(Issue::BridgeInvalid);
            }
            if pve && !ports.is_empty() && !ports.split_whitespace().all(ifname) {
                return Some(Issue::BridgeInvalid);
            }
            let c = cidr.as_deref().unwrap_or_default().trim();
            if c.is_empty() {
                if !pve && (mode == "nat" || mode == "route") {
                    return Some(Issue::CidrInvalid);
                }
                // A DHCP range is served on the network's own subnet: with
                // none, the host refuses it.
                if !pve && (dhcp_start.is_some() || dhcp_end.is_some()) {
                    return Some(Issue::DhcpInvalid);
                }
                return None;
            }
            let (address, prefix) = match ipv4::parse_cidr(c) {
                Some(parsed) => parsed,
                None => return Some(Issue::CidrInvalid),
            };
            let taken = list
                .networks
                .iter()
                .filter(|n| !pve || &n.node == node)
                .any(|n| n.cidrs.iter().any(|other| ipv4::overlaps(other, c)));
            if taken {
                return Some(Issue::SubnetTaken);
            }
            if pve || (dhcp_start.is_none() && dhcp_end.is_none()) {
                return None;
            }
            if !ipv4::dhcp_fits(address, prefix, dhcp_start.as_deref(), dhcp_end.as_deref()) {
                return Some(Issue::DhcpInvalid);
            }
        }
        Change::NetworkEdit { network: id, mode, bridge, address, prefix, dhcp_start, dhcp_end, hosts, .. } => {
            let network = found!(network(id));
            if pve {
                return Some(Issue::Unsupported);
            }
            if mode == "bridge" && !ifname(bridge.as_deref().unwrap_or_default().trim()) {
                return Some(Issue::BridgeInvalid);
            }
            // The address comes without its prefix (as the listing has it),
            // the prefix on its own: checked as the one CIDR they make.
            let bare = address.as_deref().unwrap_or_default().trim();
            let c = if bare.is_empty() {
                String::new()
            } else {
                format!("{bare}/{}", prefix.map(|p| p.to_string()).unwrap_or_default())
            };
            let mut subnet = None;
            if mode != "bridge" {
                if c.is_empty() {
                    if mode != "isolated" {
                        return Some(Issue::CidrInvalid);
                    }
                    if dhcp_start.is_some() || dhcp_end.is_some() {
                        return Some(Issue::DhcpInvalid);
                    }
                } else {
                    let Some((addr, pfx)) = ipv4::parse_cidr(&c) else { return Some(Issue::CidrInvalid) };
                    subnet = Some((addr, pfx));
                    // Its own subnet is not somebody else's.
                    let taken = list
                        .networks
                        .iter()
                        .filter(|n| n.id != network.id)
                        .any(|n| n.cidrs.iter().any(|other| ipv4::overlaps(other, &c)));
                    if taken {
                        return Some(Issue::SubnetTaken);
                    }
                    if (dhcp_start.is_some() || dhcp_end.is_some())
                        && !ipv4::dhcp_fits(addr, pfx, dhcp_start.as_deref(), dhcp_end.as_deref())
                    {
                        return Some(Issue::DhcpInvalid);
                    }
                }
            }
            let mut macs = std::collections::HashSet::new();
            let mut ips = std::collections::HashSet::new();
            for h in hosts {
                let ip = ipv4::parse_ipv4(&h.ip);
                // Handed out on the network's own subnet, off its own
                // addresses: without one (or outside it) dnsmasq never
                // serves it.
                let in_subnet = match (subnet, ip) {
                    (Some((addr, pfx)), Some(ip)) => {
                        let m = ipv4::mask(pfx);
                        ip & m == addr & m && ip != addr && ip != addr & m && ip != (addr & m) | !m
                    }
                    _ => false,
                };
                let named_ok = h.name.as_deref().is_none_or(|n| n.is_empty() || host_name(n));
                if !mac(&h.mac)
                    || !in_subnet
                    || !ips.insert(ip)
                    || !macs.insert(h.mac.to_ascii_lowercase())
                    || !named_ok
                {
                    return Some(Issue::HostInvalid);
                }
            }
            // A bridge hands guests to the host's own network; it serves no
            // DHCP of its own.
            if !hosts.is_empty() && mode == "bridge" {
                return Some(Issue::HostInvalid);
            }
        }
        Change::NetworkEditBridge { network: id, cidr, gateway, .. } => {
            let network = found!(network(id));
            if !pve {
                return Some(Issue::Unsupported);
            }
            if !network.management_editable {
                return Some(Issue::ManagementIface);
            }
            let c = cidr.as_deref().map(str::trim).unwrap_or_default();
            if !c.is_empty() && ipv4::parse_cidr(c).is_none() {
                return Some(Issue::CidrInvalid);
            }
            if gateway.as_deref().is_some_and(|g| !g.is_empty() && ipv4::parse_ipv4(g).is_none()) {
                return Some(Issue::CidrInvalid);
            }
        }
        Change::NetworkDelete { network: id } => {
            let network = found!(network(id));
            if !network.users.is_empty() {
                return Some(Issue::InUse);
            }
            if !network.management_editable {
                return Some(Issue::ManagementIface);
            }
        }
        Change::NetworkSetActive { network: id, active } => {
            let network = found!(network(id));
            if pve {
                return Some(Issue::Unsupported);
            }
            if !active && !network.users.is_empty() {
                return Some(Issue::InUse);
            }
        }
        Change::NetworkSetAutostart { network: id, .. } | Change::NetworkRestart { network: id, .. } => {
            found!(network(id));
            if pve {
                return Some(Issue::Unsupported);
            }
        }
        Change::NetworkApply { .. } | Change::NetworkRevert { .. } => {
            if !pve {
                return Some(Issue::Unsupported);
            }
        }
    }
    None
}

/// `issue` as the error a client answers a refused change with: a name
/// taken is [`ErrorKind::Exists`], anything else [`ErrorKind::Unsupported`],
/// both with [`Detail::Refused`] for the client to phrase.
pub fn refusal(issue: Issue) -> Error {
    let kind = if issue == Issue::NameTaken { ErrorKind::Exists } else { ErrorKind::Unsupported };
    Error::detail(kind, Detail::Refused { issue })
}

/// Why an upload of `name` (`size` bytes) into `pool` cannot start; None
/// when it can. `volumes` are the pool's.
pub fn upload_issue(pool: &Pool, name: &str, size: u64, volumes: &[Volume]) -> Option<Issue> {
    if name.is_empty() {
        return Some(Issue::NameEmpty);
    }
    if !libvirt_volume_name(name) {
        return Some(Issue::NameInvalid);
    }
    if volumes.iter().any(|v| v.name == name) {
        return Some(Issue::NameTaken);
    }
    if size == 0 {
        return Some(Issue::Size);
    }
    if pool.available.is_some_and(|free| size > free) {
        return Some(Issue::Space);
    }
    None
}
