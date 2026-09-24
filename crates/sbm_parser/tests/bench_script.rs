//! The benchmark commands, run against a real `/bin/sh`, ported from the app's
//! `test/unit/benchmark/yabs_script_test.dart` per the "tests as spec" rule.
//!
//! Everything here is a string assembled by [`sbm_parser::bench`] and executed
//! by a shell on someone else's machine, with one user-typed value — a working
//! directory — inside it. A quoting mistake in that is not a compile error and
//! not a failure anywhere else: on a machine it is either a command that
//! silently does nothing or one that does something nobody asked for. So these
//! run the actual fragments, with a stand-in for yabs, and check what ends up on
//! disk.
//!
//! The install half of the app's suite is deliberately absent. Over SSH the
//! script has to be uploaded, which is why `probe_command` and `install_entry`
//! exist; an agent writes the file itself, and never runs either.

#![cfg(unix)]

use std::path::Path;
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

use sbm_parser::bench::{
    self, BenchOptions, BenchPollState,
};

/// The id a caller mints per run. It stamps a run directory as this run's, and
/// cleanup checks it before deleting anything.
const RUN_ID: &str = "bench_test_1";

fn sh(home: &Path, command: &str, stdin_text: Option<&str>) -> (String, String, i32) {
    let mut child = Command::new("/bin/sh")
        .arg("-c")
        .arg(command)
        .env("HOME", home)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("sh is on every machine this runs on");
    if let Some(text) = stdin_text {
        use std::io::Write;
        child
            .stdin
            .as_mut()
            .expect("stdin was requested as piped")
            .write_all(text.as_bytes())
            .expect("the stand-in script is small enough to write in one go");
    }
    drop(child.stdin.take());
    let output = child.wait_with_output().expect("sh was started");
    (
        String::from_utf8_lossy(&output.stdout).into_owned(),
        String::from_utf8_lossy(&output.stderr).into_owned(),
        output.status.code().unwrap_or(-1),
    )
}

/// A run that has been started, and is stopped before the test ends.
///
/// The launcher is detached under `setsid`, so it belongs to no process this
/// test waits on: an assertion that fails before the run is awaited, or before
/// the cancel test asks for a stop, would leave it running with nothing left in
/// the test that knows about it — and the temporary directory is then deleted
/// under a live process.
struct Run {
    home: std::path::PathBuf,
    options: BenchOptions,
}

impl Run {
    fn dir(&self) -> String {
        bench::run_dir(&self.options.work_dir).replace("$HOME", &self.home.to_string_lossy())
    }

    fn start(&self) -> String {
        sh(
            &self.home,
            &bench::start_entry(&self.options, RUN_ID),
            Some(&bench::launcher(&self.options)),
        )
        .0
    }

    fn poll(&self) -> BenchPollState {
        let (stdout, _, _) = sh(&self.home, &bench::poll_command(&bench::run_dir(&self.options.work_dir)), None);
        BenchPollState::parse(&stdout)
    }

    /// Waits for the detached launcher to report an exit code.
    ///
    /// **Every test that starts a run has to reach this, or stop the run, before
    /// it returns.** Bounded by the clock rather than by a poll count: each poll
    /// spawns a shell, so under a parallel run the same number of iterations can
    /// be a fraction of the wall time it is meant to allow.
    fn wait(&self) -> BenchPollState {
        let deadline = Instant::now() + Duration::from_secs(30);
        let mut last = None;
        while Instant::now() < deadline {
            let state = self.poll();
            if state.finished() {
                return state;
            }
            last = Some(state);
            std::thread::sleep(Duration::from_millis(50));
        }
        panic!(
            "the run never reported an exit code\nrun dir: {}\nlast poll: {:?}",
            self.dir(),
            last
        );
    }
}

impl Drop for Run {
    fn drop(&mut self) {
        // Stop first, delete second. The stand-in the cancel test installs
        // sleeps for a minute, so a failure before its `cancel_command` would
        // otherwise leave that process — and the child it spawns — running long
        // after the suite has moved on.
        //
        // Asked before it is stopped, because `cancel_command` sleeps two
        // seconds between its TERM and its KILL.
        if self.poll().alive {
            sh(&self.home, &bench::cancel_command(&bench::run_dir(&self.options.work_dir)), None);
        }
        // Retried anyway, because a stop is not instant and a launcher writing
        // its exit code into a tree being deleted fails the delete.
        for _ in 0..20 {
            if std::fs::remove_dir_all(&self.home).is_ok() || !self.home.exists() {
                return;
            }
            std::thread::sleep(Duration::from_millis(50));
        }
        let _ = std::fs::remove_dir_all(&self.home);
    }
}

