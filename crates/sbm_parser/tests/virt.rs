//! `sbm_parser::virt` against the fixtures in `tests/fixtures/virt/` (see the
//! README there: mostly captured from a libvirt 11.3.0 host, the rest
//! hand-written and labelled as such), plus the generated scripts run by a
//! real `sh` against a stub `virsh`.
//!
//! `overview.expected.json` / `detail_*.expected.json` are also what the
//! Dart FFI test compares against. Regenerate them with
//! `SBM_UPDATE_VIRT_FIXTURES=1 cargo test -p sbm_parser --test virt`, and
//! review the diff: they are the contract, not a snapshot to accept blindly.

use sbm_parser::script;
use sbm_parser::virt::{self, VirtAction, VirtError, VirtState};
use std::path::PathBuf;
use std::process::{Command, Stdio};

fn dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/virt")
}

fn fixture(name: &str) -> String {
    std::fs::read_to_string(dir().join(name)).unwrap_or_else(|e| panic!("{name}: {e}"))
}

/// What a script prints for one `virsh` call: marker, output, status line.
fn section(key: &str, body: &str, rc: i32) -> String {
    format!("{}\n{body}\n{}{rc}\n", script::cmd_marker(key), virt::RC_PREFIX)
}

fn overview_output(list_fixture: &str) -> String {
    [
        section(virt::KEY_VERSION, &fixture("version_libvirt11.txt"), 0),
        section(virt::KEY_LIST, &fixture(list_fixture), 0),
        section(virt::KEY_AUTOSTART, &fixture("list_autostart.txt"), 0),
        section(virt::KEY_PERSISTENT, &fixture("list_persistent.txt"), 0),
        section(virt::KEY_STATS, &fixture("domstats.txt"), 0),
    ]
    .concat()
}

fn detail_output(display: (&str, i32), xml: &str) -> String {
    section(virt::KEY_DISPLAY, &fixture(display.0), display.1)
        + &section(virt::KEY_XML, &fixture(xml), 0)
}

/// Compare against (or with the env var set, rewrite) an expected JSON file.
fn assert_expected<T: serde::Serialize>(value: &T, name: &str) {
    let path = dir().join(name);
    let json = serde_json::to_string_pretty(value).unwrap() + "\n";
    if std::env::var_os("SBM_UPDATE_VIRT_FIXTURES").is_some() {
        std::fs::write(&path, &json).unwrap();
        return;
    }
    let expected: serde_json::Value =
        serde_json::from_str(&fixture(name)).unwrap_or_else(|e| panic!("{name}: {e}"));
    assert_eq!(serde_json::to_value(value).unwrap(), expected, "{name}");
}

#[test]
fn version() {
    let v = virt::parse_version(&fixture("version_libvirt11.txt")).unwrap();
    assert_eq!(v.libvirt.as_deref(), Some("11.3.0"));
    assert_eq!(v.hypervisor.as_deref(), Some("QEMU"));
    assert_eq!(v.hypervisor_version.as_deref(), Some("10.0.13"));
    let v = virt::parse_version(&fixture("version_libvirt12.txt")).unwrap();
    assert_eq!(v.libvirt.as_deref(), Some("12.0.0"));
    assert_eq!(v.hypervisor_version.as_deref(), Some("10.2.1"));
    assert!(virt::parse_version("").is_none());
    assert!(virt::parse_version("garbage\n").is_none());
}

#[test]
fn uuid_names_both_formats() {
    let new = virt::parse_uuid_names(&fixture("list_uuid_name.txt"));
    assert_eq!(new.len(), 3);
    assert_eq!(new[1].1, "cirros-paused");
    assert_eq!(new[2].1, "it's-\"odd\"");
    let old = virt::parse_uuid_names(&fixture("list_uuid_name_libvirt6.txt"));
    assert_eq!(old.len(), 3);
    assert_eq!(old[1].1.trim_end(), "cirros-paused");
    for ((u1, n1), (u2, n2)) in new.iter().zip(&old) {
        assert_eq!(u1, u2);
        assert_eq!(n1, n2.trim_end());
    }
}

