//! [`crate::create`] on a libvirt host: what a new domain can be given, a
//! [`CreateSpec`] as the scripts' [`VirtCreateSpec`], what is deleted with a
//! domain, and a copy's disks.
//!
//! Pure, like the rest of [`crate::libvirt`]: the caller reads what each
//! step needs and runs the scripts. Ported from the app's `LibvirtBackend`
//! (`createOptions`, `create`, `cloudInitJson`, `delete`, `clone`).

use std::collections::{BTreeMap, BTreeSet};

use crate::create::{self, CloneRequest, CloudInit, CreateListing, CreateOptions, CreateSpec, Created, Issue};
use crate::error::{Error, ErrorKind};
use crate::libvirt::cloud_init::{SEED_TOOLS, VirtCiIpv4, VirtCiNetwork, VirtCloudInit, sha512_crypt};
use crate::libvirt::host::{error_of, pool_holds_files, pool_of_file};
use crate::libvirt::snapshot::VirtSnapChain;
use crate::libvirt::{
    FirmwareDescriptor, VirtCloneDisk, VirtCloneSpec, VirtCreateHost, VirtCreateSpec, VirtCreateVolumes, VirtCreated,
    VirtDiskUse, VirtDomainXml, VirtHwConfig, VirtPool,
};
use crate::model::{Guest, HostKind};
use crate::resource::{Network, Pool, Volume};
use crate::snapshot::Snapshot;

/// Random bytes from the system's secure source.
fn random<const N: usize>() -> Result<[u8; N], Error> {
    let mut b = [0u8; N];
    getrandom::fill(&mut b).map_err(|e| Error::msg(ErrorKind::Unknown, format!("no random source: {e}")))?;
    Ok(b)
}

/// A MAC in QEMU's locally administered range, for a NIC cloud-init finds
/// by it.
pub fn new_mac() -> Result<String, Error> {
    let [a, b, c] = random::<3>()?;
    Ok(format!("52:54:00:{a:02x}:{b:02x}:{c:02x}"))
}

/// What a new domain can be given on this host, from `domcapabilities` for
/// the machine it gets (KVM and q35 where the host has them) and QEMU's
/// firmware descriptors: the buses that machine has (q35: no IDE), UEFI
/// where OVMF is installed, a TPM where swtpm is, and whether the host has a
/// tool to make a cloud-init seed with. A cloud image is a
/// `vol-create-from` away on any host.
///
/// Secure Boot is not `domcapabilities`' answer alone: libvirt's firmware
/// autoselection needs a descriptor carrying the enrolled keys, and a host
/// with `secure='yes'` in its loader but no such descriptor cannot start a
/// domain with the feature on.
pub fn options_of(host: &VirtCreateHost, firmware: &[FirmwareDescriptor]) -> CreateOptions {
    let caps = host.caps.as_ref();
    let q35 = host.machine.contains("q35");
    let buses = create::BUSES
        .iter()
        .filter(|b| match caps {
            None => matches!(**b, "virtio" | "sata"),
            Some(c) => c.disk_buses.iter().any(|d| d == *b) && !(**b == "ide" && q35),
        })
        .map(|b| (*b).to_owned())
        .collect();
    CreateOptions {
        buses,
        nic_models: create::NIC_MODELS.iter().map(|m| (*m).to_owned()).collect(),
        uefi: caps.is_some_and(|c| c.efi),
        secure_boot: caps.is_some_and(|c| c.secure_boot) && firmware.iter().any(|f| f.secure_boot && f.enrolled_keys),
        tpm: caps.is_some_and(|c| c.tpm_emulator),
        cloud_images: true,
        cloud_init: host.seed_tool.is_some(),
        cloud_init_missing: host.seed_tool.is_none().then(|| SEED_TOOLS.join(", ")),
    }
}

