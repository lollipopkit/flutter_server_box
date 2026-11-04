//! Shared parser FFI
//!
//! Boundary contract: input is a map of command key → raw output, output is
//! [`StatusReport`]: `sbm_parser`'s readings, typed. The Dart side builds its
//! windowed models (rates, history) from it. Parsing is pure; the FFI holds
//! no state.

use std::collections::HashMap;

use flutter_rust_bridge::frb;
use sbm_parser::types;
use serde_json::Value;
pub use sbm_parser::types::{
    AmdSmiItem, Battery, BatteryStatus, Conn, CpuCore, Disk, DiskIoPiece, GpuItem, GpuMem, GpuMemProcess, Memory, NetIface, NvidiaSmiItem,
    SensorItem, SmartAttributeFlags, Swap,
};

/// Collection command, single source of truth shared with the app's script generation
pub struct CommandSpec {
    pub key: String,
    pub cmd: String,
}

fn parse_system(system: &str) -> Option<sbm_parser::SystemType> {
    match system {
        "linux" => Some(sbm_parser::SystemType::Linux),
        "bsd" => Some(sbm_parser::SystemType::Bsd),
        "windows" => Some(sbm_parser::SystemType::Windows),
        _ => None,
    }
}

/// Shared by the script FFI module; not exposed over the bridge
#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn parse_system_or_err(system: &str) -> Result<sbm_parser::SystemType, String> {
    parse_system(system).ok_or_else(|| format!("unknown system: {system}"))
}

/// One collection round, parsed. The readings are `sbm_parser`'s own,
/// mirrored; what does not cross as it is — SMART, temperatures and the block
/// device tree, whose model holds JSON values, ordered maps or a name another
/// mirror has — is reported in a type of this layer, converted here.
pub struct StatusReport {
    pub cpu: Vec<CpuCore>,
    /// Each CPU model and how many cores carry it.
    pub cpu_brand: Vec<(String, u32)>,
    pub mem: Option<Memory>,
    pub swap: Option<Swap>,
    pub disks: Vec<Disk>,
    /// The disk total in KiB, by `sbm_parser::types::disk_usage` — the one the
    /// monitor agent stores — with network filesystems only when asked for.
    pub disk_used: u64,
    pub disk_size: u64,
    pub block_devices: Vec<StatusBlockDevice>,
    pub net: Vec<NetIface>,
    /// By name, in name order.
    pub temps: Vec<(String, f64)>,
    pub conn: Option<Conn>,
    pub uptime: Option<String>,
    pub sys: Option<String>,
    pub os_id: Option<String>,
    pub os_id_like: Vec<String>,
    pub host: Option<String>,
    pub ips: Vec<String>,
    pub diskio: Vec<DiskIoPiece>,
    pub batteries: Vec<Battery>,
    pub sensors: Vec<SensorItem>,
    pub nvidia: Vec<NvidiaSmiItem>,
    pub amd: Vec<AmdSmiItem>,
    pub gpus: Vec<GpuItem>,
    pub disk_smart: Vec<SmartReport>,
}

/// `sbm_parser::types::BlockDevice`.
pub struct StatusBlockDevice {
    pub name: String,
    pub path: String,
    pub kind: String,
    pub model: Option<String>,
    pub size: u64,
    pub tran: Option<String>,
    pub fs_type: Option<String>,
    pub mount: Option<String>,
    pub in_use: bool,
    pub children: Vec<StatusBlockDevice>,
}

/// `sbm_parser::types::DiskSmart`, without smartctl's whole answer, which
/// nothing here reads; its attributes in name order.
pub struct SmartReport {
    pub device: String,
    pub healthy: Option<bool>,
    pub temperature: Option<f64>,
    pub model: Option<String>,
    pub serial: Option<String>,
    pub power_on_hours: Option<i64>,
    pub power_cycle_count: Option<i64>,
    pub attributes: Vec<SmartReading>,
}

/// `sbm_parser::types::SmartAttribute`. `raw_value` is smartctl's raw value
/// where it is a whole number, which is what every count is read from.
pub struct SmartReading {
    pub id: Option<i64>,
    pub name: String,
    pub value: Option<i64>,
    pub worst: Option<i64>,
    pub thresh: Option<i64>,
    pub when_failed: Option<String>,
    pub raw_value: Option<i64>,
    pub raw_string: Option<String>,
    pub flags: SmartAttributeFlags,
}

