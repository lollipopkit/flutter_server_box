//! Structured status types and diff helpers
//!
//! Semantic reference: flutter_server_box `lib/data/model/server/`
//! (cpu.dart / memory.dart / disk.dart / net_speed.dart / temp.dart)

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Upper bound on how many cores a reported core count may claim.
///
/// On Bsd and Windows the count comes from the host as a bare number
/// (`sysctl -n hw.ncpu`, WMI's `NumberOfLogicalProcessors`) and decides how
/// many [`CpuCore`]s to allocate. A corrupt or hostile answer would otherwise
/// allocate until the process is killed — and in the app that process is the
/// app, since the parser runs in it over FFI rather than behind a boundary an
/// exception could cross.
///
/// Set well above real hardware (the largest shipping x86 parts are in the
/// hundreds of threads) so that the bound only ever rejects a broken reading.
pub const MAX_CPU_CORES: u64 = 4096;

/// Cumulative CPU ticks of one core (Dart `SingleCpuCore`).
/// From /proc/stat on Linux; on BSD/Windows synthesized from one-shot percentages.
///
/// KNOWN CROSS-PLATFORM SEMANTIC MISMATCH (not fixed, only documented — see
/// the "Known cross-platform semantic differences" section in
/// `monitor/CLAUDE.md`): these fields mean
/// three different things depending on `SystemType`, despite sharing one
/// struct shape.
/// - Linux: real cumulative ticks straight from `/proc/stat` — a delta
///   between two samples over the sample interval is the standard, correct
///   way to compute usage.
/// - Bsd: `top`/`vm_stat` only give an instantaneous percentage; that percent
///   is stored directly into `user`/`idle` as if it were a tick count (see
///   `bsd::parse_cpu`), so `total()` is always ~100 and a delta calculation
///   would be meaningless — callers must use the raw percentage, not a delta.
/// - Windows: WMI's `LoadPercentage` is also instantaneous, but
///   `windows::parse_cpu` *accumulates* it onto the previous sample's
///   pseudo-counters (caller-supplied `prev`) to fake a monotonic counter, so
///   deltas work again but the absolute `user`/`idle` values are not
///   comparable to Linux's real tick counts.
///
/// `monitor/src/monitoring/monitoring.rs`'s `adapt_cpu` already branches on
/// `SystemType` to compute usage correctly per platform; any *new* caller of
/// this struct must do the same rather than assuming Linux semantics.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CpuCore {
    /// "cpu" (summary) or "cpu0", "cpu1", ...
    pub id: String,
    pub user: u64,
    pub sys: u64,
    pub nice: u64,
    pub idle: u64,
    pub iowait: u64,
    pub irq: u64,
    pub softirq: u64,
}

impl CpuCore {
    pub fn total(&self) -> u64 {
        self.user + self.sys + self.nice + self.idle + self.iowait + self.irq + self.softirq
    }
}

/// CPU usage between two samples (Dart `Cpus.usedPercent`), 0.0–100.0
pub fn cpu_used_percent(pre: &CpuCore, now: &CpuCore) -> f64 {
    let total_delta = now.total() as i64 - pre.total() as i64;
    if total_delta == 0 {
        return 0.0;
    }
    let idle_delta = now.idle as i64 - pre.idle as i64;
    let used = idle_delta as f64 / total_delta as f64;
    if used.is_nan() { 0.0 } else { 100.0 - used * 100.0 }
}

/// Memory in KiB (Dart `Memory`, from meminfo)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Memory {
    pub total: u64,
    pub free: u64,
    pub avail: u64,
}

impl Memory {
    /// Dart `Memory.availPercent`: falls back to free when avail is 0
    pub fn avail_percent(&self) -> f64 {
        if self.total == 0 {
            return 0.0;
        }
        let avail = if self.avail == 0 { self.free } else { self.avail };
        avail as f64 / self.total as f64
    }

    pub fn used_percent(&self) -> f64 {
        1.0 - self.avail_percent()
    }
}

/// Swap in KiB (Dart `Swap`)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Swap {
    pub total: u64,
    pub free: u64,
    pub cached: u64,
}

