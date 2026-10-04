import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/virt/pve_resources.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_backup.dart';
import 'package:server_box/data/model/virt/virt_backup_schedule.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_manage.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/model/virt/virt_rust.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/virt/backend.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/src/rust/api/pve.dart';
import 'package:server_box/src/rust/api/resource.dart' as res;
import 'package:server_box/src/rust/api/virt.dart' show VirtActionKind;

/// Opens a TCP connection to `host:port` as seen from the PVE server — what
/// `ServerTcpDialer.startConnect` is.
typedef PveConnect = ConnectionTask<Socket> Function(String host, int port);

/// An authenticated loopback tunnel to `host:port` as seen from the PVE
/// server — what `ServerTcpDialer.loopback` is.
typedef PveTunnel = Future<SshLocalTunnel> Function(String host, int port);

/// Proxmox VE through its HTTP API.
///
/// **The session is `sbm_virt::pve`'s** ([PveSession], FFI), the one the
/// monitor agent keeps too: login (password + TOTP, or an API token), ticket
/// renewal, one new login for a refused ticket, the certificate decision, the
/// host's guests and their power. It reaches the API through an
/// authenticated loopback tunnel of the server's `ServerTcpDialer` ([tunnel]:
/// an SSH channel, the monitor agent's relay, or a direct socket for this
/// device), opened on first use and again once it has ended.
///
/// **The rest of the API calls are still made here** and read here: a Dio
/// whose adapter hands each request to [PveSession.raw], which answers the
/// status and body PVE sent. Each moves into `sbm_virt` with its part of
/// issue #1623 item 5. A console's websocket and an upload are connections
/// of their own ([connect], [_httpClient]), authenticated with the session's
/// headers.
// TODO(migration): move every remaining call onto a typed `sbm_virt` call
// (#1623 items 5.2–5.7), then drop the Dio, [connect] and the Dart TLS path.
class PveBackend implements VirtBackend {
  PveBackend({
    required this.serverId,
    required PveConfig config,
    required PveTunnel tunnel,
    required PveConnect connect,
    this.user,
    this.sshKeyId,
    this.sshPassword,
    this.securityContext,
    Future<ServerExec> Function()? exec,
    void Function(String fingerprint)? onCertConfirmed,
    void Function()? onClose,
    this.taskPoll = const Duration(seconds: 1),
    this.taskTimeout = const Duration(minutes: 10),
  }) : _config = config,
       _openTunnel = tunnel,
       _connect = connect,
       _onCertConfirmed = onCertConfirmed,
       _onClose = onClose,
       _exec = exec;

  /// The backend for [spi], connecting through its `ServerTcpDialer` and
  /// writing a confirmed certificate to `Stores.pve`.
  factory PveBackend.of(Ref ref, Spi spi, PveConfig config) {
    final dialer = ServerTcpDialer.of(ref, spi);
    return PveBackend(
      serverId: spi.id,
      config: config,
      tunnel: dialer.loopback,
      connect: dialer.startConnect,
      user: spi.ssh?.user,
      sshKeyId: spi.ssh?.keyId,
      sshPassword: spi.ssh?.pwd,
      exec: () => ref.read(serverProvider(spi.id).notifier).ensureExec(),
      onClose: dialer.close,
      onCertConfirmed: (fingerprint) {
        // Re-read rather than writing this backend's copy back: the editor
        // may have changed something else since it was made.
        final current = Stores.pve.fetch(spi.id);
        if (current == null) return;
        Stores.pve.put(spi.id, current.copyWith(certSha256: fingerprint));
      },
    );
  }

  static const connectTimeout = Duration(seconds: 15);
  static const requestTimeout = Duration(seconds: 30);

  @override
  final String serverId;

  @override
  VirtHostKind get kind => VirtHostKind.pve;

  /// The SSH user, who a password login is for.
  final String? user;

  /// The SSH login's stored key, if it uses one — which decides whether a
  /// password login sends [PveConfig.pwd] or [sshPassword]
  /// (`PveConfig.loginPassword`).
  final String? sshKeyId;

  /// Sent by a password login when the SSH login uses no key.
  final String? sshPassword;

  /// Trust roots for "validates against a CA" on a console's or an upload's
  /// own connection; null is the platform's.
  final SecurityContext? securityContext;

  /// How often a task is asked whether it has finished, and for how long.
  final Duration taskPoll;
  final Duration taskTimeout;

  PveConfig _config;
  final PveTunnel _openTunnel;
  final PveConnect _connect;
  final void Function(String fingerprint)? _onCertConfirmed;
  final void Function()? _onClose;

  PveConfig get config => _config;

  PveSession? _session;
  SshLocalTunnel? _tunnel;
  Future<PveSession>? _opening;
  Dio? _dio;
  bool _closed = false;

  /// The certificate a console's or an upload's own connection was last
  /// refused — what [confirmCert] may pin when the session did not see it.
  CertInfo? _presented;

  /// Replaces the configuration (the user edited it). An address change
  /// needs a tunnel to the new one; anything else is the session's to apply.
  void updateConfig(PveConfig config) {
    if (config == _config) return;
    final moved = config.addr.trim() != _config.addr.trim();
    _config = config;
    if (moved) {
      _dropTransport();
    } else {
      _session?.updateLogin(login: _login());
    }
  }

  Uri get _base {
    var addr = _config.addr.trim();
    while (addr.endsWith('/')) {
      addr = addr.substring(0, addr.length - 1);
    }
    return Uri.parse(addr);
  }

  /// [path] under the API root, resolved against the address by [_dio].
  String _url(String path) => '/api2/json$path';

  static String _seg(Object value) => Uri.encodeComponent('$value');

  // ---------------------------------------------------------------------------
  // VirtBackend
  // ---------------------------------------------------------------------------

  @override
  Future<VirtSnapshot> load() async {
    final json = await _rust((s) => s.load());
    final snap = VirtRust.snapshot(jsonDecode(json), serverId: serverId);
    _nodes = snap.host.nodes;
    return snap;
  }

