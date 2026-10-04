//! [`crate::hardware`] on a libvirt host: a domain's two definitions read
//! into one [`Hardware`] (the persistent one, with what the running one has
//! instead as pending), a [`Change`] as the [`VirtHwChange`] that makes it,
//! a seed's cloud-init as the Settings view edits it, and the host's
//! devices.
//!
//! Pure, like the rest of [`crate::libvirt`]: the caller reads
//! [`super::hardware_script`] (and the seed, the pools, the networks) and
//! runs [`super::hardware_change_script`]. Ported from the app's
//! `LibvirtBackend` (`hardwareOf`, `supportOf`, `pendingOf`, `changeJson`,
//! `cloudInitStateOf`, `hostDevices`).

use sha2::{Digest, Sha256};

use crate::create::{self, VolumeRef};
use crate::error::{Error, ErrorKind};
use crate::hardware::{
    self, Change, CloudInitEdit, CloudInitState, Cpu, DeviceKind, DiskKind, Display, Firmware, Hardware, HostDevice, HostDevices,
    HwDevice, HwDisk, HwNic, Limits, Listing, Memory, PendingField, Support, UsbNaming,
};
use crate::libvirt::cloud_init::{VirtCloudInit, VirtSeedRead};
use crate::libvirt::{
    FirmwareDescriptor, VirtHardwareInfo, VirtHostDevices, VirtHwCaps, VirtHwChange, VirtHwConfig, VirtHwCpu, VirtHwDisk, VirtHwNewDevice,
    VirtHwNic,
};
use crate::model::{GuestKind, HostKind};

/// What an edit is made from: the SHA-256 of the persistent definition as
/// read, and of the run it was read in — the running domain's id, new at
/// every start. A change made from a read the definition moved on from is
/// refused, and so is one made while the guest ran another time than the one
/// shown (a revert to its running definition would write back a different
/// run's). The definition itself carries the display passwords and never
/// leaves the host's side; this does.
pub fn revision_of(info: &VirtHardwareInfo) -> String {
    let run = roxmltree::Document::parse(&info.live_xml)
        .ok()
        .and_then(|d| d.root_element().attribute("id").map(str::to_owned))
        .unwrap_or_default();
    let mut h = Sha256::new();
    h.update(info.config_xml.as_bytes());
    h.update(b"\0");
    h.update(run.as_bytes());
    h.finalize().iter().map(|b| format!("{b:02x}")).collect()
}

fn owned(l: &[&str]) -> Vec<String> {
    l.iter().map(|s| (*s).to_owned()).collect()
}

/// What `domcapabilities` allows this domain, as the view's choices; without
/// them (an older libvirt, a refusal), the common ground every QEMU has.
/// Secure Boot as a new domain's ([`super::create::options_of`]): a secure
/// loader and a `firmware` descriptor with the enrolled keys — or the
/// domain has it on already, so it can be turned off.
pub fn support_of(caps: Option<&VirtHwCaps>, firmware: &[FirmwareDescriptor], secure_boot_on: bool) -> Support {
    let pick = |have: Option<&Vec<String>>, wanted: &[&str]| -> Vec<String> {
        wanted.iter().filter(|w| have.is_none_or(|h| h.iter().any(|x| x == *w))).map(|w| (*w).to_owned()).collect()
    };
    Support {
        buses: pick(caps.map(|c| &c.disk_buses), &["virtio", "scsi", "sata", "ide"]),
        caches: owned(&["default", "none", "writeback", "writethrough", "directsync", "unsafe"]),
        nic_models: owned(&["virtio", "e1000e", "e1000", "rtl8139"]),
        mac: true,
        protocols: pick(caps.map(|c| &c.graphics), &["vnc", "spice"]),
        listen: true,
        gpus: pick(caps.map(|c| &c.video), &["virtio", "qxl", "vga", "cirrus", "bochs", "none"]),
        uefi: caps.is_some_and(|c| c.efi),
        secure_boot: secure_boot_on
            || (caps.is_some_and(|c| c.secure_boot) && firmware.iter().any(|f| f.secure_boot && f.enrolled_keys)),
        tpm: caps.is_some_and(|c| c.tpm_emulator),
        usb: caps.is_some_and(|c| c.hostdev),
        pci: caps.is_some_and(|c| c.hostdev),
    }
}

