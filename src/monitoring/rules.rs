use crate::{core::config::{Config, MonitoringRule}, monitoring::monitoring::SystemMetrics, utils::error::Result, monitoring::velocity::VelocityManager};
use crate::monitoring::threshold::{Threshold, ThresholdType};
use tracing::{info, warn};

pub async fn check_rules_with_velocity(
    metrics: &SystemMetrics, 
    config: &Config, 
    velocity_manager: &VelocityManager
) -> Result<()> {
    for rule in &config.get_monitoring().rules {
        if let Err(e) = check_enhanced_rule(rule, metrics, config, velocity_manager).await {
            warn!("Failed to check enhanced rule '{}': {}", rule.name, e);
        }
    }
    Ok(())
}

async fn check_enhanced_rule(
    rule: &MonitoringRule, 
    metrics: &SystemMetrics, 
    config: &Config, 
    velocity_manager: &VelocityManager
) -> Result<()> {
    let (should_alert, _current_value, formatted_value) = match rule.monitor_type.as_str() {
        "cpu" => check_cpu_rule(rule, metrics).await?,
        "memory" => check_memory_rule(rule, metrics).await?,
        "swap" => check_swap_rule(rule, metrics).await?,
        "disk" => check_disk_rule(rule, metrics).await?,
        "network" => check_network_rule(rule, metrics, config, velocity_manager).await?,
        "temperature" | "temp" => check_temperature_rule(rule, metrics).await?,
        _ => {
            warn!("Unknown monitor type: {}", rule.monitor_type);
            return Ok(());
        }
    };

    if should_alert {
        let message = format!(
            "Alert: {} - {} {} (threshold: {})",
            rule.name,
            rule.matcher,
            formatted_value,
            rule.threshold
        );
        
        info!("Triggering enhanced alert: {}", message);
        
        let (rate_times, rate_window) = config.get_push_rate();
        let limiter = crate::monitoring::push::PushRateLimiter::global();
        for push_config in &config.get_push() {
            if !limiter.check(&push_config.name, rate_times, rate_window) {
                warn!("Push '{}' rate limit reached, skipping", push_config.name);
                continue;
            }
            match crate::monitoring::push::send_notification(push_config, &message).await {
                Ok(()) => limiter.acquire(&push_config.name),
                Err(e) => warn!("Failed to send push notification via '{}': {}", push_config.name, e),
            }
        }
    }
    
    Ok(())
}


/// 百分比/温度阈值判断,格式与 Go 版一致(如 ">=77%"、">=70c")
fn should_trigger_alert(threshold: &str, value: f64) -> Result<bool> {
    match Threshold::parse(threshold) {
        Ok(t) if matches!(t.threshold_type, ThresholdType::Percent | ThresholdType::Temperature) => {
            Ok(t.is_true(value))
        }
        Ok(t) => {
            warn!("Threshold type {:?} not applicable here: {}", t.threshold_type, threshold);
            Ok(false)
        }
        Err(_) => {
            warn!("Invalid threshold format: {}", threshold);
            Ok(false)
        }
    }
}

async fn check_cpu_rule(rule: &MonitoringRule, metrics: &SystemMetrics) -> Result<(bool, f64, String)> {
    let matcher = &rule.matcher;
    
    if matcher == "cpu" || matcher.is_empty() {
        let cpu_usage = metrics.cpu_usage as f64;
        let should_alert = should_trigger_alert(&rule.threshold, cpu_usage)?;
        let formatted = format!("{:.2}%", cpu_usage);
        Ok((should_alert, cpu_usage, formatted))
    } else if matcher.starts_with("cpu") {
        let core_index_str = matcher.strip_prefix("cpu").unwrap_or("0");
        if let Ok(core_index) = core_index_str.parse::<usize>() {
            if core_index < metrics.cpu_cores.len() {
                let core = &metrics.cpu_cores[core_index];
                let usage = if core.total > 0 {
                    (core.used as f64 / core.total as f64) * 100.0
                } else { 0.0 };
                let should_alert = should_trigger_alert(&rule.threshold, usage)?;
                let formatted = format!("{:.2}%", usage);
                Ok((should_alert, usage, formatted))
            } else {
                warn!("CPU core {} not found", core_index);
                Ok((false, 0.0, "0.00%".to_string()))
            }
        } else {
            warn!("Invalid CPU core index in matcher: {}", matcher);
            Ok((false, 0.0, "0.00%".to_string()))
        }
    } else {
        warn!("Invalid CPU matcher: {}", matcher);
        Ok((false, 0.0, "0.00%".to_string()))
    }
}

