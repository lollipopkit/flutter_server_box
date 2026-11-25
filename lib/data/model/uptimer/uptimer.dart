import 'package:flutter/foundation.dart';

/// Supported Uptimer monitor probe kinds.
enum UptimerMonitorType {
  http('http'),
  tcp('tcp'),
  heartbeat('heartbeat');

  final String wire;
  const UptimerMonitorType(this.wire);

  static UptimerMonitorType fromWire(Object? value) => switch (value) {
    'http' => UptimerMonitorType.http,
    'tcp' => UptimerMonitorType.tcp,
    'heartbeat' => UptimerMonitorType.heartbeat,
    _ => UptimerMonitorType.http,
  };

  String get shortLabel => switch (this) {
    UptimerMonitorType.http => 'HTTP',
    UptimerMonitorType.tcp => 'TCP',
    UptimerMonitorType.heartbeat => 'Heartbeat',
  };
}

/// Live status of an Uptimer monitor.
enum UptimerMonitorStatus {
  up('up'),
  down('down'),
  maintenance('maintenance'),
  paused('paused'),
  unknown('unknown');

  final String wire;
  const UptimerMonitorStatus(this.wire);

  static UptimerMonitorStatus fromWire(Object? value) => switch (value) {
    'up' => UptimerMonitorStatus.up,
    'down' => UptimerMonitorStatus.down,
    'maintenance' => UptimerMonitorStatus.maintenance,
    'paused' => UptimerMonitorStatus.paused,
    _ => UptimerMonitorStatus.unknown,
  };
}

/// Time windows supported by Uptimer uptime & outage detail queries.
enum UptimerRange {
  h24('24h'),
  d7('7d'),
  d30('30d'),
  d90('90d');

  final String wire;
  const UptimerRange(this.wire);
}