/// `ci` as the seed's [`VirtCloudInit`] for the domain `name`: the password
/// as its SHA-512 crypt hash (a salt from the system's secure source) — or,
/// where none was typed, `keep_hash` (the seed's own, when it is edited) —
/// the hostname `name` where none was given, a new instance ID, and the NIC
/// by `mac`. `extra_networks` are the seed's own NICs after the first,
/// written back as they are.
///
/// The instance ID is new every time: cloud-init runs most of its modules
/// once per instance, so a seed with the old one would be read and ignored.
pub fn cloud_init_of(
    ci: &CloudInit,
    name: &str,
    mac: Option<&str>,
    keep_hash: Option<String>,
    extra_networks: Vec<VirtCiNetwork>,
    password_expire: bool,
) -> Result<VirtCloudInit, Error> {
    const ITOA64: &[u8] = b"./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    let password_hash = match ci.password.as_deref().filter(|p| !p.is_empty()) {
        Some(p) => {
            let salt: String = random::<16>()?.iter().map(|b| ITOA64[(b & 63) as usize] as char).collect();
            Some(sha512_crypt(p, &salt).map_err(|e| error_of(&e, true))?)
        }
        None => keep_hash,
    };
    let hex: String = random::<4>()?.iter().map(|b| format!("{b:02x}")).collect();
    let safe: String = name.chars().map(|c| if c.is_ascii_alphanumeric() || matches!(c, '.' | '_' | '-') { c } else { '-' }).collect();
    Ok(VirtCloudInit {
        user: ci.user.clone(),
        password_hash,
        ssh_keys: ci.keys().into_iter().map(str::to_owned).collect(),
        hostname: ci.hostname.clone().unwrap_or_else(|| name.to_owned()),
        instance_id: format!("iid-{safe}-{hex}"),
        network: mac.map(|mac| VirtCiNetwork {
            mac: mac.to_owned(),
            ipv4: ci.address.as_ref().map(|a| VirtCiIpv4 { address: a.clone(), gateway: ci.gateway.clone() }),
            dns: ci.dns.clone(),
            search: ci.search_domains.clone(),
        }),
        extra_networks: if mac.is_some() { extra_networks } else { Vec::new() },
        password_expire,
    })
}

/// What a new domain is checked against and made from: the host's
/// `domcapabilities` and firmware, its domains, pools and networks, and the
/// volumes `media` and `image` name in their pools.
#[derive(Debug, Clone, Copy)]
pub struct CreateHost<'a> {
    pub host: &'a VirtCreateHost,
    pub firmware: &'a [FirmwareDescriptor],
    pub guests: &'a [Guest],
    pub pools: &'a [Pool],
    pub networks: &'a [Network],
    pub media: Option<&'a Volume>,
    pub image: Option<&'a Volume>,
}

/// `spec` as the scripts' spec, checked first ([`create::create_issue`]).
/// The disk and the seed are made by [`crate::libvirt::create_volume_script`],
/// then the domain is defined on their paths by
/// [`crate::libvirt::define_script`] ([`with_volumes`]). `seed_tools`
/// narrows the ISO tools tried (the end-to-end tests make a seed with each).
pub fn spec_of(spec: &CreateSpec, on: CreateHost<'_>, seed_tools: Option<Vec<String>>) -> Result<VirtCreateSpec, Error> {
    let options = options_of(on.host, on.firmware);
    let list = CreateListing {
        guests: on.guests,
        nodes: &[],
        pools: on.pools,
        networks: on.networks,
        media: on.media,
        image: on.image,
        options: &options,
    };
    if let Some(issue) = create::create_issue(spec, HostKind::Libvirt, list) {
        return Err(create::refusal(issue));
    }
    let pool = on.pools.iter().find(|p| p.id == spec.storage).ok_or_else(|| create::refusal(Issue::Storage))?;
    let path_of = |v: &Volume| {
        v.path.clone().ok_or_else(|| Error::msg(ErrorKind::InvalidResponse, format!("No path for {}", v.name)))
    };
    let network = spec.network.as_ref().and_then(|id| on.networks.iter().find(|n| &n.id == id));
    // The NIC's MAC is chosen here when cloud-init finds the NIC by it.
    let mac = match (&spec.cloud_init, network) {
        (Some(_), Some(_)) => Some(new_mac()?),
        _ => None,
    };
    let cloud_init = match &spec.cloud_init {
        Some(ci) => Some(cloud_init_of(ci, &spec.name, mac.as_deref(), None, Vec::new(), false)?),
        None => None,
    };
    Ok(VirtCreateSpec {
        name: spec.name.clone(),
        vcpus: spec.cores,
        memory_mib: spec.memory_mib,
        host: on.host.clone(),
        disk_pool: pool.id.clone(),
        disk_gib: spec.disk_gib,
        disk_format: create::libvirt_disk_format(&pool.pool_type).to_owned(),
        disk_path: None,
        base_image: on.image.filter(|_| spec.image.is_some()).map(path_of).transpose()?,
        disk_bus: spec.bus.clone(),
        cdrom: on.media.filter(|_| spec.media.is_some()).map(path_of).transpose()?,
        network: network.map(|n| n.name.clone()),
        nic_model: spec.nic_model.clone(),
        mac,
        efi: spec.uefi,
        secure_boot: spec.uefi && spec.secure_boot,
        tpm: spec.tpm,
        cloud_init,
        seed_path: None,
        seed_tools,
        start: spec.start,
    })
}

