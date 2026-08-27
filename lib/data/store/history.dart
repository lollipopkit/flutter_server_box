import 'dart:convert';

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

  void replace(String oldValue, String newValue) {
    final history = all;
    final index = history.indexOf(oldValue);
    if (index < 0) return;
    history[index] = newValue;
    _store.set(_name, history.toSet().toList());
  }
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

  final Map<String, String> _serverIdAliases = {};

  String resolveSshServerId(String id) {
    var current = id;
    final seen = <String>{};
    while (seen.add(current)) {
      final next = _serverIdAliases[current];
      if (next == null) break;
      current = next;
    }
    return current;
  }

  void renameSshServer(String oldId, String newId) {
    for (final entry in _serverIdAliases.entries.toList()) {
      if (entry.value == oldId) _serverIdAliases[entry.key] = newId;
    }
    _serverIdAliases[oldId] = newId;
    sshServerHistory.replace(oldId, newId);

    final saved = sshTabs.fetch();
    if (saved.isEmpty) return;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! List) return;
      var changed = false;
      for (final entry in decoded.whereType<Map>()) {
        for (final key in const ['sourceId', 'serverId']) {
          if (entry[key] == oldId) {
            entry[key] = newId;
            changed = true;
          }
        }
      }
      if (changed) sshTabs.put(jsonEncode(decoded));
    } catch (e, s) {
      Loggers.app.warning('Failed to rewrite renamed SSH tab state', e, s);
    }
  }

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
