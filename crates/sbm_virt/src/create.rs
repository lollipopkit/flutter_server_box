//! Making, copying and deleting guests, for either backend: what a new
//! guest is ([`CreateSpec`]), a copy of one ([`CloneRequest`]), what a host
//! offers a new one ([`CreateOptions`]), and the rules each is checked by
//! before anything is sent ([`create_issue`], [`clone_issue`]).
//!
//! A pool, a volume and a network are named by their id, and what the host
//! lists at the moment of the request is what it is checked against and
//! made on. PVE: [`crate::pve::client::Client::create`] and its neighbours;
//! libvirt: the scripts in [`crate::libvirt`], mapped from these in
//! [`crate::libvirt::host`].
//!
//! Ported from the app's `lib/data/model/virt/virt_create.dart`.

use serde::{Deserialize, Serialize};

use crate::error::{Detail, Error, ErrorKind};
use crate::model::{Guest, GuestKind, GuestState, HostKind, Node};
use crate::resource::{Network, Pool, Volume};

fn yes() -> bool {
    true
}

/// A volume of a pool's: both ids, as the host lists them. A PVE volid is
/// the same on every node that sees its storage; the pool says which.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct VolumeRef {
    pub pool: String,
    pub volume: String,
}

/// What a new VM's cloud-init sets up: an account with sudo, how to log in
/// to it, the hostname and the one NIC's address.
#[derive(Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct CloudInit {
    pub user: String,
    /// Never sent as it is to libvirt: hashed first (SHA-512 crypt), and
    /// only the hash written to the host. PVE takes it in the request body
    /// and hashes it itself. Never logged.
    #[serde(default)]
    pub password: Option<String>,
    /// OpenSSH public keys; blank entries are ignored.
    #[serde(default)]
    pub ssh_keys: Vec<String>,
    /// libvirt; PVE's cloud-init uses the VM's name.
    #[serde(default)]
    pub hostname: Option<String>,
    /// IPv4 with its prefix (`10.0.0.5/24`); None for DHCP.
    #[serde(default)]
    pub address: Option<String>,
    #[serde(default)]
    pub gateway: Option<String>,
    #[serde(default)]
    pub dns: Vec<String>,
    /// The search domains, in order.
    #[serde(default)]
    pub search_domains: Vec<String>,
}

impl CloudInit {
    /// The keys, trimmed, blank ones left out.
    pub fn keys(&self) -> Vec<&str> {
        self.ssh_keys.iter().map(|k| k.trim()).filter(|k| !k.is_empty()).collect()
    }

    fn password(&self) -> Option<&str> {
        self.password.as_deref().filter(|p| !p.is_empty())
    }
}

impl std::fmt::Debug for CloudInit {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CloudInit")
            .field("user", &self.user)
            .field("password", &self.password.as_ref().map(|_| "[redacted]"))
            .field("keys", &self.keys().len())
            .field("hostname", &self.hostname)
            .field("address", &self.address.as_deref().unwrap_or("dhcp"))
            .finish()
    }
}

/// A guest to create.
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CreateSpec {
    pub kind: GuestKind,
    /// A VM's name, a container's hostname.
    pub name: String,
    /// PVE: the node it is created on.
    #[serde(default)]
    pub node: Option<String>,
    /// PVE: its VMID; None takes the cluster's next free one.
    #[serde(default)]
    pub vmid: Option<u32>,
    pub cores: u32,
    pub memory_mib: u64,
    /// The pool the disk (a container's root filesystem) is made in.
    pub storage: String,
    pub disk_gib: u64,
    /// A VM's install media (an ISO), a container's template.
    #[serde(default)]
    pub media: Option<VolumeRef>,
    /// A cloud image the VM's disk is a copy of, grown to `disk_gib`: a disk
    /// with a system on it already, set up at its first boot by
    /// `cloud_init`. Never with `media`.
    #[serde(default)]
    pub image: Option<VolumeRef>,
    /// The one NIC's network (libvirt) or bridge (PVE, the node's); None
    /// for no NIC.
    #[serde(default)]
    pub network: Option<String>,
    /// A container's root password and SSH public keys. Sent in the request
    /// body only, never logged.
    #[serde(default)]
    pub password: Option<String>,
    #[serde(default)]
    pub ssh_keys: Vec<String>,
    /// A container whose root is an unprivileged user on the host.
    #[serde(default = "yes")]
    pub unprivileged: bool,
    /// A VM's disk bus and NIC model ([`CreateOptions`]); None for the
    /// host's default, the first offered.
    #[serde(default)]
    pub bus: Option<String>,
    #[serde(default)]
    pub nic_model: Option<String>,
    /// A VM booting from UEFI, with Secure Boot or without, and with a TPM
    /// 2.0.
    #[serde(default)]
    pub uefi: bool,
    #[serde(default)]
    pub secure_boot: bool,
    #[serde(default)]
    pub tpm: bool,
    /// What a cloud `image` is told at its first boot.
    #[serde(default)]
    pub cloud_init: Option<CloudInit>,
    /// Started once created.
    #[serde(default)]
    pub start: bool,
}

