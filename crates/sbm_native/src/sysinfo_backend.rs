//! macOS/BSD + Windows backend, built on the `sysinfo` crate. Absorbs and
//! generalizes the pattern from the removed `monitor::macos_cpu` (per-core
//! CPU only) to also cover cpu_brand/memory/swap/disks/diskio/network/temps/
//! uptime/host/sys.
//!
//! `batteries`/`sensors`/`nvidia`/`amd`/`disk_smart` are intentionally left
//! empty — those stay on the shared script path.
//!
//! Real values probed on this machine (macOS/Tahoe) confirm `Disk::name()`
//! returns a volume label ("Macintosh HD"), not a `/dev/...` device path —
//! unlike Linux/BSD's `df -k`-derived `Disk.path`. Monitor's `is_real_disk`
//! must not require a `/dev` prefix for natively-sourced Bsd disks (same
//! class of bug as the Windows `/dev`-prefix fix from earlier — see the
//! monitor-integration step).

use sbm_parser::types::{Disk, DiskIoPiece, Memory, NetIface, Swap, Temperatures};
use sbm_parser::{types::CpuCore, ServerStatus};
use sysinfo::{Components, CpuRefreshKind, Disks, Networks, System};

/// One scale for every synthetic CPU reading (0.01% precision). Matches the
/// used/total tick convention every other platform's real counters use (see
/// `ServerStatus.cpu`'s doc comment on cross-platform semantics) so it flows
/// through the existing aggregation/storage code unchanged.
const SCALE: u64 = 10_000;

pub struct State {
    system: System,
    disks: Disks,
    networks: Networks,
    components: Components,
    /// sysinfo's first CPU reading has no prior sample to diff against
    primed: bool,
    /// Refreshing the CPU list resets sysinfo's usage baseline, so only do it
    /// when this cheap topology signal changes.
    cpu_count_hint: usize,
}

impl Default for State {
    fn default() -> Self {
        let mut system = System::new();
        // sysinfo 0.39 separates CPU list and usage refresh. Without an
        // explicit list refresh an initially empty System never populates
        // system.cpus(), so the first usage refresh yields no cores and the
        // second (primed) sample still reports empty/0.
        system.refresh_cpu_list(CpuRefreshKind::everything());
        let cpu_count_hint = logical_cpu_count().unwrap_or_else(|| system.cpus().len());
        Self {
            system,
            disks: Disks::new(),
            networks: Networks::new(),
            components: Components::new(),
            primed: false,
            cpu_count_hint,
        }
    }
}

fn logical_cpu_count() -> Option<usize> {
    std::thread::available_parallelism().ok().map(usize::from)
}

/// Groups per-logical-core brand strings into (name, count), matching
/// `windows::parse_cpu_brand`'s shape (and `monitor`'s `format_cpu_brand`,
/// which expects this grouping to render "Brand (xN)")
/// Whether a reading is a measurement rather than a sentinel.
///
/// macOS reports inactive PMU sensors through the same API as live ones, with
/// values like -9201.1 °C. Passed through, they turned the temperature chart
/// into two dozen lines most of which sat far off the axis, and they would
/// drag any min/mean computed over the set.
///
/// The window is deliberately wide: −40 covers a machine sitting in a freezer
/// or a cold-boot reading, 150 covers a GPU or VRM under load. Anything
/// outside it is not a temperature this software can act on.
fn is_plausible_temp(c: f64) -> bool {
    c.is_finite() && (-40.0..=150.0).contains(&c)
}

fn cpu_brand(system: &System) -> Vec<(String, u32)> {
    let mut brands: Vec<(String, u32)> = Vec::new();
    for cpu in system.cpus() {
        let name = cpu.brand().trim();
        if name.is_empty() {
            continue;
        }
        match brands.iter_mut().find(|(n, _)| n == name) {
            Some((_, count)) => *count += 1,
            None => brands.push((name.to_string(), 1)),
        }
    }
    brands
}

fn cpu_cores(system: &System) -> Vec<CpuCore> {
    let per_core_pct: Vec<f64> =
        system.cpus().iter().map(|c| c.cpu_usage().clamp(0.0, 100.0) as f64).collect();
    if per_core_pct.is_empty() {
        return Vec::new();
    }

    let to_core = |id: String, pct: f64| {
        let used = (SCALE as f64 * pct / 100.0).round() as u64;
        CpuCore { id, user: used, sys: 0, nice: 0, idle: SCALE.saturating_sub(used), iowait: 0, irq: 0, softirq: 0 }
    };

    // A "cpu" summary row (mean of all cores) alongside "cpu0".."cpuN-1"
    // matches Linux's /proc/stat convention the rest of the pipeline
    // (summary_core, per-core filtering) already assumes.
    let mean = per_core_pct.iter().sum::<f64>() / per_core_pct.len() as f64;
    let mut cores = vec![to_core("cpu".to_string(), mean)];
    cores.extend(per_core_pct.into_iter().enumerate().map(|(i, pct)| to_core(format!("cpu{i}"), pct)));
    cores
}

