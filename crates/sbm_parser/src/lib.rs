//! ServerBox 共享状态解析库(见 ADR 0001)
//!
//! 纯解析,无 IO:输入为「命令 key → 原始输出」的映射,输出为结构化状态。
//! 语义基准为 flutter_server_box 的 Dart 实现(`lib/data/model/server/`),
//! 迁移时以 App 的 fixture 测试锁定行为。
//!
//! 设计约束:
//! - 解析产出原始计数器(CPU ticks、网卡累计字节),差分/滑窗由调用方
//!   或本库的纯函数(`types::` 中的 delta 助手)完成,不持有可变状态
//! - 单位跟随数据源:内存/磁盘为 KiB(meminfo/df -k),网络为字节

pub mod bsd;
pub mod commands;
pub mod linux;
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
    pub mem: Option<Memory>,
    pub swap: Option<Swap>,
    pub disks: Vec<Disk>,
    pub net: Vec<NetIface>,
    pub temps: Temperatures,
}

/// 解析入口:`raw` 为命令 key(见 [`commands`])→ 原始输出
pub fn parse_status(system: SystemType, raw: &HashMap<String, String>) -> ServerStatus {
    let get = |key: &str| raw.get(key).map(String::as_str).unwrap_or("");
    let mut status = ServerStatus::default();

    match system {
        SystemType::Linux => {
            status.cpu = linux::parse_cpu(get(commands::CPU));
            status.mem = linux::parse_mem(get(commands::MEM));
            status.swap = linux::parse_swap(get(commands::MEM));
            status.disks = linux::parse_disk(get(commands::DISK));
            status.net = linux::parse_net(get(commands::NET));
            status.temps =
                linux::parse_temps(get(commands::TEMP_TYPE), get(commands::TEMP_VAL), 1000.0);
        }
        SystemType::Bsd => {
            status.cpu = bsd::parse_cpu(get(commands::CPU));
            status.mem = bsd::parse_mem(get(commands::MEM));
            status.disks = linux::parse_disk(get(commands::DISK));
            status.net = bsd::parse_net(get(commands::NET));
        }
        SystemType::Windows => {
            status.cpu = windows::parse_cpu(get(commands::CPU), &[]);
            status.mem = windows::parse_mem(get(commands::MEM));
            status.disks = windows::parse_disks(get(commands::DISK));
            status.temps = windows::parse_temps(get(commands::TEMP));
            // Windows 网速为 WMI 双采样差分,直接产出速率而非累计计数,
            // 用 windows::parse_net_speed 单独获取
        }
    }

    status
}