impl Swap {
    pub fn used_percent(&self) -> f64 {
        if self.total == 0 {
            0.0
        } else {
            1.0 - self.free as f64 / self.total as f64
        }
    }
}

/// One block device as `lsblk` lists it, whether or not anything is mounted
/// from it: what a disk is, how it is split, and which parts are in use.
///
/// The filesystems the disk totals are made of are [`Disk`]; this is the
/// hardware under them, so a disk with no filesystem yet is here and not
/// there.
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct BlockDevice {
    /// `lsblk` NAME, e.g. `sda1`, `nvme0n1`, `pve-root`
    pub name: String,
    pub path: String,
    /// `lsblk` TYPE: `disk`, `part`, `lvm`, `crypt`, `raid1`, `rom`, ...
    pub kind: String,
    /// Set on whole disks only.
    pub model: Option<String>,
    /// Bytes
    pub size: u64,
    /// Transport: `sata`, `nvme`, `usb`, ...; top-level devices only.
    pub tran: Option<String>,
    pub fs_type: Option<String>,
    /// `[SWAP]` for an active swap area.
    pub mount: Option<String>,
    pub children: Vec<BlockDevice>,
}

/// One filesystem, sizes in KiB (Dart `Disk`, from df -k / lsblk / WMI)
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Disk {
    /// Filesystem path (e.g. /dev/sda1, C:)
    pub path: String,
    pub fs_type: Option<String>,
    pub mount: String,
    pub used_percent: u32,
    pub used: u64,
    pub size: u64,
    pub avail: u64,
    /// Device name (lsblk NAME, e.g. sda1)
    pub name: Option<String>,
    /// Kernel device name (lsblk KNAME)
    pub kname: Option<String>,
    pub uuid: Option<String>,
    /// Child devices (partitions), lsblk hierarchy
    pub children: Vec<Disk>,
}

/// Whether a `df` source describes storage worth reporting (Dart
/// `_shouldCalcSource`): exclude kernel mounts, snap mount points and swap
/// mounts; include /dev-prefixed sources, network mounts (//), /mnt mount
/// points; exclude the virtual filesystems [`is_virtual_fs`] names; include the
/// rest.
///
/// A source carries user-chosen text, so filesystem-type-only rules must not be
/// applied here. Use [`disk_type_should_calc`] for an `lsblk` filesystem type,
/// or [`Disk::is_storage`] where both identifiers are available.
pub fn disk_should_calc(source: &str, mount: &str) -> bool {
    // Checked before the inclusions below, so that a source spelled like a
    // block device cannot bring these back: a host that exposes many device
    // nodes publishes one devtmpfs row per node, two dozen lines all claiming
    // 0 B used of the same size.
    if is_kernel_mount(mount)
        || is_read_only_image_mount(mount)
        || is_swap_mount(mount)
        || is_macos_system_volume(mount)
    {
        return false;
    }
    if source.starts_with("/dev") || source.starts_with("//") || mount.starts_with("/mnt") {
        return true;
    }
    !is_virtual_fs(source)
}

/// Whether an `lsblk` filesystem type describes storage worth reporting.
///
/// Type-only exclusions live here so a `df` source that happens to be named
/// `squashfs`, `iso9660` or `swap` remains ordinary user-managed storage.
pub(crate) fn disk_type_should_calc(fs_type: &str, mount: &str) -> bool {
    if is_read_only_image_type(fs_type) || fs_type == "swap" {
        return false;
    }
    disk_should_calc(fs_type, mount)
}

/// A kernel-backed filesystem with nothing stored behind it, by exact name.
///
/// Matched exactly rather than by prefix, because `fs` is a *source* under
/// `df` and a source carries user-chosen text: a ZFS pool named `tmpfspool`,
/// or an export from an NFS host named `shm-nas`, each begin with one of these
/// and each is storage.
///
/// `overlay` and `overlayfs` are the current and pre-4.0 spellings of docker's
/// own layers. `fuse-overlayfs` is what a rootless podman or docker mounts,
/// one row per container carrying the host filesystem's own numbers.
///
/// `ramfs` is systemd's credential mounts, one per unit that takes a
/// credential. Most `df` builds report `-` for its usage, which fails to parse
/// and drops the row before any of this; naming it here does not depend on
/// that, since a build reporting `0%` instead leaves a row of 0 B.
fn is_virtual_fs(fs: &str) -> bool {
    matches!(
        fs,
        "shm" | "tmpfs" | "ramfs" | "devtmpfs" | "overlay" | "overlayfs" | "fuse-overlayfs"
    )
}

