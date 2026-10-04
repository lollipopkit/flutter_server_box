//! A PVE guest's configuration as [`crate::hardware`] has it, and the
//! option strings a change writes: `GET .../config` (pending changes
//! applied, with the `digest` an edit is sent back with) and
//! `GET .../pending`, which says what the running guest has instead.
//!
//! Ported from the app's `PveResources` (`parseHardware`, `parseCloudInit`,
//! `withOptions`, `withCpuType`, `onBus`, `withNicHardware`).

use std::collections::BTreeMap;

use serde_json::{Map, Value};

use super::resources::{self, int, is_numbered, lxc_disk, natural_cmp, options, qemu_disk_bus, str_of, volume_of};
use crate::hardware::{
    CloudInitState, Cpu, DeviceKind, DiskKind, Display, Firmware, Hardware, HostDevice, HostDevices, HwDevice, HwDisk, HwNic,
    Limits, Memory, PendingField, Support,
};
use crate::model::GuestKind;

fn text(v: Option<&Value>) -> Option<String> {
    str_of(v).filter(|s| !s.is_empty())
}

fn num(v: Option<&Value>) -> Option<u64> {
    int(v).and_then(|i| u64::try_from(i).ok())
}

/// A count from a configuration, held to what a `u32` takes rather than cut.
fn count(n: u64) -> u32 {
    u32::try_from(n).unwrap_or(u32::MAX)
}

fn owned(l: &[&str]) -> Vec<String> {
    l.iter().map(|s| (*s).to_owned()).collect()
}

/// What a PVE VM's hardware can be changed to. SPICE is not a choice of its
/// own there: it comes with a `qxl` card.
pub fn qemu_support() -> Support {
    Support {
        buses: owned(&["scsi", "virtio", "sata", "ide"]),
        caches: owned(&["default", "none", "writeback", "writethrough", "directsync", "unsafe"]),
        nic_models: owned(&["virtio", "e1000", "e1000e", "rtl8139", "vmxnet3"]),
        mac: true,
        gpus: owned(&["std", "virtio", "qxl", "vmware", "cirrus", "none"]),
        uefi: true,
        secure_boot: true,
        tpm: true,
        usb: true,
        pci: true,
        ..Support::default()
    }
}

pub fn lxc_support() -> Support {
    Support { mac: true, ..Support::default() }
}

/// PVE's cloud-init drive, a volume of the VM's own:
/// `<storage>:vm-<vmid>-cloudinit`, or `<storage>:<vmid>/vm-<vmid>-cloudinit.qcow2`
/// on a storage of files.
fn is_cloud_init_volume(source: &str) -> bool {
    let Some((_, rest)) = source.split_once(':') else { return false };
    let rest = match rest.split_once('/') {
        Some((dir, file)) if !dir.is_empty() && dir.bytes().all(|b| b.is_ascii_digit()) => file,
        Some(_) => return false,
        None => rest,
    };
    let stem = ["", ".qcow2", ".raw", ".vmdk"].iter().find_map(|ext| rest.strip_suffix(&format!("-cloudinit{ext}")));
    stem.and_then(|s| s.strip_prefix("vm-")).is_some_and(|id| !id.is_empty() && id.bytes().all(|b| b.is_ascii_digit()))
}

/// `usbN` (`host=0bda:b023`, `host=1-4`, `mapping=bt`, `spice`) and
/// `hostpciN` (`0000:01:00.0,pcie=1`, `01:00`, `mapping=gpu`) as devices.
fn device(key: &str, value: &str) -> Option<HwDevice> {
    let kind = if is_numbered(key, "usb") {
        DeviceKind::Usb
    } else if is_numbered(key, "hostpci") {
        DeviceKind::Pci
    } else {
        return None;
    };
    let opts = options(value);
    let named = |k: &str| opts.iter().find(|(n, _)| *n == k).map(|(_, v)| (*v).to_owned());
    let mapping = named("mapping");
    let detail = mapping.clone().or_else(|| match kind {
        DeviceKind::Usb => named("host").or_else(|| Some(opts[0].1.to_owned())),
        _ => named("host").or_else(|| opts[0].0.is_empty().then(|| opts[0].1.to_owned())),
    });
    Some(HwDevice { key: key.to_owned(), kind, detail, mapping: mapping.is_some() })
}