#[test]
fn domstats_records() {
    // Captured: libvirt prints domains in its own order, not `list`'s
    let recs = virt::parse_domstats(&fixture("domstats.txt"));
    let names: Vec<&str> = recs.iter().map(|r| r.name.as_str()).collect();
    assert_eq!(names, ["cirros-paused", "cirros-run", "it's-\"odd\""]);

    let paused = &recs[0];
    assert_eq!((paused.state_code, paused.reason_code), (Some(3), Some(1)));
    assert_eq!(paused.counters.balloon_available_kib, Some(189780));
    assert_eq!(paused.counters.balloon_unused_kib, Some(143512));

    let run = &recs[1];
    assert_eq!((run.state_code, run.reason_code), (Some(1), Some(1)));
    assert_eq!(run.counters.cpu_time_ns, Some(7550532000));
    assert_eq!((run.vcpu_current, run.vcpu_max), (Some(2), Some(2)));
    assert_eq!(run.mem_max_kib, Some(262144));
    assert_eq!(run.counters.balloon_rss_kib, Some(285628));
    // Two vCPUs' worth of `vcpu.N.*.sum` lines do not create anything
    assert_eq!(run.counters.nets.len(), 2);
    assert_eq!(run.counters.nets[1].name, "vnet1");
    assert_eq!(run.counters.nets[1].rx_bytes, Some(12948));
    assert_eq!(run.counters.blocks.len(), 2);
    assert_eq!(run.counters.blocks[1].name, "vdb");
    assert_eq!(run.counters.blocks[1].capacity, Some(1073741824));

    // Shut off: libvirt 11.3 still reports the CPU time of the last run and
    // the block sizes, but no I/O counters and no nets
    let odd = &recs[2];
    // Reason 6 (`failed`): its last start was refused (see
    // `error_apparmor_start.txt`)
    assert_eq!((odd.state_code, odd.reason_code), (Some(5), Some(6)));
    assert_eq!(odd.counters.cpu_time_ns, Some(610000000));
    assert_eq!(odd.mem_current_kib, Some(262144));
    assert!(odd.counters.nets.is_empty());
    assert_eq!(odd.counters.blocks[0].rd_bytes, None);
    assert_eq!(
        odd.counters.blocks[0].path.as_deref(),
        Some("/var/lib/libvirt/images/off1.qcow2")
    );
}

/// Shapes the test host does not have (hand-written, see the README):
/// vCPUs below the maximum, an empty cdrom, macvtap, a domain in shutdown.
#[test]
fn domstats_synthetic_records() {
    let recs = virt::parse_domstats(&fixture("domstats_synthetic.txt"));
    let win = &recs[0];
    assert_eq!((win.vcpu_current, win.vcpu_max), (Some(4), Some(8)));
    assert_eq!(win.counters.blocks.len(), 3);
    assert_eq!(win.counters.blocks[1].wr_bytes, Some(180224000));
    // An empty cdrom has no path
    assert_eq!(win.counters.blocks[2].path, None);
    assert_eq!(win.counters.nets[1].name, "macvtap0");
    assert_eq!(win.counters.nets[1].tx_bytes, Some(2048));
    let ci = &recs[1];
    assert_eq!(VirtState::from_libvirt(ci.state_code.unwrap(), ci.reason_code.unwrap()), VirtState::Stopping);
}

#[test]
fn overview() {
    let o = virt::parse_overview(&overview_output("list_uuid_name.txt")).unwrap();
    assert_eq!(o.version.as_ref().unwrap().libvirt.as_deref(), Some("11.3.0"));
    // `list` order, whatever order domstats printed
    let names: Vec<&str> = o.domains.iter().map(|d| d.name.as_str()).collect();
    assert_eq!(names, ["cirros-run", "cirros-paused", "it's-\"odd\""]);
    let by_name = |n: &str| o.domains.iter().find(|d| d.name == n).unwrap();

    let run = by_name("cirros-run");
    assert_eq!(run.state, VirtState::Running);
    assert_eq!(run.reason, "booted");
    assert!(run.autostart && run.persistent);
    assert_eq!(run.vcpu_current, Some(2));

    let paused = by_name("cirros-paused");
    assert_eq!(paused.state, VirtState::Paused);
    assert_eq!(paused.reason, "user");
    assert!(!paused.autostart && paused.persistent);

    let odd = by_name("it's-\"odd\"");
    assert_eq!(odd.uuid, "1438b9e3-f647-47ee-8ed2-6dbc3adccd68");
    assert_eq!(odd.state, VirtState::Stopped);
    assert_eq!(odd.reason, "failed");
    assert_eq!(odd.mem_max_kib, Some(262144));

    assert_expected(&o, "overview.expected.json");

    // libvirt < 7.0's padded list joins to the same result
    let old = virt::parse_overview(&overview_output("list_uuid_name_libvirt6.txt")).unwrap();
    assert_eq!(old, o);
}