/// A read-only image mounted as a filesystem — a snap's squashfs, the same
/// image handed to a container through `snapfuse`, a mounted ISO — rather than
/// storage anyone manages. Each is full by construction, so it reports 100%
/// and contributes its whole size to the total; a snap-heavy Ubuntu publishes
/// twenty of them, which is the entire device list.
///
/// Matched on the image, never on `/dev/loop`: a loop device carrying a
/// writable filesystem is storage someone mounted on purpose, and it is the
/// `df` fallback hosts (busybox, no lsblk) where that is most likely.
fn is_read_only_image_type(fs_type: &str) -> bool {
    matches!(
        fs_type,
        "squashfs" | "erofs" | "iso9660" | "snapfuse" | "fuse.snapfuse"
    )
}

/// The mount points such images live at. On macOS: the cryptexes the OS
/// mounts for simulator runtimes and toolchains, and the wrapper an iOS app
/// installed on a Mac runs from, each full or nearly so by construction.
fn is_read_only_image_mount(mount: &str) -> bool {
    [
        "/snap/",
        "/var/lib/snapd/snap/",
        "/private/var/run/com.apple.security.cryptexd/",
        "/private/var/folders/",
    ]
    .iter()
    .any(|p| mount.starts_with(p))
}

/// A volume macOS creates and manages for itself: `Preboot`, `VM`, `Update`,
/// `Hardware` and the rest under `/System/Volumes`, and the recovery volume.
/// Each sits in the same APFS container as the user's data and reports that
/// container's size, so listed they are a column of near-empty rows the user
/// has no say over.
///
/// `/System/Volumes/Data` is the exception, and the one that matters: it is
/// where everything the user writes is, so it is the row that fills up.
fn is_macos_system_volume(mount: &str) -> bool {
    if mount == "/Volumes/Recovery" {
        return true;
    }
    let Some(rest) = mount.strip_prefix("/System/Volumes/") else {
        return false;
    };
    rest != "Data" && !rest.starts_with("Data/")
}

/// A swap area, which `lsblk` lists beside filesystems. It has no mount point
/// and no `FSSIZE`, so the row reads `0 B / 0 B`, and swap is reported on its
/// own from `/proc/meminfo` anyway. `df` lists only mounted filesystems and
/// never produces one of these.
fn is_swap_mount(mount: &str) -> bool {
    mount == "[SWAP]"
}

impl Disk {
    /// Whether this describes storage worth reporting, rather than a kernel
    /// mount, a read-only image, a container layer or a swap area
    /// (Dart `Disk.isStorage`).
    ///
    /// A [`Disk`] carries both a source and, where known, a filesystem type, so
    /// each is classified in its own context. Otherwise a `df` source named
    /// `squashfs` is mistaken for that type, while a squashfs whose mount point
    /// is not under `/snap` is missed if only the source is checked.
    pub fn is_storage(&self) -> bool {
        disk_should_calc(&self.path, &self.mount)
            && self
                .fs_type
                .as_deref()
                .is_none_or(|fs_type| disk_type_should_calc(fs_type, &self.mount))
    }

    /// Whether another machine serves this filesystem — NFS, SMB/CIFS, SSHFS,
    /// a VM's share of its host — so that its size is that machine's storage,
    /// not this one's. Listed, but left out of [`disk_usage`] unless asked
    /// for.
    ///
    /// By type where one is known; by source otherwise (`df -k` carries none):
    /// `//host/share` and `host:/export`.
    pub fn is_network(&self) -> bool {
        self.fs_type.as_deref().is_some_and(is_network_type)
            || self.path.starts_with("//")
            || (!self.path.starts_with('/') && self.path.contains(":/"))
    }
}

