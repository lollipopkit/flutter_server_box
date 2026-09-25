import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/provider/session_keep_alive.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/session_keep_alive_notice.dart';

import '../helpers/test_db.dart';

/// The notice before an idle session closes: a toast in the top-right corner
/// naming the session, counting down, with "Keep alive".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    Stores.setting.remoteSessionIdleTimeout.put(30);
  });

  tearDown(() async {
    Toast.dismissAll();
    await getIt.reset();
    await closeTestDb();
  });

  late List<String> closed;

  Future<SessionKeepAlive> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    closed = [];

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (_, child) => ToastHost(
            child: SessionKeepAliveNotices(child: child ?? const SizedBox()),
          ),
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const Scaffold(body: Text('page'));
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    final keepAlive = container.read(sessionKeepAliveProvider.notifier);
    for (final (id, name) in [('a', 'web-01'), ('b', 'db-01')]) {
      keepAlive.register(
        id,
        name: name,
        host: 'pve-host',
        onClose: () => closed.add(id),
      );
    }
    return keepAlive;
  }

  /// Frames rather than `pumpAndSettle`: the countdown ticks for as long as
  /// the toast is up.
  Future<void> frames(WidgetTester tester, [int n = 10]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String closingIn(int s) => app_locale.l10n.remoteSessionClosingIn(s);

  testWidgets('names the session, counts down, top right, then closes it', (
    tester,
  ) async {
    final keepAlive = await pump(tester);
    keepAlive.setVisible('a', false);
    await tester.pump(const Duration(seconds: 30));
    await frames(tester);

    final title = find.text('web-01 · pve-host');
    expect(title, findsOneWidget);
    expect(find.text(closingIn(10)), findsOneWidget);
    expect(find.text(app_locale.l10n.remoteSessionKeepAlive), findsOneWidget);
    final at = tester.getTopRight(title);
    expect(at.dx, greaterThan(1280 / 2), reason: 'on the right');
    expect(at.dy, lessThan(800 / 4), reason: 'at the top');

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(find.text(closingIn(7)), findsOneWidget);
    expect(closed, isEmpty);

    await tester.pump(const Duration(seconds: 7));
    await frames(tester);
    expect(closed, ['a']);
    expect(title, findsNothing, reason: 'gone with the session');
  });

  testWidgets('away: the countdown shows what is left, and a session closed '
      'meanwhile is said once back', (tester) async {
    final keepAlive = await pump(tester);
    final binding = TestWidgetsFlutterBinding.instance;
    keepAlive.setVisible('a', false);
    await tester.pump(const Duration(seconds: 30 + 3));
    await frames(tester);
    expect(find.text(closingIn(7)), findsOneWidget);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await frames(tester);
    expect(find.text(closingIn(7)), findsOneWidget, reason: 'held');

    // Another whole timeout away: closed without waiting on the notice.
    await tester.pump(const Duration(seconds: 30));
    await frames(tester);
    expect(closed, ['a']);
    // No frames are drawn while the app is hidden: what is on screen is
    // checked once it is back.

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester, 20);
    expect(find.text(app_locale.l10n.remoteSessionClosedAway), findsOneWidget);
    expect(find.textContaining(closingIn(7)), findsNothing);
    expect(find.text(app_locale.l10n.remoteSessionKeepAlive), findsNothing);
    Toast.dismissAll();
    await frames(tester, 20);
  });

  testWidgets('keep alive dismisses it and starts the timeout again', (
    tester,
  ) async {
    final keepAlive = await pump(tester);
    keepAlive.setVisible('a', false);
    await tester.pump(const Duration(seconds: 30));
    await frames(tester);

    await tester.tap(find.text(app_locale.l10n.remoteSessionKeepAlive));
    await frames(tester);
    expect(find.text('web-01 · pve-host'), findsNothing);

    await tester.pump(const Duration(seconds: 20));
    await frames(tester);
    expect(closed, isEmpty, reason: 'past the first deadline, still open');
    expect(find.text('web-01 · pve-host'), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    await frames(tester);
    expect(find.text('web-01 · pve-host'), findsOneWidget);
    await tester.pump(SessionKeepAlive.grace);
    await frames(tester);
    expect(closed, ['a']);
  });

  testWidgets('coming back takes it down; several stack, each its own', (
    tester,
  ) async {
    final keepAlive = await pump(tester);
    keepAlive
      ..setVisible('a', false)
      ..setVisible('b', false);
    await tester.pump(const Duration(seconds: 30));
    await frames(tester);
    expect(find.text('web-01 · pve-host'), findsOneWidget);
    expect(find.text('db-01 · pve-host'), findsOneWidget);

    keepAlive.setVisible('a', true);
    await frames(tester);
    expect(find.text('web-01 · pve-host'), findsNothing);
    expect(find.text('db-01 · pve-host'), findsOneWidget);

    await tester.pump(SessionKeepAlive.grace);
    await frames(tester);
    expect(closed, ['b']);
  });
}
