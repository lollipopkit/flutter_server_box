import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:meta/meta.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/secure_endpoint.dart';
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
  Future<void>? _loginFuture;
  bool _disposed = false;

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

  Future<void> _loginImpl() async {
    if (_disposed) return;
    final user = monitor.user?.trim() ?? '';
    final pwd = monitor.pwd ?? '';
    try {
      final resp = await _object(
        '/api/v1/login',
        post: {'username': user, 'password': pwd},
      );
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

  /// Mints a read-only, independently revocable credential for a watch.
  /// The normal session token is never handed to the second device.
  Future<String> issueWatchToken(String clientId) {
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
      return token;
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

  /// Opens the agent's terminal endpoint and returns the raw WebSocket.
  ///
  /// The agent runs the shell itself; what travels here is PTY bytes and
  /// control JSON in the clear, so it refuses plaintext links that are not
  /// loopback. See `MonitorShellBackend` for the protocol spoken over it.
  Future<WebSocket> openTerminal({Duration? timeout}) =>
      _openWs(timeout: timeout);

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
  static Uri terminalWsUrl(String addr) => Uri.parse(addr)
      .replace(
        scheme: addr.toLowerCase().startsWith('https') ? 'wss' : 'ws',
        path: '/api/v1/terminal/ws',
        queryParameters: const <String, String>{},
      )
      .removeFragment();

  /// What the agent reads the ticket out of — `TICKET_PROTOCOL_PREFIX` in
  /// `monitor/src/api/ws/terminal.rs`, and `terminalWsProtocol` in the panel.
  /// All three have to say the same thing.
  @visibleForTesting
  static String terminalWsProtocol(String ticket) => 'sbm-ticket.$ticket';

  /// A browser can't put a bearer token on a WebSocket handshake, so the agent
  /// authorises upgrades with a short-lived, single-use ticket instead.
  Future<WebSocket> _openWs({Duration? timeout}) {
    return _authed(() async {
      final resp = await _object(
        '/api/v1/ws-ticket',
        post: const {'purpose': 'terminal'},
      );
      final ticket = resp['ticket'] as String?;
      if (ticket == null || ticket.isEmpty) {
        throw const MonitorHttpErr(
          type: MonitorHttpErrType.invalidResponse,
          message: 'Empty ticket in /api/v1/ws-ticket response',
        );
      }

      final socket =
          await WebSocket.connect(
            terminalWsUrl(_addr).toString(),
            // The ticket rides the subprotocol, not the query string. A URL is
            // what every access log, proxy and error message writes down, and
            // this one authorises a shell — the agent stopped reading
            // `?ticket=` for that reason and answers 401 to anything that
            // still sends it that way.
            protocols: [terminalWsProtocol(ticket)],
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
      return MonitorHttpErr(
        type: MonitorHttpErrType.net,
        message: e.toString(),
      );
    }
    if (e.response?.statusCode == 401) {
      return MonitorHttpErr(
        type: MonitorHttpErrType.auth,
        message: e.toString(),
      );
    }
    return MonitorHttpErr(
      type: MonitorHttpErrType.unknown,
      message: e.toString(),
    );
  }
}
