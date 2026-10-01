//! The Dart process-table suite, run against the Rust parser.
//!
//! `test/unit/server/proc_test.dart` is the specification: this file is the
//! same assertions, so that the two implementations can be compared before the
//! Dart one is deleted. The three `script output` tests read the fixtures
//! `test/fixtures/process/*.txt` — the verbatim output of the process
//! function, captured on the platform each is named after — out of the Dart
//! repository rather than a copy kept here, so both suites assert the same
//! bytes and neither can drift by editing its own.
//!
//! TODO: move the fixtures into this crate (and this file's paths with them)
//! when `lib/data/model/server/proc.dart` and its test are deleted. They stay
//! where they are while the Dart parser is still shipped, because a copy is
//! the thing that drifts.
//!
//! Read at runtime, not `include_str!`: `monitor/Dockerfile` builds `sbm_parser`
//! with `crates/` copied in and `monitor/` as the workspace root, so a path
//! pointing outside the crate does not exist in that image.

use std::fs;

use sbm_parser::SystemType;
use sbm_parser::proc::{
    Proc, ProcKillOutcome, ProcLoad, ProcSignal, ProcSortMode, PsParseFailure, PsResult, kill_command,
    kill_outcome, kill_supported, signals_for,
};

/// Where the process function was run. Beside `../../.env`, which
/// `tests/ssh_e2e.rs` already reads from the same place.
const FIXTURES: &str = concat!(env!("CARGO_MANIFEST_DIR"), "/../../test/fixtures/process/");

fn fixture(name: &str) -> String {
    let path = format!("{FIXTURES}{name}");
    fs::read_to_string(&path).unwrap_or_else(|error| panic!("read {path}: {error}"))
}

/// A table read with the defaults the Dart tests use: newest-first by CPU, no
/// previous reading, no sample clock.
fn parse(raw: &str) -> PsResult {
    PsResult::parse(raw, ProcSortMode::Cpu, None, None, 0)
}

fn pids(result: &PsResult) -> Vec<i64> {
    result.procs.iter().map(|proc| proc.pid).collect()
}

fn find(result: &PsResult, pid: i64) -> &Proc {
    result
        .procs
        .iter()
        .find(|proc| proc.pid == pid)
        .unwrap_or_else(|| panic!("no row for pid {pid}"))
}

/// The row whose command line is exactly this. Two `&` arguments, so the
/// lifetime has to say the answer comes from the first.
fn by_command<'a>(result: &'a PsResult, command: &str) -> &'a Proc {
    result
        .procs
        .iter()
        .find(|proc| proc.command == command)
        .unwrap_or_else(|| panic!("no row whose command is {command:?}"))
}

fn bare(pid: i64, command: &str) -> Proc {
    Proc {
        user: None,
        pid,
        ppid: None,
        cpu: None,
        mem: None,
        vsz: None,
        rss: None,
        tty: None,
        stat: None,
        nice: None,
        threads: None,
        start: None,
        start_id: None,
        time: None,
        elapsed_seconds: None,
        read_bytes: None,
        write_bytes: None,
        read_speed: None,
        write_speed: None,
        command: command.to_string(),
        process_name: None,
    }
}

#[test]
fn parse_process() {
    let raw = "
  PID USER       VSZ STAT COMMAND
    1 root      1276 S    /sbin/procd
";
    let result = parse(raw);
    assert_eq!(result.procs.len(), 1);
    assert_eq!(result.procs[0].pid, 1);
    assert_eq!(result.procs[0].command, "/sbin/procd");
}

#[test]
fn parse_linux_process_io_counters() {
    let raw = "
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 1024 2048 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 - - /usr/bin/app --flag
";
    let result = PsResult::parse(raw, ProcSortMode::Cpu, None, None, 1000);
    assert_eq!(result.procs.len(), 2);
    // The default order is the busiest first.
    assert_eq!(result.procs[0].pid, 2);
    assert_eq!(result.procs[1].read_bytes, Some(1024));
    assert_eq!(result.procs[1].write_bytes, Some(2048));
    // No previous reading, so no interval to divide by.
    assert_eq!(result.procs[1].read_speed, None);
    assert_eq!(result.procs[1].write_speed, None);
    assert_eq!(result.procs[1].command, "/sbin/procd");
}