/// Dies and clusters count as threads here: the form sets sockets and
/// cores, and keeps the rest of the topology as it is.
fn cpu_of(c: &VirtHwCpu) -> Cpu {
    Cpu {
        sockets: c.sockets,
        cores: c.cores,
        threads: c.threads * c.dies.max(1) * c.clusters.max(1),
        online: (c.current < c.max).then_some(c.current),
        cpu_type: None,
    }
}

/// `info` as the Hardware view edits it: the persistent definition, with
/// what the running one has instead as pending. `name` is the domain's.
pub fn hardware_of(info: &VirtHardwareInfo, name: Option<&str>) -> Hardware {
    let c = &info.config;
    Hardware {
        kind: GuestKind::Qemu,
        running: info.live.is_some(),
        cpu: cpu_of(&c.cpu),
        memory: Memory {
            mib: c.memory_kib / 1024,
            min_mib: c.balloon.then_some(c.current_memory_kib / 1024),
            balloon: c.balloon,
            swap_mib: None,
        },
        disks: c
            .disks
            .iter()
            .filter(|d| d.device == "disk" || d.device == "cdrom")
            .map(|d| HwDisk {
                key: d.target.clone(),
                kind: if d.device == "cdrom" { DiskKind::Cdrom } else { DiskKind::Disk },
                source: d.source.clone(),
                size: d.capacity,
                storage: None,
                mount_point: None,
                bus: d.bus.clone(),
                format: d.format.clone(),
                readonly: d.readonly,
                cache: d.cache.clone(),
                cloud_init: d.device == "cdrom" && c.seed.is_some() && d.source == c.seed,
                // `vol-resize` takes the file; nothing else has a path to
                // grow at while the domain is stopped.
                resizable: d.source_type.as_deref() == Some("file"),
            })
            .collect(),
        nics: c
            .nics
            .iter()
            .map(|n| HwNic {
                key: n.mac.clone(),
                mac: Some(n.mac.clone()),
                nic_type: Some(n.kind.clone()),
                source: n.source.clone(),
                model: n.model.clone(),
                link_up: n.link_up,
                firewall: None,
                name: None,
            })
            .collect(),
        boot: Some(c.boot.clone()),
        autostart: info.autostart,
        name: name.map(str::to_owned),
        description: info.description.clone(),
        protection: None,
        rename_running: false,
        pending: pending_of(c, info.live.as_ref()),
        revision: Some(revision_of(info)),
        limits: Limits { host_cpus: info.host_cpus, host_memory_bytes: info.host_memory_kib.map(|k| k * 1024) },
        cpu_types: Vec::new(),
        config_text: Some(info.config_text.trim_end().to_owned()),
        firmware: Some(Firmware { uefi: c.efi, secure_boot: c.secure_boot, vars_storage: None }),
        display: Some(Display {
            protocol: c.graphics.as_ref().map(|g| g.kind.clone()),
            listen: c.graphics.as_ref().and_then(|g| g.listen.clone()),
            gpu: c.video.clone(),
            port: c.graphics.as_ref().and_then(|g| g.port),
        }),
        devices: c
            .tpm
            .iter()
            .map(|t| HwDevice {
                key: "tpm".to_owned(),
                kind: DeviceKind::Tpm,
                detail: Some([Some(t.model.clone()), t.version.clone()].into_iter().flatten().collect::<Vec<_>>().join(" · ")),
                mapping: false,
            })
            .chain(c.hostdevs.iter().map(|h| HwDevice {
                key: h.key.clone(),
                kind: if h.kind == "pci" { DeviceKind::Pci } else { DeviceKind::Usb },
                detail: Some(h.address.clone().unwrap_or_else(|| match (&h.vendor, &h.product) {
                    (Some(v), Some(p)) => format!("{v}:{p}"),
                    _ => h.key.get(4..).unwrap_or_default().to_owned(),
                })),
                mapping: false,
            }))
            .collect(),
        support: support_of(info.caps.as_ref(), &info.firmware, c.secure_boot),
    }
}

