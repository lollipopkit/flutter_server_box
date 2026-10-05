import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';

enum ServiceAction {
  start,
  stop,
  restart,
  enable,
  disable;

  IconData get icon => switch (this) {
    start => Icons.play_arrow,
    stop => Icons.stop,
    restart => Icons.restart_alt,
    enable => Icons.power_settings_new,
    disable => Icons.block,
  };

  String get displayName => switch (this) {
    start => libL10n.start,
    stop => libL10n.stop,
    restart => libL10n.restart,
    enable => l10n.enable,
    disable => l10n.disable,
  };

  /// Whether taking it can interrupt something that is working. Asked before
  /// it runs; starting or enabling a unit is not.
  bool get destructive => switch (this) {
    stop || restart || disable => true,
    start || enable => false,
  };
}

enum ServiceManagerType {
  systemd,
  procd,
  openrc;

  String get displayName => switch (this) {
    systemd => 'systemd',
    procd => 'procd',
    openrc => 'OpenRC',
  };

  bool get supportsUserScope => this == systemd;
}

enum ServiceUnitType {
  service,
  socket,
  mount,
  timer;

  static ServiceUnitType? fromString(String? value) {
    return values.firstWhereOrNull((e) => e.name == value?.toLowerCase());
  }
}

enum ServiceScope {
  system,
  user;

  Color? get color => switch (this) {
    system => Colors.red,
    _ => null,
  };
}

enum ServiceScopeFilter {
  all,
  system,
  user;

  String get displayName => switch (this) {
    all => libL10n.all,
    system => libL10n.system,
    user => libL10n.user,
  };
}

enum ServiceState {
  running,
  stopped,
  failed,
  starting,
  stopping,
  unknown;

  /// Failed, or on its way somewhere. What a list shows first.
  bool get needsAttention => switch (this) {
    failed || starting || stopping => true,
    running || stopped || unknown => false,
  };

  Color? get color => switch (this) {
    failed => Colors.red,
    starting || stopping => Colors.orange,
    _ => null,
  };

  String get displayName => switch (this) {
    running => libL10n.running,
    stopped => libL10n.stopped,
    failed => libL10n.fail,
    starting => l10n.starting,
    stopping => l10n.stopping,
    unknown => libL10n.unknown,
  };
}

final class ServiceUnit {
  const ServiceUnit({
    required this.name,
    required this.type,
    required this.scope,
    required this.state,
    required this.actions,
    this.description,
    this.enabled,
    this.unitFileState,
    this.subState,
    this.result,
    this.exitStatus,
    this.memoryBytes,
    this.since,
    this.nextElapse,
  });

  final String name;
  final String? description;
  final ServiceUnitType type;
  final ServiceScope scope;
  final ServiceState state;

  /// Null when the manager cannot report startup registration cheaply and
  /// reliably. A false value is different: it means the manager did report
  /// that this service is not registered for startup.
  final bool? enabled;

  /// systemd's own word for startup registration, which says more than
  /// [enabled] can: `static` and `masked` units cannot be enabled at all, and
  /// offering to would fail.
  final String? unitFileState;

  /// systemd's finer state: `running`, `exited`, `dead`, `start-pre`.
  final String? subState;

  /// Why the last run ended, where systemd says: `exit-code`, `signal`,
  /// `timeout`. `success` is not kept — it explains nothing.
  final String? result;

  /// The main process's exit status, kept only when [result] is `exit-code`:
  /// otherwise it is a zero, or the number of a signal already named there.
  final int? exitStatus;

  final int? memoryBytes;

  /// When the unit entered its current state, on this device's clock.
  final DateTime? since;

  /// When a timer next fires, on this device's clock.
  final DateTime? nextElapse;

  final List<ServiceAction> actions;

  String get fullName => '$name.${type.name}';

  /// `sbm_parser::service::ServiceUnit`, which reads and acts on it.
  factory ServiceUnit.fromJson(Map<String, Object?> j) {
    DateTime? at(Object? millis) => switch (millis) {
      final num m => DateTime.fromMillisecondsSinceEpoch(m.toInt()),
      _ => null,
    };
    return ServiceUnit(
      name: j['name'] as String,
      type: ServiceUnitType.fromString(j['type'] as String?) ?? ServiceUnitType.service,
      scope: ServiceScope.values.byName(j['scope'] as String),
      state: ServiceState.values.byName(j['state'] as String),
      actions: [
        for (final a in j['actions'] as List? ?? const []) ServiceAction.values.byName(a as String),
      ],
      description: j['description'] as String?,
      enabled: j['enabled'] as bool?,
      unitFileState: j['unit_file_state'] as String?,
      subState: j['sub_state'] as String?,
      result: j['result'] as String?,
      exitStatus: (j['exit_status'] as num?)?.toInt(),
      memoryBytes: (j['memory_bytes'] as num?)?.toInt(),
      since: at(j['since_millis']),
      nextElapse: at(j['next_elapse_millis']),
    );
  }

