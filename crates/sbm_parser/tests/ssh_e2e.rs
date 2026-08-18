//! Opt-in end-to-end test over real SSH.
//!
//! Flow: build the status script → upload it with the shared install command
//! (content piped via stdin, exactly like the app) → run it with the shared
//! exec command → split with parse_script_output → parse_status. Then run
//! selected manifest commands *directly* over the same connection and assert
//! the script-transported parse agrees with the direct parse, proving the
//! generate → install → exec → segment → parse chain is lossless.
//!
//! Configuration (tests are skipped when unset), via environment or a `.env`
//! at the workspace root; values are any destination the system `ssh` accepts,
//! so `~/.ssh/config` aliases work natively:
//! - `SBM_E2E_SSH_HOST`: a Unix remote (Linux or BSD/macOS)
//! - `SBM_E2E_SSH_HOST_WINDOWS`: a Windows remote (OpenSSH server; both
//!   cmd.exe and PowerShell default shells are supported)
//!
//! Destructive shell functions (shutdown/reboot/suspend) are NEVER executed
//! against real hosts — they are covered by text assertions in script_compat.

use sbm_parser::commands;
use sbm_parser::script::{self, ScriptOptions, ShellFunc};
use sbm_parser::SystemType;
use std::io::Write;
use std::process::{Command, Stdio};

const REMOTE_DIR: &str = "/tmp/server_box_e2e";

fn env_host(var: &str) -> Option<String> {
    // Workspace-root .env; real environment variables take precedence
    // (dotenvy does not override existing vars)
    let root_env = concat!(env!("CARGO_MANIFEST_DIR"), "/../../.env");
    dotenvy::from_path(root_env).ok();
    std::env::var(var).ok().filter(|s| !s.is_empty())
}

fn ssh_host() -> Option<String> {
    env_host("SBM_E2E_SSH_HOST")
}

fn windows_host() -> Option<String> {
    env_host("SBM_E2E_SSH_HOST_WINDOWS")
}

/// Put back whatever the account had in the custom-command directory before
/// the test replaced it. Called on the failure path too — a test that leaves
/// someone's commands in a `.e2e` directory has done real damage.
fn restore_custom_cmd_dir(host: &str, dir: &str) {
    let _ = ssh(
        host,
        &format!("rm -rf \"{dir}\"; if [ -d \"{dir}.e2e\" ]; then mv \"{dir}.e2e\" \"{dir}\"; fi"),
        None,
    );
}

