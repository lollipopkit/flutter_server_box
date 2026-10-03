# Virtualization tab

One tab — **Virtualization** (`AppTab.virt`, zh "虚拟化") — for QEMU/KVM guests
managed by libvirt and for Proxmox VE (QEMU VMs and LXC containers). It
replaces the PVE page (`lib/view/page/pve.dart`), which today is reachable
only from the server detail page's PVE readout card.

Design: Claude Design project `2a6eadf3-ac6c-4925-bb18-8f763a0c3ead`,
`KVM Manager.dc.html` (wide) and `KVM Manager Mobile.dc.html` (phone frames).

## Decisions

| Topic | Decision |
| --- | --- |
| Tab name | "Virtualization" / "虚拟化". Covers VMs, LXC containers, storage and networks; "VM" excludes LXC and "KVM" names one hypervisor. |
| Transports | SSH, monitor HTTP and local, for both backends. |
| PVE access | The PVE HTTP API (`/api2/json`), unchanged. Only the TCP connection to it changes: it is carried over whichever transport the server uses. |
| libvirt access | `virsh` run through `ServerExec`. libvirt has no HTTP API enabled by default, so there is nothing to tunnel. |
| PVE auth | Password (+ TOTP), as today, **plus API token** (`PVEAPIToken=user@realm!tokenid=secret`). New configurations are pointed at tokens. |
| Phase 1 scope | Tab, host switcher, guest list and state, power actions, overview (charts), console, IntroPage, migration of the old PVE entry. |
| Phase 2 scope | Snapshots (list, create, revert, delete) for both backends; Storage and Network sections, read-only: pools/storages with their volumes, networks/interfaces with the guests on them (managed since phase 6). |
| libvirt snapshots | Internal (`snapshot-create-as` without `--disk-only`): every writable disk must be qcow2, and an active domain's snapshot always holds its memory — QEMU refuses an internal one without it, so the form shows the memory switch on and fixed. External (disk-only) snapshots are phase 8; see that section. |
| Snapshot names | PVE's `pve-configid` rule (a letter, then letters, digits, `-`, `_`; 2–40), for both backends, and never `current` (PVE's "you are here" entry). A name never needs quoting to be read back. |

## Current PVE implementation (what is being migrated)

- `lib/data/provider/pve.dart` — `pveProvider(spi)`. Binds a loopback
  `ServerSocket`, forwards each accepted socket over
  `SSHClient.forwardLocal(pveAddr.host, pveAddr.port)`, and points Dio at it
  (TLS via `SecureSocket.secure`, `pveIgnoreCert` accepts any certificate).
  Requires an SSH client: a monitor-only server gets `pveServerClientMissing`.
- Login: `POST /access/ticket` (PAM realm, `spi.ssh.user`, `pvePwd` or the SSH
  password), TOTP via `tfa-challenge`. Calls: `/version`,
  `/cluster/resources`, `POST /nodes/{node}/{qemu|lxc}/{vmid}/status/{action}`.
- Models: `lib/data/model/server/pve.dart` (`PveRes`, `PveQemu`, `PveLxc`,
  `PveNode`, `PveStorage`, `PveSdn`). Errors: `PveErr` in
  `lib/data/model/app/error.dart`.
- Config: `server` table columns `pve_addr`, `pve_ignore_cert`, `pve_pwd`
  (`lib/data/store/db.dart`), surfaced as `ServerCustom.pveAddr/pveIgnoreCert/pvePwd`;
  editor group in `lib/view/page/server/edit/widget.dart` (`_buildPVEs`).
- Entry: `ServerDetailCards.pve` → `PvePage.route`.
- Tests: `test/unit/server/pve_test.dart` (parse fixture, expired sessions,
  client replacement), store round-trip, Hive/m017 migration tests.
- Nothing in `crates/` or `monitor/` knows about PVE or libvirt.

## Architecture

Two layers. The transport layer answers "how do bytes or commands reach this
machine"; the backend layer answers "what is a guest and what can be done to
it". The UI only talks to the backend layer.

```
UI (tab, lists, detail, console)
        │
VirtBackend (interface)  ── models: VirtHost, VirtGuest, VirtGuestState, VirtStats,
        │                            VirtConsole, capabilities
   ┌────┴─────────────┐
PveBackend         LibvirtBackend
(HTTP API)         (virsh via ServerExec)
   │                    │
ServerTcpDialer     ServerNotifier.ensureExec()
(SSH | monitor relay | direct)   (SshExec | MonitorExec | ProcessExec)
```

### Transport: `ServerTcpDialer`

Extract what remote desktop already does in
`lib/data/provider/remote_desktop.dart` (`_relayCapable`, `_tunnelOver`) into
one shared place (proposed `lib/core/utils/server_tcp.dart`):

| Credential | How a TCP connection to `host:port` is made | Capability |
| --- | --- | --- |
| `ServerConnectCredentialSsh` | `SSHClient.forwardLocal` (`SshLocalTunnel`) | always |
| `ServerConnectCredentialMonitorHttp` | `MonitorTunnelChannel` over `/api/v1/stream/ws`; the agent dials from its own machine | `caps.tcpRelay` (agent `stream` grant) |
| `ServerConnectCredentialLocal` | `Socket.connect` directly — this device is the host | always |

- Same fallback rule as `ensureExec()`: a server with both SSH and an agent
  tries the leading transport, then the other.
- `pveAddr` host names resolve on the far end (SSH and monitor) or on this
  device (local). The default `https://localhost:8006` is correct in all
  three.
- Remote desktop moves onto the shared dialer in the same change, so there is
  one implementation. Its `LocalCapabilities.tcpRelay == false` rule stays
  where it is (a remote desktop to this device is not offered); the dialer's
  local case is a direct socket, which is what PVE needs.
- Dio gets a `connectionFactory` from the dialer (`ServerTcpDialer.startConnect`).
  `SecureSocket` can only wrap a socket `dart:io` created, so for SSH and the
  relay each connection is a loopback socket pair bridged to the channel; the
  listener accepts that one socket and closes, so no port stays open. A local
  server gets a direct `Socket.connect`. `ServerTcpDialer.loopback` (built on
  `SshLocalTunnel.bindWithDialer`) is for consumers that need a port number
  (VNC client).
