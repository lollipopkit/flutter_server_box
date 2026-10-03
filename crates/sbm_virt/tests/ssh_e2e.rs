//! Opt-in end-to-end test of the libvirt command layer over real SSH.
//!
//! Configuration (ignored by default), via environment or a `.env` at the
//! workspace root: `SBM_E2E_SSH_HOST`, any destination the system `ssh`
//! accepts. Run with `cargo test -p sbm_virt --test ssh_e2e -- --ignored`.
//!
//! The SSH helpers are the ones in `sbm_parser`'s `tests/ssh_e2e.rs`.

use std::io::{Read, Write};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant};

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


/// Options every helper here passes to the system `ssh`.
///
/// `ConnectTimeout` bounds the TCP connect and the handshake and nothing after
/// them. Once a session is up, an unresponsive peer — the Windows host
/// suspending mid-test is the one seen — leaves the client waiting with no
/// limit at all: one such `ssh` was found still attached to the install step
/// sixteen hours later, long after the run that spawned it was gone. The
/// keepalive turns that into a failed test in ~15s, which is the only outcome
/// the suite can act on.
const SSH_OPTS: [&str; 8] = [
    "-o",
    "BatchMode=yes",
    "-o",
    "ConnectTimeout=10",
    "-o",
    "ServerAliveInterval=5",
    "-o",
    "ServerAliveCountMax=3",
];

/// How long any one remote command may take before the suite gives up on it.
///
/// The keepalive above only covers a peer that has stopped answering. A peer
/// that answers and still never finishes the command is the case actually
/// observed — the Windows install step, whose PowerShell reads stdin to EOF,
/// has been found sitting there with the connection alive. Whatever the remote
/// side of that is, an e2e test has to end, and a killed command that names
/// itself is the only ending the suite can report.
const SSH_TIMEOUT: Duration = Duration::from_secs(120);

/// Spawn `ssh <host> <arg>`, feed it `stdin` if given, and collect its output.
///
/// The write goes on its own thread because `wait_with_output` is what drains
/// stdout and stderr: writing the whole script first, as this used to, blocks
/// the moment the remote's output fills the local pipe buffer while the remote
/// blocks on the rest of the input. It has not bitten here only because the
/// commands given input print nothing.
fn run_ssh(host: &str, arg: &str, stdin: Option<&str>) -> Result<std::process::Output, String> {
    let mut child = Command::new("ssh")
        .args(SSH_OPTS)
        .args([host, arg])
        .stdin(if stdin.is_some() {
            Stdio::piped()
        } else {
            Stdio::null()
        })
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| format!("failed to spawn ssh: {e}"))?;
    // Dropping the pipe closes it, which is the EOF the remote reader waits on
    let writer = stdin.map(|input| {
        let mut pipe = child.stdin.take().expect("stdin piped");
        let input = input.to_owned();
        std::thread::spawn(move || pipe.write_all(input.as_bytes()))
    });
    // Both drained while the command runs, which is what `wait_with_output`
    // did. Reading either one to the end first would deadlock on the other
    // filling, and reading neither until the child exits deadlocks on both.
    let reader = |mut pipe: Box<dyn Read + Send>| {
        std::thread::spawn(move || {
            let mut buf = Vec::new();
            pipe.read_to_end(&mut buf).map(|_| buf)
        })
    };
    let stdout = reader(Box::new(child.stdout.take().expect("stdout piped")));
    let stderr = reader(Box::new(child.stderr.take().expect("stderr piped")));

    // `try_wait` rather than `wait_with_output`, which consumes the `Child`:
    // the timeout has to kill *this* child, and a pid handed to a kill(1) after
    // the process is gone is a pid the OS may have given to something else.
    let deadline = Instant::now() + SSH_TIMEOUT;
    let status = loop {
        match child
            .try_wait()
            .map_err(|e| format!("ssh wait failed: {e}"))?
        {
            Some(status) => break Some(status),
            None if Instant::now() >= deadline => {
                let _ = child.kill();
                let _ = child.wait();
                break None;
            }
            None => std::thread::sleep(Duration::from_millis(50)),
        }
    };

    let collect = |handle: std::thread::JoinHandle<std::io::Result<Vec<u8>>>, which: &str| {
        handle
            .join()
            .map_err(|_| format!("ssh {which} reader panicked"))?
            .map_err(|e| format!("failed to read ssh {which}: {e}"))
    };
    let stdout = collect(stdout, "stdout")?;
    let stderr = collect(stderr, "stderr")?;

    // Before joining the writer: the kill is what unblocks it, and its broken
    // pipe is a consequence of the timeout rather than something to report
    let Some(status) = status else {
        return Err(format!(
            "ssh command {arg:?} killed after {}s",
            SSH_TIMEOUT.as_secs()
        ));
    };
    if let Some(writer) = writer {
        writer
            .join()
            .map_err(|_| "ssh stdin writer panicked".to_string())?
            .map_err(|e| format!("failed to write ssh stdin: {e}"))?;
    }
    Ok(std::process::Output {
        status,
        stdout,
        stderr,
    })
}

