import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/uptimer/uptimer.dart';

const kUptimerHttpMethods = ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'];
const kUptimerIntervalPresets = [60, 180, 300, 900, 3600];
const kUptimerMaxGraceSec = 86400;
const kUptimerMaxGroupLen = 64;

/// Text controllers owned by [UptimerEditPage], grouped so hydration,
/// validation, and disposal stay in one place.
final class UptimerEditControllers {
  final name = TextEditingController();
  final target = TextEditingController();
  final displayUrl = TextEditingController();
  final interval = TextEditingController(text: '60');
  final timeout = TextEditingController(text: '10000');
  final grace = TextEditingController(text: '60');
  final expectedStatus = TextEditingController();
  final forbiddenStatus = TextEditingController();
  final body = TextEditingController();
  final keyword = TextEditingController();
  final forbiddenKeyword = TextEditingController();

  void applyConfig(UptimerMonitorConfig cfg) {
    name.text = cfg.name;
    target.text = cfg.target;
    displayUrl.text = cfg.displayUrl ?? '';
    interval.text = '${cfg.intervalSec}';
    timeout.text = '${cfg.timeoutMs}';
    grace.text = '${cfg.graceSec ?? 60}';
    body.text = cfg.httpBody ?? '';
    expectedStatus.text = UptimerStatusRule.formatList(cfg.expectedStatus);
    forbiddenStatus.text = UptimerStatusRule.formatList(cfg.forbiddenStatus);
    keyword.text = cfg.responseKeyword ?? '';
    forbiddenKeyword.text = cfg.responseForbiddenKeyword ?? '';
  }

  void dispose() {
    name.dispose();
    target.dispose();
    displayUrl.dispose();
    interval.dispose();
    timeout.dispose();
    grace.dispose();
    expectedStatus.dispose();
    forbiddenStatus.dispose();
    body.dispose();
    keyword.dispose();
    forbiddenKeyword.dispose();
  }
}

/// Validates a TCP monitor target (`host:port` or `[ipv6]:port`, port 1..65535).
bool isValidUptimerTcpTarget(String target) {
  final trimmed = target.trim();
  if (trimmed.isEmpty || RegExp(r'\s').hasMatch(trimmed)) return false;
  final String host;
  final String portStr;
  if (trimmed.startsWith('[')) {
    final close = trimmed.indexOf(']:');
    if (close <= 1 || close + 2 >= trimmed.length) return false;
    host = trimmed.substring(1, close);
    portStr = trimmed.substring(close + 2);
    if (host.contains('[') || host.contains(']')) return false;
    try {
      Uri.parseIPv6Address(host);
    } on FormatException {
      return false;
    }
  } else {
    if (trimmed.contains('[') || trimmed.contains(']')) return false;
    final first = trimmed.indexOf(':');
    final last = trimmed.lastIndexOf(':');
    if (first <= 0 || first != last || last + 1 >= trimmed.length) {
      return false;
    }
    host = trimmed.substring(0, first);
    portStr = trimmed.substring(first + 1);
  }
  if (host.isEmpty) return false;
  if (!RegExp(r'^\d+$').hasMatch(portStr)) return false;
  final port = int.tryParse(portStr);
  return port != null && port >= 1 && port <= 65535;
}

/// Drops empty-key header entries and trims keys and values.
Map<String, String> sanitizeUptimerHeaders(Map<String, String> raw) => {
  for (final entry in raw.entries)
    if (entry.key.trim().isNotEmpty) entry.key.trim(): entry.value.trim(),
};

String? _validateTarget(UptimerMonitorType type, String target) {
  if (type == UptimerMonitorType.heartbeat) return null;
  if (target.isEmpty) return '${l10n.uptimerTarget}: ${libL10n.empty}';
  if (type == UptimerMonitorType.http) {
    final uri = Uri.tryParse(target);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return '${l10n.uptimerTarget}: http(s)://...';
    }
    return null;
  }
  if (!isValidUptimerTcpTarget(target)) {
    return '${l10n.uptimerTarget}: host:port / [ipv6]:port';
  }
  return null;
}

