import 'package:fl_lib/fl_lib.dart';

/// index from 0 -> n : latest -> oldest
class _ListHistory {
  final List<String> _history;
  final String _name;
  final HistoryStore _store;

  _ListHistory({required HistoryStore store, required String name})
    : _store = store,
      _name = name,
      _history = List<String>.from(
        store.get<List<dynamic>>(name) ?? const <String>[],
      );

  void add(String path) {
    _history.remove(path);
    _history.insert(0, path);
    _store.set(_name, _history);
  }

  List<String> get all => _history;
}

class _MapHistory {
  final Map<String, String> _history;
  final String _name;
  final HistoryStore _store;

  _MapHistory({required HistoryStore store, required String name})
    : _store = store,
      _name = name,
      _history = Map<String, String>.from(
        store.get<Map<dynamic, dynamic>>(name) ?? const <String, String>{},
      );

  void put(String id, String val) {
    _history[id] = val;
    _store.set(_name, _history);
  }

  String? fetch(String id) => _history[id];
}

class HistoryStore extends SqliteStore {
  HistoryStore._() : super('history');

  static final instance = HistoryStore._();

  /// Paths that user has visited by 'Locate' button
  late final sftpGoPath = _ListHistory(store: this, name: 'sftpPath');

  late final sftpLastPath = _MapHistory(store: this, name: 'sftpLastPath');

  late final sshCmds = _ListHistory(store: this, name: 'sshCmds');

  /// Notify users that this app will write script to server to works properly
  late final writeScriptTipShown = propertyDefault(
    'writeScriptTipShown',
    false,
  );
}