/// `cpu: host,flags=+aes` or `cputype=host,…`: the model.
fn cpu_type(raw: &str) -> Option<String> {
    options(raw).into_iter().find(|(k, _)| k.is_empty() || *k == "cputype").map(|(_, v)| v.to_owned()).filter(|v| !v.is_empty())
}

/// `cpu`'s value with the model set to `cpu_type`, its other options kept.
pub fn with_cpu_type(raw: Option<&str>, cpu_type: &str) -> String {
    let mut out = vec![cpu_type.to_owned()];
    if let Some(raw) = raw {
        out.extend(options(raw).into_iter().filter(|(k, _)| !k.is_empty() && *k != "cputype").map(|(k, v)| format!("{k}={v}")));
    }
    out.join(",")
}

/// `raw` with `set` applied: a key to a value, or to None to drop it. The
/// options it does not name stay as they were, in their place — a NIC's
/// MAC among them, which rewriting the option from scratch would lose.
pub fn with_options(raw: &str, set: &[(&str, Option<String>)]) -> String {
    let mut out = Vec::new();
    let mut done = Vec::new();
    for (k, v) in options(raw) {
        if !k.is_empty()
            && let Some((_, value)) = set.iter().find(|(s, _)| *s == k)
        {
            done.push(k);
            if let Some(value) = value {
                out.push(format!("{k}={value}"));
            }
            continue;
        }
        out.push(if k.is_empty() { v.to_owned() } else { format!("{k}={v}") });
    }
    for (k, v) in set {
        if !done.contains(k)
            && let Some(v) = v
        {
            out.push(format!("{k}={v}"));
        }
    }
    out.join(",")
}

/// The disk options only some buses take (qemu-server's `Drive.pm`):
/// moving a disk to a bus that lacks one is refused, so it is dropped.
const BUS_OPTIONS: [(&str, &[&str]); 9] = [
    ("iothread", &["scsi", "virtio"]),
    ("ro", &["scsi", "virtio"]),
    ("ssd", &["ide", "sata", "scsi"]),
    ("wwn", &["ide", "sata", "scsi"]),
    ("queues", &["scsi"]),
    ("product", &["scsi"]),
    ("vendor", &["scsi"]),
    ("scsiblock", &["scsi"]),
    ("model", &["ide"]),
];

/// Disk option `raw` as `bus` takes it: less the options that bus has not.
pub fn on_bus(raw: &str, bus: &str) -> String {
    let drop: Vec<(&str, Option<String>)> =
        BUS_OPTIONS.iter().filter(|(_, buses)| !buses.contains(&bus)).map(|(k, _)| (*k, None)).collect();
    with_options(raw, &drop)
}

/// A NIC's option with its model and MAC changed: a VM's `model=MAC` pair,
/// a container's `hwaddr`. The rest stays as written.
pub fn with_nic_hardware(raw: &str, lxc: bool, model: Option<&str>, mac: Option<&str>) -> String {
    if lxc {
        return match mac {
            Some(mac) => with_options(raw, &[("hwaddr", Some(mac.to_ascii_uppercase()))]),
            None => raw.to_owned(),
        };
    }
    const MODELS: [&str; 11] =
        ["virtio", "e1000", "e1000e", "rtl8139", "vmxnet3", "i82551", "i82557b", "i82559er", "ne2k_isa", "ne2k_pci", "pcnet"];
    let mut done = false;
    options(raw)
        .into_iter()
        .map(|(k, v)| {
            if !done && MODELS.contains(&k) {
                done = true;
                let mac = mac.map(str::to_ascii_uppercase).unwrap_or_else(|| v.to_owned());
                format!("{}={mac}", model.unwrap_or(k))
            } else if k.is_empty() {
                v.to_owned()
            } else {
                format!("{k}={v}")
            }
        })
        .collect::<Vec<_>>()
        .join(",")
}

/// PVE sizes for a disk's growth: whole GiB where it is, KiB otherwise.
pub fn size_arg(bytes: u64) -> String {
    if bytes.is_multiple_of(1 << 30) { format!("{}G", bytes >> 30) } else { format!("{}K", bytes.div_ceil(1024)) }
}

/// How many drives each bus takes (`ide0`–`ide3`, …).
pub fn bus_slots(bus: &str) -> u32 {
    match bus {
        "ide" => 4,
        "sata" => 6,
        "scsi" => 31,
        "virtio" => 16,
        _ => 1,
    }
}

