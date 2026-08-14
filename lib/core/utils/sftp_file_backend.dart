import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/data/model/file/file_backend.dart';

/// [FileBackend] over SFTP.
///
/// Wraps a client somebody else opened — the terminal's, the transfer
/// isolate's — because who owns the SSH connection is not a question this
/// answers. [close] therefore closes the SFTP channel and leaves the client
/// alone.
class SftpFileBackend implements FileBackend {
  SftpFileBackend(this._sftp);

  /// Opens one on [client]. The caller owns [client]; this owns the channel.
  static Future<SftpFileBackend> connect(SSHClient client) async =>
      SftpFileBackend(await client.sftp());

  final SftpClient _sftp;

  @override
  FileBackendTraits get traits => const FileBackendTraits(
    permissions: true,
    symlinks: true,
    // What `sftp_sudo.dart` is: an operation the server refused, retried as a
    // shell command. The shell is the SSH connection this rides on.
    sudoFallback: true,
    randomAccessReads: true,
  );

  @override
  Future<List<FileEntry>> list(String path) async {
    final names = await _sftp.listdir(path);
    return [
      for (final name in names)
        // `.` and `..` are a wire-level detail of the protocol, not entries
        // anybody browses to. Every caller filtered them out, one of them
        // incorrectly.
        if (name.filename != '.' && name.filename != '..') _entryOf(name),
    ];
  }

  @override
  Future<FileEntry?> stat(String path) async {
    final SftpFileAttrs attrs;
    try {
      attrs = await _sftp.stat(path);
    } on SftpStatusError catch (e) {
      // Only "no such file" is absence. A refusal is a refusal, and turning it
      // into null would tell a caller it is free to create something there.
      if (e.code == _sftpStatusNoSuchFile) return null;
      rethrow;
    }
    return FileEntry(
      name: _basename(path),
      kind: _kindOf(attrs),
      size: attrs.size,
      modified: _timeOf(attrs.modifyTime),
      mode: attrs.mode?.value,
    );
  }

  @override
  Future<void> mkdir(String path) => _sftp.mkdir(path);

  @override
  Future<void> remove(String path, {bool recursive = false}) async {
    final attrs = await _sftp.stat(path);
    if (!attrs.isDirectory) {
      await _sftp.remove(path);
      return;
    }
    if (recursive) await _removeChildren(path);
    // SFTP has no recursive delete; `rmdir` on a directory with anything left
    // in it fails, which is what the app's "SFTP can't delete a non-empty
    // directory" dialog was explaining to users.
    await _sftp.rmdir(path);
  }

  Future<void> _removeChildren(String path) async {
    for (final entry in await list(path)) {
      final child = _join(path, entry.name);
      if (entry.isDir) {
        await _removeChildren(child);
        await _sftp.rmdir(child);
      } else {
        await _sftp.remove(child);
      }
    }
  }

  @override
  Future<void> rename(String from, String to) => _sftp.rename(from, to);

  @override
  Stream<List<int>> read(String path, {int offset = 0}) async* {
    final file = await _sftp.open(path, mode: SftpFileOpenMode.read);
    try {
      yield* file.read(offset: offset);
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> write(String path, Stream<List<int>> data, {int? size}) async {
    // Beside the destination for the same reason as the local backend: a
    // rename on the far side is cheap and atomic only within one filesystem.
    final staging = '$path.${_stagingSuffix()}';
    var wrote = false;
    try {
      final file = await _sftp.open(
        staging,
        mode: SftpFileOpenMode.create |
            SftpFileOpenMode.write |
            SftpFileOpenMode.truncate,
      );
      wrote = true;
      try {
        await file
            .write(data.map(Uint8List.fromList))
            .done;
      } finally {
        await file.close();
      }
      await _sftp.rename(staging, path);
    } catch (_) {
      if (wrote) {
        try {
          await _sftp.remove(staging);
        } catch (_) {
          // Best effort. The write's own error is the one worth reporting.
        }
      }
      rethrow;
    }
  }

  @override
  Future<void> close() => _sftp.close();

  static var _staging = 0;

  static String _stagingSuffix() => 'sb-part-${_staging++}';

  /// `SSH_FX_NO_SUCH_FILE`, from the SFTP protocol.
  static const _sftpStatusNoSuchFile = 2;

  static FileEntry _entryOf(SftpName name) => FileEntry(
    name: name.filename,
    kind: _kindOf(name.attr),
    size: name.attr.size,
    modified: _timeOf(name.attr.modifyTime),
    mode: name.attr.mode?.value,
  );

  static FileKind _kindOf(SftpFileAttrs attrs) {
    if (attrs.isDirectory) return FileKind.dir;
    if (attrs.isSymbolicLink) return FileKind.link;
    if (attrs.isFile) return FileKind.file;
    return FileKind.other;
  }

  /// SFTP counts seconds; the rest of the app counts milliseconds.
  static DateTime? _timeOf(int? seconds) => seconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

  static String _basename(String path) {
    final trimmed = path.endsWith('/') && path.length > 1
        ? path.substring(0, path.length - 1)
        : path;
    final slash = trimmed.lastIndexOf('/');
    return slash < 0 ? trimmed : trimmed.substring(slash + 1);
  }

  static String _join(String dir, String name) =>
      dir.endsWith('/') ? '$dir$name' : '$dir/$name';
}
