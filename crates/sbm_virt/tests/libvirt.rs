//! `sbm_virt::libvirt` against the fixtures in `tests/fixtures/libvirt/` (see the
//! README there: mostly captured from a libvirt 11.3.0 host, the rest
//! hand-written and labelled as such), plus the generated scripts run by a
//! real `sh` against a stub `virsh`.
//!
//! `overview.expected.json` / `detail_*.expected.json` are also what the
//! Dart FFI test compares against. Regenerate them with
//! `SBM_UPDATE_VIRT_FIXTURES=1 cargo test -p sbm_virt --test libvirt`, and
//! review the diff: they are the contract, not a snapshot to accept blindly.

use sbm_parser::script;
use sbm_virt::libvirt::{self as virt, VirtAction, VirtError, VirtState};
use sbm_virt::libvirt::snapshot as virt_snapshot;
use std::path::PathBuf;
use std::process::{Command, Stdio};

fn dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("tests/fixtures/libvirt")
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
    // A display number past `i32` once 5900 is added: no port, not a panic.
    assert_eq!(virt::parse_display("vnc://localhost:2147483647").map(|d| d.port), Some(None));
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
    // Only what PATH decides: the container and PVE checks also read fixed
    // paths (`/.dockerenv`, `/usr/sbin/pveversion`), which are the runner's.
    let probe = virt::parse_probe(&run_sh(&virt::probe_script(), &empty.display().to_string())).unwrap();
    assert_eq!(probe.libvirt, None);
    let _ = std::fs::remove_dir_all(&empty);
}

// ---------------------------------------------------------------------------
// Snapshots, storage and networks: whole script outputs, captured
// ---------------------------------------------------------------------------

#[test]
fn snapshots_tree_current_and_memory() {
    let snaps = virt::parse_snapshots(&fixture("script_snapshots_cirros_run.txt")).unwrap();
    assert_eq!(
        snaps.iter().map(|s| s.name.as_str()).collect::<Vec<_>>(),
        ["sbx-a", "sbx-b", "sbx-off"]
    );
    let a = &snaps[0];
    assert!(a.current && a.memory && !a.external);
    assert_eq!(a.parent, None);
    assert_eq!(a.description.as_deref(), Some("first one"));
    assert_eq!(a.state.as_deref(), Some("running"));
    assert_eq!(a.creation_time, Some(1790335495));
    let off = &snaps[2];
    // Taken while shut off: disks only
    assert!(!off.memory && !off.current);
    assert_eq!(off.state.as_deref(), Some("shutoff"));
    assert_eq!(off.parent.as_deref(), Some("sbx-a"));
    assert_eq!(snaps[1].parent.as_deref(), Some("sbx-off"));
    assert_expected(&snaps, "snapshots_cirros_run.expected.json");

    // No snapshots: `snapshot-current` fails, and that is "none"
    assert_eq!(virt::parse_snapshots(&fixture("script_snapshots_none.txt")), Ok(vec![]));
}

#[test]
fn snapshot_xml_without_memory_element() {
    // libvirt < 1.0.1 had no <memory>: an active domain's snapshot held it
    let x = virt::parse_snapshot_xml(
        "<domainsnapshot><name>old</name><state>running</state>\
         <creationTime>1</creationTime></domainsnapshot>",
    )
    .unwrap();
    assert!(x.memory);
    let x = virt::parse_snapshot_xml(
        "<domainsnapshot><name>ext</name><state>disk-snapshot</state>\
         <memory snapshot='no'/><disks><disk name='vda' snapshot='external'/></disks>\
         </domainsnapshot>",
    )
    .unwrap();
    assert!(!x.memory && x.external);
    assert!(virt::parse_snapshot_xml("<domainsnapshot/>").is_err());
}

#[test]
fn snapshot_actions() {
    let s = virt::snapshot_create_script("it's", "snap-1", Some("two\nlines"));
    assert!(
        s.contains("V snapshot-create-as --domain 'it'\\''s' --name 'snap-1' --description 'two\nlines'\n"),
        "{s}"
    );
    assert!(!virt::snapshot_create_script("d", "n", Some("  ")).contains("--description"));
    assert!(
        virt::snapshot_revert_script("d", "n", true)
            .contains("V snapshot-revert --domain 'd' --snapshotname 'n' --running\n")
    );
    let del = virt::snapshot_delete_script("d", "-n", &[], &[]).unwrap();
    assert!(del.contains("R snapshot-delete --domain 'd' --snapshotname '-n'\n"), "{del}");
    assert!(!del.contains("vol-delete"), "{del}");
    assert!(virt::snapshot_delete_script("d", "n", &[], &["rel/x".into()]).is_err());

    // Captured refusals: all "the host said no", with its words
    for (file, needle) in [
        ("script_snapshot_error_raw.txt", "unsupported for storage type raw"),
        ("script_snapshot_error_exists.txt", "sbx-a already exists"),
        ("script_snapshot_error_not_found.txt", "no domain snapshot with matching name"),
        ("script_snapshot_error_delete_not_found.txt", "no domain snapshot with matching name"),
    ] {
        match virt::parse_action(&fixture(file)) {
            // A name taken is told apart from the rest, with the same words.
            Err(VirtError::Command { message } | VirtError::Exists { message }) => {
                assert!(message.contains(needle), "{file}: {message}")
            }
            other => panic!("{file}: {other:?}"),
        }
    }
    assert!(matches!(
        virt::parse_action(&fixture("script_snapshot_error_exists.txt")),
        Err(VirtError::Exists { .. })
    ));
}

#[test]
fn storage_pools_volumes_and_users() {
    let st = virt::parse_storage(&fixture("script_storage.txt")).unwrap();
    let names: Vec<&str> = st.pools.iter().map(|p| p.name.as_str()).collect();
    assert_eq!(names, ["images", "sbx-iso", "sbx-off"]);
    let images = &st.pools[0];
    assert!(images.active && images.autostart);
    assert_eq!(images.pool_type.as_deref(), Some("dir"));
    assert_eq!(images.capacity, Some(20922114048));
    assert_eq!(images.target.as_deref(), Some("/var/lib/libvirt/images"));
    assert_eq!(images.volumes.as_ref().unwrap().len(), 6);
    let iso = &st.pools[1];
    assert!(iso.active && !iso.autostart);
    // A name with a space, split from its path by the header's column
    assert_eq!(
        iso.volumes.as_ref().unwrap()[0],
        virt::VirtVolumeRef {
            name: "my disk.qcow2".into(),
            path: Some("/var/lib/libvirt/sbx-iso/my disk.qcow2".into()),
        }
    );
    // Inactive: the volumes cannot be listed
    let off = &st.pools[2];
    assert!(!off.active && off.volumes.is_none());
    // Every domain's disks, shut-off ones and cdroms included
    assert_eq!(st.disks.len(), 5);
    let cdrom = st.disks.iter().find(|d| d.device == "cdrom").unwrap();
    assert_eq!(cdrom.domain, "1438b9e3-f647-47ee-8ed2-6dbc3adccd68");
    assert_eq!(cdrom.source.as_deref(), Some("/var/lib/libvirt/sbx-iso/tiny.iso"));
    assert_expected(&st, "storage.expected.json");

    let vols = virt::parse_volumes(&fixture("script_volumes_images.txt")).unwrap();
    // `gone.qcow2` was asked for and does not exist: left out
    assert_eq!(vols.len(), 6);
    let run1 = vols.iter().find(|v| v.name == "run1.qcow2").unwrap();
    assert_eq!(run1.format.as_deref(), Some("qcow2"));
    assert_eq!(run1.capacity, Some(117440512));
    assert_eq!(run1.backing.as_deref(), Some("/var/lib/libvirt/images/cirros.img"));
    let vols = virt::parse_volumes(&fixture("script_volumes_sbx_iso.txt")).unwrap();
    assert_eq!(vols[0].path.as_deref(), Some("/var/lib/libvirt/sbx-iso/my disk.qcow2"));
    assert_eq!(vols[1].format.as_deref(), Some("raw"));
    assert_expected(&vols, "volumes_sbx_iso.expected.json");
}

#[test]
fn vol_list_columns() {
    let raw = " Name                 Path\n\
               -------------------------------------------\n \
               a b  c.qcow2         /p/a b  c.qcow2\n \
               x                    /p/x\n \
               noname-path          -\n";
    let v = virt::parse_vol_list(raw);
    assert_eq!(v[0].name, "a b  c.qcow2");
    assert_eq!(v[0].path.as_deref(), Some("/p/a b  c.qcow2"));
    assert_eq!(v[1].name, "x");
    assert_eq!(v[2].path, None);
    assert!(virt::parse_vol_list("").is_empty());
}

#[test]
fn blk_and_if_lists() {
    let d = virt::parse_blklist(
        "u",
        " file   disk    vda   /var/a b.qcow2\n file   cdrom   hdc   -\n network disk sda rbd/img\n",
    );
    assert_eq!(d[0].source.as_deref(), Some("/var/a b.qcow2"));
    assert_eq!(d[1].source, None);
    assert_eq!((d[2].kind.as_str(), d[2].target.as_str()), ("network", "sda"));
    let i = virt::parse_iflist(
        "u",
        " vnet0  bridge  br 0  virtio  52:54:00:AA:00:01\n -  user  -  e1000  52:54:00:aa:00:02\n",
    );
    assert_eq!(i[0].source.as_deref(), Some("br 0"));
    assert_eq!(i[0].mac.as_deref(), Some("52:54:00:aa:00:01"));
    assert_eq!((i[1].interface.as_deref(), i[1].source.as_deref()), (None, None));
}

/// A running domain's `dumpxml` as a definition a `define` takes: what the
/// revert discards a pending change with.
/// The firmware descriptors a real host printed, as `hardware_script`
/// collects them alongside a domain's hardware.
#[test]
fn firmware_descriptors_of_a_real_host() {
    let raw = fixture("script_hardware.txt");
    let info = virt::parse_hardware(&raw).unwrap();
    // The test host's three descriptors, as captured: the one with the
    // vendor's keys is what Secure Boot is offered on.
    assert_eq!(info.firmware.len(), 3, "{:?}", info.firmware);
    let names: Vec<&str> = info.firmware.iter().map(|f| f.name.as_str()).collect();
    assert!(names.iter().any(|n| n.contains("secure-enrolled")), "{names:?}");
    assert!(names.iter().any(|n| n.contains("secure") && !n.contains("enrolled")), "{names:?}");
    let enrolled = info
        .firmware
        .iter()
        .find(|f| f.enrolled_keys)
        .expect("one carries the keys");
    assert!(enrolled.secure_boot);
    // The domain the fixture is of, read from the same output: a running
    // BIOS domain (`cirros-run`), whose descriptors are its own host's.
    assert!(!info.config.efi);
    assert!(info.live.is_some(), "it was running");
    assert!(!info.config.nics.is_empty() || !info.config.disks.is_empty());
}

