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

pub async fn run_monitoring_loop(app_state: Arc<AppState>) -> Result<()> {
    let interval_seconds = app_state.config.get_monitoring().interval_seconds as f64;
    let interval = Duration::from_secs(app_state.config.get_monitoring().interval_seconds);

    info!("Starting monitoring loop with {}s interval", app_state.config.get_monitoring().interval_seconds);

    // CPU summary sample from the previous cycle: cumulative ticks need a
    // cross-cycle delta to yield current usage
    let mut prev_cpu: Option<CpuCore> = None;

    loop {
        match collect_metrics(&app_state.config, &mut prev_cpu).await {
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

fn system_type() -> SystemType {
    if cfg!(target_os = "windows") {
        SystemType::Windows
    } else if cfg!(target_os = "macos") {
        SystemType::Bsd
    } else {
        SystemType::Linux
    }
}

async fn collect_metrics(config: &Config, prev_cpu: &mut Option<CpuCore>) -> Result<SystemMetrics> {
    let system = system_type();
    let raw = execute_commands(system).await?;
    let status = sbm_parser::parse_status(system, &raw);
    let prev = prev_cpu.take();
    *prev_cpu = summary_core(&status.cpu).cloned();
    Ok(adapt_status(system, status, config, prev.as_ref()))
}

/// Build the core-only status script shared with the app (sbm_parser::script,
/// see ADR 0001). One script execution per cycle replaces the former
/// per-command spawn loop; the app runs the same generation code over SSH.
fn build_status_script(system: SystemType) -> String {
    sbm_parser::script::build_script(
        system,
        &sbm_parser::script::ScriptOptions {
            core_only: true,
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

/// Adapt the parse result into the monitor's aggregate metrics
fn adapt_status(
    system: SystemType,
    status: ServerStatus,
    config: &Config,
    prev_cpu: Option<&CpuCore>,
) -> SystemMetrics {
    let (cpu_usage, cpu_cores) = adapt_cpu(&status.cpu, prev_cpu);
    let (memory, swap) = adapt_memory(&status);
    let disk = aggregate_disks(&status.disks);
    let network = aggregate_net(&status);

    // Temperature prefers CPU devices (Dart `Temperatures.first`)
    let temperature = match system {
        SystemType::Bsd => None, // top output has no temperature
        _ => status.temps.first().map(|t| t as f32),
    };

    SystemMetrics {
        timestamp: Utc::now(),
        server_name: config.get_server_name(),
        cpu_usage,
        cpu_cores,
        memory,
        swap,
        disk,
        network,
        temperature,
    }
}

fn summary_core(cores: &[CpuCore]) -> Option<&CpuCore> {
    cores.iter().find(|c| c.id == "cpu").or_else(|| cores.first())
}

/// CPU: current usage from the delta between the summary row (id == "cpu", or the
/// first core on BSD) and the previous sample (same semantics as Dart
/// `Cpus.usedPercent`); a direct ratio of cumulative ticks is the since-boot
/// average and unusable. The first cycle has no baseline and reports 0; counter
/// wraparound (reboot) also resets the baseline.
/// Per-core entries become CpuCoreTime (used = total - idle)
fn adapt_cpu(cores: &[CpuCore], prev_summary: Option<&CpuCore>) -> (f32, Vec<CpuCoreTime>) {
    let usage = match (prev_summary, summary_core(cores)) {
        (Some(pre), Some(now)) if now.total() > pre.total() => {
            sbm_parser::types::cpu_used_percent(pre, now) as f32
        }
        _ => 0.0,
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

/// Disk aggregation with Go-compatible /status semantics: only /dev-prefixed
/// filesystems, deduped by path, lsblk hierarchy expanded recursively; KiB → bytes
fn aggregate_disks(disks: &[Disk]) -> DiskMetrics {
    fn walk<'a>(disks: &'a [Disk], seen: &mut Vec<&'a str>, acc: &mut (u64, u64, u64)) {
        for d in disks {
            if d.path.starts_with("/dev") && d.size > 0 && !seen.contains(&d.path.as_str()) {
                seen.push(&d.path);
                acc.0 += d.size;
                acc.1 += d.used;
                acc.2 += d.avail;
            }
            walk(&d.children, seen, acc);
        }
    }

    let mut acc = (0u64, 0u64, 0u64);
    walk(disks, &mut Vec::new(), &mut acc);
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

/// Disk segment parsing + Go-compatible aggregation (for /status and tests)
pub fn parse_disk_metrics(segment: &str) -> Result<DiskMetrics> {
    Ok(aggregate_disks(&sbm_parser::linux::parse_disk(segment)))
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

    /// The monitor's real collection path: run the generated script, split output
    #[cfg(unix)]
    #[tokio::test]
    async fn execute_commands_via_script_smoke() {
        let raw = execute_commands(system_type()).await.unwrap();
        assert!(raw.contains_key("time"), "keys: {:?}", raw.keys().collect::<Vec<_>>());
        assert!(raw.contains_key("echo"));
    }
}
