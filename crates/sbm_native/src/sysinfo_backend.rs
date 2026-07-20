//! macOS/BSD + Windows backend, built on the `sysinfo` crate. Absorbs and
//! generalizes the pattern from the now-removed `monitor::macos_cpu`
//! (per-core CPU only) to cover memory/swap/disks/network/uptime/host/sys.
//!
//! Filled in by a later step; returns an empty status for now.

use sbm_parser::ServerStatus;

#[derive(Default)]
pub struct State {
    // sysinfo::System / Disks / Networks handles + previous samples for
    // delta computation, added when this backend is implemented
}

pub fn sample(_state: &mut State) -> ServerStatus {
    ServerStatus::default()
}
