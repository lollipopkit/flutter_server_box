/// What the server editor writes to the server's PVE row on save: the pin it
/// never sets, and the PVE password only where its field is shown.
library;

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart' as app_locale;
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/pve_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/provider/private_key.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/server/edit/edit.dart';

import '../helpers/spi_fixture.dart';
import '../helpers/test_db.dart';

const _pin =
    '9c1185a5c5e9fc54612808977ee8f548b2258d31ddadef8e3b1e1b06a1a1e2b7';

void main() {
  setUp(() async {
    await openTestDb();
    if (!getIt.isRegistered<ServerStore>()) {
      getIt.registerSingleton<ServerStore>(ServerStore());
    }
    if (!getIt.isRegistered<PveStore>()) {
      getIt.registerSingleton<PveStore>(PveStore());
    }
    if (!getIt.isRegistered<PrivateKeyStore>()) {
      getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    }
    Stores.server.dropCache();
    Stores.key.dropCache();
    FlutterSecureStorage.setMockInitialValues({});
  });
  tearDown(closeTestDb);

  /// Opens the editor on [server], runs [whileOpen], and saves unless
  /// [save] is off.
  Future<void> editAndSave(
    WidgetTester tester,
    Spi server, {
    List<PrivateKeyInfo> keys = const [],
    void Function()? whileOpen,
    ServerEditSection? section,
    bool save = true,
  }) async {
    Stores.server.put(server);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serversProvider.overrideWith(() => _Servers(server)),
          privateKeyProvider.overrideWithValue(PrivateKeyState(keys: keys)),
        ],
        child: MaterialApp(
          builder: ResponsivePoints.builder,
          locale: const Locale('en'),
          localizationsDelegates: const [
            LibLocalizations.delegate,
            ...AppLocalizations.localizationsDelegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              app_locale.l10n = AppLocalizations.of(context)!;
              context.setLibL10n();
              // Pushed from the navigator it sits in, as the app's pages are.
              return Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const ValueKey('open'),
                    onPressed: () => ServerEditPage.route.go(
                      context,
                      args: ServerEditArgs(server, section: section),
                    ),
                    child: const Text('Open editor'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Opening on a group scrolls to it, after the first layout.
    if (section != null) {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    whileOpen?.call();
    if (!save) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      return;
    }

    await tester.tap(find.widgetWithText(FilledButton, libL10n.save));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('open')), findsOneWidget, reason: 'saved');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  testWidgets('opened for PVE: the group is open, on the local API', (
    tester,
  ) async {
    // What the Virtualization tab sends a server it found running PVE to.
    final server = spiFixture(name: 'pve', ip: '10.0.0.1', id: 'pve-id');
    await editAndSave(
      tester,
      server,
      section: ServerEditSection.pve,
      save: false,
      whileOpen: () {
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is TextField && w.controller?.text == PveConfig.localAddr,
          ),
          findsOneWidget,
        );
        expect(find.text(app_locale.l10n.pveTokenId), findsOneWidget);
      },
    );
    expect(Stores.pve.fetch(server.id), isNull);
  });

  testWidgets('a pin confirmed while the editor was open is kept', (
    tester,
  ) async {
    final server = spiFixture(
      name: 'pve',
      ip: '10.0.0.1',
      pwd: 'ssh-pw',
      id: 'pve-id',
    );
    const token = PveConfig(
      addr: 'https://127.0.0.1:8006',
      auth: PveAuth.token,
      tokenId: 'root@pam!sb',
      tokenSecret: 's',
    );
    Stores.server.put(server);
    Stores.pve.put(server.id, token);

    await editAndSave(
      tester,
      server,
      // The Virtualization tab confirming the certificate meanwhile. The
      // editor read the row without a pin, and saving that copy used to
      // write the confirmation away.
      whileOpen: () => Stores.pve.put(
        server.id,
        token.copyWith(certSha256: _pin),
      ),
    );

    expect(Stores.pve.fetch(server.id), token.copyWith(certSha256: _pin));
  });

  testWidgets('SSH with a password: a stored PVE password is not kept', (
    tester,
  ) async {
    // The field is hidden for this server, and a login sends the SSH
    // password — so text left in it is a second password nothing uses.
    final server = spiFixture(
      name: 'pve',
      ip: '10.0.0.1',
      pwd: 'ssh-pw',
      id: 'pve-id',
    );
    Stores.server.put(server);
    Stores.pve.put(
      server.id,
      const PveConfig(addr: 'https://127.0.0.1:8006', pwd: 'stale'),
    );

    await editAndSave(tester, server);

    expect(
      Stores.pve.fetch(server.id),
      const PveConfig(addr: 'https://127.0.0.1:8006'),
    );
  });

  testWidgets('SSH with a key: the PVE password is kept', (tester) async {
    const key = PrivateKeyInfo(id: 'k1', name: 'prod', key: 'unused');
    Stores.key.put(key);
    final server = spiFixture(
      name: 'pve',
      ip: '10.0.0.1',
      keyId: key.id,
      id: 'pve-id',
    );
    Stores.server.put(server);
    const cfg = PveConfig(addr: 'https://127.0.0.1:8006', pwd: 'pve-pw');
    Stores.pve.put(server.id, cfg);

    await editAndSave(tester, server, keys: const [key]);

    expect(Stores.pve.fetch(server.id), cfg);
  });
}

final class _Servers extends ServersNotifier {
  _Servers(this.initial);

  final Spi initial;

  @override
  ServersState build() => ServersState(
    servers: {initial.id: initial},
    serverOrder: [initial.id],
  );

  @override
  Future<void> updateServer(Spi old, Spi newSpi) async {
    final persisted = Spi.fromJson(
      jsonDecode(jsonEncode(newSpi)) as Map<String, dynamic>,
    );
    state = state.copyWith(servers: {persisted.id: persisted});
  }
}
