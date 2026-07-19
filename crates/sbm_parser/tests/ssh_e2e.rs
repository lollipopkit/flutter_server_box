//! Opt-in end-to-end test over real SSH.
//!
//! Flow: build the status script → upload it with the shared install command
//! (content piped via stdin, exactly like the app) → run it with the shared
//! exec command → split with parse_script_output → parse_status. Then run
//! selected manifest commands *directly* over the same connection and assert
//! the script-transported parse agrees with the direct parse, proving the
//! generate → install → exec → segment → parse chain is lossless.
//!
//! Configuration (test is skipped when absent): set `SBM_E2E_SSH_HOST` in the
//! environment or in a `.env` at the workspace root. The value is any
//! destination the system `ssh` accepts, so host aliases from `~/.ssh/config`
//! work natively (`SBM_E2E_SSH_HOST=my-server`). The remote must be a Unix
//! host (Linux or BSD/macOS) reachable non-interactively (BatchMode).

use sbm_parser::commands;
use sbm_parser::script::{self, ScriptOptions, ShellFunc};
use sbm_parser::SystemType;
use std::io::Write;
use std::process::{Command, Stdio};

const REMOTE_DIR: &str = "/tmp/server_box_e2e";

fn ssh_host() -> Option<String> {
    // Workspace-root .env; real environment variables take precedence
    // (dotenvy does not override existing vars)
    let root_env = concat!(env!("CARGO_MANIFEST_DIR"), "/../../.env");
    dotenvy::from_path(root_env).ok();
    std::env::var("SBM_E2E_SSH_HOST").ok().filter(|s| !s.is_empty())
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

    // Best-effort cleanup before assertions
    let _ = ssh(&host, &format!("rm -rf {REMOTE_DIR}"), None);

    let segments = script::parse_script_output(&raw);
    assert!(!segments.is_empty(), "no segments parsed; raw output: {raw:?}");

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