/// Filesystem types whose storage is on another machine.
fn is_network_type(fs_type: &str) -> bool {
    matches!(
        fs_type,
        "nfs"
            | "nfs4"
            | "cifs"
            | "smb3"
            | "smbfs"
            | "sshfs"
            | "fuse.sshfs"
            | "9p"
            | "virtiofs"
            | "afs"
            | "ceph"
            | "fuse.ceph"
            | "glusterfs"
            | "fuse.glusterfs"
            | "davfs"
            | "fuse.davfs2"
            | "fuse.rclone"
            | "lustre"
    )
}

/// `/dev`, `/proc`, `/sys`, and anything mounted inside them.
///
/// `/run` is deliberately absent: several distributions mount removable media
/// under `/run/media/<user>`, which is a disk someone wants to see. The tmpfs
/// rows `/run` otherwise carries are excluded by their source instead.
fn is_kernel_mount(mount: &str) -> bool {
    ["/dev", "/proc", "/sys"]
        .iter()
        .any(|p| mount == *p || mount.strip_prefix(p).is_some_and(|r| r.starts_with('/')))
}

/// Cumulative NIC counters in bytes (Dart `NetSpeedPart`; no timestamp — recorded by the caller per sample)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NetIface {
    pub device: String,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
}

/// NIC rates between two samples in bytes/sec (Dart `NetSpeed.speedIn/Out`)
pub fn net_speed(pre: &NetIface, now: &NetIface, seconds: f64) -> Option<(f64, f64)> {
    if seconds <= 0.0 || pre.device != now.device {
        return None;
    }
    let rx = now.rx_bytes.saturating_sub(pre.rx_bytes) as f64 / seconds;
    let tx = now.tx_bytes.saturating_sub(pre.tx_bytes) as f64 / seconds;
    Some((rx, tx))
}

/// TCP connection stats (Dart `Conn`, from /proc/net/snmp)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Conn {
    pub max_conn: i64,
    pub fail: i64,
}

/// Cumulative disk IO counters in 512-byte sectors (Dart `DiskIOPiece`; no
/// timestamp — recorded by the caller per sample).
///
/// Linux reads these from `/proc/diskstats`; Windows reads the cumulative byte
/// fields from `Win32_PerfRawData_PerfDisk_LogicalDisk` and divides by 512.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiskIoPiece {
    pub dev: String,
    pub sectors_read: i64,
    pub sectors_write: i64,
}

/// Battery state (Dart `BatteryStatus`)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum BatteryStatus {
    Charging,
    Discharging,
    Full,
    Unknown,
}

impl BatteryStatus {
    pub fn parse(status: Option<&str>) -> Self {
        match status {
            Some("Charging") => Self::Charging,
            Some("Discharging") => Self::Discharging,
            Some("Full") => Self::Full,
            _ => Self::Unknown,
        }
    }
}

/// Battery (Dart `Battery`, from power_supply uevent / Win32_Battery)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Battery {
    pub percent: Option<i64>,
    pub status: BatteryStatus,
    pub name: Option<String>,
    pub cycle: Option<i64>,
    pub tech: Option<String>,
}

impl Battery {
    /// What the Linux collector filters on when only Li-poly packs are wanted
    /// (`parse_batteries`). The Dart side no longer has a counterpart: it reads
    /// this field from the parsed battery instead.
    pub fn is_li_poly(&self) -> bool {
        self.tech.as_deref() == Some("Li-poly")
    }
}

/// One sensors output entry (Dart `SensorItem`); details keep output order
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SensorItem {
    pub device: String,
    pub adapter: String,
    pub details: Vec<(String, String)>,
}

impl SensorItem {
    /// Dart `SensorItem.summary`: value of the first detail
    pub fn summary(&self) -> Option<&str> {
        self.details.first().map(|(_, v)| v.as_str())
    }
}

/// NVIDIA GPU(Dart `NvidiaSmiItem`)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NvidiaSmiItem {
    pub name: String,
    pub temp: Option<i64>,
    /// e.g. "24.55 W / 350.00 W"; absent when both readings are missing
    pub power: Option<String>,
    pub memory: Option<GpuMem>,
    pub percent: Option<i64>,
    pub fan_speed: Option<i64>,
}