fn home() -> std::path::PathBuf {
    let dir = std::env::temp_dir().join(format!(
        "sbm_bench_script_{}_{:?}",
        std::process::id(),
        std::thread::current().id()
    ));
    let _ = std::fs::remove_dir_all(&dir);
    std::fs::create_dir_all(&dir).unwrap();
    dir
}

/// A stand-in for the benchmark script: records the arguments it was given,
/// prints on both streams, and writes the `-w` file.
fn install_fake_script(home: &Path, exit_code: i32, json: &str, body: &str) {
    let path = home.join(bench::BASE_DIR_RELATIVE).join(bench::script_file_name());
    std::fs::create_dir_all(path.parent().unwrap()).unwrap();
    let script = if body.is_empty() {
        format!(
            "#!/bin/sh\n\
             echo \"args: $*\"\n\
             echo \"on stderr\" >&2\n\
             while [ $# -gt 0 ]; do\n  \
               if [ \"$1\" = \"-w\" ]; then echo '{json}' > \"$2\"; fi\n  \
               shift\n\
             done\n\
             exit {exit_code}\n"
        )
    } else {
        body.to_string()
    };
    std::fs::write(&path, script).unwrap();
    // What the agent does when it writes the real one: the launcher execs this
    // file, and a copy that is not executable is exit 126 with nothing said.
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o755)).unwrap();
    }
}

// ---------- a run ----------

