use crate::{core::config::Config, api::server::AppState, utils::error::Result, monitoring::timeseries::CpuCoreTime};
use chrono::{DateTime, Utc};
use sbm_parser::types::{CpuCore, Disk};
use sbm_parser::{ServerStatus, SystemType};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
use std::collections::HashMap;
use std::process::Command;
use std::sync::Arc;
use tokio::time::{sleep, Duration};
use tracing::{info, error};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SystemMetrics {
    pub timestamp: DateTime<Utc>,
    pub server_name: String,
    pub cpu_usage: f32,
    pub cpu_cores: Vec<CpuCoreTime>,
    pub memory: MemoryMetrics,
    pub swap: SwapMetrics,
    pub disk: DiskMetrics,
    pub network: NetworkMetrics,
    pub temperature: Option<f32>,
    /// System version description (PRETTY_NAME / uname / OsName), if parsed
    pub sys: Option<String>,
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
    /// Last AMD reading, kept only to re-merge into `gpus` on cycles the
    /// (expensive, `core: false`) AMD command wasn't run — not part of the API
    #[serde(skip, default)]
    pub amd_cache: Vec<sbm_parser::types::AmdSmiItem>,
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
    pub name: String,
    pub usage_percent: f32,
    pub temperature: i64,
    /// e.g. "24.55 W / 350.00 W"
    pub power: String,
    pub memory_used: i64,
    pub memory_total: i64,
    /// Unit of the memory figures as reported by the tool (MiB usually)
    pub memory_unit: String,
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

/// Whether `cycle` (0-indexed, incrementing once per `interval_seconds`) is
/// due for the slower full-script collection. Cycle 0 is always extended so
/// battery/sensors/SMART/AMD data is populated from the very first sample
/// instead of waiting a full `extended_interval_secs`.
fn is_extended_cycle(cycle: u64, interval_seconds: u64, extended_interval_secs: u64) -> bool {
    let extended_every = (extended_interval_secs / interval_seconds.max(1)).max(1);
    cycle % extended_every == 0
}

pub async fn run_monitoring_loop(app_state: Arc<AppState>) -> Result<()> {
    let monitoring_config = app_state.config.get_monitoring();
    let interval_seconds = monitoring_config.interval_seconds as f64;
    let interval = Duration::from_secs(monitoring_config.interval_seconds);

    info!("Starting monitoring loop with {}s interval", monitoring_config.interval_seconds);

    // CPU summary sample from the previous cycle: cumulative ticks need a
    // cross-cycle delta to yield current usage
    let mut prev_cpu: Option<CpuCore> = None;
    let mut cycle: u64 = 0;
    let mut native_state = sbm_native::NativeState::new();
    let extended_interval_secs = monitoring_config.effective_extended_interval_secs();

    loop {
        let extended_due =
            is_extended_cycle(cycle, monitoring_config.interval_seconds, extended_interval_secs);
        cycle += 1;
        let prev_metrics = app_state.current_metrics.read().await.clone();

        match collect_metrics(
            &app_state.config,
            &mut prev_cpu,
            extended_due,
            prev_metrics.as_ref(),
            &mut native_state,
        )
        .await
        {
            Ok(metrics) => {
                // Store metrics in database
                if let Err(e) = store_metrics(&app_state.db, &metrics).await {
                    error!("Failed to store metrics: {}", e);
                }

                // Update velocity manager with network and CPU core data
                if let Err(e) = app_state.velocity_manager.write().await.update_server_metrics(
                    &metrics.server_name,
                    metrics.network.rx_bytes,
                    metrics.network.tx_bytes,
                    metrics.cpu_cores.clone(),
                    interval_seconds
                ).await {
                    error!("Failed to update velocity metrics: {}", e);
                }

                // Check rules and send alerts with velocity data
                if let Err(e) = crate::monitoring::rules::check_rules_with_velocity(&metrics, &app_state.config, &*app_state.velocity_manager.read().await).await {
                    error!("Failed to check enhanced rules: {}", e);
                }

                // Update current metrics in app state
                *app_state.current_metrics.write().await = Some(metrics);
            }
            Err(e) => {
                error!("Failed to collect metrics: {}", e);
            }
        }

        sleep(interval).await;
    }
}

pub fn system_type() -> SystemType {
    if cfg!(target_os = "windows") {
        SystemType::Windows
    } else if cfg!(target_os = "macos") {
        SystemType::Bsd
    } else {
        SystemType::Linux
    }
}

/// `sbm_parser::capabilities::capabilities` mechanically reflects the shared
/// SCRIPT manifest — correct for the app (script is its only path), but
/// stale for monitor's own native collection cutover (`sbm_native`), which
/// added coverage the script manifest never had on Bsd: `sysinfo` provides
/// swap/diskio/CPU-temperature there even though the old BSD shell command
/// table has no commands for them. Overridden here (not in `sbm_parser`,
/// which must stay script-truthful for the app) rather than changing the
/// shared crate for a monitor-only concern.
pub fn effective_capabilities(system: SystemType) -> sbm_parser::capabilities::Capabilities {
    let mut caps = sbm_parser::capabilities::capabilities(system);
    if system == SystemType::Bsd {
        use sbm_parser::capabilities::FieldSupport;
        // HardwareDependent, not Supported: sysinfo returns empty/zero when
        // there's no swap configured or no exposed thermal sensor (macOS in
        // particular locks down Components on many machines/OS versions) —
        // "collected when present" fits better than "always populated".
        caps.swap = FieldSupport::HardwareDependent;
        caps.diskio = FieldSupport::HardwareDependent;
        caps.temps = FieldSupport::HardwareDependent;
    }
    caps
}

async fn collect_metrics(
    config: &Config,
    prev_cpu: &mut Option<CpuCore>,
    extended_due: bool,
    prev_metrics: Option<&SystemMetrics>,
    native_state: &mut sbm_native::NativeState,
) -> Result<SystemMetrics> {
    let system = system_type();
    let mut status = sbm_native::sample(native_state, system);

    // Not part of sbm_native: neither a pure syscall nor worth bundling into
    // the shared script (a single targeted `nvidia-smi` call, same output
    // shape `gpu::nvidia_from_xml` already parses either way). Runs every
    // cycle, same cadence as before native sampling existed.
    status.nvidia = sample_nvidia(system).await;

    // amd/sensors/batteries/disk_smart have no native path (CLI-tool-bound —
    // amd-smi/rocm-smi, `sensors`, smartctl, platform battery queries) and
    // only refresh on the slower extended cycle; `adapt_status`'s
    // carry_forward keeps the last known values on the cycles in between.
    // Windows' `conn` also has no native implementation yet (would need
    // `GetExtendedTcpTable` FFI) so it rides along on the same schedule;
    // Linux/native already fills `status.conn` and this leaves it alone.
    if extended_due {
        let raw = execute_commands(system).await?;
        let extended = sbm_parser::parse_status(system, &raw);
        status.amd = extended.amd;
        status.sensors = extended.sensors;
        status.batteries = extended.batteries;
        status.disk_smart = extended.disk_smart;
        if status.conn.is_none() {
            status.conn = extended.conn;
        }
    }

    let prev = prev_cpu.take();
    *prev_cpu = summary_core(&status.cpu).cloned();
    Ok(adapt_status(system, status, config, prev.as_ref(), prev_metrics))
}

/// Direct `nvidia-smi` invocation — no script generation/`SrvBoxSep`
/// splitting needed for a single command. Tries PATH resolution first (the
/// common case), then the WSL-mounted Windows driver path (absent from
/// non-interactive PATH under WSL), matching the shell command's fallback
/// this replaces (`commands::LINUX`'s `NVIDIA` entry).
async fn sample_nvidia(system: SystemType) -> Vec<sbm_parser::types::NvidiaSmiItem> {
    let raw = tokio::task::spawn_blocking(move || -> String {
        let output = Command::new("nvidia-smi").args(["-q", "-x"]).output().or_else(|_| {
            Command::new("/usr/lib/wsl/lib/nvidia-smi").args(["-q", "-x"]).output()
        });
        let _ = system; // no per-platform branching needed: PATH resolution covers Windows too
        output
            .ok()
            .filter(|o| o.status.success())
            .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
            .unwrap_or_default()
    })
    .await
    .unwrap_or_default();
    sbm_parser::gpu::nvidia_from_xml(&raw)
}

/// Build the extended-cycle status script shared with the app
/// (`sbm_parser::script`) — `core_only=false` since the fields it's still
/// needed for (amd/sensors/SMART/battery) are all non-core. Everything
/// `sbm_native` covers no longer needs a generated script at all.
fn build_status_script(system: SystemType) -> String {
    sbm_parser::script::build_script(
        system,
        &sbm_parser::script::ScriptOptions {
            core_only: false,
            build_number: env!("CARGO_PKG_VERSION").to_string(),
            ..Default::default()
        },
    )
}

/// Script location in the temp dir. `.ps1` is mandatory for `powershell -File`
fn script_path(system: SystemType) -> std::path::PathBuf {
    let name = match system {
        SystemType::Windows => "status.ps1",
        _ => "status.sh",
    };
    std::env::temp_dir().join("server_box_monitor").join(name)
}

/// Write the script if missing or outdated (tmp reapers / version upgrades);
/// checked every cycle before exec
fn ensure_script(path: &std::path::Path, content: &str) -> std::io::Result<()> {
    let up_to_date = std::fs::read_to_string(path).is_ok_and(|existing| existing == content);
    if up_to_date {
        return Ok(());
    }
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    std::fs::write(path, content)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o755))?;
    }
    Ok(())
}

