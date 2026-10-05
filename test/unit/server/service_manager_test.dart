import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/service/service_manager.dart';
import 'package:server_box/src/rust/api/service.dart' as ffi;

import '../../helpers/rust_lib_helper.dart';

/// Answers each listing command by its `sbm_parser::service` name.
final class _ByName implements ServerExec {
  _ByName(ServiceManagerType type, this.answers)
    : names = {
        for (final c in ffi.serviceListingCommands(managerName: type.name)) c.command!: c.name,
      };

  final Map<String, String> names;
  final Map<String, ExecResult?> answers;

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
    final name = names[script] ?? script;
    return answers[name] ?? (throw StateError('channel closed'));
  }
}

ExecResult _ok(String stdout) => ExecResult(exitCode: 0, stdout: stdout, stderr: '');
ExecResult _fail(String stderr) => ExecResult(exitCode: 1, stdout: '', stderr: stderr);

String _fixture(String name) =>
    File('crates/sbm_parser/tests/fixtures/systemd/$name').readAsStringSync();

/// The app's half of the services page: `sbm_parser::service`'s commands
/// and listings reaching the page's model whole, and its timestamps moved
/// onto this device's clock. What the commands are and how their output
/// reads is asserted on the Rust side (`service_compat.rs`).
void main() {
  setUpAll(initRustLibForTest);

  test('the manager the machine runs', () async {
    final exec = _ByName(ServiceManagerType.systemd, {
      ffi.serviceDetectScript(): _ok('openrc\tAlpine Linux'),
    });
    final probe = await ServiceManager.probe(exec);
    expect((probe.type, probe.description), (ServiceManagerType.openrc, 'OpenRC (Alpine Linux)'));
  });

  test('a systemd listing, on this device clock', () async {
    final exec = _ByName(ServiceManagerType.systemd, {
      'system_list': _ok(_fixture('list_units.txt')),
      'system_details': _ok(_fixture('show.txt')),
      'user_list': _ok(''),
      'user_details': _ok(''),
    });
    final listing = await const ServiceManager(ServiceManagerType.systemd).list(exec);
    expect(listing.notice, isNull);
    expect(listing.units, hasLength(11));
    // The fixture was printed long ago: moved onto this clock, a running
    // unit's start is not in the past by that much.
    final since = listing.units.firstWhere((u) => u.since != null).since!;
    expect(DateTime.now().difference(since).inDays, lessThan(1));
  });

  test('a listing that cannot be read says why', () async {
    final exec = _ByName(ServiceManagerType.systemd, {
      'system_list': _fail('Access denied'),
      'system_details': _ok(''),
      'user_list': _ok(''),
      'user_details': _ok(''),
    });
    await expectLater(
      const ServiceManager(ServiceManagerType.systemd).list(exec),
      throwsA(isA<ServiceManagerLoadException>().having((e) => e.detail, 'detail', 'Access denied')),
    );
  });

  test('a command that throws is a part that failed, not a crash', () async {
    final exec = _ByName(ServiceManagerType.systemd, {
      'system_list': _ok(_fixture('list_units.txt')),
      'system_details': null,
      'user_list': null,
      'user_details': null,
    });
    final listing = await const ServiceManager(ServiceManagerType.systemd).list(exec);
    expect(listing.notice, ServiceListingNotice.userScopeUnavailable);
  });

  test('a unit crosses back to name its commands', () {
    const unit = ServiceUnit(
      name: 'chronyd',
      type: ServiceUnitType.service,
      scope: ServiceScope.system,
      state: ServiceState.stopped,
      enabled: false,
      actions: [ServiceAction.start, ServiceAction.enable],
    );
    const openrc = ServiceManager(ServiceManagerType.openrc);
    expect(openrc.commandFor(unit, ServiceAction.enable), "rc-update add 'chronyd' default");
    expect(openrc.needsRoot(unit), isTrue);
    expect(openrc.logCommand(unit), isNull);
    expect(terminalCommand('x', needsRoot: true, isRoot: false), 'sudo x');
  });

  test('a procd log, and none where logread is missing', () async {
    const unit = ServiceUnit(
      name: 'dnsmasq',
      type: ServiceUnitType.service,
      scope: ServiceScope.system,
      state: ServiceState.running,
      actions: [],
    );
    const procd = ServiceManager(ServiceManagerType.procd);
    final command = "logread -e 'dnsmasq' | tail -n 5";
    final log = await procd.recentLog(
      _ByName(ServiceManagerType.procd, {command: _ok('Wed Sep 16 21:09:58 2026 daemon.err dnsmasq[1]: x\n')}),
      unit,
    );
    expect(log!.lines.single.time, '21:09:58');
    expect(await procd.recentLog(_ByName(ServiceManagerType.procd, {command: _fail('not found')}), unit), isNull);
  });
}