/// AMD GPU(Dart `AmdSmiItem`)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AmdSmiItem {
    pub name: String,
    pub temp: Option<i64>,
    pub power: Option<String>,
    pub memory: Option<GpuMem>,
    pub utilization: Option<i64>,
    pub fan_speed: Option<i64>,
    pub clock_speed: Option<i64>,
}

/// Vendor-neutral GPU reading used by Linux DRM discovery and by consumers
/// that need to present several vendors in one device list.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct GpuItem {
    /// Stable device identity where available: PCI BDF on Linux, UUID/index on
    /// vendor tools elsewhere.
    pub id: String,
    /// Lower-case vendor name (`intel`, `amd`, `nvidia`).
    pub vendor: String,
    pub name: String,
    /// Whole-device utilization percentage. Optional because discovering a
    /// DRM device does not imply the current account may read its PMU.
    pub utilization: Option<f64>,
    pub temperature: Option<i64>,
    /// Preformatted live/limit value, e.g. `24.55 W / 350.00 W`.
    pub power: Option<String>,
    pub memory: Option<GpuMem>,
    pub fan_speed: Option<i64>,
    pub clock_speed: Option<i64>,
}

/// GPU memory (Dart `NvidiaSmiMem`/`AmdSmiMem`)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GpuMem {
    pub total: i64,
    pub used: i64,
    pub unit: String,
    pub processes: Vec<GpuMemProcess>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct GpuMemProcess {
    pub pid: i64,
    pub name: String,
    pub memory: i64,
}

/// SMART disk health (Dart `DiskSmart`)
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DiskSmart {
    pub device: String,
    pub healthy: Option<bool>,
    pub temperature: Option<f64>,
    pub model: Option<String>,
    pub serial: Option<String>,
    pub power_on_hours: Option<i64>,
    pub power_cycle_count: Option<i64>,
    pub raw_data: serde_json::Value,
    pub smart_attributes: BTreeMap<String, SmartAttribute>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct SmartAttribute {
    pub id: Option<i64>,
    pub name: String,
    pub value: Option<i64>,
    pub worst: Option<i64>,
    pub thresh: Option<i64>,
    pub when_failed: Option<String>,
    pub raw_value: serde_json::Value,
    pub raw_string: Option<String>,
    pub flags: SmartAttributeFlags,
}

#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct SmartAttributeFlags {
    pub value: Option<i64>,
    pub string: Option<String>,
    pub prefailure: bool,
    pub updated_online: bool,
    pub performance: bool,
    pub error_rate: bool,
    pub event_count: bool,
    pub auto_keep: bool,
}

/// The APFS container a volume is in, with the size and free space every
/// volume in it reports — see [`disk_usage`].
///
/// `/dev/disk3s5` and `/dev/disk3s1s1` (a snapshot of `disk3s1`) are both in
/// `disk3`. Only for a filesystem known to be APFS: partitions of another
/// kind on one disk are separate filesystems, and two of them can report the
/// same size and free space without sharing anything.
///
/// The container is the identity, not the numbers: each volume's size and
/// free space are read one after another, and a write in between makes two
/// volumes of one container disagree — counted twice, had the numbers been
/// part of the key. [`disk_usage`] keeps the first volume's.
///
/// The device is in `path` where `df` reported it, and in `name`, spelled
/// `disk3s5`, where the monitor agent's native sampler keys a volume by its
/// mount point instead.
fn apfs_container(disk: &Disk) -> Option<(String, u64, u64)> {
    if !disk
        .fs_type
        .as_deref()
        .is_some_and(|t| t.eq_ignore_ascii_case("apfs"))
    {
        return None;
    }
    let container = |device: &str| -> Option<String> {
        let rest = device.strip_prefix("/dev/").unwrap_or(device);
        let rest = rest.strip_prefix("disk")?;
        let digits = rest.find(|c: char| !c.is_ascii_digit())?;
        (digits != 0 && rest[digits..].starts_with('s')).then(|| rest[..digits].to_string())
    };
    let base = container(&disk.path).or_else(|| container(disk.name.as_deref()?))?;
    Some((base, disk.size, disk.avail))
}

