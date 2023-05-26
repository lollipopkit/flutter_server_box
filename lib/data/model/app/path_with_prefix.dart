class PathWithPrefix {
  final String _prefixPath;
  String _path = '/';
  String? _prePath;
  String get path => _prefixPath + _path;

  PathWithPrefix(String prefixPath) : _prefixPath = _trimSuffix(prefixPath);

  void update(String newPath) {
    _prePath = _path;
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
    _path = _path + (_path.endsWith('/') ? '' : '/') + newPath;
  }

  bool undo() {
    if (_prePath == null || _path == _prePath) {
      return false;
    }
    _path = _prePath!;
    return true;
  }
}

String _trimSuffix(String prefixPath) {
  if (prefixPath.endsWith('/')) {
    return prefixPath.substring(0, prefixPath.length - 1);
  }
  return prefixPath;
}
