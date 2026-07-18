//! BSD/macOS 解析(对照 Dart:cpu.dart parseBsdCpu / memory.dart parseBsdMemory /
//! net_speed.dart parseBsd)

use crate::types::*;
use regex::Regex;
use std::sync::OnceLock;

fn regex(cell: &'static OnceLock<Regex>, pattern: &str) -> &'static Regex {
    cell.get_or_init(|| Regex::new(pattern).expect("valid regex"))
}

/// `top` CPU 行。macOS:`CPU usage: 14.70% user, 12.76% sys, 72.52% idle`;
/// FreeBSD:`CPU: 5.2% user, 0.0% nice, 3.1% system, 0.1% interrupt, 91.6% idle`;
/// 其余回退提取前三个百分比(user/sys/idle)。
/// 与 Dart 一致:产出单核 "cpu0" 的一次性百分比伪计数
pub fn parse_cpu(raw: &str) -> Vec<CpuCore> {
    static MAC: OnceLock<Regex> = OnceLock::new();
    static FREEBSD: OnceLock<Regex> = OnceLock::new();
    static PERCENT: OnceLock<Regex> = OnceLock::new();

    let core = |user: u64, sys: u64, nice: u64, idle: u64, irq: u64| {
        vec![CpuCore {
            id: "cpu0".to_string(),
            user,
            sys,
            nice,
            idle,
            iowait: 0,
            irq,
            softirq: 0,
        }]
    };

    let mac = regex(&MAC, r"CPU usage: ([\d.]+)% user, ([\d.]+)% sys, ([\d.]+)% idle");
    if let Some(c) = mac.captures(raw) {
        let f = |i: usize| c[i].parse::<f64>().unwrap_or(0.0) as u64;
        return core(f(1), f(2), 0, f(3), 0);
    }

    let freebsd = regex(
        &FREEBSD,
        r"CPU: ([\d.]+)% user, ([\d.]+)% nice, ([\d.]+)% system, ([\d.]+)% interrupt, ([\d.]+)% idle",
    );
    if let Some(c) = freebsd.captures(raw) {
        let f = |i: usize| c[i].parse::<f64>().unwrap_or(0.0) as u64;
        return core(f(1), f(3), f(2), f(5), f(4));
    }

    // 回退:提取所有百分比,取前三个为 user/sys/idle(Dart 同)
    let percent = regex(&PERCENT, r"(-?\d+(?:\.\d+)?)%");
    let values: Vec<f64> = percent
        .captures_iter(raw)
        .filter_map(|c| c[1].parse::<f64>().ok())
        .map(|v| v.clamp(0.0, 100.0))
        .collect();
    if values.len() >= 3 {
        return core(values[0] as u64, values[1] as u64, 0, values[2] as u64, 0);
    }
    Vec::new()
}

/// `top` 内存行,单位 KiB。macOS:`PhysMem: 32G used (1536M wired), 64G unused.`;
/// FreeBSD:`Mem: 456M Active, 2918M Inact, 1127M Wired, 187M Cache, 829M Buf, 3535M Free`
pub fn parse_mem(raw: &str) -> Option<Memory> {
    static MAC: OnceLock<Regex> = OnceLock::new();
    static FREEBSD: OnceLock<Regex> = OnceLock::new();

    let mac = regex(
        &MAC,
        r"PhysMem:\s*([\d.]+)([KMGT])\s*used.*?,\s*([\d.]+)([KMGT])\s*unused",
    );
    if let Some(c) = mac.captures(raw) {
        let used = to_kib(c[1].parse().ok()?, &c[2]);
        let free = to_kib(c[3].parse().ok()?, &c[4]);
        return Some(Memory { total: used + free, free, avail: free });
    }

    let freebsd = regex(
        &FREEBSD,
        r"(?i)(\d+)([KMGT])\s+(Active|Inact|Wired|Cache|Buf|Free)",
    );
    let mut used = 0u64;
    let mut free = 0u64;
    let mut matched = false;
    for c in freebsd.captures_iter(raw) {
        matched = true;
        let kib = to_kib(c[1].parse().ok()?, &c[2]);
        if c[3].eq_ignore_ascii_case("free") {
            free += kib;
        } else {
            used += kib;
        }
    }
    matched.then(|| Memory { total: used + free, free, avail: free })
}

fn to_kib(amount: f64, unit: &str) -> u64 {
    let mul = match unit.to_uppercase().as_str() {
        "T" => 1024.0 * 1024.0 * 1024.0,
        "G" => 1024.0 * 1024.0,
        "M" => 1024.0,
        _ => 1.0,
    };
    (amount * mul).round() as u64
}

/// `netstat -ibn`(Dart `NetSpeed.parseBsd`):
/// 仅取 11 列的 Link 行,跳过 `*` 结尾的未激活接口,同名接口取首行
pub fn parse_net(raw: &str) -> Vec<NetIface> {
    let lines: Vec<&str> = raw.split('\n').collect();
    if lines.len() < 2 {
        return Vec::new();
    }
    let mut result: Vec<NetIface> = Vec::new();
    for line in &lines[1..] {
        let fields: Vec<&str> = line.split_whitespace().collect();
        let Some(device) = fields.first() else { continue };
        if device.ends_with('*') || result.iter().any(|n| n.device == *device) {
            continue;
        }
        if fields.len() != 11 {
            continue;
        }
        let (Ok(rx), Ok(tx)) = (fields[6].parse(), fields[9].parse()) else {
            continue;
        };
        result.push(NetIface {
            device: device.to_string(),
            rx_bytes: rx,
            tx_bytes: tx,
        });
    }
    result
}