/// The firmware section `hardware_script` writes is read back by
/// `parse_hardware`: framed like every other section, so a host's
/// descriptors are not dropped as a cut-off answer.
#[cfg(unix)]
#[test]
fn hardware_script_firmware_reaches_the_parser() {
    let d = hardware_stub("fw", &base_xml());
    let fw = d.join("firmware");
    std::fs::create_dir_all(&fw).unwrap();
    std::fs::write(fw.join("50-edk2-ovmf-4m.json"), "{}").unwrap();
    std::fs::write(fw.join("30-edk2-ovmf-4m-secure-enrolled.json"), r#"{"features": ["secure-boot", "enrolled-keys"]}"#)
        .unwrap();
    let script = virt::hardware_script("vm").replace(virt::QEMU_FIRMWARE_DIR, &fw.display().to_string());
    let path = format!("{}:/usr/bin:/bin", d.display());
    let info = virt::parse_hardware(&run_sh(&script, &path)).unwrap();
    let mut names: Vec<_> = info.firmware.iter().map(|f| (f.name.as_str(), f.enrolled_keys)).collect();
    names.sort();
    assert_eq!(
        names,
        [("30-edk2-ovmf-4m-secure-enrolled.json", true), ("50-edk2-ovmf-4m.json", false)]
    );
    // No descriptor at all is an empty list, not a failure.
    std::fs::remove_dir_all(&fw).unwrap();
    assert!(virt::parse_hardware(&run_sh(&script, &path)).unwrap().firmware.is_empty());
    let _ = std::fs::remove_dir_all(&d);
}

/// A definition rewritten from what the hardware read keeps the console's
/// password: read with `--security-info`, guarded in the same form, and
/// written back with it. What a view shows of it has none.
#[cfg(unix)]
#[test]
fn a_rewritten_definition_keeps_the_console_password() {
    use virt::VirtHwChange as C;
    let secret = base_xml().replacen(
        "<graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>",
        "<graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1' passwd='s3cr&apos;t'>",
        1,
    );
    assert!(secret.contains("passwd="));
    let d = hardware_stub("secret", &secret);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let info = virt::parse_hardware(&run_sh(&virt::hardware_script("vm"), &path)).unwrap();
    assert!(info.config_xml.contains("passwd='s3cr&apos;t'"), "{}", info.config_xml);
    assert!(!info.config_text.contains("passwd") && !info.config_text.contains("s3cr"), "{}", info.config_text);
    assert_eq!(info.config_text, virt::without_secrets(&secret));
    assert!(info.config_text.contains("<graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>"));
    // Nor printed as `{:?}` in a log line or a failed assertion.
    let debug = format!("{info:?}");
    assert!(!debug.contains("s3cr") && !debug.contains("passwd"), "{debug}");
    for change in [
        C::Cpu { sockets: 1, cores: 2, current: None },
        C::Boot { order: vec!["vda".into()] },
    ] {
        let _ = std::fs::remove_file(d.join("given_define.xml"));
        let script = virt::hardware_change_script("vm", false, Some(&info.config_xml), &change).unwrap();
        let out = run_sh(&script, &path);
        assert_eq!(virt::parse_hardware_change(&out), Ok(Default::default()), "{change:?}");
        let given = std::fs::read_to_string(d.join("given_define.xml")).unwrap();
        assert!(given.contains("passwd='s3cr&apos;t'"), "{change:?}: {given}");
        // Neither the secret nor the definition is in what the script printed.
        assert!(!out.contains("s3cr"), "{out}");
    }
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn live_xml_as_a_definition() {
    let live = fixture("dumpxml_revert_live.xml");
    let expected = fixture("dumpxml_revert_definition.xml");
    // The definition the host kept is what the expected output is (it was
    // defined on that host and accepted): made from it, the running XML
    // comes back as exactly that.
    let made = virt::definition_of_live_xml(&live, &expected).unwrap();
    assert_eq!(made.trim_end(), expected.trim_end());
    // Every time, not just once: the edit is a function of the two.
    assert_eq!(virt::definition_of_live_xml(&live, &expected).unwrap(), made);
    // Readable as a domain, and what it is:
    let hw = virt::parse_hw_xml(&made, &[]).unwrap();
    assert!(hw.disks.iter().any(|d| d.target == "vda"));
    let doc = roxmltree::Document::parse(&made).unwrap();
    let root = doc.root_element();
    assert_eq!(root.attribute("id"), None, "the running domain's number goes");
    assert_eq!(root.attribute("type"), Some("kvm"));
    for name in ["alias", "seclabel", "resource", "backingStore"] {
        assert!(
            root.descendants().all(|n| !n.has_tag_name(name)),
            "{name} is still there"
        );
    }
    assert!(
        root.descendants()
            .filter(|n| n.has_tag_name("source"))
            .all(|n| n.attribute("index").is_none())
    );

    // What the definition has that the running XML says otherwise: its own
    // <nvram> path, a host-model CPU (printed running as `custom` with the
    // host's model and features), a CPU feature of the user's, a domain
    // seclabel opted out, a disk's `relabel='no'` and a user alias.
    let definition = expected
        .replace(
            "/var/lib/libvirt/qemu/nvram/sbxe2e-dom_VARS.fd",
            "/var/lib/libvirt/qemu/nvram/other_VARS.fd",
        )
        .replacen(
            "</devices>",
            "</devices>\n  <seclabel type='none'/>",
            1,
        );
    let def_cpu_start = definition.find("<cpu").unwrap();
    let def_cpu_end = definition.find("</cpu>").map(|i| i + "</cpu>".len()).unwrap_or_else(|| {
        definition[def_cpu_start..].find("/>").unwrap() + def_cpu_start + 2
    });
    let definition = format!(
        "{}<cpu mode='host-model' check='partial'>\n    <feature policy='disable' name='vmx'/>\n  </cpu>{}",
        &definition[..def_cpu_start],
        &definition[def_cpu_end..]
    );
    let live = live.replacen(
        "<source file=",
        "<seclabel model='dac' relabel='no'/>\n      <source file=",
        1,
    );
    let live = live.replacen("<alias name='virtio-disk0'/>", "<alias name='ua-boot'/>", 1);
    let live = live.replacen(
        "</cpu>",
        "  <topology sockets='1' dies='1' clusters='1' cores='2' threads='1'/>\n  </cpu>",
        1,
    );
    let made = virt::definition_of_live_xml(&live, &definition).unwrap();
    let doc = roxmltree::Document::parse(&made).unwrap();
    let root = doc.root_element();
    let cpu = root.children().find(|n| n.has_tag_name("cpu")).unwrap();
    assert_eq!(cpu.attribute("mode"), Some("host-model"), "{made}");
    assert_eq!(cpu.attribute("check"), Some("partial"), "{made}");
    assert!(made.contains("<feature policy='disable' name='vmx'/>"), "{made}");
    // The running topology: what a pending change moves.
    let topo = cpu.children().find(|n| n.has_tag_name("topology")).unwrap();
    assert_eq!(topo.attribute("cores"), Some("2"), "{made}");
    assert!(made.contains("/var/lib/libvirt/qemu/nvram/other_VARS.fd"), "{made}");
    assert!(root.children().any(|n| n.has_tag_name("seclabel") && n.attribute("type") == Some("none")), "{made}");
    assert!(made.contains("<seclabel model='dac' relabel='no'/>"), "{made}");
    assert!(made.contains("<alias name='ua-boot'/>"), "{made}");
    assert!(!made.contains("libvirt-"), "the running label goes: {made}");

    // A namespace the domain declares is kept.
    let ns = live.replacen("<domain type='kvm'", "<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'", 1);
    let made = virt::definition_of_live_xml(&ns, &expected).unwrap();
    assert!(made.contains("xmlns:qemu="), "{made}");
    assert!(!made.contains("<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0' id="), "{made}");
    assert_eq!(roxmltree::Document::parse(&made).unwrap().root_element().attribute("id"), None);

    // A definition without an NVRAM element: the live one goes, and nothing
    // is put in its place.
    let bios = live.replace(" firmware='efi'", "").replace(
        "    <nvram template='/usr/share/OVMF/OVMF_VARS_4M.ms.fd' templateFormat='raw' format='raw'>/var/lib/libvirt/qemu/nvram/sbxe2e-dom_VARS.fd</nvram>\n",
        "",
    );
    let bios_def = expected.replace(
        "    <nvram template='/usr/share/OVMF/OVMF_VARS_4M.ms.fd' templateFormat='raw' format='raw'>/var/lib/libvirt/qemu/nvram/sbxe2e-dom_VARS.fd</nvram>\n",
        "",
    );
    let made = virt::definition_of_live_xml(&bios, &bios_def).unwrap();
    assert!(!made.contains("<nvram"), "{made}");
    assert!(!made.contains("resource"), "{made}");
    // Not a domain at all.
    assert!(virt::definition_of_live_xml("not xml", "<domain/>").is_err());
    // An empty one is readable and comes out empty: nothing to write.
    assert_eq!(virt::definition_of_live_xml("<domain/>", "<domain/>").unwrap(), "<domain/>\n");
    // A populated `<backingStore>` whose sources carry an `index` as well:
    // the whole chain goes, and nothing around it.
    let chained = live.replacen(
        "      <backingStore/>\n",
        "      <backingStore type='file' index='2'>\n        <format type='qcow2'/>\n        \
         <source file='/var/lib/libvirt/images/base.qcow2' index='2'/>\n        \
         <backingStore type='file' index='3'>\n          <format type='raw'/>\n          \
         <source file='/var/lib/libvirt/images/root.raw' index='3'/>\n          \
         <backingStore/>\n        </backingStore>\n      </backingStore>\n",
        1,
    );
    assert_ne!(chained, live);
    let made = virt::definition_of_live_xml(&chained, &expected).unwrap();
    assert_eq!(made, virt::definition_of_live_xml(&live, &expected).unwrap());
}

/// Discarding the pending changes stops where the running XML is not the
/// running domain's any more: stopped and started since, it runs the
/// definition, and writing the old running XML back would reverse it.
#[test]
fn a_revert_checks_the_running_domain_is_the_one_read() {
    let live = fixture("dumpxml_revert_live.xml");
    let definition = fixture("dumpxml_revert_definition.xml");
    let change = serde_json::json!({"op": "revert_live", "live_xml": live});
    let change: virt::VirtHwChange = serde_json::from_value(change).unwrap();
    let s = virt::hardware_change_script("dom", true, Some(&definition), &change).unwrap();
    let id = roxmltree::Document::parse(&live).unwrap().root_element().attribute("id").unwrap().to_string();
    assert!(s.contains("domid --domain 'dom'"), "{s}");
    assert!(s.contains(&format!("if [ \"$id\" != '{id}' ]")), "{s}");
    // The id is checked before anything is defined.
    assert!(s.find("domid").unwrap() < s.find("define").unwrap(), "{s}");
    // Not running: nothing to revert to.
    assert!(virt::hardware_change_script("dom", false, Some(&definition), &change).is_err());
}

/// A definition-only edit writes the saved definition, so what the listing
/// reports is the definition — not the running network, which is still on
/// the old one until it is restarted.
#[test]
fn a_saved_definition_is_what_the_listing_reports() {
    let m = sbm_parser::script::cmd_marker;
    let net_xml = |address: &str, range: &str| {
        format!(
            "<network>\n  <name>lab</name>\n  <forward mode='nat'/>\n  \
             <ip address='{address}' prefix='24'>\n    <dhcp>\n      \
             <range start='{range}.100' end='{range}.200'/>\n    </dhcp>\n  </ip>\n</network>\n"
        )
    };
    // What `networks_script` prints: the running XML, then the definition as
    // saved. The definition has 151, the running one still 150.
    let running = net_xml("192.168.150.1", "192.168.150");
    let saved = net_xml("192.168.151.1", "192.168.151");
    let raw = format!(
        "{nets}\nlab\n{rc}0\n{active}\nlab\n{rc}0\n{auto}\nlab\n{rc}0\n\
         {xml}\nlab\n{running}{rc}0\n{cfg}\nlab\n{saved}{rc}0\n",
        nets = m(virt::KEY_NETS),
        active = m(virt::KEY_NETS_ACTIVE),
        auto = m(virt::KEY_NETS_AUTOSTART),
        xml = m(virt::KEY_NET_XML),
        cfg = m(virt::KEY_NET_CONFIG),
        rc = virt::RC_PREFIX,
    );
    let nets = virt::parse_networks(&raw).unwrap();
    let lab = nets.networks.iter().find(|n| n.name == "lab").unwrap();
    // The definition is what is shown; the running network differs.
    assert_eq!(lab.ips[0].cidr, "192.168.151.1/24");
    assert_eq!(lab.ips[0].dhcp_ranges, ["192.168.151.100-192.168.151.200"]);
    assert!(lab.pending_restart, "{lab:?}");
    assert_eq!(lab.xml, saved.trim_end());

    // The same definition either side: nothing waits, and the running
    // network's own text is not what an edit is made from.
    let same = format!(
        "{nets}\nlab\n{rc}0\n{active}\nlab\n{rc}0\n{auto}\nlab\n{rc}0\n\
         {xml}\nlab\n{running}{rc}0\n{cfg}\nlab\n{running}{rc}0\n",
        nets = m(virt::KEY_NETS),
        active = m(virt::KEY_NETS_ACTIVE),
        auto = m(virt::KEY_NETS_AUTOSTART),
        xml = m(virt::KEY_NET_XML),
        cfg = m(virt::KEY_NET_CONFIG),
        rc = virt::RC_PREFIX,
    );
    let nets = virt::parse_networks(&same).unwrap();
    let lab = nets.networks.iter().find(|n| n.name == "lab").unwrap();
    assert_eq!(lab.ips[0].cidr, "192.168.150.1/24");
    assert!(!lab.pending_restart, "{lab:?}");
}

#[test]
fn networks_modes_ips_leases() {
    let n = virt::parse_networks(&fixture("script_networks.txt")).unwrap();
    let by = |name: &str| n.networks.iter().find(|x| x.name == name).unwrap();
    let def = by("default");
    assert!(def.active && def.autostart);
    assert_eq!((def.mode.as_str(), def.bridge.as_deref()), ("nat", Some("virbr0")));
    assert_eq!(def.ips[0].cidr, "192.168.122.1/24");
    assert_eq!(def.ips[0].dhcp_ranges, ["192.168.122.2-192.168.122.254"]);
    assert_eq!(def.connections, Some(3));
    let iso = by("sbx-isolated");
    assert_eq!(iso.mode, "isolated");
    assert_eq!(iso.ips.len(), 2);
    assert_eq!((iso.ips[1].family.as_str(), iso.ips[1].cidr.as_str()), ("ipv6", "fd00:99::1/64"));
    let br = by("sbx-bridge");
    assert!(!br.active);
    assert_eq!((br.mode.as_str(), br.bridge.as_deref()), ("bridge", Some("br-sbx")));
    // Inactive domains list their interfaces too, without a host device
    let odd: Vec<_> = n
        .ifaces
        .iter()
        .filter(|i| i.domain == "1438b9e3-f647-47ee-8ed2-6dbc3adccd68")
        .collect();
    assert_eq!(odd.len(), 2);
    assert!(odd.iter().all(|i| i.interface.is_none()));
    assert_eq!(odd[1].source.as_deref(), Some("sbx-isolated"));
    assert_eq!(n.leases.len(), 2);
    assert_eq!(n.leases[0].ip, "192.168.122.202/24");
    assert_expected(&n, "networks.expected.json");
}

#[test]
fn resource_scripts_errors() {
    let raw = format!("{}\n", script::cmd_marker(virt::KEY_MISSING));
    assert_eq!(virt::parse_storage(&raw), Err(VirtError::NotInstalled));
    assert_eq!(virt::parse_networks(&raw), Err(VirtError::NotInstalled));
    assert_eq!(virt::parse_snapshots(&raw), Err(VirtError::NotInstalled));
    assert_eq!(virt::parse_volumes(&raw), Err(VirtError::NotInstalled));
    let polkit = section(virt::KEY_POOLS, &fixture("error_polkit.txt"), 1);
    assert!(matches!(virt::parse_storage(&polkit), Err(VirtError::PermissionDenied { .. })));
    let polkit = section(virt::KEY_SNAP_LIST, &fixture("error_polkit.txt"), 1);
    assert!(matches!(virt::parse_snapshots(&polkit), Err(VirtError::PermissionDenied { .. })));
    assert!(matches!(
        virt::parse_volumes("sudo: a password is required"),
        Err(VirtError::Malformed { .. })
    ));
    // Nothing asked, nothing answered
    assert_eq!(virt::parse_volumes(""), Ok(vec![]));
}

/// A `virsh` for the resource scripts: lists with hostile names, and every
/// per-item call logged so the test can see the names arrive intact.
#[cfg(unix)]
fn resource_stub(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_res_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = r#"#!/bin/sh
log="$(dirname "$0")/log"
for a in "$@"; do printf '%s\n' "$a" >> "$log"; done
echo --- >> "$log"
cat >> "$(dirname "$0")/stdin"
[ "$1 $2" = "--connect qemu:///system" ] || exit 9
shift 2
[ "$1" = "-q" ] && shift
evil='it'"'"'s "odd" $(touch pwned) `touch pwned`'
case "$1" in
  pool-list|net-list|snapshot-list) printf '%s\n%s\n' plain "$evil" ;;
  list) echo 11111111-2222-4333-8444-555555555555 ;;
  pool-dumpxml) echo "<pool type='dir'><name>x</name></pool>" ;;
  vol-list) printf ' Name   Path\n----------\n v      /v\n' ;;
  net-dumpxml) echo "<network><name>x</name></network>" ;;
  snapshot-dumpxml) printf "<domainsnapshot><name>%s</name></domainsnapshot>\n" "$5" ;;
  snapshot-current) printf plain ;;
  *) : ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

#[cfg(unix)]
#[test]
fn resource_scripts_under_sh() {
    let d = resource_stub("ok");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let evil = "it's \"odd\" $(touch pwned) `touch pwned`";

    let st = virt::parse_storage(&run_sh(&virt::storage_script(), &path)).unwrap();
    assert_eq!(st.pools.len(), 2);
    assert_eq!(st.pools[1].name, evil);
    assert_eq!(st.pools[1].volumes.as_ref().unwrap()[0].name, "v");
    let n = virt::parse_networks(&run_sh(&virt::networks_script(), &path)).unwrap();
    assert_eq!(n.networks[1].name, evil);
    let s = virt::parse_snapshots(&run_sh(&virt::snapshots_script(evil), &path)).unwrap();
    assert_eq!(s.iter().map(|s| s.name.as_str()).collect::<Vec<_>>(), ["plain", evil]);
    assert!(s[0].current);
    let v = run_sh(&virt::volumes_script(evil, &[evil.to_string()]), &path);
    assert_eq!(virt::parse_volumes(&v), Ok(vec![]));

    let log = std::fs::read_to_string(d.join("log")).unwrap();
    // Each loop hands the name over as one argument, untouched
    assert!(log.contains(&format!("pool-dumpxml\n--pool\n{evil}\n---\n")), "{log}");
    assert!(log.contains(&format!("vol-list\n--pool\n{evil}\n---\n")), "{log}");
    assert!(log.contains(&format!("net-dumpxml\n--network\n{evil}\n---\n")), "{log}");
    assert!(log.contains(&format!("--domain\n{evil}\n--snapshotname\n{evil}\n---\n")), "{log}");
    assert!(log.contains(&format!("vol-dumpxml\n--pool\n{evil}\n--vol\n{evil}\n---\n")), "{log}");
    assert!(log.contains("domblklist\n--details\n--domain\n11111111-2222-4333-8444-555555555555\n"));
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap(), "");
    let _ = std::fs::remove_dir_all(&d);
}

#[cfg(unix)]
#[test]
fn probe_finds_pve_and_containers() {
    let d = std::env::temp_dir().join(format!("sbm_virt_probe_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = |name: &str, body: &str| {
        use std::os::unix::fs::PermissionsExt;
        let p = d.join(name);
        std::fs::write(&p, format!("#!/bin/sh\n{body}\n")).unwrap();
        std::fs::set_permissions(&p, std::fs::Permissions::from_mode(0o755)).unwrap();
    };
    let path = format!("{}:/usr/bin:/bin", d.display());

    // Alpine in a PVE container: no systemd, `openrc --sys` says LXC. A
    // hypervisor name before it is not a container.
    stub("systemd-detect-virt", "echo none; exit 1");
    stub("openrc", "echo LXC");
    let p = virt::parse_probe(&run_sh(&virt::probe_script(), &path)).unwrap();
    assert_eq!(p.container.as_deref(), Some("lxc"));
    assert_eq!((p.pve, p.libvirt), (None, None));

    // PVE: its line, and nothing else asked (the virsh stub is not run)
    stub(
        "pveversion",
        "echo 'pve-manager/9.2.2/b9984c6d90a4bd80 (running kernel: 7.0.2-6-pve)'",
    );
    stub("virsh", "touch \"$0.ran\"; echo 'Using library: libvirt 11.3.0'");
    let p = virt::parse_probe(&run_sh(&virt::probe_script(), &path)).unwrap();
    assert_eq!(
        p.pve.as_deref(),
        Some("pve-manager/9.2.2/b9984c6d90a4bd80 (running kernel: 7.0.2-6-pve)")
    );
    assert_eq!((p.container, p.libvirt), (None, None));
    assert!(!d.join("virsh.ran").exists());
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// Creating and deleting domains
// ---------------------------------------------------------------------------

fn create_spec(name: &str) -> virt::VirtCreateSpec {
    virt::VirtCreateSpec {
        name: name.to_string(),
        vcpus: 2,
        memory_mib: 1024,
        host: virt::parse_create_host(&fixture("script_create_host.txt")).unwrap(),
        disk_pool: "images".to_string(),
        disk_gib: 8,
        disk_format: "qcow2".to_string(),
        disk_path: Some(format!("/var/lib/libvirt/images/{name}.qcow2")),
        cdrom: Some("/var/lib/libvirt/images/sbm-test.iso".to_string()),
        network: Some("default".to_string()),
        start: true,
        ..Default::default()
    }
}

#[test]
fn create_host_prefers_kvm_and_q35() {
    let host = virt::parse_create_host(&fixture("script_create_host.txt")).unwrap();
    assert_eq!(
        (host.domain_type.as_str(), host.machine.as_str(), host.arch.as_str(), host.max_vcpus),
        ("kvm", "pc-q35-10.0", "x86_64", Some(4096))
    );
    // Captured before the seed tool was asked for, and trimmed: none.
    assert_eq!(host.seed_tool, None);
    // The whole answer (2026-09-26, with the seed tool): what the machine
    // offers besides, from the same `domcapabilities` — UEFI with Secure
    // Boot, no IDE on q35, a TPM only by passthrough (no swtpm there).
    let full = virt::parse_create_host(&fixture("script_create_host_full.txt")).unwrap();
    assert_eq!(full.machine, "pc-q35-10.0");
    assert_eq!(full.seed_tool.as_deref(), Some("genisoimage"));
    let caps = full.caps.unwrap();
    assert!(caps.efi && caps.secure_boot && !caps.tpm_emulator, "{caps:?}");
    assert_eq!(caps.disk_buses, ["fdc", "scsi", "virtio", "usb", "sata"]);
    // A host without KVM: the first sections fail, emulation answers.
    let raw = fixture("script_create_host.txt");
    let no_kvm = raw.replacen(
        "kvm\n<domainCapabilities>",
        "kvm\nerror: unsupported configuration: KVM is not supported\n<!--",
        2,
    );
    let no_kvm = no_kvm.replacen("</domainCapabilities>\n\nSbVirtRc=0", "-->\nSbVirtRc=1", 2);
    let host = virt::parse_create_host(&no_kvm).unwrap();
    assert_eq!((host.domain_type.as_str(), host.machine.as_str()), ("qemu", "pc-q35-10.0"));
}

#[test]
fn create_volume_and_define_captured() {
    assert_eq!(
        virt::parse_create_volumes(&fixture("script_create_volume.txt")).unwrap(),
        virt::VirtCreateVolumes {
            disk_path: "/var/lib/libvirt/images/sbm-create-test.qcow2".into(),
            seed_path: None,
            copied_bytes: None,
        }
    );
    // The name was defined already: nothing ran.
    assert_eq!(
        virt::parse_create_volumes(&fixture("script_create_volume_exists.txt")),
        Err(VirtError::Exists { message: String::new() })
    );
    assert_eq!(
        virt::parse_create(&fixture("script_define_ok.txt")).unwrap(),
        virt::VirtCreated {
            uuid: Some("be27edda-481c-401d-88df-57e7b8756364".into()),
            start_error: None,
        }
    );
    // Refused by the host, and the volume taken back (its section is ok).
    match virt::parse_create(&fixture("script_define_rollback.txt")) {
        Err(VirtError::Command { message }) => {
            assert!(message.contains("No PCI buses available"), "{message}");
        }
        other => panic!("{other:?}"),
    }
    assert_eq!(virt::parse_action(&fixture("script_undefine.txt")), Ok(()));
    assert_eq!(virt::parse_undefine(&fixture("script_undefine.txt")), Ok(()));
}

#[test]
fn create_start_failure_and_leftover_volume() {
    let m = script::cmd_marker;
    let ok = |key: &str, body: &str| format!("{}\n{body}\n{}0\n", m(key), virt::RC_PREFIX);
    let fail = |key: &str, body: &str| format!("{}\n{body}\n{}1\n", m(key), virt::RC_PREFIX);
    // Defined, then refused to start: created all the same, with why.
    let raw = [
        ok(virt::KEY_DEFINE, ""),
        ok(virt::KEY_UUID, "be27edda-481c-401d-88df-57e7b8756364"),
        fail(virt::KEY_START, "error: Failed to start domain 'x'\nerror: Permission denied"),
    ]
    .concat();
    let created = virt::parse_create(&raw).unwrap();
    assert_eq!(
        created.start_error.as_deref(),
        Some("Failed to start domain 'x'\nPermission denied")
    );
    // Define refused and the volume could not be removed: both said.
    let raw = [
        fail(virt::KEY_DEFINE, "error: XML error: bad"),
        fail(virt::KEY_ROLLBACK, "error: Failed to delete vol x.qcow2"),
    ]
    .concat();
    match virt::parse_create(&raw) {
        Err(VirtError::Command { message }) => {
            assert_eq!(message, "XML error: bad\nFailed to delete vol x.qcow2");
        }
        other => panic!("{other:?}"),
    }
    // Refused as this user: kept as such, so the caller retries with sudo.
    let raw = [
        fail(virt::KEY_DEFINE, "error: Permission denied"),
        fail(virt::KEY_ROLLBACK, "error: Permission denied"),
    ]
    .concat();
    assert!(matches!(
        virt::parse_create(&raw),
        Err(VirtError::PermissionDenied { .. })
    ));
}

#[test]
fn domain_xml_escapes_and_reads_back() {
    let spec = create_spec("it's \"odd\" <b>&amp;");
    let xml = virt::domain_xml(&spec);
    let back = virt::parse_domain_xml(&xml).unwrap();
    assert_eq!(back.name.as_deref(), Some(spec.name.as_str()));
    assert_eq!(back.machine.as_deref(), Some("pc-q35-10.0"));
    assert!(back.has_serial_console);
    assert_eq!(back.disks.len(), 2);
    assert_eq!(back.disks[0].source, spec.disk_path);
    assert_eq!(back.disks[0].target.as_deref(), Some("vda"));
    assert_eq!(back.disks[1].device, "cdrom");
    assert!(back.disks[1].readonly);
    assert_eq!(back.disks[1].bus.as_deref(), Some("sata"));
    assert_eq!(back.nics[0].source.as_deref(), Some("default"));
    assert_eq!(back.graphics[0].listen.as_deref(), Some("127.0.0.1"));

    // `pc` has no SATA; no media, no NIC.
    let mut spec = create_spec("plain");
    spec.host.machine = "pc-i440fx-10.0".into();
    spec.network = None;
    let back = virt::parse_domain_xml(&virt::domain_xml(&spec)).unwrap();
    assert_eq!(back.disks[1].bus.as_deref(), Some("ide"));
    assert!(back.nics.is_empty());
    spec.cdrom = None;
    assert_eq!(virt::parse_domain_xml(&virt::domain_xml(&spec)).unwrap().disks.len(), 1);
}

#[test]
fn create_specs_refused_before_running() {
    let bad = |f: &dyn Fn(&mut virt::VirtCreateSpec)| {
        let mut spec = create_spec("vm");
        f(&mut spec);
        assert!(
            matches!(virt::create_volume_script(&spec), Err(VirtError::Malformed { .. })),
            "{spec:?}"
        );
    };
    bad(&|s| s.name = String::new());
    bad(&|s| s.name = "a/b".into());
    bad(&|s| s.name = "a\nb".into());
    bad(&|s| s.name = "-rf".into());
    bad(&|s| s.name = ".hidden".into());
    bad(&|s| s.vcpus = 0);
    bad(&|s| s.disk_gib = 0);
    bad(&|s| s.disk_format = "vmdk".into());
    bad(&|s| s.host.domain_type = "xen".into());
    bad(&|s| s.host.machine = "q35'; rm".into());
    bad(&|s| s.disk_path = Some("relative.qcow2".into()));
    let mut spec = create_spec("vm");
    spec.disk_path = None;
    assert!(virt::create_volume_script(&spec).is_ok());
    assert!(matches!(virt::define_script(&spec), Err(VirtError::Malformed { .. })));

    assert!(virt::undefine_script("vm", &["vda,sda".into()], None, &[], &[]).is_err());
    assert!(virt::undefine_script("vm", &["".into()], None, &[], &[]).is_err());
    assert!(virt::undefine_script("vm", &[], Some("seed.iso"), &[], &[]).is_err());
    assert!(virt::undefine_script("vm", &[], None, &[], &["rel.qcow2".into()]).is_err());
    let keep = virt::undefine_script("vm", &[], None, &[], &[]).unwrap();
    assert!(keep.contains("--keep-nvram") && !keep.contains("--storage"), "{keep}");
    assert!(!keep.contains("vol-delete"), "{keep}");
    let all = virt::undefine_script("vm", &["vda".into(), "vdb".into()], None, &[], &[]).unwrap();
    assert!(all.contains("--nvram --storage vda,vdb"), "{all}");
}

/// A fake virsh for the create scripts: logs its arguments one per line,
/// keeps what `define --file` was given, and knows a domain once defined.
#[cfg(unix)]
fn create_stub(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_create_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
cat >> "$dir/stdin"
shift 3
case "$1" in
  domuuid) [ -f "$dir/defined.xml" ] || { echo "error: failed to get domain" >&2; exit 1; }
           echo be27edda-481c-401d-88df-57e7b8756364 ;;
  vol-create-as) ;;
  vol-path) echo "/pool/$5" ;;
  define) cp "$3" "$dir/defined.xml" ;;
  start|vol-delete|undefine) ;;
  *) echo "error: unexpected $*" >&2; exit 1 ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

