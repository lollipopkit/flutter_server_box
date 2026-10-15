//! A Linux machine's storage, as a NAS manages it: its disks and partitions
//! with their filesystems and mounts (`lsblk`), software RAID arrays
//! (`/proc/mdstat`, mdadm), ZFS pools (`zpool`), and what can be done to
//! them: partition a disk, format, mount (and keep it in `/etc/fstab`),
//! unmount, build or change an array, build or scrub a pool, start a SMART
//! test.
//!
//! Every change is a shell script run as root ([`StorageAction::script`]).
//! What makes one safe is decided here too ([`in_use`]): a device that holds
//! a mounted filesystem, swap, or a member of an array or pool in use is not
//! partitioned, formatted or put into a new array.

use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::script::shell_quote_unix as q;

// -----------------------------------------------------------------------------
// Block devices
// -----------------------------------------------------------------------------

/// Every block device as a tree (disks, their partitions, what is built on
/// them), sizes in bytes; read by [`parse_lsblk`].
pub const LSBLK_COMMAND: &str = "lsblk -J -b -o NAME,PATH,TYPE,SIZE,MODEL,SERIAL,ROTA,TRAN,RM,RO,PARTTYPE,FSTYPE,LABEL,UUID,MOUNTPOINTS,FSSIZE,FSAVAIL,FSUSED";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BlockDevice {
    pub name: String,
    pub path: String,
    /// `disk`, `part`, `raid1`…, `lvm`, `crypt`, `loop`, `rom`.
    pub kind: String,
    pub size: u64,
    pub model: Option<String>,
    pub serial: Option<String>,
    pub rotational: bool,
    /// `sata`, `nvme`, `usb`…
    pub transport: Option<String>,
    pub removable: bool,
    pub read_only: bool,
    /// The partition table's type: a GPT GUID or an MBR `0x..` id.
    #[serde(default)]
    pub part_type: Option<String>,
    pub fstype: Option<String>,
    pub label: Option<String>,
    pub uuid: Option<String>,
    /// `[SWAP]` for swap.
    pub mountpoints: Vec<String>,
    /// The filesystem's size, mounted only: below the device's after the
    /// device grew, until the filesystem is expanded.
    #[serde(default)]
    pub fs_size: Option<u64>,
    pub available: Option<u64>,
    pub used: Option<u64>,
    pub children: Vec<BlockDevice>,
}

fn text(v: &Value) -> Option<String> {
    match v {
        Value::String(s) if !s.trim().is_empty() => Some(s.trim().to_string()),
        _ => None,
    }
}

/// A number lsblk prints as a number or (older util-linux) as text.
fn number(v: &Value) -> Option<u64> {
    match v {
        Value::Number(n) => n.as_u64(),
        Value::String(s) => s.trim().parse().ok(),
        _ => None,
    }
}

/// A flag lsblk prints as a boolean or as `0`/`1`.
fn flag(v: &Value) -> bool {
    match v {
        Value::Bool(b) => *b,
        Value::String(s) => s.trim() == "1",
        Value::Number(n) => n.as_u64() == Some(1),
        _ => false,
    }
}

fn device(v: &Value) -> Option<BlockDevice> {
    let name = text(&v["name"])?;
    // Older lsblk prints one `mountpoint`.
    let mountpoints = match &v["mountpoints"] {
        Value::Array(items) => items.iter().filter_map(text).collect(),
        _ => text(&v["mountpoint"]).into_iter().collect(),
    };
    Some(BlockDevice {
        path: text(&v["path"]).unwrap_or_else(|| format!("/dev/{name}")),
        name,
        kind: text(&v["type"]).unwrap_or_default(),
        size: number(&v["size"]).unwrap_or(0),
        model: text(&v["model"]),
        serial: text(&v["serial"]),
        rotational: flag(&v["rota"]),
        transport: text(&v["tran"]),
        removable: flag(&v["rm"]),
        read_only: flag(&v["ro"]),
        part_type: text(&v["parttype"]).map(|t| t.to_ascii_lowercase()),
        fstype: text(&v["fstype"]),
        label: text(&v["label"]),
        uuid: text(&v["uuid"]),
        mountpoints,
        fs_size: number(&v["fssize"]),
        available: number(&v["fsavail"]),
        used: number(&v["fsused"]),
        children: v["children"].as_array().map(|c| c.iter().filter_map(device).collect()).unwrap_or_default(),
    })
}

/// Reads [`LSBLK_COMMAND`]'s JSON; nothing when it is not that.
pub fn parse_lsblk(stdout: &str) -> Vec<BlockDevice> {
    serde_json::from_str::<Value>(stdout)
        .ok()
        .and_then(|v| v["blockdevices"].as_array().map(|d| d.iter().filter_map(device).collect()))
        .unwrap_or_default()
}

impl BlockDevice {
    /// This device and everything under it.
    pub fn walk(&self) -> Vec<&BlockDevice> {
        let mut out = vec![self];
        for c in &self.children {
            out.extend(c.walk());
        }
        out
    }
}

/// [path] anywhere in [devices].
pub fn find<'a>(devices: &'a [BlockDevice], path: &str) -> Option<&'a BlockDevice> {
    devices.iter().flat_map(BlockDevice::walk).find(|d| d.path == path)
}

/// The devices arrays and pools hold now: an md member's name (`sdb1`, from
/// `/proc/mdstat`, inactive arrays included) and a pool's device paths (from
/// `zpool status -P`). A device carrying an old array's or pool's signature
/// and in neither is free: what made it is gone.
#[derive(Debug, Clone, Default)]
pub struct Held {
    pub md_members: Vec<String>,
    pub pool_devices: Vec<String>,
}

impl Held {
    pub fn of(arrays: &[MdArray], pools: &[Pool]) -> Self {
        Self {
            md_members: arrays.iter().flat_map(|a| a.members.iter().map(|m| m.name.clone())).collect(),
            pool_devices: pools.iter().flat_map(|p| p.vdevs.iter().map(|v| v.name.clone())).filter(|n| n.starts_with('/')).collect(),
        }
    }
}

/// Two of [paths] are one device and something on it (a disk and its
/// partition): never put into one array or pool together.
pub fn overlapping(devices: &[BlockDevice], paths: &[&str]) -> bool {
    paths.iter().any(|p| find(devices, p).is_some_and(|d| d.walk().iter().skip(1).any(|c| paths.contains(&c.path.as_str()))))
}

/// Partitions firmware or another system needs, never formatted or built
/// on, even with nothing mounted: EFI system, BIOS boot, Microsoft reserved,
/// Windows recovery (GPT), EFI and GPT protective (MBR).
const SYSTEM_PART_TYPES: &[&str] = &[
    "c12a7328-f81f-11d2-ba4b-00a0c93ec93b",
    "21686148-6449-6e6f-744e-656564454649",
    "e3c9e316-0b5c-4db8-817d-f92df00215ae",
    "de94bba4-06d1-4d40-a16a-bfd50179d6ac",
    "0xef",
    "0xee",
];

/// A mounted filesystem [`StorageAction::ExpandFilesystem`] can grow
/// online: ext2/3/4, xfs, btrfs.
pub fn growable(dev: &BlockDevice) -> bool {
    dev.mountpoints.iter().any(|m| m.starts_with('/')) && matches!(dev.fstype.as_deref(), Some("ext2" | "ext3" | "ext4" | "xfs" | "btrfs"))
}

/// [dev] is mounted where the system lives (`/`, `/boot/efi`, …): also
/// mounted elsewhere, it is never unmounted from here.
pub fn system_mounted(dev: &BlockDevice) -> bool {
    dev.mountpoints.iter().any(|m| m != "[SWAP]" && mountpoint_ok(m).is_err())
}

/// Why [mountpoint] may not be unmounted: nothing listed is mounted there,
/// or what is serves the system too ([`system_mounted`]).
pub fn unmount_refusal(devices: &[BlockDevice], mountpoint: &str) -> Option<&'static str> {
    let mountpoint = match mountpoint.trim_end_matches('/') {
        "" => "/",
        m => m,
    };
    let Some(dev) = devices.iter().flat_map(BlockDevice::walk).find(|d| d.mountpoints.iter().any(|m| m == mountpoint)) else {
        return Some("notMounted");
    };
    system_mounted(dev).then_some("systemMount")
}

/// Why [path] may not be partitioned, formatted or given to a new array or
/// pool: it (or something on it) is mounted, is swap, is a member of an array
/// or pool [held] names; it is read only; it is not found. `None` when it is
/// free.
pub fn in_use(devices: &[BlockDevice], path: &str, held: &Held) -> Option<&'static str> {
    let Some(dev) = find(devices, path) else { return Some("notFound") };
    if dev.read_only {
        return Some("readOnly");
    }
    for d in dev.walk() {
        if d.mountpoints.iter().any(|m| m == "[SWAP]") {
            return Some("swap");
        }
        if !d.mountpoints.is_empty() {
            return Some("mounted");
        }
        if held.md_members.contains(&d.name) {
            return Some("raidMember");
        }
        if held.pool_devices.contains(&d.path) {
            return Some("poolMember");
        }
        if d.part_type.as_deref().is_some_and(|t| SYSTEM_PART_TYPES.contains(&t)) {
            return Some("systemPartition");
        }
        if d.fstype.as_deref() == Some("LVM2_member") {
            return Some("lvmMember");
        }
        // An array or volume built on it (`raid1`, `lvm`, `crypt` children).
        if d.path != dev.path && d.kind != "part" {
            return Some("holdsVolume");
        }
    }
    None
}

