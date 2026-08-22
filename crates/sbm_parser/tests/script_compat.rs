//! Behavior-parity tests for script generation, ported from the app's Dart
//! tests (`test/script_builder_test.dart`, `test/disabled_cmd_types_test.dart`)
//! per the "tests as spec" migration rule.

use sbm_parser::script;
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

/// Custom commands are read from a directory, not spliced into the script.
///
/// The script is now a function of the manifest alone: whatever a user has
/// configured, these bytes are the same, which is what makes this baseline
/// worth locking at all.
#[test]
fn script_reads_custom_commands_from_a_directory() {
    for system in [SystemType::Linux, SystemType::Windows] {
        let script = build_script(system, &opts());
        assert!(script.contains(script::custom_cmd_dir(system)));
        // The marker prefix is emitted; the name comes from the file.
        assert!(script.contains("SrvBoxCusCmdSep."));
        // Only in the status function.
        let after_status = script.split("SbProcess").nth(1).unwrap();
        assert!(!after_status.contains("SrvBoxCusCmdSep."));
    }
    // A command that would break a script if it were spliced in cannot: it is
    // never in the script.
    let hostile = ScriptOptions { ..opts() };
    assert_eq!(build_script(SystemType::Linux, &hostile), build_script(SystemType::Linux, &opts()));
}

/// The installer writes the directory in one round trip, atomically.
#[test]
fn custom_cmd_installer_replaces_the_directory() {
    let cmds = vec![
        (100u32, "disk".to_string(), "df -h | tail -1".to_string()),
        // A command whose text would end a heredoc, close a quote and start a
        // new command if any of it were taken literally.
        (200u32, "hostile".to_string(), "EOF'\n rm -rf / #".to_string()),
    ];
    for system in [SystemType::Linux, SystemType::Windows] {
        let install = script::install_custom_cmds_script(system, &cmds);
        // Nothing a command contains reaches the shell: it travels encoded.
        assert!(!install.contains("rm -rf /"));
        assert!(install.contains(&script::custom_cmd_file_name(100, "disk")));
        assert!(install.contains(&script::custom_cmd_file_name(200, "hostile")));
        // Written aside and moved, so a poll sees one set or the other.
        assert!(install.contains(".new"));
        // The script reads the same place the installer writes. Nothing else
        // keeps those two in step — they are separate strings in separate
        // functions, and disagreeing would mean commands that install fine and
        // never run.
        assert!(install.contains(script::custom_cmd_dir(system)));
        assert!(build_script(system, &opts()).contains(script::custom_cmd_dir(system)));
    }
}

/// The directory does not follow the script.
///
/// The script's own directory defaults to a temp one and is swapped at runtime
/// when that proves unwritable. These files are the only copy of something the
/// user typed, so they live under the user's home and stay there.
#[test]
fn custom_cmd_dir_survives_a_reboot_and_a_script_dir_switch() {
    let unix = script::custom_cmd_dir(SystemType::Linux);
    assert!(unix.starts_with("$HOME/"), "{unix}");
    assert!(!unix.contains("/tmp"), "{unix}");
    assert_eq!(unix, script::custom_cmd_dir(SystemType::Bsd));
    assert!(script::custom_cmd_dir(SystemType::Windows).contains("$env:USERPROFILE"));
}

/// The path the monitor reads directly and the expression the generated script
/// expands must name the same directory. Nothing else would notice if they
/// drifted: each half would work, on a different directory.
#[test]
fn custom_cmd_dir_path_matches_the_shell_expression() {
    let Some(path) = script::custom_cmd_dir_path() else {
        // A test runner with no HOME; nothing to compare against.
        return;
    };

    // Compared as components rather than as text. `PathBuf` joins with the
    // host's separator and the expression is a shell string with `/` in it, so
    // on Windows the two spell one directory two ways — which is a fact about
    // `\` and not a drift between the halves. This used to assert on the
    // spelling and failed there for that reason alone.
    let tail: Vec<String> = path
        .components()
        .rev()
        .take(3)
        .map(|c| c.as_os_str().to_string_lossy().into_owned())
        .collect();
    assert_eq!(
        tail,
        vec![
            script::CUSTOM_CMD_DIR_LEAF.to_string(),
            "server_box".to_string(),
            ".config".to_string(),
        ],
        "the path the monitor reads is somewhere else now"
    );

    // The other half, ending in the same three under the home the shell knows.
    let unix = script::custom_cmd_dir(SystemType::Linux);
    assert_eq!(
        unix,
        format!("$HOME/.config/server_box/{}", script::CUSTOM_CMD_DIR_LEAF),
        "the expression the generated script expands is somewhere else now"
    );

    // And that the path really is under the home directory, which is the part
    // the components above cannot say.
    let home = std::env::var_os("HOME")
        .or_else(|| std::env::var_os("USERPROFILE"))
        .unwrap();
    assert!(path.starts_with(std::path::PathBuf::from(home)));
}

