class AbsolutePath {
  String path;
  String? _prePath;
  AbsolutePath(this.path);

  void update(String newPath) {
    _prePath = path;
    if (newPath == '..') {
      path = path.substring(0, path.lastIndexOf('/'));
      if (path == '') {
        path = '/';
      }
      return;
    }
    if (newPath == '/') {
      path = '/';
      return;
    }
    path = path + (path.endsWith('/') ? '' : '/') + newPath;
  }

  bool undo() {
    if (_prePath == null || _prePath == path) {
      return false;
    }
    path = _prePath!;
    return true;
  }
}