/// Execute the generated status script and split its output by segment.
/// Failed commands inside the script yield empty segments (the script does
/// `exec 2>/dev/null`), matching the app's per-segment tolerance; per-command
/// stderr is not observable in this mode.
async fn execute_commands(system: SystemType) -> Result<HashMap<String, String>> {
    let content = build_status_script(system);
    let path = script_path(system);

    let output = tokio::task::spawn_blocking(move || -> std::io::Result<std::process::Output> {
        ensure_script(&path, &content)?;
        if cfg!(target_os = "windows") {
            Command::new("powershell")
                .args(["-ExecutionPolicy", "Bypass", "-File"])
                .arg(&path)
                .arg("-s")
                .output()
        } else {
            Command::new("sh").arg(&path).arg("-s").output()
        }
    })
    .await
    .map_err(|e| crate::utils::error::MonitorError::Monitoring(format!("Task join error: {}", e)))?
    .map_err(|e| crate::utils::error::MonitorError::Monitoring(format!("Status script error: {}", e)))?;

    if !output.status.success() {
        error!("Status script exited with {}", output.status);
    }
    let stdout = String::from_utf8_lossy(&output.stdout);
    if stdout.trim().is_empty() {
        return Err(crate::utils::error::MonitorError::Monitoring(
            "Status script produced no output".to_string(),
        ));
    }
    Ok(sbm_parser::script::parse_script_output(&stdout))
}