// -----------------------------------------------------------------------------
// Software RAID
// -----------------------------------------------------------------------------

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MdArray {
    /// `md0`.
    pub name: String,
    /// `active`, `inactive`, `active (auto-read-only)`.
    pub state: String,
    /// `raid1`…; `None` for an inactive array.
    pub level: Option<String>,
    pub members: Vec<MdMember>,
    /// Devices it is made of, and of them working (`[2/1]`).
    pub raid_disks: Option<u32>,
    pub working_disks: Option<u32>,
    /// A sync running: `resync`, `recovery`, `check`, `reshape`.
    pub sync: Option<MdSync>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MdMember {
    /// `sdb1`.
    pub name: String,
    pub faulty: bool,
    pub spare: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MdSync {
    pub action: String,
    /// Tenths of a percent.
    pub permille: u32,
    pub finish: Option<String>,
}

impl MdArray {
    pub fn degraded(&self) -> bool {
        matches!((self.raid_disks, self.working_disks), (Some(n), Some(w)) if w < n)
    }
}

/// Reads `/proc/mdstat`.
pub fn parse_mdstat(text: &str) -> Vec<MdArray> {
    let mut out: Vec<MdArray> = Vec::new();
    for line in text.lines() {
        let trimmed = line.trim();
        if let Some((name, rest)) = line.split_once(" : ")
            && name.starts_with("md")
            && !name.contains(' ')
        {
            let mut words = rest.split_whitespace().peekable();
            let mut state = words.next().unwrap_or_default().to_string();
            if words.peek().is_some_and(|w| w.starts_with('(')) {
                state = format!("{state} {}", words.next().unwrap_or_default());
            }
            let level = words.peek().filter(|w| w.starts_with("raid") || *w == &"linear").map(|w| w.to_string());
            if level.is_some() {
                words.next();
            }
            let members = words
                .filter_map(|w| {
                    let (name, _) = w.split_once('[')?;
                    Some(MdMember { name: name.to_string(), faulty: w.ends_with("(F)"), spare: w.ends_with("(S)") })
                })
                .collect();
            out.push(MdArray { name: name.to_string(), state, level, members, raid_disks: None, working_disks: None, sync: None });
            continue;
        }
        let Some(array) = out.last_mut() else { continue };
        // `1046528 blocks super 1.2 [2/1] [U_]`
        if let Some(counts) = trimmed.split_whitespace().find(|w| w.starts_with('[') && w.contains('/') && w.ends_with(']')) {
            let inner = &counts[1..counts.len() - 1];
            if let Some((n, w)) = inner.split_once('/') {
                array.raid_disks = n.parse().ok();
                array.working_disks = w.parse().ok();
            }
        }
        // `[==>...]  recovery = 12.6% (132096/1046528) finish=0.1min speed=…`
        for action in ["resync", "recovery", "check", "reshape", "repair"] {
            let marker = format!("{action} =");
            if let Some(at) = trimmed.find(&marker) {
                let after = trimmed[at + marker.len()..].trim_start();
                let percent: f64 = after.split('%').next().and_then(|p| p.trim().parse().ok()).unwrap_or(0.0);
                let finish = after.split_whitespace().find_map(|w| w.strip_prefix("finish=")).map(String::from);
                array.sync = Some(MdSync { action: action.into(), permille: (percent * 10.0).round() as u32, finish });
            }
        }
    }
    out
}

// -----------------------------------------------------------------------------
// ZFS
// -----------------------------------------------------------------------------

/// Every pool's size and health, tab separated, sizes in bytes.
pub const ZPOOL_LIST_COMMAND: &str = "zpool list -Hp -o name,size,alloc,free,health";
/// Every pool's layout and errors.
pub const ZPOOL_STATUS_COMMAND: &str = "zpool status -P";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Pool {
    pub name: String,
    pub size: u64,
    pub allocated: u64,
    pub free: u64,
    /// `ONLINE`, `DEGRADED`, `FAULTED`…
    pub health: String,
    /// From `zpool status`: the last or running scrub or resilver.
    pub scan: Option<String>,
    /// A scrub or resilver is running now: what a page polls faster for.
    #[serde(default)]
    pub scanning: bool,
    pub vdevs: Vec<Vdev>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Vdev {
    /// `mirror-0`, `raidz1-0`, a device path.
    pub name: String,
    pub state: String,
    /// 0 for the pool's own vdevs, 1 for what they are made of.
    pub depth: u32,
    pub errors: u64,
    /// Outside the data vdevs: `spares`, `logs`, `cache`, `special`, `dedup`.
    #[serde(default)]
    pub section: Option<String>,
}

pub fn parse_zpool_list(stdout: &str) -> Vec<Pool> {
    stdout
        .lines()
        .filter_map(|l| {
            let f: Vec<&str> = l.split('\t').collect();
            (f.len() >= 5).then(|| Pool {
                name: f[0].to_string(),
                size: f[1].parse().unwrap_or(0),
                allocated: f[2].parse().unwrap_or(0),
                free: f[3].parse().unwrap_or(0),
                health: f[4].to_string(),
                scan: None,
                scanning: false,
                vdevs: Vec::new(),
            })
        })
        .collect()
}

const SECTIONS: &[&str] = &["spares", "logs", "cache", "special", "dedup"];

/// Adds `zpool status`'s scan line and vdev tree to [pools].
pub fn merge_zpool_status(pools: &mut [Pool], stdout: &str) {
    let mut current: Option<usize> = None;
    let mut in_config = false;
    let mut base_indent = 0;
    let mut section: Option<String> = None;
    for line in stdout.lines() {
        let trimmed = line.trim();
        if let Some(name) = trimmed.strip_prefix("pool: ") {
            current = pools.iter().position(|p| p.name == name);
            in_config = false;
            section = None;
            continue;
        }
        let Some(i) = current else { continue };
        if let Some(scan) = trimmed.strip_prefix("scan: ") {
            // `scrub in progress since …`, `resilver in progress since …`.
            pools[i].scanning = scan.contains(" in progress");
            pools[i].scan = Some(scan.to_string());
        } else if trimmed.starts_with("NAME") && trimmed.contains("STATE") {
            in_config = true;
            base_indent = line.len() - line.trim_start().len();
        } else if trimmed.starts_with("errors:") || trimmed.is_empty() && in_config && !pools[i].vdevs.is_empty() {
            in_config = false;
        } else if in_config && !trimmed.is_empty() {
            let indent = line.len() - line.trim_start().len();
            let f: Vec<&str> = trimmed.split_whitespace().collect();
            // `spares`, `logs`… stand alone at the pool's indent and head
            // what follows.
            if f.len() == 1 && indent == base_indent && SECTIONS.contains(&f[0]) {
                section = Some(f[0].to_string());
                continue;
            }
            if f.len() < 2 || f[0] == pools[i].name {
                continue;
            }
            // The pool's own line is at the header's indent, its vdevs two
            // further, what they are made of two more.
            let depth = (indent.saturating_sub(base_indent + 2) / 2) as u32;
            let errors = f.iter().skip(2).take(3).filter_map(|e| e.parse::<u64>().ok()).sum();
            pools[i].vdevs.push(Vdev { name: f[0].to_string(), state: f[1].to_string(), depth, errors, section: section.clone() });
        }
    }
}

// -----------------------------------------------------------------------------
// Disk health (SMART)
// -----------------------------------------------------------------------------

/// What makes a script's privileged commands root's when it runs without a
/// password (the schedule, the watch): nothing as root, else `sudo -n` per
/// command, so a sudoers rule naming just those commands is enough
/// (`smartctl`, `zpool scrub`, `mdadm --action=check`). `$S` before each.
pub const UNATTENDED: &str = r#"S=; [ "$(id -u)" = 0 ] || S="sudo -n";"#;

/// Every disk's SMART reading, each after a `### <path>` line; read by
/// [`parse_health`]. Root's (raw disk access): run as root, or unattended
/// (its `$S`). `-n standby` leaves a disk that has spun down asleep.
pub const HEALTH_COMMAND: &str = r####"command -v smartctl >/dev/null || exit 0; S=; [ "$(id -u)" = 0 ] || S="sudo -n"; for d in $(lsblk -dn -o PATH,TYPE | awk '$2 == "disk" && $1 !~ /zram/ { print $1 }'); do echo "### $d"; $S smartctl -n standby -a -j "$d"; done; true"####;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DiskHealth {
    pub device: String,
    /// The disk answers SMART: false for a virtual disk or a USB bridge
    /// that passes none through, which has nothing to read or test.
    pub supported: bool,
    /// Spun down, and not woken to be read.
    pub asleep: bool,
    /// The disk's own verdict.
    pub passed: Option<bool>,
    pub temperature: Option<f64>,
    pub power_on_hours: Option<i64>,
    /// Sectors remapped, pending or unreadable (ATA), media errors (NVMe),
    /// grown defects (SCSI): above zero, the disk is wearing out.
    pub bad_sectors: Option<i64>,
    /// Percent left of a self-test running now.
    pub testing: Option<u8>,
    /// The newest self-test that ended.
    pub last_test: Option<SelfTest>,
    /// Everything the disk reports, for its details: ATA attributes, or the
    /// NVMe health log's fields.
    #[serde(default)]
    pub attributes: Vec<SmartAttribute>,
    /// Self-tests that ended, newest first.
    #[serde(default)]
    pub tests: Vec<SelfTest>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SmartAttribute {
    /// The ATA attribute id; none for an NVMe field.
    pub id: Option<i64>,
    pub name: String,
    /// Normalized value, worst seen and the failure threshold (ATA).
    pub value: Option<i64>,
    pub worst: Option<i64>,
    pub thresh: Option<i64>,
    /// The raw value as smartctl prints it.
    pub raw: String,
    /// At or below its threshold now, or failed before.
    pub failing: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SelfTest {
    pub long: bool,
    /// `passed`, `failed`, `aborted` (stopped by the host or a reset).
    pub outcome: String,
    pub hours: Option<i64>,
}

/// Reads [`HEALTH_COMMAND`]'s output.
pub fn parse_health(stdout: &str) -> Vec<DiskHealth> {
    let mut out = Vec::new();
    let mut device: Option<&str> = None;
    let mut json = String::new();
    let mut flush = |device: Option<&str>, json: &mut String| {
        if let Some(device) = device {
            out.push(health_of(device, serde_json::from_str(json).unwrap_or(Value::Null)));
        }
        json.clear();
    };
    for line in stdout.lines() {
        if let Some(next) = line.strip_prefix("### ") {
            flush(device, &mut json);
            device = Some(next.trim());
        } else {
            json.push_str(line);
            json.push('\n');
        }
    }
    flush(device, &mut json);
    out
}

fn health_of(device: &str, d: Value) -> DiskHealth {
    let exit = d["smartctl"]["exit_status"].as_i64().unwrap_or(0);
    let said = |needle: &str| {
        d["smartctl"]["messages"].as_array().is_some_and(|m| m.iter().any(|m| m["string"].as_str().is_some_and(|s| s.to_ascii_uppercase().contains(needle))))
    };
    // Bit 1: not opened, or asleep and left so.
    let asleep = exit & 2 != 0 && said("STANDBY");
    let nvme = &d["nvme_smart_health_information_log"];
    let supported = exit & 2 == 0 && (d["smart_support"]["available"].as_bool().unwrap_or(false) || nvme.is_object());
    if !supported {
        return DiskHealth {
            device: device.into(),
            supported: false,
            asleep,
            passed: None,
            temperature: None,
            power_on_hours: None,
            bad_sectors: None,
            testing: None,
            last_test: None,
            attributes: Vec::new(),
            tests: Vec::new(),
        };
    }
    let attrs = d["ata_smart_attributes"]["table"].as_array();
    let raw = |id: i64| attrs.and_then(|t| t.iter().find(|a| a["id"].as_i64() == Some(id))).and_then(|a| a["raw"]["value"].as_i64());
    let bad_sectors = if attrs.is_some() {
        let ids = [5, 197, 198].map(raw);
        ids.iter().any(Option::is_some).then(|| ids.iter().flatten().sum())
    } else {
        nvme["media_errors"].as_i64().or_else(|| d["scsi_grown_defect_list"].as_i64())
    };
    DiskHealth {
        device: device.into(),
        supported: true,
        asleep: false,
        passed: d["smart_status"]["passed"].as_bool(),
        temperature: d["temperature"]["current"].as_f64().or_else(|| raw(194).map(|t| (t & 0xff) as f64)),
        power_on_hours: d["power_on_time"]["hours"].as_i64().or_else(|| nvme["power_on_hours"].as_i64()),
        bad_sectors,
        testing: testing(&d),
        last_test: self_tests(&d).into_iter().next(),
        attributes: attributes(&d),
        tests: self_tests(&d),
    }
}

fn attributes(d: &Value) -> Vec<SmartAttribute> {
    if let Some(table) = d["ata_smart_attributes"]["table"].as_array() {
        return table
            .iter()
            .filter_map(|a| {
                let (value, thresh) = (a["value"].as_i64(), a["thresh"].as_i64());
                let failed_before = a["when_failed"].as_str().is_some_and(|w| !w.is_empty() && w != "never");
                Some(SmartAttribute {
                    id: a["id"].as_i64(),
                    name: a["name"].as_str()?.to_string(),
                    value,
                    worst: a["worst"].as_i64(),
                    thresh,
                    raw: a["raw"]["string"].as_str().map(str::to_string).unwrap_or_else(|| a["raw"]["value"].to_string()),
                    failing: failed_before || matches!((value, thresh), (Some(v), Some(t)) if t > 0 && v <= t),
                })
            })
            .collect();
    }
    let Some(log) = d["nvme_smart_health_information_log"].as_object() else { return Vec::new() };
    log.iter()
        .filter(|(k, v)| *k != "nsid" && (v.is_number() || v.is_array()))
        .map(|(k, v)| SmartAttribute {
            id: None,
            name: k.clone(),
            value: None,
            worst: None,
            thresh: None,
            raw: v.to_string(),
            failing: (k == "critical_warning" || k == "media_errors") && v.as_i64().is_some_and(|n| n > 0),
        })
        .collect()
}

fn testing(d: &Value) -> Option<u8> {
    let ata = &d["ata_smart_data"]["self_test"]["status"];
    if let Some(left) = ata["remaining_percent"].as_u64() {
        return Some(left.min(100) as u8);
    }
    let nvme = &d["nvme_self_test_log"];
    if nvme["current_self_test_operation"]["value"].as_u64().is_some_and(|v| v != 0) {
        let done = nvme["current_self_test_completion_percent"].as_u64().unwrap_or(0).min(100);
        return Some((100 - done) as u8);
    }
    let scsi = &d["scsi_self_test_0"];
    (scsi["result"]["value"].as_u64() == Some(15)).then(|| scsi["remaining_percent"].as_u64().unwrap_or(100).min(100) as u8)
}

fn self_tests(d: &Value) -> Vec<SelfTest> {
    // Newest first in every log; the one running has no result yet.
    if let Some(table) = d["ata_smart_self_test_log"]["standard"]["table"].as_array() {
        return table
            .iter()
            .filter(|t| t["status"]["value"].as_u64() != Some(15))
            .map(|t| {
                let status = t["status"]["value"].as_u64().unwrap_or(0);
                let outcome = match (status, t["status"]["passed"].as_bool()) {
                    (1 | 2, _) => "aborted",
                    (_, Some(true)) | (0, None) => "passed",
                    _ => "failed",
                };
                SelfTest { long: t["type"]["value"].as_u64().is_some_and(|v| v & 0x7f == 2), outcome: outcome.into(), hours: t["lifetime_hours"].as_i64() }
            })
            .collect();
    }
    if let Some(table) = d["nvme_self_test_log"]["table"].as_array() {
        return table
            .iter()
            .map(|t| {
                let outcome = match t["self_test_result"]["value"].as_u64().unwrap_or(0) {
                    0 => "passed",
                    5..=7 => "failed",
                    _ => "aborted",
                };
                SelfTest { long: t["self_test_code"]["value"].as_u64() == Some(2), outcome: outcome.into(), hours: t["power_on_hours"].as_i64() }
            })
            .collect();
    }
    let t = &d["scsi_self_test_0"];
    let Some(result) = t["result"]["value"].as_u64() else { return Vec::new() };
    let outcome = match result {
        15 => return Vec::new(),
        0 => "passed",
        1 | 2 => "aborted",
        _ => "failed",
    };
    vec![SelfTest { long: matches!(t["code"]["value"].as_u64(), Some(2 | 6)), outcome: outcome.into(), hours: t["power_on_time"]["hours"].as_i64() }]
}

// -----------------------------------------------------------------------------
// Maintenance (scheduled, unattended)
// -----------------------------------------------------------------------------

/// What the schedule runs, without a password ([`UNATTENDED`]).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum Maintenance {
    /// Every pool scrubbed and every redundant md array checked, skipping
    /// one already at it.
    Scrub,
    SmartShort,
    SmartLong,
}

impl Maintenance {
    pub const ALL: [Maintenance; 3] = [Self::Scrub, Self::SmartShort, Self::SmartLong];

    pub fn name(self) -> &'static str {
        match self {
            Self::Scrub => "scrub",
            Self::SmartShort => "smartShort",
            Self::SmartLong => "smartLong",
        }
    }

    pub fn from_name(name: &str) -> Option<Self> {
        Self::ALL.into_iter().find(|m| m.name() == name)
    }

    /// The script; a SMART test is started on [disks] (those whose SMART
    /// answers, [`DiskHealth::supported`]). Exits non-zero when one failed.
    pub fn script(self, disks: &[String]) -> Result<String, StorageError> {
        Ok(match self {
            Self::Scrub => format!(
                "{UNATTENDED} r=0; \
                 for p in $(zpool list -H -o name 2>/dev/null); do \
                 zpool status \"$p\" | grep -q 'scrub in progress' && continue; $S zpool scrub \"$p\" || r=1; done; \
                 for a in /sys/block/md*/md/sync_action; do [ -r \"$a\" ] || continue; [ \"$(cat \"$a\")\" = idle ] || continue; \
                 md=${{a#/sys/block/}}; md=${{md%%/*}}; $S mdadm --action=check \"/dev/$md\" || r=1; done; exit $r"
            ),
            Self::SmartShort | Self::SmartLong => {
                disks.iter().try_for_each(|d| device_ok(d))?;
                let kind = if self == Self::SmartLong { "long" } else { "short" };
                let list: Vec<String> = disks.iter().map(|d| q(d)).collect();
                format!("{UNATTENDED} r=0; for d in {}; do $S smartctl -t {kind} \"$d\" >/dev/null || r=1; done; exit $r", list.join(" "))
            }
        })
    }
}

// -----------------------------------------------------------------------------
// Changes
// -----------------------------------------------------------------------------

/// A filesystem [`StorageAction::Format`] makes.
pub const FILESYSTEMS: &[&str] = &["ext4", "xfs", "btrfs"];
pub const RAID_LEVELS: &[u8] = &[0, 1, 5, 6, 10];
pub const POOL_LAYOUTS: &[&str] = &["stripe", "mirror", "raidz1", "raidz2", "raidz3"];

/// Host folders never mounted over.
const SYSTEM_DIRS: &[&str] = &[
    "/", "/bin", "/boot", "/dev", "/etc", "/home", "/lib", "/lib32", "/lib64", "/opt", "/proc", "/root", "/run", "/sbin",
    "/srv", "/sys", "/tmp", "/usr", "/var",
];
/// Host folders nothing is mounted in either (`/boot/efi`, `/run/…`).
const SYSTEM_TREES: &[&str] = &["/bin/", "/boot/", "/dev/", "/etc/", "/lib/", "/lib32/", "/lib64/", "/proc/", "/run/", "/sbin/", "/sys/", "/usr/"];

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "camelCase", rename_all_fields = "camelCase")]
pub enum StorageAction {
    /// The whole disk becomes one GPT partition (what it held is lost).
    Partition { device: String },
    /// With [encrypt], inside a LUKS2 container first, opened as
    /// `luks-<uuid>` (its passphrase as a key file: [`StorageAction::script_with_key`]).
    Format {
        device: String,
        fstype: String,
        label: Option<String>,
        #[serde(default)]
        encrypt: bool,
    },
    /// Mounts [device]'s filesystem at [mountpoint]; [persist] keeps it in
    /// `/etc/fstab` (by UUID, `nofail`); [own] gives its top folder to the
    /// account that asked through sudo (the agent's), so the agent can keep
    /// backups there.
    Mount {
        device: String,
        mountpoint: String,
        persist: bool,
        #[serde(default)]
        own: bool,
    },
    /// Unmounts what is at [mountpoint], and drops its `/etc/fstab` line.
    Unmount { mountpoint: String },
    CreateRaid { name: String, level: u8, devices: Vec<String> },
    /// Adds a device to an array (a replacement or a spare).
    AddToRaid { array: String, device: String },
    /// Marks a member failed and takes it out.
    RemoveFromRaid { array: String, device: String },
    /// Stops an array and wipes its members' RAID signatures.
    DeleteRaid { array: String },
    CreatePool { name: String, layout: String, devices: Vec<String> },
    ScrubPool { name: String },
    DestroyPool { name: String },
    SmartTest { device: String, long: bool },
    /// Adds a device to a RAID 1, 5 or 6 as one more working member: a
    /// mirror more, or more room once the reshape ends.
    GrowRaid { array: String, device: String },
    /// Grows the mounted filesystem on [device] to fill it (after its array
    /// or partition grew).
    ExpandFilesystem { device: String },
    /// Adds a vdev of [devices] to a pool: more room. zpool refuses one whose
    /// redundancy differs from the pool's.
    AddToPool { name: String, layout: String, devices: Vec<String> },
    /// A pool's device swapped for another (a failed or a smaller one); the
    /// pool resilvers, and grows once every device of a vdev is larger.
    ReplaceInPool { name: String, old: String, new: String },
    /// A mirror made of (or grown from) a pool's device.
    AttachToPool { name: String, existing: String, new: String },
    AddSpare { name: String, devices: Vec<String> },
    /// A spare or cache device taken out of a pool.
    RemoveFromPool { name: String, device: String },
    /// An offline device back, and grown into a larger disk.
    OnlineInPool { name: String, device: String },
    /// A partition grown into the free space after it (the filesystem then
    /// with [`StorageAction::ExpandFilesystem`]).
    GrowPartition { device: String },
    /// A LUKS container opened (`luks-<uuid>`) with its passphrase.
    Unlock { device: String },
    /// A LUKS container closed; its filesystem must be unmounted.
    Lock { device: String },
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StorageError {
    InvalidDevice,
    InvalidMountpoint,
    InvalidLabel,
    InvalidFilesystem,
    InvalidName,
    InvalidLevel,
    TooFewDevices,
    /// A LUKS passphrase is needed and none was given.
    KeyRequired,
    InvalidPassphrase,
}

impl StorageError {
    pub fn code(self) -> &'static str {
        match self {
            Self::InvalidDevice => "invalidDevice",
            Self::InvalidMountpoint => "invalidMountpoint",
            Self::InvalidLabel => "invalidLabel",
            Self::InvalidFilesystem => "invalidFilesystem",
            Self::InvalidName => "invalidName",
            Self::InvalidLevel => "invalidLevel",
            Self::TooFewDevices => "tooFewDevices",
            Self::KeyRequired => "keyRequired",
            Self::InvalidPassphrase => "invalidPassphrase",
        }
    }
}