#[cfg(unix)]
#[test]
fn create_scripts_under_sh_with_a_hostile_name() {
    let d = create_stub("hostile");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let mut spec = create_spec(name);
    spec.disk_path = None;

    let vol = virt::parse_create_volumes(&run_sh(&virt::create_volume_script(&spec).unwrap(), &path))
        .unwrap()
        .disk_path;
    assert_eq!(vol, format!("/pool/{name}.qcow2"));
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("--name\n{name}.qcow2\n--capacity\n8G\n")), "{log}");

    spec.disk_path = Some(vol);
    let created = virt::parse_create(&run_sh(&virt::define_script(&spec).unwrap(), &path)).unwrap();
    assert_eq!(created.uuid.as_deref(), Some("be27edda-481c-401d-88df-57e7b8756364"));
    assert_eq!(created.start_error, None);
    // The file virsh was given is the XML, byte for byte.
    assert_eq!(
        std::fs::read_to_string(d.join("defined.xml")).unwrap(),
        virt::domain_xml(&spec)
    );
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("start\n--domain\n{name}\n")), "{log}");
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap(), "");

    // Defined already: stops before creating anything.
    std::fs::remove_file(d.join("log")).unwrap();
    assert_eq!(
        virt::parse_create_volumes(&run_sh(&virt::create_volume_script(&spec).unwrap(), &path)),
        Err(VirtError::Exists { message: String::new() })
    );
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(!log.contains("vol-create-as"), "{log}");

    let undefine = virt::undefine_script(name, &["vda".into()], None, &[], &[]).unwrap();
    assert_eq!(virt::parse_undefine(&run_sh(&undefine, &path)), Ok(()));
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("undefine\n--domain\n{name}\n--managed-save\n")), "{log}");
    let _ = std::fs::remove_dir_all(&d);
}

/// The pools are refreshed before the undefine (so `--storage` knows the
/// file a disk is on), the files under the disks go after it; one the host
/// refuses is reported, and a refused undefine deletes none of them.
#[cfg(unix)]
#[test]
fn undefine_deletes_the_chain_files_after_the_domain() {
    let d = create_stub("chain");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let pools = ["p o".to_string()];
    let chain = ["/p o/a b.qcow2".to_string(), "/p o/base.qcow2".to_string()];
    let script = virt::undefine_script("vm", &["vda".into()], None, &pools, &chain).unwrap();
    // pool-refresh is not in the stub: it fails, which is not reported.
    assert_eq!(virt::parse_undefine(&run_sh(&script, &path)), Ok(()));
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    let refresh = log.find("pool-refresh\n--pool\np o\n").unwrap();
    let undefine = log.find("undefine\n").unwrap();
    let first = log.find("vol-delete\n--vol\n/p o/a b.qcow2\n").unwrap();
    let second = log.find("vol-delete\n--vol\n/p o/base.qcow2\n").unwrap();
    assert!(refresh < undefine && undefine < first && first < second, "{log}");

    // A refused delete: the domain is gone, the file is named.
    let stub = |from: &str, to: &str| {
        let f = d.join("virsh");
        let text = std::fs::read_to_string(&f).unwrap().replace(from, to);
        std::fs::write(&f, text).unwrap();
    };
    stub("start|vol-delete|undefine)", "start|undefine)");
    let err = virt::parse_undefine(&run_sh(&script, &path)).unwrap_err();
    assert!(
        matches!(&err, VirtError::Command { message } if message.contains("2 file(s)") && message.contains("unexpected vol-delete")),
        "{err:?}"
    );

    // A refused undefine: nothing after it runs.
    std::fs::remove_file(d.join("log")).unwrap();
    stub("start|undefine)", "start)");
    assert!(virt::parse_undefine(&run_sh(&script, &path)).is_err());
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(!log.contains("vol-delete"), "{log}");
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// VNC console: display and password
// ---------------------------------------------------------------------------

/// Captured from libvirt 11.3 for a throwaway domain whose VNC password is a
/// made-up one, `fakepw12`.
#[test]
fn vnc_console_password_from_a_secure_dump() {
    let info = virt::parse_vnc_console(&fixture("script_vnc_console_password.txt")).unwrap();
    let display = info.display.clone().unwrap();
    assert_eq!(display.protocol, "vnc");
    assert_eq!(display.port, Some(5901));
    assert_eq!(info.password.as_deref(), Some("fakepw12"));
    assert!(info.password_known);
    // Debug output is what reaches a log or a failed assertion.
    assert!(!format!("{info:?}").contains("fakepw12"));
}

#[test]
fn vnc_console_without_a_password_or_refused_one() {
    // No `passwd`: known to have none.
    let open = fixture("script_vnc_console_password.txt").replace(" passwd='fakepw12'", "");
    let info = virt::parse_vnc_console(&open).unwrap();
    assert_eq!(info.password, None);
    assert!(info.password_known);

    // `--security-info` refused (the text libvirt 11.3 prints on a read-only
    // connection): the display is still there, the password unknown.
    let raw = fixture("script_vnc_console_password.txt");
    let marker = format!("{}\n", sbm_parser::script::cmd_marker(virt::KEY_SECURE_XML));
    let head = &raw[..raw.find(&marker).unwrap() + marker.len()];
    let refused = format!(
        "{head}error: operation forbidden: virDomainGetXMLDesc with secure flag\n\n{}1\n",
        virt::RC_PREFIX
    );
    let info = virt::parse_vnc_console(&refused).unwrap();
    assert_eq!(info.display.and_then(|d| d.port), Some(5901));
    assert_eq!(info.password, None);
    assert!(!info.password_known);

    // A secure dump that does not parse is an error without its text.
    let broken = raw.replace("<domain ", "<domain <");
    match virt::parse_vnc_console(&broken) {
        Err(VirtError::Malformed { message }) => {
            assert!(!message.contains("fakepw12"), "{message}");
            assert!(!message.contains("<devices"), "{message}");
        }
        other => panic!("{other:?}"),
    }
}

// ---------------------------------------------------------------------------
// Hardware: reading and editing
// ---------------------------------------------------------------------------

/// Captured from libvirt 11.3 for a throwaway domain, running with a vCPU
/// hot-plugged and the balloon moved, so the two definitions differ.
#[test]
fn hardware_running_has_both_definitions() {
    let hw = virt::parse_hardware(&fixture("script_hardware_running.txt")).unwrap();
    let config = &hw.config;
    let live = hw.live.as_ref().expect("running");
    assert_eq!((config.cpu.max, config.cpu.current), (4, 2));
    assert_eq!((live.cpu.max, live.cpu.current), (4, 3));
    // No topology: one socket per vCPU, as libvirt gives the guest.
    assert_eq!((config.cpu.sockets, config.cpu.cores, config.cpu.topology), (4, 1, false));
    assert_eq!(config.memory_kib, 512 * 1024);
    assert_eq!(config.current_memory_kib, 384 * 1024);
    assert!(config.balloon);
    let vda = &config.disks[0];
    assert_eq!((vda.target.as_str(), vda.device.as_str()), ("vda", "disk"));
    assert_eq!(vda.capacity, Some(117_440_512));
    // An empty CD-ROM: listed, with no source and no size.
    let cd = &config.disks[1];
    assert_eq!((cd.target.as_str(), cd.device.as_str(), cd.source.as_deref(), cd.capacity), ("hdc", "cdrom", None, None));
    assert!(cd.readonly);
    let nic = &config.nics[0];
    assert_eq!((nic.mac.as_str(), nic.kind.as_str(), nic.source.as_deref()), ("52:54:00:b9:34:c3", "network", Some("default")));
    assert!(nic.link_up);
    // `<os><boot dev='hd'/>` is the first disk.
    assert_eq!(config.boot, vec!["vda"]);
    assert!(!hw.autostart);
    assert_eq!((hw.host_cpus, hw.host_memory_kib), (Some(4), Some(4_016_000)));
    assert!(hw.config_xml.starts_with("<domain type='kvm'>"), "{}", &hw.config_xml[..40]);
}

#[test]
fn hardware_stopped_has_no_running_definition() {
    let hw = virt::parse_hardware(&fixture("script_hardware_stopped.txt")).unwrap();
    assert!(hw.live.is_none());
    assert_eq!(hw.config.disks[0].capacity, Some(117_440_512));
    assert_eq!(hw.description, None);

    // The persistent definition's note, as `virsh desc` wrote it: escaped
    // in the XML, read back as typed.
    let raw = fixture("script_hardware_stopped.txt").replacen(
        "<name>it&apos;s-&quot;odd&quot;</name>",
        "<name>it&apos;s-&quot;odd&quot;</name>\n  <description>web &amp; &lt;db&gt;\nsecond</description>",
        1,
    );
    assert_eq!(virt::parse_hardware(&raw).unwrap().description.as_deref(), Some("web & <db>\nsecond"));
}

fn base_xml() -> String {
    virt::parse_hardware(&fixture("script_hardware_running.txt")).unwrap().config_xml
}

fn hw_of(xml: &str) -> virt::VirtHwConfig {
    virt::parse_hw_xml(xml, &[]).unwrap()
}

#[test]
fn cpu_edits_keep_the_rest_as_written() {
    let base = base_xml();
    // One socket of four cores, two online: a topology added inside the
    // self-closing `<cpu mode='host-passthrough' …/>`, which keeps its mode.
    let xml = virt::edit_cpu_xml(&base, 1, 4, Some(2)).unwrap();
    let cpu = hw_of(&xml).cpu;
    assert_eq!((cpu.sockets, cpu.cores, cpu.threads, cpu.max, cpu.current), (1, 4, 1, 4, 2));
    assert!(xml.contains("<cpu mode='host-passthrough' check='none' migratable='on'><topology sockets='1' cores='4' threads='1'/></cpu>"), "{xml}");
    assert!(xml.contains("<vcpu placement='static' current='2'>4</vcpu>"), "{xml}");
    // Everything else is byte for byte what it was.
    let strip = |s: &str| {
        s.lines()
            .filter(|l| !l.contains("<vcpu") && !l.contains("<cpu"))
            .collect::<Vec<_>>()
            .join("\n")
    };
    assert_eq!(strip(&xml), strip(&base));

    // An existing topology is edited in place, dies and threads kept, and
    // the maximum follows it; all online drops `current`.
    let xml = virt::edit_cpu_xml(&xml.replace("threads='1'", "threads='2' dies='1'"), 2, 3, None).unwrap();
    let cpu = hw_of(&xml).cpu;
    assert_eq!((cpu.sockets, cpu.cores, cpu.threads, cpu.max, cpu.current), (2, 3, 2, 12, 12));
    assert!(xml.contains("<vcpu placement='static'>12</vcpu>"), "{xml}");

    // The default shape needs no topology: none is added.
    let xml = virt::edit_cpu_xml(&base, 6, 1, None).unwrap();
    assert!(!xml.contains("<topology"), "{xml}");
    assert_eq!(hw_of(&xml).cpu.max, 6);

    // No `<cpu>` at all: one is added after `<vcpu>`.
    let bare = base.replace("<cpu mode='host-passthrough' check='none' migratable='on'/>", "");
    let xml = virt::edit_cpu_xml(&bare, 2, 2, None).unwrap();
    assert!(xml.contains("<vcpu placement='static'>4</vcpu>\n  <cpu><topology sockets='2' cores='2' threads='1'/></cpu>"), "{xml}");

    // A per-vCPU list names every vCPU: it goes when the maximum changes.
    let listed = base.replace(
        "</vcpu>",
        "</vcpu>\n  <vcpus><vcpu id='0' enabled='yes' hotpluggable='no'/></vcpus>",
    );
    assert!(virt::edit_cpu_xml(&listed, 4, 1, Some(2)).unwrap().contains("<vcpus>"));
    assert!(!virt::edit_cpu_xml(&listed, 8, 1, None).unwrap().contains("<vcpus>"));

    // Online more than there are, or a topology past what QEMU takes.
    assert!(virt::edit_cpu_xml(&base, 1, 2, Some(3)).is_err());
    assert!(virt::edit_cpu_xml(&base, 64, 128, None).is_err());
}

#[test]
fn boot_edits_move_to_per_device_order() {
    let base = base_xml();
    let xml = virt::edit_boot_xml(&base, &["hdc".into(), "vda".into(), "52:54:00:B9:34:C3".into()]).unwrap();
    assert!(!xml.contains("<boot dev="), "{xml}");
    let hw = hw_of(&xml);
    assert_eq!(hw.boot, vec!["hdc", "vda", "52:54:00:b9:34:c3"]);
    assert_eq!(hw.disks.iter().map(|d| d.boot_order).collect::<Vec<_>>(), vec![Some(2), Some(1)]);

    // Again, from a definition that already has orders: none are left over.
    let again = virt::edit_boot_xml(&xml, &["vda".into()]).unwrap();
    assert_eq!(hw_of(&again).boot, vec!["vda"]);
    assert_eq!(again.matches("<boot ").count(), 1, "{again}");

    assert!(virt::edit_boot_xml(&base, &["vdz".into()]).is_err());
    assert!(virt::edit_boot_xml(&base, &["vda".into(), "vda".into()]).is_err());
}

/// Every change, captured from libvirt 11.3 on a throwaway running domain.
#[test]
fn hardware_changes_as_captured() {
    for name in [
        "cpu",
        "cpu_stopped",
        "memory",
        "add_disk",
        "grow_disk",
        "grow_disk_stopped",
        "remove_disk",
        "set_media",
        "add_nic",
        "update_nic",
        "update_nic_with_boot",
        "boot",
        "remove_nic",
        "autostart",
    ] {
        let out = virt::parse_hardware_change(&fixture(&format!("script_hw_{name}.txt")));
        assert_eq!(out, Ok(virt::VirtHwOutcome::default()), "{name}");
    }
    // An IDE disk: the definition takes it, the running domain cannot.
    let out = virt::parse_hardware_change(&fixture("script_hw_add_disk_ide_live_refused.txt")).unwrap();
    assert!(out.live_error.unwrap().contains("cannot be hotplugged"));
    // …and cannot let it go either: the volume is kept, not deleted.
    let out = virt::parse_hardware_change(&fixture("script_hw_remove_disk_kept.txt")).unwrap();
    assert!(out.volume_kept);
    assert!(out.live_error.unwrap().contains("cannot be hot unplugged"));

    assert!(matches!(
        virt::parse_hardware_change(&fixture("script_hw_add_disk_exists.txt")),
        Err(VirtError::Exists { .. })
    ));
    assert!(matches!(
        virt::parse_hardware_change(&fixture("script_hw_conflict.txt")),
        Err(VirtError::Conflict { .. })
    ));
    // The definition could not be read (no sudo yet): that, not a conflict.
    assert!(matches!(
        virt::parse_hardware_change(&fixture("script_hw_guard_refused.txt")),
        Err(VirtError::PermissionDenied { .. })
    ));
}

#[test]
fn hardware_changes_refuse_what_must_not_reach_a_shell() {
    use virt::VirtHwChange as C;
    let script = |c: &C| virt::hardware_change_script("vm", true, Some(&base_xml()), c);
    assert!(script(&C::GrowDisk { target: "vda; rm".into(), bytes: 1, path: None, live: true }).is_err());
    assert!(script(&C::GrowDisk { target: "vda".into(), bytes: 1, path: Some("rel".into()), live: false }).is_err());
    assert!(script(&C::AddNic {
        kind: "direct".into(),
        source: "eth0".into(),
        model: "virtio".into(),
        mac: "52:54:00:00:00:01".into(),
    })
    .is_err());
    assert!(script(&C::AddNic {
        kind: "network".into(),
        source: "default".into(),
        model: "virtio".into(),
        mac: "52:54:00:00:00".into(),
    })
    .is_err());
    assert!(script(&C::AddDisk {
        pool: "images".into(),
        volume: "../etc".into(),
        gib: 1,
        format: "qcow2".into(),
        target: "vdb".into(),
        bus: "virtio".into(),
    })
    .is_err());
    assert!(script(&C::Memory { memory_mib: 512, current_mib: Some(1024) }).is_err());
    // A topology whose product overflows is refused, not a panic.
    assert!(script(&C::Cpu { sockets: 65536, cores: 65536, current: None }).is_err());
    assert!(script(&C::Boot { order: vec![] }).is_err());
    // Rewriting the definition needs the one it is made from.
    assert!(virt::hardware_change_script("vm", false, None, &C::Cpu { sockets: 1, cores: 1, current: None }).is_err());
    // A stopped domain's disk grows by its file, and so does one only the
    // persistent definition has.
    assert!(virt::hardware_change_script(
        "vm",
        true,
        None,
        &C::GrowDisk { target: "vdb".into(), bytes: 1, path: None, live: false }
    )
    .is_err());
    assert!(virt::hardware_change_script(
        "vm",
        false,
        None,
        &C::GrowDisk { target: "vda".into(), bytes: 1, path: None, live: false }
    )
    .is_err());
}

/// A `virsh` for the change scripts: logs its arguments, keeps the files it
/// is given, prints `base.xml` for `dumpxml --inactive`, fails what the test
/// asks it to.
#[cfg(unix)]
fn hardware_stub(tag: &str, base: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_hw_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    std::fs::write(d.join("base.xml"), base).unwrap();
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
cat >> "$dir/stdin"
shift 3
[ -f "$dir/fail_$1" ] && { echo "error: $1 refused" >&2; exit 1; }
case "$1" in
  dumpxml) case " $* " in
      *" --security-info "*) cat "$dir/base.xml" ;;
      *) sed "s/ passwd='[^']*'//" "$dir/base.xml" ;;
    esac ;;
  define) cp "$3" "$dir/given_define.xml" ;;
  update-device) cp "$5" "$dir/given_update-device.xml" ;;
  vol-path) echo "/pool/$5" ;;
  domblklist) [ -f "$dir/still" ] && echo " vdb /pool/x"; exit 0 ;;
  *) ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

