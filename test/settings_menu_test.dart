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

/// The settings page is a menu beside its content above 800, and a drawer under
/// it. Both show the same tree: a branch opens, a leaf selects, and the bar
/// names whichever leaf is showing.
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
    expect(menuRow(libL10n.conn), findsOneWidget);
    expect(menuRow(libL10n.backup), findsOneWidget);
    expect(menuRow(libL10n.about), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('the first level is subjects, closed', (tester) async {
    await pump(tester, width: 1200);

    // What is under a branch stays under it until asked for, so the menu opens
    // as a short list rather than as everything there is.
    expect(menuRow(libL10n.container), findsNothing);
    expect(menuRow(l10n.serverOrder), findsNothing);
  });

  testWidgets('every row carries an icon', (tester) async {
    await pump(tester, width: 1200);

    for (final tile in tester.widgetList<SideBarTile>(find.byType(SideBarTile))) {
      expect(tile.icon, isNotNull, reason: tile.title);
    }
  });

  testWidgets('a branch opens instead of showing something', (tester) async {
    await pump(tester, width: 1200);
    final before = barTitle(tester);

    await tester.tap(menuRow(libL10n.conn));
    await settle(tester);

    expect(menuRow(libL10n.server), findsOneWidget);
    expect(menuRow(libL10n.container), findsOneWidget);
    // The bar names what it named: the branch opened, it did not select.
    expect(barTitle(tester), before);
  });

  testWidgets('a leaf three levels down shows in the content', (tester) async {
    await pump(tester, width: 1200);

    await tester.tap(menuRow(libL10n.conn));
    await settle(tester);
    await tester.tap(menuRow(libL10n.server));
    await settle(tester);
    await tester.tap(menuRow(l10n.serverOrder));
    await settle(tester);

    expect(barTitle(tester), l10n.serverOrder);
    // Embedded, so it dropped the bar it has when pushed — one page, one bar.
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('a narrow window keeps the menu in a drawer, and can still go back', (
    tester,
  ) async {
    await pump(tester, width: 500);

    expect(menuRow(libL10n.backup), findsNothing);
    // Both: the drawer's own button would otherwise take the one place there is
    // to leave the settings from.
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await settle(tester);

    expect(find.byType(Drawer), findsOneWidget);
    expect(menuRow(libL10n.backup), findsOneWidget);
  });

  testWidgets('picking from the drawer closes it', (tester) async {
    await pump(tester, width: 500);

    await tester.tap(find.byIcon(Icons.menu));
    await settle(tester);
    await tester.tap(menuRow(libL10n.about));
    await settle(tester, 12);

    expect(find.byType(Drawer), findsNothing);
    expect(barTitle(tester), libL10n.about);
  });
}