/// `spec` with the paths [`crate::libvirt::parse_create_volumes`] read: what
/// [`crate::libvirt::define_script`] defines the domain on.
pub fn with_volumes(mut spec: VirtCreateSpec, made: &VirtCreateVolumes) -> VirtCreateSpec {
    spec.disk_path = Some(made.disk_path.clone());
    spec.seed_path = made.seed_path.clone();
    spec
}

/// What creating came to: the new domain by UUID (by name where `domuuid`
/// did not answer — virsh takes either), and a copy of a cloud image bigger
/// than asked for, which keeps its own size.
pub fn created_of(spec: &VirtCreateSpec, made: &VirtCreateVolumes, created: VirtCreated) -> Created {
    Created {
        id: created.uuid.unwrap_or_else(|| spec.name.clone()),
        start_error: created.start_error,
        disk_kept_bytes: made.copied_bytes.filter(|c| *c > spec.disk_gib << 30),
    }
}

/// What deleting a domain is decided from. `disks` are every domain's
/// (`domblklist`, [`crate::libvirt::VirtStorage::disks`]); `pools` the host's
/// and `volumes` each active pool's, by pool name; `snapshots` the domain's,
/// and `chain` its disks' backing chains, read only where
/// [`delete_needs_chain`] says.
#[derive(Debug, Clone, Copy)]
pub struct DeleteInputs<'a> {
    /// The domain's UUID and name, either of which `domblklist` lists it by.
    pub id: &'a str,
    pub name: &'a str,
    pub xml: &'a VirtDomainXml,
    pub disks: &'a [VirtDiskUse],
    pub pools: &'a [VirtPool],
    pub volumes: &'a [(String, Vec<Volume>)],
    pub snapshots: &'a [Snapshot],
    pub chain: Option<&'a VirtSnapChain>,
}

/// What goes with a domain: the arguments of
/// [`crate::libvirt::undefine_script`], and what was kept, said for a log.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct DeletePlan {
    pub targets: Vec<String>,
    pub seed: Option<String>,
    pub pools: Vec<String>,
    pub files: Vec<String>,
    pub kept: Vec<String>,
}

/// Whether deleting with the disks needs the backing chains read: the
/// domain has external snapshots, whose files `undefine --storage` leaves.
pub fn delete_needs_chain(snapshots: &[Snapshot]) -> bool {
    snapshots.iter().any(|s| s.external && s.layers.iter().any(|l| l.file.is_some()))
}