#[cfg(unix)]
#[test]
fn hardware_change_scripts_under_sh_with_hostile_names() {
    use virt::VirtHwChange as C;
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let base = base_xml();
    let d = hardware_stub("hostile", &base);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let log = || std::fs::read_to_string(d.join("log")).unwrap_or_default();
    let reset = || {
        let _ = std::fs::remove_file(d.join("log"));
    };
    let run = |running: bool, c: &C| {
        let script = virt::hardware_change_script(name, running, Some(&base), c).unwrap();
        virt::parse_hardware_change(&run_sh(&script, &path))
    };

    // The definition given to `define` is the edit, byte for byte, made
    // only once the one on the host is still the one it was made from.
    reset();
    assert_eq!(run(true, &C::Cpu { sockets: 1, cores: 4, current: Some(2) }), Ok(Default::default()));
    assert_eq!(
        std::fs::read_to_string(d.join("given_define.xml")).unwrap(),
        virt::edit_cpu_xml(&base, 1, 4, Some(2)).unwrap()
    );
    assert!(log().contains(&format!("dumpxml\n--inactive\n--security-info\n--domain\n{name}\n")), "{}", log());
    assert!(log().contains(&format!("setvcpus\n--domain\n{name}\n--count\n2\n--live\n")), "{}", log());
    // …and it is not, when it changed.
    std::fs::write(d.join("base.xml"), base.replace("<on_crash>destroy", "<on_crash>restart")).unwrap();
    reset();
    assert!(matches!(run(true, &C::Boot { order: vec!["vda".into()] }), Err(VirtError::Conflict { .. })));
    assert!(!log().contains("define"), "{}", log());
    std::fs::write(d.join("base.xml"), &base).unwrap();

    // A path with every quote in it reaches virsh as one argument.
    let file = format!("/pool/{name}.iso");
    reset();
    let media = C::SetMedia { target: "hdc".into(), source: Some(file.clone()), config: true, live: true };
    assert_eq!(run(true, &media), Ok(Default::default()));
    assert!(log().contains(&format!("--source\n{file}\n--update\n--config\n")), "{}", log());
    assert!(log().contains(&format!("--source\n{file}\n--update\n--live\n")), "{}", log());

    // The running domain refusing its half is not a failure of the change.
    std::fs::write(d.join("fail_change-media"), "").unwrap();
    let only_live = C::SetMedia { target: "hdc".into(), source: None, config: false, live: true };
    assert_eq!(
        run(true, &only_live).unwrap().live_error.as_deref(),
        Some("change-media refused")
    );
    std::fs::remove_file(d.join("fail_change-media")).unwrap();

    // A disk the definition refuses is deleted again; a new one is attached
    // by the path the pool gave.
    let add = C::AddDisk {
        pool: name.into(),
        volume: "vm-vdb.qcow2".into(),
        gib: 2,
        format: "qcow2".into(),
        target: "vdb".into(),
        bus: "virtio".into(),
    };
    reset();
    assert_eq!(run(true, &add), Ok(Default::default()));
    assert!(log().contains("--source\n/pool/vm-vdb.qcow2\n--target\nvdb\n"), "{}", log());
    std::fs::write(d.join("fail_attach-disk"), "").unwrap();
    reset();
    assert!(run(true, &add).is_err());
    assert!(log().contains(&format!("vol-delete\n--pool\n{name}\n--vol\nvm-vdb.qcow2\n")), "{}", log());
    std::fs::remove_file(d.join("fail_attach-disk")).unwrap();

    // An existing volume is attached by its path in both definitions, and
    // left alone when the attach is refused: it is not this change's to
    // delete.
    let attach = C::AttachVolume {
        path: file.clone(),
        format: "raw".into(),
        target: "vdc".into(),
        bus: "virtio".into(),
    };
    reset();
    assert_eq!(run(true, &attach), Ok(Default::default()));
    assert!(log().contains(&format!("attach-disk\n--domain\n{name}\n--source\n{file}\n--target\nvdc\n--targetbus\nvirtio\n--driver\nqemu\n--subdriver\nraw\n--config\n")), "{}", log());
    assert!(log().contains("--subdriver\nraw\n--live\n"), "{}", log());
    std::fs::write(d.join("fail_attach-disk"), "").unwrap();
    reset();
    assert!(run(false, &attach).is_err());
    assert!(!log().contains("vol-delete") && !log().contains("--live"), "{}", log());
    std::fs::remove_file(d.join("fail_attach-disk")).unwrap();
    assert!(virt::hardware_change_script(
        "vm",
        true,
        None,
        &C::AttachVolume { path: "rel/x".into(), format: "raw".into(), target: "vdc".into(), bus: "virtio".into() }
    )
    .is_err());

    // A disk the running guest still holds is kept.
    let remove = C::RemoveDisk { target: "vdb".into(), delete_path: Some(file.clone()), config: true, live: true };
    std::fs::write(d.join("still"), "").unwrap();
    reset();
    assert!(run(true, &remove).unwrap().volume_kept);
    assert!(!log().contains("vol-delete"), "{}", log());
    std::fs::remove_file(d.join("still")).unwrap();
    reset();
    assert!(!run(true, &remove).unwrap().volume_kept);
    assert!(log().contains(&format!("vol-delete\n--vol\n{file}\n")), "{}", log());
    // The unplug refused and the disk list unread (the connection gone): it
    // cannot be told whether QEMU still holds it, so it is kept.
    let live_only = C::RemoveDisk { target: "vdb".into(), delete_path: Some(file.clone()), config: false, live: true };
    std::fs::write(d.join("fail_detach-disk"), "").unwrap();
    std::fs::write(d.join("fail_domblklist"), "").unwrap();
    reset();
    let out = run(true, &live_only).unwrap();
    assert!(out.volume_kept && out.live_error.is_some(), "{out:?}");
    assert!(!log().contains("vol-delete"), "{}", log());
    std::fs::remove_file(d.join("fail_detach-disk")).unwrap();
    std::fs::remove_file(d.join("fail_domblklist")).unwrap();

    // An interface's source with quotes lands in the XML escaped, with the
    // link state and each definition's own boot order.
    reset();
    let update = C::UpdateNic {
        mac: "52:54:00:b9:34:c3".into(),
        kind: "network".into(),
        source: name.into(),
        model: Some("virtio".into()),
        link_up: false,
        boot_order: Some(2),
        live_boot_order: None,
        config: true,
        live: false,
    };
    assert_eq!(run(true, &update), Ok(Default::default()));
    assert_eq!(
        std::fs::read_to_string(d.join("given_update-device.xml")).unwrap(),
        "<interface type='network'><mac address='52:54:00:b9:34:c3'/>\
         <source network='it&apos;s &quot;odd&quot;; touch pwned $(id) `id`'/>\
         <model type='virtio'/><link state='down'/><boot order='2'/></interface>"
    );

    // A note with every quote and a leading dash reaches `desc` as one
    // argument, to both definitions of a running domain; a rename is one
    // step with the new name.
    let note = format!("-{name}\nsecond line");
    reset();
    assert_eq!(run(true, &C::Description { text: note.clone() }), Ok(Default::default()));
    assert!(log().contains(&format!("desc\n--domain\n{name}\n--config\n--new-desc\n-{name}\nsecond line\n")), "{}", log());
    assert!(log().contains(&format!("desc\n--domain\n{name}\n--live\n--new-desc\n")), "{}", log());
    reset();
    assert_eq!(run(false, &C::Description { text: String::new() }), Ok(Default::default()));
    assert!(!log().contains("--live"), "{}", log());
    reset();
    assert_eq!(run(false, &C::Rename { name: "web-02".into() }), Ok(Default::default()));
    assert!(log().contains(&format!("domrename\n--domain\n{name}\nweb-02\n")), "{}", log());
    // A name libvirt or AppArmor would trip over is refused before a shell.
    for bad in [name, "-x", ".hidden", "a b", ""] {
        assert!(virt::hardware_change_script(name, false, None, &C::Rename { name: bad.into() }).is_err(), "{bad}");
    }
    assert!(virt::hardware_change_script(name, false, None, &C::Description { text: "a\u{0}b".into() }).is_err());

    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap_or_default(), "");
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// Hardware, second part: disk bus and cache, NIC model and MAC, firmware,
// display, host devices. Captured from libvirt 11.3 (QEMU 10.0) on a nested
// Debian host with no IOMMU and no swtpm, on a throwaway q35 domain.
// ---------------------------------------------------------------------------

#[test]
fn hardware_caps_as_captured() {
    let hw = virt::parse_hardware(&fixture("script_hardware_caps_stopped.txt")).unwrap();
    let caps = hw.caps.unwrap();
    // q35: Secure Boot there; no swtpm on this host, so no TPM; no SPICE in
    // this QEMU build.
    assert!(caps.efi && caps.secure_boot && caps.hostdev);
    assert!(!caps.tpm_emulator);
    assert!(caps.graphics.contains(&"vnc".to_string()) && !caps.graphics.contains(&"spice".to_string()));
    assert!(caps.video.contains(&"virtio".to_string()));
    assert_eq!(caps.disk_buses, ["fdc", "scsi", "virtio", "usb", "sata"]);
    let c = hw.config;
    assert_eq!(c.machine.as_deref(), Some("pc-q35-10.0"));
    assert!(!c.efi && !c.secure_boot);
    assert_eq!(
        c.graphics,
        Some(virt::VirtHwGraphics { kind: "vnc".into(), listen: Some("127.0.0.1".into()), port: None })
    );
    assert_eq!(c.video.as_deref(), Some("virtio"));
    assert_eq!(c.disks[0].cache, None);

    // Running with Secure Boot, a cache mode changed in the definition only.
    let hw = virt::parse_hardware(&fixture("script_hardware_caps_running.txt")).unwrap();
    assert!(hw.config.efi && hw.config.secure_boot);
    assert_eq!(hw.config.disks[0].cache.as_deref(), Some("none"));
    assert_eq!(hw.live.unwrap().disks[0].cache.as_deref(), Some("writeback"));
}

#[test]
fn host_devices_as_captured() {
    let d = virt::parse_host_devices(&fixture("script_host_devices.txt")).unwrap();
    assert!(!d.iommu, "no IOMMU in a nested guest");
    assert!(d.usb.is_empty());
    assert_eq!(d.pci.len(), 13);
    let usb = d.pci.iter().find(|p| p.address == "0000:00:01.2").unwrap();
    assert_eq!((usb.vendor.as_deref(), usb.product.as_deref()), (Some("8086"), Some("7020")));
    assert_eq!(usb.iommu_group, None);
}

#[test]
fn hardware_changes_second_part_as_captured() {
    for name in [
        "update_disk_bus",
        "update_disk_cache",
        "cache_running",
        "nic_hardware",
        "firmware_secure",
        "firmware_plain",
        "firmware_bios",
        "firmware_efi",
        "firmware_secure_move",
        "display",
        "add_pci",
        "remove_pci",
    ] {
        let out = virt::parse_hardware_change(&fixture(&format!("script_hw_{name}.txt")));
        assert_eq!(out, Ok(virt::VirtHwOutcome::default()), "{name}");
    }
}

#[test]
fn disk_and_nic_edits() {
    let base = base_xml();
    // Another bus: the name on it, and no controller address left behind.
    let xml = virt::edit_disk_xml(&base, "vda", Some("sda"), Some("sata"), None).unwrap();
    let d = hw_of(&xml).disks.into_iter().find(|d| d.target == "sda").unwrap();
    assert_eq!(d.bus.as_deref(), Some("sata"));
    let disk = &xml[xml.find("<target dev='sda'").unwrap()..];
    assert!(!disk[..disk.find("</disk>").unwrap()].contains("<address"), "{xml}");
    // A cache mode, and back to the default.
    let xml = virt::edit_disk_xml(&base, "vda", None, None, Some("writeback")).unwrap();
    assert_eq!(hw_of(&xml).disks[0].cache.as_deref(), Some("writeback"));
    let xml = virt::edit_disk_xml(&xml, "vda", None, None, Some("default")).unwrap();
    assert_eq!(hw_of(&xml).disks[0].cache, None);
    assert!(virt::edit_disk_xml(&base, "vdz", None, None, Some("none")).is_err());

    let mac = hw_of(&base).nics[0].mac.clone();
    let xml = virt::edit_nic_hardware_xml(&base, &mac, Some("52:54:00:AA:BB:CC"), Some("e1000e")).unwrap();
    let nic = &hw_of(&xml).nics[0];
    assert_eq!((nic.mac.as_str(), nic.model.as_deref()), ("52:54:00:aa:bb:cc", Some("e1000e")));
}

#[test]
fn firmware_edits() {
    let base = base_xml();
    let edit = virt::edit_firmware_xml(&base, true, true).unwrap();
    let hw = hw_of(&edit.xml);
    assert!(hw.efi && hw.secure_boot);
    assert!(edit.xml.contains("<smm state='on'/>"), "{}", edit.xml);
    assert_eq!(edit.drop_vars, None, "BIOS had no variables file");
    let back = virt::edit_firmware_xml(&edit.xml, false, false).unwrap();
    let hw = hw_of(&back.xml);
    assert!(!hw.efi && !hw.secure_boot);
    assert!(!back.xml.contains("<firmware>") && !back.xml.contains("firmware='efi'"), "{}", back.xml);

    // A domain that has run has its variables file: one path, kept.
    const VARS: &str = "/var/lib/libvirt/qemu/nvram/vm_VARS.fd";
    let ran = virt::edit_firmware_xml(&base, true, false).unwrap().xml.replacen(
        "<firmware>",
        &format!("<nvram template='/t.fd'>{VARS}</nvram><firmware>"),
        1,
    );
    // Secure Boot on, and off again: the same path, its file dropped each
    // time so that libvirt makes it from the right template — no second
    // file left behind.
    let on = virt::edit_firmware_xml(&ran, true, true).unwrap();
    assert!(on.xml.contains(&format!("<nvram>{VARS}</nvram>")), "{}", on.xml);
    assert!(!on.xml.contains("-sb.fd") && !on.xml.contains("template="), "{}", on.xml);
    assert_eq!(on.drop_vars.as_deref(), Some(VARS));
    let off = virt::edit_firmware_xml(&on.xml, true, false).unwrap();
    assert!(off.xml.contains(&format!("<nvram>{VARS}</nvram>")), "{}", off.xml);
    assert_eq!(off.drop_vars.as_deref(), Some(VARS));
    // The same setting keeps the file it has.
    let same = virt::edit_firmware_xml(&on.xml, true, true).unwrap();
    assert_eq!(same.drop_vars, None);
    // Leaving UEFI: nothing names the file any more, so it goes.
    let bios = virt::edit_firmware_xml(&ran, false, false).unwrap();
    assert!(!bios.xml.contains("<nvram"), "{}", bios.xml);
    assert_eq!(bios.drop_vars.as_deref(), Some(VARS));

    // Only a file in libvirt's NVRAM directory is ever deleted, whatever
    // the definition says.
    for path in [
        "/etc/passwd",
        "/var/lib/libvirt/qemu/nvram/../../../../etc/x.fd",
        "/var/lib/libvirt/images/disk.fd",
        "relative/libvirt/qemu/nvram/x.fd",
        "/var/lib/libvirt/qemu/nvram/x.fd\n/etc/y.fd",
    ] {
        assert!(!virt::is_libvirt_nvram(path), "{path:?}");
        let odd = ran.replacen(VARS, path, 1);
        if let Ok(edit) = virt::edit_firmware_xml(&odd, false, false) {
            assert_eq!(edit.drop_vars, None, "{path:?}");
        }
    }
    assert!(virt::is_libvirt_nvram(
        "/home/u/.config/libvirt/qemu/nvram/vm_VARS.fd"
    ));
    // A variables file elsewhere (or a qcow2 one) is the guest's all the
    // same: an edit that resets nothing keeps its element as written…
    const ELSEWHERE: &str = "<nvram template='/t.fd' format='qcow2'>/srv/vm/vm_VARS.qcow2</nvram>";
    let kept = ran.replacen(&format!("<nvram template='/t.fd'>{VARS}</nvram>"), ELSEWHERE, 1);
    assert_ne!(kept, ran);
    let same = virt::edit_firmware_xml(&kept, true, false).unwrap();
    assert!(same.xml.contains(ELSEWHERE), "{}", same.xml);
    assert_eq!(same.drop_vars, None);
    // …and one in libvirt's directory keeps its attributes too.
    let same = virt::edit_firmware_xml(&ran, true, false).unwrap();
    assert!(same.xml.contains(&format!("<nvram template='/t.fd'>{VARS}</nvram>")), "{}", same.xml);
    // A Secure Boot change on it cannot make the file again: refused, not a
    // new path.
    assert!(matches!(
        virt::edit_firmware_xml(&kept, true, true),
        Err(VirtError::Command { message }) if message.contains("/srv/vm/vm_VARS.qcow2")
    ));
    // Leaving UEFI keeps the file where it is, deleting nothing.
    let bios = virt::edit_firmware_xml(&kept, false, false).unwrap();
    assert!(!bios.xml.contains("<nvram") && bios.drop_vars.is_none(), "{}", bios.xml);

    // Secure Boot on a definition whose SMM is turned off turns it on.
    let smm_off = virt::edit_firmware_xml(&base, true, false)
        .unwrap()
        .xml
        .replacen("<smm state='on'/>", "", 1)
        .replacen("<features>", "<features><smm state='off'><tseg unit='MiB'>48</tseg></smm>", 1);
    assert!(smm_off.contains("<smm state='off'>"), "{smm_off}");
    let on = virt::edit_firmware_xml(&smm_off, true, true).unwrap();
    assert!(on.xml.contains("<smm state='on'><tseg unit='MiB'>48</tseg></smm>"), "{}", on.xml);
    assert!(!on.xml.contains("state='off'"), "{}", on.xml);

    // The change script deletes it after the definition, quoted.
    let script = virt::hardware_change_script(
        "vm",
        false,
        Some(&ran),
        &virt::VirtHwChange::Firmware { efi: true, secure_boot: true },
    )
    .unwrap();
    let define_at = script.find("define --file").unwrap();
    let rm_at = script.find(&format!("rm -f -- '{VARS}'")).unwrap();
    assert!(define_at < rm_at, "{script}");
}

