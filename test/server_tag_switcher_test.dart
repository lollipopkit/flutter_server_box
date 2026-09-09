/// The tag switcher when there are no tags.
///
/// It used to be a plain label then — no chevron, no ink — following the rule
/// the session strips use with nothing open. The two are not alike: a terminal
/// strip with no sessions is a feature nobody has started, while this is a
/// filter whose vocabulary is defined on another page entirely. Somebody
/// looking for tags taps the control marked with a `#`, and one that does
/// nothing answers neither "there are none" nor "here is where they come
/// from".
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/tab/tab.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('tag-switcher-');
    Paths.doc = tmp.path;
  });

  tearDownAll(() => tmp.delete(recursive: true));

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<SelfAddrStore>(SelfAddrStore('self_addr_test'));
    // Off, or its periodic timer outlives the tree and fails the run.
    Stores.setting.serverStatusUpdateInterval.put(0);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  void addServer({List<String>? tags}) {
    Stores.server.put(
      spiFixture(
        id: 'srv-1',
        name: 'web',
        ip: '10.0.0.1',
        user: 'u',
        autoConnect: false,
        tags: tags,
      ),
    );
  }

  /// The page holds a refresh timer and the bar animates, so frames are counted
  /// out by hand — `pumpAndSettle` never returns here.
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
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
          home: const ServerPage(),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  Future<void> openSwitcher(WidgetTester tester) async {
    // The chevron, not the label's box: the label is `Align`ed to the start
    // inside an `Expanded`, so its box spans the bar while the ink only covers
    // the content — a tap at the centre lands on nothing.
    await tester.tap(
      find.descendant(
        of: find.byType(SessionSwitcherLabel),
        matching: find.byIcon(Icons.expand_more),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('with no tags the switcher still opens, and says where they '
      'come from', (tester) async {
    addServer();
    await pump(tester);

    // The chevron is what makes it readable as a way in at all.
    expect(
      find.descendant(
        of: find.byType(SessionSwitcherLabel),
        matching: find.byIcon(Icons.expand_more),
      ),
      findsOneWidget,
      reason: 'the switcher is a dead label with no tags',
    );

    await openSwitcher(tester);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.tagsEmptyTip), findsOneWidget);
    // `All` is still a row: it is the current state, and a sheet of nothing
    // but a sentence reads as an error. Scoped to the sheet, since the bar's
    // own label says `All` too.
    expect(
      find.descendant(
        of: find.byType(SheetChoiceTile),
        matching: find.text(libL10n.all),
      ),
      findsOneWidget,
    );
  });

  testWidgets('with tags it lists them, and drops the tip', (tester) async {
    addServer(tags: ['prod', 'eu']);
    await pump(tester);
    await openSwitcher(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('prod'), findsOneWidget);
    expect(find.text('eu'), findsOneWidget);
    expect(find.text(l10n.tagsEmptyTip), findsNothing);
  });
}