- **The loopback is authenticated.** A loopback port is open to every process
  on the device, and the first to connect used to get the remote end — a
  guest's console. `ServerTcpDialer.loopback` and
  `WebSocketTunnelChannel.loopbackOnce` now bind with `authenticated: true`:
  the tunnel draws a 32-byte token from `Random.secure()`, the remote desktop
  engine gets it in-process with the port (`RdpSessionParams`/
  `VncSessionParams.access_token`) and writes it first on the connection (VNC:
  `run_vnc`; RDP: `ConfigBuilder::with_tcp_preamble` in the vendored
  IronRDP's `connect_direct`), and the listener carries only a connection
  that presents it — read within 5 s, compared in constant time, before
  anything is dialled. Any other is dropped unread. `loopbackOnce` also stops
  listening once its one connection is through. The port-forward feature's
  `SshLocalTunnel.bind` is left open on purpose: it serves outside clients.
  Residual risk: a process that can read this app's memory, or sniff the
  loopback interface (root), can still take the token; both already own the
  session by other means.

### PVE TLS

`pveIgnoreCert` today disables verification completely. Replace it with
certificate pinning on first use, the same model as SSH host keys: the first
connection shows the certificate's SHA-256 fingerprint for confirmation and
stores it; later connections require the same certificate; a changed
certificate is an error with the old and new fingerprints.

- Stored per server (`server_pve.cert_sha256`).
- A server with `pve_ignore_cert = 1` is migrated to "pin on next connect".
- A CA-signed certificate that validates normally needs no pin.

### PVE auth

- Password: as today (PAM realm, `ssh.user`, `pvePwd` or the SSH password,
  TOTP challenge). Ticket + `CSRFPreventionToken` per session. PVE accepts a
  ticket and a TFA challenge for 2 hours, so the ticket is renewed after an
  hour (sent as the password, as PVE's web UI does; no second factor), a 401
  on a reused password session gets one new login and the request repeated,
  and `submitTfa` replaces a challenge past its lifetime before answering.
- API token: header `Authorization: PVEAPIToken=<user@realm!tokenid>=<secret>`.
  No ticket, no CSRF token, no TOTP; permissions are the token's.
- Stored in the encrypted database like the other server secrets
  (`server_pve.token_id`, `server_pve.token_secret`). Never logged; error messages name the
  token id, never the secret.
- The editor offers token first; the help text lists the minimum privileges
  (`VM.Audit`, `VM.PowerMgmt`, `VM.Console`, `Sys.Audit` on the paths the
  user wants shown; since phase 2 also `VM.Snapshot`, `VM.Snapshot.Rollback`
  and `Datastore.Audit`).
- An account that may see nothing is not refused: `/cluster/resources`
  answers the nodes' bare names and no guests (a privilege-separated token
  with no ACL of its own, verified on PVE 9.2). A load with no guests asks
  `/access/permissions`; with `VM.Audit` and `Sys.Audit` granted nowhere it
  is `permissionDenied`, carrying the `pveum acl modify / --tokens … --roles
  PVEAuditor,PVEVMAdmin` that fixes it (the two roles cover every privilege
  above).

### libvirt

- Run through `ensureExec()`: works over SSH, over an agent with the
  `full_access` grant (`caps.shell`), and locally.
- `virsh --connect qemu:///system` with `-q`; parse `list --all --uuid`,
  `dominfo`, `domstats --raw` (CPU time, balloon, block and net counters),
  `domdisplay`, `dumpxml` (phase 1: disks, NICs, graphics only).
- `qemu:///system` needs root or the `libvirt` group. A permission error runs
  the command again through `runWithSudo` (password on stdin); a user outside
  the group without sudo sees the error text and what to change.
- Command strings and output parsers live in `crates/sbm_virt` (module
  `libvirt`), per the repo's "test as spec" rule, so the monitor web panel can
  reuse them later. Fixtures are captured `virsh` output.

### Host detection

A server is a virtualization host when:

- **PVE**: it has a `server_pve` row. Explicit, as today.
- **libvirt**: `command -v virsh` succeeds through `ensureExec()`. Probed
  without being asked (the tab's first listing, pull-to-refresh) only where
  the server list is connected or connecting anyway (`VirtHosts.autoProbeable`);
  every other server only through "Check this server" / "Check all". Cached
  per server for the session. A server that has both is shown as PVE.

The probe (`sbm_virt::libvirt::probe_script`, one round trip) asks, in order:

1. `pveversion`. Present: the server runs PVE, nothing else is asked
   (`VirtProbeStatus.pve`). Without a `server_pve` row it is not a host yet —
   the switcher shows it as "PVE, not set up", and tapping it opens the
   server editor on its PVE group with `PveConfig.localAddr`
   (`https://127.0.0.1:8006`, resolved on the server's side of any
   transport) filled in. Saving the token makes it a host.
2. Whether the server is a container (`systemd-detect-virt -c`,
   `/run/systemd/container`, `openrc --sys` for Alpine,
   `/proc/1/environ` as root, Docker/Podman marker files). A container is a
   guest: its row says "LXC container" and that it is managed from its host.
3. `virsh version`, as before.

Verified on the PVE 9.2.2 host (PVE), its Alpine LXC 200 as root and as
`nobody` (`lxc`, from `openrc --sys`) and VM 100 (libvirt 11.3.0).

The host switcher lists hosts first and offers the other servers under
"Check this server" (runs the probe on demand), so a server is never hidden
because it was not probed yet.

### Models (`lib/data/model/virt/`)

- `VirtHostKind { pve, libvirt }`, `VirtHost { spiId, kind, version, node(s), cpu, mem }`.
- `VirtGuestKind { qemu, lxc }`.
- `VirtGuestState { running, paused, stopped, starting, stopping, rebooting, migrating, backup, unknown }`
  — the design's state set. Mapping: PVE `status` + `lock`, libvirt
  `domstate` + reason.
- `VirtGuest { id, name, kind, state, vmid?, node?, vcpu, memBytes, uptime, tags }`.
- `VirtStats` — CPU %, memory, disk read/write, net in/out, as rates; the
  charts reuse `MetricChart` and `ChartPalette`.
- `VirtCapabilities` per host — `lxc`, `pause`, `snapshots`,
  `snapshotMemoryRequired`, `storage`, `network`, `backup`, `cluster`,
  `serialConsole`, `vncConsole`, `termConsole`, `storedHistory`. The UI shows
  or hides by capability, never by `kind`.
- `virt_resources.dart`: `VirtGuestSnapshot` (parent, time, description,
  `current`, `withMemory`; `virtSnapshotTree` orders them depth-first),
  `VirtStoragePool`, `VirtVolume`, `VirtNetwork` and `VirtGuestRef` (a guest by
  libvirt UUID or PVE VMID, with the disk target or NIC and its MAC/address).
  `VirtSnapshot` stays the name of one load of a host.

Freezed + json_serializable; nothing here is persisted except the host
config below, so no store changes beyond the PVE columns.

### Console (phase 1)

| Backend | Guest | Console | How |
| --- | --- | --- | --- |
| PVE | LXC, QEMU with `serialN` | text | `POST .../termproxy` (QEMU: the first `serialN` in its config) → `vncwebsocket` → `PveTermShellBackend` (`lib/core/utils/pve_termproxy.dart`) behind a `ConsoleSource` → the terminal page |
| PVE | QEMU | graphical | `POST .../vncproxy` (`websocket=1`, `generate-password=1`, retried without it before PVE 7.2; PVE 9.2 generates a password for `websocket=1` anyway) → `vncwebsocket` → `WebSocketTunnelChannel.loopbackOnce` (`lib/core/utils/websocket_tunnel.dart`) → the remote desktop engine |
| libvirt | QEMU | serial | `virsh console --force` (`sudo` in front when libvirt needs it) typed into a shell on the host by the terminal page (`SshPageArgs.initCmd`), over whatever the terminal tab uses for that server: SSH, the agent's PTY, or this device; "Disconnect" sends Ctrl+] |
| libvirt | QEMU | graphical | `virsh domdisplay` → VNC port → `ServerTcpDialer.loopback` → the remote desktop engine |

- Both websocket consoles go through the same dialer, login and certificate
  pin as the API calls (`PveBackend.openConsoleSocket`, subprotocol
  `binary`).
- A console ticket opens one connection, so every connection attempt fetches
  a new one: `ConsoleSource.connect` for the terminal page's reconnect,
  `RemoteDesktopTargetOpener` for the viewer's.
- The VNC password is `generate-password`'s, or, before PVE 7.2, the ticket
  cut to 8 bytes — all that RFB's DES authentication and QEMU read of it.
- Graphical sessions live in `RemoteDesktopSessions` as *consoles*, kept
  apart from the remote desktop tab's sessions; the viewer is the same
  widget. The session closes when the console view goes.
- The text console is the terminal page shown in place in the console view
  (`SshPageArgs.embeddedIn(AppTab.virt, …)`), not pushed over the window. A
  bar under it names what it runs (`virsh console` / `termproxy`) and the
  transport, says that a serial console prints nothing until sent a key
  ("No output? Press Enter"), and has Disconnect (libvirt, Ctrl+]) and Close.
  A serial console (libvirt, PVE QEMU) that connects and stays silent gets
  Enter by itself (`lib/core/utils/serial_wake.dart`): when the cursor sits
  on an empty line under a known banner (`starting serial terminal on
  interface serialN`, `Escape character is ^]`, both captured from the real
  hosts) and the terminal has been still for a second, the bar counts down
  3 s with Now / Cancel; any output cancels it. At most one Enter per banner
  line, remembered with the terminal across leaving and coming back.
  Off screen — another guest, the graphical console, another tab — the page
  goes and parks its session in `VirtTextConsoles` for `SessionKeepAlive`;
  back on screen the view takes it up again. Close ends it.
- Opening glue: `lib/view/page/virt/console_connect.dart`; view:
  `lib/view/page/virt/console.dart`.
- A libvirt VNC display with a password: opening the console runs
  `vnc_console_script` — `domdisplay` and `dumpxml --security-info` in one
  round trip — and the parser returns only the display and the `passwd` of
  the VNC `<graphics>`; the secured XML never leaves Rust, and no error
  carries it. The password is handed to the engine for that connection (cut
  to 8 bytes: RFB's DES and QEMU use no more) and kept nowhere;
  `LibvirtVncConsole` and `LibvirtVncConsoleInfo` print it redacted. Where
  `--security-info` is refused (a read-only connection: `operation
  forbidden: virDomainGetXMLDesc with secure flag`, libvirt 11.3) the console
  is tried without one, and a display that refuses it for a password gets
  "This display asks for a password" over the viewer and a dialog; the typed
  password lives only in that console's opener.
- Force stop during a shutdown: the app's own shutdown or reboot waits on
  its task (PVE) and so kept the guest busy, offering nothing. It now offers
  force stop meanwhile (`VirtHostState.overrulable`), which takes over the
  busy entry; the shutdown's own failure afterwards is not reported. On PVE
  8.1+ the stop carries `overrule-shutdown=1`: without it a stop queues
  behind a `qmshutdown`/`vzshutdown` the guest ignores until that times out
  (PVE 9.2.2, a VM with no OS: still running 10 s after a plain stop; stopped
  in 2 s with the parameter). Older releases are sent no parameter they would
  refuse. libvirt needs nothing: `virsh shutdown` returns at once and the
  guest reads running until it goes (libvirt 11.3: `running (booted)` 5 s
  after the request, `destroy` immediate).

### Snapshots, storage and networks (phase 2)

| | libvirt (`virsh` through `ensureExec()`) | PVE (HTTP API) |
| --- | --- | --- |
| Snapshot list | `snapshots_script`: `snapshot-current --name`, `snapshot-list --name`, then `snapshot-dumpxml` per name in a `sh` loop — one round trip | `GET .../{qemu,lxc}/{vmid}/snapshot`; the `current` entry's `parent` is the current snapshot |
| Create | `snapshot-create-as --name --description` (internal; memory when active) | `POST .../snapshot` `snapname`, `description`, `vmstate=1` (VMs only), then the UPID's task |
| Revert | `snapshot-revert [--running]` | `POST .../snapshot/{name}/rollback` `start=1`, the task, then the separate `qmstart`/`vzstart` task it begins |
| Delete | `snapshot-delete` (children move up) | `DELETE .../snapshot/{name}`, the task |
| Pools | `storage_script`: `pool-list --all/--autostart --name`, `pool-dumpxml` and `vol-list` (with its header) per pool, `domblklist --details` per domain | `GET /nodes/{node}/storage` per online node, with `GET /storage` for paths (skipped without `Datastore.Audit`) |
| Volumes | `volumes_script(pool, names)`: `vol-dumpxml` per volume named by the last listing; users by disk source path | `GET /nodes/{node}/storage/{id}/content`; users by `vmid` |
| Networks | `networks_script`: `net-list`, `net-dumpxml` per network, `net-dhcp-leases` per active one, `domiflist` per domain | `GET /nodes/{node}/network` per online node; users from each guest's `config` `netN: bridge=` (4 at a time) |

- A reverted snapshot without memory leaves the guest stopped; the revert
  dialog says so in red for an active guest and offers to start it again
  (`--running` / `start=1`). A snapshot operation is one per guest and blocks
  power actions on it (`VirtHostState.snapshotOps`), and the reverse.
- Scripts, parsers and fixtures: `sbm_virt::libvirt` (`snapshots_script`,
  `storage_script`, `volumes_script`, `networks_script`, the three snapshot
  actions), `crates/sbm_virt/tests/fixtures/libvirt/script_*.txt` captured from the libvirt host.
  PVE payloads: `test/fixtures/pve/`, captured from PVE 9.2.2.
- The providers (`virtSnapshotsProvider`, `virtStoragePoolsProvider`,
  `virtVolumesProvider`, `virtNetworksProvider`) do not retry by themselves:
  an attempt may run `virsh` through sudo or log in, and a failure is shown
  with its own retry.

### Creating and deleting guests (phase 3)

A new guest is a form in the detail pane (a page with one column), opened
from the add button in the host's list bar, where `VirtCapabilities.create`
(both backends): a VM, or on PVE a container too
(`lib/view/page/virt/create.dart`). Everything offered comes from the host's
own lists — `virtDiskStorages`, `virtMediaStorages` + `virtIsMedia`,
`virtCreateNetworks` (`lib/data/model/virt/virt_create.dart`) — and
`virtCreateIssue` refuses what the host would refuse before it is asked:

- Names: libvirt `^[A-Za-z0-9][A-Za-z0-9._-]{0,62}$` — `virt-aa-helper`
  refuses to start a domain with `"` in its name (`error_apparmor_start.txt`),
  and `vol-create-as` builds its XML from the name unescaped, so `&` and `<`
  come back as an XML error from the host (verified). PVE: a DNS name. A name
  another guest has is refused on both (PVE would allow it).
- VMID 100–999999999 and free (default `/cluster/nextid`); cores up to the
  node's; memory ≥ 128 MiB (VM) / 64 MiB (container); disk 1 GiB–64 TiB.
- A container needs a template and a root password (≥ 5, PVE's floor) or
  OpenSSH public keys, one per line. Both go in the request body only.

| | libvirt | PVE |
| --- | --- | --- |
| Create | 1. `create_host_script`: `domcapabilities` for KVM/q35, KVM, QEMU/q35, QEMU, the first the host accepts. 2. `create_volume_script`: stops if the name is defined, `vol-create-as` (qcow2, raw on LVM/ZFS/RBD pools), `vol-path`. 3. `define_script`: the XML (`domain_xml`, escaped) through a `mktemp` file, `define --file`, `domuuid`, `start`; a refused define deletes the volume again. | `POST /nodes/{node}/qemu` (`scsi0` on the storage, `ide2` the ISO, `net0` virtio on the bridge, `serial0: socket`, `ostype l26`) or `/lxc` (`ostemplate`, `rootfs`, `net0` DHCP, `unprivileged`), the task; then `status/start` as its own request |
| Delete | `undefine --managed-save --snapshots-metadata`, with `--nvram --storage <targets>` of the writable disks (never a CD-ROM or a read-only disk), or `--keep-nvram` keeping them. A guest with external snapshots: the pools of its chain files are refreshed first (`--storage` skips a file its pool does not know yet — one a snapshot or a revert made — with a warning and rc 0), and the files below each disk go after it, down to the disk the first snapshot was taken of; an image below that stays | `DELETE` with `purge=1&destroy-unreferenced-disks=1`, the task. Its own disks always go (`deleteKeepsDisks` false) |

- Disks by path, not `type='volume'`: on the Debian/AppArmor libvirt host a
  volume disk failed to start with "Permission denied" on its own image
  (verified), which a file disk in the same pool does not.
- A guest that was created and did not start is not a failure:
  `VirtCreated.startError`, shown as a warning; the guest is opened either
  way. A name, VMID or volume already there is `VirtErrType.exists`
  (`VirtErrorKind::Exists` from virsh's "already exists"; PVE's `unable to
  create VM 100 - VM 100 already exists on node 'pve'`); anything else PVE
  refuses is `actionFailed` with its message and, for a 400, each parameter's
  error.
- Delete is in the guest's bar, where `create`: in red, the name typed back,
  and on libvirt a "delete its disks too" box (ticked). A guest that is not
  stopped is offered a forced stop first and asked again once off —
  `delete` itself refuses one (`unsupported`), since `undefine` would leave a
  running domain transient.
- PVE privileges on top of the listing ones: `VM.Allocate`, `VM.Config.*`,
  `Datastore.AllocateSpace`, `SDN.Use` (in the token help). A
  privilege-separated token with exactly the documented set (a custom role on
  `/`) created a VM with an ISO, a container from a template, and deleted
  both with `purge` (PVE 9.2.2, verified).

Verified 2026-09-25 by `test/e2e/virt_monitor_test.dart` ("create and
delete" groups, which touch no existing guest): on libvirt 11.3 through the
agent and sudo — a VM with ISO and NIC started on KVM/q35, its serial and VNC
consoles in its detail, the same name refused as `exists`, delete refused
while running, then deleted with its volume and the ISO kept; on PVE 9.2.2
through the relay with the token above — a VM (serial port, CD-ROM) and an
Alpine container, both started, the VMID reused refused as `exists`, both
deleted with no volume of their VMID left. The Rust scripts also ran by hand
there for the fixtures, including a hostile name (quotes, spaces, `$(id)`
and backticks) through create, define and undefine.

### Hardware editing (phase 4)

A "Hardware" view next to Overview / Console / Snapshots (labelled
"Resources" for a container), where `VirtCapabilities.hardware` (both
backends), not on a template (`lib/view/page/virt/hardware.dart`). One form
per group, in the design's order — processor, memory, disks (a container:
root disk and mount points), NICs, "CD-ROM and passthrough" (VMs), display
(VMs), boot (VMs: firmware, Secure Boot, the order), the configuration as
the host writes it — with an index beside them from
860 pt. Steppers and pickers are drafts with Cancel / Save; device toggles
(link, firewall) and device actions (add, grow, detach, eject) are one
change each, a destructive one behind a red confirmation (a disk: "delete
its volume too", unticked). "Add" rows have the design's dashed outline
(fl_lib `DashedBorder`).

The pane (`edit_pane.dart`, a mixin both the Hardware and the Settings view
use) keeps the rows, the index and the one way a change is made (`_apply`:
check, send with the revision, read again, say what waits). A pending
change is shown **where it is set**: under the processor or memory fields,
under the device row it changes (a removed device's under its group), under
the boot order, under the Settings field; an option neither view edits is
listed with the configuration file. Each has its revert on PVE; the notice
above the tabs has "revert all" (an icon, beside the design's one "Restart
now" — two labels do not fit a phone) and the restart.

#### Devices, display and firmware (phase 4, second part)

What the design's hardware view has besides CPU, memory, disks and NICs.
What a guest can be changed to is `VirtHardware.support` (`VirtHwSupport`):
PVE's fixed list (`PveResources.pveQemuSupport`), libvirt's from the host's
`domcapabilities` **for the domain's own virt type, arch and machine**
(read in `hardware_script`; Secure Boot is a q35 thing — i440fx answers
`secure: no` — and a Debian QEMU build without SPICE offers no SPICE and no
`qxl`). Nothing is offered that the host lacks: no TPM without swtpm
(`backendModel` `emulator`), no UEFI without OVMF.

| | libvirt | PVE |
| --- | --- | --- |
| Disk bus | Stopped only (`VirtHwIssue.stopFirst`). `edit_disk_xml`: the target renamed on the new bus (`vda` → `sda`), its `<address>` dropped; the `<boot order>` travels inside the disk | Stopped only. One request: the new key (`virtio0`) with the same volume string, `delete` of the old; **PVE drops the old key from `boot`**, so the order is sent again with the new key in its place |
| Disk cache | `<driver cache>` in the definition (pending while running) | The option's `cache=` (`default` drops it) |
| NIC model / MAC | `edit_nic_hardware_xml`, pending while running | The `model=MAC` pair rewritten (`withNicHardware`); a container's `hwaddr` |
| Display | `edit_display_xml`: protocol (VNC/SPICE where offered), listen address (127.0.0.1 / 0.0.0.0 — the latter warned about, as the design has it), primary video model; a VNC password and keymap are kept | `vga` type (its `memory=` kept); PVE has no protocol or listen address to set here: VNC through its proxy, SPICE comes with `qxl` |
| Firmware | Stopped only, asked first ("don't switch the firmware of an installed system"). `edit_firmware_xml`: `<os firmware='efi'>` with `enrolled-keys`/`secure-boot` features and no `<loader>`/`<nvram>` of its own, so libvirt autoselects (verified: `OVMF_CODE_4M.ms.fd` with SMM on for Secure Boot, `OVMF_CODE_4M.fd` without). **libvirt reuses a variables file whatever template made it**, and keys are enrolled only when one is made, so a change of Secure Boot keeps `<nvram>`'s path and deletes the file after the define: libvirt makes it from the right template at the next start (boot entries go, as on PVE; the view says so on both) | `bios=ovmf` plus an `efidisk0` (`<storage>:1,efitype=4m,pre-enrolled-keys=0/1`) on the storage the old one was on, or one picked. Keys are enrolled when the disk is made: turning Secure Boot on or off **replaces the EFI disk** (the old one detached and its `unusedN` deleted; the view says boot entries go with it). BIOS keeps the EFI disk |
| TPM | `<tpm model='tpm-crb'><backend type='emulator' version='2.0'/>` — only where swtpm is there; config only, pending | `tpmstate0: <storage>:1,version=v2.0`; removing it deletes the state volume too |
| USB | `nodedev-list --cap usb_device` + `nodedev-dumpxml` each (root hubs left out); a `<hostdev>` by vendor/product or by the bus and device number (phase 10), live as well while running | Resource mappings (`/cluster/mapping/usb`); the node's own devices only for root@pam with its password |
| PCI | `nodedev-list --cap pci` with IOMMU groups (and how many share one); a managed `<hostdev>` by address, config only | Mappings (`/cluster/mapping/pci`); the node's devices (`/nodes/{n}/hardware/pci`, which also says whether there is an IOMMU) for root@pam only |

- **PVE lets only root@pam give a guest a raw device**: a token (or any
  other user) gets "only root can set 'usb0' config for real devices" /
  "'hostpci0' config for non-mapped devices" in the task. So the add block
  offers mappings to everyone (`Mapping.Use` on the mapping,
  `Mapping.Audit` to list them — `PVEMappingUser`), and says why raw
  devices are missing (`VirtHostDevices.mappingsOnly`). Listing the node's
  USB devices needs `Sys.Modify`, so only root sees them anyway.
- **No IOMMU** (VT-d / AMD-Vi off, as on the test host: no DMAR table,
  every PCI device `iommugroup: -1`, and no `iommuGroup` in libvirt's
  nodedev XML) is a warning in the PCI add block, not an error: the
  configuration is written, and the guest refuses to start with the host's
  words — PVE "cannot prepare PCI pass-through, IOMMU not present", libvirt
  "host doesn't support passthrough of host PCI devices" (both seen).
- Keys: libvirt `usb:0bda:b023` (or `usb@bus.device`), `pci:0000:01:00.0`,
  `tpm`; PVE the option (`usb0`, `hostpci0`, `tpmstate0`). Removing a
  libvirt USB device detaches it live as well; a TPM and a PCI device stay
  until the guest stops (pending).
- New PVE privileges (token help): `VM.Config.HWType` for the card and
  USB/PCI devices (a request without it is refused before any task: 403),
  `Mapping.Use`/`Mapping.Audit` for mappings. Firmware, TPM, NIC model and
  cache need nothing beyond the documented set (verified with a
  privilege-separated token holding exactly that).

Verified 2026-09-26:
- **libvirt 11.3** (agent + sudo, a q35 domain of the test's own): bus
  change with the boot order following, cache (pending while running), NIC
  model and MAC, listen address and card, UEFI with Secure Boot started
  (`secure='yes'` loader, SMM on), the `-sb` variables file made on the
  next start and the old kept, back to BIOS; the host device list (nested
  guest: no IOMMU, no USB); a PCI device written and the start refused with
  the host's words, then removed.
- **PVE 9.2.2** (relay, token): bus change with the boot order, cache, NIC
  model and MAC, card, UEFI with Secure Boot on and off (EFI disk replaced,
  the old volume gone), TPM added and removed (volume gone); a token sees
  mappings only.
- **Real USB passthrough** on PVE (over SSH, `SBM_E2E_PVE_USB=0bda:b023`,
  the node's Bluetooth adapter): a temporary mapping granted to the token,
  given to a temporary VM, the VM started and QEMU's command line holding
  `usb-host` with that vendor and product; then taken off and everything
  removed.

A libvirt guest keeps one variables file at one path
(`FirmwareEdit::drop_vars`): a Secure Boot change keeps the path and deletes
the file after the define, and libvirt makes it again from the right template
at the next start; leaving UEFI deletes it. So `undefine --nvram` on delete
removes all there is. Only files under libvirt's NVRAM directory are ever
deleted (`is_libvirt_nvram`), whatever the definition names, and a refused
define keeps the file. (Replaced keeping the old file for going back, which
left one per switch that nothing removed.)

Real PCI passthrough on PVE 9.2.2, verified with a Tesla T10 (`10de:1e37`,
subsystem `10de:1370`) after enabling VT-d (the DMAR table appeared; the card
in an IOMMU group with only its root port) and binding it to `vfio-pci`:
`SBM_E2E_PVE_PCI=0000:01:00.0` mapped it, gave it to a temporary VM through
the backend, started the VM (its QEMU command line has `vfio-pci` for the
card), stopped it, took the device off. A mapping must carry the device's
`subsystem-id` when it has one: PVE 9 refuses the start otherwise ("PCI
device mapping invalid … missing expected property 'subsystem-id'"). The
guest had no OS, so what a driver inside makes of the card is not shown.

Not proven: PCI passthrough on libvirt (the libvirt host is a nested guest);
USB passthrough on libvirt (no USB device there); a TPM on libvirt (no swtpm
there); SPICE on libvirt (not in that QEMU build).

### Settings (phase 4)

The design's Settings view, a segment after Snapshots
(`lib/view/page/virt/settings.dart`), on the same hardware read:

- **General**: the name (PVE `name`, a container's `hostname`; libvirt
  `domrename`), the note (PVE `description`; libvirt `virsh desc`, both
  definitions while running; empty clears it), starting with the host
  (moved here from the boot group: `onboot` / `virsh autostart`), and PVE's
  protection. Name and note are drafts with Cancel / Save; a name is checked
  as the create form checks it (a DNS name on PVE, letters, digits, `.`,
  `_`, `-` on libvirt) and against the host's other guests.
- **Delete** (moved here from the guest's bar): the design's two presses —
  the first shows "press again to confirm", the second deletes — held back
  while the guest runs ("shut it down first") or is protected. libvirt asks
  whether the disks go too; PVE says they do.
- libvirt renames only a domain that is not running (`renameRunning`
  false): the field says so while it runs. libvirt has no protection
  (`protection` null) and no revert.
- The design's Migrate and Clone groups are later phases; its Settings view
  has nothing else.

Verified, 2026-09-26: PVE 9.2.2 through the relay with a privilege-separated
token holding exactly the documented privileges (`VM.Config.Options` covers
name, note, `onboot` and protection; a container's hostname is
`VM.Config.Network`, also documented) — a VM's name and note apply at once,
running; **a running container's hostname applies at once too** (PVE 9.2
writes it into the container; nothing pending). libvirt 11.3 through the
agent and sudo: a note starting with `-` and holding quotes and a newline
round-trips through `virsh desc`; `domrename` on the stopped domain, and
back.

`VirtHardware` (`lib/data/model/virt/virt_hardware.dart`) is **the
definition the next start gets**, so an edit starts from what was last
saved; what the running guest has instead is `pending`. `virtHwIssue`
refuses before sending: vCPUs 1..host, online 1..total, memory 16 MiB..host
and a balloon floor under it, disks only grow and fit the storage's free
space, a mount point absolute and free of `,` `=` and blanks, a boot order
with a device. What the host refuses beyond that is shown in its words.

| | libvirt | PVE |
| --- | --- | --- |
| Read | `hardware_script`: `dominfo`, `nodeinfo`, `dumpxml --inactive`, `dumpxml` while running, `domblkinfo` per disk (`--all` fails on a running domain with an empty CD-ROM) — parsed in Rust (`parse_hardware`) | `GET config` (pending applied, with `digest`), `GET pending`, node status and `capabilities/qemu/cpu` (both optional: a token without `Sys.Audit` still reads the guest) |
| Pending | The running definition compared with the persistent one (`LibvirtBackend.pendingOf`): CPU, memory, disks, NICs, boot. Not the balloon's current size, which moves by itself | PVE's `pending` list: `{key, value, pending}` or `delete: 1` |
| Change | One `virsh` round trip (`hardware_change_script`): the persistent half (`--config`, `define`) and, while running, the live half (`--live`); a refused live half leaves the change for the next start (`VirtHwOutcome.liveError`) | `POST config` (VM) / `PUT config` (container) with `digest`; `PUT resize` (a task) |
| Guard | CPU and boot rewrite the XML in Rust (`edit_cpu_xml`, `edit_boot_xml`, range splicing that keeps the rest as written), from the XML read; the script compares the host's `dumpxml --inactive` with it before `define` → `conflict`. Every other change is addressed by target/MAC from the same read, refused before the host if the backend's last read differs | `digest`: a stale one is "checksum mismatch (file change by other user?)" → `conflict`; the view says so and reads again |
| Revert | Not offered (`hardwareRevert` false): libvirt keeps no pending list to drop | `revert=<keys>`, per row and all |
| Remove a disk | `detach-disk` in both halves; the volume deleted (`vol-delete`) only once `domblklist` no longer lists it — else `volumeKept` | Delete the key; the volume turns up as `unusedN` and deleting that deletes it. Still attached to a running guest (pending) → `volumeKept` |
| Restart to apply | Shutdown, wait for it to stop (up to 3 min), start: `reboot` does not load the persistent definition | `reboot` |

- The notice above the views ("some hardware changes apply at the next
  restart", "Restart now") comes from a hardware read this session already
  has, while the guest runs.
- libvirt: all scripts and XML in Rust through FFI, every argument quoted;
  the hostile-name test runs each change script under `sh` with a stub
  `virsh`. A new NIC's MAC is `52:54:00:xx:xx:xx`; a new disk is a qcow2 (raw
  on LVM/ZFS/RBD) file volume `<guest>-<target>` in the chosen pool, on the
  first disk's bus, deleted again if the attach fails.
- PVE privileges on top of the listing ones (in the token help):
  `VM.Config.CPU`, `VM.Config.Memory`, `VM.Config.Disk`, `VM.Config.CDROM`,
  `VM.Config.Network`, `VM.Config.Options`; new disks and interfaces
  `Datastore.AllocateSpace` and `SDN.Use`. A privilege-separated token with exactly that
  set ran the whole PVE e2e group (verified).

Verified on libvirt 11.3 (through the agent and sudo, and by hand on a
domain of its own for the fixtures) and PVE 9.2.2 (through the relay), by
the "hardware" groups of `test/e2e/virt_monitor_test.dart`, 2026-09-26:

| Topic | Result |
| --- | --- |
| libvirt CPU and memory | `setvcpus --maximum` and `setmaxmem` cannot be done live: saved, pending. `setvcpus --live` within the maximum applies at once. |
| libvirt disks | IDE cannot be hot-plugged (live half refused, saved); `blockresize` grows a running disk, `vol-resize` a stopped one; a disk only in the persistent definition is grown on its file. |
| libvirt NIC and media | `update-device` replaces the whole interface, so the link state is always written; `change-media --update` inserts into an empty drive, and ejecting an empty drive is refused (not sent). |
| libvirt autostart | Not part of the XML: a separate `autostart` call, outside the guard. |
| PVE VM | Cores, sockets and the boot order go to pending while running; the balloon floor applies at once; `revert` drops each. A hot-plugged NIC applies at once. |
| PVE container | Cores, memory and swap apply at once; removing a mount point from a running container is pending (`delete: 1`), its volume kept. |

Not verified: PVE clusters. (Dies/clusters, a CD-ROM on SCSI and hardware
over SSH were run later: "Second pass", phase 10.)

### Clone and backups (phase 5)

Following the design: **Clone** is a group of the Settings view (new name,
"Full clone" on PVE / "Copy disk contents" on libvirt, the Clone button; the
copy opens on its overview afterwards), and **Backup** is a guest view of its
own on PVE, between Snapshots and Settings (the Plan group — the scheduled
jobs that take the guest, "Datacenter → Backup" — and the Backup
list: "Back up now" and each backup's file, notes, protection, verification,
Delete and Restore). Capabilities: `clone` (both), `linkedClone` and `backup`
(PVE). A clone, a backup and a restore are a guest's one operation in flight
(`VirtHostState.copyOps`); a backup or restore reads as "Backing up…".

| | libvirt | PVE |
| --- | --- | --- |
| Clone | Stopped only (a disk being written gives a copy of nothing in particular). `clone_volumes_script`: the name not defined, the source `shut off`, then per writable disk `vol-pool` → `vol-clone` (or `vol-create-as` of its capacity and format: "copy disk contents" off) → `vol-path`; any step failing deletes the volumes made. `clone_define_script`: `clone_domain_xml` (new name; no `<uuid>`, no `<mac>`: libvirt gives new ones; each disk a `file`/`block` at its new path; a CD-ROM on the same image; `<nvram>` keeps its template and loses its path, so the copy gets a variables file of its own) → `define`, its volumes deleted if refused | `POST .../clone` (`newid` from `/cluster/nextid`, `name`/`hostname`, `full`), the task waited for. Linked (`full=0`) only from a template — PVE refuses it otherwise ("Linked clone feature is not supported"), so the switch is fixed on elsewhere |
| Backups | none (libvirt has no backup of its own; the view is not offered) | Storages with `backup` content on the node; `.../content?content=backup&vmid=`; `POST /nodes/{n}/vzdump` (`mode` snapshot while running, stop otherwise; `zstd`); restore `POST /nodes/{n}/qemu` with `archive` (`/lxc` with `ostemplate` + `restore=1`) over the guest with `force=1` (stopped only) or as the next VMID; `DELETE .../content/{volid}`; jobs from `/cluster/backup` (`all` less `exclude`, or `vmid`) |

Restoring over the guest and deleting a backup are each pressed twice (the
design's two-step confirmation, the second in red); a protected backup cannot
be deleted.

Verified on real hosts (temporary guests only, all removed):

- libvirt 11.3 through the agent with sudo: a full clone and an empty-disk
  clone of a UEFI domain with a qcow2 disk and an ISO CD-ROM — new UUID and
  MAC, `<name>_VARS.fd` of its own made at the first start, the CD-ROM on
  the same image, the source untouched; a name taken (`Exists`), a running
  source (`InvalidState`), a define refused (its volume deleted). e2e: the
  app's clone of a created VM, full and empty, refused while running.
- PVE 9.2.2 through the relay, with a privilege-separated token holding
  exactly the documented privileges (the create/hardware set plus `VM.Clone`
  and `VM.Backup`: deleting a backup needs no `Datastore.Allocate`, the plan
  reads with `Sys.Audit`): clone, back up, list, restore as a new VM and over
  the stopped VM (refused running), delete. A linked clone of a template
  (lvmthin, origin `base-<vmid>-disk-0`) and PVE refusing one of a guest that
  is not a template, as root.
- Learned: `/cluster/resources` names a clone or a restored guest a moment
  after its task (the same lag as other actions): the list shows its VMID
  until the next refresh. `qm destroy --purge` takes the guest out of backup
  jobs, and deletes a job left with no guest.
- Lesson from testing: `virsh undefine --remove-all-storage` deletes every
  volume the domain names, **a CD-ROM's image included** — shared base images
  go with it. The app's delete never uses it (writable disks by target only);
  a test must not either.

### Storage and networks management (phase 6)

The Storage and Network sections manage what they list, on both backends,
as the design's pool and network views have it: the same sectioned pane as
the Hardware view (groups under a rule, an index beside them from 860 pt —
`_PaneRows` in `edit_pane.dart`, shared by every pane now), and new pools
and networks as forms in the detail pane (a page with one column), from the
list bar's add button. Views: `lib/view/page/virt/storage.dart`,
`network.dart`; changes: `VirtResourceChange` (`virt_manage.dart`), checked
with `virtResourceIssue` before they are sent, made by `VirtBackend.manage`.
What each host offers is capabilities: `storageEdit`, `poolTypes`,
`poolAutostart`, `poolDeleteStorage`, `volumeResize`, `volumeClone`,
`upload`, `networkEdit`, `networkModes`, `networkStart`, `networkApply`.

| | libvirt (`sbm_virt::libvirt::manage`, one `virsh` round trip each) | PVE (HTTP API) |
| --- | --- | --- |
| New pool | `pool-define` (XML through a `mktemp` file) → `pool-build` (`dir`, `netfs`; never `logical`: its build formats devices, an existing volume group is used as it is) → `pool-start` → `pool-autostart`; a failed build or start undefines it again | `POST /storage` (`dir` `path`; `nfs` `server`/`export`; `lvmthin` `vgname`/`thinpool`; `zfspool` `pool`), `nodes=<node>`, content `images,rootdir` (`backup,iso` for NFS, as the design) |
| Stop / start | `pool-destroy` / `pool-start` | `PUT /storage/{id}` `disable=1/0` |
| Autostart, refresh | `pool-autostart [--disable]`, `pool-refresh` | none (PVE reads a storage on every listing) |
| Remove | `pool-destroy` (active), `pool-delete` only when asked and the pool is empty (an empty directory), `pool-undefine` | `DELETE /storage/{id}`: the configuration only |
| New volume | `vol-create-as --capacity <bytes>B --format qcow2/raw` | `POST .../storage/{id}/content` `vmid` (from the name, `vm-<VMID>-…`), `filename` (with `.qcow2`/`.raw` on a file storage: PVE refuses one without), `size`, `format` |
| Delete / grow / copy | `vol-delete`; `vol-resize` (grow only); `vol-clone` | `DELETE .../content/{volid}` (a task); PVE grows a disk only as a guest's |
| Upload | A raw volume of the file's size, then `vol-upload --file /dev/stdin` on an exec channel that carries bytes (see below); a failure or a cancel deletes the volume | `POST .../upload`, multipart (`content` then the file), no send timeout, then the `imgcopy` task |
| Attach | `VirtHwAttachVolume` through the hardware path: `attach-disk --source <path>` on the first disk's bus, both definitions while running; never deleted when refused. An ISO goes into a CD-ROM drive with the existing `VirtHwSetMedia` | The same change: `<bus>N: <volid>` in the config (`mpN` for a container) |
| New network | `net-define` (NAT, routed, isolated with or without IPv4, or `<forward mode='bridge'/>` onto a host bridge; libvirt picks `virbrN`) → `net-start` (a refusal undefines it again) → `net-autostart` | `POST /nodes/{n}/network` `type=bridge`, `bridge_ports`, `cidr`, `bridge_vlan_aware`, `autostart` — **pending** |
| Stop / start, autostart | `net-destroy` / `net-start`, `net-autostart` | none |
| Delete | `net-destroy` (active), `net-undefine` | `DELETE /nodes/{n}/network/{iface}` — pending |
| Pending | `net-define` writes the definition and the running network keeps what it has until it is restarted (phase 10: `pendingRestart`, and the restart that applies it) | The listing's top-level `changes` (the diff of `interfaces.new`) per node, shown above the list and the network with "Show changes", Revert (`DELETE /nodes/{n}/network`) and Apply (`PUT /nodes/{n}/network`, `ifreload -a`, a task), each asked first |

Decisions:

- **Uploads to libvirt stream through `vol-upload`, not SFTP into the
  pool's directory.** It works for every pool type (a directory, an LVM
  volume group, an NFS mount), writes once with libvirt's own ownership and
  labels, needs no staging copy or space on the host, and needs no write
  access to the pool for the SSH account — only what the rest of the tab
  uses (libvirt, through sudo when needed). It needs an exec channel that
  carries bytes (`ServerByteExec`: `SshExec`, the local `ProcessExec`); a
  server reached only through a monitor agent (its `/exec` takes stdin
  whole) is not offered uploads (`VirtCapabilities.upload` false).
- The upload command is `sh -c 'eval "$(echo <base64> | base64 -d)"'`
  (single quotes with nothing fish reads differently), `sudo -S -p ''` or
  `sudo -n` in front as `PrivilegedExec` decided. On stdin: the sudo
  password line, then a go line, then — once the script has printed that it
  is ready — the file. `sudo -S` and `read` both stop at the newline, so the
  password never reaches `virsh`; when sudo did not ask (cached,
  `NOPASSWD`), the script finds the password where the go line belongs,
  stops before `virsh` runs, and the upload goes again with `sudo -n`. A
  refused password stops it at once (sudo would take the go line as its
  next guess). SSH writes flush every MiB, so a file is not buffered in
  memory; a cancel kills the channel and deletes the volume.
- **A signal on an SSH channel the server has already freed ends the whole
  connection** (OpenSSH: `server_input_channel_req: unknown channel`, seen
  in testing). `SshExec` now sends none after the command has ended.
- PVE's upload parser matches `Content-Disposition` case-sensitively; Dio
  writes it lowercase by default, and pveproxy then fails the upload with
  "No space left on device" in its log (PVE 9.2.2, seen). The form data is
  built with the capitalised header.
- A PVE permission refusal (`Permission check failed (<path>, <priv>)`) is
  `permissionDenied` naming the privilege, the path and the command that
  grants it: the narrowest built-in role (`PVEDatastoreUser` for
  `Datastore.AllocateSpace`, `PVEDatastoreAdmin` for `Datastore.Allocate`
  and `Datastore.AllocateTemplate`), or, for `Sys.Modify` (which only
  `Administrator` holds), a role of its own. Token help: `Datastore.Allocate`
  on `/storage` (add, disable, remove), `Datastore.AllocateSpace` (volumes),
  `Datastore.AllocateTemplate` (uploads), `Sys.Modify` on `/nodes/{n}`
  (bridges, apply, revert).
- What a guest uses is refused before the host is asked: a volume in use is
  not deleted, grown here or attached again; a pool with a volume in use is
  not stopped or removed; a network with guests on it is not deleted, and
  stopping it is asked in red. A PVE volume is "used" by the guest its VMID
  names only while that guest exists. A network address overlapping
  another network of the host's is refused by the form; one overlapping the
  host's own interfaces is refused by libvirt at `net-start`, which undefines
  it again.
- The providers of pools, volumes, networks and pending changes read again
  after a change through `VirtRevision` (a count they watch), not by the
  host notifier invalidating them: they watch the notifier, and Riverpod
  refuses that as a cycle in debug builds — which also hit the existing
  hardware refresh after a power action.
- PVE's network listing now leaves out a guest deleted since the last load
  (its config answers "does not exist") instead of failing.

Verified 2026-09-26 by the "storage and networks" groups of
`test/e2e/virt_real_test.dart`, everything named `sbxe2e*` and removed
afterwards:

- **libvirt 11.3** over SSH as root: a `dir` pool in a fresh directory made
  (built, started, autostart), a name taken → `exists`, stopped, started,
  autostart off, a file put there by hand listed after a refresh; volumes
  made, grown, cloned, deleted; a 3 MiB upload byte for byte (sha256), a
  256 MiB one cancelled at 8 MiB leaving no volume; a volume attached to a
  new VM (used by it, delete refused), its CD-ROM ejected and the uploaded
  ISO put back, detached and the VM deleted with its own disk only; the
  pool removed with its directory; NAT (with DHCP), isolated and host-bridge
  networks made, stopped, started, autostart off, deleted, and one on a
  subnet in use refused at start and not left defined. **Through sudo**, as
  the agent's account outside the `libvirt` group (`su` from root): the
  listing asks for the password, an upload with it lands byte for byte (no
  password in it), and a wrong one is `sudoPasswordRejected` with nothing
  left behind.
- **PVE 9.2.2** over SSH with a privilege-separated token: a directory
  storage added, a name taken → `exists`, disabled, enabled; a volume
  allocated for a VMID and deleted; a 3 MiB ISO uploaded byte for byte, a
  cancelled one leaving nothing and the session kept; a volume attached to a
  new VM and deleted with it; `NoAccess` on `/storage` → `permissionDenied`
  naming `Datastore.Allocate` and the command; the storage removed with its
  files kept; a bridge (no ports, an address of its own) pending, its diff
  read, reverted; made again, applied (SSH checked after), deleted,
  applied. PVE's apply rewrites `/etc/network/interfaces` in its own layout
  (a header comment, every interface listed): the same configuration.

Not verified on a real host: PVE `nfs` and `zfspool` storages, bridges with
ports, clusters; uploads from this device as a libvirt host (`ProcessExec`,
which needs libvirt on the device itself). libvirt `netfs` and `logical`
pools and routed networks were run later ("Second pass", phase 10).

### Cloud images, cloud-init and create options (phase 7)

The create form moves onto the design's sectioned pane (the `_PaneRows`
groups every other form uses, `create.dart` now a part of `hardware.dart`):
General, System (VM) or Template (container), cloud-init (a cloud image),
Resources, Storage, Network, Confirm, each group's dot in the index green
when it is complete and orange while not, as the design has it. A VM's
system comes from install media or, where the host can (`VirtCreateOptions`,
`VirtBackend.createOptions`), from a cloud image; the form also sets the disk
bus, the NIC model, UEFI or BIOS, and a TPM. The Hardware view's "CD-ROM and
passthrough" group adds and removes a CD-ROM drive.

| | libvirt (`sbm_virt::libvirt`, its `cloud_init`) | PVE (HTTP API) |
| --- | --- | --- |
| Options | `create_host_script`: `domcapabilities` for the machine a new domain gets (its disk buses — q35 has no IDE —, OVMF, swtpm) and which ISO tool the host has (`genisoimage`, `xorriso`, `mkisofs`, `cloud-localds`, first found) | Fixed: SCSI/virtio/SATA/IDE, UEFI, TPM, cloud-init; cloud images from 8.2 (`import` content) |
| Cloud images offered | qcow2 or raw volumes of any active pool no guest uses (a disk in use would be copied mid-write), not an ISO | Volumes with `import` content in a format QEMU reads (qcow2, raw, vmdk; not an OVA) on the node |
| The disk | `create_volume_script`: `vol-create-from --vol <image path>` (a copy in the chosen pool, converted to its format: qcow2, raw on LVM) → `vol-info --bytes` → `vol-resize` only when that is below the size asked for → `vol-path`; any later step failing deletes it | `<bus>0: <storage>:0,import-from=<volid>` (PVE requires size 0), then the imported disk's `size=` read from the configuration and `PUT .../resize` only when it is below the size asked for, before the start. A failed growth leaves the VM created and not started (`startError`) |
| cloud-init | A NoCloud seed made on the host, a volume `<name>-cidata.iso` in the disk's pool, attached as a read-only CD-ROM (below) | PVE's own drive `<storage>:cloudinit`; `ciuser`, `cipassword` (PVE hashes it, SHA-256 crypt), `sshkeys` URL-encoded inside the form's own encoding (`encodeURIComponent`, as PVE's web UI), `ipconfig0` (`ip=dhcp` or `ip=<cidr>,gw=<gw>`), `nameserver`, `searchdomain`. The hostname is the VM's name |
| Bus, NIC model | `<target bus>` (`vda`/`sda`/`hda`), a `virtio-scsi` controller for SCSI; `<model type>` | `<bus>0` (I/O thread on SCSI and virtio only: PVE refuses it on SATA and IDE); `net0: <model>,bridge=` |
| UEFI | `<os firmware='efi'>` with `enrolled-keys` and `secure-boot` off, as phase 4 writes it: autoselected OVMF, a variables file of its own | `bios=ovmf`, `efidisk0: <storage>:1,efitype=4m,pre-enrolled-keys=0` |
| TPM | `<tpm model='tpm-crb'>` with the swtpm emulator, only where `domcapabilities` has it | `tpmstate0: <storage>:1,version=v2.0` |
| Delete | The domain's `<metadata>` names its seed; `undefine_script` deletes it with `vol-delete` once the domain is gone (a refused undefine keeps it; one already gone is fine), with the disks only ("delete its disks too") | The cloud-init volume is the VM's own: `purge` deletes it |
| Add a CD-ROM | `attach-device` of an empty (or ISO) `<disk device='cdrom'>` on SATA (q35) or IDE (`pc`), to the persistent definition only: neither takes a drive live, so a running guest gets it at its next start (pending) | The first free of `ide2`, `ide0`, `ide1`, `ide3`, `sata0-5`: `none,media=cdrom` or the ISO; PVE puts it in pending while the VM runs |
| Remove it | `VirtHwRemoveDisk` (phase 4); a CD-ROM's image is never deleted | The same; an ISO stays on its storage |

The seed:

- `user-data` names the account as the image's default user (`user:`, the
  form PVE's own cloud-init writes): the name asked for, with passwordless
  sudo, `hashed_passwd` (or `lock_passwd` without a password), the keys, and
  `ssh_pwauth` on when there is a password; the hostname with
  `manage_etc_hosts`. Its shell, groups and sudo or doas are the
  distribution's default user's. The first release wrote a `users:` entry of
  its own with `shell: /bin/bash`, which on Alpine (no bash) made an account
  sshd refused (verified, Alpine 3.23 `nocloud`); a seed in that form is
  still read back. `meta-data`: a new `instance-id`
  (`iid-<name>-<random>`) and `local-hostname`. `network-config` (v2) finds
  the one NIC **by its MAC**, which the app therefore chooses
  (`52:54:00:…`) and writes on the interface too: DHCP, or the address with
  its prefix, a route `0.0.0.0/0` via the gateway (`to: default` needs a
  newer cloud-init), and nameservers/search. Every value goes in as a JSON
  string (JSON is YAML), so nothing typed becomes a key of its own; Rust
  checks each again (`VirtCloudInit::check`).
- **The password never leaves the app.** It is hashed in-process with
  SHA-512 crypt (`sbm_virt::libvirt::cloud_init::sha512_crypt`, checked against the
  specification's examples and glibc's `crypt(3)` on the PVE host; a
  16-character salt from `Random.secure`), and only the hash is in the seed,
  the script and the host. The files are written by `printf` (a shell
  builtin: no process, no argv) into a `mktemp -d` directory (0700, the
  files 0600 under `umask 077`), which a `trap` removes on every way out; the
  script itself travels on `sh`'s stdin as every other.
- The ISO: `genisoimage`/`mkisofs`/`xorriso -as mkisofs` `-volid cidata
  -joliet -rock`, or `cloud-localds -N`. The volume: `vol-create-as` of the
  ISO's size (raw), `vol-upload --file` from the staging file (virsh on the
  host reads it, so it works through the agent and sudo as well), `vol-path`.
  A host with none of the tools gets a callout naming them; the image can
  still be created without cloud-init. Any step failing deletes what was made
  (the seed volume, then the disk).
- **The seed's CD-ROM is where the image's kernel can read it.** Debian's
  cloud kernel has no IDE driver: on PVE, cloud-init never ran from `ide2`
  (hostname `localhost`, no SSH host keys, verified on the serial console)
  and did from `scsi1`. So the seed goes on SCSI beside a SCSI disk and on
  `pc`, SATA on q35 otherwise; PVE's drive on `scsi1` (SCSI or virtio disk),
  `sata1` beside SATA, `ide2` only beside IDE. Install media keeps the
  machine's own CD-ROM bus: an installer has every driver.
- A clone does not inherit the seed as its own (`clone_domain_xml` drops the
  metadata element): its CD-ROM reads the same image, and deleting the clone
  must not delete it. Only the app's own element (its namespace, an absolute
  `.iso` path without `..`) is read.
- The Hardware view shows a cloud-init drive (libvirt: the CD-ROM holding
  the seed its metadata names; PVE: a `vm-<vmid>-cloudinit` volume) as
  "cloud-init" with Remove only: nothing to insert into it. "Add CD-ROM" is
  offered where the guest has no other CD-ROM, as the design has it.

Decisions:

- **libvirt: a copy, not a qcow2 overlay.** An overlay (a backing store on
  the image) is instant and small, but it pins the image: deleting or
  replacing it breaks every guest made from it, the Storage view would have
  to know which volumes are bases (`domblklist` names only the top of a
  chain), and a raw image in an LVM pool cannot be a base at all. A copy is a
  guest's own disk like any other, the image stays free to be deleted or
  updated, and deleting the guest deletes exactly what it owns. The cost is
  the copy's time and space (a 325 MiB Debian image: a few seconds).
- PVE's `import-from` takes `images` or `import` content, not `iso` (PVE
  9.2's check: "needs to be 'images' or 'import'"); the form offers `import`
  only (an `images` volume is some guest's disk).
- **A cloud image's size.** PVE's content listing gives an import qcow2 or
  vmdk's **file size** (`size` 340983808 for a 3 GiB Debian image), not its
  virtual size; `GET /nodes/{n}/storage/{s}/content/{volid}` gives the
  virtual size (`qemu-img info`'s: `size` 3221225472, `used` the file's),
  and needs only what the listing and `import-from` need
  (`Datastore.Audit` or `Datastore.AllocateSpace` on the storage;
  verified on PVE 9.2.2 with a token holding `Datastore.Audit` alone). A
  raw image's listing size is its virtual size already. So the backend
  asks it for each qcow2/vmdk import volume it lists (four at a time; one
  it cannot size stays unknown), and `VirtVolume.capacity` is what the
  guest sees on both backends — libvirt's `vol-dumpxml` `capacity` is the
  virtual size (verified). The form starts the disk at the smallest step
  that holds the chosen image and offers no step below it.
- **A disk is grown, never cut.** Whatever reaches a backend, a copy of an
  image is the image's size at least: libvirt 11.3 makes a 2 GiB image's
  copy 2 GiB when asked for 1 (and `vol-resize` below it is refused: "Can't
  shrink capacity below current capacity"), PVE imports at the image's size
  and refuses to shrink. Both backends read the size the disk came out at
  and grow it only when the request is bigger; otherwise the VM is created
  and started at the image's size and `VirtCreated.diskKeptBytes` says so
  ("The disk was kept at 3.5 GiB, the image's own size…"). Before, a PVE
  request below the image left the VM created and not started, and a
  libvirt one failed the create and deleted the copy.
- PVE's cloud-init upgrades packages at the first boot by default
  (`ciupgrade`, PVE 8.1+): left as PVE has it. The libvirt seed does not.
- PVE privileges: creating with a serial port (`serial0: socket`, as every
  VM here) needs `VM.Config.HWType` (a token without it was refused:
  "Permission check failed (/vms/950, VM.Config.HWType)"); by PVE's code,
  cloud-init needs `VM.Config.Cloudinit` or `VM.Config.Network`, and
  `import-from` `Datastore.Audit` or `Datastore.AllocateSpace` on the image's
  storage — all inside the documented create set (`VM.Allocate`,
  `VM.Config.*`, `Datastore.AllocateSpace`, `SDN.Use`).

Verified 2026-09-26 by the "cloud images" groups of
`test/e2e/virt_real_test.dart` (everything named `sbxe2e*`, removed
afterwards):

- **libvirt 11.3** over SSH as root: a Debian 13 genericcloud image in a
  pool of the test's own; a UEFI VM copied from it (4 GiB, virtio) with a
  seed made by `genisoimage`, started; logged in to over SSH through the host
  with the generated key: hostname, the account, passwordless sudo, the
  shadow hash the app made (and the password makes it under the guest's own
  `crypt(3)`), the disk grown to 4 GiB; the password not in the seed;
  a CD-ROM drive added (SATA, empty) and removed; deleted with its disk,
  seed and variables file, the image byte for byte as before. By hand
  before: the create scripts with the seed, and `undefine` with the seed.
- **PVE 9.2.2** over SSH with a privilege-separated token holding the create
  set (`VM.Config.*` among it): the same image with `import` content (a hard
  link in `/var/lib/vz/import`), SCSI, UEFI, TPM, a static address and
  gateway; `qm config` with `size=8G`, the cloud-init drive on `scsi1`, the
  EFI and TPM volumes, `ipconfig0`, and no password in it; logged in over
  SSH at the static address: hostname = the VM's name, the account, sudo,
  the password against PVE's own hash, 8 GiB; a CD-ROM drive added while
  running (`ide2`) and removed; deleted with every volume of its
  VMID, the image kept.

#### Editing cloud-init after creation

A "cloud-init" group in the Settings view, after General, for a VM with a
cloud-init drive (`VirtHwDisk.cloudInit`): the user, a password (never
shown: "Set. Leave empty to keep it", and "Remove the password" for keys
only), the SSH keys, the hostname (libvirt; PVE's is the VM's name), and
where the VM has the NIC, DHCP or a static address with gateway, DNS and
search domain. A draft with Cancel / Save, checked with
`virtCloudInitEditIssue` (the create form's rules; a password kept counts
as a way in). Read by `virtCloudInitProvider`, written by
`VirtHostNotifier.setCloudInit` (`VirtBackend.cloudInit` /
`setCloudInit`), made from a revision and refused as `conflict` when the
host's changed since.

| | libvirt | PVE |
| --- | --- | --- |
| Read | The seed itself (`seed_read_script`): `vol-download` of the volume the domain's metadata names into a `mktemp -d` directory, its `cksum`, the bytes as base64 (at most 640 KiB, so a monitor agent's 1 MiB floor holds it). Rust reads the ISO 9660 image (Joliet names, else Rock Ridge `NM`; `iso_root_files`) and the subset of YAML the seed's files are in, and says what it holds that the app does not write (`foreign`: packages, commands, another account, several NICs — the view warns that saving replaces them) | `GET config`: `ciuser`, `cipassword` (answered `**********`: only whether one is set), `sshkeys` (stored URL-encoded), `ipconfig0`, `nameserver`, `searchdomain`, `digest` |
| The password | The seed's hash stays in the backend (`LibvirtBackend._seeds`) and is written back when no new password is typed; a new one is hashed in-process as at creation. The view never gets a hash | Sent in the request body when typed; PVE hashes it. `delete=cipassword` removes it |
| Write | `seed_update_script`, in place: the old seed downloaded, its `cksum` compared with the read's (`conflict` otherwise), the new ISO made as at creation, the volume grown when the ISO is bigger (a file grows by itself, a logical volume would not), `vol-upload` over it; a failed upload uploads the old one back and says whether that worked. The domain, its CD-ROM and the metadata marker are untouched: the seed keeps its volume and path | `POST config` with `digest` (the options, `ipconfig0` keeping its `ip6`, emptied options deleted), then `PUT .../cloudinit` (`VM.Config.Cloudinit`): PVE writes the drive only at a start otherwise, and a reboot from inside the system keeps the QEMU process |
| Instance ID | A new `iid-<name>-<random>` in `meta-data` at every save | PVE's own: `sha1(user-data . network-config)` (`nocloud_gen_metadata`, PVE 9.2.2), so any change to them is a new one; `ci*` options are "fast plug" (no pending entry) |

**When it takes effect.** cloud-init runs most modules once per instance, so
values changed under the same instance ID would be read and ignored; both
backends give a changed seed a new one, and the view says what that means
(a callout under the fields): nothing changes before the next boot; at it,
cloud-init treats the system as a new instance — the hostname set again,
the account made if missing, its password set, its keys **added**, the
network configuration written again, and **new SSH host keys** made (SSH
clients warn of a changed host key). A key taken out of the settings stays
in the system, and a new user name is a new account beside the old one
(both said in the view). Verified on Debian 13, Ubuntu 24.04 and Alpine 3.23
(libvirt) and Ubuntu 24.04 (PVE): after a reboot from inside the system the
new key logs in, the hostname and instance ID are new, the host key
changed, and the old key still logs in. The libvirt seed keeps the hash, so
the shadow entry is the same; PVE's new instance sets the password again (a
new hash of the same password, `$y$` on Ubuntu).

Decisions:

- **The seed is the source of what libvirt shows**, not a copy kept in the
  domain's metadata: it is what the system reads, a seed written by hand
  shows as it is (or as foreign), and nothing can drift. The metadata only
  names the seed, as before.
- **In place rather than a new volume swapped in.** The domain's XML, its
  running CD-ROM and the metadata stay as they are, so there is no define
  to guard; the old contents are kept in the staging directory until the
  upload succeeds. A shorter ISO leaves the old one's tail after it, which
  nothing reads (an ISO 9660 image states its own size).

Verified 2026-09-26 (everything named `sbxe2e*`, removed afterwards):

| What | libvirt 11.3 over SSH (root) | libvirt through the agent and sudo | PVE 9.2.2 over SSH (token) |
| --- | --- | --- | --- |
| Debian 13 genericcloud | created (UEFI), logged in, edited, rebooted into the edit; the phase 7 test (disk in the image's pool) | | earlier (phase 7) |
| Ubuntu 24.04 (noble) | created (UEFI), logged in, edited, rebooted into the edit; asked 3 GiB of a 3.5 GiB image: kept at 3.5, started | | created at 8 GiB and logged in; asked 2 GiB: kept at 3.5 GiB, started, logged in; edited (new key, DNS), rebooted from inside into the edit |
| Alpine 3.23 `nocloud` (BIOS) | created, logged in (doas, `/bin/ash`), edited, rebooted into the edit; the seed made, read back and written anew with each tool | created, seed read back, written anew (hostname, static address, password removed), a stale write refused, deleted | |
| Seed tools | `genisoimage`, `xorriso -as mkisofs`, `mkisofs` (Debian's is genisoimage's link), `cloud-localds`: each booted from (the backend narrowed to it with `LibvirtBackend.seedTools`) | `genisoimage` | PVE's own |
| Image and disk in different pools | images in a pool of the test's own, disks in `images` | the same | |
| TPM | UEFI Debian with `tpm-crb`: swtpm ran for it, `/dev/tpm0` in the system, the state gone with the domain | | earlier (phase 7) |

The libvirt host had `genisoimage`, `xorriso` and `cloud-image-utils`
already; `swtpm` and `swtpm-tools` (and their eight dependencies) were
installed for the TPM run and removed again.

Not verified on a real host: a failed upload putting the old seed back
(stubbed in the Rust tests only), and a seed growing past its LV (libvirt's
`logical` backend has no `vol-resize`; the app's seed is far below the 4 MiB
extent). A seed on LVM, PVE `vmdk` images and cloud-init on SATA and IDE
were run later ("Second pass", phase 10).

### Snapshots: external, config diff, storage support (phase 8)

The phase-2 snapshot machinery extended: a **disk-only snapshot while the
guest runs** (libvirt external snapshots), the **disk chain** the guest is
left on, the **configuration diff** between a snapshot and the guest now, and
PVE's **per-storage support** said before a task is started rather than after
it fails. Scripts: `sbm_virt::libvirt::snapshot` (`snap_chain_script`,
`snapshot_external_script`, `snap_diff_script`); the snapshot listing gained a
per-snapshot `layers` field (`sbm_virt::libvirt::VirtSnapshotInfo`), read from
the same `snapshot-dumpxml` the phase-2 script already collects.

| | libvirt (`virsh`, through `ensureExec()`) | PVE (HTTP API) |
| --- | --- | --- |
| Chain | `snap_chain_script`, one round trip: `dumpxml` (the definition's `<backingStore>` chain), `domblklist --details` (where each device is *now*), then `qemu-img info -U --backing-chain --output=json` per disk — QEMU's own reader, so it is the chain QEMU would open, not what the XML claims. `-U` skips the lock a running guest holds | none: a PVE snapshot is taken by the storage, per volume, and there is no chain to show |
| Create (external) | `snapshot-create-as --disk-only --atomic` **with** metadata, `--diskspec <target>,file=<path>,snapshot=external` per writable disk when a pool was picked | n/a (`snapshotExternal` false) |
| Create (internal) | as phase 2: `snapshot-create-as`, memory on for an active domain | `POST .../snapshot`, `vmstate=1` |
| Storage support | `snapshot_chain_script`'s own read, in two answers: `snapshot_refusal` (a disk QEMU opened as something other than qcow2 — neither kind can be taken, so the form is not offered) and `external_snapshot_refusal` (that, plus a disk `qemu-img` could not read — a lock, a permission, the tool missing — in its own words, or an overlay with no recorded backing format: only the external kind is disabled, the internal one needs no `qemu-img`) | `GET .../{qemu,lxc}/{vmid}/feature?feature=snapshot` — the question PVE's own web UI asks before it offers the button. `hasFeature` over each of the guest's volumes |
| Config diff | `snap_diff_script`: `snapshot-dumpxml` (whose `<domain>` is the definition at the time) and `dumpxml --inactive`, compared in Rust over the parsed structure | `GET .../snapshot/{name}/config` against `GET .../config`, key by key |

**What the app writes, and why.** `--disk-only --atomic`, with metadata (no
`--no-metadata`). The overlay pool picker starts on "beside each disk": no
`--diskspec`, and libvirt puts `<disk>.<snapshot>` in the disk's own
directory. A pool picked instead is one of the host's active pools of files
(`dir`, `fs`, `netfs`: a `logical` pool's `/dev/<vg>` target is no place for
a file), and every overlay goes in its directory by `--diskspec`. The pool a
disk is shown in is the one whose directory holds its file, read from the
pool list — never guessed from the path.

- **With metadata.** The layer then appears in `snapshot-list` like any other
  snapshot, `snapshot-dumpxml` names the file it was left on, and a revert can
  be asked for through libvirt. `--no-metadata` leaves a guest whose disks no
  longer match its definition with nothing recording the previous file — a
  state this app does not put a guest in.
- **`--atomic`.** libvirt makes every disk's overlay first and removes the
  ones it made if any fails; without it a guest can be left with one disk
  overlaid and another not.
- The previous overlay is **not** removed. The guest's old file becomes the
  new overlay's backing store, and a new file (`<disk>.<snapshot>`) is what
  the guest writes from then on; deleting the snapshot is what merges them
  back.
- **No pool picked: no `--diskspec` at all.** libvirt then names each overlay
  `<disk>.<snapshot>` beside the disk it backs, which needs no pool lookup and
  cannot disagree with what libvirt writes into its own metadata. A picked
  pool is resolved to its directory from the storage listing, once.

**Reverting a chain — verified on libvirt 11.3 (Debian 13, AppArmor).**
`snapshot-revert` on an external snapshot does **not** put the guest back on
the file the snapshot recorded, and commits nothing:

1. libvirt deletes the overlay the guest was writing to, with whatever was
   written since the snapshot;
2. it starts the guest on a **new** overlay of the file the snapshot kept,
   named after that file with its extension replaced by a timestamp
   (`ov1.qcow2` → `ov1.1790504997`), and the snapshot's layer now names it.
   The chain is as deep as before: reverting the newest of two snapshots
   leaves `ov1.<ts>` → `ov1.qcow2` → the base;
3. on an AppArmor host the new file has to be read by libvirt's
   `virt-aa-helper`, whose own profile reads a file of any name only under
   `/var/lib/libvirt/images`, `/srv`, `/opt`, `/mnt`, `/media` and home
   directories, and elsewhere only a known extension (`.qcow2`, `.img`, …).
   The timestamped name has none: in a pool outside those directories the
   revert failed (`Could not open '<kept file>': Permission denied`), the
   guest was left shut off on the new file with the overlay it had been
   running on deleted, and it did not start again. In
   `/var/lib/libvirt/images` the same revert, and the start after it, went
   through. So the app refuses a revert there before sending
   (`snap_revert_refusal`, read by the same one-round-trip check as a
   delete), naming the directory.

So the app offers a revert only on a **leaf** (a snapshot with no children),
which is what `VirtGuestSnapshot.hasChildren` states, and the view disables the button with
the reason rather than letting the host fail. The snapshot listing's `<disks>`
carries a `<revertDisks>` element once it has been reverted to, naming where a
*further* revert would go; the parser reads that instead when it is there.

**Deleting on an AppArmor host.** A delete is a `block-commit` of the
snapshot's overlay into the file below it. libvirt's `virt-aa-helper` writes
`deny "<file>" w` into the domain's profile for every file that was already
a backing file when QEMU started, so a commit into one is refused
(`block-commit: Could not open '<file>': Permission denied`), running or shut
off: Debian bug #932456, libvirt issue #806, still in Debian 13's 11.3.
Ubuntu carries a patch; upstream has none. On such a host only the newest
snapshot taken while the guest ran deletes. A refused delete leaves
`<snapshotDeleteInProgress/>` in the snapshot below, and libvirt refuses that
one's delete afterwards (`snapshot disk 'vda' was target of not completed
snapshot delete`); how to clear it was not established.

So the app asks before sending (`snap_check_script` /
`snap_delete_refusal`, one round trip) and refuses a delete the host would
refuse, naming the file and the bug:

- **running**, `dominfo` saying `Security model: apparmor`: refused when the
  domain's profile (`/etc/apparmor.d/libvirt/libvirt-<uuid>.files`, world
  readable; only its `deny` lines are printed) denies writing a layer's
  commit target — the file below the snapshot's layer on the current chain;
- **shut off**, the host's first `<secmodel>` being `apparmor` and the domain
  without `<seclabel type='none'>`: always refused, since libvirt starts QEMU
  for the commit with the whole chain already below.

Anything it cannot read (no profile, an internal snapshot, a layer not on the
chain) is left to the host. The profile's UUID is read from `dominfo`:
`virsh domuuid` refuses a UUID as its argument, and the app names domains by
one.

**Not a chain the app cannot read back.** `external_snapshot_refusal` refuses,
before anything is sent: a guest with no disk, a disk `qemu-img` could not
read (its refusal is kept per disk, in its words), a disk whose format is not
qcow2 (an external snapshot needs a qcow2 base), and a layer whose backing
format is not recorded (`backing-filename-format`). The last one is the subtle case: a definition without a
`<driver type>` on a qcow2 file is a chain QEMU reads as raw (`backing file
format: raw`, verified), which is exactly a chain whose layers would be opened
as the wrong format.

**The diff.** Only what the design's groups name is listed — processor,
memory, disks, interfaces, firmware, boot, other — and only where it actually
differs. A device's `<alias>`, `<address>` and the **file it currently sits
on** are left out: libvirt writes the first two from its own counters, and an
external snapshot always moves the third, so none of them is a configuration
change (the chain view is what shows the files). Values are the host's own
(`262144`, `e1000e · network=default`, `local-lvm:vm-900-disk-0,size=8G`) with
a human label on the group and key; PVE's listing keys (`digest`, `snaptime`,
`parent`, `description`) and what PVE writes by itself (`meta`, `smbios1`,
`vmgenid`) are never shown.

**PVE's storage support, checked before the task.** PVE has no `snapshot`
content kind: `content` lists what may be *stored* (`images`, `rootdir`,
`iso`, …), and snapshot support follows the storage's type and the disk's
format. Its own answer is `GET .../feature?feature=snapshot`, which is what
its web UI asks before offering the button (`PVE::QemuConfig::has_feature`
over each volume, so a guest with disks on **mixed** storages answers false
when any one of them cannot). The form is not offered when the answer is
false, and the reason comes from the guest's own configuration
(`scsi0: local-lvm:vm-900-disk-0`) rather than a task. An API token needs
`VM.Snapshot`, `VM.Snapshot.Rollback` and `VM.Audit` for the question, and
`VM.Config.Memory` (or whichever key is diffed) for nothing — the diff only
reads.

`virtSnapshotSupportIssue` and `virtPveStorageMaySnapshot` are the form's own
hints; the host's answer is what decides.

Verified 2026-09-26 by the "snapshots: external, chain and diff" groups of
`test/e2e/virt_monitor_test.dart` (libvirt over the agent, PVE over the
relay), everything named `sbxe2e*` and removed afterwards:

- **libvirt 11.3**, through the providers: a VM of the run's own with a qcow2
  disk; `snapshotChain` reads one layer, `snapshotExternal` true, no refusal;
  a disk-only snapshot while it runs leaves it **running**, the chain reads
  two layers with the overlay backing the file the guest was on, and the
  listing carries that file; a memory change in the definition shows in the
  diff as a memory row and nothing else; a second snapshot deepens the chain
  to three and **deletes cleanly** (depth back to two); reverting to the
  newest leaves the guest on a new overlay over the file that snapshot kept
  (two layers, readable); deleting the snapshot that was reverted to is
  refused by the host (`block-commit: Could not open '<file>': Permission
  denied`, AppArmor's `deny ... w` on the base) and the app shows its words.
- **PVE 9.2.2**, through the relay with a privilege-separated token: a VM on
  `lvmthin` answers `hasFeature` and snapshots; a memory change in the
  configuration reads as a memory row in the diff, with `digest`/`snaptime`
  left out; a VM on a `dir` storage holding a **raw** disk answers
  `hasFeature: 0` (`snapshot feature is not available` on the task, captured)
  and the app refuses before sending, naming the storage — no task is started
  and no snapshot appears.

By hand on the libvirt host (fixtures): the external snapshot's exact naming
(`<disk>.<snapshot>`), `qemu-img info -U --backing-chain --output=json` for a
one-, two- and three-layer chain and for a raw disk, `domblklist --details`, a
pool's `pool-dumpxml`, a snapshot's `<revertDisks>`, and the diff script
before and after a vCPU, memory and NIC-model change.

Verified again 2026-09-27 over SSH (`test/e2e/virt_real_test.dart`, the
"snapshots: external, chain and diff" and "storage support and the config
diff" groups, all passing): on libvirt 11.3 two external snapshots with no
pool picked (each overlay beside the disk), a revert to the newest leaving
three layers on a new file, the delete after it refused by the app before
it was sent (no `snapshotDeleteInProgress` left on either snapshot), and the
guest's delete leaving nothing in its pool; the check's three captured
states (running with `deny` lines, shut off, running without) matching what
the host then did with the delete in each; on PVE
9.2.2 the `lvmthin` snapshot and diff, and a raw disk on a `dir` storage
refused naming the storage. By hand, through the parser: a disk at a path
with two spaces and a `*` read with its backing file, and a missing disk
file kept as that disk's error in qemu-img's words (`Could not open ...: No
such file or directory`), refusing the external form only.

Not verified on a real host: PVE's `zfspool` and `rbd` storages (only
`lvmthin` and `dir` were available). Two writable disks, an external
snapshot refused on LVM, and an internal revert after an external one were
run later ("Second pass", phase 10).


## One implementation: `sbm_virt` (issue #1623 item 5)

The model, both backends' mapping onto it and the PVE session live in
`crates/sbm_virt`, shared by the app (FFI) and the monitor agent's `/virt`
(the web panel's Virtualization page):

- `sbm_virt::model` (host, guest, state, actions, capabilities, usage),
  `rates` (counters into usage), `error` (the failure kinds, and a `Detail`
  code for what a client phrases itself).
- `libvirt` — the `virsh` scripts and parsers (moved out of `sbm_parser`)
  and `libvirt::host`: the overview read into the model, the power plan (a
  crashed domain is destroyed before it starts). The app's `LibvirtBackend`
  keeps running the scripts and the sudo flow; `LibvirtRates` (FFI) maps
  each load.
- `pve::Client` — login (password + TOTP, or a token), ticket renewal, one
  new login for a refused ticket, the certificate decision (CA-valid against
  the Mozilla roots, or the pinned leaf, decided in the handshake), the host
  view with the state read after an action laid over the lagging listing,
  power and its task. It reaches the API over a byte stream the caller opens:
  the agent dials TCP itself; the app gives it an authenticated loopback
  tunnel of its `ServerTcpDialer` (`PveSession`, FFI), so SSH, the agent's
  relay and a local socket all work as before.

Since 5.2 also `sbm_virt`'s: a guest's detail (`pve::resources::parse_config`,
`libvirt::host::detail_of`), PVE's stored history (`parse_rrd`), console
tickets (`Client::console`, the serial port termproxy takes, the
`generate-password` fallback) and opening a console's `vncwebsocket` with
termproxy's framing (`Client::open_console`, `pve::termproxy`; the agent's
`/virt/console/ws`). The app still opens its console websocket itself
(`PveBackend.openConsoleSocket`, Dart's TLS path) with the session's headers.

Since 5.3, snapshots: `sbm_virt::snapshot` (the model, the chain, a diff and
its groups, the rules a form checks: `name_issue`, `memory`), PVE's listing,
storage support, diff, create, revert (with the start task waited for) and
delete on `pve::Client`, and libvirt's mapping (`host::snapshot_of`,
`chain_of`, `overlays`, `pool_of_file`). The app's `virtSnapshotNameIssue`,
`virtSnapshotMemory`, `virtPoolHoldsFiles` and `virtPoolOfFile` call them.

Still in Dart until their part of item 5 moves them (each marked
`TODO(migration)`): every other PVE call `PveBackend` makes, built by a Dio
whose adapter hands the request to `PveSession.raw` (the session's rules
apply; the status and body come back as PVE sent them), and a console's
websocket and an upload, which are connections of their own authenticated
with the session's headers.

Not verified on a real host since the move: the session in Rust (renewal,
TOTP, a refused ticket replaced) against PVE, and libvirt through the agent's
`/virt`. The Dart client these replace was (below); the Rust port is
locked by `crates/sbm_virt/tests/pve_client.rs` and `pve_tls.rs`, ported
from the Dart tests, and the app's remaining PVE tests now run through the
FFI session against a TLS fake. The clock-driven real-host tests (a renewal
an hour on, a challenge past its lifetime) went with the Dart session.

## Verified against real hosts

`test/e2e/virt_real_test.dart` (opt-in; its header lists the variables) and
`crates/sbm_virt/tests/ssh_e2e.rs` (`ssh_e2e_virt`), run 2026-09-25 against
PVE 9.2.2 (proxmox-termproxy 2.1.0, pve-xtermjs 6.0.0; API token auth, and
password auth with and without TOTP for throwaway `@pam` accounts) over an
SSH channel and directly, and against libvirt 11.3.0 / QEMU 10.0.13 on
Debian 13 over SSH. What they established:

| Topic | Result |
| --- | --- |
| termproxy handshake | `OK` comes back as its own 2-byte binary frame; terminal output follows in binary frames. |
| termproxy input | Binary frames and text frames both work (`0:<len>:<data>`); resize and a 1 s keep-alive leave the session running. |
| termproxy refusal | A wrong ticket, or the wrong user beside a good one, gets no reply: the websocket ends with 1006 and no close frame. It surfaces as "closed before OK" (`unreachable`). |
| termproxy user | With an API token, `user` in the termproxy answer is the token id (`root@pam!name`); that is the user the handshake must send. |
| vncproxy | `websocket=1` alone already generates an 8-character `password` and answers the ticket as `<password>:PVEVNC:...`; `generate-password=1` is accepted. RFB 3.8 greeting, security types `[VNC auth]`; DES auth with the password succeeds and a wrong one is refused. |
| `/cluster/resources` lag | It is `pvestatd`'s last broadcast: a container read `running` there for ~8 s after its `stop` task had ended, and a reboot kept the old uptime. `PveBackend` now reads `status/current` after each action and lays it over the listing until the listing agrees (at most 30 s). |
| TLS | Unpinned self-signed → `certUnconfirmed` with the SHA-256; confirming pins it; a different pin → `certChanged` with both fingerprints. Same over SSH (`localhost:8006`) and direct. |
| Password login | `POST /access/ticket` (`realm=pam`, `new-format=1`) answers a ticket `PVE:<user>@pam:...` plus `cap`. Both configurations work: SSH by key with `PveConfig.pwd`, and SSH by password with that password reused (a stored `pwd` is then ignored). The certificate question comes before any password is sent. |
| Wrong password | `401 authentication failure`, body `{"message":"authentication failure\n","data":null}`, after a delay of about 3 s. Surfaces as `authFailed` with that text. |
| TOTP challenge | The first factor answers 200 with `NeedTFA: 1` and a ticket `PVE:!tfa!{"totp"%3Atrue}:...`, with or without `new-format`. It is answered with `password=totp:<code>` and `tfa-challenge=<ticket>`. |
| TOTP answers | A wrong code: 401 `authentication failure`, and the challenge still answers. A code already used: 401 (the journal says `rejecting reused TOTP value`). The next 30 s step's code is accepted. One challenge can be answered successfully more than once while it is valid. |
| TOTP lifetime | A challenge is verified like a ticket (`verify_ticket`, `$ticket_lifetime` = 2 h, `PVE::AccessControl`), and an expired one is answered exactly like a wrong code — so `submitTfa` replaces an old one rather than answering it. |
| Ticket renewal | `password=<current ticket>` issues a new ticket, for a TOTP account too, without asking for a code. `pvedaemon` logs it as `successful auth`. |
| Refused session | A disabled account's ticket gets `401 Authentication failed!`, and its login `401`. Enabled again, the next call logs in again. |
| Console as a user | With a ticket session, termproxy's `user` is `<user>@pam`, and the websocket authenticates with the `PVEAuthCookie` cookie. |
| Uptime after a reboot | `status/current` can answer `uptime: 0` in a container's first second after `reboot`; the overlay counts it up from there rather than leaving it at 0 (read as no uptime). |
| QEMU test VM | VM 101 `pve-e2e-vm` (Debian 13 cloud image, 1 vCPU, 1 GiB, `serial0: socket`, `vga: std`, cloud-init, no guest agent), driven by `SBM_E2E_PVE_TEST_VM` over SSH, directly and through the agent's relay; the same results on all three. |
| Paused QEMU guest | `status/current` answers `status: running`, `qmpstatus: paused`; `/cluster/resources` answers `status: paused` within pvestatd's cycle. Both read as `paused`, offering resume and force stop, not suspend. The uptime keeps counting while paused. |
| QEMU start | The `qmstart` task ends in ~1 s, and the guest reads `running` at once. Its serial getty answers ~15 s later. |
| QEMU reboot | Without the guest agent it is an ACPI shutdown (`qmreboot`, 3–6 s here); the task ends once the guest is down and `qmeventd` starts it in a `qmstart` task of its own ~1 s later. `status/current` read straight after the task says `stopped`, which `PveBackend` recorded and showed as stopped (offering start, refused as "already running") for up to 30 s; it now reads again until the guest runs (at most 30 s). The uptime restarts. |
| QEMU ACPI shutdown | A booted Debian guest is `stopped` when the task ends, 2–4 s. A request sent during boot (~3 s in) is lost: the task waits 60 s and fails with `VM quit/powerdown failed - got timeout`, the VM still running (`actionFailed` with that text). |
| Stop, then start | A start within about a second of a stop leaves `qmeventd`'s cleanup of the old process holding the config lock until it gives up 30 s later ("QEMU process ... still running (or newly started)"). Every action in that window fails after 10 s with `can't lock file '/var/lock/qemu-server/lock-<vmid>.conf' - got timeout` (`actionFailed`). A few seconds between the two avoids it. |
| Locks | `qm set --lock backup`: the listing shows the lock within pvestatd's cycle, the VM reads `backup` and offers only suspend (resume when paused) — `vm_suspend` and `vm_resume` skip the lock check for a backup, and both succeeded. A stop under it is refused by PVE: task error `VM is locked (backup)`. Any other lock (`snapshot`) offers nothing, and PVE refuses a suspend with `VM is locked (snapshot)`. A running VM under a backup lock keeps its CPU and memory readings. |
| One action at a time | `VirtHostNotifier.power` refuses a second action on a guest with one in flight (`unsupported`); the guest reads as the action's transient state and offers nothing until the first returns — except force stop over a shutdown or reboot. |
| Force stop over a stuck shutdown | A VM with no OS ignores ACPI: `status/shutdown --timeout 300` held it, and a plain `status/stop` sent 3 s later left it running 10 s on; `status/stop` with `overrule-shutdown=1` stopped it in 2 s (PVE 9.2.2). |
| libvirt VNC password | A throwaway domain with `passwd` on its VNC `<graphics>`: `dumpxml --security-info` over the agent and sudo gives it, the real VNC engine behind the authenticated relay loopback connects with it, and a wrong one ends `authenticationFailed`. A process without the tunnel's token got 0 bytes. `virsh -r dumpxml --security-info` is refused with `operation forbidden: virDomainGetXMLDesc with secure flag`. |
| Engine end reason | A session that failed fast (a refused VNC password) sometimes read as ended with no reason: `next_event` returned None once the frame channel closed, while the `Error`/`Ended` events were still queued (2 of 3 runs). It now drains the queue first. |
| QEMU serial console | `termproxy` with `serial=serial0` (a task named `vncproxy`, `starting qemu termproxy`) reaches the guest's `ttyS0` getty; a root login with the cloud-init password and a command work through it, and `exit` returns to `login:`. |
| QEMU detail | `scsi0` (8 GiB, `local-lvm`), `ide2` cloud-init as a read-only CD-ROM, `net0` virtio on `vmbr0` with its MAC, graphics `std`, consoles VNC and text, `ostype` `l26`. |
| pveproxy keep-alive | pveproxy closes an idle connection after 5 s (`PVE::APIServer::AnyEvent`, `timeout`). `HttpClient` kept one for 15 s, and a request sent on it after a 5 s pause failed with `Connection closed before full header was received` (`unreachable`), directly and over SSH. `PveBackend.idleTimeout` is now 3 s. |
| libvirt `domstats` | A shut-off domain still reports the last run's `cpu.*`, `balloon.current/maximum`, `vcpu.*` and block sizes. `--vcpu` prints ~65 KVM counters per vCPU, now dropped on the host. |
| libvirt errors | `start` on a running domain says `Domain is already active` (now `invalid_state`). A domain name containing `"` cannot start on an AppArmor host (`virt-aa-helper: bad name`); libvirt's text is shown. A user outside the `libvirt` group gets the polkit refusal (`permission_denied`). |
| libvirt consoles | `virsh console --force` attaches in a PTY shell and Ctrl+] returns to it; `domdisplay` gives `vnc://127.0.0.1:0`, and the SSH loopback tunnel to 5900 carries the RFB greeting. |
| libvirt snapshots | An internal snapshot of a running domain without memory (`--memspec snapshot=no`, with or without `--diskspec ...,snapshot=internal`) is refused: `internal snapshot of a running VM must include the memory state`. A paused domain's snapshot holds memory too (`<memory snapshot='internal'/>`, state `paused`). One taken shut off has `<memory snapshot='no'/>`, state `shutoff`; reverting a running domain to it leaves it `shut off (from snapshot)` without `--force`, and one with memory resumes it `running (from snapshot)`. A raw disk: `internal snapshot for disk vda unsupported for storage type raw`. A name taken: `domain moment <name> already exists`. An unknown one: `Domain snapshot not found: no domain snapshot with matching name`. `snapshot-current --name` prints no trailing newline, and fails (`has no current snapshot`) on a domain without any, which reads as none. `snapshot-dumpxml` carries the whole domain XML (~5 KB each); `--no-domain` does not exist on 11.3. |
| libvirt storage | `pool-list --details` and `vol-list --details` print human units only (`19.49 GiB`), so sizes come from `pool-dumpxml` / `vol-dumpxml` (`unit='bytes'`). `vol-list` pads the Name column, so a volume named `my disk.qcow2` is split from its path by the header's `Path` column. An inactive pool's `pool-dumpxml` reports 0 for capacity, allocation and available (read as unknown), and `vol-list` fails. `domblklist --details` lists a shut-off domain's disks and an empty cdrom as `-`. |
| libvirt networks | No `<forward>` is an isolated network; `<forward mode='bridge'/>` names the host bridge in `<bridge name>`. `connections=` is present only while interfaces are attached. `domiflist` lists a shut-off domain's NICs with `-` for the host device. `net-dhcp-leases` gives `date time mac proto ip/prefix hostname client-id`. |
| PVE snapshots | A VM: `vmstate=1` while running saves its memory to a volume of its own (`vm-101-state-<name>`, 2.6 GiB for a 1 GiB guest), listed as `vmstate: 1`; stopped, the parameter is ignored and the snapshot has none. A container never has memory. Rolling a running VM back to a snapshot without memory leaves it `stopped`; with memory, `running`; with `start=1`, running either way. A name that is not a `pve-configid` is a 400 `invalid configuration ID`; a name taken, or a snapshot that does not exist, is answered with a UPID all the same, and the task fails (`snapshot name 'x' already used`, `snapshot 'x' does not exist`) — `actionFailed` with that text. An empty description is listed as `""`, a multi-line one with a trailing newline. |
| PVE rollback with `start=1` | The rollback task ends, and the start runs as a `qmstart`/`vzstart` task of its own, holding the guest's lock: a container's took 44–45 s here, and a snapshot deleted meanwhile failed with `Failed to obtain guest migration lock - replication running?`. `revertSnapshot` now waits for that task (it appears with the rollback's end). |
| PVE lock after a rollback with memory | A stop sent right after rolling a VM back to a snapshot with memory failed twice with `can't lock file '/var/lock/qemu-server/lock-101.conf' - got timeout`; it went through 26 s after the rollback. What holds the lock is not established. A snapshot delete straight after a `rollback start=1` failed the same way. The e2e test retries on these two messages; the app shows PVE's text. |
| PVE storage and network | `lvmthin` has no path, only `vgname`/`thinpool` (shown as `pve/data`); `content` lists `vmid`, `format`, `size`, `ctime` (a string on some storages), and no `used` for `lvmthin`. `/nodes/{node}/network` lists `bridge_ports`, `cidr`, `gateway`, `active`, `autostart` for a bridge; an unused port has neither `active` nor `autostart`. |

### Over a monitor agent

`test/e2e/virt_monitor_test.dart` (opt-in; its header lists the variables),
run 2026-09-25 through the providers themselves (`VirtHostNotifier`,
`VirtHosts`, `VirtConsoleConnect`, `TerminalSession`) for servers carrying
only agent credentials, against agent 0.1.3 over TLS on the same two hosts.
Both agents run as an ordinary account (`install.sh`'s user service), which
on the libvirt host is outside the `libvirt` group.

| Topic | Result |
| --- | --- |
| libvirt over `/exec` | The agent's account is refused by polkit (`permission_denied`) → `sudoPasswordRequired`; a wrong password is `sudoPasswordRejected`; the right one lists, samples rates, reads detail and resumes/suspends a domain, all through `sudo -S` with the password on stdin. The host list's probe counts the refusal as "found". |
| libvirt VNC | `ServerTcpDialer.loopback` over `/api/v1/stream/ws` to `127.0.0.1:5900` carries the RFB greeting. |
| libvirt serial | `TerminalSession` picks `MonitorShellBackend`; `sudo virsh console` typed into the agent's PTY prompts for sudo's password in the PTY, attaches, and Ctrl+] returns to the shell. |
| PVE over the relay | `https://localhost:8006` resolved by the agent: `certUnconfirmed` → confirm → pinned in `server_pve`, load, LXC reboot with its task, termproxy on the container, vncproxy with VNC auth through the websocket tunnel. The grant had not been read yet (no status poll first), and the relay was tried rather than refused. |
| PVE QEMU over the relay | The test VM's power cycle (start, suspend with a second action refused while it runs, resume, reboot, ACPI shutdown, start, force stop), detail, serial login and VNC auth, through the providers. |
| Snapshots, storage, networks | libvirt through the agent's `/exec` and `sudo -S`: pools with their volumes, networks, and a snapshot of the shut-off domain taken and deleted. PVE through the relay: storage with the volumes of VM 100, bridges with VM 100 and CT 200 on them. |
| `full_access` off | libvirt: `/exec` answers 403 → `execNotGranted` (was `unreachable` with a DioException's text). PVE: the relay is `relayNotGranted` whether the grant was read (refused before dialling) or not (the agent refuses the stream ticket with 403; was `unreachable`). |
| Refused before dialling | The dialer failed its socket future before `HttpClient` listened to it, and so did `PveBackend`'s TLS future on top: the load failed correctly *and* the zone got an uncaught error. Both futures are now marked handled. |
| External snapshots (phase 8) | libvirt through the agent's `/exec` and `sudo -S`, the whole flow through the providers: a guest of the run's own, a disk-only snapshot while it runs, the chain read back, a memory change read as a diff, a second snapshot, a clean delete of it, a revert onto a new overlay, and the app's refusal, before sending, to delete the snapshot that was reverted to (AppArmor). PVE through the relay: a VM on `lvmthin` snapshotting and its memory change read as a diff; a VM on a `dir` storage added for the run with a raw disk answered `hasFeature: 0` and refused before any task. |

Not verified on a real host: a ticket that expired on the server's clock (the 2 h expiry and the
renewal were driven by the backend's injected clock against real tickets),
clusters (storage and networks per node), PVE before 9.2, and PVE bonds,
VLANs and OVS (parsed from hand-written payloads only). A real backup job's
lock, the guest agent's shutdown and libvirt's `logical`/`netfs` pools were
run later ("Second pass", phase 10).

## UI

Follows the repo's tab conventions (`CLAUDE.md` → Tabs):

- `AppTab.virt`, appended after `remoteDesktop`. It takes index 7; 7 stays in
  `_retiredIndices`, which is correct: tabs are persisted by name, and the
  only integer path is reading legacy Hive values, where 7 must keep meaning
  "nothing". Update `tab.g.dart`, `app_tab_test.dart`, `home_tab.dart`
  (page, label, both icon sets), `macos_menu_bar.dart`, `_navMenuFor`, the
  theme icon keys in `docs/schemas/fsbt-manifest.schema.json`, and l10n.
- In `AppTab.defaultOrder` for new installs, after `agent`. Existing
  installs keep their bar; the migration below adds the tab for users who had
  PVE configured.
- Wide: `SessionSwitcherLabel` host switcher over a list column (guests
  grouped by state; sections VMs / Storage / Network as fl_lib
  `SegmentedTabs`, a section the host's capabilities lack left out — both
  backends have all three) and the detail beside it:
  a guest (Overview, Console, Hardware, Snapshots, Settings; a guest with a
  terminal and a screen offers them as the Console segment's second level,
  `SegmentedTab.sub`), a pool (capacity, what it is, its
  volumes with the guests using them) or a network (configuration, the guests
  on it — a tap opens the guest in the VMs section).
- Narrow: the single column is the selected host's list in the chosen
  section; the host list is behind the switcher sheet; a guest, pool or
  network is pushed (`VirtGuestPage`, `VirtPoolPage`, `VirtNetworkPage`), and
  its bar's switcher moves to another in place.
- Snapshots view (`view/page/virt/snapshots.dart`): the tree by indent, the
  current one marked; a row opens to its time, parent, description and
  Revert / Delete. The new-snapshot form checks the name as it is typed and
  shows memory as the host allows it: a switch (PVE VM, running), on and
  fixed (libvirt, active), or a note (stopped). Revert and delete are
  confirmed; a revert to a snapshot without memory on an active guest is
  asked in red with "start it afterwards". Phase 8 adds the disk chain group,
  the internal/external kind (libvirt) with its overlay pool, the
  configuration diff (a row's own button, and the revert dialog), and the
  refusal of a revert on a snapshot with children.
- Design deviations in the Hardware and Settings views, and why:
  - drafts with Save / Cancel where the design applies each step (a step
    is not a change to the host);
  - the boot order is the design's numbered rows with up/down arrows (the
    design has no drag), and tapping a row includes or leaves out a device;
  - "revert" rows and the notice's "revert all" icon, which the design has
    no place for (PVE's pending list);
  - delete keeps no typed name: the design's two presses;
  - adding a CD-ROM offers an ISO to put in it (the design's adds an empty
    drive), and a cloud-init drive is a row of its own with Remove only;
  - PVE shows no protocol or listen rows in the display group: neither is a
    PVE setting (VNC through its proxy; SPICE follows the `qxl` card); the
    port row is shown only where the host fixed one;
  - the firmware choice asks before switching (the design switches on tap):
    it is the change most likely to leave a guest unbootable;
  - a NIC's MAC is a row that opens a dialog with "generate", not an inline
    field: one typed character is not one change to send.
- Design deviations in the Storage and Network views (phase 6), and why:
  - a pool with volumes can be removed (the design wants it empty): removing
    a definition keeps the volumes, and the dialog says so; deleting the
    directory is a separate box, only for an empty pool;
  - a volume's capacity is a draft with Grow / Cancel, only for a volume no
    guest uses (a used one grows from the guest's Hardware view), and
    libvirt only;
  - attaching from the pool view offers VMs, not containers (a mount point
    would be one more question); cloning a volume is libvirt only;
  - a network's configuration is edited in phase 10, in place as the
    design has it, but as a draft with Save and Revert (below);
  - the new libvirt network form has a routed mode and the DHCP range fields
    (the design has three modes and the range only in the detail); a netfs
    pool asks for its mount point (prefilled `/mnt/<name>`);
  - PVE's pending network changes are a card above the network list and the
    network (Show changes, Revert, Apply), where the design has one line of
    text;
  - PVE volume formats follow the storage (qcow2 on a directory), where the
    design offers raw only; upload is offered on every libvirt pool of files,
    not only one already holding ISOs.
- Design deviations in the Snapshots view (phase 8), and why:
  - a **disk chain** group above the list, which the design has no place for:
    the design's "存于 qcow2 内部" right-hand note is true of phase 2's internal
    snapshots, and an external one leaves the guest on a chain whose layers
    have to be nameable. It is drawn the way the design draws a device — a
    card that lists each disk and, under it, each file by depth, the top one
    marked "in use now" and the last "base image";
  - a **snapshot kind** choice (internal / external) in the create row, only
    where the host writes both, with the overlay pool under it: the design's
    single "包含内存状态" switch does not say which of the two libvirt forms
    is being written, and an external one has no memory to offer at all;
  - the **diff** opens from a snapshot's row ("与当前比较") and is shown in the
    revert dialog, where the design shows only the revert's own warning: the
    design has no diff, and a revert is the moment it matters. Its rows are
    the design's `field` rows (name left, value right) grouped under the
    design's own headings;
  - a revert is **disabled** on a snapshot with children, with the reason
    under it, where the design always offers it: such a revert failed on
    libvirt 11.3 and left the guest shut off (see the phase-8 section);
  - a guest whose storage the host says cannot be snapshotted (PVE) gets the
    reason instead of the create row, where the design always offers it.

- Design deviations in the network editing, the revert and the small items
  (phase 10), and why:
  - the configuration rows are edited in place, as the design's `cfg`
    group, but as a **draft with Save and Revert**, where the design applies
    each change at once: a real host takes a network change in one write
    (`net-define`, or one `PUT` into PVE's pending configuration), and a
    half-typed address must not reach it. Save is held back, with the
    reason under the rows, while the host would refuse the draft. libvirt's
    autostart is the one row applied at once: it is marked on the network,
    outside the definition the draft writes. The design's "configuration
    file" group is the definition as saved, folded;
  - the **restart is a switch of its own**, on by default and shown only
    where the change actually waits for one (a static host alone applies
    live), with what it does to the guests on the network under it: the
    design's edit applies at once, which for libvirt means the running
    network is left on the old configuration until someone restarts it;
  - a **static host** is a MAC, an address and an optional name, added and
    removed in the configuration rows (the design has no such group): libvirt's static
    DHCP entries are what a guest is pinned to an address by, and they are
    the one part of a network that applies live;
  - **PVE's management interface is not offered at all** (the design would
    edit whatever is listed): applying the interface that carries the
    host's own address cuts it off, and the row says so instead;
  - the **revert-all dialog shows what is discarded** — the same rows the
    Hardware view shows under each field, where the design has a notice and
    a button: a revert that rewrites the definition from the running one is
    the moment the difference matters;
  - **Secure Boot is offered only where the host's firmware descriptors
    back it**, with the reason under the switch where they do not (the
    design always offers it): libvirt refuses a definition whose firmware
    is not there;
  - the cloud-init group **counts the NICs the seed configures** and edits
    the first (the design has one address group): a save keeps the rest as
    they are, and saying how many there are is what stops it looking like
    one;
  - **a password's expiry is libvirt-only**, and the switch says so in its
    note: PVE writes `expire: False` itself and has no option for it;
  - USB passthrough is offered **by vendor and product or by the address
    the device sits at**, as the design's device list has one entry per
    device.

- Design deviations in the Templates, Clone and Backup work (phase 9), and
  why:
  - **a Backup section of the tab** (PVE), where the design's Plan group is
    read-only and points at "数据中心 → 备份": a job that takes every guest
    (or a pool) belongs to no guest, and a guest's own Plan group can only
    say "one of them takes you". A job that takes the guest alone
    (`VirtBackupJob.takesOnly`) is the exception: the Plan group makes,
    edits and deletes one in place, with the section's own rows (`_JobForm`,
    less the node and the guests; a new one has no node, so it runs wherever
    the guest is). A job that takes other guests too is read there, says
    whom else it takes, and opens in the section (a page with one column).
    The section is the same `SegmentedTabs` the
    Storage and Network sections are, and a job is edited on the design's own
    sectioned pane (the Hardware view's groups and index) rather than in a
    dialog;
  - **a template's own state in the list**, which the design's state set
    (`LIVE`: running, paused, stopping, rebooting, migrating, backup) has no
    member for. It is grouped under "Template" after the state groups, and
    its row's right-hand meta reads "Template" where a running guest's reads
    its CPU: a template is not a stopped guest, and it never becomes one;
  - **Clone is a banner and a button on a template's overview**, where the
    design would leave the guest's own view. The clones' names come from the
    Clone group in Settings, and the design's two-step "press again" would
    not say that a template cannot be started;
  - **the run's options are a group of the Backup view**, always in place,
    where the design's "立即备份" row and its `snapshot · zstd` line name the
    same options once: a form that is there is one fewer dialog, and the
    options are what the storage/mode/compression segments show at rest. The
    design's `保留` (retention) is on the job editor, not the run, because
    PVE's `prune-backups` belongs to the storage or the job;
  - **a clone's target storage and node are choice lists** built from the
    host's own storages and nodes, not a text field: PVE refuses a storage
    that holds no images and a node that cannot see it, and a form that
    offers what the host has cannot ask for either. The node row is drawn
    only where the host has more than one, and only on a full clone (PVE
    refuses both on a linked one);
  - **a job's schedule has a "Check with the host" button** rather than an
    inline calendar picker: PVE's own format is a subset of systemd calendar
    events, its parser is the authority, and `schedule-analyze` is the call
    its own editor's "Simulate" button makes. What it answers — the next few
    runs, or the parse error — is shown under the field;
  - **the guest selection is switches over the host's guests**, with "All
    guests" and "Selected guests" as a segment, where the design has one
    read-only line: PVE's `all` less `exclude` and a `vmid` list are two
    different jobs, and a template is left out (PVE refuses to back one up).
    A pool-based job is shown in the datacenter's list and not offered in the
    form: PVE's own editor has it, and it would need a pool listing the app
    does not read.

- The Settings view's cloud-init group, which the design has no place for
  (phase 7's create form sets cloud-init up; changing it later belongs with
  the guest's other settings): the create form's cloud-init rows, a draft
  with Cancel / Save as the view's name and note, and an info callout on
  when it takes effect.
- Design deviations in the create form (phase 7), and why:
  - the design has no cloud image or cloud-init: a "Source" segment (install
    media / cloud image) opens the System group, and a cloud-init group of
    the pane's own rows follows it (user, password, keys, hostname on
    libvirt, DHCP or static address with gateway, DNS and search domain);
  - a TPM switch under the firmware (the design says "add a TPM in Hardware
    afterwards"), only where the host has one; the Windows callout asks for
    UEFI and the TPM there;
  - no command preview in Confirm (the design shows a `virt-install`/`qm
    create` line): the app runs neither, and a line that is not what runs
    would mislead;
  - "None" among the install media (a network boot, or a system later), and
    among the networks; a container's root login is a group of its own (the
    design has none);
  - the VMID is the design's stepper (was a text field); several nodes are a
    segment in General;
  - buses and NIC models are the host's (libvirt: no IDE on q35; `e1000`
    beside the design's `e1000e` and `rtl8139`); the resources group shows
    no host remainder, which the form does not read.
- Power actions with confirmation, as the PVE page does today; busy states
  (`starting`, `stopping`, …) show progress and disable conflicting actions.
  PVE actions return a UPID; poll `GET .../tasks/{upid}/status` until done.
- Errors per host (unreachable, auth failed, TOTP needed, relay or commands not granted,
  virsh permission denied, certificate changed) are shown in the list column
  with the action that fixes them.

## Migration

1. **Code**
   - `pveProvider` → `PveBackend`. Session, login, TOTP, expired-session and
     client-replacement handling move over; the SSH-only `forwardLocal`
     code is replaced by `ServerTcpDialer`.
   - `PvePage` and its route are removed. The `ServerDetailCards.pve` readout
     card stays as an entry point: tapping it opens the tab with that server
     selected (`homeTabRequestProvider.go(AppTab.virt)` + selected host).
   - `pveServerClientMissing` is removed (any transport works now); the other
     `pve*` l10n keys are kept where still used.
2. **Data** — PVE configuration leaves `server` / `Spi` / `ServerCustom` and
   gets its own child table. Schema step `m0xx_server_pve` (class +
   `SchemaVersion.current` + `kSchemaMigrations`):
   ```
   server_pve(
     server_id    TEXT PRIMARY KEY REFERENCES server(id) ON DELETE CASCADE,
     addr         TEXT NOT NULL,
     auth         TEXT NOT NULL CHECK (auth IN ('password','token')),  -- enum by name
     pwd          TEXT,
     token_id     TEXT,
     token_secret TEXT,
     cert_sha256  TEXT        -- NULL: pin on next connect
   )
   ```
   - Copy every `server` row with `pve_addr` into it (`auth = 'password'`,
     `cert_sha256 = NULL` whether or not `pve_ignore_cert` was set). `pwd`
     only where `ssh_key_id` is set: earlier builds sent `pve_pwd` only then,
     and the SSH password otherwise (`PveConfig.loginPassword`).
   - Drop `pve_addr`, `pve_ignore_cert`, `pve_pwd` from `server`. The CHECK on
     `pve_ignore_cert` makes this a create-copy-drop-rename rebuild, done as
     m017 / m028 do it (`foreign_keys` off outside the transaction,
     `legacy_alter_table`), so the six cascading children survive.
   - If any server had `pve_addr`, append `virt` to `homeTabs` (unless already
     present or the bar is full, in which case it stays under "more").
   - Model `PveConfig` (+ `PveAuth { password, token }`), read by server id.
     A child row carries no sync columns, moves with its server in sync and
     backup, and editing it stamps the parent (as `ContainerStore` does).
   - Backups, sync payloads and bulk imports from older versions carry
     `custom.pveAddr/pveIgnoreCert/pvePwd`; they are mapped into `server_pve`
     on import, merged onto an existing row rather than replacing it
     (`PveConfig.mergeLegacy`). This build also writes those fields, so a
     round trip through an older device keeps PVE; a sync record from an
     older build without them leaves the row alone (`BackupV2._pveToRestore`).
     TODO: remove both directions after 5 releases.
   - Hive legacy adapters are frozen and untouched; the Hive import chain
     writes the old columns and this step moves them.
3. **Tests**
   - Port `pve_test.dart` to `PveBackend`: parse fixture, 401 session
     drop (a 403 is a permission check and keeps the session), client replacement, plus token auth and cert pinning (match,
     mismatch, first use).
   - `ServerTcpDialer`: each credential, fallback, relay-not-granted.
   - Migration regression test fed by a database written by the release before
     this step (per `CLAUDE.md`), covering `ignore_cert` and the `homeTabs`
     change.
   - `sbm_virt` libvirt fixtures for `virsh` output (`dart_compat`-style lock).

## IntroPage

A feature page in `lib/intro.dart`:

Gating follows the existing feature pages (`_buildRemoteDesktop`,
`_buildLocalServer`): `introVer` holds a build number and cannot gate a new
page, so feature pages use the `featureIntroVer` counter.

- `_kFeatureIntroVer` 1 → 2; step `_buildVirt`, applies when
  `_featureUnseen(2)`. Shown to every install, fresh ones included, like the
  other feature pages.
- Content: the Virtualization tab manages libvirt/KVM and Proxmox VE hosts
  over SSH, a monitor agent or locally. When any server has a PVE address
  (checked at display time, no stored flag), an extra paragraph says the PVE
  page moved into this tab, that API tokens are supported, and where the tab
  is (bar or "more").
- `_onDone` already writes `featureIntroVer = _kFeatureIntroVer`; nothing else
  to record.

### Templates, clone targets and backup jobs (phase 9)

The design's Plan group becomes something the app manages a level up: a
**Backup** section of the tab (PVE, `VirtCapabilities.backupJobs`) lists the
datacenter's jobs, makes, edits, runs and deletes them, and a guest's own
Plan group reads the jobs that take it, runs one, and edits the ones that
take it alone. A **template** is a
state of a guest (`POST .../template`), shown in the list and the bar, with
no power action and no console; a **clone** can be sent to a storage and a
node of its own.

| | libvirt (`virsh` through `ensureExec()`) | PVE (HTTP API) |
| --- | --- | --- |
| Template | none: a domain is a domain, and a copy of one is a clone (`VirtCapabilities.template` false; the group is not offered) | `POST /nodes/{n}/{qemu,lxc}/{vmid}/template`, the task. PVE refuses a running guest (`you can't convert a VM to template if VM is running`) and one with snapshots (`unable to create template, because VM contains snapshots`), and there is no way back. The disks turn into base images (`vm-910-disk-0` → `base-910-disk-0` on LVM-thin) |
| Clone target | `vol-create-from` on the target pool, with `--inputpool` naming the source's (a `vol-clone` only ever clones within one pool). The XML is the name, `vol-info --bytes`'s capacity and the source's format, written to a `mktemp` file on the host | `POST .../clone` with `storage` (where the copy's disks go) and `target` (the node it is made on); both are refused on a linked clone (`parameter 'storage' not allowed for linked clones`) |
| Backup jobs | none | `GET/POST /cluster/backup`, `PUT/DELETE /cluster/backup/{id}`; a run now is `POST /nodes/{n}/vzdump` with the job's fields minus the schedule — what PVE's own "Run now" does (`/cluster/backup/{id}/included_volumes` is what its detail view *lists*) |
| A backup's own fields | none | `PUT /nodes/{n}/storage/{id}/content/{volid}`: `notes`, `protected` |
| Restore onto a storage | none | `POST /nodes/{n}/{qemu,lxc}` with `archive`/`ostemplate` + `storage` (PVE's "Default storage"), picked among the node's storages that hold guest disks (`images` for a VM, `rootdir` for a container) — not the backup storages, which need not |

Decisions:

- **A template is a guest's state, not a separate list.** PVE's own resource
  list marks one (`template: 1`), so `VirtGuest.template` does, and the list
  groups them under "Template" after the state groups (the design's own `LIVE`
  set has no such state, so this is a deviation — see the UI section). A
  template offers no power action (PVE refuses every one:
  `you can't start a vm if it's a template`), and the guest view drops the
  Console, Hardware and Snapshots segments with it, keeping Overview (where
  Clone is the button), Backups and Settings (where the Clone group is).
- **The template group is in Settings, and says it cannot be undone.** PVE
  has no way back, and its own web UI puts the action under "More"; the
  dialog is red and the note is above the button.
- **`target` is offered only where there is another node.** A copy to
  another node needs a cluster and a storage both see
  (`can't clone VM to node '<n>' (VM uses local storage)`), so
  `virtCloneNodeIssue` and `virtCloneStorageIssue` refuse both before the
  request: the node must be one the host lists, and a storage with `target`
  must be `shared`. On libvirt the pool is the same question and the answer
  is `vol-create-from`, which needs no cluster.
- **The clone form sends neither on a linked clone.** PVE refuses `storage`
  and `target` there, and the backend drops both rather than letting the
  task fail; the form refuses the combination first
  (`VirtCreateIssue.cloneLinkedTarget`).
- **`isNew` on the edit, not `id == null`.** PVE's own panel lets a new job
  be given its id, so a create carries one and still has to be a `POST`; a
  `PUT` of a job that is not there answers `no such vzdump job`.
- **The schedule is checked locally for shape, then by the host.** A
  schedule is systemd calendar format, and PVE's parser is the authority:
  `GET /cluster/jobs/schedule-analyze` is what its own editor's "Simulate"
  button calls, and `virtScheduleIssue` refuses only what is obviously not
  one (empty, a `;`, a newline, a weekday after the time, `Mon-Fri` instead
  of `mon..fri`, a field's part above 59). All 32 values the unit test
  checks were put to the host on PVE 9.2.2 and the local answer matches its
  every time — including `mon 25:00`, which PVE **accepts** (the hour is not
  range-checked the way the minute is). The shape is `[weekday] [date]
  [time]`, each optional and in that order, with `..` ranges: the
  documentation's own `sat *-1..7 15:00` and `mon..fri 8..17,22:0/15` pass
  (not put to a host).
- **A job that takes every guest is not a guest's.** `VirtBackupJob.takes`
  answers for `all` (less `exclude`) and for a `vmid` list, and returns
  false for a pool job: which guests a pool holds is not in
  `/cluster/backup`'s answer, so a guest's Plan group cannot claim one takes
  it. The datacenter's own list shows them all.
- **A run now is the job's fields without its schedule**, as PVE's own UI
  sends it — it clones the job and deletes `enabled`, `starttime`, `dow`,
  `id`, `schedule`, `type`, `node`, `comment`, `next-run` and
  `repeat-missed` before posting it — and to the same nodes: the job's own
  (refused when it is not online), or every online node for a job that
  names none. `vzdump` takes only the guests on the node it runs on (`all`
  is "all known guest systems on this host"), so one request per node is
  what covers a cluster, and no guest is backed up twice.
- **A job takes one of pool, all (less `exclude`) or a list**, the pool
  first. An edit keeps the one it has — the app lists no PVE pools, so a
  pool job offers its own pool beside "all" and "selected" — and names the
  other two in `delete`.
- **A backup's notes and protection are written together.** PVE's `PUT`
  keeps what is not sent, so an emptied note has to be written as one:
  `VirtBackupEdit` carries both and the backend sends both.
- **The run's options live in a group of the Backup view**, next to the list
  that used them, rather than a dialog per press: the design's "立即备份" row
  and its `snapshot · zstd` are the same options, and a form that is always
  there is one fewer thing to open. The group's own button is the same
  backup the list's row makes.
- **Protection is a toggle per backup, and deleting a protected one is
  refused** ("cannot remove protected volume ... on 'local'"): PVE's own
  words are shown, and the row's delete is disabled while it is set.

Verified 2026-09-26 on the real hosts (through `virt_monitor_test.dart`'s
"clone", "clone and backups" and "a template"/"a backup job" groups, every
guest named `sbme2e*`/`sbxe2e*` and removed afterwards):

- **libvirt 11.3** through the agent and sudo: a source VM of the run's own,
  and a copy into a **second pool** (`vol-create-from` out of `images` into a
  `dir` pool of the run's own): the copy's disk is a qcow2 in the target
  pool, the source's volumes are untouched, and deleting the copy deletes
  only its own. `unit='bytes'` with a literal `$cap` inside the single-quoted
  XML was refused by libvirt itself (`XML error: malformed capacity
  element`), which is what the quoting in `clone_volumes_script` is for.
- **PVE 9.2.2** through the relay with a privilege-separated token (the
  documented set plus `VM.Allocate`, which `POST .../template` needs): a VM
  turned into a template while stopped (running refused by the app *and* by
  PVE), the template reading as one with no action offered, a linked clone
  and a full clone of it onto a named storage, both running while the
  template cannot, and the template deleted with its clones. A backup job
  made with `id`, schedule, storage, mode, compression, notes template,
  retention and notification: listed, its every field read back, edited
  (schedule and mode), run now (`vzdump` on the node, a real archive made
  and listed), and deleted with nothing left. `checkSchedule` answering
  PVE's own parse errors for `not a schedule`.
- **By hand on PVE 9.2.2** (fixtures): `POST .../template` on a VM whose disk
  is on `lvmthin` (the LV renamed to `base-910-disk-0`), `all`-style and
  named-guest jobs in `/etc/pve/jobs.cfg`, `--prune-backups` stored as an
  object of strings, `PUT .../content/{volid}` for notes and protection, a
  protected backup's own refusal, a restore onto a storage other than the
  archive's, and `no such cluster node` / `does not support vm images` for
  the two bad clone targets.
- **By hand on PVE 9.2.2, 2026-09-27** (`pvesh`, the parameters the app
  sends): a job switched from a guest list to a **pool**, to all guests with
  an exclusion, back to a list, and to a pool with a node — each `PUT` with
  `all=0` and `delete` naming the absent selection fields, each leaving only
  the one selection; a run now of the pool job (`vzdump --pool` on the node)
  backing up the pool's guest alone; that archive restored as a new VM onto
  `local-lvm`, the one storage with `images` content, which is what the
  restore's storage list offers.

Not verified on a real host: a clone to **another node** (the test host is a
single node, so only the app's own refusal and PVE's `no such cluster node`
were seen); a run now of a job with no node on a **cluster** (one request
per online node; the test host is a single node);
a template refused by PVE itself and a copy into a block pool were run
later ("Second pass", phase 10).

### Network editing, pending changes and the rest (phase 10)

An existing network is editable, a libvirt guest's pending changes can be
discarded, and four smaller items: Secure Boot in the create form, several
search domains and NICs in cloud-init, a password's expiry, and USB
passthrough by address.

#### Editing an existing network

The Network section's view edits the network in place, in the design's
configuration rows: libvirt's mode, IPv4 address with its prefix, DHCP range
and static hosts; PVE's bridge ports, address, VLAN awareness and autostart.
The rows are a draft until Save. What each backend does with it differs, and
the rows say which:

| | libvirt (`sbm_virt::libvirt::net`, one `virsh` round trip) | PVE (HTTP API) |
| --- | --- | --- |
| Which fields go where | mode, host bridge, address, prefix and DHCP range through `net-define`; the static hosts through `net-update add/delete ip-dhcp-host` | `PUT /nodes/{n}/network/{iface}` — ports, `cidr`, `gateway`, `bridge_vlan_aware`, `autostart`, and the interface's current `cidr`/`cidr6` sent back with every edit (below) |
| When it applies | `net-define` writes the definition; the **running** network keeps its address, its bridge and its dnsmasq until it is restarted. A restart is offered as a switch of its own beside Save, and the rows say what it does to the guests on it | Pending, like every other PVE network change: the node's `interfaces.new`, applied with the card above the list |
| The restart | In one round trip: the running network's own XML kept, the new definition written **while it still runs** (a definition the host refuses stops there, nothing stopped), then `net-destroy` and `net-start`. A start the host refuses puts the old definition back and starts the network again from the kept XML (`net-create`, which libvirt 11.3 takes for a persistent network that is down — verified: running exactly as before, still persistent). `VirtNetworkRestart` alone, when the definition already has the change, is the same without a definition written. **An active network is never left down** unless the way back is refused too, which the error then says | none: applying the configuration is the change |
| A refused edit | `VirtErrType.conflict` when the definition changed since it was read (the guard reads `net-dumpxml --inactive`, which is what the app was given) | `digest`-less `PUT`; a parameter PVE refuses comes back in its own words |
| Never touched | – | a physical interface, and **any interface carrying the node's management traffic or sitting under one** (below). `virtPveManagedIface` refuses the edit and the deletion, `_checkApply` an apply whose diff touches one, and the view offers neither and says why |

Decisions:

- **`net-define` for the address and `net-update` for the static hosts.**
  libvirt has no `net-update` command for the mode or the address at all,
  and its `ip-dhcp-range` is checked against the *running* network's
  subnet — which is the old one until the network is restarted, so an
  address change and its range cannot go through it. The static hosts are
  the opposite: `net-update add/delete ip-dhcp-host` applies live *and*
  writes the definition, and its check is against the definition, so it is
  what a host-only change uses (verified on libvirt 11.3).
- **The definition, not the running XML, is what the view shows and what an
  edit is made from.** A `net-define` goes into the definition at once
  while the running network keeps the old address; showing the running one
  beside the new definition reads as a change that never happened, and an
  edit made from it would write the old address back. `pendingRestart` is
  the difference between the two, compared over the fields an edit touches
  (libvirt writes runtime detail — a NAT `<port>` range, a `portid=` — into
  a running network's XML that is not a change anybody made).
- **`--live --config` on every `net-update`** (and `--config` alone on an
  inactive network, which refuses `--live`): without it libvirt applies the
  entry to neither, and the change is silently lost.
- **The edited definition is the one the host wrote.** Only what this app
  sets is replaced: `<forward>`, `<bridge>`, and in the first IPv4 `<ip>`
  its address and prefix, its first DHCP range and the static hosts. Its
  other attributes (`localPtr=`), a second range, a range's `<lease>`,
  `<tftp>`, `<bootp>`, a second subnet, an IPv6 address, a `<dns>`, a
  `<domain>` and a namespace declaration (`xmlns:dnsmasq` with its options)
  stay as they are; `connections=` goes (it counts live interfaces, and is
  not a definition). A move to `bridge` mode drops what libvirt refuses in
  that mode — every `<ip>`, `<dns>`, `<domain>` and `<mac>`
  (`virNetworkDefParseXML`).
- **A static host is checked before a host sees it**: on the network's own
  subnet, off its network, broadcast and gateway addresses, no MAC or
  address twice, and none on a network without an address or in `bridge`
  mode — where it would otherwise be dropped with nothing said.
- **PVE allows a bridge, and nothing carrying the node's management
  traffic.** Decided from what the node itself says, read over the same
  server connection (`virtPveLiveNetScript`, no root needed): the devices
  its default routes go through (IPv4 and IPv6), the ones carrying the local
  address of an established TCP connection — this app's among them,
  whatever it came through (SSH, the agent, a NAT or VPN in front of the
  node, which a match on the dialled address cannot see) — and every
  interface the listing gives a `gateway` or `gateway6`. Then down to what
  each sits on (`/sys/class/net/*/lower_*` and the listing's
  `bridge_ports`, `vlan-raw-device`): a VLAN interface carrying the address
  protects the bridge under it, where turning VLAN awareness off would cut
  it. A node that does not answer (another cluster node, a failed read) has
  every interface with an address protected. An **apply** is checked
  against the pending diff (`virtPveDiffIfaces`: the stanza each changed
  line is under — a `#` line too, which is how PVE writes an interface's
  `comments`; a hunk that starts inside a stanza is placed by its line
  number in the node's current `/etc/network/interfaces`, read with the
  probe), and refused when it touches one of them — made in the app or in
  PVE's own web UI — or when a hunk cannot be placed (another cluster node,
  whose file this connection does not reach). A bridge of the app's own
  (`sbxe2e*`) is what the tests edit.
- **Every PVE bridge edit sends the addresses back.** PVE's
  `update_network` sets `method`/`method6` and the address families from
  the request alone (`$param->{method} = $param->{address} ? 'static' :
  'manual'`, pve-manager 9.2.2, read on the host): an address not sent is
  dropped. The interface is read fresh first and its `cidr` (unless the
  edit changes it) and `cidr6` go with the edit.
- **`bridge_vlan_aware` off is a `delete`, not a `0`.** PVE keeps what is
  not sent, and its own editor clears the allowed-VLAN list with it
  (`bridge_vlan_aware,bridge_vids` in `delete`).

#### libvirt: discarding a pending change

`dumpxml` live → `define`, which is what a `virsh` user does to drop an edit
libvirt keeps no pending list to drop. `VirtHwRevertPending`, made by
`VirtBackend.revertPending` (PVE keeps dropping its list item by item), from
the Hardware read the view already has; `VirtCapabilities.hardwareRevertPending`.

- The definition is written from the **running** XML, with what that XML
  says of the running process replaced by the definition's: `<domain id>`
  (cut from the tag as written, namespace declarations kept), the
  `<resource>` cgroup, a disk's runtime `index` and `<backingStore/>` go;
  an `<alias>` libvirt made goes and a user's (`ua-…`) stays; the domain's
  own `<seclabel>`s are the definition's (a device's, like a disk's
  `relabel='no'`, stays); `<cpu>` is the definition's with the running
  `<topology>` — the running one is what libvirt expanded (`host-model`
  printed as `custom` with today's host model and features), which would
  pin the host CPU at the next start. The addresses libvirt wrote into the
  definition stay.
- **Only against the running process it was read from.** The script checks
  `virsh domid` still is the running XML's `id`: a guest stopped and
  started since runs its definition, and writing the old running XML back
  would reverse the change that is already applied. A reboot inside the
  guest keeps the process and its id.
- **The NVRAM file and the firmware are not touched.** A plain `define` of
  the live XML drops `<nvram>`, and libvirt then makes a *new* variables
  file of its own template at the next start — losing the guest's boot
  entries and its Secure Boot state with them. The definition's own
  `<nvram>` element is written back as it was, and the file itself is never
  read or written. Verified on libvirt 11.3: a pending memory change
  discarded with the guest running, the NVRAM file's sha256 unchanged, the
  guest still running.
- Refused where the guest is not running: there is no running definition to
  write back, and "revert to nothing" would be a second way to delete it.
  The banner's revert-all is offered only from a read the Hardware view has
  (`hardwareRevertPending`), and what is discarded is shown first: the same
  rows the view shows under each field.

#### Small items

| Item | libvirt | PVE |
| --- | --- | --- |
| Secure Boot in the create form | offered only where a firmware descriptor (`/usr/share/qemu/firmware/*.json`) carries **both** `secure-boot` and `enrolled-keys` — the feature needs a firmware with the vendor's keys, and libvirt refuses the definition otherwise (read in one `grep -q` per file, `virt::firmware_script`). Written as both firmware features `enabled='yes'` and `<smm state='on'/>`; refused before a host without UEFI or on a machine that is not q35 | always offered: every 4m EFI disk runs `OVMF_CODE_4M.secboot.fd`, and Secure Boot is the variables template with the keys enrolled — `efidisk0` with `pre-enrolled-keys=1` (`PVE::QemuServer::OVMF`, 9.2.2) |
| Several search domains | `network-config` v2 `nameservers.search` as a list; the settings field takes several, space-separated | `searchdomain`, space-separated (PVE's own form) |
| Several NICs | `network-config`'s `ethernets` — one entry per NIC, by MAC. The form edits the first and says how many there are; the rest are kept as they are through a save | `ipconfigN`, one per `netN`. PVE's own cloud-init writes them all |
| A password's expiry | a switch in the settings (the create form has none). cloud-init's `chpasswd: expire:` expires only the passwords `chpasswd` itself set (`cc_set_passwords`), not a `hashed_passwd`, so the account's hash is set there too: `chpasswd: {expire: true, users: [{name, password: <hash>, type: hash}]}` (cloud-init 22.3+; an older one ignores it and keeps the unexpired `hashed_passwd`). Read back from the seed, so a save keeps it | **not offered**: PVE writes `expire: False` for every VM (`PVE::QemuServer::Cloudinit`, PVE 9.2.2) and has no option for it |
| USB passthrough by address | `<hostdev><source><address bus='1' device='4'/></source>` — libvirt's `usbaddress` takes exactly a bus and a device number (`domaincommon.rng`, libvirt 11.3: there is no `port` attribute on a hostdev's source), and the add block offers the device by vendor/product or by that address. The bus and device number come from `nodedev-dumpxml`; the port chain (`4`, `1.2` behind a hub) is shown as the label | by vendor/product (`host=0bda:b023`) or by address, as picked: `host=1-1.2`, PVE's own form — the bus and the port chain, which is what its web UI writes and what a mapping stores. A device the host gave no port for has no address, and is refused so |

#### After review (2026-09-27)

A review of this phase found the network form unable to save on either
backend, a restart that left a network down on a refused definition or
start, a PVE management guard that never matched, edits that dropped a PVE
bridge's addresses, a discard that could undo an applied change, Secure
Boot and USB-by-address that did nothing, a password expiry cloud-init
ignored, and **two parses that were never awaited** — a refused network
change or discard reported as a success (`ffi.parseVirtNetChange` and
`parseVirtHardwareChangeJson` are `Future`s; the project does not enable
`unawaited_futures`). All are fixed as described above and pinned by unit,
widget and Rust tests (stub-`virsh` runs for every refusal path of a
restart). Then, over SSH (`test/e2e/virt_real_test.dart`), everything named
`sbxe2e*` and removed afterwards:

- **libvirt 11.3**: a network edited — a static host live, the first range
  moved with a restart while a hand-written second range survived; an
  address on the host's LAN refused **as a definition** while that range
  was outside it (nothing stopped), then refused **at start** and the
  network running again as before from its kept XML (`net-create`), the old
  definition back; a move to `bridge` mode dropping `<ip>` and `<mac>` and
  back; a restart of its own onto a definition that cannot start, undone
  the same way. Pending changes discarded on a running guest, and refused
  (`conflict`) once the guest had been stopped and started. The phase-8
  group in `/var/lib/libvirt/images`, the revert included.
- **PVE 9.2.2** (privilege-separated token): a dual-stack bridge edited
  (VLAN awareness only) and applied with both addresses kept; the node's
  own bridge (`vmbr0`: default route and this SSH session) not editable and
  an edit refused before anything was written; a pending change to it made
  with `pvesh` refused at apply. The first run of that last check applied
  a `comments` line to `vmbr0` — the diff reader skipped `#` lines — which
  was harmless by design (the same addresses, a comment) and removed from
  the file by hand; the reader counts them now and the re-run refused it.

#### Verified against the real hosts (2026-09-27)

Everything named `sbxe2e*` and removed afterwards; the temporary PVE API
token, its ACLs and its role deleted.

| What | libvirt 11.3 (agent + sudo) | PVE 9.2.2 (SSH, the host's own agent) |
| --- | --- | --- |
| A network edited | a NAT network made, its mode, address, range and a static host edited; the static host applied live (`net-update`, no restart, the definition and dnsmasq both carrying it); the address and range written to the definition, `pendingRestart` true, the running network still on the old address; `VirtNetworkRestart` applied it and `pendingRestart` went false; the definition reworked to `route` and restarted; a stale edit refused as `conflict` | a bridge made pending, its address and VLAN flag edited through the pending model, its diff read, reverted (nothing applied, the interface gone from the listing), made again, edited, applied (`ssh pve` and `vmbr0` checked after every apply), deleted and applied |
| A refused restart | an address on the host's own LAN refused at `net-start` (`Network is already in use by interface eth0`): the old definition put back and started, the network still active and its address unchanged | – |
| The management interface | – | `vmbr0` (the default route, and the address the app is connected to) and every physical interface refused for edit and delete, nothing written |
| A pending change discarded | a memory change with the guest running, seen in the inactive XML, reverted: the inactive XML matched the live one again, the guest still running, the NVRAM file's sha256 unchanged | – |

Scripts and parsers run under real `sh` with hostile values in
`sbm_virt::libvirt::net`'s tests; fixtures captured from the libvirt host
(`script_hardware.txt`, and `dumpxml_revert_live.xml` /
`dumpxml_revert_definition.xml` for the revert transform, the latter defined
on that host and accepted).

The two libvirt failures the first e2e run found — the listing reporting the
*running* network's address instead of the saved definition's, and
`VirtNetworkRestart` re-sending the same edit instead of restarting — are
fixed and pinned by Rust and widget tests
(`a_saved_definition_is_what_the_listing_reports`,
`a_restart_writes_no_definition`, and the manage test's restart op); they
were not re-run on the libvirt host, which its own PVE node's reboot took
down mid-session (guest 100, which this work is not allowed to start). The
PVE group was re-run and passes.

Not verified on a real host: a PVE bridge with **ports** through the app
(the test node has no spare interface), and a USB device passed to a
*running* guest by address (the libvirt host has no USB device; on PVE the
only one is the node's own Bluetooth adapter, written to a stopped VM's
configuration and never started with). The routed-network restart ran in
the monitor group (`virt_monitor_test.dart`, a `route` mode change and
restart).

#### Second pass (2026-09-28)

Everything the sections above listed as not verified that the two test
hosts can do, as e2e tests of its own (`virt_real_test.dart` for libvirt
over SSH, the `_pveUnverified` group of `virt_monitor_test.dart` for PVE
through the agent's relay). The libvirt host got LVM (a loop-backed VG,
`SBM_E2E_LIBVIRT_VG`), an NFS export (`SBM_E2E_LIBVIRT_NFS`) and
`libvirt-daemon-driver-storage-logical` for the run, all removed afterwards;
both hosts ended as they began.

| What | Result |
| --- | --- |
| libvirt: two writable disks | one external snapshot overlays both, a revert puts both on new overlays |
| libvirt: internal after external | an internal snapshot (with memory) on the overlays, an external one over it, a revert to the internal one: both disks back on its files |
| libvirt: a pool outside the AppArmor helper's directories | the revert refused before anything was sent, the guest still running on the same overlay |
| libvirt: Secure Boot at create | both firmware features and `<smm state='on'/>` in the definition; the guest's `SecureBoot` efivar is 1 |
| libvirt: a second NIC | a seed with two NICs (the app's script, one extra network) read as two, kept through a save from the form; after a reboot the second NIC has its static address |
| libvirt: a password that expires | saved, read back, and at the next boot sshd asks for a new one ("You are required to change your password immediately") |
| libvirt: dies and clusters | 1×2×2×1×1 read as 1 socket, 1 core, 4 threads; a memory change keeps the topology, a CPU change keeps dies and clusters and the host takes the vCPU count |
| libvirt: a CD-ROM on SCSI, USB by address | moved to SCSI (a `virtio-scsi` controller added) and back; `<address bus='1' device='7'/>` taken by the definition and removed |
| libvirt: `logical` pool | made from a VG; a raw volume; a VM from a cloud image with its disk and seed on LVs booted, its seed edited and taken at a reboot (two search domains in `resolv.conf`); external snapshots refused there; a copy of a VM into it |
| libvirt: `netfs` pool | mounted, a qcow2 volume in the export, unmounted when stopped, deleted |
| libvirt: a volume removed behind libvirt's back | the pool refreshed, its count and its volumes agree |
| PVE: Secure Boot on SATA with cloud-init | `efidisk0` with `pre-enrolled-keys=1`, the efivar 1 in the guest; the cloud-init edit taken at a reboot |
| PVE: the guest agent's shutdown | `agent: 1`, the app's shutdown stopped it, the guest's journal has `guest-shutdown called` |
| PVE: IDE, `vmdk` | the disk and the cloud-init drive on IDE with the edit (not booted: Debian's cloud kernel has no IDE driver); a `vmdk` offered, imported and booted |
| PVE: USB by vendor/product and by address | `host=0bda:b023` and `host=1-13` (matching sysfs) on a stopped VM, as `root@pam`; removed, never started |
| PVE: a template refused by PVE | a backend that never read the snapshots gets `unable to create template, because VM contains snapshots` |
| PVE: a real backup job's lock | run now: `backup` lock, no action offered, start refused; unlocked after; the job's own `bwlimit` applied |

What the pass found, fixed and pinned by Rust and Dart tests:

- **Overlays left behind.** A snapshot on a branch the guest left (a revert
  to an internal snapshot taken before it) is deleted by libvirt 11.3
  without its overlay — and deleting the *leaf* of such a branch removed the
  file below it instead (`snap_delete_leftovers`, captured in
  `script_snap_delete_off_chain.txt`). A delete now removes the overlays off
  the chain after libvirt, and deleting the guest takes every snapshot's
  layer on its disks, off the chain too.
- **`logical` offered where the daemon has no backend.** Debian ships it as
  `libvirt-daemon-driver-storage-logical`; without it a define fails with
  "missing backend for pool type". The pool types come from
  `pool-capabilities` now, read once per backend.
- **A disk on LVM was a `file` disk**, which QEMU refuses; a volume under
  `/dev` is a `block` disk (`dev=`) in a new definition, a seed and a
  CD-ROM included.
- **A copy into a block pool kept `qcow2`** on data libvirt had converted to
  raw; it is raw, named `.img`, with a raw driver now
  (`VirtCloneSpec::target_block`).
- **No resize on LVM**: libvirt's `logical` backend has none. Not offered
  for a volume there, nor growing a disk on a `/dev` path.
- **A seed on an LV read as "too large"**: the whole 4 MiB device was read;
  only the ISO's own size is now.
- **A stale pool**: a volume whose file was removed outside libvirt was
  dropped from the list while the count kept it; the pool is refreshed and
  read again.
- **PVE Run now dropped a job's options** (`bwlimit`, `ionice`,
  `performance`, `fleecing`, …): the job is read and sent whole, as PVE's
  web UI does.
- **PVE refusals before a task** came back as `invalidResponse`; they are
  `actionFailed` with PVE's words.
- **The agent's relay dropped a connection sending more than 64 KiB at
  once** (ntex's default frame limit, which `ws::start` gives no way to
  raise; the terminal endpoint too, on a large paste). The agent upgrades
  through a copy of ntex's `start` with a 4 MiB limit now
  (`monitor/src/api/ws/upgrade.rs`), and the app splits what it sends to
  either endpoint into 64 KiB frames for agents before that
  (`monitorWsAddBinary`).

## Later phases

- Storage and networks: PVE SDN (zones, VNets); a volume's contents copied
  on PVE; uploads over a monitor agent (needs a byte-stream endpoint on the
  agent); PVE storage types beyond dir/LVM-thin/NFS/ZFS, content kinds
  chosen in the form. (Editing an existing network's configuration is phase
  10.)
- Snapshots: a chain's merge/commit from the app (libvirt `blockcommit`, so
  an old layer can be dropped without reverting); an external snapshot of a
  guest whose disks are on more than one pool (the form picks one pool for
  all of them); deleting an external snapshot on an AppArmor host, which
  libvirt refuses (`deny … w` on the backing file, Debian #932456; the app
  refuses it first, see phase 8) — an offline `qemu-img commit` with the
  snapshot's metadata dropped would be the way, and clearing the
  `<snapshotDeleteInProgress/>` a refused delete left (`snapshot-create
  --redefine` without it, not verified).
- Hardware: USB passthrough by *port* rather than by the bus and device
  number libvirt's `usbaddress` takes (a host whose device number differs
  from its port). (The libvirt revert and USB by address are phase 10.)
- cloud-init: PVE's `cicustom` snippets and `ciupgrade` in the form. (More
  than one search domain and NIC, and libvirt's password expiry, are phase
  10.)
- Migrate (PVE cluster; the design's Migrate group in Settings) — which is
  also what a clone to another node needs a cluster for. (Secure Boot in the
  create form is phase 10.)
- Clone: a **linked** clone from the app's own form choice on libvirt (an
  overlay on the source's disks: the design's switch, refused here because
  it pins the source image — see phase 7's "a copy, not a qcow2 overlay").
  Backups: a job's `fleecing`, `bwlimit`, `ionice`, PBS storages and
  `notification-mode`; a backup's verification run; `prune-backups` as its
  own steppers rather than one property string.
- Monitor agent: native virt endpoints and web panel parity, reusing
  `sbm_virt::libvirt`.