/// Total physical memory in bytes.
///
/// Builds its own throwaway `System` rather than reusing the sampling
/// [`State`]: callers need this at startup, before any sampling state is
/// constructed, and refreshing memory once is cheap.
pub fn total_memory() -> Option<u64> {
    let mut system = System::new();
    system.refresh_memory();
    Some(system.total_memory()).filter(|&t| t > 0)
}

pub fn sample(state: &mut State) -> ServerStatus {
    let current_cpu_count = logical_cpu_count().unwrap_or(state.cpu_count_hint);
    let topology_changed =
        state.system.cpus().is_empty() || current_cpu_count != state.cpu_count_hint;
    if topology_changed {
        state.system.refresh_cpu_list(CpuRefreshKind::everything());
        state.cpu_count_hint = current_cpu_count;
    }
    state.system.refresh_cpu_usage();
    state.system.refresh_memory();
    state.disks.refresh(true);
    state.networks.refresh(true);
    state.components.refresh(true);

    let first_call = !state.primed;
    state.primed = true;
    // No delta baseline yet — leave cpu empty this cycle rather than report
    // a misleading single-sample reading, matching macos_cpu's prior behavior
    let cpu = if first_call || topology_changed { Vec::new() } else { cpu_cores(&state.system) };

    let total_mem = state.system.total_memory();
    let mem = (total_mem > 0).then(|| Memory {
        total: total_mem / 1024,
        free: state.system.free_memory() / 1024,
        avail: state.system.available_memory() / 1024,
    });

    let total_swap = state.system.total_swap();
    let swap = (total_swap > 0).then(|| Swap {
        total: total_swap / 1024,
        free: (total_swap - state.system.used_swap()) / 1024,
        cached: 0,
    });

    // Volume labels are not identifiers: APFS commonly gives multiple mounts
    // the same name. Preserve every filesystem and qualify duplicate labels
    // with their mount point so frontend keys remain unique without dropping
    // real rows.
    let mut name_counts = std::collections::HashMap::new();
    for disk in state.disks.list() {
        *name_counts.entry(disk.name().to_owned()).or_insert(0usize) += 1;
    }
    let keyed_disks: Vec<_> = state
        .disks
        .list()
        .iter()
        .map(|disk| {
            let name = disk.name().to_string_lossy().into_owned();
            let mount = disk.mount_point().to_string_lossy().into_owned();
            let id = if name.is_empty() {
                mount.clone()
            } else if name_counts.get(disk.name()).copied().unwrap_or(0) > 1 {
                format!("{name} ({mount})")
            } else {
                name
            };
            (disk, id)
        })
        .collect();

    let disks: Vec<Disk> = keyed_disks
        .iter()
        .map(|(d, id)| {
            let total_kb = d.total_space() / 1024;
            let avail_kb = d.available_space() / 1024;
            let used_kb = total_kb.saturating_sub(avail_kb);
            Disk {
                path: id.clone(),
                mount: d.mount_point().to_string_lossy().into_owned(),
                fs_type: Some(d.file_system().to_string_lossy().into_owned()),
                used_percent: disk_used_percent(used_kb, total_kb),
                used: used_kb,
                size: total_kb,
                avail: avail_kb,
                ..Disk::default()
            }
        })
        .collect();

    let diskio: Vec<DiskIoPiece> = keyed_disks
        .iter()
        .map(|(d, id)| {
            let usage = d.usage();
            DiskIoPiece {
                dev: id.clone(),
                // Genuinely cumulative (sysinfo's total_*_bytes), unlike the
                // Windows script path's diskio which is a rate mislabeled as
                // sectors (see ServerStatus.diskio's doc comment) — this
                // native path doesn't inherit that mismatch
                sectors_read: (usage.total_read_bytes / 512) as i64,
                sectors_write: (usage.total_written_bytes / 512) as i64,
            }
        })
        .collect();

    let net: Vec<NetIface> = state
        .networks
        .list()
        .iter()
        .map(|(name, data)| NetIface {
            device: name.clone(),
            rx_bytes: data.total_received(),
            tx_bytes: data.total_transmitted(),
        })
        .collect();

    let mut temps = Temperatures::default();
    for component in state.components.list() {
        if let Some(t) = component.temperature()
            && is_plausible_temp(t as f64)
        {
            temps.0.insert(component.label().to_string(), t as f64);
        }
    }

    ServerStatus {
        cpu,
        cpu_brand: cpu_brand(&state.system),
        mem,
        swap,
        disks,
        diskio,
        net,
        temps,
        uptime: Some(format_uptime(System::uptime())),
        host: System::host_name(),
        sys: System::long_os_version().or_else(System::os_version),
        ..ServerStatus::default()
    }
}

