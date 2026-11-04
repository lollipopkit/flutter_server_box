//! The session a command runs in over SSH, and what kills it.
//!
//! sshd starts every command in a session of its own (`setsid()`), so its
//! login shell's pid is the session id, and an `exec` keeps the pid. That id
//! reaches every process the command started that did not leave the session
//! — which a process group does not: `set -m`, a build tool or a shell's job
//! control moves children into groups of their own, out of reach of the
//! signal SSH delivers.
//!
//! The command prints its session id on stderr ([`wrap`]); the client reads
//! it back ([`find_marker`]), checks that the session is its own run's
//! ([`owns_command`]) and kills what is left in it ([`kill_command`]).

/// Exported by [`wrap`], with the run's own nonce, to everything the command
/// starts: what ties a session id read off stderr to this run.
pub const ENV_NAME: &str = "SBM_EXEC_ID";

/// What [`owns_command`] prints when the session is this run's.
pub const OWNED: &str = "sbm-session-owned";

/// What [`kill_command`] prints when nothing is left in the session.
pub const GONE: &str = "sbm-session-gone";

const MARKER_START: &[u8] = b"\x1esbm-sid:";
const MARKER_END: &[u8] = b"\x1e\n";

/// `command` run as before — by the login shell, `$SHELL` — after `sh` has
/// printed the session marker on stderr and exported [`ENV_NAME`] as `nonce`.
///
/// The login shell need not be a POSIX one, so what it is handed is valid in
/// fish as well: one single-quoted program, and `command` single-quoted with
/// every `'` and `\` written as a `printf %b` escape — inside single quotes
/// fish reads only `\'` and `\\`, POSIX shells nothing at all. A shell that
/// rejects it anyway (cmd.exe, PowerShell, csh with a newline in quotes) runs
/// none of `command`: the marker is printed before it starts.
///
/// `nonce` is hex, as the client draws it: it is written into the program
/// unquoted.
pub fn wrap(command: &str, nonce: &str) -> String {
    assert_hex(nonce);
    let arg = command.replace('\\', r"\0134").replace('\'', r"\0047");
    format!(
        r#"exec sh -c 'printf "\036sbm-sid:%s\036\n" $$ >&2; export {ENV_NAME}={nonce}; exec "${{SHELL:-sh}}" -c "$(printf %b "$1")"' sbm '{arg}'"#
    )
}

/// Kills every process left in session `id` and prints [`GONE`] when none
/// is: POSIX `sh`, handed over in single quotes as [`wrap`] does, so that a
/// fish login shell can run it too. Signals the process group as well, for a
/// `pkill` without `-s`.
///
/// Waits a moment only when there was something to kill, for it to be gone
/// from the process table.
pub fn kill_command(id: u32) -> String {
    format!(
        "sh -c 'kill -KILL -- -{id} 2>/dev/null; pkill -KILL -s {id} 2>/dev/null && sleep 1; pgrep -s {id} >/dev/null 2>&1; [ $? -eq 1 ] && echo {GONE}'"
    )
}

/// Prints [`OWNED`] when one of session `id`'s processes carries
/// [`ENV_NAME`] as `nonce`, read as the account — and so only from its own
/// processes, and not at all without `/proc`.
///
/// The id comes off stderr, which the login shell's startup files write to
/// before the wrapper runs: nothing is killed by it until this has said the
/// session is this run's, so a forged one reaches neither another session of
/// the account nor, through its sudo password, one it could not have touched.
/// Asked before the signal, while the command's own shell still carries the
/// nonce: sudo resets the environment of what it runs, and the signal ends
/// sudo itself, which runs as the account.
pub fn owns_command(id: u32, nonce: &str) -> String {
    assert_hex(nonce);
    format!(
        r#"sh -c 'for p in $(pgrep -s {id}); do tr "\0" "\n" </proc/$p/environ 2>/dev/null | grep -qx {ENV_NAME}={nonce} && echo {OWNED} && exit 0; done'"#
    )
}

/// A nonce is interpolated into shell programs unquoted, so it is never
/// anything but hex digits.
fn assert_hex(nonce: &str) {
    assert!(!nonce.is_empty() && nonce.bytes().all(|b| b.is_ascii_hexdigit()), "a nonce is hex digits");
}

/// Where [`wrap`]'s marker is in what the caller searched, and the id it
/// carries: byte offsets into that window (the caller searches each new
/// chunk with a marker's length of what came before, never all of stderr), so the caller passes on what surrounds it as it was.
/// Looked for anywhere rather than on the first line: a login shell's rc file
/// can print before it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SessionMarker {
    pub start: u32,
    pub end: u32,
    pub id: u32,
}

pub fn find_marker(head: &[u8]) -> Option<SessionMarker> {
    let mut from = 0;
    while let Some(at) = find(&head[from..], MARKER_START) {
        let start = from + at;
        let digits = start + MARKER_START.len();
        let len = head[digits..].iter().take_while(|b| b.is_ascii_digit()).count();
        let after = digits + len;
        if len > 0 && head[after..].starts_with(MARKER_END) {
            // An id too large for a pid is not this marker: keep looking.
            if let Some(id) = std::str::from_utf8(&head[digits..after]).ok().and_then(|d| d.parse().ok()) {
                return Some(SessionMarker { start: start as u32, end: (after + MARKER_END.len()) as u32, id });
            }
        }
        from = start + 1;
    }
    None
}

