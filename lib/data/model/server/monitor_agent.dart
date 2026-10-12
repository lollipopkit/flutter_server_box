/// A task of a monitor agent's Agent mode, as `GET /api/v1/agent/flows`
/// lists it.
///
/// Hand-written rather than generated: the agent's JSON is camelCase and
/// read-only here; nothing is sent back in this shape.
final class MonitorAgentFlow {
  const MonitorAgentFlow({
    required this.id,
    required this.title,
    required this.status,
    required this.line,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    this.finishedAt,
    this.waiting,
  });

  factory MonitorAgentFlow.fromJson(Map<String, dynamic> j) => MonitorAgentFlow(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    status: MonitorAgentStatus.of(j['status'] as String?),
    line: j['line'] as String? ?? '',
    mode: j['mode'] as String? ?? 'manual',
    createdAt: _time(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: _time(j['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    finishedAt: _time(j['finishedAt']),
    waiting: j['waiting'] as String?,
  );

  final String id;
  final String title;
  final MonitorAgentStatus status;

  /// The model's latest first line, or why the task failed.
  final String line;

  /// `manual`, `auto` or `bypass`.
  final String mode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finishedAt;

  /// What it waits on while [status] is waiting: `confirm`, `danger`, `sudo`
  /// or `clarify`.
  final String? waiting;

  static DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

enum MonitorAgentStatus {
  queued,
  running,
  waiting,
  done,
  failed,
  cancelled;

  static MonitorAgentStatus of(String? s) => switch (s) {
    'queued' => queued,
    'running' => running,
    'waiting' => waiting,
    'failed' => failed,
    'cancelled' => cancelled,
    _ => done,
  };

  bool get active => this == queued || this == running || this == waiting;
}

/// `GET /api/v1/agent/flows`: the account's tasks, newest first, and whether
/// the agent has a model to run them with.
final class MonitorAgentFlows {
  const MonitorAgentFlows({
    required this.flows,
    required this.configured,
    required this.defaultMode,
    required this.bypassAllowed,
    this.next,
  });

  factory MonitorAgentFlows.fromJson(Map<String, dynamic> j) => MonitorAgentFlows(
    flows: [
      for (final f in j['flows'] as List? ?? const [])
        if (f is Map<String, dynamic>) MonitorAgentFlow.fromJson(f),
    ],
    configured: j['configured'] == true,
    defaultMode: j['defaultMode'] as String? ?? 'manual',
    bypassAllowed: j['bypassAllowed'] == true,
    next: j['next'] as String?,
  );

  final List<MonitorAgentFlow> flows;

  /// The cursor of the next page; null on the last one, and from an agent
  /// that does not page.
  final String? next;
  final bool configured;
  final String defaultMode;
  final bool bypassAllowed;
}

/// `GET /api/v1/agent/flows/{id}`: a task with its conversation, in pi's
/// entry shape (`LlmEntry`), what it waits on, and the running command's
/// output.
final class MonitorAgentDetail {
  const MonitorAgentDetail({required this.flow, required this.entries, this.pending, this.output});

  factory MonitorAgentDetail.fromJson(Map<String, dynamic> j) => MonitorAgentDetail(
    flow: MonitorAgentFlow.fromJson(j['flow'] as Map<String, dynamic>),
    entries: [
      for (final e in j['entries'] as List? ?? const [])
        if (e is Map<String, dynamic>) e,
    ],
    pending: switch (j['pending']) {
      final Map<String, dynamic> p => MonitorAgentPending.fromJson(p),
      _ => null,
    },
    output: switch (j['output']) {
      final Map<String, dynamic> o => MonitorAgentOutput.fromJson(o),
      _ => null,
    },
  );

  final MonitorAgentFlow flow;
  final List<Map<String, dynamic>> entries;
  final MonitorAgentPending? pending;
  final MonitorAgentOutput? output;
}

/// What a task waits on the account for.
final class MonitorAgentPending {
  const MonitorAgentPending(this.json);

  factory MonitorAgentPending.fromJson(Map<String, dynamic> j) => MonitorAgentPending(j);

  final Map<String, dynamic> json;

  String get id => json['id'] as String;

  /// `confirm` (a command, or a plan when [command] is null), `danger`,
  /// `sudo` or `clarify`.
  String get kind => json['kind'] as String? ?? '';
  String get toolCallId => json['toolCallId'] as String? ?? '';
  String get title => json['title'] as String? ?? '';
  String? get summary => json['summary'] as String?;
  String? get command => json['command'] as String?;

  /// A plan's steps: `text`, and the command when it has one.
  List<({String text, String? command})> get steps => [
    for (final s in json['steps'] as List? ?? const [])
      if (s is Map) (text: s['text'] as String? ?? '', command: s['command'] as String?),
  ];

  /// `clarify`'s choices.
  List<({String label, String? hint})> get options => [
    for (final o in json['options'] as List? ?? const [])
      if (o is Map) (label: o['label'] as String? ?? '', hint: o['hint'] as String?),
  ];

  /// `danger`'s safer commands.
  List<String> get alternatives => [
    for (final a in json['alternatives'] as List? ?? const [])
      if (a is String) a,
  ];

  /// What `danger` asks to be typed: the machine's name.
  String? get confirmText => json['confirmText'] as String?;

  /// `sudo`'s system account.
  String? get user => json['user'] as String?;

  /// The rule "always allow" would add; absent behind an ask rule.
  String? get allowRule => json['allowRule'] as String?;

  /// `wrongPassword` after a refused sudo password.
  String? get error => json['error'] as String?;
}

/// The running command's output: lines tagged 1 (stdout) or 2 (stderr).
final class MonitorAgentOutput {
  const MonitorAgentOutput({required this.toolCallId, required this.lines, required this.omitted});

  factory MonitorAgentOutput.fromJson(Map<String, dynamic> j) => MonitorAgentOutput(
    toolCallId: j['toolCallId'] as String? ?? '',
    lines: linesOf(j['lines']),
    omitted: (j['omitted'] as num?)?.toInt() ?? 0,
  );

  final String toolCallId;
  final List<String> lines;
  final int omitted;

  /// The text of `[[stream, text], …]`, as `output` events carry it too.
  static List<String> linesOf(Object? raw) => [
    for (final l in raw as List? ?? const [])
      if (l is List && l.length == 2 && l[1] is String) l[1] as String,
  ];
}
