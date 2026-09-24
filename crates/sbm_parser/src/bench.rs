//! Yet Another Bench Script, and the commands that install, start, watch, stop
//! and clean up after a run of it.
//!
//! **The script is shipped, not fetched.** `curl -sL yabs.sh | bash` is how
//! upstream documents it, and it pins no version and verifies nothing — the
//! machine runs whatever that URL served, decided by neither the user nor the
//! caller. It also fails outright on the large share of hosts that cannot reach
//! raw.githubusercontent.com, which is the same set of hosts people most want
//! to benchmark.
//!
//! The bytes are *not* here. The script is an asset
//! (`assets/yabs.b64`, base64, for the reason `YabsScript` in the app gives),
//! and whoever ships it decodes it; this module is the command layer and the
//! parser over what those commands print, which is the half both callers share.
//! [`UPSTREAM_VERSION`] is part of that: it is also the remote filename, so a
//! caller that writes the script and a caller that asks about it cannot name
//! two different files.
//!
//! The run itself is detached (`setsid`) and everything it reports is written
//! into its run directory, which is what makes closing the page, losing the
//! network or locking a phone cost nothing. See `start_entry` and
//! `poll_command`.
//!
// TODO(migration): `lib/data/model/server/benchmark/yabs_script.dart` is the
// same protocol against the same markers, and it is still what the app runs
// over SSH. Collapse onto this one — the app through FFI — and delete it, the
// way `script.rs` replaced its Dart counterpart. Until then an edit here has to
// be made there too, which is the whole reason the rules above are stated
// twice.

use serde::{Deserialize, Serialize};

/// `YABS_VERSION` inside the script. Also the remote filename, so a machine
/// that already has this version skips the write.
pub const UPSTREAM_VERSION: &str = "v2026-07-24";

/// The upstream revision the shipped asset was taken from. A version string
/// alone does not identify a file — upstream amends within one.
pub const UPSTREAM_COMMIT: &str = "f8c6a48cd6ff85b54c5cd2504f0807462dc58938";

/// SHA-256 of the *decoded* asset, so it means the program a machine is sent.
/// The app's own test holds this against the file; the agent asserts the asset
/// it embeds still carries [`UPSTREAM_VERSION`].
pub const SHA256_HEX: &str = "c42397c6a97c32d1b0f75bbee7ab4cca0c9b6c8871c9334d51991f938bb4ae7b";

/// Upstream, for the attribution a configuration sheet shows. WTFPL.
pub const UPSTREAM_URL: &str = "https://github.com/masonr/yet-another-bench-script";

/// Where the script lives on a machine.
///
/// Beside the status script's own directory, and for the same reasons: it
/// survives a reboot, it is the invoking user's, and one agent and one SSH
/// login reach the same copy.
pub const BASE_DIR: &str = "$HOME/.config/server_box/bench";

/// [`BASE_DIR`] without the `$HOME`, for a caller that writes the script itself
/// and so has to resolve a real path: a shell expands the literal, an agent
/// running as its own user does not need it to.
pub const BASE_DIR_RELATIVE: &str = ".config/server_box/bench";

/// The script's path, versioned exactly as `srvboxm_v<N>.sh` is: it is what
/// lets "the file is there" mean "the right file is there", so an upgraded
/// caller replaces it without comparing anything.
pub fn script_path() -> String {
    format!("{BASE_DIR}/{}", script_file_name())
}

/// The leaf name [`script_path`] ends in, and how a caller that writes the file
/// itself knows what to call it.
pub fn script_file_name() -> String {
    format!("yabs_{UPSTREAM_VERSION}.sh")
}

/// The directory a run happens in — and therefore **the filesystem fio
/// measures**, which is why it follows the working directory rather than always
/// living beside the script.
///
/// A fixed name per working directory rather than one per run, so a run can be
/// found again after the caller was closed, the phone changed network or the
/// connection dropped. Only one benchmark per machine makes sense at a time, so
/// there is nothing to collide with.
pub fn run_dir(work_dir: &str) -> String {
    let work = work_dir.trim();
    if work.is_empty() {
        return format!("{BASE_DIR}/run");
    }
    format!("{}/{}", strip_trailing_slashes(work), RUN_DIR_NAME)
}

/// The leaf name [`run_dir`] produces under a working directory, and the
/// fallback's own leaf. Both are asserted by [`cleanup_command`].
pub const RUN_DIR_NAME: &str = ".server_box_bench";

fn strip_trailing_slashes(path: &str) -> &str {
    let bytes = path.as_bytes();
    let mut end = bytes.len();
    while end > 1 && bytes[end - 1] == b'/' {
        end -= 1;
    }
    &path[..end]
}

