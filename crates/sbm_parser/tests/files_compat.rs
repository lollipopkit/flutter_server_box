//! The file browser's shell commands, ported with the app's Dart fixtures
//! (`test/unit/file/shell_file_ops_test.dart`) before the Dart copy went, and
//! run for real against a local `sh` where the Dart suite only read the text.

use sbm_parser::files::*;

fn record(name: &str, perm: &str, kind: &str, size: &str, at: &str) -> String {
    format!("{name}\0{perm}\0{kind}\0{size}\0{at}\0")
}

#[test]
fn reads_back_what_find_printed() {
    let entries = parse_records(&(record("id_rsa", "600", "f", "2602", "1700000000")
        + &record("sshd_config.d", "755", "d", "4096", "1700000001")))
    .unwrap();
    assert_eq!(entries.len(), 2);
    assert_eq!(entries[0].name, "id_rsa");
    assert_eq!(entries[0].kind, FileKind::File);
    assert_eq!(entries[0].size, Some(2602));
    assert_eq!(entries[0].mode, Some(0o600));
    assert_eq!(entries[0].mtime, Some(1_700_000_000));
    assert_eq!(entries[1].kind, FileKind::Dir);
    // Only files carry a size: a directory's is not the size of what is in it.
    assert_eq!(entries[1].size, None);
}

#[test]
fn a_name_with_a_newline_survives() {
    assert_eq!(parse_records(&record("two\nlines", "644", "f", "1", "0")).unwrap()[0].name, "two\nlines");
}

#[test]
fn a_link_is_a_link() {
    assert_eq!(parse_records(&record("cert.pem", "644", "l", "0", "0")).unwrap()[0].kind, FileKind::Link);
}

#[test]
fn an_empty_field_does_not_shift_the_entries_after_it() {
    let entries = parse_records(&(record("vanished", "", "f", "0", "0")
        + &record("after.txt", "644", "f", "99", "1700000000")))
    .unwrap();
    assert_eq!(entries.len(), 2);
    assert_eq!(entries[1].name, "after.txt");
    assert_eq!(entries[1].size, Some(99));
    assert_eq!(entries[1].mode, Some(0o644));
    assert_eq!(entries[0].mode, None);
}

#[test]
fn a_half_written_record_fails() {
    let output = record("whole", "644", "f", "1", "0") + "partial\x00644\x00";
    assert!(parse_records(&output).is_err());
}

#[test]
fn output_that_is_not_the_commands_is_refused() {
    for forged in [
        record("x", "644", "banner", "1", "0"),
        record("x", "rwx", "f", "1", "0"),
        record("x", "644", "f", "huge", "0"),
        record("x", "644", "f", "1", "never"),
        STAT_ABSENT_MARK.to_owned(),
        STAT_DENIED_MARK.to_owned(),
    ] {
        assert!(parse_records(&forged).is_err(), "{forged:?}");
    }
}

#[test]
fn none_of_the_above_is_an_entry_and_nothing_is_empty() {
    assert_eq!(
        parse_records(&record("docker.sock", "660", "u", "0", "1700000000")).unwrap()[0].kind,
        FileKind::Other
    );
    assert!(parse_records("").unwrap().is_empty());
}

