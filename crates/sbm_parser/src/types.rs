//! Structured status types and diff helpers
//!
//! Semantic reference: flutter_server_box `lib/data/model/server/`
//! (cpu.dart / memory.dart / disk.dart / net_speed.dart / temp.dart)

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Cumulative CPU ticks of one core (Dart `SingleCpuCore`).
/// From /proc/stat on Linux; on BSD/Windows synthesized from one-shot percentages.
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

/// Whether to include in aggregation (Dart `_shouldCalc`):
/// include /dev-prefixed, network mounts (//), /mnt mount points; exclude shm/overlay/tmpfs; include the rest
pub fn disk_should_calc(fs: &str, mount: &str) -> bool {
    if fs.starts_with("/dev") || fs.starts_with("//") || mount.starts_with("/mnt") {
        return true;
    }
    !(fs.starts_with("shm") || fs.starts_with("overlay") || fs.starts_with("tmpfs"))
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