  ServiceUnit copyWithTimes({DateTime? since, DateTime? nextElapse}) => ServiceUnit(
    name: name,
    type: type,
    scope: scope,
    state: state,
    actions: actions,
    description: description,
    enabled: enabled,
    unitFileState: unitFileState,
    subState: subState,
    result: result,
    exitStatus: exitStatus,
    memoryBytes: memoryBytes,
    since: since,
    nextElapse: nextElapse,
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'full_name': fullName,
    'type': type.name,
    'scope': scope.name,
    'state': state.name,
    'description': description,
    'enabled': enabled,
    'unit_file_state': unitFileState,
    'sub_state': subState,
    'result': result,
    'exit_status': exitStatus,
    'memory_bytes': memoryBytes,
    'since_millis': since?.millisecondsSinceEpoch,
    'next_elapse_millis': nextElapse?.millisecondsSinceEpoch,
    'actions': [for (final a in actions) a.name],
  };

  /// Tells apart a system and a user unit of the same name.
  String get key => '${scope.name}:$fullName';

  /// [unitFileState] where the manager has one, [enabled] in the same words
  /// where it does not.
  String? get startup =>
      unitFileState ??
      switch (enabled) {
        true => 'enabled',
        false => 'disabled',
        null => null,
      };
}

/// One line of a unit's log.
final class ServiceLogLine {
  const ServiceLogLine({this.time, required this.text});

  factory ServiceLogLine.fromJson(Map<String, Object?> j) =>
      ServiceLogLine(time: j['time'] as String?, text: j['text'] as String? ?? '');

  /// `HH:MM:SS` as the server printed it, in the server's time zone.
  final String? time;
  final String text;
}

final class ServiceLog {
  const ServiceLog({required this.lines, this.unreadable = false});

  factory ServiceLog.fromJson(Map<String, Object?> j) => ServiceLog(
    lines: [
      for (final l in j['lines'] as List? ?? const []) ServiceLogLine.fromJson(l as Map<String, Object?>),
    ],
    unreadable: j['unreadable'] as bool? ?? false,
  );

  final List<ServiceLogLine> lines;

  /// This account may not read the log it asked for. Not the same as an empty
  /// log, which a unit that has never run has.
  final bool unreadable;
}

enum ServiceListingNotice {
  userScopeUnavailable,
  detailsUnavailable,
}

final class ServiceListing {
  const ServiceListing({
    required this.units,
    this.notice,
    this.detail,
    this.sampledAt,
  });

  /// The machine's own clock when it was read: what [ServiceUnit.since] and
  /// [ServiceUnit.nextElapse] are against. Null where the manager reports no
  /// times.
  final DateTime? sampledAt;

  /// This listing with every timestamp moved onto this device's clock by the
  /// difference between [now] and [sampledAt], so a duration the page computes
  /// later is right however far the two clocks disagree.
  ServiceListing onDeviceClock(DateTime now) {
    final at = sampledAt;
    if (at == null) return this;
    final skew = now.difference(at);
    DateTime? shift(DateTime? t) => t?.add(skew);
    return ServiceListing(
      units: [for (final u in units) u.copyWithTimes(since: shift(u.since), nextElapse: shift(u.nextElapse))],
      notice: notice,
      detail: detail,
    );
  }

  factory ServiceListing.fromJson(Map<String, Object?> j) => ServiceListing(
    units: [
      for (final u in j['units'] as List? ?? const []) ServiceUnit.fromJson(u as Map<String, Object?>),
    ],
    notice: switch (j['notice']) {
      'user_scope_unavailable' => ServiceListingNotice.userScopeUnavailable,
      'details_unavailable' => ServiceListingNotice.detailsUnavailable,
      _ => null,
    },
    detail: j['detail'] as String?,
    sampledAt: switch (j['sampled_at_millis']) {
      final num m => DateTime.fromMillisecondsSinceEpoch(m.toInt()),
      _ => null,
    },
  );

  final List<ServiceUnit> units;
  final ServiceListingNotice? notice;
  final String? detail;
}
