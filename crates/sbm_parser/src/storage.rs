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
pub const LSBLK_COMMAND: &str = "lsblk -J -b -o NAME,PATH,TYPE,SIZE,MODEL,SERIAL,ROTA,TRAN,RM,RO,FSTYPE,LABEL,UUID,MOUNTPOINTS,FSAVAIL,FSUSED";

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
    pub fstype: Option<String>,
    pub label: Option<String>,
    pub uuid: Option<String>,
    /// `[SWAP]` for swap.
    pub mountpoints: Vec<String>,
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
        fstype: text(&v["fstype"]),
        label: text(&v["label"]),
        uuid: text(&v["uuid"]),
        mountpoints,
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
                vdevs: Vec::new(),
            })
        })
        .collect()
}

/// Adds `zpool status`'s scan line and vdev tree to [pools].
pub fn merge_zpool_status(pools: &mut [Pool], stdout: &str) {
    let mut current: Option<usize> = None;
    let mut in_config = false;
    let mut base_indent = 0;
    for line in stdout.lines() {
        let trimmed = line.trim();
        if let Some(name) = trimmed.strip_prefix("pool: ") {
            current = pools.iter().position(|p| p.name == name);
            in_config = false;
            continue;
        }
        let Some(i) = current else { continue };
        if let Some(scan) = trimmed.strip_prefix("scan: ") {
            pools[i].scan = Some(scan.to_string());
        } else if trimmed.starts_with("NAME") && trimmed.contains("STATE") {
            in_config = true;
            base_indent = line.len() - line.trim_start().len();
        } else if trimmed.starts_with("errors:") || trimmed.is_empty() && in_config && !pools[i].vdevs.is_empty() {
            in_config = false;
        } else if in_config && !trimmed.is_empty() {
            let indent = line.len() - line.trim_start().len();
            let f: Vec<&str> = trimmed.split_whitespace().collect();
            if f.len() < 2 || f[0] == pools[i].name {
                continue;
            }
            // The pool's own line is at the header's indent, its vdevs two
            // further, what they are made of two more.
            let depth = (indent.saturating_sub(base_indent + 2) / 2) as u32;
            let errors = f.iter().skip(2).take(3).filter_map(|e| e.parse::<u64>().ok()).sum();
            pools[i].vdevs.push(Vdev { name: f[0].to_string(), state: f[1].to_string(), depth, errors });
        }
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(tag = "action", rename_all = "camelCase", rename_all_fields = "camelCase")]
pub enum StorageAction {
    /// The whole disk becomes one GPT partition (what it held is lost).
    Partition { device: String },
    Format { device: String, fstype: String, label: Option<String> },
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
            Self::AddToRaid { device, .. } => vec![device],
            _ => Vec::new(),
        }
    }

    pub fn validate(&self) -> Result<(), StorageError> {
        match self {
            Self::Partition { device } | Self::SmartTest { device, .. } => device_ok(device),
            Self::Format { device, fstype, label } => {
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
            Self::AddToRaid { array, device } | Self::RemoveFromRaid { array, device } => {
                md_ok(array)?;
                device_ok(device)
            }
            Self::DeleteRaid { array } => md_ok(array),
            Self::CreatePool { name, layout, devices } => {
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

    /// The shell text that does it, as root. Checked first.
    pub fn script(&self) -> Result<String, StorageError> {
        self.validate()?;
        Ok(match self {
            Self::Partition { device } => {
                format!("wipefs -a {d} && printf 'label: gpt\\n,,L\\n' | sfdisk --quiet {d} && {SETTLE}", d = q(device))
            }
            Self::Format { device, fstype, label } => {
                let label = label.as_ref().map(|l| format!(" -L {}", q(l))).unwrap_or_default();
                let force = match fstype.as_str() {
                    "ext4" => " -F",
                    _ => " -f",
                };
                format!("wipefs -a {d} && mkfs.{fstype}{force}{label} {d} && {SETTLE}", d = q(device))
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
            Self::CreatePool { name, layout, devices } => {
                let devs: Vec<String> = devices.iter().map(|d| q(d)).collect();
                let vdev = if layout == "stripe" { String::new() } else { format!("{layout} ") };
                format!("zpool create -f {} {vdev}{}", q(name), devs.join(" "))
            }
            Self::ScrubPool { name } => format!("zpool scrub {}", q(name)),
            Self::DestroyPool { name } => format!("zpool destroy {}", q(name)),
            Self::SmartTest { device, long } => format!("smartctl -t {} {}", if *long { "long" } else { "short" }, q(device)),
        })
    }
}

fn has_duplicates(items: &[String]) -> bool {
    let mut seen = std::collections::HashSet::new();
    !items.iter().all(|i| seen.insert(i))
}

/// Which of the storage tools are here, one name per line; read by
/// [`parse_tools`].
pub const TOOLS_COMMAND: &str = "for t in mdadm zpool smartctl mkfs.ext4 mkfs.xfs mkfs.btrfs sfdisk wipefs; do command -v $t >/dev/null 2>&1 && echo $t; done; true";

pub fn parse_tools(stdout: &str) -> Vec<String> {
    stdout.lines().map(str::trim).filter(|l| !l.is_empty()).map(String::from).collect()
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
        assert_eq!(pools[0].vdevs.len(), 3);
        assert_eq!((pools[0].vdevs[0].name.as_str(), pools[0].vdevs[0].depth), ("mirror-0", 0));
        assert_eq!((pools[0].vdevs[2].state.as_str(), pools[0].vdevs[2].depth, pools[0].vdevs[2].errors), ("FAULTED", 1, 4));
    }

    #[test]
    fn changes_are_checked_and_quoted() {
        let bad = [
            StorageAction::Format { device: "/dev/sdb; rm -rf /".into(), fstype: "ext4".into(), label: None },
            StorageAction::Format { device: "/dev/sdb".into(), fstype: "ntfs".into(), label: None },
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
            StorageAction::Format { device: "/dev/sdc1".into(), fstype: "xfs".into(), label: Some("data".into()) }.script().unwrap(),
            "wipefs -a '/dev/sdc1' && mkfs.xfs -f -L 'data' '/dev/sdc1' && { partprobe 2>/dev/null; udevadm trigger --action=change --subsystem-match=block; udevadm settle; }"
        );
        assert_eq!(
            StorageAction::CreateRaid { name: "md1".into(), level: 1, devices: vec!["/dev/sdb".into(), "/dev/sdc".into()] }.script().unwrap(),
            "mdadm --create /dev/md1 --run --level=1 --raid-devices=2 '/dev/sdb' '/dev/sdc' && conf=/etc/mdadm/mdadm.conf; [ -d /etc/mdadm ] || conf=/etc/mdadm.conf; mdadm --detail --brief /dev/md1 >> \"$conf\""
        );
        assert_eq!(
            StorageAction::CreatePool { name: "tank".into(), layout: "raidz1".into(), devices: vec!["/dev/sdb".into(), "/dev/sdc".into(), "/dev/sdd".into()] }.script().unwrap(),
            "zpool create -f 'tank' raidz1 '/dev/sdb' '/dev/sdc' '/dev/sdd'"
        );
        let mount = StorageAction::Mount { device: "/dev/md0".into(), mountpoint: "/mnt/backup/".into(), persist: true, own: true }.script().unwrap();
        assert!(mount.starts_with("mkdir -p '/mnt/backup' && mount '/dev/md0' '/mnt/backup' && chown \"${SUDO_UID:-0}:${SUDO_GID:-0}\" '/mnt/backup'"), "{mount}");
        assert!(mount.contains("defaults,nofail 0 2"));
        let parsed: StorageAction = serde_json::from_value(serde_json::json!({ "action": "createRaid", "name": "md0", "level": 1, "devices": ["/dev/sdb", "/dev/sdc"] })).unwrap();
        assert_eq!(parsed.consumes(), vec!["/dev/sdb", "/dev/sdc"]);
    }
}