/// `fresh` wins whenever it has data; otherwise keeps whatever the previous
/// cycle had. Used for the `core: false` fields (diskio on Windows;
/// battery/sensors/disk_smart/amd everywhere) that only get real values on
/// the slower extended-collection cycles, so they don't flicker empty on the
/// core-only cycles in between.
fn carry_forward<T>(fresh: Vec<T>, prev: Vec<T>) -> Vec<T> {
    if fresh.is_empty() { prev } else { fresh }
}

fn carry_forward_opt<T>(fresh: Option<T>, prev: Option<T>) -> Option<T> {
    fresh.or(prev)
}

/// Per-device bytes/sec since `prev_metrics`, from `current`'s cumulative
/// sector counters (native sampling refreshes `diskio` every core cycle now,
/// so this is a real per-cycle rate, not just a once-per-extended-cycle
/// snapshot). Empty on the first cycle, for a zero/negative time delta
/// (clock oddities), or for a device with no matching entry in `prev`
/// (counter reset or newly appeared — one cycle without a rate is cheaper
/// than reporting a bogus spike).
fn compute_diskio_rate(
    now: DateTime<Utc>,
    current: &[sbm_parser::types::DiskIoPiece],
    prev_metrics: Option<&SystemMetrics>,
) -> Vec<DiskIoRate> {
    let Some(prev) = prev_metrics else { return Vec::new() };
    let elapsed = (now - prev.timestamp).num_milliseconds() as f64 / 1000.0;
    if elapsed <= 0.0 {
        return Vec::new();
    }
    current
        .iter()
        .filter_map(|d| {
            let p = prev.diskio.iter().find(|p| p.dev == d.dev)?;
            let read_delta = (d.sectors_read - p.sectors_read).max(0) as f64 * 512.0;
            let write_delta = (d.sectors_write - p.sectors_write).max(0) as f64 * 512.0;
            Some(DiskIoRate {
                dev: d.dev.clone(),
                read_bytes_per_sec: read_delta / elapsed,
                write_bytes_per_sec: write_delta / elapsed,
            })
        })
        .collect()
}

