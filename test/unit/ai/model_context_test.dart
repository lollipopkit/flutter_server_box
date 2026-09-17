import 'dart:async';
import 'dart:convert';
import 'package:fl_lib/fl_lib.dart';
import '../../helpers/local_http.dart';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/ai/model_context.dart';
import 'package:server_box/data/model/app/ask_ai_config.dart';

/// The table decides when a conversation is summarised. A wrong answer is
/// survivable — too low spends a summary early, too high spends a turn — so
/// what is asserted here is the matching rule and the shape of the asset, not
/// any particular model's window.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late ModelContextTable table;
  late File cache;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('model-context');
    Paths.doc = dir.path;
    cache = File('${dir.path}/model_context.json');
  });
  tearDownAll(() => dir.delete(recursive: true));
  setUp(() async {
    table = ModelContextTable();
    await cache.writeAsString(
      jsonEncode({
        'models': {
          'gpt-5-nano': 400000,
          'deepseek-v4-flash': 128000,
          'deepseek-v4-flash-0731': 1310720,
          'glm-4.6': 200000,
          'nano': 8000,
        },
      }),
    );
    await table.ensureLoaded();
  });

  test('an exact name is answered directly', () {
    expect(table.lookup('gpt-5-nano'), 400000);
  });

  test('a prefixed name is matched on its end, whatever the case', () {
    // What a proxy or an aggregator does to a model name.
    expect(table.lookup('deepseek/Deepseek-v4-Flash'), 128000);
    expect(table.lookup('accounts/fireworks/models/DEEPSEEK-V4-FLASH'), 128000);
    expect(table.lookup('openai/GPT-5-Nano'), 400000);
  });

  test('the longest match wins', () {
    // Otherwise the dated build is answered by the undated entry.
    expect(table.lookup('deepseek/deepseek-v4-flash-0731'), 1310720);
  });

  test('a match has to start at a boundary', () {
    // `gpt-5-nano` ends with `nano`, and is not that model.
    expect(table.lookup('gpt-5-nano'), 400000);
    expect(table.lookup('some-vendor/nano'), 8000);
    // A name that merely ends in the same letters is a different model.
    expect(table.lookup('ultranano'), isNull);
  });

  test('an unknown model falls back rather than answering nothing', () {
    expect(table.lookup('a-model-nobody-has-heard-of'), isNull);
    expect(
      table.contextFor('a-model-nobody-has-heard-of'),
      ModelContextTable.fallbackContext,
    );
  });

  test('a user override beats the table', () {
    expect(table.contextFor('gpt-5-nano', override: 16000), 16000);
    // Zero is "look it up", which is what the setting stores by default.
    expect(table.contextFor('gpt-5-nano', override: 0), 400000);
  });

  test('an override is keyed by endpoint and model together', () {
    const config = AskAiConfig();
    // The same model name on two providers is two answers: an aggregator may
    // serve a shorter window than the model has.
    final withOpenAi = config.copyWith(
      contextOverrides: config.withContextOverride(
        'https://api.openai.com',
        'gpt-5-nano',
        16000,
      ),
    );
    final withBoth = withOpenAi.copyWith(
      contextOverrides: withOpenAi.withContextOverride(
        'https://openrouter.ai/api/v1',
        'gpt-5-nano',
        8000,
      ),
    );

    expect(
      withBoth.contextOverrideFor('https://api.openai.com', 'gpt-5-nano'),
      16000,
    );
    expect(
      withBoth.contextOverrideFor('https://openrouter.ai/api/v1', 'gpt-5-nano'),
      8000,
    );
    // And a model that was never given one is still automatic.
    expect(withBoth.contextOverrideFor('https://api.openai.com', 'glm-4.6'), 0);
  });

  test('a path or a trailing slash is the same provider', () {
    const config = AskAiConfig();
    final set = config.copyWith(
      contextOverrides: config.withContextOverride(
        'https://open.bigmodel.cn/api/paas/v4',
        'glm-4.6',
        120000,
      ),
    );

    expect(
      set.contextOverrideFor(
        'https://open.bigmodel.cn/api/coding/paas/v4',
        'glm-4.6',
      ),
      120000,
    );
  });

  test('clearing an override removes it rather than storing a zero', () {
    const config = AskAiConfig();
    final set = config.copyWith(
      contextOverrides: config.withContextOverride('https://a', 'm', 100),
    );
    expect(set.contextOverrides, hasLength(1));

    final cleared = set.copyWith(
      contextOverrides: set.withContextOverride('https://a', 'm', 0),
    );
    expect(cleared.contextOverrides, isEmpty);
  });

  test(
    'corrupt caches fall back to the shipped asset without partial adoption',
    () async {
      for (final raw in [
        'not json',
        '{"models":{}}',
        '{"models":{"a":true}}',
        '{"models":{"a":0.5}}',
        '{"models":{"a":0}}',
        '{"generated":42,"models":{"poison":100}}',
      ]) {
        await cache.writeAsString(raw);
        final fresh = ModelContextTable();
        await fresh.ensureLoaded();
        expect(fresh.modelCount, greaterThan(100));
        expect(fresh.lookup('poison'), isNull);
        expect(fresh.generated, isNotNull);
      }
    },
  );

  test('loading filters invalid entries and accepts whole floats', () async {
    await cache.writeAsString(
      '{"models":{"good":128000.0,"zero":0,"negative":-1,"fraction":0.5,"flag":true}}',
    );
    final fresh = ModelContextTable();
    await fresh.ensureLoaded();
    expect(fresh.modelCount, 1);
    expect(fresh.lookup('good'), 128000);
    expect(fresh.contextFor('fraction'), ModelContextTable.fallbackContext);
    await cache.writeAsString('broken');
    await fresh.ensureLoaded();
    expect(fresh.lookup('good'), 128000);
  });

  test(
    'refresh joins callers, filters API data, persists and closes its client',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final release = Completer<void>();
      server.listen((request) async {
        await release.future;
        request.response.write(
          jsonEncode({
            'p': {
              'models': {
                'Good': {
                  'limit': {'context': 128000},
                },
                'bad': {
                  'limit': {'context': 0.5},
                },
              },
            },
            'q': {
              'models': {
                'good': {
                  'limit': {'context': 64000},
                },
                'whole': {
                  'limit': {'context': 8000.0},
                },
              },
            },
          }),
        );
        await request.response.close();
      });
      final http = LocalHttp(server);
      await HttpOverrides.runWithHttpOverrides(() async {
        final first = table.refresh();
        final second = table.refresh();
        expect(identical(first, second), isTrue);
        expect(table.refreshing.value, isTrue);
        release.complete();
        expect(await first, 2);
        expect(table.lookup('good'), 64000);
        expect(table.lookup('bad'), isNull);
        expect(table.lookup('whole'), 8000);
        expect(table.refreshing.value, isFalse);
        expect(table.progress.value, isNull);
        expect(http.requests, 1);
        expect(http.closed, http.created);
        final reloaded = ModelContextTable();
        await reloaded.ensureLoaded();
        expect(reloaded.lookup('good'), 64000);
      }, http);
    },
  );

  test(
    'failed refresh keeps the previous table and releases its client',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.write('{"p":{"models":{}}}');
        await request.response.close();
      });
      final http = LocalHttp(server);
      await HttpOverrides.runWithHttpOverrides(() async {
        await expectLater(table.refresh(), throwsFormatException);
        expect(table.lookup('gpt-5-nano'), 400000);
        expect(table.refreshing.value, isFalse);
        expect(http.closed, 1);
        await expectLater(table.refresh(), throwsFormatException);
        expect(http.closed, 2);
      }, http);
    },
  );
}
