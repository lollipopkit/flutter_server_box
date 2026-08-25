import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
import 'package:server_box/core/utils/sftp_escalation.dart';
import 'package:server_box/core/utils/sftp_timeout.dart';
import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/file/file_backend.dart';

/// [FileBackend] over SFTP.
///
/// Wraps a client somebody else opened — the terminal's, the transfer
/// isolate's — because who owns the SSH connection is not a question this
/// answers. [close] therefore closes the SFTP channel and leaves the client
/// alone.
class SftpFileBackend implements FileBackend {
  SftpFileBackend(this._sftp, {this.escalation, this.timeout});

  /// Opens one on [client]. The caller owns [client]; this owns the channel.
  ///
  /// [timeout] bounds opening as well as every later operation: a server that
  /// accepts the TCP connection and then says nothing used to leave the browser
  /// spinning with no way back.
  static Future<SftpFileBackend> connect(
    SSHClient client, {
    SftpEscalation? escalation,
    Duration? timeout,
  }) async {
    final sftp = timeout == null
        ? await client.sftp()
        : await withSftpSessionOpenTimeout(
            'open browser session',
            client.sftp(),
            timeout,
          );
    return SftpFileBackend(sftp, escalation: escalation, timeout: timeout);
  }

  final SftpClient _sftp;

  /// What to do when the server refuses. Null means take no for an answer,
  /// which is right for a transfer running in an isolate with nobody to ask.
  final SftpEscalation? escalation;

  /// How long any one operation may take. Null waits forever, which is right
  /// inside a transfer that has its own progress to show.
  final Duration? timeout;

  /// Whatever the SSH account can reach, which sshd decides per path rather
  /// than by a list anything here could enumerate.
  @override
  Future<List<String>> reachableRoots() async => const [];

  @override
  FileBackendTraits get traits => FileBackendTraits(
    permissions: true,
    symlinks: true,
    // Not a property of SFTP but of this connection: escalating means running
    // a shell command, and a session already root has nowhere to escalate to.
    sudoFallback: escalation?.available ?? false,
  );

  @override
  Future<List<FileEntry>> list(String path) => escalate(
    escalation: escalation,
    normal: () async {
      final names = await _bounded('list directory', _sftp.listdir(path));
      return [
        for (final name in names)
          // `.` and `..` are a wire-level detail of the protocol, not entries
          // anybody browses to. Every caller filtered them out, one of them
          // incorrectly.
          if (name.filename != '.' && name.filename != '..') _entryOf(name),
      ];
    },
    // A directory this user may not list is the case sudo exists for, so
    // reading escalates like writing does. `find` rather than `ls` because its
    // output is a fixed number of NUL-separated fields per entry, and so
    // survives names with spaces, quotes and newlines in them.
    sudoCommand: () => listCommand(path),
    fromOutput: parseListOutput,
  );

  @override
  Future<FileEntry?> stat(String path) async {
    final SftpFileAttrs attrs;
    try {
      attrs = await _bounded('stat', _sftp.stat(path));
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
      mode: _permOf(attrs),
    );
  }

  @override
  Future<void> mkdir(String path) => runWithEscalation(
    escalation: escalation,
    normal: () => _bounded('mkdir', _sftp.mkdir(path)),
    sudoCommand: () => 'mkdir -p -- ${shellSingleQuote(path)}',
  );