/// Names the run that owns a directory.
///
/// Written before the launcher is detached, and read by two things that
/// otherwise have to guess. [`cleanup_command`] will not `rm -rf` a directory
/// this does not vouch for, which matters because the path is built from a
/// working directory the user typed. And its presence is what separates "the
/// run has not written its pid yet" from "the run is gone", which a poll
/// arriving in the first moments cannot tell apart otherwise.
pub const OWNER_FILE: &str = "owner";

/// Which Geekbench release to run. The digit is the flag: yabs spells the
/// choice `-4`, `-5`, `-6`, `-7`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum GeekbenchVersion {
    V4,
    V5,
    V6,
    V7,
}

impl GeekbenchVersion {
    pub fn digit(self) -> u8 {
        match self {
            GeekbenchVersion::V4 => 4,
            GeekbenchVersion::V5 => 5,
            GeekbenchVersion::V6 => 6,
            GeekbenchVersion::V7 => 7,
        }
    }

    /// The word a stored record is written with, so a rename of a variant
    /// cannot rewrite what an older record says.
    pub fn as_str(self) -> &'static str {
        match self {
            GeekbenchVersion::V4 => "v4",
            GeekbenchVersion::V5 => "v5",
            GeekbenchVersion::V6 => "v6",
            GeekbenchVersion::V7 => "v7",
        }
    }
}

/// What the user asked a run to do.
///
/// Every phase yabs can run is a field here, because each costs something the
/// person paying for the machine is the only one who can weigh: disk writes,
/// egress, or telling a third party about the host. The defaults are an opinion
/// and nothing more — none of them is enforced.
///
/// Three of them deliberately disagree with yabs' own defaults, each in the
/// direction that spends less of someone else's money or discloses less:
///
/// - `cpu` is off. A Geekbench run **publishes** its result — CPU model, core
///   count, memory, and a public `browser.geekbench.com` URL — and downloads a
///   proprietary binary to do it.
/// - `reduced_network` is on. The full set is seven locations, each tested in
///   both directions for 15 seconds with eight parallel streams: on a 1 Gbps
///   host that is tens of gigabytes, twice over if the machine has both address
///   families.
/// - `ip_info` is off. The lookup sends the host's public address to
///   `ip-api.com` over **plaintext HTTP**.
///
/// yabs' `-p` — a custom iperf server list — is deliberately not offered. Its
/// `host:port_range:name:location:modes` is a format to get wrong rather than a
/// setting to choose, and the built-in locations are what makes one machine's
/// numbers comparable with another's.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(default)]
pub struct BenchOptions {
    /// fio: 4k/64k/512k/1m, mixed read/write, ~30s each. Writes a 2 GB test file
    /// (512 MB on ARM) into the run directory and needs that much free, or yabs
    /// skips the phase and says so in the log.
    pub disk: bool,
    /// iperf3 against public servers. See [`Self::reduced_network`] for the cost.
    pub network: bool,
    /// Three iperf locations instead of seven.
    pub reduced_network: bool,
    /// Geekbench. Off by default — see the note on this type.
    pub cpu: bool,
    pub geekbench_version: GeekbenchVersion,
    /// Look the host's public address up with ip-api.com. Off by default — see
    /// the note on this type.
    pub ip_info: bool,
    /// yabs' `-b`: use the binaries it ships rather than the host's own fio and
    /// iperf3.
    ///
    /// Off, so a host that has the packages uses them and needs no network for
    /// this at all. Turning it on means fetching from raw.githubusercontent.com,
    /// which a good share of hosts cannot reach.
    pub prefer_precompiled_binaries: bool,
    /// Where the run happens, and therefore which filesystem fio measures.
    ///
    /// Empty means the invoking account's home directory. Anyone benchmarking a
    /// second disk needs this; there is no other way to point fio at one.
    pub work_dir: String,
}

impl Default for BenchOptions {
    fn default() -> Self {
        BenchOptions {
            disk: true,
            network: true,
            reduced_network: true,
            cpu: false,
            geekbench_version: GeekbenchVersion::V6,
            ip_info: false,
            prefer_precompiled_binaries: false,
            work_dir: String::new(),
        }
    }
}

impl BenchOptions {
    /// Whether this asks for anything at all.
    ///
    /// Everything off still collects the system information header, which is a
    /// legitimate thing to want and takes seconds — so this is not an error,
    /// only something a form says out loud before the run starts.
    pub fn is_system_info_only(&self) -> bool {
        !self.disk && !self.network && !self.cpu
    }