/// The first `<prefix>N` below `slots` that `config` does not use.
pub fn free_key(config: &Map<String, Value>, prefix: &str, slots: u32) -> Option<String> {
    (0..slots).map(|i| format!("{prefix}{i}")).find(|k| !config.contains_key(k))
}

/// `boot`: `order=scsi0;ide2;net0`, or the legacy letters (`cdn`, with
/// `bootdisk` naming the disk) read the way PVE reads them.
fn boot_order(raw: Option<&str>, config: &Map<String, Value>, disks: &[HwDisk], nics: &[HwNic]) -> Vec<String> {
    let Some(raw) = raw else { return Vec::new() };
    let opts = options(raw);
    let named = |k: &str| opts.iter().find(|(n, _)| *n == k).map(|(_, v)| *v);
    if let Some(order) = named("order") {
        return order.split(';').filter(|k| !k.is_empty()).map(str::to_owned).collect();
    }
    let legacy = named("").or_else(|| named("legacy")).unwrap_or_default();
    let mut out: Vec<String> = Vec::new();
    for c in legacy.chars() {
        let key = match c {
            'c' => text(config.get("bootdisk")).or_else(|| disks.iter().find(|d| d.kind == DiskKind::Disk).map(|d| d.key.clone())),
            'd' => disks.iter().find(|d| d.kind == DiskKind::Cdrom).map(|d| d.key.clone()),
            'n' => nics.first().map(|n| n.key.clone()),
            _ => None,
        };
        if let Some(key) = key
            && !out.contains(&key)
        {
            out.push(key);
        }
    }
    out
}

