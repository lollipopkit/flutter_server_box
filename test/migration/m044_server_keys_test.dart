import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m044_server_keys.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/tables.dart';

String _shape() => '${(
  [
    for (final r in SqliteDb.instance.select('PRAGMA table_info(server_key);'))
      (r['name'], r['type'], r['notnull'], r['pk']),
  ],
  [
    for (final r in SqliteDb.instance.select('PRAGMA foreign_key_list(server_key);'))
      (r['table'], r['from'], r['to'], r['on_delete']),
  ],
)}';

Future<void> _v44() async {
  await createTables(SqliteDb.instance);
  SqliteDb.instance.execute('DROP TABLE server_key;');
}

void main() {
  setUp(() => SqliteDb.openInMemory());

  tearDown(() async {
    await closeTables();
    await SqliteDb.close();
  });

  test('is registered once, from 44, as the latest migration', () {
    expect(const ServerKeysMigration().from, 44);
    expect(kSchemaMigrations.whereType<ServerKeysMigration>(), hasLength(1));
    expect(kSchemaMigrations.last.from, SchemaVersion.current - 1);
  });

  test('creates the same table shape a fresh database has', () async {
    await createTables(SqliteDb.instance);
    final fresh = _shape();
    await closeTables();
    await SqliteDb.close();
    SqliteDb.openInMemory();
    await _v44();

    await const ServerKeysMigration().apply();

    expect(_shape(), fresh);
  });

  test('copies existing server.ssh_key_id rows into server_key and is idempotent', () async {
    await _v44();
    final db = SqliteDb.instance;
    db.execute(
      "INSERT INTO private_key (id, name, key) VALUES ('k1', 'prod', 'PEM-1');",
    );
    db.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, ssh_key_id) '
      "VALUES ('s1', 's1', '10.0.0.1', 22, 'root', 'k1');",
    );
    db.execute(
      'INSERT INTO server (id, name, ssh_ip, ssh_port, ssh_user, ssh_key_id) '
      "VALUES ('s2', 's2', '10.0.0.2', 22, 'root', NULL);",
    );

    await const ServerKeysMigration().apply();
    await const ServerKeysMigration().apply();

    final store = ServerStore();
    expect(store.fetchOneRaw('s1')!.ssh!.resolvedKeyIds, ['k1']);
    expect(store.fetchOneRaw('s2')!.ssh!.resolvedKeyIds, isEmpty);
  });

  test('persists ordered multi-key lists and cascades key deletion cleanly', () async {
    await createTables(SqliteDb.instance);
    SqliteDb.instance.execute('PRAGMA foreign_keys = ON;');

    final keyStore = PrivateKeyStore();
    keyStore.put(const PrivateKeyInfo(id: 'k1', name: 'first', key: 'PEM-1'));
    keyStore.put(const PrivateKeyInfo(id: 'k2', name: 'second', key: 'PEM-2'));
    keyStore.put(const PrivateKeyInfo(id: 'k3', name: 'third', key: 'PEM-3'));

    final serverStore = ServerStore();
    serverStore.put(
      const Spi(
        id: 's1',
        name: 's1',
        ssh: SshCredential(
          ip: '10.0.0.1',
          keyId: 'k2',
          keyIds: ['k2', 'k1', 'k3'],
        ),
      ),
    );

    final loaded = serverStore.fetchOneRaw('s1')!;
    expect(loaded.ssh!.resolvedKeyIds, ['k2', 'k1', 'k3']);
    expect(loaded.ssh!.firstKeyId, 'k2');

    // Deleting the primary key cascades out of `server_key` and backfills
    // `server.ssh_key_id` with the next surviving key in order.
    keyStore.deleteById('k2');
    serverStore.dropCache();
    final afterDelete = serverStore.fetchOneRaw('s1')!;
    expect(afterDelete.ssh!.resolvedKeyIds, ['k1', 'k3']);
    expect(afterDelete.ssh!.firstKeyId, 'k1');
    expect(
      SqliteDb.instance
          .select("SELECT ssh_key_id FROM server WHERE id = 's1';")
          .single['ssh_key_id'],
      'k1',
    );
  });
}
