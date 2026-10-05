//! tmux discovery, ported with the app's Dart fixtures
//! (`test/unit/terminal/tmux_command_builder_test.dart`,
//! `tmux_session_info_test.dart`) before the Dart copy went.

use sbm_parser::tmux::*;
use std::process::Command;

#[test]
fn attach_commands_quote_their_arguments() {
    assert_eq!(attach_session_command("tmux", "main"), "'tmux' -u -CC attach-session -t 'main'");
    assert_eq!(attach_window_command("tmux", "main", 2), "'tmux' -u -CC attach-session -t 'main:2'");
    assert_eq!(
        new_session_or_attach_command("tmux", "user's-work"),
        "'tmux' -u -CC new-session -A -s 'user'\\''s-work'"
    );
    assert_eq!(
        attach_session_command("/opt/tmux builds/tmux'; echo injected; '", "main"),
        "'/opt/tmux builds/tmux'\\''; echo injected; '\\''' -u -CC attach-session -t 'main'"
    );
}

#[test]
fn discovery_commands_force_utf8_and_shell_generated_tabs() {
    let tab = "$(printf '\\t')";
    let sessions = list_sessions_command("tmux");
    assert!(sessions.starts_with("'tmux' -u list-sessions"));
    assert!(sessions.contains(&format!("\"#{{session_id}}{tab}#{{q:session_name}}")));
    assert!(!sessions.contains('\t'));
    let windows = list_windows_command("tmux", "main");
    assert!(windows.starts_with("'tmux' -u list-windows -t 'main'"));
    assert!(windows.contains("#{q:window_name}"));
    assert!(FIND_COMMAND.contains("command -v tmux"));
}

#[test]
fn sessions_parse_the_escaped_format() {
    let listing = parse_sessions("$0\tmain\\|with:colon\t3\t1\t2024-01-01\t2024-01-02\tactivity\n$1\tunicode\\344\\275\\240\t1\t0\n");
    assert_eq!(listing.unreadable, 0);
    let s = &listing.sessions[0];
    assert_eq!((s.id.as_str(), s.name.as_str(), s.windows, s.attached), ("$0", "main|with:colon", 3, true));
    assert_eq!(s.created.as_deref(), Some("2024-01-01"));
    assert_eq!(s.activity.as_deref(), Some("activity"));
    assert_eq!(listing.sessions[1].name, "unicode你");
    assert!(!listing.sessions[1].attached);
}

#[test]
fn malformed_sessions_are_counted_not_read() {
    for line in ["main\t1\t1", "$0\tmain\tx\t1", "$0\tbusy\t1\tgarbage", "$0\tbusy\t1\t", "@1\tw\t1\t0", "$\tx\t1\t0"] {
        let listing = parse_sessions(line);
        assert!(listing.sessions.is_empty(), "{line}");
        assert_eq!(listing.unreadable, 1, "{line}");
    }
    assert_eq!(parse_sessions("\n\n"), TmuxSessionListing::default());
}

#[test]
fn a_window_name_may_contain_the_old_separator() {
    let windows = parse_windows("2\tvim\\|logs\t1\t3\tnow\n0\tsh\t0\t\t\n");
    assert_eq!((windows[0].index, windows[0].name.as_str(), windows[0].active, windows[0].panes), (2, "vim|logs", true, 3));
    assert_eq!(windows[1].panes, 1);
    assert!(parse_windows("x\tname").is_empty());
}

#[test]
fn find_answers_a_path_or_nothing() {
    assert_eq!(parse_find("/usr/bin/tmux\n", true).as_deref(), Some("/usr/bin/tmux"));
    assert_eq!(parse_find("", true), None);
    assert_eq!(parse_find("/x", false), None);
}

/// Against a real tmux in the C locale, which is what broke the Android app:
/// without `-u` tmux replaced the tab separators with `_`.
#[test]
fn discovery_reads_a_real_tmux() {
    if Command::new("tmux").arg("-V").output().map(|o| !o.status.success()).unwrap_or(true) {
        eprintln!("skipped: tmux is not installed");
        return;
    }
    let dir = tempfile::tempdir().unwrap();
    let env = |c: &mut Command| {
        c.env("TMUX_TMPDIR", dir.path())
            .env("TMUX", "")
            .env("LANG", "C")
            .env("LC_ALL", "C")
            .env("LC_CTYPE", "C");
    };
    let mut new = Command::new("tmux");
    env(&mut new);
    assert!(new.args(["new-session", "-d", "-s", "dis|covery", "-n", "a|b"]).status().unwrap().success());

    let run = |command: &str| {
        let mut c = Command::new("/bin/sh");
        env(&mut c);
        String::from_utf8_lossy(&c.arg("-c").arg(command).output().unwrap().stdout).into_owned()
    };
    let listing = parse_sessions(&run(&list_sessions_command("tmux")));
    let windows = parse_windows(&run(&list_windows_command("tmux", "dis|covery")));

    let mut kill = Command::new("tmux");
    env(&mut kill);
    let _ = kill.arg("kill-server").status();

    assert_eq!(listing.unreadable, 0);
    assert!(listing.sessions.iter().any(|s| s.name == "dis|covery"), "{listing:?}");
    assert_eq!(windows.first().map(|w| w.name.as_str()), Some("a|b"));
}

#[test]
fn a_bashrc_banner_is_not_the_path() {
    assert_eq!(
        parse_find("Welcome to the box!\nload: 0.1\n/home/linuxbrew/.linuxbrew/bin/tmux\n", true).as_deref(),
        Some("/home/linuxbrew/.linuxbrew/bin/tmux")
    );
    assert_eq!(parse_find("only a banner\n", true), None);
}