#[test]
fn overview_domain_missing_from_stats() {
    // Defined between `list` and `domstats`: listed, no numbers
    let raw = [
        section(virt::KEY_LIST, "11111111-2222-4333-8444-555555555555 new-one", 0),
        section(virt::KEY_AUTOSTART, "", 0),
        section(virt::KEY_PERSISTENT, "", 0),
        section(virt::KEY_STATS, "", 0),
    ]
    .concat();
    let o = virt::parse_overview(&raw).unwrap();
    assert_eq!(o.version, None);
    assert_eq!(o.domains[0].name, "new-one");
    assert_eq!(o.domains[0].state, VirtState::Unknown);
    assert_eq!(o.domains[0].state_code, -1);
}

#[test]
fn overview_errors() {
    let failing = |file: &str| {
        [
            virt::KEY_VERSION,
            virt::KEY_LIST,
            virt::KEY_AUTOSTART,
            virt::KEY_PERSISTENT,
            virt::KEY_STATS,
        ]
        .iter()
        .map(|k| section(k, &fixture(file), 1))
        .collect::<String>()
    };
    match virt::parse_overview(&failing("error_permission.txt")) {
        Err(VirtError::PermissionDenied { message }) => {
            assert!(message.contains("libvirt-sock': Permission denied"), "{message}");
            assert!(!message.contains("error:"));
        }
        other => panic!("{other:?}"),
    }
    assert!(matches!(
        virt::parse_overview(&failing("error_polkit.txt")),
        Err(VirtError::PermissionDenied { .. })
    ));
    assert!(matches!(
        virt::parse_probe(&failing("error_polkit.txt")),
        Err(VirtError::PermissionDenied { .. })
    ));
    assert!(matches!(
        virt::parse_overview(&failing("error_no_daemon.txt")),
        Err(VirtError::ConnectFailed { .. })
    ));
    // Cut off mid-stats: no status line
    let mut cut = overview_output("list_uuid_name.txt");
    cut.truncate(cut.rfind(virt::RC_PREFIX).unwrap());
    assert!(matches!(
        virt::parse_overview(&cut),
        Err(VirtError::Malformed { .. })
    ));
}

#[test]
fn detail_running_vnc() {
    let d = virt::parse_domain_detail(&detail_output(
        ("domdisplay_cirros_run.txt", 0),
        "dumpxml_cirros_run.xml",
    ))
    .unwrap();
    let display = d.display.as_ref().unwrap();
    assert_eq!(display.protocol, "vnc");
    assert_eq!(display.host.as_deref(), Some("127.0.0.1"));
    assert_eq!(display.port, Some(5900));
    let x = &d.xml;
    assert_eq!(x.name.as_deref(), Some("cirros-run"));
    assert_eq!(x.title, None);
    assert_eq!(x.arch.as_deref(), Some("x86_64"));
    assert_eq!(x.machine.as_deref(), Some("pc-i440fx-10.0"));
    // The backing chain's `<source>` is not a second disk
    let sources: Vec<Option<&str>> = x.disks.iter().map(|d| d.source.as_deref()).collect();
    assert_eq!(
        sources,
        [
            Some("/var/lib/libvirt/images/run1.qcow2"),
            Some("/var/lib/libvirt/images/extra.qcow2"),
        ]
    );
    assert_eq!(x.disks[0].format.as_deref(), Some("qcow2"));
    assert_eq!(x.disks[1].target.as_deref(), Some("vdb"));
    assert_eq!(x.nics.len(), 2);
    assert_eq!(x.nics[0].source.as_deref(), Some("default"));
    assert_eq!(x.nics[1].target.as_deref(), Some("vnet1"));
    assert_eq!(x.graphics[0].port, Some(5900));
    assert_eq!(x.graphics[0].listen.as_deref(), Some("127.0.0.1"));
    assert!(x.has_serial_console);
    assert_expected(&d, "detail_cirros_run.expected.json");
}

#[test]
fn detail_spice_many_devices() {
    let d = virt::parse_domain_detail(&detail_output(
        ("domdisplay_win11.txt", 0),
        "dumpxml_win11.xml",
    ))
    .unwrap();
    let display = d.display.as_ref().unwrap();
    assert_eq!((display.port, display.tls_port), (Some(5901), Some(5902)));
    let x = &d.xml;
    assert_eq!(x.description.as_deref(), Some("Windows 11 test box\nsecond line"));
    let sources: Vec<Option<&str>> = x.disks.iter().map(|d| d.source.as_deref()).collect();
    assert_eq!(
        sources,
        [
            Some("/var/lib/libvirt/images/win11.qcow2"),
            Some("/srv/vm/win11-data.raw"),
            None,
            Some("rbd:vms/win11-scratch"),
            Some("fast/win11-swap.qcow2"),
        ]
    );
    assert_eq!(x.disks[2].device, "cdrom");
    assert!(x.disks[2].readonly);
    assert_eq!(x.nics[0].kind, "bridge");
    assert_eq!(x.nics[0].source.as_deref(), Some("br0"));
    assert_eq!(x.nics[0].model.as_deref(), Some("e1000e"));
    assert_eq!(x.nics[1].source.as_deref(), Some("enp3s0"));
    assert_eq!(x.graphics[0].kind, "spice");
    assert_eq!(x.graphics[0].tls_port, Some(5902));
    assert!(!x.has_serial_console);
    assert_expected(&d, "detail_win11.expected.json");
}

