import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/systemd.dart';
import 'package:server_box/data/provider/server.dart';

final class SystemdProvider {
  late final VNode<Server> _si;
  late final bool _isRoot;

  SystemdProvider.init(Spi spi) {
    _isRoot = spi.isRoot;
    _si = ServerProvider.pick(spi: spi)!;
    getUnits();
  }

  final isBusy = false.vn;
  final units = <SystemdUnit>[].vn;

  void dispose() {
    isBusy.dispose();
    units.dispose();
  }

  Future<void> getUnits() async {
    isBusy.value = true;

    try {
      final client = _si.value.client;
      final result = await client!.execForOutput(_getUnitsCmd);
      final units = result.split('\n');

      final userUnits = <String>[];
      final systemUnits = <String>[];
      for (final unit in units) {
        if (unit.startsWith('/etc/systemd/system')) {
          systemUnits.add(unit);
        } else if (unit.startsWith('~/.config/systemd/user')) {
          userUnits.add(unit);
        } else if (unit.trim().isNotEmpty) {
          Loggers.app.warning('Unknown unit: $unit');
        }
      }

      final parsedUserUnits =
          await _parseUnitObj(userUnits, SystemdUnitScope.user);
      final parsedSystemUnits =
          await _parseUnitObj(systemUnits, SystemdUnitScope.system);
      this.units.value = [...parsedUserUnits, ...parsedSystemUnits];
    } catch (e, s) {
      Loggers.app.warning('Parse systemd', e, s);
    }

    isBusy.value = false;
  }

  Future<List<SystemdUnit>> _parseUnitObj(
    List<String> unitNames,
    SystemdUnitScope scope,
  ) async {
    final unitNames_ = unitNames
        .map((e) => e.trim().split('/').last.split('.').first)
        .toList();
    final script = '''
for unit in ${unitNames_.join(' ')}; do
  state=\$(systemctl show --no-pager \$unit)
  echo -n "${ShellFunc.seperator}\n\$state"
done
''';
    final client = _si.value.client!;
    final result = await client.execForOutput(script);
    final units = result.split(ShellFunc.seperator);

    final parsedUnits = <SystemdUnit>[];
    for (final unit in units) {
      final parts = unit.split('\n');
      var name = '';
      var type = '';
      var state = '';
      String? description;
      for (final part in parts) {
        if (part.startsWith('Id=')) {
          final val = _getIniVal(part).split('.');
          name = val.first;
          type = val.last;
          continue;
        }
        if (part.startsWith('ActiveState=')) {
          state = _getIniVal(part);
          continue;
        }
        if (part.startsWith('Description=')) {
          description = _getIniVal(part);
          continue;
        }
      }

      final unitType = SystemdUnitType.fromString(type);
      if (unitType == null) {
        Loggers.app.warning('Unit type: $type');
        continue;
      }
      final unitState = SystemdUnitState.fromString(state);
      if (unitState == null) {
        Loggers.app.warning('Unit state: $state');
        continue;
      }

      parsedUnits.add(SystemdUnit(
        name: name,
        type: unitType,
        scope: scope,
        state: unitState,
        description: description,
      ));
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
get_files() {
  unit_type=\$1
  base_dir=\$2

  # If base_dir is not a directory, return
  if [ ! -d "\$base_dir" ]; then
    return
  fi

  find "\$base_dir" -type f -name "*.\$unit_type" -print | sort
}

get_type_files() {
    unit_type=\$1
    base_dir=""

${_isRoot ? """
get_files \$unit_type /etc/systemd/system
get_files \$unit_type ~/.config/systemd/user""" : """
get_files \$unit_type ~/.config/systemd/user"""}
}

types="service socket mount timer"

for type in \$types; do
    get_type_files \$type
done
''';
}

String _getIniVal(String line) {
  return line.split('=').last;
}