/// What the running definition (`live`) has differently from the persistent
/// one: the changes the next start makes. libvirt keeps no list of its own;
/// this is the difference. The balloon's current size is not one: it moves
/// while the guest runs.
pub fn pending_of(config: &VirtHwConfig, live: Option<&VirtHwConfig>) -> Vec<PendingField> {
    let Some(live) = live else { return Vec::new() };
    let field = |key: &str, current: Option<String>, pending: Option<String>, delete: bool| PendingField {
        key: key.to_owned(),
        current,
        pending,
        delete,
    };
    let cpu = |c: &VirtHwCpu| {
        let v = cpu_of(c);
        let shape = format!("{}×{}×{}", v.sockets, v.cores, v.threads);
        if c.current < c.max { format!("{}/{} ({shape})", c.current, c.max) } else { format!("{} ({shape})", c.max) }
    };
    let mem = |kib: u64| format!("{} MiB", kib / 1024);
    let nic = |n: &VirtHwNic| {
        let mut parts = vec![n.kind.clone()];
        parts.extend(n.source.clone());
        parts.extend(n.model.clone());
        if !n.link_up {
            parts.push("link down".to_owned());
        }
        parts.join(" ")
    };
    let mut out = Vec::new();
    if cpu(&config.cpu) != cpu(&live.cpu) {
        out.push(field("cpu", Some(cpu(&live.cpu)), Some(cpu(&config.cpu)), false));
    }
    if config.memory_kib != live.memory_kib {
        out.push(field("memory", Some(mem(live.memory_kib)), Some(mem(config.memory_kib)), false));
    }
    let disk_in = |c: &VirtHwConfig, t: &str| c.disks.iter().find(|d| d.target == t).cloned();
    for d in &config.disks {
        match disk_in(live, &d.target) {
            None => out.push(field(&d.target, None, Some(d.source.clone().unwrap_or_else(|| d.device.clone())), false)),
            Some(l) if l.source != d.source => out.push(field(&d.target, l.source, d.source.clone(), false)),
            _ => {}
        }
    }
    for l in &live.disks {
        if disk_in(config, &l.target).is_none() {
            out.push(field(&l.target, Some(l.source.clone().unwrap_or_else(|| l.device.clone())), None, true));
        }
    }
    let nic_in = |c: &VirtHwConfig, m: &str| c.nics.iter().find(|n| n.mac == m).cloned();
    for n in &config.nics {
        match nic_in(live, &n.mac) {
            None => out.push(field(&n.mac, None, Some(nic(n)), false)),
            Some(l) if nic(&l) != nic(n) => out.push(field(&n.mac, Some(nic(&l)), Some(nic(n)), false)),
            _ => {}
        }
    }
    for l in &live.nics {
        if nic_in(config, &l.mac).is_none() {
            out.push(field(&l.mac, Some(nic(l)), None, true));
        }
    }
    let fw = |c: &VirtHwConfig| {
        if !c.efi {
            "BIOS"
        } else if c.secure_boot {
            "UEFI · Secure Boot"
        } else {
            "UEFI"
        }
    };
    if fw(config) != fw(live) {
        out.push(field("firmware", Some(fw(live).to_owned()), Some(fw(config).to_owned()), false));
    }
    let display = |c: &VirtHwConfig| {
        [c.graphics.as_ref().map(|g| g.kind.clone()), c.graphics.as_ref().and_then(|g| g.listen.clone()), c.video.clone()]
            .into_iter()
            .flatten()
            .collect::<Vec<_>>()
            .join(" · ")
    };
    if display(config) != display(live) {
        out.push(field("display", Some(display(live)), Some(display(config)), false));
    }
    let devs = |c: &VirtHwConfig| {
        let mut d: Vec<String> = c.hostdevs.iter().map(|h| h.key.clone()).collect();
        if c.tpm.is_some() {
            d.push("tpm".to_owned());
        }
        d
    };
    let (cd, ld) = (devs(config), devs(live));
    for k in cd.iter().filter(|k| !ld.contains(k)) {
        out.push(field(k, None, Some(k.clone()), false));
    }
    for k in ld.iter().filter(|k| !cd.contains(k)) {
        out.push(field(k, Some(k.clone()), None, true));
    }
    let disk_hw = |d: &VirtHwDisk| format!("{} {}", d.bus.as_deref().unwrap_or_default(), d.cache.as_deref().unwrap_or("default"));
    for d in &config.disks {
        if let Some(l) = disk_in(live, &d.target)
            && l.source == d.source
            && disk_hw(&l) != disk_hw(d)
        {
            out.push(field(&d.target, Some(disk_hw(&l)), Some(disk_hw(d)), false));
        }
    }
    if config.boot != live.boot {
        out.push(field("boot", Some(live.boot.join(", ")), Some(config.boot.join(", ")), false));
    }
    out
}

