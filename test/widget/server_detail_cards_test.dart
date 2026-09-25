/// The cards under the metric rows: one conclusion, a few lines of detail,
/// and a last line saying what is not on screen.
///
/// The shape matters more than any one card. A host with eight drives must not
/// get a card that lists six of them and says nothing about the other two —
/// that reads as a host with six drives — and the verdict has to be readable
/// without opening anything, which is what the chip is for.
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/app/session_requests.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/detail/view.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-cards';
  final spi = spiFixture(
    id: sid,
    name: 'web',
    ip: 'h',
    user: 'u',
    autoConnect: false,
  );

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PveStore>(PveStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    Stores.server.put(spi);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  DiskSmart drive(
    String device, {
    bool? healthy,
    double? temperature,
    int? reallocated,
  }) => DiskSmart(
    device: device,
    healthy: healthy,
    temperature: temperature,
    rawData: const {},
    smartAttributes: {
      if (reallocated != null)
        'Reallocated_Sector_Ct': SmartAttribute(
          name: 'Reallocated_Sector_Ct',
          rawValue: reallocated,
          flags: const SmartAttributeFlags(),
        ),
    },
  );

  /// Eight drives, one of them failing and none of them the hottest by
  /// accident: `sdh` is both the failure and the coolest, so a card that led
  /// with the wrong one would be visible. `sdb` passes SMART's own verdict
  /// while reporting reallocated sectors, which is the drive SMART calls fine
  /// and a person does not.
  ServerStatus statusOf() {
    final status = InitStatus.status;
    status.more[StatusCmdType.host] = 'test-host';
    status.diskSmart = [
      for (var i = 0; i < 7; i++)
        if (i == 1)
          drive('sdb', healthy: true, temperature: 44, reallocated: 2)
        else
          drive('sd${String.fromCharCode(97 + i)}', healthy: true,
              temperature: 30 + i.toDouble()),
      drive('sdh', healthy: false, temperature: 22),
    ];
    return status;
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 900);
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
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              return ServerDetailPage(args: SpiRequiredArgs(spi));
            },
          ),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerDetailPage)),
    );
    container.read(serverProvider(sid).notifier).updateStatus(statusOf());
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a card leads with its verdict and says what it left out', (
    tester,
  ) async {
    await pump(tester);

    expect(tester.takeException(), isNull);
    // The verdict, without opening anything.
    expect(find.text(app_locale.l10n.diskFailingFmt(1)), findsOneWidget);
    // The headline is the worst conclusion — how many drives are not fine and
    // which one is the worst — not a count of drives.
    expect(
      find.text(app_locale.l10n.diskWrongOfFmt(8, 2)),
      findsOneWidget,
      reason: 'the failing drive and the one with reallocated sectors',
    );
    // Spelled out as well as composed: gen-l10n orders placeholders
    // alphabetically, so a sentence reading "8 of 2 devices" is what getting
    // that order wrong looks like, and the line above would agree with it.
    expect(find.textContaining('2 of 8'), findsOneWidget);
    expect(find.textContaining('sdh · FAILING'), findsOneWidget);
    // And the footer, which is what keeps six rows from reading as six drives.
    expect(
      find.textContaining(
        app_locale.l10n.shownOfFmt(6, 8, app_locale.l10n.unitDevices),
      ),
      findsOneWidget,
    );
  });

  /// SMART's own verdict stays PASSED until a drive is nearly gone, so a card
  /// that only reads `healthy` calls a drive with reallocated sectors fine.
  testWidgets('a drive that passes but reports reallocated sectors is a row '
      'with its count', (tester) async {
    await pump(tester);

    expect(find.textContaining('2 reallocated · 44°C'), findsOneWidget);
  });

  testWidgets('a row opens the drive\'s attributes, and says where they came '
      'from', (tester) async {
    await pump(tester);

    await tester.tap(find.text('sdb'));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(
      find.text('sdb · ${app_locale.l10n.attributes}'),
      findsOneWidget,
    );
    expect(find.text('Reallocated sectors'), findsOneWidget);
    expect(find.text('smartctl -A /dev/sdb'), findsOneWidget);
  });

  /// Two cards fit side by side where there is room for two readable columns,
  /// and the readings line up on the card's edge rather than wherever the name
  /// beside them happened to end.
  testWidgets('cards share the width, and their readings are flush right', (
    tester,
  ) async {
    await pump(tester);

    final card = find.ancestor(
      of: find.text(app_locale.l10n.diskHealth),
      matching: find.byType(CardX),
    );
    final cardBox = tester.getRect(card.first);
    // Half the readings column, not all of it: the page is 1200 wide and the
    // facts take their own column beside it.
    expect(cardBox.width, lessThan(500));

    // Two readings of different lengths, against each other rather than
    // against an arithmetic of paddings: flush right means they end in the
    // same place, and the layout this replaced ended each one wherever its own
    // text ran out.
    double rightOf(String text) => tester
        .getRect(find.descendant(of: card, matching: find.text(text)).first)
        .right;

    expect(
      rightOf('FAILING · 22°C'),
      closeTo(rightOf('PASSED · 30°C'), 0.5),
      reason: 'the readings stopped short of the edge they line up on',
    );
  });

  testWidgets('the worst drive is the first row, and only six are listed', (
    tester,
  ) async {
    await pump(tester);

    // Failing first, whatever order the host reported them in. The name on
    // its own is a row; the headline's hottest drive carries its reading too.
    final name = RegExp(r'^sd[a-z]$');
    final rows = tester
        .widgetList<Text>(find.byType(Text))
        .map((e) => e.data)
        .whereType<String>()
        .where(name.hasMatch)
        .toList();
    expect(rows.first, 'sdh');
    expect(rows, hasLength(6));
  });

  /// The PVE page is gone; its card is the way to the same server on the
  /// Virtualization tab.
  testWidgets('the PVE card asks for the Virtualization tab, on this host', (
    tester,
  ) async {
    Stores.pve.put(sid, const PveConfig(addr: 'https://localhost:8006'));
    await pump(tester);

    final card = find.text('PVE');
    await tester.ensureVisible(card);
    await tester.pump();
    await tester.tap(card);
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerDetailPage)),
    );
    expect(container.read(homeTabRequestProvider), AppTab.virt);
    expect(container.read(virtHostRequestProvider), sid);
  });
}
