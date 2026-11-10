/// Switching sections while something is pushed over the settings pane.
///
/// The right-hand side is a declarative [Navigator]: its pages come from the
/// selection, so picking a section in the left menu is a `setState` and not a
/// push. A page inside it may still push a route by hand — the raw settings
/// editor does — and a pushed route sits above every declarative page. The
/// pages underneath were rebuilt on every selection and the pushed one stayed
/// on top, so the menu looked dead and the editor stayed put whichever section
/// was picked.
library;

import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:server_box/view/widget/nav_rail.dart';

import '../helpers/test_db.dart';

/// Wide enough for the menu to sit beside the content rather than in a drawer,
/// which is the layout this is about. Sized on the view, not the surface:
/// `setSurfaceSize` changes what the tree is laid out in but not what
/// `MediaQuery` reports, and the breakpoint is read from `LayoutBuilder`
/// constraints that follow the view.
void _useWideView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1400, 900);
  addTearDown(tester.view.reset);
}

Widget _app({GlobalKey<NavigatorState>? navigatorKey, bool pushed = false}) => ProviderScope(
  child: MaterialApp(
    navigatorKey: navigatorKey,
    locale: const Locale('en'),
    localizationsDelegates: const [
      ...app_locale.appLocalizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        app_locale.l10n = AppLocalizations.of(context)!;
        context.setLibL10n();
        return pushed ? const Scaffold(body: Text('under')) : const SettingsPage();
      },
    ),
  ),
);

/// The settings pushed over a page, as the home pushes them where a tab is
/// shown; [_left] once they are gone.
Future<void> _pushSettings(WidgetTester tester, {bool rail = false}) async {
  final nav = GlobalKey<NavigatorState>();
  await tester.pumpWidget(_app(navigatorKey: nav, pushed: true));
  unawaited(
    nav.currentState!.push(
      AppPageRoute<void>(builder: (_) => RailBeside(present: rail, child: const SettingsPage())),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<bool> _left(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return find.byType(SettingsPage).evaluate().isEmpty;
}

/// One group as a route builds it, which is what a caller outside the settings
/// tree gets.
Widget _sectionApp(SettingsSection section) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      ...app_locale.appLocalizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        app_locale.l10n = AppLocalizations.of(context)!;
        context.setLibL10n();
        return SettingsSectionPage.route.toWidget(args: section);
      },
    ),
  ),
);

