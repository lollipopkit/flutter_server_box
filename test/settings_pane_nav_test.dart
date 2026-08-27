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

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/agent_conversation.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/setting/entry.dart';

import 'helpers/test_db.dart';

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

Widget _app() => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      LibLocalizations.delegate,
      ...AppLocalizations.localizationsDelegates,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) {
        app_locale.l10n = AppLocalizations.of(context)!;
        context.setLibL10n();
        return const SettingsPage();
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

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<ContainerStore>(ContainerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<BmcCredentialStore>(BmcCredentialStore());
    getIt.registerSingleton<SnippetStore>(SnippetStore());
    getIt.registerSingleton<HistoryStore>(HistoryStore('history_test'));
    getIt.registerSingleton<AgentConversationStore>(AgentConversationStore());
    getIt.registerSingleton<ConnectionStatsStore>(
      ConnectionStatsStore.instance,
    );
    getIt.registerSingleton<PortForwardStore>(PortForwardStore());
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
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

    // Any other section in the left menu.
    final target = find.text(libL10n.ai);
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

    await tester.tap(find.text(libL10n.ai).first);
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
}
