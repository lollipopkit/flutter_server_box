//! The process table — the model, the two parsers and the stop command.
//!
//! Pure like the rest of this crate: [`PsResult::parse`] takes the text the
//! process function printed and returns rows, and [`kill_command`] takes a
//! description and returns a command. Nothing here runs anything, so the app
//! reaches it over SSH and the agent reaches it over a local shell and both
//! read one implementation.
//!
//! ## Two dialects, one model
//!
//! Unix is a table of columns read **by header name**, so a platform that
//! prints fewer columns (busybox `ps`, macOS `ps`) parses with no branch here
//! at all — a column that is absent is a field that is `None`. Windows prints
//! JSON, which arrives through the same model. Which one the input is, is
//! decided by its first byte, not by a platform argument: the caller has
//! already chosen the command, and a reader that re-decides would be a second
//! opinion about the platform that can disagree with the first.
//!
//! ## What is deliberately not here
//!
//! **Localised text.** The Dart implementation builds display strings inside
//! its parsers, which welds a locale to the parse. This module returns the
//! parts and leaves the sentence to the client. [`Proc::name`] is the one
//! exception and is not a sentence: it is the executable, which is what both
//! clients print where a whole command line does not fit.
//!
//! **The clock.** [`PsResult::parse`] takes the instant the output was
//! produced rather than reading one: the interval between two samples is what
//! a read/write speed divides by, and a crate that was handed a snapshot of a
//! remote machine has no business deciding when it was taken.
//!
//! ## Stopping a process
//!
//! [`kill_command`] refuses where it cannot prove what it is signalling. The
//! identity is the table's `START_ID` — `/proc/<pid>/stat`'s `starttime` on
//! Linux, the creation time in UTC ticks on Windows — and without one there is
//! nothing to check a PID against, so no command is produced rather than one
//! that signals whatever holds the number now. The value is read off a remote
//! machine and reaches a command line, so it goes through
//! [`crate::common::single_quote`] like every other untrusted argument.

use std::collections::{HashMap, HashSet};
use std::sync::LazyLock;

use regex::Regex;
use serde::{Deserialize, Serialize};

use crate::SystemType;
use crate::common::single_quote;
use crate::script::PROCESS_LOAD_MARKER;

/// First line of the process function's output, minus its marker.
///
/// `PROCESS_LOAD_MARKER` is the whole line prefix; this is what is left once
/// it is taken off, split on whitespace into three numbers.
static NON_WHITESPACE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\S+").expect("valid regex"));

/// Beyond this an elapsed time is not a measurement. A container whose boot
/// time disagrees with its host's makes procps print a start date thousands of
/// years back, and "running for 1.2 million years" says nothing true.
const MAX_ELAPSED_SECONDS: i64 = 100 * 365 * 24 * 3600;

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// One row of the process table.
///
/// Any field can be `None`: the set of columns differs per platform and per
/// `ps`, and a row can omit a value it cannot read (`-`) without omitting the
/// row. `None` means the platform did not say, which is not the same as zero.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct Proc {
    pub user: Option<String>,
    pub pid: i64,
    /// Null where the platform did not say, which is not the same as 0: PID 0
    /// is the parent a Linux kernel reports for `init` and `kthreadd`.
    pub ppid: Option<i64>,
    pub cpu: Option<f64>,
    pub mem: Option<f64>,
    pub vsz: Option<String>,
    pub rss: Option<String>,
    pub tty: Option<String>,
    pub stat: Option<String>,
    pub nice: Option<i64>,
    pub threads: Option<i64>,
    pub start: Option<String>,
    /// The identity a stop is checked against — see this module's docs.
    pub start_id: Option<String>,
    pub time: Option<String>,
    /// Seconds since the process started, as the server counted them.
    pub elapsed_seconds: Option<i64>,
    pub read_bytes: Option<i64>,
    pub write_bytes: Option<i64>,
    /// Bytes a second since the previous sample. `None` where there is nothing
    /// to difference against, which is every first sample.
    pub read_speed: Option<f64>,
    pub write_speed: Option<f64>,
    /// The command line as printed, with its own spacing: `ps` fields are
    /// split on runs of whitespace and this is the tail of the line from the
    /// command column on, put back verbatim.
    pub command: String,
    /// The image name Windows reports (`nginx.exe`). A Windows command line
    /// starts with a path that may hold spaces and quotes, so splitting it on
    /// whitespace would name the process `"C:\Program`.
    pub process_name: Option<String>,
}

impl Proc {
    /// The first word of the command line — the executable, as spelled.
    pub fn binary(&self) -> &str {
        NON_WHITESPACE
            .find(&self.command)
            .map(|found| found.as_str())
            .unwrap_or("")
    }

    /// Everything after the executable, leading whitespace removed.
    pub fn args(&self) -> &str {
        match NON_WHITESPACE.find(&self.command) {
            None => "",
            Some(found) => self.command[found.end()..].trim_start(),
        }
    }

    /// What to call the process where its whole command line does not fit.
    ///
    /// The last path component of the executable, without the colon a process
    /// that rewrites its title leaves after its own name (`nginx: worker
    /// process`). A kernel thread's command is a name in brackets, which is
    /// already the whole of what to call it.
    pub fn name(&self) -> String {
        if let Some(name) = self.process_name.as_deref() {
            let name = name.trim();
            if !name.is_empty() {
                return name.to_string();
            }
        }
        let binary = self.binary();
        if binary.starts_with('[') {
            return self.command.trim().to_string();
        }
        let base = match binary.rfind('/') {
            Some(slash) if binary.len() > slash + 1 => &binary[slash + 1..],
            _ => binary,
        };
        let mut base = base.to_string();
        if base.len() > 1 && base.ends_with(':') {
            base.pop();
        }
        if base.is_empty() {
            self.command.trim().to_string()
        } else {
            base
        }
    }

    /// `RSS` in KiB as a number.
    ///
    /// `ps` prints `-` where it has no answer, which is not a measurement of
    /// zero. Windows reports bytes, so its parser normalizes to the same unit
    /// before this ever sees it — the field is a string because the two
    /// dialects print different things into it.
    pub fn rss_kb(&self) -> Option<i64> {
        let raw = self.rss.as_deref()?;
        if raw.is_empty() || raw == "-" {
            return None;
        }
        let parsed = raw.parse::<i64>().ok()?;
        (parsed >= 0).then_some(parsed)
    }

    /// A Linux kernel thread: `kthreadd` itself, or one of its children.
    ///
    /// The command is checked too, because PPID 2 only means `kthreadd` in the
    /// root PID namespace. Inside a container PID 2 is whatever started
    /// second, and its children are ordinary processes — whose command lines,
    /// unlike a kernel thread's, are not a name in brackets.
    pub fn is_kernel_thread(&self) -> bool {
        (self.pid == 2 || self.ppid == Some(2)) && self.command.trim_start().starts_with('[')
    }
}

