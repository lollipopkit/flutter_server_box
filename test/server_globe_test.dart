import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/geo.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/self_addr.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/widget/globe/view.dart';
import 'package:server_box/view/widget/server_globe.dart';
import 'helpers/geo_fixture.dart';
import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

/// The layer that knows about servers: where each one is, what its card says,
/// and what happens when one is tapped.
///
/// Tested directly rather than only through the server tab, because what is
/// interesting here — resolution running once per server, a card carrying live
/// readings, an unplaceable server ending up in the strip — is several layers
/// down from a page.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('server-globe-');
    Paths.doc = tmp.path;
  });

  tearDownAll(() => tmp.delete(recursive: true));

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<SelfAddrStore>(SelfAddrStore('self_addr_test'));
    Stores.setting.serverStatusUpdateInterval.put(0);
    await installGeoVectors();
  });

  tearDown(() async {
    await removeGeoVectors();
    await getIt.reset();
    await closeTestDb();
  });

  void addServer(String id, String ip, {String? name, GeoCoord? geo}) {
    Stores.server.put(
      spiFixture(
        id: id,
        name: name ?? 'srv $id',
        ip: ip,
        user: 'u',
        autoConnect: false,
      ).copyWith(custom: geo == null ? null : ServerCustom(geo: geo)),
    );
  }

  Spi? tapped;
  Spi? edited;

  /// The globe under test, wrapped however the caller needs.
  ///
  /// [wrap] exists for the one case that overrides a provider: the type
  /// `ProviderScope.overrides` takes is not exported by `flutter_riverpod`, so
  /// a test that needs one builds its own scope rather than naming it.
  Widget tree(List<String> ids) => MaterialApp(
    home: Scaffold(
      body: ServerGlobe(
        ids: ids,
        onTapServer: (spi) => tapped = spi,
        onEditServer: (spi) => edited = spi,
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    // Resolution is async and the entrance animates. Counted out, because
    // `pumpAndSettle` waits for a frame with nothing scheduled and the globe
    // may never give it one.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> show(WidgetTester tester, List<String> ids) async {
    tapped = null;
    edited = null;
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(child: tree(ids)));
    await settle(tester);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('a server the database places gets a card on the globe', (
    tester,
  ) async {
    addServer('a', '8.8.8.8', name: 'washington');
    await show(tester, ['a']);
    expect(find.byType(GlobeView), findsOneWidget);
    expect(find.text('washington'), findsOneWidget);
  });

  testWidgets('a server nothing can place goes in the strip instead', (
    tester,
  ) async {
    // A private address never reaches a lookup at all.
    addServer('lan', '192.168.1.10', name: 'nas');
    await show(tester, ['lan']);
    expect(find.widgetWithText(ActionChip, 'nas'), findsOneWidget);
  });

  testWidgets('the strip says why, when there is one reason', (tester) async {
    // "Unknown" over a tab of LAN servers is true and useless: it is the
    // ordinary state of an install with nothing on the public internet, and
    // it read as the globe having failed.
    addServer('lan', '192.168.1.10', name: 'nas');
    addServer('lo', '127.0.0.1', name: 'here');
    await show(tester, ['lan', 'lo']);
    expect(find.text('Private address'), findsOneWidget);
    expect(find.text('Unknown'), findsNothing);
  });

  testWidgets('an address no database covers says that instead', (
    tester,
  ) async {
    // Public, and in a bucket the vector leaves empty — so it reaches the end
    // of the chain rather than being turned back at the top of it.
    addServer('v6', '2400:cb00::1', name: 'cf');
    await show(tester, ['v6']);
    expect(find.text('No location data'), findsOneWidget);
  });

  /// The entry point that reaches anyone.
  ///
  /// `globeEnabled` is on by default, so the switch in settings is a decision
  /// most installs never make — and with nothing downloaded the globe places
  /// only hand-typed coordinates, which means for those installs the strip
  /// along the bottom *is* the globe. Offering the download there is what makes
  /// the feature reachable at all; these hold that it is offered exactly when
  /// it would help.
  ///
  /// **The fixtures go through `tester.runAsync`.** A `testWidgets` body runs
  /// in a fake-async zone, and a real file read started there completes on a
  /// callback that zone never pumps — so installing or removing the vectors
  /// inline simply never returns, which the runner reports as the test timing
  /// out with nothing naming the cause. `setUp` needs none of this: it is
  /// outside the zone.
  group('offering the download', () {
    testWidgets('when the data is not installed and something is unplaced', (
      tester,
    ) async {
      await tester.runAsync(removeGeoVectors);
      addServer('a', '8.8.8.8', name: 'washington');

      await show(tester, ['a']);

      expect(find.widgetWithText(ActionChip, 'washington'), findsOneWidget);
      expect(find.text(libL10n.download), findsOneWidget);
      // And says what the button downloads. "No location data" is true of this
      // app and reads as a fact about the server; beside a Download button with
      // the caption fallen back to "Unknown" it read as `Unknown  Download`,
      // which names nothing at all.
      expect(find.text('City-level data · Not downloaded'), findsOneWidget);
      expect(find.text('Unknown'), findsNothing);
    });

    testWidgets('and says so even with a LAN server in the strip too', (
      tester,
    ) async {
      // The case the fallback actually appeared in: two reasons at once, one
      // of which is the download's own absence. That one wins the caption,
      // because it is what the button beside it is about.
      await tester.runAsync(removeGeoVectors);
      addServer('a', '8.8.8.8', name: 'washington');
      addServer('lan', '192.168.1.10', name: 'nas');

      await show(tester, ['a', 'lan']);

      expect(find.text('City-level data · Not downloaded'), findsOneWidget);
      expect(find.text(libL10n.download), findsOneWidget);
      expect(find.text('Unknown'), findsNothing);
    });

    testWidgets('not when it is installed', (tester) async {
      // The strip still has something in it — a LAN server is not a reason to
      // propose 25 MB, because the data would not place it either.
      addServer('lan', '192.168.1.10', name: 'nas');

      await show(tester, ['lan']);

      expect(find.widgetWithText(ActionChip, 'nas'), findsOneWidget);
      expect(find.text(libL10n.download), findsNothing);
    });

    testWidgets('not for private-only servers when data is absent', (
      tester,
    ) async {
      await tester.runAsync(removeGeoVectors);
      addServer('lan', '192.168.1.10', name: 'nas');

      await show(tester, ['lan']);

      expect(find.widgetWithText(ActionChip, 'nas'), findsOneWidget);
      expect(find.text(libL10n.download), findsNothing);
    });

    testWidgets('not when there is no strip at all', (tester) async {
      addServer('a', '8.8.8.8', name: 'washington');

      await show(tester, ['a']);

      expect(find.text(libL10n.download), findsNothing);
    });

    testWidgets('and the globe places everything once the data lands', (
      tester,
    ) async {
      // The reason `_located` and `_unplaceable` are cleared rather than
      // topped up: every answer in them was reached against data that has just
      // changed, and a settled miss is never looked at again.
      await tester.runAsync(removeGeoVectors);
      addServer('a', '8.8.8.8', name: 'washington');
      await show(tester, ['a']);
      expect(find.widgetWithText(ActionChip, 'washington'), findsOneWidget);

      await tester.runAsync(installGeoVectors);
      await settle(tester);

      expect(find.widgetWithText(ActionChip, 'washington'), findsNothing);
      expect(find.text('washington'), findsOneWidget);
      expect(find.text(libL10n.download), findsNothing);
    });
  });

  testWidgets('two reasons at once names both', (tester) async {
    // It used to say "Unknown", on the grounds that naming one reason would be
    // wrong about the half of the strip that missed for the other. Naming both
    // is wrong about neither, and each chip carries the icon that says which of
    // them it is.
    addServer('lan', '192.168.1.10', name: 'nas');
    addServer('v6', '2400:cb00::1', name: 'cf');
    await show(tester, ['lan', 'v6']);
    expect(find.text('Private address · No location data'), findsOneWidget);
    expect(find.text('Unknown'), findsNothing);
  });

  /// A LAN server placed by what the machine says about itself.
  ///
  /// The gap the private gate leaves, and the reason a VPS reached over a VPN
  /// or by an internal name was in the strip alongside a genuine homelab box.
  ///
  /// Nothing here runs a command. `ip` is a key in the status manifest, so the
  /// addresses arrive with the ordinary poll — over SSH or from a monitor
  /// agent, identically — and these cases stand in for that poll landing.
  group('placing a machine by what it reports', () {
    Future<_Fixed> showReporting(
      WidgetTester tester,
      String id,
      List<String> ips,
    ) async {
      final status = InitStatus.status;
      status.ips = ips;
      final notifier = _Fixed(
        ServerState(
          spi: Stores.server.fetch().firstWhere((e) => e.id == id),
          status: status,
          conn: ServerConn.finished,
        ),
      );
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [serverProvider(id).overrideWith(() => notifier)],
          child: tree([id]),
        ),
      );
      await settle(tester);
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
      return notifier;
    }

    testWidgets('a public address it reports puts it on the globe', (
      tester,
    ) async {
      addServer('vps', '192.168.1.10', name: 'behind-vpn');
      await showReporting(tester, 'vps', ['192.168.1.10', '8.8.8.8']);
      expect(find.widgetWithText(ActionChip, 'behind-vpn'), findsNothing);
      expect(
        find.text('behind-vpn'),
        findsOneWidget,
        reason: 'a card on the globe, not a chip in the strip',
      );
      expect(
        Stores.selfAddr.addrOf('vps')?.address,
        '8.8.8.8',
        reason: 'recorded, so a later launch places it before it connects',
      );
    });

    testWidgets('only private addresses of its own keeps it in the strip', (
      tester,
    ) async {
      // A homelab box behind NAT. Nothing local can place it, and the answer
      // is recorded so it is not reconsidered on every pass.
      addServer('nas', '192.168.1.10', name: 'nas');
      await showReporting(tester, 'nas', ['127.0.0.1', '10.0.0.7']);
      expect(find.widgetWithText(ActionChip, 'nas'), findsOneWidget);
      expect(Stores.selfAddr.addrOf('nas'), isNull);
      expect(
        Stores.selfAddr.probedAt('nas'),
        isNotNull,
        reason: '"it has none" is an answer and is stored as one',
      );
    });

    testWidgets('a server that has reported nothing records nothing', (
      tester,
    ) async {
      // Not the same as having no address: the extended poll carrying them
      // lands well after the server is up, and a stored miss would settle the
      // question before the answer arrived.
      addServer('quiet', '192.168.1.10', name: 'quiet');
      await showReporting(tester, 'quiet', const []);
      expect(find.widgetWithText(ActionChip, 'quiet'), findsOneWidget);
      expect(Stores.selfAddr.probedAt('quiet'), isNull);
    });

    testWidgets('a public server is not placed by its own report', (
      tester,
    ) async {
      // It is already placed by the address the world sees it at, so there is
      // nothing to improve on.
      addServer('pub', '8.8.8.8', name: 'washington');
      await showReporting(tester, 'pub', ['1.0.0.1']);
      expect(Stores.selfAddr.probedAt('pub'), isNull);
      expect(find.text('washington'), findsOneWidget);
    });

    testWidgets('a report that lands afterwards is picked up', (tester) async {
      // The realistic path, and the only one the listener exists for: the
      // globe is opened long before the extended poll that carries addresses,
      // and a settled miss is never re-resolved.
      addServer('vps', '192.168.1.10', name: 'behind-vpn');
      final notifier = await showReporting(tester, 'vps', const []);
      expect(find.widgetWithText(ActionChip, 'behind-vpn'), findsOneWidget);

      notifier.report(['192.168.1.10', '8.8.8.8']);
      await settle(tester);
      expect(find.widgetWithText(ActionChip, 'behind-vpn'), findsNothing);
      expect(Stores.selfAddr.addrOf('vps')?.address, '8.8.8.8');
    });

    testWidgets('an answer already on hand is not reconsidered', (
      tester,
    ) async {
      // What a relaunch looks like: the store carries last week's answer, so
      // the globe draws the server from it and ignores a fresher report.
      addServer('vps', '192.168.1.10', name: 'behind-vpn');
      Stores.selfAddr.put('vps', InternetAddress('8.8.8.8'));
      final before = Stores.selfAddr.probedAt('vps');
      await showReporting(tester, 'vps', ['1.0.0.1']);
      expect(find.text('behind-vpn'), findsOneWidget);
      expect(Stores.selfAddr.addrOf('vps')?.address, '8.8.8.8');
      expect(Stores.selfAddr.probedAt('vps'), before);
    });
  });

  testWidgets('tapping a strip chip opens the editor, not the server', (
    tester,
  ) async {
    // The editor is where a coordinate is given by hand, and that is the only
    // thing to do about a server nothing could place.
    addServer('lan', '10.0.0.5', name: 'nas');
    await show(tester, ['lan']);
    await tester.tap(find.widgetWithText(ActionChip, 'nas'));
    await tester.pump();
    expect(edited?.id, 'lan');
    expect(tapped, isNull);
  });

  testWidgets('tapping a card opens the server', (tester) async {
    addServer('a', '8.8.8.8', name: 'washington');
    await show(tester, ['a']);
    await tester.tap(find.text('washington'));
    await tester.pump();
    expect(tapped?.id, 'a');
  });

  testWidgets('tapping the dot under a card opens it too', (tester) async {
    // The dot is painted rather than a widget, so this goes through the
    // globe's own hit test rather than through an `InkWell`.
    addServer('a', '8.8.8.8');
    await show(tester, ['a']);
    // A server at the camera's own coordinate is the middle of the disc, and
    // the globe opens facing the first placed server.
    await tester.tapAt(tester.getCenter(find.byType(GlobeView)));
    await tester.pump();
    expect(tapped?.id, 'a');
  });

  testWidgets('a manual coordinate places a server no lookup could', (
    tester,
  ) async {
    // The whole point of the field: a machine behind NAT is not in any
    // database, and this is what puts it on the globe anyway.
    addServer(
      'nat',
      '192.168.1.9',
      name: 'homelab',
      geo: GeoCoord.tryParse('51.5, -0.12'),
    );
    await show(tester, ['nat']);
    expect(find.text('homelab'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'homelab'), findsNothing);
  });

  testWidgets('a card says what the server is doing before it connects', (
    tester,
  ) async {
    addServer('a', '8.8.8.8', name: 'washington');
    await show(tester, ['a']);
    expect(find.text('disconnected'), findsOneWidget);
  });

  testWidgets('a connected server shows its two readings instead', (
    tester,
  ) async {
    // The whole reason a card is on the globe rather than a dot: which server
    // it is, and whether it is all right.
    addServer('a', '8.8.8.8', name: 'washington');
    final status = InitStatus.status;
    status.mem = const Memory(total: 1000, free: 250, avail: 250);
    tapped = null;
    edited = null;
    tester.view.physicalSize = const Size(500, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverProvider('a').overrideWith(
            () => _Fixed(
              ServerState(
                spi: Stores.server.fetch().first,
                status: status,
                conn: ServerConn.finished,
              ),
            ),
          ),
        ],
        child: tree(['a']),
      ),
    );
    await settle(tester);
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
    // 1 - 250/1000 is 75%. The CPU has had one sample, so it has no percentage
    // yet and falls back to zero rather than to nothing — a connected card
    // with a blank where a number goes reads as broken.
    expect(find.text('0% · 75%'), findsOneWidget);
  });

  testWidgets('several servers on one address are all placed', (tester) async {
    // Every one of them is looked up on its own now — there is no cache keyed
    // by host any more — and the point is that they all arrive. A lookup is a
    // few reads from a file this device already has open, so four of them is
    // not a cost worth a store to avoid.
    for (var i = 0; i < 4; i++) {
      addServer('s$i', '8.8.8.8', name: 'srv$i');
    }
    await show(tester, ['s0', 's1', 's2', 's3']);
    for (var i = 0; i < 4; i++) {
      expect(find.text('srv$i'), findsOneWidget);
    }
  });

  testWidgets('a server the list gains afterwards is resolved too', (
    tester,
  ) async {
    // `didUpdateWidget`. The list this is given changes when a tag filter or a
    // search moves, and a server that was filtered out has never been looked
    // up. Both exist in the store from the start — adding one to the *store*
    // mid-test would need the provider to reload, which is a different thing
    // from the one under test.
    // Both in the same country, so both are on the near side once the globe
    // has faced the first — a server on the far side has no card, correctly,
    // and this test is not about that.
    addServer('a', '8.8.8.8', name: 'first');
    addServer('b', '8.9.10.11', name: 'second');
    await show(tester, ['a']);
    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ServerGlobe(
              ids: const ['a', 'b'],
              onTapServer: (spi) => tapped = spi,
              onEditServer: (spi) => edited = spi,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('second'), findsOneWidget);
  });

  testWidgets('an id with no server behind it is skipped, not a crash', (
    tester,
  ) async {
    // The list and the provider are read at different moments, so a server
    // deleted in between is a real state.
    addServer('a', '8.8.8.8', name: 'here');
    await show(tester, ['a', 'gone']);
    expect(tester.takeException(), isNull);
    expect(find.text('here'), findsOneWidget);
  });

  testWidgets('no servers at all is still a globe', (tester) async {
    await show(tester, const []);
    expect(find.byType(GlobeView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the globe opens facing a server rather than the Atlantic', (
    tester,
  ) async {
    // `initialCoord` is the first *placed* server, so the thing at the top of
    // the list is what is in the middle of the disc — and therefore what a tap
    // in the middle hits.
    // `10.0.0.1` in the vector, which is Sydney — and is public as far as the
    // gate is concerned only because the vector says so, so `8.8.8.8` is used
    // instead. Any placed server does; the point is that it is centred.
    addServer('cn', '8.8.8.8', name: 'mountain-view');
    await show(tester, ['cn']);
    await tester.tapAt(tester.getCenter(find.byType(GlobeView)));
    await tester.pump();
    expect(tapped?.id, 'cn');
  });

  testWidgets('a server that could not be placed is not asked about twice', (
    tester,
  ) async {
    // Remembered, or a name that will not resolve is a DNS query per frame.
    addServer('lan', '192.168.1.10', name: 'nas');
    await show(tester, ['lan']);
    final first = find.widgetWithText(ActionChip, 'nas');
    expect(first, findsOneWidget);
    // Many more frames; the chip must neither disappear nor multiply.
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.widgetWithText(ActionChip, 'nas'), findsOneWidget);
  });

  /// What the globe reports about itself.
  ///
  /// Two things are held here, and the second is the reason this is a test
  /// rather than a code review: a crumb is written to be published, so where a
  /// server is must never reach one — and a summary that repeats itself is a
  /// request per frame to a server, since the pass behind it runs on every
  /// change to the list the globe is given.
  group('what is recorded', () {
    late _RecordingSink sink;

    setUp(() {
      sink = _RecordingSink();
      Diag.install(sink);
    });

    tearDown(Diag.uninstall);

    List<Breadcrumb> named(String message) =>
        sink.crumbs.where((c) => c.message == message).toList();

    Map<String, String>? placed() => named('placed').lastOrNull?.data;

    testWidgets('a server is counted under the source that placed it', (
      tester,
    ) async {
      addServer('a', '8.8.8.8', name: 'washington');
      await show(tester, ['a']);
      expect(placed(), {
        'servers': '1',
        'manual': '0',
        'selfReported': '0',
        'city': '1',
        'private': '0',
        'noData': '0',
      });
    });

    testWidgets('one nothing could place is counted under why', (tester) async {
      addServer('lan', '192.168.1.10', name: 'nas');
      addServer(
        'nat',
        '10.0.0.9',
        name: 'homelab',
        geo: GeoCoord.tryParse('51.5, -0.12'),
      );
      await show(tester, ['lan', 'nat']);
      expect(placed()?['private'], '1');
      expect(placed()?['manual'], '1');
      // Every source is counted, including the ones nothing placed — a key
      // that appears only when it is non-zero makes two passes incomparable.
      expect(placed()?['city'], '0');
    });

    testWidgets('the same answer is not reported again', (tester) async {
      // The pass runs on every rebuild of the list -- a tag filter, a search,
      // an address edited -- and reaches the same answer nearly every time.
      addServer('a', '8.8.8.8', name: 'washington');
      await show(tester, ['a']);
      expect(named('placed'), hasLength(1));

      await tester.pumpWidget(ProviderScope(child: tree(['a'])));
      await settle(tester);
      expect(named('placed'), hasLength(1));
    });

    testWidgets('opening a server says which of the two paths was pressed', (
      tester,
    ) async {
      // The card is an `InkWell` and the dot is hit-tested by hand, so they are
      // two ways to one place -- and past `labelLimit` the dot is the only one.
      addServer('a', '8.8.8.8', name: 'washington');
      await show(tester, ['a']);
      await tester.tap(find.text('washington'));
      await tester.pump();
      expect(named('open server').map((c) => c.data?['from']), ['card']);

      await tester.tapAt(tester.getCenter(find.byType(GlobeView)));
      await tester.pump();
      expect(named('open server').map((c) => c.data?['from']), ['card', 'dot']);
    });

    testWidgets('the strip chip carries the reason it is in the strip', (
      tester,
    ) async {
      addServer('lan', '10.0.0.5', name: 'nas');
      await show(tester, ['lan']);
      await tester.tap(find.widgetWithText(ActionChip, 'nas'));
      await tester.pump();
      expect(named('edit unplaced').single.data, {'miss': 'private'});
    });

    testWidgets('nothing carries where a server is or what it is called', (
      tester,
    ) async {
      addServer('a', '8.8.8.8', name: 'washington');
      addServer(
        'nat',
        '192.168.1.9',
        name: 'homelab',
        geo: GeoCoord.tryParse('51.5, -0.12'),
      );
      await show(tester, ['a', 'nat']);
      await tester.tap(find.text('washington'));
      await tester.pump();

      final written = [
        for (final crumb in sink.crumbs) ...[
          crumb.message,
          ...?crumb.data?.keys,
          ...?crumb.data?.values,
        ],
      ].join(' ');
      for (final secret in const [
        '8.8.8.8',
        '192.168',
        '51.5',
        'washington',
        'homelab',
      ]) {
        expect(written, isNot(contains(secret)), reason: 'a crumb is public');
      }
    });
  });
}