/// Run a command on the remote via the system ssh (BatchMode: never prompts).
/// `stdin` is piped to the remote command when given.
/// The command is wrapped in `sh -c` so POSIX syntax works regardless of the
/// remote login shell (fish/zsh would otherwise reject `if ...; fi` etc.)
fn ssh(host: &str, cmd: &str, stdin: Option<&str>) -> Result<String, String> {
    let quoted = format!("sh -c '{}'", cmd.replace('\'', r"'\''"));
    let mut child = Command::new("ssh")
        .args(["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, &quoted])
        .stdin(if stdin.is_some() { Stdio::piped() } else { Stdio::null() })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("failed to spawn ssh: {e}"))?;
    if let Some(input) = stdin {
        child
            .stdin
            .take()
            .expect("stdin piped")
            .write_all(input.as_bytes())
            .map_err(|e| format!("failed to write ssh stdin: {e}"))?;
    }
    let out = child
        .wait_with_output()
        .map_err(|e| format!("ssh wait failed: {e}"))?;
    if !out.status.success() {
        return Err(format!(
            "ssh command {cmd:?} exited with {}: {}",
            out.status,
            String::from_utf8_lossy(&out.stderr)
        ));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

/// Like [`ssh`] but passes the command to the remote default shell verbatim
/// (no `sh -c` wrap) — for Windows remotes, where commands are either
/// shell-agnostic (`powershell -File`/-EncodedCommand) or plain cmd built-ins
fn ssh_raw(host: &str, cmd: &str, stdin: Option<&str>) -> Result<String, String> {
    let mut child = Command::new("ssh")
        .args(["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, cmd])
        .stdin(if stdin.is_some() { Stdio::piped() } else { Stdio::null() })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("failed to spawn ssh: {e}"))?;
    if let Some(input) = stdin {
        child
            .stdin
            .take()
            .expect("stdin piped")
            .write_all(input.as_bytes())
            .map_err(|e| format!("failed to write ssh stdin: {e}"))?;
    }
    let out = child
        .wait_with_output()
        .map_err(|e| format!("ssh wait failed: {e}"))?;
    if !out.status.success() {
        return Err(format!(
            "ssh command {cmd:?} exited with {}: {}",
            out.status,
            String::from_utf8_lossy(&out.stderr)
        ));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

/// Like [`ssh`] but returns stdout regardless of exit status — for tools that
/// exit non-zero when they have nothing to report (e.g. `sensors` without
/// detected chips), mirroring the script's `exec 2>/dev/null` tolerance
fn ssh_stdout(host: &str, cmd: &str) -> String {
    let quoted = format!("sh -c '{}'", cmd.replace('\'', r"'\''"));
    Command::new("ssh")
        .args(["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", host, &quoted])
        .stdin(Stdio::null())
        .output()
        .map(|out| String::from_utf8_lossy(&out.stdout).into_owned())
        .unwrap_or_default()
}

/// The manifest command for `key` on `system` (panics if absent — the test
/// only asks for keys that exist on both Unix systems)
fn manifest_cmd(system: SystemType, key: &str) -> &'static str {
    commands::commands(system)
        .iter()
        .find(|s| s.key == key)
        .unwrap_or_else(|| panic!("{key} missing from {system:?} manifest"))
        .cmd
}

#[test]
fn ssh_e2e_script_parse_matches_direct_commands() {
    let Some(host) = ssh_host() else {
        eprintln!("skipping ssh e2e: SBM_E2E_SSH_HOST not set (env or workspace-root .env)");
        return;
    };

    // Full app-like script (all commands enabled); Linux and Bsd yield the
    // same Unix script, which self-detects the OS at runtime
    let content = script::build_script(
        SystemType::Linux,
        &ScriptOptions { build_number: "e2e".into(), ..Default::default() },
    );
    let script_path = format!("{REMOTE_DIR}/status.sh");

    let install = script::install_command(SystemType::Linux, REMOTE_DIR, &script_path);
    ssh(&host, &install, Some(&content)).expect("install script");

    let exec = script::exec_command(SystemType::Linux, &script_path, ShellFunc::Status);
    let raw = ssh(&host, &exec, None).expect("run status script");
    // SMART/AMD live in the extended function, which the app runs on its own
    // slow timer and merges into the same parse — do the same here
    let exec_ext = script::exec_command(SystemType::Linux, &script_path, ShellFunc::StatusExt);
    let raw_ext = ssh(&host, &exec_ext, None).expect("run extended status script");

    // Best-effort cleanup before assertions
    let _ = ssh(&host, &format!("rm -rf {REMOTE_DIR}"), None);

    let mut segments = script::parse_script_output(&raw);
    assert!(!segments.is_empty(), "no segments parsed; raw output: {raw:?}");
    let segments_ext = script::parse_script_output(&raw_ext);
    assert!(
        segments_ext.contains_key(commands::DISK_SMART),
        "no extended segments parsed; raw output: {raw_ext:?}"
    );
    segments.extend(segments_ext);

    // Detect the remote system from the echo segment
    let sign = segments.get("echo").map(String::as_str).unwrap_or("");
    let system = if sign.contains("__bsd") {
        SystemType::Bsd
    } else if sign.contains("__linux") {
        SystemType::Linux
    } else {
        panic!("unexpected system sign {sign:?}; Windows remotes are not supported by this test");
    };

    let status = sbm_parser::parse_status(system, &segments);

    // Sanity: core fields populated
    let mem = status.mem.expect("mem parsed from script output");
    assert!(mem.total > 0, "mem.total must be positive");
    assert!(!status.cpu.is_empty(), "cpu cores parsed");
    assert!(!status.disks.is_empty(), "disks parsed");
    assert!(status.uptime.is_some(), "uptime parsed");

    // Remote clock sanity via the time segment (unix epoch, ±5 min tolerance)
    let remote_epoch: i64 = segments["time"].trim().parse().expect("time segment is a unix epoch");
    let local_epoch = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    assert!(
        (remote_epoch - local_epoch).abs() < 300,
        "remote/local clock skew too large: remote={remote_epoch} local={local_epoch}"
    );

    // Ground truth: run the same manifest commands directly over the same
    // connection and compare parses. Only sample-stable values are compared.
    let direct_host = ssh(&host, manifest_cmd(system, commands::HOST), None).expect("direct host");
    assert_eq!(
        status.host,
        sbm_parser::common::parse_hostname(&direct_host),
        "hostname: script-transported parse vs direct command parse"
    );

    let direct_mem = ssh(&host, manifest_cmd(system, commands::MEM), None).expect("direct mem");
    let direct_mem = match system {
        SystemType::Bsd => sbm_parser::bsd::parse_mem(&direct_mem),
        _ => sbm_parser::linux::parse_mem(&direct_mem),
    }
    .expect("direct mem parses");
    assert_eq!(mem.total, direct_mem.total, "mem.total: script vs direct");

    let direct_cpu = ssh(&host, manifest_cmd(system, commands::CPU), None).expect("direct cpu");
    let direct_cores = match system {
        SystemType::Bsd => sbm_parser::bsd::parse_cpu(&direct_cpu),
        _ => sbm_parser::linux::parse_cpu(&direct_cpu),
    };
    assert_eq!(
        status.cpu.len(),
        direct_cores.len(),
        "cpu core count: script vs direct"
    );

    let direct_sys = ssh(&host, manifest_cmd(system, commands::SYS), None).expect("direct sys");
    let direct_sys = match system {
        SystemType::Bsd => sbm_parser::common::parse_hostname(&direct_sys),
        _ => sbm_parser::common::parse_sys_version(&direct_sys),
    };
    assert_eq!(status.sys, direct_sys, "sys version: script vs direct");

    // On-demand segments (GPU/sensors/SMART/battery): what the test asserts
    // adapts to what the remote actually has — presence means the segment must
    // parse into data, absence means graceful degradation to empty.
    let has = |probe: &str| {
        ssh(&host, probe, None).map(|s| s.trim() == "yes").unwrap_or(false)
    };

    if system == SystemType::Linux {
        let has_nvidia = has(
            "if command -v nvidia-smi >/dev/null 2>&1 || [ -x /usr/lib/wsl/lib/nvidia-smi ]; then echo yes; else echo no; fi",
        );
        if has_nvidia {
            assert!(
                !status.nvidia.is_empty(),
                "nvidia-smi available on the remote but no GPU parsed; segment: {:?}",
                segments.get(commands::NVIDIA)
            );
            let direct = ssh(&host, manifest_cmd(system, commands::NVIDIA), None)
                .expect("direct nvidia");
            let direct = sbm_parser::gpu::nvidia_from_xml(&direct);
            let script_names: Vec<_> = status.nvidia.iter().map(|g| &g.name).collect();
            let direct_names: Vec<_> = direct.iter().map(|g| &g.name).collect();
            assert_eq!(script_names, direct_names, "GPU names: script vs direct");
        } else {
            assert!(status.nvidia.is_empty(), "no nvidia-smi yet GPUs parsed");
        }

        let has_amd = has(
            "if command -v amd-smi >/dev/null 2>&1 || command -v rocm-smi >/dev/null 2>&1; then echo yes; else echo no; fi",
        );
        if !has_amd {
            assert!(status.amd.is_empty(), "no AMD tools yet AMD GPUs parsed");
        }

        // Tool presence does not imply data (e.g. sensors on a VM/WSL finds no
        // chips and exits 1 with empty stdout) — the contract is that the
        // script-transported parse equals the direct parse, empty or not
        let has_sensors = has("if command -v sensors >/dev/null 2>&1; then echo yes; else echo no; fi");
        if has_sensors {
            let direct = sbm_parser::linux::parse_sensors(&ssh_stdout(
                &host,
                manifest_cmd(system, commands::SENSORS),
            ));
            let script_devices: Vec<_> = status.sensors.iter().map(|s| &s.device).collect();
            let direct_devices: Vec<_> = direct.iter().map(|s| &s.device).collect();
            assert_eq!(script_devices, direct_devices, "sensor devices: script vs direct");
        } else {
            assert!(status.sensors.is_empty());
        }

        let has_smart = has("if command -v smartctl >/dev/null 2>&1; then echo yes; else echo no; fi");
        if has_smart {
            let direct = sbm_parser::smart::parse(&ssh_stdout(
                &host,
                manifest_cmd(system, commands::DISK_SMART),
            ));
            let script_devices: Vec<_> = status.disk_smart.iter().map(|d| &d.device).collect();
            let direct_devices: Vec<_> = direct.iter().map(|d| &d.device).collect();
            assert_eq!(script_devices, direct_devices, "SMART devices: script vs direct");
        } else {
            assert!(status.disk_smart.is_empty());
        }

        // Batteries: the parser keeps Li-poly only, so presence of power
        // supplies does not imply non-empty output — assert only the reverse
        let has_power = has(
            "if [ -n \"$(ls /sys/class/power_supply/ 2>/dev/null)\" ]; then echo yes; else echo no; fi",
        );
        if !has_power {
            assert!(status.batteries.is_empty());
        }

        eprintln!(
            "on-demand: nvidia={} ({} GPUs) amd={} sensors={} ({}) smartctl={} ({}) power_supply={}",
            has_nvidia,
            status.nvidia.len(),
            has_amd,
            has_sensors,
            status.sensors.len(),
            has_smart,
            status.disk_smart.len(),
            has_power
        );
    }

    eprintln!(
        "ssh e2e ok: host={:?} system={system:?} cores={} mem_total={}KiB disks={}",
        status.host,
        status.cpu.len(),
        mem.total,
        status.disks.len()
    );
}

/// Custom commands and disabled keys against a real remote: the custom segment
/// must round-trip, the disabled segment must be absent from the output
#[test]
fn ssh_e2e_unix_custom_and_disabled() {
    let Some(host) = ssh_host() else {
        eprintln!("skipping ssh e2e: SBM_E2E_SSH_HOST not set");
        return;
    };

    const DIR: &str = "/tmp/server_box_e2e_custom";
    let opts = ScriptOptions {
        disabled: vec!["Linux.net".into(), "BSD.net".into()],
        build_number: "e2e".into(),
        ..Default::default()
    };
    let content = script::build_script(SystemType::Linux, &opts);
    let path = format!("{DIR}/status.sh");
    ssh(&host, &script::install_command(SystemType::Linux, DIR, &path), Some(&content))
        .expect("install script");
    // The commands themselves are files in a fixed directory under the user's
    // home now, written in one round trip. This is the half a unit test cannot
    // check: that a real shell on a real host reads that directory and reports
    // what it finds.
    //
    // That directory is the real one — the path is fixed precisely so that
    // every reader agrees on it — so whatever the account already had there is
    // moved aside first and put back at the end.
    let cmd_dir = script::custom_cmd_dir(SystemType::Linux);
    let _ = ssh(&host, &format!("rm -rf \"{cmd_dir}.e2e\"; mv \"{cmd_dir}\" \"{cmd_dir}.e2e\""), None);
    let cmds = vec![(100u32, "e2e_probe".to_string(), "echo custom-cmd-works".to_string())];
    let installed = ssh(&host, &script::install_custom_cmds_script(SystemType::Linux, &cmds), None);
    let raw = installed
        .and_then(|_| {
            ssh(&host, &script::exec_command(SystemType::Linux, &path, ShellFunc::Status), None)
        })
        .inspect_err(|_| restore_custom_cmd_dir(&host, cmd_dir))
        .expect("install custom commands and run status script");
    let listing =
        ssh(&host, &script::read_custom_cmds_script(SystemType::Linux), None).unwrap_or_default();
    restore_custom_cmd_dir(&host, cmd_dir);
    let _ = ssh(&host, &format!("rm -rf {DIR}"), None);

    // The editor's read path against a real shell: `base64`/`tr` exist and the
    // command comes back byte-identical to what was written.
    assert_eq!(
        script::parse_custom_cmds_listing(&listing),
        Some(vec![(100, "e2e_probe".to_string(), "echo custom-cmd-works".to_string())]),
        "listing must round-trip; raw: {listing:?}"
    );

    let segments = script::parse_script_output(&raw);
    assert_eq!(
        segments.get(&script::custom_result_key("e2e_probe")).map(String::as_str),
        Some("custom-cmd-works"),
        "custom command segment must round-trip"
    );
    assert!(
        !segments.contains_key(commands::NET),
        "disabled net segment must be absent; keys: {:?}",
        segments.keys().collect::<Vec<_>>()
    );
    assert!(segments.contains_key(commands::MEM), "non-disabled segments still present");
}

/// The process function (`-p`) on a real remote — the most complex generated
/// body (busybox detection, /proc/<pid>/io loop). Read-only, safe to execute.
#[test]
fn ssh_e2e_unix_process_function() {
    let Some(host) = ssh_host() else {
        eprintln!("skipping ssh e2e: SBM_E2E_SSH_HOST not set");
        return;
    };

    const DIR: &str = "/tmp/server_box_e2e_proc";
    let content = script::build_script(
        SystemType::Linux,
        &ScriptOptions { build_number: "e2e".into(), ..Default::default() },
    );
    let path = format!("{DIR}/status.sh");
    ssh(&host, &script::install_command(SystemType::Linux, DIR, &path), Some(&content))
        .expect("install script");
    let raw = ssh(&host, &script::exec_command(SystemType::Linux, &path, ShellFunc::Process), None)
        .expect("run process function");
    let _ = ssh(&host, &format!("rm -rf {DIR}"), None);

    let lines: Vec<&str> = raw.lines().collect();
    assert!(lines.len() > 3, "expected a process list, got {} lines", lines.len());
    assert!(
        lines[0].contains("PID"),
        "first line should be a ps header, got: {:?}",
        lines[0]
    );
}

/// Windows full chain: EncodedCommand install (works from cmd.exe default
/// shells), -File execution, WMI double-sample output, CRLF splitting, and
/// direct-vs-script parse comparisons. Status function only — destructive
/// functions are never executed.
#[test]
fn ssh_e2e_windows_script_parse_matches_direct_commands() {
    let Some(host) = windows_host() else {
        eprintln!("skipping windows ssh e2e: SBM_E2E_SSH_HOST_WINDOWS not set");
        return;
    };

    // Resolve the real temp dir first (cmd expands %TEMP%; PowerShell default
    // shells would print it literally, so fall back to an encoded query)
    let temp = {
        let t = ssh_raw(&host, "echo %TEMP%", None).unwrap_or_default().trim().to_string();
        if t.contains(':') {
            t
        } else {
            ssh_raw(&host, &script::encoded_powershell_command("Write-Output $env:TEMP"), None)
                .expect("resolve TEMP")
                .trim()
                .to_string()
        }
    };
    assert!(temp.contains(':'), "unexpected TEMP dir: {temp:?}");
    let dir = format!(r"{temp}\server_box_e2e");
    let path = format!(r"{dir}\status.ps1");

    let content = script::build_script(
        SystemType::Windows,
        &ScriptOptions { build_number: "e2e".into(), ..Default::default() },
    );
    ssh_raw(&host, &script::install_command(SystemType::Windows, &dir, &path), Some(&content))
        .expect("install script");
    let raw = ssh_raw(&host, &script::exec_command(SystemType::Windows, &path, ShellFunc::Status), None)
        .expect("run status script");
    let _ = ssh_raw(
        &host,
        &script::encoded_powershell_command(&format!("Remove-Item -Recurse -Force '{dir}'")),
        None,
    );

    let segments = script::parse_script_output(&raw);
    assert!(!segments.is_empty(), "no segments parsed; raw: {raw:?}");
    let sign = segments.get("echo").map(String::as_str).unwrap_or("");
    assert!(sign.contains("__windows"), "expected windows sign, got {sign:?}");

    let status = sbm_parser::parse_status(SystemType::Windows, &segments);

    let mem = status.mem.expect("mem parsed");
    assert!(mem.total > 0);
    assert!(!status.cpu.is_empty(), "cpu parsed");
    assert!(!status.disks.is_empty(), "disks parsed");
    assert!(status.uptime.is_some(), "uptime parsed");
    assert!(!status.net.is_empty(), "net counters parsed from WMI double sample");

    let remote_epoch: i64 = segments["time"].trim().parse().expect("time is a unix epoch");
    let local_epoch = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs() as i64;
    assert!((remote_epoch - local_epoch).abs() < 300, "clock skew too large");

    // Direct runs via EncodedCommand, so the remote default shell is irrelevant
    let direct = |cmd: &str| {
        ssh_raw(&host, &script::encoded_powershell_command(cmd), None)
    };

    let direct_host = direct(manifest_cmd(SystemType::Windows, commands::HOST)).expect("direct host");
    assert_eq!(status.host, sbm_parser::common::parse_hostname(&direct_host), "hostname");

    let direct_mem = sbm_parser::windows::parse_mem(
        &direct(manifest_cmd(SystemType::Windows, commands::MEM)).expect("direct mem"),
    )
    .expect("direct mem parses");
    assert_eq!(mem.total, direct_mem.total, "mem.total: script vs direct");

    let direct_cpu = sbm_parser::windows::parse_cpu(
        &direct(manifest_cmd(SystemType::Windows, commands::CPU)).expect("direct cpu"),
        &[],
    );
    assert_eq!(status.cpu.len(), direct_cpu.len(), "cpu core count: script vs direct");

    let direct_sys = sbm_parser::common::parse_hostname(
        &direct(manifest_cmd(SystemType::Windows, commands::SYS)).expect("direct sys"),
    );
    assert_eq!(status.sys, direct_sys, "sys: script vs direct");

    // GPU contract: script parse equals direct parse (either may be empty)
    let direct_nvidia = sbm_parser::gpu::nvidia_from_xml(
        &direct(manifest_cmd(SystemType::Windows, commands::NVIDIA)).unwrap_or_default(),
    );
    let script_names: Vec<_> = status.nvidia.iter().map(|g| &g.name).collect();
    let direct_names: Vec<_> = direct_nvidia.iter().map(|g| &g.name).collect();
    assert_eq!(script_names, direct_names, "GPU names: script vs direct");

    eprintln!(
        "windows ssh e2e ok: host={:?} sys={:?} cores={} mem_total={}KiB disks={} net_ifaces={} gpus={}",
        status.host,
        status.sys,
        status.cpu.len(),
        mem.total,
        status.disks.len(),
        status.net.len(),
        status.nvidia.len()
    );
}
