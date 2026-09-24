import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/theme_package.dart';
import 'package:server_box/data/model/app/builtin_theme.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/edge_fade_scroll.dart';

import '../helpers/test_db.dart';

/// One tree, two ways of walking it.
///
/// Above 800 it is a menu beside the content, showing every level and opening
/// branches in place. Below, it starts as a list of what there is; picking a row
/// goes in, and the level it landed on becomes a bar of tabs floating over the
/// content. Either way the bar at the top names what is being shown.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  // `Paths.doc` is `late final`, so it is set once for the process. The globe's
  // data row reads it while it builds, and it builds now that the group it is
  // in is a card rather than a tile that has to be opened.
  var pathsSet = false;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-settings-');
    if (!pathsSet) {
      Paths.doc = tempDir.path;
      pathsSet = true;
    }
    await openTestDb();
    // In memory: a real write started in a `testWidgets` body never lets go of
    // the box's lock, and this page writes on nearly every switch.
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    // The server order page reads it as soon as it is shown.
    getIt.registerSingleton<ServerStore>(ServerStore());
  });

  tearDownAll(() async {
    if (pathsSet && Directory(Paths.doc).existsSync()) {
      await Directory(Paths.doc).delete(recursive: true);
    }
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
    await tempDir.delete(recursive: true);
  });

  /// A row of the menu, and only a row of it: several of these titles are also
  /// words in the settings beside or behind it.
  Finder menuRow(String title) => find.descendant(
    of: find.byKey(settingsMenuKey),
    matching: find.text(title),
  );

  /// A tab of the floating bar, told apart from the settings behind it.
  Finder tabRow(String title) => find.descendant(
    of: find.byKey(settingsTabsKey),
    matching: find.text(title),
  );

  /// A tab of the row over the content, which is what a wide window has
  /// instead of the floating bar.
  Finder headerTab(String title) => find.descendant(
    of: find.byKey(settingsHeaderKey),
    matching: find.text(title),
  );

  /// The way back out, which is the title bar's own button and the only one on
  /// the screen — the tabs show the level and nothing else.
  final backBtn = find.byType(BackButton);

  String barTitle(WidgetTester tester) => tester
      .widget<Text>(
        find
            .descendant(of: find.byType(AppBar), matching: find.byType(Text))
            .first,
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

  testWidgets('a wide window shows the menu beside the content', (
    tester,
  ) async {
    await pump(tester, width: 1200);

    expect(menuRow(libL10n.app), findsOneWidget);
    expect(menuRow(libL10n.server), findsOneWidget);
    expect(menuRow(libL10n.terminal), findsOneWidget);
    expect(menuRow(libL10n.file), findsOneWidget);
    expect(menuRow(libL10n.about), findsOneWidget);
    // The one level of nesting there is stays shut until asked for.
    expect(menuRow(libL10n.sequence), findsNothing);
    expect(find.byKey(settingsTabsKey), findsNothing);
  });

  testWidgets('the wide menu is a rail, not a list of cards', (tester) async {
    await pump(tester, width: 1200);

    // One kind of row, each with the mark for its subject: cards among rails
    // would read as two menus rather than as one with something open in it.
    expect(
      find.descendant(
        of: find.byKey(settingsMenuKey),
        matching: find.byType(Icon),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byKey(settingsMenuKey),
        matching: find.byType(CardX),
      ),
      findsNothing,
    );
  });

  testWidgets('a subject shows what is inside it over the content', (
    tester,
  ) async {
    await pump(tester, width: 1200);

    await tester.tap(menuRow(libL10n.server));
    await settle(tester);

    // The menu is one row per subject; what a subject holds is not in it.
    expect(menuRow(libL10n.sequence), findsNothing);
    expect(menuRow(libL10n.general), findsNothing);
    // It is the row over the content, headed by the subject's own name.
    expect(headerTab(libL10n.server), findsOneWidget);
    expect(headerTab(libL10n.general), findsOneWidget);
    expect(headerTab(libL10n.sequence), findsOneWidget);
    // No bar at all on a wide window: the menu says which subject, and the
    // header over the content says which page and carries the two buttons
    // that act on the settings as a whole.
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('a page under a subject is reached by its tab', (tester) async {
    await pump(tester, width: 1200);
    await tester.tap(menuRow(libL10n.server));
    await settle(tester);

    final scheme = Theme.of(
      tester.element(find.byKey(settingsHeaderKey)),
    ).colorScheme;
    Color? fillOf(String title) {
      final pill = find
          .ancestor(of: headerTab(title), matching: find.byType(Container))
          .first;
      final decoration =
          tester.widget<Container>(pill).decoration as ShapeDecoration?;
      return decoration?.color;
    }

    // What is first inside the subject, rather than a row of tabs with none of
    // them on.
    expect(fillOf(libL10n.general), scheme.secondaryContainer);
    expect(fillOf(libL10n.sequence), Colors.transparent);

    await tester.tap(headerTab(libL10n.sequence));
    await settle(tester, 20);

    expect(fillOf(libL10n.sequence), scheme.secondaryContainer);
    expect(fillOf(libL10n.general), Colors.transparent);
  });

  testWidgets('appearance and theme share a page with separate groups', (
    tester,
  ) async {
    await pump(tester, width: 1200);
    await tester.tap(menuRow(libL10n.app));
    await settle(tester);

    final appearance = AppLocalizations.of(
      tester.element(find.byKey(settingsHeaderKey)),
    )!;
    expect(headerTab(appearance.appearanceSettings), findsNothing);
    expect(headerTab(libL10n.theme), findsOneWidget);
    expect(headerTab(libL10n.font), findsOneWidget);

    await tester.tap(headerTab(libL10n.theme));
    await settle(tester);
    final content = find.byType(AppSettingsPage);
    expect(
      find.descendant(
        of: content,
        matching: find.text(appearance.appearanceSettings.toUpperCase()),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: content,
        matching: find.text(libL10n.theme.toUpperCase()),
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, libL10n.themeMode), findsOneWidget);
    expect(
      find.widgetWithText(ListTile, libL10n.primaryColorSeed),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, appearance.appearancePreset),
      findsOneWidget,
    );
    for (final label in [
      appearance.appearanceThemeInstall,
      appearance.appearanceThemeStore,
    ]) {
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, label),
          matching: find.byIcon(Icons.keyboard_arrow_right),
        ),
        findsOneWidget,
      );
    }
    for (final label in [
      libL10n.themeMode,
      libL10n.primaryColorSeed,
      appearance.appearancePreset,
    ]) {
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, label),
          matching: find.byIcon(Icons.keyboard_arrow_right),
        ),
        findsNothing,
      );
    }
    expect(
      find.widgetWithText(ListTile, appearance.appearanceThemeStoreUrl),
      findsOneWidget,
    );
    final installTile = find.widgetWithText(
      ListTile,
      appearance.appearanceThemeInstall,
    );
    final installTip = tester.widget<TipText>(
      find.descendant(of: installTile, matching: find.byType(TipText)),
    );
    expect(
      installTip.tip,
      '${appearance.appearanceThemeSchemaRange}: ${ThemePackages.supportedSchemaRange}',
    );
    expect(tester.widget<ListTile>(installTile).subtitle, isNull);
    expect(
      find.widgetWithText(ListTile, appearance.appearanceCardCorners),
      findsNothing,
    );
    expect(find.widgetWithText(ListTile, libL10n.opacity), findsNothing);

    final image = File('${tempDir.path}/custom.png');
    image.writeAsBytesSync(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/lXcAAAAASUVORK5CYII=',
      ),
    );
    Stores.setting.appThemePreset.put('custom');
    Stores.setting.appBackgroundStyle.put('image');
    Stores.setting.appBackgroundPath.put(image.path);
    await tester.tap(headerTab(libL10n.font));
    await settle(tester);
    await tester.tap(headerTab(libL10n.theme));
    await settle(tester);
    expect(
      find.widgetWithText(ExpansionTile, appearance.appearanceCorners),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, appearance.appearanceCardCorners),
      findsNothing,
    );
    await tester.ensureVisible(
      find.widgetWithText(ExpansionTile, appearance.appearanceCorners),
    );
    await tester.tap(
      find.widgetWithText(ExpansionTile, appearance.appearanceCorners),
    );
    await settle(tester);
    expect(
      find.widgetWithText(ListTile, appearance.appearanceCardCorners),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, appearance.appearanceTileCorners),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(ListTile, appearance.appearanceButtonCorners),
      findsOneWidget,
    );
    expect(find.widgetWithText(ListTile, libL10n.opacity), findsOneWidget);

    await tester.tap(headerTab(libL10n.font));
    await settle(tester);
    expect(
      find.widgetWithText(ListTile, appearance.appearanceFontImport),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, appearance.appearanceFontImport),
        matching: find.byIcon(Icons.keyboard_arrow_right),
      ),
      findsOneWidget,
    );
  });

  test(
    'renames the development Classic preset without resetting appearance',
    () async {
      Stores.setting.appThemePreset.put('classic');
      Stores.setting.colorSeed.put(0xff123456);
      Stores.setting.themeMode.put(ThemeMode.light.index);
      await ThemePackages.prepareSelectedTheme();
      expect(Stores.setting.appThemePreset.fetch(), 'default');
      expect(ThemePackages.activeTheme!.name, 'Default');
      expect(Stores.setting.colorSeed.fetch(), 0xff123456);
      expect(Stores.setting.themeMode.fetch(), ThemeMode.light.index);
    },
  );

  for (final (legacyMode, expectedMode) in [
    (3, ThemeMode.dark),
    (4, ThemeMode.system),
  ]) {
    test(
      'migrates legacy theme mode $legacyMode to AMOLED and $expectedMode',
      () async {
        Stores.setting.themeMode.put(legacyMode);
        await ThemePackages.prepareSelectedTheme();
        expect(Stores.setting.appThemePreset.fetch(), 'amoled');
        expect(Stores.setting.themeMode.fetch(), expectedMode.index);
        expect(ThemePackages.effectiveMode, expectedMode);
        expect(ThemePackages.activeTheme!.lockedMode, isNull);
        // Subsequent startup must preserve a new user preference.
        Stores.setting.themeMode.put(ThemeMode.light.index);
        await ThemePackages.prepareSelectedTheme();
        expect(Stores.setting.themeMode.fetch(), ThemeMode.light.index);
        expect(ThemePackages.effectiveMode, ThemeMode.light);
      },
    );
  }

  testWidgets(
    'theme arrow preview cancels with Escape and commits with Enter',
    (tester) async {
      ThemePackages.select(
        ThemePackages.defaultTheme,
        preset: BuiltinTheme.defaultTheme.id,
      );
      final originalSeed = Stores.setting.colorSeed.fetch();
      await tester.runAsync(
        () => ThemePackages.loadBuiltin(BuiltinTheme.amoled),
      );
      await pump(tester, width: 1200);
      await tester.tap(menuRow(libL10n.app));
      await settle(tester);
      await tester.tap(headerTab(libL10n.theme));
      await settle(tester);
      final appearance = AppLocalizations.of(
        tester.element(find.byKey(settingsHeaderKey)),
      )!;
      final row = find.widgetWithText(ListTile, appearance.appearancePreset);
      await tester.tap(row);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      expect(ThemePackages.preview.value?.id, 'amoled');
      expect(ThemePackages.activePalette(dark: true)['surface'], 0xff000000);
      expect(Stores.setting.appThemePreset.fetch(), 'default');
      expect(Stores.setting.colorSeed.fetch(), originalSeed);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byType(RowsSheet), findsNothing);
      expect(ThemePackages.preview.value, isNull);
      expect(Stores.setting.appThemePreset.fetch(), 'default');
      expect(ThemePackages.activeTheme!.id, 'default');

      await tester.tap(row);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settle(tester);
      expect(find.byType(RowsSheet), findsNothing);
      expect(ThemePackages.preview.value, isNull);
      expect(Stores.setting.appThemePreset.fetch(), 'amoled');
    },
  );

  testWidgets('built-in presets apply their appearance without a package', (
    tester,
  ) async {
    await pump(tester, width: 1200);
    await tester.tap(menuRow(libL10n.app));
    await settle(tester);
    await tester.tap(headerTab(libL10n.theme));
    await settle(tester);
    final appearance = AppLocalizations.of(
      tester.element(find.byKey(settingsHeaderKey)),
    )!;
    for (final builtin in BuiltinTheme.values.reversed) {
      await tester.tap(
        find.widgetWithText(ListTile, appearance.appearancePreset),
      );
      await settle(tester);
      late ThemePackage theme;
      await tester.runAsync(() async {
        await tester.tap(find.text(builtin.label).last);
        theme = await ThemePackages.loadBuiltin(builtin);
      });
      await settle(tester);
      expect(Stores.setting.appThemePreset.fetch(), theme.id);
      expect(Stores.setting.colorSeed.fetch(), theme.seed);
      expect(Stores.setting.themeMode.fetch(), theme.mode);
      expect(Stores.setting.appThemePackage.fetch(), isEmpty);
      expect(Stores.setting.appBackgroundStyle.fetch(), 'none');
      expect(Stores.setting.appCardRadius.fetch(), theme.cardRadius);
      final modeRow = tester.widget<ListTile>(
        find.widgetWithText(ListTile, libL10n.themeMode),
      );
      expect(modeRow.enabled, theme.lockedMode == null);
      if (theme.lockedMode != null) {
        expect(modeRow.onTap, isNull);
        expect(
          (modeRow.subtitle as Text).data,
          appearance.appearanceThemeModeLocked(
            theme.lockedMode == ThemeMode.dark ? libL10n.dark : libL10n.bright,
          ),
        );
      } else {
        expect(modeRow.subtitle, isNull);
        expect(modeRow.onTap, isNotNull);
      }
    }
  });

  testWidgets('a subject with one page gets no tabs', (tester) async {
    await pump(tester, width: 1200);

    await tester.tap(menuRow(libL10n.about));
    await settle(tester);

    // The header stays — it names the page and carries the two buttons that
    // act on the settings as a whole — but a row with one tab on it would say
    // only what the name beside it just said. The other top-level pages are
    // not its siblings either; that is the menu's job.
    expect(headerTab(libL10n.about), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(settingsHeaderKey),
        matching: find.byType(EdgeFadeScroll),
      ),
      findsNothing,
    );
  });

  testWidgets('the search reaches a page without its subject', (tester) async {
    await pump(tester, width: 1200);

    await tester.enterText(find.byType(TextField).first, 'sequence');
    await settle(tester, 20);

    // Named by what it is under, since three pages here are called "General".
    final hit = find.descendant(
      of: find.byKey(settingsResultsKey),
      matching: find.widgetWithText(ListTile, libL10n.sequence),
    );
    expect(hit, findsOneWidget);
    // The count is a heading over the results, not a bar's title: most of
    // what a search matches is rows, and a bar cannot count those.
    expect(find.text('1 ${libL10n.result}'.toUpperCase()), findsOneWidget);

    await tester.tap(hit);
    await settle(tester, 20);

    // Gone the moment it has been used: the search is a way to a page, not a
    // place to stay.
    expect(find.text('1 ${libL10n.result}'.toUpperCase()), findsNothing);
    expect(headerTab(libL10n.sequence), findsOneWidget);
  });

  testWidgets('typing the first character keeps the caret in the field', (
    tester,
  ) async {
    await pump(tester, width: 1200);

    final field = find.byType(TextField).first;
    FocusNode? nodeOf() => tester.widget<TextField>(field).focusNode;

    await tester.showKeyboard(field);
    await settle(tester);
    expect(nodeOf()?.hasFocus, isTrue);

    // The one that turns the search on, which used to swap the page of the
    // content navigator — and a route arriving takes the focus with it, from
    // a field that is not even inside that navigator.
    await tester.enterText(field, 'u');
    await settle(tester, 20);

    expect(
      nodeOf()?.hasFocus,
      isTrue,
      reason: 'the first character must not push a route',
    );
  });

  testWidgets('a result that stops matching leaves rather than vanishing', (
    tester,
  ) async {
    await pump(tester, width: 1200);

    final field = find.byType(TextField).first;
    // Scoped to the results: the page they are drawn over is still in the
    // tree under them, and "Language" is a row on that page too.
    final row = find.descendant(
      of: find.byKey(settingsResultsKey),
      matching: find.widgetWithText(ListTile, libL10n.language),
    );

    await tester.enterText(field, libL10n.language);
    await settle(tester, 20);
    expect(row, findsOneWidget);

    // Narrowed to nothing. The row is gone from the build, which is exactly
    // when it has to still be on screen: a list that closes the gap in one
    // frame says nothing about what changed.
    await tester.enterText(field, '${libL10n.language}zzz');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(row, findsOneWidget);

    await settle(tester, 20);
    expect(row, findsNothing);
    expect(find.text(libL10n.empty), findsOneWidget);
  });

  testWidgets('a search that matches nothing says so', (tester) async {
    await pump(tester, width: 1200);

    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await settle(tester, 20);

    expect(find.text(libL10n.empty), findsOneWidget);
  });

  testWidgets('a narrow window opens on the list, with no tabs over it', (
    tester,
  ) async {
    await pump(tester, width: 500);

    expect(barTitle(tester), libL10n.setting);
    // Every first-level row, and nothing named twice: a bar of tabs here would
    // repeat the list under it.
    expect(menuRow(libL10n.app), findsOneWidget);
    expect(menuRow(libL10n.server), findsOneWidget);
    expect(menuRow(libL10n.about), findsOneWidget);
    expect(find.byKey(settingsTabsKey), findsNothing);
    // And the settings are still leavable.
    expect(find.byType(BackButton), findsOneWidget);

    // A whole screen of rows that lead somewhere, drawn as the settings they
    // lead to are.
    final tiles = find.descendant(
      of: find.byKey(settingsMenuKey),
      matching: find.byType(ListTile),
    );
    expect(tiles, findsWidgets);
    for (final tile in tester.widgetList<ListTile>(tiles)) {
      expect(tile.leading, isNotNull);
    }
  });

  testWidgets('picking a row goes in and brings up its level as tabs', (
    tester,
  ) async {
    await pump(tester, width: 500);

    await tester.tap(menuRow(libL10n.server));
    await settle(tester, 20);

    expect(find.byKey(settingsTabsKey), findsOneWidget);
    expect(tabRow(libL10n.sequence), findsOneWidget);
    // What is first inside it, rather than a row of tabs with none of them on.
    expect(barTitle(tester), libL10n.general);
    // One way back, in the bar at the top. A second at the foot was the same
    // move twice on one screen.
    expect(backBtn, findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(settingsTabsKey),
        matching: find.byIcon(Icons.arrow_back),
      ),
      findsNothing,
    );
  });

  testWidgets('the tabs rise into place rather than appearing', (tester) async {
    await pump(tester, width: 500);

    await tester.tap(menuRow(libL10n.server));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final midway = tester.getTopLeft(find.byKey(settingsTabsKey)).dy;

    await settle(tester, 20);
    final settled = tester.getTopLeft(find.byKey(settingsTabsKey)).dy;

    // Still on its way up from under the foot of the screen.
    expect(midway, greaterThan(settled));
  });

  testWidgets('a first-level leaf shows on its own, with no tabs', (
    tester,
  ) async {
    await pump(tester, width: 500);

    await tester.tap(menuRow(libL10n.about));
    await settle(tester, 20);

    expect(barTitle(tester), libL10n.about);
    // Nothing to move between. A bar with one tab on it would say what the
    // title above it just said.
    expect(find.byKey(settingsTabsKey), findsNothing);

    // Which leaves the bar's own button as the way back to the list — it leads
    // out of the level while there is one, not out of the settings.
    await tester.tap(find.byType(BackButton));
    await settle(tester, 20);
    expect(menuRow(libL10n.about), findsOneWidget);
    expect(barTitle(tester), libL10n.setting);
  });

  testWidgets('the way back leads to the list, and drops the tabs', (
    tester,
  ) async {
    await pump(tester, width: 500);

    await tester.tap(menuRow(libL10n.server));
    await settle(tester, 20);
    await tester.tap(backBtn);
    await settle(tester, 20);

    expect(barTitle(tester), libL10n.setting);
    expect(find.byKey(settingsTabsKey), findsNothing);
    expect(menuRow(libL10n.terminal), findsOneWidget);
  });

  testWidgets('the bar is as wide as the level on it', (tester) async {
    await pump(tester, width: 500);

    await tester.tap(menuRow(libL10n.server));
    await settle(tester, 20);
    final four = tester.getSize(find.byKey(settingsTabsKey)).width;

    await tester.tap(backBtn);
    await settle(tester, 20);
    await tester.tap(menuRow(libL10n.file));
    await settle(tester, 20);

    // Two tabs and a way back is a shorter bar than four and a way back.
    expect(tester.getSize(find.byKey(settingsTabsKey)).width, lessThan(four));
  });

  /// The mask over the bar, which is only there while there is something to
  /// mask — so this is `findsNothing` as often as it is `findsOneWidget`.
  Finder edgeFade() => find.ancestor(
    of: find.byKey(settingsTabsKey),
    matching: find.byType(ShaderMask),
  );

  testWidgets('a level that fits its window is not faded', (tester) async {
    await pump(tester, width: 500);

    await tester.tap(menuRow(libL10n.file));
    await settle(tester, 20);

    expect(edgeFade(), findsNothing);
  });

  testWidgets('a level wider than its window fades at the edge', (
    tester,
  ) async {
    // Narrow enough that the app group's leaves cannot all be on screen.
    await pump(tester, width: 320);

    await tester.tap(menuRow(libL10n.app));
    await settle(tester, 20);

    expect(edgeFade(), findsOneWidget);
  });

  testWidgets('a tab several along does not announce the ones passed through', (
    tester,
  ) async {
    await pump(tester, width: 500);

    await tester.tap(menuRow(libL10n.app));
    await settle(tester, 20);

    // A later tab in the app group, so the animation crosses others.
    final target = AppLocalizations.of(
      tester.element(find.byKey(settingsTabsKey)),
    )!.homeTabs;
    final titles = <String>[barTitle(tester)];

    await tester.ensureVisible(tabRow(target));
    await settle(tester, 20);
    await tester.tap(tabRow(target));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      final title = barTitle(tester);
      if (title != titles.last) titles.add(title);
    }

    // Where it started and where it was sent, and nothing in between.
    expect(titles, [libL10n.general, target]);
  });

  testWidgets('the tab being shown is filled in', (tester) async {
    await pump(tester, width: 500);
    await tester.tap(menuRow(libL10n.server));
    await settle(tester, 20);

    final scheme = Theme.of(
      tester.element(find.byKey(settingsTabsKey)),
    ).colorScheme;
    Color? fillOf(String title) {
      // The pill is around the icon, not the label — so it is a sibling of the
      // text, reached through the button's own column.
      final button = find
          .ancestor(of: tabRow(title), matching: find.byType(Column))
          .first;
      final pill = find.descendant(
        of: button,
        matching: find.byType(AnimatedContainer),
      );
      final decoration =
          tester.widget<AnimatedContainer>(pill.first).decoration
              as BoxDecoration?;
      return decoration?.color;
    }

    // Filled rather than only recoloured — a shade of grey against another is
    // not a state at a glance.
    expect(fillOf(libL10n.general), scheme.secondaryContainer);
    expect(fillOf(libL10n.sequence), isNull);
  });

  testWidgets('the leaves of a level sit side by side, and drag between', (
    tester,
  ) async {
    await pump(tester, width: 500);
    await tester.tap(menuRow(libL10n.server));
    await settle(tester, 20);

    expect(barTitle(tester), libL10n.general);

    // Dragging the content is the same move as tapping the next tab, which is
    // what putting them side by side promises.
    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await settle(tester, 20);

    expect(barTitle(tester), libL10n.sequence);
  });

  testWidgets('the list and the level are pages of one navigator', (
    tester,
  ) async {
    await pump(tester, width: 500);

    // The content navigator is the declarative one; the app's own is not.
    Navigator contentNav() => tester
        .widgetList<Navigator>(find.byType(Navigator))
        .firstWhere((n) => n.pages.isNotEmpty);

    expect(contentNav().pages.length, 1);

    await tester.tap(menuRow(libL10n.server));
    await settle(tester, 20);
    // A page arriving is a MaterialPage arriving, which is where the transition
    // comes from.
    expect(contentNav().pages.length, 2);

    await tester.tap(backBtn);
    await settle(tester, 20);
    expect(contentNav().pages.length, 1);
  });

  testWidgets('system back pops one settings page at a time', (tester) async {
    await pump(tester, width: 500);
    await tester.tap(menuRow(libL10n.server));
    await settle(tester, 20);

    final contentNavFinder = find.byWidgetPredicate(
      (widget) => widget is Navigator && widget.pages.isNotEmpty,
    );
    final contentNav = tester.state<NavigatorState>(contentNavFinder);
    final pushed = contentNav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('deeper settings page')),
      ),
    );
    await settle(tester);

    await tester.binding.handlePopRoute();
    await pushed;
    await settle(tester, 40);
    expect(find.text('deeper settings page'), findsNothing);
    expect(barTitle(tester), libL10n.general);

    await tester.binding.handlePopRoute();
    await settle(tester, 20);
    expect(barTitle(tester), libL10n.setting);
    expect(menuRow(libL10n.server), findsOneWidget);

    await tester.binding.handlePopRoute();
    await settle(tester, 20);
    expect(find.text('open'), findsOneWidget);
  });
}
