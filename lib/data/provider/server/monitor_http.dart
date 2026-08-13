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
      final resp = await _session().post<Map<String, dynamic>>(
        '/api/v1/login',
        data: {'username': user, 'password': pwd},
      );
      final token = resp.data?['token'] as String?;
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
      final resp = await _session().get<Map<String, dynamic>>(
        '/api/v1/metrics',
      );
      final data = resp.data;
      if (data == null) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: 'Empty /api/v1/metrics response',
        );
      }
      return MonitorMetrics.fromJson(data);
    });
  }

  Future<List<MonitorHistoryPoint>> fetchHistory({int minutes = 60}) {
    return _authed(() async {
      // The endpoint answers with a bare JSON array of points, not an
      // envelope object — see `get_metrics_history` in monitor's api/server.rs
      final resp = await _session().get<List<dynamic>>(
        '/api/v1/metrics/history',
        queryParameters: {'minutes': minutes},
      );
      final points = resp.data;
      if (points == null) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: 'Empty /api/v1/metrics/history response',
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
      final Response<Map<String, dynamic>> resp;
      try {
        resp = await _session().post<Map<String, dynamic>>(
          '/api/v1/exec',
          data: {
            'cmd': cmd,
            'stdin': ?stdin,
            if (env != null && env.isNotEmpty) 'env': env,
          },
        );
      } on DioException catch (e) {
        // Told apart from a generic failure because it is the one the user can
        // do something about, and because retrying it will never help: the
        // agent is configured not to run commands at all.
        if (e.response?.statusCode == 403) {
          throw MonitorHttpErr(
            type: MonitorHttpErrType.unknown,
            message:
                'The monitor agent refuses to run commands — full access is '
                'off in its config.\n$e',
          );
        }
        rethrow;
      }
      final data = resp.data;
      if (data == null) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: 'Empty /api/v1/exec response',
        );
      }
      return MonitorExecOutput.fromJson(data);
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
      final resp = await _session().get<Map<String, dynamic>>(
        '/api/v1/capabilities',
      );
      final data = resp.data;
      if (data == null) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: 'Empty /api/v1/capabilities response',
        );
      }
      return MonitorCapabilities.fromJson(data);
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
      final resp = await _session().post<Map<String, dynamic>>(
        '/api/v1/ws-ticket',
        data: {'purpose': purpose},
      );
      final ticket = resp.data?['ticket'] as String?;
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
