//! Reading PVE API answers into [`crate::model`]. Pure functions, tested
//! against captured payloads.
//!
//! Ported from the app's `lib/data/model/virt/pve_resources.dart`. Lenient: a
//! field missing from one entry (a guest being created has no name yet, an
//! offline node no figures) costs that field, not the whole listing.

use std::collections::{BTreeMap, BTreeSet};

use serde_json::Value;

use crate::model::{ConsoleKind, Disk, Graphics, Guest, GuestDetail, GuestKind, GuestState, Nic, Node, PowerAction, Stats};
use crate::rates::CounterSample;

/// `/cluster/resources` read: the nodes, the guests (templates included,
/// marked), and each guest's counters.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct Resources {
    pub nodes: Vec<Node>,
    pub guests: Vec<Guest>,
    pub samples: BTreeMap<String, CounterSample>,
}

/// `/cluster/resources` at `at` (Unix ms). Storages, SDN zones and anything
/// else that is not a node or a guest are skipped.
pub fn parse(raw: &[Value], at: i64) -> Resources {
    let mut out = Resources::default();
    for e in raw {
        let Some(e) = e.as_object() else { continue };
        match e.get("type").and_then(Value::as_str) {
            Some("node") => {
                let Some(name) = str_of(e.get("node")) else { continue };
                out.nodes.push(Node {
                    name,
                    online: e.get("status").and_then(Value::as_str) == Some("online"),
                    cpu: double(e.get("cpu")),
                    max_cpu: int(e.get("maxcpu")).and_then(|v| u32::try_from(v).ok()),
                    mem_used: uint(e.get("mem")),
                    mem_total: uint(e.get("maxmem")),
                    uptime: duration(e.get("uptime")),
                });
            }
            Some(kind @ ("qemu" | "lxc")) => {
                let vmid = int(e.get("vmid")).and_then(|v| u32::try_from(v).ok());
                let Some(id) = str_of(e.get("id")).or_else(|| vmid.map(|v| format!("{kind}/{v}"))) else {
                    continue;
                };
                let kind = if kind == "lxc" { GuestKind::Lxc } else { GuestKind::Qemu };
                let status = str_of(e.get("status"));
                let lock = str_of(e.get("lock"));
                let template = int(e.get("template")) == Some(1);
                let state = state_of(status.as_deref(), lock.as_deref());
                let state_reason = lock.clone().or_else(|| status.clone().filter(|s| s != state.as_str()));
                out.guests.push(Guest {
                    id: id.clone(),
                    name: str_of(e.get("name")).unwrap_or_else(|| vmid.map_or(id.clone(), |v| v.to_string())),
                    kind,
                    state,
                    state_reason,
                    vmid,
                    node: str_of(e.get("node")),
                    vcpu: int(e.get("maxcpu")).and_then(|v| u32::try_from(v).ok()),
                    mem_bytes: uint(e.get("maxmem")),
                    uptime: duration(e.get("uptime")),
                    tags: tags(e.get("tags")),
                    template,
                    autostart: None,
                    actions: if template {
                        BTreeSet::new()
                    } else {
                        actions_of(status.as_deref(), lock.as_deref(), kind, state)
                    },
                });
                // What runs, whatever holds the lock: a VM being backed up is
                // still running, and its counters still count.
                let active = state_of(status.as_deref(), None).is_active();
                let when_active = |v: Option<u64>| if active { v } else { None };
                let cpu = double(e.get("cpu"));
                out.samples.insert(
                    id,
                    CounterSample {
                        at,
                        cpu_time_ns: None,
                        cpu_percent: if active { cpu.map(|c| c * 100.0) } else { None },
                        vcpus: int(e.get("maxcpu")).and_then(|v| u32::try_from(v).ok()),
                        mem_used: when_active(uint(e.get("mem"))),
                        mem_total: uint(e.get("maxmem")),
                        // QEMU reports 0 used without the guest agent; that is
                        // "not known", not an empty disk.
                        disk_used: positive(uint(e.get("disk"))),
                        disk_total: positive(uint(e.get("maxdisk"))),
                        disk_read: when_active(uint(e.get("diskread"))),
                        disk_write: when_active(uint(e.get("diskwrite"))),
                        net_in: when_active(uint(e.get("netin"))),
                        net_out: when_active(uint(e.get("netout"))),
                    },
                );
            }
            _ => {}
        }
    }
    out
}

