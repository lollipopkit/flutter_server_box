import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/route.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/detail/view.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

/// A card the user collapsed stays collapsed while the status keeps arriving.
///
/// The About card carries uptime, so every poll changes its content — and it
/// was keyed by that content (`ValueKey(more.hashCode)`), which built a new
/// tile each time and re-applied `initiallyExpanded`. The card sprang open
/// every few seconds and there was no way to keep it shut.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sid = 'srv-detail-1';
  final spi = spiFixture(
    id: sid,
    name: 'web',
    ip: 'h',
    user: 'u',
    autoConnect: false,
  );
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-detail-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    // Nothing here reaches for a socket: the page is fed its status directly.
    Stores.server.put(spi);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  /// A status with something for the About card to list.
  ServerStatus statusWith(String uptime) {
    final status = InitStatus.status;
    status.more[StatusCmdType.host] = 'test-host';
    status.more[StatusCmdType.sys] = 'Ubuntu 24.04';
    status.more[StatusCmdType.uptime] = uptime;
    return status;
  }

  testWidgets('a collapsed card stays collapsed across a status refresh', (
    tester,
  ) async {
    // Wide enough for `_getInitExpand` to answer yes whatever the collapse
    // setting says, so the card starts open and there is something to close.
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
          home: ServerDetailPage(args: SpiRequiredArgs(spi)),
        ),
      ),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ServerDetailPage)),
    );
    final notifier = container.read(serverProvider(sid).notifier);

    notifier.updateStatus(statusWith('1 day'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The card is open: its rows are in the tree.
    expect(find.text('test-host'), findsOneWidget);

    final header = find
        .ancestor(
          of: find.text('test-host'),
          matching: find.byType(ExpandTile),
        )
        .first;
    await tester.tap(
      find.descendant(of: header, matching: find.byType(ListTile)).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('test-host'), findsNothing);

    // A poll arrives, and with it a different uptime — a different `more`.
    notifier.updateStatus(statusWith('1 day, 0:01'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('test-host'),
      findsNothing,
      reason: 'the refresh re-expanded the card the user collapsed',
    );
  });
}
