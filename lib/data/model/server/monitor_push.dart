/// A `monitor` agent's notification channels, as `GET/PUT /api/v1/push`
/// exposes them.
///
/// Their own endpoint rather than part of `/settings`, so that saving a
/// channel is not a read-modify-write of every other setting — and so that the
/// credential handling below lives in one place.
///
/// **A credential is write-only.** These entries hold a ServerChan key, a Bark
/// key, an iOS token, an `Authorization` header; the agent answers `null` at
/// every one of them rather than handing them to whoever holds the panel
/// password. So on this side:
///
/// - `null` in [MonitorPushEntry.config] means "set on the agent, not
///   disclosed", and an absent key means "not set at all";
/// - sending the `null` back keeps the stored value;
/// - the agent refuses a `null` anywhere else, so nothing here may invent one.
///
/// [MonitorPushEntry.fromIndex] is what "the stored value" is resolved
/// against: the position the entry was loaded from. It travels with the entry
/// through a rename and a reorder, which is exactly what matching by name or by
/// submitted position would fail to do.
library;

class MonitorPushEntry {
  final String name;
  final String pushType;

  /// The channel's own settings. Carries keys this app knows nothing about —
  /// `legacy_go_format`, a webhook's `expected_http_status` — so an editor must
  /// send the loaded map back with its edits applied rather than rebuild it out
  /// of the fields it renders.
  final Map<String, dynamic> config;

  /// Where the agent had this entry when it was read, or null for one being
  /// added. The only thing a withheld credential can be resolved against.
  final int? fromIndex;

  /// False when the agent has no sender for [pushType] and therefore cannot
  /// know which of the entry's keys are credentials: [config] arrives empty and
  /// the channel can be removed but not edited.
  final bool editable;

  const MonitorPushEntry({
    required this.name,
    required this.pushType,
    this.config = const {},
    this.fromIndex,
    this.editable = true,
  });

  factory MonitorPushEntry.fromJson(Map<String, dynamic> json, int index) {
    return MonitorPushEntry(
      name: json['name'] as String? ?? '',
      pushType: json['push_type'] as String? ?? '',
      config: switch (json['config']) {
        final Map<String, dynamic> config => Map.of(config),
        _ => const {},
      },
      fromIndex: index,
      editable: json['editable'] != false,
    );
  }

  /// `editable` is deliberately not sent: it is the agent's answer about
  /// itself, not a field a client gets an opinion on.
  Map<String, dynamic> toJson() => {
    'name': name,
    'push_type': pushType,
    'config': config,
    'from_index': fromIndex,
  };

  MonitorPushEntry copyWith({
    String? name,
    String? pushType,
    Map<String, dynamic>? config,
    int? Function()? fromIndex,
  }) => MonitorPushEntry(
    name: name ?? this.name,
    pushType: pushType ?? this.pushType,
    config: config ?? this.config,
    fromIndex: fromIndex == null ? this.fromIndex : fromIndex(),
    editable: editable,
  );
}

class MonitorPushList {
  final List<MonitorPushEntry> pushes;

  /// "N/duration", e.g. `1/1m`. Null = the agent's default of one a minute.
  final String? pushRate;

  /// The channel types this agent can actually deliver through. Asked rather
  /// than hardcoded, so an agent that grows one does not need an app release.
  final List<String> pushTypes;

  /// Whether a saved channel only reaches the rule engine on the next restart.
  /// True on every agent that has this endpoint today.
  final bool appliesOnRestart;

  const MonitorPushList({
    this.pushes = const [],
    this.pushRate,
    this.pushTypes = const [],
    this.appliesOnRestart = true,
  });

  factory MonitorPushList.fromJson(Map<String, dynamic> json) {
    final pushes = json['pushes'];
    return MonitorPushList(
      pushes: switch (pushes) {
        final List list => [
          for (var i = 0; i < list.length; i++)
            if (list[i] case final Map<String, dynamic> push)
              MonitorPushEntry.fromJson(push, i),
        ],
        _ => const [],
      },
      pushRate: json['push_rate'] as String?,
      pushTypes: switch (json['push_types']) {
        final List list => list.whereType<String>().toList(),
        _ => const [],
      },
      appliesOnRestart: json['applies_on_restart'] != false,
    );
  }

  Map<String, dynamic> toPayload() => {
    'pushes': [for (final push in pushes) push.toJson()],
    'push_rate': pushRate,
  };
}

/// What came back from `POST /api/v1/push/test`.
///
/// A refused delivery is a successful request: the agent answers 200 with
/// [ok] false and the reason, because the reason is what the person editing
/// the channel needs. Only an unreachable or refusing agent throws.
class MonitorPushTestResult {
  final bool ok;
  final String? error;

  const MonitorPushTestResult({required this.ok, this.error});

  factory MonitorPushTestResult.fromJson(Map<String, dynamic> json) {
    return MonitorPushTestResult(
      ok: json['ok'] == true,
      error: json['error'] as String?,
    );
  }
}
