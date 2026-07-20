//! Native (syscall/procfs) status sampling for monitor's local-only
//! collection path.
//!
//! This crate exists specifically because monitor runs directly on the
//! machine it monitors (never over SSH — that's the app's job, and the app
//! is the reason `sbm_parser`'s script-generation + text-parsing approach
//! exists at all). Where the app has no choice but to shell out and parse
//! text, monitor can read the same data straight from the OS. This crate is
//! never used by the app/FFI side; only `monitor` depends on it.
//!
//! Per-platform backends live as `#[cfg(target_os = ...)]` submodules within
//! this one crate rather than as separate crates — "multi-platform support"
//! is an internal concern of the native-sampling layer, mirroring how
//! `sbm_parser::commands` keeps one command table per `SystemType` in a
//! single crate rather than splitting per platform.
//!
//! `sample()` returns a `sbm_parser::ServerStatus` — the same shape the
//! script-based path parses into — filling only the fields this crate's
//! backend covers; callers merge in whatever else they still need (GPU,
//! battery, sensors, SMART) from other sources. Reusing the shared type
//! means `monitor`'s `adapt_status` doesn't care which source populated
//! `ServerStatus`.

use sbm_parser::{ServerStatus, SystemType};

#[cfg(target_os = "linux")]
mod linux;

#[cfg(any(target_os = "macos", target_os = "windows"))]
mod sysinfo_backend;

/// Cross-cycle state a backend needs to compute deltas (CPU usage, network
/// throughput, ...). Owned and passed by the caller (mirrors monitor's
/// existing `prev_cpu: &mut Option<CpuCore>` pattern) rather than a hidden
/// global — easier to test, no surprises from process-wide static state.
#[derive(Default)]
pub struct NativeState {
    #[cfg(any(target_os = "macos", target_os = "windows"))]
    sysinfo: Option<sysinfo_backend::State>,
}

impl NativeState {
    pub fn new() -> Self {
        Self::default()
    }
}

/// Sample whatever this platform's native backend can cover. Fields the
/// backend doesn't populate are left at their `Default` (empty/`None`) —
/// exactly like a missing command segment in the script-based path, so
/// downstream merging code doesn't need to distinguish the two sources.
pub fn sample(state: &mut NativeState, system: SystemType) -> ServerStatus {
    match system {
        #[cfg(target_os = "linux")]
        SystemType::Linux => linux::sample(),
        #[cfg(any(target_os = "macos", target_os = "windows"))]
        SystemType::Bsd | SystemType::Windows => {
            sysinfo_backend::sample(state.sysinfo.get_or_insert_with(Default::default))
        }
        #[allow(unreachable_patterns)]
        _ => ServerStatus::default(),
    }
}