    /// The yabs flags, in the order its `getopts` loop reads them.
    ///
    /// `-w` is not here: the output path belongs to the launcher, which owns the
    /// directory it writes into.
    pub fn flags(&self) -> Vec<String> {
        let mut flags = Vec::new();
        if self.prefer_precompiled_binaries {
            flags.push("-b".to_string());
        }
        if !self.disk {
            flags.push("-f".to_string());
        }
        if !self.network {
            flags.push("-i".to_string());
        }
        // Only meaningful with the network phase on, and yabs reads a stray one
        // harmlessly — but a flag list that says something the run will not do
        // is a flag list nobody can check against the log.
        if self.network && self.reduced_network {
            flags.push("-r".to_string());
        }
        if !self.ip_info {
            flags.push("-n".to_string());
        }
        // Never both: `-g` sets the skip and any digit clears the default, so
        // sending the pair would ask for a version of a phase that is skipped.
        if self.cpu {
            flags.push(format!("-{}", self.geekbench_version.digit()));
        } else {
            flags.push("-g".to_string());
        }
        flags
    }
}

// --- Commands ---

/// The launcher, written into the run directory and started detached.
///
/// A file rather than a command line because everything about a run — the
/// flags, three redirections, and an exit code written after the fact — would
/// otherwise have to be nested inside the quoting of a `setsid sh -c` inside
/// the quoting of whatever the caller's transport adds, which is a place bugs
/// live and cannot be tested from here.
///
/// It records **its own** pid rather than the shell's `$!`: started under
/// `setsid` it is a session leader, so that pid is also the process group every
/// child of the run inherits, and killing the group is the only way to stop a
/// benchmark — fio, iperf3 and Geekbench are separate processes and killing the
/// launcher alone would orphan whichever one is running.
pub fn launcher(options: &BenchOptions) -> String {
    let args = std::iter::once(quote_path(&script_path()))
        .chain(options.flags().iter().map(|f| quote(f)))
        .chain([quote("-w"), quote("out.json")])
        .collect::<Vec<_>>()
        .join(" ");
    format!(
        "#!/bin/sh\n\
         # Generated by ServerBox. Removed with the run directory.\n\
         cd \"$(dirname \"$0\")\" || exit 1\n\
         echo $$ > pid\n\
         {args} > log 2>&1\n\
         echo $? > exit\n"
    )
}

/// Installs [`launcher`] from stdin and starts it, in one command.
///
/// `setsid` is what makes the run outlive the connection that started it:
/// without it the benchmark dies with the channel, which on a phone means it
/// dies when the screen locks. Where `setsid` is missing, `nohup` alone still
/// survives the channel — it only costs the process group, which
/// [`cancel_command`] handles.
///
/// All three of the launcher's own streams are redirected away before it is
/// backgrounded. A detached child that keeps stdout open holds the channel open
/// with it, and the caller then waits for a process nobody is tracking.
pub fn start_entry(options: &BenchOptions, run_id: &str) -> String {
    let dir = quote_path(&run_dir(&options.work_dir));
    posix(&format!(
        "mkdir -p {dir} && cat > {dir}/run.sh && chmod +x {dir}/run.sh \
         && cd {dir} && rm -f out.json log exit pid \
         && printf %s {} > {dir}/{OWNER_FILE} \
         && {{ if command -v setsid >/dev/null 2>&1; then \
         setsid ./run.sh >/dev/null 2>&1 </dev/null & \
         else nohup ./run.sh >/dev/null 2>&1 </dev/null & fi; }} \
         && echo {STARTED}",
        quote(run_id)
    ))
}

/// The marker [`start_entry`] answers with.
pub const STARTED: &str = "SBM_BENCH_STARTED";

