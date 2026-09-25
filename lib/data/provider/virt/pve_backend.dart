import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:redfish/redfish.dart' show CertInfo, PinnedCert;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server_tcp.dart';
import 'package:server_box/core/utils/version.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/virt/pve_resources.dart';
import 'package:server_box/data/model/virt/virt.dart';
import 'package:server_box/data/model/virt/virt_console.dart';
import 'package:server_box/data/model/virt/virt_create.dart';
import 'package:server_box/data/model/virt/virt_detail.dart';
import 'package:server_box/data/model/virt/virt_hardware.dart';
import 'package:server_box/data/model/virt/virt_rates.dart';
import 'package:server_box/data/model/virt/virt_resources.dart';
import 'package:server_box/data/provider/virt/backend.dart';
import 'package:server_box/data/res/store.dart';

/// Opens a TCP connection to `host:port` as seen from the PVE server — what
/// `ServerTcpDialer.startConnect` is.
typedef PveConnect = ConnectionTask<Socket> Function(String host, int port);

/// Proxmox VE through its HTTP API, over whichever transport reaches the
/// server (`ServerTcpDialer`: an SSH channel, the monitor agent's relay, or a
/// direct socket for this device).
///
/// **Auth.** [PveAuth.token] sends `Authorization: PVEAPIToken=<id>=<secret>`
/// on every request: no ticket, no CSRF token, no TOTP. [PveAuth.password]
/// logs in to the PAM realm as the SSH user, with the password
/// [PveConfig.loginPassword] picks, and keeps the ticket and
/// `CSRFPreventionToken` for the session; an account with TOTP stops at
/// [VirtErrType.needTfa] until [submitTfa].
///
/// **TLS.** A certificate that validates against the platform's CAs is
/// trusted as it is. Otherwise its SHA-256 must be [PveConfig.certSha256]:
/// with none pinned the connection fails with [VirtErrType.certUnconfirmed]
/// carrying the presented certificate, and [confirmCert] pins it; with a
/// different one pinned it fails with [VirtErrType.certChanged]. Nothing is
/// ever accepted without having been shown — the request waiting on the
/// handshake carries a password or a token.
///
/// **Sessions.** One login at a time. [reset] (and a 401, or a transport
/// failure) moves to a new generation; a login still running for an older
/// one finishes, finds itself stale and discards what it made, and the next
/// call logs in again only after it has — so two logins never overlap and a
/// stale one never overwrites a newer session.
///
/// **Ticket lifetime.** PVE refuses a ticket, and a TFA challenge, two hours
/// after issuing it ([ticketLifetime]). A password session renews its ticket
/// once it is [renewAfter] old, by sending the ticket as the password — what
/// PVE's own web UI does, and it asks no second factor. A ticket refused
/// anyway (the device slept past the lifetime) is replaced by one new login
/// and the request repeated; for a TOTP account that login stops at
/// [VirtErrType.needTfa]. A challenge past its lifetime is replaced by
/// [submitTfa] before it answers.
class PveBackend implements VirtBackend {
  PveBackend({
    required this.serverId,
    required PveConfig config,
    required PveConnect connect,
    this.user,
    this.sshKeyId,
    this.sshPassword,
    this.securityContext,
    void Function(String fingerprint)? onCertConfirmed,
    void Function()? onClose,
    @visibleForTesting HttpClientAdapter Function()? adapter,
    this.taskPoll = const Duration(seconds: 1),
    this.taskTimeout = const Duration(minutes: 10),
    DateTime Function()? now,
  }) : _config = config,
       _connect = connect,
       _onCertConfirmed = onCertConfirmed,
       _onClose = onClose,
       _adapter = adapter,
       _now = now ?? DateTime.now;

