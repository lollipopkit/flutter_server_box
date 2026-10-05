//! The file browser's shell commands, ported with the app's Dart fixtures
//! (`test/unit/file/shell_file_ops_test.dart`) before the Dart copy went, and
//! run for real against a local `sh` where the Dart suite only read the text.

use sbm_parser::files::*;
use std::process::Command;

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

// --- Against a real shell ---------------------------------------------------

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
