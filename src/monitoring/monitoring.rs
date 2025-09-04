use crate::{core::config::Config, api::server::AppState, utils::error::Result, monitoring::timeseries::CpuCoreTime};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::SqlitePool;
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

async fn collect_metrics(config: &Config) -> Result<SystemMetrics> {
    let output = execute_monitoring_commands().await?;
    parse_shell_output(&output, config).await
}

async fn execute_monitoring_commands() -> Result<String> {
    let commands = get_system_commands();
    let mut output = String::new();
    
    for cmd_info in commands {
        output.push_str("SrvBox\n");
        
        let result = tokio::task::spawn_blocking(move || {
            if cfg!(target_os = "windows") {
                Command::new("powershell")
                    .arg("-Command")
                    .arg(&cmd_info.cmd)
                    .output()
            } else {
                Command::new("sh")
                    .arg("-c")
                    .arg(&cmd_info.cmd)
                    .output()
            }
        }).await
        .map_err(|e| crate::utils::error::MonitorError::Monitoring(format!("Task join error: {}", e)))?
        .map_err(crate::utils::error::MonitorError::Io)?;

        if result.status.success() {
            output.push_str(&String::from_utf8_lossy(&result.stdout));
        } else {
            // Log the error but continue with other commands
            error!("Command failed: {} - {}", cmd_info.name, String::from_utf8_lossy(&result.stderr));
            output.push_str(&format!("Error executing {}\n", cmd_info.name));
        }
    }
    
    Ok(output)
}

#[derive(Debug)]
struct CommandInfo {
    name: String,
    cmd: String,
}