/// Remembers every crumb, so what the globe publishes can be asserted.
final class _RecordingSink extends DiagnosticsSink {
  final crumbs = <Breadcrumb>[];

  @override
  void breadcrumb(Breadcrumb crumb) => crumbs.add(crumb);
}

/// A server whose state is decided by the test rather than by a connection.
class _Fixed extends ServerNotifier {
  _Fixed(this._state);

  ServerState _state;

  @override
  ServerState build(String serverId) => _state;

  /// Reports [ips], as an extended poll landing would.
  ///
  /// Nothing is *run* on the server for this: `ip` is a key in the status
  /// manifest, so the addresses arrive with the poll — over SSH or from a
  /// monitor agent, identically. This fixture stands in for that arrival.
  ///
  /// A **fresh** `ServerStatus`, because that is what a real poll produces:
  /// `ServerNotifier.fetchStatus` is handed `_copyStatus(state.status)` and
  /// mutates that. Mutating the old state's own object instead would leave the
  /// watcher in `ServerGlobe` comparing the new list against itself — it
  /// selects `status.ips`, and Riverpod reads the previous value at
  /// notification time rather than keeping a snapshot.
  void report(List<String> ips) {
    final status = InitStatus.status;
    status.ips = ips;
    _state = ServerState(spi: _state.spi, status: status, conn: _state.conn);
    state = _state;
  }
}
