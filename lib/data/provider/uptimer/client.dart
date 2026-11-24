import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:server_box/core/lkc.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';

/// Authenticated HTTP transport callback targeting the user's Uptimer service.
typedef UptimerTransport =
    Future<Object?> Function(
      String method,
      String path, {
      Map<String, dynamic>? query,
      Object? body,
    });

/// Typed client for the authenticated `/api/v1/me/...` Uptimer API.
final class UptimerApi {
  final UptimerTransport _call;
  final Uri Function(String token) _pushUrlOf;

  UptimerApi({
    UptimerTransport? call,
    Uri Function(String token)? pushUrlOf,
  }) : _call = call ?? _defaultCall,
       _pushUrlOf = pushUrlOf ?? _defaultPushUrl;

  static Future<Object?> _defaultCall(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) => Lkc.client.uptimerCall(method, path, query: query, body: body);

  static Uri _defaultPushUrl(String token) => Lkc.client.uptimerPushUrl(token);

  Uri pushUrl(String token) => _pushUrlOf(token);

  Future<UptimerPageData> fetchPage() async {
    final raw = await _call('GET', '/api/v1/me/page');
    return UptimerPageData.fromJson(_asMap(raw));
  }

  Future<List<UptimerMonitorConfig>> listMonitors({int limit = 200}) async {
    final raw = await _call(
      'GET',
      '/api/v1/me/monitors',
      query: {'limit': limit},
    );
    final map = _asMap(raw);
    final items = map['monitors'];
    if (items is! List) return const [];
    return [
      for (final item in items)
        if (item is Map<String, dynamic>) UptimerMonitorConfig.fromJson(item),
    ];
  }

  Future<UptimerAccountQuota> fetchAccount() async {
    final raw = await _call('GET', '/api/v1/me');
    return UptimerAccountQuota.fromJson(_asMap(raw));
  }

  Future<UptimerLatencyData> fetchLatency(int id) async {
    final raw = await _call('GET', '/api/v1/me/monitors/$id/latency');
    return UptimerLatencyData.fromJson(_asMap(raw));
  }

  Future<UptimerTotals> fetchUptime(int id, UptimerRange range) async {
    final raw = await _call(
      'GET',
      '/api/v1/me/monitors/$id/uptime',
      query: {'range': range.wire},
    );
    return UptimerTotals.fromJson(_asMap(raw));
  }

  Future<UptimerOutagesPage> fetchOutages(
    int id, {
    UptimerRange range = UptimerRange.d30,
    int limit = 20,
    int? cursor,
  }) async {
    final raw = await _call(
      'GET',
      '/api/v1/me/monitors/$id/outages',
      query: {
        'range': range.wire,
        'limit': limit,
        'cursor': ?cursor,
      },
    );
    return UptimerOutagesPage.fromJson(_asMap(raw));
  }

  Future<UptimerMonitorMutation> createMonitor(
    Map<String, dynamic> body,
  ) async {
    final raw = await _call('POST', '/api/v1/me/monitors', body: body);
    return UptimerMonitorMutation.fromJson(_asMap(raw));
  }

  Future<UptimerMonitorConfig> updateMonitor(
    int id,
    Map<String, dynamic> body,
  ) async {
    final raw = await _call('PATCH', '/api/v1/me/monitors/$id', body: body);
    return UptimerMonitorMutation.fromJson(_asMap(raw)).monitor;
  }

  Future<void> deleteMonitor(int id) async {
    await _call('DELETE', '/api/v1/me/monitors/$id');
  }

  Future<UptimerTestResult> testMonitor(int id) async {
    final raw = await _call('POST', '/api/v1/me/monitors/$id/test');
    return UptimerTestResult.fromJson(_asMap(raw));
  }

  Future<UptimerMonitorConfig> pauseMonitor(int id) async {
    final raw = await _call('POST', '/api/v1/me/monitors/$id/pause');
    return UptimerMonitorMutation.fromJson(_asMap(raw)).monitor;
  }

  Future<UptimerMonitorConfig> resumeMonitor(int id) async {
    final raw = await _call('POST', '/api/v1/me/monitors/$id/resume');
    return UptimerMonitorMutation.fromJson(_asMap(raw)).monitor;
  }

  Future<UptimerMonitorMutation> rotatePushToken(int id) async {
    final raw = await _call('POST', '/api/v1/me/monitors/$id/push-token');
    return UptimerMonitorMutation.fromJson(_asMap(raw));
  }

  Future<void> assignGroup(List<int> monitorIds, String? groupName) async {
    if (monitorIds.isEmpty) return;
    await _call(
      'POST',
      '/api/v1/me/monitors/groups/assign',
      body: {'monitor_ids': monitorIds, 'group_name': groupName},
    );
  }

  static Map<String, dynamic> _asMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return {for (final e in raw.entries) '${e.key}': e.value};
    }
    throw const FormatException('Expected JSON object from Uptimer');
  }
}

/// Injectable Uptimer API provider (override in tests).
final uptimerApiProvider = Provider<UptimerApi>((_) => UptimerApi());
