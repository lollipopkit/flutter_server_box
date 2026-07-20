//! ServerBox shared status parsing library
//!
//! Pure parsing, no IO: input is a map of command key → raw output, output is
//! structured status. The semantic baseline is flutter_server_box's Dart
//! implementation (`lib/data/model/server/`); behavior is locked by the app's
//! fixture tests during migration.
//!
//! Design constraints:
//! - Parsers emit raw counters (CPU ticks, cumulative NIC bytes, disk sectors);
//!   deltas/windowing are done by the caller or this crate's pure functions
//!   (the delta helpers in `types::`) — no mutable state is held
//! - Units follow the data source: memory/disk in KiB (meminfo/df -k), network in bytes

pub mod bsd;
pub mod capabilities;
pub mod commands;
pub mod common;
pub mod gpu;
pub mod linux;
pub mod script;
pub mod smart;
pub mod types;
pub mod windows;

use std::collections::HashMap;
use types::*;

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum SystemType {
    Linux,
    /// BSD family, including macOS
    Bsd,
    Windows,
}

/// Parse result of one collection round. `None`/empty fields mean the command was
/// missing or failed to parse, matching the app's per-segment try-catch tolerance:
/// one failing segment does not affect the others.
#[derive(Debug, Clone, Default, serde::Serialize, serde::Deserialize)]
pub struct ServerStatus {
    pub cpu: Vec<CpuCore>,
    /// CPU model → logical core count (keeping first-seen order)
    pub cpu_brand: Vec<(String, u32)>,
    pub mem: Option<Memory>,
    pub swap: Option<Swap>,
    pub disks: Vec<Disk>,
    pub net: Vec<NetIface>,
    pub temps: Temperatures,
    pub conn: Option<Conn>,
    /// KNOWN CROSS-PLATFORM DIFFERENCE (see `monitor/CLAUDE.md`): Linux/Bsd
    /// go through `common::parse_uptime`, which normalizes the `uptime`
    /// command's varied output into one string shape; Windows instead
    /// pre-formats the string in PowerShell and this field just passes it
    /// through unparsed (reusing `common::parse_hostname` as a generic
    /// trim-and-pass helper) — the presentation format is not guaranteed
    /// identical across platforms.
    pub uptime: Option<String>,
    /// System version description (PRETTY_NAME / uname / OsName).
    /// KNOWN CROSS-PLATFORM DIFFERENCE: only Linux's `common::parse_sys_version`
    /// is a real distro/version parser; Bsd/Windows repurpose
    /// `common::parse_hostname` (a generic single-line trimmer) against
    /// `uname -or`/`OsName` output — works today because those happen to be
    /// single clean lines, but this field is not semantically a "hostname
    /// parser" output on those platforms, just reused machinery.
    pub sys: Option<String>,
    pub host: Option<String>,
    pub diskio: Vec<DiskIoPiece>,
    pub batteries: Vec<Battery>,
    pub sensors: Vec<SensorItem>,
    pub nvidia: Vec<NvidiaSmiItem>,
    pub amd: Vec<AmdSmiItem>,
    pub disk_smart: Vec<DiskSmart>,
}

/// Parse options
#[derive(Debug, Clone, Copy)]
pub struct ParseOptions {
    /// Temperature divisor: Linux thermal_zone reports millidegree Celsius (1000.0);
    /// 1.0 when sensors output Celsius directly (the app's tempIsCelsius setting)
    pub temp_divisor: f64,
}

impl Default for ParseOptions {
    fn default() -> Self {
        Self { temp_divisor: 1000.0 }
    }
}

/// Parse entry point: `raw` maps command key (see [`commands`]) → raw output
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
            // Matches the app: only lithium-polymer batteries are collected
            status.batteries = linux::parse_batteries(get(commands::BATTERY), true);
            status.sensors = linux::parse_sensors(get(commands::SENSORS));
            status.disk_smart = smart::parse(get(commands::DISK_SMART));
        }
        SystemType::Bsd => {
            status.cpu = bsd::parse_cpu(get(commands::CPU));
            status.cpu_brand = bsd::parse_cpu_brand(get(commands::CPU_BRAND));
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
            // Windows uptime is pre-formatted by PowerShell
            status.uptime = common::parse_hostname(get(commands::UPTIME));
            status.conn = get(commands::CONN).trim().parse().ok().map(|count| Conn {
                max_conn: count,
                fail: 0,
            });
            status.batteries = windows::parse_batteries(get(commands::BATTERY));
            status.sensors = windows::parse_sensors(get(commands::SENSORS));
            status.disk_smart = windows::parse_disk_smart(get(commands::DISK_SMART));
            // NET is a WMI double sample: cumulative counters go into status.net
            // (consistent with other platforms); instantaneous rates are separately
            // derived by windows::parse_net_speed deltas
            status.net = windows::parse_net(get(commands::NET));
            status.diskio = windows::parse_diskio(get(commands::DISKIO));
        }
    }

    status
}
