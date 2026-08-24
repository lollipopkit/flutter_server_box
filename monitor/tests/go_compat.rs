//! Behavior-parity test suite against the Go implementation
//!
//! Reference: the Go implementation in git history (model/, web/, res/res.go).
//! Each test names the Go semantics it covers; see the threshold.rs module comment for the two deliberate divergences (Go-side bugs).

use server_box_monitor::core::config::Config;
use server_box_monitor::monitoring::{
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

/// Go Size.String(): "%.1f" + lowercase suffix, base 1024
#[test]
fn test_size_string_go_format() {
    assert_eq!(Size(0).to_string(), "0.0b");
    assert_eq!(Size(7).to_string(), "7.0b");
    assert_eq!(Size(3 * 1024).to_string(), "3.0k");
    assert_eq!(Size(26 * 1024 * 1024 * 1024).to_string(), "26.0g");
    assert_eq!(Size(1024_u64.pow(4)).to_string(), "1.0t");
    // No carry beyond t, same as Go
    assert_eq!(Size(2048 * 1024_u64.pow(4)).to_string(), "2048.0t");
}

/// Go ParseToSize: "0" special-cased; no suffix errors
#[test]
fn test_parse_size_edge_cases() {
    assert_eq!(Size::parse("0").unwrap(), Size(0));
    assert!(Size::parse("100").is_err());
    assert!(Size::parse("").is_err());
}

// ---------- Threshold:model/threshold.go ----------

/// Go doc examples: ">=80.5%" "<100m" "10m/s"
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
    // Uppercase also accepted (Go lowercases before parsing)
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

/// Full Go operator set: < <= = >= > (note: single =, not ==)
#[test]
fn test_threshold_operators() {
    assert_eq!(Threshold::parse("<10%").unwrap().compare_type, CompareType::Less);
    assert_eq!(Threshold::parse("<=10%").unwrap().compare_type, CompareType::LessOrEqual);
    assert_eq!(Threshold::parse("=10%").unwrap().compare_type, CompareType::Equal);
    assert_eq!(Threshold::parse(">=10%").unwrap().compare_type, CompareType::GreaterOrEqual);
    assert_eq!(Threshold::parse(">10%").unwrap().compare_type, CompareType::Greater);
}

/// Go zero-value behavior: without an operator, CompareType is the zero value (Less)
#[test]
fn test_threshold_no_operator_defaults_to_less() {
    let t = Threshold::parse("80%").unwrap();
    assert_eq!(t.compare_type, CompareType::Less);
    assert!(t.is_true(79.0));
    assert!(!t.is_true(80.0));
}

/// Go: bare numbers (no %, /s, size suffix, or c) have no recognizable type → error
#[test]
fn test_threshold_invalid() {
    assert!(Threshold::parse("10").is_err());
    assert!(Threshold::parse("abc").is_err());
    assert!(Threshold::parse("").is_err());
}

// ---------- Config: model/config.go + res/res.go ----------

/// Go-format config.json loads and normalizes correctly
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
            {"type": "webhook", "name": "QQ Group", "iface": {"url": "http://localhost:5700", "method": "POST", "body": {"message": "{{name}} {{msg}}"}, "code": 202, "body_regex": "accepted"}},
            {"type": "server_chan", "name": "ServerChan", "iface": {"sckey": "SCT123", "title": "{{name}}", "desp": "{{msg}}", "code": 201}}
        ]
    }"#;
    let mut config: Config = serde_json::from_str(json).unwrap();
    config.normalize().unwrap();

    assert_eq!(config.get_server_name(), "my-server");
    // Go: interval "3s" → 3 seconds
    assert_eq!(config.get_monitoring().interval_seconds, 3);
    // Go: rate "2/30s" → 2 times per 30 seconds
    assert_eq!(config.get_push_rate(), (2, Duration::from_secs(30)));

    let rules = config.get_monitoring().rules;
    assert_eq!(rules.len(), 2);
    assert_eq!(rules[0].monitor_type, "cpu");
    assert_eq!(rules[0].threshold, ">=77%");
    assert_eq!(rules[1].matcher, "eth0-in");

    let pushes = config.get_push();
    assert_eq!(pushes.len(), 2);
    assert_eq!(pushes[0].push_type, "webhook");
    assert_eq!(pushes[0].name, "QQ Group");
    assert_eq!(
        pushes[0].config.get("url").and_then(|v| v.as_str()),
        Some("http://localhost:5700")
    );
    assert!(pushes[0].config.get("body").is_some());
    assert_eq!(pushes[0].config.get("legacy_go_format").and_then(|v| v.as_bool()), Some(true));
    assert_eq!(pushes[0].config.get("expected_http_status").and_then(|v| v.as_integer()), Some(202));
    assert_eq!(pushes[1].push_type, "serverchan");
    assert_eq!(pushes[1].config.get("legacy_go_format").and_then(|v| v.as_bool()), Some(true));
    assert_eq!(pushes[1].config.get("sc_key").and_then(|v| v.as_str()), Some("SCT123"));
    assert_eq!(pushes[1].config.get("expected_http_status").and_then(|v| v.as_integer()), Some(201));
}

