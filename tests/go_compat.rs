//! Go 版行为一致性测试集
//!
//! 对照源:git 历史中的 Go 实现(model/、web/、res/res.go)。
//! 每个测试注明对应的 Go 语义;与 Go 刻意不一致的两处(Go 端 bug)见 threshold.rs 模块注释。

use server_box_monitor::core::config::Config;
use server_box_monitor::monitoring::monitoring::{
    parse_disk_metrics, DiskMetrics, MemoryMetrics, NetworkMetrics, SwapMetrics, SystemMetrics,
};
use server_box_monitor::monitoring::push::PushRateLimiter;
use server_box_monitor::monitoring::size::Size;
use server_box_monitor::monitoring::threshold::{CompareType, Threshold, ThresholdType};
use std::time::Duration;

// ---------- Size:model/size.go ----------

/// Go model/size_test.go TestParseToSize
#[test]
fn test_parse_to_size() {
    assert_eq!(Size::parse("1m").unwrap(), Size(1024 * 1024));
    assert_eq!(Size::parse("1M").unwrap(), Size(1024 * 1024));
    assert_eq!(Size::parse("3k").unwrap(), Size(3 * 1024));
    assert_eq!(Size::parse("7b").unwrap(), Size(7));
}

/// Go Size.String():"%.1f" + 小写后缀,1024 进制
#[test]
fn test_size_string_go_format() {
    assert_eq!(Size(0).to_string(), "0.0b");
    assert_eq!(Size(7).to_string(), "7.0b");
    assert_eq!(Size(3 * 1024).to_string(), "3.0k");
    assert_eq!(Size(26 * 1024 * 1024 * 1024).to_string(), "26.0g");
    assert_eq!(Size(1024_u64.pow(4)).to_string(), "1.0t");
    // 超过 t 不再进位,与 Go 相同
    assert_eq!(Size(2048 * 1024_u64.pow(4)).to_string(), "2048.0t");
}

/// Go ParseToSize:"0" 特判;无后缀报错
#[test]
fn test_parse_size_edge_cases() {
    assert_eq!(Size::parse("0").unwrap(), Size(0));
    assert!(Size::parse("100").is_err());
    assert!(Size::parse("").is_err());
}

// ---------- Threshold:model/threshold.go ----------

/// Go 文档示例:">=80.5%" "<100m" "10m/s"
#[test]
fn test_threshold_percent() {
    let t = Threshold::parse(">=80.5%").unwrap();
    assert_eq!(t.threshold_type, ThresholdType::Percent);
    assert_eq!(t.compare_type, CompareType::GreaterOrEqual);
    assert_eq!(t.value, 80.5);
    assert!(t.is_true(80.5));
    assert!(t.is_true(90.0));
    assert!(!t.is_true(80.0));
}

#[test]
fn test_threshold_size() {
    let t = Threshold::parse("<100m").unwrap();
    assert_eq!(t.threshold_type, ThresholdType::Size);
    assert_eq!(t.compare_type, CompareType::Less);
    assert_eq!(t.value, (100 * 1024 * 1024) as f64);
    assert!(t.is_true((99 * 1024 * 1024) as f64));
    assert!(!t.is_true((100 * 1024 * 1024) as f64));
}

#[test]
fn test_threshold_speed() {
    let t = Threshold::parse(">10m/s").unwrap();
    assert_eq!(t.threshold_type, ThresholdType::Speed);
    assert_eq!(t.compare_type, CompareType::Greater);
    assert_eq!(t.value, (10 * 1024 * 1024) as f64);
    // 大写也可(Go 解析前统一转小写)
    let t2 = Threshold::parse(">10M/s").unwrap();
    assert_eq!(t2.value, t.value);
}

#[test]
fn test_threshold_temperature() {
    let t = Threshold::parse(">=70c").unwrap();
    assert_eq!(t.threshold_type, ThresholdType::Temperature);
    assert_eq!(t.value, 70.0);
    assert!(t.is_true(70.0));
    assert!(!t.is_true(69.9));
}

