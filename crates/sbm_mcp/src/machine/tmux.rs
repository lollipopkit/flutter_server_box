//! The tmux sessions on a machine: [`sbm_parser::tmux`]'s commands, in order.

use serde_json::{Value, json};

use super::{Machine, Ran, Run};

/// The sessions, or `available: false` when tmux is not installed — or could
/// not be looked for, which `error` says.
///
/// "No server running" — tmux installed, no session started — is
/// `available: true` with an empty list: there is nothing to attach to, which
/// is an answer rather than a failure. A listing that failed for any other
/// reason says so in `error`, since an empty list would otherwise read as
/// "this machine has no sessions".
pub async fn sessions(m: &dyn Machine) -> Value {
    // Found through a fixed command, never named by the caller: a binary path
    // from a request would be a way to run something else.
    let bin = match m.run(Run::Line(sbm_parser::tmux::FIND_COMMAND), 0).await {
        Ok(out) if out.timed_out || out.truncated => Err(failure_reason(&out)),
        Ok(out) => Ok(sbm_parser::tmux::parse_find(&out.stdout, out.exit_code == Some(0))),
        Err(e) => Err(e),
    };
    let bin = match bin {
        Ok(Some(bin)) => bin,
        Ok(None) => return json!({ "available": false, "sessions": [], "error": null }),
        Err(e) => return json!({ "available": false, "sessions": [], "error": e }),
    };
    let (sessions, error) = match m.run(Run::Line(&sbm_parser::tmux::list_sessions_command(&bin)), 0).await {
        Ok(out) => match read_listing(&out) {
            Some(listing) => (listing.sessions, None),
            None => (Vec::new(), Some(failure_reason(&out))),
        },
        Err(e) => (Vec::new(), Some(e)),
    };
    json!({ "available": true, "sessions": sessions, "error": error })
}

/// The listing, or `None` when it failed; no server running is no sessions.
fn read_listing(out: &Ran) -> Option<sbm_parser::tmux::TmuxSessionListing> {
    // A cut or stopped answer is no listing, whatever its exit code says.
    if out.timed_out || out.truncated {
        return None;
    }
    let code = out.exit_code?;
    let output = if code == 0 { &out.stdout } else { &out.stderr };
    sbm_parser::tmux::read_sessions(output, code)
}

/// A one-line reason a listing failed: the command's own words where it had
/// any. Never the whole output.
fn failure_reason(out: &Ran) -> String {
    if out.timed_out {
        return "did not finish in time".to_owned();
    }
    if out.truncated {
        return "printed more than is read".to_owned();
    }
    if let Some(line) = out.stderr.lines().map(str::trim).find(|l| !l.is_empty()) {
        return line.to_owned();
    }
    match out.exit_code {
        Some(code) => format!("exited {code}"),
        None => "did not finish".to_owned(),
    }
}

#[cfg(test)]
mod tests {
    use super::super::fake::{Fake, ok};
    use super::*;
    use sbm_parser::SystemType;

    #[tokio::test]
    async fn a_lookup_that_could_not_run_says_so() {
        let m = Fake::new(SystemType::Linux, vec![]);
        let answer = sessions(&m).await;
        assert_eq!(answer["available"], false);
        assert!(answer["error"].is_string(), "{answer}");

        let m = Fake::new(SystemType::Linux, vec![("command -v tmux", Ran { exit_code: Some(1), ..ok("") })]);
        assert_eq!(sessions(&m).await["error"], Value::Null);
    }

    #[test]
    fn a_cut_listing_is_no_listing() {
        assert!(read_listing(&Ran { truncated: true, ..ok("main: 1 windows") }).is_none());
    }
}
