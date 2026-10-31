use crate::{
    api::server::AppState,
    core::config::Config,
    utils::error::{MonitorError, Result},
};
use sbm_parser::types::CpuCore;
use sbm_parser::{ServerStatus, SystemType};
use sqlx::SqlitePool;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::process::Command as TokioCommand;
use tokio::time::{Duration, sleep};
use tracing::{error, info};
use super::{adapt::*, metrics::*, script::*};


/// Whether `cycle` (0-indexed, incrementing once per `interval_seconds`) is
/// due for the slower full-script collection. Cycle 0 is always extended so
/// battery/sensors/SMART/AMD data is populated from the very first sample
/// instead of waiting a full `extended_interval_secs`.
pub(super) fn is_extended_cycle(cycle: u64, interval_seconds: u64, extended_interval_secs: u64) -> bool {
    let extended_every = (extended_interval_secs / interval_seconds.max(1)).max(1);
    cycle.is_multiple_of(extended_every)
}

/// Whether the extended script should actually run this cycle: `extended_due`
/// (the schedule) AND-ed with the idle-pause check (skip if enabled and
/// nobody's polled `/metrics`/`/status` within the threshold). Core metrics
/// and alert rule checks are never affected — this only ever downgrades
/// `extended_due` from true to false, never the reverse.
pub(super) fn should_run_extended(extended_due: bool, live: &LiveSettings, idle_secs: i64) -> bool {
    if !extended_due || !live.idle_pause_enabled {
        return extended_due;
    }
    // Saturating, not `as i64`. The threshold is a `u64` a config file or a
    // `PUT /settings` supplies, and one above `i64::MAX` wraps to a negative
    // number — so the largest threshold anyone could ask for, meaning "almost
    // never pause", became a comparison nothing satisfies and paused the
    // extended cycle permanently.
    let threshold = i64::try_from(live.idle_pause_threshold_secs).unwrap_or(i64::MAX);
    idle_secs < threshold
}

