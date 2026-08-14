# File plan: SFTP becomes one backend of three

Files are browsed and moved the same way wherever they live. Today "files"
means two unrelated pages — `dart:io` for this device, `SftpClient` for a
server — and one transfer engine that only knows how to move something between
exactly those two. The goal is one browser over a `FileBackend`, with local,
SFTP and monitor behind it, and a transfer that names a source and a
destination without caring which kind either is.

```
        local ─────┐                 ┌───── local
                   │   FileBackend   │
        sftp ──────┼─────────────────┼───── sftp
                   │   FileTransfer  │
     monitor ──────┘                 └───── monitor
```

## What exists today

| | Local | SFTP | Monitor |
| - | ----- | ---- | ------- |
| Browse | `storage/local.dart` (510 lines, `dart:io`) | `storage/sftp.dart` (1277 lines, `SftpClient`) | **nothing** |
| Rename / delete / mkdir | yes | yes, with a sudo fallback (`core/utils/sftp_sudo.dart`) | — |
| Transfer | copy in from the system picker | `SftpWorker`, one isolate per job | — |
| Capability flag | — | — | `ServerCapabilities` has no `files` |

The file tab already tells the two apart. `storage/tab.dart:38` has a sealed
`_FileSession` with `_LocalSession` and `_RemoteSession`, but it is private and
does one thing: pick which of the two pages to build (`:224`). Everything below
that line is duplicated between them.

Transfers are `SftpReq` (`data/model/sftp/req.dart:9`): a whole `Spi`, a
`remotePath`, a `localPath`, and `SftpReqType { download, upload }`. The
directions are named after the two ends because there are only ever those two.

## The one thing that decides this plan: monitor has no file API

`monitor/src/api/server.rs` serves `login`, `status`, `metrics`,
`capabilities`, `ws-ticket`, `tunnel/ws`, `terminal/ws`, `exec`,
`remote-access`, `settings`, `card-order`, `metrics/history`, `health`,
`velocity`. There is no `fs`, no `download`, no `upload`.

So "monitor as a file backend" is not an adapter over something that exists. It
is a decision between three different things:

### A. New file endpoints in monitor

`GET /fs/list`, `GET /fs/read`, `PUT /fs/write`, `POST /fs/mkdir`,
`DELETE /fs/remove`, `POST /fs/rename`, with streaming bodies for read and
write.

The honest answer for a host with no sshd, and the only one that can move a
large file without holding it in memory. It is also the largest new security
surface this app has ever asked monitor for: arbitrary filesystem access over
HTTP, as whoever the agent runs as. It has to sit behind the same gate as the
terminal and tunnel — `config.toml` only, off by default, never switchable from
`PUT /settings` — and it should almost certainly carry its own root restriction
rather than inheriting "wherever the agent can reach".

### B. Ride `POST /exec`

`ls -la` and parse it; `base64` a file's contents in and out.

Listing this way is tolerable. Reading is not: `exec` caps output at 1 MiB per
stream and kills the command after 60 s, both by design. A 5 MiB file is not
transferable, a binary is a base64 round trip through a shell, and there is no
progress, no resume, and no way to tell a truncated file from a complete one.
This is a fallback that would be wrong more often than it was right.

### C. Do not build one

A server reached over its monitor agent can already browse files **if it has
sshd**: `SshCredential.viaMonitor` relays the byte stream, and SFTP rides that
like everything else above `SSHSocket`. The gap is exactly the set of hosts
with a monitor agent and no reachable sshd at all.

### One category in the UI, whatever the transport

SFTP and monitor are both **a server**. Which of them is carrying the bytes is
not a distinction anybody browsing files should be shown, any more than the
terminal shows whether it reached sshd directly or through the tunnel — the app
already decides this by asking `ServerCapabilities` rather than by testing what
kind of credential a server has.

So the session model is two cases, not three:

```dart
sealed class FileSession {
  LocalFileSession()          // this device
  ServerFileSession(Spi spi)  // a server, however its files are reached
}
```

and resolving a server's backend is a separate question, answered by
capability: SFTP while there is a byte stream to run it over, a monitor file
API if one is ever built and the server has no sshd. A server that gains sshd
later changes backend and not category, and nothing in the tab strip moves.

### Recommendation

**C now, A as its own piece of work.** Ship the abstraction with local and SFTP
behind it, and let a monitor-backed server keep using SFTP over the tunnel —
which is what it already does. Add `MonitorFileBackend` when monitor has an API
worth adapting, and design that API in `monitor/`, not here.

