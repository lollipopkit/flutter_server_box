import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/migrations/m019_drop_geo_cache.dart';

/// The step that takes the retired geo cache off the device.
///
/// It has one job and one way to get it wrong, and that way is silent: `kv` is
/// shared by `setting` and `history`, so a `DELETE` without the `store` clause
/// would take every preference this install has with it and the app would come
/// up looking like a fresh one. Nothing else in the file would notice.
void main() {
  setUp(SqliteDb.openInMemory);
  tearDown(SqliteDb.close);

  // `kv` itself is not created here: `SqliteDb.openInMemory` makes it, which
  // is the definition the app actually runs against rather than one this file
  // wrote to match.

  void insert(String store, String key, String value) {
    SqliteDb.instance.execute(
      'INSERT INTO kv (store, key, value, updated_at) VALUES (?, ?, ?, 0);',
      [store, key, value],
    );
  }

  List<String> storesLeft() => SqliteDb.instance
      .select('SELECT DISTINCT store FROM kv ORDER BY store;')
      .map((row) => row['store'] as String)
      .toList();

  test('drops every cached location', () async {
    insert('geo', '8.8.8.8', '{"coord":{"lat":37.4,"lon":-122.1},"source":"city"}');
    insert('geo', 'example.com', '{"coord":{"lat":51.5,"lon":-0.1},"source":"country"}');

    await const DropGeoCacheMigration().apply();

    expect(
      SqliteDb.instance.select("SELECT * FROM kv WHERE store = 'geo';"),
      isEmpty,
    );
  });

  test('and touches nothing else in the table it shares', () async {
    // The failure this exists for. `setting` is every preference the user has
    // ever changed and `history` is what they typed; both live in `kv` beside
    // what is being removed.
    insert('geo', '8.8.8.8', '{}');
    insert('setting', 'globeEnabled', 'true');
    insert('setting', 'themeMode', '1');
    insert('history', 'sshCmd', '["ls"]');
    insert('self_addr', 'srv-1', '{"addr":"8.8.8.8","at":0}');

    await const DropGeoCacheMigration().apply();

    expect(storesLeft(), ['history', 'self_addr', 'setting']);
    expect(
      SqliteDb.instance
          .select("SELECT value FROM kv WHERE store = 'setting' AND key = ?;", [
            'globeEnabled',
          ])
          .single['value'],
      'true',
    );
    // `self_addr` in particular: it is the globe's other store and it stays,
    // because only the machine knows the address it holds.
    expect(
      SqliteDb.instance.select("SELECT * FROM kv WHERE store = 'self_addr';"),
      hasLength(1),
    );
  });

  test('an install that never used the globe is unaffected', () async {
    insert('setting', 'themeMode', '1');

    await const DropGeoCacheMigration().apply();

    expect(SqliteDb.instance.select('SELECT * FROM kv;'), hasLength(1));
  });

  test('is idempotent', () async {
    insert('geo', '8.8.8.8', '{}');
    insert('setting', 'themeMode', '1');

    await const DropGeoCacheMigration().apply();
    await const DropGeoCacheMigration().apply();

    expect(storesLeft(), ['setting']);
  });
}