#[test]
fn detail_stopped_without_graphics() {
    let d = virt::parse_domain_detail(&detail_output(
        ("error_display_not_running.txt", 1),
        "dumpxml_odd.xml",
    ))
    .unwrap();
    assert_eq!(d.display, None);
    assert_eq!(d.xml.name.as_deref(), Some("it's-\"odd\""));
    assert_eq!(d.xml.arch.as_deref(), Some("x86_64"));
    assert!(d.xml.graphics.is_empty());
    assert!(d.xml.has_serial_console);
    assert_eq!(d.xml.nics[0].target, None);

    let d = virt::parse_domain_detail(&detail_output(
        ("error_display_no_graphics.txt", 1),
        "dumpxml_odd.xml",
    ))
    .unwrap();
    assert_eq!(d.display, None);
}

#[test]
fn detail_inactive_vnc() {
    // Captured: the running domain's inactive definition, as a shut-off
    // domain with VNC prints it
    let x = virt::parse_domain_xml(&fixture("dumpxml_cirros_run_inactive.xml")).unwrap();
    assert_eq!(x.graphics.len(), 1);
    assert_eq!(x.graphics[0].port, None);
    assert!(x.graphics[0].autoport);
    assert_eq!(x.graphics[0].listen.as_deref(), Some("127.0.0.1"));
    assert!(x.nics.iter().all(|n| n.target.is_none()));

    // Hand-written: a socket listener
    let x = virt::parse_domain_xml(&fixture("dumpxml_inactive_vnc.xml")).unwrap();
    assert_eq!(x.graphics.len(), 2);
    assert_eq!(x.graphics[0].port, None);
    assert!(x.graphics[0].autoport);
    assert_eq!(x.graphics[1].socket.as_deref(), Some("/run/libvirt/qemu/web-01.vnc"));
    assert!(!x.has_serial_console);
}

#[test]
fn detail_errors() {
    let raw = section(virt::KEY_DISPLAY, "error: failed to get domain 'x'", 1)
        + &section(virt::KEY_XML, "error: failed to get domain 'x'", 1);
    assert!(matches!(
        virt::parse_domain_detail(&raw),
        Err(VirtError::DomainNotFound { .. })
    ));
    let raw = section(virt::KEY_DISPLAY, "", 0) + &section(virt::KEY_XML, "<domain><name>", 0);
    assert!(matches!(
        virt::parse_domain_detail(&raw),
        Err(VirtError::Malformed { .. })
    ));
}

#[test]
fn actions() {
    let ok = section(
        virt::KEY_ACTION,
        "Domain '3b1f0c4e-9a57-4d4e-8f0e-2d6c1a9b7e10' started",
        0,
    );
    assert_eq!(virt::parse_action(&ok), Ok(()));
    for (file, kind) in [
        ("error_already_running.txt", "invalid_state"),
        ("error_already_active.txt", "invalid_state"),
        ("error_not_running.txt", "invalid_state"),
        ("error_not_found.txt", "domain_not_found"),
        ("error_apparmor_start.txt", "command"),
    ] {
        let err = virt::parse_action(&section(virt::KEY_ACTION, &fixture(file), 1)).unwrap_err();
        assert_eq!(serde_json::to_value(&err).unwrap()["kind"], kind, "{file}: {err:?}");
        assert!(!err.message().lines().any(|l| l.starts_with("error:")), "{file}");
    }
    assert!(matches!(
        virt::parse_action(&section(virt::KEY_ACTION, &fixture("error_permission.txt"), 1)),
        Err(VirtError::PermissionDenied { .. })
    ));

    for (action, cmd) in [
        (VirtAction::Start, "start"),
        (VirtAction::Shutdown, "shutdown"),
        (VirtAction::Reboot, "reboot"),
        (VirtAction::ForceStop, "destroy"),
        (VirtAction::Suspend, "suspend"),
        (VirtAction::Resume, "resume"),
    ] {
        let s = virt::action_script(action, "3b1f0c4e-9a57-4d4e-8f0e-2d6c1a9b7e10");
        assert!(
            s.contains(&format!("V {cmd} --domain '3b1f0c4e-9a57-4d4e-8f0e-2d6c1a9b7e10'\n")),
            "{s}"
        );
    }
}