/// The 1, 5 and 15 minute load averages, as the machine reported them.
#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct ProcLoad {
    pub one: f64,
    pub five: f64,
    pub fifteen: f64,
}

/// What a process table could not be read as.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum PsParseFailure {
    /// The header named no `PID`, or no command column.
    UnsupportedOutput,
    /// Rows were dropped: an unreadable PID, a duplicate, a short line.
    InvalidRows,
    /// Windows: the text was not the JSON the command prints.
    InvalidWindowsJson,
    /// Windows: the JSON was an object or array, and rows in it were dropped.
    InvalidWindowsRows,
}

/// What one table could not be read as, and where.
///
/// The rows that *did* parse are still in [`PsResult::procs`]: a table with
/// one bad row is a table with one bad row, not an empty page.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct PsParseIssue {
    pub failure: PsParseFailure,
    /// One line per dropped row, naming the row. Shown verbatim.
    pub diagnostics: String,
}

/// How to order the table.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ProcSortMode {
    /// CPU share now, the runtime's own percentage.
    Cpu,
    /// Memory share now.
    Mem,
    /// Resident set size, in KiB — the same quantity as [`ProcSortMode::Mem`],
    /// as a count of bytes rather than a share of the machine's memory.
    Rss,
    Read,
    Write,
    Pid,
    User,
    Name,
}

impl ProcSortMode {
    /// Which way round a mode sorts when the caller does not say.
    ///
    /// Where a process is *named* (pid, user, name) the useful end is the
    /// start; where a resource is *measured* it is the largest consumer.
    pub fn default_ascending(self) -> bool {
        matches!(self, Self::Pid | Self::User | Self::Name)
    }
}

/// One reading of the process table.
#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct PsResult {
    pub procs: Vec<Proc>,
    pub issue: Option<PsParseIssue>,
    /// The instant the output was produced, in Unix milliseconds, as the
    /// caller's clock put it. Passed to the *next* parse as part of
    /// `previous`, which is where the interval for read/write speeds comes
    /// from.
    pub sampled_at_millis: i64,
    /// Null where the machine has none to report — Windows — or ran a script
    /// older than the line that carries it.
    pub load: Option<ProcLoad>,
}

impl PsResult {
    /// Read one table.
    ///
    /// `previous` is the last reading that parsed cleanly. It is what a
    /// read/write speed is differenced against, and it is matched per process
    /// by [`Proc::start_id`] rather than by PID: the kernel reuses a number,
    /// and a counter read from the process that inherited one would be a
    /// nonsense speed rather than a missing one.
    ///
    /// `sampled_at_millis` is this reading's instant — see
    /// [`PsResult::sampled_at_millis`].
    pub fn parse(
        raw: &str,
        sort: ProcSortMode,
        ascending: Option<bool>,
        previous: Option<&PsResult>,
        sampled_at_millis: i64,
    ) -> PsResult {
        let previous_by_pid: HashMap<i64, &Proc> = previous
            .map(|previous| {
                previous
                    .procs
                    .iter()
                    .map(|proc| (proc.pid, proc))
                    .collect()
            })
            .unwrap_or_default();
        // An interval that is not positive is not an interval: the same
        // timestamp twice (a page repolled inside one millisecond) divides by
        // nothing, and a clock that went backwards would report a negative
        // speed.
        let elapsed_seconds = match previous {
            Some(previous) if previous.sampled_at_millis > 0 => {
                Some((sampled_at_millis - previous.sampled_at_millis) as f64 / 1000.0)
            }
            _ => None,
        };

        if let Some(result) = parse_windows_json(
            raw,
            &previous_by_pid,
            elapsed_seconds,
            sampled_at_millis,
            sort,
            ascending,
        ) {
            return result;
        }

        let mut lines: Vec<&str> = raw
            .lines()
            .map(str::trim)
            .filter(|line| !line.is_empty())
            .collect();
        let load = take_load(&mut lines);
        if lines.is_empty() {
            return PsResult {
                procs: Vec::new(),
                issue: None,
                sampled_at_millis,
                load,
            };
        }

        let header = lines[0];
        let columns: Vec<&str> = header.split_whitespace().collect();
        let Some(pid_column) = columns.iter().position(|name| *name == "PID") else {
            return unsupported_header(header, sampled_at_millis, load);
        };
        let command_column = columns
            .iter()
            .position(|name| *name == "COMMAND")
            .or_else(|| columns.iter().position(|name| *name == "CMD"));
        let Some(command_column) = command_column else {
            return unsupported_header(header, sampled_at_millis, load);
        };
        let column_of = |name: &str| columns.iter().position(|column| *column == name);
        let map = ValIdxMap {
            pid: pid_column,
            ppid: column_of("PPID"),
            user: column_of("USER"),
            cpu: column_of("%CPU"),
            mem: column_of("%MEM"),
            vsz: column_of("VSZ"),
            rss: column_of("RSS"),
            tty: column_of("TTY"),
            stat: column_of("STAT"),
            nice: column_of("NI"),
            threads: column_of("NLWP"),
            start: column_of("START"),
            start_id: column_of("START_ID"),
            time: column_of("TIME"),
            elapsed: column_of("ELAPSED"),
            read_bytes: column_of("READ_BYTES"),
            write_bytes: column_of("WRITE_BYTES"),
            command: command_column,
        };

        let mut procs = Vec::new();
        let mut errors: Vec<String> = Vec::new();
        let mut seen_pids: HashSet<i64> = HashSet::new();
        for line in &lines[1..] {
            let pid = match row_pid(line, map.pid) {
                Ok(pid) => pid,
                Err(error) => {
                    errors.push(format!("{line}: {error}"));
                    continue;
                }
            };
            // Inserted before the rest of the row is read, so a PID that
            // appeared twice is reported as a duplicate even where the first
            // appearance itself failed to parse.
            if !seen_pids.insert(pid) {
                errors.push(format!("{line}: Duplicate process ID: {pid}"));
                continue;
            }
            match parse_row(line, pid, &map, &previous_by_pid, elapsed_seconds) {
                Ok(proc) => procs.push(proc),
                Err(error) => errors.push(format!("{line}: {error}")),
            }
        }

        sort_procs(&mut procs, sort, ascending);
        PsResult {
            procs,
            issue: (!errors.is_empty()).then(|| PsParseIssue {
                failure: PsParseFailure::InvalidRows,
                diagnostics: errors.join("\n"),
            }),
            sampled_at_millis,
            load,
        }
    }

