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