What this plan owes A is the seam: nothing in the browser, the transfer engine
or the session model may assume its backend speaks SFTP. That is most of the
work, and it is worth doing on its own.

## `FileBackend`

The same shape as `ShellBackend` and `ServerExec`, which already answer "where
do these bytes come from" for terminals and commands:

```dart
// lib/data/model/file/file_backend.dart
abstract interface class FileBackend {
  Future<List<FileEntry>> list(String path);
  Future<FileEntry?> stat(String path);
  Future<void> mkdir(String path);
  Future<void> remove(String path, {bool recursive = false});
  Future<void> rename(String from, String to);

  /// Bytes out, bytes in. A transfer is these two and nothing else, which is
  /// what makes any pair of backends a pair.
  Stream<List<int>> read(String path, {int offset = 0});
  Future<void> write(String path, Stream<List<int>> data, {int? size});

  /// What this backend cannot do, so the UI can leave it out rather than
  /// offering it and failing: symlinks, permissions, sudo, resume.
  FileBackendTraits get traits;
}
```

`FileEntry` is name, size, modified, kind (file/dir/link), and an optional
`mode` — the union of what `FileSystemEntity` and `SftpName` can say, with the
parts only one of them knows behind `traits`.

Three implementations:

| | Reads | Writes | Notes |
| - | ----- | ------ | ----- |
| `LocalFileBackend` | `File.openRead` | `File.openWrite` | `dart:io`, no auth, no failure modes worth retrying |
| `SftpFileBackend` | `SftpFile.read` | `SftpFile.write` | wraps the existing client; keeps the sudo fallback |
| `MonitorFileBackend` | — | — | not in this plan; see above |

The sudo fallback (`core/utils/sftp_sudo.dart`) stays SFTP's own. It is not a
general idea: it works by running a shell command when an SFTP operation is
refused, and a backend without a shell has nothing to fall back to. It belongs
behind `traits.sudoFallback`.

It also belongs **inside** the backend rather than in the page. The SFTP page
wrapped each mutating action in a retry by hand, which is why only the actions
somebody remembered to wrap had one. `SftpEscalation` is the seam: the backend
says "run this command as root", and obtaining, caching and forgetting the
password stays where there is a screen to ask on. The backend never holds one,
which is also what lets a transfer isolate use the same class with no
escalation at all — nobody there to ask.

## Transfers between any two

A transfer names two ends, and neither is privileged:

```dart
class FileTransfer {
  final FileRef from;   // (backend descriptor, path)
  final FileRef to;
  // download/upload disappear: they were the names of the only two directions
  // that existed.
}
```

`FileRef`'s backend half must be **serializable**, because of the isolate.

### The isolate stays

`SftpWorker` (`data/model/sftp/worker.dart:163`) runs each job in its own
isolate. It cannot be handed a live `SSHClient` — those do not cross isolates —
so it is handed an `SftpReq` carrying a whole `Spi` and reconnects inside
(`_connectSftpSsh`, `:90`), which is also why host-key and
keyboard-interactive prompts have to be marshalled back over ports
(`SftpHostKeyPrompt`, `SftpKeyboardInteractivePrompt`).

Running transfers on the main isolate instead would be far less code and no
serialization at all. `benchmark/README.md` rules it out. Symmetric crypto is
pure Dart and costs, at 32 KiB packets:

| | MiB/s |
| - | ----- |
| `aes256-ctr` + `hmac-sha2-256` | 57.8 |
| `chacha20-poly1305` primitives | 84.5 |
| SFTP get over chacha, end to end | 67.4 |

A LAN-speed transfer is therefore crypto-bound at roughly one core. On the main
isolate that is the UI thread pegged for the length of the transfer. Over a
slow link it would not matter; the app must not jank on the fast one.

So `FileRef`'s backend half is **serializable**, and the isolate builds both
ends itself.

Not every pair needs one, and the engine should say so rather than starting an
isolate out of symmetry:

| Pair | Where it runs |
| ---- | ------------- |
| local → local | main isolate; it is a file copy with no crypto |
| local ↔ sftp | one isolate, one connection — what happens today |
| sftp → sftp | one isolate, two connections and two prompt channels |

## What the pages become

One `FileBrowserPage` over a `FileBackend`, replacing both. The behaviour that
differs today is mostly the behaviour that should not:

- **Local has no transfer UI.** It copies in from the system picker
  (`local.dart:89`) and cannot send anywhere. With `FileTransfer` it gets the
  same "send to…" the remote page has.