    /// The same reading, ordered differently.
    ///
    /// The issue and the load line come along: they are what the reading *is*,
    /// not what its order is.
    pub fn sorted_by(&self, sort: ProcSortMode, ascending: Option<bool>) -> PsResult {
        let mut procs = self.procs.clone();
        sort_procs(&mut procs, sort, ascending);
        PsResult {
            procs,
            issue: self.issue.clone(),
            sampled_at_millis: self.sampled_at_millis,
            load: self.load,
        }
    }
}

fn unsupported_header(header: &str, sampled_at_millis: i64, load: Option<ProcLoad>) -> PsResult {
    PsResult {
        procs: Vec::new(),
        issue: Some(PsParseIssue {
            failure: PsParseFailure::UnsupportedOutput,
            diagnostics: format!("Unsupported process output header: {header}"),
        }),
        sampled_at_millis,
        load,
    }
}

/// Which column each field is in, by name, for one header.
///
/// `None` is a column this platform does not print — which is how busybox and
/// macOS parse without a branch: the fields they lack are `None` on every row.
#[derive(Debug, Clone, Copy)]
struct ValIdxMap {
    pid: usize,
    ppid: Option<usize>,
    user: Option<usize>,
    cpu: Option<usize>,
    mem: Option<usize>,
    vsz: Option<usize>,
    rss: Option<usize>,
    tty: Option<usize>,
    stat: Option<usize>,
    nice: Option<usize>,
    threads: Option<usize>,
    start: Option<usize>,
    start_id: Option<usize>,
    time: Option<usize>,
    elapsed: Option<usize>,
    read_bytes: Option<usize>,
    write_bytes: Option<usize>,
    command: usize,
}

/// The table's columns for one row, in the order they were printed.
///
/// Non-whitespace runs, not a whitespace split: a run of spaces inside a
/// command is part of the command, and the command is the tail of the raw line
/// from its column on — see [`Proc::command`].
fn row_columns(raw: &str) -> Vec<&str> {
    NON_WHITESPACE.find_iter(raw).map(|found| found.as_str()).collect()
}

/// The PID a row says it is.
///
/// Read before the rest of the row so that a duplicate is caught whether or
/// not the first row carrying that PID was readable.
fn row_pid(raw: &str, column: usize) -> Result<i64, String> {
    let columns = row_columns(raw);
    let value = columns
        .get(column)
        .copied()
        .ok_or_else(|| format!("no PID in column {column}"))?;
    positive_pid(value)
}

fn positive_pid(raw: &str) -> Result<i64, String> {
    match raw.parse::<i64>() {
        Ok(pid) if pid > 0 => Ok(pid),
        _ => Err(format!("Invalid process ID: {raw}")),
    }
}

/// A row's field of a column the platform may not print at all.
///
/// `Ok(None)` where the column does not exist, `Err` where the header named it
/// and the row is too short to have it — a row that is missing a column it
/// should have is a row this parser is not reading correctly, and dropping it
/// with a note beats reading the next column's value into it.
fn column_value<'a>(
    columns: &[&'a str],
    column: Option<usize>,
) -> Result<Option<&'a str>, String> {
    match column {
        None => Ok(None),
        Some(index) => columns
            .get(index)
            .copied()
            .map(Some)
            .ok_or_else(|| format!("row has no column {index}")),
    }
}

/// A numeric column's value, and `None` where the column is absent or too
/// short — `ps` prints `-` for a metric it cannot read, and a row is not
/// dropped for that.
fn optional_int(columns: &[&str], column: Option<usize>, non_negative: bool) -> Option<i64> {
    let parsed = int_from_str(column.and_then(|index| columns.get(index).copied())?)?;
    if non_negative && parsed < 0 {
        return None;
    }
    Some(parsed)
}

fn optional_double(columns: &[&str], column: Option<usize>) -> Option<f64> {
    double_from_str(column.and_then(|index| columns.get(index).copied())?)
}

fn parse_row(
    raw: &str,
    pid: i64,
    map: &ValIdxMap,
    previous_by_pid: &HashMap<i64, &Proc>,
    elapsed_seconds: Option<f64>,
) -> Result<Proc, String> {
    let columns = row_columns(raw);
    let matches: Vec<_> = NON_WHITESPACE.find_iter(raw).collect();
    let command = matches
        .get(map.command)
        .map(|found| raw[found.start()..].to_string())
        .ok_or_else(|| format!("row has no column {}", map.command))?;

    let text = |column| column_value(&columns, column).map(|value| value.map(str::to_string));
    let start = text(map.start)?;
    let start_id = process_identity(text(map.start_id)?);
    let user = text(map.user)?;
    let vsz = text(map.vsz)?;
    let rss = text(map.rss)?;
    let tty = text(map.tty)?;
    let stat = text(map.stat)?;
    let time = text(map.time)?;
    let elapsed_seconds_current = match column_value(&columns, map.elapsed)? {
        Some(value) => parse_elapsed(value),
        None => None,
    };
    let read_bytes = optional_int(&columns, map.read_bytes, true);
    let write_bytes = optional_int(&columns, map.write_bytes, true);
    let (read_speed, write_speed) = calculate_speeds(
        read_bytes,
        write_bytes,
        matching_previous(
            previous_by_pid.get(&pid).copied(),
            start.as_deref(),
            start_id.as_deref(),
        ),
        elapsed_seconds,
    );

    Ok(Proc {
        user,
        pid,
        ppid: optional_int(&columns, map.ppid, true),
        cpu: optional_double(&columns, map.cpu),
        mem: optional_double(&columns, map.mem),
        vsz,
        rss,
        tty,
        stat,
        nice: optional_int(&columns, map.nice, false),
        threads: optional_int(&columns, map.threads, true),
        start,
        start_id,
        time,
        elapsed_seconds: elapsed_seconds_current,
        read_bytes,
        write_bytes,
        read_speed,
        write_speed,
        command,
        process_name: None,
    })
}

// ---------------------------------------------------------------------------
// Windows JSON
// ---------------------------------------------------------------------------

