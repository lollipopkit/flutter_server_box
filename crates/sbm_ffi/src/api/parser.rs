//! Shared parser FFI
//!
//! Boundary contract: input is a map of command key → raw output, output is
//! `sbm_parser`'s serde JSON. The Dart side builds its existing model classes
//! from it and can run side-by-side with the Dart parsers during migration.
//! Parsing is pure; the FFI holds no state.

use std::collections::HashMap;

/// Collection command, single source of truth shared with the app's script generation
pub struct CommandSpec {
    pub key: String,
    pub cmd: String,
}

fn parse_system(system: &str) -> Option<sbm_parser::SystemType> {
    match system {
        "linux" => Some(sbm_parser::SystemType::Linux),
        "bsd" => Some(sbm_parser::SystemType::Bsd),
        "windows" => Some(sbm_parser::SystemType::Windows),
        _ => None,
    }
}

/// Shared by the script FFI module; not exposed over the bridge
#[flutter_rust_bridge::frb(ignore)]
pub(crate) fn parse_system_or_err(system: &str) -> Result<sbm_parser::SystemType, String> {
    parse_system(system).ok_or_else(|| format!("unknown system: {system}"))
}

/// Parse all output of one collection round, returning `ServerStatus` JSON.
/// `system`: "linux" | "bsd" | "windows"; see `ParseOptions` for `temp_divisor`.
///
/// Beside the status, `disk_used` and `disk_size` (KiB): the disk total, by
/// `sbm_parser::types::disk_usage` — the one the monitor agent stores — with
/// network filesystems in it only when `count_network`.
/// Async: runs on the Rust thread pool without blocking the UI isolate
pub fn parse_status_json(
    system: String,
    raw: HashMap<String, String>,
    temp_divisor: f64,
    count_network: bool,
) -> Result<String, String> {
    let system = parse_system(&system).ok_or_else(|| format!("unknown system: {}", system))?;
    let status = sbm_parser::parse_status_opts(
        system,
        &raw,
        sbm_parser::ParseOptions { temp_divisor },
    );
    let (disk_used, disk_size) = sbm_parser::types::disk_usage(&status.disks, count_network);
    let mut json = serde_json::to_value(&status).map_err(|e| e.to_string())?;
    json["disk_used"] = disk_used.into();
    json["disk_size"] = disk_size.into();
    Ok(json.to_string())
}

/// Per-platform collection command manifest (the app's script generation derives from it, versioned with the parsers)
/// The probe that tells a Unix server's system (`sbm_parser::system`).
#[flutter_rust_bridge::frb(sync)]
pub fn system_probe_uname() -> String {
    sbm_parser::system::UNAME_PROBE.to_owned()
}

/// The probe that tells Windows, run when `uname` said nothing it knows.
#[flutter_rust_bridge::frb(sync)]
pub fn system_probe_ver() -> String {
    sbm_parser::system::VER_PROBE.to_owned()
}

/// What `uname -a` said, as `linux` / `bsd`; `None` when it says neither.
#[flutter_rust_bridge::frb(sync)]
pub fn system_from_uname(output: String) -> Option<String> {
    sbm_parser::system::from_uname(&output).map(system_name)
}

/// `windows` when `ver` answered as Windows does.
#[flutter_rust_bridge::frb(sync)]
pub fn system_from_ver(output: String) -> Option<String> {
    sbm_parser::system::from_ver(&output).map(system_name)
}

fn system_name(system: sbm_parser::SystemType) -> String {
    match system {
        sbm_parser::SystemType::Linux => "linux",
        sbm_parser::SystemType::Bsd => "bsd",
        sbm_parser::SystemType::Windows => "windows",
    }
    .to_owned()
}

/// The seconds a status's `uptime` string says (`sbm_parser::common::uptime_seconds`);
/// `None` when it cannot be read.
#[flutter_rust_bridge::frb(sync)]
pub fn uptime_seconds(formatted: String) -> Option<u64> {
    sbm_parser::common::uptime_seconds(&formatted)
}

#[flutter_rust_bridge::frb(sync)]
pub fn command_specs(system: String) -> Result<Vec<CommandSpec>, String> {
    let system = parse_system(&system).ok_or_else(|| format!("unknown system: {}", system))?;
    Ok(sbm_parser::commands::commands(system)
        .iter()
        .map(|spec| CommandSpec { key: spec.key.to_string(), cmd: spec.cmd.to_string() })
        .collect())
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