  @override
  Future<void> remove(String path, {bool recursive = false}) async {
    // `lstat`, not `stat`: a symlink to a directory is a link, and following
    // it here meant running `rmdir` on the link, which every server refuses.
    //
    // Inside the try, because a path under a directory this user cannot
    // traverse fails here rather than at the delete — and outside the
    // escalation it never reached the sudo retry the class advertises.
    bool? isDir;
    try {
      isDir = (await _bounded(
        'stat',
        _sftp.stat(path, followLink: false),
      )).isDirectory;
    } catch (e) {
      if (!isPermissionDenied(e)) rethrow;
      // Unknown, and about to be escalated: `rm -r` covers both shapes and is
      // only reached when the user asked for a recursive delete anyway.
    }

    await runWithEscalation(
      escalation: escalation,
      normal: () async {
        if (isDir != true) {
          await _bounded('remove', _sftp.remove(path));
          return;
        }
        if (recursive) await _removeChildren(path);
        // SFTP has no recursive delete; `rmdir` on a directory with anything
        // left in it fails, which is what the app's "SFTP can't delete a
        // non-empty directory" dialog was explaining to users.
        await _bounded('rmdir', _sftp.rmdir(path));
      },
      // One command instead of walking the tree over a channel that is
      // refusing every step of it.
      sudoCommand: () => switch ((isDir, recursive)) {
        (true, true) => 'rm -r -- ${shellSingleQuote(path)}',
        (true, false) => 'rmdir -- ${shellSingleQuote(path)}',
        (false, _) => 'rm -f -- ${shellSingleQuote(path)}',
        // Never stat'd, because this user could not. `-r` covers a directory
        // and `-f` a file, and one of the two is what is there.
        (null, _) => 'rm -rf -- ${shellSingleQuote(path)}',
      },
    );
  }

  Future<void> _removeChildren(String path) async {
    for (final entry in await list(path)) {
      final child = _join(path, entry.name);
      if (entry.isDir) {
        await _removeChildren(child);
        await _bounded('rmdir', _sftp.rmdir(child));
      } else {
        await _bounded('remove', _sftp.remove(child));
      }
    }
  }

  @override
  Future<void> rename(String from, String to) => runWithEscalation(
    escalation: escalation,
    normal: () => _bounded('rename', _sftp.rename(from, to)),
    sudoCommand: () =>
        'mv -- ${shellSingleQuote(from)} ${shellSingleQuote(to)}',
  );

  @override
  Future<void> chmod(String path, int mode) => runWithEscalation(
    escalation: escalation,
    normal: () => _bounded(
      'chmod',
      // `SSH_FXP_SETSTAT` rather than a shell `chmod`, which is what this used
      // to run: a server that serves SFTP need not give out shells, and
      // changing a mode is something the protocol itself does.
      _sftp.setStat(path, SftpFileAttrs(mode: SftpFileMode.value(mode))),
    ),
    sudoCommand: () =>
        'chmod ${mode.toRadixString(8)} -- ${shellSingleQuote(path)}',
  );

  @override
  Stream<List<int>> read(String path, {int offset = 0}) async* {
    final file = await _openFile(
      'open for read',
      _sftp.open(path, mode: SftpFileOpenMode.read),
      lateCleanup: (file) => file.close(),
    );
    try {
      // Not bounded: a slow transfer is not a stalled one, and the caller
      // watching bytes arrive is better placed to decide it has given up.
      yield* file.read(offset: offset);
    } finally {
      await file.close();
    }
  }

  @override
  Future<void> write(
    String path,
    Stream<List<int>> data, {
    int? size,
    void Function(String staging)? onStaging,
    Stream<List<int>> Function()? replayData,
  }) async {
    // Beside the destination for the same reason as the local backend: a
    // rename on the far side is cheap and atomic only within one filesystem.
    final staging = stagingNameFor(path);
    onStaging?.call(staging);
    var wrote = false;
    var replacementOutcomeUnknown = false;
    try {
      final file = await _openFile(
        'open for write',
        _sftp.open(
          staging,
          mode:
              SftpFileOpenMode.create |
              SftpFileOpenMode.write |
              SftpFileOpenMode.truncate,
        ),
        lateCleanup: (file) async {
          await file.close();
          try {
            await _sftp.remove(staging);
          } catch (_) {}
        },
      );
      wrote = true;
      try {
        await file.write(data.map(Uint8List.fromList)).done;
        await file.close();
      } catch (_) {
        // As in the local backend: a close that complains about a handle the
        // failure already invalidated must not replace the failure.
        try {
          await file.close();
        } catch (_) {}
        rethrow;
      }
      try {
        await _replace(staging, path);
      } on TimeoutException {
        replacementOutcomeUnknown = true;
        try {
          await _sftp.close();
        } catch (_) {}
        rethrow;
      }
    } catch (_) {
      if (wrote && !replacementOutcomeUnknown) {
        try {
          await _sftp.remove(staging);
        } catch (_) {
          // Best effort. The write's own error is the one worth reporting.
        }
      }
      rethrow;
    }
  }