fn device_ok(path: &str) -> Result<(), StorageError> {
    let rest = path.strip_prefix("/dev/").ok_or(StorageError::InvalidDevice)?;
    let ok = !rest.is_empty()
        && rest.len() <= 128
        && !rest.split('/').any(|p| p.is_empty() || p == "." || p == "..")
        && rest.bytes().all(|b| b.is_ascii_alphanumeric() || b"/_.-:".contains(&b));
    if ok { Ok(()) } else { Err(StorageError::InvalidDevice) }
}

/// An absolute folder outside the system's own, without spaces (an fstab
/// field) or `..`.
pub fn mountpoint_ok(path: &str) -> Result<(), StorageError> {
    let trimmed = path.trim_end_matches('/');
    let ok = trimmed.starts_with('/')
        && trimmed.len() <= 256
        && !SYSTEM_DIRS.contains(&trimmed)
        && !SYSTEM_TREES.iter().any(|t| trimmed.starts_with(t))
        && !trimmed.split('/').skip(1).any(|p| p.is_empty() || p == "." || p == "..")
        && trimmed.bytes().all(|b| b.is_ascii_alphanumeric() || b"/_.-@+".contains(&b));
    if ok { Ok(()) } else { Err(StorageError::InvalidMountpoint) }
}

fn md_ok(name: &str) -> Result<(), StorageError> {
    let ok = name.strip_prefix("md").is_some_and(|n| (1..=3).contains(&n.len()) && n.bytes().all(|b| b.is_ascii_digit()));
    if ok { Ok(()) } else { Err(StorageError::InvalidName) }
}

