/// The command a service action's confirmation shows is the one that runs.
///
/// The confirmation used to decide `sudo` from the SSH user's name, while the
/// action itself asks the server who it runs as. Through a monitor agent, or as
/// a uid-0 account with another name, the two disagreed: the dialog showed
/// `sudo systemctl restart …` and what ran had no `sudo` in it.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/model/server/service.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/services.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/service/detector.dart';
import 'package:server_box/data/service/systemd.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-services-command';
  // Not named root, so `Spi.isRoot` is false whatever the server says.
  final spi = spiFixture(
    id: sid,
    name: 'web',
    ip: 'h',
    user: 'u',
    autoConnect: false,
  );

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.server.put(spi);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// Lists units against [exec] and answers the notifier and a system unit.
  Future<(ServicesNotifier, ServiceUnit)> listed(_SystemdExec exec) async {
    final container = ProviderContainer(
      overrides: [
        serverProvider(sid).overrideWith(() => _FakeServerNotifier(exec)),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(servicesProvider(spi).notifier);
    await notifier.getServices();
    final unit = container
        .read(servicesProvider(spi))
        .units
        .firstWhere((u) => u.scope == ServiceScope.system);
    return (notifier, unit);
  }

  test('an account the server says is root is shown no sudo', () async {
    final exec = _SystemdExec(uid: 0);
    final (notifier, unit) = await listed(exec);

    final shown = await notifier.commandFor(unit, ServiceAction.restart);
    await notifier.runAction(unit, ServiceAction.restart);

    final ran = exec.runs.last;
    expect(ran.entry, 'sh');
    expect(shown, ran.script);
    // Asked once, and the answer reused by the action.
    expect(exec.runs.where((r) => r.script == 'id -u'), hasLength(1));
  });

  test('an account that is not root is shown the sudo that runs', () async {
    final exec = _SystemdExec(uid: 1000);
    final (notifier, unit) = await listed(exec);

    final shown = await notifier.commandFor(unit, ServiceAction.restart);
    await notifier.runAction(unit, ServiceAction.restart);

    final ran = exec.runs.last;
    expect(ran.entry, startsWith('sudo '));
    expect(shown, 'sudo ${ran.script}');
  });
}

/// Hands out a prepared [ServerExec].
class _FakeServerNotifier extends ServerNotifier {
  _FakeServerNotifier(this.exec);

  final ServerExec exec;

  @override
  Future<ServerExec> ensureExec({VoidCallback? onSshDial}) async => exec;
}

/// A systemd host whose account has [uid], recording what it was asked to run.
class _SystemdExec implements ServerExec {
  _SystemdExec({required this.uid});

  final int uid;
  final runs = <({String script, String? entry})>[];

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
    runs.add((script: script, entry: entry));
    ExecResult ok(String stdout) =>
        ExecResult(exitCode: 0, stdout: stdout, stderr: '');

    if (script == ServiceManagerDetector.script) {
      return ok('systemd\tDebian GNU/Linux');
    }
    if (script == SystemdServiceManager.listCommand(ServiceScope.system)) {
      return ok(File('test/fixtures/systemd/list_units.txt').readAsStringSync());
    }
    if (script == 'id -u') return ok('$uid\n');
    // Details are optional to a listing, and not what this is about.
    for (final scope in ServiceScope.values) {
      if (script == SystemdServiceManager.detailsCommand(scope)) {
        return const ExecResult(exitCode: 1, stdout: '', stderr: 'no');
      }
    }
    return ok('');
  }
}