/// `config` and `pending` read into [`Hardware`]. `limits` and `cpu_types`
/// are the node's (`/nodes/{node}/status`, `.../capabilities/qemu/cpu`).
pub fn parse_hardware(
    config: &Map<String, Value>,
    pending: &[Value],
    kind: GuestKind,
    running: bool,
    limits: Limits,
    cpu_types: Vec<String>,
) -> Hardware {
    let lxc = kind == GuestKind::Lxc;
    let base = resources::parse_config(config, kind);
    let mut disks = Vec::new();
    let mut nics = Vec::new();
    let mut devices = Vec::new();
    let mut keys: Vec<&String> = config.keys().collect();
    keys.sort_by(|a, b| natural_cmp(a, b));
    for key in &keys {
        let Some(value) = config[key.as_str()].as_str() else { continue };
        let opts = options(value);
        let named = |k: &str| opts.iter().find(|(n, _)| *n == k).map(|(_, v)| (*v).to_owned());
        let is_disk = if lxc { lxc_disk(key) } else { qemu_disk_bus(key).is_some() };
        if is_disk {
            if key.starts_with("tpmstate") {
                let version = named("version").unwrap_or_else(|| "v1.2".to_owned());
                devices.push(HwDevice { key: (*key).clone(), kind: DeviceKind::Tpm, detail: Some(format!("TPM {version}")), mapping: false });
                continue;
            }
            // Detached volumes and EFI vars are not disks to edit.
            if key.starts_with("unused") || key.starts_with("efidisk") {
                continue;
            }
            let d = base.disks.iter().find(|d| d.target.as_deref() == Some(key.as_str())).cloned().unwrap_or_default();
            let source = d.source.clone();
            disks.push(HwDisk {
                key: (*key).clone(),
                kind: match d.device.as_str() {
                    "cdrom" => DiskKind::Cdrom,
                    "rootfs" => DiskKind::Rootfs,
                    "mp" => DiskKind::Mount,
                    _ => DiskKind::Disk,
                },
                size: d.size,
                storage: source.as_deref().and_then(|s| s.split_once(':')).map(|(s, _)| s.to_owned()),
                mount_point: named("mp"),
                bus: d.bus.clone(),
                format: d.format.clone(),
                readonly: d.readonly,
                cache: named("cache"),
                cloud_init: d.device == "cdrom" && source.as_deref().is_some_and(is_cloud_init_volume),
                resizable: true,
                source,
            });
            continue;
        }
        if !lxc && let Some(device) = device(key, value) {
            devices.push(device);
            continue;
        }
        if is_numbered(key, "net") {
            let n = base.nics.iter().find(|n| n.kind == key.as_str()).cloned().unwrap_or_default();
            nics.push(HwNic {
                key: (*key).clone(),
                mac: n.mac,
                nic_type: None,
                source: n.source,
                model: n.model,
                link_up: named("link_down").as_deref() != Some("1"),
                firewall: Some(named("firewall").as_deref() == Some("1")),
                name: n.target,
            });
        }
    }

    let (cpu, memory) = if lxc {
        // No `cores`: every core of the host.
        let cores = num(config.get("cores")).map(count).or(limits.host_cpus).unwrap_or(1);
        (
            Cpu { sockets: 1, cores, threads: 1, online: None, cpu_type: None },
            Memory { mib: num(config.get("memory")).unwrap_or(512), min_mib: None, balloon: false, swap_mib: Some(num(config.get("swap")).unwrap_or(512)) },
        )
    } else {
        let sockets = num(config.get("sockets")).map_or(1, count);
        let cores = num(config.get("cores")).map_or(1, count);
        let vcpus = num(config.get("vcpus")).map(count);
        // `memory` is a property string since PVE 8.1 (`current=2048`), and
        // a number before.
        let mib = match config.get("memory") {
            Some(Value::String(s)) => {
                options(s).into_iter().find(|(k, _)| k.is_empty() || *k == "current").and_then(|(_, v)| v.parse().ok())
            }
            other => num(other),
        };
        (
            Cpu {
                sockets,
                cores,
                threads: 1,
                online: vcpus.filter(|v| *v < sockets.saturating_mul(cores)),
                cpu_type: text(config.get("cpu")).as_deref().and_then(cpu_type),
            },
            Memory { mib: mib.unwrap_or(512), min_mib: num(config.get("balloon")), balloon: true, swap_mib: None },
        )
    };

    let efi = text(config.get("efidisk0"));
    let vga = text(config.get("vga"));
    let boot = (!lxc).then(|| boot_order(text(config.get("boot")).as_deref(), config, &disks, &nics));
    Hardware {
        kind,
        running,
        cpu,
        memory,
        disks,
        nics,
        boot,
        autostart: num(config.get("onboot")) == Some(1),
        name: text(config.get(if lxc { "hostname" } else { "name" })),
        description: text(config.get("description")).map(|d| d.trim_end().to_owned()).filter(|d| !d.is_empty()),
        protection: Some(num(config.get("protection")) == Some(1)),
        rename_running: true,
        pending: pending
            .iter()
            .filter_map(Value::as_object)
            .filter(|i| i.get("key").and_then(Value::as_str) != Some("digest"))
            .filter(|i| i.contains_key("pending") || i.contains_key("delete"))
            .map(|i| PendingField {
                key: value_text(i.get("key")).unwrap_or_default(),
                current: value_text(i.get("value")),
                pending: value_text(i.get("pending")),
                delete: int(i.get("delete")).is_some_and(|d| d > 0),
            })
            .collect(),
        revision: text(config.get("digest")),
        limits,
        cpu_types,
        config_text: Some(
            keys.iter()
                .filter(|k| k.as_str() != "digest" && !config[k.as_str()].is_null())
                .map(|k| format!("{k}: {}", value_text(config.get(k.as_str())).unwrap_or_default()))
                .collect::<Vec<_>>()
                .join("\n"),
        ),
        firmware: (!lxc).then(|| Firmware {
            uefi: text(config.get("bios")).as_deref() == Some("ovmf"),
            secure_boot: efi.as_deref().is_some_and(|e| options(e).contains(&("pre-enrolled-keys", "1"))),
            vars_storage: efi.as_deref().and_then(volume_of).and_then(|v| v.split_once(':').map(|(s, _)| s.to_owned())),
        }),
        display: (!lxc).then(|| Display {
            gpu: Some(vga.as_deref().map_or_else(|| "std".to_owned(), |v| options(v)[0].1.to_owned())),
            ..Display::default()
        }),
        devices,
        support: if lxc { lxc_support() } else { qemu_support() },
    }
}

/// A JSON value as PVE's form shows it: a string as it is, a number in
/// digits.
fn value_text(v: Option<&Value>) -> Option<String> {
    match v? {
        Value::String(s) => Some(s.clone()),
        Value::Null => None,
        other => Some(other.to_string()),
    }
}

