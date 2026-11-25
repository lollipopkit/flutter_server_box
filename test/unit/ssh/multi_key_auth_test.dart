import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/ssh/identities.dart';
import 'package:server_box/core/utils/server_share.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/share/server_share.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/data/store/sync_records.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    Paths.doc = Directory.systemTemp.createTempSync('sbm-multi-key-').path;
  });
  tearDownAll(() => Directory(Paths.doc).deleteSync(recursive: true));

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
    await openTestDb();
    await Stores.init();
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  test('SshCredential resolves ordered keyIds with legacy pubKeyId fallback', () {
    final legacy = SshCredential.fromJson({
      'ip': '10.0.0.1',
      'pubKeyId': 'k1',
    });
    expect(legacy.resolvedKeyIds, ['k1']);
    expect(legacy.firstKeyId, 'k1');
    expect(legacy.keyRefs, ['id:k1']);

    const multi = SshCredential(
      ip: '10.0.0.1',
      keyIds: ['k2', 'k1', 'k2', ''],
    );
    expect(multi.resolvedKeyIds, ['k2', 'k1']);
    expect(multi.firstKeyId, 'k2');
    expect(multi.keyRefs, ['id:k2', 'id:k1']);

    final json = multi.toJson();
    expect(json['pubKeyId'], 'k2');
    expect(json['keyIds'], ['k2', 'k1']);

    final decoded = SshCredential.fromJson(json);
    expect(decoded.resolvedKeyIds, ['k2', 'k1']);
    expect(decoded, multi);
    expect(decoded.hashCode, multi.hashCode);

    // Order matters for equality & reconnect check.
    const reordered = SshCredential(ip: '10.0.0.1', keyIds: ['k1', 'k2']);
    expect(multi.isSameAs(reordered), isFalse);

    // Legacy copyWith(keyId: ...) and copyWith(keyIds: ...) normalize cleanly.
    final singleReplaced = multi.copyWith(keyId: 'k3');
    expect(singleReplaced.resolvedKeyIds, ['k3']);
    final cleared = multi.copyWith(keyId: null);
    expect(cleared.resolvedKeyIds, isEmpty);
    expect(cleared.toJson().containsKey('keyIds'), isFalse);
    final clearedList = multi.copyWith(keyIds: const <String>[]);
    expect(clearedList.resolvedKeyIds, isEmpty);
    expect(clearedList.toJson().containsKey('keyIds'), isFalse);
    expect(multi.copyWith(keyId: '').resolvedKeyIds, isEmpty);
    expect(multi.copyWith(keyIds: const ['', 'k2']).keyId, 'k2');
  });

  test('privateKeyDisplayName strips keyRef prefixes and resolves store name', () {
    Stores.key.put(const PrivateKeyInfo(id: 'k1', name: 'prod-key', key: 'PEM'));
    expect(privateKeyDisplayName('id:k1'), 'prod-key');
    expect(privateKeyDisplayName('id:unknown'), 'unknown');
    expect(privateKeyDisplayName('path:~/.ssh/id_ed25519'), '~/.ssh/id_ed25519');
  });

  test('resolvePrivateKeys returns stored keys in order and skips a missing one', () async {
    Stores.key.put(const PrivateKeyInfo(id: 'k1', name: 'one', key: 'PEM-1'));
    Stores.key.put(const PrivateKeyInfo(id: 'k2', name: 'two', key: 'PEM-2'));

    const ssh = SshCredential(
      ip: '10.0.0.1',
      keyIds: ['k2', 'missing', 'k1'],
    );

    final syncResolved = resolvePrivateKeys(ssh);
    expect(syncResolved.keys.toList(), ['id:k2', 'id:k1']);
    expect(syncResolved.values.toList(), ['PEM-2', 'PEM-1']);

    final asyncResolved = await resolvePrivateKeysAsync(ssh);
    expect(asyncResolved.keys.toList(), ['id:k2', 'id:k1']);
    expect(asyncResolved.values.toList(), ['PEM-2', 'PEM-1']);
  });

  test('ServerShare packs and installs multiple keys in order', () {
    Stores.key.put(const PrivateKeyInfo(id: 'k1', name: 'first', key: 'PEM-1'));
    Stores.key.put(const PrivateKeyInfo(id: 'k2', name: 'second', key: 'PEM-2'));

    const spi = Spi(
      id: 'srv-1',
      name: 'prod',
      ssh: SshCredential(
        ip: '10.0.0.9',
        keyId: 'k2',
        keyIds: ['k2', 'k1'],
      ),
    );
    Stores.server.put(spi);

    expect(ServerShare.omissionsOf(spi), isEmpty);
    final share = ServerShare.of(spi);
    expect(share.version, ServerShare.formatVer);
    expect(share.keys.map((k) => k.id).toList(), ['k2', 'k1']);
    expect(share.spi.ssh!.resolvedKeyIds, ['k2', 'k1']);

    // Zero or one key still emits version 1 for backwards compatibility.
    const singleKeySpi = Spi(
      id: 'srv-single',
      name: 'single',
      ssh: SshCredential(ip: '10.0.0.8', keyId: 'k1'),
    );
    expect(ServerShare.of(singleKeySpi).version, 1);
    const noKeySpi = Spi(
      id: 'srv-nokey',
      name: 'nokey',
      ssh: SshCredential(ip: '10.0.0.7'),
    );
    expect(ServerShare.of(noKeySpi).version, 1);

    // Simulate installing on a clean device with different existing key ids.
    Stores.server.deleteById('srv-1');
    Stores.key.deleteById('k1');
    Stores.key.deleteById('k2');
    Stores.key.put(
      const PrivateKeyInfo(id: 'local-k1', name: 'first', key: 'PEM-1'),
    );

    final res = ServerShareInstaller.install(share);
    final installed = Stores.server.fetchOneRaw(res.spi.id)!;
    final installedIds = installed.ssh!.resolvedKeyIds;
    expect(installedIds, hasLength(2));
    expect(installedIds[1], 'local-k1');
    expect(Stores.key.fetchOne(installedIds[0])?.key, 'PEM-2');
  });

  test('ServerStore.put rejects missing key IDs strictly and rolls back', () {
    Stores.key.put(const PrivateKeyInfo(id: 'k1', name: 'one', key: 'PEM-1'));

    const badSpi = Spi(
      id: 'srv-bad',
      name: 'bad',
      ssh: SshCredential(ip: '10.0.0.5', keyIds: ['k1', 'deleted-key']),
    );
    expect(() => Stores.server.put(badSpi), throwsA(isA<SqliteException>()));
    expect(Stores.server.fetchOneRaw('srv-bad'), isNull);
  });

  test('EntityRecords.write links server_key when server op precedes key ops', () {
    const serverSpi = Spi(
      id: 'srv-sync',
      name: 'synced',
      ssh: SshCredential(ip: '10.0.0.2', keyIds: ['k2', 'k1']),
    );
    const key1 = PrivateKeyInfo(id: 'k1', name: 'first', key: 'PEM-1');
    const key2 = PrivateKeyInfo(id: 'k2', name: 'second', key: 'PEM-2');

    final hlc = SyncClock.now();
    String h(int seq) =>
        syncStampOf(ms: BigInt.from(hlc + seq), device: BigInt.one);

    SqliteStore.transact(() {
      EntityRecords.instance.write([
        (
          c: Stores.server.table,
          id: serverSpi.id,
          h: h(1),
          d: {'spi': serverSpi.toJson()},
        ),
        (c: Stores.key.table, id: key1.id, h: h(2), d: key1.toJson()),
        (c: Stores.key.table, id: key2.id, h: h(3), d: key2.toJson()),
      ]);
    });

    final loaded = Stores.server.fetchOneRaw('srv-sync');
    expect(loaded, isNotNull);
    expect(loaded!.ssh!.resolvedKeyIds, ['k2', 'k1']);
    expect(loaded.ssh!.keyId, 'k2');
  });

  test('BackupV2.merge resolves restored key references by ID before name', () async {
    // Local key k1 was renamed to 'renamed'; a different local key k2 now owns
    // k1's old name 'old-name'.
    Stores.key.put(const PrivateKeyInfo(id: 'k1', name: 'renamed', key: 'PEM-1'));
    Stores.key.put(const PrivateKeyInfo(id: 'k2', name: 'old-name', key: 'PEM-2'));

    final backup = BackupV2(
      version: BackupV2.formatVer,
      date: DateTime.now().millisecondsSinceEpoch,
      spis: {
        'srv-bak': json.decode(
          json.encode(
            const Spi(
              id: 'srv-bak',
              name: 'bak-server',
              ssh: SshCredential(ip: '10.0.0.3', keyIds: ['k1']),
            ).toJson(),
          ),
        ),
      },
      keys: {
        'k1': json.decode(
          json.encode(
            const PrivateKeyInfo(
              id: 'k1',
              name: 'old-name',
              key: 'PEM-1',
            ).toJson(),
          ),
        ),
      },
      snippets: const {},
      container: const {},
      settings: const {},
      history: const {},
    );

    await backup.merge(force: false);
    Stores.server.dropCache();

    final restored = Stores.server.fetchOneRaw('srv-bak');
    expect(restored, isNotNull);
    expect(restored!.ssh!.resolvedKeyIds, ['k1']);
  });

  test('BackupV2.merge(force: false) does not remap distinct explicit key IDs by name', () async {
    Stores.key.put(const PrivateKeyInfo(id: 'k-local', name: 'laptop', key: 'PEM-LOCAL'));

    final backup = BackupV2(
      version: BackupV2.formatVer,
      date: DateTime.now().millisecondsSinceEpoch,
      spis: {
        'srv-remote': json.decode(
          json.encode(
            const Spi(
              id: 'srv-remote',
              name: 'remote-server',
              ssh: SshCredential(ip: '10.0.0.4', keyIds: ['k-remote']),
            ).toJson(),
          ),
        ),
      },
      keys: {
        'k-remote': json.decode(
          json.encode(
            const PrivateKeyInfo(
              id: 'k-remote',
              name: 'laptop',
              key: 'PEM-REMOTE',
            ).toJson(),
          ),
        ),
      },
      snippets: const {},
      container: const {},
      settings: const {},
      history: const {},
    );

    await backup.merge(force: false);
    Stores.server.dropCache();

    // k-remote collides on unique name and is skipped in non-force sync;
    // srv-remote must NOT be silently rebound to unrelated k-local.
    final restored = Stores.server.fetchOneRaw('srv-remote');
    expect(restored, isNotNull);
    expect(restored!.ssh!.resolvedKeyIds, isEmpty);
  });
}
