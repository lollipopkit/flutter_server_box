import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/systemd.dart';
import 'package:server_box/data/provider/server/single.dart';

part 'systemd.freezed.dart';
part 'systemd.g.dart';

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
    // Async initialization
    Future.microtask(() => getUnits());
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

  Future<void> getUnits() async {
    state = state.copyWith(isBusy: true);

    try {
      final client = _si.client;
      if (client == null) return;

      final systemUnits = SystemdUnit.parseListUnits(
        await client.execForOutput(SystemdUnitScope.system.listUnitsCmd),
        SystemdUnitScope.system,
      );

      // The user manager may be unavailable over SSH (no session bus). Its
      // error output simply parses to no units, so no special handling is
      // needed here.
      final userUnits = SystemdUnit.parseListUnits(
        await client.execForOutput(SystemdUnitScope.user.listUnitsCmd),
        SystemdUnitScope.user,
      );

      final units = [...userUnits, ...systemUnits]..sort(_compareUnits);
      state = state.copyWith(units: units);
    } catch (e, s) {
      dprint('Parse systemd', e, s);
    } finally {
      state = state.copyWith(isBusy: false);
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
