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
///
/// Keep it on one thread for its whole life: on Windows the sysinfo backend's
/// components are WMI COM objects bound to the thread that created them, and
/// refreshing them from another thread once that one has exited faults the
/// process. The monitor gives it a thread of its own (`NativeSampler`).
#[derive(Default)]
pub struct NativeState {
    #[cfg(any(target_os = "macos", target_os = "windows"))]
    sysinfo: Option<sysinfo_backend::State>,
    /// `lsblk`'s output as [`refresh_block_devices`] last read it: the device
    /// tree each sample's `df` is merged into.
    #[cfg(target_os = "linux")]
    block_devices: String,
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
pub fn sample(#[allow(unused_variables)] state: &mut NativeState, system: SystemType) -> ServerStatus {
    match system {
        #[cfg(target_os = "linux")]
        SystemType::Linux => linux::sample(&state.block_devices),
        #[cfg(any(target_os = "macos", target_os = "windows"))]
        SystemType::Bsd | SystemType::Windows => {
            match &mut state.sysinfo {
                Some(s) => sysinfo_backend::sample(s),
                slot => sysinfo_backend::State::new()
                    .map(|s| sysinfo_backend::sample(slot.insert(s)))
                    .unwrap_or_default(),
            }
        }
        #[allow(unreachable_patterns)]
        _ => ServerStatus::default(),
    }
}

/// Processes using the GPU under WSL2 (`linux::dxg_processes`); none
/// elsewhere, where the GPU's own tool lists them.
pub fn wsl_gpu_processes() -> Vec<sbm_parser::types::GpuMemProcess> {
    #[cfg(target_os = "linux")]
    if linux::wsl() {
        return linux::dxg_processes();
    }
    Vec::new()
}

/// Reads the block devices again: which there are, how they nest, their
/// filesystem types and UUIDs, and those nothing is mounted from — what `df`
/// cannot say (#1669). Each [`sample`] merges it with a fresh `df`, which has
/// the numbers.
///
/// Separate from [`sample`] so the caller can keep it to its slower cycle: it
/// changes when a disk is added, not between samples. `lsblk` reads udev's
/// database and sysfs, never the disk, but where libudev is missing a root
/// `lsblk` reads each device's superblock instead — and that cycle is the one
/// that pauses while nobody is looking. Linux only; elsewhere a no-op.
pub fn refresh_block_devices(#[allow(unused_variables)] state: &mut NativeState) {
    #[cfg(target_os = "linux")]
    {
        state.block_devices = linux::block_devices();
    }
}

/// Total physical memory in bytes, or `None` when this platform has no
/// backend here or the read failed.
///
/// Separate from [`sample`] because the caller needs it before any sampling
/// happens: monitor sizes its buffer/session limits off it at startup (see
/// `RemoteAccessConfig`), and running a whole sample cycle just to read one
/// constant would be wasteful and would need a `NativeState` that doesn't
/// exist yet. The value doesn't change while the process runs, so callers
/// read it once.
pub fn total_memory() -> Option<u64> {
    #[cfg(target_os = "linux")]
    {
        linux::total_memory()
    }
    #[cfg(any(target_os = "macos", target_os = "windows"))]
    {
        sysinfo_backend::total_memory()
    }
    #[cfg(not(any(target_os = "linux", target_os = "macos", target_os = "windows")))]
    {
        None
    }
}

#[cfg(test)]
mod tests {
    /// Only asserts plausibility, not a value: this reads the real host.
    /// Platforms without a backend legitimately return `None`.
    #[test]
    fn total_memory_is_plausible_or_absent() {
        if let Some(total) = super::total_memory() {
            assert!(
                total >= 64 * 1024 * 1024,
                "implausibly small total memory: {total}"
            );
        }
    }
}
