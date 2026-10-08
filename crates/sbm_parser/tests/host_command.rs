//! The Linux status script's hostname command, run by `sh` against a stand-in
//! for `/etc/hostname` in each shape it comes in: missing (OpenWrt, Gentoo's
//! OpenRC, Termux), blank, without a final newline, and ordinary.

#![cfg(unix)]

use sbm_parser::commands::{self, LINUX};
use sbm_parser::common::parse_hostname;
use std::process::Command;

fn host_command() -> &'static str {
    LINUX.iter().find(|c| c.key == commands::HOST).expect("Linux has a host command").cmd
}

/// What `sh` prints for the command with `/etc/hostname` read from [file].
/// The path goes in through the environment, quoted, so a temporary directory
/// with a space in it stays one argument.
fn run_with(file: &std::path::Path) -> String {
    let cmd = host_command().replace("/etc/hostname", "\"$SBM_HOSTNAME_FILE\"");
    let out = Command::new("sh")
        .args(["-c", &cmd])
        .env("SBM_HOSTNAME_FILE", file)
        .output()
        .expect("sh runs");
    String::from_utf8(out.stdout).expect("utf-8")
}

fn uname_n() -> String {
    let out = Command::new("uname").arg("-n").output().expect("uname runs");
    String::from_utf8(out.stdout).expect("utf-8").trim().to_string()
}

#[test]
fn the_file_is_read_when_it_names_the_host() {
    let dir = tempfile::tempdir().unwrap();
    let file = dir.path().join("hostname");
    std::fs::write(&file, "box\n").unwrap();
    assert_eq!(run_with(&file), "box\n");
}

#[test]
fn a_file_without_a_final_newline_still_ends_its_line() {
    // Else the next section's marker would be glued to the name.
    let dir = tempfile::tempdir().unwrap();
    let file = dir.path().join("hostname");
    std::fs::write(&file, "box").unwrap();
    assert_eq!(run_with(&file), "box\n");
}

#[test]
fn no_file_falls_back_to_the_kernel_name() {
    let dir = tempfile::tempdir().unwrap();
    let out = run_with(&dir.path().join("hostname"));
    assert_eq!(parse_hostname(&out), Some(uname_n()));
}

#[test]
fn a_blank_file_falls_back_to_the_kernel_name() {
    let dir = tempfile::tempdir().unwrap();
    let file = dir.path().join("hostname");
    std::fs::write(&file, " \n\n").unwrap();
    assert_eq!(parse_hostname(&run_with(&file)), Some(uname_n()));
}

#[test]
fn a_path_with_a_space_is_one_argument() {
    let dir = tempfile::tempdir().unwrap();
    let file = dir.path().join("host name");
    std::fs::write(&file, "box\n").unwrap();
    assert_eq!(run_with(&file), "box\n");
}

#[test]
fn this_machine_has_a_name_either_way() {
    // macOS has no /etc/hostname and a Linux runner has one: both answer.
    let out = Command::new("sh").args(["-c", host_command()]).output().unwrap();
    assert!(parse_hostname(&String::from_utf8_lossy(&out.stdout)).is_some());
}