/// One table of Windows rows, or `None` where the text is not JSON at all and
/// the Unix path should read it.
///
/// Decided by the text: anything that starts with `{` or `[` was *meant* to be
/// JSON, so a document that does not parse is reported as a broken one rather
/// than re-read as a table of columns — which would answer a JSON syntax error
/// with "unsupported header" and hide the real one. Anything else is tried as
/// JSON too, and only a text that is not JSON at all falls through.
fn parse_windows_json(
    raw: &str,
    previous_by_pid: &HashMap<i64, &Proc>,
    elapsed_seconds: Option<f64>,
    sampled_at_millis: i64,
    sort: ProcSortMode,
    ascending: Option<bool>,
) -> Option<PsResult> {
    let trimmed = raw.trim();
    if !trimmed.starts_with('{')
        && !trimmed.starts_with('[')
        && serde_json::from_str::<serde_json::Value>(trimmed).is_err()
    {
        return None;
    }

    let value: serde_json::Value = match serde_json::from_str(trimmed) {
        Ok(value) => value,
        Err(error) => {
            return Some(invalid_windows_json(
                format!("Invalid Windows process JSON: {error}"),
                sampled_at_millis,
            ));
        }
    };
    let items: Vec<&serde_json::Value> = match &value {
        serde_json::Value::Array(values) => values.iter().collect(),
        // The command wraps its list in `@(...)` and `ConvertTo-Json` unwraps
        // a one-element array into the object itself.
        serde_json::Value::Object(_) => vec![&value],
        _ => {
            return Some(invalid_windows_json(
                "Invalid Windows process JSON: expected an object or array".to_string(),
                sampled_at_millis,
            ));
        }
    };

    let mut procs = Vec::new();
    let mut errors: Vec<String> = Vec::new();
    let mut seen_pids: HashSet<i64> = HashSet::new();
    for (index, item) in items.iter().enumerate() {
        let Some(row) = item.as_object() else {
            errors.push(format!(
                "Invalid Windows process row {index}: expected an object"
            ));
            continue;
        };
        let Some(pid) = process_id(row.get("Id").or_else(|| row.get("ProcessId"))) else {
            errors.push(format!(
                "Invalid Windows process row {index}: missing or invalid PID"
            ));
            continue;
        };
        if !seen_pids.insert(pid) {
            errors.push(format!(
                "Invalid Windows process row {index}: duplicate PID {pid}"
            ));
            continue;
        }
        procs.push(parse_windows_row(
            row,
            pid,
            previous_by_pid,
            elapsed_seconds,
        ));
    }

    sort_procs(&mut procs, sort, ascending);
    Some(PsResult {
        procs,
        issue: (!errors.is_empty()).then(|| PsParseIssue {
            failure: PsParseFailure::InvalidWindowsRows,
            diagnostics: errors.join("\n"),
        }),
        sampled_at_millis,
        load: None,
    })
}

fn invalid_windows_json(diagnostics: String, sampled_at_millis: i64) -> PsResult {
    PsResult {
        procs: Vec::new(),
        issue: Some(PsParseIssue {
            failure: PsParseFailure::InvalidWindowsJson,
            diagnostics,
        }),
        sampled_at_millis,
        load: None,
    }
}

fn parse_windows_row(
    row: &serde_json::Map<String, serde_json::Value>,
    pid: i64,
    previous_by_pid: &HashMap<i64, &Proc>,
    elapsed_seconds: Option<f64>,
) -> Proc {
    let name = first_non_empty_string(&[row.get("ProcessName"), row.get("Name")]);
    let command = first_non_empty_string(&[row.get("CommandLine"), row.get("Path")])
        .or_else(|| name.clone())
        .unwrap_or_default();
    let start_id = process_identity(row.get("StartId").map(json_text));
    let read_bytes = first_parsed_int(
        &[row.get("IOReadBytes"), row.get("ReadTransferCount")],
        true,
    );
    let write_bytes = first_parsed_int(
        &[row.get("IOWriteBytes"), row.get("WriteTransferCount")],
        true,
    );
    let (read_speed, write_speed) = calculate_speeds(
        read_bytes,
        write_bytes,
        matching_previous(previous_by_pid.get(&pid).copied(), None, start_id.as_deref()),
        elapsed_seconds,
    );
    let working_set = first_parsed_int(&[row.get("WorkingSet"), row.get("WorkingSetSize")], true);
    let elapsed = parse_dynamic_int(row.get("ElapsedSeconds"));

    Proc {
        user: None,
        pid,
        ppid: first_parsed_int(&[row.get("ParentId")], true),
        cpu: first_parsed_double(&[row.get("CPUPercent"), row.get("PercentProcessorTime")]),
        mem: None,
        vsz: None,
        // Unix `ps` reports RSS in KiB. The Windows byte count is normalized
        // to the same unit so sorting and display stay consistent across
        // platforms.
        rss: working_set.map(|bytes| ((bytes + 1023) / 1024).to_string()),
        tty: None,
        stat: None,
        nice: None,
        threads: first_parsed_int(&[row.get("Threads")], true),
        start: None,
        start_id,
        time: None,
        elapsed_seconds: elapsed.filter(|value| *value >= 0 && *value <= MAX_ELAPSED_SECONDS),
        read_bytes,
        write_bytes,
        read_speed,
        write_speed,
        command,
        process_name: name,
    }
}

/// A JSON value as the text a column would have carried.
///
/// `Get-CimInstance` hands `Id` and `StartId` over as numbers, and the Dart
/// implementation read them through `toString()`. What this must not do is
/// treat a number as a different process than the table's own `START_ID`
/// column: both sides go through here.
fn json_text(value: &serde_json::Value) -> String {
    match value {
        serde_json::Value::String(text) => text.clone(),
        other => other.to_string(),
    }
}

/// A value's integer reading, and `None` where it is not one.
///
/// A fractional `1.5` is not rounded into a process ID or a byte count: it is
/// a value this parser does not understand, and the caller falls back to the
/// next field name or to nothing.
fn parse_dynamic_int(value: Option<&serde_json::Value>) -> Option<i64> {
    match value? {
        serde_json::Value::Number(number) => {
            if let Some(integer) = number.as_i64() {
                return Some(integer);
            }
            let float = number.as_f64()?;
            if !float.is_finite() || float != float.trunc() {
                return None;
            }
            Some(float as i64)
        }
        serde_json::Value::String(text) => int_from_str(text),
        _ => None,
    }
}

fn first_parsed_int(values: &[Option<&serde_json::Value>], non_negative: bool) -> Option<i64> {
    values.iter().find_map(|value| {
        let parsed = parse_dynamic_int(*value)?;
        if non_negative && parsed < 0 {
            return None;
        }
        Some(parsed)
    })
}

fn parse_dynamic_double(value: Option<&serde_json::Value>) -> Option<f64> {
    match value? {
        serde_json::Value::Number(number) => number.as_f64().filter(|value| value.is_finite()),
        serde_json::Value::String(text) => double_from_str(text),
        _ => None,
    }
}

fn first_parsed_double(values: &[Option<&serde_json::Value>]) -> Option<f64> {
    values.iter().find_map(|value| parse_dynamic_double(*value))
}