/// Where a bus's disks are named: `vd` for virtio, `hd` for IDE, `sd` for
/// the rest.
fn bus_prefix(bus: &str) -> &'static str {
    match bus {
        "virtio" => "vd",
        "ide" => "hd",
        _ => "sd",
    }
}

/// `vda`, `vdb`, … `vdz`, then `vdaa`, as libvirt names disks.
fn free_target(prefix: &str, taken: &[&str]) -> Result<String, Error> {
    let name = |i: usize| {
        let a = b'a';
        if i < 26 {
            format!("{prefix}{}", (a + i as u8) as char)
        } else {
            format!("{prefix}{}{}", (a + (i / 26 - 1) as u8) as char, (a + (i % 26) as u8) as char)
        }
    };
    (0..26 * 27).map(name).find(|n| !taken.contains(&n.as_str())).ok_or_else(|| Error::msg(ErrorKind::Unsupported, "No free disk target"))
}

fn path_of(v: Option<&crate::resource::Volume>) -> Result<Option<String>, Error> {
    match v {
        None => Ok(None),
        Some(v) => v.path.clone().map(Some).ok_or_else(|| Error::msg(ErrorKind::Unsupported, format!("No path for {}", v.name))),
    }
}

fn media_path(media: &Option<VolumeRef>, list: Listing<'_>) -> Result<Option<String>, Error> {
    path_of(media.as_ref().and_then(|r| list.volume(r)))
}