fn pool_ok(name: &str) -> Result<(), StorageError> {
    let ok = (1..=64).contains(&name.len())
        && name.as_bytes()[0].is_ascii_alphabetic()
        && name.bytes().all(|b| b.is_ascii_alphanumeric() || b"_-.:".contains(&b))
        && !["mirror", "raidz", "spare", "log", "cache"].iter().any(|r| name.starts_with(r));
    if ok { Ok(()) } else { Err(StorageError::InvalidName) }
}

/// Until udev has read the device again, so a listing right after shows
/// what was just made (`lsblk` reads udev's database).
const SETTLE: &str = "{ partprobe 2>/dev/null; udevadm trigger --action=change --subsystem-match=block; udevadm settle; }";

/// Where mdadm keeps its arrays (Debian's, else the others').
const MDADM_CONF: &str = "conf=/etc/mdadm/mdadm.conf; [ -d /etc/mdadm ] || conf=/etc/mdadm.conf";

impl StorageAction {
    /// The devices this would partition, format or build on: what must not
    /// be in use ([`in_use`]).
    pub fn consumes(&self) -> Vec<&str> {
        match self {
            Self::Partition { device } | Self::Format { device, .. } => vec![device],
            Self::CreateRaid { devices, .. } | Self::CreatePool { devices, .. } => devices.iter().map(String::as_str).collect(),
            Self::AddToRaid { device, .. } | Self::GrowRaid { device, .. } => vec![device],
            Self::AddToPool { devices, .. } | Self::AddSpare { devices, .. } => devices.iter().map(String::as_str).collect(),
            Self::ReplaceInPool { new, .. } | Self::AttachToPool { new, .. } => vec![new],
            _ => Vec::new(),
        }
    }

    pub fn validate(&self) -> Result<(), StorageError> {
        match self {
            Self::Partition { device }
            | Self::SmartTest { device, .. }
            | Self::ExpandFilesystem { device }
            | Self::GrowPartition { device }
            | Self::Unlock { device }
            | Self::Lock { device } => device_ok(device),
            Self::ReplaceInPool { name, old: a, new: b } | Self::AttachToPool { name, existing: a, new: b } => {
                pool_ok(name)?;
                device_ok(a)?;
                device_ok(b)
            }
            Self::AddSpare { name, devices } => {
                pool_ok(name)?;
                if devices.is_empty() || has_duplicates(devices) {
                    return Err(StorageError::TooFewDevices);
                }
                devices.iter().try_for_each(|d| device_ok(d))
            }
            Self::RemoveFromPool { name, device } | Self::OnlineInPool { name, device } => {
                pool_ok(name)?;
                device_ok(device)
            }
            Self::Format { device, fstype, label, .. } => {
                device_ok(device)?;
                if !FILESYSTEMS.contains(&fstype.as_str()) {
                    return Err(StorageError::InvalidFilesystem);
                }
                if label.as_ref().is_some_and(|l| !(1..=16).contains(&l.len()) || !l.bytes().all(|b| b.is_ascii_alphanumeric() || b"_-".contains(&b))) {
                    return Err(StorageError::InvalidLabel);
                }
                Ok(())
            }
            Self::Mount { device, mountpoint, .. } => {
                device_ok(device)?;
                mountpoint_ok(mountpoint)
            }
            Self::Unmount { mountpoint } => mountpoint_ok(mountpoint),
            Self::CreateRaid { name, level, devices } => {
                md_ok(name)?;
                if !RAID_LEVELS.contains(level) {
                    return Err(StorageError::InvalidLevel);
                }
                devices.iter().try_for_each(|d| device_ok(d))?;
                let min = match level {
                    0 | 1 => 2,
                    5 => 3,
                    6 | 10 => 4,
                    _ => 2,
                };
                if devices.len() < min || has_duplicates(devices) {
                    return Err(StorageError::TooFewDevices);
                }
                Ok(())
            }
            Self::AddToRaid { array, device } | Self::RemoveFromRaid { array, device } | Self::GrowRaid { array, device } => {
                md_ok(array)?;
                device_ok(device)
            }
            Self::DeleteRaid { array } => md_ok(array),
            Self::CreatePool { name, layout, devices } | Self::AddToPool { name, layout, devices } => {
                pool_ok(name)?;
                if !POOL_LAYOUTS.contains(&layout.as_str()) {
                    return Err(StorageError::InvalidLevel);
                }
                devices.iter().try_for_each(|d| device_ok(d))?;
                let min = match layout.as_str() {
                    "stripe" => 1,
                    "mirror" => 2,
                    "raidz1" => 3,
                    "raidz2" => 4,
                    _ => 5,
                };
                if devices.len() < min || has_duplicates(devices) {
                    return Err(StorageError::TooFewDevices);
                }
                Ok(())
            }
            Self::ScrubPool { name } | Self::DestroyPool { name } => pool_ok(name),
        }
    }

    /// The shell text that does it, as root. Checked first. One that needs a
    /// LUKS passphrase is [`StorageAction::script_with_key`]'s.
    pub fn script(&self) -> Result<String, StorageError> {
        self.script_with_key(None)
    }