#[test]
fn parse_linux_process_io_counters_without_start_column() {
    let raw = "
PID USER %CPU %MEM VSZ RSS TTY STAT TIME READ_BYTES WRITE_BYTES COMMAND
8987 root 0.9 1.8 1276 512 ? Sl 02:10:05 1024 2048 barad_agent
";
    let result = PsResult::parse(raw, ProcSortMode::Cpu, None, None, 1000);
    let proc = &result.procs[0];
    assert_eq!(proc.pid, 8987);
    assert_eq!(proc.start, None);
    assert_eq!(proc.time.as_deref(), Some("02:10:05"));
    assert_eq!(proc.read_bytes, Some(1024));
    assert_eq!(proc.write_bytes, Some(2048));
    assert_eq!(proc.command, "barad_agent");
    assert_eq!(proc.binary(), "barad_agent");
    assert!(proc.args().is_empty());
}

#[test]
fn parse_process_binary_and_args_for_display() {
    let raw = "
PID USER %CPU %MEM VSZ RSS TTY STAT TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.0 1.0 173552 8396 ? Ss 00:01:08 7603757056 4942843904 /usr/lib/systemd/systemd --system --deserialize 20 showopts
";
    let proc = &parse(raw).procs[0];
    assert_eq!(proc.binary(), "/usr/lib/systemd/systemd");
    assert_eq!(proc.args(), "--system --deserialize 20 showopts");
    assert_eq!(
        proc.command,
        "/usr/lib/systemd/systemd --system --deserialize 20 showopts"
    );
}

#[test]
fn unix_command_text_preserves_repeated_whitespace() {
    let raw = "
PID USER COMMAND
1 root /bin/tool  --name 'a  b'
";
    assert_eq!(parse(raw).procs[0].command, "/bin/tool  --name 'a  b'");
}

#[test]
fn malformed_optional_metrics_do_not_discard_unix_process_rows() {
    let raw = "
PID USER %CPU %MEM COMMAND
1 root - N/A /sbin/procd
";
    let proc = &parse(raw).procs[0];
    assert_eq!(proc.pid, 1);
    assert_eq!(proc.cpu, None);
    assert_eq!(proc.mem, None);
    assert_eq!(proc.command, "/sbin/procd");
}

#[test]
fn calculate_process_io_speed_from_previous_snapshot() {
    let first = "
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 1000 2000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 500 700 /usr/bin/app
";
    let second = "
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 3000 5000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 1000 1200 /usr/bin/app
";
    let previous = PsResult::parse(first, ProcSortMode::Cpu, None, None, 1000);
    let current = PsResult::parse(second, ProcSortMode::Cpu, None, Some(&previous), 3000);
    let proc = find(&current, 1);
    // Two seconds, so 2000 bytes read and 3000 written a second.
    assert_eq!(proc.read_speed, Some(1000.0));
    assert_eq!(proc.write_speed, Some(1500.0));
}

#[test]
fn io_speed_uses_elapsed_sample_time_and_matches_predecessors_by_pid() {
    let first = "
PID START_ID READ_BYTES WRITE_BYTES COMMAND
1 100 1000 4000 /one
2 200 8000 2000 /two
";
    let second = "
PID START_ID READ_BYTES WRITE_BYTES COMMAND
2 200 10000 10000 /two
1 100 5000 6000 /one
";
    let previous = PsResult::parse(first, ProcSortMode::Cpu, None, None, 1000);
    let current = PsResult::parse(second, ProcSortMode::Pid, None, Some(&previous), 5000);

    assert_eq!(current.procs[0].read_speed, Some(1000.0));
    assert_eq!(current.procs[0].write_speed, Some(500.0));
    assert_eq!(current.procs[1].read_speed, Some(500.0));
    assert_eq!(current.procs[1].write_speed, Some(2000.0));
}

