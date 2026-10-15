//! The parsed status adapted into [`SystemMetrics`]: CPU per platform, memory,
//! disks and network aggregated, rates against the previous sample.

use crate::{
    core::config::Config,
    monitoring::timeseries::{CpuCoreTime, core_usage_percent},
    utils::error::Result,
};
use chrono::{DateTime, Utc};
use sbm_parser::types::{CpuCore, Disk};
use sbm_parser::{ServerStatus, SystemType};
use super::metrics::*;

pub(super) fn carry_forward_opt<T>(fresh: Option<T>, prev: Option<T>) -> Option<T> {
    fresh.or(prev)
}

/// Per-device bytes/sec since `prev_metrics`, from `current`'s cumulative
/// sector counters (native sampling refreshes `diskio` every core cycle now,
/// so this is a real per-cycle rate, not just a once-per-extended-cycle
/// snapshot). Empty on the first cycle, for a zero/negative time delta
/// (clock oddities), or for a device with no matching entry in `prev`
/// (counter reset or newly appeared — one cycle without a rate is cheaper
/// than reporting a bogus spike).
pub(super) fn compute_diskio_rate(
    now: DateTime<Utc>,
    current: &[sbm_parser::types::DiskIoPiece],
    prev_metrics: Option<&SystemMetrics>,
) -> Vec<DiskIoRate> {
    let Some(prev) = prev_metrics else {
        return Vec::new();
    };
    let elapsed = (now - prev.timestamp).num_milliseconds() as f64 / 1000.0;
    if elapsed <= 0.0 {
        return Vec::new();
    }
    current
        .iter()
        .filter_map(|d| {
            let p = prev.diskio.iter().find(|p| p.dev == d.dev)?;
            if d.sectors_read < p.sectors_read || d.sectors_write < p.sectors_write {
                return None;
            }
            let read_delta = (d.sectors_read - p.sectors_read) as f64 * 512.0;
            let write_delta = (d.sectors_write - p.sectors_write) as f64 * 512.0;
            Some(DiskIoRate {
                dev: d.dev.clone(),
                read_bytes_per_sec: read_delta / elapsed,
                write_bytes_per_sec: write_delta / elapsed,
            })
        })
        .collect()
}

