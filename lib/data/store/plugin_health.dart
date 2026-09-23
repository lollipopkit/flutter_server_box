import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/plugin/health.dart';

/// What each plugin has been doing, by id. PLUGINS.md 8.4.
///
/// A key-value store rather than a table: nothing is queried by field, one
/// plugin's record is read by its id, and adding a field stays a one-line
/// change. It is also the shape the data is in — one small document per
/// plugin.
///
/// **Never a user edit, never synced, never in a backup.** It describes what
/// happened on *this* device: a record arriving on another one would say a
/// plugin failed somewhere it has never run, and the timestamps would be a
/// different machine's. Hence `updateLastUpdateTsOnSet: false` — a plugin
/// failing must not make this device look like the newer side of a sync.
class PluginHealthStore extends SqliteStore {
  PluginHealthStore([super.storeName = 'plugin_health'])
    : super(
        updateLastUpdateTsOnSet: false,
        updateLastUpdateTsOnRemove: false,
        updateLastUpdateTsOnClear: false,
      );

  static final instance = PluginHealthStore();

  PluginHealth fetch(String pluginId) =>
      PluginHealth.fromJson(pluginId, get<Map>(pluginId));

  /// Adds one event to a plugin's record.
  ///
  /// Read-modify-write, which is safe here because everything that records is
  /// on the UI isolate: a surface's calls, the bridge's answers, the status
  /// poll. Nothing else writes these keys.
  void record(String pluginId, PluginEvent event) {
    final next = fetch(pluginId).record(event);
    set(pluginId, next.toJson());
  }

  /// Every plugin that has a record, by id.
  Map<String, PluginHealth> readAll() => {
    for (final key in keys()) key: fetch(key),
  };

  void removePlugin(String pluginId) => remove(pluginId);
}

/// Where the app records what a plugin did, in one place so callers do not
/// each hold a store.
///
/// A function rather than a method on the store, because most callers have a
/// plugin id and a stopwatch and nothing else — and because a diagnostic that
/// throws is worse than one that is missing, so this never does.
void recordPluginEvent(
  String pluginId, {
  required PluginStage stage,
  required Duration elapsed,
  String? failure,
  PluginHealthStore? store,
}) {
  if (pluginId.isEmpty) return;
  try {
    (store ?? PluginHealthStore.instance).record(
      pluginId,
      PluginEvent(
        stage: stage,
        at: DateTime.now(),
        elapsed: elapsed,
        failure: failure,
      ),
    );
  } catch (e, s) {
    // The database is not open yet, or will not write. Nothing that calls this
    // is doing it for the record's sake.
    Loggers.app.fine('Recording $stage for $pluginId', e, s);
  }
}

/// A short tag for what class of failure an exception is.
///
/// **A tag, never the message.** The message carries paths, host names and
/// whatever a plugin put in it, and this ends up in a report somebody pastes
/// in public. What an author needs from it is which *kind* of thing failed;
/// the message itself is on the surface and in the log, where the person
/// having the problem can read it and decide.
String pluginFailureTag(Object error) {
  final said = '$error'.toLowerCase();
  if (said.contains('permission denied')) return 'denied';
  if (said.contains('out of scope')) return 'out_of_scope';
  if (said.contains('is not available on')) return 'unavailable';
  if (said.contains('timeout') || said.contains('did not answer')) {
    return 'timeout';
  }
  if (said.contains('cancelled')) return 'cancelled';
  if (said.contains('no such export')) return 'no_such_export';
  if (said.contains('invalid plugin') || said.contains('invalid manifest')) {
    return 'module';
  }
  if (said.contains('memory')) return 'memory';
  return 'threw';
}
