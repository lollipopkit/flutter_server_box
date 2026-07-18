use crate::{core::config::Config, api::server::AppState, utils::error::Result, monitoring::timeseries::CpuCoreTime};
use chrono::{DateTime, Utc};
use sbm_parser::types::{CpuCore, Disk};
use sbm_parser::{commands, ServerStatus, SystemType};
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

    loop {
        match collect_metrics(&app_state.config).await {
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

async fn collect_metrics(config: &Config) -> Result<SystemMetrics> {
    let system = system_type();
    let raw = execute_commands(system).await?;
    let status = sbm_parser::parse_status(system, &raw);
    Ok(adapt_status(system, status, config))
}

/// 执行 sbm_parser 命令清单(单一事实来源,见 ADR 0001),按 key 收集输出。
/// 仅执行 core 命令:GPU/SMART 等高开销命令不适合周期采集
async fn execute_commands(system: SystemType) -> Result<HashMap<String, String>> {
    let mut raw = HashMap::new();

    for spec in commands::commands(system).iter().filter(|s| s.core) {
        let result = tokio::task::spawn_blocking(move || {
            if cfg!(target_os = "windows") {
                Command::new("powershell").arg("-Command").arg(spec.cmd).output()
            } else {
                Command::new("sh").arg("-c").arg(spec.cmd).output()
            }
        })
        .await
        .map_err(|e| crate::utils::error::MonitorError::Monitoring(format!("Task join error: {}", e)))?;

        match result {
            Ok(output) if output.status.success() => {
                raw.insert(
                    spec.key.to_string(),
                    String::from_utf8_lossy(&output.stdout).into_owned(),
                );
            }
            Ok(output) => {
                // 单条命令失败不影响其余采集(与 App 逐段容错一致)
                error!(
                    "Command '{}' failed: {}",
                    spec.key,
                    String::from_utf8_lossy(&output.stderr)
                );
            }
            Err(e) => error!("Command '{}' error: {}", spec.key, e),
        }
    }

    Ok(raw)
}

/// 将解析结果适配为 monitor 的聚合指标
fn adapt_status(system: SystemType, status: ServerStatus, config: &Config) -> SystemMetrics {
    let (cpu_usage, cpu_cores) = adapt_cpu(&status.cpu);
    let (memory, swap) = adapt_memory(&status);
    let disk = aggregate_disks(&status.disks);
    let network = aggregate_net(&status);

    // 温度取 CPU 器件优先(Dart `Temperatures.first`)
    let temperature = match system {
        SystemType::Bsd => None, // top 输出无温度
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

/// CPU:汇总行(id == "cpu",BSD 无汇总则取首核)计算使用率;
/// 逐核转为 CpuCoreTime(used = total - idle)。
/// 注意:单次采样的累计 ticks 反映开机以来均值;差分改造见 ADR Phase 1b
fn adapt_cpu(cores: &[CpuCore]) -> (f32, Vec<CpuCoreTime>) {
    let summary = cores.iter().find(|c| c.id == "cpu").or_else(|| cores.first());
    let usage = summary
        .map(|c| {
            let total = c.total();
            if total == 0 { 0.0 } else { ((total - c.idle) as f32 / total as f32) * 100.0 }
        })
        .unwrap_or(0.0);

    let core_times = cores
        .iter()
        .filter(|c| c.id != "cpu")
        .map(|c| CpuCoreTime { used: c.total() - c.idle, total: c.total() })
        .collect();

    (usage, core_times)
}

/// 内存/交换:KiB → 字节;used 按 Dart `Memory.usedPercent` 语义
/// (avail 为 0 时回退 free)
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

/// Go 兼容 /status 语义的磁盘聚合:仅 /dev 前缀文件系统,按路径去重,
/// 递归展开 lsblk 层级;KiB → 字节
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

/// 磁盘段解析 + Go 兼容聚合(供 /status 与测试使用)
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
