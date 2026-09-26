import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/data/ssh/terminal_source.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/ssh/page/page.dart';

import '../helpers/fake_shell.dart';
import '../helpers/spi_fixture.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-term-deleted-');
    Paths.doc = tempDir.path;
  });

  tearDownAll(() => tempDir.delete(recursive: true));

  setUp(() async {
    SqliteDb.openInMemory();
    await Stores.init();
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  testWidgets('a tab for a server deleted since still opens', (tester) async {
    // The route carries a snapshot of the server. Restored after the server
    // was deleted — here or by a sync — the page asked a provider whose first
    // build throws "not found" (SERVERBOX-D).
    final gone = spiFixture(id: 'deleted', name: 'gone', ip: 'h', user: 'u');
    expect(Stores.server.fetchOneRaw(gone.id), isNull);

    final session = TerminalSession(
      source: ServerSource(gone),
      backend: FakeShellBackend(),
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SSHPage(
            args: SshPageArgs(source: ServerSource(gone), session: session),
          ),
        ),
      ),
    );
    // Counted out: a terminal always has something scheduled.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(SSHPage), findsOneWidget);
  });
}
