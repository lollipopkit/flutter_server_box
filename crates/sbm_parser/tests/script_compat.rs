//! Behavior-parity tests for script generation, ported from the app's Dart
//! tests (`test/script_builder_test.dart`, `test/disabled_cmd_types_test.dart`)
//! per the "tests as spec" migration rule.

use sbm_parser::script::*;
use sbm_parser::SystemType;

fn opts() -> ScriptOptions {
    ScriptOptions { build_number: "1466".into(), ..Default::default() }
}

// ---------- script_builder_test.dart ----------

/// Dart 'script generation produces valid output for all platforms'
#[test]
fn script_valid_output_all_platforms() {
    for system in [SystemType::Linux, SystemType::Windows] {
        let script = build_script(system, &opts());
        assert!(!script.is_empty());
        for func in ShellFunc::ALL {
            assert!(script.contains(func.name()), "{system:?} missing {}", func.name());
        }
        match system {
            SystemType::Windows => {
                assert!(script.contains("switch ($args[0])"));
                assert!(script.contains("PowerShell script for ServerBox"));
            }
            _ => {
                assert!(script.contains("#!/bin/sh"));
                assert!(script.contains("case $1 in"));
            }
        }
    }
}

/// Dart 'script generation with custom commands works correctly'
#[test]
fn script_custom_commands() {
    let o = ScriptOptions {
        custom_cmds: vec![
            ("custom_test".into(), "echo \"Custom test command\"".into()),
            ("another_cmd".into(), "whoami".into()),
        ],
        ..opts()
    };
    for system in [SystemType::Linux, SystemType::Windows] {
        let script = build_script(system, &o);
        assert!(script.contains("echo \"Custom test command\""));
        assert!(script.contains("whoami"));
        assert!(script.contains("SrvBoxCusCmdSep.custom_test"));
        // Custom commands are only injected into SbStatus
        let after_status = script.split("SbProcess").nth(1).unwrap();
        assert!(!after_status.contains("SrvBoxCusCmdSep."));
    }
}

/// Dart 'install commands are generated correctly'; the Windows variant is
/// -EncodedCommand wrapped so it runs from cmd.exe default shells too
#[test]
fn install_commands() {
    let unix = install_command(SystemType::Linux, "/tmp/test", "/tmp/test/script.sh");
    assert!(unix.contains("mkdir"));
    assert!(unix.contains("chmod 755"));
    assert!(unix.contains("/tmp/test/script.sh"));

    let win = install_command(SystemType::Windows, r"C:\temp\test", r"C:\temp\test\script.ps1");
    assert!(win.starts_with("powershell -NoProfile -ExecutionPolicy Bypass -EncodedCommand "));
    let b64 = win.rsplit(' ').next().unwrap();
    let decoded = decode_utf16le_b64(b64);
    assert!(decoded.contains("New-Item"));
    assert!(decoded.contains("[System.Console]::In.ReadToEnd()"));
    assert!(decoded.contains("Set-Content"));
    assert!(decoded.contains(r"C:\temp\test\script.ps1"));
}

fn decode_utf16le_b64(b64: &str) -> String {
    use base64::Engine;
    let bytes = base64::engine::general_purpose::STANDARD.decode(b64).unwrap();
    let utf16: Vec<u16> = bytes.chunks_exact(2).map(|c| u16::from_le_bytes([c[0], c[1]])).collect();
    String::from_utf16(&utf16).unwrap()
}

/// Dart 'exec commands are generated correctly for all platforms'
#[test]
fn exec_commands() {
    for func in ShellFunc::ALL {
        let unix = exec_command(SystemType::Linux, "/tmp/test/script.sh", func);
        assert!(unix.contains("/tmp/test/script.sh"));
        assert!(unix.ends_with(&format!("-{}", func.flag())));

        let win = exec_command(SystemType::Windows, r"C:\temp\test\script.ps1", func);
        assert!(win.contains("powershell"));
        assert!(win.contains("-ExecutionPolicy Bypass"));
        assert!(win.ends_with(&format!("-{}", func.flag())));
    }
}

