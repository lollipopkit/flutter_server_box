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
import 'package:server_box/core/utils/version.dart';
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
    DateTime Function()? now,
  }) : _config = config,
       _openTunnel = tunnel,
       _connect = connect,
       _onCertConfirmed = onCertConfirmed,
       _onClose = onClose,
       _exec = exec,
       _now = now ?? DateTime.now;

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
  final DateTime Function() _now;

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
    _guests = snap.guests;
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
    final kind = switch (action) {
      VirtPowerAction.start => VirtActionKind.start,
      VirtPowerAction.shutdown => VirtActionKind.shutdown,
      VirtPowerAction.reboot => VirtActionKind.reboot,
      VirtPowerAction.forceStop => VirtActionKind.forceStop,
      VirtPowerAction.suspend => VirtActionKind.suspend,
      VirtPowerAction.resume => VirtActionKind.resume,
    };
    await _rust((s) => s.power(guestId: guest.id, action: kind));
  }

  @override
  Future<VirtGuestDetail> detail(VirtGuest guest) async {
    final data = await _call(
      (dio) => dio.get(_url('${_guestPath(guest)}/config')),
    );
    if (data is! Map) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    return PveResources.parseConfig(data.cast<String, Object?>(), guest.kind);
  }

  @override
  Future<PveConsole> console(VirtGuest guest, VirtConsoleKind kind) async {
    final path = _guestPath(guest);
    final vnc = kind == VirtConsoleKind.vnc;
    if (vnc && guest.kind == VirtGuestKind.lxc) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: 'Containers have a text console only',
      );
    }
    final serial = !vnc && guest.kind == VirtGuestKind.qemu
        ? await _serialDevice(guest)
        : null;
    Future<Object?> request({required bool generatePassword}) => _call(
      (dio) => dio.post(
        _url('$path/${vnc ? 'vncproxy' : 'termproxy'}'),
        data: {
          if (vnc) 'websocket': 1,
          // A VNC password of its own rather than the ticket: QEMU checks
          // only the first 8 bytes of one, and a bare ticket's first 8 are
          // `PVEVNC:` and one more character. PVE 9.2 generates one for any
          // `websocket=1` request anyway and answers it as `password`, with
          // the ticket as `<password>:PVEVNC:...` (verified,
          // test/e2e/virt_real_test.dart); the flag stays for versions that
          // do not (since which release is not checked).
          if (vnc && generatePassword) 'generate-password': 1,
          'serial': ?serial,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
      action: true,
    );
    Object? data;
    try {
      data = await request(generatePassword: vnc);
    } on VirtErr catch (e) {
      // `generate-password` is PVE 7.2 and later; an older API refuses the
      // parameter by name.
      if (!vnc || !_refusedParam(e, 'generate-password')) rethrow;
      data = await request(generatePassword: false);
    }
    if (data is! Map) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    final port = int.tryParse('${data['port']}');
    final ticket = data['ticket'];
    if (port == null || ticket is! String || ticket.isEmpty) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    final user = '${data['user'] ?? ''}';
    if (vnc) {
      final password = data['password'];
      return PveVncConsole(
        node: guest.node!,
        guestKind: guest.kind,
        vmid: guest.vmid!,
        port: port,
        ticket: ticket,
        user: user,
        password: password is String && password.isNotEmpty
            ? password
            : ticket,
      );
    }
    return PveTermConsole(
      node: guest.node!,
      guestKind: guest.kind,
      vmid: guest.vmid!,
      port: port,
      ticket: ticket,
      user: user,
    );
  }

  /// The first serial port in a QEMU guest's configuration — what
  /// `termproxy` attaches to — or `serial0` when it names none.
  Future<String> _serialDevice(VirtGuest guest) async {
    final data = await _call(
      (dio) => dio.get(_url('${_guestPath(guest)}/config')),
    );
    final ports = data is Map
        ? (data.keys
              .whereType<String>()
              .where(_serialKey.hasMatch)
              .toList()
            ..sort())
        : const <String>[];
    return ports.firstOrNull ?? 'serial0';
  }

  /// Whether [e] is PVE's parameter check refusing [name]: a 400 whose
  /// `errors` names it.
  static bool _refusedParam(VirtErr e, String name) {
    final cause = e.cause;
    if (cause is! DioException || cause.response?.statusCode != 400) {
      return false;
    }
    final data = cause.response?.data;
    final errors = data is Map ? data['errors'] : null;
    return (errors is Map && errors.containsKey(name)) ||
        (e.message?.contains(name) ?? false);
  }

  /// termproxy accepts `serial0` to `serial3`.
  static final _serialKey = RegExp(r'^serial[0-3]$');

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
  }) async {
    final data = await _call(
      (dio) => dio.get(
        _url('${_guestPath(guest)}/rrddata'),
        queryParameters: {'timeframe': window.pveTimeframe, 'cf': 'AVERAGE'},
      ),
    );
    if (data is! List) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    return PveResources.parseRrd(data);
  }

  // ---------------------------------------------------------------------------
  // Snapshots
  // ---------------------------------------------------------------------------

  /// The nodes and guests of the last [load]: which nodes to list storage and
  /// networks for, and whose NICs say which guest is on which bridge.
  List<VirtNode> _nodes = const [];
  List<VirtGuest> _guests = const [];

  @override
  Future<List<VirtGuestSnapshot>> snapshots(VirtGuest guest) async {
    final data = await _call(
      (dio) => dio.get(_url('${_guestPath(guest)}/snapshot')),
    );
    if (data is! List) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    return PveResources.parseSnapshots(data);
  }

  /// PVE snapshots whole volumes: a disk on an `lvmthin`, `zfspool` or `rbd`
  /// storage is one, a raw file on a `dir` storage is not. `/storage` and a
  /// node's storage list say what each storage holds, not whether it
  /// snapshots, so the question is asked of the guest itself — the same
  /// `feature?feature=snapshot` its own web UI asks before it offers the
  /// button (`PVE::QemuConfig::has_feature` over each volume).
  ///
  /// A guest whose disks are on **mixed** storages answers false when any one
  /// of them cannot be snapshotted, and PVE then refuses the task with
  /// "snapshot feature is not available" (verified on PVE 9.2.2 with a raw
  /// disk on a `dir` storage beside a thin one).
  @override
  Future<bool?> snapshotSupported(VirtGuest guest) async {
    try {
      final data = await _call(
        (dio) => dio.get(
          _url('${_guestPath(guest)}/feature'),
          queryParameters: {'feature': 'snapshot'},
        ),
      );
      return data is Map ? data['hasFeature'] == 1 : null;
    } on VirtErr catch (e) {
      // An older PVE, or a guest deleted since the last load: unknown
      // rather than "no".
      Loggers.app.info('PVE snapshot feature of ${guest.vmid}: ${e.message}');
      return null;
    }
  }

  /// The storages the guest's disks are on, by name, for the view to name
  /// when it says why a snapshot is refused.
  @override
  Future<String?> snapshotRefusal(VirtGuest guest) async {
    final supported = await snapshotSupported(guest);
    if (supported != false) return null;
    final storages = await _guestStorages(guest);
    return storages.isEmpty
        ? 'snapshot feature is not available'
        : 'snapshot feature is not available: ${storages.join(', ')}';
  }

  /// The ids of the storages this guest's own volumes are on, from its
  /// configuration (`scsi0: local-lvm:vm-900-disk-0`).
  Future<List<String>> _guestStorages(VirtGuest guest) async {
    try {
      final data = await _call((dio) => dio.get(_url('${_guestPath(guest)}/config')));
      if (data is! Map) return const [];
      // The disks a snapshot takes: not a CD-ROM, not an unused volume, and
      // named `<storage>:<volume>` rather than by a host path.
      final out = <String>{
        for (final d in PveResources.parseConfig(
          data.cast<String, Object?>(),
          guest.kind,
        ).disks)
          if (d.device != 'cdrom' && !(d.target?.startsWith('unused') ?? false))
            if (d.source case final src?
                when !src.startsWith('/') && src.indexOf(':') > 0)
              src.substring(0, src.indexOf(':')),
      };
      return out.toList()..sort();
    } on VirtErr catch (e) {
      Loggers.app.info('PVE config of ${guest.vmid}: ${e.message}');
      return const [];
    }
  }

  /// The snapshot's own `config` against the guest's current one.
  ///
  /// PVE answers the snapshot's configuration whole (`GET .../snapshot/
  /// {name}/config`), which is the guest's configuration as it was; the
  /// guest's own is `GET config`, with the pending changes already applied
  /// (that is what a rollback would produce). Keys that are the listing's own
  /// (`digest`, `snapname`, `snaptime`, `parent`, `description`) are left out,
  /// as are the ones that are not a setting anyone makes (`meta`, `smbios1`,
  /// `vmgenid`): none of them differs for a reason the view could act on.
  @override
  Future<List<VirtSnapDiff>> snapshotDiff(VirtGuest guest, String name) async {
    final path = _guestPath(guest);
    final snap = await _call(
      (dio) => dio.get(_url('$path/snapshot/${_seg(name)}/config')),
    );
    final current = await _call((dio) => dio.get(_url('$path/config')));
    if (snap is! Map || current is! Map) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    final before = snap.cast<String, Object?>();
    final after = current.cast<String, Object?>();
    final keys = {...before.keys, ...after.keys}.difference(_diffIgnore);
    final out = <VirtSnapDiff>[];
    for (final key in keys) {
      final b = _diffValue(before[key]);
      final a = _diffValue(after[key]);
      if (b == a) continue;
      out.add(
        VirtSnapDiff(
          group: VirtSnapDiffGroup.of(key),
          key: key,
          before: b,
          after: a,
        ),
      );
    }
    out.sort((x, y) => x.key.compareTo(y.key));
    return out;
  }

  /// Keys a diff never shows: the listing's own bookkeeping, and what PVE
  /// writes by itself.
  static const _diffIgnore = {
    'digest',
    'snapname',
    'snaptime',
    'parent',
    'description',
    'meta',
    'smbios1',
    'vmgenid',
    'lock',
    'pending',
  };

  /// A configuration value as one line. A password is never read back (PVE
  /// answers `**********`), and `delete: 1` entries are the removal of a key
  /// rather than a value.
  static String? _diffValue(Object? v) {
    if (v == null) return null;
    if (v is Map) {
      if (v['delete'] == 1) return null;
      if (v['pending'] != null) return v['pending'].toString();
      return null;
    }
    final text = v.toString();
    return text.isEmpty ? null : text;
  }

  /// PVE has no external form: a snapshot is a volume-level one taken by the
  /// storage, and a running VM's memory is `vmstate`.
  @override
  Future<VirtSnapChain> snapshotChain(VirtGuest guest) async =>
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: 'PVE snapshots are per volume; there is no chain to show',
      );

  /// `vmstate` only for a VM: a container's snapshot never has memory, and
  /// PVE refuses the parameter for one.
  @override
  Future<void> createSnapshot(
    VirtGuest guest, {
    required String name,
    String? description,
    bool memory = false,
    VirtSnapshotForm form = VirtSnapshotForm.internal,
    String? overlayPool,
  }) async {
    if (!virtSnapshotNamePattern.hasMatch(name)) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: 'Not a snapshot name: $name',
      );
    }
    // Refused before the task is started, with what the host says about the
    // guest's storages, rather than after it fails.
    if (await snapshotRefusal(guest) case final why?) {
      throw VirtErr(type: VirtErrType.unsupported, message: why);
    }
    final desc = description?.trim();
    await _task(
      guest,
      (dio) => dio.post(
        _url('${_guestPath(guest)}/snapshot'),
        data: {
          'snapname': name,
          if (desc != null && desc.isNotEmpty) 'description': desc,
          if (memory && guest.kind == VirtGuestKind.qemu) 'vmstate': 1,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
  }

  /// `rollback`, with `start=1` for [start]. A snapshot without memory stops
  /// a running guest; PVE starts it again afterwards when asked (verified on
  /// PVE 9.2 for a VM and a container).
  ///
  /// That start is a task of its own (`qmstart` / `vzstart`), begun as the
  /// rollback's ends, and it holds the guest's lock until it is done: on
  /// PVE 9.2 a container's took 45 s, and a snapshot deleted meanwhile failed
  /// with "Failed to obtain guest migration lock". So with [start] this
  /// returns once that task has finished too, and the guest is not offered
  /// anything before.
  @override
  Future<void> revertSnapshot(
    VirtGuest guest,
    String name, {
    bool start = false,
  }) async {
    final path = _guestPath(guest);
    await _task(
      guest,
      (dio) => dio.post(
        _url('$path/snapshot/${_seg(name)}/rollback'),
        data: {if (start) 'start': 1},
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
    if (start) await _waitStartTask(guest);
    await _rust((s) => s.refreshStatus(guestId: guest.id));
  }

  /// How long [_waitStartTask] looks for the start task to appear.
  static const _startTaskAppears = Duration(seconds: 5);

  /// Waits for the guest's running start task, if one appears within
  /// [_startTaskAppears]. Its failure is the action's.
  Future<void> _waitStartTask(VirtGuest guest) async {
    final node = guest.node!;
    final deadline = _now().add(_startTaskAppears);
    while (true) {
      final data = await _call(
        (dio) => dio.get(
          _url('/nodes/${_seg(node)}/tasks'),
          queryParameters: {'vmid': guest.vmid, 'source': 'active'},
        ),
        action: true,
      );
      final upid = data is List
          ? data
                .whereType<Map>()
                .where((t) => t['type'] == 'qmstart' || t['type'] == 'vzstart')
                .map((t) => t['upid'])
                .whereType<String>()
                .firstOrNull
          : null;
      if (upid != null) {
        await _waitTask(node, upid);
        return;
      }
      if (_now().isAfter(deadline)) return;
      await Future<void>.delayed(taskPoll);
    }
  }

  @override
  Future<void> deleteSnapshot(VirtGuest guest, String name) => _task(
    guest,
    (dio) => dio.delete(_url('${_guestPath(guest)}/snapshot/${_seg(name)}')),
  );

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
  Future<int?> nextVmid() async {
    final data = await _call((dio) => dio.get(_url('/cluster/nextid')));
    return switch (data) {
      final int id => id,
      final String id => int.tryParse(id),
      _ => null,
    };
  }

  /// The first release with the `import` content type, where a cloud image
  /// is kept for `import-from`.
  static const importContentSince = [8, 2];

  /// PVE's fixed set: OVMF and swtpm ship with it, cloud-init is its own
  /// drive. Cloud images wait for a release with `import` content (an
  /// unknown release is given the benefit of the doubt: its storages say
  /// whether they hold any).
  @override
  Future<VirtCreateOptions> createOptions() async {
    final release = _session?.release();
    return VirtCreateOptions(
      buses: virtPveCreateBuses,
      nicModels: virtCreateNicModels,
      uefi: true,
      // Every 4m EFI disk runs PVE's `OVMF_CODE_4M.secboot.fd`; what turns
      // Secure Boot on is the variables template with the keys enrolled
      // (`pre-enrolled-keys=1`, `PVE::QemuServer::OVMF`, 9.2.2).
      secureBoot: true,
      tpm: true,
      cloudImages:
          release == null || !isVersionLessThan(release, importContentSince),
      cloudInit: true,
    );
  }

  /// `POST /nodes/{node}/qemu` or `/lxc`, waited for; then `start` as a
  /// request of its own rather than the create's `start=1`, so a guest that
  /// was created and did not start is told apart from one that was not
  /// created.
  ///
  /// A VM gets a serial port (`serial0: socket`), so its text console works
  /// before it has a network, and the install media first in the boot order
  /// after its disk. A cloud image is its disk's `import-from` (PVE 8.2+
  /// takes one from `import` or `images` content), grown afterwards to the
  /// size asked for, with PVE's own cloud-init drive; the password goes in
  /// the request body and PVE stores its hash. A container is unprivileged
  /// unless asked otherwise, with DHCP on its NIC.
  @override
  Future<VirtCreated> create(VirtCreateSpec spec) async {
    final node = spec.node;
    final vmid = spec.vmid;
    if (node == null || vmid == null) {
      throw const VirtErr(
        type: VirtErrType.unsupported,
        message: 'A PVE guest needs a node and a VMID',
      );
    }
    final lxc = spec.kind == VirtGuestKind.lxc;
    final storage = spec.storage.name;
    final bridge = spec.network?.name;
    final Map<String, Object> body;
    if (lxc) {
      final template = spec.media;
      if (template == null) {
        throw const VirtErr(
          type: VirtErrType.unsupported,
          message: 'A container needs a template',
        );
      }
      final password = spec.password ?? '';
      final keys = (spec.sshKeys ?? '').trim();
      body = {
        'vmid': vmid,
        'hostname': spec.name,
        'ostemplate': template.id,
        'cores': spec.cores,
        'memory': spec.memoryMiB,
        'rootfs': '$storage:${spec.diskGiB}',
        'unprivileged': spec.unprivileged ? 1 : 0,
        'net0': ?bridge == null ? null : 'name=eth0,bridge=$bridge,ip=dhcp',
        'password': ?password.isEmpty ? null : password,
        'ssh-public-keys': ?keys.isEmpty ? null : keys,
      };
    } else {
      body = qemuCreateBody(spec, vmid: vmid);
    }
    final kind = lxc ? 'lxc' : 'qemu';
    try {
      final upid = await _call(
        (dio) => dio.post(
          _url('/nodes/${_seg(node)}/$kind'),
          data: body,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        ),
        action: true,
      );
      if (upid is String && upid.startsWith('UPID:')) {
        await _waitTask(node, upid);
      }
    } on VirtErr catch (e) {
      throw _createErr(e);
    }
    final id = '$kind/$vmid';
    String? startError;
    int? kept;
    if (!lxc && spec.image != null) {
      // Imported at the image's own size, which the configuration says
      // (`size=`). Grown now, before a first boot lays its filesystem out —
      // and only grown: a request below the image keeps the image's size,
      // as PVE cannot shrink a disk and cutting one would cut its system.
      final want = spec.diskGiB * (1 << 30);
      final disk = '${_createBus(spec)}0';
      int? size;
      try {
        final config = await _configOf('/nodes/${_seg(node)}/qemu/$vmid');
        if (config[disk] case final String raw) {
          size = PveResources.optionSize(raw);
        }
      } on VirtErr catch (e) {
        Loggers.app.info('PVE config of $vmid after import: ${e.message}');
      }
      if (size != null && size > want) kept = size;
      if (size == null || size < want) {
        try {
          final upid = await _call(
            (dio) => dio.put(
              _url('/nodes/${_seg(node)}/qemu/$vmid/resize'),
              data: {'disk': disk, 'size': '${spec.diskGiB}G'},
              options: Options(contentType: Headers.formUrlEncodedContentType),
            ),
            action: true,
          );
          if (upid is String && upid.startsWith('UPID:')) {
            await _waitTask(node, upid);
          }
        } on VirtErr catch (e) {
          // Created all the same; not started on a disk of the wrong size.
          return VirtCreated(id: id, startError: e.message ?? e.type.name);
        }
      }
    }
    if (spec.start) {
      try {
        final upid = await _call(
          (dio) => dio.post(_url('/nodes/${_seg(node)}/$kind/$vmid/status/start')),
          action: true,
        );
        if (upid is String && upid.startsWith('UPID:')) {
          await _waitTask(node, upid);
        }
      } on VirtErr catch (e) {
        startError = e.message ?? e.type.name;
      }
    }
    return VirtCreated(id: id, startError: startError, diskKeptBytes: kept);
  }

  static String _createBus(VirtCreateSpec spec) => spec.bus ?? 'scsi';

  /// A VM's `POST /nodes/{node}/qemu` parameters for [spec].
  @visibleForTesting
  static Map<String, Object> qemuCreateBody(VirtCreateSpec spec, {required int vmid}) {
    final storage = spec.storage.name;
    final bridge = spec.network?.name;
    final bus = _createBus(spec);
    final disk = '${bus}0';
    final iso = spec.media?.id;
    final image = spec.image?.id;
    final ci = spec.cloudInit;
    // An I/O thread is for virtio-blk and virtio-scsi-single only; PVE
    // refuses it on SATA and IDE.
    final iothread = bus == 'scsi' || bus == 'virtio' ? ',iothread=1' : '';
    final address = ci?.address;
    // The cloud-init drive where the image's kernel can read it: Debian's
    // cloud kernel has no IDE driver at all (PVE 9.2: cloud-init never ran
    // from `ide2`, and did from `scsi1`). SCSI beside a SCSI or virtio disk
    // (the virtio-scsi controller is there anyway), SATA beside SATA, IDE
    // only beside IDE.
    final ciDrive = switch (bus) {
      'ide' => 'ide2',
      'sata' => 'sata1',
      _ => 'scsi1',
    };
    return {
      'vmid': vmid,
      'name': spec.name,
      'cores': spec.cores,
      'memory': spec.memoryMiB,
      'ostype': 'l26',
      'scsihw': 'virtio-scsi-single',
      disk: image == null
          ? '$storage:${spec.diskGiB}$iothread'
          : '$storage:0,import-from=$image$iothread',
      // The install media, or the cloud-init drive: never both.
      if (iso != null) 'ide2': '$iso,media=cdrom',
      if (ci != null && iso == null) ciDrive: '$storage:cloudinit',
      'net0': ?bridge == null ? null : '${spec.nicModel ?? 'virtio'},bridge=$bridge',
      'serial0': 'socket',
      'boot': 'order=${[disk, if (iso != null) 'ide2'].join(';')}',
      if (spec.uefi) ...{
        'bios': 'ovmf',
        // Keys are enrolled when the EFI disk is made: Secure Boot is the
        // disk with `pre-enrolled-keys=1`, which is what PVE's own UEFI
        // default writes.
        'efidisk0':
            '$storage:1,efitype=4m,pre-enrolled-keys=${spec.secureBoot ? 1 : 0}',
      },
      if (spec.tpm) 'tpmstate0': '$storage:1,version=v2.0',
      if (ci != null) ...{
        'ciuser': ci.user,
        if (ci.password case final p? when p.isNotEmpty) 'cipassword': p,
        // PVE wants the keys URL-encoded, as its web UI sends them
        // (`encodeURIComponent`), inside the form's own encoding.
        if (ci.keys.isNotEmpty) 'sshkeys': Uri.encodeComponent('${ci.keys.join('\n')}\n'),
        'ipconfig0': address == null
            ? 'ip=dhcp'
            : ['ip=$address', if (ci.gateway case final gw?) 'gw=$gw'].join(','),
        if (ci.dns.isNotEmpty) 'nameserver': ci.dns.join(' '),
        'searchdomain': ?(ci.searchDomains.isEmpty ? null : ci.searchDomains.join(' ')),
      },
    };
  }

  /// A refused create, in the host's words: PVE answers a bad parameter with
  /// 400 and a taken VMID with 500, before any task.
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

  /// `DELETE` with `purge=1` (out of backup jobs, replication and HA) and
  /// `destroy-unreferenced-disks=1` (volumes of its VMID no configuration
  /// names). PVE deletes a guest's own disks whatever is asked:
  /// [removeDisks] cannot keep them here.
  @override
  Future<void> delete(VirtGuest guest, {bool removeDisks = true}) async {
    if (guest.state != VirtGuestState.stopped) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} is not stopped',
      );
    }
    await _task(
      guest,
      (dio) => dio.delete(
        _url(_guestPath(guest)),
        queryParameters: {'purge': 1, 'destroy-unreferenced-disks': 1},
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Templates, cloning and backups
  // ---------------------------------------------------------------------------

  /// `POST .../template` on the guest's node, waited for (`VM.Allocate` on
  /// `/vms/{vmid}`, checked by PVE before the task). A guest with snapshots
  /// cannot become one, and a template cannot become a guest again: PVE
  /// writes `template: 1` and turns every disk into a base image
  /// (`vdisk_create_base`: `vm-910-disk-0` → `base-910-disk-0` on LVM-thin),
  /// which is what a linked clone then shares.
  @override
  Future<void> makeTemplate(VirtGuest guest) async {
    if (guest.template) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} is already a template',
      );
    }
    if (guest.state != VirtGuestState.stopped) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${guest.name} is not stopped',
      );
    }
    await _task(
      guest,
      (dio) => dio.post(
        _url('${_guestPath(guest)}/template'),
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
    );
  }

  /// `POST .../clone` on the guest's node, waited for. A full clone copies
  /// the disks to the storages they are on, or to [VirtCloneRequest.storage]
  /// where one was picked; a linked one (a template only — PVE refuses it for
  /// anything else) shares them.
  ///
  /// A clone that moves to another node needs a cluster and shared storage:
  /// on a single node PVE answers `no such cluster node '<name>'` — or, once
  /// the node exists, `can't clone VM to node '<n>' (VM uses local storage)`.
  /// [`virtCloneTargetIssue`] refuses both before the request is sent.
  @override
  Future<String> clone(VirtGuest guest, VirtCloneRequest request) async {
    final lxc = guest.kind == VirtGuestKind.lxc;
    final vmid = request.vmid ?? await nextVmid();
    if (vmid == null) {
      throw const VirtErr(
        type: VirtErrType.invalidResponse,
        message: 'No VMID for the clone',
      );
    }
    final full = request.full || !guest.template;
    try {
      await _task(
        guest,
        (dio) => dio.post(
          _url('${_guestPath(guest)}/clone'),
          data: {
            'newid': vmid,
            lxc ? 'hostname' : 'name': request.name,
            'full': full ? 1 : 0,
            // PVE refuses either on a linked clone: `parameter 'storage' not
            // allowed for linked clones`.
            'storage': ?full ? request.storage : null,
            'target': ?request.targetNode,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        ),
      );
    } on VirtErr catch (e) {
      throw _createErr(e);
    }
    return '${lxc ? 'lxc' : 'qemu'}/$vmid';
  }

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

  /// `GET .../config` (pending changes applied, and the `digest` an edit is
  /// sent back with) and `GET .../pending`, with the node's CPUs, memory
  /// and — for a VM — the CPU models it offers. The node's parts are extras:
  /// a token without `Sys.Audit` on the node still edits the guest.
  @override
  Future<VirtHardware> hardware(VirtGuest guest) async {
    final path = _guestPath(guest);
    final node = guest.node!;
    Future<Object?> extra(String url) async {
      try {
        return await _call((dio) => dio.get(_url(url)));
      } on VirtErr catch (e) {
        Loggers.app.info('PVE $url for the hardware view: ${e.message}');
        return null;
      }
    }

    final (config, pending, status, cpus) = await (
      _call((dio) => dio.get(_url('$path/config'))),
      _call((dio) => dio.get(_url('$path/pending'))),
      extra('/nodes/${_seg(node)}/status'),
      guest.kind == VirtGuestKind.qemu
          ? extra('/nodes/${_seg(node)}/capabilities/qemu/cpu')
          : Future<Object?>.value(),
    ).wait;
    if (config is! Map || pending is! List) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    final cpuinfo = status is Map ? status['cpuinfo'] : null;
    final memory = status is Map ? status['memory'] : null;
    return PveResources.parseHardware(
      config: config.cast<String, Object?>(),
      pending: pending,
      kind: guest.kind,
      running: guest.state.isActive,
      limits: VirtHwLimits(
        hostCpus: cpuinfo is Map ? _intOf(cpuinfo['cpus']) : null,
        hostMemoryBytes: memory is Map ? _intOf(memory['total']) : null,
      ),
      cpuTypes: [
        if (cpus is List)
          for (final c in cpus)
            if (c is Map && c['name'] is String) c['name'] as String,
      ]..sort(),
    );
  }

  static int? _intOf(Object? v) => switch (v) {
    final num n => n.toInt(),
    final String s => int.tryParse(s),
    _ => null,
  };

  /// Every change is `.../config` with the `digest` [base] was read with, so
  /// PVE refuses one made from a configuration someone has changed since
  /// ("checksum mismatch"), except a disk's growth, which is `.../resize`
  /// with the same digest. A VM's configuration is set with `POST` (a task,
  /// since adding a disk allocates it), a container's with `PUT`.
  ///
  /// What the running guest cannot take is PVE's to put in `pending`: this
  /// returns once the request has, and [hardware] shows it.
  @override
  Future<VirtHwOutcome> changeHardware(
    VirtGuest guest,
    VirtHardware base,
    VirtHwChange change,
  ) async {
    final path = _guestPath(guest);
    final lxc = guest.kind == VirtGuestKind.lxc;
    final digest = base.revision;
    // The options as PVE writes them, for the changes that keep most of an
    // option and set a part of it.
    Map<String, Object?>? raw;
    Future<Map<String, Object?>> rawConfig() async =>
        raw ??= await _configOf(path);
    String? rawOf(Map<String, Object?> config, String key) =>
        config[key] is String ? config[key] as String : null;

    try {
      switch (change) {
        case VirtHwSetCpu(:final sockets, :final cores, :final online, :final type):
          if (lxc) {
            await _setConfig(guest, {'cores': cores}, digest: digest);
          } else {
            final cpu = type == null || type == base.cpu.type
                ? null
                : PveResources.withCpuType(rawOf(await rawConfig(), 'cpu'), type);
            await _setConfig(
              guest,
              {
                'sockets': sockets,
                'cores': cores,
                'vcpus': ?online,
                'cpu': ?cpu,
              },
              delete: [if (online == null && base.cpu.online != null) 'vcpus'],
              digest: digest,
            );
          }
        case VirtHwSetMemory(:final mib, :final minMib, :final swapMib):
          await _setConfig(
            guest,
            {
              'memory': mib,
              if (!lxc) 'balloon': ?minMib,
              if (lxc) 'swap': ?swapMib,
            },
            delete: [if (!lxc && minMib == null && base.memory.minMib != null) 'balloon'],
            digest: digest,
          );
        case VirtHwGrowDisk(:final key, :final bytes):
          await _task(
            guest,
            (dio) => dio.put(
              _url('$path/resize'),
              data: {
                'disk': key,
                'size': PveResources.sizeArg(bytes),
                'digest': ?digest,
              },
              options: Options(contentType: Headers.formUrlEncodedContentType),
            ),
          );
        case VirtHwAddDisk(:final storage, :final gib, :final mountPoint):
          final config = await rawConfig();
          final String key;
          final String value;
          if (lxc) {
            key = _freeKey(config, 'mp', 256);
            value = '${storage.name}:$gib,mp=$mountPoint';
          } else {
            // On the bus the guest's first disk is on: the controller it
            // already has, and the drivers its OS already loads.
            final bus = base.disks
                    .where((d) => d.kind == VirtHwDiskKind.disk)
                    .firstOrNull
                    ?.bus ??
                'scsi';
            key = _freeKey(config, bus, _busSlots[bus] ?? 1);
            value = '${storage.name}:$gib';
          }
          await _setConfig(guest, {key: value}, digest: digest);
        case VirtHwAttachVolume(:final volume, :final mountPoint):
          final config = await rawConfig();
          final String key;
          final String value;
          if (lxc) {
            key = _freeKey(config, 'mp', 256);
            value = '${volume.id},mp=$mountPoint';
          } else {
            final bus = base.disks
                    .where((d) => d.kind == VirtHwDiskKind.disk)
                    .firstOrNull
                    ?.bus ??
                'scsi';
            key = _freeKey(config, bus, _busSlots[bus] ?? 1);
            value = volume.id;
          }
          await _setConfig(guest, {key: value}, digest: digest);
        case VirtHwRemoveDisk(:final key, :final deleteVolume):
          if (!deleteVolume) {
            await _setConfig(guest, const {}, delete: [key], digest: digest);
            break;
          }
          if (await _dropVolume(guest, key, digest: digest)) {
            return const VirtHwOutcome(volumeKept: true);
          }
        case VirtHwAddCdrom(:final media):
          // IDE's secondary master first, as PVE's own create puts one;
          // then the rest of IDE, then SATA.
          final config = await rawConfig();
          final key = [
            'ide2', 'ide0', 'ide1', 'ide3',
            for (var i = 0; i < 6; i++) 'sata$i',
          ].firstWhere(
            (k) => !config.containsKey(k),
            orElse: () => throw const VirtErr(
              type: VirtErrType.unsupported,
              message: 'No free IDE or SATA slot for a CD-ROM',
            ),
          );
          await _setConfig(guest, {
            key: '${media?.id ?? 'none'},media=cdrom',
          }, digest: digest);
        case VirtHwSetMedia(:final key, :final media):
          await _setConfig(guest, {
            key: '${media?.id ?? 'none'},media=cdrom',
          }, digest: digest);
        case VirtHwAddNic(:final network, :final model):
          final config = await rawConfig();
          final key = _freeKey(config, 'net', 32);
          final String value;
          if (lxc) {
            final names = {
              for (final n in base.nics)
                if (n.name != null) n.name,
            };
            var i = 0;
            while (names.contains('eth$i')) {
              i++;
            }
            value = 'name=eth$i,bridge=${network.name},ip=dhcp';
          } else {
            value = '${model ?? 'virtio'},bridge=${network.name}';
          }
          await _setConfig(guest, {key: value}, digest: digest);
        case VirtHwRemoveNic(:final key):
          await _setConfig(guest, const {}, delete: [key], digest: digest);
        case VirtHwUpdateNic(
          :final key,
          :final network,
          :final linkUp,
          :final firewall,
        ):
          final current = rawOf(await rawConfig(), key);
          if (current == null) {
            throw VirtErr(type: VirtErrType.conflict, message: '$key is gone');
          }
          await _setConfig(guest, {
            key: PveResources.withOptions(current, {
              'bridge': ?network?.name,
              'link_down': linkUp ? null : '1',
              if (firewall != null) 'firewall': firewall ? '1' : null,
            }),
          }, digest: digest);
        case VirtHwSetBoot(:final order):
          await _setConfig(guest, {
            'boot': 'order=${order.join(';')}',
          }, digest: digest);
        case VirtHwSetAutostart(:final on):
          await _setConfig(guest, {'onboot': on ? 1 : 0}, digest: digest);
        case VirtHwSetName(:final name):
          await _setConfig(guest, {
            lxc ? 'hostname' : 'name': name,
          }, digest: digest);
        case VirtHwSetDescription(:final text):
          await _setConfig(
            guest,
            {if (text.isNotEmpty) 'description': text},
            delete: [if (text.isEmpty) 'description'],
            digest: digest,
          );
        case VirtHwSetProtection(:final on):
          await _setConfig(guest, {'protection': on ? 1 : 0}, digest: digest);
        case VirtHwRevert(:final keys):
          await _setConfig(guest, {'revert': keys.join(',')}, digest: digest);
        case VirtHwUpdateDisk(:final key, :final bus, :final cache):
          final config = await rawConfig();
          final current = rawOf(config, key);
          if (current == null) {
            throw VirtErr(type: VirtErrType.conflict, message: '$key is gone');
          }
          final value = cache == null
              ? current
              : PveResources.withOptions(current, {
                  'cache': cache == 'default' ? null : cache,
                });
          if (bus == null || key.startsWith(bus)) {
            await _setConfig(guest, {key: value}, digest: digest);
            break;
          }
          // Another bus is another option for the same volume, set in the
          // request that drops the old one, less what that bus does not take
          // (`iothread` on SATA). PVE drops the old one from the boot order
          // too; it is put back as the new one, in its place.
          final to = _freeKey(config, bus, _busSlots[bus] ?? 1);
          final order = base.boot;
          await _setConfig(
            guest,
            {
              to: PveResources.onBus(value, bus),
              if (order != null && order.contains(key))
                'boot': 'order=${[for (final k in order) k == key ? to : k].join(';')}',
            },
            delete: [key],
            digest: digest,
          );
        case VirtHwSetNicHardware(:final key, :final model, :final mac):
          final current = rawOf(await rawConfig(), key);
          if (current == null) {
            throw VirtErr(type: VirtErrType.conflict, message: '$key is gone');
          }
          await _setConfig(guest, {
            key: PveResources.withNicHardware(
              current,
              lxc: lxc,
              model: model,
              mac: mac,
            ),
          }, digest: digest);
        case VirtHwSetFirmware(:final uefi, :final secureBoot, :final storage):
          if (!uefi) {
            // The EFI variables disk stays: switching back finds them.
            await _setConfig(guest, {'bios': 'seabios'}, digest: digest);
            break;
          }
          final config = await rawConfig();
          final efi = rawOf(config, 'efidisk0');
          final keys = efi != null &&
              PveResources.withOptions(efi, const {}).contains('pre-enrolled-keys=1');
          if (efi != null && keys == secureBoot) {
            await _setConfig(guest, {'bios': 'ovmf'}, digest: digest);
            break;
          }
          // Keys are enrolled when the variables disk is made: turning
          // Secure Boot on or off is a new one, and the old one goes.
          final on = storage ??
              (efi == null ? null : PveResources.volumeOf(efi)?.split(':').first);
          if (on == null) {
            throw const VirtErr(
              type: VirtErrType.unsupported,
              message: 'No storage for the EFI disk',
            );
          }
          var at = digest;
          if (efi != null) {
            await _dropVolume(guest, 'efidisk0', digest: at);
            at = null;
          }
          await _setConfig(guest, {
            'bios': 'ovmf',
            'efidisk0':
                '$on:1,efitype=4m,pre-enrolled-keys=${secureBoot ? 1 : 0}',
          }, digest: at);
        case VirtHwSetDisplay(:final gpu):
          if (gpu == null) break;
          final vga = rawOf(await rawConfig(), 'vga');
          final memory = vga == null
              ? null
              : {for (final (k, v) in PveResources.optionsOf(vga)) k: v}['memory'];
          await _setConfig(guest, {
            'vga': [gpu, if (memory != null && gpu != 'none') 'memory=$memory'].join(','),
          }, digest: digest);
        case VirtHwAddDevice(:final kind, :final host, :final storage, :final usbNaming):
          final config = await rawConfig();
          switch (kind) {
            case VirtHwDeviceKind.tpm:
              await _setConfig(guest, {
                'tpmstate0': '$storage:1,version=v2.0',
              }, digest: digest);
            case VirtHwDeviceKind.usb:
              // By vendor and product (`host=0bda:b023`: that device wherever
              // it is plugged), or by where it sits — PVE's own form of the
              // address is `bus-port` (`host=1-1.2`), which is what its web
              // UI writes and what its mapping uses (`PVE::Mapping::USB`:
              // `"$busnum-$usbpath"`), so it is built from the port chain
              // rather than the device number. A device the host gave no
              // port for has no such address.
              final String value;
              if (host!.mapping) {
                value = 'mapping=${host.id}';
              } else if (usbNaming == VirtUsbNaming.address) {
                if (host.usbBus == null || host.usbPort == null) {
                  throw const VirtErr(
                    type: VirtErrType.unsupported,
                    message: 'The host gave no port for this USB device',
                  );
                }
                value = 'host=${virtUsbAddress(host, VirtHostKind.pve)}';
              } else {
                value = 'host=${host.id}';
              }
              await _setConfig(guest, {
                _freeKey(config, 'usb', 14): value,
              }, digest: digest);
            case VirtHwDeviceKind.pci:
              final id = host!.id;
              await _setConfig(guest, {
                _freeKey(config, 'hostpci', 16): host.mapping ? 'mapping=$id' : id,
              }, digest: digest);
          }
        case VirtHwRevertPending():
          // PVE drops changes item by item; there is nothing to write back.
          throw const VirtErr(type: VirtErrType.unsupported);
        case VirtHwRemoveDevice(:final key):
          if (key.startsWith('tpmstate')) {
            // The state is the TPM: removing it removes what it held.
            await _dropVolume(guest, key, digest: digest);
          } else {
            await _setConfig(guest, const {}, delete: [key], digest: digest);
          }
      }
    } on VirtErr catch (e) {
      throw _changeErr(e);
    }
    return const VirtHwOutcome();
  }

  /// PVE drops pending changes item by item (`revert`); there is no
  /// "write it all back" — its `pending` list is the authority, and a
  /// config key set again is enough.
  @override
  Future<void> revertPending(VirtGuest guest, VirtHardware base) async {
    final keys = [for (final p in base.pending) p.key];
    if (keys.isEmpty) return;
    await changeHardware(guest, base, VirtHwRevert(keys));
  }

  /// PVE's `ci*` options, from the VM's configuration.
  @override
  Future<VirtCloudInitState> cloudInit(VirtGuest guest) async =>
      PveResources.parseCloudInit(await _configOf(_guestPath(guest)));

  /// The `ci*` options set with [base]'s `digest`, then the cloud-init
  /// drive written again at once (`PUT .../cloudinit`, `VM.Config.Cloudinit`)
  /// — PVE otherwise writes it only when it starts the VM, so a reboot from
  /// inside the system would read the old one. The system takes it at its
  /// next boot: PVE's instance ID is a hash of the user and network data,
  /// so any change here is a new instance to cloud-init.
  ///
  /// The password goes in the request body, and PVE keeps its hash. What
  /// `ipconfig0` holds besides the IPv4 settings (`ip6`) stays.
  @override
  Future<void> setCloudInit(
    VirtGuest guest,
    VirtCloudInitState base,
    VirtCloudInitEdit edit,
  ) async {
    final ci = edit.values;
    final path = _guestPath(guest);
    try {
      final config = await _configOf(path);
      String? rawOf(String key) =>
          config[key] is String ? config[key] as String : null;
      final password = ci.password ?? '';
      final keys = ci.keys;
      final ip = {
        'ip': ci.address ?? 'dhcp',
        'gw': ci.address == null ? null : ci.gateway,
      };
      final ipconfig = switch (rawOf('ipconfig0')) {
        final raw? when raw.isNotEmpty => PveResources.withOptions(raw, ip),
        _ => [for (final e in ip.entries) if (e.value != null) '${e.key}=${e.value}'].join(','),
      };
      final search = ci.searchDomains.join(' ');
      await _setConfig(
        guest,
        {
          'ciuser': ci.user,
          if (password.isNotEmpty) 'cipassword': password,
          // URL-encoded inside the form's own encoding, as at creation.
          if (keys.isNotEmpty) 'sshkeys': Uri.encodeComponent('${keys.join('\n')}\n'),
          if (base.network) 'ipconfig0': ipconfig,
          if (ci.dns.isNotEmpty) 'nameserver': ci.dns.join(' '),
          'searchdomain': ?(search.isEmpty ? null : search),
        },
        delete: [
          if (edit.removePassword && password.isEmpty && rawOf('cipassword') != null)
            'cipassword',
          if (keys.isEmpty && rawOf('sshkeys') != null) 'sshkeys',
          if (ci.dns.isEmpty && rawOf('nameserver') != null) 'nameserver',
          if (search.isEmpty && rawOf('searchdomain') != null) 'searchdomain',
        ],
        digest: base.revision.isEmpty ? null : base.revision,
      );
      await _call(
        (dio) => dio.put(_url('$path/cloudinit')),
        action: true,
      );
    } on VirtErr catch (e) {
      throw _changeErr(e);
    }
  }

  /// Detaches [key] and deletes its volume: detached, it is `unusedN`, and
  /// deleting that entry deletes it. True when the volume was kept: still
  /// attached — a running guest that cannot let go of it until it stops —
  /// it is not `unusedN`, and nothing is deleted.
  ///
  /// The entry is deleted with the digest of the configuration it was found
  /// in: another administrator reattaching the volume in between may reuse
  /// the slot for another volume, which is then refused, not deleted.
  Future<bool> _dropVolume(VirtGuest guest, String key, {String? digest}) async {
    final path = _guestPath(guest);
    final raw = (await _configOf(path))[key];
    final volume = raw is String ? PveResources.volumeOf(raw) : null;
    await _setConfig(guest, const {}, delete: [key], digest: digest);
    if (volume == null || volume == 'none') return false;
    final after = await _configOf(path);
    final unused = after.entries
        .where(
          (e) =>
              e.key.startsWith('unused') &&
              e.value is String &&
              PveResources.volumeOf(e.value! as String) == volume,
        )
        .map((e) => e.key)
        .firstOrNull;
    if (unused == null) return true;
    await _setConfig(
      guest,
      const {},
      delete: [unused],
      digest: after['digest'] as String?,
    );
    return false;
  }

  /// Resource mappings, which any account with `Mapping.Use` can give a
  /// guest, and — for root@pam logged in with its password, the only one
  /// PVE lets set a raw device ("only root can set 'usb0' config for real
  /// devices") — the node's own devices. The PCI list says whether the
  /// node has an IOMMU at all.
  @override
  Future<VirtHostDevices> hostDevices(VirtGuest guest) async {
    final node = _seg(guest.node!);
    Future<List<Map<String, Object?>>> list(String url) async {
      try {
        final data = await _call((dio) => dio.get(_url(url)));
        return [
          if (data is List)
            for (final e in data)
              if (e is Map) e.cast<String, Object?>(),
        ];
      } on VirtErr catch (e) {
        Loggers.app.info('PVE $url for host devices: ${e.message}');
        return const [];
      }
    }

    final root =
        _config.auth == PveAuth.password &&
        (_userFields()['username'] == 'root' ||
            _userFields()['username'] == 'root@pam');
    final (usbMaps, pciMaps, pci, usb) = await (
      list('/cluster/mapping/usb'),
      list('/cluster/mapping/pci'),
      list('/nodes/$node/hardware/pci'),
      root ? list('/nodes/$node/hardware/usb') : Future.value(const <Map<String, Object?>>[]),
    ).wait;
    VirtHostDevice mapped(Map<String, Object?> m) {
      final map = m['map'];
      final here = map is List
          ? map.whereType<String>().firstWhere(
              (e) => e.contains('node=${guest.node}'),
              orElse: () => map.whereType<String>().firstOrNull ?? '',
            )
          : '';
      final opts = {for (final (k, v) in PveResources.optionsOf(here)) k: v};
      return VirtHostDevice(
        id: '${m['id']}',
        label: '${m['id']}',
        detail: [opts['path'], opts['id']].nonNulls.join(' · '),
        mapping: true,
        iommuGroup: int.tryParse(opts['iommugroup'] ?? ''),
      );
    }

    String hex(Object? v) => '$v'.replaceFirst('0x', '');
    final groups = <int, int>{};
    for (final p in pci) {
      final g = _intOf(p['iommugroup']) ?? -1;
      if (g >= 0) groups[g] = (groups[g] ?? 0) + 1;
    }
    return VirtHostDevices(
      mappingsOnly: !root,
      iommu: pci.isEmpty || groups.isNotEmpty,
      usb: [
        for (final m in usbMaps) mapped(m),
        for (final u in usb)
          // Hubs are not devices anyone passes through.
          if (_intOf(u['class']) != 9)
            VirtHostDevice(
              id: '${u['vendid']}:${u['prodid']}',
              label: [u['manufacturer'], u['product']].nonNulls.join(' ').trim(),
              detail: '${u['vendid']}:${u['prodid']}',
              usbBus: _intOf(u['busnum']),
              usbPort: switch (u['usbpath']) {
                final p? => '$p',
                _ => null,
              },
            ),
      ],
      pci: [
        for (final m in pciMaps) mapped(m),
        if (root)
          for (final p in pci)
            VirtHostDevice(
              id: '${p['id']}',
              label: '${p['device_name'] ?? '${hex(p['vendor'])}:${hex(p['device'])}'}',
              detail: [p['id'], p['vendor_name']].nonNulls.join(' · '),
              iommuGroup: switch (_intOf(p['iommugroup'])) {
                final g? when g >= 0 => g,
                _ => null,
              },
              groupSize: groups[_intOf(p['iommugroup']) ?? -1] ?? 0,
            ),
      ],
    );
  }

  /// How many drives each bus takes (`ide0`–`ide3`, …).
  static const _busSlots = {'ide': 4, 'sata': 6, 'scsi': 31, 'virtio': 16};

  /// The first `<prefix>N` below [slots] that [config] does not use.
  static String _freeKey(Map<String, Object?> config, String prefix, int slots) {
    for (var i = 0; i < slots; i++) {
      if (!config.containsKey('$prefix$i')) return '$prefix$i';
    }
    throw VirtErr(
      type: VirtErrType.unsupported,
      message: 'No free $prefix slot',
    );
  }

  Future<Map<String, Object?>> _configOf(String path) async {
    final data = await _call((dio) => dio.get(_url('$path/config')));
    if (data is! Map) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    return data.cast<String, Object?>();
  }

  Future<void> _setConfig(
    VirtGuest guest,
    Map<String, Object?> params, {
    List<String> delete = const [],
    String? digest,
  }) {
    final data = {
      ...params,
      if (delete.isNotEmpty) 'delete': delete.join(','),
      'digest': ?digest,
    };
    final url = _url('${_guestPath(guest)}/config');
    final options = Options(contentType: Headers.formUrlEncodedContentType);
    return _task(
      guest,
      (dio) => guest.kind == VirtGuestKind.lxc
          ? dio.put(url, data: data, options: options)
          : dio.post(url, data: data, options: options),
    );
  }

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
  Future<List<VirtStoragePool>> storagePools() async {
    final nodes = await _onlineNodes();
    // Where each storage is comes from the cluster's configuration, which
    // needs `Datastore.Audit` on `/storage`: without it the list is still
    // there, only without paths.
    List<Object?>? config;
    try {
      final c = await _call((dio) => dio.get(_url('/storage')));
      if (c is List) config = c;
    } on VirtErr catch (e) {
      if (e.type != VirtErrType.authFailed) rethrow;
      Loggers.app.info('PVE /storage: ${e.message}');
    }
    final out = <VirtStoragePool>[];
    for (final node in nodes) {
      final data = await _call(
        (dio) => dio.get(_url('/nodes/${_seg(node)}/storage')),
      );
      if (data is! List) continue;
      out.addAll(PveResources.parseStorages(node, data, config: config));
    }
    return out;
  }

  @override
  Future<List<VirtVolume>> volumes(VirtStoragePool pool) async {
    final node = pool.node;
    if (node == null) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: 'No node for storage ${pool.name}',
      );
    }
    if (!pool.active) return const [];
    final data = await _call(
      (dio) => dio.get(
        _url('/nodes/${_seg(node)}/storage/${_seg(pool.name)}/content'),
      ),
    );
    if (data is! List) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    return _withImageSizes(node, PveResources.parseContent(data));
  }

  /// How many import images are sized at once.
  static const _imageSizeConcurrency = 4;

  /// [volumes] with the virtual size of each import image whose listing
  /// gives only its file's ([PveResources.imageSizeUnknown]), from
  /// `GET .../content/{volid}` — what a new disk made from it must hold at
  /// least. A few at a time; one PVE will not say stays unknown.
  Future<List<VirtVolume>> _withImageSizes(
    String node,
    List<VirtVolume> volumes,
  ) async {
    final out = [...volumes];
    final todo = [
      for (var i = 0; i < out.length; i++)
        if (PveResources.imageSizeUnknown(out[i].content, out[i].format)) i,
    ];
    var next = 0;
    Future<void> worker() async {
      while (next < todo.length) {
        final i = todo[next++];
        final v = out[i];
        final storage = v.id.split(':').first;
        try {
          final info = await _call(
            (dio) => dio.get(
              _url(
                '/nodes/${_seg(node)}/storage/${_seg(storage)}/content/${_seg(v.id)}',
              ),
            ),
          );
          final size = info is Map ? _intOf(info['size']) : null;
          if (size != null) out[i] = v.copyWith(capacity: size);
        } on VirtErr catch (e) {
          Loggers.app.info('PVE size of ${v.id}: ${e.message}');
        }
      }
    }

    await Future.wait([
      for (var w = 0; w < _imageSizeConcurrency && w < todo.length; w++) worker(),
    ]);
    return out;
  }

  /// How many guest configurations are read at once to find which bridge
  /// each NIC is on.
  static const _configConcurrency = 4;

  /// Every online node's interfaces, with the guests whose NICs are on each
  /// bridge — read from each guest's configuration, one request per guest.
  @override
  Future<List<VirtNetwork>> networks() async {
    final nodes = await _onlineNodes();
    final out = <VirtNetwork>[];
    for (final node in nodes) {
      final data = await _call(
        (dio) => dio.get(_url('/nodes/${_seg(node)}/network')),
      );
      if (data is! List) continue;
      final users = await _bridgeUsers([
        for (final g in _guests)
          if (g.node == node) g,
      ]);
      final management = await _managementOf(node, data);
      out.addAll(PveResources.parseNetworks(node, data, users: users, management: management));
    }
    return out;
  }

  Future<Map<String, List<VirtGuestRef>>> _bridgeUsers(
    List<VirtGuest> guests,
  ) async {
    final users = <String, List<VirtGuestRef>>{};
    var next = 0;
    Future<void> worker() async {
      while (next < guests.length) {
        final guest = guests[next++];
        try {
          final config = await _call(
            (dio) => dio.get(_url('${_guestPath(guest)}/config')),
          );
          if (config is! Map) continue;
          final of = PveResources.bridgeUsers(
            guest,
            config.cast<String, Object?>(),
          );
          for (final MapEntry(:key, :value) in of.entries) {
            users.putIfAbsent(key, () => []).addAll(value);
          }
        } on VirtErr catch (e) {
          // One guest this account may not read, or one deleted since the
          // last load listed it ("Configuration file ... does not exist"),
          // leaves only that guest out.
          if (e.type != VirtErrType.authFailed &&
              e.type != VirtErrType.invalidResponse) {
            rethrow;
          }
        }
      }
    }

    await Future.wait([
      for (var i = 0; i < _configConcurrency; i++) worker(),
    ]);
    for (final list in users.values) {
      list.sort((a, b) => (a.vmid ?? 0).compareTo(b.vmid ?? 0));
    }
    return users;
  }

  // ---------------------------------------------------------------------------
  // Managing storage and networks
  // ---------------------------------------------------------------------------

  static final _form = Options(contentType: Headers.formUrlEncodedContentType);

  /// A storage is cluster configuration (`/storage`), limited to the node it
  /// was made on; a volume and a bridge are a node's. Network changes wait in
  /// the node's `interfaces.new` until [VirtNetworkApply].
  ///
  /// A node's network changes run one at a time: they all write the one
  /// pending file, and an apply or a revert running beside an edit would
  /// apply what its safety check never saw, or drop an edit just saved.
  @override
  Future<void> manage(VirtResourceChange change) {
    final node = switch (change) {
      VirtNetworkCreate(:final node) => node,
      VirtNetworkEditBridge(:final network) ||
      VirtNetworkDelete(:final network) => network.node,
      VirtNetworkApply(:final node) || VirtNetworkRevert(:final node) => node,
      _ => null,
    };
    if (node == null) return _manage(change);
    final before = _netChanges[node] ?? Future<void>.value();
    final run = before.then((_) => _manage(change));
    final done = run.then<void>((_) {}, onError: (Object _) {});
    _netChanges[node] = done;
    unawaited(
      done.whenComplete(() {
        if (identical(_netChanges[node], done)) _netChanges.remove(node);
      }),
    );
    return run;
  }

  /// Each node's last network change, which the next one waits for
  /// ([manage]). Never completes with an error.
  final _netChanges = <String, Future<void>>{};

  Future<void> _manage(VirtResourceChange change) async {
    try {
      switch (change) {
        case VirtPoolCreate(:final name, :final type, :final source, :final node, :final content):
          final lvm = source.split('/');
          final nfs = source.indexOf(':/');
          await _call(
            (dio) => dio.post(
              _url('/storage'),
              data: {
                'storage': name,
                'type': type,
                ...switch (type) {
                  'dir' => {'path': source},
                  'nfs' => {
                    'server': source.substring(0, nfs),
                    'export': source.substring(nfs + 1),
                  },
                  'lvmthin' => {'vgname': lvm.first, 'thinpool': lvm.last},
                  'zfspool' => {'pool': source},
                  _ => throw const VirtErr(type: VirtErrType.unsupported),
                },
                'content': (content.isNotEmpty
                        ? content
                        : type == 'nfs'
                        ? const ['backup', 'iso']
                        : const ['images', 'rootdir'])
                    .join(','),
                'nodes': ?node,
              },
              options: _form,
            ),
            action: true,
          );
        case VirtPoolSetActive(:final pool, :final active):
          await _call(
            (dio) => dio.put(
              _url('/storage/${_seg(pool.name)}'),
              data: {'disable': active ? 0 : 1},
              options: _form,
            ),
            action: true,
          );
        case VirtPoolDelete(:final pool):
          await _call(
            (dio) => dio.delete(_url('/storage/${_seg(pool.name)}')),
            action: true,
          );
        case VirtPoolRefresh():
          // PVE reads a storage's contents on every listing.
          break;
        case VirtVolumeCreate(:final pool, :final name, :final gib, :final format):
          await _call(
            (dio) => dio.post(
              _url('${_storagePath(pool)}/content'),
              data: {
                'vmid': virtPveVolumeVmid(name),
                'filename': virtVolumeFileName(pool, name, format),
                'size': '${gib}G',
                'format': format,
              },
              options: _form,
            ),
            action: true,
          );
        case VirtVolumeDelete(:final pool, :final volume):
          await _nodeTask(
            pool.node!,
            (dio) => dio.delete(
              _url('${_storagePath(pool)}/content/${_seg(volume.id)}'),
            ),
          );
        case VirtNetworkCreate(
          :final name,
          :final node,
          :final bridge,
          :final cidr,
          :final vlanAware,
          :final autostart,
          :final mode,
        ):
          if (mode != 'bridge' || node == null) {
            throw const VirtErr(type: VirtErrType.unsupported);
          }
          final ports = bridge?.trim() ?? '';
          final address = cidr?.trim() ?? '';
          await _call(
            (dio) => dio.post(
              _url('/nodes/${_seg(node)}/network'),
              data: {
                'iface': name,
                'type': 'bridge',
                'autostart': autostart ? 1 : 0,
                'bridge_ports': ?(ports.isEmpty ? null : ports),
                'cidr': ?(address.isEmpty ? null : address),
                'bridge_vlan_aware': ?(vlanAware ? 1 : null),
              },
              options: _form,
            ),
            action: true,
          );
        case VirtNetworkEditBridge(
          :final network,
          :final ports,
          :final cidr,
          :final gateway,
          :final vlanAware,
          :final autostart,
        ):
          final node = network.node!;
          // The interface carries the node's management address: PVE would
          // cut itself off applying this, and there is no console here.
          if (!await _mayEditIfaceRead(node, network)) {
            throw const VirtErr(
              type: VirtErrType.unsupported,
              message: 'This interface carries the host\'s own address',
            );
          }
          final address = cidr?.trim();
          final gw = gateway?.trim();
          // PVE's `update_network` sets the interface's `method`/`method6`
          // and its address families from this request alone
          // (`$param->{method} = $param->{address} ? 'static' : 'manual'`,
          // pve-manager 9.2.2): an address not sent is an address dropped.
          // So the ones it has now go back with it — the IPv4 one unless
          // this edit changes it, and the IPv6 one, which the form does not
          // edit. Read fresh: the listing may be a while old.
          final now = await _call(
            (dio) => dio.get(
              _url('/nodes/${_seg(node)}/network/${_seg(network.name)}'),
            ),
          );
          String? current(String key) {
            final v = now is Map ? now[key] : null;
            final text = v?.toString().trim() ?? '';
            return text.isEmpty ? null : text;
          }
          final cidr4 = address ?? current('cidr');
          final cidr6 = current('cidr6');
          // Everything else PVE keeps, and a `0` is not sent: turning
          // something off means naming the key in `delete`.
          final delete = <String>[
            if (address != null && address.isEmpty) 'cidr,gateway',
            // VLAN awareness is a pair of properties: PVE's own editor
            // clears the allowed-VLAN list with it (`bridge_vids` is what
            // writes the `bridge-vids` line, and pvesh drops a bare `0`).
            if (vlanAware == false) 'bridge_vlan_aware,bridge_vids',
          ];
          await _call(
            (dio) => dio.put(
              _url('/nodes/${_seg(node)}/network/${_seg(network.name)}'),
              data: {
                'type': network.mode,
                if (ports != null) 'bridge_ports': ports.trim(),
                if (cidr4 != null && cidr4.isNotEmpty) 'cidr': cidr4,
                'cidr6': ?cidr6,
                if (gw != null && gw.isNotEmpty) 'gateway': gw,
                if (vlanAware == true) 'bridge_vlan_aware': 1,
                if (autostart != null) 'autostart': autostart ? 1 : 0,
                if (delete.isNotEmpty) 'delete': delete.join(','),
              },
              options: _form,
            ),
            action: true,
          );
        case VirtNetworkDelete(:final network):
          if (!await _mayEditIfaceRead(network.node!, network)) {
            throw const VirtErr(
              type: VirtErrType.unsupported,
              message: 'This interface carries the host\'s own address',
            );
          }
          await _call(
            (dio) => dio.delete(
              _url(
                '/nodes/${_seg(network.node!)}/network/${_seg(network.name)}',
              ),
            ),
            action: true,
          );
        case VirtNetworkApply(:final node):
          await _checkApply(node);
          await _nodeTask(
            node,
            (dio) => dio.put(_url('/nodes/${_seg(node)}/network')),
          );
        case VirtNetworkRevert(:final node):
          await _call(
            (dio) => dio.delete(_url('/nodes/${_seg(node)}/network')),
            action: true,
          );
        case VirtPoolSetAutostart() ||
            VirtVolumeResize() ||
            VirtVolumeClone() ||
            VirtNetworkSetActive() ||
            VirtNetworkSetAutostart() ||
            VirtNetworkRestart() ||
            // libvirt's network edit: PVE has its own (`VirtNetworkEditBridge`).
            VirtNetworkEdit():
          throw const VirtErr(type: VirtErrType.unsupported);
      }
    } on VirtErr catch (e) {
      throw _manageErr(e);
    }
  }

  /// Runs a command on the server this backend reaches PVE through, for
  /// what the API does not say ([_liveNet]); null in tests.
  final Future<ServerExec> Function()? _exec;

  /// The interfaces that carry a node's management traffic
  /// ([virtPveManagementIfaces]), from its listing and — for the node this
  /// app is connected through — what the node itself says it is using.
  /// Kept per node: an edit or a delete asks without reading them again.
  final _managementIfaces = <String, Set<String>>{};

  Future<Set<String>> _managementOf(String node, Object? listing) async =>
      _management(node, listing, await _liveNet());

  /// [_managementOf] with [live] already read; [also] as
  /// [virtPveManagementIfaces] takes it.
  Set<String> _management(
    String node,
    Object? listing,
    VirtPveLiveNet? live, {
    Set<String> also = const {},
  }) {
    final raw = listing is List ? listing : const <Object?>[];
    final management = virtPveManagementIfaces(
      PveResources.parseNetworks(node, raw),
      live: live?.host == node ? live : null,
      also: also,
      gateways6: {
        for (final e in raw)
          if (e case {'iface': final String iface, 'gateway6': final Object g}
              when '$g'.isNotEmpty)
            iface,
      },
    );
    _managementIfaces[node] = management;
    return management;
  }

  /// [virtPveLiveNetScript] on the server; null when it could not be run or
  /// read, which [virtPveManagementIfaces] answers by protecting every
  /// interface with an address.
  Future<VirtPveLiveNet?> _liveNet() async {
    final exec = _exec;
    if (exec == null) return null;
    try {
      final r = await (await exec()).run(virtPveLiveNetScript, entry: 'sh');
      return virtPveParseLiveNet(r.stdout);
    } catch (e) {
      Loggers.app.info('PVE live network probe: $e');
      return null;
    }
  }

  /// Whether [network] may be edited or deleted through this app.
  ///
  /// PVE allows a bridge; a physical interface's own settings belong to the
  /// host. And never one carrying the node's management traffic, or one it
  /// sits on ([virtPveManagementIfaces]): applying its configuration would
  /// cut the host off, with no console to fix it from.
  ///
  /// A listing that cannot be read refuses the interface, which is what an
  /// unknown management address deserves.
  Future<bool> _mayEditIfaceRead(String node, VirtNetwork network) async {
    if (network.mode != 'bridge') return false;
    var known = _managementIfaces[node];
    if (known == null) {
      try {
        final data = await _call(
          (dio) => dio.get(_url('/nodes/${_seg(node)}/network')),
        );
        known = await _managementOf(node, data);
      } on VirtErr catch (e) {
        Loggers.app.info('PVE network listing for $node: ${e.message}');
        return false;
      }
    }
    return virtPveManagedIface(network, management: known);
  }

  /// Refuses applying [node]'s pending network configuration when it touches
  /// a management interface ([virtPveManagementIfaces]) — made in the app or
  /// anywhere else, PVE's web UI included — or when the diff does not say
  /// whose lines it changes. Read fresh: an apply is the moment it matters.
  Future<void> _checkApply(String node) async {
    final body = await _call(
      (dio) => dio.get(_url('/nodes/${_seg(node)}/network')),
      whole: true,
    );
    final diff = body is Map ? body['changes'] : null;
    if (diff is! String || diff.trim().isEmpty) return;
    final probed = await _liveNet();
    final live = probed?.host == node ? probed : null;
    final touched = virtPveDiffIfaces(diff, interfaces: live?.interfaces);
    // The listing is the pending configuration: an interface it no longer
    // gives a gateway — or, without the node's own word on what it uses, an
    // address — may be the one the node is managed through until this is
    // applied.
    final management = _management(
      node,
      body is Map ? body['data'] : null,
      live,
      also: {
        ...touched.oldGateways,
        if (live == null) ...touched.oldAddressed,
      },
    );
    final hit = touched.ifaces.intersection(management);
    if (touched.unknown || hit.isNotEmpty) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: hit.isNotEmpty
            ? 'The pending configuration changes ${hit.join(', ')}, which '
                  "carries the host's management traffic: apply it from "
                  "the host's console or PVE's own interface"
            : 'Which interfaces the pending configuration changes cannot be '
                  "told from its diff: apply it from the host's console or "
                  "PVE's own interface",
      );
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

  /// A name taken as [VirtErrType.exists]; PVE's permission refusal as
  /// [VirtErrType.permissionDenied] naming the privilege, where, and how to
  /// grant it — the refusal alone says which, not what to type.
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
      // No built-in role holds it without far more: a role of its own.
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
  @visibleForTesting
  static String? pvePrivilegeRole(String privilege) => switch (privilege) {
    'Datastore.AllocateSpace' || 'Datastore.Audit' => 'PVEDatastoreUser',
    'Datastore.Allocate' || 'Datastore.AllocateTemplate' => 'PVEDatastoreAdmin',
    'Sys.Audit' => 'PVEAuditor',
    'SDN.Use' => 'PVESDNUser',
    final p when p.startsWith('VM.') => 'PVEVMAdmin',
    _ => null,
  };

  /// Each online node's pending network configuration: the `changes` PVE
  /// puts beside the interfaces it lists.
  @override
  Future<List<VirtNetworkChanges>> networkChanges() async {
    final out = <VirtNetworkChanges>[];
    for (final node in await _onlineNodes()) {
      final body = await _call(
        (dio) => dio.get(_url('/nodes/${_seg(node)}/network')),
        whole: true,
      );
      if (body case {'changes': final String diff}
          when diff.trim().isNotEmpty) {
        out.add(VirtNetworkChanges(node: node, diff: diff));
      }
    }
    return out;
  }

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

  /// A failure of the session as this app phrases it. What `sbm_virt` leaves
  /// to the caller (`detail_json`) is said in the user's language; the
  /// host's own words otherwise.
  VirtErr _fromRust(PveError e) {
    final type = switch (e.kind) {
      VirtFailure.unreachable => VirtErrType.unreachable,
      VirtFailure.notConfigured => VirtErrType.notConfigured,
      VirtFailure.authFailed => VirtErrType.authFailed,
      VirtFailure.needTfa => VirtErrType.needTfa,
      VirtFailure.certUnconfirmed => VirtErrType.certUnconfirmed,
      VirtFailure.certChanged => VirtErrType.certChanged,
      VirtFailure.permissionDenied => VirtErrType.permissionDenied,
      VirtFailure.invalidResponse => VirtErrType.invalidResponse,
      VirtFailure.actionFailed => VirtErrType.actionFailed,
      VirtFailure.unsupported => VirtErrType.unsupported,
      VirtFailure.exists => VirtErrType.exists,
      VirtFailure.conflict => VirtErrType.conflict,
      VirtFailure.notInstalled => VirtErrType.notInstalled,
      VirtFailure.sudoPasswordRequired => VirtErrType.sudoPasswordRequired,
      VirtFailure.sudoPasswordRejected => VirtErrType.sudoPasswordRejected,
      VirtFailure.closed || VirtFailure.unknown => VirtErrType.unknown,
    };
    final detail = e.detailJson == null ? null : jsonDecode(e.detailJson!);
    final message = switch (detail) {
      {'code': 'no_user'} => 'No user to log in to PVE as. Use an API token.',
      {'code': 'password_required'} => l10n.pvePasswordRequired,
      {'code': 'token_incomplete'} => 'The PVE API token is incomplete',
      {'code': 'otp_required'} => l10n.pveOtpRequired,
      {'code': 'otp_empty'} => l10n.pveOtpCodeRequired,
      {'code': 'otp_rejected'} => l10n.pveOtpVerificationFailed,
      {'code': 'invalid_body'} => l10n.pveInvalidResponseBody,
      {'code': 'invalid_data'} => l10n.pveInvalidResponseData,
      {'code': 'missing_ticket'} => l10n.pveMissingAuthTicket,
      {
        'code': 'no_privileges',
        'token': final bool token,
        'account': final String account,
        'command': final String command,
      } =>
        token
            ? l10n.pveTokenNoPrivileges(account, command)
            : l10n.pveUserNoPrivileges(account, command),
      {
        'code': 'task_still_running',
        'node': final String node,
        'upid': final String upid,
        'minutes': final int minutes,
      } =>
        'Still running on $node after $minutes min; '
            'its task log on the host says how it ends: $upid',
      {'code': 'cert_not_presented'} =>
        'That certificate was not presented by this server',
      {'code': 'not_offered'} => 'Not offered for this guest',
      _ => e.message,
    };
    final cert = e.cert;
    if (cert != null) _presented = cert;
    return VirtErr(
      type: type,
      message:
          (type == VirtErrType.certUnconfirmed ||
                  type == VirtErrType.certChanged) &&
              cert != null
          ? cert.prettyFingerprint
          : message,
      cert: cert,
      previousFingerprint: e.previousFingerprint,
      cause: e,
    );
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

  String _guestPath(VirtGuest guest) {
    final node = guest.node;
    final vmid = guest.vmid;
    if (node == null || vmid == null) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: 'No node or VMID for ${guest.name}',
      );
    }
    return '/nodes/${_seg(node)}/${guest.kind.name}/$vmid';
  }

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
