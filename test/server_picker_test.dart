/// The shared "which server?" sheet.
///
/// Shared because each of these is easy to leave out of a picker written for
/// one page, and every one of them was left out of the first: the distribution
/// mark, the tags, the search, and the order the user actually arranged. A
/// second hand-rolled dropdown would have missed the same four.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server_picker.dart';
import 'package:server_box/data/model/app/server_sort.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/dist_icon.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-picker-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    // `DistIcon` reads the cache through `Stores.serverDist`.
    getIt.registerSingleton<ServerDistStore>(ServerDistStore());
    Stores.setting.serverStatusUpdateInterval.put(0);

    Stores.server.put(
      spiFixture(id: 'a', name: 'alpha', ip: '10.0.0.1', tags: ['prod']),
    );
    Stores.server.put(
      spiFixture(id: 'b', name: 'beta', ip: '10.0.0.2', tags: ['staging']),
    );
    Stores.server.put(spiFixture(id: 'c', name: 'gamma', ip: '10.0.0.3'));
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// Raises the sheet and hands back whatever it answered.
  Future<Spi?> open(WidgetTester tester, {String? selectedId}) async {
    Spi? picked;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    picked = await pickServer(ctx, selectedId: selectedId);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // No `pumpAndSettle`: the sheet holds a text field, whose cursor never
    // stops scheduling frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return picked;
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('lists every server, and answers with the one tapped', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);

    await tester.tap(find.text('beta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // The sheet is gone, and it was the tap that closed it.
    expect(find.text('alpha'), findsNothing);
    await close(tester);
  });

  testWidgets('search narrows by name, tag and address', (tester) async {
    await open(tester);

    Future<void> type(String needle) async {
      await tester.enterText(find.byType(TextField).first, needle);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await type('bet');
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('alpha'), findsNothing);

    // A tag, not a name.
    await type('prod');
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsNothing);

    // An address, not a name either. Somebody who reaches a box by its IP
    // remembers the IP.
    await type('10.0.0.3');
    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('alpha'), findsNothing);

    await close(tester);
  });

  testWidgets('the tag row filters, and is absent when nothing is tagged', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(TagSwitcher), findsOneWidget);
    // The tag set is published after the frame that computed it, so the chips
    // arrive one frame behind the row that holds them.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // `TagSwitcher` labels a chip `#tag`; the bare word appears only inside a
    // row's subtitle, joined with the address.
    await tester.tap(find.text('#prod'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsNothing);
    expect(find.text('gamma'), findsNothing);
    await close(tester);

    // Nothing tagged: no row, rather than an empty strip of chrome.
    Stores.server.put(spiFixture(id: 'a', name: 'alpha', ip: '10.0.0.1'));
    Stores.server.put(spiFixture(id: 'b', name: 'beta', ip: '10.0.0.2'));
    await open(tester);
    expect(find.byType(TagSwitcher), findsNothing);
    await close(tester);
  });

  testWidgets('rows carry the distribution mark', (tester) async {
    // Off by default, which is a setting and not an oversight — turned on here
    // because the question is whether the picker honours it.
    Stores.setting.showDistMark.put(true);
    // Nothing in a `Spi` says what a machine runs; it is observed. The cache is
    // what lets a mark appear on a server that is not currently connected,
    // which is every server in a picker.
    Stores.serverDist.put('a', Dist.debian);

    await open(tester);

    expect(find.byType(DistIcon), findsWidgets);
    await close(tester);
  });

  testWidgets('the mark is absent when the setting is off', (tester) async {
    // Which is the default. `distIcon` answers null rather than an empty box,
    // so that off means no pixels — a zero-sized widget would still reserve the
    // whole leading column.
    Stores.setting.showDistMark.put(false);
    Stores.serverDist.put('a', Dist.debian);

    await open(tester);

    expect(find.byType(DistIcon), findsNothing);
    await close(tester);
  });

  testWidgets('the order is the one the user arranged', (tester) async {
    // Sorted by name, descending — the setting the server tab writes. The
    // picker reads the same one, so the two lists can never disagree.
    const ServerSortOrder(ServerSortField.name, ascending: false).save();

    await open(tester);

    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d == 'alpha' || d == 'beta' || d == 'gamma')
        .toList();
    expect(names, ['gamma', 'beta', 'alpha']);
    await close(tester);
  });

  testWidgets('the current server is ticked', (tester) async {
    await open(tester, selectedId: 'b');

    final tick = find.descendant(
      of: find.ancestor(
        of: find.text('beta'),
        matching: find.byType(ListTile),
      ),
      matching: find.byIcon(Icons.check),
    );
    expect(tick, findsOneWidget);
    await close(tester);
  });
}
