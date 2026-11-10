import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/src/rust/api/service.dart';

export 'package:server_box/src/rust/api/service.dart'
    show
        ServiceAction,
        ServiceListing,
        ServiceListingNotice,
        ServiceLog,
        ServiceLogLine,
        ServiceManagerType,
        ServiceScope,
        ServiceState,
        ServiceUnit,
        ServiceUnitType;

extension ServiceActionX on ServiceAction {
  IconData get icon => switch (this) {
    ServiceAction.start => Icons.play_arrow,
    ServiceAction.stop => Icons.stop,
    ServiceAction.restart => Icons.restart_alt,
    ServiceAction.enable => Icons.power_settings_new,
    ServiceAction.disable => Icons.block,
  };

  String get displayName => switch (this) {
    ServiceAction.start => libL10n.start,
    ServiceAction.stop => libL10n.stop,
    ServiceAction.restart => libL10n.restart,
    ServiceAction.enable => l10n.enable,
    ServiceAction.disable => l10n.disable,
  };

  /// Whether taking it can interrupt something that is working. Asked before
  /// it runs; starting or enabling a unit is not.
  bool get destructive => switch (this) {
    ServiceAction.stop || ServiceAction.restart || ServiceAction.disable => true,
    ServiceAction.start || ServiceAction.enable => false,
  };
}

extension ServiceManagerTypeX on ServiceManagerType {
  String get displayName => switch (this) {
    ServiceManagerType.systemd => 'systemd',
    ServiceManagerType.procd => 'procd',
    ServiceManagerType.openrc => 'OpenRC',
  };

  bool get supportsUserScope => this == ServiceManagerType.systemd;
}

extension ServiceScopeX on ServiceScope {
  Color? get color => switch (this) {
    ServiceScope.system => Colors.red,
    ServiceScope.user => null,
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

extension ServiceStateX on ServiceState {
  Color? get color => switch (this) {
    ServiceState.failed => Colors.red,
    ServiceState.starting || ServiceState.stopping => Colors.orange,
    _ => null,
  };

  String get displayName => switch (this) {
    ServiceState.running => libL10n.running,
    ServiceState.stopped => libL10n.stopped,
    ServiceState.failed => libL10n.fail,
    ServiceState.starting => l10n.starting,
    ServiceState.stopping => l10n.stopping,
    ServiceState.unknown => libL10n.unknown,
  };
}

extension ServiceUnitX on ServiceUnit {
  /// When the unit entered its current state, on this device's clock.
  DateTime? get since => _at(sinceMillis);

  /// When a timer next fires, on this device's clock.
  DateTime? get nextElapse => _at(nextElapseMillis);

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

  static DateTime? _at(int? millis) => millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
}