impl From<&types::BlockDevice> for StatusBlockDevice {
    fn from(d: &types::BlockDevice) -> Self {
        StatusBlockDevice {
            name: d.name.clone(),
            path: d.path.clone(),
            kind: d.kind.clone(),
            model: d.model.clone(),
            size: d.size,
            tran: d.tran.clone(),
            fs_type: d.fs_type.clone(),
            mount: d.mount.clone(),
            in_use: d.in_use,
            children: d.children.iter().map(Into::into).collect(),
        }
    }
}

impl From<types::DiskSmart> for SmartReport {
    fn from(d: types::DiskSmart) -> Self {
        SmartReport {
            device: d.device,
            healthy: d.healthy,
            temperature: d.temperature,
            model: d.model,
            serial: d.serial,
            power_on_hours: d.power_on_hours,
            power_cycle_count: d.power_cycle_count,
            attributes: d
                .smart_attributes
                .into_values()
                .map(|a| SmartReading {
                    id: a.id,
                    name: a.name,
                    value: a.value,
                    worst: a.worst,
                    thresh: a.thresh,
                    when_failed: a.when_failed,
                    raw_value: whole(&a.raw_value),
                    raw_string: a.raw_string,
                    flags: a.flags,
                })
                .collect(),
        }
    }
}

/// A raw value as the count it is: a whole number, written as a number or
/// spelled out.
fn whole(v: &Value) -> Option<i64> {
    match v {
        Value::Number(n) => n.as_i64().or_else(|| n.as_f64().filter(|f| f.fract() == 0.0).map(|f| f as i64)),
        Value::String(s) => s.trim().parse().ok(),
        _ => None,
    }
}

/// Parses all output of one collection round. `system`: "linux" | "bsd" |
/// "windows"; see `ParseOptions` for `temp_divisor`. Async: runs on the Rust
/// thread pool without blocking the UI isolate.
pub fn parse_status(system: String, raw: HashMap<String, String>, temp_divisor: f64, count_network: bool) -> Result<StatusReport, String> {
    let system = parse_system(&system).ok_or_else(|| format!("unknown system: {}", system))?;
    let status = sbm_parser::parse_status_opts(system, &raw, sbm_parser::ParseOptions { temp_divisor });
    let (disk_used, disk_size) = types::disk_usage(&status.disks, count_network);
    Ok(StatusReport {
        block_devices: status.block_devices.iter().map(Into::into).collect(),
        temps: status.temps.0.into_iter().collect(),
        disk_smart: status.disk_smart.into_iter().map(Into::into).collect(),
        cpu: status.cpu,
        cpu_brand: status.cpu_brand,
        mem: status.mem,
        swap: status.swap,
        disks: status.disks,
        disk_used,
        disk_size,
        net: status.net,
        conn: status.conn,
        uptime: status.uptime,
        sys: status.sys,
        os_id: status.os_id,
        os_id_like: status.os_id_like,
        host: status.host,
        ips: status.ips,
        diskio: status.diskio,
        batteries: status.batteries,
        sensors: status.sensors,
        nvidia: status.nvidia,
        amd: status.amd,
        gpus: status.gpus,
    })
}

// --- Mirrors -----------------------------------------------------------------

#[frb(mirror(CpuCore))]
pub struct _CpuCore {
    pub id: String,
    pub user: u64,
    pub sys: u64,
    pub nice: u64,
    pub idle: u64,
    pub iowait: u64,
    pub irq: u64,
    pub softirq: u64,
}

#[frb(mirror(Memory))]
pub struct _Memory {
    pub total: u64,
    pub free: u64,
    pub avail: u64,
}

#[frb(mirror(Swap))]
pub struct _Swap {
    pub total: u64,
    pub free: u64,
    pub cached: u64,
}

#[frb(mirror(Disk))]
pub struct _Disk {
    pub path: String,
    pub fs_type: Option<String>,
    pub mount: String,
    pub used_percent: u32,
    pub used: u64,
    pub size: u64,
    pub avail: u64,
    pub name: Option<String>,
    pub kname: Option<String>,
    pub uuid: Option<String>,
    pub children: Vec<Disk>,
}

#[frb(mirror(NetIface))]
pub struct _NetIface {
    pub device: String,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
}

#[frb(mirror(Conn))]
pub struct _Conn {
    pub max_conn: i64,
    pub fail: i64,
}

#[frb(mirror(DiskIoPiece))]
pub struct _DiskIoPiece {
    pub dev: String,
    pub sectors_read: i64,
    pub sectors_write: i64,
}

#[frb(mirror(BatteryStatus))]
pub enum _BatteryStatus {
    Charging,
    Discharging,
    Full,
    Unknown,
}

