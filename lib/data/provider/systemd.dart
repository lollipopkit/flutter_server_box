import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/ssh_client.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/systemd.dart';
import 'package:server_box/data/res/provider.dart';

final class SystemdProvider {
  late final SSHClient _client;

  SystemdProvider.init(ServerPrivateInfo spi) {
    _client = Pros.server.pick(spi: spi)!.client!;
    getUnits();
  }

  final isBusy = false.vn;
  final isRoot = false.vn;
  final units = <SystemdUnit>[].vn;

  Future<void> getUnits() async {
    isBusy.value = true;

    final result = await _client.runScriptIn(_getUnitsCmd);
    final units = result.split('\n');
    final isRootRaw = units.firstOrNull;
    isRoot.value = isRootRaw == '0';

    final userUnits = <String>[];
    final systemUnits = <String>[];
    for (final unit in units.skip(1)) {
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

    isBusy.value = false;
  }

  Future<List<SystemdUnit>> _parseUnitObj(
    List<String> unitNames,
    SystemdUnitScope scope,
  ) async {
    final script = '''
for unit in ${unitNames.join(' ')}; do
  state=\$(systemctl show --property=ActiveState \$unit)
  echo "\$unit \$state"
done
''';
    final result = await _client.runScriptIn(script);
    final units = result.split('\n');

    final parsedUnits = <SystemdUnit>[];
    for (final unit in units) {
      if (unit.trim().isEmpty) {
        continue;
      }
      final parts = unit.split(' ');
      if (parts.length != 2) {
        Loggers.app.warning('Unit: $unit');
        continue;
      }

      final name = parts[0];
      final state = parts[1];
      final nameSplit = name.split('/').lastOrNull;
      final typeSplit = nameSplit?.split('.');
      final name_ = typeSplit?.firstOrNull;
      if (name_ == null) {
        Loggers.app.warning('Unit name: $name');
        continue;
      }

      final type = typeSplit?.lastOrNull;
      final unitType = SystemdUnitType.fromString(type);
      if (unitType == null) {
        Loggers.app.warning('Unit type: $type');
        continue;
      }

      final state_ = state.split('=').lastOrNull;
      final unitState = SystemdUnitState.fromString(state_);
      if (unitState == null) {
        Loggers.app.warning('Unit state: $state');
        continue;
      }

      parsedUnits.add(SystemdUnit(
        name: name_,
        type: unitType,
        scope: scope,
        state: unitState,
      ));
    }

    return parsedUnits;
  }
}

const _getUnitsCmd = '''
# If root, get system & user units, otherwise get user units
uid=\$(id -u)
echo \$uid

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
    if [ "\$uid" -eq 0 ]; then
        get_files \$unit_type /etc/systemd/system
        get_files \$unit_type ~/.config/systemd/user
    else
        get_files \$unit_type ~/.config/systemd/user
    fi
}

types="service socket mount timer"

for type in \$types; do
    get_type_files \$type
done
''';
