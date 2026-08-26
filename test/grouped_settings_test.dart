/// The Agent shell's eight settings keys and the AI provider's six, folded
/// into one row each.
///
/// Two things have to hold. The migration takes what the old keys held and
/// nothing more — a field nobody ever set keeps the model's default rather
/// than being pinned to whatever this build would have shown for it. And a
/// `FieldProp` has to behave like the property it replaced at every call site,
/// including its `listenable()`, which the settings UI binds per field.
library;

import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/ask_ai_config.dart';
import 'package:server_box/data/model/app/float_shell_config.dart';
import 'package:server_box/data/store/migrations/m009_grouped_settings.dart';
import 'package:server_box/data/store/setting.dart';

/// The `value` column exactly as stored.
String? _rawValue(String key) {
  final rows = SqliteDb.instance.select(
    'SELECT value FROM kv WHERE store = ? AND key = ?;',
    ['setting_test', key],
  );
  return rows.isEmpty ? null : rows.first['value'] as String?;
}

void main() {
  late SettingStore store;
  late GroupedSettingsMigration migration;

  setUp(() {
    SqliteDb.openInMemory();
    store = SettingStore.forTest();
    migration = GroupedSettingsMigration(store: store);
  });

  tearDown(SqliteDb.close);

  test('it is the step that follows the one before it', () {
    expect(migration.from, 9);
  });

  group('askAi', () {
    test('every old key moves into the object', () async {
      store.setAll({
        'askAiBaseUrl': 'https://example.test',
        'askAiApiKey': 'sk-secret',
        'askAiModel': 'some-model',
        'askAiProtocol': 'responses',
        'askAiAutoRunSafeCommands': true,
        'askAiSendOnEnter': false,
      });

      await migration.apply();

      final config = store.askAi.get();
      expect(config.baseUrl, 'https://example.test');
      expect(config.apiKey, 'sk-secret');
      expect(config.model, 'some-model');
      expect(config.protocol, 'responses');
      expect(config.autoRunSafeCommands, isTrue);
      expect(config.sendOnEnter, isFalse);
    });

    test('and the old keys are gone afterwards', () async {
      store.setAll({'askAiModel': 'some-model', 'askAiApiKey': 'sk-secret'});

      await migration.apply();

      // Left behind they would go into the next backup, and a later restore
      // would carry a shape nothing reads any more.
      expect(store.get<Object>('askAiModel'), isNull);
      expect(store.get<Object>('askAiApiKey'), isNull);
    });

    test('a key nobody set keeps the default, not this build\'s idea of it',
        () async {
      store.set('askAiModel', 'some-model');

      await migration.apply();

      final config = store.askAi.get();
      expect(config.model, 'some-model');
      // Never set, so it goes on tracking whatever the model says the default
      // is — pinning it here would freeze it at today's value forever.
      expect(config.baseUrl, const AskAiConfig().baseUrl);
      expect(config.sendOnEnter, const AskAiConfig().sendOnEnter);
    });

    test('nothing stored writes nothing at all', () async {
      await migration.apply();

      expect(_rawValue('askAi'), isNull);
    });
  });

  group('agentShell', () {
    test('the eight keys land in their two halves', () async {
      store.setAll({
        'agentShellMode': 'docked',
        'agentShellLeft': 12.5,
        'agentShellTop': 34.5,
        'agentShellWidth': 500.0,
        'agentShellHeight': 700.0,
        'agentShellPillOnRight': false,
        'agentShellPillY': 0.25,
        'agentShellSheetHeight': 0.8,
      });

      await migration.apply();

      final config = store.agentShell.get();
      expect(config.mode, 'docked');
      expect(config.window.left, 12.5);
      expect(config.window.top, 34.5);
      expect(config.window.width, 500.0);
      expect(config.window.height, 700.0);
      expect(config.pill.onRight, isFalse);
      expect(config.pill.y, 0.25);
      expect(config.pill.sheetHeight, 0.8);
    });

    test('a position written as an int is still a position', () async {
      // `-1` is valid JSON for a double and reads back as an `int`, which is
      // exactly the value that means "never placed".
      store.set('agentShellLeft', -1);
      store.set('agentShellWidth', 400);

      await migration.apply();

      expect(store.agentShell.get().window.left, -1.0);
      expect(store.agentShell.get().window.width, 400.0);
    });

    test('a key holding the wrong type keeps the default but still goes',
        () async {
      store.set('agentShellWidth', 'not a number');
      store.set('agentShellHeight', 700.0);

      await migration.apply();

      expect(store.agentShell.get().window.height, 700.0);
      expect(
        store.agentShell.get().window.width,
        const FloatShellWindow().width,
      );
      // Removed all the same. Once the field is served by the grouped row the
      // old key has no reader, this step will not run again to reconsider it,
      // and every future backup would carry it.
      expect(store.get<Object>('agentShellWidth'), isNull);
    });
  });

  test('the rows really are objects', () async {
    store.set('askAiModel', 'some-model');
    store.set('agentShellMode', 'docked');

    await migration.apply();

    expect(jsonDecode(_rawValue('askAi')!), isA<Map<String, dynamic>>());
    final shell = jsonDecode(_rawValue('agentShell')!) as Map<String, dynamic>;
    expect(shell['window'], isA<Map<String, dynamic>>());
    expect(shell['pill'], isA<Map<String, dynamic>>());
  });

  test('running the step twice is the same as running it once', () async {
    store.setAll({'askAiModel': 'some-model', 'agentShellPillY': 0.25});
    await migration.apply();
    final first = _rawValue('askAi');

    await migration.apply();

    expect(_rawValue('askAi'), first);
    expect(store.askAi.get().model, 'some-model');
    expect(store.agentShell.get().pill.y, 0.25);
  });

  test('none of it counts as a user edit', () async {
    store.set('askAiModel', 'some-model', updateLastUpdateTsOnSet: false);
    store.set('agentShellMode', 'docked', updateLastUpdateTsOnSet: false);

    await migration.apply();

    // Sync compares this number; moving a value from one key to another is
    // not an edit anybody made.
    expect(store.lastUpdateTs, anyOf(isNull, isEmpty));
  });

  group('a field reads and writes like the property it replaced', () {
    test('get falls back to the model default', () {
      expect(store.askAiModel.get(), const AskAiConfig().model);
      expect(store.agentShell.pillY.get(), const FloatShellPill().y);
    });

    test('set touches one field and leaves the rest', () async {
      await store.askAiApiKey.set('sk-secret');
      await store.askAiModel.set('some-model');

      expect(store.askAiApiKey.get(), 'sk-secret');
      expect(store.askAiModel.get(), 'some-model');
      expect(store.askAiBaseUrl.get(), const AskAiConfig().baseUrl);
    });

    test('and so does a nested one', () async {
      await store.agentShell.width.set(500);
      await store.agentShell.pillY.set(0.25);

      expect(store.agentShell.width.get(), 500);
      expect(store.agentShell.pillY.get(), 0.25);
      expect(store.agentShell.height.get(), const FloatShellWindow().height);
      expect(store.agentShell.mode.get(), const FloatShellConfig().mode);
    });

    test('remove puts the field back to its default, not the whole row',
        () async {
      await store.askAiApiKey.set('sk-secret');
      await store.askAiModel.set('some-model');

      await store.askAiApiKey.remove();

      expect(store.askAiApiKey.get(), '');
      expect(store.askAiModel.get(), 'some-model');
    });

    test('fetch, put and delete are the same three operations', () async {
      store.askAiModel.put('some-model');
      expect(store.askAiModel.fetch(), 'some-model');

      store.askAiModel.delete();
      expect(store.askAiModel.fetch(), const AskAiConfig().model);
    });
  });

  group('a field listenable reports its own field', () {
    test('and fires when it changes', () async {
      final listenable = store.askAiModel.listenable();
      var fired = 0;
      void onChange() => fired++;
      listenable.addListener(onChange);
      addTearDown(() => listenable.removeListener(onChange));

      await store.askAiModel.set('some-model');

      expect(fired, 1);
      expect(listenable.value, 'some-model');
    });

    test('and stays quiet when a sibling field changes', () async {
      // The parent notifies on every write to the object, so without the
      // filter a switch bound to one field would rebuild whenever any other
      // was touched.
      final listenable = store.askAiModel.listenable();
      var fired = 0;
      void onChange() => fired++;
      listenable.addListener(onChange);
      addTearDown(() => listenable.removeListener(onChange));

      await store.askAiApiKey.set('sk-secret');
      await store.askAiBaseUrl.set('https://example.test');

      expect(fired, 0);
    });

    test('and the same callback added twice is removed twice', () async {
      // `ValueListenable` allows it, and keying one wrapper per callback lost
      // the first — it stayed registered on the store with no way to reach it.
      final listenable = store.askAiModel.listenable();
      var fired = 0;
      void onChange() => fired++;
      listenable.addListener(onChange);
      listenable.addListener(onChange);

      await store.askAiModel.set('a');
      expect(fired, 2);

      listenable.removeListener(onChange);
      await store.askAiModel.set('b');
      expect(fired, 3);

      listenable.removeListener(onChange);
      await store.askAiModel.set('c');
      expect(fired, 3);
    });

    test('and a removed listener hears nothing', () async {
      final listenable = store.askAiModel.listenable();
      var fired = 0;
      void onChange() => fired++;
      listenable.addListener(onChange);
      listenable.removeListener(onChange);

      await store.askAiModel.set('some-model');

      expect(fired, 0);
    });
  });
}
