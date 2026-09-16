import 'dart:collection';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/service/detector.dart';
import 'package:server_box/data/service/openrc.dart';
import 'package:server_box/data/service/procd.dart';
import 'package:server_box/data/service/service_manager.dart';
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

final class _ThrowingExec implements ServerExec {
  _ThrowingExec(this.answer);

  /// A result, or null to throw — the way a dropped connection does rather
  /// than a command that exits non-zero.
  final ExecResult? Function(String script) answer;

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
    await Future<void>.delayed(Duration.zero);
    return answer(script) ?? (throw StateError('channel closed: $script'));
  }
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
      expect(sshd.subState, 'running');
      expect(sshd.actions, [ServiceAction.stop, ServiceAction.restart]);

      expect(units[1].state, ServiceState.stopped);
      expect(units[2].state, ServiceState.failed);
      expect(units[3].type, ServiceUnitType.socket);
      expect(units[4].type, ServiceUnitType.timer);
    });

    test('keeps system units when the user scope is unavailable', () async {
      final exec = _QueueExec([
        _result(stdout: output),
        _result(),
        _result(
          exitCode: 1,
          stderr: 'Failed to connect to bus: No medium found',
        ),
        _result(exitCode: 1),
      ]);

      final listing = await const SystemdServiceManager().list(exec);

      expect(listing.units, hasLength(5));
      expect(listing.notice, ServiceListingNotice.userScopeUnavailable);
      expect(exec.scripts, [
        SystemdServiceManager.listCommand(ServiceScope.system),
        SystemdServiceManager.detailsCommand(ServiceScope.system),
        SystemdServiceManager.listCommand(ServiceScope.user),
        SystemdServiceManager.detailsCommand(ServiceScope.user),
      ]);
    });

    test('ignores stderr warnings from successful listings', () async {
      final exec = _QueueExec([
        _result(stderr: 'fake.service loaded active running warning'),
        _result(),
        _result(),
        _result(),
      ]);

      final listing = await const SystemdServiceManager().list(exec);

      expect(listing.units, isEmpty);
      expect(listing.notice, isNull);
    });

    test('treats a non-zero result as failed even with parsed units', () async {
      final exec = _QueueExec([
        _result(exitCode: 1, stdout: output, stderr: 'partial failure'),
        _result(),
        _result(),
        _result(),
      ]);

      await expectLater(
        const SystemdServiceManager().list(exec),
        throwsA(isA<ServiceManagerLoadException>()),
      );
    });

    test('builds scoped commands, and only system units need root', () {
      const system = ServiceUnit(
        name: 'sshd',
        type: ServiceUnitType.service,
        scope: ServiceScope.system,
        state: ServiceState.running,
        actions: [ServiceAction.restart],
      );
      const user = ServiceUnit(
        name: 'gpg-agent',
        type: ServiceUnitType.socket,
        scope: ServiceScope.user,
        state: ServiceState.running,
        actions: [ServiceAction.restart],
      );
      final manager = const SystemdServiceManager();

      expect(
        manager.commandFor(system, ServiceAction.restart),
        "systemctl restart 'sshd.service'",
      );
      expect(manager.needsRoot(system), isTrue);
      expect(
        terminalCommand(
          manager.commandFor(system, ServiceAction.restart),
          needsRoot: manager.needsRoot(system),
          isRoot: false,
        ),
        "sudo systemctl restart 'sshd.service'",
      );

      // `sudo systemctl --user` would reach root's user manager.
      expect(
        manager.commandFor(user, ServiceAction.restart),
        "systemctl --user restart 'gpg-agent.socket'",
      );
      expect(manager.needsRoot(user), isFalse);
      expect(
        manager.definitionCommand(user),
        "systemctl --user cat 'gpg-agent.socket'",
      );
      expect(
        manager.logCommand(user),
        "journalctl --user -e -u 'gpg-agent.socket'",
      );
    });
  });

  group('systemd listing when a call throws', () {
    const listed = 'sshd.service loaded active running OpenSSH server daemon\n';
    ExecResult ok([String stdout = '']) => _result(stdout: stdout);

    test('a details call that throws keeps the list and says so', () async {
      final exec = _ThrowingExec(
        (script) => script.contains(' show ')
            ? null
            : ok(script.contains('--user') ? '' : listed),
      );

      final listing = await const SystemdServiceManager().list(exec);

      expect(listing.units.single.name, 'sshd');
      expect(listing.notice, ServiceListingNotice.detailsUnavailable);
    });

    test('a user listing that throws is the missing user scope', () async {
      final exec = _ThrowingExec(
        (script) => script.contains('--user') ? null : ok(listed),
      );

      final listing = await const SystemdServiceManager().list(exec);

      expect(listing.units, hasLength(1));
      expect(listing.notice, ServiceListingNotice.userScopeUnavailable);
      expect(listing.detail, contains('channel closed'));
    });

    test('a system listing that throws fails the page, and only once', () async {
      // Every call throws. Any error left unobserved would fail this test on
      // its own, as it would reach the zone as a crash in the app.
      final exec = _ThrowingExec((_) => null);

      await expectLater(
        const SystemdServiceManager().list(exec),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('status is what each manager prints about a unit, sudo only where due', () {
    const system = ServiceUnit(
      name: 'nginx',
      type: ServiceUnitType.service,
      scope: ServiceScope.system,
      state: ServiceState.failed,
      actions: [],
    );
    expect(
      const SystemdServiceManager().unitStatusCommand(system),
      "systemctl status --no-pager --full 'nginx.service'",
    );
    expect(
      const OpenRcServiceManager().unitStatusCommand(system),
      "rc-service 'nginx' status",
    );
    expect(
      const ProcdServiceManager().unitStatusCommand(system),
      "'/etc/init.d/nginx' status",
    );
  });

  group('systemd details, read from a real systemd 258', () {
    String fixture(String name) =>
        File('test/fixtures/systemd/$name').readAsStringSync();

    // The device's clock is an hour ahead of the server's.
    final serverNow = DateTime.fromMillisecondsSinceEpoch(
      int.parse(fixture('show.txt').split('\n').first) * 1000,
      isUtc: true,
    );
    final deviceNow = serverNow.add(const Duration(hours: 1));

    Future<Map<String, ServiceUnit>> listing() async {
      final exec = _QueueExec([
        _result(stdout: fixture('list_units.txt')),
        _result(stdout: fixture('show.txt')),
        _result(),
        _result(),
      ]);
      final units = SystemdServiceManager.parseListUnits(
        fixture('list_units.txt'),
        ServiceScope.system,
      );
      final details = SystemdServiceManager.parseDetails(
        fixture('show.txt'),
        now: deviceNow,
      );
      // The same merge list() does, with the device clock pinned.
      final listed = await const SystemdServiceManager().list(exec);
      expect(listed.units.map((u) => u.key).toSet(), units.map((u) => u.key).toSet());
      expect(listed.notice, isNull);
      return {
        for (final unit in units)
          unit.fullName: SystemdServiceManager.withDetails(
            unit,
            details[unit.fullName],
          ),
      };
    }

    test('a failed unit keeps why, and when on this device\'s clock', () async {
      final unit = (await listing())['sbfail.service']!;

      expect(unit.state, ServiceState.failed);
      expect(unit.result, 'exit-code');
      expect(unit.exitStatus, 3);
      expect(unit.unitFileState, 'transient');
      // Neither enabled nor disabled, so neither is offered.
      expect(unit.enabled, isNull);
      expect(unit.actions, [ServiceAction.restart]);
      expect(
        unit.since,
        DateTime.utc(2026, 9, 16, 17, 12, 26).add(const Duration(hours: 1)),
      );
    });

    test('a running unit has memory; success is not a result', () async {
      final units = await listing();
      final journald = units['systemd-journald.service']!;

      expect(journald.memoryBytes, 12386304);
      expect(journald.result, isNull);
      expect(journald.unitFileState, 'enabled');
      expect(journald.enabled, isTrue);
      expect(journald.actions, contains(ServiceAction.disable));
      expect(journald.startup, 'enabled');

      // `[not set]` is not zero bytes.
      expect(units['dbus.socket']!.memoryBytes, isNull);
    });

    test('a timer with no calendar has no next elapse', () async {
      final timer = (await listing())['sbtimer.timer']!;

      expect(timer.state, ServiceState.running);
      expect(timer.subState, 'waiting');
      expect(timer.nextElapse, isNull);
    });

    test('odd values do not become measurements', () {
      expect(SystemdUnitDetails.parseMemory('18446744073709551615'), isNull);
      expect(SystemdUnitDetails.parseMemory('[not set]'), isNull);
      expect(SystemdUnitDetails.parseTimestamp(''), isNull);
      expect(SystemdUnitDetails.parseTimestamp('n/a'), isNull);
      // Only UTC is unambiguous; a zone abbreviation is refused.
      expect(
        SystemdUnitDetails.parseTimestamp('Wed 2026-09-16 12:04:31 CST'),
        isNull,
      );
    });

    test('details without the clock line are taken as they are', () {
      final details = SystemdServiceManager.parseDetails(
        'Id=a.service\nActiveEnterTimestamp=Wed 2026-09-16 17:12:26 UTC\n',
        now: deviceNow,
      );
      expect(details['a.service']!.activeEnter, DateTime.utc(2026, 9, 16, 17, 12, 26));
    });

    test('the journal loses its date and host, and says when it is unreadable', () {
      final log = SystemdServiceManager.parseJournal(fixture('journal.txt'));

      expect(log.unreadable, isFalse);
      expect(log.lines, hasLength(4));
      expect(log.lines.first.time, '01:12:26');
      expect(log.lines.first.text, 'systemd[1]: Started Fails on purpose.');

      final hidden = SystemdServiceManager.parseJournal(
        '-- No entries --\n',
        stderr:
            'Hint: You are currently not seeing messages from other users '
            'and the system.\n',
      );
      expect(hidden.lines, isEmpty);
      expect(hidden.unreadable, isTrue);

      expect(SystemdServiceManager.parseJournal('-- No entries --\n').unreadable, isFalse);
    });

    test('a failing details call keeps the list and says so', () async {
      final exec = _QueueExec([
        _result(stdout: fixture('list_units.txt')),
        _result(exitCode: 1, stderr: 'Unknown command verb show.'),
        _result(),
        _result(),
      ]);

      final listing = await const SystemdServiceManager().list(exec);

      expect(listing.units, hasLength(11));
      expect(listing.notice, ServiceListingNotice.detailsUnavailable);
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
        const ProcdServiceManager().commandFor(unit, ServiceAction.restart),
        "'/etc/init.d/dropbear' restart",
      );
      expect(const ProcdServiceManager().needsRoot(unit), isTrue);
    });

    test('reads logread lines', () {
      final lines = ProcdServiceManager.parseLogread(
        'Wed Sep 16 21:09:58 2026 daemon.err dnsmasq[1234]: failed to bind\n'
        'garbage\n',
      );

      expect(lines.first.time, '21:09:58');
      expect(lines.first.text, 'dnsmasq[1234]: failed to bind');
      expect(lines.last.time, isNull);
      expect(lines.last.text, 'garbage');
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
        manager.commandFor(unit, ServiceAction.start),
        "rc-service 'chronyd' start",
      );
      expect(
        manager.commandFor(unit, ServiceAction.enable),
        "rc-update add 'chronyd' default",
      );
      expect(
        manager.commandFor(unit, ServiceAction.disable),
        "rc-update --all delete 'chronyd'",
      );
      expect(manager.needsRoot(unit), isTrue);
    });
  });
}
