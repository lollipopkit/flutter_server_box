//! What one sampling cycle produces: the metrics model the API serves and
//! history stores, and the settings that apply live.

use crate::{
    core::config::MonitoringConfig,
    monitoring::timeseries::CpuCoreTime,
};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// The subset of `MonitoringConfig` that takes effect immediately on a
/// settings save, instead of requiring a restart — resolved once from
/// `Config` at startup, then read fresh by `run_monitoring_loop` every
/// cycle so a later write through `PUT /api/v1/settings` is picked up
/// without restarting the process.
#[derive(Debug, Clone)]
pub struct LiveSettings {
    pub extended_interval_secs: u64,
    pub idle_pause_enabled: bool,
    pub idle_pause_threshold_secs: u64,
    /// [`MonitoringConfig::disk_counts_network`].
    pub disk_counts_network: bool,
}

impl LiveSettings {
    pub fn from_config(config: &MonitoringConfig) -> Self {
        Self {
            extended_interval_secs: config.effective_extended_interval_secs(),
            idle_pause_enabled: config.extended.idle_pause.enabled,
            idle_pause_threshold_secs: config.effective_idle_pause_threshold_secs(),
            disk_counts_network: config.disk_counts_network,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemMetrics {
    pub timestamp: DateTime<Utc>,
    /// When amd/sensors/batteries/disk_smart were last actually refreshed
    /// (the extended script ran) — distinct from `timestamp`, which updates
    /// every cycle even when those fields are just carried forward unchanged
    pub extended_updated_at: DateTime<Utc>,
    pub server_name: String,
    pub cpu_usage: f32,
    pub cpu_cores: Vec<CpuCoreTime>,
    pub memory: MemoryMetrics,
    pub swap: SwapMetrics,
    pub disk: DiskMetrics,
    pub network: NetworkMetrics,
    /// The single reading the home-page card shows: a CPU sensor when one is
    /// identifiable, else any. Kept alongside `temps` because every consumer
    /// wants that one number and re-deriving the preference order per client
    /// would let them drift.
    pub temperature: Option<f32>,
    /// Every sensor the platform exposes, keyed by device name. `Temperatures`
    /// has always been a named map; only this API flattened it.
    #[serde(default)]
    pub temps: Vec<TempReading>,
    /// System version description (PRETTY_NAME / uname / OsName), if parsed
    pub sys: Option<String>,
    /// `/etc/os-release`'s `ID=` — Linux only, and what a client should match
    /// the distribution on rather than looking for substrings in [`sys`].
    ///
    /// [`sys`]: SystemMetrics::sys
    #[serde(default)]
    pub os_id: Option<String>,
    /// `/etc/os-release`'s `ID_LIKE=`, closest base first. Only a derivative
    /// declares one, so this is empty on most installs.
    #[serde(default)]
    pub os_id_like: Vec<String>,
    /// CPU model, e.g. "Apple M1 Pro" or "Intel(R) Core(TM) i7 (x8)" when
    /// several logical cores share one brand string; joined with ", " for
    /// the rare heterogeneous (multi-socket, differing model) case
    pub cpu_brand: Option<String>,
    /// Detail lists for the panel's drill-down views (not persisted)
    #[serde(default)]
    pub gpus: Vec<GpuMetrics>,
    #[serde(default)]
    pub disk_details: Vec<DiskDetail>,
    #[serde(default)]
    pub ifaces: Vec<IfaceMetrics>,
    /// System uptime, already formatted by the collection script (e.g. "up 3 days, 2:14")
    pub uptime: Option<String>,
    pub conn: Option<sbm_parser::types::Conn>,
    /// Cumulative per-device sector counters (not a rate — see `diskio_rate`)
    #[serde(default)]
    pub diskio: Vec<sbm_parser::types::DiskIoPiece>,
    /// Bytes/sec since the previous cycle, derived from `diskio`'s cumulative
    /// counters + `timestamp` deltas; empty on the first cycle (no baseline)
    /// or for a device that just appeared
    #[serde(default)]
    pub diskio_rate: Vec<DiskIoRate>,
    #[serde(default)]
    pub batteries: Vec<sbm_parser::types::Battery>,
    #[serde(default)]
    pub sensors: Vec<sbm_parser::types::SensorItem>,
    #[serde(default)]
    pub disk_smart: Vec<SmartSummary>,
    /// The machine's own interface addresses, as `sbm_parser::common::parse_ips`
    /// read them — every address, public or not.
    ///
    /// Here so the app can place a server it reaches at a private address:
    /// this agent runs *on* the machine, so it can answer where the machine is
    /// without the app running a command for it.
    ///
    /// Extended cadence, carried forward in between — an address changes when
    /// a machine moves or its lease does, not between two samples.
    #[serde(default)]
    pub ips: Vec<String>,
    /// Output of the user's custom commands, in the order their files sort in
    /// — which is the order the user arranged them in. Refreshed on the
    /// extended cycle, since that is the one that runs the script.
    #[serde(default)]
    pub custom_cmds: Vec<CustomCmdOutput>,
    /// Last legacy AMD CLI reading, kept only on platforms where it remains an
    /// extended command. Linux DRM/sysfs GPUs are sampled every cycle instead.
    /// Not part of the API.
    #[serde(skip, default)]
    pub amd_cache: Vec<sbm_parser::types::AmdSmiItem>,
}

/// What one custom command printed.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CustomCmdOutput {
    pub name: String,
    pub output: String,
}

/// `sbm_parser::types::DiskSmart` trimmed for display: drops `raw_data` /
/// `smart_attributes`, which would otherwise re-serialize a large SMART JSON
/// blob on every `/api/metrics` poll even though it only changes once per
/// extended collection cycle
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SmartSummary {
    pub device: String,
    pub healthy: Option<bool>,
    pub temperature: Option<f64>,
    pub model: Option<String>,
    pub serial: Option<String>,
    pub power_on_hours: Option<i64>,
    pub power_cycle_count: Option<i64>,
}

impl From<&sbm_parser::types::DiskSmart> for SmartSummary {
    fn from(d: &sbm_parser::types::DiskSmart) -> Self {
        Self {
            device: d.device.clone(),
            healthy: d.healthy,
            temperature: d.temperature,
            model: d.model.clone(),
            serial: d.serial.clone(),
            power_on_hours: d.power_on_hours,
            power_cycle_count: d.power_cycle_count,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TempReading {
    pub device: String,
    /// Celsius
    pub value: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryMetrics {
    pub total: u64,
    pub used: u64,
    pub free: u64,
    pub usage_percent: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SwapMetrics {
    pub total: u64,
    pub used: u64,
    pub usage_percent: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskMetrics {
    pub total: u64,
    pub used: u64,
    pub free: u64,
    pub usage_percent: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkMetrics {
    pub rx_bytes: u64,
    pub tx_bytes: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GpuMetrics {
    pub id: String,
    pub vendor: String,
    pub name: String,
    pub usage_percent: Option<f32>,
    pub temperature: Option<i64>,
    /// e.g. "24.55 W / 350.00 W"
    pub power: Option<String>,
    pub memory_used: Option<i64>,
    pub memory_total: Option<i64>,
    /// Unit of the memory figures as reported by the tool (MiB usually)
    pub memory_unit: Option<String>,
    pub fan_speed: Option<i64>,
    pub clock_speed: Option<i64>,
    /// What holds the card's memory: pid, name, MiB (0 where the driver does
    /// not report it, as under WDDM). Read with the rest of this, watch tokens
    /// included; it says which program is using a GPU, not what it runs.
    /// Empty for drivers that list none (Intel, AMD through DRM). Absent on
    /// older agents.
    #[serde(default)]
    pub processes: Vec<sbm_parser::types::GpuMemProcess>,
}

impl From<sbm_parser::types::GpuItem> for GpuMetrics {
    fn from(gpu: sbm_parser::types::GpuItem) -> Self {
        let (memory_used, memory_total, memory_unit, processes) = gpu
            .memory
            .map(|memory| {
                (
                    Some(memory.used),
                    Some(memory.total),
                    Some(memory.unit),
                    memory.processes,
                )
            })
            .unwrap_or((None, None, None, Vec::new()));
        Self {
            id: gpu.id,
            vendor: gpu.vendor,
            name: gpu.name,
            usage_percent: gpu.utilization.map(|value| value as f32),
            temperature: gpu.temperature,
            power: gpu.power,
            memory_used,
            memory_total,
            memory_unit,
            fan_speed: gpu.fan_speed,
            clock_speed: gpu.clock_speed,
            processes,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskDetail {
    pub path: String,
    pub mount: String,
    pub fs_type: Option<String>,
    /// Bytes
    pub used: u64,
    pub total: u64,
    pub usage_percent: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IfaceMetrics {
    pub name: String,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DiskIoRate {
    pub dev: String,
    pub read_bytes_per_sec: f64,
    pub write_bytes_per_sec: f64,
}