/// One request that answers everything a page needs: whether the run is still
/// going, what it has printed, and the result if it has one.
///
/// The result is included on every poll rather than fetched afterwards. It costs
/// nothing while the run is going — yabs writes `out.json` only at the very end
/// — and it removes the window where a run finished, the caller asked for the
/// file, and the connection dropped in between.
///
/// The log comes last so that nothing in it can be mistaken for a marker
/// belonging to a later section; it is the only part carrying arbitrary text.
///
/// Takes the directory rather than the options it could be derived from: the
/// run's own directory is recorded on its record, and that stored value is what
/// a later caller must poll. Re-deriving it would quietly send a changed
/// derivation looking somewhere the running benchmark is not.
pub fn poll_command(run_dir: &str) -> String {
    let dir = quote_path(run_dir);
    posix(&format!(
        r#"d={dir}
e=`cat "$d/exit" 2>/dev/null | tr -dc '0-9-'`
p=`cat "$d/pid" 2>/dev/null | tr -dc '0-9'`
a=0
if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then a=1; fi
s=0
if [ -d "$d" ]; then s=1; fi
f=0
if [ -f "$d/pid" ]; then f=1; fi
echo "{STATE_MARKER} exit=$e alive=$a started=$s pid=$f"
echo {JSON_MARKER}
cat "$d/out.json" 2>/dev/null
echo
echo {PS_MARKER}
if [ -n "$p" ] && [ -d /proc ]; then
  for e in /proc/[0-9]*; do
    [ -r "$e/stat" ] || continue
    pg=`sed 's/^.*) //' "$e/stat" 2>/dev/null | awk '{{print $3}}'`
    [ "$pg" = "$p" ] || continue
    c=`tr '\0' ' ' < "$e/cmdline" 2>/dev/null`
    [ -n "$c" ] || c=`sed -n 's/^Name:[[:space:]]*//p' "$e/status" 2>/dev/null`
    echo "${{e#/proc/}} $c"
  done
elif [ -n "$p" ]; then
  ps -o pid=,args= -p "$p" 2>/dev/null || true
fi
echo {LOG_MARKER}
cat "$d/log" 2>/dev/null
"#
    ))
}

pub const STATE_MARKER: &str = "SBM_BENCH_STATE";
pub const JSON_MARKER: &str = "SBM_BENCH_JSON";
pub const PS_MARKER: &str = "SBM_BENCH_PS";
pub const LOG_MARKER: &str = "SBM_BENCH_LOG";

/// Stops a run.
///
/// The negative pid is the process group, which is what actually ends a
/// benchmark: the launcher is a shell waiting on a child, and killing it alone
/// leaves fio writing or Geekbench running. The plain-pid fallback is for the
/// `nohup` path in [`start_entry`], where there is no group of our own to signal
/// — there the children are left to their own timeouts, which fio and iperf3
/// have and Geekbench does not.
///
/// Writes the exit file itself, because a killed launcher never reaches the line
/// that would have.
pub fn cancel_command(run_dir: &str) -> String {
    let dir = quote_path(run_dir);
    posix(&format!(
        r#"d={dir}
p=`cat "$d/pid" 2>/dev/null | tr -dc '0-9'`
if [ -n "$p" ]; then
  kill -TERM -"$p" 2>/dev/null || kill -TERM "$p" 2>/dev/null
  sleep 2
  kill -KILL -"$p" 2>/dev/null || kill -KILL "$p" 2>/dev/null
fi
[ -f "$d/exit" ] || echo {CANCELLED_EXIT_CODE} > "$d/exit"
echo {CANCELLED}
"#
    ))
}

/// 128 + SIGTERM, the shell's own convention for it, so a reader of the stored
/// record sees a number that means something.
pub const CANCELLED_EXIT_CODE: i32 = 143;
pub const CANCELLED: &str = "SBM_BENCH_CANCELLED";

/// Removes the run directory once its result has been read, or `None` when the
/// path is not one [`run_dir`] could have produced.
///
/// Recursive because yabs creates a timestamped working directory inside this
/// one and only removes it when it exits normally — a cancelled run leaves a
/// 2 GB fio file behind, which is not something to leave on someone's disk.
///
/// The path is asserted rather than trusted. It is built from a working
/// directory the user types, and `rm -rf` on a path assembled from user input
/// deserves a check that it is still the directory this module names — even
/// though the only way to reach it is through [`run_dir`].
pub fn cleanup_command(run_dir: &str, run_id: &str) -> Option<String> {
    let leaf_ok = run_dir.ends_with(&format!("/{RUN_DIR_NAME}")) || run_dir.ends_with("/run");
    if !leaf_ok {
        return None;
    }
    let dir = quote_path(run_dir);
    // Two checks, because neither is enough on its own. The shape rules out a
    // path this module could not have produced; the marker rules out a
    // directory of that shape that some other run — or something that is not a
    // run at all — happens to own.
    Some(posix(&format!(
        "d={dir}\n\
         if [ \"`cat \"$d/{OWNER_FILE}\" 2>/dev/null`\" = {} ]; then\n  \
         rm -rf \"$d\" && echo {CLEANED}\n\
         else\n  echo {NOT_OURS}\n\
         fi\n",
        quote(run_id)
    )))
}

/// The directory did not carry this run's marker, so nothing was removed.
pub const NOT_OURS: &str = "SBM_BENCH_NOT_OURS";
pub const CLEANED: &str = "SBM_BENCH_CLEANED";

// --- What a poll answered ---

