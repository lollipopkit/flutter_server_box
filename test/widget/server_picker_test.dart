/// The shared "which server?" sheet.
///
/// Shared because each of these is easy to leave out of a picker written for
/// one page, and every one of them was left out of the first: the distribution
/// mark, the tags, the search, and the order the user actually arranged. A
/// second hand-rolled dropdown would have missed the same four.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/dist.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/server_sort.dart';
import 'package:server_box/data/provider/server/sort.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/server_dist.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/dist_icon.dart';
import 'package:server_box/view/widget/server_picker.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

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

  /// Raises [ask], whose answer the test keeps for itself: it arrives once
  /// the sheet is gone.
  Future<void> raise(
    WidgetTester tester,
    Future<Object?> Function(BuildContext ctx) ask,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [...appLocalizationsDelegates],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => ask(ctx),
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
  }

  /// Past the sheet's exit, after which its answer has arrived.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> open(WidgetTester tester, {String? selectedId}) =>
      raise(tester, (ctx) => pickServer(ctx, selectedId: selectedId));

  Future<void> type(WidgetTester tester, String needle) async {
    await tester.enterText(find.byType(TextField).first, needle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  Finder tickOf(String name) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(ListTile)),
    matching: find.byIcon(Icons.check),
  );

  testWidgets('lists every server, and answers with the one tapped', (
    tester,
  ) async {
    Spi? picked;
    await raise(tester, (ctx) async => picked = await pickServer(ctx));

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('gamma'), findsOneWidget);

    await tester.tap(find.text('beta'));
    await settle(tester);

    // The sheet is gone, and it was the tap that closed it.
    expect(find.text('alpha'), findsNothing);
    expect(picked?.id, 'b');
    await close(tester);
  });

  testWidgets('search narrows by name, tag and address', (tester) async {
    await open(tester);

    Future<void> typed(String needle) => type(tester, needle);

    await typed('bet');
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('alpha'), findsNothing);

    // A tag, not a name.
    await typed('prod');
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsNothing);

    // An address, not a name either. Somebody who reaches a box by its IP
    // remembers the IP.
    await typed('10.0.0.3');
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
    // Sorted by name, descending — the setting the server tab writes for the
    // list with no tag on it. The picker is not inside a tag either, so it
    // reads that same one and the two lists can never disagree.
    const ServerSortOrder(
      ServerSortField.name,
      ascending: false,
    ).save(TagSwitcher.kDefaultTag);

    await open(tester);

    final names = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d == 'alpha' || d == 'beta' || d == 'gamma')
        .toList();
    expect(names, ['gamma', 'beta', 'alpha']);
    await close(tester);
  });

  testWidgets('its sort button sets the order, the server tab\'s own', (
    tester,
  ) async {
    await open(tester);
    List<String?> names() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((d) => d == 'alpha' || d == 'beta' || d == 'gamma')
        .toList();
    expect(names(), ['alpha', 'beta', 'gamma']);

    const descending = ServerSortOrder(ServerSortField.name, ascending: false);
    await tester.tap(find.byTooltip(libL10n.sort));
    await settle(tester);
    await tester.tap(find.text(descending.label));
    await settle(tester);

    expect(names(), ['gamma', 'beta', 'alpha']);
    expect(descending.isCurrentFor(TagSwitcher.kDefaultTag), isTrue);
    await close(tester);
  });

  testWidgets('the current server is ticked', (tester) async {
    await open(tester, selectedId: 'b');

    expect(tickOf('beta'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a filter narrows what is offered, in the same order', (
    tester,
  ) async {
    await raise(
      tester,
      (ctx) => pickServer(
        ctx,
        title: 'title',
        where: (_, spi) => spi.id != 'b',
      ),
    );

    expect(find.text('title'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsNothing);
    expect(find.text('gamma'), findsOneWidget);
    // The tags are those of what is offered: `staging` was beta's alone.
    await settle(tester);
    expect(find.text('#prod'), findsOneWidget);
    expect(find.text('#staging'), findsNothing);
    await close(tester);
  });

  group('extra rows', () {
    // The shape of "send to": this device, then the servers that take files.
    Future<void> sendTo(
      WidgetTester tester,
      void Function(ServerPick<String>?) onAnswer,
    ) => raise(tester, (ctx) async {
      final pick = await pickServerOr<String>(
        ctx,
        where: (_, spi) => spi.id != 'c',
        extras: [
          ServerPickerExtra(
            icon: Icons.smartphone,
            title: libL10n.device,
            value: 'device',
          ),
        ],
      );
      onAnswer(pick);
      return pick;
    });

    testWidgets('come first, and answer their value', (tester) async {
      ServerPick<String>? picked;
      await sendTo(tester, (p) => picked = p);

      final device = tester.getTopLeft(find.text(libL10n.device)).dy;
      expect(device, lessThan(tester.getTopLeft(find.text('alpha')).dy));
      expect(find.text('gamma'), findsNothing);

      await tester.tap(find.text(libL10n.device));
      await settle(tester);
      expect(picked, isA<PickedExtra<String>>());
      expect((picked! as PickedExtra<String>).value, 'device');
      await close(tester);
    });

    testWidgets('a server still answers as one', (tester) async {
      ServerPick<String>? picked;
      await sendTo(tester, (p) => picked = p);

      await tester.tap(find.text('alpha'));
      await settle(tester);
      expect(picked, isA<PickedServer<String>>());
      expect((picked! as PickedServer<String>).spi.id, 'a');
      await close(tester);
    });

    testWidgets('search narrows the servers and drops the fixed rows', (
      tester,
    ) async {
      ServerPick<String>? picked;
      await sendTo(tester, (p) => picked = p);

      await type(tester, 'bet');
      expect(find.text('beta'), findsOneWidget);
      expect(find.text('alpha'), findsNothing);
      expect(find.text(libL10n.device), findsNothing);

      // Still only what the filter offers.
      await type(tester, '10.0.0.3');
      expect(find.text('gamma'), findsNothing);
      expect(find.text(libL10n.empty), findsOneWidget);

      await type(tester, '');
      expect(find.text(libL10n.device), findsOneWidget);
      await tester.tap(find.text('beta'));
      await settle(tester);
      expect((picked! as PickedServer<String>).spi.id, 'b');
      await close(tester);
    });

    testWidgets('a dismissal answers null', (tester) async {
      var answered = false;
      ServerPick<String>? picked;
      await sendTo(tester, (p) {
        answered = true;
        picked = p;
      });

      await tester.tapAt(const Offset(400, 10));
      await settle(tester);
      expect(answered, isTrue);
      expect(picked, isNull);
      await close(tester);
    });

    testWidgets('a selected one is ticked', (tester) async {
      await raise(
        tester,
        (ctx) => pickServerOr<int>(
          ctx,
          extras: [
            ServerPickerExtra(
              icon: Icons.dns_outlined,
              title: libL10n.all,
              value: 0,
              selected: true,
            ),
          ],
        ),
      );
      expect(tickOf(libL10n.all), findsOneWidget);
      await close(tester);
    });
  });

  group('several', () {
    late List<Spi>? picked;
    late bool answered;

    Future<void> openMany(
      WidgetTester tester, {
      Iterable<String> initial = const [],
      bool clearable = false,
      ServerFilter? where,
    }) async {
      picked = null;
      answered = false;
      await raise(tester, (ctx) async {
        picked = await pickServers(
          ctx,
          initial: initial,
          clearable: clearable,
          where: where,
        );
        answered = true;
        return picked;
      });
    }

    Future<void> ok(WidgetTester tester) async {
      await tester.tap(find.text(libL10n.ok));
      await settle(tester);
    }

    testWidgets('ticks the initial ones, toggles, and answers in order', (
      tester,
    ) async {
      await openMany(tester, initial: ['c']);
      expect(tickOf('gamma'), findsOneWidget);
      expect(tickOf('alpha'), findsNothing);

      await tester.tap(find.text('alpha'));
      await tester.pump();
      // A tap ticks; it does not close the sheet.
      expect(tickOf('alpha'), findsOneWidget);
      expect(answered, isFalse);

      await ok(tester);
      expect(picked?.map((e) => e.id), ['a', 'c']);
      await close(tester);
    });

    testWidgets('a dismissal is null, a cleared OK an empty list', (
      tester,
    ) async {
      await openMany(tester, initial: ['a'], clearable: true);
      await tester.tapAt(const Offset(400, 10));
      await settle(tester);
      expect(answered, isTrue);
      expect(picked, isNull);
      await close(tester);

      await openMany(tester, initial: ['a'], clearable: true);
      await tester.tap(find.text('alpha'));
      await tester.pump();
      await ok(tester);
      expect(picked, isEmpty);
      await close(tester);
    });

    testWidgets('without clearable the last one stays ticked', (tester) async {
      await openMany(tester, initial: ['a']);
      await tester.tap(find.text('alpha'));
      await tester.pump();
      expect(tickOf('alpha'), findsOneWidget);
      await ok(tester);
      expect(picked?.map((e) => e.id), ['a']);
      await close(tester);
    });

    testWidgets('an initial id not offered is not answered', (tester) async {
      await openMany(
        tester,
        initial: ['a', 'b', 'gone'],
        where: (_, spi) => spi.id != 'b',
      );
      await ok(tester);
      expect(picked?.map((e) => e.id), ['a']);
      await close(tester);
    });

    testWidgets('a ticked one hidden by the search stays ticked', (
      tester,
    ) async {
      await openMany(tester, initial: ['a']);
      await type(tester, 'gam');
      await tester.tap(find.text('gamma'));
      await tester.pump();
      await ok(tester);
      expect(picked?.map((e) => e.id), ['a', 'c']);
      await close(tester);
    });
  });
}
