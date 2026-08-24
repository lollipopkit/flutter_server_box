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