fn first_non_empty_string(values: &[Option<&serde_json::Value>]) -> Option<String> {
    values.iter().find_map(|value| {
        let text = match (*value)? {
            serde_json::Value::String(text) => text.clone(),
            other => other.to_string(),
        };
        (!text.trim().is_empty()).then_some(text)
    })
}

/// Where a value is a number that is not a positive integer, it is not a PID.
///
/// `Id: 0` is not process 0: Windows has no such process, and a table that
/// answered one would be offering to stop something that is not there.
fn process_id(value: Option<&serde_json::Value>) -> Option<i64> {
    let parsed = parse_dynamic_int(value)?;
    (parsed > 0).then_some(parsed)
}

// ---------------------------------------------------------------------------
// Shared field parsing
// ---------------------------------------------------------------------------

fn int_from_str(raw: &str) -> Option<i64> {
    if raw.is_empty() || raw == "-" {
        return None;
    }
    raw.parse::<i64>().ok()
}

fn double_from_str(raw: &str) -> Option<f64> {
    if raw.is_empty() || raw == "-" {
        return None;
    }
    raw.parse::<f64>().ok().filter(|value| value.is_finite())
}

/// `etime`: `[[dd-]hh:]mm:ss`.
///
/// `ps` prints `-` for a process it cannot date, and a container whose boot
/// time is not its host's produces a day count that overflows a year 100 — the
/// limit is what turns that into `None` rather than a number nobody can act
/// on.
fn parse_elapsed(raw: &str) -> Option<i64> {
    if raw.is_empty() || raw == "-" {
        return None;
    }
    let mut days = 0i64;
    let mut rest = raw;
    if let Some(dash) = raw.find('-') {
        let parsed = raw[..dash].parse::<i64>().ok()?;
        if parsed < 0 {
            return None;
        }
        days = parsed;
        rest = &raw[dash + 1..];
    }
    let fields: Vec<&str> = rest.split(':').collect();
    if fields.len() < 2 || fields.len() > 3 {
        return None;
    }
    let mut seconds = 0i64;
    for field in fields {
        let value = field.parse::<i64>().ok()?;
        if value < 0 {
            return None;
        }
        seconds = seconds * 60 + value;
    }
    let total = days * 86400 + seconds;
    (total <= MAX_ELAPSED_SECONDS).then_some(total)
}

/// The identity a stop checks a PID against, or `None` where the table cannot
/// say — `ps` prints `-` there, which is not an identity.
fn process_identity(raw: Option<String>) -> Option<String> {
    let identity = raw?;
    let identity = identity.trim();
    if identity.is_empty() || identity == "-" {
        return None;
    }
    Some(identity.to_string())
}

/// The previous reading's row for this process, where it is provably the same
/// process.
///
/// The identity is the primary key: without one on either side there is
/// nothing to compare, and a PID is not enough — the kernel hands a freed
/// number to the next process, and the counters that came with it belong to
/// that one. `START` is the fallback for a table that carries no `START_ID`,
/// and is coarser: it is a time to the minute on Linux and a whole date on
/// BSD.
fn matching_previous<'a>(
    previous: Option<&'a Proc>,
    start: Option<&str>,
    start_id: Option<&str>,
) -> Option<&'a Proc> {
    let previous = previous?;
    if start_id.is_some() || previous.start_id.is_some() {
        let current = start_id?;
        let stored = previous.start_id.as_deref()?;
        return (current == stored).then_some(previous);
    }
    if start.is_some() || previous.start.is_some() {
        let current = start?;
        let stored = previous.start.as_deref()?;
        return (current == stored).then_some(previous);
    }
    None
}

/// Bytes a second over the interval between two readings.
///
/// Both halves or neither: a speed needs a counter on each side, and an
/// interval that is not positive is not an interval.
fn calculate_speeds(
    read_bytes: Option<i64>,
    write_bytes: Option<i64>,
    previous: Option<&Proc>,
    elapsed_seconds: Option<f64>,
) -> (Option<f64>, Option<f64>) {
    let Some(previous) = previous else {
        return (None, None);
    };
    let Some(seconds) = elapsed_seconds.filter(|seconds| *seconds > 0.0) else {
        return (None, None);
    };
    (
        calculate_speed(read_bytes, previous.read_bytes, seconds),
        calculate_speed(write_bytes, previous.write_bytes, seconds),
    )
}

fn calculate_speed(current: Option<i64>, previous: Option<i64>, seconds: f64) -> Option<f64> {
    let difference = current? - previous?;
    // A counter that went backwards is a reused PID or a reset interface, not
    // a negative speed.
    if difference < 0 {
        return None;
    }
    Some(difference as f64 / seconds)
}

/// The load line, removed from `lines` and answered.
///
/// Taken out before the header is looked for, because the table's header is
/// whatever line comes first and this one is not a table. A line that is there
/// and unreadable is removed all the same: it is the script's, not the
/// machine's, and leaving it would make it the header.
fn take_load(lines: &mut Vec<&str>) -> Option<ProcLoad> {
    let index = lines.iter().position(|line| {
        line.strip_prefix(PROCESS_LOAD_MARKER)
            .is_some_and(|rest| rest.starts_with(' '))
    })?;
    let values: Vec<Option<f64>> = lines
        .remove(index)
        .get(PROCESS_LOAD_MARKER.len()..)
        .unwrap_or("")
        .split_whitespace()
        .map(|value| value.parse::<f64>().ok())
        .collect();
    if values.len() != 3 || values.iter().any(|value| value.is_none_or(|value| value < 0.0)) {
        return None;
    }
    Some(ProcLoad {
        one: values[0]?,
        five: values[1]?,
        fifteen: values[2]?,
    })
}

// ---------------------------------------------------------------------------
// Sorting
// ---------------------------------------------------------------------------

fn sort_procs(procs: &mut [Proc], sort: ProcSortMode, ascending: Option<bool>) {
    let ascending = ascending.unwrap_or_else(|| sort.default_ascending());
    procs.sort_by(|a, b| {
        let ordered = match sort {
            ProcSortMode::Cpu => compare_nullable(a.cpu, b.cpu, ascending),
            ProcSortMode::Mem => compare_nullable(a.mem, b.mem, ascending),
            ProcSortMode::Rss => compare_nullable(a.rss_kb(), b.rss_kb(), ascending),
            ProcSortMode::Read => compare_nullable(a.read_speed, b.read_speed, ascending),
            ProcSortMode::Write => compare_nullable(a.write_speed, b.write_speed, ascending),
            ProcSortMode::Pid => apply_direction(a.pid.cmp(&b.pid), ascending),
            ProcSortMode::User => compare_nullable(
                a.user.as_ref().map(|user| user.to_lowercase()),
                b.user.as_ref().map(|user| user.to_lowercase()),
                ascending,
            ),
            // The whole command line, not [`Proc::name`]: the name is a
            // display choice, and ordering by a value the reader cannot see
            // makes the list look arbitrary.
            ProcSortMode::Name => apply_direction(
                a.command.to_lowercase().cmp(&b.command.to_lowercase()),
                ascending,
            ),
        };
        // A tie is broken by PID both ways round, so equal readings keep one
        // order between refreshes instead of shuffling.
        if ordered == std::cmp::Ordering::Equal {
            a.pid.cmp(&b.pid)
        } else {
            ordered
        }
    });
}

