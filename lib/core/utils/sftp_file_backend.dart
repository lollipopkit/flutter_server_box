import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/core/utils/sftp_escalation.dart';
import 'package:server_box/core/utils/sftp_timeout.dart';
import 'package:server_box/core/utils/shell_file_ops.dart';
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

  /// What bounds a step of a *transfer*, as opposed to an operation.
  ///
  /// The same distinction the SCP backend draws, and the same floor: a command
  /// answers at once or not at all, while a transfer is bounded by the gap
  /// between bytes — and five seconds of silence on a slow link is a slow
  /// link, not a stall. See [SftpIdleWatchdog].
  Duration? get _streamTimeout {
    final bound = timeout;
    if (bound == null) return null;
    return bound < SftpIdleWatchdog.minIdle ? SftpIdleWatchdog.minIdle : bound;
  }

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
    // reading escalates like writing does. The command is `shell_file_ops`',
    // shared with the SCP backend, which has no protocol for a listing at all.
    sudoCommand: () => shellListCommand(path),
    fromOutput: parseShellFileRecords,
  );

  @override
  Future<FileEntry?> stat(String path) async {
    // Asked without following, first. Following answered for whatever the link
    // points at — reporting a symlink as its target's kind, and a link to
    // nowhere as *absent*, which is what a caller reads as "free to create
    // something here" before it writes over the link. [list] has always
    // reported links as links, and so do the local and SCP backends; this is
    // the same question and now gives the same answer.
    final SftpFileAttrs linkless;
    try {
      linkless = await _bounded('stat', _sftp.stat(path, followLink: false));
    } on SftpStatusError catch (e) {
      // Only "no such file" is absence. A refusal is a refusal, and turning it
      // into null would tell a caller it is free to create something there.
      if (e.code == _sftpStatusNoSuchFile) return null;
      rethrow;
    }
    if (!linkless.isSymbolicLink) {
      return FileEntry(
        name: _basename(path),
        kind: _kindOf(linkless),
        size: linkless.size,
        modified: _timeOf(linkless.modifyTime),
        mode: _permOf(linkless),
      );
    }
    // A link is reported as a link and nothing more, which is what the local
    // backend answers: its own size and time describe the link, the target's
    // describe the target, and neither is an answer about this entry. It also
    // saves the second round trip a followed stat would cost.
    return FileEntry(name: _basename(path), kind: FileKind.link);
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
        // Never stat'd, because this user could not, so the shell decides
        // where the file is — while keeping the caller's recursion choice
        // intact. `rm -rf` was here for both cases and turned a delete the
        // user asked to be non-recursive into one that took a whole tree: a
        // stat this account was refused is not consent for that.
        //
        // Asked rather than tried in order, so a refusal is reported as what
        // it refused: `rm -f || rmdir` reaches the second command whatever the
        // first failed for, and the error the user reads is then about the
        // wrong one.
        (null, true) => 'rm -rf -- ${shellSingleQuote(path)}',
        (null, false) =>
          'if [ -d ${shellSingleQuote(path)} ] && '
              '[ ! -L ${shellSingleQuote(path)} ]; '
              'then rmdir -- ${shellSingleQuote(path)}; '
              'else rm -f -- ${shellSingleQuote(path)}; fi',
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
    // The same guard the SCP backend needs, for the same reason and only on
    // this path: `SSH_FXP_RENAME` refuses a destination that is a directory,
    // and `mv` files the source away inside it instead. Escalating a rename
    // must not quietly change what the rename does.
    sudoCommand: () => shellRenameCommand(from, to),
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
      // Bounded by the gap between chunks, not by the length of the read: a
      // slow transfer is not a stalled one, and the same five seconds that is
      // generous for a `stat` would abort every large file over a bad link.
      // Unbounded is what it was, and a server that accepted the channel and
      // then said nothing left this stream — and the isolate around it — alive
      // for as long as the process was.
      final idle = _streamTimeout;
      final bytes = file.read(offset: offset);
      yield* idle == null ? bytes : bytes.timeout(idle);
    } finally {
      await _bounded('close file', file.close());
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
    // Intentionally unused: a timed-out rename has an unknown outcome, so an
    // SFTP write is never replayed.
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
        // Bounded the same way [read] is, and for the same reason: `done`
        // resolves when the server has taken everything, and a server that
        // stops acknowledging never resolves it. `onProgress` is the only
        // sign of life there is, so it is what restarts the clock.
        final idle = _streamTimeout;
        final watchdog = idle == null ? null : SftpIdleWatchdog('write', idle);
        try {
          final writer = file.write(
            data.map(Uint8List.fromList),
            onProgress: watchdog == null ? null : (_) => watchdog.beat(),
          );
          await (watchdog == null ? writer.done : watchdog.guard(writer.done));
        } finally {
          watchdog?.cancel();
        }
        await _bounded('close file', file.close());
      } catch (e) {
        // As in the local backend: a close that complains about a handle the
        // failure already invalidated must not replace the failure.
        if (e is! TimeoutException) {
          try {
            await _bounded('close file', file.close());
          } catch (_) {}
        }
        rethrow;
      }
      // Before the rename, which is what carries a mode onto the destination:
      // the staged copy was created with the far side's umask, so replacing a
      // 0755 script left it 0644 and a 0600 file world-readable.
      await carryModeToStaging(this, staging, path);
      try {
        await _replace(staging, path);
      } on TimeoutException {
        replacementOutcomeUnknown = true;
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

  Future<T> _bounded<T>(String what, Future<T> future) async {
    final limit = timeout;
    if (limit == null) return future;
    try {
      return await withSftpOpTimeout(what, future, limit);
    } on TimeoutException {
      // Future.timeout cannot cancel a request already on the wire. Closing
      // the SFTP channel fences its late reply before callers retry anything.
      unawaited(_sftp.close().catchError((_) {}));
      rethrow;
    }
  }

  Future<SftpFile> _openFile(
    String what,
    Future<SftpFile> future, {
    required FutureOr<void> Function(SftpFile file) lateCleanup,
  }) async {
    final limit = timeout;
    if (limit == null) return future;
    try {
      return await withSftpLateCleanupTimeout(
        what,
        future,
        limit,
        cleanup: lateCleanup,
      );
    } on TimeoutException {
      unawaited(_sftp.close().catchError((_) {}));
      rethrow;
    }
  }

  /// `SSH_FX_NO_SUCH_FILE`, from the SFTP protocol.
  static const _sftpStatusNoSuchFile = 2;

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
