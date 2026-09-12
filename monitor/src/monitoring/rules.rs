use crate::{core::config::{Config, MonitoringRule}, monitoring::SystemMetrics, utils::error::Result, monitoring::velocity::VelocityManager};
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
        "network" => check_network_rule(rule, metrics, velocity_manager).await?,
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
            match crate::monitoring::push::send_notification(config, push_config, &message).await {
                Ok(()) => limiter.acquire(&push_config.name),
                Err(e) => warn!("Failed to send push notification via '{}': {}", push_config.name, e),
            }
        }
    }
    
    Ok(())
}


/// Percentage/temperature threshold check, Go-compatible format (e.g. ">=77%", ">=70c")
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
                // adapt_cpu already resolved this per platform; deriving it from
                // used/total here would be the since-boot average on Linux
                let Some(usage) = metrics.cpu_cores[core_index].usage_percent else {
                    // No baseline yet (first Linux cycle) — no reading to judge
                    return Ok((false, 0.0, "--".to_string()));
                };
                let usage = usage as f64;
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

    // `adapt_memory` reports an absent sample as zeros, so a total of 0 means
    // /proc/meminfo (or its platform equivalent) could not be read — no machine
    // has no memory. Judged as a reading it is 0% used, which silences a "high
    // memory" rule, and `avail` divides by it: NaN compares false against every
    // threshold, so that rule can never fire again.
    if metrics.memory.total == 0 {
        warn!("No memory reading this cycle; skipping rule '{}'", rule.name);
        return Ok((false, 0.0, "--".to_string()));
    }

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
    // Disk usage comes from `df`, which the native sampler abandons on a
    // timeout (an unresponsive network mount) and reports as no filesystems at
    // all. That aggregates to a total of 0 and a usage of 0%, which reads as a
    // measured "empty disk": a `<10%` rule fires on a machine that is fine, and
    // a `>=90%` rule stays quiet on one that is filling up.
    if metrics.disk.total == 0 {
        warn!("No disk reading this cycle; skipping rule '{}'", rule.name);
        return Ok((false, 0.0, "--".to_string()));
    }

    let usage = metrics.disk.usage_percent as f64;
    let should_alert = should_trigger_alert(&rule.threshold, usage)?;
    let formatted = format!("{:.2}%", usage);
    Ok((should_alert, usage, formatted))
}