/// What a guest with PVE's `status` and `lock` offers, `state` being
/// [`state_of`] the two.
///
/// A lock is an operation in progress (snapshot, clone, rollback, ...) that
/// PVE refuses power actions during, with two exceptions. `suspended` is a
/// hibernated VM, which `start` resumes. `backup` still lets a VM be paused
/// and resumed (`vm_suspend` and `vm_resume` skip the lock check for it, PVE
/// 9.2 `QemuServer/RunState.pm`), which is how a paused VM that a backup job
/// picked up is woken.
pub fn actions_of(status: Option<&str>, lock: Option<&str>, kind: GuestKind, state: GuestState) -> BTreeSet<PowerAction> {
    let qemu = kind == GuestKind::Qemu;
    match lock {
        None | Some("suspended") => PowerAction::offered(state, qemu, true),
        Some("backup") if qemu => match status {
            Some("running") => BTreeSet::from([PowerAction::Suspend]),
            Some("paused") => BTreeSet::from([PowerAction::Resume]),
            _ => BTreeSet::new(),
        },
        _ => BTreeSet::new(),
    }
}

/// PVE's `status` and `lock`, as one state.
///
/// `status` is the QEMU run state where `pvestatd` has one, so beside
/// `running` and `stopped` it can be `paused`, `prelaunch`, `suspended` (S3),
/// `io-error`, `internal-error`, `guest-panicked`, ... A `lock` wins where it
/// names what the guest is busy with.
pub fn state_of(status: Option<&str>, lock: Option<&str>) -> GuestState {
    match lock {
        Some("backup") => return GuestState::Backup,
        Some("migrate") => return GuestState::Migrating,
        Some("suspending") => return GuestState::Stopping,
        _ => {}
    }
    match status {
        Some("running") => GuestState::Running,
        Some("stopped") => GuestState::Stopped,
        Some("paused" | "suspended" | "io-error") => GuestState::Paused,
        Some("prelaunch" | "inmigrate") => GuestState::Starting,
        Some("shutdown") => GuestState::Stopping,
        Some("postmigrate" | "finish-migrate") => GuestState::Migrating,
        _ => GuestState::Unknown,
    }
}

pub(crate) fn tags(v: Option<&Value>) -> Vec<String> {
    let Some(raw) = v.and_then(Value::as_str) else { return Vec::new() };
    raw.split([';', ',', ' ']).map(str::trim).filter(|t| !t.is_empty()).map(str::to_owned).collect()
}

pub(crate) fn str_of(v: Option<&Value>) -> Option<String> {
    v.and_then(Value::as_str).filter(|s| !s.is_empty()).map(str::to_owned)
}

pub(crate) fn int(v: Option<&Value>) -> Option<i64> {
    match v? {
        Value::Number(n) => n.as_i64().or_else(|| n.as_f64().map(|f| f as i64)),
        Value::String(s) => s.parse().ok(),
        _ => None,
    }
}

pub(crate) fn uint(v: Option<&Value>) -> Option<u64> {
    int(v).and_then(|i| u64::try_from(i).ok())
}

pub(crate) fn double(v: Option<&Value>) -> Option<f64> {
    match v? {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.parse().ok(),
        _ => None,
    }
}

fn positive(v: Option<u64>) -> Option<u64> {
    v.filter(|v| *v > 0)
}

fn duration(v: Option<&Value>) -> Option<u64> {
    int(v).filter(|s| *s > 0).map(|s| s as u64)
}

// ---------------------------------------------------------------------------
// A guest's configuration and its stored history
// ---------------------------------------------------------------------------