#[test]
fn io_speed_is_null_for_zero_or_negative_sample_intervals() {
    let first = "
PID START_ID READ_BYTES WRITE_BYTES COMMAND
1 100 1000 2000 /one
";
    let second = "
PID START_ID READ_BYTES WRITE_BYTES COMMAND
1 100 3000 5000 /one
";
    let previous = PsResult::parse(first, ProcSortMode::Cpu, None, None, 2000);
    // The same millisecond, and a clock that went backwards.
    for sampled_at in [2000, 1000] {
        let current = PsResult::parse(second, ProcSortMode::Cpu, None, Some(&previous), sampled_at);
        assert_eq!(current.procs[0].read_speed, None, "at {sampled_at}");
        assert_eq!(current.procs[0].write_speed, None, "at {sampled_at}");
    }
}

#[test]
fn io_speed_is_null_for_missing_previous_and_counter_rollback() {
    let first = "
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 3000 5000 /sbin/procd
";
    let second = "
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 1000 4000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 1000 1200 /usr/bin/app
";
    let previous = PsResult::parse(first, ProcSortMode::Cpu, None, None, 1000);
    let current = PsResult::parse(second, ProcSortMode::Cpu, None, Some(&previous), 3000);
    let rolled_back = find(&current, 1);
    let new_proc = find(&current, 2);
    assert_eq!(rolled_back.read_speed, None);
    assert_eq!(rolled_back.write_speed, None);
    assert_eq!(new_proc.read_speed, None);
    assert_eq!(new_proc.write_speed, None);
}

#[test]
fn missing_process_identity_does_not_inherit_io_counters_by_pid() {
    let first = "
PID USER %CPU %MEM TIME READ_BYTES WRITE_BYTES COMMAND
7 root 0.1 1.2 00:01 1000 2000 /usr/bin/worker --old
";
    let second = "
PID USER %CPU %MEM TIME READ_BYTES WRITE_BYTES COMMAND
7 root 0.1 1.2 00:02 3000 5000 /usr/bin/worker --new
";
    let previous = PsResult::parse(first, ProcSortMode::Cpu, None, None, 1000);
    let current = PsResult::parse(second, ProcSortMode::Cpu, None, Some(&previous), 3000);
    assert_eq!(current.procs[0].read_speed, None);
    assert_eq!(current.procs[0].write_speed, None);
}

#[test]
fn pid_reuse_with_a_new_process_start_id_does_not_inherit_io_counters() {
    let first = "
PID USER %CPU %MEM VSZ RSS TTY STAT TIME START_ID READ_BYTES WRITE_BYTES COMMAND
42 root 0.1 1.2 1276 512 ? S 00:01 100 1000 2000 /usr/bin/worker
";
    let second = "
PID USER %CPU %MEM VSZ RSS TTY STAT TIME START_ID READ_BYTES WRITE_BYTES COMMAND
42 root 0.1 1.2 1276 512 ? S 00:01 200 9000 12000 /usr/bin/worker
";
    let previous = PsResult::parse(first, ProcSortMode::Cpu, None, None, 1000);
    let current = PsResult::parse(second, ProcSortMode::Cpu, None, Some(&previous), 2000);
    assert_eq!(current.procs[0].start_id.as_deref(), Some("200"));
    assert_eq!(current.procs[0].read_speed, None);
    assert_eq!(current.procs[0].write_speed, None);
}

#[test]
fn sort_process_by_io_speed_with_null_last() {
    let first = "
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 1000 1000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 1000 1000 /usr/bin/app
3 nobody 0.0 0.1 1024 256 ? S 10:02 00:00 - - idle
";
    let second = "
PID USER %CPU %MEM VSZ RSS TTY STAT START TIME READ_BYTES WRITE_BYTES COMMAND
1 root 0.1 1.2 1276 512 ? S 10:00 00:01 2000 6000 /sbin/procd
2 app 3.4 5.6 4096 2048 ? R 10:01 00:02 5000 2000 /usr/bin/app
3 nobody 0.0 0.1 1024 256 ? S 10:02 00:00 - - idle
";
    let previous = PsResult::parse(first, ProcSortMode::Cpu, None, None, 1000);
    let by_read = PsResult::parse(second, ProcSortMode::Read, None, Some(&previous), 2000);
    let by_write = PsResult::parse(second, ProcSortMode::Write, None, Some(&previous), 2000);
    assert_eq!(pids(&by_read), [2, 1, 3]);
    assert_eq!(pids(&by_write), [1, 2, 3]);
}

