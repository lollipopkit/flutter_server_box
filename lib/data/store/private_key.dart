import 'package:server_box/data/db/app_db.dart' as adb;
import 'package:server_box/data/model/server/private_key_info.dart';

class PrivateKeyStore {
  PrivateKeyStore._();

  static final instance = PrivateKeyStore._();

  adb.AppDb get _db => adb.AppDb.instance;

  Future<void> put(PrivateKeyInfo info) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.privateKeys)
        .insertOnConflictUpdate(
          adb.PrivateKeysCompanion.insert(
            id: info.id,
            privateKey: info.key,
            updatedAt: now,
          ),
        );
  }

  Future<List<PrivateKeyInfo>> fetch() async {
    final rows = await _db.select(_db.privateKeys).get();
    return rows
        .map((row) => PrivateKeyInfo(id: row.id, key: row.privateKey))
        .toList(growable: false);
  }

  Future<PrivateKeyInfo?> fetchOne(String? id) async {
    if (id == null) return null;
    final row = await (_db.select(
      _db.privateKeys,
    )..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    return PrivateKeyInfo(id: row.id, key: row.privateKey);
  }

  Future<void> delete(PrivateKeyInfo s) async {
    await (_db.delete(
      _db.privateKeys,
    )..where((tbl) => tbl.id.equals(s.id))).go();
  }

  Future<Set<String>> keys() async {
    final query = _db.selectOnly(_db.privateKeys)
      ..addColumns([_db.privateKeys.id]);
    final rows = await query.get();
    return rows
        .map((row) => row.read(_db.privateKeys.id))
        .whereType<String>()
        .toSet();
  }

  Future<void> clear() async {
    await _db.delete(_db.privateKeys).go();
  }
}