impl CreateSpec {
    fn keys(&self) -> Vec<&str> {
        self.ssh_keys.iter().map(|k| k.trim()).filter(|k| !k.is_empty()).collect()
    }

    /// One line for an audit log: no password, no key.
    pub fn describe(&self) -> String {
        let what = match self.kind {
            GuestKind::Qemu => "vm",
            GuestKind::Lxc => "container",
        };
        match self.vmid {
            Some(vmid) => format!("create {what} {} ({vmid})", self.name),
            None => format!("create {what} {}", self.name),
        }
    }
}

impl std::fmt::Debug for CreateSpec {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("CreateSpec")
            .field("kind", &self.kind)
            .field("name", &self.name)
            .field("node", &self.node)
            .field("vmid", &self.vmid)
            .field("storage", &self.storage)
            .field("media", &self.media)
            .field("image", &self.image)
            .field("network", &self.network)
            .field("password", &self.password.as_ref().map(|_| "[redacted]"))
            .field("cloud_init", &self.cloud_init)
            .finish_non_exhaustive()
    }
}

/// What a new VM on this host can be given, beyond what every host offers.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct CreateOptions {
    /// Disk buses, the default first.
    pub buses: Vec<String>,
    /// NIC models, the default first.
    pub nic_models: Vec<String>,
    /// UEFI firmware is installed (libvirt: OVMF), and a software TPM
    /// (swtpm).
    pub uefi: bool,
    pub tpm: bool,
    /// Secure Boot can be turned on: the host has a firmware that carries
    /// its enrolled keys. libvirt: a descriptor under
    /// [`crate::libvirt::QEMU_FIRMWARE_DIR`] with both `secure-boot` and
    /// `enrolled-keys` (without one, firmware autoselection finds nothing
    /// and libvirt refuses the definition). PVE: `efidisk0` with
    /// `pre-enrolled-keys=1`, which its own UEFI default writes.
    pub secure_boot: bool,
    /// A VM's disk can be a copy of a cloud image.
    pub cloud_images: bool,
    /// A cloud image can be set up with cloud-init; where not,
    /// `cloud_init_missing` says what the host lacks.
    pub cloud_init: bool,
    pub cloud_init_missing: Option<String>,
}

/// What creating a guest came to.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Created {
    /// The new guest's [`Guest::id`].
    pub id: String,
    /// Created, but it did not start: the host's words.
    pub start_error: Option<String>,
    /// A cloud image bigger than the disk asked for: the disk is the image's
    /// size, this. A disk is grown, never cut — cutting it would cut the
    /// system on it.
    pub disk_kept_bytes: Option<u64>,
}

/// A copy of a guest.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CloneRequest {
    /// A VM's name, a container's hostname: the same rules as a new guest's.
    pub name: String,
    /// PVE: a full clone, or a linked one sharing the template's disks
    /// (templates only). libvirt: each disk's contents copied, or an empty
    /// disk of the same size.
    #[serde(default = "yes")]
    pub full: bool,
    /// PVE: the new guest's VMID; None takes the cluster's next free one.
    #[serde(default)]
    pub vmid: Option<u32>,
    /// PVE: the storage the copy's disks go to, None for the ones the
    /// source's are on. A linked clone cannot name one.
    #[serde(default)]
    pub storage: Option<String>,
    /// PVE: the node the copy is made on, None for the source's. Needs a
    /// cluster and shared storage.
    #[serde(default)]
    pub target_node: Option<String>,
    /// libvirt: the pool the copy's disks go in, None for each disk's own.
    #[serde(default)]
    pub target_pool: Option<String>,
}