/// The navigator the settings content lives in.
NavigatorState _contentNav(WidgetTester tester) {
  // The innermost one: the `MaterialApp`'s is above the page, and this is the
  // one the page builds for its own pages.
  final navs = tester.stateList<NavigatorState>(find.byType(Navigator));
  return navs.last;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The search builds the rows, and one of them reads `Paths.doc`.
  setUpAll(() {
    Paths.doc = Directory.systemTemp.createTempSync('server-box-pane-').path;
  });
  tearDownAll(() => Directory(Paths.doc).deleteSync(recursive: true));

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<ContainerStore>(ContainerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<BmcCredentialStore>(BmcCredentialStore());
    getIt.registerSingleton<SnippetStore>(SnippetStore());
    getIt.registerSingleton<HistoryStore>(HistoryStore('history_test'));
    getIt.registerSingleton<ConnectionStatsStore>(
      ConnectionStatsStore.instance,
    );
    getIt.registerSingleton<PortForwardStore>(PortForwardStore());
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// A group reached from outside the settings tree — the terminal tab's "add
  /// a Linux system" is the one caller there is.
  ///
  /// [AppSettingsPage] is a group's rows and nothing else: the settings' own
  /// layout supplies the bar, the title and the surface, on nine call sites. A
  /// route holding it alone is therefore a `ListView` over an empty route,
  /// which draws as a black screen with settings on it. [SettingsSectionPage]
  /// is what a caller pushes instead.
  group('a group as a page of its own', () {
    testWidgets('has a surface under it', (tester) async {
      await tester.pumpWidget(_sectionApp(SettingsSection.editor));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: find.byType(SettingsSectionPage),
          matching: find.byType(Scaffold),
        ),
        findsOneWidget,
        reason: 'without one the route paints nothing behind the rows',
      );
      expect(find.byType(AppSettingsPage), findsOneWidget);
    });

    testWidgets('and says which group it is', (tester) async {
      // The subject's name rather than the leaf's: three of the leaves in the
      // menu are called "General", which beside the menu says which General
      // and on a page of its own says nothing.
      await tester.pumpWidget(_sectionApp(SettingsSection.editor));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.descendant(
          of: find.byType(CustomAppBar),
          matching: find.text(SettingsSection.editor.title),
        ),
        findsOneWidget,
      );
      expect(SettingsSection.editor.title, isNot(libL10n.general));
    });
  });

  testWidgets('a pushed page goes when another section is picked', (
    tester,
  ) async {
    _useWideView(tester);
    await tester.pumpWidget(_app());
    // Counted out rather than settled: the tree holds text fields, which keep
    // scheduling, so `pumpAndSettle` would wait out its ten minutes.
    await tester.pump(const Duration(milliseconds: 300));

    // Stands in for the raw settings editor, which pushes onto this navigator
    // from `entries/app.dart`. What matters is that it is pushed rather than
    // declared, not which page it is.
    unawaited(
      _contentNav(tester).push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('pushed editor')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('pushed editor'), findsOneWidget);

    // Any other section in the left menu: one at its top level, as the
    // account opens first and leaves the groups folded.
    final target = find.text(libL10n.about);
    expect(target, findsWidgets, reason: 'the menu has to be on screen');
    await tester.tap(target.first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('pushed editor'),
      findsNothing,
      reason: 'the selection asked to go elsewhere, so the push is discarded',
    );
  });

  testWidgets('and the declarative pages themselves are not popped', (
    tester,
  ) async {
    _useWideView(tester);
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 300));

    final nav = _contentNav(tester);
    unawaited(
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('pushed editor')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(libL10n.about).first);
    await tester.pump(const Duration(milliseconds: 500));

    // `popUntil` stops at the first route whose settings is a `Page`. Popping
    // through those as well would empty the navigator and leave a blank pane.
    expect(find.byType(Navigator), findsWidgets);
    expect(
      tester.takeException(),
      isNull,
      reason: 'the content navigator still has a page in it',
    );
  });

  testWidgets('a pushed page with unsaved edits is asked, and can refuse', (
    tester,
  ) async {
    _useWideView(tester);
    await tester.pumpWidget(_app());
    await tester.pump(const Duration(milliseconds: 300));

    var answer = false;
    var asked = 0;
    unawaited(
      _contentNav(tester).push(
        MaterialPageRoute<void>(
          builder: (_) => PopGuard(
            enabled: true,
            confirm: () async {
              asked++;
              return answer;
            },
            child: const Scaffold(body: Text('dirty editor')),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text(libL10n.about).first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(asked, 1);
    expect(find.text('dirty editor'), findsOneWidget);

    // Platform back reaches the editor rather than skipping past it.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 500));
    expect(asked, 2);
    expect(find.text('dirty editor'), findsOneWidget);

    answer = true;
    await tester.tap(find.text(libL10n.about).first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(asked, 3);
    expect(find.text('dirty editor'), findsNothing);
  });

  group('pushed where a tab is shown', () {
    for (final (name, width) in [('wide', 1400.0), ('narrow', 400.0)]) {
      testWidgets('$name: back and its button put the settings away', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final wide = width >= 1000;
        await _pushSettings(tester, rail: wide);

        await tester.binding.handlePopRoute();
        expect(await _left(tester), isTrue);

        // Wide, the home rail beside the settings is the way out.
        await _pushSettings(tester, rail: wide);
        if (!wide) {
          await tester.tap(find.byType(BackButton).hitTestable().first);
          expect(await _left(tester), isTrue);
        } else {
          expect(find.byType(BackButton), findsNothing);
        }
      });
    }

    testWidgets('narrow on iOS, a swipe from the left edge is followed, and puts the settings away', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(400, 900);
      addTearDown(tester.view.reset);
      await _pushSettings(tester);

      Future<void> swipe(int steps) async {
        final g = await tester.startGesture(const Offset(4, 450));
        for (var i = 0; i < steps; i++) {
          await g.moveBy(const Offset(30, 0));
          await tester.pump(const Duration(milliseconds: 50));
        }
        // Followed: the page under shows through.
        expect(find.text('under'), findsOneWidget);
        await g.up();
      }

      // Short of a third, slowly: back to the settings.
      await swipe(3);
      expect(await _left(tester), isFalse);

      await swipe(10);
      expect(await _left(tester), isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('wide with no rail, the header button leaves the settings with a page open in them', (tester) async {
      _useWideView(tester);
      await _pushSettings(tester);
      unawaited(
        _contentNav(tester).push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('pushed editor'))),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tester.tap(
        find.descendant(of: find.byKey(settingsHeaderKey), matching: find.byType(BackButton)),
      );
      expect(await _left(tester), isTrue);
    });

    testWidgets('back leaves a pushed page and a search before the settings', (
      tester,
    ) async {
      _useWideView(tester);
      await _pushSettings(tester);

      unawaited(
        _contentNav(tester).push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('pushed editor')),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.binding.handlePopRoute();
      expect(await _left(tester), isFalse);
      expect(find.text('pushed editor'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'zzzz');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.binding.handlePopRoute();
      expect(await _left(tester), isFalse);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );

      await tester.binding.handlePopRoute();
      expect(await _left(tester), isTrue);
    });
  });
}
