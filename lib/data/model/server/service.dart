import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';

enum ServiceAction {
  start,
  stop,
  restart,
  status,
  enable,
  disable;

  IconData get icon => switch (this) {
    start => Icons.play_arrow,
    stop => Icons.stop,
    restart => Icons.refresh,
    status => Icons.info,
    enable => Icons.power_settings_new,
    disable => Icons.power_off,
  };

  String get displayName => switch (this) {
    start => libL10n.start,
    stop => libL10n.stop,
    restart => libL10n.restart,
    status => l10n.status,
    enable => l10n.enable,
    disable => l10n.disable,
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

  final List<ServiceAction> actions;
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