/// Why a guest cannot be created, copied, deleted or made a template. The
/// first that applies wins.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Issue {
    NameEmpty,
    NameInvalid,
    NameTaken,
    VmidInvalid,
    VmidTaken,
    /// PVE: the node is not one of the host's online nodes.
    Node,
    Cores,
    Memory,
    /// Not a pool a new disk of this kind can be made in.
    Storage,
    DiskSize,
    /// A container's template: none picked, or not one.
    Template,
    /// A VM's install media that is not on offer.
    Media,
    /// A container's root login: neither a password nor a key.
    Credentials,
    Password,
    SshKeys,
    /// A cloud image not picked, not one, or bigger than the disk asked for.
    Image,
    ImageSize,
    /// The network is not one a new NIC can be on.
    Network,
    /// Secure Boot asked for without UEFI.
    SecureBoot,
    /// Something the host does not offer a new VM: a bus, a NIC model,
    /// UEFI, a TPM, a cloud image or cloud-init.
    NotOffered,
    /// cloud-init: the account's name, its way in, the hostname, the
    /// address.
    CiUser,
    CiCredentials,
    CiHostname,
    CiAddress,
    CiGateway,
    CiDns,
    CiSearch,
    /// A clone: a linked one cannot name a storage or a node; a storage that
    /// is not there, holds no disks of the guest's kind, or is not shared
    /// while the copy moves to another node; a node the host does not have.
    CloneLinkedTarget,
    CloneStorage,
    CloneStorageContent,
    CloneStorageShared,
    CloneNodeUnknown,
    /// Only a stopped guest: deleting one, making a template of one, a
    /// libvirt copy.
    NotStopped,
    /// Already a template.
    IsTemplate,
    /// The guest (or what the request names) is not, or no longer, on the
    /// host.
    NotFound,
    /// Not something this kind of host does.
    Unsupported,
}

/// `issue` as the error a client answers a refused request with: a name or
/// VMID taken is [`ErrorKind::Exists`], anything else
/// [`ErrorKind::Unsupported`], both with [`Detail::CreateRefused`] for the
/// client to phrase.
pub fn refusal(issue: Issue) -> Error {
    let kind = if matches!(issue, Issue::NameTaken | Issue::VmidTaken) { ErrorKind::Exists } else { ErrorKind::Unsupported };
    Error::detail(kind, Detail::CreateRefused { issue })
}

/// PVE's own floor for a container's root password.
pub const LXC_PASSWORD_MIN: usize = 5;

/// VMIDs PVE accepts.
pub const VMID_MIN: u32 = 100;
pub const VMID_MAX: u32 = 999_999_999;

/// Disk buses and NIC models a new VM can have, the default first. libvirt
/// narrows the buses to what the machine has (q35: no IDE); PVE puts its
/// disk on SCSI.
pub const BUSES: &[&str] = &["virtio", "scsi", "sata", "ide"];
pub const PVE_BUSES: &[&str] = &["scsi", "virtio", "sata", "ide"];
pub const NIC_MODELS: &[&str] = &["virtio", "e1000e", "e1000", "rtl8139"];

/// libvirt: what AppArmor's `virt-aa-helper` accepts (a `"` in a domain
/// name makes it refuse to start the domain), what `vol-create-as` puts in
/// its XML unescaped (`&`, `<`), and what makes a file name: letters,
/// digits, `.`, `_`, `-`, not first a dot or dash.
pub fn libvirt_name(s: &str) -> bool {
    let b = s.as_bytes();
    !b.is_empty()
        && b.len() <= 63
        && b[0].is_ascii_alphanumeric()
        && b.iter().all(|&c| c.is_ascii_alphanumeric() || matches!(c, b'.' | b'_' | b'-'))
}

/// PVE: a DNS name (`pve-configid` `dns-name`) of at most 63 characters,
/// which is what a VM's name and a container's hostname must be.
pub fn pve_name(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 63
        && s.split('.').all(|l| {
            !l.is_empty()
                && l.bytes().all(|c| c.is_ascii_alphanumeric() || c == b'-')
                && !l.starts_with('-')
                && !l.ends_with('-')
        })
}

/// A guest's name as a host of `host` takes it.
pub fn name_ok(name: &str, host: HostKind) -> bool {
    match host {
        HostKind::Pve => pve_name(name),
        HostKind::Libvirt => libvirt_name(name),
    }
}