/// Dart 'script headers contain proper metadata'
#[test]
fn script_headers() {
    let win = build_script(SystemType::Windows, &opts());
    assert!(win.contains("PowerShell script for ServerBox app v1.0.1466"));
    assert!(win.contains("DO NOT delete this file"));
    assert!(win.contains("$ErrorActionPreference = \"SilentlyContinue\""));

    let unix = build_script(SystemType::Linux, &opts());
    assert!(unix.starts_with("#!/bin/sh"));
    assert!(unix.contains("# Script for ServerBox app v1.0.1466"));
    assert!(unix.contains("DO NOT delete this file"));
    assert!(unix.contains("export LANG=en_US.UTF-8"));
}

/// Dart 'scripts handle all system types properly': env probes + Bsd == Linux
#[test]
fn system_types_and_probes() {
    let unix = build_script(SystemType::Linux, &opts());
    assert!(unix.contains("macSign="));
    assert!(unix.contains("bsdSign="));
    assert!(unix.contains("isBusybox="));
    assert_eq!(unix, build_script(SystemType::Bsd, &opts()));
}

// ---------- disabled_cmd_types_test.dart ----------

/// Dart 'filters Linux status commands when disabled'
#[test]
fn disabled_filters_linux() {
    let o = ScriptOptions {
        disabled: vec!["Linux.net".into(), "Linux.sys".into()],
        ..opts()
    };
    let script = build_script(SystemType::Linux, &o);
    assert!(!script.contains("cat /proc/net/dev"));
    assert!(!script.contains("cat /etc/*-release | grep ^PRETTY_NAME"));
    assert!(script.contains("uptime"));
    assert!(script.contains("date +%s"));
}

/// Dart 'filters BSD status commands when disabled' — both scopes apply
/// within the single Unix script
#[test]
fn disabled_filters_bsd_in_unix_script() {
    let o = ScriptOptions {
        disabled: vec!["BSD.sys".into(), "BSD.mem".into()],
        ..opts()
    };
    let script = build_script(SystemType::Linux, &o);
    assert!(!script.contains("uname -or"));
    assert!(!script.contains("top -l 1 | grep PhysMem"));
    assert!(script.contains("cat /etc/*-release | grep ^PRETTY_NAME"));
    assert!(script.contains("cat /proc/meminfo | grep -E 'Mem|Swap'"));
}

/// Dart 'filters Windows status commands when disabled'
#[test]
fn disabled_filters_windows() {
    let o = ScriptOptions {
        disabled: vec!["Windows.net".into(), "Windows.uptime".into(), "Windows.temp".into()],
        ..opts()
    };
    let script = build_script(SystemType::Windows, &o);
    assert!(!script.contains("LastBootUpTime"));
    assert!(!script.contains("MSAcpi_ThermalZoneTemperature"));
    assert!(script.contains("Get-Process"));
    assert!(script.contains("Get-WmiObject -Class Win32_OperatingSystem"));
}

/// Dart 'ignores disabled names for other platforms'
#[test]
fn disabled_other_platform_ignored() {
    let o = ScriptOptions {
        disabled: vec!["Windows.sys".into(), "Windows.net".into()],
        ..opts()
    };
    let script = build_script(SystemType::Linux, &o);
    assert!(script.contains("cat /etc/*-release | grep ^PRETTY_NAME"));
    assert!(script.contains("cat /proc/net/dev"));
}

/// Dart 'disabling all status commands removes separators'
#[test]
fn disabled_all_removes_separators() {
    let all_unix: Vec<String> = sbm_parser::commands::LINUX
        .iter()
        .map(|s| format!("Linux.{}", s.key))
        .chain(sbm_parser::commands::BSD.iter().map(|s| format!("BSD.{}", s.key)))
        .collect();
    let unix = build_script(SystemType::Linux, &ScriptOptions { disabled: all_unix, ..opts() });
    assert!(!unix.contains("SrvBoxSep."));

    let all_win: Vec<String> = sbm_parser::commands::WINDOWS
        .iter()
        .map(|s| format!("Windows.{}", s.key))
        .collect();
    let win = build_script(SystemType::Windows, &ScriptOptions { disabled: all_win, ..opts() });
    assert!(!win.contains("SrvBoxSep."));
}

