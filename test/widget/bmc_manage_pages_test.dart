import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/bmc/bmc.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/src/rust/api/bmc.dart';
import 'package:server_box/view/page/server/bmc/drives.dart';
import 'package:server_box/view/page/server/bmc/logs.dart';

import '../helpers/spi_fixture.dart';

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
  BmcState build(Spi spi) => const BmcState();

  @override
  Future<List<LogService>> logServices() async => [_event, _journal];

  @override
  Future<LogPage> logEntries(LogService service) async => service == _event
      ? LogPage(entries: eventEntries, total: BigInt.from(500), truncated: true)
      : const LogPage(
          entries: [LogEntry(id: 'j', message: 'bmcweb started')],
          truncated: false,
        );

  @override
  Future<void> clearLog(LogService service) async {
    cleared.add(service);
    eventEntries = const [];
  }

  @override
  Future<StorageReport> storage() async => report;
}

void main() {
  final spi = spiFixture(name: 'web', id: 'web');
  late _FakeBmc bmc;

  setUp(() => bmc = _FakeBmc());
  tearDown(Toast.dismissAll);

  Future<void> pump(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [bmcProvider(spi).overrideWith(() => bmc)],
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
    await pump(tester, BmcLogsPage(args: SpiRequiredArgs(spi)));

    expect(find.text('Event Log'), findsOneWidget);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('CPU 1 over temperature'), findsOneWidget);
    expect(find.byIcon(Icons.delete_sweep), findsOneWidget);

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
      find.text(app_locale.l10n.bmcClearLogConfirm('Event Log', spi.name)),
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
    await pump(tester, BmcDrivesPage(args: SpiRequiredArgs(spi)));

    final failing = tester.getTopLeft(find.text('failing'));
    final good = tester.getTopLeft(find.text('good'));
    expect(failing.dy, lessThan(good.dy));
    expect(find.byIcon(Icons.warning), findsOneWidget);
  });

  testWidgets('drives: a service without storage says so', (tester) async {
    await pump(tester, BmcDrivesPage(args: SpiRequiredArgs(spi)));
    expect(find.text(app_locale.l10n.bmcNoStorage), findsOneWidget);
  });
}