#[test]
fn the_commands_quote_and_carry_their_contract() {
    assert!(list_command("/tmp/it's here").starts_with("find '/tmp/it'\\''s here' "));
    let list = list_command("/etc");
    assert!(list.contains("-mindepth 1 -maxdepth 1"));
    assert!(list.contains(r#"if meta=$(stat -c "%a %s %Y" "$path")"#));
    assert!(list.contains("exit 1"));
    assert!(list.contains("continue"));

    // Handed to `sh`: read the script back out of its quoting.
    let unwrap = |c: String| c.strip_prefix("sh -c '").unwrap().replace("'\\''", "'");
    let stat = unwrap(stat_command("/etc/it's here"));
    assert!(stat.starts_with("path='/etc/it'\\''s here'"), "{stat}");
    assert!(stat.contains("dir=${path%/*}"));
    assert_ne!(STAT_ABSENT_EXIT, STAT_DENIED_EXIT);
    assert!(stat.contains(&format!("exit {STAT_ABSENT_EXIT}")));
    assert!(stat.contains(&format!("exit {STAT_DENIED_EXIT}")));
    assert!(stat.contains(STAT_ABSENT_MARK) && stat.contains(STAT_DENIED_MARK));
}

#[test]
fn a_trailing_slash_does_not_empty_the_name() {
    for (path, quoted) in [("/etc/ssh/", "/etc/ssh"), ("/etc/ssh///", "/etc/ssh"), ("/", "/")] {
        assert!(stat_command(path).starts_with(&format!("sh -c 'path='\\''{quoted}'\\'';")), "{path}");
    }
}

#[test]
fn remove_keeps_the_callers_choice_of_recursion() {
    assert!(remove_command("/a b", None, false, true).starts_with("sh -c 'if [ -d "));
    assert_eq!(remove_command("/a", None, true, true), "rm -rf -- '/a'");
    assert_eq!(remove_command("/a", None, true, false), "rm -r -- '/a'");
    assert_eq!(remove_command("/a", Some(true), false, true), "rmdir -- '/a'");
    assert_eq!(remove_command("/a", Some(false), false, false), "rm -- '/a'");
}

#[test]
fn small_commands() {
    assert_eq!(chmod_command("/a", 0o755), "chmod 755 -- '/a'");
    assert_eq!(mkdir_command("/a", true), "mkdir -p -- '/a'");
    assert_eq!(parse_size(" 42\n"), Some(42));
    assert_eq!(parse_home("lk:x:1000:1000::/home/lk:/bin/fish\n").as_deref(), Some("/home/lk"));
    assert_eq!(parse_home("lk:x:1000:1000::relative:/bin/sh"), None);
    assert_eq!(fallback_home("root"), "/root");
    assert_eq!(extract_command("/x/a.tar.gz").as_deref(), Some("tar zxvf '/x/a.tar.gz'"));
    assert_eq!(extract_command("a.gz").as_deref(), Some("gunzip 'a.gz'"));
    assert_eq!(extract_command("a.txt"), None);
    assert_eq!(scp_sink_command("/a b"), "scp -t '/a b'");
}

#[test]
fn a_capped_read_parses_and_refuses_what_it_did_not_print() {
    assert_eq!(parse_capped_read("5\naGVsbG8=", 128).unwrap(), (5, b"hello".to_vec()));
    // Capped: the size is the whole file, the bytes only what the cap allows.
    assert_eq!(parse_capped_read("11\naGVsbG8=", 5).unwrap(), (11, b"hello".to_vec()));
    // A quartet short still decodes, and is still a reply cut short.
    assert!(parse_capped_read("11\naGVs", 5).is_err());
    assert_eq!(parse_capped_read("0\n", 128).unwrap(), (0, Vec::new()));
    assert!(parse_capped_read("", 128).is_err());
    assert!(parse_capped_read("\naGk=", 128).is_err());
    assert!(parse_capped_read("-1\naGk=", 128).is_err());
    assert!(parse_capped_read("2\n!!", 128).is_err());
}

// --- Against a real shell ---------------------------------------------------

/// `/bin/sh` and Unix modes; the Windows CI runner has neither.
#[cfg(unix)]
mod shell {
    use super::*;
    use std::process::Command;

    fn sh(command: &str) -> (Option<i32>, String) {
        let out = Command::new("/bin/sh").arg("-c").arg(command).output().expect("sh");
        (out.status.code(), String::from_utf8_lossy(&out.stdout).into_owned())
    }

    fn has_stat_c() -> bool {
        Command::new("/bin/sh")
            .args(["-c", "stat -c %a / >/dev/null 2>&1"])
            .status()
            .is_ok_and(|s| s.success())
    }

    #[test]
    fn listing_and_stat_run_and_read_back() {
        if !has_stat_c() {
            eprintln!("skipped: this host's stat has no -c (BSD)");
            return;
        }
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join("a file"), b"hello").unwrap();
        std::fs::create_dir(dir.path().join("sub")).unwrap();
        std::os::unix::fs::symlink("sub", dir.path().join("link")).unwrap();
        let root = dir.path().to_str().unwrap();

        let (code, out) = sh(&list_command(root));
        assert_eq!(code, Some(0));
        let mut entries = parse_records(&out).unwrap();
        entries.sort_by(|a, b| a.name.cmp(&b.name));
        let shape: Vec<_> = entries.iter().map(|e| (e.name.as_str(), e.kind, e.size)).collect();
        assert_eq!(
            shape,
            vec![("a file", FileKind::File, Some(5)), ("link", FileKind::Link, None), ("sub", FileKind::Dir, None)]
        );

        let (code, out) = sh(&stat_command(&format!("{root}/sub/")));
        assert_eq!(code, Some(0));
        assert_eq!(parse_records(&out).unwrap()[0].name, "sub");

        let (code, out) = sh(&stat_command("/"));
        assert_eq!(code, Some(0));
        assert_eq!(parse_records(&out).unwrap()[0].name, "/");

        let (code, out) = sh(&stat_command(&format!("{root}/missing")));
        assert_eq!((code, out.as_str()), (Some(STAT_ABSENT_EXIT), STAT_ABSENT_MARK));
    }

    #[test]
    fn rename_refuses_a_directory_destination() {
        let dir = tempfile::tempdir().unwrap();
        let from = dir.path().join("f");
        let to = dir.path().join("d");
        std::fs::write(&from, b"x").unwrap();
        std::fs::create_dir(&to).unwrap();
        let (code, _) = sh(&rename_command(from.to_str().unwrap(), to.to_str().unwrap()));
        assert_ne!(code, Some(0));
        assert!(from.exists(), "the file was filed away inside the directory");
    }

    #[test]
    fn capped_read_and_atomic_write_run() {
        if !has_stat_c() {
            eprintln!("skipped: this host's stat has no -c (BSD)");
            return;
        }
        use std::io::Write;
        use std::os::unix::fs::PermissionsExt;
        let dir = tempfile::tempdir().unwrap();
        let file = dir.path().join("run me.sh");
        std::fs::write(&file, b"old").unwrap();
        std::fs::set_permissions(&file, std::fs::Permissions::from_mode(0o755)).unwrap();
        let path = file.to_str().unwrap();

        let mut child = Command::new("/bin/sh")
            .arg("-c")
            .arg(atomic_write_command(path))
            .stdin(std::process::Stdio::piped())
            .spawn()
            .unwrap();
        child.stdin.take().unwrap().write_all(b"aGVsbG8gd29ybGQ=").unwrap();
        assert!(child.wait().unwrap().success());
        assert_eq!(std::fs::read(&file).unwrap(), b"hello world");
        // The existing file's mode survives the staged copy's umask.
        assert_eq!(std::fs::metadata(&file).unwrap().permissions().mode() & 0o777, 0o755);

        let (code, out) = sh(&capped_read_command(path, 5));
        assert_eq!(code, Some(0));
        assert_eq!(parse_capped_read(&out, 5).unwrap(), (11, b"hello".to_vec()));
        assert_eq!(sh(&capped_read_command(dir.path().to_str().unwrap(), 5)).0, Some(READ_IS_DIR_EXIT));
        assert_eq!(sh(&capped_read_command(&format!("{path}.missing"), 5)).0, Some(READ_MISSING_EXIT));

        // A directory at the path is refused, not written into.
        let mut child = Command::new("/bin/sh")
            .arg("-c")
            .arg(atomic_write_command(dir.path().to_str().unwrap()))
            .stdin(std::process::Stdio::piped())
            .spawn()
            .unwrap();
        drop(child.stdin.take());
        assert!(!child.wait().unwrap().success());
    }

    /// Relative names that begin with `-`, run where they are relative to.
    #[test]
    fn dash_led_relative_paths_run() {
        if !has_stat_c() {
            eprintln!("skipped: this host's stat has no -c (BSD)");
            return;
        }
        use std::io::Write;
        let dir = tempfile::tempdir().unwrap();
        std::fs::create_dir(dir.path().join("-d")).unwrap();
        std::fs::write(dir.path().join("-d/x"), b"").unwrap();
        let in_dir = |command: &str| {
            let out = Command::new("/bin/sh").current_dir(dir.path()).arg("-c").arg(command).output().unwrap();
            (out.status.code(), String::from_utf8_lossy(&out.stdout).into_owned())
        };

        let mut child = Command::new("/bin/sh")
            .current_dir(dir.path())
            .arg("-c")
            .arg(atomic_write_command("-n"))
            .stdin(std::process::Stdio::piped())
            .spawn()
            .unwrap();
        child.stdin.take().unwrap().write_all(b"aGk=").unwrap();
        assert!(child.wait().unwrap().success());
        assert_eq!(std::fs::read(dir.path().join("-n")).unwrap(), b"hi");

        let (code, out) = in_dir(&capped_read_command("-n", 5));
        assert_eq!(code, Some(0));
        assert_eq!(parse_capped_read(&out, 5).unwrap(), (2, b"hi".to_vec()));
        let (code, out) = in_dir(&stat_command("-n"));
        assert_eq!(code, Some(0));
        assert_eq!(parse_records(&out).unwrap()[0].name, "-n");
        let (code, out) = in_dir(&list_command("-d"));
        assert_eq!(code, Some(0));
        assert_eq!(parse_records(&out).unwrap()[0].name, "x");
        assert_eq!(in_dir(&read_command("-n")), (Some(0), "hi".to_owned()));
    }
}

#[test]
fn a_size_or_mode_the_command_cannot_print_is_refused() {
    assert!(parse_records(&record("x", "644", "f", "-1", "0")).is_err());
    assert!(parse_records(&record("x", "40000000000", "f", "1", "0")).is_err());
    assert!(parse_records(&record("x", "17777", "f", "1", "0")).is_err());
    for forged in [
        record("x", "+644", "f", "1", "0"),
        record("x", "644", "f", "+1", "0"),
        record("x", "644", "f", "1", " 0"),
        record("", "644", "f", "1", "0"),
    ] {
        assert!(parse_records(&forged).is_err(), "{forged:?}");
    }
    assert_eq!(parse_records(&record("old", "644", "f", "1", "-86400")).unwrap()[0].mtime, Some(-86400));
    assert_eq!(parse_records(&record("x", "4755", "f", "1", "0")).unwrap()[0].mode, Some(0o4755));
}

#[test]
fn the_staging_file_is_made_exclusively() {
    let command = atomic_write_command("/a");
    assert!(command.contains("tmp=$(mktemp \"$p.XXXXXX\")"), "{command}");
}

#[test]
fn a_dash_led_relative_path_is_never_an_option() {
    assert!(list_command("-P").starts_with("find './-P' "));
    assert!(list_command("/-P").starts_with("find '/-P' "));
    assert!(atomic_write_command("-n").contains("p='./-n'"));
    assert!(capped_read_command("-n", 1).contains("p='./-n'"));
    assert!(stat_command("-n").contains("path='\\''./-n'\\''"), "{}", stat_command("-n"));
    assert_eq!(read_command("-n"), "cat './-n'");
    assert_eq!(scp_source_command("-n"), "scp -f './-n'");
    assert_eq!(scp_sink_command("-n"), "scp -t './-n'");
    assert_eq!(extract_command("-n.zip").as_deref(), Some("unzip './-n.zip'"));
}