- **SFTP has the mission list** (`storage/sftp_mission.dart`). It becomes the
  transfer list for every backend.
- **Both have their own rename/delete/mkdir dialogs**, differing only in which
  client they call. One implementation over `FileBackend`.
- **Sort, search, hidden files, the toolbar handover to the tab strip**: all in
  the shared page, so the local browser stops being the one that lacks them.

`storage/tab.dart` keeps its `SessionTabsController` and its restoration; a
session's serialized form becomes the `FileRef` descriptor rather than
`{serverId, path}` with local implied by its absence (`:71`).

## Capabilities

`ServerCapabilities` (`data/model/server/capabilities.dart:18`) gains `files`,
beside `shell`, `terminal` and `byteStream`. SSH answers true; a monitor-backed
server answers whether it can reach sshd through the tunnel — which is the same
question `byteStream` already asks, so `files => byteStream` until there is a
monitor file API to make it its own answer.

The point of the flag is the server list and the function buttons
(`view/widget/server_func_btns.dart`): a server that cannot browse files should
not offer the button.

## Delivery stages

| Stage | Content | Verifiable on its own |
| ----- | ------- | --------------------- |
| 1 | `FileBackend`, `FileEntry`, `FileRef`, traits; `LocalFileBackend` and `SftpFileBackend` | unit tests against a temp dir and a real server; nothing in the UI moves |
| 2 | `FileBrowserPage` over the interface; the local page migrates to it | this device's files behave as before |
| 3a | `SftpEscalation`: the sudo retry moves into the backend | every operation gets it, not the wrapped ones |
| 3b | The SFTP page migrates onto the browser | both tabs are one page |
| 4 | `FileTransfer` replaces `SftpReq`; missions list generalised | local→server and server→local as today |
| 5 | Server→server, local→local | the pair that never existed |
| 6 | `ServerCapabilities.files`; buttons hidden where there is nothing to browse | a monitor-only server without sshd stops offering files |

All six are in. What follows is what each one settled that the plan above did
not decide in advance.

Stage 1 changes no behaviour. Stages 2 and 3 are the risky ones: they replace
1787 lines of working page code, and the SFTP page carries a lot of hard-won
handling — sudo, timeouts (`core/utils/sftp_timeout.dart`), host-key prompts.

### What stage 3b settled along the way

- **Reading escalates too.** `SftpEscalation.run` answers with the command's
  output, so `list` can fall back to a `find` under sudo — a directory this
  user may not list is the case sudo exists for. `escalate<T>` is the general
  form; `runWithEscalation` is it for operations with nothing to report.
- **`chmod` joined the interface** rather than staying an SFTP-only menu entry,
  because `traits.permissions` already claimed it and a monitor file API would
  have it too. SFTP does it with `SSH_FXP_SETSTAT` — a server that serves files
  need not give out shells — and falls back to `chmod` under sudo.
- **`FileEntry.mode` is permission bits only.** SFTP packs the type into the
  same number; `kind` already answers that, and a caller handing the value to
  `chmod` should not have to know which bits to mask.
- **Back and up are different.** `BrowsePath` grew a bounded history, because
  the SFTP page's back button retraced browsing while the `..` row walked the
  tree, and the browser needs both.
- **No modal over a mutating operation.** The SFTP page wrapped each one in a
  loading dialog. An operation may now stop halfway to ask for a sudo password,
  and a barrier of its own would sit over that question — so the browser shows
  a progress line and reports failures in a snackbar.
- **One gap, marked with a TODO.** "New file" no longer offers sudo: escalating
  a write means getting bytes to the far side first, which is the dance an
  upload does at page level. Creating an *empty* file could escalate, through a
  method of its own that does not exist yet.

### What stages 4 to 6 settled

- **The engine still specialises; the API does not.** `FileTransfer` names two
  ends and neither is privileged, but the worker keeps the two hand-written
  SFTP paths for the pairs that already existed. Segmented reads, an idle timer
  and a bounded write window are what make a large file over a slow link
  finish, and none of it is expressible as `read` piped into `write`. The
  general path serves the pairs that could not be expressed at all before.
- **local → local runs on the main isolate**, as the table above says it
  should, and `FileTransferStatus` emits the same events either way — so
  nothing downstream can tell which it got.
- **"Send to…" is one flow, in the browser.** It replaced two half-flows that
  between them could only name a server and this device: the local page's
  "upload" picked a server, and the SFTP page's "download" picked nothing
  because there was only one place a download could land.
