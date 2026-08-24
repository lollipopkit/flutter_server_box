import 'package:server_box/data/model/app/agent_shell_config.dart';
import 'package:server_box/data/model/app/ask_ai_config.dart';
import 'package:server_box/data/store/schema.dart';
import 'package:server_box/data/store/setting.dart';

/// Folds the Agent shell's eight keys and the AI provider's six into one row
/// each.
///
/// Fourteen `kv` rows for two pieces of state: fourteen entries in a backup,
/// fourteen in the sync timestamps, fourteen lines in the raw settings editor.
/// They are `agentShell` and `askAi` now — see [AgentShellConfig] and
/// [AskAiConfig] for the shapes, and `FieldProp` for how a caller still reads
/// and writes one field at a time.
///
/// Each field is taken only when the old key is actually present, so anything
/// the user never touched keeps the model's default rather than being frozen
/// at whatever this build happens to think it is. The old keys are removed
/// once read: leaving them would put them back in the next backup, and a later
/// restore would then carry a shape nothing reads.
///
/// Safe to run again on data it has already converted — which it has to be,
/// since the version is recorded only after every statement has run. A second
/// pass finds no old keys, takes nothing, and writes the same object back.
class GroupedSettingsMigration implements SchemaMigration {
  const GroupedSettingsMigration({SettingStore? store}) : _store = store;

  /// Which store to convert. Null is the app's own; a test hands in a
  /// `forTest` one, since the singleton is bound to the real store name.
  final SettingStore? _store;

  @override
  int get from => 9;

  /// Written with `updateLastUpdateTsOnSet: false` throughout: moving a value
  /// from one key to another is not an edit the user made, and counting it as
  /// one would have every install claim a newer copy than whatever it last
  /// synced with.
  @override
  Future<void> apply() async {
    final store = _store ?? SettingStore.instance;
    _groupAskAi(store);
    _groupAgentShell(store);
  }

  static void _groupAskAi(SettingStore store) {
    var config = store.askAi.get();
    final read = _Reader(store);

    config = config.copyWith(
      baseUrl: read.string('askAiBaseUrl'),
      apiKey: read.string('askAiApiKey'),
      model: read.string('askAiModel'),
      protocol: read.string('askAiProtocol'),
      autoRunSafeCommands: read.boolean('askAiAutoRunSafeCommands'),
      sendOnEnter: read.boolean('askAiSendOnEnter'),
    );

    if (!read.tookAnything) return;
    store.set('askAi', config.toJson(), updateLastUpdateTsOnSet: false);
    read.removeAll();
  }

  static void _groupAgentShell(SettingStore store) {
    final config = store.agentShell.get();
    final read = _Reader(store);

    final grouped = config.copyWith(
      mode: read.string('agentShellMode'),
      window: config.window.copyWith(
        left: read.number('agentShellLeft'),
        top: read.number('agentShellTop'),
        width: read.number('agentShellWidth'),
        height: read.number('agentShellHeight'),
      ),
      pill: config.pill.copyWith(
        onRight: read.boolean('agentShellPillOnRight'),
        y: read.number('agentShellPillY'),
        sheetHeight: read.number('agentShellSheetHeight'),
      ),
    );

    if (!read.tookAnything) return;
    store.set('agentShell', grouped.toJson(), updateLastUpdateTsOnSet: false);
    read.removeAll();
  }
}

/// Reads old keys, remembering which were there.
///
/// Every getter answers null for a key that is absent or holds the wrong type,
/// and null is what `copyWith` reads as "leave this one alone" — so a field
/// nobody ever set keeps the model's default instead of being pinned to
/// whatever value this build would have shown for it.
class _Reader {
  _Reader(this.store);

  final SettingStore store;
  final _taken = <String>[];

  bool get tookAnything => _taken.isNotEmpty;

  String? string(String key) => _take<String>(key);

  bool? boolean(String key) => _take<bool>(key);

  /// A number written as an `int` reads back as one — `-1` and `0.0` are both
  /// valid JSON for a position — so this widens rather than asking for a
  /// `double` and getting null for half the rows.
  double? number(String key) => _take<num>(key)?.toDouble();

  T? _take<T extends Object>(String key) {
    final raw = store.get<Object>(key);
    if (raw is! T) return null;
    _taken.add(key);
    return raw;
  }

  /// After the grouped row is written, never before: a process that stops in
  /// between leaves the version unchanged, and the rerun needs these.
  void removeAll() {
    for (final key in _taken) {
      store.remove(key, updateLastUpdateTsOnRemove: false);
    }
  }
}