/// An OpenSSH public key line.
pub fn ssh_key(line: &str) -> bool {
    let mut parts = line.splitn(3, ' ');
    let (Some(kind), Some(body)) = (parts.next(), parts.next()) else { return false };
    let known = matches!(kind, "ssh-rsa" | "ssh-ed25519" | "ssh-dss")
        || kind.strip_prefix("ecdsa-sha2-nistp").is_some_and(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))
        || matches!(kind, "sk-ssh-ed25519@openssh.com" | "sk-ecdsa-sha2-nistp256@openssh.com");
    known && !body.is_empty() && body.bytes().all(|b| b.is_ascii_alphanumeric() || matches!(b, b'+' | b'/' | b'='))
}

/// A Linux account name as `useradd` takes it by default.
pub fn user_name(s: &str) -> bool {
    crate::libvirt::cloud_init::is_user_name(s) && !s.is_empty()
}

fn ipv4(s: &str) -> bool {
    let parts: Vec<&str> = s.split('.').collect();
    parts.len() == 4
        && parts.iter().all(|p| {
            !p.is_empty() && p.len() <= 3 && p.bytes().all(|b| b.is_ascii_digit()) && (p.len() == 1 || !p.starts_with('0')) && p.parse::<u16>().is_ok_and(|n| n <= 255)
        })
}

fn ip(s: &str) -> bool {
    ipv4(s) || (s.contains(':') && s.parse::<std::net::Ipv6Addr>().is_ok())
}

/// The content kind a guest's disks are kept as on PVE: a container's root
/// filesystem is `rootdir`, a VM's disk `images`.
fn disk_content(kind: GuestKind) -> &'static str {
    match kind {
        GuestKind::Lxc => "rootdir",
        GuestKind::Qemu => "images",
    }
}

/// libvirt pools of whole devices, LUNs, multipath and SCSI adapters: they
/// hold volumes the host made, not ones `vol-create-as` can.
const LIBVIRT_NO_CREATE: [&str; 5] = ["disk", "iscsi", "iscsi-direct", "scsi", "mpath"];

/// libvirt pools whose volumes are raw: block devices and datasets.
const LIBVIRT_RAW_ONLY: [&str; 4] = ["logical", "zfs", "rbd", "vstorage"];

/// The image format a libvirt pool of `pool_type` takes: qcow2 (thin,
/// snapshots) where it can.
pub fn libvirt_disk_format(pool_type: &str) -> &'static str {
    if LIBVIRT_RAW_ONLY.contains(&pool_type) { "raw" } else { "qcow2" }
}

fn pve_usable(p: &Pool, node: Option<&str>) -> bool {
    p.active && p.node.as_deref() == node && p.enabled != Some(false)
}

/// Where a new `kind` guest's disk can go on a host of `host` (`node` for
/// PVE).
pub fn disk_storages<'a>(pools: &'a [Pool], host: HostKind, kind: GuestKind, node: Option<&str>) -> Vec<&'a Pool> {
    pools
        .iter()
        .filter(|p| match host {
            HostKind::Pve => pve_usable(p, node) && p.content.iter().any(|c| c == disk_content(kind)),
            HostKind::Libvirt => p.active && !LIBVIRT_NO_CREATE.contains(&p.pool_type.as_str()),
        })
        .collect()
}

/// Where install media (a VM's ISOs) or templates (a container's) are found
/// on a host of `host` (`node` for PVE). libvirt keeps no content kinds:
/// every active pool is looked in, and [`is_media`] picks the ISOs.
pub fn media_storages<'a>(pools: &'a [Pool], host: HostKind, kind: GuestKind, node: Option<&str>) -> Vec<&'a Pool> {
    let content = match kind {
        GuestKind::Lxc => "vztmpl",
        GuestKind::Qemu => "iso",
    };
    pools
        .iter()
        .filter(|p| match host {
            HostKind::Pve => pve_usable(p, node) && p.content.iter().any(|c| c == content),
            HostKind::Libvirt => p.active,
        })
        .collect()
}

