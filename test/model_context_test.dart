import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/ai/model_context.dart';
import 'package:server_box/data/model/app/ask_ai_config.dart';

/// The table decides when a conversation is summarised. A wrong answer is
/// survivable — too low spends a summary early, too high spends a turn — so
/// what is asserted here is the matching rule and the shape of the asset, not
/// any particular model's window.
void main() {
  setUp(() {
    ModelContextTable.loadForTest(const {
      'gpt-5-nano': 400000,
      'deepseek-v4-flash': 128000,
      'deepseek-v4-flash-0731': 1310720,
      'glm-4.6': 200000,
      'nano': 8000,
    });
  });

  tearDown(ModelContextTable.resetForTest);

  test('an exact name is answered directly', () {
    expect(ModelContextTable.lookup('gpt-5-nano'), 400000);
  });

  test('a prefixed name is matched on its end, whatever the case', () {
    // What a proxy or an aggregator does to a model name.
    expect(ModelContextTable.lookup('deepseek/Deepseek-v4-Flash'), 128000);
    expect(
      ModelContextTable.lookup('accounts/fireworks/models/DEEPSEEK-V4-FLASH'),
      128000,
    );
    expect(ModelContextTable.lookup('openai/GPT-5-Nano'), 400000);
  });

  test('the longest match wins', () {
    // Otherwise the dated build is answered by the undated entry.
    expect(
      ModelContextTable.lookup('deepseek/deepseek-v4-flash-0731'),
      1310720,
    );
  });

  test('a match has to start at a boundary', () {
    // `gpt-5-nano` ends with `nano`, and is not that model.
    expect(ModelContextTable.lookup('gpt-5-nano'), 400000);
    expect(ModelContextTable.lookup('some-vendor/nano'), 8000);
    // A name that merely ends in the same letters is a different model.
    expect(ModelContextTable.lookup('ultranano'), isNull);
  });

  test('an unknown model falls back rather than answering nothing', () {
    expect(ModelContextTable.lookup('a-model-nobody-has-heard-of'), isNull);
    expect(
      ModelContextTable.contextFor('a-model-nobody-has-heard-of'),
      ModelContextTable.fallbackContext,
    );
  });

  test('a user override beats the table', () {
    expect(
      ModelContextTable.contextFor('gpt-5-nano', override: 16000),
      16000,
    );
    // Zero is "look it up", which is what the setting stores by default.
    expect(ModelContextTable.contextFor('gpt-5-nano', override: 0), 400000);
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
    expect(
      withBoth.contextOverrideFor('https://api.openai.com', 'glm-4.6'),
      0,
    );
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
      set.contextOverrideFor('https://open.bigmodel.cn/api/coding/paas/v4', 'glm-4.6'),
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

  test('a models.dev document reduces to the two columns needed', () {
    const raw = '''
{
  "openai": {"models": {"gpt-5-nano": {"limit": {"context": 400000}}}},
  "aggregator": {"models": {"gpt-5-nano": {"limit": {"context": 64000}}}},
  "broken": {"models": {"no-limit": {}}},
  "not-a-provider": 7
}
''';
    final table = ModelContextTable.tableFromApiDocument(raw);

    // The smallest wins: compacting early costs a summary, late costs a turn.
    expect(table['gpt-5-nano'], 64000);
    expect(table.containsKey('no-limit'), isFalse);

    // The same rule on the way in from models.dev, not only out of a cache.
    final odd = ModelContextTable.tableFromApiDocument(
      '{"p":{"models":{'
      '"fraction":{"limit":{"context":1.5}},'
      '"flag":{"limit":{"context":true}},'
      '"whole":{"limit":{"context":8000.0}}'
      '}}}',
    );
    expect(odd.containsKey('fraction'), isFalse);
    expect(odd.containsKey('flag'), isFalse);
    expect(odd['whole'], 8000);
  });

  test('a document that parses to nothing usable is refused', () {
    // Refused rather than adopted empty: `ensureLoaded` reads the cache first
    // and only falls back to the asset when this answers false. Adopting an
    // empty map counts as loaded, so a half-written cache file would leave the
    // app with no table while its own asset sat there unread.
    expect(ModelContextTable.adoptForTest('not json at all'), isFalse);
    expect(ModelContextTable.adoptForTest('{"models":{}}'), isFalse);
    expect(
      ModelContextTable.adoptForTest('{"models":{"a":"not a number"}}'),
      isFalse,
    );
    expect(ModelContextTable.adoptForTest('{"models":{"a":0}}'), isFalse);
    // A fraction under one truncates to a zero, which is the value the check
    // above exists to keep out.
    expect(ModelContextTable.adoptForTest('{"models":{"a":0.5}}'), isFalse);
    expect(ModelContextTable.adoptForTest('{"models":{"a":true}}'), isFalse);
  });

  test('a whole number written as a float is still a number', () {
    // `128000.0` is a `double` in Dart and means what it says; only a real
    // fraction is a document that has stopped meaning what it says.
    expect(
      ModelContextTable.adoptForTest('{"models":{"whole":128000.0}}'),
      isTrue,
    );
    expect(ModelContextTable.lookup('whole'), 128000);
  });

  test('a fraction or a boolean is dropped, not truncated', () {
    expect(
      ModelContextTable.adoptForTest(
        '{"models":{"good":1000,"fraction":128000.5,"flag":true,"tiny":0.5}}',
      ),
      isTrue,
    );
    expect(ModelContextTable.lookup('good'), 1000);
    expect(ModelContextTable.lookup('fraction'), isNull);
    expect(ModelContextTable.lookup('flag'), isNull);
    // The one that mattered: truncating this stores a zero, and a zero is
    // answered instead of falling back.
    expect(ModelContextTable.lookup('tiny'), isNull);
    expect(
      ModelContextTable.contextFor('tiny'),
      ModelContextTable.fallbackContext,
    );
  });

  test('a broken entry is dropped rather than answered', () {
    // Zero would be worse than not knowing: `lookup` would answer it, so
    // `contextFor` would return it instead of the fallback, and the token test
    // is skipped whenever the context is not positive.
    expect(
      ModelContextTable.adoptForTest(
        '{"generated":"2026-09-11","models":{"good":1000,"zero":0,"negative":-5}}',
      ),
      isTrue,
    );
    expect(ModelContextTable.lookup('good'), 1000);
    expect(ModelContextTable.lookup('zero'), isNull);
    expect(ModelContextTable.lookup('negative'), isNull);
    expect(
      ModelContextTable.contextFor('zero'),
      ModelContextTable.fallbackContext,
    );
  });

  test('the shipped asset is shaped the way the loader reads it', () {
    final file = File('assets/model_context.json');
    expect(file.existsSync(), isTrue, reason: 'run scripts/update-model-context.sh');

    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect(decoded['source'], 'https://models.dev/api.json');
    expect(decoded['generated'], isA<String>());

    final models = decoded['models'] as Map<String, dynamic>;
    expect(models, isNotEmpty);
    for (final entry in models.entries) {
      expect(entry.key, entry.key.toLowerCase(), reason: 'keys are matched lowercased');
      expect(entry.value, isA<num>(), reason: entry.key);
      expect((entry.value as num) > 0, isTrue, reason: entry.key);
    }
    // And the loader accepts it — the asset is the fallback for everything
    // else, so a shape it refuses would leave the app with no table at all.
    expect(ModelContextTable.adoptForTest(file.readAsStringSync()), isTrue);
  });
}
