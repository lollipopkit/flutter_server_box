import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/bmc/common.dart';
import 'package:server_box/view/page/server/bmc/drives.dart';
import 'package:server_box/view/page/server/bmc/logs.dart';
import 'package:server_box/view/page/server/bmc/panel.dart';

const _event = LogService(
  path: '/redfish/v1/Systems/1/LogServices/EventLog',
  id: 'EventLog',
  name: 'Event Log',
  scope: LogScope.system,
  entries: '/redfish/v1/Systems/1/LogServices/EventLog/Entries',
  clearTarget: '/redfish/v1/Systems/1/LogServices/EventLog/Actions/LogService.ClearLog',
);

const _journal = LogService(
  path: '/redfish/v1/Managers/bmc/LogServices/Journal',
  id: 'Journal',
  name: 'Journal',
  scope: LogScope.manager,
  entries: '/redfish/v1/Managers/bmc/LogServices/Journal/Entries',
);

/// A BMC answering from memory, recording what was asked of it.
final class _FakeBmc extends BmcNotifier {
  final cleared = <LogService>[];
  final clearedGens = <int?>[];
  final entriesGens = <int?>[];
  final ejectedGens = <int?>[];
  var _gen = 0;
  var serviceLoadCount = 0;
  var slots = const <MediaSlot>[];
  var eventEntries = const [
    LogEntry(id: '2', severity: 'Critical', message: 'CPU 1 over temperature'),
    LogEntry(id: '1', severity: 'OK', message: 'Power on'),
  ];
  StorageReport report = const StorageReport(
    drives: [],
    truncated: false,
    unsupported: true,
  );

  @override
  int get endpointGeneration => _gen;

  void bumpGeneration() {
    _gen++;
    state = state.copyWith(isBusy: !state.isBusy);
  }

  @override
  BmcState build(String targetId) => const BmcState();

  @override
  Future<List<LogService>> logServices() async {
    serviceLoadCount++;
    return [_event, _journal];
  }

  @override
  Future<LogPage> logEntries(
    LogService service, {
    int? expectedGeneration,
  }) async {
    entriesGens.add(expectedGeneration);
    if (expectedGeneration != null && expectedGeneration != _gen) {
      throw const BmcError(failure: RedfishFailure.closed);
    }
    return service == _event
        ? LogPage(
            entries: eventEntries,
            total: BigInt.from(eventEntries.isEmpty ? 0 : 500),
            truncated: eventEntries.isNotEmpty,
          )
        : const LogPage(
            entries: [LogEntry(id: 'j', message: 'bmcweb started')],
            truncated: false,
          );
  }

  @override
  Future<void> clearLog(LogService service, {int? expectedGeneration}) async {
    clearedGens.add(expectedGeneration);
    if (expectedGeneration != null && expectedGeneration != _gen) {
      throw const BmcError(failure: RedfishFailure.closed);
    }
    cleared.add(service);
    eventEntries = const [];
  }

  @override
  Future<StorageReport> storage() async => report;

  @override
  Future<List<MediaSlot>> mediaSlots() async => slots;

  @override
  Future<void> ejectMedia(MediaSlot slot, {int? expectedGeneration}) async {
    ejectedGens.add(expectedGeneration);
    if (expectedGeneration != null && expectedGeneration != _gen) {
      throw const BmcError(failure: RedfishFailure.closed);
    }
  }
}

final class _FakeTargets extends BmcTargetsNotifier {
  _FakeTargets(this._target);
  final BmcTarget _target;

  @override
  BmcTargetsState build() => BmcTargetsState(
    targets: {_target.id: _target},
    order: [_target.id],
  );

  void replace(BmcTarget next) {
    state = state.copyWith(targets: {...state.targets, next.id: next});
  }
}