/// Where cloud images are found: a PVE storage with `import` content (what
/// `import-from` takes, PVE 8.2+); every active libvirt pool.
pub fn image_storages<'a>(pools: &'a [Pool], host: HostKind, node: Option<&str>) -> Vec<&'a Pool> {
    pools
        .iter()
        .filter(|p| match host {
            HostKind::Pve => pve_usable(p, node) && p.content.iter().any(|c| c == "import"),
            HostKind::Libvirt => p.active,
        })
        .collect()
}

/// Whether `volume` is install media (a VM) or a template (a container).
pub fn is_media(volume: &Volume, kind: GuestKind) -> bool {
    if let Some(content) = &volume.content {
        return content == if kind == GuestKind::Lxc { "vztmpl" } else { "iso" };
    }
    kind == GuestKind::Qemu && (volume.format.as_deref() == Some("iso") || volume.name.to_ascii_lowercase().ends_with(".iso"))
}

/// Whether `volume` is a disk image a new VM can be a copy of: PVE's
/// `import` content in a format QEMU reads (not an OVA, which carries a
/// machine of its own); on libvirt a qcow2 or raw volume no guest uses — a
/// disk in use would be copied mid-write — and not an ISO.
pub fn is_cloud_image(volume: &Volume, host: HostKind) -> bool {
    let format = volume.format.as_deref().unwrap_or_default();
    match host {
        HostKind::Pve => volume.content.as_deref() == Some("import") && matches!(format, "qcow2" | "raw" | "vmdk"),
        HostKind::Libvirt => {
            matches!(format, "qcow2" | "raw") && volume.users.is_empty() && !volume.name.to_ascii_lowercase().ends_with(".iso")
        }
    }
}

/// The networks a new guest's NIC can be on: libvirt's active networks
/// (not a `hostdev` one, which hands out whole devices), a PVE node's
/// bridges.
pub fn create_networks<'a>(networks: &'a [Network], host: HostKind, node: Option<&str>) -> Vec<&'a Network> {
    networks
        .iter()
        .filter(|n| {
            n.active
                && match host {
                    HostKind::Pve => n.node.as_deref() == node && matches!(n.mode.as_str(), "bridge" | "OVSBridge"),
                    HostKind::Libvirt => n.mode != "hostdev",
                }
        })
        .collect()
}

/// What a new guest is checked against: the host's guests, nodes, pools and
/// networks, the volumes the spec's `media` and `image` name (None where
/// the pool does not list them), and what the host offers a new VM.
#[derive(Debug, Clone, Copy)]
pub struct CreateListing<'a> {
    pub guests: &'a [Guest],
    pub nodes: &'a [Node],
    pub pools: &'a [Pool],
    pub networks: &'a [Network],
    pub media: Option<&'a Volume>,
    pub image: Option<&'a Volume>,
    pub options: &'a CreateOptions,
}

