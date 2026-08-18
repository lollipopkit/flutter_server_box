//! Linux backend: reads the same procfs/sysfs paths the shared script's
//! `cat` commands read (see `sbm_parser::commands::LINUX`), directly via
//! `std::fs::read_to_string`, and feeds the output into
//! `sbm_parser::linux::parse_*`/`sbm_parser::common::parse_*` unmodified —
//! those functions are pure text-in/struct-out and don't care whether the
//! text came from a shell pipeline or a direct file read. Zero extra
//! dependencies.
//!
//! Two fields still shell out to a single, targeted command instead of
//! reading a file: `uptime` (no simple procfs equivalent that already
//! matches `common::parse_uptime`'s expected shape — `/proc/uptime` is a raw
//! seconds count, not the `uptime` command's structured text) and `disks`
//! (filesystem usage isn't in one clean procfs file — `df -k` is the
//! existing fallback path `sbm_parser::linux::parse_disk` already handles).
//! These are still a big win over the old approach: one direct process
//! spawn per field instead of building/writing/executing a whole generated
//! multi-command script and splitting its output by `SrvBoxSep` markers.
//!
//! `batteries`/`sensors`/`nvidia`/`amd`/`disk_smart` are intentionally left
//! empty here — those stay on the shared script path (see monitor's
//! extended-cycle collection), which is the only source for them.

use sbm_parser::types::Disk;
use sbm_parser::{common, linux, ServerStatus};
use std::fs;
use std::path::PathBuf;
use std::process::Command;

fn read(path: &str) -> String {
    fs::read_to_string(path).unwrap_or_default()
}

/// Run one targeted command and return stdout, empty on any failure —
/// matching the shared script's tolerance (a failed segment parses to empty)
fn run(cmd: &str, args: &[&str]) -> String {
    Command::new(cmd)
        .args(args)
        .output()
        .ok()
        .filter(|o| o.status.success())
        .map(|o| String::from_utf8_lossy(&o.stdout).into_owned())
        .unwrap_or_default()
}

/// Concatenation of every `/etc/*-release` file, filtered to the
/// `PRETTY_NAME=...` line — mirrors `cat /etc/*-release | grep ^PRETTY_NAME`.
/// `parse_sys_version` requires exactly this one line (it errors on more
/// than one `=` in its input), so the filter isn't optional here.
fn release_pretty_name() -> String {
    let mut all = String::new();
    if let Ok(entries) = fs::read_dir("/etc") {
        for entry in entries.flatten() {
            let name = entry.file_name();
            if name.to_string_lossy().ends_with("-release") {
                all.push_str(&read(&entry.path().to_string_lossy()));
                all.push('\n');
            }
        }
    }
    all.lines().find(|l| l.starts_with("PRETTY_NAME")).unwrap_or("").to_string()
}

/// `/sys/class/thermal/thermal_zone*/{type,temp}`, sorted by zone directory
/// name (matches shell glob order). Returns line-parallel (types, values)
/// blocks as `linux::parse_temps` expects — one line always appended to both
/// per zone, even on a read failure, so the two stay index-aligned.
fn thermal_zones() -> (String, String) {
    let mut zones: Vec<PathBuf> = fs::read_dir("/sys/class/thermal")
        .into_iter()
        .flatten()
        .flatten()
        .map(|e| e.path())
        .filter(|p| {
            p.file_name().and_then(|n| n.to_str()).is_some_and(|n| n.starts_with("thermal_zone"))
        })
        .collect();
    zones.sort();

    let mut types = String::new();
    let mut values = String::new();
    for zone in &zones {
        types.push_str(read(&zone.join("type").to_string_lossy()).trim());
        types.push('\n');
        values.push_str(read(&zone.join("temp").to_string_lossy()).trim());
        values.push('\n');
    }
    (types, values)
}

/// `MemTotal` from `/proc/meminfo`, in bytes (the file reports kibibytes).
///
/// Parsed here rather than going through `sbm_parser::linux::parse_mem`
/// because callers of `sbm_native::total_memory` want this before any
/// sampling state exists, and the one field is trivial to read directly.
pub fn total_memory() -> Option<u64> {
    read("/proc/meminfo")
        .lines()
        .find_map(|line| line.strip_prefix("MemTotal:"))
        .and_then(|rest| rest.split_whitespace().next()?.parse::<u64>().ok())
        .map(|kib| kib * 1024)
}

pub fn sample() -> ServerStatus {
    let mem_raw = read("/proc/meminfo");
    let (temp_types, temp_values) = thermal_zones();
    let disk_raw = run("df", &["-k"]);
    // No lsblk JSON attempt here (keeps this path to a single subprocess);
    // `parse_disk` falls back to the `df -k` table shape it already supports
    let disks: Vec<Disk> = linux::parse_disk(&disk_raw);

    ServerStatus {
        cpu: linux::parse_cpu(&read("/proc/stat")),
        cpu_brand: linux::parse_cpu_brand(&read("/proc/cpuinfo")),
        mem: linux::parse_mem(&mem_raw),
        swap: linux::parse_swap(&mem_raw),
        disks,
        net: linux::parse_net(&read("/proc/net/dev")),
        temps: linux::parse_temps(&temp_types, &temp_values, 1000.0),
        conn: linux::parse_conn(&read("/proc/net/snmp")),
        uptime: common::parse_uptime(&run("uptime", &[])),
        sys: common::parse_sys_version(&release_pretty_name()),
        host: common::parse_hostname(&read("/etc/hostname")),
        diskio: linux::parse_diskio(&read("/proc/diskstats")),
        ..ServerStatus::default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Reads the real host's procfs — can't assert exact values (that's
    // sbm_parser's fixture-based job), only that the native path actually
    // produces plausible data end to end on a real Linux machine.
    #[test]
    fn sample_produces_plausible_data() {
        let status = sample();
        assert!(!status.cpu.is_empty(), "expected at least a 'cpu' summary row");
        assert!(status.mem.is_some());
        assert!(status.host.is_some());
        assert!(!status.net.is_empty(), "expected at least one network interface");
    }
}
