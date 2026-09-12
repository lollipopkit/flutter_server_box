//! What a remote host must not be able to do to the process parsing its output.
//!
//! Every input here is text a server sent back. In the app the parser runs
//! in-process over FFI, so a panic or an unbounded allocation is not an error a
//! caller can catch — it is the app disappearing. None of these need a hostile
//! server either: each is also a shape a broken tool or a corrupt reading
//! produces.

use sbm_parser::types::MAX_CPU_CORES;
use sbm_parser::{bsd, linux, windows};

/// `Size` is rejected at zero, but anything under a KiB floors to zero after
/// the conversion and used to divide by it. Integer division by zero panics in
/// release as well, so this was not gated on debug assertions.
#[test]
fn a_volume_smaller_than_a_kib_is_not_a_division_by_zero() {
    let disks = windows::parse_disks(
        r#"[{"DeviceID":"C:","Size":512,"FreeSpace":0,"FileSystem":"NTFS"}]"#,
    );
    assert!(disks.is_empty(), "a sub-KiB volume is not a reading");
}

/// The same query on a real volume still reports one.
#[test]
fn an_ordinary_volume_still_parses() {
    let disks = windows::parse_disks(
        r#"[{"DeviceID":"C:","Size":107374182400,"FreeSpace":53687091200,"FileSystem":"NTFS"}]"#,
    );
    assert_eq!(disks.len(), 1);
    assert_eq!(disks[0].used_percent, 50);
}

/// `NumberOfLogicalProcessors` decides how many core structs to allocate, each
/// with a heap-allocated id. Unbounded, this ran until the process was killed.
#[test]
fn an_absurd_logical_processor_count_is_refused() {
    let cores = windows::parse_cpu(
        r#"[{"LoadPercentage":50,"NumberOfCores":1,"NumberOfLogicalProcessors":100000000000}]"#,
        &[],
    );
    assert!(cores.is_empty(), "a count no machine has is a broken query");
}

/// A second processor entry must still be read after a broken one, and its
/// cores must be numbered as though the broken entry contributed nothing.
#[test]
fn a_broken_processor_entry_does_not_take_the_others_with_it() {
    let cores = windows::parse_cpu(
        r#"[{"LoadPercentage":50,"NumberOfCores":1,"NumberOfLogicalProcessors":100000000000},
            {"LoadPercentage":50,"NumberOfCores":2,"NumberOfLogicalProcessors":2}]"#,
        &[],
    );
    let ids: Vec<&str> = cores.iter().map(|c| c.id.as_str()).collect();
    assert_eq!(ids, ["cpu", "cpu0", "cpu1"]);
}

/// A bound on one entry is not a bound on the reply: entries each well inside
/// it still add up. 100 sockets of 128 threads is not a machine, and every
/// core allocated carries a heap-allocated id.
#[test]
fn processor_entries_cannot_add_up_past_the_bound() {
    let entry = r#"{"LoadPercentage":50,"NumberOfCores":64,"NumberOfLogicalProcessors":128}"#;
    let raw = format!("[{}]", [entry; 100].join(","));

    let cores = windows::parse_cpu(&raw, &[]);
    // The summary row is not one of the machine's cores.
    let per_core = cores.len() as u64 - 1;
    assert!(
        per_core <= MAX_CPU_CORES,
        "allocated {per_core} cores, bound is {MAX_CPU_CORES}"
    );
    // 32 entries of 128 reach the bound exactly; the 33rd would pass it.
    assert_eq!(per_core, MAX_CPU_CORES);
}

/// An entry reporting no logical processors is a real answer for a socket that
/// is present and unpopulated, and contributes nothing rather than stopping.
#[test]
fn a_zero_logical_entry_is_not_a_broken_one() {
    let cores = windows::parse_cpu(
        r#"[{"LoadPercentage":50,"NumberOfCores":0,"NumberOfLogicalProcessors":0},
            {"LoadPercentage":50,"NumberOfCores":2,"NumberOfLogicalProcessors":2}]"#,
        &[],
    );
    let ids: Vec<&str> = cores.iter().map(|c| c.id.as_str()).collect();
    assert_eq!(ids, ["cpu", "cpu0", "cpu1"]);
}

/// The BSD twin: `sysctl -n hw.ncpu` arrives as a bare integer and is
/// replicated into that many pseudo-cores.
#[test]
fn an_absurd_bsd_core_count_falls_back_to_one_core() {
    let cores = bsd::parse_cpu("CPU usage: 14.70% user, 12.76% sys, 72.52% idle\n99999999999\n");
    assert_eq!(cores.len(), 1);
    assert_eq!(cores[0].id, "cpu0");
}

/// A plausible count is still honoured.
#[test]
fn a_real_bsd_core_count_is_still_honoured() {
    let cores = bsd::parse_cpu("CPU usage: 14.70% user, 12.76% sys, 72.52% idle\n10\n");
    assert_eq!(cores.len(), 10);
}

/// `df`'s size column was split one *byte* from the end to read its unit, which
/// lands inside a multi-byte character and panics.
#[test]
fn a_multi_byte_character_in_a_df_size_is_not_a_panic() {
    let raw = "Filesystem 1K-blocks Used Available Use% Mounted on\n/dev/sda1 10G° 5 5 50% /\n";
    let disks = linux::parse_disk(raw);
    assert!(disks.is_empty(), "an unreadable size is not a disk");
}

/// The degenerate version: the whole column is one multi-byte character.
#[test]
fn a_df_size_that_is_only_a_multi_byte_character_is_not_a_panic() {
    let raw = "Filesystem 1K-blocks Used Available Use% Mounted on\n/dev/sda1 ° 5 5 50% /\n";
    assert!(linux::parse_disk(raw).is_empty());
}

/// `df -h` suffixes still convert.
#[test]
fn a_df_h_suffix_still_converts() {
    let raw = "Filesystem 1K-blocks Used Available Use% Mounted on\n/dev/sda1 10G 5G 5G 50% /\n";
    let disks = linux::parse_disk(raw);
    assert_eq!(disks.len(), 1);
    assert_eq!(disks[0].size, 10 * 1024 * 1024);
}
