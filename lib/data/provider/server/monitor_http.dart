import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_metrics.dart';

/// Talks to one server's `monitor` HTTP API. One instance is owned per
/// `ServerNotifier` (see `single.dart`), mirroring how `PveNotifier` owns its
/// own `Dio` session in `pve.dart` — but simpler, since monitor is meant to
/// be reached directly over HTTPS rather than tunneled through an SSH
/// forward like PVE.
class MonitorHttpClient {
  MonitorHttpClient(this.credential);

  final ServerConnectCredentialMonitorHttp credential;

  Dio? _dio;
  String? _token;

  String get _addr {
    final addr = credential.monitor.addr.trim();
    return addr.endsWith('/') ? addr.substring(0, addr.length - 1) : addr;
  }

  Dio _session() {
    final existing = _dio;
    if (existing != null) return existing;
    final ignoreCert = credential.monitor.ignoreCert;
    final dio = Dio(BaseOptions(baseUrl: _addr))
      ..httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          if (ignoreCert) {
            client.badCertificateCallback = (_, _, _) => true;
          }
          return client;
        },
        validateCertificate: ignoreCert ? (_, _, _) => true : null,
      );
    _dio = dio;
    return dio;
  }

  Future<void> _login() async {
    final user = credential.monitor.user?.trim() ?? '';
    final pwd = credential.monitor.pwd ?? '';
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
      final resp = await _session().get<Map<String, dynamic>>(
        '/api/v1/metrics/history',
        queryParameters: {'minutes': minutes},
      );
      final points = resp.data?['points'] ?? resp.data?['data'];
      if (points is! List) {
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

  void dispose() {
    _dio?.close(force: true);
    _dio = null;
    _token = null;
  }

  /// Whether this client was built from the same monitor connection config
  /// as [other] — used to decide whether a cached client can be reused
  /// across refreshes or must be rebuilt (and re-logged-in) instead.
  bool matches(ServerConnectCredentialMonitorHttp other) {
    return credential.monitor == other.monitor;
  }

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