/// Adapt the parse result into the monitor's aggregate metrics
fn adapt_status(
    system: SystemType,
    status: ServerStatus,
    config: &Config,
    prev_cpu: Option<&CpuCore>,
    prev_metrics: Option<&SystemMetrics>,
) -> SystemMetrics {
    let (cpu_usage, cpu_cores) = adapt_cpu(system, &status.cpu, prev_cpu);
    let (memory, swap) = adapt_memory(&status);
    let disk = aggregate_disks(system, &status.disks);
    let network = aggregate_net(&status);

    // Temperature prefers CPU devices (Dart `Temperatures.first`)
    let temperature = match system {
        SystemType::Bsd => None, // top output has no temperature
        _ => status.temps.first().map(|t| t as f32),
    };

    let amd = carry_forward(
        status.amd,
        prev_metrics.map(|p| p.amd_cache.clone()).unwrap_or_default(),
    );

    let gpus = status
        .nvidia
        .iter()
        .map(|g| GpuMetrics {
            name: g.name.clone(),
            usage_percent: g.percent as f32,
            temperature: g.temp,
            power: g.power.clone(),
            memory_used: g.memory.used,
            memory_total: g.memory.total,
            memory_unit: g.memory.unit.clone(),
        })
        .chain(amd.iter().map(|g| GpuMetrics {
            name: g.name.clone(),
            usage_percent: g.utilization as f32,
            temperature: g.temp,
            power: g.power.clone(),
            memory_used: g.memory.used,
            memory_total: g.memory.total,
            memory_unit: g.memory.unit.clone(),
        }))
        .collect();

    let disk_details = flatten_disks(system, &status.disks);

    let ifaces = status
        .net
        .iter()
        .map(|n| IfaceMetrics {
            name: n.device.clone(),
            rx_bytes: n.rx_bytes,
            tx_bytes: n.tx_bytes,
        })
        .collect();

    let disk_smart = carry_forward(
        status.disk_smart.iter().map(SmartSummary::from).collect(),
        prev_metrics.map(|p| p.disk_smart.clone()).unwrap_or_default(),
    );

    let now = Utc::now();
    let diskio = carry_forward(status.diskio, prev_metrics.map(|p| p.diskio.clone()).unwrap_or_default());
    let diskio_rate = compute_diskio_rate(now, &diskio, prev_metrics);

    SystemMetrics {
        timestamp: now,
        server_name: config.get_server_name(),
        cpu_usage,
        cpu_cores,
        memory,
        swap,
        disk,
        network,
        temperature,
        sys: status.sys.clone(),
        cpu_brand: format_cpu_brand(&status.cpu_brand),
        gpus,
        disk_details,
        ifaces,
        uptime: carry_forward_opt(status.uptime, prev_metrics.and_then(|p| p.uptime.clone())),
        conn: carry_forward_opt(status.conn, prev_metrics.and_then(|p| p.conn)),
        diskio,
        diskio_rate,
        batteries: carry_forward(
            status.batteries,
            prev_metrics.map(|p| p.batteries.clone()).unwrap_or_default(),
        ),
        sensors: carry_forward(
            status.sensors,
            prev_metrics.map(|p| p.sensors.clone()).unwrap_or_default(),
        ),
        disk_smart,
        amd_cache: amd,
    }
}

fn format_cpu_brand(brands: &[(String, u32)]) -> Option<String> {
    if brands.is_empty() {
        return None;
    }
    Some(
        brands
            .iter()
            .map(|(name, count)| if *count > 1 { format!("{name} (x{count})") } else { name.clone() })
            .collect::<Vec<_>>()
            .join(", "),
    )
}

/// `Disk.path` is a Unix device path ("/dev/sda1") from Linux's native
/// `df -k` sampling (`sbm_native::linux`) — the `/dev` prefix there filters
/// out `df`'s pseudo-filesystems (tmpfs, overlay, ...) and still matters.
/// Windows (`Disk.path` = drive letter, e.g. "C:") and Bsd/macOS (`Disk.path`
/// = sysinfo's volume label, e.g. "Macintosh HD" — confirmed empirically,
/// `sbm_native::sysinfo_backend` never produces a `/dev`-prefixed path)
/// both source `disks` natively now, where the list sysinfo/WMI returns is
/// already curated to real volumes, so a `/dev` check there would zero out
/// every disk instead of filtering anything meaningful.
fn is_real_disk(system: SystemType, d: &Disk) -> bool {
    d.size > 0
        && match system {
            SystemType::Windows | SystemType::Bsd => true,
            SystemType::Linux => d.path.starts_with("/dev"),
        }
}

