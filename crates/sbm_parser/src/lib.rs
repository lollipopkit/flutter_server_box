//! ServerBox 共享状态解析库(见 ADR 0001)
//!
//! 纯解析,无 IO:输入为「命令 key → 原始输出」的映射,输出为结构化状态。
//! 语义基准为 flutter_server_box 的 Dart 实现(`lib/data/model/server/`),
//! 迁移时以 App 的 fixture 测试锁定行为。
//!
//! 设计约束:
//! - 解析产出原始计数器(CPU ticks、网卡累计字节、磁盘扇区),差分/滑窗
//!   由调用方或本库的纯函数(`types::` 中的 delta 助手)完成,不持有可变状态
//! - 单位跟随数据源:内存/磁盘为 KiB(meminfo/df -k),网络为字节

pub mod bsd;
pub mod commands;
pub mod common;
pub mod gpu;
pub mod linux;
pub mod smart;
pub mod types;
pub mod windows;

use std::collections::HashMap;
use types::*;

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SystemType {
    Linux,
    /// BSD 家族,含 macOS
    Bsd,
    Windows,
}

/// 一次采集的解析结果。字段为 `None`/空表示对应命令缺失或解析失败,
/// 与 App 逐段 try-catch 的容错语义一致:单段失败不影响其余字段。
#[derive(Debug, Clone, Default, serde::Serialize, serde::Deserialize)]
pub struct ServerStatus {
    pub cpu: Vec<CpuCore>,
    /// CPU 型号 → 逻辑核数(保持出现顺序)
    pub cpu_brand: Vec<(String, u32)>,
    pub mem: Option<Memory>,
    pub swap: Option<Swap>,
    pub disks: Vec<Disk>,
    pub net: Vec<NetIface>,
    pub temps: Temperatures,
    pub conn: Option<Conn>,
    pub uptime: Option<String>,
    /// 系统版本描述(PRETTY_NAME / uname / OsName)
    pub sys: Option<String>,
    pub host: Option<String>,
    pub diskio: Vec<DiskIoPiece>,
    pub batteries: Vec<Battery>,
    pub sensors: Vec<SensorItem>,
    pub nvidia: Vec<NvidiaSmiItem>,
    pub amd: Vec<AmdSmiItem>,
    pub disk_smart: Vec<DiskSmart>,
}

/// 解析选项
#[derive(Debug, Clone, Copy)]
pub struct ParseOptions {
    /// 温度值除数:Linux thermal_zone 为毫摄氏度(1000.0);
    /// 传感器直接输出摄氏度时为 1.0(App 的 tempIsCelsius 配置)
    pub temp_divisor: f64,
}

impl Default for ParseOptions {
    fn default() -> Self {
        Self { temp_divisor: 1000.0 }
    }
}

/// 解析入口:`raw` 为命令 key(见 [`commands`])→ 原始输出
pub fn parse_status(system: SystemType, raw: &HashMap<String, String>) -> ServerStatus {
    parse_status_opts(system, raw, ParseOptions::default())
}

pub fn parse_status_opts(
    system: SystemType,
    raw: &HashMap<String, String>,
    opts: ParseOptions,
) -> ServerStatus {
    let get = |key: &str| raw.get(key).map(String::as_str).unwrap_or("");
    let mut status = ServerStatus {
        uptime: common::parse_uptime(get(commands::UPTIME)),
        host: common::parse_hostname(get(commands::HOST)),
        nvidia: gpu::nvidia_from_xml(get(commands::NVIDIA)),
        amd: gpu::amd_from_json(get(commands::AMD)),
        ..ServerStatus::default()
    };

    match system {
        SystemType::Linux => {
            status.cpu = linux::parse_cpu(get(commands::CPU));
            status.cpu_brand = linux::parse_cpu_brand(get(commands::CPU_BRAND));
            status.mem = linux::parse_mem(get(commands::MEM));
            status.swap = linux::parse_swap(get(commands::MEM));
            status.disks = linux::parse_disk(get(commands::DISK));
            status.net = linux::parse_net(get(commands::NET));
            status.temps = linux::parse_temps(
                get(commands::TEMP_TYPE),
                get(commands::TEMP_VAL),
                opts.temp_divisor,
            );
            status.conn = linux::parse_conn(get(commands::CONN));
            status.sys = common::parse_sys_version(get(commands::SYS));
            status.diskio = linux::parse_diskio(get(commands::DISKIO));
            // 与 App 一致:仅收集锂聚合物电池
            status.batteries = linux::parse_batteries(get(commands::BATTERY), true);
            status.sensors = linux::parse_sensors(get(commands::SENSORS));
            status.disk_smart = smart::parse(get(commands::DISK_SMART));
        }
        SystemType::Bsd => {
            status.cpu = bsd::parse_cpu(get(commands::CPU));
            status.mem = bsd::parse_mem(get(commands::MEM));
            status.disks = linux::parse_disk(get(commands::DISK));
            status.net = bsd::parse_net(get(commands::NET));
            status.sys = common::parse_hostname(get(commands::SYS));
        }
        SystemType::Windows => {
            status.cpu = windows::parse_cpu(get(commands::CPU), &[]);
            status.cpu_brand = windows::parse_cpu_brand(get(commands::CPU));
            status.mem = windows::parse_mem(get(commands::MEM));
            status.disks = windows::parse_disks(get(commands::DISK));
            status.temps = windows::parse_temps(get(commands::TEMP));
            status.sys = common::parse_hostname(get(commands::SYS));
            // Windows uptime 已由 PowerShell 预格式化
            status.uptime = common::parse_hostname(get(commands::UPTIME));
            status.conn = get(commands::CONN).trim().parse().ok().map(|count| Conn {
                max_conn: count,
                fail: 0,
            });
            status.batteries = windows::parse_batteries(get(commands::BATTERY));
            // NET 为 WMI 双采样:累计计数进 status.net(与其他平台一致),
            // 即时速率另由 windows::parse_net_speed 差分产出
            status.net = windows::parse_net(get(commands::NET));
            status.diskio = windows::parse_diskio(get(commands::DISKIO));
        }
    }

    status
}