#[cfg(unix)]
#[test]
fn firmware_change_deletes_the_dropped_variables_file() {
    use virt::VirtHwChange as C;
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let nvram = std::env::temp_dir()
        .join(format!("sbm_nv_{}", std::process::id()))
        .join("libvirt/qemu/nvram");
    std::fs::create_dir_all(&nvram).unwrap();
    let vars = nvram.join(format!("{name}_VARS.fd"));
    let vars_s = vars.display().to_string();
    // As a domain that has run: UEFI without Secure Boot, and its file.
    let base = virt::edit_firmware_xml(&base_xml(), true, false).unwrap().xml.replacen(
        "<firmware>",
        &format!("<nvram>{}</nvram><firmware>", vars_s.replace('&', "&amp;").replace('<', "&lt;")),
        1,
    );
    let d = hardware_stub("nvram", &base);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let run = || {
        let script = virt::hardware_change_script(name, false, Some(&base), &C::Firmware {
            efi: true,
            secure_boot: true,
        })
        .unwrap();
        virt::parse_hardware_change(&run_sh(&script, &path))
    };

    // A refused definition still names the file: it stays.
    std::fs::write(&vars, "vars").unwrap();
    std::fs::write(d.join("fail_define"), "").unwrap();
    assert!(run().is_err());
    assert!(vars.exists());
    std::fs::remove_file(d.join("fail_define")).unwrap();

    // Defined: gone, and nothing else with it.
    std::fs::write(nvram.join("other_VARS.fd"), "other").unwrap();
    assert_eq!(run(), Ok(Default::default()));
    assert!(!vars.exists());
    assert!(nvram.join("other_VARS.fd").exists());
    assert!(!std::path::Path::new("pwned").exists());
    let _ = std::fs::remove_dir_all(nvram.parent().unwrap().parent().unwrap().parent().unwrap());
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn display_and_device_edits() {
    let base = base_xml();
    let with_pw = base.replacen("<graphics type='vnc'", "<graphics type='vnc' passwd='x&amp;y'", 1);
    let xml = virt::edit_display_xml(&with_pw, None, Some("0.0.0.0"), Some("vga")).unwrap();
    let hw = hw_of(&xml);
    assert_eq!(hw.graphics.unwrap().listen.as_deref(), Some("0.0.0.0"));
    assert_eq!(hw.video.as_deref(), Some("vga"));
    // What the console had besides stays: its password among it.
    assert!(xml.contains("passwd='x&amp;y'"), "{xml}");

    let added = virt::VirtHwNewDevice::Pci { address: "0000:01:00.0".into() }.xml();
    let with = base.replacen("</devices>", &format!("{added}</devices>"), 1);
    assert_eq!(hw_of(&with).hostdevs[0].key, "pci:0000:01:00.0");
    let (without, element) = virt::remove_device_xml(&with, "pci:0000:01:00.0").unwrap();
    assert!(hw_of(&without).hostdevs.is_empty());
    assert_eq!(element, added);
    let usb = virt::VirtHwNewDevice::Usb { vendor: Some("0bda".into()), product: Some("b023".into()), bus: None, device: None }.xml();
    let with = base.replacen("</devices>", &format!("{usb}</devices>"), 1);
    assert_eq!(hw_of(&with).hostdevs[0].key, "usb:0bda:b023");
    assert!(virt::remove_device_xml(&base, "tpm").is_err());
}

#[test]
fn second_part_changes_refuse_what_must_not_reach_a_shell() {
    use virt::{VirtHwChange as C, VirtHwNewDevice as D};
    let script = |c: &C| virt::hardware_change_script("vm", false, Some(&base_xml()), c);
    let disk = |bus: Option<&str>, cache: Option<&str>| C::UpdateDisk {
        target: "vda".into(),
        new_target: bus.map(|_| "sda".into()),
        bus: bus.map(str::to_string),
        cache: cache.map(str::to_string),
    };
    assert!(script(&disk(Some("sata; rm"), None)).is_err());
    assert!(script(&disk(None, Some("fast"))).is_err());
    assert!(script(&disk(None, None)).is_err());
    let nic = |mac: &str| C::UpdateNicHardware { mac: "52:54:00:b9:34:c3".into(), new_mac: Some(mac.into()), model: None };
    assert!(script(&nic("01:00:00:00:00:01")).is_err(), "multicast");
    assert!(script(&nic("00:00:00:00:00:00")).is_err());
    assert!(script(&nic("52:54:00:00:00:01'")).is_err());
    let display = |l: &str| C::Display { graphics: None, listen: Some(l.into()), video: None };
    assert!(script(&display("0.0.0.0' autoport='no")).is_err());
    assert!(script(&display("::1")).is_ok());
    for bad in [
        D::Pci { address: "0000:01:00.0'/>".into() },
        D::Pci { address: "0000:01:20.0".into() },
        D::Usb { vendor: Some("0bda".into()), product: Some("b02".into()), bus: None, device: None },
        D::Tpm { model: "tpm-crb' x='".into() },
    ] {
        assert!(script(&C::AddDevice { device: bad.clone() }).is_err(), "{bad:?}");
    }
    assert!(script(&C::RemoveDevice { key: "pci:0000:01:00.0; x".into() }).is_err());
}

#[cfg(unix)]
#[test]
fn second_part_scripts_under_sh_with_a_hostile_name() {
    use virt::VirtHwChange as C;
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let base = base_xml();
    let d = hardware_stub("hostile2", &base);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let run = |running: bool, c: &C| {
        let script = virt::hardware_change_script(name, running, Some(&base), c).unwrap();
        virt::parse_hardware_change(&run_sh(&script, &path))
    };
    let log = || std::fs::read_to_string(d.join("log")).unwrap_or_default();

    let change = C::UpdateDisk { target: "vda".into(), new_target: None, bus: None, cache: Some("none".into()) };
    assert_eq!(run(true, &change), Ok(Default::default()));
    assert_eq!(
        std::fs::read_to_string(d.join("given_define.xml")).unwrap(),
        virt::edit_disk_xml(&base, "vda", None, None, Some("none")).unwrap()
    );
    assert!(log().contains(&format!("dumpxml\n--inactive\n--security-info\n--domain\n{name}\n")), "{}", log());

    // A USB device goes to the running guest too; a PCI one does not.
    let usb = C::AddDevice { device: virt::VirtHwNewDevice::Usb { vendor: Some("0bda".into()), product: Some("b023".into()), bus: None, device: None } };
    let _ = std::fs::remove_file(d.join("log"));
    assert_eq!(run(true, &usb), Ok(Default::default()));
    assert!(log().contains(&format!("attach-device\n--domain\n{name}\n")), "{}", log());
    assert_eq!(log().matches("attach-device").count(), 2, "{}", log());
    let pci = C::AddDevice { device: virt::VirtHwNewDevice::Pci { address: "0000:01:00.0".into() } };
    let _ = std::fs::remove_file(d.join("log"));
    assert_eq!(run(true, &pci), Ok(Default::default()));
    assert_eq!(log().matches("attach-device").count(), 1, "{}", log());
    assert!(!std::path::Path::new("pwned").exists() && !d.join("pwned").exists());
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// Cloning: captured from libvirt 11.3, and under sh with a stub
// ---------------------------------------------------------------------------

#[test]
fn clone_outputs_from_the_host() {
    let full = virt::parse_clone_volumes(&fixture("script_clone_volumes_full.txt")).unwrap();
    assert_eq!(full, ["/var/lib/libvirt/images/sbcl-full.qcow2"]);
    let empty = virt::parse_clone_volumes(&fixture("script_clone_volumes_empty.txt")).unwrap();
    assert_eq!(empty, ["/var/lib/libvirt/images/sbcl-empty.qcow2"]);
    assert!(matches!(
        virt::parse_clone_volumes(&fixture("script_clone_volumes_exists.txt")),
        Err(VirtError::Exists { .. })
    ));
    assert!(matches!(
        virt::parse_clone_volumes(&fixture("script_clone_volumes_running.txt")),
        Err(VirtError::InvalidState { .. })
    ));
    let made = virt::parse_create(&fixture("script_clone_define.txt")).unwrap();
    assert_eq!(made.uuid.as_deref(), Some("b0352bd8-52ad-4cf7-875c-7ceb45b0d751"));
    // A define refused (the name taken meanwhile) says so, its volume gone.
    assert!(matches!(
        virt::parse_create(&fixture("script_clone_define_rollback.txt")),
        Err(VirtError::Exists { .. })
    ));
}

#[test]
fn clone_xml_is_a_new_domain_on_new_disks() {
    let base = r#"<domain type='kvm'>
  <name>src</name>
  <uuid>8ecccb6b-4f93-4739-afb1-caa17c3f4f91</uuid>
  <os firmware='efi'><type arch='x86_64' machine='q35'>hvm</type>
    <nvram template='/usr/share/OVMF/OVMF_VARS_4M.ms.fd' format='raw'>/var/lib/libvirt/qemu/nvram/src_VARS.fd</nvram>
  </os>
  <devices>
    <disk type='volume' device='disk'><driver name='qemu' type='qcow2'/><source pool='images' volume='src.qcow2'/><target dev='vda' bus='virtio'/></disk>
    <disk type='file' device='disk'><driver name='qemu' type='raw'/><source file='/v/data.img'/><target dev='vdb' bus='virtio'/></disk>
    <disk type='file' device='cdrom'><source file='/iso/cirros.img'/><target dev='sda' bus='sata'/><readonly/></disk>
    <interface type='network'><mac address='52:54:00:df:b2:a4'/><source network='default'/></interface>
  </devices>
</domain>"#;
    let name = "it's <new> & \"odd\"";
    let xml = virt::clone_domain_xml(
        base,
        name,
        &[
            ("vda".into(), "/var/lib/libvirt/images/new.qcow2".into()),
            ("vdb".into(), "/dev/vg0/new-1".into()),
        ],
    )
    .unwrap();
    let doc = roxmltree::Document::parse(&xml).unwrap();
    let root = doc.root_element();
    let el = |name: &str| root.descendants().find(|n| n.has_tag_name(name));
    assert_eq!(el("name").and_then(|n| n.text()), Some(name));
    assert!(el("uuid").is_none(), "libvirt gives it one");
    assert!(el("mac").is_none(), "nor one of the source's MACs");
    let disks: Vec<_> = root.descendants().filter(|n| n.has_tag_name("disk")).collect();
    fn src<'a>(d: roxmltree::Node<'a, 'a>) -> (Option<&'a str>, Option<&'a str>) {
        let s = d.children().find(|n| n.has_tag_name("source")).unwrap();
        (d.attribute("type"), s.attribute("file").or(s.attribute("dev")))
    }
    assert_eq!(src(disks[0]), (Some("file"), Some("/var/lib/libvirt/images/new.qcow2")));
    assert_eq!(src(disks[1]), (Some("block"), Some("/dev/vg0/new-1")));
    // A copy on a block device is raw, and says so; a file keeps its format.
    fn driver<'a>(d: roxmltree::Node<'a, 'a>) -> Option<&'a str> {
        d.children().find(|n| n.has_tag_name("driver")).and_then(|n| n.attribute("type"))
    }
    assert_eq!(driver(disks[0]), Some("qcow2"));
    assert_eq!(driver(disks[1]), Some("raw"));
    assert_eq!(src(disks[2]), (Some("file"), Some("/iso/cirros.img")), "a CD-ROM keeps its image");
    // Its own variables file, made by libvirt from the same template.
    let nvram = el("nvram").unwrap();
    assert_eq!(nvram.attribute("template"), Some("/usr/share/OVMF/OVMF_VARS_4M.ms.fd"));
    assert_eq!(nvram.text(), None);
    assert!(virt::clone_domain_xml(base, "x", &[("vdz".into(), "/p".into())]).is_err());
}

#[cfg(unix)]
#[test]
fn clone_scripts_under_sh_with_hostile_names() {
    use virt::{VirtCloneDisk, VirtCloneSpec};
    let d = std::env::temp_dir().join(format!("sbm_virt_clone_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    // A virsh that logs its arguments, answers the domain as shut off, and
    // makes volumes as files — refusing the second clone when told to.
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
shift 3
case "$1" in
  domuuid) exit 1 ;;
  domstate) echo 'shut off' ;;
  vol-pool) echo pool ;;
  vol-clone) [ -f "$dir/fail_second" ] && [ -f "$dir/made" ] && { echo "error: clone refused" >&2; exit 1; }; echo x >> "$dir/made"; echo "Vol cloned" ;;
  vol-info) echo "Capacity:       1073741824 bytes" ;;
  vol-create-as) echo "Vol created" ;;
  vol-path) echo "/pool/$5" ;;
  vol-delete) echo "Vol deleted" ;;
  *) echo "error: unexpected $*" >&2; exit 1 ;;
esac
"#;
    std::fs::write(d.join("virsh"), stub).unwrap();
    Command::new("chmod").arg("+x").arg(d.join("virsh")).status().unwrap();
    let path = format!("{}:/usr/bin:/bin", d.display());
    let log = || std::fs::read_to_string(d.join("log")).unwrap_or_default();
    let name = "it's \"odd\"; touch pwned $(id) `id`";
    let spec = |full: bool| VirtCloneSpec {
        source: name.into(),
        name: format!("{name} copy"),
        full,
        disks: vec![
            VirtCloneDisk { target: "vda".into(), source: format!("/pool/{name}.qcow2"), format: Some("qcow2".into()) },
            VirtCloneDisk { target: "vdb".into(), source: "/pool/data".into(), format: Some("raw".into()) },
        ],
        target_pool: None,
        target_block: false,
    };

    let raw = run_sh(&virt::clone_volumes_script(&spec(true)).unwrap(), &path);
    let paths = virt::parse_clone_volumes(&raw).unwrap();
    assert_eq!(paths, [format!("/pool/{name} copy.qcow2"), format!("/pool/{name} copy-1")]);
    assert!(log().contains(&format!("vol-clone\n--vol\n/pool/{name}.qcow2\n--newname\n{name} copy.qcow2\n")), "{}", log());
    assert!(!std::path::Path::new("pwned").exists() && !d.join("pwned").exists());

    // Empty copies: the source's size and format.
    let _ = std::fs::remove_file(d.join("log"));
    let raw = run_sh(&virt::clone_volumes_script(&spec(false)).unwrap(), &path);
    assert_eq!(virt::parse_clone_volumes(&raw).unwrap().len(), 2);
    assert!(log().contains("vol-create-as\n--pool\npool\n--name\nit's"), "{}", log());
    assert!(log().contains("--capacity\n1073741824\n--format\nraw\n"), "{}", log());

    // The second disk refused: the first one's volume is deleted again.
    let _ = std::fs::remove_file(d.join("log"));
    let _ = std::fs::remove_file(d.join("made"));
    std::fs::write(d.join("fail_second"), "").unwrap();
    let raw = run_sh(&virt::clone_volumes_script(&spec(true)).unwrap(), &path);
    assert!(matches!(virt::parse_clone_volumes(&raw), Err(VirtError::Command { .. })), "{raw}");
    assert!(log().contains(&format!("vol-delete\n--vol\n/pool/{name} copy.qcow2\n")), "{}", log());
    let _ = std::fs::remove_dir_all(&d);
}

/// A clone into another pool: `vol-create-from` with the source's pool named
/// as the input, its capacity and format in the XML the host is handed. The
/// hostile name is in the volume, the pool and the XML's name.
#[cfg(unix)]
#[test]
fn clone_to_another_pool_under_sh() {
    use virt::{VirtCloneDisk, VirtCloneSpec};
    let d = clone_stub("cross");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let log = || std::fs::read_to_string(d.join("log")).unwrap_or_default();
    let name = "it's \"odd\" & `id`";
    let spec = |full: bool| VirtCloneSpec {
        source: "sbcl-src".into(),
        name: name.into(),
        full,
        disks: vec![VirtCloneDisk {
            target: "vda".into(),
            source: "/var/lib/libvirt/images/src & q.qcow2".into(),
            format: Some("qcow2".into()),
        }],
        target_pool: Some("sbxe2e-p9 #2".into()),
        target_block: false,
    };

    // Full: copied out of `pool` (what `vol-pool` answered) into the target.
    let raw = run_sh(&virt::clone_volumes_script(&spec(true)).unwrap(), &path);
    assert_eq!(
        virt::parse_clone_volumes(&raw),
        Ok(vec![format!("/pool/{name}.qcow2")]),
        "{raw}"
    );
    let l = log();
    assert!(l.contains("vol-create-from\n"), "{l}");
    assert!(l.contains("--pool\nsbxe2e-p9 #2\n--file\n"), "{l}");
    assert!(l.contains("--vol\n/var/lib/libvirt/images/src & q.qcow2\n--inputpool\npool\n"), "{l}");
    // The XML the host was handed: this app's own document, every value in
    // it escaped, and the capacity `vol-info --bytes` answered — the
    // source's own size, expanded by the shell (a `$cap` that reached
    // libvirt unexpanded is `malformed capacity element`).
    assert_eq!(
        std::fs::read_to_string(d.join("xml")).unwrap(),
        concat!(
            "<volume><name>it&apos;s &quot;odd&quot; &amp; `id`.qcow2</name>",
            "<capacity unit='bytes'>1073741824</capacity>",
            "<target><format type='qcow2'/></target></volume>",
        )
    );
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());

    // The path read back is asked of the target pool, not the source's.
    assert!(l.contains("vol-path\n--pool\nsbxe2e-p9 #2\n"), "{l}");

    // Empty: made in the target with the source's capacity and format.
    let _ = std::fs::remove_file(d.join("log"));
    let raw = run_sh(&virt::clone_volumes_script(&spec(false)).unwrap(), &path);
    assert_eq!(virt::parse_clone_volumes(&raw).unwrap().len(), 1);
    let l = log();
    assert!(l.contains("vol-create-as\n"), "{l}");
    assert!(l.contains("--pool\nsbxe2e-p9 #2\n"), "{l}");
    assert!(l.contains("--capacity\n1073741824\n--format\nqcow2\n"), "{l}");

    // Into a pool of block devices: raw, named `.img`, whatever the source
    // was (libvirt converts it to raw there anyway).
    let _ = std::fs::remove_file(d.join("log"));
    let block = VirtCloneSpec { target_block: true, ..spec(true) };
    let raw = run_sh(&virt::clone_volumes_script(&block).unwrap(), &path);
    assert_eq!(virt::parse_clone_volumes(&raw), Ok(vec![format!("/pool/{name}.img")]), "{raw}");
    assert!(std::fs::read_to_string(d.join("xml")).unwrap().contains("<format type='raw'/>"));
    let _ = std::fs::remove_file(d.join("log"));
    let raw = run_sh(&virt::clone_volumes_script(&VirtCloneSpec { full: false, ..block }).unwrap(), &path);
    assert_eq!(virt::parse_clone_volumes(&raw).unwrap().len(), 1);
    assert!(log().contains("--capacity\n1073741824\n--format\nraw\n"), "{}", log());

    // The copy refused: nothing is left, and the error is the host's.
    let _ = std::fs::remove_file(d.join("log"));
    std::fs::write(d.join("fail"), "vol-create-from\n").unwrap();
    let raw = run_sh(&virt::clone_volumes_script(&spec(true)).unwrap(), &path);
    assert!(matches!(virt::parse_clone_volumes(&raw), Err(VirtError::Command { .. })), "{raw}");
    let _ = std::fs::remove_dir_all(&d);
}