/// How many `net` keys are looked at when counting a VM's NICs.
const MAX_NICS: u32 = 32;

fn words(v: Option<&Value>) -> Vec<String> {
    text(v).map(|s| s.split([' ', ',', '\t', '\n']).filter(|w| !w.is_empty()).map(str::to_owned).collect()).unwrap_or_default()
}

/// A VM's cloud-init options: `ciuser`, whether `cipassword` is set (PVE
/// answers it masked, never the value or its hash), `sshkeys` (stored
/// URL-encoded, as PVE's web UI sends them), `ipconfig0`, `nameserver`,
/// `searchdomain`, and the `digest` an edit is sent back with.
pub fn parse_cloud_init(config: &Map<String, Value>) -> CloudInitState {
    let raw_keys = text(config.get("sshkeys")).unwrap_or_default();
    let keys = percent_decode(&raw_keys).unwrap_or(raw_keys);
    let ip: BTreeMap<String, String> = text(config.get("ipconfig0"))
        .map(|s| options(&s).into_iter().map(|(k, v)| (k.to_owned(), v.to_owned())).collect())
        .unwrap_or_default();
    let address = ip.get("ip").filter(|a| *a != "dhcp" && a.contains('/')).cloned();
    CloudInitState {
        user: text(config.get("ciuser")).unwrap_or_default(),
        ssh_keys: keys.lines().map(str::trim).filter(|l| !l.is_empty()).map(str::to_owned).collect(),
        hostname: None,
        gateway: address.as_ref().and_then(|_| ip.get("gw").cloned()),
        address,
        dns: words(config.get("nameserver")),
        // One property string: several domains are a space-separated list.
        search_domains: words(config.get("searchdomain")),
        nics: (0..MAX_NICS).filter(|i| config.get(&format!("net{i}")).is_some_and(Value::is_string)).count() as u32,
        password_set: text(config.get("cipassword")).is_some(),
        // PVE writes `chpasswd: expire: false` and has no option for it.
        password_expires: false,
        network: config.get("net0").is_some_and(Value::is_string),
        foreign: false,
        revision: text(config.get("digest")).unwrap_or_default(),
    }
}

/// `%XX` decoded as UTF-8; None where it is not well formed.
fn percent_decode(s: &str) -> Option<String> {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if b[i] == b'%' {
            let hex = s.get(i + 1..i + 3)?;
            out.push(u8::from_str_radix(hex, 16).ok()?);
            i += 3;
        } else {
            out.push(b[i]);
            i += 1;
        }
    }
    String::from_utf8(out).ok()
}