/// What goes with the domain when its disks do: the volumes of its writable
/// disks, its NVRAM and its own cloud-init seed — not a CD-ROM's image or a
/// read-only disk, which are install media or shared — and the files its
/// external snapshots left under those disks.
///
/// `undefine --storage` deletes a volume however many domains have it, and
/// a volume made on another as its backing file breaks with it: a disk
/// another domain has, or one something else is made on, stays.
pub fn delete_plan(i: DeleteInputs<'_>) -> DeletePlan {
    let mut plan = DeletePlan { seed: i.xml.seed.clone(), ..Default::default() };
    let mut targets: Vec<String> = i
        .xml
        .disks
        .iter()
        .filter(|d| d.device == "disk" && !d.readonly)
        .filter_map(|d| d.target.clone())
        .collect();
    if targets.is_empty() {
        return plan;
    }
    let ours: BTreeMap<&str, &VirtDiskUse> = i
        .disks
        .iter()
        .filter(|d| d.source.is_some() && (d.domain == i.id || d.domain == i.name))
        .map(|d| (d.target.as_str(), d))
        .collect();
    let others: Vec<&VirtDiskUse> = i
        .disks
        .iter()
        .filter(|d| d.source.is_some() && d.domain != i.id && d.domain != i.name)
        .collect();
    let mut by_ref = BTreeMap::new();
    let mut backers: BTreeMap<&str, BTreeSet<&str>> = BTreeMap::new();
    for (pool, volumes) in i.volumes {
        for v in volumes {
            let Some(path) = v.path.as_deref() else { continue };
            by_ref.insert(format!("{pool}/{}", v.name), path);
            if let Some(backing) = v.backing.as_deref() {
                backers.entry(backing).or_default().insert(path);
            }
        }
    }
    let tops: BTreeMap<&str, &str> = ours
        .iter()
        .filter_map(|(target, d)| {
            let source = d.source.as_deref()?;
            let path = if d.kind == "volume" { by_ref.get(source).copied()? } else { source };
            Some((*target, path))
        })
        .collect();
    let top_paths: BTreeSet<&str> = tops.values().copied().collect();
    let others_need = |path: &str| backers.get(path).is_some_and(|b| b.iter().any(|b| !top_paths.contains(b)));
    targets.retain(|t| {
        let use_ = ours.get(t.as_str());
        let shared = use_.is_some_and(|u| others.iter().any(|o| o.kind == u.kind && o.source == u.source))
            || tops.get(t.as_str()).is_some_and(|top| others_need(top));
        if shared {
            let what = use_.and_then(|u| u.source.clone()).unwrap_or_else(|| t.clone());
            plan.kept.push(format!("{what} is another disk's too, it stays"));
        }
        !shared
    });
    let (pools, files) = snapshot_files(&i, &targets, &mut plan.kept);
    let ours_all: BTreeSet<&str> = top_paths.iter().copied().chain(files.iter().map(String::as_str)).collect();
    if let Some(needed) = files.iter().find(|f| backers.get(f.as_str()).is_some_and(|b| b.iter().any(|b| !ours_all.contains(b)))) {
        // A layer something else is made on: the chain stays whole, since
        // what that layer is made on would go from under it too.
        plan.kept.push(format!("{needed} backs another volume, its snapshot files stay"));
    } else {
        plan.pools = pools;
        plan.files = files;
    }
    plan.targets = targets;
    plan
}