/// Every real filesystem as its own row (raw view for the drill-down; unlike
/// aggregate_disks, APFS volumes are not pooled here), KiB -> bytes
fn flatten_disks(system: SystemType, disks: &[Disk]) -> Vec<DiskDetail> {
    fn walk<'a>(system: SystemType, disks: &'a [Disk], seen: &mut Vec<&'a str>, out: &mut Vec<DiskDetail>) {
        for d in disks {
            if is_real_disk(system, d) && !seen.contains(&d.path.as_str()) {
                seen.push(&d.path);
                out.push(DiskDetail {
                    path: d.path.clone(),
                    mount: d.mount.clone(),
                    fs_type: d.fs_type.clone(),
                    used: d.used * 1024,
                    total: d.size * 1024,
                    usage_percent: percent(d.used, d.size),
                });
            }
            walk(system, &d.children, seen, out);
        }
    }
    let mut out = Vec::new();
    walk(system, disks, &mut Vec::new(), &mut out);
    out
}

fn summary_core(cores: &[CpuCore]) -> Option<&CpuCore> {
    cores.iter().find(|c| c.id == "cpu").or_else(|| cores.first())
}

/// CPU usage semantics differ per source:
/// - Linux /proc/stat is cumulative ticks — usage is the delta against the
///   previous sample (Dart `Cpus.usedPercent`); a direct ratio would be the
///   since-boot average. First cycle (no baseline) and counter wraparound
///   report 0.
/// - BSD top / Windows WMI emit one-shot percentage pseudo-counters (totals
///   stay ~100), so the single-sample ratio IS the current usage; a delta
///   would divide by ~0 and always yield 0.
/// Per-core entries become CpuCoreTime (used = total - idle)
fn adapt_cpu(
    system: SystemType,
    cores: &[CpuCore],
    prev_summary: Option<&CpuCore>,
) -> (f32, Vec<CpuCoreTime>) {
    let usage = match system {
        SystemType::Linux => match (prev_summary, summary_core(cores)) {
            (Some(pre), Some(now)) if now.total() > pre.total() => {
                sbm_parser::types::cpu_used_percent(pre, now) as f32
            }
            _ => 0.0,
        },
        _ => summary_core(cores)
            .map(|c| {
                let total = c.total();
                if total == 0 { 0.0 } else { (total - c.idle) as f32 / total as f32 * 100.0 }
            })
            .unwrap_or(0.0),
    };

    let core_times = cores
        .iter()
        .filter(|c| c.id != "cpu")
        .map(|c| CpuCoreTime { used: c.total() - c.idle, total: c.total() })
        .collect();

    (usage, core_times)
}

/// Memory/swap: KiB → bytes; used follows the Dart `Memory.usedPercent` semantics
/// (falls back to free when avail is 0)
fn adapt_memory(status: &ServerStatus) -> (MemoryMetrics, SwapMetrics) {
    let memory = match &status.mem {
        Some(m) => {
            let avail = if m.avail == 0 { m.free } else { m.avail };
            let used = m.total.saturating_sub(avail);
            MemoryMetrics {
                total: m.total * 1024,
                used: used * 1024,
                free: avail * 1024,
                usage_percent: percent(used, m.total),
            }
        }
        None => MemoryMetrics { total: 0, used: 0, free: 0, usage_percent: 0.0 },
    };

    let swap = match &status.swap {
        Some(s) => {
            let used = s.total.saturating_sub(s.free);
            SwapMetrics {
                total: s.total * 1024,
                used: used * 1024,
                usage_percent: percent(used, s.total),
            }
        }
        None => SwapMetrics { total: 0, used: 0, usage_percent: 0.0 },
    };

    (memory, swap)
}

fn percent(used: u64, total: u64) -> f32 {
    if total == 0 { 0.0 } else { (used as f32 / total as f32) * 100.0 }
}

/// APFS volumes of one container each report the full container size/avail
/// (df shows /dev/disk3s1, /dev/disk3s5, ... all at ~container size), so a
/// naive sum multiplies the real capacity. Volumes sharing (base disk, size,
/// avail) belong to one pool: count size/avail once, keep summing used.
/// Linux paths never match the /dev/diskN pattern and are unaffected.
fn apfs_pool_key(d: &Disk) -> Option<(String, u64, u64)> {
    let rest = d.path.strip_prefix("/dev/disk")?;
    let base: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
    (!base.is_empty()).then(|| (base, d.size, d.avail))
}