/// `/nodes/{node}/{type}/{vmid}/rrddata`: rates already, bytes per second;
/// oldest first.
pub fn parse_rrd(raw: &[Value]) -> Vec<Stats> {
    let mut out: Vec<Stats> = raw
        .iter()
        .filter_map(Value::as_object)
        .filter_map(|e| {
            let time = int(e.get("time"))?;
            let rounded = |k: &str| double(e.get(k)).map(|v| v.round().max(0.0) as u64);
            Some(Stats {
                at: time * 1000,
                cpu: double(e.get("cpu")).map(|c| c * 100.0),
                mem_used: rounded("mem"),
                mem_total: rounded("maxmem"),
                disk_used: positive(rounded("disk")),
                disk_total: positive(rounded("maxdisk")),
                disk_read: double(e.get("diskread")),
                disk_write: double(e.get("diskwrite")),
                net_in: double(e.get("netin")),
                net_out: double(e.get("netout")),
            })
        })
        .collect();
    out.sort_by_key(|s| s.at);
    out
}

/// `/nodes/{node}/{type}/{vmid}/config`.
pub fn parse_config(config: &serde_json::Map<String, Value>, kind: GuestKind) -> GuestDetail {
    let qemu = kind == GuestKind::Qemu;
    let mut disks = Vec::new();
    let mut nics = Vec::new();
    let mut has_serial = false;
    let mut keys: Vec<&String> = config.keys().collect();
    keys.sort_by(|a, b| natural_cmp(a, b));
    for key in keys {
        let Some(value) = config[key].as_str() else { continue };
        if qemu && is_numbered(key, "serial") {
            has_serial = true;
        }
        let bus = if qemu { qemu_disk_bus(key) } else { lxc_disk(key).then_some("") };
        if let Some(bus) = bus {
            disks.push(disk(key, value, kind, bus));
            continue;
        }
        if is_numbered(key, "net") {
            nics.push(nic(key, value, kind));
        }
    }
    let vga = config
        .get("vga")
        .and_then(Value::as_str)
        .map(|v| options(v)[0].1.to_owned())
        .unwrap_or_else(|| "std".to_owned());
    // `vga: serial0` puts the display on the serial port, and `none` has no
    // display: neither has a VNC console.
    let has_vnc = vga != "none" && !vga.starts_with("serial");
    let mut consoles = BTreeSet::new();
    match kind {
        GuestKind::Lxc => {
            consoles.insert(ConsoleKind::Text);
        }
        GuestKind::Qemu => {
            if has_vnc {
                consoles.insert(ConsoleKind::Vnc);
            }
            if has_serial {
                consoles.insert(ConsoleKind::Text);
            }
        }
    }
    GuestDetail {
        disks,
        nics,
        graphics: if qemu { vec![Graphics { kind: vga, ..Graphics::default() }] } else { Vec::new() },
        display: None,
        consoles,
        description: str_of(config.get("description")),
        arch: str_of(config.get("arch")),
        machine: str_of(config.get("ostype")).or_else(|| str_of(config.get("machine"))),
    }
}

/// The first serial port in a QEMU guest's configuration — what `termproxy`
/// attaches to (it accepts `serial0` to `serial3`) — or `serial0`.
pub fn serial_device(config: &serde_json::Map<String, Value>) -> String {
    let mut ports: Vec<&String> = config
        .keys()
        .filter(|k| k.strip_prefix("serial").is_some_and(|n| matches!(n, "0" | "1" | "2" | "3")))
        .collect();
    ports.sort();
    ports.first().map_or_else(|| "serial0".to_owned(), |p| (*p).clone())
}

fn disk(key: &str, value: &str, kind: GuestKind, bus: &str) -> Disk {
    let opts = options(value);
    let named = |k: &str| opts.iter().find(|(n, _)| *n == k).map(|(_, v)| (*v).to_owned());
    let media = named("media");
    let source = volume_of(value).filter(|v| v != "none");
    let device = match kind {
        GuestKind::Lxc if key == "rootfs" => "rootfs",
        GuestKind::Lxc => "mp",
        GuestKind::Qemu if media.as_deref() == Some("cdrom") => "cdrom",
        GuestKind::Qemu => "disk",
    };
    Disk {
        device: device.to_owned(),
        source_type: None,
        source,
        target: Some(key.to_owned()),
        bus: (kind == GuestKind::Qemu).then(|| bus.to_owned()),
        format: named("format"),
        readonly: named("ro").as_deref() == Some("1") || media.as_deref() == Some("cdrom"),
        size: named("size").as_deref().and_then(size_of),
    }
}