/// Go res.go defaults: interval 7s, rate "1/1m". `name` intentionally
/// diverges from Go's literal "Server 1" default — it falls back to the
/// real OS hostname (see `Config::get_server_name`) so a fresh install
/// identifies itself meaningfully instead of a generic label
#[test]
fn test_go_config_defaults() {
    let mut config: Config = serde_json::from_str("{}").unwrap();
    config.normalize().unwrap();

    let expected_name = hostname::get()
        .ok()
        .and_then(|h| h.into_string().ok())
        .filter(|h| !h.is_empty())
        .unwrap_or_else(|| "Server 1".to_string());
    assert_eq!(config.get_server_name(), expected_name);
    assert_eq!(config.get_monitoring().interval_seconds, 7);
    assert_eq!(config.get_push_rate(), (1, Duration::from_secs(60)));
}

/// Go initRateLimiter: falls back to the default rate limit when rate parsing fails
#[test]
fn test_go_rate_invalid_falls_back_to_default() {
    for bad in ["abc", "1", "x/1m", "1/xx", "1/1w"] {
        let mut config: Config = serde_json::from_str(&format!(r#"{{"rate": "{}"}}"#, bad)).unwrap();
        config.normalize().unwrap();
        assert_eq!(
            config.get_push_rate(),
            (1, Duration::from_secs(60)),
            "rate {:?} should fall back to the default",
            bad
        );
    }
    // Go duration units: s/m/h
    let mut config: Config = serde_json::from_str(r#"{"rate": "3/2h"}"#).unwrap();
    config.normalize().unwrap();
    assert_eq!(config.get_push_rate(), (3, Duration::from_secs(7200)));
}

// ---------- Rate limiting: gommon rate.Limiter semantics ----------

/// Go runner: Check before pushing (no consumption), Acquire after success (consumes); rejected once the window count is reached
#[test]
fn test_rate_limiter_check_acquire() {
    let limiter = PushRateLimiter::new();
    let window = Duration::from_secs(60);

    // check does not consume quota
    assert!(limiter.check("ios", 1, window));
    assert!(limiter.check("ios", 1, window));

    limiter.acquire("ios");
    assert!(!limiter.check("ios", 1, window));

    // Independent counters per name
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

// ---------- Disk parsing: model/status.go + web/web.go ----------

/// Fixture from Go model/test/disk (model/status_test.go TestParseDisk).
/// Aggregation matches Go web.Status: only /dev-prefixed filesystems, deduped by
/// filesystem name, so tmpfs/devtmpfs/overlay/shm are excluded; expected values are
/// /dev/mapper/centosvolume-root(40G/26G/14G) + /dev/sda2(1014M/602M/413M) + /dev/sda1(100M/7.3M/93M)
#[test]
fn test_parse_disk_go_fixture() {
    const GIB: u64 = 1024 * 1024 * 1024;
    const MIB: u64 = 1024 * 1024;
    let fixture = include_str!("fixtures/disk");

    let disk = parse_disk_metrics(fixture).unwrap();

    const KIB: u64 = 1024;
    assert_eq!(disk.total, 40 * GIB + 1014 * MIB + 100 * MIB);
    // Parsing is KiB-granular: 7.3M → 7475 KiB (< 1KiB off Go's byte-level math; display unaffected)
    assert_eq!(disk.used, 26 * GIB + 602 * MIB + ((7.3 * KIB as f64) as u64) * KIB);
    assert_eq!(disk.free, 14 * GIB + 413 * MIB + 93 * MIB);
    // Go web.Status display format
    assert_eq!(
        format!("{} / {}", Size(disk.used), Size(disk.total)),
        "26.6g / 41.1g"
    );
}

// ---------- /status endpoint: web/web.go + web/base.go ----------

fn sample_metrics() -> SystemMetrics {
    SystemMetrics {
        timestamp: chrono::Utc::now(),
        extended_updated_at: chrono::Utc::now(),
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
        custom_cmds: vec![],
        amd_cache: vec![],
    }
}

/// Go web.Status: {"name","cpu","mem","net","disk"}, cpu "%.1f%%", others "used/total" in Size format
#[test]
fn test_status_response_go_shape() {
    let metrics = sample_metrics();
    let data = server_box_monitor::api::server::go_status_data(Some(&metrics), "Server 1");

    assert_eq!(data["name"], "Server 1");
    assert_eq!(data["cpu"], "36.6%");
    assert_eq!(data["mem"], "26.0g / 40.0g");
    assert_eq!(data["net"], "3.0k / 7.0b");
    assert_eq!(data["disk"], "27.0g / 41.0g");
    // Exactly the same 5 fields as Go, no more, no less
    assert_eq!(data.as_object().unwrap().len(), 5);
}

/// Fields are empty strings before metrics are ready; name comes from config
#[test]
fn test_status_response_no_metrics() {
    let data = server_box_monitor::api::server::go_status_data(None, "my-server");
    assert_eq!(data["name"], "my-server");
    assert_eq!(data["cpu"], "");
    assert_eq!(data["mem"], "");
    assert_eq!(data["net"], "");
    assert_eq!(data["disk"], "");
}