#[test]
fn error_json_shape() {
    let e = VirtError::PermissionDenied {
        message: "m".into(),
    };
    assert_eq!(
        serde_json::to_value(&e).unwrap(),
        serde_json::json!({"kind": "permission_denied", "message": "m"})
    );
    assert_eq!(
        serde_json::to_value(VirtError::NotInstalled).unwrap(),
        serde_json::json!({"kind": "not_installed"})
    );
}

// ---------------------------------------------------------------------------
// The scripts under a real sh, against a stub virsh
// ---------------------------------------------------------------------------

/// A directory holding a `virsh` that answers from the fixtures, logs its
/// argv (one argument per line) and whatever it finds on stdin.
fn stub_dir(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_stub_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let f = dir();
    let f = f.display();
    let stub = format!(
        r#"#!/bin/sh
log="$(dirname "$0")/log"
for a in "$@"; do printf '%s\n' "$a" >> "$log"; done
echo --- >> "$log"
cat >> "$(dirname "$0")/stdin"
[ "$1 $2 $3" = "--connect qemu:///system -q" ] || {{ echo "error: bad prefix" >&2; exit 9; }}
shift 3
case "$*" in
  version) cat '{f}/version_libvirt11.txt' ;;
  "list --all --uuid --name") cat '{f}/list_uuid_name.txt' ;;
  "list --all --uuid --autostart") cat '{f}/list_autostart.txt' ;;
  "list --all --uuid --persistent") cat '{f}/list_persistent.txt' ;;
  domstats*) cat '{f}/domstats.txt' ;;
  "domdisplay --domain "*) cat '{f}/error_display_not_running.txt' >&2; exit 1 ;;
  "dumpxml --domain "*) cat '{f}/dumpxml_odd.xml' ;;
  "start --domain "*) echo "Domain '$3' started" ;;
  *) echo "error: unexpected $*" >&2; exit 1 ;;
esac
"#
    );
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

/// Feed `script` to `sh` on stdin, as the app does, with `path` as PATH.
fn run_sh(script: &str, path: &str) -> String {
    use std::io::Write;
    let mut child = Command::new("/bin/sh")
        .env("PATH", path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    child.stdin.take().unwrap().write_all(script.as_bytes()).unwrap();
    let out = child.wait_with_output().unwrap();
    String::from_utf8(out.stdout).unwrap()
}

#[cfg(unix)]
#[test]
fn scripts_under_sh() {
    let d = stub_dir("ok");
    let path = format!("{}:/usr/bin:/bin", d.display());

    let o = virt::parse_overview(&run_sh(&virt::overview_script(), &path)).unwrap();
    let expected = virt::parse_overview(&overview_output("list_uuid_name.txt")).unwrap();
    assert_eq!(o, expected);

    // The name reaches virsh as one argument, untouched
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let detail = virt::parse_domain_detail(&run_sh(&virt::domain_detail_script(name), &path))
        .unwrap();
    assert_eq!(detail.display, None);
    assert_eq!(detail.xml.name.as_deref(), Some("it's-\"odd\""));
    assert_eq!(
        virt::parse_action(&run_sh(&virt::action_script(VirtAction::Start, name), &path)),
        Ok(())
    );
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("--domain\n{name}\n---\n")), "{log}");
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    // virsh never saw the script, which sh is reading from the same stdin
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap(), "");

    // A failing call's stderr lands in its section
    let bad = run_sh(
        &virt::action_script(VirtAction::Resume, "x"),
        &path,
    );
    assert!(matches!(virt::parse_action(&bad), Err(VirtError::Command { .. })));
    let _ = std::fs::remove_dir_all(&d);
}

#[cfg(unix)]
#[test]
fn scripts_without_virsh() {
    let empty = std::env::temp_dir().join(format!("sbm_virt_empty_{}", std::process::id()));
    std::fs::create_dir_all(&empty).unwrap();
    let raw = run_sh(&virt::overview_script(), &empty.display().to_string());
    assert_eq!(virt::parse_overview(&raw), Err(VirtError::NotInstalled));
    assert_eq!(
        virt::parse_probe(&run_sh(&virt::probe_script(), &empty.display().to_string())),
        Err(VirtError::NotInstalled)
    );
    let _ = std::fs::remove_dir_all(&empty);
}