/// Disk aggregation with Go-compatible /status semantics: real filesystems
/// only (see `is_real_disk`), deduped by path (APFS volumes additionally
/// deduped per container pool), lsblk hierarchy expanded recursively; KiB → bytes
fn aggregate_disks(system: SystemType, disks: &[Disk]) -> DiskMetrics {
    fn walk<'a>(
        system: SystemType,
        disks: &'a [Disk],
        seen: &mut Vec<&'a str>,
        pools: &mut Vec<(String, u64, u64)>,
        acc: &mut (u64, u64, u64),
    ) {
        for d in disks {
            if is_real_disk(system, d) && !seen.contains(&d.path.as_str()) {
                seen.push(&d.path);
                let pooled = match apfs_pool_key(d) {
                    Some(key) if pools.contains(&key) => true,
                    Some(key) => {
                        pools.push(key);
                        false
                    }
                    None => false,
                };
                acc.1 += d.used;
                if !pooled {
                    acc.0 += d.size;
                    acc.2 += d.avail;
                }
            }
            walk(system, &d.children, seen, pools, acc);
        }
    }

    let mut acc = (0u64, 0u64, 0u64);
    walk(system, disks, &mut Vec::new(), &mut Vec::new(), &mut acc);
    let (total, used, avail) = acc;

    DiskMetrics {
        total: total * 1024,
        used: used * 1024,
        free: avail * 1024,
        usage_percent: percent(used, total),
    }
}

fn aggregate_net(status: &ServerStatus) -> NetworkMetrics {
    NetworkMetrics {
        rx_bytes: status.net.iter().map(|n| n.rx_bytes).sum(),
        tx_bytes: status.net.iter().map(|n| n.tx_bytes).sum(),
    }
}

/// Disk segment parsing + Go-compatible aggregation (for /status and tests);
/// Linux-only (the legacy Go /status endpoint never ran on other platforms)
pub fn parse_disk_metrics(segment: &str) -> Result<DiskMetrics> {
    Ok(aggregate_disks(SystemType::Linux, &sbm_parser::linux::parse_disk(segment)))
}

