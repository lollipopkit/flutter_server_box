import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
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
        return state.units.where((unit) => unit.scope == SystemdUnitScope.system).toList();
      case SystemdScopeFilter.user:
        return state.units.where((unit) => unit.scope == SystemdUnitScope.user).toList();
    }
  }

  void setScopeFilter(SystemdScopeFilter filter) {
    state = state.copyWith(scopeFilter: filter);
  }

  Future<void> getUnits() async {
    state = state.copyWith(isBusy: true);

    try {
      final client = _si.client;
      final result = await client!.execForOutput(_getUnitsCmd);
      final units = result.split('\n');

      final userUnits = <String>[];
      final systemUnits = <String>[];
      for (final unit in units) {
        final maybeSystem = unit.contains('/systemd/system');
        final maybeUser = unit.contains('/.config/systemd/user');
        if (maybeSystem && !maybeUser) {
          systemUnits.add(unit);
        } else {
          userUnits.add(unit);
        }
      }

      final parsedUserUnits = await _parseUnitObj(userUnits, SystemdUnitScope.user);
      final parsedSystemUnits = await _parseUnitObj(systemUnits, SystemdUnitScope.system);
      state = state.copyWith(units: [...parsedUserUnits, ...parsedSystemUnits], isBusy: false);
    } catch (e, s) {
      dprint('Parse systemd', e, s);
      state = state.copyWith(isBusy: false);
    }
  }

  Future<List<SystemdUnit>> _parseUnitObj(List<String> unitNames, SystemdUnitScope scope) async {
    final unitNames_ = unitNames.map((e) {
      final fullName = e.trim().split('/').last;
      final lastDot = fullName.lastIndexOf('.');
      final name = lastDot > 0 ? fullName.substring(0, lastDot) : fullName;
      return name.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.@:]'), '');
    }).toList();
    final script =
        '''
for unit in ${unitNames_.map((e) => '"$e"').join(' ')}; do
  state=\$(systemctl show --no-pager "\$unit")
  echo "\$state"
  echo -n "\n${ScriptConstants.separator}\n"
done
''';
    final client = _si.client!;
    final result = await client.execForOutput(script);
    final units = result.split(ScriptConstants.separator);

    final parsedUnits = <SystemdUnit>[];
    for (final unit in units.where((e) => e.trim().isNotEmpty)) {
      final parts = unit.split('\n').where((e) => e.trim().isNotEmpty).toList();
      if (parts.isEmpty) continue;
      var name = '';
      var type = '';
      var state = '';
      String? description;
      for (final part in parts) {
        if (part.startsWith('Id=')) {
          final val = _getIniVal(part);
          if (val == null) continue;
          // Id=sshd.service
          final vals = val.split('.');
          name = vals.first;
          type = vals.last;
          continue;
        }
        if (part.startsWith('ActiveState=')) {
          final val = _getIniVal(part);
          if (val == null) continue;
          state = val;
          continue;
        }
        if (part.startsWith('Description=')) {
          description = _getIniVal(part);
          continue;
        }
      }

      final unitType = SystemdUnitType.fromString(type);
      if (unitType == null) {
        dprint('Unit type: $type');
        continue;
      }
      final unitState = SystemdUnitState.fromString(state);
      if (unitState == null) {
        dprint('Unit state: $state');
        continue;
      }

      parsedUnits.add(
        SystemdUnit(name: name, type: unitType, scope: scope, state: unitState, description: description),
      );
    }

    parsedUnits.sort((a, b) {
      // user units first
      if (a.scope != b.scope) {
        return a.scope == SystemdUnitScope.user ? -1 : 1;
      }
      // active units first
      if (a.state != b.state) {
        return a.state == SystemdUnitState.active ? -1 : 1;
      }
      return a.name.compareTo(b.name);
    });
    return parsedUnits;
  }

  late final _getUnitsCmd = '''
    types="service socket mount timer"

    get_files() {
      unit_type=\$1
      base_dir=\$2
      [ -d "\$base_dir" ] || return
      find "\$base_dir" -type f -name "*.\$unit_type" -print
    }

    for type in \$types; do
      get_files \$type /etc/systemd/system
      # Parsing these paths can lead to SSH transport closed errors
      # get_files \$type /lib/systemd/system
      # get_files \$type /usr/lib/systemd/system
      get_files \$type ~/.config/systemd/user
    done | sort
    ''';
}

String? _getIniVal(String line) {
  final idx = line.indexOf('=');
  if (idx < 0) return null;
  return line.substring(idx + 1).trim();
}
