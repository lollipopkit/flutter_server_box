/// What the `setting` store's rows actually look like in the `kv` table.
///
/// `SqliteStore.set` encodes whatever it is handed, so a `toObj` that returns
/// an already-encoded string gets it encoded twice and the `value` column ends
/// up holding a quoted, escaped JSON document. It reads back — the decoder
/// accepted a string — so nothing ever failed; it just cost twice the bytes
/// and rendered as one unbreakable line in the raw settings editor.
///
/// These assert both halves of the fix: new writes are objects, and a row
/// written the old way is still read.
library;

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

/// The `value` column exactly as stored, with no decoding of any kind.
String? _rawValue(String store, String key) {
  final rows = SqliteDb.instance.select(
    'SELECT value FROM kv WHERE store = ? AND key = ?;',
    [store, key],
  );
  return rows.isEmpty ? null : rows.first['value'] as String?;
}

void main() {
  late SettingStore store;

  setUp(() async {
    await openTestDb();
    store = SettingStore('setting_test');
  });

  tearDown(SqliteDb.close);

  group('windowState', () {
    const state = WindowState(Size(1323, 817), Offset(605, 268));

    test('is stored as an object, not as a string holding one', () async {
      await store.windowState.set(state);

      final raw = _rawValue('setting_test', 'windowState');
      expect(raw, isNotNull);

      // The whole point: one decode reaches the fields. Two decodes were
      // needed before, because the first only unwrapped a string.
      final decoded = jsonDecode(raw!);
      expect(
        decoded,
        isA<Map<String, dynamic>>(),
        reason: 'a second encode would make this a String',
      );
      expect((decoded as Map)['size'], {'width': 1323.0, 'height': 817.0});
      expect(decoded['position'], {'dx': 605.0, 'dy': 268.0});
    });

    test('round trips', () async {
      await store.windowState.set(state);

      final read = store.windowState.get();
      expect(read?.size, state.size);
      expect(read?.position, state.position);
    });

    test('still reads a row written the old, double-encoded way', () async {
      // Exactly what shipped builds wrote: `jsonEncode(state.toJson())` handed
      // to `set`, which encoded it again.
      final legacy = jsonEncode(state.toJson());
      expect(store.set('windowState', legacy), isTrue);
      expect(
        _rawValue('setting_test', 'windowState'),
        startsWith('"{'),
        reason: 'the fixture has to be the doubly-encoded shape',
      );

      final read = store.windowState.get();
      expect(read?.size, state.size);
      expect(read?.position, state.position);
    });

    test('and rewrites it as an object on the next write', () async {
      store.set('windowState', jsonEncode(state.toJson()));

      await store.windowState.set(
        const WindowState(Size(800, 600), Offset.zero),
      );

      expect(
        jsonDecode(_rawValue('setting_test', 'windowState')!),
        isA<Map<String, dynamic>>(),
      );
    });

    test('an unreadable value is null rather than a crash', () async {
      store.set('windowState', 42);
      expect(store.windowState.get(), isNull);
    });
  });

  group('the last-update timestamps', () {
    test('are stored as an object, not as a string holding one', () async {
      // Any ordinary write stamps the map.
      await store.timeout.set(9);

      final raw = _rawValue(
        'setting_test',
        StoreDefaults.defaultLastUpdateTsKey,
      );
      expect(raw, isNotNull);

      final decoded = jsonDecode(raw!);
      expect(
        decoded,
        isA<Map<String, dynamic>>(),
        reason: 'a second encode would make this a String',
      );
      expect((decoded as Map)['timeOut'], isA<int>());
    });

    test('still read a map written the old, double-encoded way', () async {
      store.set(
        StoreDefaults.defaultLastUpdateTsKey,
        jsonEncode({'timeOut': 1787551595420}),
        updateLastUpdateTsOnSet: false,
      );
      expect(
        _rawValue('setting_test', StoreDefaults.defaultLastUpdateTsKey),
        startsWith('"{'),
      );

      expect(store.lastUpdateTs, {'timeOut': 1787551595420});
    });

    test('and carry the old entries forward when rewritten', () async {
      store.set(
        StoreDefaults.defaultLastUpdateTsKey,
        jsonEncode({'oldKey': 1787551595420}),
        updateLastUpdateTsOnSet: false,
      );

      await store.timeout.set(9);

      // Losing these would tell the next sync every one of those keys had
      // never been written, which is how a peer's copy wins over a newer one.
      expect(store.lastUpdateTs?['oldKey'], 1787551595420);
      expect(store.lastUpdateTs?['timeOut'], isA<int>());
    });
  });
}