/// Compare two optional keys, with an absent one last whichever way the sort
/// runs.
///
/// A process whose CPU share the platform did not report is not a process
/// using the least CPU, and sorting it to the top is how a list of the busiest
/// processes fills with ones that have no reading.
fn compare_nullable<T: PartialOrd>(
    a: Option<T>,
    b: Option<T>,
    ascending: bool,
) -> std::cmp::Ordering {
    use std::cmp::Ordering;
    match (a, b) {
        (None, None) => Ordering::Equal,
        (None, Some(_)) => Ordering::Greater,
        (Some(_), None) => Ordering::Less,
        (Some(a), Some(b)) => apply_direction(
            a.partial_cmp(&b).unwrap_or(Ordering::Equal),
            ascending,
        ),
    }
}

fn apply_direction(ordering: std::cmp::Ordering, ascending: bool) -> std::cmp::Ordering {
    if ascending {
        ordering
    } else {
        ordering.reverse()
    }
}

// ---------------------------------------------------------------------------
// Stopping one process
// ---------------------------------------------------------------------------

/// How to ask a process to go.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ProcSignal {
    /// Asks. The process can clean up, and can also ignore it.
    Term,
    /// Does not ask. For a process that ignored [`ProcSignal::Term`] or cannot
    /// act on it.
    Kill,
}

