import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/core/utils/ssh_local_tunnel.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
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
/// **Every call is `sbm_virt::pve`'s** ([PveSession], FFI), the client the
/// monitor agent keeps too: login (password + TOTP, or an API token), ticket
/// renewal, one new login for a refused ticket, the certificate decision,
/// and each typed call with the rules it is checked by. It reaches the API
/// through an authenticated loopback tunnel of the server's
/// `ServerTcpDialer` ([tunnel]: an SSH channel, the monitor agent's relay,
/// or a direct socket for this device), opened on first use and again once
/// it has ended.
///
/// Two connections are this class's own, authenticated with the session's
/// headers ([connect], [_httpClient]): a console's websocket, which the
/// console view reads frame by frame, and an upload, which streams a file
/// the session would hold in memory. An upload's refusal is said by the
/// session all the same ([PveSession.refusal]).
// TODO(migration): the console's websocket through the session
// (`sbm_virt::pve::Client::open_console`, which the agent uses), then drop
// the Dart TLS path for it.
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
    return VirtRust.snapshot(jsonDecode(json), serverId: serverId);
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

  /// Every backup of the guest on its node's backup storages, newest first
  /// (`sbm_virt::pve::Client::backups`).
  @override
  Future<List<VirtBackup>> backups(VirtGuest guest) async =>
      VirtRust.backups(jsonDecode(await _rust((s) => s.backups(guest: _ref(guest)))));

  @override
  Future<List<VirtStoragePool>> backupStorages(VirtGuest guest) async =>
      VirtRust.pools(jsonDecode(await _rust((s) => s.backupStorages(node: guest.node!))));

  /// Every online node's backup storages, one per `node/storage`.
  @override
  Future<List<VirtStoragePool>> allBackupStorages() async =>
      VirtRust.pools(jsonDecode(await _rust((s) => s.allBackupStorages())));

  /// The jobs that take the guest. `/cluster/backup` needs `Sys.Audit`: an
  /// account without it sees no plan, which is not a failure of the view.
  @override
  Future<List<VirtBackupJob>> backupJobs(VirtGuest guest) async =>
      VirtRust.backupJobs(jsonDecode(await _rust((s) => s.backupJobs(guest: _ref(guest)))));

  @override
  Future<List<VirtBackupJob>> allBackupJobs() async =>
      VirtRust.backupJobs(jsonDecode(await _rust((s) => s.allBackupJobs())));

  /// Made, edited or removed — `Sys.Modify` on `/`; checked first
  /// (`sbm_virt::backup::job_issue`).
  @override
  Future<void> editBackupJob(VirtBackupJobEdit edit, {bool remove = false}) => _rust(
    (s) => s.editBackupJob(editJson: jsonEncode(VirtRust.backupJobEditJson(edit)), remove: remove),
  );

  /// What PVE makes of [schedule] (`GET /cluster/jobs/schedule-analyze`).
  @override
  Future<VirtScheduleCheck> checkSchedule(String schedule) async =>
      VirtRust.scheduleCheck(jsonDecode(await _rust((s) => s.checkSchedule(schedule: schedule))));

  /// `vzdump` for the one guest, waited for.
  @override
  Future<void> backup(VirtGuest guest, VirtBackupRequest request) => _rust(
    (s) => s.backup(guest: _ref(guest), requestJson: jsonEncode(VirtRust.backupRequestJson(request))),
  );

  /// A job's "Run now", on its node or every online one.
  @override
  Future<void> runBackupJob(VirtBackupJob job) => _rust((s) => s.runBackupJob(id: job.id));

  /// Over the guest itself (stopped) or as a new guest [vmid]; [storage]
  /// is where the restored disks land.
  @override
  Future<void> restoreBackup(
    VirtGuest guest,
    VirtBackup backup, {
    int? vmid,
    String? storage,
  }) => _rust(
    (s) => s.restoreBackup(guest: _ref(guest), backupId: backup.id, vmid: vmid, storage: storage),
  );

  /// A backup's own notes and protection.
  @override
  Future<void> editBackup(VirtBackup backup, VirtBackupEdit edit) => _rust(
    (s) => s.editBackup(
      backupJson: jsonEncode(VirtRust.backupJson(backup)),
      editJson: jsonEncode(VirtRust.backupEditJson(edit)),
    ),
  );

  @override
  Future<void> deleteBackup(VirtGuest guest, VirtBackup backup) =>
      _rust((s) => s.deleteBackup(backupJson: jsonEncode(VirtRust.backupJson(backup))));

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

  // ---------------------------------------------------------------------------
  // Storage and networks
  // ---------------------------------------------------------------------------

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
      final resp = await dio.post<Object?>(
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
        );
      final body = resp.data;
      final upid = body is Map ? body['data'] : null;
      // The file is moved into place by that task: without it, nothing says
      // the upload is there.
      if (upid is! String || !upid.startsWith('UPID:')) {
        throw VirtErr(
          type: VirtErrType.invalidResponse,
          message: 'No task for the upload: ${jsonEncode(body)}',
        );
      }
      await _waitTask(pool.node!, upid);
      return true;
    } on DioException catch (e) {
      if (cancelled) return false;
      final status = e.response?.statusCode;
      final message = _pveMessage(e);
      // PVE's refusal said as a change's is (`sbm_virt`): a name taken, a
      // missing privilege and the command that grants it.
      if (status != null && message != null && status != 401) {
        throw _fromRust(
          await _rust((s) async => s.refusal(message: message, status: status)),
        );
      }
      throw _toErr(e);
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
    // The address changed while the tunnel opened: it reaches the old host,
    // which the new configuration's credentials must never be sent to.
    if ('$_base' != '$base') {
      await tunnel.close();
      return _open();
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
  }

  /// A failure of the session as this app phrases it ([VirtRust.error]);
  /// the certificate it presented is what [confirmCert] may pin.
  VirtErr _fromRust(PveError e) {
    final cert = e.cert;
    if (cert != null) _presented = cert;
    return VirtRust.error(e);
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
