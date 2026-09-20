import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/provider/server/all.dart';
import 'package:server_box/data/provider/server/single.dart';
import 'package:server_box/data/res/store.dart';

/// A server removed while its notifier was alive must not error the provider.
///
/// `serverProvider` is `keepAlive`, so deleting a server does not dispose its
/// element: `ref.invalidate` runs the notifier's dispose listeners and then
/// schedules a refresh. Riverpod refreshes an *active* element, so with the
/// server's editor still on screen — the page the delete button sits on —
/// `build` ran again after the record was gone, threw `Server ... not found`,
/// and left the provider in an error state. In the app that surfaced as
/// `Unhandled (FlutterError)` in the crash log, twice per delete; and the SSH
/// client was never closed, because the state read the close sat behind is
/// what threw.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-delete-live-');
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

  /// Lets the end-of-event-loop refresh Riverpod scheduled for the invalidated
  /// element run, while the listener below is still attached.
  Future<void> settle() {
    return Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('deleting a watched server does not error its provider', () async {
    const doomed = Spi(
      id: 'doomed-server',
      name: 'doomed',
      ssh: SshCredential(ip: '10.0.0.1'),
    );
    Stores.server.put(doomed);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(serversProvider);
    final sub = container.listen(serverProvider(doomed.id), (_, _) {});
    addTearDown(sub.close);

    await container.read(serversProvider.notifier).delServer(doomed.id);
    await settle();

    expect(
      () => container.read(serverProvider(doomed.id)),
      returnsNormally,
      reason: 'the deleted server\'s notifier must not end up in error state',
    );
  });

  test('a record dropped by a sync pull does not error its provider', () async {
    const pulled = Spi(
      id: 'pulled-server',
      name: 'pulled',
      ssh: SshCredential(ip: '10.0.0.2'),
    );
    Stores.server.put(pulled);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(serversProvider);
    final sub = container.listen(serverProvider(pulled.id), (_, _) {});
    addTearDown(sub.close);

    // What `reload` sees after a pull that removed the record.
    Stores.server.deleteById(pulled.id);
    await container.read(serversProvider.notifier).reload();
    await settle();

    expect(
      () => container.read(serverProvider(pulled.id)),
      returnsNormally,
      reason: 'a removed record must not leave its provider in error state',
    );
  });
}