/// Why `spec` cannot be created on a host of `host`; None when it can.
pub fn create_issue(spec: &CreateSpec, host: HostKind, list: CreateListing<'_>) -> Option<Issue> {
    let pve = host == HostKind::Pve;
    let qemu = spec.kind == GuestKind::Qemu;
    let name = spec.name.as_str();
    if name.is_empty() {
        return Some(Issue::NameEmpty);
    }
    if !name_ok(name, host) {
        return Some(Issue::NameInvalid);
    }
    // PVE lets two guests share a name; one list with two of a name is a
    // question nobody wants to answer later.
    if list.guests.iter().any(|g| g.name == name) {
        return Some(Issue::NameTaken);
    }
    let node = if pve {
        if let Some(vmid) = spec.vmid {
            if !(VMID_MIN..=VMID_MAX).contains(&vmid) {
                return Some(Issue::VmidInvalid);
            }
            if list.guests.iter().any(|g| g.vmid == Some(vmid)) {
                return Some(Issue::VmidTaken);
            }
        }
        match list.nodes.iter().find(|n| n.online && Some(&n.name) == spec.node.as_ref()) {
            Some(n) => Some(n),
            None => return Some(Issue::Node),
        }
    } else {
        if !qemu {
            return Some(Issue::Unsupported);
        }
        None
    };
    let max_cores = node.and_then(|n| n.max_cpu).unwrap_or(512);
    if spec.cores < 1 || spec.cores > max_cores {
        return Some(Issue::Cores);
    }
    if qemu {
        // Secure Boot is UEFI's: a BIOS guest has nothing to enable it on.
        if spec.secure_boot && !spec.uefi {
            return Some(Issue::SecureBoot);
        }
        let o = list.options;
        let offered = |chosen: &Option<String>, all: &[String]| chosen.as_ref().is_none_or(|c| all.contains(c));
        if !offered(&spec.bus, &o.buses)
            || !offered(&spec.nic_model, &o.nic_models)
            || (spec.uefi && !o.uefi)
            || (spec.secure_boot && !o.secure_boot)
            || (spec.tpm && !o.tpm)
            || (spec.image.is_some() && !o.cloud_images)
            || (spec.cloud_init.is_some() && !o.cloud_init)
        {
            return Some(Issue::NotOffered);
        }
        if spec.image.is_some() && spec.media.is_some() {
            return Some(Issue::Image);
        }
        if spec.cloud_init.is_some() && spec.image.is_none() {
            return Some(Issue::Image);
        }
        if let Some(r) = &spec.image {
            let node = spec.node.as_deref();
            let image = match list.image {
                Some(v) if image_storages(list.pools, host, node).iter().any(|p| p.id == r.pool) && is_cloud_image(v, host) => v,
                _ => return Some(Issue::Image),
            };
            // A copy is grown, never cut.
            if image.capacity.is_some_and(|bytes| bytes > spec.disk_gib << 30) {
                return Some(Issue::ImageSize);
            }
        }
        if let Some(ci) = &spec.cloud_init {
            // No hostname of its own: the VM's name is the one written.
            let named = CloudInit { hostname: ci.hostname.clone().or_else(|| Some(spec.name.clone())), ..ci.clone() };
            if let Some(i) = cloud_init_issue(&named, host, false) {
                return Some(i);
            }
        }
    }
    let min_mem = if qemu { 128 } else { 64 };
    if spec.memory_mib < min_mem || spec.memory_mib > 16 << 20 {
        return Some(Issue::Memory);
    }
    let node = spec.node.as_deref().filter(|_| pve);
    if !disk_storages(list.pools, host, spec.kind, node).iter().any(|p| p.id == spec.storage) {
        return Some(Issue::Storage);
    }
    if !(1..=65536).contains(&spec.disk_gib) {
        return Some(Issue::DiskSize);
    }
    let media_ok = |r: &VolumeRef| {
        media_storages(list.pools, host, spec.kind, node).iter().any(|p| p.id == r.pool)
            && list.media.is_some_and(|v| is_media(v, spec.kind))
    };
    if qemu {
        if spec.media.as_ref().is_some_and(|r| !media_ok(r)) {
            return Some(Issue::Media);
        }
    } else {
        if !spec.media.as_ref().is_some_and(media_ok) {
            return Some(Issue::Template);
        }
        let password = spec.password.as_deref().unwrap_or_default();
        let keys = spec.keys();
        if password.is_empty() && keys.is_empty() {
            return Some(Issue::Credentials);
        }
        if !password.is_empty() && password.chars().count() < LXC_PASSWORD_MIN {
            return Some(Issue::Password);
        }
        if !keys.iter().all(|k| ssh_key(k)) {
            return Some(Issue::SshKeys);
        }
    }
    if let Some(net) = &spec.network
        && !create_networks(list.networks, host, node).iter().any(|n| &n.id == net)
    {
        return Some(Issue::Network);
    }
    None
}

/// Why `ci` cannot be sent; None when it can. Checked where a cloud image
/// is created ([`create_issue`]) and where its settings are edited;
/// `keeps_password`: the account has a password already, which stays.
pub fn cloud_init_issue(ci: &CloudInit, host: HostKind, keeps_password: bool) -> Option<Issue> {
    if !user_name(&ci.user) {
        return Some(Issue::CiUser);
    }
    let keys = ci.keys();
    if ci.password().is_none() && !keeps_password && keys.is_empty() {
        return Some(Issue::CiCredentials);
    }
    if !keys.iter().all(|k| ssh_key(k)) {
        return Some(Issue::SshKeys);
    }
    if host == HostKind::Libvirt && !pve_name(ci.hostname.as_deref().unwrap_or_default()) {
        return Some(Issue::CiHostname);
    }
    if let Some(address) = &ci.address {
        let ok = match address.split_once('/') {
            Some((a, p)) => ipv4(a) && p.parse::<u8>().is_ok_and(|p| (1..=32).contains(&p)) && !p.starts_with('+'),
            None => false,
        };
        if !ok {
            return Some(Issue::CiAddress);
        }
        if ci.gateway.as_deref().is_some_and(|g| !ipv4(g)) {
            return Some(Issue::CiGateway);
        }
    }
    if !ci.dns.iter().all(|d| ip(d)) {
        return Some(Issue::CiDns);
    }
    if !ci.search_domains.iter().all(|d| pve_name(d)) {
        return Some(Issue::CiSearch);
    }
    None
}

