import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/systemd.dart';
import 'package:server_box/data/provider/server/single.dart';

part 'systemd.freezed.dart';
part 'systemd.g.dart';

/// Outcome of [SystemdNotifier.getUnits], so the view can inform the user
/// about what failed.
enum SystemdRefreshResult {
  ok,

  /// System units could not be listed at all (no client or command failed).
  systemFailed,

  /// System units loaded, but the user manager could not be queried (e.g. no
  /// session bus over SSH). User units are simply absent.
  userFailed,
}

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
  late final ServerState _si;

  @override
  SystemdState build(Spi spi) {
    final si = ref.read(serverProvider(spi.id));
    _si = si;
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

  /// Refreshes the unit list and reports what, if anything, failed so the view
  /// can inform the user instead of silently dropping units.
  Future<SystemdRefreshResult> getUnits() async {
    state = state.copyWith(isBusy: true);

    try {
      final client = _si.client;
      if (client == null) return SystemdRefreshResult.systemFailed;

      final system = await _listScope(client, SystemdUnitScope.system);
      if (system.failed) return SystemdRefreshResult.systemFailed;

      final user = await _listScope(client, SystemdUnitScope.user);

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

  /// Lists the units of [scope].
  ///
  /// systemctl prints nothing for an empty list, so non-empty output that
  /// yields no units means it reported an error (no session bus, systemd not
  /// the init system, command missing) rather than an empty list.
  Future<({List<SystemdUnit> units, bool failed})> _listScope(
    SSHClient client,
    SystemdUnitScope scope,
  ) async {
    try {
      final raw = await client.execForOutput(scope.listUnitsCmd);
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
