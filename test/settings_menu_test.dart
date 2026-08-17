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
/// it. Both show the same tree, and a branch is a row that opens rather than a
/// row that shows something.
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
          home: const SettingsPage(),
        ),
      ),
    );
    // Counted out rather than settled: the menu animates open and closed, and
    // `pumpAndSettle` on a tree with a frame always scheduled waits ten minutes.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('a wide window shows the menu beside the content', (tester) async {
    await pump(tester, width: 1200);

    // Every top level row is there, and no drawer to reach them through.
    expect(find.text(libL10n.server), findsOneWidget);
    expect(find.text(libL10n.backup), findsOneWidget);
    expect(find.text(libL10n.about), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
  });

  testWidgets('a narrow window keeps the menu in a drawer', (tester) async {
    await pump(tester, width: 500);

    // Not on screen, and reachable: `Scaffold` puts the hamburger in the bar
    // for us because the page has a drawer.
    expect(find.text(libL10n.backup), findsNothing);

    await tester.tap(find.byTooltip(MaterialLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    ).openAppDrawerTooltip));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(Drawer), findsOneWidget);
    expect(find.text(libL10n.backup), findsOneWidget);
  });

  testWidgets('a branch opens instead of showing something', (tester) async {
    await pump(tester, width: 1200);

    // Closed to start with, so the menu opens as a list of subjects.
    expect(find.text(l10n.serverOrder), findsNothing);
    final titleBefore = tester.widget<Text>(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first,
    );

    await tester.tap(find.text(libL10n.server));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text(l10n.serverOrder), findsOneWidget);
    // The bar still names what it named: the branch opened, it did not select.
    final titleAfter = tester.widget<Text>(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first,
    );
    expect(titleAfter.data, titleBefore.data);
  });

  testWidgets('a leaf under a branch shows in the content, named by the bar', (
    tester,
  ) async {
    await pump(tester, width: 1200);

    await tester.tap(find.text(libL10n.server));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text(l10n.serverOrder));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    final title = tester.widget<Text>(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first,
    );
    expect(title.data, l10n.serverOrder);
    // Embedded, so it dropped the bar it has when pushed — one page, one bar.
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('picking from the drawer closes it', (tester) async {
    await pump(tester, width: 500);

    await tester.tap(find.byTooltip(MaterialLocalizations.of(
      tester.element(find.byType(Scaffold).first),
    ).openAppDrawerTooltip));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    await tester.tap(find.text(libL10n.about));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(Drawer), findsNothing);
    final title = tester.widget<Text>(
      find.descendant(of: find.byType(AppBar), matching: find.byType(Text)).first,
    );
    expect(title.data, libL10n.about);
  });
}