/// What one [`poll_command`] answered.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct BenchPollState {
    /// Whether this is an answer to the poll at all.
    ///
    /// False when the output carried no state line — the command never ran, or
    /// what came back was not its output. A caller whose transport answers an
    /// empty body on its own timeout would otherwise read the resulting all-zero
    /// state as "the run directory is gone" and fail a benchmark that is running
    /// perfectly well.
    ///
    /// So: not answered means ask again. [`Self::dir_exists`] is only meaningful
    /// once this is true.
    pub answered: bool,
    /// `None` while the run is still going: the launcher writes this file as its
    /// last act.
    pub exit_code: Option<i32>,
    /// Whether the launcher's process is still there.
    ///
    /// Both this and [`Self::exit_code`] are needed. A run killed by the OOM
    /// killer — which a Geekbench run on a small VPS invites — leaves no exit
    /// file and no process, and only the pair tells that apart from a run still
    /// in its first second.
    pub alive: bool,
    /// Whether the run directory is there at all. False means nothing was ever
    /// started here, or it has been cleaned up.
    pub dir_exists: bool,
    /// Whether the launcher has recorded its pid yet.
    ///
    /// The start command creates the directory and returns as soon as it has
    /// backgrounded the launcher, so the first poll routinely arrives before the
    /// launcher has run a single line. Without this, that moment — a directory,
    /// no process, no exit code — is indistinguishable from a run that died.
    pub launcher_started: bool,
    pub log: String,
    /// The run's process group, as a listing — what it is actually doing.
    ///
    /// Empty when the far side has no `ps` that took the flags, which is not
    /// worth failing over: this exists to explain a silence, and a missing
    /// explanation is the state the page was already in.
    pub processes: String,
    /// The raw `out.json` text, or `None` before yabs writes it.
    ///
    /// Raw rather than parsed: the record keeps the text, so what this build
    /// could not read is not lost.
    pub result_json: Option<String>,
}

impl BenchPollState {
    pub fn finished(&self) -> bool {
        self.answered && self.exit_code.is_some()
    }

    /// Started, no exit code, and no process left to produce one.
    pub fn died_without_reporting(&self) -> bool {
        self.answered
            && self.dir_exists
            && self.launcher_started
            && !self.alive
            && self.exit_code.is_none()
    }

    /// Reads the fixed shape [`poll_command`] prints.
    ///
    /// Tolerant of a missing section: over a transport that caps output the
    /// answer can be truncated, and half an answer is still worth more than an
    /// exception — the log is the part that grows, and it is last for exactly
    /// this reason.
    pub fn parse(output: &str) -> Self {
        let Some(state_idx) = output.find(STATE_MARKER) else {
            return BenchPollState::default();
        };
        let state_end = output[state_idx..]
            .find('\n')
            .map(|offset| state_idx + offset)
            .unwrap_or(output.len());
        let state_line = &output[state_idx..state_end];

        let field = |name: &str| -> Option<i32> {
            let rest = state_line.split(&format!("{name}=")).nth(1)?;
            let digits: String = rest.chars().take_while(|c| c.is_ascii_digit() || *c == '-').collect();
            if digits.is_empty() || digits == "-" {
                return None;
            }
            digits.parse().ok()
        };

        let json_idx = output[state_idx..].find(JSON_MARKER).map(|i| state_idx + i);
        let after_json = json_idx.unwrap_or(state_idx);
        let ps_idx = output[after_json..].find(PS_MARKER).map(|i| after_json + i);
        let after_ps = ps_idx.unwrap_or(after_json);
        let log_idx = output[after_ps..].find(LOG_MARKER).map(|i| after_ps + i);

        let result_json = json_idx.and_then(|idx| {
            let start = idx + JSON_MARKER.len();
            let end = ps_idx.or(log_idx).unwrap_or(output.len());
            let text = output[start.min(end)..end].trim();
            (!text.is_empty()).then(|| text.to_string())
        });

        let processes = ps_idx.map_or(String::new(), |idx| {
            let start = idx + PS_MARKER.len();
            let end = log_idx.unwrap_or(output.len());
            output[start.min(end)..end].trim().to_string()
        });

        let log = log_idx.map_or(String::new(), |idx| {
            output[(idx + LOG_MARKER.len()).min(output.len())..]
                .trim_start()
                .to_string()
        });

        BenchPollState {
            answered: true,
            exit_code: field("exit"),
            alive: field("alive") == Some(1),
            dir_exists: field("started") == Some(1),
            // Absent from an older caller's answer, which reads as `None`.
            // Treated as "started" there, so this is no stricter than the check
            // it replaced.
            launcher_started: field("pid") != Some(0),
            log,
            processes,
            result_json,
        }
    }
}

// --- Quoting ---