    /// Whether [`StorageAction::script_with_key`] needs a passphrase.
    pub fn needs_key(&self) -> bool {
        matches!(self, Self::Format { encrypt: true, .. } | Self::Unlock { .. })
    }

    /// The script, reading a LUKS passphrase from [key_file] (a file only the
    /// agent's account and root can read; the passphrase is never in the
    /// script, which a job logs).
    pub fn script_with_key(&self, key_file: Option<&str>) -> Result<String, StorageError> {
        self.script_keyed(key_file.map(q))
    }

    /// The script with the passphrase written into it, into a key file made
    /// and removed by the script itself: for a caller that sends the script
    /// on stdin (the app), where no process list or log sees it.
    pub fn script_with_passphrase(&self, passphrase: &str) -> Result<String, StorageError> {
        if !passphrase_ok(passphrase) {
            return Err(StorageError::InvalidPassphrase);
        }
        let inner = self.script_keyed(Some("\"$k\"".to_string()))?;
        Ok(format!(
            "k=$(mktemp) && chmod 600 \"$k\" && trap 'rm -f \"$k\"' EXIT && printf %s {} > \"$k\" && {{ {inner}; }}",
            q(passphrase)
        ))
    }

    /// [key]: the key file as shell text (quoted path or variable).
    fn script_keyed(&self, key: Option<String>) -> Result<String, StorageError> {
        self.validate()?;
        let key = match (self.needs_key(), key) {
            (true, Some(k)) => k,
            (true, None) => return Err(StorageError::KeyRequired),
            (false, _) => String::new(),
        };
        Ok(match self {
            Self::Partition { device } => {
                format!("wipefs -a {d} && printf 'label: gpt\\n,,L\\n' | sfdisk --quiet {d} && {SETTLE}", d = q(device))
            }
            Self::Format { device, fstype, label, encrypt } => {
                let label = label.as_ref().map(|l| format!(" -L {}", q(l))).unwrap_or_default();
                let force = match fstype.as_str() {
                    "ext4" => " -F",
                    _ => " -f",
                };
                if *encrypt {
                    format!(
                        "wipefs -a {d} && cryptsetup luksFormat --batch-mode --type luks2 --key-file {key} {d} \
                         && name=\"luks-$(cryptsetup luksUUID {d})\" && cryptsetup open --key-file {key} {d} \"$name\" \
                         && mkfs.{fstype}{force}{label} \"/dev/mapper/$name\" && {SETTLE}",
                        d = q(device)
                    )
                } else {
                    format!("wipefs -a {d} && mkfs.{fstype}{force}{label} {d} && {SETTLE}", d = q(device))
                }
            }
            Self::Mount { device, mountpoint, persist, own } => {
                let mp = q(mountpoint.trim_end_matches('/'));
                let mut s = format!("mkdir -p {mp} && mount {d} {mp}", d = q(device));
                if *own {
                    s.push_str(&format!(" && chown \"${{SUDO_UID:-0}}:${{SUDO_GID:-0}}\" {mp}"));
                }
                if *persist {
                    s.push_str(&format!(
                        " && uuid=$(blkid -s UUID -o value {d}) && fst=$(blkid -s TYPE -o value {d}) && [ -n \"$uuid\" ] \
                         && cp /etc/fstab /etc/fstab.sbm-bak \
                         && awk -v u=\"UUID=$uuid\" -v m={mp} '$1 != u && $2 != m' /etc/fstab > /etc/fstab.sbm \
                         && printf 'UUID=%s %s %s defaults,nofail 0 2\\n' \"$uuid\" {mp} \"$fst\" >> /etc/fstab.sbm \
                         && mv /etc/fstab.sbm /etc/fstab",
                        d = q(device)
                    ));
                }
                s
            }
            Self::Unmount { mountpoint } => {
                let mp = q(mountpoint.trim_end_matches('/'));
                format!(
                    "umount {mp} && cp /etc/fstab /etc/fstab.sbm-bak && awk -v m={mp} '$2 != m' /etc/fstab > /etc/fstab.sbm && mv /etc/fstab.sbm /etc/fstab"
                )
            }
            Self::CreateRaid { name, level, devices } => {
                let devs: Vec<String> = devices.iter().map(|d| q(d)).collect();
                format!(
                    "mdadm --create /dev/{name} --run --level={level} --raid-devices={n} {devs} && {MDADM_CONF}; mdadm --detail --brief /dev/{name} >> \"$conf\"",
                    n = devices.len(),
                    devs = devs.join(" ")
                )
            }
            // An old superblock (a member taken out before) would make mdadm
            // ask; it goes first.
            Self::AddToRaid { array, device } => {
                format!("mdadm --zero-superblock {d} 2>/dev/null; mdadm --manage /dev/{array} --add {d}", d = q(device))
            }
            // A member just failed may be busy a moment (a sync stopping): the
            // removal is tried again for ten seconds.
            Self::RemoveFromRaid { array, device } => format!(
                "mdadm --manage /dev/{array} --fail {d} && for i in 1 2 3 4 5 6 7 8 9 10; do \
                 mdadm --manage /dev/{array} --remove {d} && exit 0; sleep 1; done; exit 1",
                d = q(device)
            ),
            Self::DeleteRaid { array } => format!(
                "uuid=$(mdadm --detail --export /dev/{array} | sed -n 's/^MD_UUID=//p') \
                 && members=$(mdadm --detail --export /dev/{array} | sed -n 's/^MD_DEVICE_.*_DEV=//p') \
                 && mdadm --stop /dev/{array} && for m in $members; do mdadm --zero-superblock \"$m\"; done \
                 && {MDADM_CONF}; [ -f \"$conf\" ] && [ -n \"$uuid\" ] && sed -i \"/UUID=$uuid/d\" \"$conf\"; true"
            ),
            // `autoexpand`: a pool grows once its disks are replaced by larger
            // ones, without being asked.
            Self::CreatePool { name, layout, devices } => {
                let devs: Vec<String> = devices.iter().map(|d| q(d)).collect();
                let vdev = if layout == "stripe" { String::new() } else { format!("{layout} ") };
                format!("zpool create -f -o autoexpand=on {} {vdev}{}", q(name), devs.join(" "))
            }
            Self::ScrubPool { name } => format!("zpool scrub {}", q(name)),
            Self::DestroyPool { name } => format!("zpool destroy {}", q(name)),
            Self::SmartTest { device, long } => format!("smartctl -t {} {}", if *long { "long" } else { "short" }, q(device)),
            // Levels without redundancy (0) or with a layout mdadm reshapes
            // differently (10) are refused by the agent first; mdadm refuses
            // them too.
            Self::GrowRaid { array, device } => format!(
                "n=$(mdadm --detail --export /dev/{array} | sed -n 's/^MD_DEVICES=//p') && [ -n \"$n\" ] \
                 && {{ mdadm --zero-superblock {d} 2>/dev/null; true; }} && mdadm --manage /dev/{array} --add {d} \
                 && mdadm --grow /dev/{array} --raid-devices=$((n + 1))",
                d = q(device)
            ),
            Self::ExpandFilesystem { device } => format!(
                "mp=$(findmnt -nro TARGET -S {d} | head -n 1) && [ -n \"$mp\" ] || {{ echo 'not mounted' >&2; exit 1; }}; \
                 case $(lsblk -dno FSTYPE {d}) in \
                 ext2|ext3|ext4) resize2fs {d} ;; \
                 xfs) xfs_growfs \"$mp\" ;; \
                 btrfs) btrfs filesystem resize max \"$mp\" ;; \
                 *) echo 'this filesystem cannot be grown here' >&2; exit 1 ;; esac",
                d = q(device)
            ),
            Self::ReplaceInPool { name, old, new } => format!(
                "wipefs -a {n} && zpool set autoexpand=on {p} && zpool replace {p} {o} {n}",
                p = q(name),
                o = q(old),
                n = q(new)
            ),
            Self::AttachToPool { name, existing, new } => {
                format!("wipefs -a {n} && zpool attach {p} {e} {n}", p = q(name), e = q(existing), n = q(new))
            }
            Self::AddSpare { name, devices } => {
                let devs: Vec<String> = devices.iter().map(|d| q(d)).collect();
                format!("wipefs -a {d} && zpool add {} spare {d}", q(name), d = devs.join(" "))
            }
            Self::RemoveFromPool { name, device } => format!("zpool remove {} {}", q(name), q(device)),
            Self::OnlineInPool { name, device } => format!("zpool online -e {} {}", q(name), q(device)),
            // sfdisk takes the partition to the end of the free space after
            // it; `partx -u` tells the kernel while it is in use.
            Self::GrowPartition { device } => format!(
                "d={d}; disk=\"/dev/$(lsblk -dno PKNAME \"$d\")\"; n=$(cat \"/sys/class/block/$(basename \"$(readlink -f \"$d\")\")/partition\") \
                 && [ -n \"$n\" ] && echo ', +' | sfdisk --no-reread --force -N \"$n\" \"$disk\" && partx -u \"$disk\"",
                d = q(device)
            ),
            Self::Unlock { device } => format!(
                "cryptsetup open --key-file {key} {d} \"luks-$(cryptsetup luksUUID {d})\" && {SETTLE}",
                d = q(device)
            ),
            Self::Lock { device } => format!("cryptsetup close \"luks-$(cryptsetup luksUUID {d})\"", d = q(device)),
            Self::AddToPool { name, layout, devices } => {
                let devs: Vec<String> = devices.iter().map(|d| q(d)).collect();
                let vdev = if layout == "stripe" { String::new() } else { format!("{layout} ") };
                format!("zpool add {} {vdev}{}", q(name), devs.join(" "))
            }
        })
    }
}

fn has_duplicates(items: &[String]) -> bool {
    let mut seen = std::collections::HashSet::new();
    !items.iter().all(|i| seen.insert(i))
}

/// Which of the storage tools are here, one name per line; read by
/// [`parse_tools`].
pub const TOOLS_COMMAND: &str = "for t in mdadm zpool smartctl mkfs.ext4 mkfs.xfs mkfs.btrfs sfdisk wipefs cryptsetup; do command -v $t >/dev/null 2>&1 && echo $t; done; true";

