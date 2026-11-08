import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/home.dart';
import 'package:server_box/view/page/setting/entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every navigator on screen and off, by identity: one mounted again is a
/// different state.
List<NavigatorState> _navigators(WidgetTester tester) =>
    tester.stateList<NavigatorState>(find.byType(Navigator, skipOffstage: false)).toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Paths.doc = Directory.systemTemp.createTempSync('sbm-home-swipe-').path;
  });
  tearDownAll(() => Directory(Paths.doc).deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    FlutterSecureStorage.setMockInitialValues({});
    SqliteDb.openInMemory();
    await Stores.init();
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// The home on a phone, or at [size]; its settings [open]ed.
  Future<ProviderContainer> pumpHome(WidgetTester tester, {Size size = const Size(390, 844)}) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [...app_locale.appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: ResponsivePoints.builder,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return const HomePage();
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  Future<void> open(WidgetTester tester, ProviderContainer container) async {
    container.read(settingsRequestProvider.notifier).go();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SettingsPage).hitTestable(), findsOneWidget);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    // The sync a settings write schedules.
    await tester.pump(const Duration(seconds: 6));
  }

  testWidgets('a back swipe on the settings keeps the tabs mounted, and puts the settings away once', (
    tester,
  ) async {
    final container = await pumpHome(tester);
    final tabs = _navigators(tester);
    await open(tester, container);
    final before = _navigators(tester);

    final gesture = await tester.startGesture(const Offset(4, 400));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(_navigators(tester), before, reason: 'nothing is mounted again as the swipe begins');

    await gesture.up();
    await settle(tester);
    expect(find.byType(SettingsPage), findsNothing, reason: 'the settings are put away, not shown again');
    expect(_navigators(tester), tabs);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('back puts the settings away and then is the app\'s', (tester) async {
    final container = await pumpHome(tester);
    await open(tester, container);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await settle(tester);
    expect(find.byType(SettingsPage), findsNothing);

    // And open again.
    await open(tester, container);
    await unmount(tester);
  });

  // #1886: wide enough for the settings' two columns, too narrow for the rail
  // beside them, so the bar was the way out, and the settings cover it.
  testWidgets('an iPad upright has a way back out of the settings', (tester) async {
    final container = await pumpHome(tester, size: const Size(820, 1180));
    await open(tester, container);

    await tester.tap(find.byType(BackButton).hitTestable());
    await settle(tester);
    expect(find.byType(SettingsPage), findsNothing);
    await unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