/// `change` as what makes it on the domain read as `info` (named `name`),
/// checked first: made from the read whose [`revision_of`] is `revision`
/// ([`hardware::conflict`] otherwise), against the rules
/// ([`hardware::issue`]) with the host's pools, networks and the volumes it
/// names in `list`.
pub fn change_of(info: &VirtHardwareInfo, name: &str, revision: Option<&str>, change: &Change, list: Listing<'_>) -> Result<VirtHwChange, Error> {
    if revision != Some(revision_of(info).as_str()) {
        return Err(hardware::conflict());
    }
    let hw = hardware_of(info, Some(name));
    if let Some(issue) = hardware::issue(&hw, change, HostKind::Libvirt, list) {
        return Err(hardware::refusal(issue));
    }
    let config = &info.config;
    let live = info.live.as_ref();
    let disk_in = |c: Option<&VirtHwConfig>, t: &str| c.and_then(|c| c.disks.iter().find(|d| d.target == t)).cloned();
    let nic_in = |c: Option<&VirtHwConfig>, m: &str| c.and_then(|c| c.nics.iter().find(|n| n.mac == m)).cloned();
    let taken: Vec<&str> = config.disks.iter().chain(live.map(|l| l.disks.iter()).into_iter().flatten()).map(|d| d.target.as_str()).collect();
    let first_bus = || config.disks.iter().find(|d| d.device == "disk").and_then(|d| d.bus.clone()).unwrap_or_else(|| "virtio".to_owned());
    Ok(match change {
        Change::SetCpu { sockets, cores, online, .. } => VirtHwChange::Cpu { sockets: *sockets, cores: *cores, current: *online },
        Change::SetMemory { mib, min_mib, .. } => VirtHwChange::Memory { memory_mib: *mib, current_mib: *min_mib },
        Change::GrowDisk { key, bytes } => {
            let disk = disk_in(Some(config), key);
            let running = disk_in(live, key);
            VirtHwChange::GrowDisk {
                target: key.clone(),
                bytes: *bytes,
                path: disk.as_ref().filter(|d| d.source_type.as_deref() == Some("file")).and_then(|d| d.source.clone()),
                // `blockresize` grows what the running domain has at the
                // target: only the disk the editor shows when the definition
                // has not put another source there.
                live: matches!((&running, &disk), (Some(r), Some(d)) if r.source == d.source && r.source_type == d.source_type),
            }
        }
        Change::AddDisk { pool, gib, .. } => {
            let pool = list.pool(pool).expect("checked");
            let bus = first_bus();
            let target = free_target(bus_prefix(&bus), &taken)?;
            let format = create::libvirt_disk_format(&pool.pool_type);
            VirtHwChange::AddDisk {
                pool: pool.id.clone(),
                volume: format!("{name}-{target}.{}", if format == "qcow2" { "qcow2" } else { "img" }),
                gib: *gib,
                format: format.to_owned(),
                target,
                bus,
            }
        }
        Change::AttachVolume { volume, .. } => {
            let v = list.volume(volume).expect("checked");
            let path = path_of(Some(v))?.unwrap_or_default();
            let bus = first_bus();
            VirtHwChange::AttachVolume {
                path,
                // What the image is, as the pool read it; an ISO's bytes are
                // raw.
                format: v.format.clone().filter(|f| f != "iso" && f != "unknown").unwrap_or_else(|| "raw".to_owned()),
                target: free_target(bus_prefix(&bus), &taken)?,
                bus,
            }
        }
        Change::RemoveDisk { key, delete_volume } => {
            let disk = disk_in(Some(config), key).or_else(|| disk_in(live, key));
            // A CD-ROM's image, or a read-only disk, is somebody's media: not
            // deleted here whatever was asked.
            let deletable = disk.filter(|d| *delete_volume && d.device == "disk" && !d.readonly && d.source_type.as_deref() == Some("file"));
            VirtHwChange::RemoveDisk {
                target: key.clone(),
                delete_path: deletable.and_then(|d| d.source),
                config: disk_in(Some(config), key).is_some(),
                live: disk_in(live, key).is_some(),
            }
        }
        Change::AddCdrom { media } => {
            // Where the machine has a controller for one: SATA on q35, IDE
            // on `pc`.
            let bus = if config.machine.as_deref().unwrap_or_default().contains("q35") { "sata" } else { "ide" };
            VirtHwChange::AddCdrom { target: free_target(bus_prefix(bus), &taken)?, bus: bus.to_owned(), source: media_path(media, list)? }
        }
        Change::SetMedia { key, media } => {
            let source = media_path(media, list)?;
            // Ejecting an empty drive is refused; there is nothing to do.
            let touches = |c: Option<&VirtHwConfig>| disk_in(c, key).is_some_and(|d| source.is_some() || d.source.is_some());
            VirtHwChange::SetMedia { target: key.clone(), config: touches(Some(config)), live: touches(live), source }
        }
        Change::AddNic { network, model } => VirtHwChange::AddNic {
            kind: "network".to_owned(),
            source: list.network(network).expect("checked").name.clone(),
            model: model.clone().unwrap_or_else(|| "virtio".to_owned()),
            mac: create_mac()?,
        },
        Change::RemoveNic { key } => VirtHwChange::RemoveNic {
            mac: key.clone(),
            kind: nic_in(Some(config), key).map(|n| n.kind),
            live_kind: nic_in(live, key).map(|n| n.kind),
        },
        Change::UpdateNic { key, network, link_up, .. } => {
            let c = nic_in(Some(config), key);
            let l = nic_in(live, key);
            let current = c.clone().or_else(|| l.clone()).unwrap_or_default();
            let net = network.as_ref().map(|n| list.network(n).expect("checked").name.clone());
            VirtHwChange::UpdateNic {
                mac: key.clone(),
                kind: if net.is_some() { "network".to_owned() } else { current.kind.clone() },
                source: net.or(current.source.clone()).unwrap_or_default(),
                model: current.model.clone(),
                link_up: *link_up,
                boot_order: c.as_ref().and_then(|n| n.boot_order),
                live_boot_order: l.as_ref().and_then(|n| n.boot_order),
                config: c.is_some(),
                live: l.is_some(),
            }
        }
        Change::SetBoot { order } => VirtHwChange::Boot { order: order.clone() },
        Change::SetAutostart { on } => VirtHwChange::Autostart { on: *on },
        Change::SetDescription { text } => VirtHwChange::Description { text: text.clone() },
        Change::SetName { name } => VirtHwChange::Rename { name: name.clone() },
        Change::UpdateDisk { key, bus, cache } => {
            let new_target = match bus {
                Some(b) if disk_in(Some(config), key).and_then(|d| d.bus).as_ref() != Some(b) => Some(free_target(bus_prefix(b), &taken)?),
                _ => None,
            };
            VirtHwChange::UpdateDisk {
                target: key.clone(),
                bus: new_target.as_ref().and(bus.clone()),
                new_target,
                cache: cache.clone(),
            }
        }
        Change::SetNicHardware { key, model, mac } => {
            VirtHwChange::UpdateNicHardware { mac: key.clone(), new_mac: mac.as_ref().map(|m| m.to_ascii_lowercase()), model: model.clone() }
        }
        Change::SetFirmware { uefi, secure_boot, .. } => VirtHwChange::Firmware { efi: *uefi, secure_boot: *uefi && *secure_boot },
        Change::SetDisplay { protocol, listen, gpu } => {
            VirtHwChange::Display { graphics: protocol.clone(), listen: listen.clone(), video: gpu.clone() }
        }
        Change::AddDevice { kind, host, usb_naming, .. } => VirtHwChange::AddDevice {
            device: match kind {
                DeviceKind::Tpm => VirtHwNewDevice::Tpm { model: "tpm-crb".to_owned() },
                DeviceKind::Usb => {
                    let h = host.as_ref().expect("checked");
                    if *usb_naming == UsbNaming::Address {
                        VirtHwNewDevice::Usb { vendor: None, product: None, bus: h.usb_bus, device: h.usb_device }
                    } else {
                        let (v, p) = h.id.split_once(':').unwrap_or((&h.id, ""));
                        VirtHwNewDevice::Usb { vendor: Some(v.to_owned()), product: Some(p.to_owned()), bus: None, device: None }
                    }
                }
                DeviceKind::Pci => VirtHwNewDevice::Pci { address: host.as_ref().expect("checked").id.clone() },
            },
        },
        Change::RemoveDevice { key } => VirtHwChange::RemoveDevice { key: key.clone() },
        // Refused by `issue` above: PVE's.
        Change::SetProtection { .. } | Change::Revert { .. } => return Err(hardware::refusal(hardware::Issue::Unsupported)),
    })
}