#[frb(mirror(Battery))]
pub struct _Battery {
    pub percent: Option<i64>,
    pub status: BatteryStatus,
    pub name: Option<String>,
    pub cycle: Option<i64>,
    pub tech: Option<String>,
}

#[frb(mirror(SensorItem))]
pub struct _SensorItem {
    pub device: String,
    pub adapter: String,
    pub details: Vec<(String, String)>,
}

#[frb(mirror(GpuMemProcess))]
pub struct _GpuMemProcess {
    pub pid: i64,
    pub name: String,
    pub memory: i64,
}

#[frb(mirror(GpuMem))]
pub struct _GpuMem {
    pub total: i64,
    pub used: i64,
    pub unit: String,
    pub processes: Vec<GpuMemProcess>,
}

#[frb(mirror(NvidiaSmiItem))]
pub struct _NvidiaSmiItem {
    pub name: String,
    pub temp: Option<i64>,
    pub power: Option<String>,
    pub memory: Option<GpuMem>,
    pub percent: Option<i64>,
    pub fan_speed: Option<i64>,
}

#[frb(mirror(AmdSmiItem))]
pub struct _AmdSmiItem {
    pub name: String,
    pub temp: Option<i64>,
    pub power: Option<String>,
    pub memory: Option<GpuMem>,
    pub utilization: Option<i64>,
    pub fan_speed: Option<i64>,
    pub clock_speed: Option<i64>,
}

#[frb(mirror(GpuItem))]
pub struct _GpuItem {
    pub id: String,
    pub vendor: String,
    pub name: String,
    pub utilization: Option<f64>,
    pub temperature: Option<i64>,
    pub power: Option<String>,
    pub memory: Option<GpuMem>,
    pub fan_speed: Option<i64>,
    pub clock_speed: Option<i64>,
}

#[frb(mirror(SmartAttributeFlags))]
pub struct _SmartAttributeFlags {
    pub value: Option<i64>,
    pub string: Option<String>,
    pub prefailure: bool,
    pub updated_online: bool,
    pub performance: bool,
    pub error_rate: bool,
    pub event_count: bool,
    pub auto_keep: bool,
}

/// The probe that tells a Unix server's system (`sbm_parser::system`).
#[flutter_rust_bridge::frb(sync)]
pub fn system_probe_uname() -> String {
    sbm_parser::system::UNAME_PROBE.to_owned()
}

/// The probe that tells Windows, run when `uname` said nothing it knows.
#[flutter_rust_bridge::frb(sync)]
pub fn system_probe_ver() -> String {
    sbm_parser::system::VER_PROBE.to_owned()
}

/// What `uname -a` said, as `linux` / `bsd`; `None` when it says neither.
#[flutter_rust_bridge::frb(sync)]
pub fn system_from_uname(output: String) -> Option<String> {
    sbm_parser::system::from_uname(&output).map(system_name)
}

/// `windows` when `ver` answered as Windows does.
#[flutter_rust_bridge::frb(sync)]
pub fn system_from_ver(output: String) -> Option<String> {
    sbm_parser::system::from_ver(&output).map(system_name)
}

fn system_name(system: sbm_parser::SystemType) -> String {
    match system {
        sbm_parser::SystemType::Linux => "linux",
        sbm_parser::SystemType::Bsd => "bsd",
        sbm_parser::SystemType::Windows => "windows",
    }
    .to_owned()
}

/// The seconds a status's `uptime` string says (`sbm_parser::common::uptime_seconds`);
/// `None` when it cannot be read.
#[flutter_rust_bridge::frb(sync)]
pub fn uptime_seconds(formatted: String) -> Option<u64> {
    sbm_parser::common::uptime_seconds(&formatted)
}

/// Per-platform collection command manifest (the app's script generation derives from it, versioned with the parsers)
#[flutter_rust_bridge::frb(sync)]
pub fn command_specs(system: String) -> Result<Vec<CommandSpec>, String> {
    let system = parse_system(&system).ok_or_else(|| format!("unknown system: {}", system))?;
    Ok(sbm_parser::commands::commands(system)
        .iter()
        .map(|spec| CommandSpec { key: spec.key.to_string(), cmd: spec.cmd.to_string() })
        .collect())
}

/// Once per process, however many isolates load the library: each
/// `RustLib.init` calls this — the transfer worker's, once per transfer — and
/// every setup wraps the panic hook in another layer that captures a backtrace.
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    static ONCE: std::sync::Once = std::sync::Once::new();
    ONCE.call_once(flutter_rust_bridge::setup_default_user_utils);
}