/// A fake virsh for the clone scripts, keeping the XML a `--file` was given.
#[cfg(unix)]
fn clone_stub(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_clone_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
shift 3
if [ -f "$dir/fail" ] && grep -qx "$1" "$dir/fail"; then echo "error: $1 refused" >&2; exit 1; fi
case "$1" in
  domuuid) exit 1 ;;
  domstate) echo 'shut off' ;;
  vol-pool) echo pool ;;
  vol-clone|vol-create-as) echo "Vol made" ;;
  # The XML arrives as a path under /tmp that the script removes again, so
  # it is copied out here for the test to read.
  vol-create-from) [ -f "$5" ] && cp "$5" "$dir/xml"; echo "Vol made" ;;
  vol-info) echo "Capacity:       1073741824 bytes" ;;
  vol-path) echo "/pool/$5" ;;
  vol-delete) echo "Vol deleted" ;;
  *) echo "error: unexpected $*" >&2; exit 1 ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

// ---------------------------------------------------------------------------
// Managing storage and networks, and uploading, under a real sh
// ---------------------------------------------------------------------------

/// A fake virsh for the storage and network scripts: logs its arguments one
/// per line, keeps what a `define --file` was given, writes what
/// `vol-upload` reads into `uploaded`, and fails the commands listed in
/// `$dir/fail`.
#[cfg(unix)]
fn manage_stub(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_manage_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
for a in "$@"; do printf '%s\n' "$a" >> "$dir/log"; done
echo --- >> "$dir/log"
shift 3
if [ -f "$dir/fail" ] && grep -qx "$1" "$dir/fail"; then echo "error: $1 refused" >&2; exit 1; fi
case "$1" in
  pool-define|net-define) cp "$3" "$dir/defined.xml" ;;
  vol-upload) cat > "$dir/uploaded" ;;
  net-info) if [ -f "$dir/inactive" ]; then echo 'Active:         no'; else echo 'Active:         yes'; fi ;;
  *) cat >> "$dir/stdin" ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

#[cfg(unix)]
#[test]
fn manage_scripts_under_sh_with_hostile_names() {
    use sbm_virt::libvirt::manage::{self as m, VirtResourceOp as Op};
    let d = manage_stub("hostile");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let hostile = "it's \"odd\"; touch pwned $(id) `id`";
    let log = || std::fs::read_to_string(d.join("log")).unwrap_or_default();

    // Existing objects are named by whatever libvirt calls them.
    for op in [
        Op::PoolStart { name: hostile.into() },
        Op::PoolAutostart { name: hostile.into(), on: false },
        Op::VolDelete { pool: hostile.into(), name: hostile.into() },
        Op::VolResize { pool: hostile.into(), name: hostile.into(), bytes: 5 << 30 },
        Op::NetDelete { name: hostile.into() },
    ] {
        assert_eq!(m::parse_resource(&run_sh(&m::resource_script(&op).unwrap(), &path)), Ok(()), "{op:?}");
    }
    let l = log();
    assert!(l.contains(&format!("pool-start\n--pool\n{hostile}\n---")), "{l}");
    assert!(l.contains(&format!("pool-autostart\n--pool\n{hostile}\n--disable\n---")), "{l}");
    assert!(l.contains(&format!("vol-delete\n--pool\n{hostile}\n--vol\n{hostile}\n---")), "{l}");
    assert!(l.contains("--capacity\n5368709120B\n"), "{l}");
    assert!(l.contains(&format!("net-destroy\n--network\n{hostile}\n---\n")), "{l}");
    assert!(l.contains(&format!("net-undefine\n--network\n{hostile}\n---\n")), "{l}");
    // Stopped since the listing that showed it running: not stopped again
    // (libvirt would refuse: `network is not active`), just undefined.
    std::fs::write(d.join("inactive"), "").unwrap();
    std::fs::remove_file(d.join("log")).unwrap();
    let op = Op::NetDelete { name: hostile.into() };
    assert_eq!(m::parse_resource(&run_sh(&m::resource_script(&op).unwrap(), &path)), Ok(()));
    let l = log();
    assert!(!l.contains("net-destroy"), "{l}");
    assert!(l.contains(&format!("net-undefine\n--network\n{hostile}\n---\n")), "{l}");
    std::fs::remove_file(d.join("inactive")).unwrap();
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap_or_default(), "");

    // A create: defined from the XML byte for byte, built, started, autostart
    std::fs::remove_file(d.join("log")).unwrap();
    let create = Op::PoolCreate {
        name: "sbxe2e-p".into(),
        pool_type: "dir".into(),
        target: Some("/var/lib/libvirt/sbxe2e-p & q".into()),
        source: None,
        autostart: true,
    };
    assert_eq!(m::parse_resource(&run_sh(&m::resource_script(&create).unwrap(), &path)), Ok(()));
    assert_eq!(
        std::fs::read_to_string(d.join("defined.xml")).unwrap(),
        m::pool_xml("sbxe2e-p", "dir", Some("/var/lib/libvirt/sbxe2e-p & q"), None)
    );
    let l = log();
    let order: Vec<&str> = l
        .lines()
        .filter(|x| x.starts_with("pool-"))
        .collect();
    assert_eq!(order, ["pool-define", "pool-build", "pool-start", "pool-autostart"], "{l}");

    // The start refused: undefined again, and the error is the start's
    std::fs::remove_file(d.join("log")).unwrap();
    std::fs::write(d.join("fail"), "net-start\n").unwrap();
    let net = Op::NetCreate {
        name: "sbxe2e-n".into(),
        mode: "nat".into(),
        bridge: None,
        ipv4: Some(m::VirtNetIpv4 {
            address: "10.231.78.1".into(),
            prefix: 24,
            dhcp_start: Some("10.231.78.100".into()),
            dhcp_end: Some("10.231.78.200".into()),
        }),
        autostart: true,
    };
    let e = m::parse_resource(&run_sh(&m::resource_script(&net).unwrap(), &path)).unwrap_err();
    assert!(e.message().contains("net-start refused"), "{e:?}");
    let l = log();
    assert!(l.contains("net-undefine\n--network\nsbxe2e-n\n") && !l.contains("net-autostart"), "{l}");
    let _ = std::fs::remove_dir_all(&d);
}

/// Runs `command` the way an SSH server does — the login shell's `-c` —
/// with `input` on its stdin.
#[cfg(unix)]
fn run_command(command: &str, path: &str, input: &[u8]) -> String {
    use std::io::Write;
    let mut child = Command::new("/bin/sh")
        .arg("-c")
        .arg(command)
        .env("PATH", path)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let mut stdin = child.stdin.take().unwrap();
    // The script may stop before reading it all: a closed pipe is its answer.
    let _ = stdin.write_all(input);
    drop(stdin);
    let out = child.wait_with_output().unwrap();
    String::from_utf8(out.stdout).unwrap()
}

#[cfg(unix)]
#[test]
fn upload_streams_stdin_into_the_volume() {
    use sbm_virt::libvirt::manage::{self as m, VirtUploadEntry};
    let d = manage_stub("upload");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let hostile = "it's \"odd\" \\ $(id) `id`.iso";
    let command = m::vol_upload_command("images", hostile, VirtUploadEntry::Direct).unwrap();

    // Binary content, a line that looks like the go line included
    let mut data: Vec<u8> = (0..=255u8).cycle().take(300_000).collect();
    data.extend_from_slice(format!("\n{}\n", m::UPLOAD_GO).as_bytes());
    let mut input = format!("{}\n", m::UPLOAD_GO).into_bytes();
    input.extend_from_slice(&data);
    let out = run_command(&command, &path, &input);
    assert!(out.contains(m::UPLOAD_READY), "{out}");
    assert_eq!(m::parse_vol_upload(&out), Ok(true), "{out}");
    assert_eq!(std::fs::read(d.join("uploaded")).unwrap(), data);
    let l = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(l.contains(&format!("vol-upload\n--pool\nimages\n--vol\n{hostile}\n--file\n/dev/stdin\n")), "{l}");
    assert!(l.contains("pool-refresh\n--pool\nimages\n"), "{l}");

    // Something else first — a password sudo did not ask for: virsh never
    // runs, and nothing reaches a volume.
    std::fs::remove_file(d.join("uploaded")).unwrap();
    std::fs::remove_file(d.join("log")).unwrap();
    let out = run_command(&command, &path, b"hunter2\nSbVirtUploadGo\nbytes");
    assert_eq!(m::parse_vol_upload(&out), Ok(false), "{out}");
    assert!(!out.contains(m::UPLOAD_READY), "{out}");
    assert!(!d.join("uploaded").exists() && !d.join("log").exists());

    // Refused by the host
    std::fs::write(d.join("fail"), "vol-upload\n").unwrap();
    let out = run_command(&command, &path, &input);
    assert!(matches!(m::parse_vol_upload(&out), Err(VirtError::Command { .. })), "{out}");
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// External snapshots: the disk chain
// ---------------------------------------------------------------------------

#[test]
fn snap_chain_of_an_overlay_and_a_plain_disk() {
    let chain = virt_snapshot::parse_snap_chain(&fixture("script_snap_chain_overlay.txt")).unwrap();
    assert_eq!(chain.depth(), 2);
    assert!(chain.has_overlays());
    let d = chain.disks_iter().next().unwrap();
    assert_eq!(d.target, "vda");
    assert_eq!(d.error, None);
    // Topmost first: the overlay the guest writes to, then its base
    assert_eq!(d.files[0].path, "/var/lib/libvirt/sbxe2e-p8q/sx1.qcow2");
    assert_eq!(d.files[0].format.as_deref(), Some("qcow2"));
    assert_eq!(
        d.files[0].backing.as_deref(),
        Some("/var/lib/libvirt/images/sbxe2e-f1.qcow2")
    );
    assert_eq!(d.files[0].backing_format.as_deref(), Some("qcow2"));
    assert_eq!(d.files[0].capacity, Some(268435456));
    assert_eq!(d.files[1].path, "/var/lib/libvirt/images/sbxe2e-f1.qcow2");
    assert_eq!(d.files[1].backing, None);
    assert_eq!(virt_snapshot::external_snapshot_refusal(&chain), None);
    assert_expected(&chain, "snap_chain_overlay.expected.json");
}

#[test]
fn snap_chain_of_two_overlays_lists_three_layers() {
    let chain = virt_snapshot::parse_snap_chain(&fixture("script_snap_chain_chain.txt")).unwrap();
    assert_eq!(chain.depth(), 3);
    let files = &chain.disks_iter().next().unwrap().files;
    assert_eq!(
        files.iter().map(|f| f.path.as_str()).collect::<Vec<_>>(),
        [
            "/var/lib/libvirt/sbxe2e-p8q/sx2.qcow2",
            "/var/lib/libvirt/sbxe2e-p8q/sx1.qcow2",
            "/var/lib/libvirt/images/sbxe2e-f1.qcow2",
        ]
    );
    assert_expected(&chain, "snap_chain_chain.expected.json");
}

#[test]
fn snap_chain_refuses_a_raw_disk() {
    let chain = virt_snapshot::parse_snap_chain(&fixture("script_snap_chain_raw.txt")).unwrap();
    assert!(!chain.has_overlays());
    assert_eq!(chain.depth(), 1);
    let top = &chain.disks_iter().next().unwrap().files[0];
    assert_eq!(top.format.as_deref(), Some("raw"));
    let refusal = virt_snapshot::external_snapshot_refusal(&chain).unwrap();
    assert!(refusal.contains("vda") && refusal.contains("raw"), "{refusal}");
    // An internal snapshot needs qcow2 too: the same refusal for both forms
    assert_eq!(virt_snapshot::snapshot_refusal(&chain), Some(refusal));
    assert_expected(&chain, "snap_chain_raw.expected.json");
}

#[test]
fn snap_chain_of_a_plain_qcow2_is_one_layer() {
    let chain = virt_snapshot::parse_snap_chain(&fixture("script_snap_chain_plain.txt")).unwrap();
    assert_eq!(chain.depth(), 2, "cirros-run's first disk is an overlay");
    assert_eq!(chain.disks_iter().count(), 2);
    let vdb = chain.disks_iter().nth(1).unwrap();
    assert_eq!(vdb.target, "vdb");
    assert_eq!(vdb.files.len(), 1);
    assert_expected(&chain, "snap_chain_plain.expected.json");
}

#[test]
fn external_snapshot_refusal_says_what_is_wrong() {
    let disk = |files, error: Option<&str>| virt_snapshot::VirtSnapChain {
        disks: vec![virt_snapshot::VirtSnapChainDisk {
            target: "vda".into(),
            files,
            error: error.map(Into::into),
        }],
    };
    let file = |format: Option<&str>, backing: Option<&str>, backing_format: Option<&str>| {
        virt_snapshot::VirtSnapChainFile {
            path: "/x.qcow2".into(),
            format: format.map(Into::into),
            backing: backing.map(Into::into),
            backing_format: backing_format.map(Into::into),
            allocation: None,
            capacity: None,
        }
    };
    // No disk at all
    let empty = virt_snapshot::VirtSnapChain::default();
    assert!(virt_snapshot::external_snapshot_refusal(&empty).is_some());
    // A disk qemu-img could not read: its words are the refusal, and only the
    // external form is refused — virsh does not need qemu-img
    let unread = disk(
        vec![file(None, None, None)],
        Some("qemu-img: Could not open '/x.qcow2': Permission denied"),
    );
    let why = virt_snapshot::external_snapshot_refusal(&unread).unwrap();
    assert!(why.contains("vda") && why.contains("Permission denied"), "{why}");
    assert_eq!(virt_snapshot::snapshot_refusal(&unread), None);
    // An overlay whose backing format is not recorded
    let probed = disk(vec![file(Some("qcow2"), Some("/base.qcow2"), None)], None);
    let why = virt_snapshot::external_snapshot_refusal(&probed).unwrap();
    assert!(why.contains("backing format"), "{why}");
    assert_eq!(virt_snapshot::snapshot_refusal(&probed), None);
    // Recorded: allowed
    let ok = disk(
        vec![file(Some("qcow2"), Some("/base.qcow2"), Some("qcow2"))],
        None,
    );
    assert_eq!(virt_snapshot::external_snapshot_refusal(&ok), None);
}

#[test]
fn external_snapshot_script_quotes_everything() {
    let s = virt_snapshot::snapshot_external_script(
        "it's",
        "snap-1",
        Some("two\nlines"),
        &[("vda".into(), "/p/a b.qcow2".into())],
    );
    assert!(
        s.contains(
            "V snapshot-create-as --domain 'it'\\''s' --name 'snap-1' --disk-only --atomic \
             --description 'two\nlines' \
             --diskspec 'vda,file=/p/a b.qcow2,snapshot=external'\n"
        ),
        "{s}"
    );
    // No description, no flag; no overlay named, libvirt's own name is used
    let s = virt_snapshot::snapshot_external_script("d", "n", None, &[]);
    assert!(!s.contains("--description") && !s.contains("--diskspec"), "{s}");
    assert!(virt_snapshot::snapshot_external_script("d", "n", Some("  "), &[]).contains("--atomic"));
}

#[test]
fn snapshot_listing_carries_the_layers() {
    let snaps = virt::parse_snapshots(&fixture("script_snapshots_external.txt")).unwrap();
    assert_eq!(
        snaps.iter().map(|s| s.name.as_str()).collect::<Vec<_>>(),
        ["sx1", "sx2"]
    );
    assert!(snaps.iter().all(|s| s.external && !s.memory));
    assert_eq!(snaps[1].parent.as_deref(), Some("sx1"));
    assert!(snaps[1].current);
    assert_eq!(snaps[0].layers.len(), 1);
    assert_eq!(
        snaps[0].layers[0].file.as_deref(),
        Some("/var/lib/libvirt/sbxe2e-p8q/sx1.qcow2")
    );
    assert_eq!(snaps[0].layers[0].snapshot.as_deref(), Some("external"));
    assert_expected(&snaps, "snapshots_external.expected.json");
}

#[test]
fn snapshot_listing_reads_revert_disks() {
    // A snapshot reverted to once names where a further revert would go in
    // <revertDisks>, not in <disks> (captured on libvirt 11.3).
    let x = virt::parse_snapshot_xml(&fixture("snapshot_revert_disks.xml")).unwrap();
    assert_eq!(x.layers.len(), 1);
    assert_eq!(x.layers[0].target, "vda");
    assert_eq!(
        x.layers[0].file.as_deref(),
        Some("/var/lib/libvirt/images/sbxe2e-r.1790417094")
    );
}

/// A `virsh` and a `qemu-img` for the chain script: the domain's disks, and
/// every path handed to `qemu-img` logged so the test sees it arrive whole.
#[cfg(unix)]
fn chain_stub(tag: &str) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_chain_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    for (name, body) in [
        (
            "virsh",
            r#"#!/bin/sh
log="$(dirname "$0")/log"
for a in "$@"; do printf '%s\n' "$a" >> "$log"; done
echo --- >> "$log"
cat >> "$(dirname "$0")/stdin"
[ "$1 $2" = "--connect qemu:///system" ] || exit 9
shift 2
[ "$1" = "-q" ] && shift
case "$1" in
  dumpxml) cat <<'XML'
<domain><devices><disk type='file' device='disk'><source file="/var/lib/libvirt/images/evil's.qcow2"/><target dev='vda' bus='virtio'/></disk><disk type='file' device='disk'><source file="/p/a  b *.qcow2"/><target dev='vdb' bus='virtio'/></disk><disk type='file' device='cdrom'><target dev='sda' bus='sata'/></disk></devices></domain>
XML
  ;;
  domblklist) printf ' Type   Device   Target   Source\n--------------------------------------------\n file   disk     vda      /var/lib/libvirt/images/evil'\''s.qcow2\n file   disk     vdb      /p/a  b *.qcow2\n file   cdrom    sda      -\n' ;;
  *) : ;;
esac
"#,
        ),
        (
            "qemu-img",
            r#"#!/bin/sh
log="$(dirname "$0")/log"
for a in "$@"; do printf '%s\n' "$a" >> "$log"; done
echo --- >> "$log"
cat >> "$(dirname "$0")/stdin"
case "$5" in
  */a*) echo "qemu-img: Could not open '$5': Permission denied" >&2; exit 1 ;;
esac
printf '[{"filename": "%s", "format": "qcow2", "virtual-size": 1024, "actual-size": 512}]\n' "$5"
"#,
        ),
    ] {
        use std::os::unix::fs::PermissionsExt;
        let p = d.join(name);
        std::fs::write(&p, body).unwrap();
        std::fs::set_permissions(&p, std::fs::Permissions::from_mode(0o755)).unwrap();
    }
    d
}

