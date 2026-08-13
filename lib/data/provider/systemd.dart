import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/systemd.dart';
import 'package:server_box/data/provider/server/single.dart';

part 'systemd.freezed.dart';
part 'systemd.g.dart';

/// Outcome of [SystemdNotifier.getUnits], so the view can report what failed.
enum SystemdRefreshResult { ok, systemFailed, userFailed }

@freezed
abstract class SystemdState with _$SystemdState {
  const factory SystemdState({
    @Default(false) bool isBusy,
    @Default(<SystemdUnit>[]) List<SystemdUnit> units,
    @Default(SystemdScopeFilter.all) SystemdScopeFilter scopeFilter,
  }) = _SystemdState;
}

@riverpod
class SystemdNotifier extends _$SystemdNotifier {
  late final Spi _spi;

  @override
  SystemdState build(Spi spi) {
    _spi = spi;
    // The initial load is driven by the view so it can surface failures.
    return const SystemdState();
  }

  List<SystemdUnit> get filteredUnits {
    switch (state.scopeFilter) {
      case SystemdScopeFilter.all:
        return state.units;
      case SystemdScopeFilter.system:
        return state.units
            .where((unit) => unit.scope == SystemdUnitScope.system)
            .toList();
      case SystemdScopeFilter.user:
        return state.units
            .where((unit) => unit.scope == SystemdUnitScope.user)
            .toList();
    }
  }

  void setScopeFilter(SystemdScopeFilter filter) {
    state = state.copyWith(scopeFilter: filter);
  }

  /// System units are essential; user units are optional and only reported.
  Future<SystemdRefreshResult> getUnits() async {
    state = state.copyWith(isBusy: true);

    try {
      // Asked for rather than taken from the state: a server reached over its
      // monitor agent has no client sitting there, and one is opened on
      // demand — which is the same path the terminal and SFTP take.
      final exec = await ref.read(serverProvider(_spi.id).notifier).ensureExec();

      final system = await _listScope(exec, SystemdUnitScope.system);
      if (system.failed) return SystemdRefreshResult.systemFailed;

      final user = await _listScope(exec, SystemdUnitScope.user);

      final units = [...user.units, ...system.units]..sort(_compareUnits);
      state = state.copyWith(units: units);
      return user.failed
          ? SystemdRefreshResult.userFailed
          : SystemdRefreshResult.ok;
    } catch (e, s) {
      dprint('Systemd refresh', e, s);
      return SystemdRefreshResult.systemFailed;
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// systemctl prints nothing for an empty list, so non-empty output yielding
  /// no units means it reported an error rather than an empty list.
  Future<({List<SystemdUnit> units, bool failed})> _listScope(
    ServerExec exec,
    SystemdUnitScope scope,
  ) async {
    try {
      final raw = (await exec.run(scope.listUnitsCmd)).combined;
      final units = SystemdUnit.parseListUnits(raw, scope);
      return (units: units, failed: units.isEmpty && raw.trim().isNotEmpty);
    } catch (e, s) {
      dprint('Systemd ${scope.name} units', e, s);
      return (units: const <SystemdUnit>[], failed: true);
    }
  }
}

int _compareUnits(SystemdUnit a, SystemdUnit b) {
  // user units first
  if (a.scope != b.scope) {
    return a.scope == SystemdUnitScope.user ? -1 : 1;
  }
  // active units first
  if (a.state != b.state) {
    return a.state == SystemdUnitState.active ? -1 : 1;
  }
  return a.name.compareTo(b.name);
}
