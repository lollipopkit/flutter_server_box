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
| libvirt snapshots | Internal (`snapshot-create-as` without `--disk-only`): every writable disk must be qcow2, and an active domain's snapshot always holds its memory — QEMU refuses an internal one without it, so the form shows the memory switch on and fixed. External snapshots are left out: reverting them needs libvirt ≥ 9.9 and they add overlay files to every disk. |
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
- Command strings and output parsers live in `crates/sbm_parser` (new module
  `virt`), per the repo's "test as spec" rule, so the monitor web panel can
  reuse them later. Fixtures are captured `virsh` output.

### Host detection

A server is a virtualization host when:

- **PVE**: it has a `server_pve` row. Explicit, as today.
- **libvirt**: `command -v virsh` succeeds through `ensureExec()`. Probed
  without being asked (the tab's first listing, pull-to-refresh) only where
  the server list is connected or connecting anyway (`VirtHosts.autoProbeable`);
  every other server only through "Check this server" / "Check all". Cached
  per server for the session. A server that has both is shown as PVE.

The probe (`sbm_parser::virt::probe_script`, one round trip) asks, in order:

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
- Scripts, parsers and fixtures: `sbm_parser::virt` (`snapshots_script`,
  `storage_script`, `volumes_script`, `networks_script`, the three snapshot
  actions), `tests/fixtures/virt/script_*.txt` captured from the libvirt host.
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
| Delete | `undefine --managed-save --snapshots-metadata`, with `--nvram --storage <targets>` of the writable disks (never a CD-ROM or a read-only disk), or `--keep-nvram` keeping them | `DELETE` with `purge=1&destroy-unreferenced-disks=1`, the task. Its own disks always go (`deleteKeepsDisks` false) |

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
| USB | `nodedev-list --cap usb_device` + `nodedev-dumpxml` each (root hubs left out); a `<hostdev>` by vendor/product, live as well while running | Resource mappings (`/cluster/mapping/usb`); the node's own devices only for root@pam with its password |
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

Not verified: libvirt topologies with dies/clusters (folded into threads,
kept as they are), a CD-ROM on SATA/SCSI, PVE clusters, and hardware over
SSH (the read-only groups in `virt_real_test.dart` need an SSH key the test
can open).

### Clone and backups (phase 5)

Following the design: **Clone** is a group of the Settings view (new name,
"Full clone" on PVE / "Copy disk contents" on libvirt, the Clone button; the
copy opens on its overview afterwards), and **Backup** is a guest view of its
own on PVE, between Snapshots and Settings (the Plan group — the scheduled
jobs that take the guest, read only, "Datacenter → Backup" — and the Backup
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

| | libvirt (`sbm_parser::virt_manage`, one `virsh` round trip each) | PVE (HTTP API) |
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
| Pending | none: libvirt applies each change | The listing's top-level `changes` (the diff of `interfaces.new`) per node, shown above the list and the network with "Show changes", Revert (`DELETE /nodes/{n}/network`) and Apply (`PUT /nodes/{n}/network`, `ifreload -a`, a task), each asked first |

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

Not verified on a real host: libvirt `netfs` and `logical` pools (no NFS
server, no LVM on the test host) and routed networks; PVE `nfs`, `lvmthin`
and `zfspool` storages, bridges with ports, clusters; uploads from this
device as a libvirt host (`ProcessExec`).

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

| | libvirt (`sbm_parser::virt`, `virt_cloud_init`) | PVE (HTTP API) |
| --- | --- | --- |
| Options | `create_host_script`: `domcapabilities` for the machine a new domain gets (its disk buses — q35 has no IDE —, OVMF, swtpm) and which ISO tool the host has (`genisoimage`, `xorriso`, `mkisofs`, `cloud-localds`, first found) | Fixed: SCSI/virtio/SATA/IDE, UEFI, TPM, cloud-init; cloud images from 8.2 (`import` content) |
| Cloud images offered | qcow2 or raw volumes of any active pool no guest uses (a disk in use would be copied mid-write), not an ISO | Volumes with `import` content in a format QEMU reads (qcow2, raw, vmdk; not an OVA) on the node |
| The disk | `create_volume_script`: `vol-create-from --vol <image path>` (a copy in the chosen pool, converted to its format: qcow2, raw on LVM) → `vol-resize` to the size asked for → `vol-path`; any later step failing deletes it | `<bus>0: <storage>:0,import-from=<volid>` (PVE requires size 0), then `PUT .../resize` to the size asked for, before the start. A failed growth leaves the VM created and not started (`startError`) |
| cloud-init | A NoCloud seed made on the host, a volume `<name>-cidata.iso` in the disk's pool, attached as a read-only CD-ROM (below) | PVE's own drive `<storage>:cloudinit`; `ciuser`, `cipassword` (PVE hashes it, SHA-256 crypt), `sshkeys` URL-encoded inside the form's own encoding (`encodeURIComponent`, as PVE's web UI), `ipconfig0` (`ip=dhcp` or `ip=<cidr>,gw=<gw>`), `nameserver`, `searchdomain`. The hostname is the VM's name |
| Bus, NIC model | `<target bus>` (`vda`/`sda`/`hda`), a `virtio-scsi` controller for SCSI; `<model type>` | `<bus>0` (I/O thread on SCSI and virtio only: PVE refuses it on SATA and IDE); `net0: <model>,bridge=` |
| UEFI | `<os firmware='efi'>` with `enrolled-keys` and `secure-boot` off, as phase 4 writes it: autoselected OVMF, a variables file of its own | `bios=ovmf`, `efidisk0: <storage>:1,efitype=4m,pre-enrolled-keys=0` |
| TPM | `<tpm model='tpm-crb'>` with the swtpm emulator, only where `domcapabilities` has it | `tpmstate0: <storage>:1,version=v2.0` |
| Delete | The domain's `<metadata>` names its seed; `undefine_script` deletes it with `vol-delete` once the domain is gone (a refused undefine keeps it; one already gone is fine), with the disks only ("delete its disks too") | The cloud-init volume is the VM's own: `purge` deletes it |
| Add a CD-ROM | `attach-device` of an empty (or ISO) `<disk device='cdrom'>` on SATA (q35) or IDE (`pc`), to the persistent definition only: neither takes a drive live, so a running guest gets it at its next start (pending) | The first free of `ide2`, `ide0`, `ide1`, `ide3`, `sata0-5`: `none,media=cdrom` or the ISO; PVE puts it in pending while the VM runs |
| Remove it | `VirtHwRemoveDisk` (phase 4); a CD-ROM's image is never deleted | The same; an ISO stays on its storage |

The seed:

- `user-data` makes one account of its own (not the image's default user,
  so the name asked for is the name on every distribution) with passwordless
  sudo, `hashed_passwd` (or `lock_passwd` without a password), the keys, and
  `ssh_pwauth` on when there is a password; the hostname with
  `manage_etc_hosts`. `meta-data`: a new `instance-id`
  (`iid-<name>-<random>`) and `local-hostname`. `network-config` (v2) finds
  the one NIC **by its MAC**, which the app therefore chooses
  (`52:54:00:…`) and writes on the interface too: DHCP, or the address with
  its prefix, a route `0.0.0.0/0` via the gateway (`to: default` needs a
  newer cloud-init), and nameservers/search. Every value goes in as a JSON
  string (JSON is YAML), so nothing typed becomes a key of its own; Rust
  checks each again (`VirtCloudInit::check`).
- **The password never leaves the app.** It is hashed in-process with
  SHA-512 crypt (`virt_cloud_init::sha512_crypt`, checked against the
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
  only (an `images` volume is some guest's disk). PVE's content listing
  gives an import volume's **file size**, not its virtual size, so the form
  cannot tell that a 3 GiB Debian image does not fit a 2 GiB disk; the growth
  then fails ("shrinking disks is not supported") and the VM is left created,
  not started, with that message. libvirt reports the virtual size, and the
  form refuses a disk smaller than the image.
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

Not verified on a real host: a TPM on libvirt (no swtpm there), a seed
through the monitor agent or sudo (the same script as every other), a cloud
image in another pool than the disk's, `xorriso`/`mkisofs`/`cloud-localds`
(stubbed in the Rust tests only), cloud images other than Debian 13, and
editing cloud-init after creation (not in the design).

## Verified against real hosts

`test/e2e/virt_real_test.dart` (opt-in; its header lists the variables) and
`crates/sbm_parser/tests/ssh_e2e.rs` (`ssh_e2e_virt`), run 2026-09-25 against
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

Not verified on a real host: a ticket that expired on the server's clock (the 2 h expiry and the
renewal were driven by the backend's injected clock against real tickets), a
real backup job (the lock was set by hand), the guest agent's shutdown,
clusters (storage and networks per node), PVE before 9.2, external libvirt
snapshots, libvirt pools other than `dir`, and PVE bonds, VLANs and OVS
(parsed from hand-written payloads only).

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
  asked in red with "start it afterwards".
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
  - a network's configuration is read-only once made (the design edits it in
    place): a change means restarting the network under its guests, or a
    pending PVE change — a later phase. The design's "configuration file"
    group is left out for the same reason;
  - the new libvirt network form has a routed mode and the DHCP range fields
    (the design has three modes and the range only in the detail); a netfs
    pool asks for its mount point (prefilled `/mnt/<name>`);
  - PVE's pending network changes are a card above the network list and the
    network (Show changes, Revert, Apply), where the design has one line of
    text;
  - PVE volume formats follow the storage (qcow2 on a directory), where the
    design offers raw only; upload is offered on every libvirt pool of files,
    not only one already holding ISOs.
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
   - `sbm_parser` virt fixtures for `virsh` output (`dart_compat`-style lock).

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

## Later phases

- Storage and networks: PVE SDN (zones, VNets); editing an existing
  network's configuration (libvirt `net-update`/redefine, PVE `PUT
  .../network/{iface}`); a volume's contents copied on PVE; uploads over a
  monitor agent (needs a byte-stream endpoint on the agent); PVE storage
  types beyond dir/LVM-thin/NFS/ZFS, content kinds chosen in the form.
- Snapshots: external libvirt snapshots (disk-only while running), a
  snapshot's configuration diff, PVE's per-storage snapshot support shown
  before trying.
- Hardware: libvirt revert (redefine from the running XML); USB passthrough
  by port rather than vendor/product; editing cloud-init after creation
  (PVE's `ci*` options, a new libvirt seed).
- Migrate (PVE cluster; the design's Migrate group in Settings). Create:
  Secure Boot in the form, a cloud image's virtual size on PVE.
- Clone: "convert to template" (PVE `POST .../template`), a target storage
  or node for a full clone. Backups: scheduled jobs edited from the app,
  per-run options (storage, mode, compression, notes, protection) in the
  view, notes and protection edited on a backup, a restore's target storage.
- Monitor agent: native virt endpoints and web panel parity, reusing
  `sbm_parser::virt`.