#[cfg(unix)]
#[test]
fn chain_script_under_sh_keeps_a_hostile_path_whole() {
    let d = chain_stub("ok");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let chain = virt_snapshot::parse_snap_chain(&run_sh(
        &virt_snapshot::snap_chain_script("evil"),
        &path,
    ))
    .unwrap();
    // A CD-ROM is not a chain: two disks, each with the file it names
    let disks: Vec<_> = chain.disks_iter().collect();
    assert_eq!(disks.len(), 2);
    assert_eq!(disks[0].target, "vda");
    assert_eq!(disks[0].error, None);
    assert_eq!(disks[0].files[0].format.as_deref(), Some("qcow2"));
    // qemu-img's refusal (rc 1) is kept in its words, for the path whole
    assert_eq!(disks[1].target, "vdb");
    assert_eq!(disks[1].files[0].path, "/p/a  b *.qcow2");
    assert_eq!(
        disks[1].error.as_deref(),
        Some("qemu-img: Could not open '/p/a  b *.qcow2': Permission denied")
    );
    let why = virt_snapshot::external_snapshot_refusal(&chain).unwrap();
    assert!(why.starts_with("disk vdb: ") && why.contains("Permission denied"), "{why}");
    assert_eq!(virt_snapshot::snapshot_refusal(&chain), None);
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains("info\n-U\n--backing-chain\n--output=json\n"), "{log}");
    // The path with a quote in it arrives as one argument
    assert!(
        log.contains("/var/lib/libvirt/images/evil's.qcow2\n---\n"),
        "{log}"
    );
    // Spaces kept, the `*` not globbed
    assert!(log.contains("/p/a  b *.qcow2\n---\n"), "{log}");
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert_eq!(std::fs::read_to_string(d.join("stdin")).unwrap(), "");
    let _ = std::fs::remove_dir_all(&d);
}

#[cfg(unix)]
#[test]
fn external_snapshot_script_under_sh_keeps_a_hostile_name_whole() {
    let d = chain_stub("ext");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let evil = "it's \"odd\" $(touch pwned) `touch pwned`";
    let out = run_sh(
        &virt_snapshot::snapshot_external_script(
            evil,
            evil,
            Some(evil),
            &[
                ("vda".into(), format!("/p/{evil}.qcow2")),
                ("vdb".into(), "/srv/vm,images/disk.snap".into()),
            ],
        ),
        &path,
    );
    // The stub's `virsh` takes no `snapshot-create-as`, so the action section
    // is the status line alone; what is checked is what reached `virsh`
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("snapshot-create-as\n--domain\n{evil}\n")), "{log}");
    assert!(log.contains(&format!("--name\n{evil}\n")), "{log}");
    assert!(log.contains(&format!("--diskspec\nvda,file=/p/{evil}.qcow2,snapshot=external\n")), "{log}");
    // A comma in the path is virsh's escaped `,,`, not a new field.
    assert!(log.contains("--diskspec\nvdb,file=/srv/vm,,images/disk.snap,snapshot=external\n"), "{log}");
    assert!(!d.join("pwned").exists() && !std::path::Path::new("pwned").exists());
    assert!(out.contains(&format!("{}{}\n", virt::RC_PREFIX, 0)), "{out}");
    let _ = std::fs::remove_dir_all(&d);
}

#[test]
fn snap_diff_reads_only_meaningful_changes() {
    let diff = virt_snapshot::parse_snap_diff(&fixture("script_snap_diff.txt")).unwrap();
    // The captured change: vCPUs 1 -> 2, memory 256 -> 512 MiB, a NIC model
    // virtio -> e1000e. The snapshot's own definition is the `<domain>` of
    // `snapshot-dumpxml`, and `dumpxml --inactive` is the guest's now.
    assert_eq!(
        diff.iter()
            .map(|d| (d.group.as_str(), d.key.as_str()))
            .collect::<Vec<_>>(),
        [
            ("cpu", "vcpu"),
            ("memory", "memory"),
            ("interfaces", "52:54:00:2e:3d:88"),
        ]
    );
    let vcpu = &diff[0];
    assert_eq!((vcpu.before.as_deref(), vcpu.after.as_deref()), (Some("1"), Some("2")));
    assert!(!vcpu.added && !vcpu.removed);
    let mem = &diff[1];
    assert_eq!(
        (mem.before.as_deref(), mem.after.as_deref()),
        (Some("262144"), Some("524288"))
    );
    let nic = &diff[2];
    assert!(nic.added && nic.before.is_none());
    assert_eq!(nic.after.as_deref(), Some("e1000e · network=default"));
    // A disk's own file is never a configuration change: an external snapshot
    // moves the guest onto an overlay. No disk row, then.
    assert!(!diff.iter().any(|d| d.group == "disks"));
    assert_expected(&diff, "snap_diff.expected.json");
}

#[test]
fn snap_diff_of_the_same_definition_is_empty() {
    let xml = fixture("dumpxml_cirros_run_inactive.xml");
    assert_eq!(virt_snapshot::diff_domain_xml(&xml, &xml), Vec::new());
    // Two reads of one definition differ in what libvirt writes itself
    // (aliases, addresses, the running `index=`): none of it is a change.
    let running = fixture("dumpxml_cirros_run.xml");
    let quiet = virt_snapshot::diff_domain_xml(&running, &xml);
    assert!(
        quiet.iter().all(|d| matches!(d.group.as_str(), "disks" | "interfaces" | "boot" | "other")),
        "{quiet:?}"
    );
    // Nothing to compare at all is an empty list, not a failure.
    assert_eq!(virt_snapshot::diff_domain_xml("", ""), Vec::new());
    assert_eq!(virt_snapshot::diff_domain_xml("<domainsnapshot/>", "<domain/>"), Vec::new());
}

#[test]
fn snap_diff_tells_namesake_devices_apart() {
    let dom = |devices: &str| format!("<domain><devices>{devices}</devices></domain>");
    let root = "<controller type='pci' index='0' model='pcie-root'/>";
    let port = "<controller type='pci' index='1' model='pcie-root-port'/>";
    let usb = |bus: &str| {
        format!("<hostdev mode='subsystem' type='usb'><source><address bus='{bus}' device='2'/></source></hostdev>")
    };
    let before = format!("<domainsnapshot>{}</domainsnapshot>", dom(root));
    // A second PCI controller: its own key, not folded into the first
    let diff = virt_snapshot::diff_domain_xml(&before, &dom(&format!("{root}{port}")));
    assert_eq!(diff.len(), 1, "{diff:?}");
    assert_eq!(diff[0].key, "controller:pci:1");
    assert!(diff[0].added);
    // A second USB device: counted, not overwritten
    let before = format!("<domainsnapshot>{}</domainsnapshot>", dom(&usb("1")));
    let diff = virt_snapshot::diff_domain_xml(&before, &dom(&format!("{}{}", usb("1"), usb("3"))));
    assert_eq!(diff.len(), 1, "{diff:?}");
    assert_eq!(diff[0].key, "hostdev:usb#2");
    assert!(diff[0].added);
}

/// A device changed in place is a change: a controller's model, a passed-
/// through device's source, a CPU mode that names no model.
#[test]
fn snap_diff_reads_a_device_modified_in_place() {
    let snap = |inner: &str| format!("<domainsnapshot><domain>{inner}</domain></domainsnapshot>");
    let dom = |inner: &str| format!("<domain>{inner}</domain>");
    let devs = |d: &str| format!("<devices>{d}</devices>");
    let one = |before: &str, after: &str| {
        let diff = virt_snapshot::diff_domain_xml(&snap(before), &dom(after));
        assert_eq!(diff.len(), 1, "{before} → {after}: {diff:?}");
        diff.into_iter().next().unwrap()
    };
    let d = one(
        &devs("<controller type='usb' index='0' model='ich9-ehci1'/>"),
        &devs("<controller type='usb' index='0' model='qemu-xhci'/>"),
    );
    assert_eq!((d.group.as_str(), d.key.as_str()), ("other", "controller:usb:0"));
    assert!(d.before.unwrap().contains("ich9-ehci1") && d.after.unwrap().contains("qemu-xhci"));
    let usb = |bus: &str| {
        format!("<hostdev mode='subsystem' type='usb'><source><address bus='{bus}' device='2'/></source></hostdev>")
    };
    let d = one(&devs(&usb("1")), &devs(&usb("3")));
    assert_eq!(d.key, "hostdev:usb");
    // Named by vendor and product: the address a running guest's definition
    // adds is not a change.
    let named = |addr: &str| {
        format!(
            "<hostdev mode='subsystem' type='usb'><source><vendor id='0x1d6b'/><product id='0x0002'/>{addr}</source></hostdev>"
        )
    };
    assert_eq!(
        virt_snapshot::diff_domain_xml(
            &snap(&devs(&named("<address bus='1' device='4'/>"))),
            &dom(&devs(&named("")))
        ),
        vec![]
    );
    let d = one(
        &devs("<video><model type='vga' vram='16384' heads='1' primary='yes'/></video>"),
        &devs("<video><model type='virtio' heads='1' primary='yes'/></video>"),
    );
    assert_eq!(d.key, "video:video");
    let d = one(
        &devs("<tpm model='tpm-tis'><backend type='emulator' version='1.2'/></tpm>"),
        &devs("<tpm model='tpm-crb'><backend type='emulator' version='2.0'/></tpm>"),
    );
    assert_eq!(d.key, "tpm:tpm");
    // host-passthrough ↔ host-model: neither names a model.
    let d = one("<cpu mode='host-passthrough' check='none'/>", "<cpu mode='host-model'/>");
    assert_eq!((d.group.as_str(), d.key.as_str()), ("cpu", "model"));
    assert_eq!((d.before.as_deref(), d.after.as_deref()), (Some("host-passthrough"), Some("host-model")));
    let d = one(
        "<cpu mode='custom'><model fallback='forbid'>qemu64</model></cpu>",
        "<cpu mode='host-model'><model fallback='allow'>Skylake</model></cpu>",
    );
    assert_eq!(d.before.as_deref(), Some("qemu64 (forbid)"));
    assert_eq!(d.after.as_deref(), Some("host-model Skylake (allow)"));
}

#[test]
fn snap_diff_script_and_its_refusals() {
    let s = virt_snapshot::snap_diff_script("it's", "snap-1");
    assert!(
        s.contains("V snapshot-dumpxml --domain 'it'\\''s' --snapshotname 'snap-1'\n"),
        "{s}"
    );
    assert!(s.contains("V dumpxml --domain 'it'\\''s' --inactive\n"), "{s}");
    // Either half failing is the failure: no diff is "nothing changed".
    let raw = format!(
        "{}\n{}\n{}{}\n",
        script::cmd_marker(virt_snapshot::KEY_DIFF_SNAP),
        fixture("error_not_found.txt"),
        virt::RC_PREFIX,
        1
    );
    assert!(matches!(
        virt_snapshot::parse_snap_diff(&raw),
        Err(VirtError::DomainNotFound { .. })
    ));
    let raw = format!("{}\n", script::cmd_marker(virt::KEY_MISSING));
    assert_eq!(virt_snapshot::parse_snap_diff(&raw), Err(VirtError::NotInstalled));
}


/// Captured on libvirt 11.3 with AppArmor: a delete the profile would refuse
/// is refused before it is sent, running or shut off; one it allows is not.
#[test]
fn snap_delete_refused_where_apparmor_denies_the_commit() {
    let why = virt_snapshot::snap_delete_refusal(&fixture("script_snap_delete_running_denied.txt"))
        .unwrap()
        .unwrap();
    assert!(why.contains("writes into /var/lib/libvirt/sbxe2e-exp/ov1.qcow2"), "{why}");
    assert!(why.contains("#932456"), "{why}");

    let why = virt_snapshot::snap_delete_refusal(&fixture("script_snap_delete_shut_off.txt"))
        .unwrap()
        .unwrap();
    assert!(why.contains("shut off"), "{why}");
    assert!(why.contains("/var/lib/libvirt/sbxe2e-exp/ov1.qcow2"), "{why}");

    assert_eq!(
        virt_snapshot::snap_delete_refusal(&fixture("script_snap_delete_running_clear.txt")),
        Ok(None)
    );

    // A domain opted out of confinement is left to the host.
    let off = fixture("script_snap_delete_shut_off.txt");
    // In the domain's own definition, not the snapshot's copy of it.
    let at = off.find("SrvBoxSep.b64.dmlydC54bWw=").unwrap();
    let off = format!(
        "{}{}",
        &off[..at],
        off[at..].replacen("<devices>", "<seclabel type='none'/><devices>", 1)
    );
    assert_eq!(virt_snapshot::snap_delete_refusal(&off), Ok(None));
    // So is a host whose driver is not AppArmor.
    let selinux = fixture("script_snap_delete_shut_off.txt")
        .replace("<model>apparmor</model>", "<model>selinux</model>");
    assert_eq!(virt_snapshot::snap_delete_refusal(&selinux), Ok(None));
    // And a running domain whose profile could not be read.
    let unread = fixture("script_snap_delete_running_denied.txt");
    let at = unread.find("SrvBoxSep.b64.dmlydC5zbmFwLmRlbC5kZW55").unwrap();
    let unread = format!(
        "{}SrvBoxSep.b64.dmlydC5zbmFwLmRlbC5kZW55\nno profile\n\nSbVirtRc=1\n",
        &unread[..at]
    );
    assert_eq!(virt_snapshot::snap_delete_refusal(&unread), Ok(None));
}

/// `pool-capabilities` captured on a host whose daemon started before LVM
/// was installed: `logical` unsupported, so it is not offered.
#[test]
fn pool_types_are_the_ones_the_daemon_supports() {
    let caps = fixture("pool_capabilities.xml");
    let raw = |body: &str, rc: i32| format!("SrvBoxSep.b64.dmlydC5wb29sLmNhcHM=\n{body}\n\nSbVirtRc={rc}\n");
    assert!(virt::pool_types_script().contains("V pool-capabilities\n"));
    assert_eq!(virt::parse_pool_types(&raw(&caps, 0)), Some(vec!["dir".to_string(), "netfs".to_string()]));
    let all = caps.replace("type='logical' supported='no'", "type='logical' supported='yes'");
    assert_eq!(
        virt::parse_pool_types(&raw(&all, 0)),
        Some(vec!["dir".to_string(), "netfs".to_string(), "logical".to_string()])
    );
    // A libvirt before 5.2 has no such command: it cannot say.
    assert_eq!(virt::parse_pool_types(&raw("error: unknown command: 'pool-capabilities'", 1)), None);
    assert_eq!(virt::parse_pool_types(&raw("<capabilities/>", 0)), None);
}

/// A snapshot on a branch the guest left (captured: `i1` internal, `m2`
/// external over it, then a revert to `i1`): libvirt deletes it and keeps
/// its overlay, which is named to be deleted with it. On the chain, nothing
/// is: the commit libvirt makes takes care of it.
#[test]
fn snap_delete_names_the_overlay_libvirt_leaves_off_the_chain() {
    let raw = fixture("script_snap_delete_off_chain.txt");
    assert_eq!(
        virt_snapshot::snap_delete_leftovers(&raw),
        Ok(vec!["/var/lib/libvirt/sbxe2e-exp/ov2.qcow2".to_string()])
    );
    // Off the chain, nothing is committed: no refusal either.
    assert_eq!(virt_snapshot::snap_delete_refusal(&raw), Ok(None));
    for on_chain in [
        "script_snap_delete_running_denied.txt",
        "script_snap_delete_shut_off.txt",
        "script_snap_delete_running_clear.txt",
    ] {
        assert_eq!(virt_snapshot::snap_delete_leftovers(&fixture(on_chain)), Ok(vec![]), "{on_chain}");
    }
    // A chain that could not be read: a file on it would look off it.
    let from = raw.find("SrvBoxSep.b64.dmlydC5zbmFwLmNoYWlu").unwrap();
    let to = raw.find("SrvBoxSep.b64.dmlydC5zbmFwLmRlbC5pbmZv").unwrap();
    let unread = format!(
        "{}SrvBoxSep.b64.dmlydC5zbmFwLmNoYWlu\n/var/lib/libvirt/sbxe2e-exp/base.qcow2\n\
         qemu-img: Could not open: Permission denied\n\nSbVirtRc=1\n{}",
        &raw[..from],
        &raw[to..]
    );
    assert_eq!(virt_snapshot::snap_delete_leftovers(&unread), Ok(vec![]));
}

/// The part of `raw` from the section `from` up to the section `to`.
fn cut_sections(raw: &str, from: &str, to: &str) -> (usize, usize) {
    let at = |k: &str| raw.find(&script::cmd_marker(k)).unwrap_or_else(|| panic!("{k}"));
    (at(from), at(to))
}

/// The leftovers are deleted, so an incomplete chain answer names none: a
/// snapshot whose layer is `ov1` — the running guest's backing file — must
/// never be named when the chain that shows it in use was not read.
#[test]
fn snap_delete_leftovers_fail_closed_on_an_incomplete_chain() {
    // The captured running guest on ov2 → ov1 → base, and a snapshot whose
    // layer is ov1, which is on that chain.
    let raw = fixture("script_snap_delete_running_denied.txt").replacen(
        "<source file='/var/lib/libvirt/sbxe2e-exp/ov2.qcow2'/>",
        "<source file='/var/lib/libvirt/sbxe2e-exp/ov1.qcow2'/>",
        1,
    );
    assert_eq!(virt_snapshot::snap_delete_leftovers(&raw), Ok(vec![]));
    // `domblklist` failed (its status is not kept): no chain section, and the
    // definition names only the top file.
    let (from, to) = cut_sections(&raw, virt_snapshot::KEY_SNAP_CHAIN, virt_snapshot::KEY_DEL_INFO);
    let no_list = format!("{}{}", &raw[..from], &raw[to..]);
    assert_eq!(virt_snapshot::snap_delete_leftovers(&no_list), Ok(vec![]));
    // `dumpxml` refused as well.
    let (from, to) = cut_sections(&no_list, virt::KEY_XML, virt_snapshot::KEY_DEL_INFO);
    let no_xml = format!(
        "{}{}{}",
        &no_list[..from],
        section(virt::KEY_XML, "error: failed to get domain 'x'", 1),
        &no_list[to..]
    );
    assert_eq!(virt_snapshot::snap_delete_leftovers(&no_xml), Ok(vec![]));
    // A disk `domblklist` is not asked about (not a regular file) has no
    // answer, so its chain is unknown.
    let block = raw.replacen(
        "<emulator>/usr/bin/qemu-system-x86_64</emulator>",
        "<emulator>/usr/bin/qemu-system-x86_64</emulator>\
         <disk type='block' device='disk'><source dev='/dev/vg/vdb'/><target dev='vdb'/></disk>",
        3,
    );
    let off = block.replacen(
        "<source file='/var/lib/libvirt/sbxe2e-exp/ov1.qcow2'/>",
        "<source file='/var/lib/libvirt/sbxe2e-exp/gone.qcow2'/>",
        1,
    );
    assert_eq!(virt_snapshot::snap_delete_leftovers(&off), Ok(vec![]));
    // The same with the block disk gone: the off-chain file is named.
    let off = raw.replacen(
        "<source file='/var/lib/libvirt/sbxe2e-exp/ov1.qcow2'/>",
        "<source file='/var/lib/libvirt/sbxe2e-exp/gone.qcow2'/>",
        1,
    );
    assert_eq!(
        virt_snapshot::snap_delete_leftovers(&off),
        Ok(vec!["/var/lib/libvirt/sbxe2e-exp/gone.qcow2".to_string()])
    );
    // A chain that does not end in a base (its last layer still names a
    // backing file) is not a whole one.
    let (from, to) = cut_sections(&off, virt_snapshot::KEY_SNAP_CHAIN, virt_snapshot::KEY_DEL_INFO);
    let json = r#"[{"filename": "/var/lib/libvirt/sbxe2e-exp/ov2.qcow2", "format": "qcow2", "full-backing-filename": "/var/lib/libvirt/sbxe2e-exp/ov1.qcow2", "backing-filename-format": "qcow2"}]"#;
    let cut = format!(
        "{}{}{}",
        &off[..from],
        section(virt_snapshot::KEY_SNAP_CHAIN, &format!("/var/lib/libvirt/sbxe2e-exp/ov2.qcow2\n{json}\n"), 0),
        &off[to..]
    );
    assert_eq!(virt_snapshot::snap_delete_leftovers(&cut), Ok(vec![]));
}