#[test]
fn parse_windows_process_json_io_counters() {
    let first = r#"
[
  {"ProcessName":"a","Id":1,"CPUPercent":12.5,"StartId":"100","WorkingSet":1024,"IOReadBytes":100,"IOWriteBytes":200},
  {"ProcessName":"b","Id":2,"CPUPercent":2.5,"StartId":"200","WorkingSet":512,"IOReadBytes":1000,"IOWriteBytes":1200}
]
"#;
    let second = r#"
[
  {"ProcessName":"a","Id":1,"CPUPercent":25.0,"StartId":"100","WorkingSet":1024,"IOReadBytes":1100,"IOWriteBytes":2200},
  {"ProcessName":"b","Id":2,"CPUPercent":5.0,"StartId":"200","WorkingSet":512,"IOReadBytes":1200,"IOWriteBytes":1600}
]
"#;
    let previous = PsResult::parse(first, ProcSortMode::Cpu, None, None, 1000);
    let current = PsResult::parse(second, ProcSortMode::Write, None, Some(&previous), 2000);
    assert_eq!(current.procs[0].pid, 1);
    assert_eq!(current.procs[0].read_speed, Some(1000.0));
    assert_eq!(current.procs[0].write_speed, Some(2000.0));
    assert_eq!(current.procs[0].cpu, Some(25.0));
    assert_eq!(current.procs[0].start_id.as_deref(), Some("100"));
    // Windows reports bytes; this is the same unit as `ps`'s RSS.
    assert_eq!(current.procs[0].rss_kb(), Some(1));
    assert_eq!(current.procs[1].rss_kb(), Some(1));
}

#[test]
fn windows_cumulative_cpu_seconds_are_not_parsed_as_cpu_usage() {
    let raw = r#"
{"ProcessName":"legacy","Id":1,"CPU":99.5,"WorkingSet":1024}
"#;
    assert_eq!(parse(raw).procs[0].cpu, None);
}

#[test]
fn invalid_numeric_metrics_and_negative_rss_are_omitted() {
    let unix_raw = "
PID %CPU %MEM RSS COMMAND
1 NaN Infinity -1 /bad
";
    let unix_proc = &parse(unix_raw).procs[0];
    assert_eq!(unix_proc.cpu, None);
    assert_eq!(unix_proc.mem, None);
    assert_eq!(unix_proc.rss_kb(), None);

    let windows_raw = r#"
{"Id":2,"WorkingSet":-1,"CPUPercent":"Infinity","IOReadBytes":1.5}
"#;
    let windows_proc = &parse(windows_raw).procs[0];
    assert_eq!(windows_proc.cpu, None);
    assert_eq!(windows_proc.rss_kb(), None);
    assert_eq!(windows_proc.read_bytes, None);
}

#[test]
fn negative_unix_io_counters_are_omitted() {
    let raw = "
PID START_ID READ_BYTES WRITE_BYTES COMMAND
1 100 -1 -2 /bad
";
    let proc = &parse(raw).procs[0];
    assert_eq!(proc.read_bytes, None);
    assert_eq!(proc.write_bytes, None);
}

#[test]
fn scalar_json_is_classified_as_invalid_windows_json() {
    for raw in ["null", "123", "true", "\"text\""] {
        let result = parse(raw);
        assert!(result.procs.is_empty(), "{raw}");
        assert_eq!(
            result.issue.map(|issue| issue.failure),
            Some(PsParseFailure::InvalidWindowsJson),
            "{raw}"
        );
    }
}