async fn store_metrics(db: &SqlitePool, metrics: &SystemMetrics) -> Result<()> {
    let memory_total = metrics.memory.total as i64;
    let memory_used = metrics.memory.used as i64;
    let memory_free = metrics.memory.free as i64;
    let swap_total = metrics.swap.total as i64;
    let swap_used = metrics.swap.used as i64;
    let disk_total = metrics.disk.total as i64;
    let disk_used = metrics.disk.used as i64;
    let disk_free = metrics.disk.free as i64;
    let network_rx_bytes = metrics.network.rx_bytes as i64;
    let network_tx_bytes = metrics.network.tx_bytes as i64;

    sqlx::query!(
        r#"
        INSERT INTO system_metrics (
            timestamp, server_name, cpu_usage, memory_total, memory_used, memory_free,
            swap_total, swap_used, disk_total, disk_used, disk_free,
            network_rx_bytes, network_tx_bytes, temperature
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        "#,
        metrics.timestamp,
        metrics.server_name,
        metrics.cpu_usage,
        memory_total,
        memory_used,
        memory_free,
        swap_total,
        swap_used,
        disk_total,
        disk_used,
        disk_free,
        network_rx_bytes,
        network_tx_bytes,
        metrics.temperature
    )
    .execute(db)
    .await?;

    // Store CPU core data
    for (core_id, core_time) in metrics.cpu_cores.iter().enumerate() {
        let usage_percent = if core_time.total > 0 {
            ((core_time.total - core_time.used) as f32 / core_time.total as f32) * 100.0
        } else {
            0.0
        };

        let core_id_i32 = core_id as i32;
        let used_time_i64 = core_time.used as i64;
        let total_time_i64 = core_time.total as i64;

        sqlx::query!(
            r#"
            INSERT INTO cpu_core_metrics (
                timestamp, server_name, core_id, used_time, total_time, usage_percent
            ) VALUES (?, ?, ?, ?, ?, ?)
            "#,
            metrics.timestamp,
            metrics.server_name,
            core_id_i32,
            used_time_i64,
            total_time_i64,
            usage_percent
        )
        .execute(db)
        .await?;
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ensure_script_writes_and_rewrites() {
        let dir = std::env::temp_dir().join("sbm_monitor_ensure_script_test");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("status.sh");
        std::fs::remove_file(&path).ok();

        ensure_script(&path, "v1").unwrap();
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "v1");

        // Unchanged content is not rewritten (mtime stays)
        let mtime = std::fs::metadata(&path).unwrap().modified().unwrap();
        ensure_script(&path, "v1").unwrap();
        assert_eq!(std::fs::metadata(&path).unwrap().modified().unwrap(), mtime);

        // Changed content is rewritten
        ensure_script(&path, "v2").unwrap();
        assert_eq!(std::fs::read_to_string(&path).unwrap(), "v2");

        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = std::fs::metadata(&path).unwrap().permissions().mode();
            assert_eq!(mode & 0o777, 0o755);
        }
        std::fs::remove_dir_all(&dir).ok();
    }

    #[test]
    fn effective_capabilities_upgrades_bsd_native_gains() {
        use sbm_parser::capabilities::FieldSupport;
        let caps = effective_capabilities(SystemType::Bsd);
        assert_eq!(caps.swap, FieldSupport::HardwareDependent);
        assert_eq!(caps.diskio, FieldSupport::HardwareDependent);
        assert_eq!(caps.temps, FieldSupport::HardwareDependent);
        // Untouched fields still match the script-manifest-derived baseline
        assert_eq!(caps.conn, FieldSupport::NotImplemented);
    }

    #[test]
    fn effective_capabilities_leaves_linux_and_windows_unchanged() {
        assert_eq!(
            effective_capabilities(SystemType::Linux).swap,
            sbm_parser::capabilities::capabilities(SystemType::Linux).swap
        );
        assert_eq!(
            effective_capabilities(SystemType::Windows).diskio,
            sbm_parser::capabilities::capabilities(SystemType::Windows).diskio
        );
    }

    #[test]
    fn is_extended_cycle_always_true_on_first_cycle() {
        assert!(is_extended_cycle(0, 5, 60));
        assert!(is_extended_cycle(0, 30, 60));
    }

    #[test]
    fn is_extended_cycle_respects_ratio() {
        // 60s extended / 5s interval = every 12th cycle
        assert!(is_extended_cycle(12, 5, 60));
        assert!(!is_extended_cycle(1, 5, 60));
        assert!(!is_extended_cycle(11, 5, 60));
        // extended_interval_secs smaller than interval_seconds: every cycle
        assert!(is_extended_cycle(1, 30, 5));
    }

    fn empty_status() -> ServerStatus {
        ServerStatus::default()
    }

    /// Windows disks use drive-letter paths ("C:"), not "/dev/..." — the
    /// aggregation must not zero them out the way it would filter a
    /// non-device Unix pseudo-filesystem
    #[test]
    fn aggregate_disks_counts_windows_drive_letters() {
        let disks = vec![sbm_parser::types::Disk {
            path: "C:".to_string(),
            mount: "C:".to_string(),
            used: 1000,
            size: 2000,
            avail: 1000,
            ..Default::default()
        }];

        let metrics = aggregate_disks(SystemType::Windows, &disks);
        assert_eq!(metrics.total, 2000 * 1024);
        assert_eq!(metrics.used, 1000 * 1024);

        let details = flatten_disks(SystemType::Windows, &disks);
        assert_eq!(details.len(), 1);
        assert_eq!(details[0].path, "C:");
    }

    #[test]
    fn aggregate_disks_ignores_non_dev_paths_on_unix() {
        let disks = vec![sbm_parser::types::Disk {
            path: "tmpfs".to_string(),
            mount: "/tmp".to_string(),
            used: 1000,
            size: 2000,
            avail: 1000,
            ..Default::default()
        }];

        let metrics = aggregate_disks(SystemType::Linux, &disks);
        assert_eq!(metrics.total, 0);
        assert!(flatten_disks(SystemType::Linux, &disks).is_empty());
    }

    #[test]
    fn adapt_status_uses_fresh_extended_fields_when_present() {
        let mut status = empty_status();
        status.uptime = Some("up 1 day".to_string());
        status.conn = Some(sbm_parser::types::Conn { max_conn: 10, fail: 0 });
        status.diskio = vec![sbm_parser::types::DiskIoPiece {
            dev: "sda".to_string(),
            sectors_read: 100,
            sectors_write: 50,
        }];
        status.batteries = vec![sbm_parser::types::Battery {
            percent: Some(80),
            status: sbm_parser::types::BatteryStatus::Charging,
            name: None,
            cycle: None,
            tech: None,
        }];
        status.sensors = vec![sbm_parser::types::SensorItem {
            device: "coretemp".to_string(),
            adapter: "ISA".to_string(),
            details: vec![],
        }];
        status.disk_smart = vec![sbm_parser::types::DiskSmart {
            device: "sda".to_string(),
            healthy: Some(true),
            temperature: Some(35.0),
            model: None,
            serial: None,
            power_on_hours: None,
            power_cycle_count: None,
            raw_data: serde_json::Value::Null,
            smart_attributes: Default::default(),
        }];

        let metrics = adapt_status(SystemType::Linux, status, &Config::default(), None, None);

        assert_eq!(metrics.uptime.as_deref(), Some("up 1 day"));
        assert_eq!(metrics.conn.unwrap().max_conn, 10);
        assert_eq!(metrics.diskio.len(), 1);
        assert_eq!(metrics.batteries.len(), 1);
        assert_eq!(metrics.sensors.len(), 1);
        assert_eq!(metrics.disk_smart.len(), 1);
    }

    #[test]
    fn adapt_status_carries_forward_when_extended_fields_absent() {
        let prev = adapt_status(
            SystemType::Linux,
            {
                let mut s = empty_status();
                s.uptime = Some("up 1 day".to_string());
                s.diskio = vec![sbm_parser::types::DiskIoPiece {
                    dev: "sda".to_string(),
                    sectors_read: 100,
                    sectors_write: 50,
                }];
                s.batteries = vec![sbm_parser::types::Battery {
                    percent: Some(80),
                    status: sbm_parser::types::BatteryStatus::Charging,
                    name: None,
                    cycle: None,
                    tech: None,
                }];
                s
            },
            &Config::default(),
            None,
            None,
        );

        // Next (core-only) cycle: the script never included these commands,
        // so the parser returns empty/None — the previous snapshot should win.
        let metrics = adapt_status(SystemType::Linux, empty_status(), &Config::default(), None, Some(&prev));

        assert_eq!(metrics.uptime.as_deref(), Some("up 1 day"));
        assert_eq!(metrics.diskio.len(), 1);
        assert_eq!(metrics.batteries.len(), 1);
    }

    #[test]
    fn diskio_rate_computed_from_cumulative_delta_over_elapsed_time() {
        let mut first_status = empty_status();
        first_status.diskio = vec![sbm_parser::types::DiskIoPiece {
            dev: "sda".to_string(),
            sectors_read: 1000,
            sectors_write: 500,
        }];
        let first = adapt_status(SystemType::Linux, first_status, &Config::default(), None, None);
        assert!(first.diskio_rate.is_empty(), "no baseline on the first cycle");

        let mut second_status = empty_status();
        // +2000 sectors read, +1000 written, 1MiB/512B-per-sector = 2048 sectors
        second_status.diskio = vec![sbm_parser::types::DiskIoPiece {
            dev: "sda".to_string(),
            sectors_read: 3000,
            sectors_write: 1500,
        }];
        let mut second = adapt_status(SystemType::Linux, second_status, &Config::default(), None, Some(&first));
        // Force a known 2-second elapsed window instead of relying on real time
        // passing between the two adapt_status() calls in this test
        second.timestamp = first.timestamp + chrono::Duration::seconds(2);
        let rate = compute_diskio_rate(second.timestamp, &second.diskio, Some(&first));

        assert_eq!(rate.len(), 1);
        assert_eq!(rate[0].dev, "sda");
        // (3000-1000)*512 bytes / 2s = 512_000 B/s
        assert_eq!(rate[0].read_bytes_per_sec, 512_000.0);
        // (1500-500)*512 bytes / 2s = 256_000 B/s
        assert_eq!(rate[0].write_bytes_per_sec, 256_000.0);
    }

    /// The monitor's real collection path: run the generated script, split output
    #[cfg(unix)]
    #[tokio::test]
    async fn execute_commands_via_script_smoke() {
        let raw = execute_commands(system_type()).await.unwrap();
        assert!(raw.contains_key("time"), "keys: {:?}", raw.keys().collect::<Vec<_>>());
        assert!(raw.contains_key("echo"));
    }
}
