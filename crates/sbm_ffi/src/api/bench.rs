//! Benchmark FFI (sbm_parser::bench)
//!
//! The commands that install, start, watch, stop and clear a yabs run, and
//! what a poll printed — the ones the monitor agent runs for its panel, for
//! the app's benchmark page. The app runs them over its own connection.
//! Options cross as `sbm_parser::bench::BenchOptions` JSON.

use sbm_parser::bench::{self, BenchOptions, BenchPollState};

fn options(json: &str) -> Result<BenchOptions, String> {
    serde_json::from_str(json).map_err(|e| e.to_string())
}

/// The vendored yabs release, for the attribution the page shows.
#[flutter_rust_bridge::frb(sync)]
pub fn bench_upstream_version() -> String {
    bench::UPSTREAM_VERSION.to_owned()
}

/// The vendored asset as the program a machine is sent; `None` for one that
/// will not decode, which is a packaging mistake to report rather than run.
pub fn bench_decode_asset(encoded: String) -> Option<String> {
    bench::decode_asset(&encoded)
}

/// Whether the server has this version of the script already: read the
/// answer with [`bench_script_present`].
#[flutter_rust_bridge::frb(sync)]
pub fn bench_probe_command() -> String {
    bench::probe_command()
}

#[flutter_rust_bridge::frb(sync)]
pub fn bench_script_present(output: String) -> bool {
    output.contains(bench::SCRIPT_PRESENT)
}

/// Run with the script on stdin; read the answer with
/// [`bench_script_installed`].
#[flutter_rust_bridge::frb(sync)]
pub fn bench_install_entry() -> String {
    bench::install_entry()
}

#[flutter_rust_bridge::frb(sync)]
pub fn bench_script_installed(output: String) -> bool {
    output.contains(bench::SCRIPT_INSTALLED)
}

/// The directory a run happens in: the filesystem fio measures.
#[flutter_rust_bridge::frb(sync)]
pub fn bench_run_dir(options_json: String) -> Result<String, String> {
    Ok(bench::run_dir(&options(&options_json)?.work_dir))
}

/// The launcher, sent on stdin to [`bench_start_entry`].
#[flutter_rust_bridge::frb(sync)]
pub fn bench_launcher(options_json: String) -> Result<String, String> {
    Ok(bench::launcher(&options(&options_json)?))
}

/// Writes the launcher and starts it detached; read the answer with
/// [`bench_started`].
#[flutter_rust_bridge::frb(sync)]
pub fn bench_start_entry(options_json: String, run_id: String) -> Result<String, String> {
    Ok(bench::start_entry(&options(&options_json)?, &run_id))
}

#[flutter_rust_bridge::frb(sync)]
pub fn bench_started(output: String) -> bool {
    output.contains(bench::STARTED)
}

#[flutter_rust_bridge::frb(sync)]
pub fn bench_poll_command(run_dir: String) -> String {
    bench::poll_command(&run_dir)
}

/// What a poll printed.
pub struct BenchPoll {
    /// The command produced something this recognises at all.
    pub answered: bool,
    pub exit_code: Option<i32>,
    pub alive: bool,
    pub dir_exists: bool,
    pub launcher_started: bool,
    pub log: String,
    pub processes: String,
    pub result_json: Option<String>,
    /// Ended, with its exit code written.
    pub finished: bool,
    /// No exit code and no process: killed (the OOM killer, say).
    pub died_without_reporting: bool,
}

#[flutter_rust_bridge::frb(sync)]
pub fn bench_parse_poll(output: String) -> BenchPoll {
    let s = BenchPollState::parse(&output);
    BenchPoll {
        finished: s.finished(),
        died_without_reporting: s.died_without_reporting(),
        answered: s.answered,
        exit_code: s.exit_code,
        alive: s.alive,
        dir_exists: s.dir_exists,
        launcher_started: s.launcher_started,
        log: s.log,
        processes: s.processes,
        result_json: s.result_json,
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn bench_cancel_command(run_dir: String) -> String {
    bench::cancel_command(&run_dir)
}

/// The exit code a cancelled run records.
#[flutter_rust_bridge::frb(sync)]
pub fn bench_cancelled_exit_code() -> i32 {
    bench::CANCELLED_EXIT_CODE
}

/// Clears the run directory where it is this run's; `None` where the
/// directory is not one this could have made.
#[flutter_rust_bridge::frb(sync)]
pub fn bench_cleanup_command(run_dir: String, run_id: String) -> Option<String> {
    bench::cleanup_command(&run_dir, &run_id)
}
