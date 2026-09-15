import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/ask_ai_config.dart';
import 'package:server_box/data/store/migrations/all.dart';
import 'package:server_box/data/store/migrations/m022_ai_endpoint_version.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// The path completion used to insert `v1` into any address that did not have
/// it. Removing the guess is what fixes #1465 — and would break every address
/// that was working because of it, with a 404 and nothing to say why. This
/// puts the guess into the stored value once, so tomorrow's request is the one
/// that went out yesterday.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the rule', () {
    test('an address with no version gets the one it was being given', () {
      expect(
        AiEndpointVersionMigration.versioned('https://api.openai.com'),
        'https://api.openai.com/v1',
      );
      expect(
        AiEndpointVersionMigration.versioned('https://proxy.example/openai'),
        'https://proxy.example/openai/v1',
      );
      // A trailing slash is the same address.
      expect(
        AiEndpointVersionMigration.versioned('https://api.openai.com/'),
        'https://api.openai.com/v1',
      );
    });

    test('an address that names its version is left alone', () {
      for (final url in const [
        'https://api.openai.com/v1',
        'https://open.bigmodel.cn/api/paas/v4',
        'https://open.bigmodel.cn/api/coding/paas/v4',
      ]) {
        expect(AiEndpointVersionMigration.versioned(url), url, reason: url);
      }
    });

    test('a complete endpoint is left alone', () {
      // The completion never touched these, so neither does this.
      for (final url in const [
        'https://api.openai.com/v1/chat/completions',
        'https://api.openai.com/v1/responses',
        'https://gateway.example/weird/path/chat/completions',
      ]) {
        expect(AiEndpointVersionMigration.versioned(url), url, reason: url);
      }
    });

    test('nothing to work with is left as it is', () {
      expect(AiEndpointVersionMigration.versioned(''), '');
      expect(AiEndpointVersionMigration.versioned('   '), '   ');
      // No host: a value like this cannot be an endpoint anyway, and rewriting
      // it would only make the error message about a different string.
      expect(AiEndpointVersionMigration.versioned('not a url'), 'not a url');
    });
  });

  group('the step', () {
    late SettingStore store;

    setUp(() {
      SqliteDb.openInMemory();
      store = SettingStore('setting_test');
    });

    tearDown(SqliteDb.close);

    test('is registered as the step after the current schema', () {
      final migration = AiEndpointVersionMigration(store: store);
      expect(migration.from, 22);
      // Relative on purpose: an absolute number here fails the day the next
      // step is added, which is not what this test is about.
      expect(SchemaVersion.current, greaterThan(migration.from));
      // Missing from the list throws `Missing schema migration from v22` at
      // launch on a device that has one, and nothing here would say so.
      expect(
        kSchemaMigrations.any((m) => m is AiEndpointVersionMigration),
        isTrue,
      );
      expect(
        kSchemaMigrations.last.from,
        SchemaVersion.current - 1,
        reason: 'the chain has to reach the current version',
      );
    });

    test('rewrites a stored address that was relying on the guess', () {
      store.set(
        AiEndpointVersionMigration.key,
        const AskAiConfig(
          baseUrl: 'https://api.openai.com',
          model: 'gpt-5-nano',
        ).toJson(),
        updateLastUpdateTsOnSet: false,
      );

      AiEndpointVersionMigration(store: store).applySync();

      final raw = store.get<Object>(AiEndpointVersionMigration.key);
      final config = AskAiConfig.fromJson(Map<String, dynamic>.from(raw! as Map));
      expect(config.baseUrl, 'https://api.openai.com/v1');
      // And nothing else about the configuration moved.
      expect(config.model, 'gpt-5-nano');
    });

    test('leaves an address that already names a version', () {
      const url = 'https://open.bigmodel.cn/api/paas/v4';
      store.set(
        AiEndpointVersionMigration.key,
        const AskAiConfig(baseUrl: url).toJson(),
        updateLastUpdateTsOnSet: false,
      );

      AiEndpointVersionMigration(store: store).applySync();

      final raw = store.get<Object>(AiEndpointVersionMigration.key);
      final config = AskAiConfig.fromJson(Map<String, dynamic>.from(raw! as Map));
      expect(config.baseUrl, url);
    });

    test('an install that never configured one is not given a row', () {
      AiEndpointVersionMigration(store: store).applySync();

      expect(store.get<Object>(AiEndpointVersionMigration.key), isNull);
    });

    test('is not a user edit', () {
      store.set(
        AiEndpointVersionMigration.key,
        const AskAiConfig(baseUrl: 'https://api.openai.com').toJson(),
        updateLastUpdateTsOnSet: false,
      );
      final before = store.lastUpdateTs;

      AiEndpointVersionMigration(store: store).applySync();

      // Stamping it would carry a rewrite nobody made to every other device.
      expect(store.lastUpdateTs, before);
    });
  });
}
