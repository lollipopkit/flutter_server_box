import 'package:fl_lib/theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/motion.dart';
import 'package:server_box/data/model/app/motion.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../helpers/test_db.dart';

/// Whether the app moves less: the device's settings, the app's own
/// preference over them, and the page transitions that follow the answer.
///
/// The preference is written where the app writes it — `Stores.setting`'s own
/// property, which `AppMotion.init` follows — rather than through a setter
/// only this file could reach.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // One store and one `AppMotion.init` for the whole file: `init` runs once per
  // process and subscribes to the store that was registered when it did, so a
  // store re-registered per test would leave it following a disposed one.
  setUpAll(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    await AppMotion.init();
  });

  setUp(() {
    // What the device says, before any test overrides it: the two that assert
    // the device's own signals are about a preference that defers to them.
    Stores.setting.motionPref.put(MotionPref.system);
  });

  tearDownAll(() async {
    await getIt.reset();
    await closeTestDb();
  });

  /// The app's preference, changed the way a user changes it.
  ///
  /// `put` reaches `AppMotion` through the property's listenable synchronously,
  /// so there is nothing to await — and nothing that may be: inside
  /// `testWidgets` the clock is fake, so `pumpEventQueue` never returns.
  void setPref(MotionPref pref) => Stores.setting.motionPref.put(pref);

  test('the preference over what the device says', () {
    for (final system in [false, true]) {
      expect(MotionPref.system.reduces(system: system), system);
      expect(MotionPref.reduce.reduces(system: system), isTrue);
      expect(MotionPref.full.reduces(system: system), isFalse);
    }
  });

  /// What a widget under [MotionScope] is told.
  Future<bool> seen(WidgetTester tester) async {
    late bool reduced;
    await tester.pumpWidget(
      MotionScope(
        child: Builder(
          builder: (context) {
            reduced = MediaQuery.disableAnimationsOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return reduced;
  }

  Future<void> device(
    WidgetTester tester, {
    bool disableAnimations = false,
    bool reduceMotion = false,
  }) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(
          disableAnimations: disableAnimations,
          reduceMotion: reduceMotion,
        );
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    AppMotion.refreshSystem();
  }

  testWidgets("iOS's reduce motion counts, which Flutter does not merge", (
    tester,
  ) async {
    await device(tester, reduceMotion: true);
    expect(await seen(tester), isTrue);
  });

  testWidgets("and so does Android's remove animations", (tester) async {
    await device(tester, disableAnimations: true);
    expect(await seen(tester), isTrue);
  });

  testWidgets('the app says otherwise in either direction', (tester) async {
    await device(tester, reduceMotion: true);
    setPref(MotionPref.full);
    expect(await seen(tester), isFalse);

    await device(tester);
    setPref(MotionPref.reduce);
    expect(await seen(tester), isTrue);
  });

  testWidgets('a change keeps the state below it', (tester) async {
    final key = GlobalKey<_CounterState>();
    await tester.pumpWidget(
      MotionScope(child: _Counter(key: key)),
    );
    key.currentState!.count = 3;

    setPref(MotionPref.reduce);
    await tester.pump();
    expect(key.currentState!.count, 3);
  });

  group('a page pushed', () {
    /// Where the arriving page is and how opaque, halfway in.
    Future<(double, double)> halfway(
      WidgetTester tester, {
      required bool reduced,
    }) async {
      setPref(reduced ? MotionPref.reduce : MotionPref.full);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          theme: ThemeData(
            platform: TargetPlatform.iOS,
            pageTransitionsTheme: AppPageTransitions.plain,
          ),
          builder: (_, child) => MotionScope(child: child!),
          home: const Text('below'),
        ),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('arriving')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      final x = tester.getTopLeft(find.text('arriving')).dx;
      final fades = find.ancestor(
        of: find.text('arriving'),
        matching: find.byType(FadeTransition),
      );
      // Every fade the page is under: the platform's builder may bring its
      // own, held at 1 while the app moves less.
      final opacity = tester
          .widgetList<FadeTransition>(fades)
          .fold(1.0, (o, f) => o * f.opacity.value);
      return (x, opacity);
    }

    testWidgets('slides in', (tester) async {
      final (x, _) = await halfway(tester, reduced: false);
      expect(x, greaterThan(0));
    });

    testWidgets('fades in where it stands when the app moves less', (
      tester,
    ) async {
      final (x, opacity) = await halfway(tester, reduced: true);
      expect(x, 0);
      expect(opacity, inExclusiveRange(0, 1));
    });

    testWidgets('and is still left with a swipe from the edge', (tester) async {
      await halfway(tester, reduced: true);
      await tester.pumpAndSettle();
      expect(find.text('arriving'), findsOneWidget);

      final drag = await tester.startGesture(const Offset(5, 300));
      for (var i = 0; i < 10; i++) {
        await drag.moveBy(const Offset(60, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Held still under the finger, fading rather than following it.
      expect(tester.getTopLeft(find.text('arriving')).dx, 0);
      await drag.up();
      await tester.pumpAndSettle();
      expect(find.text('arriving'), findsNothing);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter({super.key});

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => const SizedBox();
}
