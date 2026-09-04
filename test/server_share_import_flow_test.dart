/// The glue between the dialogs and the store.
///
/// `ServerShareCodec` and `ServerShareInstaller` are covered on their own in
/// `server_share_test.dart`; what is only reachable through a widget tree is
/// the part between them — that the passphrase typed into the field is the one
/// the payload is decrypted with, that a refusal leaves the store alone, and
/// that confirming actually writes the server and the key it arrived with.
///
/// `tester.runAsync` throughout the decrypt: `decodeAsync` hands the key
/// derivation to `compute`, and a real isolate does not complete inside the
/// fake-async zone a `testWidgets` body runs in. `pumpAndSettle` is avoided for
/// the reason the repo notes elsewhere — the passphrase field always has
/// something scheduled, so it would run to its ten-minute timeout.
@Timeout(Duration(minutes: 3))
library;

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/server_share.dart';
import 'package:server_box/data/model/app/share/server_share.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/widget/server_share.dart';

import 'helpers/test_db.dart';

const _pwd = 'a-passphrase';
const _keyMaterial = '-----BEGIN OPENSSH PRIVATE KEY-----\nshared\n-----END-----';

/// A payload as a sender's device would produce one, key included.
String _payload() => ServerShareCodec.encode(
  ServerShare(
    version: ServerShare.formatVer,
    spi: const Spi(
      id: 'shared1',
      name: 'shared-server',
      ssh: SshCredential(
        ip: '10.9.9.9',
        port: 22,
        user: 'root',
        pwd: 'hunter2',
        keyId: 'k1',
      ),
    ),
    keys: const [
      PrivateKeyInfo(id: 'k1', name: 'their-key', key: _keyMaterial),
    ],
  ),
  _pwd,
  // The cheaper of the two costs. Which carrier the payload came from is not
  // what this is about, and 600k rounds per case is a minute of test time.
  ShareCarrier.file,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    if (!getIt.isRegistered<ServerStore>()) {
      getIt.registerSingleton<ServerStore>(ServerStore());
    }
    if (!getIt.isRegistered<PrivateKeyStore>()) {
      getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    }
    if (!getIt.isRegistered<SettingStore>()) {
      getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    }
    Stores.server.dropCache();
    Stores.key.dropCache();
  });

  tearDown(closeTestDb);

  /// A page that hands [text] to the importer, on its own navigator — which is
  /// what every real caller is, and what makes the dialogs' `popDialog` reach
  /// the root navigator rather than this page.
  Future<void> open(WidgetTester tester, String text) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (ctx, ref, _) => TextButton(
                onPressed: () =>
                    ServerShareUi.consume(ctx, ref, text, digitsOnly: false),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Runs the pending isolate work and lets the tree catch up.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(seconds: 2));
    });
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('the passphrase typed in is the one it decrypts with', (
    tester,
  ) async {
    await open(tester, _payload());

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), _pwd);
    await tester.pump();

    await tester.tap(find.text(libL10n.ok).last);
    await settle(tester);

    // The preview, before anything is written.
    expect(find.text('shared-server'), findsOneWidget);
    expect(find.text('root@10.9.9.9:22'), findsOneWidget);
    expect(find.text(l10n.shareIncludesKey), findsOneWidget);
    expect(Stores.server.fetch(), isEmpty, reason: 'nothing written yet');

    await tester.tap(find.text(libL10n.ok).last);
    await settle(tester);

    final servers = Stores.server.fetch();
    expect(servers, hasLength(1));
    expect(servers.single.name, 'shared-server');
    expect(servers.single.ssh?.pwd, 'hunter2');

    // The key travelled with it, and the server points at where it landed.
    final keyId = servers.single.ssh?.keyId;
    expect(keyId, isNotNull);
    expect(Stores.key.fetchOne(keyId)?.key, _keyMaterial);
  });

  testWidgets('declining the preview writes nothing', (tester) async {
    await open(tester, _payload());
    await tester.enterText(find.byType(TextField), _pwd);
    await tester.pump();
    await tester.tap(find.text(libL10n.ok).last);
    await settle(tester);

    expect(find.text('shared-server'), findsOneWidget);
    await tester.tap(find.text(libL10n.cancel).last);
    await settle(tester);

    expect(Stores.server.fetch(), isEmpty);
    expect(Stores.key.fetch(), isEmpty, reason: 'nor the key it carried');
  });

  testWidgets('a wrong passphrase writes nothing and does not preview', (
    tester,
  ) async {
    await open(tester, _payload());
    await tester.enterText(find.byType(TextField), 'not-it');
    await tester.pump();
    await tester.tap(find.text(libL10n.ok).last);
    await settle(tester);

    expect(find.text('shared-server'), findsNothing);
    expect(Stores.server.fetch(), isEmpty);
  });

  testWidgets('cancelling the passphrase asks for nothing else', (
    tester,
  ) async {
    await open(tester, _payload());
    await tester.tap(find.text(libL10n.cancel).last);
    await settle(tester);

    expect(find.text('shared-server'), findsNothing);
    expect(Stores.server.fetch(), isEmpty);
  });
}
