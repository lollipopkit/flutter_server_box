import 'package:hive_flutter/hive_flutter.dart';
import 'package:toolbox/core/persistant_store.dart';

typedef _HistoryType = List<String>;

/// index from 0 -> n : latest -> oldest
class _History {
  final _HistoryType _history;
  final String _name;
  final Box<_HistoryType> _box;

  _History({
    required Box<_HistoryType> box,
    required String name,
  })  : _box = box,
        _name = name,
        _history = box.get(name, defaultValue: <String>[])!;

  void add(String path) {
    _history.remove(path);
    _history.insert(0, path);
    _box.put(_name, _history);
  }

  _HistoryType get all => _history;
}

class HistoryStore extends PersistentStore<_HistoryType> {
  late final _History sftpPath = _History(box: box, name: 'sftpPath');

  late final _History sshCmds = _History(box: box, name: 'sshCmds');
}
