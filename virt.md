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
| Phase 2 scope | Snapshots (list, create, revert, delete) for both backends; Storage and Network sections, read-only: pools/storages with their volumes, networks/interfaces with the guests on them. |
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
- A libvirt VNC display with a password is not supported: `dumpxml` without
  `--security-info` does not show it, and nothing asks for it.

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
| One action at a time | `VirtHostNotifier.power` refuses a second action on a guest with one in flight (`unsupported`); the guest reads as the action's transient state and offers nothing until the first returns. |
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
  grouped by state; sections VMs / Storage / Network, a section the host's
  capabilities lack drawn disabled with a tooltip) and the detail beside it:
  a guest (Overview, Console, Snapshots), a pool (capacity, what it is, its
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

- Storage and network management: create, start/stop, delete pools, volumes
  and networks; upload an ISO; attach a volume; PVE SDN.
- Snapshots: external libvirt snapshots (disk-only while running), a
  snapshot's configuration diff, PVE's per-storage snapshot support shown
  before trying.
- Hardware editing (pending-change model: libvirt `define` vs PVE `pending`).
- Create wizard (VM, and LXC on PVE), clone, migrate (PVE cluster).
- Backups (PVE `vzdump` / backup storage).
- Monitor agent: native virt endpoints and web panel parity, reusing
  `sbm_parser::virt`.
