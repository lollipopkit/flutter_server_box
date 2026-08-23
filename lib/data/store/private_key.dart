import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:sqlite3/sqlite3.dart';

/// Private keys, as rows in `private_key`.
///
/// `id` is generated and `name` is what the user typed. They were the same
/// value until the tables landed, which is why renaming a key detached every
/// server pointing at it — `Spi.ssh.keyId` held the name.
class PrivateKeyStore extends EntityStore<PrivateKeyInfo> {
  PrivateKeyStore._();

  /// A second instance over the same table.
  ///
  /// The table name is fixed by the schema now, so isolation between tests
  /// comes from `SqliteDb.openInMemory()` being fresh per test. What this
  /// still buys is a cache that is not the singleton's.
  @visibleForTesting
  PrivateKeyStore.forTest();

  static final instance = PrivateKeyStore._();

  @override
  String get table => 'private_key';

  @override
  String idOf(PrivateKeyInfo item) => item.id;

  @override
  List<PrivateKeyInfo> readAll() => db
      .select('SELECT id, name, key FROM private_key ORDER BY name;')
      .map(_fromRow)
      .toList();

  static PrivateKeyInfo _fromRow(Row row) => PrivateKeyInfo(
    id: row['id'] as String,
    name: row['name'] as String,
    key: row['key'] as String,
  );

  @override
  void write(PrivateKeyInfo item) =>
      upsert(const ['id', 'name', 'key'], [item.id, item.name, item.key]);

  @override
  String? nameOf(PrivateKeyInfo item) => item.name;

  @override
  Map<String, dynamic> toJson(PrivateKeyInfo item) => item.toJson();

  @override
  PrivateKeyInfo? fromJson(Map<String, dynamic> json) {
    try {
      return PrivateKeyInfo.fromJson(json);
    } catch (e) {
      dprint('Parsing PrivateKeyInfo from JSON', e);
      return null;
    }
  }

  /// A key from a backup written before ids existed carries its name as its
  /// id; keeping the one already here is what makes restoring twice a no-op.
  @override
  PrivateKeyInfo reconcile(PrivateKeyInfo incoming) {
    if (fetchOneRaw(incoming.id) != null) return incoming;
    final existing = fetchByName(incoming.name);
    return existing == null ? incoming : incoming.copyWith(id: existing.id);
  }

  PrivateKeyInfo? fetchOne(String? id) => id == null ? null : fetchOneRaw(id);

  /// The key called [name], for the places that only have one — an imported
  /// `~/.ssh/config`, and the backup format that keyed keys by name.
  PrivateKeyInfo? fetchByName(String name) {
    for (final key in fetch()) {
      if (key.name == name) return key;
    }
    return null;
  }
}
