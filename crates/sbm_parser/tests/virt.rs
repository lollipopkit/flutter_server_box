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
    let probe = virt::parse_probe(&run_sh(&virt::probe_script(), &empty.display().to_string()));
    assert_eq!(probe, Ok(virt::VirtHostProbe::default()));
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
    assert!(virt::snapshot_delete_script("d", "-n").contains("V snapshot-delete --domain 'd' --snapshotname '-n'\n"));

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
    }
}

#[test]
fn create_host_prefers_kvm_and_q35() {
    let host = virt::parse_create_host(&fixture("script_create_host.txt")).unwrap();
    assert_eq!(
        host,
        virt::VirtCreateHost {
            domain_type: "kvm".into(),
            machine: "pc-q35-10.0".into(),
            arch: "x86_64".into(),
            max_vcpus: Some(4096),
        }
    );
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
        virt::parse_create_volume(&fixture("script_create_volume.txt")).unwrap(),
        "/var/lib/libvirt/images/sbm-create-test.qcow2"
    );
    // The name was defined already: nothing ran.
    assert_eq!(
        virt::parse_create_volume(&fixture("script_create_volume_exists.txt")),
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

    assert!(virt::undefine_script("vm", &["vda,sda".into()]).is_err());
    assert!(virt::undefine_script("vm", &["".into()]).is_err());
    let keep = virt::undefine_script("vm", &[]).unwrap();
    assert!(keep.contains("--keep-nvram") && !keep.contains("--storage"), "{keep}");
    let all = virt::undefine_script("vm", &["vda".into(), "vdb".into()]).unwrap();
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

    let vol = virt::parse_create_volume(&run_sh(&virt::create_volume_script(&spec).unwrap(), &path))
        .unwrap();
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
        virt::parse_create_volume(&run_sh(&virt::create_volume_script(&spec).unwrap(), &path)),
        Err(VirtError::Exists { message: String::new() })
    );
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(!log.contains("vol-create-as"), "{log}");

    let undefine = virt::undefine_script(name, &["vda".into()]).unwrap();
    assert_eq!(virt::parse_action(&run_sh(&undefine, &path)), Ok(()));
    let log = std::fs::read_to_string(d.join("log")).unwrap();
    assert!(log.contains(&format!("undefine\n--domain\n{name}\n--managed-save\n")), "{log}");
    let _ = std::fs::remove_dir_all(&d);
}
