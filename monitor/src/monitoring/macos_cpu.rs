//! Native per-core CPU sampling on macOS.
//!
//! `top` (the shared BSD manifest command) gives an aggregate percentage
//! only — macOS exposes no shell command for real per-core data. htop's own
//! macOS backend calls the Mach `host_processor_info` kernel API directly;
//! we get the same data through `sysinfo`, which wraps that call, rather
//! than hand-rolling unsafe FFI against the raw Mach interface.
//!
//! This bypasses the shared script/parser path for the CPU segment only,
//! when the monitor itself runs natively on macOS (never over SSH — the app
//! has no way to invoke a kernel API on a remote host, so it keeps using the
//! shared parser's replicated-aggregate reading for macOS servers).

use sbm_parser::types::CpuCore;
use std::sync::Mutex;
use sysinfo::System;

/// One scale for every synthetic reading, giving 0.01% precision. The
/// resulting CpuCore uses the same used/total tick convention as every other
/// platform's real counters (see `adapt_cpu`'s doc comment) so it flows
/// through the existing aggregation/storage code unchanged.
const SCALE: u64 = 10_000;

static SYSTEM: Mutex<Option<System>> = Mutex::new(None);

/// Sample real per-core CPU usage. Returns `None` on the first call (sysinfo
/// needs two samples to compute a delta) and on non-macOS platforms.
pub fn sample() -> Option<Vec<CpuCore>> {
    let mut guard = SYSTEM.lock().unwrap_or_else(|e| e.into_inner());
    let first_call = guard.is_none();
    let sys = guard.get_or_insert_with(System::new);
    sys.refresh_cpu_usage();
    if first_call {
        // sysinfo's first reading has no prior sample to diff against
        return None;
    }

    let per_core_pct: Vec<f64> = sys.cpus().iter().map(|c| c.cpu_usage().clamp(0.0, 100.0) as f64).collect();
    if per_core_pct.is_empty() {
        return None;
    }

    let to_core = |id: String, pct: f64| {
        let used = (SCALE as f64 * pct / 100.0).round() as u64;
        CpuCore {
            id,
            user: used,
            sys: 0,
            nice: 0,
            idle: SCALE.saturating_sub(used),
            iowait: 0,
            irq: 0,
            softirq: 0,
        }
    };

    // A "cpu" summary row (mean of all cores) alongside "cpu0".."cpuN-1" rows
    // matches Linux's /proc/stat convention, which the rest of the pipeline
    // (summary_core, per-core filtering) already assumes: without it, the
    // aggregate cpu_usage figure would fall back to core 0's reading alone
    // instead of a whole-machine average.
    let mean = per_core_pct.iter().sum::<f64>() / per_core_pct.len() as f64;
    let mut cores = vec![to_core("cpu".to_string(), mean)];
    cores.extend(
        per_core_pct
            .into_iter()
            .enumerate()
            .map(|(i, pct)| to_core(format!("cpu{i}"), pct)),
    );
    Some(cores)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn first_call_returns_none() {
        // Fresh module state (test binary, single process): the very first
        // sample has no prior reading to diff against
        assert!(sample().is_none());
    }

    #[test]
    fn second_call_returns_real_core_data() {
        sample();
        std::thread::sleep(std::time::Duration::from_millis(250));
        let cores = sample().expect("second sample should have a delta");
        assert!(cores.len() >= 2, "expected a summary row plus at least one core");
        assert_eq!(cores[0].id, "cpu");
        assert_eq!(cores[1].id, "cpu0");
        // total() must equal SCALE for every row (idle = SCALE - used)
        for c in &cores {
            assert_eq!(c.total(), SCALE);
        }
    }
}
