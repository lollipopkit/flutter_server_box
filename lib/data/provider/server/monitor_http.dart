import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor_exec_output.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_metrics.dart';

/// Talks to one server's `monitor` HTTP API. One instance is owned per
/// `ServerNotifier` (see `single.dart`), mirroring how `PveNotifier` owns its
/// own `Dio` session in `pve.dart` — but simpler, since monitor is meant to
/// be reached directly over HTTPS rather than tunneled through an SSH
/// forward like PVE.
///
/// Holds the [MonitorHttpCredential] rather than the full
/// `ServerConnectCredentialMonitorHttp`: nothing here needs the `Spi`, and
/// `MonitorTunnelSocket` builds a client from a bare credential inside
/// `genClient`, which also runs in isolates where no `Spi` graph is loaded.
class MonitorHttpClient {
  MonitorHttpClient(this.monitor);

  final MonitorHttpCredential monitor;

  Dio? _dio;
  String? _token;

  String get _addr {
    final addr = monitor.addr.trim();
    return addr.endsWith('/') ? addr.substring(0, addr.length - 1) : addr;
  }

  Dio _session() {
    final existing = _dio;
    if (existing != null) return existing;
    final dio = Dio(BaseOptions(baseUrl: _addr))
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
      client.badCertificateCallback = (_, _, _) => true;
    }
    return client;
  }

  Future<void> _login() async {
    final user = monitor.user?.trim() ?? '';
    final pwd = monitor.pwd ?? '';
    try {
      final resp = await _object(
        '/api/v1/login',
        post: {'username': user, 'password': pwd},
      );
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
      throw _toMonitorHttpErr(e);
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

  Future<List<MonitorHistoryPoint>> fetchHistory({int minutes = 60}) {
    return _authed(() async {
      // The endpoint answers with a bare JSON array of points, not an
      // envelope object — see `get_metrics_history` in monitor's api/server.rs
      final resp = await _session().get<dynamic>(
        '/api/v1/metrics/history',
        queryParameters: {'minutes': minutes},
      );
      final points = resp.data;
      if (points is! List) {
        throw MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: '/api/v1/metrics/history answered with '
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
  /// Answers 403 when the agent's `full_access` grant is off, which it
  /// re-checks per request: what `/capabilities` said earlier decides what the
  /// app *offers*, not what the agent allows.
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
        final message = switch (e.response?.statusCode) {
          403 =>
            'The monitor agent refuses to run commands — full access is off '
                'in its config.',
          404 =>
            'This monitor agent has no command endpoint. It is older than '
                'this app expects; update the agent.',
          _ => null,
        };
        if (message == null) rethrow;
        throw MonitorHttpErr(
          type: MonitorHttpErrType.unknown,
          message: '$message\n$e',
        );
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
          message: '/api/v1/fs/list answered with '
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
  }) {
    return _authed(() async {
      await _session().put<dynamic>(
        '/api/v1/fs/write',
        queryParameters: {'path': path},
        data: data,
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
    });
  }

  Future<void> fsMkdir(String path) => _authed(() async {
    await _object('/api/v1/fs/mkdir', post: {'path': path});
  });

  Future<void> fsRename(String from, String to) => _authed(() async {
    await _object('/api/v1/fs/rename', post: {'from': from, 'to': to});
  });

  Future<void> fsChmod(String path, int mode) => _authed(() async {
    await _object('/api/v1/fs/chmod', post: {'path': path, 'mode': mode});
  });

  Future<void> fsRemove(String path, {bool recursive = false}) {
    return _authed(() async {
      await _session().request<dynamic>(
        '/api/v1/fs/remove',
        data: {'path': path, 'recursive': recursive},
        options: Options(method: 'DELETE'),
      );
    });
  }

  /// Opens the agent's SSH tunnel and returns the raw WebSocket.
  ///
  /// Takes a single-use ticket first: a browser can't put a bearer token on a
  /// WebSocket handshake, so the agent authorises upgrades with a short-lived
  /// ticket instead, and this client uses the same path rather than a second
  /// mechanism that only native clients could exercise.
  ///
  /// Sends no target — the agent connects to its own configured address and
  /// refuses to take one from a client.
  Future<WebSocket> openTunnel({Duration? timeout}) =>
      _openWs(purpose: 'tunnel', path: '/api/v1/tunnel/ws', timeout: timeout);

  /// Opens the agent's terminal endpoint and returns the raw WebSocket.
  ///
  /// Unlike the tunnel this carries no SSH: the agent runs the shell itself
  /// and what travels here is PTY bytes and control JSON in the clear, which
  /// is why the agent refuses this endpoint on a plaintext link that isn't
  /// loopback. See `MonitorShellBackend` for the protocol spoken over it.
  Future<WebSocket> openTerminal({Duration? timeout}) => _openWs(
    purpose: 'terminal',
    path: '/api/v1/terminal/ws',
    timeout: timeout,
  );

  /// What this agent will accept right now, and what it runs on.
  ///
  /// Reports what the agent will *do*, not what its config asks for — the
  /// transport check is already folded into `terminal`, so a caller can hide
  /// an entry rather than offer one that answers 403.
  Future<MonitorCapabilities> fetchCapabilities() {
    return _authed(() async {
      return MonitorCapabilities.fromJson(
        await _object('/api/v1/capabilities'),
      );
    });
  }

  /// Takes a single-use ticket, then upgrades.
  ///
  /// A browser can't put a bearer token on a WebSocket handshake, so the agent
  /// authorises upgrades with a short-lived, purpose-bound ticket instead;
  /// this client uses the same path rather than a second mechanism that only
  /// native clients could exercise.
  Future<WebSocket> _openWs({
    required String purpose,
    required String path,
    Duration? timeout,
  }) {
    return _authed(() async {
      final resp = await _object(
        '/api/v1/ws-ticket',
        post: {'purpose': purpose},
      );
      final ticket = resp['ticket'] as String?;
      if (ticket == null || ticket.isEmpty) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: 'Empty ticket in /api/v1/ws-ticket response',
        );
      }

      // Scheme compared case-insensitively: `Uri.parse` lowercases it, but
      // `_addr` is whatever the user typed, and reading `HTTPS://` as
      // plaintext would dial `ws://` at a TLS port and hang
      final url = Uri.parse(_addr).replace(
        scheme: _addr.toLowerCase().startsWith('https') ? 'wss' : 'ws',
        path: path,
        queryParameters: {'ticket': ticket},
      );
      final socket = await WebSocket.connect(
        url.toString(),
        // Carries `ignoreCert` onto the upgrade: this is the same endpoint the
        // status poll uses, so it has to trust the same certs
        customClient: _httpClient(),
      ).timeout(
        timeout ?? const Duration(seconds: 15),
        onTimeout: () => throw MonitorHttpErr(
          type: MonitorHttpErrType.net,
          message: 'Timed out opening the monitor $purpose',
        ),
      );
      return socket;
    });
  }

  void dispose() {
    _dio?.close(force: true);
    _dio = null;
    _token = null;
  }

  /// Whether this client was built from the same monitor connection config
  /// as [other] — used to decide whether a cached client can be reused
  /// across refreshes or must be rebuilt (and re-logged-in) instead.
  bool matches(MonitorHttpCredential other) => monitor == other;

  MonitorHttpErr _toMonitorHttpErr(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return MonitorHttpErr(type: MonitorHttpErrType.net, message: e.toString());
    }
    if (e.response?.statusCode == 401) {
      return MonitorHttpErr(type: MonitorHttpErrType.auth, message: e.toString());
    }
    return MonitorHttpErr(type: MonitorHttpErrType.unknown, message: e.toString());
  }
}
