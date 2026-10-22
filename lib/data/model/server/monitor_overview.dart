/// What a `monitor` agent says about itself beyond its readings, for the
/// Monitor tab: the rules firing now, its notifications, its audit log, and
/// what is signed in to it and open on it.
library;

DateTime? _time(Object? raw) => raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

DateTime? _unix(Object? raw) =>
    raw is num ? DateTime.fromMillisecondsSinceEpoch(raw.toInt() * 1000) : null;

String _str(Object? raw) => raw is String ? raw : '';

String? _opt(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

List<Map<String, dynamic>> _rows(Object? raw) => [
  for (final row in raw is List ? raw : const [])
    if (row is Map<String, dynamic>) row,
];

/// How an agent was put on its machine, which decides how it is updated
/// (`sbm_parser::monitor_agent::InstallKind`).
enum MonitorInstall {
  /// By `install.sh`: its upgrade command updates it.
  script,

  /// In a container: a new image and a new container.
  container,

  /// By the NixOS module: the system's configuration.
  nix,

  /// Anything else, or a name this app does not know.
  other;

  static MonitorInstall parse(Object? raw) => values.firstWhere((v) => v.name == raw, orElse: () => other);
}

/// Whether a newer agent is released, as the agent read it
/// (`GET /api/v1/update`).
class MonitorUpdate {
  const MonitorUpdate({
    required this.version,
    this.latest,
    this.outdated = false,
    this.checkedAt,
    this.error,
    this.install = MonitorInstall.other,
    this.command,
    this.needsPassword = false,
    this.run,
  });

  /// The agent's own version.
  final String version;

  /// The newest release; null when the agent could not read it.
  final String? latest;
  final bool outdated;
  final DateTime? checkedAt;

  /// Why the releases could not be read.
  final String? error;
  final MonitorInstall install;

  /// What updates it, run on its machine: only for [MonitorInstall.script].
  final String? command;

  /// Whether starting the update needs the sudo password.
  final bool needsPassword;

  /// The last update started on the agent (`POST /api/v1/update/run`).
  final MonitorUpdateRun? run;

  factory MonitorUpdate.fromJson(Map<String, dynamic> json) => MonitorUpdate(
    version: _str(json['version']),
    latest: _opt(json['latest']),
    outdated: json['outdated'] == true,
    checkedAt: _time(json['checked_at']),
    error: _opt(json['error']),
    install: MonitorInstall.parse(json['install']),
    command: _opt(json['command']),
    needsPassword: json['needs_password'] == true,
    run: json['run'] is Map<String, dynamic> ? MonitorUpdateRun.fromJson(json['run'] as Map<String, dynamic>) : null,
  );
}

enum MonitorUpdateRunState {
  running,
  done,
  failed,

  /// No end was recorded, and too long ago to be running still.
  interrupted;

  static MonitorUpdateRunState parse(Object? raw) => values.firstWhere((v) => v.name == raw, orElse: () => interrupted);
}

/// An update the agent started, as its log tells it.
class MonitorUpdateRun {
  const MonitorUpdateRun({required this.state, this.startedAt, this.exit, this.lines = const []});

  final MonitorUpdateRunState state;
  final DateTime? startedAt;

  /// The installer's exit status, once it ended.
  final int? exit;

  /// What the installer said.
  final List<String> lines;

  factory MonitorUpdateRun.fromJson(Map<String, dynamic> json) => MonitorUpdateRun(
    state: MonitorUpdateRunState.parse(json['state']),
    startedAt: _time(json['started_at']),
    exit: json['exit'] is num ? (json['exit'] as num).toInt() : null,
    lines: [for (final line in json['lines'] is List ? json['lines'] as List : const []) if (line is String) line],
  );
}

/// A monitoring rule over its threshold at the agent's last check
/// (`GET /api/v1/alerts`).
class MonitorAlert {
  const MonitorAlert({
    required this.rule,
    required this.monitorType,
    required this.matcher,
    required this.threshold,
    required this.value,
    this.since,
  });

  final String rule;

  /// As configured: `cpu`, `mem`, `disk`, …
  final String monitorType;
  final String matcher;
  final String threshold;

  /// The reading that crossed it, formatted as the rule compares it.
  final String value;

  /// Firing without a break since.
  final DateTime? since;

  factory MonitorAlert.fromJson(Map<String, dynamic> json) => MonitorAlert(
    rule: _str(json['rule']),
    monitorType: _str(json['monitor_type']),
    matcher: _str(json['matcher']),
    threshold: _str(json['threshold']),
    value: _str(json['value']),
    since: _time(json['since']),
  );
}

class MonitorAlerts {
  const MonitorAlerts({this.checkedAt, this.alerts = const []});

  /// Null before the agent's first check.
  final DateTime? checkedAt;
  final List<MonitorAlert> alerts;

  factory MonitorAlerts.fromJson(Map<String, dynamic> json) => MonitorAlerts(
    checkedAt: _time(json['checked_at']),
    alerts: [for (final row in _rows(json['alerts'])) MonitorAlert.fromJson(row)],
  );
}

/// One of the agent's notifications (`GET /api/v1/desk/notifications`).
///
/// [kind] and [params] say it in a form a client words in its own language;
/// [subject] and [body] are the agent's English, for a kind this app does not
/// know and for rows written before kinds.
class MonitorNotice {
  const MonitorNotice({
    required this.id,
    required this.level,
    required this.source,
    required this.subject,
    required this.body,
    required this.read,
    this.createdAt,
    this.kind,
    this.params = const {},
  });

  final int id;
  final DateTime? createdAt;

  /// `info`, `warning` or `error`.
  final String level;

  /// `alert`, `stack`, `storage`, …
  final String source;
  final String subject;
  final String body;
  final String? kind;
  final Map<String, dynamic> params;
  final bool read;

  factory MonitorNotice.fromJson(Map<String, dynamic> json) => MonitorNotice(
    id: (json['id'] as num?)?.toInt() ?? 0,
    createdAt: _time(json['created_at']),
    level: _str(json['level']),
    source: _str(json['source']),
    subject: _str(json['subject']),
    body: _str(json['body']),
    kind: _opt(json['kind']),
    params: json['params'] is Map<String, dynamic> ? json['params'] as Map<String, dynamic> : const {},
    read: json['read'] == true,
  );

  MonitorNotice markedRead() => MonitorNotice(
    id: id,
    createdAt: createdAt,
    level: level,
    source: source,
    subject: subject,
    body: body,
    kind: kind,
    params: params,
    read: true,
  );

  String param(String key) => switch (params[key]) {
    final String value => value,
    final num value => value.toString(),
    _ => '',
  };

  List<String> paramList(String key) => [...?(params[key] as List?)?.whereType<String>()];
}

class MonitorNotices {
  const MonitorNotices({this.notices = const [], this.unread = 0});

  /// Newest first.
  final List<MonitorNotice> notices;
  final int unread;

  factory MonitorNotices.fromJson(Map<String, dynamic> json) => MonitorNotices(
    notices: [for (final row in _rows(json['notifications'])) MonitorNotice.fromJson(row)],
    unread: (json['unread'] as num?)?.toInt() ?? 0,
  );
}

/// A row of the agent's audit log (`GET /api/v1/audit`).
class MonitorAuditEntry {
  const MonitorAuditEntry({
    required this.id,
    required this.kind,
    required this.action,
    required this.result,
    this.at,
    this.subject,
    this.remoteIp,
    this.systemUser,
    this.detail,
  });

  final int id;
  final DateTime? at;

  /// `login`, `terminal`, `exec`, `fs`, … ([MonitorAuditKind.all]).
  final String kind;
  final String action;

  /// `ok`, `denied` or `error`.
  final String result;

  /// What it was about, in the kind's terms.
  final String? subject;
  final String? remoteIp;

  /// The system account a terminal session ran as.
  final String? systemUser;
  final String? detail;

  factory MonitorAuditEntry.fromJson(Map<String, dynamic> json) => MonitorAuditEntry(
    id: (json['id'] as num?)?.toInt() ?? 0,
    at: _time(json['timestamp']),
    kind: _str(json['kind']),
    action: _str(json['action']),
    result: _str(json['result']),
    subject: _opt(json['subject']),
    remoteIp: _opt(json['remote_ip']),
    systemUser: _opt(json['ssh_user']),
    detail: _opt(json['detail']),
  );
}

abstract final class MonitorAuditKind {
  /// What `GET /audit?kind=` takes (`api::ws::audit::Kind::ALL`).
  static const all = [
    'login',
    'terminal',
    'exec',
    'fs',
    'machine',
    'agent',
    'stack',
    'stream',
    'listen',
    'ticket',
    'custom_cmd',
    'push',
    'admin',
    'backup',
  ];
}

class MonitorAuditPage {
  const MonitorAuditPage({this.entries = const [], this.next});

  /// Newest first.
  final List<MonitorAuditEntry> entries;

  /// `before` for the next page; null on the last.
  final int? next;

  factory MonitorAuditPage.fromJson(Map<String, dynamic> json) => MonitorAuditPage(
    entries: [for (final row in _rows(json['entries'])) MonitorAuditEntry.fromJson(row)],
    next: (json['next'] as num?)?.toInt(),
  );
}

/// A terminal session open on the agent.
class MonitorLiveSession {
  const MonitorLiveSession({
    required this.id,
    required this.what,
    required this.attached,
    this.user,
    this.remoteIp,
    this.openedAt,
  });

  final String id;

  /// `shell`, `container <id>`, `tmux <name>`, …
  final String what;
  final bool attached;

  /// The system account the shell runs as.
  final String? user;
  final String? remoteIp;
  final DateTime? openedAt;

  factory MonitorLiveSession.fromJson(Map<String, dynamic> json) => MonitorLiveSession(
    id: _str(json['id']),
    what: _str(json['what']),
    attached: json['attached'] == true,
    user: _opt(json['user']),
    remoteIp: _opt(json['remote_ip']),
    openedAt: _time(json['opened_at']),
  );
}

/// A relayed connection, listened port, console or remote desktop.
class MonitorLiveConnection {
  const MonitorLiveConnection({
    required this.id,
    required this.kind,
    required this.target,
    this.remoteIp,
    this.openedAt,
  });

  final String id;

  /// `stream`, `accepted`, `listen`, `virt_console` or `rdp`.
  final String kind;
  final String target;
  final String? remoteIp;
  final DateTime? openedAt;

  factory MonitorLiveConnection.fromJson(Map<String, dynamic> json) => MonitorLiveConnection(
    id: _str(json['id']),
    kind: _str(json['kind']),
    target: _str(json['target']),
    remoteIp: _opt(json['remote_ip']),
    openedAt: _time(json['opened_at']),
  );
}

/// A watch or widget's read-only token.
class MonitorWatchTokenInfo {
  const MonitorWatchTokenInfo({required this.clientId, this.createdAt, this.expiresAt});

  /// `watch:<id>`, `widget:<id>`, …
  final String clientId;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory MonitorWatchTokenInfo.fromJson(Map<String, dynamic> json) => MonitorWatchTokenInfo(
    clientId: _str(json['client_id']),
    createdAt: _unix(json['created_at']),
    expiresAt: _unix(json['expires_at']),
  );
}

/// A device that signed in with the password.
class MonitorLoginDevice {
  const MonitorLoginDevice({required this.id, required this.label, this.lastIp, this.createdAt, this.lastUsed});

  final int id;

  /// What it called itself, else its User-Agent; may be empty.
  final String label;
  final String? lastIp;
  final DateTime? createdAt;
  final DateTime? lastUsed;

  factory MonitorLoginDevice.fromJson(Map<String, dynamic> json) => MonitorLoginDevice(
    id: (json['id'] as num?)?.toInt() ?? 0,
    label: _str(json['label']),
    lastIp: _opt(json['last_ip']),
    createdAt: _unix(json['created_at']),
    lastUsed: _unix(json['last_used']),
  );
}

/// `GET /api/v1/live`.
class MonitorLive {
  const MonitorLive({
    this.sessions = const [],
    this.connections = const [],
    this.watchTokens = const [],
    this.devices = const [],
  });

  final List<MonitorLiveSession> sessions;
  final List<MonitorLiveConnection> connections;
  final List<MonitorWatchTokenInfo> watchTokens;

  /// Most recently used first.
  final List<MonitorLoginDevice> devices;

  factory MonitorLive.fromJson(Map<String, dynamic> json) => MonitorLive(
    sessions: [for (final row in _rows(json['sessions'])) MonitorLiveSession.fromJson(row)],
    connections: [for (final row in _rows(json['connections'])) MonitorLiveConnection.fromJson(row)],
    watchTokens: [for (final row in _rows(json['watch_tokens'])) MonitorWatchTokenInfo.fromJson(row)],
    devices: [for (final row in _rows(json['devices'])) MonitorLoginDevice.fromJson(row)],
  );
}