async fn check_network_rule(
    rule: &MonitoringRule,
    metrics: &SystemMetrics,
    velocity_manager: &VelocityManager
) -> Result<(bool, f64, String)> {
    let matcher = &rule.matcher;
    if let Ok(velocity_metrics) = velocity_manager.get_server_velocity(&metrics.server_name).await {
        // A speed is the difference between two samples, so there is none until
        // the second one lands: after an agent restart, after a gap in
        // collection, and for an interface that has just appeared. `None` is
        // that state and is not 0 B/s — a bare threshold parses as `<`
        // (`Threshold::parse`, Go-compatible), so substituting zero reports the
        // link as down every time the agent starts.
        let Some(value) = (match matcher.as_str() {
            "rx" | "in" => velocity_metrics.network_rx_speed,
            "tx" | "out" => velocity_metrics.network_tx_speed,
            _ => match (velocity_metrics.network_rx_speed, velocity_metrics.network_tx_speed) {
                (Some(rx), Some(tx)) => Some(rx + tx),
                _ => None,
            },
        }) else {
            return Ok((false, 0.0, "--".to_string()));
        };

        let should_alert = should_trigger_speed_alert(&rule.threshold, value)?;
        let formatted = format_network_speed(value);

        Ok((should_alert, value, formatted))
    } else {
        Ok((false, 0.0, "--".to_string()))
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

/// Speed/size threshold check, Go-compatible format (e.g. ">10m/s", "<100m", base-1024 lowercase units)
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
    use crate::monitoring::SystemMetrics;
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
            extended_updated_at: Utc::now(),
            server_name: "test".to_string(),
            cpu_usage: 85.0, // Should trigger CPU alert (>=77%)
            cpu_cores: vec![crate::monitoring::timeseries::CpuCoreTime {
                used: 85,
                total: 100,
                usage_percent: Some(85.0),
            }],
            memory: crate::monitoring::MemoryMetrics {
                total: 1000,
                used: 800,
                free: 200,
                usage_percent: 80.0, // Should not trigger memory alert (>=85%)
            },
            swap: crate::monitoring::SwapMetrics {
                total: 500,
                used: 100,
                usage_percent: 20.0,
            },
            disk: crate::monitoring::DiskMetrics {
                total: 10000,
                used: 9500,
                free: 500,
                usage_percent: 95.0, // Should trigger disk alert (>=90%)
            },
            network: crate::monitoring::NetworkMetrics {
                rx_bytes: 1000,
                tx_bytes: 2000,
            },
            temperature: Some(65.0),
            temps: vec![],
            sys: None,
            os_id: None,
            os_id_like: Vec::new(),
            cpu_brand: None,
            gpus: vec![],
            disk_details: vec![],
            ifaces: vec![],
            uptime: None,
            conn: None,
            diskio: vec![],
            diskio_rate: vec![],
            batteries: vec![],
            sensors: vec![],
            disk_smart: vec![],
        ips: vec![],
            custom_cmds: vec![],
            amd_cache: vec![],
        };

        // This test would need velocity_manager to work with check_rules_with_velocity
        // For now we just test that the function exists and rules are parsed correctly
        assert!(!config.get_monitoring().rules.is_empty());
    }

    fn rule(monitor_type: &str, matcher: &str, threshold: &str) -> MonitoringRule {
        MonitoringRule {
            name: format!("{monitor_type}-{matcher}"),
            monitor_type: monitor_type.to_string(),
            threshold: threshold.to_string(),
            matcher: matcher.to_string(),
        }
    }

    /// Every field zeroed, which is what `adapt_memory`/`aggregate_disks`
    /// produce when the sample behind them is missing.
    fn empty_metrics() -> SystemMetrics {
        SystemMetrics {
            timestamp: Utc::now(),
            extended_updated_at: Utc::now(),
            server_name: "test".to_string(),
            cpu_usage: 0.0,
            cpu_cores: vec![],
            memory: crate::monitoring::MemoryMetrics {
                total: 0,
                used: 0,
                free: 0,
                usage_percent: 0.0,
            },
            swap: crate::monitoring::SwapMetrics {
                total: 0,
                used: 0,
                usage_percent: 0.0,
            },
            disk: crate::monitoring::DiskMetrics {
                total: 0,
                used: 0,
                free: 0,
                usage_percent: 0.0,
            },
            network: crate::monitoring::NetworkMetrics {
                rx_bytes: 0,
                tx_bytes: 0,
            },
            temperature: None,
            temps: vec![],
            sys: None,
            os_id: None,
            os_id_like: Vec::new(),
            cpu_brand: None,
            gpus: vec![],
            disk_details: vec![],
            ifaces: vec![],
            uptime: None,
            conn: None,
            diskio: vec![],
            diskio_rate: vec![],
            batteries: vec![],
            sensors: vec![],
            disk_smart: vec![],
            ips: vec![],
            custom_cmds: vec![],
            amd_cache: vec![],
        }
    }

    /// `/proc/meminfo` unreadable arrives as a total of 0. `avail` divided by
    /// it, so the rule compared NaN — false against every threshold — and the
    /// low-memory alert could never fire again.
    #[tokio::test]
    async fn memory_rule_skips_a_cycle_with_no_reading() {
        let metrics = empty_metrics();

        let (alert, value, formatted) = check_memory_rule(&rule("memory", "avail", "<=10%"), &metrics)
            .await
            .unwrap();
        assert!(!alert);
        assert!(!value.is_nan(), "a missing sample must not produce NaN");
        assert_eq!(formatted, "--");

        // The same total of 0 reads as 0% used, which would silence this one.
        let (alert, _, formatted) = check_memory_rule(&rule("memory", "used", ">=90%"), &metrics)
            .await
            .unwrap();
        assert!(!alert);
        assert_eq!(formatted, "--");
    }

    #[tokio::test]
    async fn memory_rule_fires_on_a_real_reading() {
        let mut metrics = empty_metrics();
        metrics.memory = crate::monitoring::MemoryMetrics {
            total: 1000,
            used: 950,
            free: 50,
            usage_percent: 95.0,
        };

        let (alert, _, _) = check_memory_rule(&rule("memory", "used", ">=90%"), &metrics)
            .await
            .unwrap();
        assert!(alert);

        let (alert, value, _) = check_memory_rule(&rule("memory", "avail", "<=10%"), &metrics)
            .await
            .unwrap();
        assert!(alert);
        assert_eq!(value, 5.0);
    }

    /// A `df` that timed out leaves no filesystems, which aggregates to a total
    /// of 0 and 0% used — indistinguishable from a measured empty disk.
    #[tokio::test]
    async fn disk_rule_skips_a_cycle_with_no_reading() {
        let (alert, _, formatted) = check_disk_rule(&rule("disk", "", "<10%"), &empty_metrics())
            .await
            .unwrap();
        assert!(!alert, "an absent reading must not fire a low-usage rule");
        assert_eq!(formatted, "--");
    }

    #[tokio::test]
    async fn disk_rule_fires_on_a_real_reading() {
        let mut metrics = empty_metrics();
        metrics.disk = crate::monitoring::DiskMetrics {
            total: 10000,
            used: 9500,
            free: 500,
            usage_percent: 95.0,
        };

        let (alert, _, _) = check_disk_rule(&rule("disk", "", ">=90%"), &metrics)
            .await
            .unwrap();
        assert!(alert);
    }

    /// A speed needs two samples. Until the second one lands there is no
    /// reading, and substituting 0 B/s made every agent restart report the
    /// link as down: a bare threshold parses as `<`.
    #[tokio::test]
    async fn network_rule_skips_a_cycle_with_no_speed_yet() {
        let velocity = VelocityManager::new();
        let metrics = empty_metrics();

        for matcher in ["rx", "tx", ""] {
            let (alert, value, formatted) =
                check_network_rule(&rule("network", matcher, "1m/s"), &metrics, &velocity)
                    .await
                    .unwrap();
            assert!(!alert, "matcher {matcher:?} fired without a reading");
            assert_eq!(value, 0.0);
            assert_eq!(formatted, "--");
        }
    }

    #[tokio::test]
    async fn network_rule_fires_once_a_speed_is_measured() {
        let mut velocity = VelocityManager::new();
        let now = Utc::now();
        velocity
            .update_server_metrics("test", 0, 0, vec![], now - chrono::Duration::seconds(10))
            .await;
        velocity
            .update_server_metrics("test", 10_000_000, 10_000_000, vec![], now)
            .await;

        // 10 MB over 10 s, against a threshold in KiB/s.
        let (alert, value, _) = check_network_rule(
            &rule("network", "rx", ">100k/s"),
            &empty_metrics(),
            &velocity,
        )
        .await
        .unwrap();
        assert!(alert, "expected a measured speed, got {value}");
    }

    #[test]
    fn test_invalid_threshold_format() {
        // Test invalid threshold formats
        assert!(!should_trigger_alert("invalid", 50.0).unwrap());
        assert!(!should_trigger_alert("", 50.0).unwrap());
        assert!(!should_trigger_alert("50", 60.0).unwrap()); // Missing operator
    }
}