/// Adapt the parse result into the monitor's aggregate metrics
pub(super) fn adapt_status(
    system: SystemType,
    status: ServerStatus,
    config: &Config,
    prev_cpu: Option<&CpuCore>,
    prev_metrics: Option<&SystemMetrics>,
    extended_refreshed: bool,
    disk_counts_network: bool,
) -> SystemMetrics {
    let (cpu_usage, cpu_cores) = adapt_cpu(
        system,
        &status.cpu,
        prev_cpu,
        prev_metrics.map(|m| m.cpu_cores.as_slice()).unwrap_or(&[]),
    );
    let (memory, swap) = adapt_memory(&status);
    let disk = aggregate_disks(&status.disks, disk_counts_network);
    let network = aggregate_net(&status);

    // Temperature prefers CPU devices (Dart `Temperatures.first`). Bsd used
    // to be forced to None here ("top output has no temperature") — true for
    // the old script-only path, but stale post-native-cutover: `sbm_native`'s
    // sysinfo backend can populate `status.temps` via Components on Bsd now
    // (empty when the platform locks down thermal sensors, e.g. many Macs —
    // see `effective_capabilities`, which reports this as HardwareDependent).
    let temperature = status.temps.first().map(|t| t as f32);
    let temps = status
        .temps
        .0
        .iter()
        .map(|(device, value)| TempReading {
            device: device.clone(),
            value: *value,
        })
        .collect();

    let amd = if extended_refreshed {
        status.amd
    } else {
        prev_metrics
            .map(|p| p.amd_cache.clone())
            .unwrap_or_default()
    };

    let mut gpu_items = status.gpus;
    gpu_items.extend(sbm_parser::gpu::amd_as_gpu(&amd));
    let mut gpus: Vec<GpuMetrics> = gpu_items.into_iter().map(GpuMetrics::from).collect();
    // Under WSL2 the driver lists no process; with one GPU, what holds the
    // GPU device is what uses it.
    if let [gpu] = gpus.as_mut_slice()
        && gpu.processes.is_empty()
        && gpu.memory_used.is_some_and(|m| m > 0)
    {
        gpu.processes = sbm_native::wsl_gpu_processes();
    }

    let disk_details = flatten_disks(&status.disks);

    let ifaces = status
        .net
        .iter()
        .map(|n| IfaceMetrics {
            name: n.device.clone(),
            rx_bytes: n.rx_bytes,
            tx_bytes: n.tx_bytes,
        })
        .collect();

    let disk_smart = if extended_refreshed {
        status.disk_smart.iter().map(SmartSummary::from).collect()
    } else {
        prev_metrics
            .map(|p| p.disk_smart.clone())
            .unwrap_or_default()
    };
    // Same cadence and the same carry-forward. Without it every cycle between
    // two extended runs would report no addresses at all, which a client
    // cannot tell from a machine that has none.
    let ips = if extended_refreshed {
        status.ips.clone()
    } else {
        prev_metrics.map(|p| p.ips.clone()).unwrap_or_default()
    };

    let now = Utc::now();
    let diskio = status.diskio;
    let diskio_rate = compute_diskio_rate(now, &diskio, prev_metrics);
    // Only stamped on a cycle that actually ran the extended script — a
    // carry_forward'd value (unchanged battery/sensors/SMART reading) keeps
    // its previous timestamp rather than looking falsely fresh every cycle
    let extended_updated_at = if extended_refreshed {
        now
    } else {
        prev_metrics.map(|p| p.extended_updated_at).unwrap_or(now)
    };

    SystemMetrics {
        timestamp: now,
        extended_updated_at,
        server_name: config.get_server_name(),
        cpu_usage,
        cpu_cores,
        memory,
        swap,
        disk,
        network,
        temperature,
        temps,
        sys: status.sys.clone(),
        os_id: status.os_id.clone(),
        os_id_like: status.os_id_like.clone(),
        cpu_brand: format_cpu_brand(&status.cpu_brand),
        gpus,
        disk_details,
        ifaces,
        uptime: carry_forward_opt(status.uptime, prev_metrics.and_then(|p| p.uptime.clone())),
        conn: carry_forward_opt(status.conn, prev_metrics.and_then(|p| p.conn)),
        diskio,
        diskio_rate,
        batteries: if extended_refreshed {
            status.batteries
        } else {
            prev_metrics
                .map(|p| p.batteries.clone())
                .unwrap_or_default()
        },
        sensors: if extended_refreshed {
            status.sensors
        } else {
            prev_metrics.map(|p| p.sensors.clone()).unwrap_or_default()
        },
        disk_smart,
        ips,
        // Filled in by `collect_metrics`: whether these are fresh or the
        // previous cycle's depends on whether the script ran, which this
        // function is not the one that knows.
        custom_cmds: Vec::new(),
        amd_cache: amd,
    }
}

pub(super) fn format_cpu_brand(brands: &[(String, u32)]) -> Option<String> {
    if brands.is_empty() {
        return None;
    }
    Some(
        brands
            .iter()
            .map(|(name, count)| {
                if *count > 1 {
                    format!("{name} (x{count})")
                } else {
                    name.clone()
                }
            })
            .collect::<Vec<_>>()
            .join(", "),
    )
}

/// Every filesystem as its own row, for the drill-down (APFS volumes are not
/// pooled here, unlike [`aggregate_disks`]), KiB → bytes. NFS and SMB are
/// listed whether or not they count in the total, and so is a device nothing
/// is mounted from — though not one that only holds others (an LVM physical
/// volume, a RAID or ZFS member, a LUKS container), which is the tree's
/// structure rather than storage of its own.
pub(super) fn flatten_disks(disks: &[Disk]) -> Vec<DiskDetail> {
    fn listed(d: &Disk) -> bool {
        if !d.is_storage() {
            return false;
        }
        if d.size > 0 {
            return true;
        }
        d.mount.is_empty()
            && d.children.is_empty()
            && d.fs_type.as_deref().is_some_and(|t| {
                !t.ends_with("_member") && t != "crypto_LUKS" && t != "LVM2_member"
            })
    }
    fn walk<'a>(disks: &'a [Disk], seen: &mut Vec<(&'a str, &'a str)>, out: &mut Vec<DiskDetail>) {
        for d in disks {
            let identity = (d.path.as_str(), d.mount.as_str());
            if listed(d) && !seen.contains(&identity) {
                seen.push(identity);
                out.push(DiskDetail {
                    path: d.path.clone(),
                    mount: d.mount.clone(),
                    fs_type: d.fs_type.clone(),
                    used: d.used * 1024,
                    total: d.size * 1024,
                    usage_percent: percent(d.used, d.size),
                });
            }
            walk(&d.children, seen, out);
        }
    }
    let mut out = Vec::new();
    walk(disks, &mut Vec::new(), &mut out);
    out
}