fn create_mac() -> Result<String, Error> {
    super::create::new_mac()
}

/// Every pending change discarded: the definition written again from what
/// the domain runs ([`VirtHwChange::RevertLive`]), made from the read whose
/// [`revision_of`] is `revision`.
pub fn revert_of(info: &VirtHardwareInfo, revision: Option<&str>) -> Result<VirtHwChange, Error> {
    if revision != Some(revision_of(info).as_str()) {
        return Err(hardware::conflict());
    }
    // Whether it runs is `live`: `dumpxml` of a domain that does not run
    // prints its persistent definition, so `live_xml` is not empty then.
    if info.live.is_none() || info.live_xml.is_empty() {
        return Err(Error::msg(ErrorKind::Unsupported, "The guest is not running: there is nothing to revert to"));
    }
    Ok(VirtHwChange::RevertLive { live_xml: info.live_xml.clone() })
}

/// A seed's read as the Settings view shows it: never the hash, only that
/// there is one. `nic_macs` are the domain's NICs.
pub fn cloud_init_state_of(read: &VirtSeedRead, nic_macs: &[String]) -> CloudInitState {
    let ci = &read.cloud_init;
    let net = ci.network.as_ref();
    CloudInitState {
        user: ci.user.clone(),
        ssh_keys: ci.ssh_keys.clone(),
        hostname: Some(ci.hostname.clone()),
        address: net.and_then(|n| n.ipv4.as_ref()).map(|i| i.address.clone()),
        gateway: net.and_then(|n| n.ipv4.as_ref()).and_then(|i| i.gateway.clone()),
        dns: net.map(|n| n.dns.clone()).unwrap_or_default(),
        search_domains: net.map(|n| n.search.clone()).unwrap_or_default(),
        nics: (net.is_some() as u32) + ci.extra_networks.len() as u32,
        password_set: ci.password_hash.is_some(),
        password_expires: ci.password_expire,
        network: !nic_macs.is_empty(),
        foreign: read.foreign,
        revision: read.revision.clone(),
    }
}