impl ProcSignal {
    /// The shell's name for it, upper-case as `kill -s` takes it.
    ///
    /// Public because it is also the word an audit row names the signal with:
    /// a caller that spelled its own would be a second vocabulary for the same
    /// two things.
    pub fn name(self) -> &'static str {
        match self {
            Self::Term => "TERM",
            Self::Kill => "KILL",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ProcKillOutcome {
    Succeeded,
    /// The PID is gone, or now belongs to a process that started at a
    /// different time — something the kernel handed the number to after the
    /// list was read.
    TargetChanged,
    /// The process exists and this account may not signal it.
    Denied,
    Failed,
}

const KILL_SUCCEEDED: &str = "SrvBoxKill.Succeeded";
const KILL_TARGET_CHANGED: &str = "SrvBoxKill.TargetChanged";
const KILL_DENIED: &str = "SrvBoxKill.Denied";
const KILL_FAILED: &str = "SrvBoxKill.Failed";

/// Which signals mean something on `system`.
///
/// Windows has no polite request: `TerminateProcess` is the only stop there
/// is, so it is offered once, as what it is. BSD has none implemented here.
pub fn signals_for(system: SystemType) -> &'static [ProcSignal] {
    match system {
        SystemType::Windows => &[ProcSignal::Kill],
        SystemType::Linux => &[ProcSignal::Term, ProcSignal::Kill],
        SystemType::Bsd => &[],
    }
}

/// Whether [`kill_command`] can say anything for `target` on `system`. What a
/// page asks before it offers the action at all.
pub fn kill_supported(pid: i64, start_id: Option<&str>, system: SystemType) -> bool {
    signals_for(system)
        .iter()
        .any(|signal| kill_command(pid, start_id, system, *signal).is_some())
}

/// The command that stops one process, or `None` where it cannot be stopped
/// safely from here: no identity to check the PID against, or a platform with
/// no implementation (BSD).
///
/// Unix commands are POSIX `sh` and are meant to be fed to one as its stdin,
/// which is also what lets the same text run under `sudo`.
pub fn kill_command(
    pid: i64,
    start_id: Option<&str>,
    system: SystemType,
    signal: ProcSignal,
) -> Option<String> {
    let start_id = start_id?;
    match system {
        SystemType::Linux => Some(linux_kill_command(pid, start_id, signal)),
        SystemType::Windows => (signal == ProcSignal::Kill)
            .then(|| windows_kill_command(pid, start_id)),
        SystemType::Bsd => None,
    }
}

/// What a command answered.
pub fn kill_outcome(output: &str) -> ProcKillOutcome {
    if output.contains(KILL_SUCCEEDED) {
        return ProcKillOutcome::Succeeded;
    }
    if output.contains(KILL_TARGET_CHANGED) {
        return ProcKillOutcome::TargetChanged;
    }
    if output.contains(KILL_DENIED) {
        return ProcKillOutcome::Denied;
    }
    ProcKillOutcome::Failed
}

/// A pidfd where the machine has one, the PID where it does not.
///
/// The pidfd is the exact answer: opened before `/proc/<pid>/stat` is read, it
/// keeps naming that process even if the process exits and its number is
/// reused before the signal is sent. It needs python3 (the shell has no way to
/// hold one), Python 3.9 and Linux 5.3; Python answers with nothing where any
/// of those is missing — an `AttributeError` on `os.pidfd_open`, or an `OSError`
/// on a kernel that has no pidfd — and the shell does the same check by PID.
///
/// That fallback has a window between reading `stat` and `kill` in which the
/// PID could be reused. It is microseconds wide and needs the PID space to
/// wrap inside it. `kill`, `top` and `htop` check nothing at all, and the
/// alternative on Alpine and on an older kernel was not being able to stop a
/// process from here.
fn linux_kill_command(pid: i64, start_id: &str, signal: ProcSignal) -> String {
    let name = signal.name();
    let python = format!(
        r#"import os
import signal
import sys

pid = {pid}
expected = {expected}
try:
    fd = os.pidfd_open(pid)
    send = signal.pidfd_send_signal
except ProcessLookupError:
    print("{target_changed}")
    sys.exit(0)
except (AttributeError, OSError):
    sys.exit(0)
try:
    with open(f"/proc/{{pid}}/stat", encoding="utf-8") as stat_file:
        fields = stat_file.read().rsplit(") ", 1)[1].split()
    if fields[19] != expected:
        print("{target_changed}")
    else:
        send(fd, signal.SIG{name})
        print("{succeeded}")
except (ProcessLookupError, FileNotFoundError):
    print("{target_changed}")
except PermissionError:
    print("{denied}")
except Exception:
    print("{failed}")
finally:
    os.close(fd)
"#,
        pid = pid,
        // A JSON string literal, so a value with a quote or a backslash in it
        // arrives in the Python source as the text it was.
        expected = serde_json::to_string(start_id).unwrap_or_default(),
        name = name,
        target_changed = KILL_TARGET_CHANGED,
        succeeded = KILL_SUCCEEDED,
        denied = KILL_DENIED,
        failed = KILL_FAILED,
    );
    format!(
        r#"pid={pid}
expected={expected}
out=
if command -v python3 >/dev/null 2>&1; then
	out=$(python3 -c {python} 2>/dev/null)
fi
case $out in
SrvBoxKill.*) echo "$out" ;;
*)
	stat=
	[ -r "/proc/$pid/stat" ] && IFS= read -r stat < "/proc/$pid/stat"
	if [ -z "$stat" ]; then
		echo {target_changed}
	else
		set -f
		set -- ${{stat##*") "}}
		set +f
		if [ "${{20}}" != "$expected" ]; then
			echo {target_changed}
		elif kill -s {name} "$pid" 2>/dev/null; then
			echo {succeeded}
		elif [ -e "/proc/$pid" ]; then
			echo {denied}
		else
			echo {target_changed}
		fi
	fi
	;;
esac
"#,
        pid = pid,
        expected = single_quote(start_id),
        python = single_quote(&python),
        name = name,
        target_changed = KILL_TARGET_CHANGED,
        succeeded = KILL_SUCCEEDED,
        denied = KILL_DENIED,
    )
}

/// The PowerShell script, with `{pid}` and `{expected}` filled in.
///
/// Every `{` and `}` in it is a PowerShell brace and is doubled for `format!`
/// — the script is mostly braces, so a reader comparing it with the Dart it
/// was ported from has to read `{{` as `{`.
///
/// The handle is opened before the start time is read, which is what makes the
/// check hold: Windows does not reuse a process ID while a handle to the
/// process is open. The start time is read from `Win32_Process.CreationDate`,
/// the same place the table's `StartId` came from — `Get-Process`'s `StartTime`
/// is the same instant at 100ns, where CIM_DATETIME stops at microseconds, and
/// comparing the two refused nine stops in ten as a changed target.
fn windows_kill_command(pid: i64, start_id: &str) -> String {
    // Single-quoted PowerShell, where a quote is escaped by doubling it.
    let expected = format!("'{}'", start_id.replace('\'', "''"));
    let script = format!(
        r#"Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class SrvBoxNative {{ [DllImport("kernel32.dll", SetLastError=true)] public static extern bool TerminateProcess(IntPtr process, uint exitCode); }}' -ErrorAction SilentlyContinue; $p = Get-Process -Id {pid} -ErrorAction SilentlyContinue; if ($null -eq $p) {{ Write-Output '{target_changed}' }} else {{ try {{ $handle = $p.Handle; $c = Get-CimInstance Win32_Process -Filter 'ProcessId={pid}' -ErrorAction Stop; if ($null -eq $c -or $c.CreationDate.ToUniversalTime().Ticks.ToString() -ne {expected}) {{ Write-Output '{target_changed}' }} elseif ([SrvBoxNative]::TerminateProcess($handle, 1)) {{ $p.WaitForExit(); Write-Output '{succeeded}' }} else {{ Write-Output '{failed}' }} }} catch {{ Write-Output '{failed}' }} }}"#,
        pid = pid,
        expected = expected,
        target_changed = KILL_TARGET_CHANGED,
        succeeded = KILL_SUCCEEDED,
        failed = KILL_FAILED,
    );
    // `-EncodedCommand` takes UTF-16LE: the script is PowerShell, which is not
    // restricted to the machine's ANSI code page, and a process's image name
    // is whatever the writer of it chose.
    let mut utf16 = Vec::with_capacity(script.len() * 2);
    for unit in script.encode_utf16() {
        utf16.extend_from_slice(&unit.to_le_bytes());
    }
    use base64::Engine;
    format!(
        "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand {}",
        base64::engine::general_purpose::STANDARD.encode(utf16)
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn proc(pid: i64, command: &str) -> Proc {
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
    fn name_is_the_executable_without_a_rewritten_title() {
        assert_eq!(proc(9, "nginx: worker process").name(), "nginx");
        assert_eq!(
            proc(9, "/usr/lib/systemd/systemd-journald").name(),
            "systemd-journald"
        );
        assert_eq!(proc(9, "dockerd -H fd://").name(), "dockerd");
        assert_eq!(proc(9, "[kworker/0:1-events]").name(), "[kworker/0:1-events]");
        assert_eq!(proc(9, "(sd-pam)").name(), "(sd-pam)");
        // A Windows command line begins with a path this cannot split on
        // whitespace, which is why the image name travels beside it.
        let mut windows = proc(9, r#""C:\Program Files\nginx\nginx.exe" -g daemon"#);
        windows.process_name = Some("nginx.exe".to_string());
        assert_eq!(windows.name(), "nginx.exe");
    }

    #[test]
    fn binary_and_args_split_on_any_whitespace() {
        let tabbed = proc(1, "\t/usr/bin/worker\t--job  one");
        assert_eq!(tabbed.binary(), "/usr/bin/worker");
        assert_eq!(tabbed.args(), "--job  one");
        // Repeated whitespace inside the arguments is the command's, not a
        // column separator: this is what `ps` printed.
        assert_eq!(
            proc(1, "/bin/tool  --name 'a  b'").args(),
            "--name 'a  b'"
        );
        assert_eq!(proc(1, "").binary(), "");
        assert_eq!(proc(1, "").args(), "");
        assert_eq!(proc(1, "   ").name(), "");
    }

    #[test]
    fn elapsed_refuses_what_is_not_a_duration() {
        assert_eq!(parse_elapsed("05:03"), Some(303));
        assert_eq!(parse_elapsed("1:02:03"), Some(3723));
        assert_eq!(parse_elapsed("2-01:02:03"), Some(2 * 86400 + 3723));
        assert_eq!(parse_elapsed("-"), None);
        assert_eq!(parse_elapsed("1:2:3:4"), None);
        assert_eq!(parse_elapsed("1::3"), None);
        assert_eq!(parse_elapsed("-1:03"), None);
        // procps in a container whose boot time is not its host's.
        assert_eq!(parse_elapsed("441077234-00:18:40"), None);
    }

    #[test]
    fn a_missing_reading_is_not_a_reading_of_zero() {
        assert_eq!(proc(1, "x").rss_kb(), None);
        let mut with_rss = proc(1, "x");
        with_rss.rss = Some("-".to_string());
        assert_eq!(with_rss.rss_kb(), None);
        with_rss.rss = Some("-1".to_string());
        assert_eq!(with_rss.rss_kb(), None);
        with_rss.rss = Some("2048".to_string());
        assert_eq!(with_rss.rss_kb(), Some(2048));
    }

    #[test]
    fn an_absent_key_sorts_last_whichever_way_the_sort_runs() {
        let mut rows = vec![
            proc(1, "/a"),
            proc(2, "/b"),
            proc(3, "/c"),
        ];
        rows[0].cpu = Some(9.0);
        rows[1].cpu = None;
        rows[2].cpu = Some(1.0);

        sort_procs(&mut rows, ProcSortMode::Cpu, None);
        assert_eq!(rows.iter().map(|row| row.pid).collect::<Vec<_>>(), [1, 3, 2]);
        sort_procs(&mut rows, ProcSortMode::Cpu, Some(true));
        assert_eq!(rows.iter().map(|row| row.pid).collect::<Vec<_>>(), [3, 1, 2]);
    }

    #[test]
    fn equal_values_tie_break_by_pid() {
        let mut rows = vec![proc(20, "/second"), proc(10, "/first")];
        rows[0].cpu = Some(5.0);
        rows[1].cpu = Some(5.0);
        sort_procs(&mut rows, ProcSortMode::Cpu, None);
        assert_eq!(rows.iter().map(|row| row.pid).collect::<Vec<_>>(), [10, 20]);
    }

    #[test]
    fn no_identity_no_command() {
        for system in [SystemType::Linux, SystemType::Bsd, SystemType::Windows] {
            for signal in [ProcSignal::Term, ProcSignal::Kill] {
                assert!(kill_command(12345, None, system, signal).is_none());
            }
            assert!(!kill_supported(12345, None, system));
        }
    }

    #[test]
    fn which_signals_each_platform_offers() {
        assert_eq!(
            signals_for(SystemType::Linux),
            [ProcSignal::Term, ProcSignal::Kill]
        );
        // TerminateProcess is the only stop Windows has, and it is not a
        // request.
        assert_eq!(signals_for(SystemType::Windows), [ProcSignal::Kill]);
        assert!(kill_command(1, Some("2"), SystemType::Windows, ProcSignal::Term).is_none());
        assert!(kill_command(1, Some("2"), SystemType::Windows, ProcSignal::Kill).is_some());
        assert!(kill_supported(1, Some("2"), SystemType::Windows));

        assert!(signals_for(SystemType::Bsd).is_empty());
        assert!(!kill_supported(1, Some("2"), SystemType::Bsd));
    }

    #[test]
    fn the_signal_named_is_the_signal_sent() {
        let term = kill_command(1, Some("2"), SystemType::Linux, ProcSignal::Term).unwrap();
        let kill = kill_command(1, Some("2"), SystemType::Linux, ProcSignal::Kill).unwrap();
        assert!(term.contains("signal.SIGTERM"));
        assert!(term.contains("kill -s TERM"));
        assert!(!term.contains("KILL"));
        assert!(kill.contains("signal.SIGKILL"));
        assert!(kill.contains("kill -s KILL"));
    }

    #[test]
    fn outcome_reads_the_marker_and_anything_else_is_a_failure() {
        assert_eq!(kill_outcome("SrvBoxKill.Succeeded\n"), ProcKillOutcome::Succeeded);
        assert_eq!(
            kill_outcome("noise\nSrvBoxKill.TargetChanged\n"),
            ProcKillOutcome::TargetChanged
        );
        assert_eq!(kill_outcome("SrvBoxKill.Denied"), ProcKillOutcome::Denied);
        assert_eq!(kill_outcome(""), ProcKillOutcome::Failed);
        assert_eq!(
            kill_outcome("Traceback (most recent call last)"),
            ProcKillOutcome::Failed
        );
    }

    #[test]
    fn a_start_id_cannot_escape_its_quoting() {
        let hostile = "1'; touch /tmp/owned; echo '";
        let command = kill_command(7, Some(hostile), SystemType::Linux, ProcSignal::Term).unwrap();
        // The shell sees one argument: the text, quoted.
        assert!(command.contains(&single_quote(hostile)));
        assert!(!command.contains("expected=1'; touch"));

        let windows =
            kill_command(7, Some("1' ; Remove-Item x ; '2"), SystemType::Windows, ProcSignal::Kill)
                .unwrap();
        // The script travels base64'd, so the check is on what PowerShell will
        // parse: the quote doubled, inside one single-quoted literal.
        assert!(decode_powershell(&windows).contains("-ne '1'' ; Remove-Item x ; ''2'"));
    }

    #[test]
    fn windows_compares_the_start_time_the_table_was_read_from() {
        let command =
            kill_command(12345, Some("4242"), SystemType::Windows, ProcSignal::Kill).unwrap();
        let script = decode_powershell(&command);

        // CIM's CreationDate, like the table's StartId: Get-Process's StartTime
        // is the same instant at a finer precision, and never compared equal.
        assert!(script.contains("Win32_Process -Filter 'ProcessId=12345'"));
        assert!(script.contains("CreationDate.ToUniversalTime().Ticks"));
        assert!(!script.contains("StartTime"));
        // The handle is taken before the check, so the PID cannot be reused
        // between the two.
        assert!(
            script.find("$handle = $p.Handle").unwrap()
                < script.find("CreationDate").unwrap()
        );
        assert!(script.contains("-ne '4242'"));
    }

    /// The command's last word is the script, little-endian UTF-16 in base64.
    fn decode_powershell(command: &str) -> String {
        use base64::Engine;
        let encoded = command.split(' ').next_back().unwrap();
        let bytes = base64::engine::general_purpose::STANDARD
            .decode(encoded)
            .unwrap();
        String::from_utf16(
            &bytes
                .chunks_exact(2)
                .map(|pair| u16::from_le_bytes([pair[0], pair[1]]))
                .collect::<Vec<_>>(),
        )
        .unwrap()
    }

    #[test]
    fn a_read_speed_needs_a_counter_on_both_sides() {
        let mut first = proc(1, "/a");
        first.start_id = Some("100".to_string());
        first.read_bytes = Some(1000);
        let mut second = proc(1, "/a");
        second.start_id = Some("100".to_string());
        second.read_bytes = Some(3000);

        assert_eq!(
            calculate_speeds(Some(3000), None, Some(&first), Some(2.0)),
            (Some(1000.0), None)
        );
        // The same reading twice is no interval at all.
        assert_eq!(
            calculate_speeds(Some(3000), None, Some(&first), Some(0.0)),
            (None, None)
        );
        // A counter that went backwards is a number that was handed to another
        // process, not a negative speed.
        assert_eq!(
            calculate_speeds(Some(500), None, Some(&second), Some(2.0)),
            (None, None)
        );
    }
}