- **The browser cannot name its own end.** It holds a `FileBackend` — a
  connection somebody already has — and a transfer needs a description of how
  to *get* one. `FileBrowserArgs.refOf` is that description, written by the
  page that built the backend rather than guessed from a runtime type.
- **Host-key questions queue.** One at a time across every worker, because a
  server-to-server transfer connects to two machines from one isolate and the
  dialogs would otherwise stack — with the user answering the top one about the
  other host's fingerprint.
- **`files` is its own capability**, not `byteStream` read twice. They come
  apart the moment a monitor agent grows a file API, and `_canBrowse` and
  "where can I send this" are now literally the same call, so the two lists
  cannot drift.
- **Upload progress reports bytes**, not just a percentage. It used to send a
  bare `double`, so the speed column was blank for every upload.
- **Directories transfer**, through the general path whatever their two ends
  are: `planCopy` walks the tree first so progress has a denominator from the
  first byte, then `runCopy` creates the directories and moves the files.
- **`randomAccessReads` is gone.** Declared, answered `true` by both
  implementations, and read by nothing — a promise with no way to tell whether
  it was kept. Honouring `read`'s offset is now part of the interface.
- **Hidden files are a setting**, applied while sorting rather than while
  listing, so turning it on costs no round trip. In the same menu as the sort
  order, because both are decisions about how the list is shown.
- **Cancel means stop.** An isolate is stopped by killing it; the inline copy
  had to be asked, and until it was, cancelling removed the row and left the
  copy running. A cancelled transfer also loses the cleanup its own `finally`
  would have done, so the staging path is reported to this side and deleted
  here — for a local destination. A cancelled upload leaves one on the server,
  visible in the browser beside the file it was going to become.
- **A session says what kind it is.** `{'kind': 'local'|'server', ...}` rather
  than "local is the one with no `serverId`" — a rule the reader had to know
  and the writer never stated. The old shape still reads, behind a TODO.

## Open risks

- **Deleting a working 1277-line page.** The SFTP page's edge cases are not in
  its structure, they are in its details. Anything not carried over is a
  regression nobody will notice until they hit it. Stage 3 should port
  behaviour, not rewrite it.
- **A second connection per two-remote job.** Keeping the isolate is settled,
  but `sftp → sftp` pays two connections and two prompt channels for one
  transfer, and a host that prompts for its key does so from inside an isolate
  that is already juggling another.
- **Two prompts at once.** A server→server transfer can raise two host-key
  dialogs. They must queue, not stack.
- **Partial writes.** Settled everywhere: `write` stages beside the destination
  and renames, and the two specialised paths now do the same — a download
  writes to `.sb-part-N` and renames, an upload opens a staged remote path and
  renames over the destination. Overwriting takes a delete-then-rename on
  servers without `posix-rename@openssh.com`, since `SSH_FXP_RENAME` is
  specified to fail when the destination exists.
- **Monitor's file API, if it is ever built,** is arbitrary filesystem access
  over HTTP. It belongs behind `remote_access`, off by default, with its own
  root, and it should be designed in `monitor/` with the same care the terminal
  endpoint got.

## Manual verification

Carried over from the pane work, whose file-tab checks were never run — they
are the same surface this plan replaces, so they are the regression baseline.

### 1. The file tab as it stands today (baseline, before any of this)

- [ ] The SFTP button switches to the File tab and adds a session beside this
      device's files.
- [ ] Two servers stay open at once; switching between them does not reconnect.
- [ ] One bar, not two. Download / sort / search / refresh sit in the tab strip
      and follow the session you switch to; sudo appears only where sudo is
      configured.
- [ ] Opening SFTP as a file picker from elsewhere still draws its own bar with
      the server name.
- [ ] The file tab reopens the same servers, each in the directory it was left
      in.

### 2. After the browser is one page

- [ ] Rename, delete and mkdir behave the same on both backends.
- [ ] Sudo still rescues a refused operation on a server, and is absent on this
      device.
- [ ] Sort, search and hidden-file toggles work on this device's files, which
      they did not before.

### 3. Transfers

- [ ] local → server and server → local, as before, with progress and cancel.
- [ ] server → server between two different hosts.
- [ ] A transfer interrupted halfway leaves no partial file under its final
      name.
- [ ] Two host-key prompts raised by one transfer queue rather than stack.

### 4. Capabilities

- [ ] A monitor-only server with no reachable sshd does not offer a file
      button, and its saved file tab does not reopen into an error.
