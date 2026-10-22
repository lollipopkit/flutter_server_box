import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/service/monitor_login_devices.dart';
import 'package:server_box/core/utils/secure_endpoint.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_agent.dart';
import 'package:server_box/data/model/server/monitor_backup.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor_desk_app.dart';
import 'package:server_box/data/model/server/monitor_exec_output.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_metrics.dart';
import 'package:server_box/data/model/server/monitor_overview.dart';
import 'package:server_box/data/model/server/monitor_push.dart';
import 'package:server_box/data/model/server/monitor_settings.dart';
import 'package:server_box/data/model/server/monitor_stack.dart';
import 'package:server_box/src/rust/api/protocol.dart';

/// A [MonitorHttpClient] shared by every holder of a lease on the same
/// credential: one sign-in, one connection pool. The status poll, the Monitor
/// tab, web apps and file browsers each hold one; the client goes with the
/// last [release].
final class MonitorClientLease {
  MonitorClientLease(MonitorHttpCredential monitor) : _shared = _SharedClient.acquire(monitor);

  final _SharedClient _shared;
  var _released = false;

  MonitorHttpClient get client => _shared.client;

  /// Idempotent.
  void release() {
    if (_released) return;
    _released = true;
    _shared.release();
  }
}

final class _SharedClient {
  _SharedClient(this.monitor) : client = MonitorHttpClient(monitor);

  static final _clients = <MonitorHttpCredential, _SharedClient>{};

  final MonitorHttpCredential monitor;
  final MonitorHttpClient client;
  int _references = 0;

  static _SharedClient acquire(MonitorHttpCredential monitor) {
    final shared = _clients.putIfAbsent(monitor, () => _SharedClient(monitor));
    shared._references++;
    return shared;
  }

  void release() {
    if (_references == 0) return;
    _references--;
    if (_references != 0) return;
    if (identical(_clients[monitor], this)) _clients.remove(monitor);
    client.dispose();
  }
}

/// Talks to one server's `monitor` HTTP API. Long-lived users share one
/// through [MonitorClientLease]; a short task (a dialog, a sync) makes its own.
///
/// Holds the [MonitorHttpCredential] rather than the full
/// `ServerConnectCredentialMonitorHttp`: nothing here needs the `Spi`, and a
/// bare credential is all a caller has to carry to reach one agent.
class MonitorHttpClient {
  MonitorHttpClient(this.monitor);

  static const _connectTimeout = Duration(seconds: 10);
  static const _sendTimeout = Duration(seconds: 30);
  static const _receiveTimeout = Duration(seconds: 30);

  final MonitorHttpCredential monitor;

  Dio? _dio;
  String? _token;

  /// Whether `/health` said the two of us understand each other; asked once,
  /// before the first sign-in. An agent replaced later by one that no longer
  /// answers this app says so with `426` instead.
  bool _protocolChecked = false;
  Future<void>? _loginFuture;
  bool _disposed = false;

  /// Completes on [dispose]: a sign-in of this client others wait for stops
  /// holding them (`MonitorLoginDevices.signingIn`).
  final _abandoned = Completer<void>();