/// The ZFS pool a dataset is in: the first component of its name. Only for a
/// filesystem known to be ZFS (`df -kT`, the agent's sampler).
fn zfs_pool(disk: &Disk) -> Option<&str> {
    if disk.fs_type.as_deref() != Some("zfs") {
        return None;
    }
    disk.path.split('/').next().filter(|p| !p.is_empty())
}

/// Disk usage aggregation: `(used, size)` in KiB. Deduped by path:kname,
/// nodes carrying their own data are not descended into.
///
/// The volumes of one APFS container count once. Each reports the whole
/// container as its size and the container's free space as its own, so
/// summed, a Mac with a 1 TB disk had a total of seven and read as a quarter
/// full while its data volume was at 95%. A container's used space is its size
/// less its free space, which is what every volume in it is sharing.
///
/// The datasets of one ZFS pool likewise share its free space: each reports
/// its own used space and the pool's free space, so a pool counts the sum of
/// the one and the other once.
///
/// [`Disk::is_network`] filesystems count only with [`count_network`]. A
/// device with no filesystem mounted adds nothing either way: it has no
/// filesystem size to add.
pub fn disk_usage(disks: &[Disk], count_network: bool) -> (u64, u64) {
    let total = disk_total(disks, count_network);
    (total.used, total.size)
}

/// [`disk_usage`], with the space available as well, in KiB.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct DiskTotal {
    pub used: u64,
    pub size: u64,
    /// What `df` calls available: less than `size - used` by whatever the
    /// filesystem keeps back (ext4 reserves 5% for root).
    pub avail: u64,
}

/// [`disk_usage`] with [`DiskTotal::avail`]: what the monitor agent stores.
pub fn disk_total(disks: &[Disk], count_network: bool) -> DiskTotal {
    #[derive(Default)]
    struct Tally {
        seen: Vec<String>,
        containers: Vec<(String, u64, u64)>,
        /// Pool → summed used space, the pool's free space.
        pools: Vec<(String, u64, u64)>,
        used: u64,
        size: u64,
        avail: u64,
    }
    fn visit(disk: &Disk, count_network: bool, t: &mut Tally) {
        if !disk.is_storage() || (!count_network && disk.is_network()) {
            return;
        }
        if let Some(container) = apfs_container(disk) {
            if !t.containers.iter().any(|(c, _, _)| *c == container.0) {
                t.used += container.1.saturating_sub(container.2);
                t.size += container.1;
                t.avail += container.2;
                t.containers.push(container);
            }
            return;
        }
        if let Some(pool) = zfs_pool(disk) {
            match t.pools.iter_mut().find(|(p, _, _)| p == pool) {
                Some((_, used, avail)) => {
                    *used += disk.used;
                    *avail = (*avail).max(disk.avail);
                }
                None => t.pools.push((pool.to_string(), disk.used, disk.avail)),
            }
            return;
        }
        let unique = format!("{}:{}", disk.path, disk.kname.as_deref().unwrap_or("unknown"));
        if !t.seen.contains(&unique) {
            t.seen.push(unique);
            t.used += disk.used;
            t.size += disk.size;
            t.avail += disk.avail;
        }
        if disk.used != 0 || disk.size != 0 {
            return;
        }
        for child in &disk.children {
            visit(child, count_network, t);
        }
    }
    let mut t = Tally::default();
    for disk in disks {
        visit(disk, count_network, &mut t);
    }
    for (_, used, avail) in &t.pools {
        t.used += used;
        t.size += used + avail;
        t.avail += avail;
    }
    DiskTotal {
        used: t.used,
        size: t.size,
        avail: t.avail,
    }
}

/// Temperature table in Celsius (Dart `Temperatures`)
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Temperatures(pub BTreeMap<String, f64>);

/// CPU temperature device priority (Dart `_cpuTemp`)
const CPU_TEMP_KEYS: [&str; 5] = ["x86_pkg_temp", "coretemp", "zenpower", "cpu_thermal", "soc"];

impl Temperatures {
    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    /// Dart `Temperatures.first`: prefer a CPU device temperature, else any first entry
    pub fn first(&self) -> Option<f64> {
        for key in CPU_TEMP_KEYS {
            if let Some(v) = self.0.get(key) {
                return Some(*v);
            }
        }
        self.0.values().next().copied()
    }
}