/// The files under `targets`' disks that the domain's external snapshots
/// made, and the pools of every file of those chains: `undefine --storage`
/// deletes only the file each disk is on now, and skips even that when its
/// pool was not refreshed since a snapshot or a revert made it.
///
/// Per disk, the chain down to the file the deepest snapshot layer on it
/// backs: that file is the disk the first snapshot was taken of. Anything
/// further down was there before any snapshot (an image the disk was made
/// on, which other domains may share) and stays. And every layer on those
/// disks that is off the chain: a branch the domain left by reverting to an
/// internal snapshot taken before it.
fn snapshot_files(i: &DeleteInputs<'_>, targets: &[String], kept: &mut Vec<String>) -> (Vec<String>, Vec<String>) {
    let by_target: Vec<(&str, &str)> = i
        .snapshots
        .iter()
        .filter(|s| s.external)
        .flat_map(|s| s.layers.iter())
        .filter_map(|l| Some((l.target.as_str(), l.file.as_deref()?)))
        .collect();
    let layers: BTreeSet<&str> = by_target.iter().map(|(_, f)| *f).collect();
    let Some(chain) = i.chain.filter(|_| !layers.is_empty()) else { return (Vec::new(), Vec::new()) };
    let mut files: Vec<String> = Vec::new();
    let mut tops: Vec<&str> = Vec::new();
    for d in chain.disks.iter().filter(|d| targets.contains(&d.target)) {
        if let Some(e) = &d.error {
            kept.push(format!("the chain of {} is unreadable, its snapshot files stay: {e}", d.target));
            continue;
        }
        let on_chain: BTreeSet<&str> = d.files.iter().flat_map(|f| std::iter::once(f.path.as_str()).chain(f.backing.as_deref())).collect();
        for (target, file) in &by_target {
            if *target == d.target && !on_chain.contains(file) && !files.iter().any(|f| f == file) {
                files.push((*file).to_owned());
            }
        }
        let Some(deepest) = d.files.iter().rposition(|f| layers.contains(f.path.as_str())) else { continue };
        tops.push(d.files[0].path.as_str());
        for f in d.files.iter().take(deepest + 2).skip(1) {
            files.push(f.path.clone());
        }
    }
    if files.is_empty() {
        return (Vec::new(), Vec::new());
    }
    let mut pools: Vec<String> = Vec::new();
    for f in tops.iter().copied().chain(files.iter().map(String::as_str)) {
        if let Some(p) = pool_of_file(i.pools, f)
            && !pools.contains(&p.name)
        {
            pools.push(p.name.clone());
        }
    }
    (pools, files)
}

/// A copy of `guest` as [`crate::libvirt::clone_volumes_script`]'s spec,
/// from its persistent definition: each writable disk copied (or made
/// empty) in the pool its source is in — or in `request.target_pool`,
/// which `vol-create-from` copies across pools. A CD-ROM stays on the image
/// it has. Checked first ([`create::clone_issue`]).
pub fn clone_spec_of(
    guest: &Guest,
    config: &VirtHwConfig,
    request: &CloneRequest,
    guests: &[Guest],
    pools: &[VirtPool],
) -> Result<VirtCloneSpec, Error> {
    let listed: Vec<Pool> = pools.iter().map(crate::libvirt::host::pool_of).collect();
    let list = create::CloneListing { guests, nodes: &[], pools: &listed };
    if let Some(issue) = create::clone_issue(guest, request, HostKind::Libvirt, list) {
        return Err(create::refusal(issue));
    }
    let mut disks = Vec::new();
    for d in config.disks.iter().filter(|d| d.device == "disk" && !d.readonly) {
        let source = d.source.as_deref().filter(|s| s.starts_with('/')).ok_or_else(|| {
            Error::msg(ErrorKind::Unsupported, format!("Disk {} has no file to copy", d.target))
        })?;
        disks.push(VirtCloneDisk {
            target: d.target.clone(),
            source: source.to_owned(),
            format: d.format.clone().filter(|f| f == "qcow2" || f == "raw"),
        });
    }
    let target = request.target_pool.as_ref().and_then(|name| pools.iter().find(|p| &p.name == name));
    Ok(VirtCloneSpec {
        source: guest.id.clone(),
        name: request.name.clone(),
        full: request.full,
        disks,
        target_pool: request.target_pool.clone(),
        target_block: target.is_some_and(|p| !pool_holds_files(p)),
    })
}

/// The copy's disks, each target with the path
/// [`crate::libvirt::parse_clone_volumes`] read for it: what
/// [`crate::libvirt::clone_define_script`] defines the copy on.
pub fn clone_disks(spec: &VirtCloneSpec, paths: &[String]) -> Vec<(String, String)> {
    spec.disks.iter().zip(paths).map(|(d, p)| (d.target.clone(), p.clone())).collect()
}

/// A refusal of a name or volume the host already has, said as one.
pub fn exists_or(e: Error) -> Error {
    if e.kind == ErrorKind::Exists && e.detail.is_none() {
        let mut out = create::refusal(Issue::NameTaken);
        out.message = e.message;
        return out;
    }
    e
}