  /// Renames [staging] over [path], whether or not something is there.
  ///
  /// `SSH_FXP_RENAME` is specified to *fail* when the destination exists, and
  /// only servers carrying `posix-rename@openssh.com` replace it — which the
  /// client prefers when offered. Everywhere else, overwriting means deleting
  /// first. That is a moment where neither file is in place, and it is still
  /// better than truncating the destination before the bytes have arrived.
  Future<void> _replace(String staging, String path) async {
    await replaceSftpPath(
      staging: staging,
      destination: path,
      aside: stagingNameFor(path),
      rename: (from, to) => _bounded('rename', _sftp.rename(from, to)),
      remove: (target) => _bounded('remove', _sftp.remove(target)),
    );
  }

  @override
  Future<void> close() => _sftp.close();

  Future<T> _bounded<T>(String what, Future<T> future) =>
      timeout == null ? future : withSftpOpTimeout(what, future, timeout!);

  Future<SftpFile> _openFile(
    String what,
    Future<SftpFile> future, {
    required FutureOr<void> Function(SftpFile file) lateCleanup,
  }) => timeout == null
      ? future
      : withSftpLateCleanupTimeout(
          what,
          future,
          timeout!,
          cleanup: lateCleanup,
        );

  /// `SSH_FX_NO_SUCH_FILE`, from the SFTP protocol.
  static const _sftpStatusNoSuchFile = 2;

  /// One directory level, as five NUL-terminated fields per entry.
  ///
  /// `-mindepth 1 -maxdepth 1` is this directory and no deeper; `-exec … {} +`
  /// hands the whole batch to one shell rather than starting one per file.
  @visibleForTesting
  static String listCommand(String path) =>
      'find ${shellSingleQuote(path)} '
      '-mindepth 1 -maxdepth 1 '
      '-exec sh -c \''
      'for path do '
      'name=\${path##*/}; '
      'perm=\$(stat -c %a "\$path"); '
      'size=\$(stat -c %s "\$path"); '
      'mtime=\$(stat -c %Y "\$path"); '
      'type=u; '
      '[ -d "\$path" ] && type=d; '
      '[ -f "\$path" ] && type=f; '
      // Last, so a link is reported as a link: the two tests above follow it
      // and would otherwise answer for whatever it points at.
      '[ -L "\$path" ] && type=l; '
      'printf "%s\\0%s\\0%s\\0%s\\0%s\\0" "\$name" "\$perm" "\$type" "\$size" "\$mtime"; '
      'done'
      '\' sh {} +';

  @visibleForTesting
  static List<FileEntry> parseListOutput(String output) {
    // Split, not filtered. The command prints five NUL-terminated fields per
    // entry and an empty one is still a field — `stat -c %a` printing nothing
    // used to be dropped, and from that entry onward names were read out of
    // the perm column and sizes out of the mtime column. A silently
    // rearranged listing is worse than a short one.
    final parts = output.split('\u0000');
    // The command's own trailing NUL leaves one empty string at the end.
    if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
    final entries = <FileEntry>[];
    for (var i = 0; i + 4 < parts.length; i += 5) {
      final perm = int.tryParse(parts[i + 1], radix: 8);
      final kind = switch (parts[i + 2]) {
        'd' => FileKind.dir,
        'l' => FileKind.link,
        'f' => FileKind.file,
        _ => FileKind.other,
      };
      entries.add(
        FileEntry(
          name: parts[i],
          kind: kind,
          size: kind == FileKind.file ? int.tryParse(parts[i + 3]) : null,
          modified: _timeOf(int.tryParse(parts[i + 4])),
          mode: perm,
        ),
      );
    }
    return entries;
  }

  static FileEntry _entryOf(SftpName name) => FileEntry(
    name: name.filename,
    kind: _kindOf(name.attr),
    size: name.attr.size,
    modified: _timeOf(name.attr.modifyTime),
    mode: _permOf(name.attr),
  );

  /// SFTP's mode is the type and the permissions in one number; [FileEntry]
  /// keeps only the half that `chmod` takes.
  static int? _permOf(SftpFileAttrs attrs) {
    final value = attrs.mode?.value;
    return value == null ? null : value & kFilePermMask;
  }

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
