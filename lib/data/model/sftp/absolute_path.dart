import 'package:toolbox/core/utils/misc.dart';

class AbsolutePath {
  String _path;
  String get path => _path;
  final List<String> _prePath;

  AbsolutePath(this._path) : _prePath = ['/'];

  void update(String newPath) {
    _prePath.add(_path);
    if (newPath == '..') {
      _path = _path.substring(0, _path.lastIndexOf('/'));
      if (_path == '') {
        _path = '/';
      }
      return;
    }
    if (newPath == '/') {
      _path = '/';
      return;
    }
    if (newPath.startsWith('/')) {
      _path = newPath;
      return;
    }
    _path = pathJoin(_path, newPath);
  }

  bool undo() {
    if (_prePath.isEmpty) {
      return false;
    }
    _path = _prePath.removeLast();
    return true;
  }
}
