import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/server/bmc_credential.dart';
import 'package:server_box/data/model/server/bmc_target.dart';
import 'package:server_box/data/provider/bmc/selection.dart';
import 'package:server_box/data/provider/bmc/targets.dart';
import 'package:server_box/data/provider/server/selection.dart';
import 'package:server_box/data/store/bmc_credential.dart';
import 'package:server_box/data/store/bmc_target.dart';
import 'package:server_box/data/store/container.dart';
import 'package:server_box/data/store/history.dart';
import 'package:server_box/data/store/port_forward.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/pve.dart';
import 'package:server_box/data/store/remote_desktop.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/snippet.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_records.dart';

import '../../helpers/spi_fixture.dart';
import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<HistoryStore>(HistoryStore('history_test'));
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    getIt.registerSingleton<BmcCredentialStore>(BmcCredentialStore());
    getIt.registerSingleton<BmcTargetStore>(BmcTargetStore());
    getIt.registerSingleton<ServerStore>(
      ServerStore(bmcTargets: Stores.bmcTarget),
    );
    getIt.registerSingleton<PveStore>(PveStore());
    getIt.registerSingleton<ContainerStore>(ContainerStore());
    getIt.registerSingleton<SnippetStore>(SnippetStore());
    getIt.registerSingleton<PortForwardStore>(PortForwardStore());
    getIt.registerSingleton<RemoteDesktopStore>(RemoteDesktopStore());
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  test('CRUD, tags, renameTag, and forServer round-trip', () {
    const cred = BmcCredential(id: 'c1', name: 'rack', user: 'root', pwd: 'pw');
    Stores.bmcCredential.put(cred);
    final srv = spiFixture(id: 's1', name: 'host-a', ip: '10.0.0.1');
    Stores.server.put(srv);

    const linked = BmcTarget(
      id: 'b1',
      name: 'host-a-bmc',
      addr: 'https://10.0.0.11',
      credId: 'c1',
      certSha256: 'deadbeef',
      serverId: 's1',
      tags: ['prod', 'rack-1'],
    );
    const standalone = BmcTarget(
      id: 'b2',
      name: 'storage-bmc',
      addr: 'https://10.0.0.12',
      credId: 'c1',
      tags: ['prod'],
    );
    Stores.bmcTarget.put(linked);
    Stores.bmcTarget.put(standalone);

    expect(Stores.bmcTarget.forServer('s1'), linked);
    expect(Stores.bmcTarget.forServer('missing'), isNull);
    expect(Stores.bmcTarget.allTags(), ['prod', 'rack-1']);

    Stores.bmcTarget.renameTag('prod', 'production');
    expect(Stores.bmcTarget.allTags(), ['production', 'rack-1']);
    expect(
      Stores.bmcTarget.fetchOne('b1')?.tags,
      unorderedEquals(['production', 'rack-1']),
    );
    expect(Stores.bmcTarget.fetchOne('b2')?.tags, ['production']);
  });

  test('writeLinks binds FKs when parent records arrive later in sync', () {
    const pending = BmcTarget(
      id: 'b-late',
      name: 'late',
      addr: 'https://10.0.0.50',
      credId: 'c-late',
      serverId: 's-late',
    );
    Stores.bmcTarget.put(pending);
    // Parents do not exist yet, so FKs start NULL without violating constraints.
    final before = Stores.bmcTarget.fetchOne('b-late')!;
    expect(before.credId, isNull);
    expect(before.serverId, isNull);

    Stores.bmcCredential.put(
      const BmcCredential(id: 'c-late', name: 'late-cred', user: 'u', pwd: 'p'),
    );
    Stores.server.put(spiFixture(id: 's-late', name: 'late-srv', ip: '10.0.0.5'));

    Stores.bmcTarget.writeLinks(pending);
    Stores.bmcTarget.invalidate();
    final after = Stores.bmcTarget.fetchOne('b-late')!;
    expect(after.credId, 'c-late');
    expect(after.serverId, 's-late');
  });

  test('deleting a server unlinks its BMC target instead of deleting it', () {
    Stores.server.put(spiFixture(id: 's1', name: 'web', ip: '10.0.0.1'));
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'b1',
        name: 'web-bmc',
        addr: 'https://10.0.0.11',
        serverId: 's1',
      ),
    );

    Stores.server.deleteById('s1');

    final bmc = Stores.bmcTarget.fetchOne('b1');
    expect(bmc, isNotNull);
    expect(bmc!.serverId, isNull);
  });

  test('renaming a server keeps its BMC target linked', () {
    final oldSrv = spiFixture(id: 'old-id', name: 'web', ip: '10.0.0.1');
    final newSrv = oldSrv.copyWith(id: 'new-id');
    Stores.server.put(oldSrv);
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'b1',
        name: 'web-bmc',
        addr: 'https://10.0.0.11',
        serverId: 'old-id',
      ),
    );

    Stores.server.rename(oldSrv, newSrv);

    expect(Stores.bmcTarget.forServer('old-id'), isNull);
    expect(Stores.bmcTarget.forServer('new-id')?.id, 'b1');
  });

  test('linking a second BMC target to a server unlinks the previous one', () {
    Stores.server.put(spiFixture(id: 's1', name: 'web', ip: '10.0.0.1'));
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'b1',
        name: 'bmc-old',
        addr: 'https://10.0.0.11',
        serverId: 's1',
      ),
    );
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'b2',
        name: 'bmc-new',
        addr: 'https://10.0.0.12',
        serverId: 's1',
      ),
    );

    expect(Stores.bmcTarget.forServer('s1')?.id, 'b2');
    expect(Stores.bmcTarget.fetchOne('b1')?.serverId, isNull);
  });

  test('BackupV2 restores v44 bmcTargets and promotes legacy <= v43 Spi.bmc', () async {
    final cred = const BmcCredential(
      id: 'cred-1',
      name: 'bmc-admin',
      user: 'admin',
      pwd: 'pw',
    );
    final srv = spiFixture(id: 's-legacy', name: 'legacy-host', ip: '10.0.0.9');
    final spiJson =
        (json.decode(json.encode(srv.toJson())) as Map<String, dynamic>)
          ..['bmc'] = {
            'addr': 'https://10.0.0.99',
            'credId': cred.id,
            'certSha256': 'abcd',
          };

    final legacyBackup = BackupV2(
      version: 43,
      date: DateTime.now().millisecondsSinceEpoch,
      spis: {'s-legacy': spiJson},
      snippets: const {},
      keys: const {},
      bmcCredentials: {cred.id: cred.toJson()},
      container: const {},
      history: const {},
      settings: const {},
    );

    await legacyBackup.restoreStores(force: true);

    final promoted = Stores.bmcTarget.forServer('s-legacy');
    expect(promoted, isNotNull);
    expect(promoted!.addr, 'https://10.0.0.99');
    expect(promoted.credId, cred.id);
    expect(promoted.certSha256, 'abcd');

    // Now test v44 backup with standalone BMC target.
    const standalone = BmcTarget(
      id: 'bmc-standalone',
      name: 'oob-rack',
      addr: 'https://10.0.0.88',
      credId: 'cred-1',
      tags: ['rack-2'],
    );
    final v44Backup = BackupV2(
      version: BackupV2.formatVer,
      date: DateTime.now().millisecondsSinceEpoch,
      spis: const {},
      snippets: const {},
      keys: const {},
      bmcCredentials: {cred.id: cred.toJson()},
      bmcTargets: {standalone.id: standalone.toJson()},
      container: const {},
      history: const {},
      settings: const {},
    );

    await v44Backup.restoreStores(force: true);

    final restoredStandalone = Stores.bmcTarget.fetchOne('bmc-standalone');
    expect(restoredStandalone, standalone);
  });

  test('forced <= v43 restore clears removed linked BMC, keeps standalone, and reuses existing linked id', () async {
    const cred = BmcCredential(id: 'cred-1', name: 'bmc', user: 'root', pwd: 'pw');
    Stores.bmcCredential.put(cred);
    final srv = spiFixture(id: 's1', name: 'host-1', ip: '10.0.0.1');
    Stores.server.put(srv);
    // Existing local linked BMC with a non-`bmc_s1` id + a standalone BMC.
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'custom-linked-id',
        name: 'host-1-bmc',
        addr: 'https://10.0.0.50',
        credId: 'cred-1',
        serverId: 's1',
      ),
    );
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'solo-1',
        name: 'solo-bmc',
        addr: 'https://10.0.0.51',
        credId: 'cred-1',
      ),
    );

    // 1) Legacy backup WITH spi.bmc must update the existing linked row without
    //    violating the unique `server_id` index.
    final withBmc =
        (json.decode(json.encode(srv.toJson())) as Map<String, dynamic>)
          ..['bmc'] = {'addr': 'https://10.0.0.60', 'credId': cred.id};
    await BackupV2(
      version: 43,
      date: DateTime.now().millisecondsSinceEpoch,
      spis: {'s1': withBmc},
      snippets: const {},
      keys: const {},
      bmcCredentials: {cred.id: cred.toJson()},
      container: const {},
      history: const {},
      settings: const {},
    ).restoreStores(force: true);

    expect(Stores.bmcTarget.forServer('s1')?.id, 'custom-linked-id');
    expect(Stores.bmcTarget.forServer('s1')?.addr, 'https://10.0.0.60');
    expect(Stores.bmcTarget.fetchOne('solo-1'), isNotNull);

    // 2) Legacy backup WITHOUT spi.bmc on force restore clears the linked BMC
    //    but keeps the standalone BMC.
    final withoutBmc =
        json.decode(json.encode(srv.toJson())) as Map<String, dynamic>;
    await BackupV2(
      version: 43,
      date: DateTime.now().millisecondsSinceEpoch,
      spis: {'s1': withoutBmc},
      snippets: const {},
      keys: const {},
      bmcCredentials: {cred.id: cred.toJson()},
      container: const {},
      history: const {},
      settings: const {},
    ).restoreStores(force: true);

    expect(Stores.bmcTarget.forServer('s1'), isNull);
    expect(Stores.bmcTarget.fetchOne('solo-1'), isNotNull);
  });

  test('EntityStore.merge server deletion stamps linked bmc_target for sync', () {
    Stores.server.put(spiFixture(id: 's1', name: 'web', ip: '10.0.0.1'));
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'b1',
        name: 'web-bmc',
        addr: 'https://10.0.0.11',
        serverId: 's1',
      ),
    );
    final beforeTs = Stores.bmcTarget.synced.lastModTime;
    final deleteAt = beforeTs + 10000;

    final changed = Stores.server.merge(
      {
        StoreDefaults.defaultLastUpdateTsKey: {'s1': deleteAt},
      },
      force: false,
    );
    expect(changed, isTrue);
    Stores.bmcTarget.invalidate();
    expect(Stores.bmcTarget.fetchOne('b1')?.serverId, isNull);
    expect(Stores.bmcTarget.synced.lastModTime, deleteAt);
  });

  test('EntityStore.merge server tombstone does not lower newer bmc_target updated_at', () {
    Stores.server.put(spiFixture(id: 's1', name: 'web', ip: '10.0.0.1'));
    Stores.bmcTarget.put(
      const BmcTarget(
        id: 'b1',
        name: 'web-bmc',
        addr: 'https://10.0.0.11',
        serverId: 's1',
      ),
    );
    final newerBmcTs = Stores.bmcTarget.synced.lastModTime + 50000;
    Stores.bmcTarget.synced.stamp('b1', at: newerBmcTs);
    final olderDeleteAt = newerBmcTs - 10000;

    final changed = Stores.server.merge(
      {
        StoreDefaults.defaultLastUpdateTsKey: {'s1': olderDeleteAt},
      },
      force: false,
    );
    expect(changed, isTrue);
    Stores.bmcTarget.invalidate();
    expect(Stores.bmcTarget.fetchOne('b1')?.serverId, isNull);
    expect(Stores.bmcTarget.synced.lastModTime, newerBmcTs);
  });

  test('BmcTargetsNotifier & BmcSelection handle CRUD, tags, cert pin, mutual exclusion, and selection cleanup', () {
    Stores.bmcCredential.put(
      const BmcCredential(id: 'c1', name: 'rack', user: 'root', pwd: 'pw'),
    );
    Stores.server.put(spiFixture(id: 's1', name: 'srv', ip: '10.0.0.1'));

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(bmcTargetsProvider.notifier);
    final selection = container.read(bmcSelectionProvider.notifier);
    final srvSelection = container.read(serverSelectionProvider.notifier);

    const t1 = BmcTarget(
      id: 'b1',
      name: 'bmc-1',
      addr: 'https://10.0.0.11',
      credId: 'c1',
      tags: ['rack-a'],
    );
    notifier.add(t1);
    expect(container.read(bmcTargetsProvider).targets['b1'], t1);

    selection.select('b1');
    expect(container.read(bmcSelectionProvider), 'b1');

    // Selecting a server clears BMC selection (mutual exclusion).
    srvSelection.select('s1');
    expect(container.read(bmcSelectionProvider), isNull);

    selection.select('b1');
    expect(container.read(bmcSelectionProvider), 'b1');

    // Mismatched expectedAddr rejects stale cert pin write.
    expect(
      notifier.updateCertPin(
        'b1',
        'badpin',
        expectedAddr: 'https://10.0.0.99',
      ),
      isFalse,
    );
    expect(container.read(bmcTargetsProvider).targets['b1']?.certSha256, isNull);

    // Matching expectedAddr persists the pin.
    expect(
      notifier.updateCertPin(
        'b1',
        'deadbeef',
        expectedAddr: 'https://10.0.0.11',
      ),
      isTrue,
    );
    expect(container.read(bmcTargetsProvider).targets['b1']?.certSha256, 'deadbeef');

    notifier.setTags('b1', const ['rack-a', 'gpu']);
    expect(
      container.read(bmcTargetsProvider).targets['b1']?.tags,
      unorderedEquals(['rack-a', 'gpu']),
    );

    notifier.renameTag('rack-a', 'rack-1');
    expect(
      container.read(bmcTargetsProvider).targets['b1']?.tags,
      unorderedEquals(['rack-1', 'gpu']),
    );

    // Linking to a server removes it from standalone selection.
    final current = container.read(bmcTargetsProvider).targets['b1']!;
    notifier.update(current, current.copyWith(serverId: 's1'));
    expect(container.read(bmcSelectionProvider), isNull);

    // Deleting also removes from selection.
    selection.select('b1');
    notifier.delete('b1');
    expect(container.read(bmcTargetsProvider).targets['b1'], isNull);
    expect(container.read(bmcSelectionProvider), isNull);
  });

  test('EntityRecords applies out-of-order bmc_target before server/cred via writeLinks', () {
    const target = BmcTarget(
      id: 'b-sync',
      name: 'sync-bmc',
      addr: 'https://10.0.0.77',
      credId: 'c-sync',
      serverId: 's-sync',
    );
    const cred = BmcCredential(
      id: 'c-sync',
      name: 'sync-cred',
      user: 'root',
      pwd: 'pw',
    );
    final srv = spiFixture(id: 's-sync', name: 'sync-srv', ip: '10.0.0.7');
    final hlc = SyncClock.now();
    String h(int seq) =>
        syncStampOf(ms: BigInt.from(hlc + seq), device: BigInt.one);

    // Out-of-order batch: bmc_target arrives before bmc_credential and server.
    final written = EntityRecords.instance.write([
      (c: 'bmc_target', id: target.id, h: h(1), d: target.toJson()),
      (c: 'bmc_credential', id: cred.id, h: h(2), d: cred.toJson()),
      (c: 'server', id: srv.id, h: h(3), d: {'spi': srv.toJson()}),
    ]);
    expect(written, containsAll(['bmc_target', 'bmc_credential', 'server']));

    Stores.bmcTarget.invalidate();
    final restored = Stores.bmcTarget.fetchOne('b-sync');
    expect(restored?.credId, 'c-sync');
    expect(restored?.serverId, 's-sync');
  });
}
