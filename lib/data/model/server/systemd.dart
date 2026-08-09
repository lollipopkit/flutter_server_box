import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:server_box/core/extension/context/locale.dart';

enum SystemdUnitFunc {
  start,
  stop,
  restart,
  status;

  IconData get icon => switch (this) {
    start => Icons.play_arrow,
    stop => Icons.stop,
    restart => Icons.refresh,
    status => Icons.info,
  };
}

enum SystemdUnitType {
  service,
  socket,
  mount,
  timer;

  static SystemdUnitType? fromString(String? value) {
    return values.firstWhereOrNull((e) => e.name == value?.toLowerCase());
  }
}

enum SystemdUnitScope {
  system,
  user;

  Color? get color => switch (this) {
    system => Colors.red,
    _ => null,
  };

  String getCmdPrefix(bool isRoot) {
    if (this == system) {
      return isRoot ? 'systemctl' : 'sudo systemctl';
    }
    return 'systemctl --user';
  }

  /// Command to enumerate units for this scope.
  ///
  /// Listing is read-only, so no `sudo` is needed even for the system scope.
  String get listUnitsCmd {
    final prefix = this == system ? 'systemctl' : 'systemctl --user';
    return '$prefix list-units --all --no-legend --no-pager --plain '
        '--type=service,socket,mount,timer';
  }
}

enum SystemdScopeFilter {
  all,
  system,
  user;

  String get displayName => switch (this) {
    all => libL10n.all,
    system => l10n.system,
    user => libL10n.user,
  };
}

enum SystemdUnitState {
  active,
  inactive,
  failed,
  activating,
  deactivating;

  static SystemdUnitState? fromString(String? value) {
    return values.firstWhereOrNull((e) => e.name == value?.toLowerCase());
  }

  Color? get color => switch (this) {
    failed => Colors.red,
    _ => null,
  };
}

final class SystemdUnit {
  final String name;
  final String? description;
  final SystemdUnitType type;
  final SystemdUnitScope scope;
  final SystemdUnitState state;

  SystemdUnit({
    required this.name,
    this.description,
    required this.type,
    required this.scope,
    required this.state,
  });

  String getCmd({required SystemdUnitFunc func, required bool isRoot}) {
    final prefix = scope.getCmdPrefix(isRoot);
    return '$prefix ${func.name} ${name.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.@:]'), '')}';
  }

  /// Parses the output of `systemctl list-units --plain --no-legend`.
  ///
  /// Each line has the columns: `UNIT LOAD ACTIVE SUB DESCRIPTION...`, where
  /// the description is the (possibly multi-word) remainder of the line.
  /// Lines with an unsupported unit type or unmapped active state are skipped.
  static List<SystemdUnit> parseListUnits(
    String output,
    SystemdUnitScope scope,
  ) {
    final units = <SystemdUnit>[];
    for (final line in output.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 4) continue;

      final fullName = parts[0];
      final lastDot = fullName.lastIndexOf('.');
      if (lastDot <= 0) continue;

      final type = SystemdUnitType.fromString(fullName.substring(lastDot + 1));
      if (type == null) continue;

      final state = SystemdUnitState.fromString(parts[2]);
      if (state == null) continue;

      units.add(SystemdUnit(
        name: fullName.substring(0, lastDot),
        type: type,
        scope: scope,
        state: state,
        description: parts.length > 4 ? parts.sublist(4).join(' ') : null,
      ));
    }
    return units;
  }

  List<SystemdUnitFunc> get availableFuncs {
    final funcs = <SystemdUnitFunc>{};
    switch (state) {
      case SystemdUnitState.active:
        funcs.addAll([SystemdUnitFunc.stop, SystemdUnitFunc.restart]);
        break;
      case SystemdUnitState.inactive:
        funcs.addAll([SystemdUnitFunc.start]);
        break;
      case SystemdUnitState.failed:
        funcs.addAll([SystemdUnitFunc.restart]);
        break;
      case SystemdUnitState.activating:
        funcs.addAll([SystemdUnitFunc.stop]);
        break;
      case SystemdUnitState.deactivating:
        funcs.addAll([SystemdUnitFunc.start]);
        break;
    }
    funcs.addAll([SystemdUnitFunc.status]);
    return funcs.toList();
  }
}