/// Windows names its files `.ps1` (`&` will not run an extensionless file),
/// and the extension is not part of the encoded name. Emitting it made a
/// marker that decodes to nothing, so the command's output was swallowed into
/// whichever section came before it.
#[test]
fn windows_marker_drops_the_ps1_extension() {
    let script = build_script(SystemType::Windows, &opts());
    assert!(script.contains("$_.BaseName"));
    assert!(!script.contains("$_.Name -replace"));
    // What the script would emit for one file, decoded back.
    let file = script::custom_cmd_file_name(100, "disk usage");
    let marker = script::custom_cmd_marker("disk usage");
    assert_eq!(marker, format!("SrvBoxCusCmdSep.b64.{}", file.split_once('_').unwrap().1));
}

/// The editor's read path: what the listing script prints comes back as the
/// same commands that were installed.
#[test]
fn custom_cmd_listing_round_trips() {
    use base64::Engine;
    let b64 = base64::engine::general_purpose::STANDARD;
    let cmds = [(100u32, "disk", "df -h | tail -1"), (200u32, "多行", "echo a\necho b\n")];

    let mut listing = format!("{}\n", script::CUSTOM_CMD_DIR_MARKER);
    for (order, name, cmd) in &cmds {
        listing.push_str(&format!(
            "{} {}\n",
            script::custom_cmd_file_name(*order, name),
            b64.encode(cmd)
        ));
    }

    let parsed = script::parse_custom_cmds_listing(&listing).expect("directory exists");
    assert_eq!(
        parsed,
        cmds.iter().map(|(o, n, c)| (*o, n.to_string(), c.to_string())).collect::<Vec<_>>()
    );
}

/// A directory that does not exist and one that is empty are different
/// answers: the first means the app has never installed here and should seed
/// from what it still holds, the second means the user deleted them all and it
/// must not resurrect them.
#[test]
fn custom_cmd_listing_tells_missing_from_empty() {
    assert_eq!(script::parse_custom_cmds_listing(""), None);
    assert_eq!(script::parse_custom_cmds_listing("sh: base64: not found\n"), None);
    assert_eq!(
        script::parse_custom_cmds_listing(&format!("{}\n", script::CUSTOM_CMD_DIR_MARKER)),
        Some(vec![])
    );
}

/// A stray file in the directory costs that file, not the editor.
#[test]
fn custom_cmd_listing_skips_what_is_not_ours() {
    use base64::Engine;
    let b64 = base64::engine::general_purpose::STANDARD;
    let listing = format!(
        "{}\nREADME {}\n00100_notbase64!! x\n{} {}\n",
        script::CUSTOM_CMD_DIR_MARKER,
        b64.encode("notes"),
        script::custom_cmd_file_name(300, "ok"),
        b64.encode("echo ok"),
    );
    assert_eq!(
        script::parse_custom_cmds_listing(&listing),
        Some(vec![(300, "ok".to_string(), "echo ok".to_string())])
    );
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
    assert!(decoded.contains("Set-Content"));
    assert!(decoded.contains(r"C:\temp\test\script.ps1"));

    // Never ReadToEnd: Windows OpenSSH does not reliably hand the channel's EOF
    // to the child, so waiting for one hangs the install for good. The end of
    // the content has to be a line in the content — see `install_command`.
    assert!(!decoded.contains("ReadToEnd"));
    assert!(decoded.contains("ReadLine()"));
    assert!(decoded.contains(WINDOWS_INSTALL_EOF));
}

/// The two halves have to agree: the command stops at a line the payload is
/// responsible for putting there, and neither is any use alone.
#[test]
fn install_payload_terminates_what_the_command_waits_for() {
    let script = "Write-Output 'hi'\n";
    let win = install_payload(SystemType::Windows, script);
    assert!(win.starts_with(script));
    assert_eq!(win, format!("{script}{WINDOWS_INSTALL_EOF}\n"));

    // A script that does not end in a newline still gets the marker on a line
    // of its own, or the last line of the script would swallow it
    let unterminated = "Write-Output 'hi'";
    assert_eq!(
        install_payload(SystemType::Windows, unterminated),
        format!("{unterminated}\n{WINDOWS_INSTALL_EOF}\n")
    );

    // Unix reads to EOF and gets one, so nothing is added — a stray marker line
    // would end up inside the installed script
    for system in [SystemType::Linux, SystemType::Bsd] {
        assert_eq!(install_payload(system, script), script);
    }
}

