import 'package:fl_lib/fl_lib.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:meta/meta.dart';

/// index from 0 -> n : latest -> oldest
class _ListHistory {
  final List _history;
  final String _name;
  final Box _box;

  _ListHistory({required Box box, required String name})
    : _box = box,
      _name = name,
      _history = box.get(name, defaultValue: [])!;

  void add(String path) {
    _history.remove(path);
    _history.insert(0, path);
    _box.put(_name, _history);
  }

  List get all => _history;

  void clear() {
    _history.clear();
    _box.put(_name, _history);
  }
}

class _MapHistory {
  final Map _history;
  final String _name;
  final Box _box;

  _MapHistory({required Box box, required String name})
    : _box = box,
      _name = name,
      _history = box.get(name, defaultValue: <dynamic, dynamic>{})!;

  void put(String id, String val) {
    _history[id] = val;
    _box.put(_name, _history);
  }

  String? fetch(String id) => _history[id];
}

class HistoryStore extends HiveStore {
  HistoryStore._() : super('history');

  /// The same seam [SettingStore.forBox] and [ServerStore.forBox] have.
  ///
  /// This one holds the terminal tab set, which is the piece of session state
  /// that does survive a relaunch — Flutter's own restoration does not, here —
  /// so it is what a test of "what comes back" has to be able to write.
  @visibleForTesting
  HistoryStore.forBox(Box<dynamic> testBox) : super('history_test') {
    box = testBox;
  }

  static final instance = HistoryStore._();

  late final sftpGoPath = _ListHistory(box: box, name: 'sftpPath');

  late final sftpLastPath = _MapHistory(box: box, name: 'sftpLastPath');

  late final sshServerHistory = _ListHistory(
    box: box,
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
}
