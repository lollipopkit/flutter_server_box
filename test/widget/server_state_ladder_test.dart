import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icons_plus/icons_plus.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/chart_palette.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/connection_stats.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/card/card.dart';
import 'package:server_box/view/page/server/card/density.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

/// The six states a machine can be in, as a line and as a tile.
///
/// A line's whole value is that forty of them are aligned, so the one thing
/// none of the six may do is change its height — a machine that cannot be
/// reached must not push the rest down. And what it says instead of readings
/// has to be in the same place every time, or the column has to be read row by
/// row to find out whether it said anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-ladder-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<ConnectionStatsStore>(ConnectionStatsStore.instance);
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  ServerStatus blank() => ServerStatus(
    cpu: Cpus(),
    mem: const Memory(total: 0, free: 0, avail: 0),
    disk: const [],
    tcp: const Conn(maxConn: 0, fail: 0),
    netSpeed: NetSpeed(),
    swap: const Swap(total: 0, free: 0, cached: 0),
    temps: Temperatures(),
    system: SystemType.linux,
    diskIO: DiskIO(),
  );

  ServerStatus sampled() => ServerStatus(
    cpu: Cpus(),
    mem: const Memory(total: 1048576, free: 524288, avail: 524288),
    disk: const [],
    tcp: const Conn(maxConn: 0, fail: 0),
    netSpeed: NetSpeed(),
    swap: const Swap(total: 0, free: 0, cached: 0),
    temps: Temperatures(),
    system: SystemType.linux,
    diskIO: DiskIO(),
  );

  ServerState state(ServerConn conn, {Err? err, bool sample = false}) {
    final status = sample ? sampled() : blank();
    status.err = err;
    return ServerState(
      spi: spiFixture(id: 'srv-1', name: 'web', ip: 'h', user: 'u'),
      status: status,
      conn: conn,
    );
  }

  /// The five that can be built without a clock — stale is the sixth and is
  /// `finished` with an old sample, which is `serverStaleSince`'s own test.
  final ladder = <String, ServerState>{
    'disconnected': state(ServerConn.disconnected),
    'connecting': state(ServerConn.connecting),
    'failed': state(
      ServerConn.failed,
      err: SSHErr(type: SSHErrType.connect, message: 'Connection refused'),
    ),
    'auth': state(
      ServerConn.failed,
      err: SSHErr(type: SSHErrType.interactiveAuth, message: 'need otp'),
    ),
    'finished': state(ServerConn.finished, sample: true),
  };

  Future<void> pump(
    WidgetTester tester,
    ServerState srv, {
    required ServerListDensity density,
    double width = 700,
  }) async {
    tester.view.physicalSize = Size(width, 400);
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
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: ServerCard(
                srv: srv,
                promoted: null,
                onPromote: (_) {},
                onToggleExpanded: () {},
                onTap: () {},
                density: density,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('a line', () {
    testWidgets('is the same height in every state', (tester) async {
      final heights = <String, double>{};
      for (final MapEntry(key: name, value: srv) in ladder.entries) {
        await pump(tester, srv, density: ServerListDensity.rows);
        expect(tester.takeException(), isNull, reason: name);
        heights[name] = tester.getSize(find.byType(ServerCard)).height;
      }

      expect(
        heights.values.toSet(),
        hasLength(1),
        reason: 'the six states drew at $heights',
      );
    });

    testWidgets('says where the machine stands, in the same place', (
      tester,
    ) async {
      // The right column, which is what a chevron used to be. Each of these
      // is the word for one of the states, and none of them is a reading.
      // `disconnected` and `auth` are not here: the middle of those rows is
      // already the same sentence, and the column keeps quiet rather than
      // saying it twice on one 40pt line.
      final words = {
        'connecting': l10n.connecting,
        'failed': libL10n.retry,
      };

      double? at;
      for (final MapEntry(key: name, value: word) in words.entries) {
        await pump(tester, ladder[name]!, density: ServerListDensity.rows);
        expect(find.text(word), findsOneWidget, reason: name);
        // The same place on every row: the column's right edge does not move.
        final right = tester.getRect(find.text(word)).right;
        at ??= right;
        expect(right, moreOrLessEquals(at, epsilon: 0.5), reason: name);
      }
    });

    testWidgets('and says it once when the middle already has', (tester) async {
      for (final (name, word) in [
        ('disconnected', libL10n.disconnected),
        ('auth', libL10n.tapToAuth),
      ]) {
        await pump(tester, ladder[name]!, density: ServerListDensity.rows);
        expect(find.text(word), findsOneWidget, reason: name);
      }
    });

    testWidgets('and offers the one thing to do about it', (tester) async {
      // The same mapping the card's own title row uses, so a machine offers
      // the same control whichever shape the list is in.
      for (final (name, icon) in [
        ('disconnected', MingCute.link_3_line),
        ('failed', Icons.refresh),
        ('auth', Icons.lock_outline),
        ('finished', MingCute.unlink_2_line),
      ]) {
        await pump(tester, ladder[name]!, density: ServerListDensity.rows);
        expect(find.byIcon(icon), findsOneWidget, reason: name);
      }
    });

    testWidgets('a machine on its way shows a line, not a word about it', (
      tester,
    ) async {
      await pump(tester, ladder['connecting']!, density: ServerListDensity.rows);
      // One, not two: the action slot keeps its width and draws nothing,
      // because the line across the middle is already that answer.
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('and one that failed says what the far end said', (
      tester,
    ) async {
      await pump(tester, ladder['failed']!, density: ServerListDensity.rows);
      // Not "Failure": `Connection refused` against `No route to host` is the
      // difference between a machine to look at now and one to look at later.
      expect(find.textContaining('Connection refused'), findsWidgets);
    });
  });

  group('a tile', () {
    Color colorOf(WidgetTester tester, String text) =>
        tester.widget<Text>(find.text(text)).style!.color!;

    testWidgets('has room for one word, so it is a short one', (tester) async {
      await pump(
        tester,
        ladder['failed']!,
        density: ServerListDensity.grid,
        width: 200,
      );
      expect(find.text(libL10n.fail), findsOneWidget);
      expect(colorOf(tester, libL10n.fail), StatePalette.failed);
    });

    testWidgets('and one waiting to be let in says so in amber', (
      tester,
    ) async {
      await pump(
        tester,
        ladder['auth']!,
        density: ServerListDensity.grid,
        width: 200,
      );
      expect(find.text(l10n.authShort), findsOneWidget);
      expect(colorOf(tester, l10n.authShort), StatePalette.warn);
      // Not the card's word, which a 44pt tile cannot hold.
      expect(find.text(libL10n.tapToAuth), findsNothing);
    });

    testWidgets('is the same height whether it has readings or not', (
      tester,
    ) async {
      final heights = <double>{};
      for (final srv in ladder.values) {
        await pump(
          tester,
          srv,
          density: ServerListDensity.grid,
          width: 200,
        );
        heights.add(tester.getSize(find.byType(ServerCard)).height);
      }
      expect(heights, hasLength(1));
    });
  });
}