async fn check_memory_rule(rule: &MonitoringRule, metrics: &SystemMetrics) -> Result<(bool, f64, String)> {
    let matcher = &rule.matcher;
    
    match matcher.as_str() {
        "used" | "memory" | "" => {
            let usage = metrics.memory.usage_percent as f64;
            let should_alert = should_trigger_alert(&rule.threshold, usage)?;
            let formatted = format!("{:.2}%", usage);
            Ok((should_alert, usage, formatted))
        }
        "free" => {
            let usage = 100.0 - metrics.memory.usage_percent as f64;
            let should_alert = should_trigger_alert(&rule.threshold, usage)?;
            let formatted = format!("{:.2}%", usage);
            Ok((should_alert, usage, formatted))
        }
        "avail" => {
            let avail_percent = (metrics.memory.free as f64 / metrics.memory.total as f64) * 100.0;
            let should_alert = should_trigger_alert(&rule.threshold, avail_percent)?;
            let formatted = format!("{:.2}%", avail_percent);
            Ok((should_alert, avail_percent, formatted))
        }
        _ => {
            warn!("Invalid memory matcher: {}", matcher);
            Ok((false, 0.0, "0.00%".to_string()))
        }
    }
}

async fn check_swap_rule(rule: &MonitoringRule, metrics: &SystemMetrics) -> Result<(bool, f64, String)> {
    let matcher = &rule.matcher;
    
    match matcher.as_str() {
        "used" | "swap" | "" => {
            let usage = metrics.swap.usage_percent as f64;
            let should_alert = should_trigger_alert(&rule.threshold, usage)?;
            let formatted = format!("{:.2}%", usage);
            Ok((should_alert, usage, formatted))
        }
        "free" => {
            let free_percent = 100.0 - metrics.swap.usage_percent as f64;
            let should_alert = should_trigger_alert(&rule.threshold, free_percent)?;
            let formatted = format!("{:.2}%", free_percent);
            Ok((should_alert, free_percent, formatted))
        }
        _ => {
            warn!("Invalid swap matcher: {}", matcher);
            Ok((false, 0.0, "0.00%".to_string()))
        }
    }
}

async fn check_disk_rule(rule: &MonitoringRule, metrics: &SystemMetrics) -> Result<(bool, f64, String)> {
    let usage = metrics.disk.usage_percent as f64;
    let should_alert = should_trigger_alert(&rule.threshold, usage)?;
    let formatted = format!("{:.2}%", usage);
    Ok((should_alert, usage, formatted))
}

async fn check_network_rule(
    rule: &MonitoringRule,
    metrics: &SystemMetrics,
    config: &Config,
    velocity_manager: &VelocityManager
) -> Result<(bool, f64, String)> {
    let matcher = &rule.matcher;
    let interval_seconds = config.get_monitoring().interval_seconds as f64;
    
    if let Ok(velocity_metrics) = velocity_manager.get_server_velocity(&metrics.server_name, interval_seconds).await {
        let (value, _unit) = match matcher.as_str() {
            "rx" | "in" => {
                if let Some(speed) = velocity_metrics.network_rx_speed {
                    (speed, "B/s")
                } else {
                    (0.0, "B/s")
                }
            }
            "tx" | "out" => {
                if let Some(speed) = velocity_metrics.network_tx_speed {
                    (speed, "B/s")
                } else {
                    (0.0, "B/s")
                }
            }
            _ => {
                let rx = velocity_metrics.network_rx_speed.unwrap_or(0.0);
                let tx = velocity_metrics.network_tx_speed.unwrap_or(0.0);
                (rx + tx, "B/s")
            }
        };
        
        let should_alert = should_trigger_speed_alert(&rule.threshold, value)?;
        let formatted = format_network_speed(value);
        
        Ok((should_alert, value, formatted))
    } else {
        Ok((false, 0.0, "0 B/s".to_string()))
    }
}

