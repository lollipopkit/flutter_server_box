import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Turns models.dev's document into the two columns the table needs.
///
/// Top level because it runs through `compute`, which takes a function that
/// can be sent to another isolate.
///
/// The same reduction `scripts/update-model-context.sh` does, because the app
/// has to be able to do it without the script — smallest window per id for the
/// same reason: compacting early costs a summary, compacting late costs the
/// turn.
Map<String, int> _tableFromApiDocument(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) return const {};
  final table = <String, int>{};
  for (final provider in decoded.values) {
    if (provider is! Map) continue;
    final models = provider['models'];
    if (models is! Map) continue;
    for (final entry in models.entries) {
      final model = entry.value;
      if (model is! Map) continue;
      final limit = model['limit'];
      if (limit is! Map) continue;
      final context = limit['context'];
      if (context is! num || context <= 0) continue;
      final key = entry.key.toString().toLowerCase();
      final tokens = context.toInt();
      final existing = table[key];
      table[key] = existing == null || tokens < existing ? tokens : existing;
    }
  }
  return table;
}

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

  /// Where models.dev publishes what it knows.
  ///
  /// One document for every provider it has, about 4.5 MB. There is no
  /// per-provider endpoint, which is why a refresh is something the user asks
  /// for rather than something that happens on its own.
  static const sourceUrl = 'https://models.dev/api.json';

  static Map<String, int>? _models;
  static String? _generated;

  /// The fetch in flight, so a second caller joins it rather than starting
  /// another. Held here rather than in the row that shows it: that row is
  /// rebuilt whenever any AI setting changes, and a flag living in its build
  /// method came back false mid-fetch — spinner gone, button live again.
  static Future<int>? _inFlight;

  /// Whether a fetch is running. A `ValueListenable` so the row can follow it
  /// across those rebuilds.
  static final refreshing = ValueNotifier(false);

  /// When the table in use was generated, or null before it is loaded.
  ///
  /// The shipped date for the asset, the download's date after a refresh —
  /// which is the one thing that tells a user whether refreshing did anything.
  static String? get generated => _generated;

  static int get modelCount => _models?.length ?? 0;

  @visibleForTesting
  static void loadForTest(Map<String, int> models) => _models = models;

  @visibleForTesting
  static void resetForTest() {
    _models = null;
    _generated = null;
  }

  /// Where a refreshed table is kept. The asset cannot be written to, and a
  /// table the user asked for should outlive the launch that fetched it.
  static File _cacheFile() => File('${Paths.doc}/model_context.json');

  /// Reads the table once. Safe to call again; it answers from memory after.
  ///
  /// The downloaded copy wins over the shipped one. If it is unreadable — a
  /// partial write, a format from a later release — the asset still answers,
  /// which is the reason the asset stays in the app after a refresh.
  static Future<void> ensureLoaded() async {
    if (_models != null) return;
    try {
      final cached = _cacheFile();
      if (cached.existsSync() && _adopt(await cached.readAsString())) return;
    } catch (_) {
      // Fall through to the asset.
    }
    try {
      _adopt(await rootBundle.loadString('assets/model_context.json'));
    } catch (_) {
      // An asset that will not load is not worth failing a conversation over.
    }
    _models ??= const {};
  }

  /// Fetches the table again and keeps it, answering how many models it has.
  ///
  /// Throws what the network threw. The caller is a button the user pressed,
  /// so a failure has somewhere to be reported — unlike [ensureLoaded], which
  /// runs at launch and must not be able to stop one.
  static Future<int> refresh({Dio? dio}) {
    // Joining rather than refusing: two taps mean the same thing, and the
    // second should get the same answer rather than a second download.
    return _inFlight ??= _refresh(dio).whenComplete(() {
      _inFlight = null;
      refreshing.value = false;
    });
  }

  static Future<int> _refresh(Dio? dio) async {
    refreshing.value = true;
    final client = dio ?? Dio();
    final response = await client.get<String>(
      sourceUrl,
      options: Options(
        responseType: ResponseType.plain,
        // Both halves. A standalone `Dio` has no connect timeout by default,
        // so a host that accepts nothing leaves the button spinning forever.
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final body = response.data;
    if (body == null || body.isEmpty) {
      throw const FormatException('models.dev returned nothing');
    }

    // On another isolate: 4.5 MB of JSON is tens of milliseconds of parsing
    // and this is a button on a page that is still drawing. `compute` copies
    // the string across, which is cheaper than the frames it would otherwise
    // drop.
    final table = await compute(_tableFromApiDocument, body);
    if (table.isEmpty) {
      throw const FormatException('models.dev returned no context limits');
    }

    final generated = DateTime.now().toIso8601String().split('T').first;
    final document = jsonEncode({
      'source': sourceUrl,
      'generated': generated,
      'models': table,
    });
    // Written before it is adopted: a table in memory that is not on disk
    // would be gone at the next launch with nothing to say why.
    await _cacheFile().writeAsString(document, flush: true);
    _models = table;
    _generated = generated;
    return table.length;
  }

  /// Turns models.dev's document into the two columns this needs.
  @visibleForTesting
  static Map<String, int> tableFromApiDocument(String raw) =>
      _tableFromApiDocument(raw);

  /// Reads one of this app's own documents — the asset or the cache. Answers
  /// whether it was usable.
  static bool _adopt(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return false;
      final models = decoded['models'];
      if (models is! Map || models.isEmpty) return false;
      _models = {
        for (final entry in models.entries)
          if (entry.value is num)
            entry.key.toString().toLowerCase(): (entry.value as num).toInt(),
      };
      _generated = decoded['generated'] as String?;
      return true;
    } catch (_) {
      return false;
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
  ///
  /// Candidates are cut out of the *name* rather than searched for in the
  /// table. A match has to start at a separator, so the only substrings that
  /// can match are the ones beginning just after one — four of them for
  /// `accounts/fireworks/models/deepseek-v4-flash`. Asking the map about each,
  /// longest first, is four hash lookups; scanning every entry was 3370
  /// `endsWith` calls, on a path that runs once a turn and again on every
  /// rebuild of the settings row that shows the answer.
  static int? lookup(String model) {
    final models = _models;
    if (models == null || models.isEmpty) return null;
    final needle = model.trim().toLowerCase();
    if (needle.isEmpty) return null;

    final exact = models[needle];
    if (exact != null) return exact;

    // Left to right, so the first hit is the longest — `deepseek-v4-flash-0731`
    // is answered by its own entry rather than by `deepseek-v4-flash`.
    for (var index = 0; index < needle.length - 1; index++) {
      if (!_isSeparator(needle.codeUnitAt(index))) continue;
      final found = models[needle.substring(index + 1)];
      if (found != null) return found;
    }
    return null;
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
