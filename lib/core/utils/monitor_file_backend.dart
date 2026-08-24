import 'dart:async';

import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/provider/server/monitor_http.dart';

/// [FileBackend] over a `monitor` agent's `/api/v1/fs/*`.
///
/// The third implementation, and the one that exists for the narrowest case: a
/// server running the agent whose sshd this app cannot reach at all. Anywhere
/// sshd *is* reachable — directly, or relayed through the agent's own tunnel —
/// SFTP already works end to end and is the better answer, because the agent
/// in the middle cannot read it.
///
/// Confinement lives on the agent, not here. It resolves every path against
/// the roots its operator named and refuses anything outside them. This class
/// does not sanitise paths and must not start: two ends with their own opinion
/// about what a path means is how they stop agreeing, and the one that matters
/// is the end holding the filesystem.
class MonitorFileBackend implements FileBackend {
  /// Opens a session of its own for [monitor].
  ///
  /// Owns it, unlike [SftpFileBackend], which wraps a connection somebody else
  /// holds. There is nothing to share with: the polling client's session
  /// belongs to the `ServerNotifier` and outlives any browser, and coupling a
  /// browse that stalls to the card that says the machine is up would be worse
  /// than one extra login.
  MonitorFileBackend(MonitorHttpCredential monitor)
    : _client = MonitorHttpClient(monitor);

  final MonitorHttpClient _client;

  @override
  FileBackendTraits get traits => const FileBackendTraits(
    // Reported per entry and settable, on the platforms that have them. The
    // agent answers 501 where they do not, which is a failure the browser
    // shows rather than a menu entry it hides — the trait is one answer for
    // the whole backend and the agent may be serving any platform.
    permissions: true,
    symlinks: true,
    // Nowhere to escalate to. The agent runs as one account and offers no way
    // to ask for another; what it will not do, it will not do.
    sudoFallback: false,
  );

  /// The agent's own answer, cached for the life of this backend.
  ///
  /// Cached because it is read where a listing has just failed, which is where
  /// a second round trip is least welcome, and because it cannot change under a
  /// running agent — the roots are resolved once at its startup.
  ///
  /// A failure is *not* cached. This is read from an error view whose other
  /// button is "retry", and a remembered failure would make that button unable
  /// to fix anything for the life of the tab.
  @override
  Future<List<String>> reachableRoots() {
    return _roots ??= _client.fsRoots().onError((Object e, StackTrace s) {
      _roots = null;
      Error.throwWithStackTrace(e, s);
    });
  }

  Future<List<String>>? _roots;

  @override
  Future<List<FileEntry>> list(String path) async {
    final entries = await _client.fsList(path);
    return entries.map(_entryOf).toList();
  }

  @override
  Future<FileEntry?> stat(String path) async {
    final entry = await _client.fsStat(path);
    return entry == null ? null : _entryOf(entry);
  }

  @override
  Future<void> mkdir(String path) => _client.fsMkdir(path);

  @override
  Future<void> remove(String path, {bool recursive = false}) =>
      _client.fsRemove(path, recursive: recursive);

  @override
  Future<void> rename(String from, String to) => _client.fsRename(from, to);

  @override
  Future<void> chmod(String path, int mode) => _client.fsChmod(path, mode);

  @override
  Stream<List<int>> read(String path, {int offset = 0}) async* {
    yield* await _client.fsRead(path, offset: offset);
  }

  @override
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    int? size,
    // Never called: the staging happens inside the agent, under a name this
    // side is not told and could not delete anyway.
    void Function(String staging)? onStaging,
  }) =>
      // Atomic on the agent's side: it stages beside the destination and
      // renames, which is the same contract the other two backends keep and
      // the reason this one does not have to stage anything itself.
      _client.fsWrite(path, data, size: size);

  /// Closes the HTTP session, and with it the connection pool behind it.
  ///
  /// Not a no-op, which is what this was when the client came from outside:
  /// a `Dio` left open holds sockets, and one per file browser and one per
  /// transfer adds up on a device that keeps the app running.
  @override
  Future<void> close() async => _client.dispose();

  static FileEntry _entryOf(Map<String, dynamic> json) {
    final modified = json['modified'];
    return FileEntry(
      name: json['name'] as String? ?? '',
      kind: switch (json['kind']) {
        'dir' => FileKind.dir,
        'file' => FileKind.file,
        'link' => FileKind.link,
        _ => FileKind.other,
      },
      size: (json['size'] as num?)?.toInt(),
      // Seconds on the wire, as SFTP reports them, so both remote backends
      // speak one unit.
      modified: modified is num
          ? DateTime.fromMillisecondsSinceEpoch(modified.toInt() * 1000)
          : null,
      mode: (json['mode'] as num?)?.toInt(),
      linkTarget: json['link_target'] as String?,
    );
  }
}
