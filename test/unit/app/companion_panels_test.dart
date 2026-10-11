/// The panels a tab shows beside its subject: whether they are open, which
/// one, and how the host lays them out.
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
    test('each tab offers the other two and the Agent', () {
      expect(CompanionPanel.of(AppTab.ssh), [
        CompanionPanel.status,
        CompanionPanel.files,
        CompanionPanel.agent,
      ]);
      expect(CompanionPanel.of(AppTab.file), [
        CompanionPanel.status,
        CompanionPanel.terminal,
        CompanionPanel.agent,
      ]);
      expect(CompanionPanel.of(AppTab.server), [
        CompanionPanel.terminal,
        CompanionPanel.files,
        CompanionPanel.agent,
      ]);
      expect(CompanionPanel.of(AppTab.agent), isEmpty);
      expect(CompanionPanels.isOpen(AppTab.agent), isFalse);
    });

    test('open, close and the panel shown are per tab, and kept', () {
      expect(CompanionPanels.selectedOf(AppTab.ssh), CompanionPanel.status);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.files);
      expect(CompanionPanels.isOpen(AppTab.ssh), isTrue);
      expect(CompanionPanels.isOpen(AppTab.file), isFalse);

      CompanionPanels.close(AppTab.ssh);
      expect(CompanionPanels.isOpen(AppTab.ssh), isFalse);
      // Opens where it was left.
      CompanionPanels.toggle(AppTab.ssh);
      expect(CompanionPanels.selectedOf(AppTab.ssh), CompanionPanel.files);
    });

    test('a stored panel the tab does not offer falls back to its first', () {
      Stores.setting.companionPanel.put({AppTab.ssh.name: 'terminal'});
      expect(CompanionPanels.selectedOf(AppTab.ssh), CompanionPanel.status);
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
            builder: (_, panel, _) => CompanionFrame(
              body: _Counter(key: ValueKey('counter:${panel.name}')),
            ),
            child: const _Counter(key: ValueKey('subject')),
          ),
        ),
      ),
    );

    Future<void> sized(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Finder counter(String name) => find.byKey(ValueKey('counter:$name'));

    testWidgets('wide, the panels are a column on the right', (tester) async {
      await sized(tester, 1280);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.files);
      await tester.pumpWidget(host(withServer: true));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(counter('files')).dx, greaterThan(800));
      // Never visited, so never built.
      expect(counter('status'), findsNothing);
    });

    testWidgets('switching keeps every panel visited as it was', (
      tester,
    ) async {
      await sized(tester, 1280);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.files);
      await tester.pumpWidget(host(withServer: true));
      await tester.pumpAndSettle();
      await tester.tap(counter('files'));
      await tester.pump();

      await tester.tap(find.text(l10n.status));
      await tester.pumpAndSettle();
      expect(CompanionPanels.selectedOf(AppTab.ssh), CompanionPanel.status);
      await tester.tap(find.text(libL10n.file));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: counter('files'), matching: find.text('taps:1')),
        findsOneWidget,
      );
    });

    testWidgets('narrow, a sheet that closes from its strip', (tester) async {
      await sized(tester, 400);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.files);
      await tester.pumpWidget(host(withServer: true));
      await tester.pumpAndSettle();
      expect(counter('files'), findsOneWidget);

      await tester.tap(find.byTooltip(libL10n.close));
      await tester.pumpAndSettle();
      expect(CompanionPanels.isOpen(AppTab.ssh), isFalse);
    });

    testWidgets('the subject keeps its state as the panels open and close', (
      tester,
    ) async {
      await sized(tester, 1280);
      await tester.pumpWidget(host(withServer: true));
      await tester.tap(find.byKey(const ValueKey('subject')));
      await tester.pump();

      CompanionPanels.open(AppTab.ssh);
      await tester.pumpAndSettle();
      CompanionPanels.close(AppTab.ssh);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('subject')),
          matching: find.text('taps:1'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('nothing beside a subject with no server', (tester) async {
      await sized(tester, 1280);
      CompanionPanels.open(AppTab.ssh, CompanionPanel.status);
      await tester.pumpWidget(host(withServer: false));
      expect(counter('status'), findsNothing);
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
