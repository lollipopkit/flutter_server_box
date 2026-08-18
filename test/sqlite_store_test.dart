import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Covers the two halves of [SqliteStore] separately.
///
/// The store's own behaviour runs against an in-memory database, because the
/// keyed path needs the platform vault and a test that reaches the keychain
/// cannot run on a bare CI machine. The keying itself is exercised directly
/// against a temp file with a fixed key, which is the part that has to be right
/// before any real data is written through it.
void main() {
  group('sqlite3mc is what got compiled in', () {
    test('the multiple-ciphers build reports itself', () {
      final db = sqlite3.openInMemory();
      addTearDown(db.close);

      // Absent from a plain SQLite build, so this failing means
      // `hooks.user_defines.sqlite3.source` in pubspec.yaml did not take.
      final rows = db.select('SELECT sqlite3mc_version() AS v;');
      expect(rows.single['v'], isA<String>());
    });
  });

  group('encryption', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('sbm_sqlite_test'));
    tearDown(() => dir.deleteSync(recursive: true));

    String hex(Uint8List b) =>
        b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

    Uint8List randomKey() => Uint8List.fromList(
      List<int>.generate(32, (_) => Random.secure().nextInt(256)),
    );

    void key(Database db, Uint8List k) {
      db.execute("PRAGMA cipher = 'chacha20';");
      db.execute('PRAGMA key = "x\'${hex(k)}\'";');
    }

    test('a raw key round-trips, and the file is not plaintext', () {
      final path = '${dir.path}/keyed.db';
      final k = randomKey();

      final db = sqlite3.open(path);
      key(db, k);
      db.execute('CREATE TABLE t (v TEXT);');
      db.execute("INSERT INTO t VALUES ('a-recognisable-secret');");
      db.close();

      final reopened = sqlite3.open(path);
      key(reopened, k);
      expect(reopened.select('SELECT v FROM t;').single['v'],
          'a-recognisable-secret');
      reopened.close();

      // The point of the whole exercise: neither the value nor the schema is
      // readable in the file. Hive only ever encrypted values, which is what
      // made `conn_stats_index.hive` legible.
      final bytes = File(path).readAsBytesSync();
      expect(String.fromCharCodes(bytes), isNot(contains('a-recognisable-secret')));
      expect(String.fromCharCodes(bytes), isNot(contains('CREATE TABLE')));
    });

    test('the wrong key does not open the file', () {
      final path = '${dir.path}/keyed.db';

      final db = sqlite3.open(path);
      key(db, randomKey());
      db.execute('CREATE TABLE t (v TEXT);');
      db.close();

      final reopened = sqlite3.open(path);
      key(reopened, randomKey());
      // `PRAGMA key` itself succeeds; the first statement that reads a page is
      // where it fails. `SqliteDb._open` runs exactly this for that reason.
      expect(
        () => reopened.select('SELECT count(*) FROM sqlite_master;'),
        throwsA(isA<SqliteException>()),
      );
      reopened.close();
    });
  });

  group('SqliteStore', () {
    late SqliteStore store;
    late SqliteStore other;

    setUp(() {
      SqliteDb.openInMemory();
      store = SqliteStore('a');
      other = SqliteStore('b');
    });
    tearDown(SqliteDb.close);

    test('round-trips primitives, maps and lists', () {
      store.set('s', 'txt');
      store.set('i', 42);
      store.set('b', true);
      store.set('m', {'x': 1});
      store.set('l', [1, 2, 3]);

      expect(store.get<String>('s'), 'txt');
      expect(store.get<int>('i'), 42);
      expect(store.get<bool>('b'), true);
      expect(store.get<Map>('m'), {'x': 1});
      expect(store.get<List>('l'), [1, 2, 3]);
    });

    test('an absent key is null, not a throw', () {
      expect(store.get<String>('nope'), isNull);
    });

    test('stores with the same key do not see each other', () {
      store.set('k', 'from-a');
      other.set('k', 'from-b');

      expect(store.get<String>('k'), 'from-a');
      expect(other.get<String>('k'), 'from-b');
    });

    test('keys() hides internal keys unless asked', () {
      store.set('visible', 1);
      // Written by `updateLastUpdateTs` on every set above.
      expect(store.keys(), {'visible'});
      expect(
        store.keys(includeInternalKeys: true),
        containsAll(<String>['visible', store.lastUpdateTsKey]),
      );
    });

    test('remove drops one key, clear drops the store only', () {
      store.set('x', 1);
      store.set('y', 2);
      other.set('x', 3);

      store.remove('x');
      expect(store.get<int>('x'), isNull);
      expect(store.get<int>('y'), 2);

      store.clear();
      expect(store.keys(), isEmpty);
      expect(other.get<int>('x'), 3);
    });

    test('clear keeps the last-update map', () {
      store.set('x', 1);
      final before = store.lastUpdateTs;
      expect(before, isNotNull);
      expect(before!['x'], isNotNull);

      store.clear();

      // Not just non-null: `clear` used to put the map back in a shape the
      // reader rejected, so the entries have to survive, not only the key.
      final after = store.lastUpdateTs;
      expect(after, isNotNull);
      expect(after!['x'], isNotNull);
    });

    test('enums are stored by name, not index', () {
      store.set('e', _Fruit.pear);
      expect(store.get<String>('e'), 'pear');
      expect(
        store.get<_Fruit>('e', fromObj: (v) => _Fruit.values.byName(v as String)),
        _Fruit.pear,
      );
    });

    test('an object is stored through toJson', () {
      store.set('o', _Point(1, 2));
      expect(store.get<Map>('o'), {'x': 1, 'y': 2});
    });

    test('a value that cannot be encoded fails loudly, not silently', () {
      expect(store.set('bad', _NoJson()), isFalse);
      expect(store.get<Object>('bad'), isNull);
    });

    test('fromObj converts when the stored shape is not T', () {
      store.set('m', {'x': 1, 'y': 2});
      final p = store.get<_Point>(
        'm',
        fromObj: (v) => _Point((v as Map)['x'] as int, v['y'] as int),
      );
      expect(p?.x, 1);
      expect(p?.y, 2);
    });

    test('setAll writes every entry', () {
      expect(store.setAll({'a': 1, 'b': 2}), isTrue);
      expect(store.get<int>('a'), 1);
      expect(store.get<int>('b'), 2);
    });

    test('getAllMap returns the store contents without internal keys', () {
      store.set('a', 1);
      store.set('b', 'two');
      expect(store.getAllMap(), {'a': 1, 'b': 'two'});
    });

    test('a property notifies its own listeners on write', () {
      final prop = store.property<int>('n');
      final listenable = prop.listenable();

      var calls = 0;
      void onChange() => calls++;
      listenable.addListener(onChange);
      addTearDown(() => listenable.removeListener(onChange));

      prop.set(1);
      expect(calls, 1);
      expect(listenable.value, 1);

      // Another key on the same store must not wake this listener.
      store.set('unrelated', 9);
      expect(calls, 1);

      prop.remove();
      expect(calls, 2);
      expect(listenable.value, isNull);
    });

    test('a default property reports its default until written', () {
      final prop = store.propertyDefault<int>('n', 7);
      expect(prop.get(), 7);
      prop.set(1);
      expect(prop.get(), 1);
    });

    test('listProperty round-trips through JSON', () {
      final prop = store.listProperty<int>('l', defaultValue: const [1]);
      expect(prop.get(), [1]);
      prop.set([4, 5, 6]);
      expect(prop.get(), [4, 5, 6]);
    });

    test('a removed listener stops being called', () {
      final prop = store.property<int>('n');
      final listenable = prop.listenable();

      var calls = 0;
      void onChange() => calls++;
      listenable.addListener(onChange);
      prop.set(1);
      listenable.removeListener(onChange);
      prop.set(2);

      expect(calls, 1);
    });

    test('the stored value really is JSON text', () {
      store.set('m', {'x': 1});
      final raw = SqliteDb.instance.select(
        'SELECT value FROM kv WHERE store = ? AND key = ?;',
        ['a', 'm'],
      ).single['value'] as String;
      expect(json.decode(raw), {'x': 1});
    });
  });
}

enum _Fruit { apple, pear }

class _Point {
  const _Point(this.x, this.y);
  final int x;
  final int y;
  Map<String, Object?> toJson() => {'x': x, 'y': y};
}

class _NoJson {}
