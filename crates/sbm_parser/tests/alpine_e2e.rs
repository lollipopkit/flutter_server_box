//! Opt-in Alpine container e2e: exercises the busybox branches of the
//! generated Unix script (ash as /bin/sh, `ps w` process fallback) and the
//! df -k disk fallback (Alpine ships no lsblk).
//!
//! Ignored by default because it requires Docker in Linux-container mode. Each
//! run pipes the script via
//! stdin using the shared install command and then executes it — the same
//! install-then-exec flow the app performs over SSH, inside one container.
//! Run with `cargo test -p sbm_parser --test alpine_e2e -- --ignored`.

use sbm_parser::script::{self, ScriptOptions, ShellFunc};
use sbm_parser::SystemType;
use std::io::Write;
use std::process::{Command, Stdio};

const IMAGE: &str = "alpine:3.20";
const DIR: &str = "/tmp/server_box";

/// Whether there is a docker that can run *this* image.
///
/// Not "is docker installed": the Windows runner has one, and it is in Windows
/// container mode, where `alpine:3.20` fails to pull with "no matching manifest
/// for windows/amd64". Asking `docker info` alone let that through and the
/// suite failed on a machine that was never going to run a Linux container.
fn docker_runs_linux() -> bool {
    let out = Command::new("docker")
        .args(["version", "--format", "{{.Server.Os}}"])
        .stderr(Stdio::null())
        .output();
    match out {
        Ok(out) if out.status.success() => String::from_utf8_lossy(&out.stdout).trim() == "linux",
        _ => false,
    }
}

/// Run `sh -c <cmd>` in a fresh Alpine container, piping `stdin` in.
/// `strict` asserts a zero exit; script executions are lenient because the
/// script's exit status is that of its last command (e.g. `grep "model name"`
/// exits 1 on ARM cpuinfo) and the app only consumes the output
fn alpine(cmd: &str, stdin: Option<&str>, strict: bool) -> String {
    let mut child = Command::new("docker")
        .args(["run", "--rm", "-i", IMAGE, "sh", "-c", cmd])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .expect("spawn docker");
    child
        .stdin
        .take()
        .expect("stdin piped")
        .write_all(stdin.unwrap_or_default().as_bytes())
        .expect("write stdin");
    let out = child.wait_with_output().expect("docker wait");
    if strict {
        assert!(
            out.status.success(),
            "docker run failed ({}): stderr={:?}",
            out.status,
            String::from_utf8_lossy(&out.stderr)
        );
    }
    String::from_utf8_lossy(&out.stdout).into_owned()
}

/// The shared install command followed by the shared exec command: `cat >`
/// consumes stdin (the script) up to EOF, then the function runs
fn install_then_exec(func: ShellFunc) -> String {
    let path = format!("{DIR}/status.sh");
    format!(
        "{}{}",
        script::install_command(SystemType::Linux, DIR, &path),
        script::exec_command(SystemType::Linux, &path, func),
    )
}

#[test]
#[ignore = "requires Docker in Linux-container mode"]
fn alpine_busybox_status_and_process() {
    assert!(
        docker_runs_linux(),
        "Docker must be available in Linux-container mode"
    );

    // Sanity: this image really is busybox-backed (the branch under test)
    let sh_link = alpine("ls -l /bin/sh", None, true);
    assert!(
        sh_link.contains("busybox"),
        "expected busybox sh, got: {sh_link:?}"
    );

    let content = script::build_script(
        SystemType::Linux,
        &ScriptOptions {
            build_number: "e2e".into(),
            ..Default::default()
        },
    );

    // ---- status (-s) ----
    let raw = alpine(&install_then_exec(ShellFunc::Status), Some(&content), false);
    let segments = script::parse_script_output(&raw);
    assert_eq!(
        segments.get("echo").map(String::as_str),
        Some("__linux"),
        "keys: {:?}",
        segments.keys().collect::<Vec<_>>()
    );

    let status = sbm_parser::parse_status(SystemType::Linux, &segments);
    let mem = status.mem.expect("mem parsed");
    assert!(mem.total > 0);
    assert!(!status.cpu.is_empty(), "cpu parsed");
    // Alpine has no lsblk, so this exercises the df -k fallback parser
    assert!(!status.disks.is_empty(), "disks parsed via df fallback");
    assert!(status.host.is_some(), "hostname parsed");
    assert!(status.uptime.is_some(), "uptime parsed");

    // ---- process (-p): must take the busybox `ps w` branch ----
    let proc_out = alpine(
        &install_then_exec(ShellFunc::Process),
        Some(&content),
        false,
    );
    let first = proc_out.lines().next().unwrap_or_default();
    assert!(
        first.contains("PID") && first.contains("COMMAND"),
        "expected busybox ps header, got: {first:?}"
    );
    assert!(
        !proc_out.contains("READ_BYTES"),
        "READ_BYTES header means the non-busybox branch ran"
    );
    assert!(proc_out.lines().count() > 1, "at least one process listed");

    eprintln!(
        "alpine e2e ok: host={:?} cores={} mem_total={}KiB disks={} (df fallback), busybox ps branch taken",
        status.host,
        status.cpu.len(),
        mem.total,
        status.disks.len()
    );
}
