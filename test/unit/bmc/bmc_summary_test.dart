import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/model/bmc/bmc_credential.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_sort.dart';
import 'package:server_box/data/model/server/status/cpu.dart';
import 'package:server_box/data/model/status/card_item.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/bmc_credential.dart';
import 'package:server_box/data/provider/bmc/summary.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/provider/server/sort.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/card/notices.dart';

import '../../helpers/spi_fixture.dart';

const _cred = BmcCredential(id: 'c1', name: 'bmc', user: 'root', pwd: 'pw');

final class _FakeCreds extends BmcCredentialNotifier {
  @override
  BmcCredentialState build() => const BmcCredentialState(creds: [_cred]);
}

final class _FakeTargets extends BmcTargetsNotifier {
  _FakeTargets(this._initial);

  final List<BmcTarget> _initial;

  @override
  BmcTargetsState build() => BmcTargetsState(
    targets: {for (final t in _initial) t.id: t},
    order: [for (final t in _initial) t.id],
  );

  void replace(BmcTarget target) {
    state = state.copyWith(targets: {...state.targets, target.id: target});
  }
}

RedfishTopology _topology(PowerState power, {String? health = 'OK'}) =>
    RedfishTopology(
      root: const RedfishRoot(systems: '/redfish/v1/Systems'),
      systemPath: '/redfish/v1/Systems/1',
      system: RedfishSystem(
        model: 'R750',
        powerState: power,
        health: health,
        resetTarget: '/redfish/v1/Systems/1/Actions/ComputerSystem.Reset',
        resetTypes: const ['On', 'GracefulShutdown'],
      ),
      hasMultipleSystems: false,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    BmcSummaryNotifier.testReadSummary = null;
    BmcSummaryNotifier.testPower = null;
  });

  test('BmcPollBudget caps concurrent in-flight polls to maxConcurrent', () async {
    final budget = BmcPollBudget(maxConcurrent: 2);
    var active = 0;
    var peak = 0;
    final gates = List.generate(5, (_) => Completer<void>());

    final futures = [
      for (final gate in gates)
        budget.run(() async {
          active++;
          if (active > peak) peak = active;
          await gate.future;
          active--;
        }),
    ];

    // Let first two enter.
    await Future<void>.delayed(Duration.zero);
    expect(peak, 2);
    expect(budget.activeCount, 2);

    for (final gate in gates) {
      gate.complete();
      await Future<void>.delayed(Duration.zero);
    }
    await Future.wait(futures);
    expect(peak, 2);
    expect(budget.activeCount, 0);
  });

  test('BmcSummaryNotifier does not poll or throw if disposed before microtask', () async {
    var reads = 0;
    BmcSummaryNotifier.testReadSummary = (target, known) async {
      reads++;
      return BmcSummary(topology: _topology(PowerState.on_), watts: 100.0);
    };

    const target = BmcTarget(
      id: 'bmc-disposed',
      name: 'ephemeral',
      addr: 'https://10.0.0.20',
      credId: 'c1',
    );
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_FakeCreds.new),
        bmcTargetsProvider.overrideWith(() => _FakeTargets([target])),
      ],
    );

    final sub = container.listen(bmcSummaryProvider(target.id), (_, _) {});
    sub.close();
    container.dispose();

    // Flush queued microtasks; must neither throw nor issue a poll.
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(reads, 0);
  });

  test('BmcSummaryNotifier distinguishes invalidUrl from noCredential and ignores non-connection edits', () async {
    var reads = 0;
    BmcSummaryNotifier.testReadSummary = (_, _) async {
      reads++;
      return BmcSummary(topology: _topology(PowerState.on_), watts: 90.0);
    };

    const badUrl = BmcTarget(id: 'b-bad', name: 'bad', addr: 'ftp://1.2.3.4', credId: 'c1');
    const noCred = BmcTarget(id: 'b-nc', name: 'nc', addr: 'https://10.0.0.2');
    const ok = BmcTarget(id: 'b-ok', name: 'ok', addr: 'https://10.0.0.3', credId: 'c1');
    final targets = _FakeTargets([badUrl, noCred, ok]);
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_FakeCreds.new),
        bmcTargetsProvider.overrideWith(() => targets),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(bmcSummaryProvider(badUrl.id)).failure, RedfishFailure.invalidUrl);
    expect(container.read(bmcSummaryProvider(noCred.id)).failure, RedfishFailure.noCredential);

    final done = Completer<void>();
    final sub = container.listen(bmcSummaryProvider(ok.id), (_, next) {
      if (!next.isBusy && next.hasData && !done.isCompleted) done.complete();
    }, fireImmediately: true);
    addTearDown(sub.close);
    await done.future.timeout(const Duration(seconds: 5));
    expect(reads, 1);

    // Renaming / tagging must not trigger another summary poll.
    targets.replace(ok.copyWith(name: 'renamed', tags: const ['prod']));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(reads, 1);
  });

  test('BmcSummaryNotifier polls summary, handles errors, and runs quick power', () async {
    var reads = 0;
    var power = PowerState.off;
    BmcSummaryNotifier.testReadSummary = (target, known) async {
      reads++;
      return BmcSummary(
        topology: _topology(power),
        watts: power == PowerState.on_ ? 145.0 : 12.0,
      );
    };
    BmcSummaryNotifier.testPower = (target, topo, intent) async {
      expect(intent, PowerIntent.on_);
      power = PowerState.on_;
      return const BmcOutcome();
    };

    const target = BmcTarget(
      id: 'bmc-1',
      name: 'rack-1',
      addr: 'https://10.0.0.10',
      credId: 'c1',
    );
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_FakeCreds.new),
        bmcTargetsProvider.overrideWith(() => _FakeTargets([target])),
      ],
    );
    addTearDown(container.dispose);

    final firstDone = Completer<BmcSummaryState>();
    final sub = container.listen(bmcSummaryProvider(target.id), (_, next) {
      if (!next.isBusy && next.hasData && !firstDone.isCompleted) {
        firstDone.complete(next);
      }
    }, fireImmediately: true);
    addTearDown(sub.close);

    final initial = await firstDone.future.timeout(const Duration(seconds: 5));
    expect(initial.powerState, PowerState.off);
    expect(initial.watts, 12.0);
    expect(reads, 1);

    final result = await container
        .read(bmcSummaryProvider(target.id).notifier)
        .power(PowerIntent.on_);
    expect(result, BmcPowerResult.accepted);

    // Wait for follow-up refresh triggered by power().
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final updated = container.read(bmcSummaryProvider(target.id));
    expect(updated.powerState, PowerState.on_);
    expect(updated.watts, 145.0);
    expect(reads, greaterThanOrEqualTo(2));
  });

  test('BmcSummaryNotifier.power clears isPowering and resumes refresh when connection rebuilds mid-flight', () async {
    final powerGate = Completer<void>();
    var reads = 0;
    BmcSummaryNotifier.testReadSummary = (target, _) async {
      reads++;
      return BmcSummary(topology: _topology(PowerState.off), watts: 10.0);
    };
    BmcSummaryNotifier.testPower = (_, _, _) async {
      await powerGate.future;
      return const BmcOutcome();
    };

    const target = BmcTarget(
      id: 'bmc-rebuild',
      name: 'rack',
      addr: 'https://10.0.0.10',
      credId: 'c1',
    );
    final targets = _FakeTargets([target]);
    final container = ProviderContainer(
      overrides: [
        bmcCredentialProvider.overrideWith(_FakeCreds.new),
        bmcTargetsProvider.overrideWith(() => targets),
      ],
    );
    addTearDown(container.dispose);

    final firstDone = Completer<void>();
    final sub = container.listen(bmcSummaryProvider(target.id), (_, next) {
      if (!next.isBusy && next.hasData && !firstDone.isCompleted) {
        firstDone.complete();
      }
    }, fireImmediately: true);
    addTearDown(sub.close);
    await firstDone.future.timeout(const Duration(seconds: 5));
    expect(reads, 1);

    final powerFuture = container
        .read(bmcSummaryProvider(target.id).notifier)
        .power(PowerIntent.on_);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(bmcSummaryProvider(target.id)).isPowering, isTrue);

    // Trigger a connection rebuild (changing certSha256) while power() is in flight.
    targets.replace(target.copyWith(certSha256: 'newpin'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(container.read(bmcSummaryProvider(target.id)).isPowering, isTrue);

    // Complete power(): isPowering must clear and the skipped refresh must run.
    powerGate.complete();
    await powerFuture;
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final after = container.read(bmcSummaryProvider(target.id));
    expect(after.isPowering, isFalse);
    expect(after.isBusy, isFalse);
    expect(reads, greaterThanOrEqualTo(2));
  });

  test('ServerSortOrder.applyItems sorts mixed servers and BMCs coherently', () {
    final srvZ = spiFixture(id: 's-z', name: 'zeta', ip: '10.0.0.2');
    final srvA = spiFixture(id: 's-a', name: 'alpha', ip: '10.0.0.1');
    const bmcM = BmcTarget(id: 'b-m', name: 'mid-bmc', addr: 'https://10.0.0.3');

    final items = <StatusCardItem>[
      ServerCardItem(srvZ),
      const BmcCardItem(bmcM),
      ServerCardItem(srvA),
    ];

    ServerState srvState(String id, ServerConn conn, {double? cpuUsed}) {
      final status = InitStatus.status;
      if (cpuUsed != null) {
        status.cpu = Cpus()
          ..update([
            SingleCpuCore('cpu', 100, 0, 0, 100, 0, 0, 0),
          ])
          ..update([
            SingleCpuCore(
              'cpu',
              100 + cpuUsed.round(),
              0,
              0,
              100 + (100 - cpuUsed.round()),
              0,
              0,
              0,
            ),
          ]);
      }
      return ServerState(
        spi: id == 's-z' ? srvZ : srvA,
        conn: conn,
        status: status,
      );
    }

    // Name ascending mixes both card types alphabetically.
    final byName = const ServerSortOrder(
      ServerSortField.name,
      ascending: true,
    ).applyItems(
      items,
      serverStateOf: (id) => srvState(id, ServerConn.finished),
      bmcStateOf: (_) => BmcSummaryState(topology: _topology(PowerState.on_)),
    );
    expect(byName.map((i) => i.name).toList(), ['alpha', 'mid-bmc', 'zeta']);

    // Status order places failed BMC ahead of healthy connected servers.
    final byStatus = const ServerSortOrder(
      ServerSortField.status,
      ascending: true,
    ).applyItems(
      items,
      serverStateOf: (id) => srvState(id, ServerConn.finished),
      bmcStateOf: (_) => const BmcSummaryState(
        failure: RedfishFailure.unreachable,
      ),
    );
    expect(byStatus.first, isA<BmcCardItem>());

    // CPU metric has no reading on BMCs so BMC cards sort after servers with readings.
    final byCpu = const ServerSortOrder(
      ServerSortField.cpu,
      ascending: true,
    ).applyItems(
      items,
      serverStateOf: (id) =>
          srvState(id, ServerConn.finished, cpuUsed: id == 's-z' ? 80 : 20),
      bmcStateOf: (_) => BmcSummaryState(topology: _topology(PowerState.on_)),
    );
    expect(byCpu.last, isA<BmcCardItem>());
    expect(byCpu.first.id, 's-z');
  });

  test('ServerNotice reports poweredOff when host fails and linked BMC is off', () {
    final srv = ServerState(
      spi: spiFixture(id: 's1', name: 'lab', ip: '10.0.0.1'),
      conn: ServerConn.failed,
      status: InitStatus.status,
    );

    final notice = ServerNotice.of(srv, bmcPower: PowerState.off);
    expect(notice.kind, ServerNoticeKind.poweredOff);

    final cardNotice = ServerNotice.onCard(srv, bmcPower: PowerState.off);
    expect(cardNotice?.kind, ServerNoticeKind.poweredOff);

    final whenOn = ServerNotice.of(srv, bmcPower: PowerState.on_);
    expect(whenOn.kind, isNot(ServerNoticeKind.poweredOff));
  });
}
