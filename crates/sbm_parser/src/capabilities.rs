//! Explicit per-platform `ServerStatus` field support, mechanically derived
//! from the command manifest (`commands::commands(system)`) wherever a field
//! maps 1:1 to a command key — so adding/removing a command automatically
//! keeps this matrix in sync, instead of a hand-maintained table silently
//! drifting out of date.
//!
//! This reflects command-manifest presence, not parser-dispatch correctness:
//! a field whose command exists but whose output the dispatch in `lib.rs`
//! doesn't consume yet (a "dead command" bug, see `windows::parse_sensors`/
//! `parse_disk_smart`) is still reported here as supported — capabilities
//! answers "does this platform have a way to collect this," not "is today's
//! dispatch code wired up correctly."

use crate::{commands, SystemType};

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum FieldSupport {
    /// Populated whenever the command succeeds — software-only data, no
    /// optional hardware involved
    Supported,
    /// No command produces this field's raw segment on this platform at all
    NotImplemented,
    /// Command exists and is parsed, but naturally empties out when the
    /// underlying hardware/tool isn't present (battery, GPU, SMART, sensors)
    HardwareDependent,
}

#[derive(Debug, Clone, Copy, serde::Serialize, serde::Deserialize)]
pub struct Capabilities {
    pub cpu: FieldSupport,
    pub cpu_brand: FieldSupport,
    pub mem: FieldSupport,
    pub swap: FieldSupport,
    pub disks: FieldSupport,
    pub net: FieldSupport,
    pub temps: FieldSupport,
    pub conn: FieldSupport,
    pub uptime: FieldSupport,
    pub sys: FieldSupport,
    pub host: FieldSupport,
    pub diskio: FieldSupport,
    pub batteries: FieldSupport,
    pub sensors: FieldSupport,
    pub nvidia: FieldSupport,
    pub amd: FieldSupport,
    pub disk_smart: FieldSupport,
}

fn has_command(system: SystemType, key: &str) -> bool {
    commands::commands(system).iter().any(|c| c.key == key)
}

/// `Supported` if any of `keys` exists in `system`'s command table, else `NotImplemented`
fn from_commands(system: SystemType, keys: &[&str]) -> FieldSupport {
    if keys.iter().any(|k| has_command(system, k)) {
        FieldSupport::Supported
    } else {
        FieldSupport::NotImplemented
    }
}

/// Same as `from_commands`, but a present command downgrades to `HardwareDependent`
fn hw_from_commands(system: SystemType, keys: &[&str]) -> FieldSupport {
    match from_commands(system, keys) {
        FieldSupport::Supported => FieldSupport::HardwareDependent,
        other => other,
    }
}

pub fn capabilities(system: SystemType) -> Capabilities {
    Capabilities {
        cpu: from_commands(system, &[commands::CPU]),
        cpu_brand: from_commands(system, &[commands::CPU_BRAND]),
        mem: from_commands(system, &[commands::MEM]),
        // Bsd/Windows have no dedicated swap command or parser at all (their
        // MEM command's output carries no swap fields) — command-table
        // presence can't express this, since MEM itself exists everywhere
        swap: match system {
            SystemType::Linux => FieldSupport::Supported,
            SystemType::Bsd | SystemType::Windows => FieldSupport::NotImplemented,
        },
        disks: from_commands(system, &[commands::DISK]),
        net: from_commands(system, &[commands::NET]),
        temps: hw_from_commands(system, &[commands::TEMP_TYPE, commands::TEMP_VAL, commands::TEMP]),
        conn: from_commands(system, &[commands::CONN]),
        uptime: from_commands(system, &[commands::UPTIME]),
        sys: from_commands(system, &[commands::SYS]),
        host: from_commands(system, &[commands::HOST]),
        diskio: from_commands(system, &[commands::DISKIO]),
        batteries: hw_from_commands(system, &[commands::BATTERY]),
        sensors: hw_from_commands(system, &[commands::SENSORS]),
        nvidia: hw_from_commands(system, &[commands::NVIDIA]),
        amd: hw_from_commands(system, &[commands::AMD]),
        disk_smart: hw_from_commands(system, &[commands::DISK_SMART]),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use FieldSupport::{HardwareDependent as Hw, NotImplemented as No, Supported as Yes};

    #[test]
    fn linux_matrix() {
        let c = capabilities(SystemType::Linux);
        assert_eq!(c.cpu, Yes);
        assert_eq!(c.cpu_brand, Yes);
        assert_eq!(c.mem, Yes);
        assert_eq!(c.swap, Yes);
        assert_eq!(c.disks, Yes);
        assert_eq!(c.net, Yes);
        assert_eq!(c.temps, Hw);
        assert_eq!(c.conn, Yes);
        assert_eq!(c.uptime, Yes);
        assert_eq!(c.sys, Yes);
        assert_eq!(c.host, Yes);
        assert_eq!(c.diskio, Yes);
        assert_eq!(c.batteries, Hw);
        assert_eq!(c.sensors, Hw);
        assert_eq!(c.nvidia, Hw);
        assert_eq!(c.amd, Hw);
        assert_eq!(c.disk_smart, Hw);
    }

    #[test]
    fn bsd_matrix() {
        let c = capabilities(SystemType::Bsd);
        assert_eq!(c.cpu, Yes);
        assert_eq!(c.cpu_brand, Yes);
        assert_eq!(c.mem, Yes);
        assert_eq!(c.swap, No);
        assert_eq!(c.disks, Yes);
        assert_eq!(c.net, Yes);
        assert_eq!(c.temps, No);
        assert_eq!(c.conn, No);
        assert_eq!(c.uptime, Yes);
        assert_eq!(c.sys, Yes);
        assert_eq!(c.host, Yes);
        assert_eq!(c.diskio, No);
        assert_eq!(c.batteries, No);
        assert_eq!(c.sensors, No);
        assert_eq!(c.nvidia, No);
        assert_eq!(c.amd, No);
        assert_eq!(c.disk_smart, No);
    }

    #[test]
    fn windows_matrix() {
        let c = capabilities(SystemType::Windows);
        assert_eq!(c.cpu, Yes);
        assert_eq!(c.cpu_brand, Yes);
        assert_eq!(c.mem, Yes);
        assert_eq!(c.swap, No);
        assert_eq!(c.disks, Yes);
        assert_eq!(c.net, Yes);
        assert_eq!(c.temps, Hw);
        assert_eq!(c.conn, Yes);
        assert_eq!(c.uptime, Yes);
        assert_eq!(c.sys, Yes);
        assert_eq!(c.host, Yes);
        assert_eq!(c.diskio, Yes);
        assert_eq!(c.batteries, Hw);
        // Command exists (Win32_TemperatureProbe / Get-StorageReliabilityCounter);
        // whether the dispatch actually consumes it is a separate concern (see
        // module docs) — fixed in the windows::parse_sensors/parse_disk_smart change
        assert_eq!(c.sensors, Hw);
        assert_eq!(c.nvidia, Hw);
        assert_eq!(c.amd, Hw);
        assert_eq!(c.disk_smart, Hw);
    }
}