/// A header may record its backing file relative to the overlay's
/// directory (`qemu-img create -b ov1.qcow2`); the chain carries the path
/// QEMU opens, so it matches the profile's absolute `deny` entries.
#[test]
fn snap_chain_backing_is_the_absolute_path() {
    let raw = fixture("script_snap_delete_running_denied.txt")
        .replace(
            "\"backing-filename\": \"/var/lib/libvirt/sbxe2e-exp/ov1.qcow2\"",
            "\"backing-filename\": \"ov1.qcow2\"",
        )
        .replace(
            "\"backing-filename\": \"/var/lib/libvirt/sbxe2e-exp/base.qcow2\"",
            "\"backing-filename\": \"base.qcow2\"",
        );
    let why = virt_snapshot::snap_delete_refusal(&raw).unwrap().unwrap();
    assert!(why.contains("/var/lib/libvirt/sbxe2e-exp/ov1.qcow2"), "{why}");
    // Without `full-backing-filename` (an older qemu-img), the relative name
    // is resolved against the overlay's directory.
    let old = raw
        .lines()
        .filter(|l| !l.contains("\"full-backing-filename\""))
        .collect::<Vec<_>>()
        .join("\n");
    let chain = virt_snapshot::parse_snap_chain(&old).unwrap();
    let files = &chain.disks[0].files;
    assert_eq!(files[0].backing.as_deref(), Some("/var/lib/libvirt/sbxe2e-exp/ov1.qcow2"));
    assert_eq!(files[1].backing.as_deref(), Some("/var/lib/libvirt/sbxe2e-exp/base.qcow2"));
    assert!(virt_snapshot::snap_delete_refusal(&old).unwrap().is_some());
}

/// The delete under sh with a stub virsh: the leftovers go after the
/// snapshot, through their pool refreshed first; a refused snapshot delete
/// deletes none of them, and a refused file delete is named.
#[cfg(unix)]
#[test]
fn snapshot_delete_deletes_the_leftovers_after_the_snapshot() {
    let d = create_stub("snapdel");
    let path = format!("{}:/usr/bin:/bin", d.display());
    let stub = |from: &str, to: &str| {
        let f = d.join("virsh");
        let text = std::fs::read_to_string(&f).unwrap().replace(from, to);
        std::fs::write(&f, text).unwrap();
    };
    stub("start|vol-delete|undefine)", "start|vol-delete|undefine|snapshot-delete|pool-refresh)");
    let script = virt::snapshot_delete_script(
        "vm",
        "m 2",
        &["p o".to_string()],
        &["/p o/vm.m 2".to_string()],
    )
    .unwrap();
    assert_eq!(virt::parse_snapshot_delete(&run_sh(&script, &path)), Ok(()));
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    let del = log.find("snapshot-delete\n--domain\nvm\n--snapshotname\nm 2\n").unwrap();
    let refresh = log.find("pool-refresh\n--pool\np o\n").unwrap();
    let vol = log.find("vol-delete\n--vol\n/p o/vm.m 2\n").unwrap();
    assert!(del < refresh && refresh < vol, "{log}");

    // A refused file delete: the snapshot is gone, the file is named.
    stub("|vol-delete|", "|");
    let err = virt::parse_snapshot_delete(&run_sh(&script, &path)).unwrap_err();
    assert!(
        matches!(&err, VirtError::Command { message } if message.contains("1 file(s)") && message.contains("unexpected vol-delete")),
        "{err:?}"
    );

    // A refused snapshot delete: nothing after it runs.
    std::fs::remove_file(d.join("log")).unwrap();
    stub("|snapshot-delete|", "|");
    assert!(virt::parse_snapshot_delete(&run_sh(&script, &path)).is_err());
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(!log.contains("vol-delete") && !log.contains("pool-refresh"), "{log}");
}

/// The check script under sh: a hostile name stays one word, and only the
/// profile's `deny` lines are printed.
#[test]
fn snap_check_script_quotes_and_filters() {
    let s = virt_snapshot::snap_check_script("vm'x", "a b'c");
    assert!(s.contains("snapshot-dumpxml --domain 'vm'\\''x' --snapshotname 'a b'\\''c'"), "{s}");
    assert!(s.contains("grep -F 'deny \"'"), "{s}");
    // The app names a domain by its UUID, which `domuuid` refuses (captured:
    // `failed to get domain '<uuid>'`); the profile's UUID comes from
    // `dominfo`.
    assert!(!s.contains("domuuid"), "{s}");
    assert!(s.contains("sed -n 's/^UUID: *//p'"), "{s}");
}

// ---------------------------------------------------------------------------
// Network editing: what the scripts do when a step is refused
// ---------------------------------------------------------------------------

/// A fake virsh for the network scripts: logs each command, prints the
/// definition it was given for `net-dumpxml`, and refuses the commands
/// listed one per line in `fail`.
#[cfg(unix)]
fn net_stub(tag: &str, base: &str, fail: &[&str]) -> PathBuf {
    let d = std::env::temp_dir().join(format!("sbm_virt_net_{tag}_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    std::fs::write(d.join("base.xml"), base).unwrap();
    std::fs::write(d.join("fail"), fail.join("\n") + "\n").unwrap();
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
shift 3
echo "$1" >> "$dir/log"
if grep -qx "$1" "$dir/fail"; then echo "error: $1 refused" >&2; exit 1; fi
case "$1" in
  net-dumpxml) cat "$dir/base.xml" ;;
esac
"#;
    let path = d.join("virsh");
    std::fs::write(&path, stub).unwrap();
    Command::new("chmod").arg("+x").arg(&path).status().unwrap();
    d
}

#[cfg(unix)]
fn net_edit_op(base: &str, restart: bool) -> sbm_virt::libvirt::net::VirtNetOp {
    let mut edit = sbm_virt::libvirt::net::VirtNetEdit {
        mode: "nat".into(),
        ..Default::default()
    };
    edit.address = Some("10.30.0.1".into());
    edit.prefix = Some(24);
    sbm_virt::libvirt::net::VirtNetOp::Edit {
        name: "lab".into(),
        edit,
        base_xml: base.into(),
        active: true,
        restart,
        force_restart: false,
    }
}

/// A restart never leaves the network down on a refusal: a definition the
/// host refuses stops everything before the network is stopped, and a start
/// that fails is answered by the old definition and a `net-create` of the
/// running network's own XML.
#[cfg(unix)]
#[test]
fn a_network_restart_is_undone_on_every_refusal() {
    use sbm_virt::libvirt::net::{net_change_script, parse_net_change};
    let base = "<network>\n  <name>lab</name>\n  <forward mode='nat'/>\n  <ip address='10.20.0.1' prefix='24'/>\n</network>";
    let log = |d: &PathBuf| std::fs::read_to_string(d.join("log")).unwrap_or_default();
    let script = net_change_script(&net_edit_op(base, true)).unwrap();

    // Everything goes through.
    let d = net_stub("ok", base, &[]);
    let path = format!("{}:/usr/bin:/bin", d.display());
    assert_eq!(parse_net_change(&run_sh(&script, &path)), Ok(()));
    assert_eq!(log(&d), "net-dumpxml\nnet-dumpxml\nnet-define\nnet-destroy\nnet-start\n");

    // The new definition refused: nothing is stopped.
    let d = net_stub("define", base, &["net-define"]);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let e = parse_net_change(&run_sh(&script, &path)).unwrap_err();
    assert!(e.message().contains("net-define refused"), "{e:?}");
    assert!(!log(&d).contains("net-destroy"), "{}", log(&d));

    // The start refused: the old definition back, the running XML created.
    let d = net_stub("start", base, &["net-start"]);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let e = parse_net_change(&run_sh(&script, &path)).unwrap_err();
    assert!(e.message().contains("started again as it ran before"), "{e:?}");
    assert_eq!(
        log(&d),
        "net-dumpxml\nnet-dumpxml\nnet-define\nnet-destroy\nnet-start\nnet-define\nnet-create\n"
    );

    // ... and the way back refused too: said so, not hidden.
    let d = net_stub("down", base, &["net-start", "net-create"]);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let e = parse_net_change(&run_sh(&script, &path)).unwrap_err();
    assert!(e.message().contains("it is down"), "{e:?}");

    // A restart of its own: the same way back, with no definition written.
    let restart = net_change_script(&sbm_virt::libvirt::net::VirtNetOp::Restart {
        name: "lab".into(),
        base_xml: base.into(),
    })
    .unwrap();
    let d = net_stub("restart", base, &["net-start"]);
    let path = format!("{}:/usr/bin:/bin", d.display());
    let e = parse_net_change(&run_sh(&restart, &path)).unwrap_err();
    assert!(e.message().contains("started again as it ran before"), "{e:?}");
    assert_eq!(log(&d), "net-dumpxml\nnet-dumpxml\nnet-destroy\nnet-start\nnet-create\n");
    let _ = std::fs::remove_dir_all(&d);
}

/// Secure Boot in the create form: both firmware features on, so libvirt
/// autoselects a firmware with the vendor's keys, and SMM with them. Off, or
/// on BIOS, it is what it always was.
#[test]
fn create_with_secure_boot() {
    let mut spec = create_spec("sb");
    spec.efi = true;
    let off = virt::domain_xml(&spec);
    assert!(off.contains("<feature enabled='no' name='secure-boot'/>"), "{off}");
    assert!(!off.contains("<smm"), "{off}");
    spec.secure_boot = true;
    let on = virt::domain_xml(&spec);
    assert!(on.contains("<feature enabled='yes' name='enrolled-keys'/><feature enabled='yes' name='secure-boot'/>"), "{on}");
    assert!(on.contains("<smm state='on'/>"), "{on}");
    // What the hardware view reads back from it.
    let hw = virt::parse_hw_xml(&on, &[]).unwrap();
    assert!(hw.efi && hw.secure_boot);
    assert!(virt::define_script(&spec).is_ok());
    // Without UEFI, or on a machine without SMM: refused before a host.
    spec.efi = false;
    assert!(virt::define_script(&spec).is_err());
    spec.efi = true;
    spec.host.machine = "pc-i440fx-10.0".into();
    assert!(virt::define_script(&spec).is_err());
}

/// A revert on an AppArmor host puts the guest on a new file named without
/// a known extension beside the kept one: outside the directories
/// `virt-aa-helper` reads any name in, it would not start. The captured
/// chains are in `/var/lib/libvirt/sbxe2e-exp`, which is outside them.
#[test]
fn snap_revert_refused_where_apparmor_cannot_read_the_new_file() {
    for f in ["script_snap_delete_running_denied.txt", "script_snap_delete_shut_off.txt"] {
        let why = virt_snapshot::snap_revert_refusal(&fixture(f)).unwrap().unwrap();
        assert!(why.contains("beside /var/lib/libvirt/sbxe2e-exp/"), "{f}: {why}");
        // Moved into the default pool's directory: nothing to refuse.
        let images = fixture(f).replace("/var/lib/libvirt/sbxe2e-exp/", "/var/lib/libvirt/images/sbxe2e-exp/");
        assert_eq!(virt_snapshot::snap_revert_refusal(&images), Ok(None), "{f}");
        // Another security driver: nothing to refuse either.
        let selinux = fixture(f)
            .replace("Security model: apparmor", "Security model: selinux")
            .replace("<model>apparmor</model>", "<model>selinux</model>");
        assert_eq!(virt_snapshot::snap_revert_refusal(&selinux), Ok(None), "{f}");
    }
    // Under /srv, /opt, a home directory: read whatever the name.
    for dir in ["/srv/vms/", "/opt/vm/", "/home/me/vms/", "/root/vms/"] {
        let moved = fixture("script_snap_delete_running_clear.txt").replace("/var/lib/libvirt/sbxe2e-exp/", dir);
        assert_eq!(virt_snapshot::snap_revert_refusal(&moved), Ok(None), "{dir}");
    }
}

/// Memory past the running guest's maximum is a change for the next start:
/// the live `setmem` is not asked for (libvirt would refuse it), and within
/// it the balloon takes the change live.
#[cfg(unix)]
#[test]
fn memory_past_the_running_maximum_waits_for_the_next_start() {
    let d = std::env::temp_dir().join(format!("sbm_virt_mem_{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&d);
    std::fs::create_dir_all(&d).unwrap();
    let stub = r#"#!/bin/sh
dir="$(dirname "$0")"
shift 3
printf '%s ' "$@" >> "$dir/log"; echo >> "$dir/log"
case "$1" in
  dominfo) printf 'Name:           vm\nMax memory:     262144 KiB\nUsed memory:    262144 KiB\n' ;;
esac
"#;
    std::fs::write(d.join("virsh"), stub).unwrap();
    Command::new("chmod").arg("+x").arg(d.join("virsh")).status().unwrap();
    let path = format!("{}:/usr/bin:/bin", d.display());
    let run = |mib: u64| {
        let _ = std::fs::remove_file(d.join("log"));
        let change: virt::VirtHwChange =
            serde_json::from_value(serde_json::json!({"op": "memory", "memory_mib": mib})).unwrap();
        let script = virt::hardware_change_script("vm", true, None, &change).unwrap();
        let out = virt::parse_hardware_change(&run_sh(&script, &path)).unwrap();
        (out.live_error, std::fs::read_to_string(d.join("log")).unwrap())
    };
    let (err, log) = run(768);
    assert_eq!(err, None);
    assert!(log.contains("setmaxmem --domain vm --size 768MiB --config"), "{log}");
    assert!(!log.contains("--live"), "{log}");
    let (err, log) = run(128);
    assert_eq!(err, None);
    assert!(log.contains("setmem --domain vm --size 128MiB --live"), "{log}");
    let _ = std::fs::remove_dir_all(&d);
}

// ---------------------------------------------------------------------------
// The overview as the model has it (libvirt::host), ported from the app's
// `libvirt_backend_test.dart`.
// ---------------------------------------------------------------------------

mod host {
    use super::*;
    use sbm_virt::libvirt::host::{power_plan, view_of};
    use sbm_virt::model::{GuestState, HostKind, PowerAction};
    use sbm_virt::rates::RateTracker;
    use std::collections::BTreeSet;

    // Guests in the captured fixtures (libvirt 11.3.0).
    const RUN: &str = "8a2ed2a2-83e1-4c41-ad0a-a57d54d0d649"; // cirros-run
    const PAUSED: &str = "24a8bbc6-deaa-4be0-9699-a1d801faa927"; // cirros-paused
    const ODD: &str = "1438b9e3-f647-47ee-8ed2-6dbc3adccd68"; // it's-"odd"

    fn overview(stats: &str) -> virt::VirtOverview {
        let raw = [
            section(virt::KEY_VERSION, &fixture("version_libvirt11.txt"), 0),
            section(virt::KEY_LIST, &fixture("list_uuid_name.txt"), 0),
            section(virt::KEY_AUTOSTART, &fixture("list_autostart.txt"), 0),
            section(virt::KEY_PERSISTENT, &fixture("list_persistent.txt"), 0),
            section(virt::KEY_STATS, stats, 0),
        ]
        .concat();
        virt::parse_overview(&raw).unwrap()
    }

    fn set(a: &[PowerAction]) -> BTreeSet<PowerAction> {
        a.iter().copied().collect()
    }

    #[test]
    fn the_overview_maps_to_guests_states_and_actions() {
        let view = view_of(&overview(&fixture("domstats.txt")), &mut RateTracker::new(false), 0, None, false);
        assert_eq!(view.host.kind, HostKind::Libvirt);
        assert_eq!(view.host.version.as_deref(), Some("11.3.0"));
        assert_eq!(view.host.hypervisor.as_deref(), Some("QEMU 10.0.13"));
        assert!(!view.capabilities.lxc && view.capabilities.pause);
        assert_eq!(view.capabilities.pool_types, ["dir", "netfs", "logical"]);
        assert_eq!(view.guests.len(), 3);

        let web = view.guests.iter().find(|g| g.id == RUN).unwrap();
        assert_eq!(web.name, "cirros-run");
        assert_eq!(web.state, GuestState::Running);
        assert_eq!(web.vcpu, Some(2));
        assert_eq!(web.mem_bytes, Some(262_144 * 1024));
        assert_eq!(web.autostart, Some(true));
        use PowerAction::*;
        assert_eq!(web.actions, set(&[Shutdown, Reboot, ForceStop, Suspend]));

        let db = view.guests.iter().find(|g| g.id == PAUSED).unwrap();
        assert_eq!(db.state, GuestState::Paused);
        assert_eq!(db.actions, set(&[Resume, ForceStop]));

        let odd = view.guests.iter().find(|g| g.id == ODD).unwrap();
        assert_eq!(odd.state, GuestState::Stopped);
        assert_eq!(odd.state_reason.as_deref(), Some("failed"));
        assert_eq!(odd.actions, set(&[Start]));
    }

    #[test]
    fn rates_across_two_samples() {
        let mut rates = RateTracker::new(false);
        let stats = fixture("domstats.txt");
        let first = view_of(&overview(&stats), &mut rates, 0, None, false);
        let web = &first.stats[RUN];
        assert_eq!(web.cpu, None, "nothing to diff");
        assert_eq!(web.mem_used, Some((198_384 - 151_264) * 1024));

        let stats = stats
            // +2 s of CPU over 2 s on 2 vCPUs: 50 %.
            .replacen("cpu.time=7550532000", "cpu.time=9550532000", 1)
            .replacen("block.0.rd.bytes=26923008", "block.0.rd.bytes=28923008", 1)
            .replacen("net.0.rx.bytes=13386", "net.0.rx.bytes=23386", 1);
        let second = view_of(&overview(&stats), &mut rates, 2000, None, false);
        let web = &second.stats[RUN];
        assert!((web.cpu.unwrap() - 50.0).abs() < 1e-9, "{:?}", web.cpu);
        assert_eq!(web.disk_read, Some(1e6));
        assert_eq!(web.disk_write, Some(0.0));
        assert_eq!(web.net_in, Some(5000.0));
        assert_eq!(web.net_out, Some(0.0));
    }

    #[test]
    fn a_crashed_domain_is_destroyed_before_it_starts() {
        let view = view_of(&overview(&fixture("domstats.txt")), &mut RateTracker::new(false), 0, None, false);
        let mut odd = view.guests.into_iter().find(|g| g.id == ODD).unwrap();
        assert_eq!(power_plan(&odd, PowerAction::Start), Some(vec![virt::VirtAction::Start]));
        assert_eq!(power_plan(&odd, PowerAction::Shutdown), None, "not offered");
        odd.state_reason = Some("crashed".into());
        assert_eq!(
            power_plan(&odd, PowerAction::Start),
            Some(vec![virt::VirtAction::ForceStop, virt::VirtAction::Start])
        );
    }
}
