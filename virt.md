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
  for phase 1 (`VM.Audit`, `VM.PowerMgmt`, `VM.Console`, `Sys.Audit` on the
  paths the user wants shown).

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
- `VirtCapabilities` per host — `lxc`, `pause`, `snapshots`, `backup`,
  `cluster`, `serialConsole`, `vncConsole`, `termConsole`. The UI shows or
  hides by capability, never by `kind`.

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
- Opening glue: `lib/view/page/virt/console_connect.dart`; view:
  `lib/view/page/virt/console.dart`.
- A libvirt VNC display with a password is not supported: `dumpxml` without
  `--security-info` does not show it, and nothing asks for it.

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
| libvirt `domstats` | A shut-off domain still reports the last run's `cpu.*`, `balloon.current/maximum`, `vcpu.*` and block sizes. `--vcpu` prints ~65 KVM counters per vCPU, now dropped on the host. |
| libvirt errors | `start` on a running domain says `Domain is already active` (now `invalid_state`). A domain name containing `"` cannot start on an AppArmor host (`virt-aa-helper: bad name`); libvirt's text is shown. A user outside the `libvirt` group gets the polkit refusal (`permission_denied`). |
| libvirt consoles | `virsh console --force` attaches in a PTY shell and Ctrl+] returns to it; `domdisplay` gives `vnc://127.0.0.1:0`, and the SSH loopback tunnel to 5900 carries the RFB greeting. |

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
| `full_access` off | libvirt: `/exec` answers 403 → `execNotGranted` (was `unreachable` with a DioException's text). PVE: the relay is `relayNotGranted` whether the grant was read (refused before dialling) or not (the agent refuses the stream ticket with 403; was `unreachable`). |
| Refused before dialling | The dialer failed its socket future before `HttpClient` listened to it, and so did `PveBackend`'s TLS future on top: the load failed correctly *and* the zone got an uncaught error. Both futures are now marked handled. |

Not verified on a real host: a ticket that expired on the server's clock (the 2 h expiry and the
renewal were driven by the backend's injected clock against real tickets), a
paused PVE QEMU guest, clusters, and PVE before 9.2.

## UI (phase 1)

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
  grouped by state; sections VMs / Storage / Network, with Storage and
  Network shown disabled in phase 1 and a tooltip saying they are not
  available yet) and the guest detail beside it (Overview, Console tabs).
- Narrow: the single column is the selected host's guest list; the host list
  is behind the switcher sheet; the guest detail is pushed.
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

- Snapshots (list / create / revert / delete).
- Storage pools and volumes, networks — read-only first, then management.
- Hardware editing (pending-change model: libvirt `define` vs PVE `pending`).
- Create wizard (VM, and LXC on PVE), clone, migrate (PVE cluster).
- Backups (PVE `vzdump` / backup storage).
- Monitor agent: native virt endpoints and web panel parity, reusing
  `sbm_parser::virt`.