/// Validates edit-form values and builds the API mutation payload.
///
/// Returns either a non-null `payload` or a localized validation `error`.
({Map<String, dynamic>? payload, String? error})
validateAndBuildUptimerPayload({
  required bool isEditing,
  required UptimerMonitorType type,
  required UptimerEditControllers ctrls,
  required String rawGroupName,
  required int minInterval,
  required bool showOnStatusPage,
  required bool submittedActive,
  required bool initialIsActive,
  required bool initialWasPaused,
  required String httpMethod,
  required bool followRedirects,
  required Map<String, String> rawHeaders,
  required String keywordMode,
  required String forbiddenKeywordMode,
}) {
  final name = ctrls.name.text.trim();
  if (name.isEmpty) {
    return (payload: null, error: '${libL10n.name}: ${libL10n.empty}');
  }

  final target = ctrls.target.text.trim();
  if (_validateTarget(type, target) case final err?) {
    return (payload: null, error: err);
  }

  final groupName = rawGroupName.trim();
  if (groupName.length > kUptimerMaxGroupLen) {
    return (
      payload: null,
      error: '${l10n.uptimerGroup} <= $kUptimerMaxGroupLen',
    );
  }

  final displayUrl = ctrls.displayUrl.text.trim();
  if (displayUrl.isNotEmpty) {
    final uri = Uri.tryParse(displayUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return (payload: null, error: '${l10n.uptimerDisplayUrl}: http(s)://...');
    }
  }

  final intervalSec = int.tryParse(ctrls.interval.text.trim());
  if (intervalSec == null || intervalSec < minInterval) {
    return (
      payload: null,
      error:
          '${l10n.uptimerInterval}: ${l10n.uptimerMinIntervalHint(minInterval)}',
    );
  }

  int? timeoutMs;
  int? graceSec;
  if (type == UptimerMonitorType.heartbeat) {
    final g = ctrls.grace.text.trim();
    graceSec = g.isEmpty ? 60 : int.tryParse(g);
    if (graceSec == null || graceSec < 0 || graceSec > kUptimerMaxGraceSec) {
      return (
        payload: null,
        error: '${l10n.uptimerGracePeriod}: 0..$kUptimerMaxGraceSec',
      );
    }
  } else {
    timeoutMs = int.tryParse(ctrls.timeout.text.trim());
    if (timeoutMs == null || timeoutMs < 1000) {
      return (payload: null, error: '${l10n.uptimerTimeout} >= 1000 ms');
    }
  }

  List<UptimerStatusRule>? expectedStatus;
  List<UptimerStatusRule>? forbiddenStatus;
  Map<String, String>? headers;
  final rawKeyword = ctrls.keyword.text;
  final rawForbiddenKeyword = ctrls.forbiddenKeyword.text;
  final rawBody = ctrls.body.text;
  // Preserve outer whitespace in keyword patterns; trim only for emptiness.
  final hasKeyword = rawKeyword.trim().isNotEmpty;
  final hasForbiddenKeyword = rawForbiddenKeyword.trim().isNotEmpty;
  if (type == UptimerMonitorType.http) {
    try {
      expectedStatus = UptimerStatusRule.parseInput(ctrls.expectedStatus.text);
      forbiddenStatus = UptimerStatusRule.parseInput(
        ctrls.forbiddenStatus.text,
      );
      final cleanHeaders = sanitizeUptimerHeaders(rawHeaders);
      headers = cleanHeaders.isEmpty ? null : cleanHeaders;
      if (hasKeyword && keywordMode == 'regex') RegExp(rawKeyword);
      if (hasForbiddenKeyword && forbiddenKeywordMode == 'regex') {
        RegExp(rawForbiddenKeyword);
      }
    } on FormatException catch (e) {
      return (payload: null, error: e.message);
    }
  }

  final payload = <String, dynamic>{
    'name': name,
    if (!isEditing) 'type': type.wire,
    if (type != UptimerMonitorType.heartbeat) 'target': target,
    'display_url': displayUrl.isEmpty ? null : displayUrl,
    'interval_sec': intervalSec,
    if (type == UptimerMonitorType.heartbeat)
      'grace_sec': graceSec
    else
      'timeout_ms': timeoutMs,
    'group_name': groupName.isEmpty ? null : groupName,
    'show_on_status_page': showOnStatusPage,
    if (isEditing &&
        submittedActive != initialIsActive &&
        (submittedActive || initialWasPaused))
      'is_active': submittedActive,
    if (type == UptimerMonitorType.http) ...{
      'http_method': httpMethod,
      'follow_redirects': followRedirects,
      if (isEditing || expectedStatus != null)
        'expected_status_json': expectedStatus?.map((r) => r.toJson()).toList(),
      if (isEditing || forbiddenStatus != null)
        'forbidden_status_json': forbiddenStatus
            ?.map((r) => r.toJson())
            .toList(),
      if (isEditing || headers != null) 'http_headers_json': headers,
      if (httpMethod != 'GET' && httpMethod != 'HEAD')
        'http_body': rawBody.isEmpty ? null : rawBody
      else if (isEditing)
        'http_body': null,
      if (isEditing || hasKeyword) ...{
        'response_keyword': hasKeyword ? rawKeyword : null,
        'response_keyword_mode': hasKeyword ? keywordMode : null,
      },
      if (isEditing || hasForbiddenKeyword) ...{
        'response_forbidden_keyword': hasForbiddenKeyword
            ? rawForbiddenKeyword
            : null,
        'response_forbidden_keyword_mode': hasForbiddenKeyword
            ? forbiddenKeywordMode
            : null,
      },
    },
  };
  if (!isEditing) {
    payload.removeWhere((_, v) => v == null);
  }
  return (payload: payload, error: null);
}
