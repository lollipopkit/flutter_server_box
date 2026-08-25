import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-selection-reload-');
    Paths.doc = tempDir.path;
  });

  tearDownAll(() async => tempDir.delete(recursive: true));

  setUp(() async {
    SqliteDb.openInMemory();
    await Stores.init();
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  test('reload clears a selection whose server no longer exists', () async {
    const server = Spi(
      id: 'selected-server',
      name: 'selected',
      ssh: SshCredential(ip: '10.0.0.1'),
    );
    Stores.server.put(server);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(serversProvider);
    container.read(serverSelectionProvider.notifier).select(server.id);

    Stores.server.deleteById(server.id);
    await container.read(serversProvider.notifier).reload();

    expect(container.read(serverSelectionProvider), isNull);
  });

  test(
    'reload updates an existing child provider without reconnecting',
    () async {
      const original = Spi(
        id: 'updated-server',
        name: 'before',
        ssh: SshCredential(ip: '10.0.0.1', keyId: 'deleted-key'),
      );
      const updated = Spi(
        id: 'updated-server',
        name: 'after',
        ssh: SshCredential(ip: '10.0.0.1'),
      );
      Stores.server.put(original);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(serversProvider);
      expect(container.read(serverProvider(original.id)).spi, original);

      Stores.server.put(updated);
      await container
          .read(serversProvider.notifier)
          .reload(refreshConnections: false);

      expect(container.read(serverProvider(original.id)).spi, updated);
      expect(
        container.read(serverProvider(original.id)).conn,
        ServerConn.disconnected,
      );
    },
  );

  test('a stale edit cannot overwrite a newer server value', () async {
    const original = Spi(
      id: 'stale-edit-server',
      name: 'original',
      ssh: SshCredential(ip: '10.0.0.1'),
    );
    const newer = Spi(
      id: 'stale-edit-server',
      name: 'newer',
      ssh: SshCredential(ip: '10.0.0.1'),
    );
    const stale = Spi(
      id: 'stale-edit-server',
      name: 'stale',
      ssh: SshCredential(ip: '10.0.0.1'),
    );
    Stores.server.put(original);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(serversProvider.notifier);

    await notifier.updateServer(original, newer);
    await expectLater(
      notifier.updateServer(original, stale),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(contains(libL10n.server), contains(libL10n.retry)),
        ),
      ),
    );

    expect(container.read(serversProvider).servers[original.id], newer);
    expect(Stores.server.fetchOneRaw(original.id), newer);
  });
}