pub fn parse_tools(stdout: &str) -> Vec<String> {
    stdout.lines().map(str::trim).filter(|l| !l.is_empty()).map(String::from).collect()
}

/// A LUKS passphrase this takes: 8 to 512 bytes on one line.
pub fn passphrase_ok(p: &str) -> bool {
    (8..=512).contains(&p.len()) && !p.contains(['\n', '\r', '\0'])
}

// -----------------------------------------------------------------------------
// The whole view, and what a change is checked against
// -----------------------------------------------------------------------------

/// Everything a page draws, each after a `### <name>` line; read by
/// [`parse_view`]. Readable without root.
pub fn view_command() -> String {
    format!(
        "echo '### lsblk'; {LSBLK_COMMAND} 2>/dev/null\necho '### mdstat'; cat /proc/mdstat 2>/dev/null\n\
         echo '### zpool'; {ZPOOL_LIST_COMMAND} 2>/dev/null\necho '### zstatus'; {ZPOOL_STATUS_COMMAND} 2>/dev/null\n\
         echo '### tools'; {TOOLS_COMMAND}\ntrue"
    )
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct StorageView {
    pub disks: Vec<BlockDevice>,
    /// Why each device may not be partitioned, formatted or built on
    /// ([`in_use`]).
    pub busy: std::collections::BTreeMap<String, String>,
    /// Devices mounted where the system lives ([`system_mounted`]).
    pub system: Vec<String>,
    pub arrays: Vec<MdArray>,
    pub pools: Vec<Pool>,
    pub tools: Vec<String>,
}

impl StorageView {
    pub fn held(&self) -> Held {
        Held::of(&self.arrays, &self.pools)
    }
}

/// Reads [`view_command`]'s output; `None` when lsblk answered nothing
/// (not Linux, or not there).
pub fn parse_view(stdout: &str) -> Option<StorageView> {
    let mut sections: Vec<(&str, String)> = Vec::new();
    for line in stdout.lines() {
        if let Some(name) = line.strip_prefix("### ") {
            sections.push((name.trim(), String::new()));
        } else if let Some((_, text)) = sections.last_mut() {
            text.push_str(line);
            text.push('\n');
        }
    }
    let section = |name: &str| sections.iter().find(|(n, _)| *n == name).map(|(_, t)| t.as_str()).unwrap_or("");
    let lsblk = section("lsblk");
    if serde_json::from_str::<Value>(lsblk).is_err() {
        return None;
    }
    let disks = parse_lsblk(lsblk);
    let arrays = parse_mdstat(section("mdstat"));
    let mut pools = parse_zpool_list(section("zpool"));
    if !pools.is_empty() {
        merge_zpool_status(&mut pools, section("zstatus"));
    }
    let held = Held::of(&arrays, &pools);
    let busy = disks
        .iter()
        .flat_map(BlockDevice::walk)
        .filter_map(|d| in_use(&disks, &d.path, &held).map(|why| (d.path.clone(), why.to_string())))
        .collect();
    let system = disks.iter().flat_map(BlockDevice::walk).filter(|d| system_mounted(d)).map(|d| d.path.clone()).collect();
    Some(StorageView { disks, busy, system, arrays, pools, tools: parse_tools(section("tools")) })
}

/// Why [action] is refused on the machine as [view] says it is: an HTTP
/// status, a code, and for `inUse` the device and why.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Refusal {
    pub status: u16,
    pub error: String,
    pub device: Option<String>,
    pub why: Option<String>,
}

fn refusal(status: u16, error: &str) -> Refusal {
    Refusal { status, error: error.into(), device: None, why: None }
}

