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

  Finder fallback() => find.byIcon(BoxIcons.bxs_server);

  testWidgets('a distribution nothing recognised draws the outline', (
    tester,
  ) async {
    await pump(tester, null);
    expect(fallback(), findsOneWidget);
  });

  testWidgets('and so does one recognised but not shipped', (tester) async {
    // Ubuntu is the case people will meet: identified perfectly well, and its
    // logo is not ours to ship. Out of the box that is an outline, not a gap.
    expect(Dist.ubuntu.markAsset, isNull, reason: 'the premise of this test');
    await pump(tester, Dist.ubuntu);
    expect(fallback(), findsOneWidget);
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
