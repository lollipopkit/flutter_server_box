import 'package:fl_lib/fl_lib.dart';

/// Global persistent Ask AI conversation history.
///
/// Kept separate from [HistoryStore] to avoid mixing with SSH/SFTP history.
class AiHistoryStore extends HiveStore {
  AiHistoryStore._() : super('ai_history');

  static final instance = AiHistoryStore._();

  /// Stored as a list of maps to avoid needing Hive type adapters.
  late final history = listProperty<Map<String, dynamic>>(
    'history',
    defaultValue: const [],
    fromObj: (val) => List<Map<String, dynamic>>.from(
      (val as List).map((e) => Map<String, dynamic>.from(e as Map)),
    ),
  );

  void clearHistory() {
    history.put(const []);
  }
}
