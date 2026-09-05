//! Structured status types and diff helpers
//!
//! Semantic reference: flutter_server_box `lib/data/model/server/`
//! (cpu.dart / memory.dart / disk.dart / net_speed.dart / temp.dart)

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Cumulative CPU ticks of one core (Dart `SingleCpuCore`).
/// From /proc/stat on Linux; on BSD/Windows synthesized from one-shot percentages.
///
/// KNOWN CROSS-PLATFORM SEMANTIC MISMATCH (not fixed, only documented — see
/// `monitor/CLAUDE.md`'s "已知的跨平台语义差异" section): these fields mean
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

/// Whether a `df` row describes storage worth reporting (Dart `_shouldCalc`):
/// exclude kernel mounts, read-only images and swap areas; include /dev-prefixed
/// sources, network mounts (//), /mnt mount points; exclude
/// shm/overlay/fuse-overlayfs/tmpfs/devtmpfs sources; include the rest
pub fn disk_should_calc(fs: &str, mount: &str) -> bool {
    // Checked before the inclusions below, so that a source spelled like a
    // block device cannot bring these back: a host that exposes many device
    // nodes publishes one devtmpfs row per node, two dozen lines all claiming
    // 0 B used of the same size.
    if is_kernel_mount(mount) || is_read_only_image(fs, mount) || is_swap_area(fs, mount) {
        return false;
    }
    if fs.starts_with("/dev") || fs.starts_with("//") || mount.starts_with("/mnt") {
        return true;
    }
    // `overlay` covers the old `overlayfs` spelling too, but not the
    // `fuse-overlayfs` a rootless podman or docker uses: that one publishes a
    // row per container carrying the host filesystem's own numbers.
    !(fs.starts_with("shm")
        || fs.starts_with("overlay")
        || fs == "fuse-overlayfs"
        || fs.starts_with("tmpfs")
        || fs.starts_with("devtmpfs"))
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
/// `fs` is a filesystem type under `lsblk` and a source under `df`, so the
/// two sources are recognised by different halves of this.
fn is_read_only_image(fs: &str, mount: &str) -> bool {
    matches!(
        fs,
        "squashfs" | "erofs" | "iso9660" | "snapfuse" | "fuse.snapfuse"
    ) || mount.starts_with("/snap/")
        || mount.starts_with("/var/lib/snapd/snap/")
}

/// A swap area, which `lsblk` lists beside filesystems. It has no mount point
/// and no `FSSIZE`, so the row reads `0 B / 0 B`, and swap is reported on its
/// own from `/proc/meminfo` anyway. `df` lists only mounted filesystems and
/// never produces one of these.
fn is_swap_area(fs: &str, mount: &str) -> bool {
    fs == "swap" || mount == "[SWAP]"
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

/// Cumulative disk IO sector counters (Dart `DiskIOPiece`; no timestamp — recorded by the caller per sample)
///
/// KNOWN CROSS-PLATFORM SEMANTIC MISMATCH (not fixed, only documented — see
/// `monitor/CLAUDE.md`'s "已知的跨平台语义差异" section): despite the name and
/// doc, `sectors_read`/`sectors_write` are NOT the same kind of value on every
/// platform.
/// - Linux (`linux::parse_diskio`): genuine cumulative sector counters read
///   straight from `/proc/diskstats` — a true "since boot" total.
/// - Windows (`windows::parse_diskio`): the source command already samples
///   WMI twice one second apart and computes a bytes/sec *rate*, which is
///   then divided by 512 and stored into these same "sectors" fields — i.e.
///   Windows silently returns an instantaneous rate, not a cumulative count.
///
/// Any caller diffing two samples to compute a rate (as this crate's design
/// doc at the top of `lib.rs` assumes for all "raw counters") will
/// double-differentiate Windows data. Not currently an issue because
/// `monitor` only displays the raw value directly (no delta), but a future
/// caller must branch on `SystemType` before doing arithmetic on this field.
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
    /// Dart `Battery.isLiPoly`
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
    pub temp: i64,
    /// e.g. "24.55 W / 350.00 W"; "null / null" when missing, matching Dart
    pub power: String,
    pub memory: GpuMem,
    pub percent: i64,
    pub fan_speed: i64,
}

/// AMD GPU(Dart `AmdSmiItem`)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AmdSmiItem {
    pub name: String,
    pub temp: i64,
    pub power: String,
    pub memory: GpuMem,
    pub utilization: i64,
    pub fan_speed: i64,
    pub clock_speed: i64,
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

/// Disk usage aggregation (Dart `DiskUsage.parse`): dedupe by path:kname,
/// nodes carrying their own data are not descended into
pub fn disk_usage(disks: &[Disk]) -> (u64, u64) {
    fn visit(disk: &Disk, seen: &mut Vec<String>, used: &mut u64, size: &mut u64) {
        if !disk_should_calc(&disk.path, &disk.mount) {
            return;
        }
        let unique = format!("{}:{}", disk.path, disk.kname.as_deref().unwrap_or("unknown"));
        if !seen.contains(&unique) {
            seen.push(unique);
            *used += disk.used;
            *size += disk.size;
        }
        if disk.used != 0 || disk.size != 0 {
            return;
        }
        for child in &disk.children {
            visit(child, seen, used, size);
        }
    }
    let (mut seen, mut used, mut size) = (Vec::new(), 0, 0);
    for disk in disks {
        visit(disk, &mut seen, &mut used, &mut size);
    }
    (used, size)
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
