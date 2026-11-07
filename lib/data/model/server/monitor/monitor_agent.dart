import 'package:collection/collection.dart';

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
    this.model,
    this.thinkingLevel,
  });

  factory MonitorAgentFlow.fromJson(Map<String, dynamic> j) => MonitorAgentFlow(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    status: MonitorAgentStatus.of(j['status'] as String?),
    line: j['line'] as String? ?? '',
    mode: AgentPermissionMode.of(j['mode']),
    createdAt: _time(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    updatedAt: _time(j['updatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    finishedAt: _time(j['finishedAt']),
    waiting: j['waiting'] as String?,
    model: MonitorAgentModel.maybe(j['model']),
    thinkingLevel: j['thinkingLevel'] as String?,
  );

  final String id;
  final String title;
  final MonitorAgentStatus status;

  /// The model's latest first line, or why the task failed.
  final String line;

  /// `manual`, `auto` or `bypass`.
  final AgentPermissionMode mode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finishedAt;

  /// What it waits on while [status] is waiting: `confirm`, `danger`, `sudo`
  /// or `clarify`.
  final String? waiting;

  /// What its account picked; null is the machine's.
  final MonitorAgentModel? model;
  final String? thinkingLevel;

  static DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}

/// A model on a monitor agent, as pi names it: its provider and id there.
final class MonitorAgentModel {
  const MonitorAgentModel(this.provider, this.id, {this.name, this.reasoning = false});

  static MonitorAgentModel? maybe(Object? j) => switch (j) {
    {'provider': final String p, 'id': final String id} =>
      MonitorAgentModel(p, id, name: (j as Map)['name'] as String?, reasoning: j['reasoning'] == true),
    _ => null,
  };

  final String provider;
  final String id;

  /// How its provider names it; null for a reference that carries no name.
  final String? name;

  /// Whether it thinks, so a thinking level means something to it.
  final bool reasoning;

  String get label => name ?? id;

  Map<String, String> toJson() => {'provider': provider, 'id': id};

  bool same(MonitorAgentModel? o) => o != null && o.provider == provider && o.id == id;
}

/// What a task may be started or replied to with (`GET /agent/choices`).
final class MonitorAgentChoices {
  const MonitorAgentChoices({required this.models, required this.thinkingLevels, this.model, required this.thinkingLevel});

  factory MonitorAgentChoices.fromJson(Map<String, dynamic> j) => MonitorAgentChoices(
    models: [
      for (final m in j['models'] as List? ?? const [])
        ?MonitorAgentModel.maybe(m),
    ],
    thinkingLevels: [
      for (final l in j['thinkingLevels'] as List? ?? const [])
        if (l is String) l,
    ],
    model: MonitorAgentModel.maybe(j['model']),
    thinkingLevel: j['thinkingLevel'] as String? ?? 'off',
  );

  final List<MonitorAgentModel> models;
  final List<String> thinkingLevels;

  /// The machine's, for a task that picks none.
  final MonitorAgentModel? model;
  final String thinkingLevel;

  /// [ref] as the list knows it, with its name and whether it thinks.
  MonitorAgentModel? find(MonitorAgentModel? ref) => ref == null ? null : models.firstWhereOrNull((m) => m.same(ref)) ?? ref;
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
    defaultMode: AgentPermissionMode.of(j['defaultMode']),
    bypassAllowed: j['bypassAllowed'] == true,
    next: j['next'] as String?,
  );

  final List<MonitorAgentFlow> flows;

  /// The cursor of the next page; null on the last one, and from an agent
  /// that does not page.
  final String? next;
  final bool configured;
  final AgentPermissionMode defaultMode;
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

/// How a server's Agent task asks before it acts: `auto` decides by itself,
/// `manual` asks by the server's rules, `bypass` never asks.
enum AgentPermissionMode {
  auto,
  manual,
  bypass;

  /// [manual] for none and for a mode this app does not know: the safe one.
  static AgentPermissionMode of(Object? name) =>
      values.firstWhereOrNull((m) => m.name == name) ?? manual;
}

/// One of the auto mode judge's prose lists, by its key in `autoMode`.
enum AgentAutoRuleKind {
  environment('environment'),
  allow('allow'),
  softDeny('soft_deny'),
  hardDeny('hard_deny');

  const AgentAutoRuleKind(this.key);
  final String key;
}

/// How the commands a server's Agent tasks run are approved, for every
/// account (`/api/v1/agent/permissions`). Sent back whole on save.
final class MonitorAgentPermissions {
  const MonitorAgentPermissions({
    this.defaultMode = AgentPermissionMode.manual,
    this.disableBypass = false,
    this.allow = const [],
    this.ask = const [],
    this.deny = const [],
    this.autoMode = const {},
    this.raw = const {},
  });

  factory MonitorAgentPermissions.fromJson(Map<String, dynamic> j) {
    final rules = j['rules'] as Map? ?? const {};
    final auto = j['autoMode'] as Map? ?? const {};
    final mode = j['defaultMode'];
    return MonitorAgentPermissions(
      defaultMode: mode == null
          ? AgentPermissionMode.manual
          : AgentPermissionMode.values.firstWhereOrNull((m) => m.name == mode),
      disableBypass: j['disableBypass'] == true,
      allow: _strings(rules['allow']),
      ask: _strings(rules['ask']),
      deny: _strings(rules['deny']),
      autoMode: {
        for (final k in AgentAutoRuleKind.values)
          if (auto[k.key] is List) k: _strings(auto[k.key]),
      },
      raw: j,
    );
  }

  /// Null for a mode this app does not know, which is sent back as it came.
  final AgentPermissionMode? defaultMode;
  final bool disableBypass;
  final List<String> allow;
  final List<String> ask;
  final List<String> deny;

  /// A list absent is the built-in one.
  final Map<AgentAutoRuleKind, List<String>> autoMode;

  /// What the agent sent, so a field this app does not know survives a save.
  final Map<String, dynamic> raw;

  MonitorAgentPermissions copyWith({
    AgentPermissionMode? defaultMode,
    bool? disableBypass,
    List<String>? allow,
    List<String>? ask,
    List<String>? deny,
    Map<AgentAutoRuleKind, List<String>>? autoMode,
  }) => MonitorAgentPermissions(
    defaultMode: defaultMode ?? this.defaultMode,
    disableBypass: disableBypass ?? this.disableBypass,
    allow: allow ?? this.allow,
    ask: ask ?? this.ask,
    deny: deny ?? this.deny,
    autoMode: autoMode ?? this.autoMode,
    raw: raw,
  );

  Map<String, dynamic> toJson() {
    final rules = raw['rules'] is Map ? Map<String, dynamic>.of(raw['rules'] as Map<String, dynamic>) : <String, dynamic>{};
    final auto = raw['autoMode'] is Map ? Map<String, dynamic>.of(raw['autoMode'] as Map<String, dynamic>) : <String, dynamic>{};
    for (final k in AgentAutoRuleKind.values) {
      auto.remove(k.key);
    }
    return {
      ...raw,
      'defaultMode': defaultMode?.name ?? raw['defaultMode'],
      'disableBypass': disableBypass,
      'rules': {...rules, 'allow': allow, 'ask': ask, 'deny': deny},
      'autoMode': {...auto, for (final e in autoMode.entries) e.key.key: e.value},
    };
  }
}

/// [MonitorAgentPermissions] with the built-in auto mode lists.
final class MonitorAgentPermissionsView {
  const MonitorAgentPermissionsView({required this.permissions, required this.defaults});

  factory MonitorAgentPermissionsView.fromJson(Map<String, dynamic> j) {
    final defaults = j['defaults'] as Map? ?? const {};
    return MonitorAgentPermissionsView(
      permissions: MonitorAgentPermissions.fromJson(j['permissions'] as Map<String, dynamic>? ?? const {}),
      defaults: {for (final k in AgentAutoRuleKind.values) k: _strings(defaults[k.key])},
    );
  }

  final MonitorAgentPermissions permissions;
  final Map<AgentAutoRuleKind, List<String>> defaults;
}

List<String> _strings(Object? raw) => [
  for (final s in raw as List? ?? const [])
    if (s is String) s,
];
