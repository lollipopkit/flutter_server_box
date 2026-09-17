import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
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

  /// `HH:MM:SS` as the server printed it, in the server's time zone.
  final String? time;
  final String text;
}

final class ServiceLog {
  const ServiceLog({required this.lines, this.unreadable = false});

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
  });

  final List<ServiceUnit> units;
  final ServiceListingNotice? notice;
  final String? detail;
}
