import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';

/// Remote server only can be linux-like system, so use '/' as seperator
const _sep = '/';

class SftpBrowserStatus {
  final List<SftpName> files = [];
  final path = _AbsolutePath(_sep);
  SftpClient? client;

  SftpBrowserStatus(SSHClient client) {
    client.sftp().then((value) => this.client = value);
  }
}

class _AbsolutePath {
  String _path;
  final _prePath = <String>[];

  _AbsolutePath(this._path);

  String get path => _path;

  /// Update path, not set path
  set path(String newPath) {
    _prePath.add(_path);
    if (newPath == '..') {
      _path = _path.substring(0, _path.lastIndexOf(_sep));
      if (_path == '') {
        _path = _sep;
      }
      return;
    }
    if (newPath.startsWith(_sep)) {
      _path = newPath;
      return;
    }
    _path = _path.joinPath(newPath, seperator: _sep);
  }

  bool undo() {
    if (_prePath.isEmpty) {
      return false;
    }
    _path = _prePath.removeLast();
    return true;
  }
}