/// The seed `edit` writes, made from `read` (the seed as it is now, which
/// must be the read `edit` was made from) for the domain `name` with NICs
/// `nic_macs`: a new password hashed, none keeping the seed's own hash; the
/// NIC the seed names while the domain still has it, its first otherwise;
/// the seed's other NICs kept as they are; a new instance ID.
pub fn cloud_init_update(read: &VirtSeedRead, name: &str, nic_macs: &[String], edit: &CloudInitEdit) -> Result<VirtCloudInit, Error> {
    if edit.revision != read.revision {
        return Err(Error::msg(ErrorKind::Conflict, "Read the cloud-init settings again"));
    }
    let state = cloud_init_state_of(read, nic_macs);
    if let Some(issue) = hardware::cloud_init_edit_issue(&state, edit, HostKind::Libvirt) {
        return Err(create::refusal(issue));
    }
    let ci = &read.cloud_init;
    let macs: Vec<String> = nic_macs.iter().map(|m| m.to_ascii_lowercase()).collect();
    let seed_mac = ci.network.as_ref().map(|n| n.mac.to_ascii_lowercase());
    let mac = seed_mac.filter(|m| macs.contains(m)).or_else(|| macs.first().cloned());
    // The NIC the form's settings go to is configured once: where it was
    // one of the seed's other NICs, that entry gives way to them.
    let extra = ci.extra_networks.iter().filter(|n| Some(n.mac.to_ascii_lowercase()) != mac).cloned().collect();
    super::create::cloud_init_of(
        &edit.values,
        name,
        mac.as_deref().filter(|_| state.network),
        if edit.remove_password { None } else { ci.password_hash.clone() },
        extra,
        edit.password_expires,
    )
}

/// The host's USB and PCI devices (`nodedev-list`), for giving one to a
/// guest. Root hubs are the host's own, never anyone's to pass through.
pub fn host_devices_of(d: &VirtHostDevices) -> HostDevices {
    let name = |v: &Option<String>, p: &Option<String>, fallback: &str| {
        let n = [v.as_deref(), p.as_deref()].into_iter().flatten().collect::<Vec<_>>().join(" ");
        if n.trim().is_empty() { fallback.to_owned() } else { n.trim().to_owned() }
    };
    HostDevices {
        iommu: d.iommu,
        mappings_only: false,
        usb: d
            .usb
            .iter()
            .filter(|u| u.vendor != "1d6b")
            .map(|u| {
                let id = format!("{}:{}", u.vendor, u.product);
                HostDevice {
                    label: name(&u.vendor_name, &u.product_name, &id),
                    detail: Some(id.clone()),
                    id,
                    usb_bus: u.bus,
                    usb_device: u.device,
                    usb_port: u.port.clone(),
                    ..HostDevice::default()
                }
            })
            .collect(),
        pci: d
            .pci
            .iter()
            .map(|p| HostDevice {
                id: p.address.clone(),
                label: name(&p.vendor_name, &p.product_name, &p.address),
                detail: Some(p.address.clone()),
                iommu_group: p.iommu_group,
                group_size: p.group_size,
                ..HostDevice::default()
            })
            .collect(),
    }
}