fn check_ssh(cmd: &str, out: std::process::Output) -> Result<String, String> {
    if !out.status.success() {
        return Err(format!(
            "ssh command {cmd:?} exited with {}: {}",
            out.status,
            String::from_utf8_lossy(&out.stderr)
        ));
    }
    Ok(String::from_utf8_lossy(&out.stdout).into_owned())
}

/// Run a command on the remote via the system ssh (BatchMode: never prompts).
/// `stdin` is piped to the remote command when given.
/// The command is wrapped in `sh -c` so POSIX syntax works regardless of the
/// remote login shell (fish/zsh would otherwise reject `if ...; fi` etc.)
fn ssh(host: &str, cmd: &str, stdin: Option<&str>) -> Result<String, String> {
    let quoted = format!("sh -c '{}'", cmd.replace('\'', r"'\''"));
    check_ssh(cmd, run_ssh(host, &quoted, stdin)?)
}


/// Feed a `virt` script to `sh` on stdin, as the app does (`entry: 'sh'`).
fn run_virt(host: &str, script: &str) -> String {
    let out = run_ssh(host, "sh", Some(script)).expect("run virt script");
    String::from_utf8_lossy(&out.stdout).into_owned()
}

/// libvirt command layer against a real host: probe, overview, per-domain
/// detail, and a power action aimed at a UUID that does not exist. No action
/// is ever run against a real domain. Hosts without `virsh` pass silently.
#[test]
#[ignore = "requires SBM_E2E_SSH_HOST and a reachable SSH server"]
fn ssh_e2e_virt() {
    use sbm_virt::libvirt::{self as virt, VirtError, VirtState};

    let host =
        ssh_host().expect("SBM_E2E_SSH_HOST must be set in the environment or workspace-root .env");

    let version = match virt::parse_probe(&run_virt(&host, &virt::probe_script())) {
        Ok(virt::VirtHostProbe { libvirt: Some(v), .. }) => v,
        Ok(p) => {
            eprintln!("virsh not installed on {host} ({p:?}); skipping");
            return;
        }
        Err(VirtError::PermissionDenied { message }) => {
            eprintln!("virsh refused this user on {host} ({message}); skipping");
            return;
        }
        Err(e) => panic!("probe failed: {e:?}"),
    };
    assert!(version.libvirt.is_some(), "{version:?}");

    let raw = run_virt(&host, &virt::overview_script());
    // Per-vCPU counters are filtered out on the host
    assert!(
        !raw.lines().any(|l| l.trim_start().starts_with("vcpu.0.")),
        "per-vCPU lines reached the app"
    );
    let overview = virt::parse_overview(&raw).expect("overview");
    assert_eq!(overview.version.as_ref(), Some(&version));

    // Same set of domains as a direct listing
    let direct = ssh(
        &host,
        "LC_ALL=C virsh --connect qemu:///system -q list --all --uuid",
        None,
    )
    .expect("direct list");
    let mut direct: Vec<String> = virt::parse_uuids(&direct);
    let mut got: Vec<String> = overview.domains.iter().map(|d| d.uuid.clone()).collect();
    direct.sort();
    got.sort();
    assert_eq!(got, direct);

    for dom in &overview.domains {
        // The numeric state agrees with virsh's own text for it
        let text = ssh(
            &host,
            &format!(
                "LC_ALL=C virsh --connect qemu:///system -q domstate --domain {}",
                dom.uuid
            ),
            None,
        )
        .expect("domstate");
        let expected = match text.trim() {
            "running" | "idle" => VirtState::Running,
            "shut off" | "crashed" => VirtState::Stopped,
            "in shutdown" => VirtState::Stopping,
            // The reason decides between these three
            "paused" | "pmsuspended" => {
                assert!(
                    matches!(
                        dom.state,
                        VirtState::Paused | VirtState::Starting | VirtState::Stopping
                    ),
                    "{}: {:?}",
                    dom.name,
                    dom.state
                );
                dom.state
            }
            other => panic!("unexpected domstate {other:?}"),
        };
        assert_eq!(dom.state, expected, "{}: {}", dom.name, text.trim());

        let detail = virt::parse_domain_detail(&run_virt(
            &host,
            &virt::domain_detail_script(&dom.uuid),
        ))
        .unwrap_or_else(|e| panic!("detail of {}: {e:?}", dom.name));
        assert_eq!(detail.xml.uuid.as_deref(), Some(dom.uuid.as_str()));
        assert_eq!(detail.xml.name.as_deref(), Some(dom.name.as_str()));
        // A paused guest's QEMU keeps its display; only an inactive one has none.
        if dom.state == VirtState::Stopped {
            assert!(detail.display.is_none());
        } else if dom.state == VirtState::Running
            && detail.xml.graphics.iter().any(|g| g.kind == "vnc" && g.socket.is_none()) {
            // A running TCP VNC display resolves to a real port
            let display = detail.display.as_ref().expect("running VNC display");
            assert_eq!(display.protocol, "vnc");
            assert!(display.port.is_some_and(|p| p >= 5900), "{display:?}");
        }
    }

    // A domain that is not there, asked read-only: a power action here
    // would start whatever the host has under this UUID.
    let missing = virt::parse_domain_detail(&run_virt(
        &host,
        &virt::domain_detail_script("00000000-0000-4000-8000-00000000e2e0"),
    ));
    assert!(
        matches!(missing, Err(VirtError::DomainNotFound { .. })),
        "{missing:?}"
    );

    // Read-only listings: snapshots of every domain, pools with each active
    // one's volumes, networks. Every domain's disks and NICs are listed.
    for dom in &overview.domains {
        virt::parse_snapshots(&run_virt(&host, &virt::snapshots_script(&dom.uuid)))
            .unwrap_or_else(|e| panic!("snapshots of {}: {e:?}", dom.name));
    }
    let storage = virt::parse_storage(&run_virt(&host, &virt::storage_script())).expect("storage");
    let with_disks: std::collections::BTreeSet<&str> =
        storage.disks.iter().map(|d| d.domain.as_str()).collect();
    for dom in overview.domains.iter().filter(|d| d.persistent) {
        assert!(with_disks.contains(dom.uuid.as_str()) || dom.counters.blocks.is_empty(), "{}", dom.name);
    }
    for pool in storage.pools.iter().filter(|p| p.active) {
        let names: Vec<String> = pool
            .volumes
            .as_ref()
            .expect("an active pool lists its volumes")
            .iter()
            .map(|v| v.name.clone())
            .collect();
        let vols = virt::parse_volumes(&run_virt(&host, &virt::volumes_script(&pool.name, &names)))
            .unwrap_or_else(|e| panic!("volumes of {}: {e:?}", pool.name));
        assert_eq!(vols.len(), names.len(), "{}", pool.name);
    }
    let nets = virt::parse_networks(&run_virt(&host, &virt::networks_script())).expect("networks");
    for n in nets.networks.iter().filter(|n| n.active) {
        assert!(n.bridge.is_some() || n.mode != "nat", "{}", n.name);
    }
}