fn get_system_commands() -> Vec<CommandInfo> {
    if cfg!(target_os = "macos") {
        vec![
            CommandInfo { name: "network".to_string(), cmd: "netstat -ibn".to_string() },
            CommandInfo { name: "cpu".to_string(), cmd: "top -l 1 | grep 'CPU usage'".to_string() },
            CommandInfo { name: "disk".to_string(), cmd: "df -k".to_string() },
            CommandInfo { name: "memory".to_string(), cmd: "top -l 1 | grep PhysMem && vm_stat".to_string() },
            CommandInfo { name: "temp_types".to_string(), cmd: "echo 'macOS'".to_string() },
            CommandInfo { name: "temp_values".to_string(), cmd: "sudo powermetrics -n 1 -s smc | grep -i temp | head -5 || echo 'No temperature data'".to_string() },
        ]
    } else if cfg!(target_os = "windows") {
        vec![
            CommandInfo { name: "network".to_string(), cmd: r#"Get-Counter -Counter "\\Network Interface(*)\\Bytes Received/sec", "\\Network Interface(*)\\Bytes Sent/sec" -MaxSamples 1 | ConvertTo-Json"#.to_string() },
            CommandInfo { name: "cpu".to_string(), cmd: "Get-WmiObject -Class Win32_Processor | Select-Object LoadPercentage | ConvertTo-Json".to_string() },
            CommandInfo { name: "disk".to_string(), cmd: "Get-WmiObject -Class Win32_LogicalDisk | Select-Object DeviceID, Size, FreeSpace | ConvertTo-Json".to_string() },
            CommandInfo { name: "memory".to_string(), cmd: "Get-WmiObject -Class Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory | ConvertTo-Json".to_string() },
            CommandInfo { name: "temp_types".to_string(), cmd: "echo 'Windows'".to_string() },
            CommandInfo { name: "temp_values".to_string(), cmd: r#"Get-CimInstance -ClassName MSAcpi_ThermalZoneTemperature -Namespace root/wmi -ErrorAction SilentlyContinue | Select-Object @{Name='Temperature';Expression={[math]::Round(($_.CurrentTemperature - 2732) / 10, 1)}} | ConvertTo-Json"#.to_string() },
        ]
    } else {
        // Linux/Unix - original commands
        vec![
            CommandInfo { name: "network".to_string(), cmd: "cat /proc/net/dev".to_string() },
            CommandInfo { name: "cpu".to_string(), cmd: "cat /proc/stat | grep cpu".to_string() },
            CommandInfo { name: "disk".to_string(), cmd: "df -h".to_string() },
            CommandInfo { name: "memory".to_string(), cmd: "cat /proc/meminfo".to_string() },
            CommandInfo { name: "temp_types".to_string(), cmd: "cat /sys/class/thermal/thermal_zone*/type".to_string() },
            CommandInfo { name: "temp_values".to_string(), cmd: "cat /sys/class/thermal/thermal_zone*/temp".to_string() },
        ]
    }
}

async fn parse_shell_output(output: &str, _config: &Config) -> Result<SystemMetrics> {
    let segments: Vec<&str> = output.split("SrvBox").collect();
    
    if segments.len() != 7 {
        return Err(crate::utils::error::MonitorError::Monitoring(format!(
            "Expected 7 segments in shell output, got {}", segments.len()
        )));
    }

    let (network, cpu_usage, cpu_cores, disk, memory, swap, temperature) = if cfg!(target_os = "macos") {
        parse_macos_output(&segments)?
    } else if cfg!(target_os = "windows") {
        parse_windows_output(&segments)?
    } else {
        parse_linux_output(&segments)?
    };

    Ok(SystemMetrics {
        timestamp: Utc::now(),
        server_name: "server".to_string(), // TODO: get from config
        cpu_usage,
        cpu_cores,
        memory,
        swap,
        disk,
        network,
        temperature,
    })
}

fn parse_linux_output(segments: &[&str]) -> Result<(NetworkMetrics, f32, Vec<CpuCoreTime>, DiskMetrics, MemoryMetrics, SwapMetrics, Option<f32>)> {
    let network = parse_network_metrics(segments[1])?;
    let (cpu_usage, cpu_cores) = parse_cpu_metrics(segments[2])?;
    let disk = parse_disk_metrics(segments[3])?;
    let (memory, swap) = parse_memory_metrics(segments[4])?;
    let temperature = parse_temperature_metrics(segments[5], segments[6])?;
    
    Ok((network, cpu_usage, cpu_cores, disk, memory, swap, temperature))
}

fn parse_macos_output(segments: &[&str]) -> Result<(NetworkMetrics, f32, Vec<CpuCoreTime>, DiskMetrics, MemoryMetrics, SwapMetrics, Option<f32>)> {
    let network = parse_macos_network_metrics(segments[1])?;
    let (cpu_usage, cpu_cores) = parse_macos_cpu_metrics(segments[2])?;
    let disk = parse_macos_disk_metrics(segments[3])?;
    let (memory, swap) = parse_macos_memory_metrics(segments[4])?;
    let temperature = None; // macOS temperature parsing can be added later
    
    Ok((network, cpu_usage, cpu_cores, disk, memory, swap, temperature))
}

fn parse_windows_output(_segments: &[&str]) -> Result<(NetworkMetrics, f32, Vec<CpuCoreTime>, DiskMetrics, MemoryMetrics, SwapMetrics, Option<f32>)> {
    // Windows parsing would go here - simplified for now
    let network = NetworkMetrics { rx_bytes: 0, tx_bytes: 0 };
    let cpu_usage = 0.0;
    let cpu_cores = Vec::new();
    let disk = DiskMetrics { total: 0, used: 0, free: 0, usage_percent: 0.0 };
    let memory = MemoryMetrics { total: 0, used: 0, free: 0, usage_percent: 0.0 };
    let swap = SwapMetrics { total: 0, used: 0, usage_percent: 0.0 };
    let temperature = None;
    
    Ok((network, cpu_usage, cpu_cores, disk, memory, swap, temperature))
}

fn parse_network_metrics(segment: &str) -> Result<NetworkMetrics> {
    let lines: Vec<&str> = segment.trim().lines().collect();
    if lines.len() < 3 {
        return Ok(NetworkMetrics { rx_bytes: 0, tx_bytes: 0 });
    }

    let mut total_rx = 0u64;
    let mut total_tx = 0u64;

    for line in lines.iter().skip(2) { // Skip header lines
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() >= 17
            && let (Ok(rx), Ok(tx)) = (fields[1].parse::<u64>(), fields[9].parse::<u64>()) {
                total_rx += rx;
                total_tx += tx;
            }
    }

    Ok(NetworkMetrics {
        rx_bytes: total_rx,
        tx_bytes: total_tx,
    })
}

fn parse_cpu_metrics(segment: &str) -> Result<(f32, Vec<CpuCoreTime>)> {
    let lines: Vec<&str> = segment.trim().lines().collect();
    let mut total_usage = 0.0;
    let mut cpu_count = 0;
    let mut core_times = Vec::new();

    for line in lines {
        if line.starts_with("cpu") && !line.starts_with("cpu ") {
            let fields: Vec<&str> = line.split_whitespace().collect();
            if fields.len() >= 8 {
                let mut total = 0u64;
                let mut idle = 0u64;
                
                for (i, field) in fields.iter().enumerate().take(8).skip(1) {
                    if let Ok(val) = field.parse::<u64>() {
                        total += val;
                        if i == 4 { // idle time is at index 4
                            idle = val;
                        }
                    }
                }
                
                if total > 0 {
                    let used = total - idle;
                    let core_time = CpuCoreTime { used, total };
                    core_times.push(core_time);
                    
                    let usage = (used as f32 / total as f32) * 100.0;
                    total_usage += usage;
                    cpu_count += 1;
                }
            }
        }
    }

    let avg_usage = if cpu_count > 0 { total_usage / cpu_count as f32 } else { 0.0 };
    Ok((avg_usage, core_times))
}

fn parse_disk_metrics(segment: &str) -> Result<DiskMetrics> {
    let lines: Vec<&str> = segment.trim().lines().collect();
    if lines.len() < 2 {
        return Ok(DiskMetrics { total: 0, used: 0, free: 0, usage_percent: 0.0 });
    }

    let mut total_size = 0u64;
    let mut total_used = 0u64;
    let mut total_avail = 0u64;

    for line in lines.iter().skip(1) { // Skip header line
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() >= 6
            && let (Ok(size), Ok(used), Ok(avail)) = (
                parse_size_string(fields[1]),
                parse_size_string(fields[2]),
                parse_size_string(fields[3])
            ) {
                total_size += size;
                total_used += used;
                total_avail += avail;
            }
    }

    let usage_percent = if total_size > 0 {
        (total_used as f32 / total_size as f32) * 100.0
    } else {
        0.0
    };

    Ok(DiskMetrics {
        total: total_size,
        used: total_used,
        free: total_avail,
        usage_percent,
    })
}

fn parse_memory_metrics(segment: &str) -> Result<(MemoryMetrics, SwapMetrics)> {
    let lines: Vec<&str> = segment.trim().lines().collect();
    
    let mut mem_total = 0u64;
    let mut mem_available = 0u64;
    let mut swap_total = 0u64;
    let mut swap_free = 0u64;

    for line in lines {
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() >= 2
            && let Ok(value) = fields[1].parse::<u64>() {
                let value_bytes = value * 1024; // Convert KB to bytes
                
                match fields[0] {
                    "MemTotal:" => mem_total = value_bytes,
                    "MemAvailable:" => mem_available = value_bytes,
                    "SwapTotal:" => swap_total = value_bytes,
                    "SwapFree:" => swap_free = value_bytes,
                    _ => {}
                }
            }
    }

    let mem_used = mem_total - mem_available;
    let mem_usage_percent = if mem_total > 0 {
        (mem_used as f32 / mem_total as f32) * 100.0
    } else {
        0.0
    };

    let swap_used = swap_total - swap_free;
    let swap_usage_percent = if swap_total > 0 {
        (swap_used as f32 / swap_total as f32) * 100.0
    } else {
        0.0
    };

    let memory = MemoryMetrics {
        total: mem_total,
        used: mem_used,
        free: mem_available,
        usage_percent: mem_usage_percent,
    };

    let swap = SwapMetrics {
        total: swap_total,
        used: swap_used,
        usage_percent: swap_usage_percent,
    };

    Ok((memory, swap))
}

fn parse_temperature_metrics(types_segment: &str, values_segment: &str) -> Result<Option<f32>> {
    let types_lines: Vec<&str> = types_segment.trim().lines().collect();
    let values_lines: Vec<&str> = values_segment.trim().lines().collect();

    if types_lines.is_empty() || values_lines.is_empty() || 
       types_lines.len() != values_lines.len() ||
       types_lines[0].contains("/sys/class/thermal/thermal_zone*/type") {
        return Ok(None);
    }

    let mut temp_sum = 0.0;
    let mut temp_count = 0;

    for value_line in values_lines {
        if let Ok(temp_millicelsius) = value_line.trim().parse::<f32>() {
            temp_sum += temp_millicelsius / 1000.0; // Convert millicelsius to celsius
            temp_count += 1;
        }
    }

    Ok(if temp_count > 0 {
        Some(temp_sum / temp_count as f32)
    } else {
        None
    })
}

fn parse_size_string(size_str: &str) -> Result<u64> {
    let size_str = size_str.trim();
    let (number_part, unit) = if let Some(pos) = size_str.find(|c: char| c.is_alphabetic()) {
        size_str.split_at(pos)
    } else {
        (size_str, "")
    };

    let number: f64 = number_part.parse()
        .map_err(|_| crate::utils::error::MonitorError::Monitoring(format!("Invalid size number: {}", number_part)))?;

    let multiplier = match unit.to_uppercase().as_str() {
        "K" | "KB" => 1024,
        "M" | "MB" => 1024 * 1024,
        "G" | "GB" => 1024 * 1024 * 1024,
        "T" | "TB" => 1024_u64.pow(4),
        "" => 1, // No unit, assume bytes
        _ => return Err(crate::utils::error::MonitorError::Monitoring(format!("Unknown size unit: {}", unit))),
    };

    Ok((number * multiplier as f64) as u64)
}

// macOS-specific parsing functions
fn parse_macos_network_metrics(segment: &str) -> Result<NetworkMetrics> {
    let lines: Vec<&str> = segment.trim().lines().collect();
    let mut total_rx = 0u64;
    let mut total_tx = 0u64;

    for line in lines {
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() >= 7 && !line.contains("Name") && !line.contains("lo0") {
            // Skip header and loopback interface
            if let (Ok(rx), Ok(tx)) = (fields[6].parse::<u64>(), fields[9].parse::<u64>()) {
                total_rx += rx;
                total_tx += tx;
            }
        }
    }

    Ok(NetworkMetrics {
        rx_bytes: total_rx,
        tx_bytes: total_tx,
    })
}

fn parse_macos_cpu_metrics(segment: &str) -> Result<(f32, Vec<CpuCoreTime>)> {
    let line = segment.trim();
    // Parse "CPU usage: 4.28% user, 2.85% sys, 92.85% idle"
    if let Some(user_start) = line.find("usage: ")
        && let Some(user_end) = line[user_start..].find("% user") {
            let user_str = &line[user_start + 7..user_start + user_end];
            if let Ok(user_percent) = user_str.parse::<f32>()
                && let Some(sys_start) = line.find("% user, ")
                    && let Some(sys_end) = line[sys_start..].find("% sys") {
                        let sys_str = &line[sys_start + 8..sys_start + sys_end];
                        if let Ok(sys_percent) = sys_str.parse::<f32>() {
                            let total_usage = user_percent + sys_percent;
                            // For macOS, we create a single virtual core since top doesn't provide per-core data
                            let core_time = CpuCoreTime {
                                used: (total_usage * 100.0) as u64,
                                total: 10000,
                            };
                            return Ok((total_usage, vec![core_time]));
                        }
                    }
        }
    Ok((0.0, Vec::new()))
}

fn parse_macos_disk_metrics(segment: &str) -> Result<DiskMetrics> {
    let lines: Vec<&str> = segment.trim().lines().collect();
    if lines.len() < 2 {
        return Ok(DiskMetrics { total: 0, used: 0, free: 0, usage_percent: 0.0 });
    }

    let mut total_size = 0u64;
    let mut total_used = 0u64;
    let mut total_avail = 0u64;

    for line in lines.iter().skip(1) {
        let fields: Vec<&str> = line.split_whitespace().collect();
        if fields.len() >= 4 && !fields[0].contains("devfs") && !fields[0].contains("map")
            && let (Ok(size), Ok(used), Ok(avail)) = (
                fields[1].parse::<u64>(),
                fields[2].parse::<u64>(),
                fields[3].parse::<u64>()
            ) {
                // df -k outputs in KB, convert to bytes
                total_size += size * 1024;
                total_used += used * 1024;
                total_avail += avail * 1024;
            }
    }

    let usage_percent = if total_size > 0 {
        (total_used as f32 / total_size as f32) * 100.0
    } else {
        0.0
    };

    Ok(DiskMetrics {
        total: total_size,
        used: total_used,
        free: total_avail,
        usage_percent,
    })
}

fn parse_macos_memory_metrics(segment: &str) -> Result<(MemoryMetrics, SwapMetrics)> {
    let lines: Vec<&str> = segment.trim().lines().collect();
    
    let mut mem_total = 0u64;
    let mut mem_used = 0u64;
    let swap_total = 0u64;
    let swap_used = 0u64;

    // Parse PhysMem line: "PhysMem: 15G used (2821M wired), 1023M unused."
    for line in lines {
        if line.contains("PhysMem:") {
            // Extract memory info from PhysMem line
            if let Some(used_start) = line.find("PhysMem: ") {
                let mem_part = &line[used_start + 9..];
                if let Some(used_end) = mem_part.find(" used") {
                    let used_str = &mem_part[..used_end];
                    if let Ok(used) = parse_size_string_macos(used_str) {
                        mem_used = used;
                    }
                }
                if let Some(unused_start) = mem_part.find(", ")
                    && let Some(unused_end) = mem_part[unused_start..].find(" unused") {
                        let unused_str = &mem_part[unused_start + 2..unused_start + unused_end];
                        if let Ok(unused) = parse_size_string_macos(unused_str) {
                            mem_total = mem_used + unused;
                        }
                    }
            }
        } else if line.contains("Swapouts:") {
            // This is vm_stat output, we can extract swap info if needed
            // For now, set swap to 0 as vm_stat format is complex
        }
    }

    let mem_usage_percent = if mem_total > 0 {
        (mem_used as f32 / mem_total as f32) * 100.0
    } else {
        0.0
    };

    let swap_usage_percent = if swap_total > 0 {
        (swap_used as f32 / swap_total as f32) * 100.0
    } else {
        0.0
    };

    let mem_free = if mem_total >= mem_used {
        mem_total - mem_used
    } else {
        0
    };

    let memory = MemoryMetrics {
        total: mem_total,
        used: mem_used,
        free: mem_free,
        usage_percent: mem_usage_percent,
    };

    let swap = SwapMetrics {
        total: swap_total,
        used: swap_used,
        usage_percent: swap_usage_percent,
    };

    Ok((memory, swap))
}

fn parse_size_string_macos(size_str: &str) -> Result<u64> {
    let size_str = size_str.trim();
    let (number_part, unit) = if let Some(pos) = size_str.rfind(|c: char| c.is_alphabetic()) {
        (&size_str[..pos], &size_str[pos..])
    } else {
        (size_str, "")
    };

    let number: f64 = number_part.parse()
        .map_err(|_| crate::utils::error::MonitorError::Monitoring(format!("Invalid size number: {}", number_part)))?;

    let multiplier = match unit.to_uppercase().as_str() {
        "K" | "KB" => 1024,
        "M" | "MB" => 1024 * 1024,
        "G" | "GB" => 1024 * 1024 * 1024,
        "T" | "TB" => 1024_u64.pow(4),
        "" => 1,
        _ => return Err(crate::utils::error::MonitorError::Monitoring(format!("Unknown size unit: {}", unit))),
    };

    Ok((number * multiplier as f64) as u64)
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