int _asInt(Object? v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? _asIntOrNull(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _asDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool _asBool(Object? v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  return fallback;
}

String? _asNonEmptyString(Object? v) {
  if (v is! String) return null;
  final trimmed = v.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Preserves outer whitespace in pattern strings (e.g. response keywords)
/// while still treating empty or whitespace-only values as unset.
String? _asRawNonEmptyString(Object? v) {
  if (v is! String) return null;
  return v.trim().isEmpty ? null : v;
}

List<int> _asIntList(Object? v) {
  if (v is! List) return const [];
  return [for (final e in v) ?_asIntOrNull(e)];
}

Map<String, String>? _asStringMapOrNull(Object? v) {
  if (v is! Map) return null;
  final out = <String, String>{};
  for (final entry in v.entries) {
    final k = entry.key?.toString();
    final val = entry.value?.toString();
    if (k != null && k.isNotEmpty && val != null) out[k] = val;
  }
  return out.isEmpty ? null : Map.unmodifiable(out);
}

/// One check point returned in `heartbeats` or `latency.points`.
@immutable
final class UptimerHeartbeat {
  final int checkedAt;
  final String status;
  final int? latencyMs;

  const UptimerHeartbeat({
    required this.checkedAt,
    required this.status,
    this.latencyMs,
  });

  bool get isUp => status == 'up';
  bool get isDown => status == 'down';

  factory UptimerHeartbeat.fromJson(Map<String, dynamic> json) =>
      UptimerHeartbeat(
        checkedAt: _asInt(json['checked_at']),
        status: (json['status'] as String?) ?? 'unknown',
        latencyMs: _asIntOrNull(json['latency_ms']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UptimerHeartbeat &&
          other.checkedAt == checkedAt &&
          other.status == status &&
          other.latencyMs == latencyMs);

  @override
  int get hashCode => Object.hash(checkedAt, status, latencyMs);
}

/// Aggregated uptime statistics over a window or a single UTC day.
@immutable
final class UptimerTotals {
  final int totalSec;
  final int downtimeSec;
  final int unknownSec;
  final int uptimeSec;
  final double? uptimePct;

  const UptimerTotals({
    this.totalSec = 0,
    this.downtimeSec = 0,
    this.unknownSec = 0,
    this.uptimeSec = 0,
    this.uptimePct,
  });

  factory UptimerTotals.fromJson(Map<String, dynamic> json) => UptimerTotals(
    totalSec: _asInt(json['total_sec']),
    downtimeSec: _asInt(json['downtime_sec']),
    unknownSec: _asInt(json['unknown_sec']),
    uptimeSec: _asInt(json['uptime_sec']),
    uptimePct: _asDoubleOrNull(json['uptime_pct']),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UptimerTotals &&
          other.totalSec == totalSec &&
          other.downtimeSec == downtimeSec &&
          other.unknownSec == unknownSec &&
          other.uptimeSec == uptimeSec &&
          other.uptimePct == uptimePct);

  @override
  int get hashCode =>
      Object.hash(totalSec, downtimeSec, unknownSec, uptimeSec, uptimePct);
}

@immutable
final class UptimerDay {
  final int dayStartAt;
  final UptimerTotals totals;

  const UptimerDay({required this.dayStartAt, required this.totals});

  factory UptimerDay.fromJson(Map<String, dynamic> json) => UptimerDay(
    dayStartAt: _asInt(json['day_start_at']),
    totals: UptimerTotals.fromJson(json),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UptimerDay &&
          other.dayStartAt == dayStartAt &&
          other.totals == totals);

  @override
  int get hashCode => Object.hash(dayStartAt, totals);
}

/// Summary card entry returned by `GET /api/v1/me/page`.
@immutable
final class UptimerMonitorCard {
  final int id;
  final String name;
  final UptimerMonitorType type;
  final String? displayUrl;
  final String? groupName;
  final int groupSortOrder;
  final int sortOrder;
  final bool isPublic;
  final UptimerMonitorStatus status;
  final int? lastCheckedAt;
  final int? lastLatencyMs;
  final int? lastPingAt;

  /// Recent heartbeats in API order (newest first).
  final List<UptimerHeartbeat> heartbeats;
  final UptimerTotals uptime30d;
  final List<UptimerDay> uptimeDays;

  const UptimerMonitorCard({
    required this.id,
    required this.name,
    required this.type,
    this.displayUrl,
    this.groupName,
    this.groupSortOrder = 0,
    this.sortOrder = 0,
    this.isPublic = false,
    this.status = UptimerMonitorStatus.unknown,
    this.lastCheckedAt,
    this.lastLatencyMs,
    this.lastPingAt,
    this.heartbeats = const [],
    this.uptime30d = const UptimerTotals(),
    this.uptimeDays = const [],
  });

  /// Up to [limit] most recent heartbeats ordered oldest -> newest (left -> right).
  List<UptimerHeartbeat> recentChronological(int limit) {
    if (heartbeats.isEmpty || limit <= 0) return const [];
    final take = heartbeats.length < limit ? heartbeats.length : limit;
    return [for (var i = take - 1; i >= 0; i--) heartbeats[i]];
  }

  /// Display host/target label suitable for search and compact subtitles.
  String get displayAddr {
    final url = displayUrl;
    if (url != null && url.isNotEmpty) {
      final parsed = Uri.tryParse(url);
      if (parsed != null && parsed.host.isNotEmpty) {
        return parsed.hasPort ? '${parsed.host}:${parsed.port}' : parsed.host;
      }
      return url;
    }
    return type.shortLabel;
  }

  factory UptimerMonitorCard.fromJson(Map<String, dynamic> json) {
    final rawBeats = json['heartbeats'];
    final rawDays = json['uptime_days'];
    final rawUptime30 = json['uptime_30d'];
    return UptimerMonitorCard(
      id: _asInt(json['id']),
      name: (json['name'] as String?) ?? '',
      type: UptimerMonitorType.fromWire(json['type']),
      displayUrl: _asNonEmptyString(json['display_url']),
      groupName: _asNonEmptyString(json['group_name']),
      groupSortOrder: _asInt(json['group_sort_order']),
      sortOrder: _asInt(json['sort_order']),
      isPublic: _asBool(json['is_public']),
      status: UptimerMonitorStatus.fromWire(json['status']),
      lastCheckedAt: _asIntOrNull(json['last_checked_at']),
      lastLatencyMs: _asIntOrNull(json['last_latency_ms']),
      lastPingAt: _asIntOrNull(json['last_ping_at']),
      heartbeats: rawBeats is List
          ? List.unmodifiable([
              for (final e in rawBeats)
                if (e is Map<String, dynamic>) UptimerHeartbeat.fromJson(e),
            ])
          : const [],
      uptime30d: rawUptime30 is Map<String, dynamic>
          ? UptimerTotals.fromJson(rawUptime30)
          : const UptimerTotals(),
      uptimeDays: rawDays is List
          ? List.unmodifiable([
              for (final e in rawDays)
                if (e is Map<String, dynamic>) UptimerDay.fromJson(e),
            ])
          : const [],
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UptimerMonitorCard &&
          other.id == id &&
          other.name == name &&
          other.type == type &&
          other.displayUrl == displayUrl &&
          other.groupName == groupName &&
          other.groupSortOrder == groupSortOrder &&
          other.sortOrder == sortOrder &&
          other.isPublic == isPublic &&
          other.status == status &&
          other.lastCheckedAt == lastCheckedAt &&
          other.lastLatencyMs == lastLatencyMs &&
          other.lastPingAt == lastPingAt &&
          other.uptime30d == uptime30d &&
          listEquals(other.heartbeats, heartbeats) &&
          listEquals(other.uptimeDays, uptimeDays));

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    displayUrl,
    groupName,
    groupSortOrder,
    sortOrder,
    isPublic,
    status,
    lastCheckedAt,
    lastLatencyMs,
    lastPingAt,
    uptime30d,
    Object.hashAll(heartbeats),
    Object.hashAll(uptimeDays),
  );
}

/// One HTTP status code rule: either a single code (`200`) or an inclusive
/// range (`{"from": 200, "to": 299}`).
@immutable
final class UptimerStatusRule {
  final int from;
  final int to;

  const UptimerStatusRule(this.from, [int? to]) : to = to ?? from;

  bool get isRange => from != to;

  Object toJson() => isRange ? {'from': from, 'to': to} : from;

  String format() => isRange ? '$from-$to' : '$from';

  static UptimerStatusRule? fromJson(Object? raw) {
    if (raw is int || raw is num || raw is String) {
      final code = _asIntOrNull(raw);
      if (code != null && code >= 100 && code <= 599) {
        return UptimerStatusRule(code);
      }
      return null;
    }
    if (raw is Map) {
      final f = _asIntOrNull(raw['from']);
      final t = _asIntOrNull(raw['to']);
      if (f != null && t != null && f >= 100 && t <= 599 && f <= t) {
        return UptimerStatusRule(f, t);
      }
    }
    return null;
  }

  static List<UptimerStatusRule>? fromJsonList(Object? raw) {
    if (raw is! List) return null;
    final out = <UptimerStatusRule>[];
    for (final item in raw) {
      if (fromJson(item) case final rule?) out.add(rule);
    }
    return out.isEmpty ? null : List.unmodifiable(out);
  }

  /// Parses comma/whitespace-separated codes and ranges (`200, 201-204`).
  static List<UptimerStatusRule>? parseInput(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final out = <UptimerStatusRule>[];
    for (final part in trimmed.split(RegExp(r'[\s,]+'))) {
      if (part.isEmpty) continue;
      final dash = part.indexOf('-');
      final UptimerStatusRule rule;
      if (dash >= 0) {
        final left = int.tryParse(part.substring(0, dash));
        final right = int.tryParse(part.substring(dash + 1));
        if (left == null ||
            right == null ||
            left < 100 ||
            right > 599 ||
            left > right) {
          throw FormatException('Invalid HTTP status range: $part');
        }
        rule = UptimerStatusRule(left, right);
      } else {
        final code = int.tryParse(part);
        if (code == null || code < 100 || code > 599) {
          throw FormatException('Invalid HTTP status code: $part');
        }
        rule = UptimerStatusRule(code);
      }
      if (!out.contains(rule)) out.add(rule);
    }
    return out.isEmpty ? null : List.unmodifiable(out);
  }

  static String formatList(List<UptimerStatusRule>? rules) =>
      rules == null ? '' : rules.map((r) => r.format()).join(', ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UptimerStatusRule && other.from == from && other.to == to);

  @override
  int get hashCode => Object.hash(from, to);
}

/// Full editable monitor configuration returned by `/api/v1/me/monitors`.
@immutable
final class UptimerMonitorConfig {
  final int id;
  final String name;
  final UptimerMonitorType type;
  final String target;
  final String? displayUrl;
  final int intervalSec;
  final int timeoutMs;
  final int? graceSec;
  final int? lastPingAt;
  final String? httpMethod;
  final Map<String, String>? httpHeaders;
  final String? httpBody;
  final bool followRedirects;
  final List<UptimerStatusRule>? expectedStatus;
  final List<UptimerStatusRule>? forbiddenStatus;
  final String? responseKeyword;
  final String? responseKeywordMode;
  final String? responseForbiddenKeyword;
  final String? responseForbiddenKeywordMode;
  final String? groupName;
  final int groupSortOrder;
  final int sortOrder;
  final bool showOnStatusPage;
  final bool isActive;
  final UptimerMonitorStatus status;
  final int? lastCheckedAt;
  final int? lastLatencyMs;
  final String? lastError;

  const UptimerMonitorConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.target,
    this.displayUrl,
    this.intervalSec = 60,
    this.timeoutMs = 10000,
    this.graceSec,
    this.lastPingAt,
    this.httpMethod,
    this.httpHeaders,
    this.httpBody,
    this.followRedirects = true,
    this.expectedStatus,
    this.forbiddenStatus,
    this.responseKeyword,
    this.responseKeywordMode,
    this.responseForbiddenKeyword,
    this.responseForbiddenKeywordMode,
    this.groupName,
    this.groupSortOrder = 0,
    this.sortOrder = 0,
    this.showOnStatusPage = false,
    this.isActive = true,
    this.status = UptimerMonitorStatus.unknown,
    this.lastCheckedAt,
    this.lastLatencyMs,
    this.lastError,
  });

  factory UptimerMonitorConfig.fromJson(Map<String, dynamic> json) {
    return UptimerMonitorConfig(
      id: _asInt(json['id']),
      name: (json['name'] as String?) ?? '',
      type: UptimerMonitorType.fromWire(json['type']),
      target: (json['target'] as String?) ?? '',
      displayUrl: _asNonEmptyString(json['display_url']),
      intervalSec: _asInt(json['interval_sec'], 60),
      timeoutMs: _asInt(json['timeout_ms'], 10000),
      graceSec: _asIntOrNull(json['grace_sec']),
      lastPingAt: _asIntOrNull(json['last_ping_at']),
      httpMethod: _asNonEmptyString(json['http_method']),
      httpHeaders: _asStringMapOrNull(json['http_headers_json']),
      httpBody: json['http_body'] is String && (json['http_body'] as String).isNotEmpty
          ? json['http_body'] as String
          : null,
      followRedirects: _asBool(json['follow_redirects'], true),
      expectedStatus: UptimerStatusRule.fromJsonList(
        json['expected_status_json'],
      ),
      forbiddenStatus: UptimerStatusRule.fromJsonList(
        json['forbidden_status_json'],
      ),
      responseKeyword: _asRawNonEmptyString(json['response_keyword']),
      responseKeywordMode: _asNonEmptyString(json['response_keyword_mode']),
      responseForbiddenKeyword: _asRawNonEmptyString(
        json['response_forbidden_keyword'],
      ),
      responseForbiddenKeywordMode: _asNonEmptyString(
        json['response_forbidden_keyword_mode'],
      ),
      groupName: _asNonEmptyString(json['group_name']),
      groupSortOrder: _asInt(json['group_sort_order']),
      sortOrder: _asInt(json['sort_order']),
      showOnStatusPage: _asBool(json['show_on_status_page']),
      isActive: _asBool(json['is_active'], true),
      status: UptimerMonitorStatus.fromWire(json['status']),
      lastCheckedAt: _asIntOrNull(json['last_checked_at']),
      lastLatencyMs: _asIntOrNull(json['last_latency_ms']),
      lastError: _asNonEmptyString(json['last_error']),
    );
  }
}

@immutable
final class UptimerIncidentUpdate {
  final int id;
  final String status;
  final String message;
  final int createdAt;

  const UptimerIncidentUpdate({
    required this.id,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  factory UptimerIncidentUpdate.fromJson(Map<String, dynamic> json) =>
      UptimerIncidentUpdate(
        id: _asInt(json['id']),
        status: (json['status'] as String?) ?? '',
        message: (json['message'] as String?) ?? '',
        createdAt: _asInt(json['created_at']),
      );
}

@immutable
final class UptimerIncident {
  final int id;
  final String title;
  final String status;
  final String impact;
  final String? message;
  final int startedAt;
  final int? resolvedAt;
  final List<int> monitorIds;
  final List<UptimerIncidentUpdate> updates;

  const UptimerIncident({
    required this.id,
    required this.title,
    required this.status,
    required this.impact,
    this.message,
    required this.startedAt,
    this.resolvedAt,
    this.monitorIds = const [],
    this.updates = const [],
  });

  bool affectsMonitor(int monitorId) => monitorIds.contains(monitorId);

  factory UptimerIncident.fromJson(Map<String, dynamic> json) {
    final rawUpdates = json['updates'];
    return UptimerIncident(
      id: _asInt(json['id']),
      title: (json['title'] as String?) ?? '',
      status: (json['status'] as String?) ?? '',
      impact: (json['impact'] as String?) ?? 'minor',
      message: _asNonEmptyString(json['message']),
      startedAt: _asInt(json['started_at']),
      resolvedAt: _asIntOrNull(json['resolved_at']),
      monitorIds: List.unmodifiable(_asIntList(json['monitor_ids'])),
      updates: rawUpdates is List
          ? List.unmodifiable([
              for (final u in rawUpdates)
                if (u is Map<String, dynamic>)
                  UptimerIncidentUpdate.fromJson(u),
            ])
          : const [],
    );
  }
}

@immutable
final class UptimerMaintenanceWindow {
  final int id;
  final String title;
  final String? message;
  final int startsAt;
  final int endsAt;
  final List<int> monitorIds;

  const UptimerMaintenanceWindow({
    required this.id,
    required this.title,
    this.message,
    required this.startsAt,
    required this.endsAt,
    this.monitorIds = const [],
  });

  bool affectsMonitor(int monitorId) => monitorIds.contains(monitorId);

  factory UptimerMaintenanceWindow.fromJson(Map<String, dynamic> json) =>
      UptimerMaintenanceWindow(
        id: _asInt(json['id']),
        title: (json['title'] as String?) ?? '',
        message: _asNonEmptyString(json['message']),
        startsAt: _asInt(json['starts_at']),
        endsAt: _asInt(json['ends_at']),
        monitorIds: List.unmodifiable(_asIntList(json['monitor_ids'])),
      );
}

/// Full status-page snapshot returned by `GET /api/v1/me/page`.
@immutable
final class UptimerPageData {
  final int generatedAt;
  final String overallStatus;
  final List<UptimerMonitorCard> monitors;
  final List<UptimerIncident> activeIncidents;
  final List<UptimerMaintenanceWindow> activeMaintenance;
  final List<UptimerMaintenanceWindow> upcomingMaintenance;
  final Map<int, List<UptimerIncident>> _incidentsByMonitor;
  final Map<int, List<UptimerMaintenanceWindow>> _activeMaintByMonitor;
  final Map<int, List<UptimerMaintenanceWindow>> _upcomingMaintByMonitor;

  const UptimerPageData._({
    required this.generatedAt,
    required this.overallStatus,
    required this.monitors,
    required this.activeIncidents,
    required this.activeMaintenance,
    required this.upcomingMaintenance,
    required this._incidentsByMonitor,
    required this._activeMaintByMonitor,
    required this._upcomingMaintByMonitor,
  });

  factory UptimerPageData({
    required int generatedAt,
    required String overallStatus,
    List<UptimerMonitorCard> monitors = const [],
    List<UptimerIncident> activeIncidents = const [],
    List<UptimerMaintenanceWindow> activeMaintenance = const [],
    List<UptimerMaintenanceWindow> upcomingMaintenance = const [],
  }) => UptimerPageData._(
    generatedAt: generatedAt,
    overallStatus: overallStatus,
    monitors: monitors,
    activeIncidents: activeIncidents,
    activeMaintenance: activeMaintenance,
    upcomingMaintenance: upcomingMaintenance,
    incidentsByMonitor: _indexByMonitor(activeIncidents, (i) => i.monitorIds),
    activeMaintByMonitor: _indexByMonitor(
      activeMaintenance,
      (w) => w.monitorIds,
    ),
    upcomingMaintByMonitor: _indexByMonitor(
      upcomingMaintenance,
      (w) => w.monitorIds,
    ),
  );

  static Map<int, List<T>> _indexByMonitor<T>(
    List<T> items,
    List<int> Function(T) idsOf,
  ) {
    if (items.isEmpty) return const {};
    final map = <int, List<T>>{};
    for (final item in items) {
      for (final id in idsOf(item)) {
        (map[id] ??= <T>[]).add(item);
      }
    }
    return Map<int, List<T>>.unmodifiable({
      for (final e in map.entries) e.key: List<T>.unmodifiable(e.value),
    });
  }

  /// Stable unmodifiable list for [monitorId] so Riverpod `.select()`
  /// deduplicates without reallocating on unrelated state changes.
  List<UptimerIncident> incidentsFor(int monitorId) =>
      _incidentsByMonitor[monitorId] ?? const [];

  List<UptimerMaintenanceWindow> activeMaintenanceFor(int monitorId) =>
      _activeMaintByMonitor[monitorId] ?? const [];

  List<UptimerMaintenanceWindow> upcomingMaintenanceFor(int monitorId) =>
      _upcomingMaintByMonitor[monitorId] ?? const [];

  factory UptimerPageData.fromJson(Map<String, dynamic> json) {
    final rawMonitors = json['monitors'];
    final rawIncidents = json['active_incidents'];
    final rawMaint = json['maintenance_windows'];
    final rawActive = rawMaint is Map ? rawMaint['active'] : null;
    final rawUpcoming = rawMaint is Map ? rawMaint['upcoming'] : null;
    return UptimerPageData(
      generatedAt: _asInt(json['generated_at']),
      overallStatus: (json['overall_status'] as String?) ?? 'unknown',
      monitors: rawMonitors is List
          ? List.unmodifiable([
              for (final m in rawMonitors)
                if (m is Map<String, dynamic>) UptimerMonitorCard.fromJson(m),
            ])
          : const [],
      activeIncidents: rawIncidents is List
          ? List.unmodifiable([
              for (final i in rawIncidents)
                if (i is Map<String, dynamic>) UptimerIncident.fromJson(i),
            ])
          : const [],
      activeMaintenance: rawActive is List
          ? List.unmodifiable([
              for (final w in rawActive)
                if (w is Map<String, dynamic>)
                  UptimerMaintenanceWindow.fromJson(w),
            ])
          : const [],
      upcomingMaintenance: rawUpcoming is List
          ? List.unmodifiable([
              for (final w in rawUpcoming)
                if (w is Map<String, dynamic>)
                  UptimerMaintenanceWindow.fromJson(w),
            ])
          : const [],
    );
  }
}

/// 24-hour latency series returned by `GET /api/v1/me/monitors/:id/latency`.
@immutable
final class UptimerLatencyData {
  final int rangeStartAt;
  final int rangeEndAt;
  final int? avgLatencyMs;
  final int? p95LatencyMs;

  /// Chronological points (oldest -> newest).
  final List<UptimerHeartbeat> points;

  const UptimerLatencyData({
    required this.rangeStartAt,
    required this.rangeEndAt,
    this.avgLatencyMs,
    this.p95LatencyMs,
    this.points = const [],
  });

  factory UptimerLatencyData.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return UptimerLatencyData(
      rangeStartAt: _asInt(json['range_start_at']),
      rangeEndAt: _asInt(json['range_end_at']),
      avgLatencyMs: _asIntOrNull(json['avg_latency_ms']),
      p95LatencyMs: _asIntOrNull(json['p95_latency_ms']),
      points: rawPoints is List
          ? List.unmodifiable([
              for (final p in rawPoints)
                if (p is Map<String, dynamic>) UptimerHeartbeat.fromJson(p),
            ])
          : const [],
    );
  }
}

@immutable
final class UptimerOutage {
  final int id;
  final int monitorId;
  final int startedAt;
  final int? endedAt;
  final String? initialError;
  final String? lastError;

  const UptimerOutage({
    required this.id,
    required this.monitorId,
    required this.startedAt,
    this.endedAt,
    this.initialError,
    this.lastError,
  });

  bool get ongoing => endedAt == null;

  String? get errorSummary => lastError ?? initialError;

  factory UptimerOutage.fromJson(Map<String, dynamic> json) => UptimerOutage(
    id: _asInt(json['id']),
    monitorId: _asInt(json['monitor_id']),
    startedAt: _asInt(json['started_at']),
    endedAt: _asIntOrNull(json['ended_at']),
    initialError: _asNonEmptyString(json['initial_error']),
    lastError: _asNonEmptyString(json['last_error']),
  );
}

@immutable
final class UptimerOutagesPage {
  final List<UptimerOutage> outages;
  final int? nextCursor;

  const UptimerOutagesPage({required this.outages, this.nextCursor});

  factory UptimerOutagesPage.fromJson(Map<String, dynamic> json) {
    final raw = json['outages'];
    return UptimerOutagesPage(
      outages: raw is List
          ? List.unmodifiable([
              for (final o in raw)
                if (o is Map<String, dynamic>) UptimerOutage.fromJson(o),
            ])
          : const [],
      nextCursor: _asIntOrNull(json['next_cursor']),
    );
  }
}

@immutable
final class UptimerTestResult {
  final String status;
  final int? latencyMs;
  final int? httpStatus;
  final String? error;
  final int attempts;

  const UptimerTestResult({
    required this.status,
    this.latencyMs,
    this.httpStatus,
    this.error,
    this.attempts = 1,
  });

  bool get isUp => status == 'up';

  factory UptimerTestResult.fromJson(Map<String, dynamic> json) {
    final raw = json['result'] is Map<String, dynamic>
        ? json['result'] as Map<String, dynamic>
        : json;
    return UptimerTestResult(
      status: (raw['status'] as String?) ?? 'unknown',
      latencyMs: _asIntOrNull(raw['latency_ms']),
      httpStatus: _asIntOrNull(raw['http_status']),
      error: _asNonEmptyString(raw['error']),
      attempts: _asInt(raw['attempts'], 1),
    );
  }
}

@immutable
final class UptimerAccountQuota {
  final int? maxMonitors;
  final int? minIntervalSec;
  final int usedMonitors;

  const UptimerAccountQuota({
    this.maxMonitors,
    this.minIntervalSec,
    this.usedMonitors = 0,
  });

  factory UptimerAccountQuota.fromJson(Map<String, dynamic> json) {
    final quota = json['quota'] is Map<String, dynamic>
        ? json['quota'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final usage = json['usage'] is Map<String, dynamic>
        ? json['usage'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return UptimerAccountQuota(
      maxMonitors: _asIntOrNull(quota['max_monitors']),
      minIntervalSec: _asIntOrNull(quota['min_interval_sec']),
      usedMonitors: _asInt(usage['monitors']),
    );
  }
}

@immutable
final class UptimerMonitorMutation {
  final UptimerMonitorConfig monitor;
  final String? pushToken;

  const UptimerMonitorMutation({required this.monitor, this.pushToken});

  factory UptimerMonitorMutation.fromJson(Map<String, dynamic> json) {
    final rawMonitor = json['monitor'];
    if (rawMonitor is! Map<String, dynamic>) {
      throw const FormatException('Missing monitor in Uptimer response');
    }
    return UptimerMonitorMutation(
      monitor: UptimerMonitorConfig.fromJson(rawMonitor),
      pushToken: _asNonEmptyString(json['push_token']),
    );
  }
}
