import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/selection.dart';
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
}