  @override
  Future<void> power(VirtGuest guest, VirtPowerAction action) async {
    if (!guest.actions.contains(action)) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${action.name} is not offered for ${guest.name}',
      );
    }
    final kind = _kindOf(action);
    await _rust((s) => s.power(guest: _ref(guest), action: kind));
  }

  @override
  Future<VirtGuestDetail> detail(VirtGuest guest) async => VirtRust.detail(
    jsonDecode(await _rust((s) => s.detail(guest: _ref(guest)))),
  );

  @override
  Future<PveConsole> console(VirtGuest guest, VirtConsoleKind kind) async {
    final t = await _rust(
      (s) => s.console(
        guest: _ref(guest),
        kind: kind == VirtConsoleKind.vnc ? PveConsoleKind.vnc : PveConsoleKind.text,
      ),
    );
    final guestKind = t.lxc ? VirtGuestKind.lxc : VirtGuestKind.qemu;
    if (t.vnc) {
      return PveVncConsole(
        node: t.node,
        guestKind: guestKind,
        vmid: t.vmid,
        port: t.port,
        ticket: t.ticket,
        user: t.user,
        password: t.password ?? t.ticket,
      );
    }
    return PveTermConsole(
      node: t.node,
      guestKind: guestKind,
      vmid: t.vmid,
      port: t.port,
      ticket: t.ticket,
      user: t.user,
    );
  }

  /// A websocket to [console]'s `vncwebsocket`, over the same transport,
  /// certificate policy and login as the API calls.
  Future<WebSocket> openConsoleSocket(PveConsole console) async {
    final auth = await _authHeaders();
    final base = _base;
    final url = base
        .replace(scheme: base.isScheme('https') ? 'wss' : 'ws')
        .resolve(console.websocketPath);
    final headers = <String, Object>{
      for (final key in const ['Authorization', 'Cookie'])
        if (auth[key] case final String v) key: v,
    };
    final client = _httpClient(_config.certSha256);
    try {
      return await WebSocket.connect(
        url.toString(),
        // What PVE's own clients ask for: frames relayed byte for byte.
        protocols: const ['binary'],
        headers: headers,
        customClient: client,
      ).timeout(connectTimeout);
    } catch (e) {
      throw _toErr(e);
    } finally {
      // The upgraded socket is detached from the client; closing it only
      // stops it from pooling anything else.
      client.close();
    }
  }

  @override
  Future<List<VirtStats>> history(
    VirtGuest guest, {
    VirtHistoryWindow window = VirtHistoryWindow.hour,
  }) async => VirtRust.history(
    jsonDecode(
      await _rust(
        (s) => s.history(
          guest: _ref(guest),
          window: switch (window) {
            VirtHistoryWindow.hour => PveHistoryWindow.hour,
            VirtHistoryWindow.day => PveHistoryWindow.day,
            VirtHistoryWindow.week => PveHistoryWindow.week,
          },
        ),
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Snapshots
  // ---------------------------------------------------------------------------

  /// The nodes of the last [load]: which nodes to list backups for.
  List<VirtNode> _nodes = const [];

  @override
  Future<List<VirtGuestSnapshot>> snapshots(VirtGuest guest) async =>
      VirtRust.snapshots(jsonDecode(await _rust((s) => s.snapshots(guest: _ref(guest)))));

  /// PVE's own answer whether every disk of [guest] is on a storage that
  /// snapshots (`sbm_virt::pve::Client::snapshot_supported`); null where it
  /// cannot say.
  @override
  Future<bool?> snapshotSupported(VirtGuest guest) =>
      _rust((s) => s.snapshotSupported(guest: _ref(guest)));

  @override
  Future<String?> snapshotRefusal(VirtGuest guest) =>
      _rust((s) => s.snapshotRefusal(guest: _ref(guest)));

  @override
  Future<List<VirtSnapDiff>> snapshotDiff(VirtGuest guest, String name) async =>
      VirtRust.diff(
        jsonDecode(await _rust((s) => s.snapshotDiff(guest: _ref(guest), name: name))),
      );

  /// PVE has no external form: a snapshot is a volume-level one taken by the
  /// storage, and a running VM's memory is `vmstate`.
  @override
  Future<VirtSnapChain> snapshotChain(VirtGuest guest) async =>
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: 'PVE snapshots are per volume; there is no chain to show',
      );

  @override
  Future<void> createSnapshot(
    VirtGuest guest, {
    required String name,
    String? description,
    bool memory = false,
    VirtSnapshotForm form = VirtSnapshotForm.internal,
    String? overlayPool,
  }) => _rust(
    (s) => s.createSnapshot(
      guest: _ref(guest),
      name: name,
      description: description,
      memory: memory,
    ),
  );

  /// `rollback`, with the start after it waited for
  /// (`sbm_virt::pve::Client::revert_snapshot`).
  @override
  Future<void> revertSnapshot(
    VirtGuest guest,
    String name, {
    bool start = false,
  }) => _rust(
    (s) => s.revertSnapshot(guest: _ref(guest), name: name, start: start),
  );

  @override
  Future<void> deleteSnapshot(VirtGuest guest, String name) =>
      _rust((s) => s.deleteSnapshot(guest: _ref(guest), name: name));

  /// Runs [request], which answers a UPID, and waits for its task. PVE
  /// answers a snapshot request that is bound to fail (a name taken, one that
  /// is gone) with a task all the same, and the task's exit status says why.
  Future<void> _task(
    VirtGuest guest,
    Future<Response<dynamic>> Function(Dio dio) request,
  ) async {
    final upid = await _call(request, action: true);
    if (upid is String && upid.startsWith('UPID:')) {
      await _waitTask(guest.node!, upid);
    }
  }

  // ---------------------------------------------------------------------------
  // Creating and deleting
  // ---------------------------------------------------------------------------

  @override
  Future<int?> nextVmid() => _rust((s) => s.nextVmid());

  /// PVE's fixed set (`sbm_virt::pve::Client::create_options`): cloud images
  /// wait for a release with `import` content.
  @override
  Future<VirtCreateOptions> createOptions() async =>
      VirtRust.createOptions(jsonDecode(await _rust((s) async => s.createOptions())));

  /// `sbm_virt::pve::Client::create`: checked against what the host lists
  /// now, made, a cloud image's disk grown to the size asked for, then
  /// started as a request of its own.
  @override
  Future<VirtCreated> create(VirtCreateSpec spec) async => VirtRust.created(
    jsonDecode(await _rust((s) => s.create(specJson: jsonEncode(VirtRust.specJson(spec))))),
  );

  /// Purged, with the disks of its VMID no configuration names. PVE deletes
  /// a guest's own disks whatever is asked: [removeDisks] cannot keep them.
  @override
  Future<void> delete(VirtGuest guest, {bool removeDisks = true}) =>
      _rust((s) => s.delete(guest: _ref(guest)));

  /// A stopped guest that is not one already; a guest with snapshots PVE
  /// refuses in its own words.
  @override
  Future<void> makeTemplate(VirtGuest guest) =>
      _rust((s) => s.makeTemplate(guest: _ref(guest)));

  /// Full unless a template asks for a linked one; checked against the
  /// host's storages and nodes first (`sbm_virt::create::clone_issue`).
  @override
  Future<String> clone(VirtGuest guest, VirtCloneRequest request) => _rust(
    (s) => s.cloneGuest(
      guest: _ref(guest),
      requestJson: jsonEncode(VirtRust.cloneRequestJson(request)),
    ),
  );

  /// Every storage on the guest's node that holds backups, listed for the
  /// guest's VMID.
  @override
  Future<List<VirtBackup>> backups(VirtGuest guest) async {
    final node = guest.node!;
    final out = <VirtBackup>[];
    for (final storage in await backupStorages(guest)) {
      final data = await _call(
        (dio) => dio.get(
          _url('/nodes/${_seg(node)}/storage/${_seg(storage.name)}/content'),
          queryParameters: {'content': 'backup', 'vmid': guest.vmid},
        ),
      );
      if (data is List) {
        out.addAll(PveResources.parseBackups(node, storage.name, data));
      }
    }
    out.sort(
      (a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return out;
  }

  @override
  Future<List<VirtStoragePool>> backupStorages(VirtGuest guest) =>
      _backupStorages(guest.node!);

  /// Every online node's storages, deduplicated by `node/storage`: a shared
  /// storage is listed by each node that sees it, and a job names one by its
  /// own id.
  @override
  Future<List<VirtStoragePool>> allBackupStorages() async {
    final out = <String, VirtStoragePool>{};
    for (final node in await _onlineNodes()) {
      for (final pool in await _backupStorages(node)) {
        out.putIfAbsent('${pool.node}/${pool.name}', () => pool);
      }
    }
    final list = out.values.toList()
      ..sort((a, b) {
        final byName = a.name.compareTo(b.name);
        return byName != 0 ? byName : (a.node ?? '').compareTo(b.node ?? '');
      });
    return list;
  }

  Future<List<VirtStoragePool>> _backupStorages(String node) async {
    final data = await _call(
      (dio) => dio.get(
        _url('/nodes/${_seg(node)}/storage'),
        queryParameters: {'content': 'backup', 'enabled': 1},
      ),
    );
    if (data is! List) return const [];
    return PveResources.parseStorages(node, data)
        .where((s) => s.active && s.content.contains('backup'))
        .toList();
  }

  /// `/cluster/backup` needs `Sys.Audit`: an account without it sees no plan,
  /// which is not a failure of the view.
  @override
  Future<List<VirtBackupJob>> backupJobs(VirtGuest guest) async {
    final jobs = await allBackupJobs();
    return [
      for (final j in jobs)
        if (j.takes(guest.vmid, node: guest.node)) j,
    ];
  }

  /// `/cluster/backup` for the datacenter's Backup view. The same
  /// `Sys.Audit`: an account without it sees no jobs rather than an error.
  @override
  Future<List<VirtBackupJob>> allBackupJobs() async {
    final Object? data;
    try {
      data = await _call((dio) => dio.get(_url('/cluster/backup')));
    } on VirtErr catch (e) {
      if (e.type == VirtErrType.authFailed) return const [];
      rethrow;
    }
    if (data is! List) return const [];
    return PveResources.parseBackupJobs(data);
  }

  /// `POST /cluster/backup` (a new job), `PUT /cluster/backup/{id}` (the
  /// job with that id) or `DELETE` with [remove] — `Sys.Modify` on `/`, which
  /// is PVE's own rule for the datacenter's job list. PVE validates the
  /// schedule itself (`pve-calendar-event`); [`virtScheduleIssue`] refuses
  /// what it would before it is asked.
  @override
  Future<void> editBackupJob(VirtBackupJobEdit edit, {bool remove = false}) async {
    final id = edit.id;
    if (remove) {
      if (id == null) {
        throw const VirtErr(type: VirtErrType.unsupported);
      }
      final removeId = id;
      await _call(
        (dio) => dio.delete(_url('/cluster/backup/${_seg(removeId)}')),
      );
      return;
    }
    final which = _jobGuests(
      pool: edit.pool,
      all: edit.all,
      vmids: edit.vmids,
      exclude: edit.exclude,
    );
    // PVE's own `PUT` keeps what it is not sent, so a field this edit does
    // not set is named in `delete` — what its web UI's `deleteEmpty` does per
    // field. Deleting one that was not set is a no-op, and a create takes
    // none (there is nothing to clear).
    final deletes = <String>[
      for (final k in const ['vmid', 'exclude', 'pool'])
        if (!which.containsKey(k)) k,
      if (edit.node == null) 'node',
      if (edit.comment == null) 'comment',
      if (edit.notesTemplate == null) 'notes-template',
      if (edit.prune == null) 'prune-backups',
    ];
    final body = {
      'storage': edit.storage,
      'schedule': edit.schedule,
      'mode': edit.mode,
      'compress': edit.compress,
      'enabled': edit.enabled ? 1 : 0,
      // Cleared unless [which] takes all guests, which sets it to 1.
      'all': 0,
      ...which,
      'node': ?edit.node,
      'comment': ?edit.comment,
      'notes-template': ?edit.notesTemplate,
      'mailnotification': ?edit.mailNotification,
      'prune-backups': ?edit.prune,
      if (!edit.isNew && deletes.isNotEmpty) 'delete': deletes.join(','),
    };
    // A new job may be named by the form; PVE generates an id when it is
    // not, and answers with the one it made.
    final data = await _call(
      (dio) => edit.isNew
          ? dio.post(
              _url('/cluster/backup'),
              data: {'id': ?id, ...body},
              options: Options(contentType: Headers.formUrlEncodedContentType),
            )
          : dio.put(
              _url('/cluster/backup/${_seg(id ?? '')}'),
              data: body,
              options: Options(contentType: Headers.formUrlEncodedContentType),
            ),
    );
    // A `POST` answers the new job's id (`"sbbk-job"`); this app names every
    // job it makes, so there is nothing to keep.
    if (data is String && data.isEmpty) {
      throw const VirtErr(type: VirtErrType.invalidResponse);
    }
  }

  /// `GET /cluster/jobs/schedule-analyze`, the call PVE's job editor's
  /// "Simulate" button makes. Its permission is `user => 'all'`: any account
  /// that may log in can ask it, and it is what the form's Validate runs
  /// rather than a calendar parser written here.
  @override
  Future<VirtScheduleCheck> checkSchedule(String schedule) async {
    try {
      final data = await _call(
        (dio) => dio.get(
          _url('/cluster/jobs/schedule-analyze'),
          queryParameters: {'schedule': schedule, 'iterations': 3},
        ),
      );
      if (data is! List) return const VirtScheduleCheck();
      return VirtScheduleCheck(
        next: [
          for (final item in data)
            if (item is Map && item['timestamp'] is int)
              DateTime.fromMillisecondsSinceEpoch(
                (item['timestamp'] as int) * 1000,
                isUtc: true,
              ),
        ],
      );
    } on VirtErr catch (e) {
      // A refused schedule is a 400 with PVE's parse error; the form shows
      // it under the field rather than as a failed request.
      if (e.type == VirtErrType.actionFailed ||
          e.type == VirtErrType.invalidResponse) {
        return VirtScheduleCheck(error: e.message ?? 'HTTP 400');
      }
      rethrow;
    }
  }

  /// `POST /nodes/{node}/vzdump` for the one guest, waited for.
  @override
  Future<void> backup(VirtGuest guest, VirtBackupRequest request) async {
    final notes = request.notes?.trim();
    await _runVzdump(guest.node!, {
      'vmid': guest.vmid,
      'storage': request.storage,
      'mode': request.mode,
      'compress': request.compress,
      'notes-template': ?(notes == null || notes.isEmpty) ? null : notes,
      'protected': ?request.protected ? 1 : null,
      'prune-backups': ?request.prune,
    });
  }

  /// Which guests a job takes, as `vzdump` and `/cluster/backup` name
  /// them: a pool, all of them (less `exclude`), or a list — one of the
  /// three, the pool first. PVE's own editor offers the same three.
  static Map<String, Object> _jobGuests({
    required String? pool,
    required bool all,
    required List<int> vmids,
    required List<int> exclude,
  }) => switch (pool) {
    final pool? => {'pool': pool},
    null when all => {
      'all': 1,
      if (exclude.isNotEmpty) 'exclude': exclude.join(','),
    },
    null => {if (vmids.isNotEmpty) 'vmid': vmids.join(',')},
  };

  /// A job's "Run now", as PVE's own web UI does it (`run_backup_now` in
  /// `dc/Backup.js`): the job's fields without the ones that describe the
  /// schedule, posted to `vzdump` on the job's node — refused when it is not
  /// online — or, for a job with no node, on every online node. `vzdump`
  /// takes only the guests on the node it runs on, so one request per node
  /// is what covers a cluster. (`/cluster/backup/{id}/included_volumes` is
  /// what its detail view *lists*, not what runs it.)
  ///
  /// The job is read again for it: [VirtBackupJob] models what the form
  /// edits, and a job also carries what only PVE's editor sets (`bwlimit`,
  /// `ionice`, `performance`, `fleecing`, ...), which a run must keep.
  @override
  Future<void> runBackupJob(VirtBackupJob job) async {
    final raw = await _call(
      (dio) => dio.get(_url('/cluster/backup/${_seg(job.id)}')),
    );
    if (raw is! Map) {
      throw const VirtErr(type: VirtErrType.invalidResponse);
    }
    final online = [
      for (final n in _nodes)
        if (n.online) n.name,
    ];
    final nodes = switch (raw['node']) {
      '' => online,
      final node? when online.contains(node) => [node],
      final node? => throw VirtErr(
        type: VirtErrType.unsupported,
        message: "Node '$node' of backup job ${job.id} is not online",
      ),
      null => online,
    };
    if (nodes.isEmpty) {
      throw const VirtErr(
        type: VirtErrType.unsupported,
        message: 'No online node to run the job on',
      );
    }
    final body = PveResources.vzdumpOfJob(raw.cast<String, Object?>());
    await Future.wait([for (final n in nodes) _runVzdump(n, body)]);
  }

  /// One `vzdump` request, waited for. It is the node's task rather than a
  /// guest's, so `_task` — which names the guest — does not fit.
  Future<void> _runVzdump(String node, Map<String, Object?> body) async {
    final upid = await _call(
      (dio) => dio.post(
        _url('/nodes/${_seg(node)}/vzdump'),
        data: body,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
      action: true,
    );
    if (upid is String && upid.startsWith('UPID:')) {
      await _waitTask(node, upid);
    }
  }

  /// `POST /nodes/{node}/qemu` with `archive`, or `/lxc` with `ostemplate`
  /// and `restore=1`. Over the guest itself with `force=1`, which PVE
  /// refuses while it runs; as a new guest with [vmid] otherwise.
  ///
  /// [storage] is where the restored disks land (`--storage`, PVE's `Default
  /// storage`), which is how a backup taken on one storage is restored onto
  /// another; null leaves each volume where the archive says.
  @override
  Future<void> restoreBackup(
    VirtGuest guest,
    VirtBackup backup, {
    int? vmid,
    String? storage,
  }) async {
    final node = guest.node!;
    final lxc = (backup.kind ?? guest.kind) == VirtGuestKind.lxc;
    final over = vmid == null;
    if (over && guest.state != VirtGuestState.stopped) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} is not stopped',
      );
    }
    try {
      await _task(
        guest,
        (dio) => dio.post(
          _url('/nodes/${_seg(node)}/${lxc ? 'lxc' : 'qemu'}'),
          data: {
            'vmid': vmid ?? guest.vmid,
            if (lxc) ...{'ostemplate': backup.id, 'restore': 1} else 'archive': backup.id,
            'force': ?over ? 1 : null,
            'storage': ?storage,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        ),
      );
    } on VirtErr catch (e) {
      throw _createErr(e);
    }
  }

  /// A refused restore, in the host's words: PVE answers a bad parameter with
  /// 400 and a taken VMID with 500, before any task.
  // TODO(migration): goes with the restore's move to sbm_virt (#1623 item 5,
  // backups), whose client maps it as `manage_err` does.
  static VirtErr _createErr(VirtErr e) {
    // `unable to create VM 105 - VM 105 already exists on node 'pve'`.
    if (e.message?.contains('already exists') ?? false) {
      return VirtErr(type: VirtErrType.exists, message: e.message, cause: e);
    }
    final cause = e.cause;
    if (e.type == VirtErrType.invalidResponse &&
        cause is DioException &&
        cause.response != null) {
      return VirtErr(
        type: VirtErrType.actionFailed,
        message: e.message,
        cause: cause,
      );
    }
    return e;
  }

  /// `PUT /nodes/{node}/storage/{id}/content/{volid}`: a backup's own notes
  /// and protection. Both fields are sent every time — PVE keeps what is not
  /// sent, so an empty note has to be written as one.
  @override
  Future<void> editBackup(VirtBackup backup, VirtBackupEdit edit) async {
    await _call(
      (dio) => dio.put(
        _url(
          '/nodes/${_seg(backup.node)}/storage/${_seg(backup.storage)}'
          '/content/${_seg(backup.id)}',
        ),
        data: {'notes': edit.notes, 'protected': edit.protected ? 1 : 0},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
  }

  @override
  Future<void> deleteBackup(VirtGuest guest, VirtBackup backup) => _task(
    guest,
    (dio) => dio.delete(
      _url(
        '/nodes/${_seg(backup.node)}/storage/${_seg(backup.storage)}'
        '/content/${_seg(backup.id)}',
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Hardware
  // ---------------------------------------------------------------------------

  /// `sbm_virt::pve::Client::hardware`: the configuration with its pending
  /// changes applied and the `digest` an edit is sent back with, what the
  /// running guest has instead, and the node's CPUs, memory and CPU models.
  @override
  Future<VirtHardware> hardware(VirtGuest guest) async =>
      VirtRust.hardware(jsonDecode(await _rust((s) => s.hardware(guest: _ref(guest)))));

  /// One change, made from [base]'s digest and checked against the guest as
  /// it is now (`sbm_virt::pve::Client::change_hardware`). What the running
  /// guest cannot take is PVE's to put in `pending`.
  @override
  Future<VirtHwOutcome> changeHardware(
    VirtGuest guest,
    VirtHardware base,
    VirtHwChange change,
  ) async => VirtRust.hwOutcome(
    jsonDecode(
      await _rust(
        (s) => s.changeHardware(
          guest: _ref(guest),
          revision: base.revision,
          changeJson: jsonEncode(VirtRust.hwChangeJson(change)),
        ),
      ),
    ),
  );

  /// PVE drops pending changes item by item (`revert`).
  @override
  Future<void> revertPending(VirtGuest guest, VirtHardware base) =>
      _rust((s) => s.revertPending(guest: _ref(guest), revision: base.revision));

  /// PVE's `ci*` options.
  @override
  Future<VirtCloudInitState> cloudInit(VirtGuest guest) async =>
      VirtRust.cloudInitState(jsonDecode(await _rust((s) => s.cloudInit(guest: _ref(guest)))));

  /// The `ci*` options set with [base]'s digest, then the drive written at
  /// once. The password goes in the request body; PVE keeps its hash.
  @override
  Future<void> setCloudInit(
    VirtGuest guest,
    VirtCloudInitState base,
    VirtCloudInitEdit edit,
  ) => _rust(
    (s) => s.setCloudInit(
      guest: _ref(guest),
      editJson: jsonEncode(VirtRust.cloudInitEditJson(base, edit)),
    ),
  );

  /// Resource mappings, and the node's own devices for root@pam logged in
  /// with its password.
  @override
  Future<VirtHostDevices> hostDevices(VirtGuest guest) async =>
      VirtRust.hostDevices(jsonDecode(await _rust((s) => s.hostDevices(guest: _ref(guest)))));

  /// PVE's refusal of a stale digest as [VirtErrType.conflict]; a rejected
  /// parameter as the action refused, in PVE's words.
  static VirtErr _changeErr(VirtErr e) {
    final message = e.message ?? '';
    if (message.contains('checksum mismatch') ||
        message.contains('file change by other user')) {
      return VirtErr(type: VirtErrType.conflict, message: message, cause: e);
    }
    final cause = e.cause;
    if (e.type == VirtErrType.invalidResponse &&
        cause is DioException &&
        cause.response != null) {
      return VirtErr(
        type: VirtErrType.actionFailed,
        message: e.message,
        cause: cause,
      );
    }
    return e;
  }

  // ---------------------------------------------------------------------------
  // Storage and networks
  // ---------------------------------------------------------------------------

  /// The nodes to ask: the online ones of the last [load], or every node
  /// `/nodes` lists when there has been none.
  Future<List<String>> _onlineNodes() async {
    if (_nodes.isNotEmpty) {
      return [
        for (final n in _nodes)
          if (n.online) n.name,
      ];
    }
    final data = await _call((dio) => dio.get(_url('/nodes')));
    if (data is! List) return const [];
    return [
      for (final n in data)
        if (n is Map && n['status'] == 'online' && n['node'] is String)
          n['node'] as String,
    ]..sort();
  }

  @override
  Future<List<VirtStoragePool>> storagePools() async =>
      VirtRust.pools(jsonDecode(await _rust((s) => s.storagePools())));

  @override
  Future<List<VirtVolume>> volumes(VirtStoragePool pool) async =>
      VirtRust.volumes(
        jsonDecode(
          await _rust(
            (s) => s.volumes(poolJson: jsonEncode(VirtRust.poolJson(pool))),
          ),
        ),
      );

  /// Every online node's interfaces, with the guests whose NICs are on each
  /// bridge and which may be changed at all
  /// (`sbm_virt::pve::Client::networks`).
  @override
  Future<List<VirtNetwork>> networks() async {
    final live = await _liveNet();
    return VirtRust.networks(
      jsonDecode(await _rust((s) => s.networks(live: live))),
    );
  }

  /// Checked against what the host lists now, then made, a node's network
  /// changes one at a time (`sbm_virt::pve::Client::manage`).
  @override
  Future<void> manage(VirtResourceChange change) async {
    final network = change.nodeScope != null;
    final live = network ? await _liveNet() : null;
    await _rust(
      (s) => s.manage(
        changeJson: jsonEncode(VirtRust.changeJson(change)),
        live: live,
      ),
    );
  }

  /// Runs a command on the server this backend reaches PVE through, for
  /// what the API does not say ([_liveNet]); null in tests.
  final Future<ServerExec> Function()? _exec;

  /// What the server says of the interfaces it is using
  /// (`sbm_virt::pve::net::LIVE_NET_SCRIPT`), as it printed it; null when it
  /// could not be run, which protects every interface with an address.
  Future<String?> _liveNet() async {
    final exec = _exec;
    if (exec == null) return null;
    try {
      final r = await (await exec()).run(res.virtPveLiveNetScript(), entry: 'sh');
      return r.stdout;
    } catch (e) {
      Loggers.app.info('PVE live network probe: $e');
      return null;
    }
  }

  String _storagePath(VirtStoragePool pool) {
    final node = pool.node;
    if (node == null) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: 'No node for storage ${pool.name}',
      );
    }
    return '/nodes/${_seg(node)}/storage/${_seg(pool.name)}';
  }

  /// [request] on [node], which answers a UPID or, for a change PVE makes at
  /// once, nothing; the task waited for.
  Future<void> _nodeTask(
    String node,
    Future<Response<dynamic>> Function(Dio dio) request, {
    Dio? via,
  }) async {
    final upid = await _call(request, action: true, via: via);
    if (upid is String && upid.startsWith('UPID:')) {
      await _waitTask(node, upid);
    }
  }

  static final _permissionCheck = RegExp(
    r'Permission check failed \(([^,()]+), ([A-Za-z.]+)\)',
  );

  /// An upload's refusal: a name taken as [VirtErrType.exists]; PVE's
  /// permission refusal naming the privilege, where, and how to grant it.
  // TODO(migration): what `sbm_virt::pve::Client::manage` says of a refusal
  // (`Detail::NeedsPrivilege`); here only for the upload, which streams over
  // a connection of its own.
  VirtErr _manageErr(VirtErr e) {
    final message = e.message ?? '';
    if (message.contains('already exists') ||
        message.contains('already defined')) {
      return VirtErr(type: VirtErrType.exists, message: message, cause: e.cause);
    }
    final m = _permissionCheck.firstMatch(message);
    if (m == null) return _changeErr(e);
    final path = m[1]!.trim();
    final privilege = m[2]!;
    final token = _config.auth == PveAuth.token;
    final account = token ? _config.tokenId ?? '' : _userFields()['username']!;
    final qualified = token || account.contains('@') ? account : '$account@pam';
    final who = "--${token ? 'tokens' : 'users'} '$qualified'";
    final command = switch (pvePrivilegeRole(privilege)) {
      final role? => 'pveum acl modify $path $who --roles $role',
      null =>
        "pveum role add ServerBox-${privilege.replaceAll('.', '')} "
            '--privs $privilege\n'
            'pveum acl modify $path $who '
            '--roles ServerBox-${privilege.replaceAll('.', '')}',
    };
    return VirtErr(
      type: VirtErrType.permissionDenied,
      message: l10n.pveNeedsPrivilege(qualified, privilege, path, command),
      cause: e.cause,
    );
  }

  /// The narrowest built-in PVE role holding [privilege]; null where only
  /// `Administrator` does (`Sys.Modify`).
  // TODO(migration): `sbm_virt::pve::client` has the same table; remove with
  // [_manageErr].
  @visibleForTesting
  static String? pvePrivilegeRole(String privilege) => switch (privilege) {
    'Datastore.AllocateSpace' || 'Datastore.Audit' => 'PVEDatastoreUser',
    'Datastore.Allocate' || 'Datastore.AllocateTemplate' => 'PVEDatastoreAdmin',
    'Sys.Audit' => 'PVEAuditor',
    'SDN.Use' => 'PVESDNUser',
    final p when p.startsWith('VM.') => 'PVEVMAdmin',
    _ => null,
  };

  /// Each online node's pending network configuration.
  @override
  Future<List<VirtNetworkChanges>> networkChanges() async =>
      VirtRust.networkChanges(
        jsonDecode(await _rust((s) => s.networkChanges())),
      );

  /// How long PVE may take to answer an upload once it has the bytes: it
  /// checks the file and starts the task that moves it into place.
  static const uploadReplyTimeout = Duration(minutes: 5);

  /// `POST .../upload`, multipart, the file last as PVE wants it; no send
  /// timeout (the file takes as long as it takes). PVE spools the upload to
  /// a temporary file and removes it when the connection breaks, so a
  /// cancelled one leaves nothing; a finished one is moved into place by a
  /// task, waited for.
  @override
  Future<bool> upload(
    VirtUpload upload, {
    void Function(int sent)? onProgress,
    Future<void>? cancel,
  }) async {
    final pool = upload.pool;
    final token = CancelToken();
    var cancelled = false;
    unawaited(
      cancel?.then((_) {
        cancelled = true;
        token.cancel();
      }),
    );
    // Its own connection, streamed: the session's adapter holds a body in
    // memory, which is no way to send an image.
    final dio = Dio(
      BaseOptions(
        baseUrl: '$_base',
        connectTimeout: connectTimeout,
        headers: await _authHeaders(),
      ),
    )..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => _httpClient(_config.certSha256),
      );
    try {
      await _nodeTask(
        pool.node!,
        via: dio,
        (dio) => dio.post(
          _url('${_storagePath(pool)}/upload'),
          // Made per attempt: a repeated request reads the file again.
          // `Content-Disposition` capitalised: pveproxy finds the parts with
          // a case-sensitive pattern, and Dio's default lowercase header
          // leaves it waiting for a part it never sees until the upload
          // fails (PVE 9.2).
          data: FormData.fromMap(
            {
              'content': upload.content,
              'filename': MultipartFile.fromStream(
                upload.open,
                upload.size,
                filename: upload.name,
              ),
            },
            ListFormat.multi,
            true,
          ),
          cancelToken: token,
          onSendProgress: (sent, _) => onProgress?.call(sent),
          options: Options(
            sendTimeout: Duration.zero,
            receiveTimeout: uploadReplyTimeout,
          ),
        ),
      );
      return true;
    } on VirtErr catch (e) {
      if (cancelled) return false;
      throw _manageErr(e);
    } catch (_) {
      if (cancelled) return false;
      rethrow;
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<void> reset() async {
    _session?.reset();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _dropTransport();
    _onClose?.call();
  }

  // ---------------------------------------------------------------------------
  // What the user answers
  // ---------------------------------------------------------------------------

  /// The TOTP code for the challenge [VirtErrType.needTfa] announced. Then
  /// [load] again. A challenge gone or past its lifetime is replaced by a new
  /// login first (`sbm_virt::pve::Client::submit_tfa`).
  Future<void> submitTfa(String code) => _rust((s) => s.submitTfa(code: code));

  /// Pins [fingerprint], which must be the certificate the last refused
  /// connection presented ([VirtErr.cert]), and starts over. Writes it to the
  /// server's PVE configuration.
  Future<void> confirmCert(String fingerprint) async {
    String pin;
    try {
      final session = await _ensure();
      pin = session.confirmCert(fingerprint: fingerprint);
    } on PveError catch (e) {
      // Refused on a console's or an upload's own connection, which the
      // session did not see.
      final presented = _presented;
      if (presented == null ||
          presented.fingerprint.toLowerCase() != fingerprint.toLowerCase()) {
        throw _fromRust(e);
      }
      pin = presented.fingerprint.toLowerCase();
    }
    _presented = null;
    _config = _config.copyWith(certSha256: pin);
    _session?.updateLogin(login: _login());
    _onCertConfirmed?.call(pin);
  }

  // ---------------------------------------------------------------------------
  // The session (sbm_virt::pve over FFI)
  // ---------------------------------------------------------------------------

  /// [guest] as a call on it carries it to the session.
  static PveGuestRef _ref(VirtGuest guest) => PveGuestRef(
    id: guest.id,
    name: guest.name,
    node: guest.node,
    vmid: guest.vmid,
    lxc: guest.kind == VirtGuestKind.lxc,
    actions: [for (final a in guest.actions) _kindOf(a)],
  );

  static VirtActionKind _kindOf(VirtPowerAction action) => switch (action) {
    VirtPowerAction.start => VirtActionKind.start,
    VirtPowerAction.shutdown => VirtActionKind.shutdown,
    VirtPowerAction.reboot => VirtActionKind.reboot,
    VirtPowerAction.forceStop => VirtActionKind.forceStop,
    VirtPowerAction.suspend => VirtActionKind.suspend,
    VirtPowerAction.resume => VirtActionKind.resume,
  };

  /// Who a password login is for: `root@pam` already names its realm.
  Map<String, String> _userFields() {
    final name = user?.trim() ?? '';
    return name.contains('@')
        ? {'username': name}
        : {'username': name, 'realm': 'pam'};
  }

  PveLogin _login() {
    final token = _config.auth == PveAuth.token;
    return PveLogin(
      addr: '$_base',
      token: token,
      user: user?.trim() ?? '',
      // Sent as stored, spaces included: PAM compares it byte for byte.
      password:
          _config.loginPassword(sshKeyId: sshKeyId, sshPassword: sshPassword) ??
          '',
      tokenId: _config.tokenId ?? '',
      tokenSecret: _config.tokenSecret ?? '',
      certSha256: _config.certSha256,
    );
  }

  /// The session, with a live tunnel under it. Opened once however many
  /// callers ask.
  Future<PveSession> _ensure() async {
    if (_closed) throw StateError('PveBackend used after close');
    final session = _session;
    final tunnel = _tunnel;
    if (session != null && tunnel != null && !tunnel.isClosed) return session;
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<PveSession> _open() async {
    final base = _base;
    final SshLocalTunnel tunnel;
    try {
      tunnel = await _openTunnel(base.host, base.hasPort ? base.port : 443);
    } catch (e) {
      throw _toErr(e);
    }
    final token = tunnel.accessToken!;
    if (_closed) {
      await tunnel.close();
      throw StateError('PveBackend used after close');
    }
    final stale = _tunnel;
    _tunnel = tunnel;
    unawaited(stale?.close());
    final session = _session;
    if (session != null) {
      session.setLoopback(port: tunnel.port, token: token);
      return session;
    }
    try {
      return _session = PveSession(
        login: _login(),
        port: tunnel.port,
        token: token,
        timing: PveTiming(
          taskPollMs: BigInt.from(taskPoll.inMilliseconds),
          taskTimeoutMs: BigInt.from(taskTimeout.inMilliseconds),
        ),
      );
    } on PveError catch (e) {
      throw _fromRust(e);
    }
  }

  /// Runs [call] in the session; a failure is a [VirtErr]. A transport
  /// failure lets the tunnel go, so the next call opens another.
  Future<T> _rust<T>(Future<T> Function(PveSession s) call) async {
    final session = await _ensure();
    try {
      return await call(session);
    } on PveError catch (e) {
      if (e.kind == VirtFailure.unreachable) {
        final tunnel = _tunnel;
        _tunnel = null;
        unawaited(tunnel?.close());
      }
      throw _fromRust(e);
    }
  }

  void _dropTransport() {
    _session?.close();
    _session = null;
    final tunnel = _tunnel;
    _tunnel = null;
    unawaited(tunnel?.close());
    _dio?.close(force: true);
    _dio = null;
  }

  /// A failure of the session as this app phrases it ([VirtRust.error]);
  /// the certificate it presented is what [confirmCert] may pin.
  VirtErr _fromRust(PveError e) {
    final cert = e.cert;
    if (cert != null) _presented = cert;
    return VirtRust.error(e);
  }

  /// The client the calls not yet in `sbm_virt` build their requests with;
  /// every request goes through the session ([_PveSessionAdapter]).
  Dio _api() => _dio ??= Dio(
    BaseOptions(
      baseUrl: '$_base',
      connectTimeout: connectTimeout,
      sendTimeout: requestTimeout,
      receiveTimeout: requestTimeout,
    ),
  )..httpClientAdapter = _PveSessionAdapter(this);

  /// Runs [request] in the session and answers the body's `data`.
  ///
  /// **A 403 never ends the session.** PVE answers 403 only after it has
  /// accepted the ticket or token, from its permission check ("Permission
  /// check failed (/vms/101, VM.PowerMgmt)") — the account lacks a privilege
  /// on that path. [action] marks a call on one guest (a power action, its
  /// task, a console ticket), whose 403 is [VirtErrType.actionFailed] with
  /// PVE's text; elsewhere it is [VirtErrType.authFailed].
  ///
  /// A 401, a refused ticket's new login and the request sent again are the
  /// session's ([PveSession.raw]); a 401 that reaches here is the account's.
  ///
  /// [whole]: the response body itself, for what PVE puts beside `data`
  /// (the network listing's `changes`). [via]: a client of the caller's own
  /// rather than the session's (an upload).
  Future<Object?> _call(
    Future<Response<dynamic>> Function(Dio dio) request, {
    bool action = false,
    bool whole = false,
    Dio? via,
  }) async {
    try {
      final resp = await request(via ?? _api());
      final body = resp.data;
      if (body is! Map) {
        throw VirtErr(
          type: VirtErrType.invalidResponse,
          message: l10n.pveInvalidResponseBody,
        );
      }
      return whole ? body : body['data'];
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      if (status == 403) {
        final err = _toErr(e);
        if (!action) throw err;
        throw VirtErr(
          type: VirtErrType.actionFailed,
          message: _pveMessage(e as DioException) ?? err.message,
          cause: e,
        );
      }
      final err = _toErr(e);
      // An action PVE answered with a refusal of its own (`unable to create
      // template, because VM contains snapshots`, a 500 before any task) is
      // the action refused, in PVE's words, not a response this app
      // cannot read.
      if (action &&
          err.type == VirtErrType.invalidResponse &&
          e is DioException &&
          e.response != null) {
        throw VirtErr(
          type: VirtErrType.actionFailed,
          message: err.message,
          cause: e,
        );
      }
      throw err;
    }
  }

  Future<void> _waitTask(String node, String upid) =>
      _rust((s) => s.waitTask(node: node, upid: upid));

  // ---------------------------------------------------------------------------
  // A console's and an upload's own connection
  // ---------------------------------------------------------------------------

  /// The session's headers, for a connection made outside it.
  Future<Map<String, String>> _authHeaders() async {
    final headers = await _rust((s) => s.authHeaders());
    return {for (final h in headers) h.name: h.value};
  }

  /// How long an idle connection is kept for the next request: under
  /// pveproxy's own 5 s, after which it closes the connection.
  static const idleTimeout = Duration(seconds: 3);

  /// [pin] is the confirmed certificate's fingerprint, or null when none has
  /// been confirmed — in which case every certificate no CA vouches for is
  /// refused for review.
  HttpClient _httpClient(String? pin) {
    final client = HttpClient(context: securityContext)
      ..connectionTimeout = connectTimeout
      ..idleTimeout = idleTimeout;
    client.connectionFactory = (url, proxyHost, proxyPort) async =>
        _connectTo(url, pin);
    return client;
  }

  /// A connection for [url]: the dialer's socket, secured here for `https` so
  /// the certificate decision is this class's and not `HttpClient`'s.
  ConnectionTask<Socket> _connectTo(Uri url, String? pin) {
    final task = _connect(url.host, url.port);
    if (!url.isScheme('https') && !url.isScheme('wss')) return task;
    X509Certificate? refused;
    final secure = task.socket.then((socket) async {
      try {
        return await SecureSocket.secure(
          socket,
          host: url.host,
          context: securityContext,
          onBadCertificate: (cert) {
            if (certPinAccepts(pin: pin, der: cert.der)) return true;
            refused = cert;
            return false;
          },
        );
      } on HandshakeException catch (e) {
        final cert = refused;
        if (cert == null) rethrow;
        throw _certErr(cert, pin, e);
      }
    });
    // Handled here for the reason `ServerTcpDialer.startConnect` gives: a
    // refusal decided before dialling fails this before `HttpClient` listens.
    secure.ignore();
    return ConnectionTask.fromSocket(secure, task.cancel);
  }

  VirtErr _certErr(X509Certificate cert, String? pin, Object cause) {
    final info =
        certInfoFromDer(der: cert.der) ??
        CertInfo(
          fingerprint: certFingerprint(der: cert.der),
          subject: cert.subject,
          issuer: cert.issuer,
          notBefore: cert.startValidity.millisecondsSinceEpoch ~/ 1000,
          notAfter: cert.endValidity.millisecondsSinceEpoch ~/ 1000,
        );
    _presented = info;
    if (pin == null || pin.isEmpty) {
      return VirtErr(
        type: VirtErrType.certUnconfirmed,
        message: info.prettyFingerprint,
        cert: info,
        cause: cause,
      );
    }
    return VirtErr(
      type: VirtErrType.certChanged,
      message: info.prettyFingerprint,
      cert: info,
      previousFingerprint: pin,
      cause: cause,
    );
  }

  /// PVE's own words for a failed request: `message`, or the reason phrase.
  static String? _pveMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'];
      final errors = data['errors'];
      // A 400 says "Parameter verification failed." and which parameter in
      // `errors`: both, or the first says nothing.
      final lines = [
        if (message is String && message.trim().isNotEmpty) message.trim(),
        if (errors is Map)
          for (final e in errors.entries) '${e.key}: ${'${e.value}'.trim()}',
      ];
      if (lines.isNotEmpty) return lines.join('\n');
    }
    final reason = e.response?.statusMessage;
    return reason == null || reason.trim().isEmpty ? null : reason.trim();
  }

  VirtErr _toErr(Object e) {
    if (e is VirtErr) return e;
    if (e is PveError) return _fromRust(e);
    if (e is ServerTcpErr) {
      return VirtErr(
        type: e.type == ServerTcpErrType.relayNotGranted
            ? VirtErrType.relayNotGranted
            : VirtErrType.unreachable,
        message: e.message,
        cause: e,
      );
    }
    if (e is DioException) {
      final inner = e.error;
      if (inner is VirtErr || inner is ServerTcpErr || inner is PveError) {
        return _toErr(inner!);
      }
      final code = e.response?.statusCode;
      if (code == 401 || code == 403) {
        // Without PVE's text, which token (never its secret) or the status:
        // identifiers rather than a sentence, since the UI supplies the
        // localized title.
        final token = _config.auth == PveAuth.token;
        return VirtErr(
          type: VirtErrType.authFailed,
          message:
              _pveMessage(e) ??
              (token ? _config.tokenId : null) ??
              'HTTP $code',
          cause: e,
        );
      }
      if (e.response != null) {
        return VirtErr(
          type: VirtErrType.invalidResponse,
          message: _pveMessage(e) ?? 'HTTP $code',
          cause: e,
        );
      }
      if (inner != null) return _toErr(inner);
      return VirtErr(
        type: VirtErrType.unreachable,
        message: e.message ?? e.type.name,
        cause: e,
      );
    }
    if (e is SocketException ||
        e is HandshakeException ||
        e is TlsException ||
        e is HttpException ||
        e is TimeoutException ||
        e is WebSocketException) {
      return VirtErr(
        type: VirtErrType.unreachable,
        message: e.toString(),
        cause: e,
      );
    }
    return VirtErr(type: VirtErrType.unknown, message: '$e', cause: e);
  }
}

/// Hands each request a [PveBackend]'s Dio builds to its session
/// ([PveSession.raw]) and answers what PVE did, status and body as sent.
// TODO(migration): goes with the last call not yet in `sbm_virt`.
class _PveSessionAdapter implements HttpClientAdapter {
  _PveSessionAdapter(this.backend);

  final PveBackend backend;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = BytesBuilder(copy: false);
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.add(chunk);
      }
    }
    final uri = options.uri;
    final method = switch (options.method.toUpperCase()) {
      'POST' => PveMethod.post,
      'PUT' => PveMethod.put,
      'DELETE' => PveMethod.delete,
      _ => PveMethod.get_,
    };
    final resp = await backend._rust(
      (s) => s.raw(
        method: method,
        path: uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path,
        contentType: options.contentType,
        body: requestStream == null ? null : bytes.takeBytes(),
      ),
    );
    return ResponseBody.fromBytes(
      resp.body,
      resp.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