fn nic(key: &str, value: &str, kind: GuestKind) -> Nic {
    let opts = options(value);
    let named = |k: &str| opts.iter().find(|(n, _)| *n == k).map(|(_, v)| (*v).to_owned());
    if kind == GuestKind::Lxc {
        return Nic {
            kind: key.to_owned(),
            mac: named("hwaddr"),
            source: named("bridge"),
            model: named("type").or_else(|| Some("veth".to_owned())),
            target: named("name"),
        };
    }
    // `virtio=BC:24:11:AA:BB:CC,bridge=vmbr0`: the model is the key of the
    // pair that carries the MAC.
    const MODELS: &[&str] =
        &["virtio", "e1000", "e1000e", "rtl8139", "vmxnet3", "i82551", "i82557b", "i82559er", "ne2k_isa", "ne2k_pci", "pcnet"];
    let found = opts.iter().find(|(k, _)| MODELS.contains(k));
    Nic {
        kind: key.to_owned(),
        mac: found.and_then(|(_, v)| (!v.is_empty()).then(|| (*v).to_owned())).or_else(|| named("macaddr")),
        source: named("bridge"),
        model: found.map(|(k, _)| (*k).to_owned()).or_else(|| named("model")),
        target: None,
    }
}

/// `a,b=c,d=e` → `[("", a), (b, c), (d, e)]`.
pub fn options(value: &str) -> Vec<(&str, &str)> {
    value.split(',').map(|part| part.split_once('=').unwrap_or(("", part))).collect()
}

/// A disk value's volume: its first bare word, or `file=`.
pub fn volume_of(raw: &str) -> Option<String> {
    let opts = options(raw);
    if opts[0].0.is_empty() {
        return Some(opts[0].1.to_owned());
    }
    opts.iter().find(|(k, _)| *k == "file").map(|(_, v)| (*v).to_owned())
}

/// PVE sizes: `32G`, `512M`, `1T`, `4096` (bytes).
pub fn size_of(s: &str) -> Option<u64> {
    let last = s.chars().last()?;
    let unit: Option<u64> = match last.to_ascii_uppercase() {
        'K' => Some(1 << 10),
        'M' => Some(1 << 20),
        'G' => Some(1 << 30),
        'T' => Some(1 << 40),
        _ => None,
    };
    let number: f64 = if unit.is_some() { s[..s.len() - 1].parse().ok()? } else { s.parse().ok()? };
    Some((number * unit.unwrap_or(1) as f64).round() as u64)
}

/// `scsi2` before `scsi10`.
pub fn natural_cmp(a: &str, b: &str) -> std::cmp::Ordering {
    let split = |s: &str| {
        let at = s.find(|c: char| c.is_ascii_digit()).unwrap_or(s.len());
        let (head, digits) = s.split_at(at);
        (head.to_owned(), digits.parse::<i64>().unwrap_or(-1), digits.chars().all(|c| c.is_ascii_digit()))
    };
    let (ha, na, da) = split(a);
    let (hb, nb, db) = split(b);
    if !da || !db {
        return a.cmp(b);
    }
    ha.cmp(&hb).then(na.cmp(&nb))
}

fn is_numbered(key: &str, prefix: &str) -> bool {
    key.strip_prefix(prefix).is_some_and(|n| !n.is_empty() && n.bytes().all(|b| b.is_ascii_digit()))
}

/// The bus of a QEMU disk key (`scsi0` → `scsi`), or None.
fn qemu_disk_bus(key: &str) -> Option<&str> {
    ["ide", "sata", "scsi", "virtio", "efidisk", "tpmstate", "unused"]
        .into_iter()
        .find(|bus| is_numbered(key, bus))
}

fn lxc_disk(key: &str) -> bool {
    key == "rootfs" || is_numbered(key, "mp") || is_numbered(key, "unused")
}
