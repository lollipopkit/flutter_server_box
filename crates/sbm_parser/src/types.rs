//! 结构化状态类型与差分助手
//!
//! 语义对照:flutter_server_box `lib/data/model/server/`
//! (cpu.dart / memory.dart / disk.dart / net_speed.dart / temp.dart)

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// 单核 CPU 累计 ticks(Dart `SingleCpuCore`)。
/// Linux 下来自 /proc/stat;BSD/Windows 下为一次性百分比模拟的计数。
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct CpuCore {
    /// "cpu"(汇总)或 "cpu0"、"cpu1" …
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

/// 两次采样间的 CPU 使用率(Dart `Cpus.usedPercent`),0.0–100.0
pub fn cpu_used_percent(pre: &CpuCore, now: &CpuCore) -> f64 {
    let total_delta = now.total() as i64 - pre.total() as i64;
    if total_delta == 0 {
        return 0.0;
    }
    let idle_delta = now.idle as i64 - pre.idle as i64;
    let used = idle_delta as f64 / total_delta as f64;
    if used.is_nan() { 0.0 } else { 100.0 - used * 100.0 }
}

/// 内存,单位 KiB(Dart `Memory`,来自 meminfo)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Memory {
    pub total: u64,
    pub free: u64,
    pub avail: u64,
}

impl Memory {
    /// Dart `Memory.availPercent`:avail 为 0 时回退 free
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

/// 交换分区,单位 KiB(Dart `Swap`)
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

/// 单个文件系统,大小单位 KiB(Dart `Disk`,来自 df -k / lsblk / WMI)
#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct Disk {
    /// 文件系统路径(如 /dev/sda1、C:)
    pub path: String,
    pub fs_type: Option<String>,
    pub mount: String,
    pub used_percent: u32,
    pub used: u64,
    pub size: u64,
    pub avail: u64,
    /// 设备名(lsblk NAME,如 sda1)
    pub name: Option<String>,
    /// 内核设备名(lsblk KNAME)
    pub kname: Option<String>,
    pub uuid: Option<String>,
    /// 子设备(分区),lsblk 层级
    pub children: Vec<Disk>,
}

/// 是否纳入统计(Dart `_shouldCalc`):
/// /dev 前缀、网络挂载(//)、/mnt 挂载点纳入;shm/overlay/tmpfs 排除;其余纳入
pub fn disk_should_calc(fs: &str, mount: &str) -> bool {
    if fs.starts_with("/dev") || fs.starts_with("//") || mount.starts_with("/mnt") {
        return true;
    }
    !(fs.starts_with("shm") || fs.starts_with("overlay") || fs.starts_with("tmpfs"))
}

/// 网卡累计计数,单位字节(Dart `NetSpeedPart`,不含时间戳——由调用方随采样记录)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NetIface {
    pub device: String,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
}

/// 两次采样间的网卡速率,单位字节/秒(Dart `NetSpeed.speedIn/Out`)
pub fn net_speed(pre: &NetIface, now: &NetIface, seconds: f64) -> Option<(f64, f64)> {
    if seconds <= 0.0 || pre.device != now.device {
        return None;
    }
    let rx = now.rx_bytes.saturating_sub(pre.rx_bytes) as f64 / seconds;
    let tx = now.tx_bytes.saturating_sub(pre.tx_bytes) as f64 / seconds;
    Some((rx, tx))
}

/// TCP 连接统计(Dart `Conn`,来自 /proc/net/snmp)
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub struct Conn {
    pub max_conn: i64,
    pub fail: i64,
}

/// 磁盘 IO 累计扇区计数(Dart `DiskIOPiece`,不含时间戳——由调用方随采样记录)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DiskIoPiece {
    pub dev: String,
    pub sectors_read: i64,
    pub sectors_write: i64,
}

/// 电池状态(Dart `BatteryStatus`)
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

/// 电池(Dart `Battery`,来自 power_supply uevent / Win32_Battery)
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

/// sensors 输出条目(Dart `SensorItem`);details 保持输出顺序
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct SensorItem {
    pub device: String,
    pub adapter: String,
    pub details: Vec<(String, String)>,
}

impl SensorItem {
    /// Dart `SensorItem.summary`:首个 detail 的值
    pub fn summary(&self) -> Option<&str> {
        self.details.first().map(|(_, v)| v.as_str())
    }
}

/// NVIDIA GPU(Dart `NvidiaSmiItem`)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct NvidiaSmiItem {
    pub name: String,
    pub temp: i64,
    /// 如 "24.55 W / 350.00 W";缺失时与 Dart 一致为 "null / null"
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

/// GPU 显存(Dart `NvidiaSmiMem`/`AmdSmiMem`)
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

/// SMART 磁盘健康(Dart `DiskSmart`)
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

/// 磁盘用量聚合(Dart `DiskUsage.parse`):按 path:kname 去重,
/// 自身有数据的节点不再下钻子设备
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

/// 温度表,摄氏度(Dart `Temperatures`)
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Temperatures(pub BTreeMap<String, f64>);

/// CPU 温度器件优先级(Dart `_cpuTemp`)
const CPU_TEMP_KEYS: [&str; 5] = ["x86_pkg_temp", "coretemp", "zenpower", "cpu_thermal", "soc"];

impl Temperatures {
    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    /// Dart `Temperatures.first`:优先返回 CPU 器件温度,否则任意第一个
    pub fn first(&self) -> Option<f64> {
        for key in CPU_TEMP_KEYS {
            if let Some(v) = self.0.get(key) {
                return Some(*v);
            }
        }
        self.0.values().next().copied()
    }
}
