/// Where a browser is, and the furthest up it may go.
///
/// POSIX-shaped, like [FileBackend]: a path handed from one backend to another
/// has to mean the same thing at both ends, and the one place that knows about
/// backslashes is the local backend's own edge.
///
/// Root and current directory are separate, which they were not before. The
/// local page took one string and used it as both, so a file tab reopened at
/// `~/Documents/logs/2026` made that its root and could not go up — the
/// directory somebody had happened to be in became the top of the world.
class BrowsePath {
  BrowsePath({required String root, String? initial})
    : root = _normalize(root),
      _path = _normalize(initial ?? root) {
    // Somewhere else entirely, or a stale path from a session saved when the
    // root was different. Landing at the root beats refusing to open.
    if (!_isWithin(_path, this.root)) _path = this.root;
  }

  /// The top. `..` from here does nothing, and nothing above it is reachable.
  final String root;

  String _path;

  /// Where this has been, most recent last.
  ///
  /// Separate from [goUp], which walks the tree: after entering `/etc/ssh` from
  /// `/var/log`, going up lands in `/etc` and going back lands in `/var/log`.
  /// A browser needs both, and conflating them was what made "back" surprising.
  final _history = <String>[];

  String get path => _path;

  bool get canGoUp => _path != root;

  bool get canGoBack => _history.isNotEmpty;

  /// Returns to the previous directory. Returns whether it moved.
  bool goBack() {
    if (_history.isEmpty) return false;
    _path = _history.removeLast();
    return true;
  }

  void _moveTo(String next) {
    if (next == _path) return;
    _history.add(_path);
    // Bounded, because a long browse should not become a long list of strings
    // nobody will scroll back through.
    if (_history.length > _maxHistory) _history.removeAt(0);
    _path = next;
  }

  static const _maxHistory = 64;

  /// The last component, or the root's own name when there is nothing above.
  String get name {
    final slash = _path.lastIndexOf('/');
    if (slash <= 0) return _path;
    return _path.substring(slash + 1);
  }

  void enter(String child) => _moveTo(join(_path, child));

  void goUp() {
    if (!canGoUp) return;
    final slash = _path.lastIndexOf('/');
    final parent = slash <= 0 ? '/' : _path.substring(0, slash);
    _moveTo(_isWithin(parent, root) ? parent : root);
  }

  /// Jumps somewhere, refusing anything outside [root].
  ///
  /// Returns whether it moved, so a caller can say why nothing happened rather
  /// than looking like it ignored the tap.
  bool goTo(String target) {
    final normalized = _normalize(target);
    if (!_isWithin(normalized, root)) return false;
    _moveTo(normalized);
    return true;
  }

  static String join(String dir, String child) =>
      dir.endsWith('/') ? '$dir$child' : '$dir/$child';

  /// Trailing slashes off, `\` in, `/` out.
  ///
  /// A Windows root arrives as `C:\Users\me\Documents` and has to become a
  /// path this can split on; the local backend turns it back at the other end.
  static String _normalize(String path) {
    var value = path.replaceAll(r'\', '/');
    while (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value.isEmpty ? '/' : value;
  }

  /// Whether [path] is [root] or sits under it.
  ///
  /// Compared with the separator attached, so `/var/logs` is not read as being
  /// inside `/var/log`.
  static bool _isWithin(String path, String root) {
    if (path == root) return true;
    final prefix = root.endsWith('/') ? root : '$root/';
    return path.startsWith(prefix);
  }
}