/// Wraps `value` so a POSIX shell reads it as one literal word.
///
/// Single quotes, because inside them the shell expands nothing at all; double
/// quotes would still leave `$`, `` ` `` and `\` live. An embedded single quote
/// ends the string, escapes itself outside it, and opens a new one.
///
/// Every path and flag value on the way to a shell goes through this. The
/// working directory is typed by the user and ends up on a command line on a
/// machine they own.
pub fn quote(value: &str) -> String {
    crate::script::shell_quote_unix(value)
}

/// [`quote`], except that a leading `$HOME` is left for the shell to expand.
///
/// Single quotes suppress *everything*, `$HOME` included, so quoting these paths
/// the ordinary way would send a literal `$HOME/.config/...` and every command
/// would fail on a directory of that name. The remainder is still quoted, which
/// is what matters: a home directory with a space in it is unusual on a server
/// and completely ordinary on the macOS and Windows machines this also has to
/// work against.
///
/// Adjacent quoted words concatenate in the shell, so `"$HOME"'/rest'` is one
/// argument.
pub fn quote_path(path: &str) -> String {
    const PREFIX: &str = "$HOME/";
    match path.strip_prefix(PREFIX) {
        Some(tail) => format!("\"$HOME\"/{}", quote(tail)),
        None => quote(path),
    }
}

/// Hands `script` to `sh`, rather than to whatever shell the account uses.
///
/// A login shell may be fish, which removed backticks, or csh, which has no
/// `if ...; then`. Either turns every script here into a syntax error, and a
/// syntax error is not an exception — the command "succeeds" with a diagnostic
/// on stderr and none of the markers the caller is looking for, which surfaced
/// as "the server did not answer the poll" from a server that was answering.
///
/// This is the convention the rest of the crate already follows:
/// [`crate::script::exec_command`] emits `sh <path> -<flag>` for the same
/// reason. Only the wrapper has to survive the login shell, and `sh -c '...'`
/// parses the same in every shell anyone logs in with.
pub fn posix(script: &str) -> String {
    format!("sh -c {}", quote(script))
}

// --- What a run is going to cost ---

/// What a set of options is going to cost, shown before the run starts.
///
/// The numbers are yabs' own parameters rather than measurements, and they exist
/// because both costs are invisible at the moment the decision is made and
/// expensive by the time they are not: a disk test that takes three minutes is a
/// surprise on a page with a spinner, and an iperf run is tens of gigabytes on a
/// plan somebody pays for by the gigabyte.
///
/// Deliberately rounded and deliberately labelled "about". A precise-looking
/// figure derived from a link speed nobody has measured would be a worse answer
/// than an approximate one that is honest about being approximate.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BenchEstimate {
    /// Whole minutes, rounded up.
    pub minutes: u32,
    /// Bytes iperf will move at the assumed link rate.
    pub traffic_bytes: u64,
    /// Free space the disk phase needs, or `None` when it is not running.
    pub required_free_bytes: Option<u64>,
}

/// yabs runs four block sizes for 30 seconds each, plus setup.
const DISK_MINUTES: f64 = 3.0;
/// Seven locations, or three, each tested in both directions with a 15 second
/// timeout and up to three attempts.
const PER_LOCATION_MINUTES: f64 = 0.6;
/// Download, run, upload. Geekbench 6 on a small VPS is routinely worse.
const CPU_MINUTES: f64 = 6.0;
const FULL_LOCATIONS: f64 = 7.0;
const REDUCED_LOCATIONS: f64 = 3.0;
/// Both address families are tested when the host has both, which doubles the
/// network phase. Assumed, since it is the common case on a VPS and guessing low
/// is the direction that surprises people.
const ADDRESS_FAMILIES: f64 = 2.0;
/// 1 Gbps, which is what a VPS usually has. A host with ten times that moves ten
/// times this, and the point is the order of magnitude.
const ASSUMED_BITS_PER_SEC: f64 = 1e9;
const SECONDS_PER_DIRECTION: f64 = 15.0;
const DIRECTIONS: f64 = 2.0;

/// Free space the disk phase needs. yabs skips the phase below this and says so
/// only in the log, so it is worth stating up front.
pub const DISK_FREE_BYTES: u64 = 2 * 1024 * 1024 * 1024;

pub fn estimate(options: &BenchOptions) -> BenchEstimate {
    let mut total = 1.0;
    if options.disk {
        total += DISK_MINUTES;
    }
    if options.network {
        total += locations(options) * PER_LOCATION_MINUTES * ADDRESS_FAMILIES;
    }
    if options.cpu {
        total += CPU_MINUTES;
    }
    BenchEstimate {
        minutes: total.ceil() as u32,
        traffic_bytes: if options.network {
            traffic_bytes_of(locations(options))
        } else {
            0
        },
        required_free_bytes: options.disk.then_some(DISK_FREE_BYTES),
    }
}