/// Why a clone cannot go to `storage` on `target_node`, or None. The checks
/// are the ones PVE makes before it starts the clone task, so its refusals
/// are said before the task: a linked clone cannot name a storage
/// (`parameter 'storage' not allowed for linked clones`), a storage that
/// holds no disks of `kind`'s (`does not support vm images`; a container's
/// are `rootdir`), and a copy moving to another node needs a storage both
/// see (`can't clone VM to node '<n>' (VM uses local storage)`). `storages`
/// are the ones on the source's node; `storage` is a storage's name.
pub fn clone_storage_issue(
    storages: &[&Pool],
    storage: Option<&str>,
    full: bool,
    kind: GuestKind,
    target_node: Option<&str>,
) -> Option<Issue> {
    if !full && storage.is_some() {
        return Some(Issue::CloneLinkedTarget);
    }
    let storage = storage?;
    let Some(pool) = storages.iter().find(|p| p.name == storage) else {
        return Some(Issue::CloneStorage);
    };
    if !pool.content.iter().any(|c| c == disk_content(kind)) {
        return Some(Issue::CloneStorageContent);
    }
    if target_node.is_some() && pool.shared != Some(true) {
        return Some(Issue::CloneStorageShared);
    }
    None
}

/// Why `target_node` cannot be a clone's node, or None: the host has to
/// have it. PVE answers `no such cluster node '<name>'` — on a single node,
/// for any other name. With nothing known of the nodes, the host answers.
pub fn clone_node_issue(nodes: &[Node], target_node: Option<&str>, source_node: Option<&str>) -> Option<Issue> {
    let target = target_node?;
    if Some(target) == source_node || nodes.is_empty() || nodes.iter().any(|n| n.name == target) {
        return None;
    }
    Some(Issue::CloneNodeUnknown)
}

/// What a clone is checked against: the host's guests, nodes and pools.
#[derive(Debug, Clone, Copy)]
pub struct CloneListing<'a> {
    pub guests: &'a [Guest],
    pub nodes: &'a [Node],
    pub pools: &'a [Pool],
}

/// The request as it is sent: a PVE guest that is not a template has only
/// full clones, and a linked one names no storage or node.
pub fn clone_full(guest: &Guest, request: &CloneRequest, host: HostKind) -> bool {
    match host {
        HostKind::Libvirt => request.full,
        HostKind::Pve => request.full || !guest.template,
    }
}

/// Why `guest` cannot be copied as `request` asks on a host of `host`, or
/// None. libvirt copies a disk only while nothing writes to it; PVE clones
/// a running guest through a snapshot of its own.
pub fn clone_issue(guest: &Guest, request: &CloneRequest, host: HostKind, list: CloneListing<'_>) -> Option<Issue> {
    let name = request.name.as_str();
    if name.is_empty() {
        return Some(Issue::NameEmpty);
    }
    if !name_ok(name, host) {
        return Some(Issue::NameInvalid);
    }
    if list.guests.iter().any(|g| g.name == name) {
        return Some(Issue::NameTaken);
    }
    match host {
        HostKind::Libvirt => {
            if guest.state != GuestState::Stopped {
                return Some(Issue::NotStopped);
            }
            if let Some(pool) = &request.target_pool
                && !disk_storages(list.pools, host, guest.kind, None).iter().any(|p| &p.name == pool)
            {
                return Some(Issue::CloneStorage);
            }
            None
        }
        HostKind::Pve => {
            if let Some(vmid) = request.vmid {
                if !(VMID_MIN..=VMID_MAX).contains(&vmid) {
                    return Some(Issue::VmidInvalid);
                }
                if list.guests.iter().any(|g| g.vmid == Some(vmid)) {
                    return Some(Issue::VmidTaken);
                }
            }
            let full = clone_full(guest, request, host);
            if !full && request.target_node.is_some() {
                return Some(Issue::CloneLinkedTarget);
            }
            // The node's usable storages, whatever they hold: one that holds
            // no disks of the guest's kind is said as such.
            let storages: Vec<&Pool> = list.pools.iter().filter(|p| pve_usable(p, guest.node.as_deref())).collect();
            clone_node_issue(list.nodes, request.target_node.as_deref(), guest.node.as_deref()).or_else(|| {
                clone_storage_issue(&storages, request.storage.as_deref(), full, guest.kind, request.target_node.as_deref())
            })
        }
    }
}

