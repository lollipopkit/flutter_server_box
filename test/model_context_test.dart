import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/ai/model_context.dart';

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
  });
}
