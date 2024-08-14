import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

enum SystemdUnitFunc {
  start,
  stop,
  restart,
  reload,
  enable,
  disable,
  status,
  ;

  IconData get icon => switch (this) {
        start => Icons.play_arrow,
        stop => Icons.stop,
        restart => Icons.refresh,
        reload => Icons.refresh,
        enable => Icons.check,
        disable => Icons.close,
        status => Icons.info,
      };
}

enum SystemdUnitType {
  service,
  socket,
  mount,
  timer,
  ;

  static SystemdUnitType? fromString(String? value) {
    return values.firstWhereOrNull((e) => e.name == value?.toLowerCase());
  }
}

enum SystemdUnitScope {
  system,
  user,
  ;

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
}

enum SystemdUnitState {
  active,
  inactive,
  failed,
  activating,
  deactivating,
  ;

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

  String getCmd({
    required SystemdUnitFunc func,
    required bool isRoot,
  }) {
    final prefix = scope.getCmdPrefix(isRoot);
    return '$prefix ${func.name} $name';
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
