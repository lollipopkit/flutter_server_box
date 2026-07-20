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

      final systemUnits = SystemdUnit.parseListUnits(
        await client.execForOutput(SystemdUnitScope.system.listUnitsCmd),
        SystemdUnitScope.system,
      );

      var userUnits = <SystemdUnit>[];
      var userFailed = false;
      try {
        final userRaw =
            await client.execForOutput(SystemdUnitScope.user.listUnitsCmd);
        userUnits = SystemdUnit.parseListUnits(userRaw, SystemdUnitScope.user);
        // A successful-but-empty list yields no output. Non-empty output that
        // parses to no units means systemctl printed an error instead (e.g.
        // no session bus), which is a failure worth surfacing.
        userFailed = userUnits.isEmpty && userRaw.trim().isNotEmpty;
      } catch (e, s) {
        dprint('Systemd user units', e, s);
        userFailed = true;
      }

      final units = [...userUnits, ...systemUnits]..sort(_compareUnits);
      state = state.copyWith(units: units);
      return userFailed
          ? SystemdRefreshResult.userFailed
          : SystemdRefreshResult.ok;
    } catch (e, s) {
      dprint('Parse systemd', e, s);
      return SystemdRefreshResult.systemFailed;
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
