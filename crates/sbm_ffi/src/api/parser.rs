//! Shared parser FFI (ADR 0001 Phase 2)
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

/// Parse all output of one collection round, returning `ServerStatus` JSON.
/// `system`: "linux" | "bsd" | "windows"; see `ParseOptions` for `temp_divisor`.
/// Async: runs on the Rust thread pool without blocking the UI isolate
pub fn parse_status_json(
    system: String,
    raw: HashMap<String, String>,
    temp_divisor: f64,
) -> Result<String, String> {
    let system = parse_system(&system).ok_or_else(|| format!("unknown system: {}", system))?;
    let status = sbm_parser::parse_status_opts(
        system,
        &raw,
        sbm_parser::ParseOptions { temp_divisor },
    );
    serde_json::to_string(&status).map_err(|e| e.to_string())
}

/// Windows WMI double-sample net speed delta, returning `[{name, rx, tx}]` JSON (bytes/sec)
#[flutter_rust_bridge::frb(sync)]
pub fn parse_windows_net_speed_json(raw: String) -> String {
    let speeds: Vec<_> = sbm_parser::windows::parse_net_speed(&raw)
        .into_iter()
        .map(|(name, rx, tx)| serde_json::json!({ "name": name, "rx": rx, "tx": tx }))
        .collect();
    serde_json::Value::Array(speeds).to_string()
}

/// Per-platform collection command manifest (the app's script generation derives from it, versioned with the parsers)
#[flutter_rust_bridge::frb(sync)]
pub fn command_specs(system: String) -> Result<Vec<CommandSpec>, String> {
    let system = parse_system(&system).ok_or_else(|| format!("unknown system: {}", system))?;
    Ok(sbm_parser::commands::commands(system)
        .iter()
        .map(|spec| CommandSpec { key: spec.key.to_string(), cmd: spec.cmd.to_string() })
        .collect())
}

/// Output segment separator (`SrvBoxSep`)
#[flutter_rust_bridge::frb(sync)]
pub fn separator() -> String {
    sbm_parser::commands::SEPARATOR.to_string()
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}
