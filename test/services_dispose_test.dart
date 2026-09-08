/// Listing units for a page that has already gone.
///
/// `servicesProvider` is keyed by the whole `Spi`, so saving a server edit
/// makes a *different* provider and disposes this one — while the listing
/// started before the edit is still in flight. Writing `state` then throws
/// `UnmountedRefException` out of a future nobody awaits, which reaches the
/// zone handler and is reported as a crash: it was, from a device that had
/// saved the same server's editor twice in ten seconds.
///
/// Nothing in the page can see this. The listing is correct, the failure is in
/// what happens to it afterwards, and the exception names Riverpod rather than
/// anything in this repository.
library;

import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_exec.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/services.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-services-1';
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

  /// A container whose servers hand out [exec], or refuse if it is null.
  ProviderContainer containerWith(ServerExec? exec) => ProviderContainer(
    overrides: [
      serverProvider(sid).overrideWith(() => _FakeServerNotifier(exec)),
    ],
  );

  test('a server that answers after the page closed', () async {
    // The listing succeeds — this is the ordinary path, arriving late.
    final gate = Completer<void>();
    final container = containerWith(_GatedExec(gate.future));
    final pending = container.read(servicesProvider(spi).notifier).getServices();

    // Far enough in to be waiting on the probe.
    await Future<void>.delayed(Duration.zero);
    container.dispose();
    gate.complete();

    await expectLater(pending, completes);
  });

  test('a server that fails after the page closed', () async {
    // The other half: `ensureExec` throwing is the common case — the machine is
    // off, or the credentials were what the user was editing — and its handler
    // writes `state` as well.
    final container = containerWith(null);
    final pending = container.read(servicesProvider(spi).notifier).getServices();

    container.dispose();

    await expectLater(pending, completes);
  });

  test('a listing that arrives in time is still kept', () async {
    // The guards must not have turned the ordinary path into a no-op.
    final container = containerWith(_GatedExec(Future.value()));
    addTearDown(container.dispose);
    final notifier = container.read(servicesProvider(spi).notifier);

    await notifier.getServices();

    final state = container.read(servicesProvider(spi));
    expect(state.isBusy, isFalse);
    // Nothing on the far side answers the probe, so this is the "no init system
    // found" answer rather than a list of units — what matters here is that an
    // answer was written at all.
    expect(state.failure?.issue, ServiceIssue.unsupported);
  });
}

/// Hands out a prepared [ServerExec], or refuses like an unreachable machine.
class _FakeServerNotifier extends ServerNotifier {
  _FakeServerNotifier(this.exec);

  final ServerExec? exec;

  @override
  Future<ServerExec> ensureExec() async {
    final exec = this.exec;
    if (exec == null) throw StateError('offline: this test does not connect');
    return exec;
  }
}

/// Answers nothing, and only once [gate] has completed.
///
/// The gate is what puts the dispose *between* the request and its answer,
/// which is the window the whole file is about.
class _GatedExec implements ServerExec {
  const _GatedExec(this.gate);

  final Future<void> gate;

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
    await gate;
    return const ExecResult(exitCode: 0, stdout: '', stderr: '');
  }
}