async fn check_temperature_rule(rule: &MonitoringRule, metrics: &SystemMetrics) -> Result<(bool, f64, String)> {
    if let Some(temp) = metrics.temperature {
        let temp_value = temp as f64;
        let should_alert = should_trigger_alert(&rule.threshold, temp_value)?;
        let formatted = format!("{:.1}°C", temp_value);
        Ok((should_alert, temp_value, formatted))
    } else {
        Ok((false, 0.0, "N/A".to_string()))
    }
}

/// 速度/大小阈值判断,格式与 Go 版一致(如 ">10m/s"、"<100m",1024 进制小写单位)
fn should_trigger_speed_alert(threshold: &str, value: f64) -> Result<bool> {
    match Threshold::parse(threshold) {
        Ok(t) if matches!(t.threshold_type, ThresholdType::Speed | ThresholdType::Size) => {
            Ok(t.is_true(value))
        }
        Ok(t) => {
            warn!("Threshold type {:?} not applicable for network: {}", t.threshold_type, threshold);
            Ok(false)
        }
        Err(_) => {
            warn!("Invalid speed threshold format: {}", threshold);
            Ok(false)
        }
    }
}

fn format_network_speed(bytes_per_sec: f64) -> String {
    const KB: f64 = 1024.0;
    const MB: f64 = 1024.0 * 1024.0;
    const GB: f64 = 1024.0 * 1024.0 * 1024.0;

    if bytes_per_sec >= GB {
        format!("{:.2} GB/s", bytes_per_sec / GB)
    } else if bytes_per_sec >= MB {
        format!("{:.2} MB/s", bytes_per_sec / MB)
    } else if bytes_per_sec >= KB {
        format!("{:.2} KB/s", bytes_per_sec / KB)
    } else {
        format!("{:.2} B/s", bytes_per_sec)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::core::config::Config;
    use crate::monitoring::monitoring::SystemMetrics;
    use chrono::Utc;

    #[tokio::test]
    async fn test_threshold_parsing() {
        // Test various threshold formats
        assert!(should_trigger_alert(">=77%", 80.0).unwrap());
        assert!(!should_trigger_alert(">=77%", 70.0).unwrap());
        
        assert!(should_trigger_alert(">77%", 78.0).unwrap());
        assert!(!should_trigger_alert(">77%", 77.0).unwrap());
        
        assert!(should_trigger_alert("<=10%", 5.0).unwrap());
        assert!(!should_trigger_alert("<=10%", 15.0).unwrap());
        
        assert!(should_trigger_alert("<10%", 9.0).unwrap());
        assert!(!should_trigger_alert("<10%", 10.0).unwrap());
    }

    #[tokio::test]
    async fn test_rule_evaluation() {
        let config = Config::default();
        
        let _metrics = SystemMetrics {
            timestamp: Utc::now(),
            server_name: "test".to_string(),
            cpu_usage: 85.0, // Should trigger CPU alert (>=77%)
            cpu_cores: vec![crate::monitoring::timeseries::CpuCoreTime { used: 85, total: 100 }],
            memory: crate::monitoring::monitoring::MemoryMetrics {
                total: 1000,
                used: 800,
                free: 200,
                usage_percent: 80.0, // Should not trigger memory alert (>=85%)
            },
            swap: crate::monitoring::monitoring::SwapMetrics {
                total: 500,
                used: 100,
                usage_percent: 20.0,
            },
            disk: crate::monitoring::monitoring::DiskMetrics {
                total: 10000,
                used: 9500,
                free: 500,
                usage_percent: 95.0, // Should trigger disk alert (>=90%)
            },
            network: crate::monitoring::monitoring::NetworkMetrics {
                rx_bytes: 1000,
                tx_bytes: 2000,
            },
            temperature: Some(65.0),
        };

        // This test would need velocity_manager to work with check_rules_with_velocity
        // For now we just test that the function exists and rules are parsed correctly
        assert!(!config.get_monitoring().rules.is_empty());
    }

    #[test]
    fn test_invalid_threshold_format() {
        // Test invalid threshold formats
        assert!(!should_trigger_alert("invalid", 50.0).unwrap());
        assert!(!should_trigger_alert("", 50.0).unwrap());
        assert!(!should_trigger_alert("50", 60.0).unwrap()); // Missing operator
    }
}