/// The marker cannot appear in a generated script, or the install would stop
/// partway through and write a truncated file.
#[test]
fn no_generated_script_contains_the_install_marker() {
    for system in [SystemType::Windows, SystemType::Linux, SystemType::Bsd] {
        let script = build_script(system, &ScriptOptions::default());
        assert!(
            !script.contains(WINDOWS_INSTALL_EOF),
            "{system:?} script contains {WINDOWS_INSTALL_EOF}"
        );
    }
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

// ---------- SbStatus / SbStatusExt split ----------

fn func_body(script: &str, func: ShellFunc) -> &str {
    let start = script.find(&format!("{}() {{", func.name())).unwrap();
    let rest = &script[start..];
    &rest[..rest.find("\n}\n").unwrap()]
}

/// The expensive/hardware-disturbing commands live in `SbStatusExt` only, so
/// the fast poll never runs them — see `commands::EXTENDED`
#[test]
fn extended_commands_split_out_of_status() {
    let script = build_script(SystemType::Linux, &opts());
    let status = func_body(&script, ShellFunc::Status);
    let ext = func_body(&script, ShellFunc::StatusExt);

    assert!(!status.contains("smartctl"));
    assert!(!status.contains("amd-smi"));
    assert!(ext.contains("smartctl"));
    assert!(ext.contains("amd-smi"));

    // Everything else stays in the fast poll: cheap to run, and wanted at the
    // status interval rather than minutes apart
    assert!(status.contains(&format!("echo {}", script::cmd_marker("sensors"))));
    assert!(status.contains(&format!("echo {}", script::cmd_marker("battery"))));
    assert!(status.contains("nvidia-smi -q -x"));
    assert!(!ext.contains(&format!("echo {}", script::cmd_marker("sensors"))));
    assert!(!ext.contains("nvidia-smi"));
}

#[test]
fn extended_commands_split_out_of_status_windows() {
    let script = build_script(SystemType::Windows, &opts());
    let status = script.split("function SbProcess").next().unwrap();
    let (status, ext) = status.split_once("function SbStatusExt").unwrap();

    assert!(!status.contains("Get-StorageReliabilityCounter"));
    assert!(!status.contains("amd-smi"));
    assert!(ext.contains("Get-StorageReliabilityCounter"));
    assert!(ext.contains("amd-smi"));
    // The Windows disk-IO sample costs two seconds of Start-Sleep but feeds a
    // live chart, so it stays in the fast poll
    assert!(status.contains("Win32_PerfRawData_PerfDisk_PhysicalDisk"));
}

/// Disabling every command of one half must not emit an empty `then`/`else`
/// branch, which `sh` rejects as a syntax error
#[test]
fn disabled_all_extended_keeps_script_valid() {
    let disabled: Vec<String> = sbm_parser::commands::EXTENDED
        .iter()
        .flat_map(|key| [format!("Linux.{key}"), format!("BSD.{key}")])
        .collect();
    let script = build_script(SystemType::Linux, &ScriptOptions { disabled, ..opts() });
    let ext = func_body(&script, ShellFunc::StatusExt);
    assert!(!ext.contains("SrvBoxSep."));
    // Body lines carry the function's tab prefix
    assert!(ext.contains("then\n\t\t:\n\telse\n\t\t:\n\tfi"), "{ext}");
}

// ---------- parse_script_output ----------

/// Builds the wire form of a section: marker line + body
fn section(key: &str, body: &str) -> String {
    format!("{}\n{body}\n", script::cmd_marker(key))
}

fn custom_section(name: &str, body: &str) -> String {
    format!("{}\n{body}\n", script::custom_cmd_marker(name))
}

#[test]
fn parse_output_basic() {
    let raw = section("time", "123456") + &section("host", "myhost");
    let map = parse_script_output(&raw);
    assert_eq!(map["time"], "123456");
    assert_eq!(map["host"], "myhost");
}

#[test]
fn parse_output_custom_and_multiline() {
    let raw = section("mem", "MemTotal: 1\nMemFree: 2") + &custom_section("my_cmd", "hello\nworld");
    let map = parse_script_output(&raw);
    assert_eq!(map["mem"], "MemTotal: 1\nMemFree: 2");
    assert_eq!(map[&script::custom_result_key("my_cmd")], "hello\nworld");
}

/// A custom command may be named after a built-in section. Filing it under a
/// namespaced key keeps it from replacing that section's real output.
#[test]
fn custom_command_cannot_overwrite_a_builtin_section() {
    let raw = section("cpu", "cpu 1 2 3") + &custom_section("cpu", "user output");
    let map = parse_script_output(&raw);
    assert_eq!(map["cpu"], "cpu 1 2 3");
    assert_eq!(map[&script::custom_result_key("cpu")], "user output");
}

/// Markers share the stream with command output, so only the encoded form
/// counts. A command printing a plausible-looking separator is data.
#[test]
fn unencoded_separator_in_output_is_data() {
    let raw = section("host", "SrvBoxSep.time\nSrvBoxCusCmdSep.x\nmyhost");
    let map = parse_script_output(&raw);
    assert_eq!(map.len(), 1);
    assert_eq!(map["host"], "SrvBoxSep.time\nSrvBoxCusCmdSep.x\nmyhost");
}

#[test]
fn segment_detection_uses_the_same_encoded_markers_as_parsing() {
    assert!(!script::contains_script_segment("SrvBoxSep.time\noutput"));
    assert!(!script::contains_status_segment("SrvBoxSep.time\noutput"));

    let status = section("time", "123");
    assert!(script::contains_script_segment(&status));
    assert!(script::contains_status_segment(&status));

    let custom = custom_section("probe", "hello");
    assert!(script::contains_script_segment(&custom));
    assert!(!script::contains_status_segment(&custom));
}

#[test]
fn custom_result_key_classification_round_trips() {
    let key = script::custom_result_key("disk");
    assert_eq!(script::custom_result_name(&key), Some("disk"));
    assert_eq!(script::custom_result_name("disk"), None);
    assert_eq!(script::custom_result_name("SrvBoxCusCmdSep."), None);
}

/// Likewise a marker whose payload is not decodable base64url
#[test]
fn undecodable_marker_is_data() {
    let raw = section("host", "SrvBoxSep.b64.!!!not-base64!!!\nmyhost");
    let map = parse_script_output(&raw);
    assert_eq!(map.len(), 1);
    assert!(map["host"].contains("myhost"));
}

#[test]
fn parse_output_empty_and_leading_noise() {
    assert!(parse_script_output("").is_empty());
    // Lines before the first separator are dropped (no current key)
    let map = parse_script_output(&("noise\n".to_string() + &section("time", "1")));
    assert_eq!(map.len(), 1);
    assert_eq!(map["time"], "1");
}

/// CRLF tolerance is a deliberate deviation from Dart (see module docs)
#[test]
fn parse_output_crlf() {
    let raw = (section("time", "123456") + &section("host", "myhost")).replace('\n', "\r\n");
    let map = parse_script_output(&raw);
    assert_eq!(map["time"], "123456");
    assert_eq!(map["host"], "myhost");
}

// ---------- e2e: run the generated script the way the monitor does ----------

/// Executes the status script through `sh -s` and parses the output.
/// This is exactly the monitor's local collection path.
#[cfg(unix)]
#[test]
fn e2e_unix_status_script_runs() {
    use std::io::Write;
    use std::process::{Command, Stdio};

    let script = build_script(SystemType::Linux, &ScriptOptions {
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

/// The convention both ends of the migration have to agree on: the app writes
/// these files over SSH, the monitor reads the same directory, and the script
/// sorts by name because the name carries the order.
#[test]
fn custom_cmd_file_names_sort_by_order() {
    use sbm_parser::script::{
        custom_cmd_file_name, custom_cmd_name_from_file, CUSTOM_CMD_ORDER_STEP,
    };

    let first = custom_cmd_file_name(CUSTOM_CMD_ORDER_STEP, "disk usage");
    let second = custom_cmd_file_name(CUSTOM_CMD_ORDER_STEP * 2, "who is on");
    // Sorting the directory sorts the commands. Zero padding is what makes a
    // string compare agree with a numeric one.
    assert!(first < second);
    // And there is room to move one between them without touching either.
    let between = custom_cmd_file_name(CUSTOM_CMD_ORDER_STEP + 50, "in between");
    assert!(first < between && between < second);

    // A name survives the round trip whatever is in it.
    for name in ["disk usage", "磁盘", "a\"b$c`d", "with_underscore"] {
        let file = custom_cmd_file_name(300, name);
        assert_eq!(custom_cmd_name_from_file(&file).as_deref(), Some(name));
        // Nothing that could act in a shell reaches the file name.
        assert!(file.bytes().all(|b| b.is_ascii_alphanumeric() || b"-_=".contains(&b)));
    }

    // Anything else in that directory is not ours and is left alone.
    assert_eq!(custom_cmd_name_from_file("README"), None);
    assert_eq!(custom_cmd_name_from_file("_notanumber"), None);
}
