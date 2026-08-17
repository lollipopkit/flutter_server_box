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

  /// The way back out, which is the bar's first button.
  final backTab = find.descendant(
    of: find.byKey(settingsTabsKey),
    matching: find.byType(InkWell),
  ).first;

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

  testWidgets('a narrow window floats the tabs, with no way back at the root', (
    tester,
  ) async {
    await pump(tester, width: 500);

    expect(find.byKey(settingsTabsKey), findsOneWidget);
    // No column beside the content, and the settings are still leavable.
    expect(find.byType(SideBarTile), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);

    expect(tabRow(libL10n.server), findsOneWidget);
    // There, and off: the root has no level above it.
    expect(tester.widget<InkWell>(backTab).onTap, isNull);
  });

  testWidgets('a tab that is a branch goes in and shows what is first inside', (
    tester,
  ) async {
    await pump(tester, width: 500);

    await tester.tap(tabRow(libL10n.server));
    await settle(tester);

    // The level below, with the branch's own settings showing rather than a row
    // of tabs with none of them on.
    expect(tabRow(l10n.serverOrder), findsOneWidget);
    // Checked against the first tab, not a late one: the row scrolls, so a tab
    // off the end of it is absent for a reason that has nothing to do with the
    // level being shown.
    expect(tabRow(libL10n.app), findsNothing);
    expect(barTitle(tester), libL10n.setting);
    expect(tester.widget<InkWell>(backTab).onTap, isNotNull);
  });

  testWidgets('the leading button goes back out a level', (tester) async {
    await pump(tester, width: 500);

    await tester.tap(tabRow(libL10n.server));
    await settle(tester);
    await tester.tap(tabRow(l10n.serverOrder));
    await settle(tester);
    expect(barTitle(tester), l10n.serverOrder);

    await tester.tap(backTab);
    await settle(tester);

    expect(tabRow(libL10n.app), findsOneWidget);
    // What was picked is still what is showing, and the branch it is inside is
    // the tab that says so.
    expect(barTitle(tester), l10n.serverOrder);
  });
}
