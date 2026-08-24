/// What gets drawn beside a server's name, given what is and is not known.
///
/// Three outcomes and they have to stay distinguishable: a project's own mark
/// where one is shipped, an outline where nothing is known, and the address's
/// picture once one is set. The failure that hides is the outline — a row that
/// silently draws nothing looks like a layout bug, and a row that draws the
/// outline over a mark it had looks like the wrong distribution.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/widget/dist_icon.dart';

import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    GetIt.instance.registerSingleton<SettingStore>(
      SettingStore.forTest()..init(),
    );
    // Off by default, and every case below is about what is drawn when it is
    // on. The off case has a group of its own.
    GetIt.instance<SettingStore>().showDistMark.put(true);
  });

  tearDown(() async {
    await GetIt.instance.reset();
    SqliteDb.close();
  });

  Future<void> pump(WidgetTester tester, Dist? dist) => tester.pumpWidget(
    MaterialApp(home: Scaffold(body: Center(child: DistIconOf(dist)))),
  );

  /// A machine — what is drawn when it is not even known to be a Linux.
  Finder fallback() => find.byIcon(BoxIcons.bxs_server);

  /// A penguin — what is drawn for a Linux with no mark of its own.
  Finder penguin() => find.byIcon(MingCute.linux_fill);

  testWidgets('a distribution nothing recognised draws the machine', (
    tester,
  ) async {
    // Not the penguin: `uname -or` reaches the BSDs, macOS and Windows too, so
    // a machine that has not been identified is not known to be a Linux.
    await pump(tester, null);
    expect(fallback(), findsOneWidget);
    expect(penguin(), findsNothing);
  });

  testWidgets('a Linux with no mark of its own draws the penguin', (
    tester,
  ) async {
    // Ubuntu is the case people will meet: identified perfectly well, and its
    // logo is not ours to ship. That is not the same as not knowing, and the
    // row should not say it is.
    expect(Dist.ubuntu.markAsset, isNull, reason: 'the premise of this test');
    expect(Dist.ubuntu.isLinux, isTrue);
    await pump(tester, Dist.ubuntu);
    expect(penguin(), findsOneWidget);
  });

  testWidgets('and a recognised non-Linux draws the machine', (tester) async {
    // macOS and the BSDs are identified by name and are not Linux; a penguin
    // there would be wrong rather than merely uninformative.
    for (final dist in [Dist.macos, Dist.freebsd, Dist.windows]) {
      expect(dist.isLinux, isFalse, reason: 'Dist.${dist.name}');
      await pump(tester, dist);
      expect(fallback(), findsOneWidget, reason: 'Dist.${dist.name}');
      expect(penguin(), findsNothing, reason: 'Dist.${dist.name}');
    }
  });

  testWidgets('a shipped mark is drawn instead of the outline', (tester) async {
    await pump(tester, Dist.debian);
    await tester.pump();

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(fallback(), findsNothing, reason: 'the mark, not a stand-in for it');
  });

  testWidgets('and it is drawn in one colour', (tester) async {
    // A column of full-colour logos at the size of a line of text reads as
    // noise. Every mark takes the row's colour, and the fallback icons take
    // the same one so the column stays a column.
    await pump(tester, Dist.debian);
    await tester.pump();

    final svg = tester.widget<SvgPicture>(find.byType(SvgPicture));
    expect(
      svg.colorFilter,
      isNotNull,
      reason: 'the mark is drawn as published, in colour',
    );
  });

  group('switched off', () {
    // Off has to mean no pixels, not a blank of the same size: a leading slot
    // that holds a zero-sized box still reserves width in a `ListTile`, and a
    // six-pixel gap in a row is six pixels. So the answer is null and the
    // caller leaves the slot out — which is what `distIcon`/`distIconOf` are
    // for, and why every call site goes through them.
    setUp(() => GetIt.instance<SettingStore>().showDistMark.put(false));

    test('nothing is offered to draw, for any distribution', () {
      expect(distIconOf(null), isNull);
      expect(distIconOf(Dist.ubuntu), isNull);
      // Not even one with a mark shipped for it.
      expect(distIconOf(Dist.debian), isNull);
      expect(distIcon('some-id'), isNull);
    });

    testWidgets('and the widget itself draws nothing if reached anyway', (
      tester,
    ) async {
      // Belt and braces: a caller that builds `DistIconOf` directly — a test,
      // or a call site added without the helper — still draws no icon.
      await pump(tester, Dist.debian);
      expect(fallback(), findsNothing);
      expect(penguin(), findsNothing);
      expect(find.byType(SvgPicture), findsNothing);
    });
  });

  testWidgets('an address that cannot name a file leaves the outline', (
    tester,
  ) async {
    // `{DIST}` with nothing to put in it. Requesting the literal token would
    // be a 404 per row; the outline says "not known", which is the truth.
    GetIt.instance<SettingStore>().serverMarkUrl.put(
      'https://ex.com/{DIST}.svg',
    );
    await pump(tester, null);

    expect(fallback(), findsOneWidget);
  });
}