fn disk_used_percent(used: u64, total: u64) -> u32 {
    ((u128::from(used) * 100)
        .checked_div(u128::from(total))
        .unwrap_or(0))
    .min(100) as u32
}

/// `System::uptime()` is raw seconds; format to roughly the same shape
/// `common::parse_uptime` normalizes shell `uptime` output into ("N days,
/// H:MM" / "H:MM") — see `ServerStatus.uptime`'s doc comment: exact string
/// shape isn't guaranteed identical across platforms/sources already, so
/// this doesn't need byte-for-byte parity with the shell-derived format.
fn format_uptime(total_secs: u64) -> String {
    let days = total_secs / 86400;
    let hours = (total_secs % 86400) / 3600;
    let minutes = (total_secs % 3600) / 60;
    if days > 0 {
        format!("{days} days, {hours}:{minutes:02}")
    } else {
        format!("{hours}:{minutes:02}")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sample_produces_plausible_data() {
        let mut state = State::default();
        sample(&mut state); // primes the CPU baseline
        std::thread::sleep(std::time::Duration::from_millis(250));
        let status = sample(&mut state);

        assert!(status.cpu.len() >= 2, "expected a summary row plus at least one core");
        assert_eq!(status.cpu[0].id, "cpu");
        assert!(status.mem.is_some());
        assert!(status.host.is_some());
        // Regression: an earlier version of this backend only covered CPU
        // usage and silently dropped cpu_brand entirely (no script fallback
        // exists post-cutover, so this was a real "CPU (x18)" -> blank
        // regression on every Bsd/Windows agent, not just a missing nicety)
        assert!(!status.cpu_brand.is_empty(), "expected at least one cpu_brand entry");
    }

    #[test]
    fn topology_refresh_suppresses_the_reset_usage_sample() {
        let mut state = State::default();
        sample(&mut state);
        state.primed = true;
        state.cpu_count_hint = 0;

        let refreshed = sample(&mut state);
        assert!(refreshed.cpu.is_empty());

        std::thread::sleep(std::time::Duration::from_millis(250));
        let next = sample(&mut state);
        assert!(!next.cpu.is_empty());
    }

    /// macOS/APFS volumes sharing a container (e.g. "/" and
    /// "/System/Volumes/Data") report identical sysinfo `name()`s — the
    /// frontend keys disk/diskio rows by exactly that value, so a duplicate
    /// breaks the Svelte keyed-each render (real bug hit on a real machine)
    #[test]
    fn disks_and_diskio_have_unique_keys() {
        let mut state = State::default();
        let status = sample(&mut state);

        assert_eq!(status.disks.len(), state.disks.list().len());
        assert_eq!(status.diskio.len(), state.disks.list().len());

        let disk_paths: Vec<&str> = status.disks.iter().map(|d| d.path.as_str()).collect();
        let mut unique_paths = disk_paths.clone();
        unique_paths.sort();
        unique_paths.dedup();
        assert_eq!(disk_paths.len(), unique_paths.len(), "duplicate disk path: {disk_paths:?}");

        let devs: Vec<&str> = status.diskio.iter().map(|d| d.dev.as_str()).collect();
        let mut unique_devs = devs.clone();
        unique_devs.sort();
        unique_devs.dedup();
        assert_eq!(devs.len(), unique_devs.len(), "duplicate diskio dev: {devs:?}");
    }

    #[test]
    fn format_uptime_shapes() {
        assert_eq!(format_uptime(90), "0:01");
        assert_eq!(format_uptime(3661), "1:01");
        assert_eq!(format_uptime(90000), "1 days, 1:00");
    }

    #[test]
    fn disk_percent_handles_zero_and_large_totals() {
        assert_eq!(disk_used_percent(0, 0), 0);
        assert_eq!(disk_used_percent(50, 100), 50);
        assert_eq!(disk_used_percent(u64::MAX, u64::MAX), 100);
    }
}