/// The same figure for the other setting, so a switch can say what it saves
/// rather than only what it does.
pub fn traffic_bytes_for(reduced: bool) -> u64 {
    traffic_bytes_of(if reduced {
        REDUCED_LOCATIONS
    } else {
        FULL_LOCATIONS
    })
}

fn locations(options: &BenchOptions) -> f64 {
    if options.reduced_network {
        REDUCED_LOCATIONS
    } else {
        FULL_LOCATIONS
    }
}

fn traffic_bytes_of(locations: f64) -> u64 {
    (locations * DIRECTIONS * ADDRESS_FAMILIES * SECONDS_PER_DIRECTION * ASSUMED_BITS_PER_SEC / 8.0)
        as u64
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_launcher_carries_the_flags_and_writes_its_own_pid() {
        let options = BenchOptions::default();
        let launcher = launcher(&options);
        assert!(launcher.starts_with("#!/bin/sh"));
        assert!(launcher.contains("echo $$ > pid"), "{launcher}");
        // Every flag is quoted, and `-w out.json` is the runner's own.
        assert!(launcher.contains("'-r'"), "{launcher}");
        assert!(launcher.contains("'-w' 'out.json'"), "{launcher}");
        assert!(launcher.contains("> log 2>&1"), "{launcher}");
        assert!(launcher.contains("echo $? > exit"), "{launcher}");
    }

    #[test]
    fn flags_follow_yabs_order_and_never_ask_for_both_geekbench_forms() {
        assert_eq!(BenchOptions::default().flags(), vec!["-r", "-n", "-g"]);

        let everything = BenchOptions {
            cpu: true,
            ip_info: true,
            disk: false,
            network: false,
            prefer_precompiled_binaries: true,
            ..Default::default()
        };
        // -b, -f, -i, then no -r (network is off), no -n (ip info is on), and
        // the digit rather than -g.
        assert_eq!(everything.flags(), vec!["-b", "-f", "-i", "-6"]);

        // `-g` and a digit together would ask for a version of a phase that is
        // skipped.
        let skipped = BenchOptions {
            cpu: false,
            ..Default::default()
        };
        assert!(skipped.flags().contains(&"-g".to_string()));
        assert!(!skipped.flags().iter().any(|f| f.len() == 2 && f.starts_with('-') && f.as_bytes()[1].is_ascii_digit()));
    }

    #[test]
    fn the_script_path_is_the_versioned_file_under_the_home_directory() {
        assert_eq!(script_path(), format!("{BASE_DIR}/yabs_{UPSTREAM_VERSION}.sh"));
        // The three forms have to describe one file: a caller that writes it and
        // a caller that names it in a command both go through here.
        assert_eq!(
            script_path(),
            format!("$HOME/{BASE_DIR_RELATIVE}/{}", script_file_name())
        );
    }

    #[test]
    fn the_run_directory_follows_the_working_directory() {
        assert_eq!(run_dir(""), format!("{BASE_DIR}/run"));
        assert_eq!(run_dir("   "), format!("{BASE_DIR}/run"));
        assert_eq!(run_dir("/mnt/data/"), "/mnt/data/.server_box_bench");
        assert_eq!(run_dir("/mnt/data///"), "/mnt/data/.server_box_bench");
        // A root working directory still resolves to a subdirectory this module
        // named, which is what makes cleanup's shape check meaningful. The
        // doubled slash is the app's own output for this input, which is what
        // matters: a run one caller starts has to be the run the other finds.
        assert_eq!(run_dir("/"), "//.server_box_bench");
    }

    #[test]
    fn cleanup_refuses_a_path_it_could_not_have_produced() {
        assert!(cleanup_command("/home/me", "bench_1").is_none());
        assert!(cleanup_command("/", "bench_1").is_none());
        let command = cleanup_command(&run_dir("/"), "bench_1").unwrap();
        assert!(command.contains(".server_box_bench"));
        assert!(command.contains("bench_1"));
    }

    #[test]
    fn an_answer_that_is_not_one_is_told_apart_from_a_missing_run() {
        let none = BenchPollState::parse("");
        assert!(!none.answered);
        assert!(!none.finished());
        assert!(!none.died_without_reporting());

        let gone = BenchPollState::parse(&format!("{STATE_MARKER} exit= alive=0 started=0"));
        assert!(gone.answered);
        assert!(!gone.dir_exists);
        assert!(!gone.finished());
        assert!(!gone.died_without_reporting());
    }

    #[test]
    fn a_log_containing_the_markers_cannot_forge_a_state() {
        let output = [
            format!("{STATE_MARKER} exit= alive=1 started=1"),
            JSON_MARKER.to_string(),
            String::new(),
            LOG_MARKER.to_string(),
            format!("{STATE_MARKER} exit=0 alive=0 started=1"),
            JSON_MARKER.to_string(),
            r#"{"malicious":true}"#.to_string(),
        ]
        .join("\n");

        let state = BenchPollState::parse(&output);
        assert!(!state.finished());
        assert!(state.alive);
        assert!(state.result_json.is_none());
        assert!(state.log.contains("malicious"));
    }

    #[test]
    fn a_full_answer_parses_every_section() {
        let output = format!(
            "{STATE_MARKER} exit=0 alive=0 started=1 pid=1\n{JSON_MARKER}\n\
             {{\"version\":\"v1\"}}\n{PS_MARKER}\n1234 fio --name=randread\n{LOG_MARKER}\n\
             args: -r -n -g -w out.json\n"
        );
        let state = BenchPollState::parse(&output);
        assert!(state.finished());
        assert_eq!(state.exit_code, Some(0));
        assert!(!state.alive);
        assert!(state.dir_exists);
        assert!(state.launcher_started);
        assert_eq!(state.result_json.as_deref(), Some("{\"version\":\"v1\"}"));
        assert_eq!(state.processes, "1234 fio --name=randread");
        assert!(state.log.starts_with("args:"));
    }

    #[test]
    fn a_directory_with_no_pid_yet_is_not_a_run_that_died() {
        // The line the poll actually prints for a directory whose launcher has
        // not written its pid: `pid=0`, which is the field's absence meaning
        // something. A line with the field missing entirely is an older
        // caller's answer and is deliberately read as "started".
        let state = BenchPollState::parse(&format!("{STATE_MARKER} exit= alive=0 started=1 pid=0"));
        assert!(state.dir_exists);
        assert!(!state.alive);
        assert!(!state.finished());
        assert!(!state.launcher_started);
        assert!(!state.died_without_reporting());

        let older = BenchPollState::parse(&format!("{STATE_MARKER} exit= alive=0 started=1"));
        assert!(older.launcher_started);
    }

    #[test]
    fn a_pid_whose_process_is_gone_is_a_run_that_died() {
        let state = BenchPollState::parse(&format!("{STATE_MARKER} exit= alive=0 started=1 pid=1"));
        assert!(state.launcher_started);
        assert!(!state.alive);
        assert!(state.died_without_reporting());
    }

    #[test]
    fn every_command_is_one_sh_c_with_everything_inside_it() {
        // Structural, so this holds on any machine: only the wrapper has to
        // survive the login shell, and `sh -c '<one word>'` parses the same
        // everywhere. Anything after the closing quote would not.
        for command in [
            start_entry(&BenchOptions::default(), "bench_x"),
            poll_command(&run_dir("")),
            cancel_command(&run_dir("")),
            cleanup_command(&run_dir(""), "bench_x").unwrap(),
        ] {
            let body = command
                .strip_prefix("sh -c '")
                .unwrap_or_else(|| panic!("not an sh -c wrapper: {command}"));
            let closed = body
                .strip_suffix('\'')
                .unwrap_or_else(|| panic!("the quoted argument is not closed: {command}"));
            // Every inner quote has to be the `'\''` idiom, never a bare one
            // that would end the argument early.
            assert!(
                !closed.replace("'\\''", "").contains('\''),
                "the quoted argument ends before the script does: {command}"
            );
        }
    }

    #[test]
    fn the_estimate_is_rounded_up_and_says_what_is_running() {
        let everything = estimate(&BenchOptions {
            disk: true,
            network: true,
            cpu: true,
            ..Default::default()
        });
        // 1 + 3 + (3 * 0.6 * 2) + 6 = 13.6
        assert_eq!(everything.minutes, 14);
        assert_eq!(everything.required_free_bytes, Some(DISK_FREE_BYTES));
        assert!(everything.traffic_bytes > 0);

        let system_info_only = estimate(&BenchOptions {
            disk: false,
            network: false,
            cpu: false,
            ..Default::default()
        });
        assert_eq!(system_info_only.minutes, 1);
        assert_eq!(system_info_only.traffic_bytes, 0);
        assert_eq!(system_info_only.required_free_bytes, None);
        assert!(BenchOptions {
            disk: false,
            network: false,
            cpu: false,
            ..Default::default()
        }
        .is_system_info_only());

        // Reduced is what the default asks for, and the full set is what the
        // switch says it costs.
        assert!(traffic_bytes_for(true) < traffic_bytes_for(false));
    }
}