  String get _addr {
    final addr = monitor.addr.trim();
    final normalized = addr.endsWith('/')
        ? addr.substring(0, addr.length - 1)
        : addr;
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !isSecureRemoteEndpoint(uri, allowInsecure: monitor.allowInsecure)) {
      throw MonitorHttpErr(
        type: MonitorHttpErrType.net,
        message: l10n.monitorHttpsRequired,
      );
    }
    return normalized;
  }

  Dio _session() {
    if (_disposed) throw StateError('MonitorHttpClient disposed');
    final existing = _dio;
    if (existing != null) return existing;
    final dio =
        Dio(
            BaseOptions(
              baseUrl: _addr,
              connectTimeout: _connectTimeout,
              sendTimeout: _sendTimeout,
              receiveTimeout: _receiveTimeout,
              headers: {MonitorProtocol.header: '${MonitorProtocol.current}'},
            ),
          )
          ..httpClientAdapter = IOHttpClientAdapter(
            createHttpClient: _httpClient,
            validateCertificate: monitor.ignoreCert ? (_, _, _) => true : null,
          );
    _dio = dio;
    return dio;
  }

  HttpClient _httpClient() {
    final client = HttpClient();
    if (monitor.ignoreCert) {
      Loggers.app.warning(
        'Monitor ignoring TLS certificate for ${monitor.addr} — only use on trusted private network',
      );
      client.badCertificateCallback = (_, _, _) => true;
    }
    return client;
  }

  Future<void> _login() {
    final existing = _loginFuture;
    if (existing != null) return existing;
    final future = _loginImpl();
    _loginFuture = future;
    return future.whenComplete(() {
      if (identical(_loginFuture, future)) _loginFuture = null;
    });
  }

  /// What this device is called in the agent's list of signed-in devices.
  @visibleForTesting
  static String get deviceName => 'ServerBox on ${Pfs.type.name} (${Platform.localHostname})';

  Future<void> _loginImpl() async {
    if (_disposed) return;
    final pwd = monitor.pwd ?? '';
    try {
      await _checkProtocol();
      if (_disposed) return;
      final resp = await MonitorLoginDevices.signingIn(abandoned: _abandoned.future, monitor.addr, (device) async {
        final resp = await _object(
          '/api/v1/login',
          // TODO: drop `username` with `MonitorHttpCredential.legacyUser`.
          post: {'username': ?monitor.legacyUser, 'password': pwd, 'device': ?device, 'name': deviceName},
        );
        if (resp['device'] case final String issued when issued.isNotEmpty) {
          await MonitorLoginDevices.remember(monitor.addr, issued);
        }
        return resp;
      });
      if (_disposed) return;
      final token = resp['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.loginFailed,
          message: 'Empty token in login response',
        );
      }
      _token = token;
      _session().options.headers['Authorization'] = 'Bearer $token';
    } on DioException catch (e) {
      if (_disposed) return;
      // An agent from before it had one account wants a user name, and its
      // JSON extractor refuses a body without one before anything else.
      // TODO: remove with `MonitorHttpCredential.legacyUser`.
      final status = e.response?.statusCode;
      if ((status == 400 || status == 422) && '${e.response?.data}'.contains('username')) {
        throw MonitorHttpErr(type: MonitorHttpErrType.agentTooOld, message: l10n.monitorAgentTooOld);
      }
      throw _toMonitorHttpErr(e);
    }
  }

  /// Refuses an agent this app cannot talk to, before signing in to it —
  /// `sbm_parser::protocol::compat` on what `/health` says.
  Future<void> _checkProtocol() async {
    if (_protocolChecked) return;
    Map<String, dynamic> health = const {};
    try {
      health = await _object('/api/v1/health');
    } on DioException catch (e) {
      // Answered, but not with numbers — an agent from before `/health`, or a
      // proxy in front of it: the first protocol, like an agent naming none.
      // A link that failed is still that.
      if (e.response == null) rethrow;
    } on MonitorHttpErr catch (e) {
      if (e.type != MonitorHttpErrType.invalidResponse) rethrow;
    }
    final agent = switch (health['protocol']) {
      final int n => n,
      _ => null,
    };
    final minClient = switch (health['min_client_protocol']) {
      final int n => n,
      _ => null,
    };
    switch (monitorProtocolCompat(agent: agent, minClient: minClient)) {
      case ProtocolCompat.ok:
        _protocolChecked = true;
      case ProtocolCompat.agentTooOld:
        throw MonitorHttpErr(
          type: MonitorHttpErrType.agentTooOld,
          message: 'The monitor agent speaks protocol $agent, older than this app reads',
        );
      case ProtocolCompat.clientTooOld:
        throw MonitorHttpErr(
          type: MonitorHttpErrType.clientTooOld,
          message: 'The monitor agent answers protocol $minClient and later; this app speaks ${MonitorProtocol.current}',
        );
    }
  }

  /// A JSON object from [path], or a [MonitorHttpErr] saying what came instead.
  ///
  /// Typed as `dynamic` on the way in and checked here rather than asking Dio
  /// to cast the body for us: that cast runs before the status code is looked
  /// at, so an endpoint the agent does not have — a 404 with a line of text —
  /// surfaced as a type-cast error naming two Dart types, which says nothing
  /// about what went wrong.
  Future<Map<String, dynamic>> _object(
    String path, {
    Object? post,
    Map<String, dynamic>? query,
  }) async {
    final dio = _session();
    final resp = post == null
        ? await dio.get<dynamic>(path, queryParameters: query)
        : await dio.post<dynamic>(path, data: post, queryParameters: query);
    final data = resp.data;
    if (data is Map<String, dynamic>) return data;
    throw MonitorHttpErr(
      type: MonitorHttpErrType.invalidResponse,
      message: data == null || (data is String && data.isEmpty)
          ? 'Empty $path response'
          : '$path answered with ${data.runtimeType}, not a JSON object',
    );
  }

  Future<T> _authed<T>(Future<T> Function() fn) async {
    if (_token == null) {
      await _login();
    }
    try {
      return await fn();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        // Token expired/invalid: re-login once, then retry.
        _token = null;
        await _login();
        try {
          return await fn();
        } on DioException catch (e2) {
          throw _toMonitorHttpErr(e2);
        }
      }
      throw _toMonitorHttpErr(e);
    }
  }

  Future<MonitorMetrics> fetchStatus() {
    return _authed(() async {
      return MonitorMetrics.fromJson(await _object('/api/v1/metrics'));
    });
  }

  /// Mints a read-only, independently revocable credential for a second
  /// device. The normal session token is never handed to one.
  ///
  /// The agent's `expires_at` is returned rather than dropped: these live 90
  /// days, and a caller that keeps the token without keeping the deadline has
  /// no way to renew it before the device it was given to starts answering
  /// 401 with nobody to report it to. Zero when the agent did not say — an
  /// older one — which [ScopedToken] treats as due for renewal.
  Future<({String token, int expiresAt})> issueWatchToken(String clientId) {
    return _authed(() async {
      final resp = await _object(
        '/api/v1/watch-token',
        post: {'client_id': clientId},
      );
      final token = resp['token'] as String?;
      if (token == null || token.isEmpty) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: 'Empty token in /api/v1/watch-token response',
        );
      }
      final expiresAt = resp['expires_at'];
      return (
        token: token,
        expiresAt: expiresAt is num ? expiresAt.toInt() : 0,
      );
    });
  }

  Future<void> revokeWatchToken(String clientId) {
    return _authed(() async {
      await _session().delete<dynamic>(
        '/api/v1/watch-token',
        data: {'client_id': clientId},
      );
    });
  }

  /// [maxPoints] is how many points to come back with; the agent averages the
  /// window into that many buckets rather than answering with its own default
  /// of 300 for the caller to throw most of away. An agent from before that
  /// parameter existed ignores it and answers with 300, which is why nothing
  /// here assumes the count it asked for.
  Future<List<MonitorHistoryPoint>> fetchHistory({
    int minutes = 60,
    int maxPoints = 300,
    DateTime? from,
    DateTime? to,
  }) {
    return _authed(() async {
      // The endpoint answers with a bare JSON array of points, not an
      // envelope object — see `get_metrics_history` in monitor's api/server.rs
      //
      // `from`/`to` name a window outright and the agent ignores `minutes`
      // when they are given; an agent too old for them falls back to it, which
      // is why it is still sent.
      final resp = await _session().get<dynamic>(
        '/api/v1/metrics/history',
        queryParameters: {
          'minutes': minutes,
          'max_points': maxPoints,
          if (from != null) 'from': from.millisecondsSinceEpoch ~/ 1000,
          if (to != null) 'to': to.millisecondsSinceEpoch ~/ 1000,
        },
      );
      final points = resp.data;
      if (points is! List) {
        throw MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message:
              '/api/v1/metrics/history answered with '
              '${points.runtimeType}, not a JSON array',
        );
      }
      return points
          .map((p) => MonitorHistoryPoint.fromJson(p as Map<String, dynamic>))
          .toList();
    });
  }

  /// Runs one command on the agent's machine and collects what it printed.
  ///
  /// [cmd] is handed to a POSIX shell, so it may be a pipeline or a script.
  /// [stdin] is written before the command's input closes — a sudo password
  /// with no terminal to type it into. The agent caps output and running time
  /// and reports when it had to; see [MonitorExecOutput].
  ///
  /// Answers 403 when the agent refuses this connection (plaintext HTTP
  /// without its `allow_insecure`), which it re-checks per request: what
  /// `/capabilities` said earlier decides what the app *offers*, not what the
  /// agent allows.
  Future<MonitorExecOutput> exec(
    String cmd, {
    String? stdin,
    Map<String, String>? env,
  }) {
    return _authed(() async {
      try {
        return MonitorExecOutput.fromJson(
          await _object(
            '/api/v1/exec',
            post: {
              'cmd': cmd,
              'stdin': ?stdin,
              if (env != null && env.isNotEmpty) 'env': env,
            },
          ),
        );
      } on DioException catch (e) {
        // Both are told apart from a generic failure because they are the ones
        // the user can do something about, and because retrying neither will
        // ever help.
        switch (e.response?.statusCode) {
          case 403:
            // Typed rather than worded: a caller has to tell "the agent said
            // no" from "the agent could not be reached", and only the type
            // survives being wrapped on the way up.
            throw const MonitorHttpErr(
              type: MonitorHttpErrType.notGranted,
              message:
                  'The monitor agent refuses to run commands over this '
                  'connection.',
            );
          case 404:
            throw MonitorHttpErr(
              type: MonitorHttpErrType.unknown,
              message:
                  'This monitor agent has no command endpoint. It is older '
                  'than this app expects; update the agent.\n$e',
            );
          default:
            rethrow;
        }
      }
    });
  }

  // --------------------------------------------------------------- files
  //
  // `/api/v1/fs/*`, which the agent serves only when its operator switched it
  // on and named the directories it may reach. Every path is absolute and is
  // resolved against those roots on the agent's side; nothing here has to
  // sanitise one, and nothing here should try — a second opinion about what a
  // path means is how the two ends stop agreeing.

  /// The directories this agent will serve at all.
  ///
  /// Asked rather than assumed: the roots are its operator's decision, they are
  /// the only paths any other call here can succeed on, and a browser that does
  /// not know them can only start at `/` and be refused.
  Future<List<String>> fsRoots() {
    return _fsRoots ??= _loadFsRoots().onError((Object e, StackTrace s) {
      _fsRoots = null;
      Error.throwWithStackTrace(e, s);
    });
  }

  Future<List<String>> _loadFsRoots() {
    return _authed(() async {
      final resp = await _object('/api/v1/fs/roots');
      final roots = resp['roots'];
      if (roots is! List) {
        throw MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message:
              '/api/v1/fs/roots answered with '
              '${roots.runtimeType}, not a JSON array',
        );
      }
      return roots.whereType<String>().toList();
    });
  }

  Future<List<String>>? _fsRoots;

  /// One directory, as the agent's `EntryView` describes it.
  Future<List<Map<String, dynamic>>> fsList(String path) {
    return _authed(() async {
      // A bare JSON array, like `/metrics/history`.
      final resp = await _session().get<dynamic>(
        '/api/v1/fs/list',
        queryParameters: {'path': path},
      );
      final entries = resp.data;
      if (entries is! List) {
        throw MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message:
              '/api/v1/fs/list answered with '
              '${entries.runtimeType}, not a JSON array',
        );
      }
      return entries.cast<Map<String, dynamic>>();
    });
  }

  /// One entry, or null where there is nothing there.
  ///
  /// The agent answers 404 both for absent and for out-of-bounds, on purpose:
  /// telling those apart would let a caller map the filesystem one status code
  /// at a time. Null therefore means "nothing you can have", which is the same
  /// thing from here.
  Future<Map<String, dynamic>?> fsStat(String path) {
    return _authed(() async {
      try {
        return await _object('/api/v1/fs/stat', query: {'path': path});
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) return null;
        rethrow;
      }
    });
  }

  /// The bytes, from [offset].
  ///
  /// Streamed rather than collected: this is the path that has to move a file
  /// bigger than the app is willing to hold.
  Future<Stream<List<int>>> fsRead(String path, {int offset = 0}) {
    return _authed(() async {
      final resp = await _session().get<ResponseBody>(
        '/api/v1/fs/read',
        queryParameters: {'path': path, if (offset > 0) 'offset': offset},
        options: Options(responseType: ResponseType.stream),
      );
      final body = resp.data;
      if (body == null) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: 'Empty /api/v1/fs/read response',
        );
      }
      return body.stream.map((chunk) => chunk.toList());
    });
  }

  /// Sends [data] to [path]. The agent stages it and renames, so a write that
  /// dies halfway leaves no half-file under the destination's name.
  Future<void> fsWrite(
    String path,
    Stream<List<int>> data, {
    int? size,
    Stream<List<int>> Function()? replayData,
  }) async {
    // Validate or refresh the token with a replayable request before touching
    // this one-shot body. `_authed` cannot safely retry the PUT itself: a
    // `File.openRead()` stream has already been consumed by the first attempt.
    await fsRoots();

    Future<void> put(Stream<List<int>> body) async {
      await _session().put<dynamic>(
        '/api/v1/fs/write',
        queryParameters: {'path': path},
        data: body,
        options: Options(
          // Dio will not set one for a stream, and the agent needs to know
          // where the body ends. Null sends it chunked, which the agent reads
          // to completion either way.
          headers: {
            'content-type': 'application/octet-stream',
            'content-length': ?size,
          },
        ),
      );
    }

    try {
      await put(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 && replayData != null) {
        _token = null;
        await _login();
        try {
          await put(replayData());
          return;
        } on DioException catch (retryError) {
          throw _toMonitorHttpErr(retryError);
        }
      }
      throw _toMonitorHttpErr(e);
    }
  }

  Future<void> fsMkdir(String path) =>
      _fsAct('/api/v1/fs/mkdir', {'path': path});

  Future<void> fsRename(String from, String to) =>
      _fsAct('/api/v1/fs/rename', {'from': from, 'to': to});

  Future<void> fsChmod(String path, int mode) =>
      _fsAct('/api/v1/fs/chmod', {'path': path, 'mode': mode});

  /// One of the endpoints that answers 200 and nothing else.
  ///
  /// Not [_object], which requires a JSON object and would turn every
  /// successful mkdir into "Empty /api/v1/fs/mkdir response" — a failure
  /// reported for an operation that worked, with the browser then skipping the
  /// refresh that would have shown it did.
  Future<void> _fsAct(String path, Map<String, Object?> body) {
    return _authed(() async {
      await _session().post<dynamic>(path, data: body);
    });
  }

  Future<void> fsRemove(String path, {bool recursive = false}) {
    return _authed(() async {
      await _session().request<dynamic>(
        '/api/v1/fs/remove',
        data: {'path': path, 'recursive': recursive},
        options: Options(method: 'DELETE'),
      );
    });
  }

  // -------------------------------------------------------------- backup
  //
  // `/api/v1/stacks*`: the web apps the agent deployed, any account.

  /// The deployed web apps, in the agent's order.
  Future<List<MonitorWebApp>> stacks() => _access(
    () async => MonitorWebApp.deployed(await _object('/api/v1/stacks')),
  );

  /// A single-use ticket into web app [id] through the agent's proxy, which
  /// a browser takes within seconds ([MonitorStackEntry.uri]).
  Future<MonitorStackEntry> stackEnter(String id) => _access(
    () async => MonitorStackEntry.fromJson(
      await _object('/api/v1/stacks/${Uri.encodeComponent(id)}/enter', post: const {}),
    ),
  );

  /// The agent's address, which a proxy without a host of its own shares.
  Uri get agentUri => Uri.parse(_addr);

  // ------------------------------------------------------------ desk apps
  //
  // `/api/v1/apps`: the apps installed on the agent's desk, any account.

  /// The approved desk apps, in the agent's order.
  Future<List<MonitorDeskApp>> deskApps() => _access(
    () async => MonitorDeskApp.approved(await _object('/api/v1/apps')),
  );

  // ------------------------------------------------------------ overview
  //
  // What the Monitor tab reads beside the apps: the rules firing now, the
  // notifications, the audit log, and what is signed in and open.

  /// The monitoring rules firing at the agent's last check.
  Future<MonitorAlerts> alerts() => _access(
    () async => MonitorAlerts.fromJson(await _object('/api/v1/alerts')),
  );

  /// Whether a newer agent is released, and how this one is updated; with
  /// [check], the agent reads its releases again first.
  Future<MonitorUpdate> update({bool check = false}) => _access(
    () async => MonitorUpdate.fromJson(await _object('/api/v1/update', query: {if (check) 'check': 1})),
  );

  /// Starts the agent's update (`POST /api/v1/update/run`): it runs apart
  /// from the agent and outlives its restart; [update] then says how it goes.
  /// [password] is sudo's, where the agent `needsPassword`.
  Future<void> startUpdate({String? password}) => _access(() async {
    await _session().post<dynamic>('/api/v1/update/run', data: {'password': ?password});
  });

  /// The newest [limit] notifications, and how many are unread.
  Future<MonitorNotices> notices({int limit = 100}) => _access(
    () async => MonitorNotices.fromJson(
      await _object('/api/v1/desk/notifications', query: {'limit': limit}),
    ),
  );

  /// Marks [ids] read, or every notification with [all].
  Future<void> markNoticesRead({List<int> ids = const [], bool all = false}) => _access(() async {
    await _session().post<dynamic>(
      '/api/v1/desk/notifications/read',
      data: {'ids': ids, 'all': all},
    );
  });

  /// A page of the audit log, newest first: rows older than [before], of one
  /// [kind] and [result] when given. Over a link the account may act on only.
  Future<MonitorAuditPage> audit({int? before, String? kind, String? result, int limit = 100}) => _access(
    () async => MonitorAuditPage.fromJson(
      await _object(
        '/api/v1/audit',
        query: {'limit': limit, 'before': ?before, 'kind': ?kind, 'result': ?result},
      ),
    ),
  );

  /// Terminal sessions, connections, watch tokens and signed-in devices.
  Future<MonitorLive> live() => _access(
    () async => MonitorLive.fromJson(await _object('/api/v1/live')),
  );

  Future<void> endSession(String id) => _access(() async {
    await _session().delete<dynamic>('/api/v1/live/sessions/${Uri.encodeComponent(id)}');
  });

  Future<void> endConnection(String id) => _access(() async {
    await _session().delete<dynamic>('/api/v1/live/connections/${Uri.encodeComponent(id)}');
  });

  /// Forgets a signed-in device: its next sign-in is a new device's. It does
  /// not sign it out; a new password does.
  Future<void> forgetDevice(int id) => _access(() async {
    await _session().delete<dynamic>('/api/v1/live/devices/$id');
  });

  // `/api/v1/backup*`: opaque blobs the agent stores for this app's backup
  // sync. What is sent is already encrypted with the backup password, so the
  // agent holds bytes it cannot read. Admin accounts only.

  Future<MonitorBackupList> fetchBackups() {
    return _authed(
      () => _backup(() async {
        return MonitorBackupList.fromJson(await _object('/api/v1/backup'));
      }, missing: l10n.monitorBackupUnsupported),
    );
  }

  /// One blob's bytes, streamed.
  Future<Stream<List<int>>> backupRead(String name) {
    return _authed(
      () => _backup(() async {
        final resp = await _session().get<ResponseBody>(
          '/api/v1/backup/blob',
          queryParameters: {'name': name},
          options: Options(responseType: ResponseType.stream),
        );
        final body = resp.data;
        if (body == null) {
          throw const MonitorHttpErr(
            type: MonitorHttpErrType.invalidResponse,
            message: 'Empty /api/v1/backup/blob response',
          );
        }
        return body.stream.map((chunk) => chunk.toList());
      }, missing: '404 noSuchBlob: $name'),
    );
  }

  /// Stores [size] bytes from [open] under [name], replacing a blob of that
  /// name.
  ///
  /// [open] is called once per attempt, so the 401 retry in [_authed] sends a
  /// fresh stream rather than one the first attempt already consumed. The
  /// listing first is what refreshes the token, and what lets a file over the
  /// agent's cap be refused before any of it is sent.
  Future<void> backupWrite(
    String name,
    Stream<List<int>> Function() open, {
    required int size,
  }) async {
    final maxBytes = (await fetchBackups()).maxBytes;
    if (maxBytes != null && size > maxBytes) {
      throw MonitorHttpErr(
        type: MonitorHttpErrType.badRequest,
        message: l10n.monitorBackupTooLarge(maxBytes.bytes2Str),
      );
    }
    await _authed(
      () => _backup(() async {
        await _session().put<dynamic>(
          '/api/v1/backup/blob',
          queryParameters: {'name': name},
          data: open(),
          options: Options(
            headers: {
              'content-type': 'application/octet-stream',
              'content-length': size,
            },
          ),
        );
      }, maxBytes: maxBytes),
    );
  }

  Future<void> backupRemove(String name) {
    return _authed(
      () => _backup(() async {
        await _session().delete<dynamic>(
          '/api/v1/backup/blob',
          queryParameters: {'name': name},
        );
      }, missing: '404 noSuchBlob: $name'),
    );
  }

  /// [fn] with the backup endpoints' refusals typed and worded. A 401 is left
  /// to [_authed]. [missing] is what a 404 means for this call: no such blob,
  /// or, for the listing, an agent without the endpoints.
  Future<T> _backup<T>(
    Future<T> Function() fn, {
    String? missing,
    int? maxBytes,
  }) async {
    try {
      return await fn();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final (type, message) = switch (status) {
        403 => (MonitorHttpErrType.forbidden, l10n.funcNeedsAgentHttps(libL10n.backup)),
        404 => (MonitorHttpErrType.notFound, missing),
        409 => (MonitorHttpErrType.conflict, l10n.monitorBackupTooMany),
        413 => (
          MonitorHttpErrType.badRequest,
          l10n.monitorBackupTooLarge(maxBytes?.bytes2Str ?? '?'),
        ),
        400 => (MonitorHttpErrType.badRequest, '400 ${e.response?.data}'),
        _ => (null, null),
      };
      if (type == null) rethrow;
      throw MonitorHttpErr(type: type, message: message);
    }
  }

  // ------------------------------------------------------------ settings
  //
  // The agent's own configuration, not this app's record of the server. Two
  // endpoints rather than one: a notification channel holds a credential the
  // agent will not disclose, and keeping that on its own save means an edit to
  // an interval can never be what drops one. See `monitor_push.dart`.

  Future<MonitorSettings> fetchSettings() {
    return _authed(() async {
      return MonitorSettings.fromJson(await _object('/api/v1/settings'));
    });
  }

  /// Replaces every field the payload names. Nothing here merges: the agent
  /// takes the whole whitelist at once, so [settings] must be what was loaded
  /// with the edits applied.
  Future<void> saveSettings(MonitorSettings settings) {
    return _authed(() async {
      await _session().put<dynamic>(
        '/api/v1/settings',
        data: settings.toPayload(),
      );
    });
  }

  Future<MonitorPushList> fetchPush() {
    return _authed(() async {
      return MonitorPushList.fromJson(await _object('/api/v1/push'));
    });
  }

  // ------------------------------------------------------------- account
  //
  // One account, signed in with its password — `docs/dev/monitor-permissions.md`.

  /// Changes this account's own password. The app keeps logging in with the
  /// one it has stored, so a caller updates that as well.
  Future<void> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _access(() async {
      await _session().put<dynamic>(
        '/api/v1/me/password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Agent mode (`/api/v1/agent*`)

  /// The account's tasks, newest change first: [limit] of them after the
  /// cursor [before] (a page's `next`), only those whose title or last line
  /// has [query]; every one without a [limit]. An agent from before paging
  /// ignores the three and answers them all, with no `next`.
  Future<MonitorAgentFlows> agentFlows({int? limit, String? before, String? query}) => _access(
    () async => MonitorAgentFlows.fromJson(
      await _object(
        '/api/v1/agent/flows',
        query: {'limit': ?limit, 'before': ?before, if (query != null && query.isNotEmpty) 'q': query},
      ),
    ),
  );

  /// Task [id] with its conversation.
  Future<MonitorAgentDetail> agentFlow(String id) => _access(
    () async => MonitorAgentDetail.fromJson(
      await _object('/api/v1/agent/flows/${Uri.encodeComponent(id)}'),
    ),
  );

  /// Starts a task; [mode] null is the admin's default, [model] and
  /// [thinkingLevel] null the machine's. [files] are upload ids
  /// ([agentUpload]).
  Future<MonitorAgentFlow> agentStart(
    String prompt, {
    String? mode,
    List<String> files = const [],
    MonitorAgentModel? model,
    String? thinkingLevel,
  }) => _access(
    () async => MonitorAgentFlow.fromJson(
      await _object(
        '/api/v1/agent/flows',
        post: {
          'prompt': prompt,
          'mode': ?mode,
          if (files.isNotEmpty) 'files': files,
          'model': ?model?.toJson(),
          'thinkingLevel': ?thinkingLevel,
        },
      ),
    ),
  );

  /// Says [text] to task [id]: the next turn while it runs, an edit or an
  /// answer while it waits, a new run once it is done. [files] are upload ids
  /// ([agentUpload]); [model] and [thinkingLevel] hold from then on.
  Future<MonitorAgentFlow> agentReply(
    String id,
    String text, {
    List<String> files = const [],
    MonitorAgentModel? model,
    String? thinkingLevel,
  }) => _access(
    () async => MonitorAgentFlow.fromJson(
      await _object(
        '/api/v1/agent/flows/${Uri.encodeComponent(id)}/reply',
        post: {
          'text': text,
          if (files.isNotEmpty) 'files': files,
          'model': ?model?.toJson(),
          'thinkingLevel': ?thinkingLevel,
        },
      ),
    ),
  );

  /// What a task may run with: the models and thinking levels there are.
  Future<MonitorAgentChoices> agentChoices() => _access(
    () async => MonitorAgentChoices.fromJson(await _object('/api/v1/agent/choices')),
  );

  /// The most one attachment may be, as the agent takes it.
  static const agentUploadMax = 20 << 20;

  /// Sends [file] for a task the next message names; answers its id. Read
  /// as it is sent, not held whole.
  Future<String> agentUpload(File file, {String? mime}) async {
    final size = await file.length();
    if (size > agentUploadMax) {
      throw const MonitorHttpErr(type: MonitorHttpErrType.badRequest, message: 'tooLarge');
    }
    final name = file.uri.pathSegments.lastOrNull ?? 'file';
    // An image goes to the model as one only under its own type.
    final type = mime ?? await file.mimeType ?? 'application/octet-stream';
    return _access(() async {
      final resp = await _session().post<dynamic>(
        '/api/v1/agent/files',
        queryParameters: {'name': name},
        data: file.openRead(),
        options: Options(
          headers: {
            Headers.contentLengthHeader: size,
            Headers.contentTypeHeader: type,
          },
        ),
      );
      final id = resp.data is Map ? resp.data['id'] : null;
      if (id is! String) {
        throw const MonitorHttpErr(type: MonitorHttpErrType.invalidResponse, message: 'No id in /api/v1/agent/files response');
      }
      return id;
    });
  }

  /// Answers what task [id] waits on: [action] with what it needs (`text`,
  /// `index`, `password` and `remember`, `confirm`).
  Future<void> agentAnswer(String id, Map<String, Object?> answer) => _access(() async {
    await _session().post<dynamic>('/api/v1/agent/flows/${Uri.encodeComponent(id)}/answer', data: answer);
  });

  Future<void> agentStop(String id) => _access(() async {
    await _session().post<dynamic>('/api/v1/agent/flows/${Uri.encodeComponent(id)}/stop');
  });

  Future<void> agentDelete(String id) => _access(() async {
    await _session().delete<dynamic>('/api/v1/agent/flows/${Uri.encodeComponent(id)}');
  });

  /// The account's Agent mode events (`flow`, `removed`, `pending`, `output`,
  /// `event`, `resync`), until the agent ends the stream or the
  /// subscription is cancelled. The agent pings every 25 s, so a stream
  /// silent for longer than [_eventsSilence] is gone.
  Stream<Map<String, dynamic>> agentEvents() async* {
    final body = await _authed(() async {
      final resp = await _session().get<ResponseBody>(
        '/api/v1/agent/events',
        options: Options(responseType: ResponseType.stream, receiveTimeout: _eventsSilence),
      );
      return resp.data;
    });
    if (body == null) return;
    var pending = '';
    await for (final chunk in body.stream.cast<List<int>>().transform(utf8.decoder)) {
      pending += chunk.replaceAll('\r\n', '\n');
      for (var end = pending.indexOf('\n\n'); end >= 0; end = pending.indexOf('\n\n')) {
        final frame = pending.substring(0, end);
        pending = pending.substring(end + 2);
        if (sseData(frame) case final e?) yield e;
      }
    }
  }

  static const _eventsSilence = Duration(seconds: 75);

  /// The JSON object an event-stream frame carries in its `data:` lines; null
  /// for a comment (`: ping`) or anything else.
  @visibleForTesting
  static Map<String, dynamic>? sseData(String frame) {
    final data = [
      for (final line in const LineSplitter().convert(frame))
        if (line.startsWith('data:')) line.substring(5).trimLeft(),
    ].join('\n');
    if (data.isEmpty) return null;
    try {
      final v = json.decode(data);
      return v is Map<String, dynamic> ? v : null;
    } on FormatException {
      return null;
    }
  }

  /// [fn] with the agent's refusals typed — see [accessErr]. A 401 still
  /// reaches [_authed], which logs in again and retries.
  Future<T> _access<T>(Future<T> Function() fn) {
    return _authed(() async {
      try {
        return await fn();
      } on DioException catch (e) {
        final typed = accessErr(e.response?.statusCode, e.response?.data);
        if (typed != null) throw typed;
        rethrow;
      }
    });
  }

  /// What a refusal means, from its status and the agent's
  /// `{"error": code, "message": ...}` body; null for a 401 and for anything
  /// that is not one of these.
  @visibleForTesting
  static MonitorHttpErr? accessErr(int? status, Object? body) {
    final code = body is Map ? body['error'] : null;
    final said = body is Map ? body['message'] : null;
    final type = switch ((status, code)) {
      (403, 'reauth') => MonitorHttpErrType.reauth,
      (403, 'sudo_password') => MonitorHttpErrType.sudoRefused,
      (409, _) => MonitorHttpErrType.conflict,
      (403, _) => MonitorHttpErrType.forbidden,
      (404, _) => MonitorHttpErrType.notFound,
      (400, _) => MonitorHttpErrType.badRequest,
      _ => null,
    };
    if (type == null) return null;
    return MonitorHttpErr(
      type: type,
      message: said is String && said.isNotEmpty ? said : '$status $code',
    );
  }

  /// Answers with the saved set read back, not with what was sent: after a
  /// reorder the `from_index` positions an editor needs next are the new ones.
  Future<MonitorPushList> savePush(MonitorPushList pushes) {
    return _authed(() async {
      final resp = await _session().put<dynamic>(
        '/api/v1/push',
        data: pushes.toPayload(),
      );
      final data = resp.data;
      if (data is! Map<String, dynamic>) {
        throw MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message:
              '/api/v1/push answered with ${data.runtimeType}, '
              'not a JSON object',
        );
      }
      return MonitorPushList.fromJson(data);
    });
  }

  /// Sends one notification through [entry] as it stands, saved or not.
  ///
  /// A withheld credential is resolved against `entry.fromIndex` on the
  /// agent's side, so a channel can be tested without the app ever holding its
  /// key. [message] travels with the request so it arrives in the user's
  /// language; the agent caps its length.
  Future<MonitorPushTestResult> testPush(
    MonitorPushEntry entry,
    String message,
  ) {
    return _authed(() async {
      return MonitorPushTestResult.fromJson(
        await _object(
          '/api/v1/push/test',
          post: {'push': entry.toJson(), 'message': message},
        ),
      );
    });
  }

  /// Opens the agent's terminal endpoint and returns the raw WebSocket.
  ///
  /// The agent runs the shell itself; what travels here is PTY bytes and
  /// control JSON in the clear, so it refuses plaintext links that are not
  /// loopback. See `MonitorShellBackend` for the protocol spoken over it.
  Future<WebSocket> openTerminal({Duration? timeout}) =>
      _openWs(timeout: timeout);

  /// Opens the agent's TCP relay and returns the raw WebSocket.
  ///
  /// The connection itself is asked for over the socket rather than in the URL
  /// — the address is the operator's own network and there is no reason to
  /// write it into every access log between here and the agent. See
  /// `MonitorTunnelChannel` for the protocol spoken over it.
  Future<WebSocket> openStream({Duration? timeout}) =>
      _openWs(timeout: timeout, purpose: 'stream', path: '/api/v1/stream/ws');

  /// Opens the agent's listener endpoint and returns the raw WebSocket: the
  /// control socket of a remote port forward. See `MonitorRemoteListener` for
  /// the protocol spoken over it.
  Future<WebSocket> openListen({Duration? timeout}) =>
      _openWs(timeout: timeout, purpose: 'listen', path: '/api/v1/listen/ws');

  /// What this agent will accept right now, and what it runs on.
  ///
  /// Reports what the agent will *do*, not what its config asks for — the
  /// transport check is already folded into `access`, so a caller can hide an
  /// entry rather than offer one that answers 403.
  Future<MonitorCapabilities> fetchCapabilities() {
    return _authed(() async {
      return MonitorCapabilities.fromJson(
        await _object('/api/v1/capabilities'),
      );
    });
  }

  /// Takes a single-use ticket, then upgrades.
  ///
  /// Where the terminal upgrade is opened, carrying no ticket.
  ///
  /// Split out, and paired with [terminalWsProtocol], because this is one half
  /// of a contract whose other half is in another language: the agent reads
  /// the ticket in `api/ws/terminal.rs` and the panel sends it from
  /// `frontend/src/lib/terminal.svelte.ts`. The panel's two functions are
  /// shaped this way for the same reason and are tested the same way — this
  /// side had it inline and untested, which is how it went on sending
  /// `?ticket=` for a release after the agent stopped reading it.
  ///
  /// Scheme compared case-insensitively: `Uri.parse` lowercases it, but [addr]
  /// is whatever the user typed, and reading `HTTPS://` as plaintext would
  /// dial `ws://` at a TLS port and hang.
  @visibleForTesting
  static Uri terminalWsUrl(String addr) =>
      _wsUrl(addr, '/api/v1/terminal/ws');

  /// The relay's upgrade URL. Same contract, one endpoint further along.
  @visibleForTesting
  static Uri streamWsUrl(String addr) => _wsUrl(addr, '/api/v1/stream/ws');

  static Uri _wsUrl(String addr, String path) {
    // Rebuilt rather than `.replace`d: an empty `queryParameters` map is a
    // query, so the URL came out with a bare `?` on the end — the same
    // cosmetic half of the bug the empty fragment used to be.
    final base = Uri.parse(addr);
    return Uri(
      scheme: addr.toLowerCase().startsWith('https') ? 'wss' : 'ws',
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
    );
  }

  /// What the agent reads the ticket out of — `TICKET_PROTOCOL_PREFIX` in
  /// `monitor/src/api/ws/terminal.rs`, and `terminalWsProtocol` in the panel.
  /// All three have to say the same thing.
  @visibleForTesting
  static String terminalWsProtocol(String ticket) => 'sbm-ticket.$ticket';

  /// A browser can't put a bearer token on a WebSocket handshake, so the agent
  /// authorises upgrades with a short-lived, single-use ticket instead.
  ///
  /// [purpose] and [path] are the two halves of which endpoint this is; the
  /// ticket carries the first and the agent checks it against the second, so a
  /// ticket minted for one is refused at the other.
  Future<WebSocket> _openWs({
    Duration? timeout,
    String purpose = 'terminal',
    String path = '/api/v1/terminal/ws',
  }) {
    return _authed(() async {
      final Map<String, dynamic> resp;
      try {
        resp = await _object('/api/v1/ws-ticket', post: {'purpose': purpose});
      } on DioException catch (e) {
        // The agent mints a ticket only over a connection it serves, so a 403
        // here is its transport check speaking — what a caller that has not
        // read `/capabilities` yet learns instead, and must be able to tell
        // from a link that failed.
        if (e.response?.statusCode != 403) rethrow;
        final body = e.response?.data;
        final said = body is Map ? body['error'] : null;
        throw MonitorHttpErr(
          type: MonitorHttpErrType.notGranted,
          message: said is String && said.isNotEmpty
              ? 'The monitor agent refused: $said'
              : 'The monitor agent refused the $purpose endpoint',
        );
      }
      final ticket = resp['ticket'] as String?;
      if (ticket == null || ticket.isEmpty) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: 'Empty ticket in /api/v1/ws-ticket response',
        );
      }

      final socket =
          await WebSocket.connect(
            _wsUrl(_addr, path).toString(),
            // The ticket rides the subprotocol, not the query string. A URL is
            // what every access log, proxy and error message writes down, and
            // this one authorises a shell — the agent stopped reading
            // `?ticket=` for that reason and answers 401 to anything that
            // still sends it that way.
            protocols: [terminalWsProtocol(ticket)],
            headers: {MonitorProtocol.header: '${MonitorProtocol.current}'},
            // Carries `ignoreCert` onto the upgrade: this is the same endpoint the
            // status poll uses, so it has to trust the same certs
            customClient: _httpClient(),
          ).timeout(
            timeout ?? const Duration(seconds: 15),
            onTimeout: () => throw MonitorHttpErr(
              type: MonitorHttpErrType.net,
              message: 'Timed out opening the monitor terminal',
            ),
          );
      return socket;
    });
  }

  void dispose() {
    _disposed = true;
    if (!_abandoned.isCompleted) _abandoned.complete();
    _dio?.close(force: true);
    _dio = null;
    _token = null;
    _loginFuture = null;
  }

  /// Whether this client was built from the same monitor connection config
  /// as [other] — used to decide whether a cached client can be reused
  /// across refreshes or must be rebuilt (and re-logged-in) instead.
  bool matches(MonitorHttpCredential other) => monitor == other;

  MonitorHttpErr _toMonitorHttpErr(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      // The cause, not Dio's paragraph about it.
      return MonitorHttpErr(
        type: MonitorHttpErrType.net,
        message: '${e.error ?? e.message ?? e.type.name}',
      );
    }
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final said = data is Map ? data['message'] ?? data['error'] : null;
    final message = [
      if (status != null) 'HTTP $status',
      if (said is String && said.isNotEmpty) said else ?e.message,
    ].join(': ');
    if (status == 401) {
      return MonitorHttpErr(type: MonitorHttpErrType.auth, message: message);
    }
    if (status == 426) {
      return MonitorHttpErr(type: MonitorHttpErrType.clientTooOld, message: message);
    }
    return MonitorHttpErr(type: MonitorHttpErrType.unknown, message: message);
  }
}

/// `sbm_parser::protocol` as this app speaks it, read once.
abstract final class MonitorProtocol {
  static final header = monitorProtocolHeader();
  static final current = monitorProtocol();
}
