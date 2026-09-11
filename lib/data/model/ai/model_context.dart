import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// How many tokens a model will hold, looked up by the name the user typed.
///
/// The table ships with the app (`assets/model_context.json`, generated from
/// models.dev by `scripts/update-model-context.sh`) and goes stale between
/// releases. That is the reason for [fallbackContext] rather than for a
/// download: a model nobody has heard of still has to be usable, and a wrong
/// answer here only decides when a conversation gets summarised.
abstract final class ModelContextTable {
  /// What an unrecognised model is assumed to hold.
  ///
  /// Low on purpose. Too low costs a summary that was not needed yet; too high
  /// costs the turn, because the request is refused and the user sees an error
  /// instead of an answer.
  static const fallbackContext = 32000;

  static Map<String, int>? _models;

  @visibleForTesting
  static void loadForTest(Map<String, int> models) => _models = models;

  @visibleForTesting
  static void resetForTest() => _models = null;

  /// Reads the table once. Safe to call again; it answers from memory after.
  static Future<void> ensureLoaded() async {
    if (_models != null) return;
    try {
      final raw = await rootBundle.loadString('assets/model_context.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _models = const {};
        return;
      }
      final models = decoded['models'];
      if (models is! Map) {
        _models = const {};
        return;
      }
      _models = {
        for (final entry in models.entries)
          if (entry.value is num)
            entry.key.toString().toLowerCase(): (entry.value as num).toInt(),
      };
    } catch (_) {
      // An asset that will not load is not worth failing a conversation over.
      _models = const {};
    }
  }

  /// The context window for [model], or null when nothing matched.
  ///
  /// Matched on the **end** of the name, case-insensitively. What a user types
  /// is whatever their provider calls the model, and a proxy or aggregator
  /// prefixes it freely — `deepseek/Deepseek-v4-Flash`, `accounts/fireworks/
  /// models/deepseek-v4-flash`, `openai/gpt-5-nano`. The model's own id is the
  /// tail of all of them.
  ///
  /// The longest match wins, so `deepseek-v4-flash-0731` is not answered by
  /// the entry for `deepseek-v4-flash`. Prefixes are not matched at all: a
  /// name ending in something else is a different model, whatever it starts
  /// with.
  static int? lookup(String model) {
    final models = _models;
    if (models == null || models.isEmpty) return null;
    final needle = model.trim().toLowerCase();
    if (needle.isEmpty) return null;

    final exact = models[needle];
    if (exact != null) return exact;

    int? best;
    var bestLength = 0;
    for (final entry in models.entries) {
      if (entry.key.length <= bestLength) continue;
      if (!needle.endsWith(entry.key)) continue;
      // Only at a boundary. Without this, `gpt-5-nano` would be answered by an
      // entry for `nano`, and a name is not a substring match.
      final boundary = needle.length - entry.key.length;
      if (boundary > 0 && !_isSeparator(needle.codeUnitAt(boundary - 1))) {
        continue;
      }
      best = entry.value;
      bestLength = entry.key.length;
    }
    return best;
  }

  /// What sits between a prefix and the model's own id.
  static bool _isSeparator(int codeUnit) =>
      codeUnit == 0x2F || // /
      codeUnit == 0x3A || // :
      codeUnit == 0x2E; // .

  /// What to assume [model] holds, given an optional user override.
  ///
  /// [override] wins outright. A user who has typed a number knows something
  /// the table cannot: their provider serves this model with a shorter window
  /// than the model has, or a longer one than it had when the app shipped.
  static int contextFor(String model, {int? override}) {
    if (override != null && override > 0) return override;
    return lookup(model) ?? fallbackContext;
  }
}
