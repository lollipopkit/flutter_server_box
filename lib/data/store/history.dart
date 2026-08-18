import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';

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
  HistoryStore._() : super('history');

  /// The same seam [ServerStore.forTest] has: a distinct store name, so a test
  /// on `SqliteDb.openInMemory()` cannot collide with another test's rows.
  ///
  /// This one holds the terminal tab set, which is the piece of session state
  /// that does survive a relaunch — Flutter's own restoration does not, here —
  /// so it is what a test of "what comes back" has to be able to write.
  @visibleForTesting
  HistoryStore.forTest() : super('history_test');

  static final instance = HistoryStore._();

  late final sftpGoPath = _ListHistory(store: this, name: 'sftpPath');

  late final sftpLastPath = _MapHistory(store: this, name: 'sftpLastPath');

  late final sshServerHistory = _ListHistory(
    store: this,
    name: 'sshServerHistory',
  );

  /// The terminal tabs that were open, as JSON.
  ///
  /// Here rather than in `RestorationMixin`, which is what it used to use.
  /// Flutter's restoration data is Android's saved instance state, and this app
  /// never had any: measured on an API 36 emulator, the terminal tab's
  /// `restoreState` ran with a **null bucket**, so nothing registered with it
  /// was ever written. `MaterialApp.home` builds its route without a
  /// restoration id, and a route without one hands no bucket to its subtree.
  ///
  /// A store also survives what saved instance state does not — the process
  /// being killed in the background, and the task being swiped away — which is
  /// exactly when someone wants their terminals back.
  late final sshTabs = propertyDefault('sshTabs', '');

  /// The file tab's sessions, for the same reason and in the same shape.
  ///
  /// This page held them in a `RestorableString` until the measurement above
  /// was applied to it too: it registered, it read back within a session, and
  /// nothing survived a relaunch — so "reopens where it was left" was a
  /// feature that had never once worked.
  late final fileTabs = propertyDefault('fileTabs', '');

  /// Which bottom tab the app was last on.
  ///
  /// An index into the enabled tabs rather than the tab's identity, which is
  /// what it always was — and why every reader clamps it: the enabled set is a
  /// setting, so the list under this number can change while it is stored.
  late final homeTabIndex = propertyDefault('homeTabIndex', 0);
}