#[test]
fn a_run_reports_an_exit_code_and_hands_back_the_json() {
    let home = home();
    install_fake_script(&home, 0, r#"{"version":"v1","cpu":{"cores":4}}"#, "");
    let run = Run {
        home: home.clone(),
        options: BenchOptions::default(),
    };

    assert!(run.start().contains(bench::STARTED));
    let state = run.wait();

    assert!(state.finished());
    assert_eq!(state.exit_code, Some(0));
    assert!(!state.alive);
    assert!(state.dir_exists);
    assert_eq!(
        state.result_json.as_deref(),
        Some(r#"{"version":"v1","cpu":{"cores":4}}"#)
    );
    // stdout and stderr both land in the log, which is what a page shows.
    assert!(state.log.contains("args:"), "{}", state.log);
    assert!(state.log.contains("on stderr"), "{}", state.log);
}

#[test]
fn the_options_reach_the_script_as_flags() {
    let home = home();
    install_fake_script(&home, 0, "{}", "");
    let run = Run {
        home,
        options: BenchOptions {
            cpu: true,
            ip_info: true,
            disk: false,
            ..Default::default()
        },
    };
    run.start();
    let state = run.wait();

    let args = state
        .log
        .lines()
        .find_map(|line| line.strip_prefix("args: "))
        .unwrap_or_default();
    // -f because disk is off, -6 because cpu is on, no -n because ip info is
    // on, -r because the network phase stays reduced.
    assert!(args.contains("-f"), "{args}");
    assert!(args.contains("-r"), "{args}");
    assert!(args.contains("-6"), "{args}");
    assert!(!args.contains("-n"), "{args}");
    assert!(!args.contains("-g"), "{args}");
    assert!(args.contains("-w out.json"), "{args}");
}

#[test]
fn a_non_zero_exit_is_reported_rather_than_swallowed() {
    let home = home();
    install_fake_script(&home, 3, "{}", "");
    let run = Run {
        home,
        options: BenchOptions::default(),
    };
    run.start();

    assert_eq!(run.wait().exit_code, Some(3));
}

// ---------- the user-typed value ----------

#[test]
fn a_working_directory_with_spaces_and_quotes_still_works() {
    let home = home();
    install_fake_script(&home, 0, "{}", "");
    let work = home.join("we're here").join("some dir");
    std::fs::create_dir_all(&work).unwrap();
    let run = Run {
        home,
        options: BenchOptions {
            work_dir: work.to_string_lossy().into_owned(),
            ..Default::default()
        },
    };
    run.start();
    run.wait();

    // fio measures whatever filesystem this is on, which is the reason the
    // option exists — so the run really has to happen there.
    assert!(work.join(".server_box_bench").join("out.json").is_file());
}

#[test]
fn a_working_directory_is_a_path_never_shell_syntax() {
    let home = home();
    install_fake_script(&home, 0, "{}", "");
    // If this were interpolated unquoted, the `;` would end the command and
    // `touch` would run. It is the one user-typed value left on these command
    // lines, and it reaches three of them.
    let injected = home.join(format!("x; touch {}/pwned", home.display()));
    std::fs::create_dir_all(&injected).unwrap();
    let run = Run {
        home: home.clone(),
        options: BenchOptions {
            work_dir: injected.to_string_lossy().into_owned(),
            ..Default::default()
        },
    };
    run.start();
    run.wait();

    assert!(!home.join("pwned").exists(), "an injected command ran");
    assert!(injected.join(".server_box_bench").join("run.sh").is_file());
}

// ---------- the moment before the launcher runs ----------

#[test]
fn a_directory_with_no_pid_yet_is_not_a_run_that_died() {
    // The start command creates the directory and returns as soon as it has
    // backgrounded the launcher. A poll arriving in that window sees a
    // directory, no process and no exit code — which is also what a run killed
    // by the OOM killer looks like.
    let home = home();
    let options = BenchOptions::default();
    let run = Run {
        home: home.clone(),
        options: options.clone(),
    };
    sh(&home, &format!("mkdir -p {}", bench::quote_path(&bench::run_dir(""))), None);

    let state = run.poll();
    assert!(state.dir_exists);
    assert!(!state.alive);
    assert!(!state.finished());
    assert!(!state.launcher_started);
    assert!(!state.died_without_reporting());
}

#[test]
fn a_pid_whose_process_is_gone_is_a_run_that_died() {
    let home = home();
    let options = BenchOptions::default();
    let run = Run {
        home: home.clone(),
        options: options.clone(),
    };
    let dir = bench::run_dir("");
    sh(
        &home,
        &format!(
            "mkdir -p {dir} && echo 2147483646 > {dir}/pid",
            dir = bench::quote_path(&dir)
        ),
        None,
    );

    let state = run.poll();
    assert!(state.launcher_started);
    assert!(!state.alive);
    assert!(state.died_without_reporting());
}

// ---------- cancelling ----------

#[test]
fn cancel_kills_the_process_group_and_marks_the_run_stopped() {
    let home = home();
    // A stand-in that sleeps, so there is something to interrupt, and that
    // spawns a child to prove the whole group goes.
    install_fake_script(&home, 0, "{}", "#!/bin/sh\nsleep 60 &\nsleep 60\n");
    let options = BenchOptions::default();
    let run = Run {
        home: home.clone(),
        options: options.clone(),
    };

    assert!(run.start().contains(bench::STARTED));

    // Wait for the launcher to record its pid before asking to stop it.
    let dir = home.join(bench::BASE_DIR_RELATIVE).join("run");
    let deadline = Instant::now() + Duration::from_secs(30);
    while !dir.join("pid").is_file() && Instant::now() < deadline {
        std::thread::sleep(Duration::from_millis(50));
    }
    assert!(dir.join("pid").is_file(), "the launcher never recorded its pid");
    assert!(run.poll().alive);

    let (stdout, _, _) = sh(&home, &bench::cancel_command(&bench::run_dir("")), None);
    assert!(stdout.contains(bench::CANCELLED), "{stdout}");

    let state = run.poll();
    assert!(state.finished());
    assert_eq!(state.exit_code, Some(bench::CANCELLED_EXIT_CODE));
    assert!(!state.alive);
}

// ---------- cleanup ----------

#[test]
fn cleanup_removes_the_run_directory_and_everything_under_it() {
    let home = home();
    install_fake_script(&home, 0, "{}", "");
    let options = BenchOptions::default();
    let run = Run {
        home: home.clone(),
        options: options.clone(),
    };
    run.start();
    run.wait();

    let dir = home.join(bench::BASE_DIR_RELATIVE).join("run");
    // yabs makes a timestamped working directory inside this one and only
    // removes it if it exits normally, so cleanup has to be recursive.
    std::fs::create_dir_all(dir.join("2026-01-01")).unwrap();

    let (stdout, _, _) = sh(
        &home,
        &bench::cleanup_command(&bench::run_dir(""), RUN_ID).unwrap(),
        None,
    );
    assert!(stdout.contains(bench::CLEANED), "{stdout}");
    assert!(!dir.exists());
    // The script itself survives: it is versioned and shared by every run.
    assert!(
        home.join(bench::BASE_DIR_RELATIVE)
            .join(bench::script_file_name())
            .is_file()
    );
}

#[test]
fn cleanup_will_not_delete_a_directory_it_does_not_own() {
    let home = home();
    install_fake_script(&home, 0, "{}", "");
    let options = BenchOptions::default();
    let run = Run {
        home: home.clone(),
        options: options.clone(),
    };
    run.start();
    run.wait();

    let dir = bench::run_dir("");
    let real = home.join(bench::BASE_DIR_RELATIVE).join("run");
    assert!(real.exists());

    // The path is the right shape and the marker is somebody else's, which is
    // the case the shape check alone cannot answer.
    let (stdout, _, _) = sh(&home, &bench::cleanup_command(&dir, "bench_other").unwrap(), None);
    assert!(stdout.contains(bench::NOT_OURS), "{stdout}");
    assert!(!stdout.contains(bench::CLEANED), "{stdout}");
    assert!(real.exists(), "a run that does not own this directory removed it");

    // And a directory of the right shape with no marker at all is left alone
    // too.
    std::fs::remove_file(real.join(bench::OWNER_FILE)).unwrap();
    let (stdout, _, _) = sh(&home, &bench::cleanup_command(&dir, RUN_ID).unwrap(), None);
    assert!(stdout.contains(bench::NOT_OURS), "{stdout}");
    assert!(real.exists());
}

// ---------- the login shell ----------

#[test]
fn a_fish_login_shell_runs_them_and_would_not_have_run_the_old_form() {
    let fish = ["/opt/homebrew/bin/fish", "/usr/local/bin/fish", "/usr/bin/fish"]
        .into_iter()
        .find(|path| Path::new(path).is_file());
    let Some(fish) = fish else {
        // Skipped rather than passed: the assertion is about fish, and a
        // machine without it can only say it did not run.
        eprintln!("no fish on this machine");
        return;
    };
    let home = home();
    // An empty run directory with an empty log in it, so the poll is a
    // complete answer: its last statement is the only thing that decides the
    // exit status, and against a directory that is not there `cat` fails.
    let run_dir = home.join(bench::BASE_DIR_RELATIVE).join("run");
    std::fs::create_dir_all(&run_dir).unwrap();
    std::fs::write(run_dir.join("log"), "").unwrap();

    // The wrapped form parses.
    let output = Command::new(fish)
        .args(["-c", &bench::poll_command(&bench::run_dir(""))])
        .env("HOME", &home)
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(0), "{}", String::from_utf8_lossy(&output.stderr));
    assert!(String::from_utf8_lossy(&output.stdout).contains(bench::STATE_MARKER));

    // The unwrapped form does not: backticks alone are a syntax error, and fish
    // reports it without failing in any way a caller would notice as an
    // exception.
    let bad = Command::new(fish)
        .args(["-c", "p=`echo 1`\nif [ -n \"$p\" ]; then echo MARKER; fi"])
        .env("HOME", &home)
        .output()
        .unwrap();
    assert!(!String::from_utf8_lossy(&bad.stdout).contains("MARKER"));
}

#[test]
fn a_working_directory_with_no_run_in_it_polls_as_absent() {
    // The state a page reads after the run directory has been cleaned up: the
    // answer to a poll that arrives after the page was reopened.
    let home = home();
    let run = Run {
        home,
        options: BenchOptions::default(),
    };

    let state = run.poll();
    assert!(state.answered);
    assert!(!state.dir_exists);
    assert!(!state.finished());
    assert!(state.log.is_empty());
    assert!(state.result_json.is_none());
}
