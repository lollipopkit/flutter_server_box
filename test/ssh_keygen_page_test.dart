import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:fl_lib/generated/l10n/lib_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ssh_keygen.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/private_key/generate.dart';

import 'helpers/test_db.dart';

/// The algorithm list is closed to begin with.
///
/// There is a right answer for almost everyone and it is the default, so the
/// four choices are something to open when a server refuses that one — not
/// four rows of key algorithms between the name field and everything else.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-keygen-page-');
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore.forTest());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore.forTest());
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
    await tempDir.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 900);
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
          home: const PrivateKeyGeneratePage(),
        ),
      ),
    );
    // Counted out rather than settled: the name field autofocuses, and
    // `pumpAndSettle` on a tree with a text field in it waits its full ten
    // minutes before giving up.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));
  }

  testWidgets('the choices are closed, and the default is named', (
    tester,
  ) async {
    await pump(tester);

    // The tile says what it is set to without being opened.
    expect(find.text('Ed25519'), findsOneWidget);
    // And the rest are not in the tree at all.
    expect(find.text('RSA 4096'), findsNothing);
    expect(find.text('ECDSA (P-256)'), findsNothing);
    expect(find.byType(RadioListTile<SshKeyAlgorithm>), findsNothing);
  });

  testWidgets('opening it shows every algorithm', (tester) async {
    await pump(tester);

    await tester.tap(find.text(AppLocalizations.of(tester.element(
      find.byType(PrivateKeyGeneratePage),
    ))!.sshKeyAlgorithm));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('RSA 2048'), findsOneWidget);
    expect(find.text('RSA 4096'), findsOneWidget);
    expect(find.text('ECDSA (P-256)'), findsOneWidget);
    // Twice now: once as the tile's subtitle, once as a choice.
    expect(find.text('Ed25519'), findsNWidgets(2));
  });

  testWidgets('choosing one closes it again and updates the subtitle', (
    tester,
  ) async {
    await pump(tester);
    final title = AppLocalizations.of(
      tester.element(find.byType(PrivateKeyGeneratePage)),
    )!.sshKeyAlgorithm;

    await tester.tap(find.text(title));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('RSA 4096'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Closed, so the one left is the tile's own subtitle — the choice was
    // made and the list has nothing more to say.
    expect(find.text('RSA 4096'), findsOneWidget);
    expect(find.text('Ed25519'), findsNothing);
    expect(find.byType(RadioListTile<SshKeyAlgorithm>), findsNothing);
  });
}