fn find(haystack: &[u8], needle: &[u8]) -> Option<usize> {
    haystack.windows(needle.len()).position(|w| w == needle)
}

/// Bytes of what came before a new chunk that a marker split across chunks
/// can still need.
pub const MARKER_MAX: u32 = (MARKER_START.len() + 10 + MARKER_END.len()) as u32;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_marker_is_found_after_what_an_rc_file_printed() {
        let said = b"welcome\n\x1esbm-sid:4242\x1e\nwarning: x\n";
        assert_eq!(find_marker(said), Some(SessionMarker { start: 8, end: 23, id: 4242 }));
        assert_eq!(find_marker(b"\x1esbm-sid:12"), None, "not yet whole");
        assert_eq!(find_marker(b"\x1esbm-sid:x\x1e\n\x1esbm-sid:7\x1e\n").map(|m| m.id), Some(7));
    }

    #[test]
    fn an_id_too_large_for_a_pid_is_passed_over_for_the_real_one() {
        let said = b"\x1esbm-sid:99999999999\x1e\n\x1esbm-sid:31\x1e\n";
        assert_eq!(find_marker(said).map(|m| m.id), Some(31));
        assert!(MARKER_MAX as usize >= b"\x1esbm-sid:4294967295\x1e\n".len());
    }

    #[test]
    #[should_panic(expected = "a nonce is hex digits")]
    fn a_nonce_that_is_not_hex_is_refused() {
        owns_command(1, "x; rm -rf ~");
    }
}

/// Run by the shells this machine has, as sshd would: `<shell> -c`, with
/// `SHELL` set to it. One not installed is said to have been skipped.
#[cfg(all(test, unix))]
mod shell_tests {
    use super::*;
    use std::process::Command;

    const SCRIPT: &str = "printf '%s|' \"a'b\" 'c\\\\d' \"$((1+2))\" '\\0047'\necho 'line2 \\n' done";

    fn shell(name: &str) -> Option<String> {
        let found = ["/bin", "/usr/bin", "/usr/local/bin", "/opt/homebrew/bin"]
            .iter()
            .map(|d| format!("{d}/{name}"))
            .find(|p| std::path::Path::new(p).exists());
        if found.is_none() {
            eprintln!("skipped: {name} is not installed");
        }
        found
    }

    #[test]
    fn the_command_runs_as_before_after_its_session_is_printed() {
        for name in ["sh", "bash", "zsh", "fish", "dash"] {
            let Some(sh) = shell(name) else { continue };
            let plain = Command::new(&sh).args(["-c", SCRIPT]).env("SHELL", &sh).output().unwrap();
            let wrapped = Command::new(&sh).args(["-c", &wrap(SCRIPT, "0abc")]).env("SHELL", &sh).output().unwrap();
            let marker = find_marker(&wrapped.stderr).unwrap_or_else(|| panic!("{name}: no marker"));
            assert_eq!(marker.start, 0, "{name}: printed before anything else");
            assert_eq!(wrapped.stdout, plain.stdout, "{name}");
            assert_eq!(wrapped.status.code(), plain.status.code(), "{name}");
        }
    }

    /// A shell that refuses the wrapper runs none of the command: the client
    /// runs it again, untracked, and it must not run twice.
    #[test]
    fn a_shell_that_refuses_the_wrapper_runs_none_of_the_command() {
        for name in ["csh", "tcsh"] {
            let Some(sh) = shell(name) else { continue };
            let wrapped = Command::new(&sh).args(["-c", &wrap(SCRIPT, "0abc")]).env("SHELL", &sh).output().unwrap();
            if find_marker(&wrapped.stderr).is_none() {
                assert!(wrapped.stdout.is_empty(), "{name}: {}", String::from_utf8_lossy(&wrapped.stdout));
            }
        }
    }

    #[test]
    fn the_exit_code_and_the_nonce_reach_the_command() {
        let r = Command::new("/bin/sh").args(["-c", &wrap("exit 7", "0abc")]).env("SHELL", "/bin/sh").output().unwrap();
        assert_eq!(r.status.code(), Some(7));
        let r = Command::new("/bin/sh")
            .args(["-c", &wrap(&format!("echo \"${ENV_NAME}\""), "0abc")])
            .env("SHELL", "/bin/sh")
            .output()
            .unwrap();
        assert_eq!(r.stdout, b"0abc\n");
    }

    #[test]
    fn the_kill_and_the_ownership_check_are_one_command_each() {
        for name in ["sh", "fish"] {
            let Some(sh) = shell(name) else { continue };
            for program in [kill_command(123), owns_command(123, "0abc")] {
                // `printf` in place of `sh`: what the login shell hands on, unrun.
                let r = Command::new(&sh).args(["-c", &program.replacen("sh -c ", "printf %s ", 1)]).output().unwrap();
                assert!(r.status.success(), "{name}: {}", String::from_utf8_lossy(&r.stderr));
                let parsed = Command::new("/bin/sh").args(["-n", "-c", std::str::from_utf8(&r.stdout).unwrap()]).output().unwrap();
                assert!(parsed.status.success(), "{name}: {}", String::from_utf8_lossy(&parsed.stderr));
            }
        }
    }
}
