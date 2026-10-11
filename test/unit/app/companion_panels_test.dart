/// The panels a tab opens beside its subject: which are open, in what order,
/// and how the host lays them out.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/companion.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/page/companion/host.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  group('CompanionPanels', () {
    test('each tab offers the other two', () {
      expect(CompanionPanel.of(AppTab.ssh), [
        CompanionPanel.status,
        CompanionPanel.files,
      ]);
      expect(CompanionPanel.of(AppTab.file), [
        CompanionPanel.status,
        CompanionPanel.terminal,
      ]);
      expect(CompanionPanel.of(AppTab.server), [
        CompanionPanel.terminal,
        CompanionPanel.files,
      ]);
      expect(CompanionPanel.of(AppTab.agent), isEmpty);
    });

    test('opening again moves a panel to the top, per tab', () {
      CompanionPanels.open(AppTab.ssh, CompanionPanel.status);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.files);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.status);
      expect(CompanionPanels.openOf(AppTab.ssh), [
        CompanionPanel.files,
        CompanionPanel.status,
      ]);
      expect(CompanionPanels.openOf(AppTab.file), isEmpty);

      CompanionPanels.close(AppTab.ssh, CompanionPanel.status);
      CompanionPanels.close(AppTab.ssh, CompanionPanel.files);
      expect(CompanionPanels.openOf(AppTab.ssh), isEmpty);
      expect(Stores.setting.companionPanels.fetch(), isEmpty);
    });

    test('a stored name the tab does not offer is dropped', () {
      Stores.setting.companionPanels.put({
        AppTab.ssh.name: 'terminal,gone,files',
      });
      expect(CompanionPanels.openOf(AppTab.ssh), [CompanionPanel.files]);
    });

    test('folding is per panel and per tab', () {
      CompanionPanels.setCollapsed(AppTab.ssh, CompanionPanel.status, true);
      expect(CompanionPanels.collapsedOf(AppTab.ssh), {CompanionPanel.status});
      expect(CompanionPanels.collapsedOf(AppTab.file), isEmpty);
      CompanionPanels.setCollapsed(AppTab.ssh, CompanionPanel.status, false);
      expect(CompanionPanels.collapsedOf(AppTab.ssh), isEmpty);
    });
  });

  group('CompanionHost', () {
    Widget host({required bool withServer}) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        home: Scaffold(
          body: CompanionHost(
            tab: AppTab.ssh,
            spi: withServer ? spiFixture(name: 'box') : null,
            builder: (_, panel, _) =>
                CompanionFrame(body: Text('body:${panel.name}')),
            child: const _Counter(),
          ),
        ),
      ),
    );

    Future<void> sized(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('wide, open panels are sections in the bar order', (
      tester,
    ) async {
      await sized(tester, 1280);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.files);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.status);
      await tester.pumpWidget(host(withServer: true));

      final status = tester.getTopLeft(find.text('body:status'));
      final files = tester.getTopLeft(find.text('body:files'));
      expect(status.dy, lessThan(files.dy), reason: 'status above files');
      expect(status.dx, greaterThan(800), reason: 'in a column on the right');
    });

    testWidgets('narrow, only the newest panel shows, as a sheet', (
      tester,
    ) async {
      await sized(tester, 400);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.status);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.files);
      await tester.pumpWidget(host(withServer: true));

      expect(find.text('body:files'), findsOneWidget);
      expect(find.text('body:status'), findsNothing);

      await tester.tap(find.byTooltip(libL10n.close));
      await tester.pump();
      expect(find.text('body:status'), findsOneWidget);
    });

    testWidgets('the subject keeps its state as panels open and close', (
      tester,
    ) async {
      await sized(tester, 1280);
      await tester.pumpWidget(host(withServer: true));
      await tester.tap(find.byType(_Counter));
      await tester.pump();
      expect(find.text('taps:1'), findsOneWidget);

      CompanionPanels.open(AppTab.ssh, CompanionPanel.status);
      await tester.pump();
      expect(find.text('body:status'), findsOneWidget);
      expect(find.text('taps:1'), findsOneWidget);

      CompanionPanels.close(AppTab.ssh, CompanionPanel.status);
      await tester.pump();
      expect(find.text('taps:1'), findsOneWidget);
    });

    testWidgets('folding one panel builds neither again', (tester) async {
      await sized(tester, 1280);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.status);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.files);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            home: Scaffold(
              body: CompanionHost(
                tab: AppTab.ssh,
                spi: spiFixture(name: 'box'),
                builder: (_, panel, _) => CompanionFrame(
                  body: _Counter(key: ValueKey('counter:${panel.name}')),
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('counter:files')));
      await tester.tap(find.byKey(const ValueKey('counter:status')));
      await tester.pump();

      CompanionPanels.setCollapsed(AppTab.ssh, CompanionPanel.status, true);
      await tester.pumpAndSettle();
      CompanionPanels.setCollapsed(AppTab.ssh, CompanionPanel.status, false);
      await tester.pumpAndSettle();

      expect(find.text('taps:1'), findsNWidgets(2));
    });

    testWidgets('nothing beside a subject with no server', (tester) async {
      await sized(tester, 1280);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.status);
      await tester.pumpWidget(host(withServer: false));
      expect(find.text('body:status'), findsNothing);
      expect(CompanionHost.actions(AppTab.ssh, enabled: false), isEmpty);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _taps = 0;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => _taps++),
    child: ColoredBox(
      color: Colors.transparent,
      child: Center(child: Text('taps:$_taps')),
    ),
  );
}