#[test]
fn windows_fields_fall_back_after_empty_or_unparsable_values() {
    let raw = r#"
{"Id":7,"CommandLine":"","Path":"C:\\app.exe","CPUPercent":"","PercentProcessorTime":12.5,"IOReadBytes":1.5,"ReadTransferCount":100,"WorkingSet":"bad","WorkingSetSize":2048}
"#;
    let proc = &parse(raw).procs[0];
    assert_eq!(proc.command, r"C:\app.exe");
    assert_eq!(proc.cpu, Some(12.5));
    assert_eq!(proc.read_bytes, Some(100));
    assert_eq!(proc.rss_kb(), Some(2));
}

#[test]
fn invalid_windows_rows_preserve_typed_diagnostics() {
    let raw = r#"
[
  {"ProcessName":"missing-pid"},
  {"ProcessName":"fractional-pid","Id":1.5},
  "not-an-object",
  {"ProcessName":"valid","Id":7,"CPUPercent":3.0}
]
"#;
    let result = PsResult::parse(raw, ProcSortMode::Cpu, None, None, 1234);
    assert_eq!(pids(&result), [7]);
    let issue = result.issue.as_ref().expect("an issue");
    assert_eq!(issue.failure, PsParseFailure::InvalidWindowsRows);
    assert_eq!(issue.diagnostics.matches("missing or invalid PID").count(), 2);
    assert!(issue.diagnostics.contains("expected an object"));
    assert_eq!(result.sampled_at_millis, 1234);
}

#[test]
fn windows_rows_reject_non_positive_process_ids() {
    let raw = r#"
[
  {"ProcessName":"zero","Id":0},
  {"ProcessName":"negative","Id":-2},
  {"ProcessName":"string-zero","Id":"0"},
  {"ProcessName":"valid","Id":3}
]
"#;
    let result = parse(raw);
    assert_eq!(pids(&result), [3]);
    let issue = result.issue.as_ref().expect("an issue");
    assert_eq!(issue.failure, PsParseFailure::InvalidWindowsRows);
    assert_eq!(issue.diagnostics.matches("missing or invalid PID").count(), 3);
}

#[test]
fn unix_rows_reject_non_positive_and_duplicate_process_ids() {
    let raw = "
PID COMMAND
0 zero
-1 negative
2 valid
2 duplicate
";
    let result = parse(raw);
    assert_eq!(pids(&result), [2]);
    let issue = result.issue.as_ref().expect("an issue");
    assert_eq!(issue.failure, PsParseFailure::InvalidRows);
    assert!(issue.diagnostics.contains("Invalid process ID"));
    assert!(issue.diagnostics.contains("Duplicate process ID"));
}

#[test]
fn windows_rows_reject_duplicate_process_ids() {
    let raw = r#"
[{"Id":3,"ProcessName":"first"},{"Id":3,"ProcessName":"second"}]
"#;
    let result = parse(raw);
    assert_eq!(result.procs.len(), 1);
    let issue = result.issue.as_ref().expect("an issue");
    assert_eq!(issue.failure, PsParseFailure::InvalidWindowsRows);
    assert!(issue.diagnostics.contains("duplicate PID 3"));
}