pub(super) fn summary_core(cores: &[CpuCore]) -> Option<&CpuCore> {
    cores
        .iter()
        .find(|c| c.id == "cpu")
        .or_else(|| cores.first())
}

/// CPU usage semantics differ per source:
/// - Linux /proc/stat is cumulative ticks — usage is the delta against the
///   previous sample (Dart `Cpus.usedPercent`); a direct ratio would be the
///   since-boot average. First cycle (no baseline) and counter wraparound
///   report 0.
/// - BSD top / Windows WMI emit one-shot percentage pseudo-counters (totals
///   stay ~100), so the single-sample ratio IS the current usage; a delta
///   would divide by ~0 and always yield 0.
///   Per-core entries become CpuCoreTime (used = total - idle) with
///   `usage_percent` resolved here against `prev_cores`, so that every consumer
///   (storage, rules, velocity, the panel) reads one already-correct number
///   instead of re-deriving it from the platform-dependent raw counters.
pub(super) fn adapt_cpu(
    system: SystemType,
    cores: &[CpuCore],
    prev_summary: Option<&CpuCore>,
    prev_cores: &[CpuCoreTime],
) -> (f32, Vec<CpuCoreTime>) {
    let usage = match system {
        SystemType::Linux => match (prev_summary, summary_core(cores)) {
            (Some(pre), Some(now)) if now.total() > pre.total() => {
                sbm_parser::types::cpu_used_percent(pre, now) as f32
            }
            _ => 0.0,
        },
        _ => summary_core(cores)
            .map(|c| {
                let total = c.total();
                if total == 0 {
                    0.0
                } else {
                    (total - c.idle) as f32 / total as f32 * 100.0
                }
            })
            .unwrap_or(0.0),
    };

    let core_times = cores
        .iter()
        .filter(|c| c.id != "cpu")
        .enumerate()
        .map(|(i, c)| {
            let now = CpuCoreTime {
                used: c.total() - c.idle,
                total: c.total(),
                usage_percent: None,
            };
            CpuCoreTime {
                usage_percent: core_usage_percent(system, prev_cores.get(i).copied(), now),
                ..now
            }
        })
        .collect();

    (usage, core_times)
}

/// Memory/swap: KiB → bytes; used follows the Dart `Memory.usedPercent` semantics
/// (falls back to free when avail is 0)
pub(super) fn adapt_memory(status: &ServerStatus) -> (MemoryMetrics, SwapMetrics) {
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
        None => MemoryMetrics {
            total: 0,
            used: 0,
            free: 0,
            usage_percent: 0.0,
        },
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
        None => SwapMetrics {
            total: 0,
            used: 0,
            usage_percent: 0.0,
        },
    };

    (memory, swap)
}

pub(super) fn percent(used: u64, total: u64) -> f32 {
    if total == 0 {
        0.0
    } else {
        (used as f32 / total as f32) * 100.0
    }
}

/// The disk total history stores and disk rules check: `sbm_parser`'s, the one
/// the app shows for a server it reaches over SSH, so the two agree (#1669) —
/// APFS containers and ZFS pools counted once, NFS and SMB only with
/// [`disk_counts_network`]. KiB → bytes.
pub(super) fn aggregate_disks(disks: &[Disk], disk_counts_network: bool) -> DiskMetrics {
    let total = sbm_parser::types::disk_total(disks, disk_counts_network);
    DiskMetrics {
        total: total.size * 1024,
        used: total.used * 1024,
        free: total.avail * 1024,
        usage_percent: percent(total.used, total.size),
    }
}

pub(super) fn aggregate_net(status: &ServerStatus) -> NetworkMetrics {
    NetworkMetrics {
        rx_bytes: status.net.iter().map(|n| n.rx_bytes).sum(),
        tx_bytes: status.net.iter().map(|n| n.tx_bytes).sum(),
    }
}

/// Disk segment parsing + Go-compatible aggregation, Linux-only: what the
/// retired Go agent's `/status` answered, kept so `tests/go_compat.rs` holds
/// the aggregation to it. Nothing in the agent calls it.
///
/// TODO: remove with `tests/go_compat.rs` once no Go agent's numbers are
/// compared against.
pub fn parse_disk_metrics(segment: &str) -> Result<DiskMetrics> {
    Ok(aggregate_disks(
        &sbm_parser::linux::parse_disk(segment),
        false,
    ))
}