/// Go 操作符全集:< <= = >= >(注意是单个 =,不是 ==)
#[test]
fn test_threshold_operators() {
    assert_eq!(Threshold::parse("<10%").unwrap().compare_type, CompareType::Less);
    assert_eq!(Threshold::parse("<=10%").unwrap().compare_type, CompareType::LessOrEqual);
    assert_eq!(Threshold::parse("=10%").unwrap().compare_type, CompareType::Equal);
    assert_eq!(Threshold::parse(">=10%").unwrap().compare_type, CompareType::GreaterOrEqual);
    assert_eq!(Threshold::parse(">10%").unwrap().compare_type, CompareType::Greater);
}

/// Go 零值行为:无操作符时 CompareType 为零值(Less)
#[test]
fn test_threshold_no_operator_defaults_to_less() {
    let t = Threshold::parse("80%").unwrap();
    assert_eq!(t.compare_type, CompareType::Less);
    assert!(t.is_true(79.0));
    assert!(!t.is_true(80.0));
}

/// Go:纯数字(无 %、/s、大小后缀、c)无法识别类型 → 报错
#[test]
fn test_threshold_invalid() {
    assert!(Threshold::parse("10").is_err());
    assert!(Threshold::parse("abc").is_err());
    assert!(Threshold::parse("").is_err());
}

// ---------- 配置:model/config.go + res/res.go ----------

/// Go 格式 config.json 能被加载并正确归一化
#[test]
fn test_go_config_json_normalize() {
    let json = r#"{
        "version": 2,
        "name": "my-server",
        "interval": "3s",
        "rate": "2/30s",
        "rules": [
            {"type": "cpu", "threshold": ">=77%", "matcher": "cpu"},
            {"type": "net", "threshold": ">10m/s", "matcher": "eth0-in"}
        ],
        "pushes": [
            {"type": "webhook", "name": "QQ Group", "iface": {"url": "http://localhost:5700", "method": "POST"}}
        ]
    }"#;
    let mut config: Config = serde_json::from_str(json).unwrap();
    config.normalize().unwrap();

    assert_eq!(config.get_server_name(), "my-server");
    // Go:interval "3s" → 3 秒
    assert_eq!(config.get_monitoring().interval_seconds, 3);
    // Go:rate "2/30s" → 30 秒内 2 次
    assert_eq!(config.get_push_rate(), (2, Duration::from_secs(30)));

    let rules = config.get_monitoring().rules;
    assert_eq!(rules.len(), 2);
    assert_eq!(rules[0].monitor_type, "cpu");
    assert_eq!(rules[0].threshold, ">=77%");
    assert_eq!(rules[1].matcher, "eth0-in");

    let pushes = config.get_push();
    assert_eq!(pushes.len(), 1);
    assert_eq!(pushes[0].push_type, "webhook");
    assert_eq!(pushes[0].name, "QQ Group");
    assert_eq!(
        pushes[0].config.get("url").and_then(|v| v.as_str()),
        Some("http://localhost:5700")
    );
}

/// Go res.go 默认值:name "Server 1"、interval 7s、rate "1/1m"
#[test]
fn test_go_config_defaults() {
    let mut config: Config = serde_json::from_str("{}").unwrap();
    config.normalize().unwrap();

    assert_eq!(config.get_server_name(), "Server 1");
    assert_eq!(config.get_monitoring().interval_seconds, 7);
    assert_eq!(config.get_push_rate(), (1, Duration::from_secs(60)));
}