/// Scope prefix matching is case-insensitive (Hive-stored values use
/// "Linux."/"BSD."/"Windows." casing)
#[test]
fn disabled_case_insensitive() {
    let o = ScriptOptions { disabled: vec!["linux.NET".into()], ..opts() };
    let script = build_script(SystemType::Linux, &o);
    assert!(!script.contains("cat /proc/net/dev"));
}

// ---------- core_only (monitor mode) ----------

#[test]
fn core_only_excludes_expensive_commands() {
    let core = build_script(SystemType::Linux, &ScriptOptions { core_only: true, ..opts() });
    assert!(!core.contains("smartctl"));
    assert!(!core.contains("amd-smi"));
    assert!(!core.contains("\techo SrvBoxSep.sensors"));
    // NVIDIA is core: a cheap single probe, wanted for the GPU card
    assert!(core.contains("nvidia-smi -q -x"));
    let full = build_script(SystemType::Linux, &opts());
    assert!(full.contains("smartctl"));
    assert!(full.contains("amd-smi"));
}

// ---------- parse_script_output ----------

#[test]
fn parse_output_basic() {
    let raw = "SrvBoxSep.time\n123456\nSrvBoxSep.host\nmyhost\n";
    let map = parse_script_output(raw);
    assert_eq!(map["time"], "123456");
    assert_eq!(map["host"], "myhost");
}

#[test]
fn parse_output_custom_and_multiline() {
    let raw = "SrvBoxSep.mem\nMemTotal: 1\nMemFree: 2\nSrvBoxCusCmdSep.my_cmd\nhello\nworld\n";
    let map = parse_script_output(raw);
    assert_eq!(map["mem"], "MemTotal: 1\nMemFree: 2");
    assert_eq!(map["my_cmd"], "hello\nworld");
}

#[test]
fn parse_output_empty_and_leading_noise() {
    assert!(parse_script_output("").is_empty());
    // Lines before the first separator are dropped (no current key)
    let map = parse_script_output("noise\nSrvBoxSep.time\n1\n");
    assert_eq!(map.len(), 1);
    assert_eq!(map["time"], "1");
}

/// CRLF tolerance is a deliberate deviation from Dart (see module docs)
#[test]
fn parse_output_crlf() {
    let raw = "SrvBoxSep.time\r\n123456\r\nSrvBoxSep.host\r\nmyhost\r\n";
    let map = parse_script_output(raw);
    assert_eq!(map["time"], "123456");
    assert_eq!(map["host"], "myhost");
}

// ---------- e2e: run the generated script the way the monitor does ----------

/// Executes the core-only status script through `sh -s` and parses the output.
/// This is exactly the monitor's local collection path.
#[cfg(unix)]
#[test]
fn e2e_unix_status_script_runs() {
    use std::io::Write;
    use std::process::{Command, Stdio};

    let script = build_script(SystemType::Linux, &ScriptOptions {
        core_only: true,
        build_number: "test".into(),
        ..Default::default()
    });

    let dir = std::env::temp_dir().join("sbm_script_compat_test");
    std::fs::create_dir_all(&dir).unwrap();
    let path = dir.join("status.sh");
    std::fs::write(&path, &script).unwrap();

    let mut child = Command::new("sh")
        .arg(&path)
        .arg("-s")
        .stdout(Stdio::piped())
        .stdin(Stdio::null())
        .spawn()
        .unwrap();
    let out = {
        let mut buf = String::new();
        use std::io::Read;
        child.stdout.take().unwrap().read_to_string(&mut buf).unwrap();
        child.wait().unwrap();
        buf
    };
    let _ = std::io::stdout().flush();
    std::fs::remove_dir_all(&dir).ok();

    let map = parse_script_output(&out);
    assert!(map.contains_key("time"), "keys: {:?}", map.keys().collect::<Vec<_>>());
    assert!(map.contains_key("echo"));
    let sign = &map["echo"];
    assert!(sign.contains("__linux") || sign.contains("__bsd"), "echo: {sign}");
}