/// The checks a change passes before it runs, decided on what the machine
/// has now: nothing in use is consumed, the system's mounts stay, a filesystem
/// grows only mounted, a container locks only unmounted, only spares and
/// caches leave a pool, only RAID 1/5/6 grow.
pub fn check(view: &StorageView, action: &StorageAction) -> Result<(), Refusal> {
    action.validate().map_err(|e| refusal(400, e.code()))?;
    let disks = &view.disks;
    match action {
        StorageAction::Unmount { mountpoint } => {
            if let Some(why) = unmount_refusal(disks, mountpoint) {
                return Err(refusal(409, why));
            }
        }
        StorageAction::ExpandFilesystem { device } => {
            let d = find(disks, device).ok_or_else(|| refusal(409, "notFound"))?;
            if !growable(d) {
                return Err(refusal(409, "notGrowable"));
            }
        }
        StorageAction::Lock { device } => {
            let d = find(disks, device).ok_or_else(|| refusal(409, "notFound"))?;
            if d.walk().iter().any(|c| !c.mountpoints.is_empty()) {
                return Err(refusal(409, "mounted"));
            }
        }
        StorageAction::GrowPartition { device } => {
            if find(disks, device).is_none_or(|d| d.kind != "part") {
                return Err(refusal(409, "notGrowable"));
            }
        }
        StorageAction::RemoveFromPool { name, device } => {
            let removable = view.pools.iter().find(|p| &p.name == name).is_some_and(|p| {
                p.vdevs.iter().any(|v| &v.name == device && matches!(v.section.as_deref(), Some("spares" | "cache")))
            });
            if !removable {
                return Err(refusal(409, "notRemovable"));
            }
        }
        StorageAction::GrowRaid { array, .. } => {
            let level = view.arrays.iter().find(|a| &a.name == array).and_then(|a| a.level.as_deref());
            if !matches!(level, Some("raid1" | "raid5" | "raid6")) {
                return Err(refusal(409, "notGrowable"));
            }
        }
        _ => {}
    }
    let consumes = action.consumes();
    if overlapping(disks, &consumes) {
        return Err(refusal(400, "overlapping"));
    }
    let held = view.held();
    for device in consumes {
        if let Some(why) = in_use(disks, device, &held) {
            return Err(Refusal { status: 409, error: "inUse".into(), device: Some(device.into()), why: Some(why.into()) });
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    const LSBLK: &str = r#"{"blockdevices":[
      {"name":"sda","path":"/dev/sda","type":"disk","size":500107862016,"model":"Samsung SSD","serial":"S1","rota":false,"tran":"sata","rm":false,"ro":false,"fstype":null,"label":null,"uuid":null,"mountpoints":[null],"fsavail":null,"fsused":null,
       "children":[{"name":"sda1","path":"/dev/sda1","type":"part","size":536870912,"fstype":"vfat","mountpoints":["/boot/efi"],"rota":false,"rm":false,"ro":false},
                   {"name":"sda2","path":"/dev/sda2","type":"part","size":499570991104,"fstype":"ext4","uuid":"u2","mountpoints":["/"],"fsavail":"400000000000","fsused":"60000000000","rota":"0","rm":"0","ro":"0"}]},
      {"name":"sdb","path":"/dev/sdb","type":"disk","size":4000787030016,"model":"WDC","rota":true,"tran":"sata","rm":false,"ro":false,"fstype":null,"mountpoints":[null],
       "children":[{"name":"sdb1","path":"/dev/sdb1","type":"part","size":4000785104896,"fstype":"linux_raid_member","mountpoints":[null],
                    "children":[{"name":"md0","path":"/dev/md0","type":"raid1","size":4000650887168,"fstype":"ext4","mountpoints":["/srv/data"]}]}]},
      {"name":"sdc","path":"/dev/sdc","type":"disk","size":4000787030016,"rota":true,"rm":false,"ro":false,"fstype":null,"mountpoints":[null]},
      {"name":"sdd","path":"/dev/sdd","type":"disk","size":10737418240,"rota":true,"rm":false,"ro":false,"fstype":"swap","mountpoints":["[SWAP]"]}
    ]}"#;

    #[test]
    fn disks_read_as_a_tree() {
        let d = parse_lsblk(LSBLK);
        assert_eq!(d.len(), 4);
        assert_eq!(d[0].model.as_deref(), Some("Samsung SSD"));
        assert!(!d[0].rotational && d[1].rotational);
        assert_eq!(d[0].mountpoints, Vec::<String>::new());
        assert_eq!(d[0].children[1].available, Some(400_000_000_000));
        assert_eq!(find(&d, "/dev/md0").unwrap().kind, "raid1");
        assert!(parse_lsblk("not json").is_empty());
    }

    #[test]
    fn what_is_in_use_is_left_alone() {
        let d = parse_lsblk(LSBLK);
        let held = Held { md_members: vec!["sdb1".into()], pool_devices: vec!["/dev/sde1".into()] };
        assert_eq!(in_use(&d, "/dev/sda", &held), Some("mounted"));
        assert_eq!(in_use(&d, "/dev/sdb", &held), Some("raidMember"));
        assert_eq!(in_use(&d, "/dev/sdd", &held), Some("swap"));
        assert_eq!(in_use(&d, "/dev/sdx", &held), Some("notFound"));
        assert_eq!(in_use(&d, "/dev/sdc", &held), None);
        // The array on it is mounted, whatever mdstat says.
        assert_eq!(in_use(&d, "/dev/sdb1", &Held::default()), Some("mounted"));
        // An old array's signature, its array gone: free.
        let stale = parse_lsblk(r#"{"blockdevices":[{"name":"sdf","path":"/dev/sdf","type":"disk","size":1,"fstype":"linux_raid_member","mountpoints":[null]}]}"#);
        assert_eq!(in_use(&stale, "/dev/sdf", &Held::default()), None);
        assert_eq!(in_use(&stale, "/dev/sdf", &Held { md_members: vec!["sdf".into()], pool_devices: vec![] }), Some("raidMember"));
        // Firmware's partitions, nothing mounted (a BIOS boot partition, a
        // second disk's EFI partition).
        let boot = parse_lsblk(
            r#"{"blockdevices":[{"name":"sdg","path":"/dev/sdg","type":"disk","size":1,"mountpoints":[null],"children":[
              {"name":"sdg14","path":"/dev/sdg14","type":"part","size":1,"parttype":"21686148-6449-6e6f-744e-656564454649","mountpoints":[null]},
              {"name":"sdg15","path":"/dev/sdg15","type":"part","size":1,"parttype":"C12A7328-F81F-11D2-BA4B-00A0C93EC93B","fstype":"vfat","mountpoints":[null]},
              {"name":"sdg2","path":"/dev/sdg2","type":"part","size":1,"parttype":"0fc63daf-8483-4772-8e79-3d69d8477de4","mountpoints":[null]}]}]}"#,
        );
        assert_eq!(in_use(&boot, "/dev/sdg14", &Held::default()), Some("systemPartition"));
        assert_eq!(in_use(&boot, "/dev/sdg15", &Held::default()), Some("systemPartition"));
        assert_eq!(in_use(&boot, "/dev/sdg", &Held::default()), Some("systemPartition"));
        assert_eq!(in_use(&boot, "/dev/sdg2", &Held::default()), None);
        assert!(overlapping(&boot, &["/dev/sdg", "/dev/sdg2"]));
        assert!(!overlapping(&d, &["/dev/sdc", "/dev/sdd"]));
    }

    #[test]
    fn the_systems_mounts_are_kept() {
        let d = parse_lsblk(LSBLK);
        assert_eq!(unmount_refusal(&d, "/boot/efi"), Some("systemMount"));
        assert_eq!(unmount_refusal(&d, "/"), Some("systemMount"));
        assert_eq!(unmount_refusal(&d, "/srv/data/"), None);
        assert_eq!(unmount_refusal(&d, "/mnt/nothing"), Some("notMounted"));
        // WSL: the root filesystem also at /var/lib/docker.
        let wsl = parse_lsblk(r#"{"blockdevices":[{"name":"sdd","path":"/dev/sdd","type":"disk","size":1,"fstype":"ext4","mountpoints":["/var/lib/docker","/mnt/wslg/distro","/"]}]}"#);
        assert_eq!(unmount_refusal(&wsl, "/var/lib/docker"), Some("systemMount"));
        assert!(mountpoint_ok("/boot/efi").is_err() && mountpoint_ok("/run/media/x").is_err());
        assert!(mountpoint_ok("/mnt/backup").is_ok() && mountpoint_ok("/srv/data").is_ok());
    }

    #[test]
    fn mdstat_reads_arrays_and_their_sync() {
        let text = "Personalities : [raid1] [raid6] [raid5] [raid4]\n\
md1 : active raid5 sde[3] sdd[1](F) sdc[0]\n      7813772288 blocks super 1.2 level 5, 512k chunk, algorithm 2 [3/2] [U_U]\n      [==>..................]  recovery = 12.6% (493417472/3906886144) finish=310.4min speed=183140K/sec\n\n\
md0 : active raid1 sdb1[0] sdf1[1](S)\n      3906886144 blocks super 1.2 [1/1] [U]\n\n\
md127 : inactive sdg[0](S)\n      976630488 blocks super 1.2\n\nunused devices: <none>\n";
        let a = parse_mdstat(text);
        assert_eq!(a.len(), 3);
        assert_eq!(a[0].level.as_deref(), Some("raid5"));
        assert!(a[0].degraded());
        assert!(a[0].members.iter().any(|m| m.name == "sdd" && m.faulty));
        assert_eq!(a[0].sync, Some(MdSync { action: "recovery".into(), permille: 126, finish: Some("310.4min".into()) }));
        assert!(a[1].members.iter().any(|m| m.name == "sdf1" && m.spare));
        assert!(!a[1].degraded());
        assert_eq!((a[2].state.as_str(), a[2].level.as_deref()), ("inactive", None));
    }

    #[test]
    fn zpool_reads_pools_and_their_layout() {
        let mut pools = parse_zpool_list("tank\t7999376588800\t1099511627776\t6899864961024\tDEGRADED\n");
        let status = "  pool: tank\n state: DEGRADED\n  scan: resilvered 1.2G in 00:01:02 with 0 errors on Sun Oct 11 01:00:00 2026\nconfig:\n\n\tNAME          STATE     READ WRITE CKSUM\n\ttank          DEGRADED     0     0     0\n\t  mirror-0    DEGRADED     0     0     0\n\t    /dev/sdb  ONLINE       0     0     0\n\t    /dev/sdc  FAULTED      3     1     0  too many errors\n\nerrors: No known data errors\n";
        merge_zpool_status(&mut pools, status);
        assert_eq!(pools[0].health, "DEGRADED");
        assert!(pools[0].scan.as_deref().unwrap().starts_with("resilvered"));
        assert!(!pools[0].scanning);
        let mut running = pools.clone();
        merge_zpool_status(&mut running, "  pool: tank\n state: ONLINE\n  scan: scrub in progress since Sun Oct 11 01:00:00 2026\n");
        assert!(running[0].scanning);
        assert_eq!(pools[0].vdevs.len(), 3);
        assert_eq!((pools[0].vdevs[0].name.as_str(), pools[0].vdevs[0].depth), ("mirror-0", 0));
        assert_eq!((pools[0].vdevs[2].state.as_str(), pools[0].vdevs[2].depth, pools[0].vdevs[2].errors), ("FAULTED", 1, 4));
    }

    #[test]
    fn changes_are_checked_and_quoted() {
        let bad = [
            StorageAction::Format { device: "/dev/sdb; rm -rf /".into(), fstype: "ext4".into(), label: None, encrypt: false },
            StorageAction::Format { device: "/dev/sdb".into(), fstype: "ntfs".into(), label: None, encrypt: false },
            StorageAction::Mount { device: "/dev/sdb1".into(), mountpoint: "/etc".into(), persist: true, own: false },
            StorageAction::Mount { device: "/dev/sdb1".into(), mountpoint: "/srv/../etc".into(), persist: true, own: false },
            StorageAction::Mount { device: "/dev/sdb1".into(), mountpoint: "/mnt/my disk".into(), persist: true, own: false },
            StorageAction::CreateRaid { name: "md0".into(), level: 5, devices: vec!["/dev/sdb".into(), "/dev/sdc".into()] },
            StorageAction::CreateRaid { name: "md0".into(), level: 1, devices: vec!["/dev/sdb".into(), "/dev/sdb".into()] },
            StorageAction::CreateRaid { name: "data".into(), level: 1, devices: vec!["/dev/sdb".into(), "/dev/sdc".into()] },
            StorageAction::CreatePool { name: "mirror1".into(), layout: "mirror".into(), devices: vec!["/dev/sdb".into(), "/dev/sdc".into()] },
            StorageAction::Partition { device: "/dev/../sda".into() },
        ];
        for a in bad {
            assert!(a.script().is_err(), "{a:?}");
        }
        assert_eq!(
            StorageAction::Format { device: "/dev/sdc1".into(), fstype: "xfs".into(), label: Some("data".into()), encrypt: false }.script().unwrap(),
            "wipefs -a '/dev/sdc1' && mkfs.xfs -f -L 'data' '/dev/sdc1' && { partprobe 2>/dev/null; udevadm trigger --action=change --subsystem-match=block; udevadm settle; }"
        );
        assert_eq!(
            StorageAction::CreateRaid { name: "md1".into(), level: 1, devices: vec!["/dev/sdb".into(), "/dev/sdc".into()] }.script().unwrap(),
            "mdadm --create /dev/md1 --run --level=1 --raid-devices=2 '/dev/sdb' '/dev/sdc' && conf=/etc/mdadm/mdadm.conf; [ -d /etc/mdadm ] || conf=/etc/mdadm.conf; mdadm --detail --brief /dev/md1 >> \"$conf\""
        );
        assert_eq!(
            StorageAction::CreatePool { name: "tank".into(), layout: "raidz1".into(), devices: vec!["/dev/sdb".into(), "/dev/sdc".into(), "/dev/sdd".into()] }.script().unwrap(),
            "zpool create -f -o autoexpand=on 'tank' raidz1 '/dev/sdb' '/dev/sdc' '/dev/sdd'"
        );
        let mount = StorageAction::Mount { device: "/dev/md0".into(), mountpoint: "/mnt/backup/".into(), persist: true, own: true }.script().unwrap();
        assert!(mount.starts_with("mkdir -p '/mnt/backup' && mount '/dev/md0' '/mnt/backup' && chown \"${SUDO_UID:-0}:${SUDO_GID:-0}\" '/mnt/backup'"), "{mount}");
        assert!(mount.contains("defaults,nofail 0 2"));
        let parsed: StorageAction = serde_json::from_value(serde_json::json!({ "action": "createRaid", "name": "md0", "level": 1, "devices": ["/dev/sdb", "/dev/sdc"] })).unwrap();
        assert_eq!(parsed.consumes(), vec!["/dev/sdb", "/dev/sdc"]);
    }

    #[test]
    fn disk_health_reads_every_kind_of_disk() {
        let h = parse_health(include_str!("../tests/fixtures/storage_health.txt"));
        let names: Vec<&str> = h.iter().map(|d| d.device.as_str()).collect();
        assert_eq!(names, ["/dev/nvme0n1", "/dev/nvme1n1", "/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd", "/dev/sde"]);

        // NVMe, a short test 13% in, none ended before.
        assert!(h[0].supported && h[0].passed == Some(true));
        assert_eq!((h[0].temperature, h[0].power_on_hours, h[0].bad_sectors, h[0].testing), (Some(58.0), Some(15511), Some(0), Some(87)));
        assert_eq!(h[0].last_test, None);
        // The same disk once it ended.
        assert_eq!(h[1].testing, None);
        assert_eq!(h[1].last_test, Some(SelfTest { long: false, outcome: "passed".into(), hours: Some(15511) }));

        // A QEMU disk has no SMART: nothing to read or test.
        assert!(!h[2].supported && !h[2].asleep);
        assert_eq!((h[2].passed, h[2].temperature), (None, None));

        // ATA: a long test running, the one before it failed, sectors going.
        let ata = &h[3];
        assert!(ata.supported);
        assert_eq!((ata.temperature, ata.power_on_hours, ata.bad_sectors, ata.testing), (Some(35.0), Some(31024), Some(10), Some(90)));
        assert_eq!(ata.last_test, Some(SelfTest { long: true, outcome: "failed".into(), hours: Some(30980) }));

        // Asleep and left so; gone; smartctl printing nothing.
        assert!(h[4].asleep && !h[4].supported);
        assert!(!h[5].asleep && !h[5].supported);
        assert!(!h[6].supported);
        assert!(parse_health("").is_empty());
    }

    #[test]
    fn growing_and_maintenance_are_checked_scripts() {
        let grow = StorageAction::GrowRaid { array: "md0".into(), device: "/dev/sdd".into() };
        let script = grow.script().unwrap();
        assert!(script.contains("mdadm --manage /dev/md0 --add '/dev/sdd'") && script.contains("--raid-devices=$((n + 1))"), "{script}");
        assert_eq!(grow.consumes(), ["/dev/sdd"]);
        assert!(StorageAction::GrowRaid { array: "md0; reboot".into(), device: "/dev/sdd".into() }.script().is_err());

        let expand = StorageAction::ExpandFilesystem { device: "/dev/md0".into() }.script().unwrap();
        assert!(expand.contains("resize2fs '/dev/md0'") && expand.contains("xfs_growfs \"$mp\""), "{expand}");
        assert!(StorageAction::ExpandFilesystem { device: "/dev/md0".into() }.consumes().is_empty());

        let add = StorageAction::AddToPool { name: "tank".into(), layout: "mirror".into(), devices: vec!["/dev/sdd".into(), "/dev/sde".into()] };
        assert_eq!(add.script().unwrap(), "zpool add 'tank' mirror '/dev/sdd' '/dev/sde'");
        assert_eq!(add.consumes().len(), 2);
        let one = StorageAction::AddToPool { name: "tank".into(), layout: "mirror".into(), devices: vec!["/dev/sdd".into()] };
        assert_eq!(one.script(), Err(StorageError::TooFewDevices));

        let scrub = Maintenance::Scrub.script(&[]).unwrap();
        assert!(scrub.starts_with(UNATTENDED) && scrub.contains("$S zpool scrub") && scrub.contains("$S mdadm --action=check"), "{scrub}");
        let long = Maintenance::SmartLong.script(&["/dev/sda".into(), "/dev/nvme0n1".into()]).unwrap();
        assert!(long.contains("for d in '/dev/sda' '/dev/nvme0n1'; do $S smartctl -t long"), "{long}");
        assert!(Maintenance::SmartShort.script(&["/dev/sda;id".into()]).is_err());
        assert_eq!(Maintenance::from_name("smartShort"), Some(Maintenance::SmartShort));
        assert_eq!(Maintenance::from_name("format"), None);
    }

    #[test]
    fn pool_devices_luks_and_partitions_are_checked_scripts() {
        let status = "  pool: tank\n state: DEGRADED\nconfig:\n\n\tNAME          STATE     READ WRITE CKSUM\n\ttank          DEGRADED     0     0     0\n\t  mirror-0    DEGRADED     0     0     0\n\t    /dev/sdb  ONLINE       0     0     0\n\t    /dev/sdc  OFFLINE      0     0     0\n\tspares\n\t  /dev/sdd    AVAIL\n\nerrors: No known data errors\n";
        let mut pools = parse_zpool_list("tank\t100\t10\t90\tDEGRADED\n");
        merge_zpool_status(&mut pools, status);
        let v: Vec<(&str, u32, Option<&str>)> = pools[0].vdevs.iter().map(|v| (v.name.as_str(), v.depth, v.section.as_deref())).collect();
        assert_eq!(v, [("mirror-0", 0, None), ("/dev/sdb", 1, None), ("/dev/sdc", 1, None), ("/dev/sdd", 0, Some("spares"))]);

        let replace = StorageAction::ReplaceInPool { name: "tank".into(), old: "/dev/sdc".into(), new: "/dev/sde".into() };
        assert_eq!(replace.script().unwrap(), "wipefs -a '/dev/sde' && zpool set autoexpand=on 'tank' && zpool replace 'tank' '/dev/sdc' '/dev/sde'");
        assert_eq!(replace.consumes(), ["/dev/sde"]);
        assert!(StorageAction::AttachToPool { name: "tank".into(), existing: "/dev/sdb".into(), new: "/dev/sdf".into() }.script().unwrap().ends_with("zpool attach 'tank' '/dev/sdb' '/dev/sdf'"));
        assert!(StorageAction::AddSpare { name: "tank".into(), devices: vec!["/dev/sdg".into()] }.script().unwrap().ends_with("zpool add 'tank' spare '/dev/sdg'"));
        assert_eq!(StorageAction::RemoveFromPool { name: "tank".into(), device: "/dev/sdd".into() }.script().unwrap(), "zpool remove 'tank' '/dev/sdd'");
        assert_eq!(StorageAction::OnlineInPool { name: "tank".into(), device: "/dev/sdc".into() }.script().unwrap(), "zpool online -e 'tank' '/dev/sdc'");
        assert_eq!(StorageAction::AddSpare { name: "tank".into(), devices: vec![] }.script(), Err(StorageError::TooFewDevices));

        // A passphrase is only ever a key file's path in the script.
        let luks = StorageAction::Format { device: "/dev/sdb1".into(), fstype: "ext4".into(), label: None, encrypt: true };
        assert_eq!(luks.script(), Err(StorageError::KeyRequired));
        let script = luks.script_with_key(Some("/run/user/1000/sbm-key")).unwrap();
        assert!(script.contains("cryptsetup luksFormat --batch-mode --type luks2 --key-file '/run/user/1000/sbm-key' '/dev/sdb1'"), "{script}");
        assert!(script.contains("mkfs.ext4 -F \"/dev/mapper/$name\""), "{script}");
        assert!(StorageAction::Unlock { device: "/dev/sdb1".into() }.script_with_key(Some("/k")).unwrap().starts_with("cryptsetup open --key-file '/k' '/dev/sdb1' \"luks-$(cryptsetup luksUUID '/dev/sdb1')\""));
        assert_eq!(StorageAction::Lock { device: "/dev/sdb1".into() }.script().unwrap(), "cryptsetup close \"luks-$(cryptsetup luksUUID '/dev/sdb1')\"");

        let grow = StorageAction::GrowPartition { device: "/dev/sdb1".into() }.script().unwrap();
        assert!(grow.contains("sfdisk --no-reread --force -N \"$n\" \"$disk\" && partx -u \"$disk\""), "{grow}");
        assert!(StorageAction::GrowPartition { device: "/dev/sdb1;id".into() }.script().is_err());
    }

    #[test]
    fn smart_details_keep_every_attribute_and_test() {
        let h = parse_health(include_str!("../tests/fixtures/storage_health.txt"));
        let ata = &h[3];
        let names: Vec<&str> = ata.attributes.iter().map(|a| a.name.as_str()).collect();
        assert_eq!(names, ["Reallocated_Sector_Ct", "Temperature_Celsius", "Current_Pending_Sector", "Offline_Uncorrectable"]);
        assert_eq!(ata.attributes[1].raw, "35 (Min/Max 20/40)");
        assert!(ata.attributes.iter().all(|a| !a.failing));
        assert_eq!(ata.tests.iter().map(|t| t.outcome.as_str()).collect::<Vec<_>>(), ["failed", "passed"]);
        let nvme = &h[0];
        assert!(nvme.attributes.iter().any(|a| a.name == "percentage_used" && a.raw == "4"), "{:?}", nvme.attributes);
        assert!(nvme.attributes.iter().all(|a| a.id.is_none()));
        assert!(h[2].attributes.is_empty(), "a disk without SMART has none");
    }

    #[test]
    fn the_view_reads_whole_and_changes_are_checked_against_it() {
        let raw = format!("### lsblk\n{LSBLK}\n### mdstat\nPersonalities : [raid1]\nmd0 : active raid1 sdb1[0]\n      100 blocks [2/1] [U_]\n\n### zpool\n### zstatus\nno pools available\n### tools\nmdadm\nsfdisk\n");
        let v = parse_view(&raw).unwrap();
        assert_eq!(v.tools, ["mdadm", "sfdisk"]);
        assert_eq!(v.busy.get("/dev/sdb1").map(String::as_str), Some("raidMember"));
        assert!(v.system.contains(&"/dev/sda2".to_string()));
        assert_eq!(parse_view("### lsblk\nlsblk: not found\n"), None);

        let format = |d: &str| StorageAction::Format { device: d.into(), fstype: "ext4".into(), label: None, encrypt: false };
        assert_eq!(check(&v, &format("/dev/sdc")), Ok(()));
        let r = check(&v, &format("/dev/sdb")).unwrap_err();
        assert_eq!((r.status, r.error.as_str(), r.why.as_deref()), (409, "inUse", Some("raidMember")));
        assert_eq!(check(&v, &StorageAction::Unmount { mountpoint: "/srv/data".into() }), Ok(()));
        assert_eq!(check(&v, &StorageAction::GrowRaid { array: "md0".into(), device: "/dev/sdc".into() }), Ok(()));
        assert_eq!(check(&v, &StorageAction::GrowPartition { device: "/dev/sdc".into() }).unwrap_err().error, "notGrowable");
        assert_eq!(check(&v, &format("/dev/sdb; id")).unwrap_err().error, "invalidDevice");

        let luks = StorageAction::Unlock { device: "/dev/sdc".into() };
        let s = luks.script_with_passphrase("it's a secret").unwrap();
        assert!(s.starts_with("k=$(mktemp) && chmod 600 \"$k\" && trap 'rm -f \"$k\"' EXIT && printf %s 'it'\\''s a secret' > \"$k\""), "{s}");
        assert!(s.contains("cryptsetup open --key-file \"$k\" '/dev/sdc'"), "{s}");
        assert_eq!(luks.script_with_passphrase("short"), Err(StorageError::InvalidPassphrase));
    }
}
