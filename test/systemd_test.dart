import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/systemd.dart';

void main() {
  group('SystemdUnit.parseListUnits', () {
    test('parses `systemctl list-units --plain --no-legend` output', () {
      final units = SystemdUnit.parseListUnits(
        _listUnitsOutput,
        SystemdUnitScope.system,
      );

      // session-1.scope is an unsupported unit type and must be skipped;
      // reloading.service has an unmapped active state and must be skipped too.
      expect(units.length, 6);

      final sshd = units.firstWhere((u) => u.name == 'sshd');
      expect(sshd.type, SystemdUnitType.service);
      expect(sshd.state, SystemdUnitState.active);
      expect(sshd.scope, SystemdUnitScope.system);
      expect(sshd.description, 'OpenSSH server daemon');

      // Multi-word description keeps all trailing columns.
      final nginx = units.firstWhere((u) => u.name == 'nginx');
      expect(nginx.state, SystemdUnitState.inactive);
      expect(
        nginx.description,
        'A high performance web server and a reverse proxy server',
      );

      final broken = units.firstWhere((u) => u.name == 'broken');
      expect(broken.state, SystemdUnitState.failed);

      expect(units.firstWhere((u) => u.name == 'dbus').type,
          SystemdUnitType.socket);
      expect(units.firstWhere((u) => u.name == 'logrotate').type,
          SystemdUnitType.timer);

      // A unit with no description column yields a null description.
      final empty = units.firstWhere((u) => u.name == 'empty');
      expect(empty.description, isNull);
    });

    test('tags units with the requested scope', () {
      final units = SystemdUnit.parseListUnits(
        'foo.service loaded active running Foo',
        SystemdUnitScope.user,
      );
      expect(units.single.scope, SystemdUnitScope.user);
    });

    test('returns empty list for empty / error output', () {
      expect(SystemdUnit.parseListUnits('', SystemdUnitScope.system), isEmpty);
      expect(
        SystemdUnit.parseListUnits(
          'Failed to connect to bus: No such file or directory\n',
          SystemdUnitScope.user,
        ),
        isEmpty,
      );
    });

    test('skips lines with fewer than the four required columns', () {
      // Only sshd.service has the full UNIT/LOAD/ACTIVE/SUB set; the short
      // lines lack columns and must be dropped instead of throwing.
      const output = 'garbage\n'
          'partial.service loaded\n'
          'sshd.service loaded active running OpenSSH server daemon\n';
      final units = SystemdUnit.parseListUnits(output, SystemdUnitScope.system);
      expect(units.single.name, 'sshd');
    });
  });
}

// Simulated `systemctl list-units --all --no-legend --no-pager --plain` output.
const _listUnitsOutput = '''
sshd.service loaded active running OpenSSH server daemon
nginx.service loaded inactive dead A high performance web server and a reverse proxy server
dbus.socket loaded active running D-Bus System Message Bus Socket
logrotate.timer loaded active waiting Daily rotation of log files
broken.service loaded failed failed A broken unit
empty.service loaded inactive dead
session-1.scope loaded active running Unsupported type stays out
reloading.service loaded reloading start-post Unmapped active state stays out

''';
