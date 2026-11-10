import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/tab.dart';

/// index from 0 -> n : latest -> oldest
class _ListHistory {
  const _ListHistory({required SqliteStore store, required String name})
    : _store = store,
      _name = name;

  final SqliteStore _store;
  final String _name;

  /// Read through on every call rather than cached at construction.
  ///
  /// The Hive version held the list it was built with and wrote the same
  /// instance back, so it was the store's contents only as long as nothing else
  /// touched the key. Nothing did, but a restore now goes through the store
  /// like everything else, and a snapshot taken at first access would outlive
  /// it.
  List<String> get all =>
      _store.get<List>(_name)?.cast<String>().toList() ?? <String>[];

  void add(String path) {
    final history = all..remove(path);
    history.insert(0, path);
    _store.set(_name, history);
  }

  void clear() => _store.set(_name, const <String>[]);
}

class _MapHistory {
  const _MapHistory({required SqliteStore store, required String name})
    : _store = store,
      _name = name;

  final SqliteStore _store;
  final String _name;

  Map<String, String> get _all =>
      _store.get<Map>(_name)?.cast<String, String>() ?? <String, String>{};

  void put(String id, String val) {
    _store.set(_name, {..._all, id: val});
  }

  String? fetch(String id) => _all[id];
}

class HistoryStore extends SqliteStore {
  HistoryStore([super.storeName = 'history']);

  static final instance = HistoryStore();

  late final sftpGoPath = _ListHistory(store: this, name: 'sftpPath');

  late final sftpLastPath = _MapHistory(store: this, name: 'sftpLastPath');

  /// The workspace tab's workspaces, as JSON — see `Workspaces`. Not a table:
  /// it is where this device left off, not a record anybody edits, and it is
  /// read whole.
  late final workspaces = propertyDefault('workspaces', '');

  /// Which of [workspaces] was on screen.
  late final workspaceIndex = propertyDefault('workspaceIndex', 0);

  /// Which bottom tab the app was last on, by [AppTab.name].
  ///
  /// The tab and not its position. It was a position — an index into the
  /// enabled tabs, which every reader had to clamp — and the enabled set is a
  /// setting the user can reorder and shorten while the number is stored. So
  /// moving Terminal to the front and relaunching reopened whatever had taken
  /// its old place, which reads as the app forgetting rather than as the
  /// consequence of a reorder. A name means the same tab or nothing at all.
  ///
  /// Empty means nothing has been stored, or a name this build cannot place:
  /// the caller falls back to the first tab.
  late final homeTab = propertyDefault('homeTab', '');

  /// The position [homeTab] replaced, read once for an install upgrading from
  /// a build that wrote it.
  ///
  /// TODO: delete once no install can still be carrying one.
  late final homeTabIndex = propertyDefault('homeTabIndex', 0);
}