pub async fn run_monitoring_loop(app_state: Arc<AppState>) -> Result<()> {
    let monitoring_config = app_state.config.get_monitoring();
    let interval = Duration::from_secs(monitoring_config.interval_seconds);

    info!(
        "Starting monitoring loop with {}s interval",
        monitoring_config.interval_seconds
    );

    // CPU summary sample from the previous cycle: cumulative ticks need a
    // cross-cycle delta to yield current usage
    let mut prev_cpu: Option<CpuCore> = None;
    let mut cycle: u64 = 0;
    let mut native = NativeSampler::default();

    loop {
        // Re-read every cycle (not captured once outside the loop) so a
        // `PUT /api/v1/settings` save takes effect on the very next cycle
        // instead of needing a restart — see `LiveSettings`.
        let live = app_state.live_settings.read().await.clone();
        let mut extended_due = is_extended_cycle(
            cycle,
            monitoring_config.interval_seconds,
            live.extended_interval_secs,
        );
        let idle_secs =
            (chrono::Utc::now() - *app_state.last_viewer_seen.read().await).num_seconds();
        extended_due = should_run_extended(extended_due, &live, idle_secs);
        let first_cycle = cycle == 0;
        cycle += 1;
        let prev_metrics = app_state.current_metrics.read().await.clone();

        match collect_metrics(
            &app_state.config,
            &mut prev_cpu,
            extended_due,
            prev_metrics.as_ref(),
            &mut native,
            first_cycle,
            live.disk_counts_network,
        )
        .await
        {
            Ok(metrics) => {
                // Store metrics in database
                if let Err(e) = store_metrics(&app_state.db, &metrics).await {
                    error!("Failed to store metrics: {}", e);
                }

                // Update the bounded in-memory velocity history used by the
                // rules engine and velocity API.
                app_state
                    .velocity_manager
                    .write()
                    .await
                    .update_server_metrics(
                        &metrics.server_name,
                        metrics.network.rx_bytes,
                        metrics.network.tx_bytes,
                        metrics.cpu_cores.clone(),
                        metrics.timestamp,
                    )
                    .await;

                // Check rules and send alerts with velocity data
                match crate::monitoring::rules::check_rules_with_velocity(
                    &metrics,
                    &app_state.config,
                    &*app_state.velocity_manager.read().await,
                )
                .await
                {
                    Ok(firing) => app_state.desk.rules_checked(&app_state.db, firing).await,
                    Err(e) => error!("Failed to check enhanced rules: {}", e),
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
    system_type_for(std::env::consts::OS)
}

pub(super) fn system_type_for(os: &str) -> SystemType {
    match os {
        "windows" => SystemType::Windows,
        "macos" | "freebsd" | "openbsd" | "netbsd" | "dragonfly" => SystemType::Bsd,
        _ => SystemType::Linux,
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
    if native_status_available(system) {
        use sbm_parser::capabilities::FieldSupport;
        if matches!(system, SystemType::Bsd | SystemType::Windows) {
            caps.swap = FieldSupport::HardwareDependent;
        }
        if system == SystemType::Bsd {
            // HardwareDependent, not Supported: sysinfo returns empty/zero
            // when the platform exposes no thermal or disk-I/O data.
            caps.diskio = FieldSupport::HardwareDependent;
            caps.temps = FieldSupport::HardwareDependent;
        }
    }
    caps
}

pub(super) fn native_status_available(system: SystemType) -> bool {
    match system {
        SystemType::Linux | SystemType::Windows => true,
        SystemType::Bsd => cfg!(target_os = "macos"),
    }
}

/// The system, whether to read the block devices again first, and where the
/// sample goes.
pub(super) type SampleRequest = (SystemType, bool, tokio::sync::oneshot::Sender<ServerStatus>);

/// Where `sbm_native::sample` runs: one thread of its own, holding the
/// `NativeState` for that thread's whole life.
///
/// Off the reactor, because `sample` is synchronous and does real IO (procfs
/// and sysfs on Linux, a `statvfs` per mount on the sysinfo backends); a mount
/// that does not answer holds this thread, not a worker serving the API.
///
/// Always the same thread, because on Windows sysinfo's components are WMI
/// COM objects bound to the thread that made them. Moving the state through
/// the blocking pool ran each sample wherever a pooled thread was free, and
/// once the thread that made them had been retired an idle pool thread
/// refreshing them faulted the whole process (`ComponentInner::refresh`,
/// access violation).
///
/// A sample that panics ends the thread; the next one starts a new thread
/// with fresh state, which costs the CPU delta for one sample.
#[derive(Default)]
pub(super) struct NativeSampler {
    tx: Option<std::sync::mpsc::Sender<SampleRequest>>,
}

impl NativeSampler {
    fn start() -> std::io::Result<std::sync::mpsc::Sender<SampleRequest>> {
        let (tx, rx) = std::sync::mpsc::channel::<SampleRequest>();
        std::thread::Builder::new().name("native-sampler".into()).spawn(move || {
            let mut state = sbm_native::NativeState::new();
            for (system, refresh_devices, reply) in rx {
                if refresh_devices {
                    sbm_native::refresh_block_devices(&mut state);
                }
                let _ = reply.send(sbm_native::sample(&mut state, system));
            }
        })?;
        Ok(tx)
    }

    async fn sample(&mut self, system: SystemType, refresh_devices: bool) -> Result<ServerStatus> {
        let failed = |why: String| crate::utils::error::MonitorError::Monitoring(format!("Native sampling failed: {why}"));
        let tx = match &self.tx {
            Some(tx) => tx.clone(),
            None => {
                let tx = Self::start().map_err(|e| failed(e.to_string()))?;
                self.tx = Some(tx.clone());
                tx
            }
        };
        let (reply, answer) = tokio::sync::oneshot::channel();
        if tx.send((system, refresh_devices, reply)).is_err() {
            self.tx = None;
            return Err(failed("the sampler thread is gone".into()));
        }
        match answer.await {
            Ok(status) => Ok(status),
            // It panicked: a fresh thread next cycle.
            Err(_) => {
                self.tx = None;
                Err(failed("the sampler thread panicked".into()))
            }
        }
    }
}

pub(super) async fn collect_metrics(
    config: &Config,
    prev_cpu: &mut Option<CpuCore>,
    extended_due: bool,
    prev_metrics: Option<&SystemMetrics>,
    native: &mut NativeSampler,
    first_cycle: bool,
    disk_counts_network: bool,
) -> Result<SystemMetrics> {
    let system = system_type();
    // The device tree on the slower cycle, the one that pauses while nobody
    // looks; each sample merges it with a fresh `df`. And once at start, which
    // is idle by then: otherwise there is no tree until somebody opens a page.
    let mut status = native.sample(system, extended_due || first_cycle).await?;

    // Not part of sbm_native: neither a pure syscall nor worth bundling into
    // the shared script (a single targeted `nvidia-smi` call, same output
    // shape `gpu::nvidia_from_xml` already parses either way). Runs every
    // cycle, same cadence as before native sampling existed.
    let (nvidia, linux_gpus) = tokio::join!(sample_nvidia(), sample_linux_gpus(system));
    status.nvidia = nvidia;
    status.gpus = linux_gpus;
    status
        .gpus
        .extend(sbm_parser::gpu::nvidia_as_gpu(&status.nvidia));

    // sensors/batteries/disk_smart and legacy Windows AMD have no native path
    // (CLI-tool-bound — `sensors`, smartctl, platform battery queries, AMD
    // userspace tools) and only refresh on the slower extended cycle;
    // `adapt_status`'s carry_forward keeps the last known values on the cycles
    // in between. Linux AMD/Intel DRM readings above refresh every cycle.
    // Windows' `conn` also has no native implementation yet (would need
    // `GetExtendedTcpTable` FFI) so it rides along on the same schedule;
    // Linux/native already fills `status.conn` and this leaves it alone.
    let script_due = extended_due || !native_status_available(system);
    let mut custom_cmds = Vec::new();
    let mut extended_refreshed = false;
    if script_due {
        let execution = match execute_commands(system, extended_due).await {
            Ok(execution) => execution,
            Err(error) if native_status_available(system) => {
                tracing::warn!("optional status script failed; keeping native sample: {error}");
                ScriptExecution::default()
            }
            Err(error) => return Err(error),
        };
        if !execution.status_succeeded && !native_status_available(system) {
            return Err(crate::utils::error::MonitorError::Monitoring(
                "Status script SbStatus failed".to_string(),
            ));
        }
        extended_refreshed = extended_due && execution.extended_succeeded;
        let segments = execution.segments;
        custom_cmds = custom_cmd_outputs(&segments);
        // Built-in probes run before custom commands. Keep the first value for
        // each section so custom output cannot forge a later built-in marker
        // and replace the real reading.
        let mut raw = HashMap::new();
        for (key, value) in segments {
            raw.entry(key).or_insert(value);
        }
        let scripted = sbm_parser::parse_status(system, &raw);
        if native_status_available(system) {
            status.amd = scripted.amd;
            status.sensors = scripted.sensors;
            status.batteries = scripted.batteries;
            status.disk_smart = scripted.disk_smart;
            status.ips = scripted.ips;
            if status.conn.is_none() {
                status.conn = scripted.conn;
            }
        } else {
            let nvidia = std::mem::take(&mut status.nvidia);
            status = scripted;
            status.nvidia = nvidia;
            status.gpus.retain(|gpu| gpu.vendor != "nvidia");
            status
                .gpus
                .extend(sbm_parser::gpu::nvidia_as_gpu(&status.nvidia));
        }
    }

    let prev = prev_cpu.take();
    *prev_cpu = summary_core(&status.cpu).cloned();
    let mut metrics = adapt_status(
        system,
        status,
        config,
        prev.as_ref(),
        prev_metrics,
        extended_refreshed,
        disk_counts_network,
    );
    metrics.custom_cmds = refreshed_custom_cmds(custom_cmds, prev_metrics, extended_refreshed);
    Ok(metrics)
}

pub(super) fn refreshed_custom_cmds(
    custom_cmds: Vec<CustomCmdOutput>,
    prev_metrics: Option<&SystemMetrics>,
    extended_refreshed: bool,
) -> Vec<CustomCmdOutput> {
    // An empty successful extended result means the user deleted their
    // commands. A skipped or failed extended refresh keeps the previous set.
    if extended_refreshed {
        custom_cmds
    } else {
        prev_metrics
            .map(|p| p.custom_cmds.clone())
            .unwrap_or_default()
    }
}

/// The custom-command sections of the script's output, in the order it printed
/// them.
pub(super) fn custom_cmd_outputs(segments: &[(String, String)]) -> Vec<CustomCmdOutput> {
    let prefix = format!("{}.", sbm_parser::script::CUSTOM_CMD_SEPARATOR);
    segments
        .iter()
        .filter_map(|(key, value)| {
            let name = key.strip_prefix(&prefix)?;
            Some(CustomCmdOutput {
                name: name.to_string(),
                output: value.clone(),
            })
        })
        .collect()
}

/// Direct `nvidia-smi` invocation — no script generation/`SrvBoxSep`
/// splitting needed for a single command. Tries PATH resolution first (the
/// common case), then the WSL-mounted Windows driver path (absent from
/// non-interactive PATH under WSL), matching the shell command's fallback
/// this replaces (`commands::LINUX`'s `NVIDIA` entry).
pub(super) async fn sample_nvidia() -> Vec<sbm_parser::types::NvidiaSmiItem> {
    let mut primary = TokioCommand::new("nvidia-smi");
    primary.args(["-q", "-x"]);
    let output = match command_output(primary, "nvidia-smi").await {
        Ok(output) => output,
        // The WSL driver is not normally on a non-interactive service's PATH.
        // Only PATH lookup failure tries this second location; a process that
        // did start but failed its collection remains its own failure.
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            let mut fallback = TokioCommand::new("/usr/lib/wsl/lib/nvidia-smi");
            fallback.args(["-q", "-x"]);
            command_output(fallback, "WSL nvidia-smi")
                .await
                .ok()
                .flatten()
        }
        Err(error) => {
            tracing::warn!("nvidia-smi collection failed: {error}");
            None
        }
    };
    let raw = output
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).into_owned())
        .unwrap_or_default();
    sbm_parser::gpu::nvidia_from_xml(&raw)
}

/// Run the Linux DRM probe from the shared command manifest every cycle.
/// AMD uses kernel sysfs, while Intel delegates per device to `intel_gpu_top`.
/// Keeping the command here targeted avoids running sensors, batteries and
/// user custom commands at the fast monitoring cadence.
pub(super) async fn sample_linux_gpus(system: SystemType) -> Vec<sbm_parser::types::GpuItem> {
    if system != SystemType::Linux {
        return Vec::new();
    }
    let Some(spec) = sbm_parser::commands::commands(system)
        .iter()
        .find(|spec| spec.key == sbm_parser::commands::GPU)
    else {
        return Vec::new();
    };
    let mut command = TokioCommand::new("sh");
    command.args(["-c", spec.cmd]);
    let output = match command_output(command, "Linux GPU collection").await {
        Ok(Some(output)) if output.status.success() => output,
        Ok(_) => return Vec::new(),
        Err(error) => {
            tracing::warn!("Linux GPU collection failed: {error}");
            return Vec::new();
        }
    };
    sbm_parser::gpu::linux_drm_from_output(&String::from_utf8_lossy(&output.stdout))
}

/// Store the aggregate trend row used by history queries. Per-core samples
/// stay in the current in-memory snapshot; no database consumer queried them.
pub async fn store_metrics(db: &SqlitePool, metrics: &SystemMetrics) -> Result<()> {
    let checked = |name: &str, value: u64| {
        i64::try_from(value)
            .map_err(|_| MonitorError::Monitoring(format!("{name} exceeds SQLite INTEGER range")))
    };
    let memory_total = checked("memory_total", metrics.memory.total)?;
    let memory_used = checked("memory_used", metrics.memory.used)?;
    let memory_free = checked("memory_free", metrics.memory.free)?;
    let swap_total = checked("swap_total", metrics.swap.total)?;
    let swap_used = checked("swap_used", metrics.swap.used)?;
    let disk_total = checked("disk_total", metrics.disk.total)?;
    let disk_used = checked("disk_used", metrics.disk.used)?;
    let disk_free = checked("disk_free", metrics.disk.free)?;
    let network_rx_bytes = checked("network_rx_bytes", metrics.network.rx_bytes)?;
    let network_tx_bytes = checked("network_tx_bytes", metrics.network.tx_bytes)?;
    // Summed across all devices — same "one aggregate trend line" shape as
    // network_rx_bytes/network_tx_bytes, not per-device (diskio's per-device
    // detail is snapshot-only, matching disk_details/ifaces)
    let diskio_bytes = |read: bool| {
        metrics.diskio.iter().try_fold(0i64, |sum, disk| {
            let sectors = if read {
                disk.sectors_read
            } else {
                disk.sectors_write
            }
            .max(0);
            let bytes = sectors
                .checked_mul(512)
                .ok_or_else(|| MonitorError::Monitoring("disk I/O counter overflow".to_string()))?;
            sum.checked_add(bytes)
                .ok_or_else(|| MonitorError::Monitoring("disk I/O aggregate overflow".to_string()))
        })
    };
    let diskio_read_bytes = diskio_bytes(true)?;
    let diskio_write_bytes = diskio_bytes(false)?;
    // First battery only — matches the home page card's existing convention
    let battery_percent: Option<f64> = metrics
        .batteries
        .first()
        .and_then(|b| b.percent)
        .map(|p| p as f64);

    sqlx::query!(
        r#"
        INSERT INTO system_metrics (
            timestamp, server_name, cpu_usage, memory_total, memory_used, memory_free,
            swap_total, swap_used, disk_total, disk_used, disk_free,
            network_rx_bytes, network_tx_bytes, temperature,
            diskio_read_bytes, diskio_write_bytes, battery_percent
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        metrics.temperature,
        diskio_read_bytes,
        diskio_write_bytes,
        battery_percent
    )
    .execute(db)
    .await?;

    Ok(())
}

#[cfg(test)]
#[path = "service_tests.rs"]
mod tests;