  /// The backend for [spi], connecting through its `ServerTcpDialer` and
  /// writing a confirmed certificate to `Stores.pve`.
  factory PveBackend.of(Ref ref, Spi spi, PveConfig config) {
    final dialer = ServerTcpDialer.of(ref, spi);
    return PveBackend(
      serverId: spi.id,
      config: config,
      connect: dialer.startConnect,
      user: spi.ssh?.user,
      sshKeyId: spi.ssh?.keyId,
      sshPassword: spi.ssh?.pwd,
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

  /// How long PVE accepts a ticket or a TFA challenge
  /// (`$ticket_lifetime` in `PVE::AccessControl`, 2 hours on PVE 9.2).
  static const ticketLifetime = Duration(hours: 2);

  /// When a password session renews its ticket. PVE's web UI renews every
  /// 15 minutes; an hour leaves as much margin while the view refreshes every
  /// few seconds.
  static const renewAfter = Duration(hours: 1);

  /// Treated as expired this long before [ticketLifetime], for the time a
  /// request spends in flight and clocks that drift.
  static const _lifetimeMargin = Duration(minutes: 5);

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

  /// Trust roots for "validates against a CA"; null is the platform's.
  final SecurityContext? securityContext;

  /// How often a task is asked whether it has finished, and for how long.
  final Duration taskPoll;
  final Duration taskTimeout;

  PveConfig _config;
  final PveConnect _connect;
  final void Function(String fingerprint)? _onCertConfirmed;
  final void Function()? _onClose;
  final HttpClientAdapter Function()? _adapter;
  final DateTime Function() _now;

  final _rates = VirtRateTracker(holdUntilChanged: true);

  /// Guest states read from `status/current` right after one of this app's
  /// actions finished, by guest id, laid over `/cluster/resources` until that
  /// agrees — the same status, and no longer an uptime from before a reboot —
  /// or [freshStatusFor] has passed.
  ///
  /// `/cluster/resources` is what `pvestatd` last broadcast, which lags by up
  /// to its ~10 s cycle: on PVE 9.2 a container still read `running` there
  /// 8 s after its `stop` task had ended, while `status/current` already said
  /// `stopped`. Without this the refresh after an action shows the state from
  /// before it and offers the actions that no longer apply.
  final _fresh = <String, _FreshStatus>{};

  static const freshStatusFor = Duration(seconds: 30);

  PveConfig get config => _config;

  int _generation = 0;
  _Session? _session;
  Future<void>? _connecting;
  int _connectingGeneration = -1;
  _TfaChallenge? _tfa;
  String? _release;
  bool _closed = false;

  /// The certificate the last refused handshake presented — what
  /// [confirmCert] may pin.
  CertInfo? _presented;

  /// Replaces the configuration (the user edited it). Starts a new session
  /// when anything that reaches the API changed.
  void updateConfig(PveConfig config) {
    if (config == _config) return;
    _config = config;
    unawaited(reset());
  }

  Uri get _base {
    var addr = _config.addr.trim();
    while (addr.endsWith('/')) {
      addr = addr.substring(0, addr.length - 1);
    }
    return Uri.parse(addr);
  }

  String _url(String path) => '$_base/api2/json$path';

  static String _seg(Object value) => Uri.encodeComponent('$value');

  // ---------------------------------------------------------------------------
  // VirtBackend
  // ---------------------------------------------------------------------------

  @override
  Future<VirtSnapshot> load() async {
    final data = await _call((dio) => dio.get(_url('/cluster/resources')));
    if (data is! List) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    final at = _now();
    final parsed = PveResources.parse(_withFreshStatus(data, at), at: at);
    // PVE lists only what this account may see, and says nothing about the
    // rest: a token with privilege separation and no ACL of its own gets its
    // nodes' bare names and no guests (seen on PVE 9.2). Asked only then — a
    // host with no guests is rare, and it is one request.
    if (parsed.guests.isEmpty) await _ensureAuditable();
    final stats = <String, VirtStats>{
      for (final MapEntry(:key, :value) in parsed.samples.entries)
        key: _rates.add(key, value),
    };
    _rates.retain(parsed.samples.keys);
    final nodes = parsed.nodes..sort((a, b) => a.name.compareTo(b.name));
    _nodes = nodes;
    _guests = parsed.guests;
    return VirtSnapshot(
      host: VirtHost(
        serverId: serverId,
        kind: VirtHostKind.pve,
        version: _release,
        nodes: nodes,
      ),
      guests: parsed.guests,
      stats: stats,
      capabilities: VirtCapabilities(
        lxc: true,
        pause: true,
        snapshots: true,
        storage: true,
        network: true,
        cluster: nodes.length > 1,
        vncConsole: true,
        termConsole: true,
        storedHistory: true,
        create: true,
        hardware: true,
        hardwareRevert: true,
      ),
    );
  }

  /// Throws [VirtErrType.permissionDenied] when this account may audit
  /// nothing at all (`VM.Audit` and `Sys.Audit` nowhere), with the ACL that
  /// fixes it; returns when the empty list is the host's real answer.
  Future<void> _ensureAuditable() async {
    final perms = await _call((dio) => dio.get(_url('/access/permissions')));
    if (perms is! Map) return;
    bool granted(String priv) => perms.values.any(
      (privs) => privs is Map && privs[priv] != null && privs[priv] != 0,
    );
    if (granted('VM.Audit') || granted('Sys.Audit')) return;
    final token = _config.auth == PveAuth.token;
    final account = token ? _config.tokenId ?? '' : _userFields()['username']!;
    final qualified = token || account.contains('@') ? account : '$account@pam';
    final command =
        "pveum acl modify / --${token ? 'tokens' : 'users'} '$qualified' "
        '--roles PVEAuditor,PVEVMAdmin';
    throw VirtErr(
      type: VirtErrType.permissionDenied,
      message: token
          ? l10n.pveTokenNoPrivileges(qualified, command)
          : l10n.pveUserNoPrivileges(qualified, command),
    );
  }

  @override
  Future<void> power(VirtGuest guest, VirtPowerAction action) async {
    if (!guest.actions.contains(action)) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: '${action.name} is not offered for ${guest.name}',
      );
    }
    final path = _guestPath(guest);
    final verb = switch (action) {
      VirtPowerAction.start => 'start',
      VirtPowerAction.shutdown => 'shutdown',
      VirtPowerAction.reboot => 'reboot',
      VirtPowerAction.forceStop => 'stop',
      VirtPowerAction.suspend => 'suspend',
      VirtPowerAction.resume => 'resume',
    };
    final upid = await _call(
      (dio) => dio.post(
        _url('$path/status/$verb'),
        data: {
          // A shutdown the guest ignores holds the guest until it times
          // out, and a plain stop queues behind it; this aborts it instead.
          if (action == VirtPowerAction.forceStop && _canOverruleShutdown)
            'overrule-shutdown': 1,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      ),
      action: true,
    );
    if (upid is String && upid.startsWith('UPID:')) {
      await _waitTask(guest.node!, upid);
    }
    if (action == VirtPowerAction.reboot) {
      await _readStatusAfterReboot(guest, path);
    } else {
      await _readStatus(guest, path);
    }
  }

  /// The first release whose `status/stop` takes `overrule-shutdown` (QEMU
  /// and LXC alike). Sent only to a release known to have it: an older one
  /// refuses the request for a parameter it does not know.
  static const overruleShutdownSince = [8, 1];

  bool get _canOverruleShutdown {
    final release = _release;
    return release != null &&
        !isVersionLessThan(release, overruleShutdownSince);
  }

  /// How long a reboot's guest may read as not running once its task has
  /// ended, before that is believed.
  static const rebootRestartTimeout = Duration(seconds: 30);

  /// [_readStatus] until the guest runs again, for at most
  /// [rebootRestartTimeout].
  ///
  /// A QEMU reboot's task (`qmreboot`) ends once the guest has shut down;
  /// `qmeventd` then starts it again in a task of its own. On PVE 9.2 the
  /// guest read `stopped` right after the reboot task and ran again about a
  /// second later (verified, test/e2e/virt_real_test.dart). Recording that
  /// first reading would show a rebooting VM as stopped for [freshStatusFor]
  /// and offer `start`, which PVE then refuses as "already running".
  Future<void> _readStatusAfterReboot(VirtGuest guest, String path) async {
    final deadline = _now().add(rebootRestartTimeout);
    while (true) {
      final status = await _readStatus(guest, path);
      if (status == null || status == 'running') return;
      if (_now().isAfter(deadline)) return;
      await Future<void>.delayed(taskPoll);
    }
  }

  /// Records [guest]'s state as `status/current` has it now — see [_fresh] —
  /// and answers it; null when it could not be read. Best effort: the action
  /// itself has succeeded either way.
  Future<String?> _readStatus(VirtGuest guest, String path) async {
    try {
      final data = await _call(
        (dio) => dio.get(_url('$path/status/current')),
        action: true,
      );
      if (data is! Map) return null;
      // What `pvestatd` puts in `/cluster/resources`: the QEMU run state
      // where there is one (`paused`, ...), else `running` or `stopped`.
      // PVE 9.2 answers a paused VM as `status: running` and
      // `qmpstatus: paused` here, and as `status: paused` in the listing.
      final status = data['qmpstatus'] ?? data['status'];
      if (status is! String || status.isEmpty) return null;
      final uptime = data['uptime'];
      _fresh[guest.id] = _FreshStatus(
        status: status,
        uptime: uptime is num ? uptime.toInt() : null,
        at: _now(),
      );
      return status;
    } on VirtErr catch (e) {
      Loggers.app.info('PVE status after an action: ${e.message}');
      return null;
    }
  }

  /// [raw] with each guest that has a [_fresh] state showing it, until the
  /// listing reports the same status itself or the state is too old to trust.
  List<Object?> _withFreshStatus(List<Object?> raw, DateTime now) {
    if (_fresh.isEmpty) return raw;
    final listed = <String>{};
    final out = <Object?>[];
    for (final item in raw) {
      final id = item is Map ? item['id'] : null;
      final fresh = _fresh[id];
      if (item is! Map || id is! String || fresh == null) {
        out.add(item);
        continue;
      }
      listed.add(id);
      final elapsed = now.difference(fresh.at);
      // Uptime as of now, going by the fresh reading. A guest read in its
      // first second after a start or a reboot reports 0 and is running all
      // the same (PVE 9.2, a container right after `reboot`), so it counts up
      // too; only a guest that is not running stays at 0.
      final uptime = switch (fresh.uptime) {
        null => null,
        final u when u > 0 || fresh.status == 'running' =>
          u + elapsed.inSeconds,
        final u => u,
      };
      final listedUptime = item['uptime'];
      // The same status is not enough after a reboot, which keeps it: an
      // uptime longer than the guest has been up since is from before.
      final caughtUp =
          item['status'] == fresh.status &&
          (uptime == null ||
              listedUptime is! num ||
              listedUptime <= uptime + 2);
      if (caughtUp || elapsed > freshStatusFor) {
        _fresh.remove(id);
        out.add(item);
        continue;
      }
      out.add({...item, 'status': fresh.status, 'uptime': ?uptime});
    }
    _fresh.removeWhere((id, _) => !listed.contains(id));
    return out;
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
    final session = await _ensureSession();
    final base = _base;
    final url = base
        .replace(scheme: base.isScheme('https') ? 'wss' : 'ws')
        .resolve(console.websocketPath);
    final headers = <String, Object>{
      for (final key in const ['Authorization', 'Cookie'])
        if (session.dio.options.headers[key] case final Object v) key: v,
    };
    final client = _httpClient();
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

  /// `vmstate` only for a VM: a container's snapshot never has memory, and
  /// PVE refuses the parameter for one.
  @override
  Future<void> createSnapshot(
    VirtGuest guest, {
    required String name,
    String? description,
    bool memory = false,
  }) async {
    if (!virtSnapshotNamePattern.hasMatch(name)) {
      throw VirtErr(
        type: VirtErrType.unsupported,
        message: 'Not a snapshot name: $name',
      );
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
    await _readStatus(guest, path);
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

  /// `POST /nodes/{node}/qemu` or `/lxc`, waited for; then `start` as a
  /// request of its own rather than the create's `start=1`, so a guest that
  /// was created and did not start is told apart from one that was not
  /// created.
  ///
  /// A VM gets a serial port (`serial0: socket`), so its text console works
  /// before it has a network, and the install media first in the boot order
  /// after its disk. A container is unprivileged unless asked otherwise, with
  /// DHCP on its NIC.
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
      final iso = spec.media?.id;
      body = {
        'vmid': vmid,
        'name': spec.name,
        'cores': spec.cores,
        'memory': spec.memoryMiB,
        'ostype': 'l26',
        'scsihw': 'virtio-scsi-single',
        'scsi0': '$storage:${spec.diskGiB},iothread=1',
        'ide2': ?iso == null ? null : '$iso,media=cdrom',
        'net0': ?bridge == null ? null : 'virtio,bridge=$bridge',
        'serial0': 'socket',
        'boot': 'order=${['scsi0', if (iso != null) 'ide2'].join(';')}',
      };
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
    return VirtCreated(id: id, startError: startError);
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
        case VirtHwRemoveDisk(:final key, :final deleteVolume):
          final volume = switch (rawOf(await rawConfig(), key)) {
            final String v => PveResources.volumeOf(v),
            null => null,
          };
          await _setConfig(guest, const {}, delete: [key], digest: digest);
          if (!deleteVolume || volume == null) break;
          // Detached, the volume is `unusedN`, and deleting that entry
          // deletes it. Still attached — a running guest that cannot let go
          // of it until it stops — it is not there, and is kept.
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
          if (unused == null) return const VirtHwOutcome(volumeKept: true);
          await _setConfig(
            guest,
            const {},
            delete: [unused],
            digest: after['digest'] as String?,
          );
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
          // request that drops the old one. PVE drops the old one from the
          // boot order too; it is put back as the new one, in its place.
          final to = _freeKey(config, bus, _busSlots[bus] ?? 1);
          final order = base.boot;
          await _setConfig(
            guest,
            {
              to: value,
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
        case VirtHwAddDevice(:final kind, :final host, :final storage):
          final config = await rawConfig();
          switch (kind) {
            case VirtHwDeviceKind.tpm:
              await _setConfig(guest, {
                'tpmstate0': '$storage:1,version=v2.0',
              }, digest: digest);
            case VirtHwDeviceKind.usb:
              final id = host!.id;
              await _setConfig(guest, {
                _freeKey(config, 'usb', 14): host.mapping ? 'mapping=$id' : 'host=$id',
              }, digest: digest);
            case VirtHwDeviceKind.pci:
              final id = host!.id;
              await _setConfig(guest, {
                _freeKey(config, 'hostpci', 16): host.mapping ? 'mapping=$id' : id,
              }, digest: digest);
          }
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

  /// Detaches [key] and deletes its volume: detached, it is `unusedN`, and
  /// deleting that entry deletes it.
  Future<void> _dropVolume(VirtGuest guest, String key, {String? digest}) async {
    final path = _guestPath(guest);
    final raw = (await _configOf(path))[key];
    final volume = raw is String ? PveResources.volumeOf(raw) : null;
    await _setConfig(guest, const {}, delete: [key], digest: digest);
    if (volume == null) return;
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
    if (unused == null) return;
    await _setConfig(guest, const {}, delete: [unused]);
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
    return PveResources.parseContent(data);
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
      out.addAll(PveResources.parseNetworks(node, data, users: users));
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
          // One guest this account may not read leaves only that guest out.
          if (e.type != VirtErrType.authFailed) rethrow;
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

  @override
  Future<void> reset() async {
    _generation++;
    _session?.dio.close(force: true);
    _session = null;
    _tfa?.dio.close(force: true);
    _tfa = null;
    _rates.clear();
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    await reset();
    _closed = true;
    _onClose?.call();
  }

  // ---------------------------------------------------------------------------
  // What the user answers
  // ---------------------------------------------------------------------------

  /// The TOTP code for the challenge [VirtErrType.needTfa] announced. Then
  /// [load] again.
  ///
  /// A challenge that is gone (a [reset] since) or past [ticketLifetime] is
  /// replaced by a new login first, and the code answers that one: the code
  /// belongs to the account, not to a challenge. PVE answers an expired
  /// challenge exactly as it answers a wrong code (401 `authentication
  /// failure`), so without this every code typed after two hours would read as
  /// wrong.
  Future<void> submitTfa(String code) async {
    final otp = code.trim();
    if (otp.isEmpty) {
      throw VirtErr(
        type: VirtErrType.needTfa,
        message: l10n.pveOtpCodeRequired,
      );
    }
    var pending = _tfa;
    if (pending == null || !_challengeUsable(pending)) {
      pending = await _newChallenge();
      if (pending == null) return;
    }
    final Map<String, dynamic> data;
    try {
      final resp = await _requestTicket(pending.dio, {
        ..._userFields(),
        'password': 'totp:$otp',
        'tfa-challenge': pending.ticket,
        'new-format': '1',
      });
      data = _ticketData(resp);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // A wrong code, or one already used (PVE rejects a reused TOTP
        // value). The challenge stays: PVE lets it be answered again until it
        // expires.
        throw VirtErr(
          type: VirtErrType.needTfa,
          message: l10n.pveOtpVerificationFailed,
        );
      }
      throw _toErr(e);
    }
    try {
      final ticket = _setTicket(pending.dio, data);
      final release = await _fetchRelease(pending.dio);
      if (pending.generation != _generation || !identical(_tfa, pending)) {
        return;
      }
      _tfa = null;
      _release = release ?? _release;
      _session = _Session(
        pending.generation,
        pending.dio,
        ticket: ticket,
        issuedAt: _now(),
      );
    } catch (e) {
      throw _toErr(e);
    }
  }

  bool _challengeUsable(_TfaChallenge challenge) =>
      challenge.generation == _generation &&
      _now().difference(challenge.issuedAt) < ticketLifetime - _lifetimeMargin;

  /// Logs in again for a challenge to answer. Null when the login needed no
  /// second factor after all (the account's TOTP was removed): the session is
  /// there and nothing is left to answer.
  Future<_TfaChallenge?> _newChallenge() async {
    final stale = _tfa;
    if (stale != null) {
      _tfa = null;
      stale.dio.close(force: true);
    }
    try {
      await _ensureSession();
      return null;
    } on VirtErr catch (e) {
      final fresh = _tfa;
      if (e.type != VirtErrType.needTfa || fresh == null) rethrow;
      return fresh;
    }
  }

  /// Pins [fingerprint], which must be the certificate the last refused
  /// connection presented ([VirtErr.cert]), and starts over. Writes it to the
  /// server's PVE configuration.
  Future<void> confirmCert(String fingerprint) async {
    final presented = _presented;
    if (presented == null ||
        presented.fingerprint.toLowerCase() != fingerprint.toLowerCase()) {
      throw const VirtErr(
        type: VirtErrType.certUnconfirmed,
        message: 'That certificate was not presented by this server',
      );
    }
    final pin = presented.fingerprint.toLowerCase();
    _config = _config.copyWith(certSha256: pin);
    _presented = null;
    _onCertConfirmed?.call(pin);
    await reset();
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  Future<_Session> _ensureSession() async {
    while (true) {
      if (_closed) throw StateError('PveBackend used after close');
      final session = _session;
      if (session != null && session.generation == _generation) {
        if (!_renewDue(session)) return session;
        await _renew(session);
        // Dropped when PVE refused the renewal: log in again.
        if (identical(_session, session)) return session;
        continue;
      }
      final pending = _connecting;
      if (pending != null) {
        final pendingGeneration = _connectingGeneration;
        try {
          await pending;
        } catch (_) {
          // A stale attempt's failure is not this caller's: go round again
          // and log in for the current generation.
          if (pendingGeneration == _generation) rethrow;
        }
        continue;
      }
      final generation = _generation;
      final attempt = _open(generation);
      _connecting = attempt;
      _connectingGeneration = generation;
      try {
        await attempt;
      } catch (_) {
        if (generation == _generation) rethrow;
      } finally {
        if (identical(_connecting, attempt)) _connecting = null;
      }
    }
  }

  bool _renewDue(_Session session) =>
      session.ticket != null &&
      _now().difference(session.issuedAt) >= renewAfter;

  /// Renews [session]'s ticket, once however many callers ask. Drops the
  /// session when PVE refuses the old ticket, or when it is too old to be
  /// worth asking; keeps it as it is on any other failure, which the request
  /// that follows reports.
  Future<void> _renew(_Session session) =>
      session.renewing ??= _renewTicket(
        session,
      ).whenComplete(() => session.renewing = null);

  Future<void> _renewTicket(_Session session) async {
    final ticket = session.ticket;
    if (ticket == null) return;
    if (_now().difference(session.issuedAt) >=
        ticketLifetime - _lifetimeMargin) {
      await _drop(session);
      return;
    }
    try {
      final resp = await _requestTicket(session.dio, {
        ..._userFields(),
        'password': ticket,
        'new-format': '1',
      });
      final data = _ticketData(resp);
      if (!identical(_session, session)) return;
      session
        ..ticket = _setTicket(session.dio, data)
        ..issuedAt = _now();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _drop(session);
        return;
      }
      Loggers.app.info('PVE ticket renewal: ${_toErr(e).message}');
    } on VirtErr catch (e) {
      Loggers.app.info('PVE ticket renewal: ${e.message}');
    }
  }

  /// Logs in for [generation]. A result for a generation that has moved on
  /// is discarded, never installed.
  Future<void> _open(int generation) async {
    final dio = _newDio();
    var keep = false;
    try {
      String? ticket;
      switch (_config.auth) {
        case PveAuth.token:
          if (!_config.hasToken) {
            throw const VirtErr(
              type: VirtErrType.notConfigured,
              message: 'The PVE API token is incomplete',
            );
          }
          dio.options.headers['Authorization'] =
              'PVEAPIToken=${_config.tokenId}=${_config.tokenSecret}';
        case PveAuth.password:
          ticket = await _login(dio, generation);
      }
      final release = await _fetchRelease(dio);
      if (generation != _generation) return;
      _release = release ?? _release;
      _session = _Session(generation, dio, ticket: ticket, issuedAt: _now());
      keep = true;
    } on VirtErr catch (e) {
      if (e.type == VirtErrType.needTfa && generation == _generation) {
        keep = true;
      }
      rethrow;
    } catch (e) {
      throw _toErr(e);
    } finally {
      if (!keep) dio.close(force: true);
    }
  }

  Map<String, String> _userFields() {
    final name = user?.trim() ?? '';
    // `root@pam` already names its realm.
    return name.contains('@')
        ? {'username': name}
        : {'username': name, 'realm': 'pam'};
  }

  /// Logs [dio] in and answers the ticket.
  Future<String> _login(Dio dio, int generation) async {
    final name = user?.trim() ?? '';
    // Sent as stored, spaces included: PAM compares it byte for byte, and the
    // SSH login this may be borrowed from sends it untrimmed too.
    final password = _config.loginPassword(
      sshKeyId: sshKeyId,
      sshPassword: sshPassword,
    );
    if (name.isEmpty) {
      throw const VirtErr(
        type: VirtErrType.notConfigured,
        message: 'No user to log in to PVE as. Use an API token.',
      );
    }
    if (password == null || password.isEmpty) {
      throw VirtErr(
        type: VirtErrType.notConfigured,
        message: l10n.pvePasswordRequired,
      );
    }
    final Response<dynamic> resp;
    try {
      resp = await _requestTicket(dio, {
        ..._userFields(),
        'password': password,
        'new-format': '1',
      });
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // PVE's own words or none: the UI titles this itself, in the user's
        // language, and a sentence made up here would be English in any.
        throw VirtErr(
          type: VirtErrType.authFailed,
          message: _pveMessage(e),
          cause: e,
        );
      }
      rethrow;
    }
    final data = _ticketData(resp);
    if (data['NeedTFA'] == 1 || data['TFA'] != null) {
      final ticket = data['ticket'];
      if (ticket is! String || ticket.isEmpty) {
        throw VirtErr(
          type: VirtErrType.invalidResponse,
          message: l10n.pveInvalidResponseData,
        );
      }
      if (generation == _generation) {
        _tfa?.dio.close(force: true);
        _tfa = _TfaChallenge(generation, dio, ticket, _now());
      }
      throw VirtErr(type: VirtErrType.needTfa, message: l10n.pveOtpRequired);
    }
    return _setTicket(dio, data);
  }

  Future<Response<dynamic>> _requestTicket(
    Dio dio,
    Map<String, dynamic> data,
  ) => dio.post(
    _url('/access/ticket'),
    data: data,
    options: Options(contentType: Headers.formUrlEncodedContentType),
  );

  Map<String, dynamic> _ticketData(Response<dynamic> resp) {
    final body = resp.data;
    if (body is! Map<String, dynamic>) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseBody,
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw VirtErr(
        type: VirtErrType.invalidResponse,
        message: l10n.pveInvalidResponseData,
      );
    }
    return data;
  }

  /// Puts the ticket in [data] on [dio] and answers it.
  String _setTicket(Dio dio, Map<String, dynamic> data) {
    final ticket = data['ticket'];
    if (ticket is! String || ticket.isEmpty) {
      throw VirtErr(
        type: VirtErrType.authFailed,
        message: l10n.pveMissingAuthTicket,
      );
    }
    dio.options.headers['CSRFPreventionToken'] = data['CSRFPreventionToken'];
    dio.options.headers['Cookie'] = 'PVEAuthCookie=$ticket';
    return ticket;
  }

  Future<String?> _fetchRelease(Dio dio) async {
    try {
      final resp = await dio.get(_url('/version'));
      final body = resp.data;
      final data = body is Map ? body['data'] : null;
      if (data is! Map) return null;
      final version = data['version'] ?? data['release'];
      return version is String && version.isNotEmpty ? version : null;
    } on DioException catch (e) {
      // Only an auth or transport failure is fatal here: a version is
      // nice to show, not needed.
      final code = e.response?.statusCode;
      if (code == 401 || code == 403 || e.response == null) rethrow;
      return null;
    }
  }

  /// Runs [request] in the current session and answers the body's `data`.
  ///
  /// **What ends the session** is what says the session itself is no good: a
  /// 401 (PVE's answer to a missing, expired or forged ticket, a bad CSRF
  /// token, or a refused API token), or a transport or certificate failure.
  /// The next call logs in again.
  ///
  /// **A 403 never does.** PVE answers 403 only after it has accepted the
  /// ticket or token, from its permission check ("Permission check failed
  /// (/vms/101, VM.PowerMgmt)") — the account lacks a privilege on that path,
  /// on any endpoint. Dropping the session there throws away a good ticket
  /// (and the rate history with it), and for an account with TOTP makes the
  /// user type a code again, to be refused the same way.
  ///
  /// [action] marks a call on one guest (a power action, its task, a console
  /// ticket), whose 403 is reported as [VirtErrType.actionFailed] with PVE's
  /// text: the host view is fine, that one thing is not allowed. Elsewhere a
  /// 403 is [VirtErrType.authFailed] — what this account may see is the
  /// problem, and the configuration is where it is fixed.
  ///
  /// **A 401 on a password session this call did not log in** is retried
  /// once, after a new login: PVE refused the ticket (it expired while the
  /// device slept through the renewal), and nothing ran. Without it the view
  /// would stop on [VirtErrType.authFailed], which waits for the user,
  /// although the stored password is fine. A second refusal, the login's own,
  /// or a 401 on a token is reported as it is.
  Future<Object?> _call(
    Future<Response<dynamic>> Function(Dio dio) request, {
    bool action = false,
  }) async {
    final before = _session;
    final session = await _ensureSession();
    try {
      return await _send(session, request, action: action);
    } on VirtErr catch (e) {
      final reused = identical(before, session) && session.ticket != null;
      final cause = e.cause;
      final refused =
          e.type == VirtErrType.authFailed &&
          cause is DioException &&
          cause.response?.statusCode == 401;
      if (!reused || !refused) rethrow;
      return _send(await _ensureSession(), request, action: action);
    }
  }

  Future<Object?> _send(
    _Session session,
    Future<Response<dynamic>> Function(Dio dio) request, {
    required bool action,
  }) async {
    try {
      final resp = await request(session.dio);
      final body = resp.data;
      if (body is! Map) {
        throw VirtErr(
          type: VirtErrType.invalidResponse,
          message: l10n.pveInvalidResponseBody,
        );
      }
      return body['data'];
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
      if (err.type == VirtErrType.authFailed ||
          err.type == VirtErrType.unreachable ||
          err.type == VirtErrType.relayNotGranted ||
          err.type == VirtErrType.certChanged ||
          err.type == VirtErrType.certUnconfirmed) {
        await _drop(session);
      }
      throw err;
    }
  }

  Future<void> _drop(_Session session) async {
    if (!identical(_session, session)) return;
    await reset();
  }

  Future<void> _waitTask(String node, String upid) async {
    final deadline = _now().add(taskTimeout);
    final path = '/nodes/${_seg(node)}/tasks/${_seg(upid)}/status';
    while (true) {
      final data = await _call((dio) => dio.get(_url(path)), action: true);
      if (data is Map && data['status'] == 'stopped') {
        final exit = '${data['exitstatus'] ?? ''}';
        // `WARNINGS: n` is a task that completed and logged warnings.
        if (exit == 'OK' || exit.startsWith('WARNINGS')) return;
        throw VirtErr(
          type: VirtErrType.actionFailed,
          message: exit.isEmpty ? upid : exit,
        );
      }
      if (_now().isAfter(deadline)) {
        // Still running: the state the next refresh reads says what became
        // of it. Not a failure.
        Loggers.app.info('PVE task still running after $taskTimeout: $upid');
        return;
      }
      await Future<void>.delayed(taskPoll);
    }
  }

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
  // Transport and TLS
  // ---------------------------------------------------------------------------

  Dio _newDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: connectTimeout,
        sendTimeout: requestTimeout,
        receiveTimeout: requestTimeout,
      ),
    );
    dio.httpClientAdapter =
        _adapter?.call() ?? IOHttpClientAdapter(createHttpClient: _httpClient);
    return dio;
  }

  /// How long an idle connection is kept for the next request: under
  /// pveproxy's own 5 s (`PVE::APIServer::AnyEvent`, `timeout`), after which
  /// it closes the connection. `HttpClient` keeps one for 15 s by default,
  /// and a request sent on it as pveproxy closes it fails with "Connection
  /// closed before full header was received" (seen on PVE 9.2 after a 5 s
  /// pause, directly and over SSH) — for a power action, after it may have
  /// been received.
  static const idleTimeout = Duration(seconds: 3);

  HttpClient _httpClient() {
    final client = HttpClient()
      ..connectionTimeout = connectTimeout
      ..idleTimeout = idleTimeout;
    client.connectionFactory = (url, proxyHost, proxyPort) async =>
        _connectTo(url);
    return client;
  }

  /// A connection for [url]: the dialer's socket, secured here for `https` so
  /// the certificate decision is this class's and not `HttpClient`'s.
  ConnectionTask<Socket> _connectTo(Uri url) {
    final task = _connect(url.host, url.port);
    if (!url.isScheme('https') && !url.isScheme('wss')) return task;
    final pin = PinnedCert(_config.certSha256);
    X509Certificate? refused;
    final secure = task.socket.then((socket) async {
      try {
        return await SecureSocket.secure(
          socket,
          host: url.host,
          context: securityContext,
          onBadCertificate: (cert) {
            if (pin.accepts(cert)) return true;
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

  VirtErr _certErr(X509Certificate cert, PinnedCert pin, Object cause) {
    final info = CertInfo.of(cert);
    _presented = info;
    if (!pin.hasPin) {
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
      previousFingerprint: pin.fingerprint,
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
      if (inner is VirtErr || inner is ServerTcpErr) return _toErr(inner!);
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

final class _FreshStatus {
  const _FreshStatus({required this.status, this.uptime, required this.at});

  final String status;
  final int? uptime;
  final DateTime at;
}

final class _Session {
  _Session(this.generation, this.dio, {this.ticket, required this.issuedAt});

  final int generation;
  final Dio dio;

  /// The PVE ticket of a password session, which renews it; null for a
  /// token.
  String? ticket;

  /// When [ticket] was issued, by this device's clock.
  DateTime issuedAt;

  /// The renewal in flight, which every caller waits for.
  Future<void>? renewing;
}

/// A password login waiting for its TOTP code: the half-logged-in client and
/// the challenge ticket to answer.
final class _TfaChallenge {
  const _TfaChallenge(this.generation, this.dio, this.ticket, this.issuedAt);

  final int generation;
  final Dio dio;
  final String ticket;
  final DateTime issuedAt;
}