/// Go initRateLimiter:rate 解析失败时回退默认限流
#[test]
fn test_go_rate_invalid_falls_back_to_default() {
    for bad in ["abc", "1", "x/1m", "1/xx", "1/1w"] {
        let mut config: Config = serde_json::from_str(&format!(r#"{{"rate": "{}"}}"#, bad)).unwrap();
        config.normalize().unwrap();
        assert_eq!(
            config.get_push_rate(),
            (1, Duration::from_secs(60)),
            "rate {:?} 应回退默认值",
            bad
        );
    }
    // Go 时长单位:s/m/h
    let mut config: Config = serde_json::from_str(r#"{"rate": "3/2h"}"#).unwrap();
    config.normalize().unwrap();
    assert_eq!(config.get_push_rate(), (3, Duration::from_secs(7200)));
}

// ---------- 限流:gommon rate.Limiter 语义 ----------

/// Go runner:推送前 Check(不消耗),成功后 Acquire(消耗);窗口内达到次数则拒绝
#[test]
fn test_rate_limiter_check_acquire() {
    let limiter = PushRateLimiter::new();
    let window = Duration::from_secs(60);

    // check 不消耗配额
    assert!(limiter.check("ios", 1, window));
    assert!(limiter.check("ios", 1, window));

    limiter.acquire("ios");
    assert!(!limiter.check("ios", 1, window));

    // 不同名称独立计数
    assert!(limiter.check("webhook", 1, window));
}

#[test]
fn test_rate_limiter_window_expiry() {
    let limiter = PushRateLimiter::new();
    let window = Duration::from_millis(50);

    limiter.acquire("x");
    assert!(!limiter.check("x", 1, window));
    std::thread::sleep(Duration::from_millis(80));
    assert!(limiter.check("x", 1, window));
}

// ---------- 磁盘解析:model/status.go + web/web.go ----------

/// fixture 来自 Go model/test/disk(model/status_test.go TestParseDisk)。
/// 聚合语义与 Go web.Status 一致:仅 /dev 前缀文件系统 + 按文件系统名去重,
/// 因此 tmpfs/devtmpfs/overlay/shm 不计入,期望值为
/// /dev/mapper/centosvolume-root(40G/26G/14G) + /dev/sda2(1014M/602M/413M) + /dev/sda1(100M/7.3M/93M)
#[test]
fn test_parse_disk_go_fixture() {
    const GIB: u64 = 1024 * 1024 * 1024;
    const MIB: u64 = 1024 * 1024;
    let fixture = include_str!("fixtures/disk");

    let disk = parse_disk_metrics(fixture).unwrap();

    const KIB: u64 = 1024;
    assert_eq!(disk.total, 40 * GIB + 1014 * MIB + 100 * MIB);
    // 解析以 KiB 为粒度:7.3M → 7475 KiB(与 Go 的字节级换算差 <1KiB,展示不受影响)
    assert_eq!(disk.used, 26 * GIB + 602 * MIB + ((7.3 * KIB as f64) as u64) * KIB);
    assert_eq!(disk.free, 14 * GIB + 413 * MIB + 93 * MIB);
    // Go web.Status 展示格式
    assert_eq!(
        format!("{} / {}", Size(disk.used), Size(disk.total)),
        "26.6g / 41.1g"
    );
}

// ---------- /status 端点:web/web.go + web/base.go ----------

fn sample_metrics() -> SystemMetrics {
    SystemMetrics {
        timestamp: chrono::Utc::now(),
        server_name: "Server 1".to_string(),
        cpu_usage: 36.6,
        cpu_cores: vec![],
        memory: MemoryMetrics {
            total: 40 * 1024 * 1024 * 1024,
            used: 26 * 1024 * 1024 * 1024,
            free: 14 * 1024 * 1024 * 1024,
            usage_percent: 65.0,
        },
        swap: SwapMetrics { total: 0, used: 0, usage_percent: 0.0 },
        disk: DiskMetrics {
            total: 41 * 1024 * 1024 * 1024,
            used: 27 * 1024 * 1024 * 1024,
            free: 14 * 1024 * 1024 * 1024,
            usage_percent: 65.8,
        },
        network: NetworkMetrics {
            rx_bytes: 3 * 1024,
            tx_bytes: 7,
        },
        temperature: None,
    }
}

/// Go web.Status:{"name","cpu","mem","net","disk"},cpu "%.1f%%",其余 "used/total" Size 格式
#[test]
fn test_status_response_go_shape() {
    let metrics = sample_metrics();
    let data = server_box_monitor::api::server::go_status_data(Some(&metrics), "Server 1");

    assert_eq!(data["name"], "Server 1");
    assert_eq!(data["cpu"], "36.6%");
    assert_eq!(data["mem"], "26.0g / 40.0g");
    assert_eq!(data["net"], "3.0k / 7.0b");
    assert_eq!(data["disk"], "27.0g / 41.0g");
    // 与 Go 相同的 5 个字段,不多不少
    assert_eq!(data.as_object().unwrap().len(), 5);
}

/// 指标未就绪时字段为空串,name 取配置
#[test]
fn test_status_response_no_metrics() {
    let data = server_box_monitor::api::server::go_status_data(None, "my-server");
    assert_eq!(data["name"], "my-server");
    assert_eq!(data["cpu"], "");
    assert_eq!(data["mem"], "");
    assert_eq!(data["net"], "");
    assert_eq!(data["disk"], "");
}