void main() {
  const target = BmcTarget(
    id: 'bmc-web',
    name: 'web',
    addr: 'https://10.0.0.9',
  );
  late _FakeBmc bmc;

  setUp(() => bmc = _FakeBmc());
  tearDown(Toast.dismissAll);

  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bmcTargetsProvider.overrideWith(() => _FakeTargets(target)),
          bmcProvider(target.id).overrideWith(() => bmc),
        ],
        child: MaterialApp(
          localizationsDelegates: app_locale.appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => ToastHost(child: child ?? const SizedBox()),
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return page;
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('logs: the event log first, and cleared', (
    tester,
  ) async {
    await pump(tester, const BmcLogsPage(args: BmcTargetRequiredArgs(target)));

    expect(find.text('Event Log'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('CPU 1 over temperature'), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep), findsOneWidget);
    expect(find.text(app_locale.l10n.bmcEntriesTruncated), findsOneWidget);

    // The BMC's own log cannot be cleared: nothing offers it.
    await tester.tap(find.text('Journal'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('bmcweb started'), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep), findsNothing);

    await tester.tap(find.text('Event Log'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byIcon(Icons.delete_sweep));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text(app_locale.l10n.bmcClearLogConfirm('Event Log', target.name)),
      findsOneWidget,
    );
    expect(bmc.cleared, isEmpty);
    await tester.tap(find.text(libL10n.ok));
    // The answer once the sheet is gone, then the loading sheet in and out.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    expect(bmc.cleared, [_event]);
    expect(find.text(libL10n.empty), findsOneWidget);
  });

  testWidgets('drives: a failing one comes first', (tester) async {
    bmc.report = StorageReport(
      drives: [
        Drive(model: 'good', health: 'OK', needsAttention: false),
        Drive(
          model: 'failing',
          health: 'OK',
          failurePredicted: true,
          capacityBytes: BigInt.from(1 << 30),
          needsAttention: true,
        ),
      ],
      truncated: false,
      unsupported: false,
    );
    await pump(
      tester,
      const BmcDrivesPage(args: BmcTargetRequiredArgs(target)),
    );

    final failing = tester.getTopLeft(find.text('failing'));
    final good = tester.getTopLeft(find.text('good'));
    expect(failing.dy, lessThan(good.dy));
    expect(find.byIcon(Icons.warning), findsOneWidget);
  });

  testWidgets('drives: a service without storage says so', (tester) async {
    await pump(
      tester,
      const BmcDrivesPage(args: BmcTargetRequiredArgs(target)),
    );
    expect(find.text(app_locale.l10n.bmcNoStorage), findsOneWidget);
  });

  testWidgets('drives: retains report on rename, discards stale report on addr change', (
    tester,
  ) async {
    bmc.report = const StorageReport(
      drives: [Drive(model: 'old-drive', health: 'OK', needsAttention: false)],
      truncated: false,
      unsupported: false,
    );
    final targets = _FakeTargets(target);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bmcTargetsProvider.overrideWith(() => targets),
          bmcProvider(target.id).overrideWith(() => bmc),
        ],
        child: MaterialApp(
          localizationsDelegates: app_locale.appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => ToastHost(child: child ?? const SizedBox()),
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const BmcDrivesPage(args: BmcTargetRequiredArgs(target));
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('old-drive'), findsOneWidget);

    // Name-only change keeps the loaded report without losing it.
    targets.replace(target.copyWith(name: 'renamed'));
    await tester.pump();
    expect(find.text('old-drive'), findsOneWidget);
    expect(find.text('renamed'), findsOneWidget);

    // Address change drops the stale report and loads from the new endpoint.
    bmc.report = const StorageReport(
      drives: [Drive(model: 'new-drive', health: 'OK', needsAttention: false)],
      truncated: false,
      unsupported: false,
    );
    targets.replace(target.copyWith(name: 'renamed', addr: 'https://10.0.0.22'));
    await tester.pump();
    expect(find.text('old-drive'), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('new-drive'), findsOneWidget);
  });

  testWidgets('logs: reloads services when endpointGeneration changes and passes new generation', (
    tester,
  ) async {
    await pump(tester, const BmcLogsPage(args: BmcTargetRequiredArgs(target)));
    expect(bmc.serviceLoadCount, 1);
    expect(bmc.entriesGens, [0]);

    // Simulate credential rotation bumping endpointGeneration without changing
    // BmcTarget's fields.
    bmc.bumpGeneration();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(bmc.serviceLoadCount, 2);
    expect(bmc.entriesGens.last, 1);

    // Clear log now succeeds using the refreshed generation 1.
    await tester.tap(find.byIcon(Icons.delete_sweep));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text(libL10n.ok));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(bmc.clearedGens, [1]);
    expect(bmc.cleared, [_event]);
  });

  testWidgets('virtual media: forwards captured generation and rejects stale sheet actions', (
    tester,
  ) async {
    bmc.slots = const [
      MediaSlot(
        path: '/redfish/v1/Managers/bmc/VirtualMedia/CD1',
        id: 'CD1',
        name: 'Virtual CD',
        mediaTypes: ['CD'],
        inserted: true,
        image: 'https://10.0.0.2/os.iso',
      ),
    ];

    await pump(
      tester,
      Consumer(
        builder: (context, ref, _) {
          ref.watch(bmcProvider(target.id));
          return Center(
            child: TextButton(
              onPressed: () =>
                  BmcManageActions.openMediaSheet(context, ref, target),
              child: const Text('OPEN_MEDIA'),
            ),
          );
        },
      ),
    );

    await tester.tap(find.text('OPEN_MEDIA'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Virtual CD'), findsOneWidget);

    // Endpoint rebuilds while media sheet is open.
    bmc.bumpGeneration();
    await tester.pump();

    await tester.tap(find.text(app_locale.l10n.bmcEjectMedia));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // Eject was invoked with the sheet's original generation 0 and rejected.
    expect(bmc.ejectedGens, [0]);
    expect(find.text('Virtual CD'), findsOneWidget);
  });
}