/// Why `guest` cannot be deleted, or None: only a stopped one (libvirt's
/// `undefine` would leave a running domain running, transient; PVE refuses).
pub fn delete_issue(guest: &Guest) -> Option<Issue> {
    (guest.state != GuestState::Stopped).then_some(Issue::NotStopped)
}

/// Why `guest` cannot become a template, or None: PVE only, a stopped guest
/// that is not one already. libvirt has no templates: a copy of a domain is
/// a clone.
pub fn template_issue(guest: &Guest, host: HostKind) -> Option<Issue> {
    if host != HostKind::Pve {
        return Some(Issue::Unsupported);
    }
    if guest.template {
        return Some(Issue::IsTemplate);
    }
    delete_issue(guest)
}

/// A volume a form offers, with the pool it is in.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Offer {
    pub pool: String,
    pub volume: Volume,
}

/// What a form offers a new guest of one kind (on one PVE node): where its
/// disk can go, the networks its NIC can be on, the install media or
/// templates, the cloud images.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct CreateForm {
    pub options: CreateOptions,
    /// PVE: the VMID offered.
    pub next_vmid: Option<u32>,
    pub storages: Vec<Pool>,
    pub networks: Vec<Network>,
    pub media: Vec<Offer>,
    pub images: Vec<Offer>,
}

/// The pools whose volumes a form for `kind` lists: media (or templates),
/// and cloud images where the host takes them.
pub fn form_pools<'a>(pools: &'a [Pool], host: HostKind, kind: GuestKind, node: Option<&str>, options: &CreateOptions) -> Vec<&'a Pool> {
    let mut out = media_storages(pools, host, kind, node);
    if kind == GuestKind::Qemu && options.cloud_images {
        for p in image_storages(pools, host, node) {
            if !out.iter().any(|o| o.id == p.id) {
                out.push(p);
            }
        }
    }
    out
}

/// The form for `kind` on `node` (PVE), from the host's lists. `volumes`
/// are those of [`form_pools`]' pools, by pool id.
#[allow(clippy::too_many_arguments)]
pub fn create_form(
    kind: GuestKind,
    host: HostKind,
    node: Option<&str>,
    options: CreateOptions,
    next_vmid: Option<u32>,
    pools: &[Pool],
    networks: &[Network],
    volumes: &[(String, Vec<Volume>)],
) -> CreateForm {
    let offers = |of: Vec<&Pool>, keep: &dyn Fn(&Volume) -> bool| {
        let mut out: Vec<Offer> = of
            .iter()
            .filter_map(|p| volumes.iter().find(|(id, _)| id == &p.id))
            .flat_map(|(id, list)| list.iter().filter(|v| keep(v)).map(|v| Offer { pool: id.clone(), volume: v.clone() }))
            .collect();
        out.sort_by(|a, b| a.volume.name.cmp(&b.volume.name));
        out
    };
    let media = offers(media_storages(pools, host, kind, node), &|v| is_media(v, kind));
    let images = if kind == GuestKind::Qemu && options.cloud_images {
        offers(image_storages(pools, host, node), &|v| is_cloud_image(v, host))
    } else {
        Vec::new()
    };
    CreateForm {
        storages: disk_storages(pools, host, kind, node).into_iter().cloned().collect(),
        networks: create_networks(networks, host, node).into_iter().cloned().collect(),
        media,
        images,
        options,
        next_vmid,
    }
}

/// Where a copy of `guest`'s disks can go: on PVE the storages of its node
/// that hold disks of its kind; on libvirt the pools a volume can be made in.
pub fn clone_storages<'a>(pools: &'a [Pool], host: HostKind, guest: &Guest) -> Vec<&'a Pool> {
    disk_storages(pools, host, guest.kind, guest.node.as_deref().filter(|_| host == HostKind::Pve))
}