#[test]
fn malformed_windows_json_preserves_typed_diagnostics() {
    let result = PsResult::parse(r#"{"ProcessName":"#, ProcSortMode::Cpu, None, None, 5678);
    assert!(result.procs.is_empty());
    let issue = result.issue.as_ref().expect("an issue");
    assert_eq!(issue.failure, PsParseFailure::InvalidWindowsJson);
    assert!(issue.diagnostics.contains("Invalid Windows process JSON"));
    assert_eq!(result.sampled_at_millis, 5678);
}

#[test]
fn sorted_by_reorders_processes_and_keeps_metadata() {
    let mut third = bare(3, "/zeta");
    third.user = Some("z-user".to_string());
    third.cpu = Some(0.2);
    third.mem = Some(5.0);
    third.rss = Some("2048".to_string());
    third.read_speed = Some(10.0);
    third.write_speed = Some(20.0);

    let mut first = bare(1, "/alpha");
    first.user = Some("a-user".to_string());
    first.cpu = Some(9.0);
    first.mem = Some(1.0);

    let mut second = bare(2, "/middle");
    second.user = Some("m-user".to_string());
    second.cpu = Some(3.0);
    second.mem = Some(8.0);
    second.rss = Some("1024".to_string());
    second.read_speed = Some(50.0);
    second.write_speed = Some(5.0);

    let original = PsResult {
        procs: vec![third, first, second],
        issue: Some(sbm_parser::proc::PsParseIssue {
            failure: PsParseFailure::InvalidRows,
            diagnostics: "partial parse error".to_string(),
        }),
        sampled_at_millis: 1234,
        load: None,
    };

    let order = |mode| pids(&original.sorted_by(mode, None));
    assert_eq!(order(ProcSortMode::Cpu), [1, 2, 3]);
    assert_eq!(order(ProcSortMode::Mem), [2, 3, 1]);
    assert_eq!(order(ProcSortMode::Rss), [3, 2, 1]);
    assert_eq!(order(ProcSortMode::Read), [2, 3, 1]);
    assert_eq!(order(ProcSortMode::Write), [3, 2, 1]);
    assert_eq!(order(ProcSortMode::Pid), [1, 2, 3]);
    assert_eq!(order(ProcSortMode::User), [1, 2, 3]);
    assert_eq!(order(ProcSortMode::Name), [1, 2, 3]);

    assert_eq!(pids(&original.sorted_by(ProcSortMode::Cpu, Some(true))), [3, 2, 1]);
    assert_eq!(pids(&original.sorted_by(ProcSortMode::Pid, Some(false))), [3, 2, 1]);
    // An absent RSS is last either way round.
    assert_eq!(pids(&original.sorted_by(ProcSortMode::Rss, Some(true))), [2, 3, 1]);

    let sorted = original.sorted_by(ProcSortMode::Pid, None);
    assert_eq!(sorted.issue, original.issue);
    assert_eq!(sorted.sampled_at_millis, original.sampled_at_millis);
    // The reading it was asked for the order of is untouched.
    assert_eq!(pids(&original), [3, 1, 2]);
}

#[test]
fn cpu_sort_breaks_equal_value_ties_by_pid() {
    let mut second = bare(20, "second");
    second.cpu = Some(5.0);
    let mut first = bare(10, "first");
    first.cpu = Some(5.0);
    let result = PsResult {
        procs: vec![second, first],
        issue: None,
        sampled_at_millis: 0,
        load: None,
    }
    .sorted_by(ProcSortMode::Cpu, None);

    assert_eq!(pids(&result), [10, 20]);
}

#[test]
fn malformed_process_header_preserves_typed_diagnostics() {
    let raw = "
USER CPU COMMAND
root 0.0 /sbin/procd
";
    let result = PsResult::parse(raw, ProcSortMode::Cpu, None, None, 4321);
    assert!(result.procs.is_empty());
    let issue = result.issue.as_ref().expect("an issue");
    assert_eq!(issue.failure, PsParseFailure::UnsupportedOutput);
    assert!(
        issue
            .diagnostics
            .contains("Unsupported process output header")
    );
    assert_eq!(result.sampled_at_millis, 4321);
}

// ---------------------------------------------------------------------------
// Script output
// ---------------------------------------------------------------------------

#[test]
fn procps_identity_parentage_and_spacing_survive() {
    let result = parse(&fixture("linux_procps.txt"));

    assert_eq!(result.issue, None);
    assert_eq!(
        result.load,
        Some(ProcLoad {
            one: 0.01,
            five: 0.02,
            fifteen: 0.0
        })
    );
    assert!(result.procs.iter().all(|proc| proc.start_id.is_some()));

    let shell = by_command(&result, "sh -c sleep  31; :");
    let child = by_command(&result, "sleep 31");
    assert_eq!(child.ppid, Some(shell.pid));
    assert_eq!(child.threads, Some(1));
    assert_eq!(child.nice, Some(0));
    assert_eq!(child.elapsed_seconds, Some(0));
    assert_eq!(child.name(), "sleep");
    assert!(!result.procs.iter().any(|proc| proc.is_kernel_thread()));
}

#[test]
fn busybox_the_columns_busybox_ps_lacks_are_read_from_proc() {
    let result = parse(&fixture("linux_busybox.txt"));

    assert_eq!(result.issue, None);
    assert!(result.load.is_some());
    let shell = by_command(&result, "sh -c sleep  31; :");
    let child = by_command(&result, "sleep 31");
    assert_eq!(child.ppid, Some(shell.pid));
    assert!(child.start_id.is_some());
    assert_eq!(child.time.as_deref(), Some("0:00"));
    // Busybox reports no elapsed time and no CPU share.
    assert_eq!(child.elapsed_seconds, None);
    assert_eq!(child.cpu, None);

    // `ps` itself had exited by the time its /proc entry was read.
    let ps = by_command(&result, "ps w");
    assert_eq!(ps.ppid, None);
    assert_eq!(ps.start_id, None);
}

#[test]
fn macos_lstart_is_the_identity_and_etime_counts_days() {
    let result = parse(&fixture("macos.txt"));

    assert_eq!(result.issue, None);
    assert_eq!(
        result.load,
        Some(ProcLoad {
            one: 4.51,
            five: 4.0,
            fifteen: 3.83
        })
    );
    let launchd = find(&result, 1);
    assert_eq!(launchd.ppid, Some(0));
    assert_eq!(launchd.start_id.as_deref(), Some("Tue_Sep_15_02:35:59_2026"));
    assert_eq!(launchd.elapsed_seconds, Some(86400 + 22 * 3600 + 19 * 60 + 56));
    assert_eq!(launchd.name(), "launchd");
    assert_eq!(launchd.threads, None);
}

// ---------------------------------------------------------------------------
// Load line
// ---------------------------------------------------------------------------

const LOAD_TABLE: &str = "
PID USER COMMAND
1 root /sbin/init
";

#[test]
fn load_line_is_taken_out_before_the_header_is_looked_for() {
    let result = parse(&format!("SrvBoxProc.Load 1.5 0.25 3\n{LOAD_TABLE}"));
    assert_eq!(result.issue, None);
    assert_eq!(
        result.load,
        Some(ProcLoad {
            one: 1.5,
            five: 0.25,
            fifteen: 3.0
        })
    );
    assert_eq!(result.procs[0].command, "/sbin/init");
}

#[test]
fn load_line_absent_or_malformed_means_no_load_and_the_table_still_parses() {
    assert_eq!(parse(LOAD_TABLE).load, None);

    let malformed = parse(&format!("SrvBoxProc.Load 1.5 x\n{LOAD_TABLE}"));
    assert_eq!(malformed.load, None);
    assert_eq!(malformed.issue, None);
    assert_eq!(malformed.procs.len(), 1);
}

#[test]
fn load_line_is_kept_by_sorted_by() {
    let result = parse(&format!("SrvBoxProc.Load 1 2 3\n{LOAD_TABLE}"))
        .sorted_by(ProcSortMode::Pid, None);
    assert_eq!(
        result.load,
        Some(ProcLoad {
            one: 1.0,
            five: 2.0,
            fifteen: 3.0
        })
    );
}

#[test]
fn elapsed_time_reads_every_etime_form_and_refuses_nonsense() {
    let elapsed = |value: &str| {
        parse(&format!("PID ELAPSED COMMAND\n1 {value} init\n"))
            .procs[0]
            .elapsed_seconds
    };
    assert_eq!(elapsed("05:03"), Some(303));
    assert_eq!(elapsed("1:02:03"), Some(3723));
    assert_eq!(elapsed("2-01:02:03"), Some(2 * 86400 + 3723));
    assert_eq!(elapsed("-"), None);
    assert_eq!(elapsed("1:2:3:4"), None);
    // procps in a container whose boot time is not its host's.
    assert_eq!(elapsed("441077234-00:18:40"), None);
}

// ---------------------------------------------------------------------------
// Kernel threads
// ---------------------------------------------------------------------------

const KERNEL_HEADER: &str = "PID PPID USER %CPU %MEM VSZ RSS TTY STAT NI NLWP TIME ELAPSED \
START_ID READ_BYTES WRITE_BYTES COMMAND";

fn kernel_row(line: &str) -> Proc {
    let raw = format!("{KERNEL_HEADER}\n{line}\n");
    parse(&raw).procs[0].clone()
}

#[test]
fn kthreadd_and_its_children_are_kernel_threads() {
    assert!(kernel_row("2 0 root 0.0 0.0 0 0 ? S 0 1 00:00:00 31-00:00:00 2 - - [kthreadd]")
        .is_kernel_thread());
    assert!(
        kernel_row(
            "48 2 root 0.0 0.0 0 0 ? I< -20 1 00:00:00 31-00:00:00 9 - - [kworker/0:1H-kblockd]"
        )
        .is_kernel_thread()
    );
}

#[test]
fn pid_2_in_a_container_and_its_children_are_not() {
    assert!(
        !kernel_row("2 1 root 0.0 0.0 3120 1920 ? Sl 0 2 00:00:00 2-01:46:59 225 - - /init")
            .is_kernel_thread()
    );
    assert!(
        !kernel_row("7 2 lk 0.0 0.0 3120 1920 ? S 0 1 00:00:00 01:00 300 - - -bash")
            .is_kernel_thread()
    );
}

#[test]
fn windows_rows_carry_parent_threads_and_elapsed_time() {
    let raw = r#"
[{"ProcessName":"svc.exe","Id":40,"ParentId":4,"Threads":12,"ElapsedSeconds":90,"StartId":"1","CommandLine":"svc.exe"},
 {"ProcessName":"bad.exe","Id":41,"ElapsedSeconds":-5,"StartId":"2","CommandLine":"bad.exe"}]
"#;
    let result = PsResult::parse(raw, ProcSortMode::Pid, None, None, 0);
    let procs = &result.procs;

    assert_eq!(procs[0].ppid, Some(4));
    assert_eq!(procs[0].threads, Some(12));
    assert_eq!(procs[0].elapsed_seconds, Some(90));
    assert_eq!(procs[0].name(), "svc.exe");
    assert_eq!(procs[1].elapsed_seconds, None);
    assert_eq!(procs[1].ppid, None);
}

// ---------------------------------------------------------------------------
// Stopping a process
// ---------------------------------------------------------------------------

#[test]
fn a_stop_is_offered_only_where_there_is_an_identity_to_check() {
    assert!(kill_supported(1, Some("16608145"), SystemType::Linux));
    assert!(!kill_supported(1, None, SystemType::Linux));
    assert!(!kill_supported(1, Some("1"), SystemType::Bsd));

    assert!(kill_command(1, Some("1"), SystemType::Linux, ProcSignal::Term).is_some());
    assert!(kill_command(1, Some("1"), SystemType::Windows, ProcSignal::Kill).is_some());
    // Windows has no polite request.
    assert!(kill_command(1, Some("1"), SystemType::Windows, ProcSignal::Term).is_none());
    assert_eq!(signals_for(SystemType::Bsd), &[]);
}

#[test]
fn the_outcome_is_what_the_command_printed() {
    assert_eq!(kill_outcome("SrvBoxKill.Succeeded"), ProcKillOutcome::Succeeded);
    assert_eq!(kill_outcome("SrvBoxKill.TargetChanged"), ProcKillOutcome::TargetChanged);
    assert_eq!(kill_outcome("SrvBoxKill.Denied"), ProcKillOutcome::Denied);
    assert_eq!(kill_outcome("SrvBoxKill.Failed"), ProcKillOutcome::Failed);
    // Nothing printed is not success.
    assert_eq!(kill_outcome(""), ProcKillOutcome::Failed);
}
