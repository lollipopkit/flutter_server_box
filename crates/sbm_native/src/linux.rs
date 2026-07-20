//! Linux backend: reads the same procfs/sysfs paths the shared script's
//! `cat` commands read (see `sbm_parser::commands::LINUX`), directly via
//! `std::fs::read_to_string`, and feeds the output into
//! `sbm_parser::linux::parse_*` unmodified — those functions are pure
//! text-in/struct-out and don't care whether the text came from a shell
//! pipeline or a direct file read. Zero extra dependencies.
//!
//! Filled in by a later step; returns an empty status for now.

use sbm_parser::ServerStatus;

pub fn sample() -> ServerStatus {
    ServerStatus::default()
}
