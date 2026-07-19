//! BSD/macOS parsing (Dart reference: cpu.dart parseBsdCpu / memory.dart parseBsdMemory /
//! net_speed.dart parseBsd)

use crate::types::*;
use regex::Regex;
use std::sync::OnceLock;

fn regex(cell: &'static OnceLock<Regex>, pattern: &str) -> &'static Regex {
    cell.get_or_init(|| Regex::new(pattern).expect("valid regex"))
}

/// `top` CPU line. macOS: `CPU usage: 14.70% user, 12.76% sys, 72.52% idle`;
/// FreeBSD:`CPU: 5.2% user, 0.0% nice, 3.1% system, 0.1% interrupt, 91.6% idle`;
/// otherwise falls back to extracting the first three percentages (user/sys/idle).
/// Matching Dart: produces one-shot percentage pseudo-counters for a single "cpu0" core
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

    // Fallback: extract all percentages, take the first three as user/sys/idle (same as Dart)
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

/// `top` memory line, in KiB. macOS: `PhysMem: 32G used (1536M wired), 64G unused.`;
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
        let total = used + free;
        // top's "used" includes cached files; when vm_stat output accompanies
        // the PhysMem line, derive real usage (active + wired + compressor)
        // so avail reflects reclaimable memory, like MemAvailable on Linux
        let avail = vm_stat_avail(raw, total).unwrap_or(free);
        return Some(Memory { total, free, avail });
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

/// Available memory from vm_stat pages: total - (active + wired + compressor).
/// Returns None when the vm_stat block is missing (plain PhysMem input)
fn vm_stat_avail(raw: &str, total_kib: u64) -> Option<u64> {
    static PAGE_SIZE: OnceLock<Regex> = OnceLock::new();
    static PAGES: OnceLock<Regex> = OnceLock::new();

    let page_size = regex(&PAGE_SIZE, r"page size of (\d+) bytes")
        .captures(raw)
        .and_then(|c| c[1].parse::<u64>().ok())
        .unwrap_or(4096);

    let pages = regex(
        &PAGES,
        r"Pages (active|wired down|occupied by compressor):\s*(\d+)",
    );
    let mut used_pages = 0u64;
    let mut found = 0;
    for c in pages.captures_iter(raw) {
        used_pages += c[2].parse::<u64>().ok()?;
        found += 1;
    }
    if found == 0 {
        return None;
    }
    let used_kib = used_pages * page_size / 1024;
    Some(total_kib.saturating_sub(used_kib))
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
/// Only 11-column Link lines; skip inactive interfaces ending in `*`; first line wins per interface name
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