/// The fields and the deletions a cloud-init edit writes, against the
/// configuration as it is (`config`). The password goes in the request
/// body; PVE keeps its hash. What `ipconfig0` holds besides the IPv4
/// settings (`ip6`) stays.
pub fn cloud_init_fields(edit: &crate::hardware::CloudInitEdit, network: bool, config: &Map<String, Value>) -> (Vec<(&'static str, String)>, Vec<&'static str>) {
    let ci = &edit.values;
    let raw = |k: &str| text(config.get(k));
    let password = ci.password.as_deref().unwrap_or_default();
    let keys = ci.keys();
    let gw = ci.address.as_ref().and(ci.gateway.clone());
    let ip = [("ip", Some(ci.address.clone().unwrap_or_else(|| "dhcp".to_owned()))), ("gw", gw)];
    let ipconfig = match raw("ipconfig0") {
        Some(r) => with_options(&r, &ip),
        None => ip.iter().filter_map(|(k, v)| v.as_ref().map(|v| format!("{k}={v}"))).collect::<Vec<_>>().join(","),
    };
    let search = ci.search_domains.join(" ");
    let mut fields = vec![("ciuser", ci.user.clone())];
    if !password.is_empty() {
        fields.push(("cipassword", password.to_owned()));
    }
    if !keys.is_empty() {
        // URL-encoded inside the form's own encoding, as at creation.
        fields.push(("sshkeys", super::seg(&format!("{}\n", keys.join("\n")))));
    }
    if network {
        fields.push(("ipconfig0", ipconfig));
    }
    if !ci.dns.is_empty() {
        fields.push(("nameserver", ci.dns.join(" ")));
    }
    if !search.is_empty() {
        fields.push(("searchdomain", search.clone()));
    }
    let mut delete = Vec::new();
    if edit.remove_password && password.is_empty() && raw("cipassword").is_some() {
        delete.push("cipassword");
    }
    if keys.is_empty() && raw("sshkeys").is_some() {
        delete.push("sshkeys");
    }
    if ci.dns.is_empty() && raw("nameserver").is_some() {
        delete.push("nameserver");
    }
    if search.is_empty() && raw("searchdomain").is_some() {
        delete.push("searchdomain");
    }
    (fields, delete)
}

/// The devices a guest on `node` can be given: resource mappings (any
/// account with `Mapping.Use`), and — `root` logged in with its password,
/// the only one PVE lets set a raw device — the node's own. The PCI list
/// says whether the node has an IOMMU at all.
pub fn host_devices(node: &str, usb_maps: &[Value], pci_maps: &[Value], pci: &[Value], usb: &[Value], root: bool) -> HostDevices {
    let mapped = |m: &Value| {
        let here = m
            .get("map")
            .and_then(Value::as_array)
            .map(|map| {
                let all: Vec<&str> = map.iter().filter_map(Value::as_str).collect();
                let here = |e: &&&str| options(e).iter().any(|(k, v)| *k == "node" && *v == node);
                all.iter().find(here).or(all.first()).map(|s| (*s).to_owned()).unwrap_or_default()
            })
            .unwrap_or_default();
        let opts = options(&here);
        let named = |k: &str| opts.iter().find(|(n, _)| *n == k).map(|(_, v)| (*v).to_owned());
        let id = value_text(m.get("id")).unwrap_or_default();
        HostDevice {
            label: id.clone(),
            id,
            detail: Some([named("path"), named("id")].into_iter().flatten().collect::<Vec<_>>().join(" · ")),
            mapping: true,
            iommu_group: named("iommugroup").and_then(|g| g.parse().ok()),
            ..HostDevice::default()
        }
    };
    let hex = |v: Option<&Value>| value_text(v).unwrap_or_default().trim_start_matches("0x").to_owned();
    let mut groups: BTreeMap<i64, u32> = BTreeMap::new();
    for p in pci {
        if let Some(g) = int(p.get("iommugroup")).filter(|g| *g >= 0) {
            *groups.entry(g).or_default() += 1;
        }
    }
    let mut out = HostDevices { mappings_only: !root, iommu: pci.is_empty() || !groups.is_empty(), ..HostDevices::default() };
    out.usb.extend(usb_maps.iter().map(mapped));
    // Hubs are not devices anyone passes through.
    out.usb.extend(usb.iter().filter(|u| int(u.get("class")) != Some(9)).map(|u| {
        let id = format!("{}:{}", value_text(u.get("vendid")).unwrap_or_default(), value_text(u.get("prodid")).unwrap_or_default());
        // Each trimmed: PVE passes the device's strings as they are, and
        // `Realtek ` + `Bluetooth Radio ` would read with two spaces.
        let label = [value_text(u.get("manufacturer")), value_text(u.get("product"))]
            .into_iter()
            .flatten()
            .map(|s| s.trim().to_owned())
            .filter(|s| !s.is_empty())
            .collect::<Vec<_>>()
            .join(" ");
        HostDevice {
            // A device that names neither: its ids, as libvirt's are shown.
            label: if label.is_empty() { id.clone() } else { label },
            detail: Some(id.clone()),
            id,
            usb_bus: num(u.get("busnum")).map(|b| b as u32),
            usb_port: value_text(u.get("usbpath")),
            ..HostDevice::default()
        }
    }));
    out.pci.extend(pci_maps.iter().map(mapped));
    if root {
        out.pci.extend(pci.iter().map(|p| {
            let group = int(p.get("iommugroup")).filter(|g| *g >= 0);
            HostDevice {
                id: value_text(p.get("id")).unwrap_or_default(),
                label: value_text(p.get("device_name")).unwrap_or_else(|| format!("{}:{}", hex(p.get("vendor")), hex(p.get("device")))),
                detail: Some([value_text(p.get("id")), value_text(p.get("vendor_name"))].into_iter().flatten().collect::<Vec<_>>().join(" · ")),
                iommu_group: group.map(|g| g as u32),
                group_size: group.and_then(|g| groups.get(&g).copied()).unwrap_or(0),
                ..HostDevice::default()
            }
        }));
    }
    out
}
