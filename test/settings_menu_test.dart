import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/entry.dart';

/// One tree, two ways of walking it: a menu beside the content above 800, and a
/// bar of tabs floating over its foot below. The menu shows every level and
/// opens branches in place; the tabs show one level and go in and out of it.
/// Either way the bar at the top names whichever leaf is showing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<dynamic> settingBox;
  late Box<dynamic> serverBox;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-settings-');
    Hive.init(tempDir.path);
    // In memory: a real write started in a `testWidgets` body never lets go of
    // the box's lock, and this page writes on nearly every switch.
    settingBox = await Hive.openBox<dynamic>('setting_test', bytes: Uint8List(0));
    serverBox = await Hive.openBox<dynamic>('server_test', bytes: Uint8List(0));
    getIt.registerSingleton<SettingStore>(SettingStore.forBox(settingBox));
    // The server order page reads it as soon as it is shown.
    getIt.registerSingleton<ServerStore>(ServerStore.forBox(serverBox));
  });

  tearDown(() async {
    await getIt.reset();
    await settingBox.close();
    await serverBox.close();
    await tempDir.delete(recursive: true);
  });

  /// A row of the menu, and only a row of it: several of these titles are also
  /// words in the settings on the right.
  Finder menuRow(String title) =>
      find.descendant(of: find.byType(SideBarTile), matching: find.text(title));

  /// A tab of the floating bar, told apart from the settings behind it.
  Finder tabRow(String title) =>
      find.descendant(of: find.byKey(settingsTabsKey), matching: find.text(title));

  /// The way back out. Absent at the root, where there is nowhere to go.
  final backTab = find.descendant(
    of: find.byKey(settingsTabsKey),
    matching: find.byIcon(Icons.arrow_back),
  );

  String barTitle(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first,
      )
      .data!;

  Future<void> settle(WidgetTester tester, [int frames = 10]) async {
    // Counted out rather than settled: the menu animates open and closed, and
    // `pumpAndSettle` on a tree with a frame always scheduled waits ten minutes.
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Pushed rather than shown as the home page, which is how it is reached and
  /// what decides whether the bar has anything to go back with.
  Future<void> pump(WidgetTester tester, {required double width}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.of(ctx).push(
                  MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('a wide window shows the menu beside the content', (tester) async {
    await pump(tester, width: 1200);

    expect(menuRow(libL10n.app), findsOneWidget);
    expect(menuRow(libL10n.server), findsOneWidget);
    expect(menuRow(libL10n.terminal), findsOneWidget);
    expect(menuRow(libL10n.file), findsOneWidget);
    expect(menuRow(libL10n.about), findsOneWidget);
    // The one level of nesting there is stays shut until asked for.
    expect(menuRow(l10n.serverOrder), findsNothing);
    expect(find.byKey(settingsTabsKey), findsNothing);
  });

  testWidgets('every menu row carries an icon', (tester) async {
    await pump(tester, width: 1200);

    for (final tile in tester.widgetList<SideBarTile>(find.byType(SideBarTile))) {
      expect(tile.icon, isNotNull, reason: tile.title);
    }
  });

  testWidgets('a branch opens instead of showing something', (tester) async {
    await pump(tester, width: 1200);
    final before = barTitle(tester);

    await tester.tap(menuRow(libL10n.server));
    await settle(tester);

    expect(menuRow(l10n.serverOrder), findsOneWidget);
    // The bar names what it named: the branch opened, it did not select.
    expect(barTitle(tester), before);
  });

  testWidgets('a leaf under a branch shows in the content', (tester) async {
    await pump(tester, width: 1200);

    await tester.tap(menuRow(libL10n.server));
    await settle(tester);
    await tester.tap(menuRow(l10n.serverOrder));
    await settle(tester);

    expect(barTitle(tester), l10n.serverOrder);
    // Embedded, so it dropped the bar it has when pushed — one page, one bar.
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('it opens inside the first group, not on the odds and ends', (
    tester,
  ) async {
    await pump(tester, width: 500);

    // The leaves at the root are backup, keys and about; opening on one of them
    // would answer "what is in here" with the least of it.
    expect(barTitle(tester), libL10n.setting);
    expect(tabRow(libL10n.ai), findsOneWidget);
    expect(backTab, findsOneWidget);
  });

  testWidgets('the way back out is absent at the root', (tester) async {
    await pump(tester, width: 500);

    await tester.tap(backTab);
    await settle(tester, 20);

    expect(tabRow(libL10n.server), findsOneWidget);
    expect(backTab, findsNothing);
    // No column beside the content, and the settings are still leavable.
    expect(find.byType(SideBarTile), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a tab that is a branch goes in and shows what is first inside', (
    tester,
  ) async {
    await pump(tester, width: 500);
    await tester.tap(backTab);
    await settle(tester, 20);

    await tester.tap(tabRow(libL10n.server));
    await settle(tester, 20);

    // The level below, with the branch's own settings showing rather than a row
    // of tabs with none of them on.
    expect(tabRow(l10n.serverOrder), findsOneWidget);
    // Checked against the first tab, not a late one: the row scrolls, so a tab
    // off the end of it is absent for a reason that has nothing to do with the
    // level being shown.
    expect(tabRow(libL10n.app), findsNothing);
    expect(barTitle(tester), libL10n.setting);
    expect(backTab, findsOneWidget);
  });

  testWidgets('the bar is as wide as the level on it', (tester) async {
    await pump(tester, width: 500);
    await tester.tap(backTab);
    await settle(tester, 20);

    // The root has more tabs than the window is wide, so the bar fills it.
    final atRoot = tester.getSize(find.byKey(settingsTabsKey)).width;
    expect(atRoot, greaterThan(400));

    await tester.tap(tabRow(libL10n.server));
    await settle(tester, 20);

    // Four tabs and a way back: shorter than the eight it came from.
    expect(tester.getSize(find.byKey(settingsTabsKey)).width, lessThan(atRoot));
  });

  testWidgets('the tab being shown is filled in', (tester) async {
    await pump(tester, width: 500);

    final scheme = Theme.of(tester.element(find.byKey(settingsTabsKey))).colorScheme;
    Color? fillOf(String title) {
      // The pill is around the icon, not the label — so it is a sibling of the
      // text, reached through the button's own column.
      final button = find.ancestor(of: tabRow(title), matching: find.byType(Column)).first;
      final pill = find.descendant(of: button, matching: find.byType(AnimatedContainer));
      final decoration =
          tester.widget<AnimatedContainer>(pill.first).decoration as BoxDecoration?;
      return decoration?.color;
    }

    // Filled rather than only recoloured — a shade of grey against another is
    // not a state at a glance.
    expect(fillOf(libL10n.setting), scheme.secondaryContainer);
    expect(fillOf(libL10n.ai), isNull);
  });

  testWidgets('the leaves of a level sit side by side, and drag between', (
    tester,
  ) async {
    await pump(tester, width: 500);

    expect(find.byType(PageView), findsOneWidget);
    expect(barTitle(tester), libL10n.setting);

    // Dragging the content is the same move as tapping the next tab, which is
    // what putting them side by side promises.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await settle(tester, 20);

    expect(barTitle(tester), libL10n.ai);
  });

  testWidgets('going a level in and out is a push and a pop', (tester) async {
    await pump(tester, width: 500);
    await tester.tap(backTab);
    await settle(tester, 20);

    final atRoot = find.byType(PageView).evaluate().length;

    await tester.tap(tabRow(libL10n.server));
    // Mid-transition both levels are on screen, which is what a push looks like.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.byType(PageView).evaluate().length, greaterThan(atRoot));

    await settle(tester, 20);
    expect(find.byType(PageView).evaluate().length, atRoot);
    expect(barTitle(tester), libL10n.setting);

    await tester.tap(backTab);
    await settle(tester, 20);
    expect(tabRow(libL10n.app), findsOneWidget);
  });
}
