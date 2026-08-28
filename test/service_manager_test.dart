import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/service/detector.dart';
import 'package:server_box/data/service/openrc.dart';
import 'package:server_box/data/service/procd.dart';
import 'package:server_box/data/service/systemd.dart';

final class _QueueExec implements ServerExec {
  _QueueExec(List<ExecResult> results) : results = Queue.of(results);

  final Queue<ExecResult> results;
  final scripts = <String>[];

  @override
  Future<ExecResult> run(
    String script, {
    String? entry,
    Map<String, String>? env,
    String? stdin,
    OnExecOutput? onStdout,
    OnExecOutput? onStderr,
    Future<void>? cancel,
  }) async {
    scripts.add(script);
    return results.removeFirst();
  }
}

ExecResult _result({
  int? exitCode = 0,
  String stdout = '',
  String stderr = '',
}) {
  return ExecResult(exitCode: exitCode, stdout: stdout, stderr: stderr);
}

void main() {
  group('ServiceManagerDetector', () {
    test('recognizes every supported manager', () {
      expect(
        ServiceManagerDetector.parse('systemd\tDebian GNU/Linux').type,
        ServiceManagerType.systemd,
      );
      expect(
        ServiceManagerDetector.parse('procd\tiStoreOS 25.12.5').type,
        ServiceManagerType.procd,
      );
      expect(
        ServiceManagerDetector.parse('openrc\tAlpine Linux').type,
        ServiceManagerType.openrc,
      );
    });

    test('keeps the detected unsupported manager and OS', () {
      final probe = ServiceManagerDetector.parse('runit\tVoid Linux');

      expect(probe.type, isNull);
      expect(probe.detectedName, 'runit');
      expect(probe.description, 'runit (Void Linux)');
    });

    test('checks procd before the generic init.d fallback', () {
      expect(
        ServiceManagerDetector.script.indexOf('manager=procd'),
        lessThan(ServiceManagerDetector.script.indexOf('manager=sysvinit')),
      );
    });
  });

  group('SystemdServiceManager', () {
    const output = '''
sshd.service loaded active running OpenSSH server daemon
nginx.service loaded inactive dead A high performance web server
broken.service loaded failed failed Broken unit description
dbus.socket loaded active running D-Bus System Message Bus Socket
backup.timer loaded active waiting Daily backup timer
unsupported.target loaded active active A target
''';

    test('parses unit type, state, scope, and description', () {
      final units = SystemdServiceManager.parseListUnits(
        output,
        ServiceScope.system,
      );

      expect(units, hasLength(5));
      final sshd = units.first;
      expect(sshd.name, 'sshd');
      expect(sshd.type, ServiceUnitType.service);
      expect(sshd.state, ServiceState.running);
      expect(sshd.scope, ServiceScope.system);
      expect(sshd.description, 'OpenSSH server daemon');
      expect(sshd.actions, [ServiceAction.stop, ServiceAction.restart,
        ServiceAction.status]);

      expect(units[1].state, ServiceState.stopped);
      expect(units[2].state, ServiceState.failed);
      expect(units[3].type, ServiceUnitType.socket);
      expect(units[4].type, ServiceUnitType.timer);
    });

    test('keeps system units when the user scope is unavailable', () async {
      final exec = _QueueExec([
        _result(stdout: output),
        _result(stderr: 'Failed to connect to bus: No medium found'),
      ]);

      final listing = await const SystemdServiceManager().list(exec);

      expect(listing.units, hasLength(5));
      expect(listing.notice, ServiceListingNotice.userScopeUnavailable);
      expect(exec.scripts, [
        SystemdServiceManager.listCommand(ServiceScope.system),
        SystemdServiceManager.listCommand(ServiceScope.user),
      ]);
    });

    test('builds scoped and privileged commands', () {
      const unit = ServiceUnit(
        name: 'sshd',
        type: ServiceUnitType.service,
        scope: ServiceScope.system,
        state: ServiceState.running,
        actions: [ServiceAction.restart],
      );
      final manager = const SystemdServiceManager();

      expect(
        manager.commandFor(unit, ServiceAction.restart, isRoot: false),
        "sudo systemctl restart 'sshd.service'",
      );
    });
  });

  group('ProcdServiceManager', () {
    const catalog = '''
dnsmasq\t1
dropbear\t1
rpcd\t1
uhttpd\t0
''';
    const status = '''
{
  "dnsmasq": {"instances": {"cfg01411c": {"running": true}}},
  "uhttpd": {"instances": {"instance1": {"running": false}}},
  "rpcd": {"instances": {}},
  "../../tmp/not-an-init-script": {"instances": {"x": {"running": true}}}
}
''';

    test('merges init scripts, startup links, and ubus state', () async {
      final exec = _QueueExec([
        _result(stdout: catalog),
        _result(stdout: status),
      ]);

      final listing = await const ProcdServiceManager().list(exec);

      expect(listing.notice, isNull);
      expect(listing.units.map((unit) => unit.name),
          ['dnsmasq', 'dropbear', 'rpcd', 'uhttpd']);
      final dnsmasq = listing.units.first;
      expect(dnsmasq.state, ServiceState.running);
      expect(dnsmasq.enabled, isTrue);
      expect(dnsmasq.actions, contains(ServiceAction.disable));

      final dropbear = listing.units[1];
      expect(dropbear.state, ServiceState.unknown);
      expect(dropbear.enabled, isTrue);

      final uhttpd = listing.units.last;
      expect(uhttpd.state, ServiceState.stopped);
      expect(uhttpd.enabled, isFalse);
      expect(uhttpd.actions, contains(ServiceAction.enable));
    });

    test('keeps the catalog when ubus status is unavailable', () async {
      final exec = _QueueExec([
        _result(stdout: catalog),
        _result(exitCode: 1, stderr: 'Command failed: Not found'),
      ]);

      final listing = await const ProcdServiceManager().list(exec);

      expect(listing.units, hasLength(4));
      expect(listing.notice, ServiceListingNotice.detailsUnavailable);
      expect(listing.units.every(
        (unit) => unit.state == ServiceState.unknown,
      ), isTrue);
    });

    test('builds init script commands', () {
      const unit = ServiceUnit(
        name: 'dropbear',
        type: ServiceUnitType.service,
        scope: ServiceScope.system,
        state: ServiceState.running,
        actions: [ServiceAction.restart],
      );

      expect(
        const ProcdServiceManager().commandFor(
          unit,
          ServiceAction.restart,
          isRoot: false,
        ),
        "sudo '/etc/init.d/dropbear' restart",
      );
    });
  });

  group('OpenRcServiceManager', () {
    const catalog = '''
acpid
chronyd
localmount
networking
sshd
''';
    const status = '''
 acpid                  [  started  ]
 chronyd                [  stopped  ]
 localmount             [  crashed  ]
 networking             [  starting ]
''';
    const startup = '''
             acpid | default
        localmount | boot
''';

    test('parses service state and enabled runlevels', () async {
      final exec = _QueueExec([
        _result(stdout: catalog),
        _result(stdout: status),
        _result(stdout: startup),
      ]);

      final listing = await const OpenRcServiceManager().list(exec);

      expect(listing.notice, isNull);
      expect(listing.units.map((unit) => unit.name),
          ['acpid', 'chronyd', 'localmount', 'networking', 'sshd']);
      expect(listing.units[0].state, ServiceState.running);
      expect(listing.units[0].enabled, isTrue);
      expect(listing.units[1].state, ServiceState.stopped);
      expect(listing.units[1].enabled, isFalse);
      expect(listing.units[2].state, ServiceState.failed);
      expect(listing.units[3].state, ServiceState.starting);
      expect(listing.units[4].state, ServiceState.unknown);
      expect(listing.units[4].enabled, isFalse);
    });

    test('builds rc-service and rc-update commands', () {
      const unit = ServiceUnit(
        name: 'chronyd',
        type: ServiceUnitType.service,
        scope: ServiceScope.system,
        state: ServiceState.stopped,
        enabled: false,
        actions: [ServiceAction.start, ServiceAction.enable],
      );
      final manager = const OpenRcServiceManager();

      expect(
        manager.commandFor(unit, ServiceAction.start, isRoot: true),
        "rc-service 'chronyd' start",
      );
      expect(
        manager.commandFor(unit, ServiceAction.enable, isRoot: false),
        "sudo rc-update add 'chronyd' default",
      );
      expect(
        manager.commandFor(unit, ServiceAction.disable, isRoot: false),
        "sudo rc-update --all delete 'chronyd'",
      );
    });
  });
}
