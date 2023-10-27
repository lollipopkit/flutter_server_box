import 'package:hive_flutter/hive_flutter.dart';
import 'package:toolbox/core/persistant_store.dart';

/// index from 0 -> n : latest -> oldest
class _ListHistory {
  final List _history;
  final String _name;
  final Box _box;

  _ListHistory({
    required Box box,
    required String name,
  })  : _box = box,
        _name = name,
        _history = box.get(name, defaultValue: [])!;

  void add(String path) {
    _history.remove(path);
    _history.insert(0, path);
    _box.put(_name, _history);
  }

  List get all => _history;
}

class _MapHistory {
  final Map _history;
  final String _name;
  final Box _box;

  _MapHistory({
    required Box box,
    required String name,
  })  : _box = box,
        _name = name,
        _history = box.get(name, defaultValue: <dynamic, dynamic>{})!;

  void put(String id, String val) {
    _history[id] = val;
    _box.put(_name, _history);
  }

  String? fetch(String id) => _history[id];
}

class HistoryStore extends PersistentStore {
  HistoryStore() : super('history');

  /// Paths that user has visited by 'Locate' button
  late final sftpGoPath = _ListHistory(box: box, name: 'sftpPath');

  late final sftpLastPath = _MapHistory(box: box, name: 'sftpLastPath');

  late final sshCmds = _ListHistory(box: box, name: 'sshCmds');
}
