import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';
import 'package:server_box/data/model/server/shell_backend.dart';

/// [ShellBackend] on the machine the app is running on.
///
/// The third answer to "where do these bytes come from", beside SSH and a
/// monitor agent's PTY. Nothing above [ShellBackend] changes: a terminal does
/// not have to know that this shell needed no network at all.
///
/// Not available everywhere. iOS App Store apps cannot `fork`/`exec`, and on
/// Android the shell is whatever toybox provides — see [isSupported], which is
/// the only thing a caller should ask.
class LocalShellBackend implements ShellBackend {
  LocalShellBackend();

  /// Whether this platform has a shell to give.
  ///
  /// iOS has none: an App Store app cannot start a process, and there is no
  /// `/bin/sh` inside its container to start. Everything else does, though what
  /// Android hands over is a good deal less than a desktop's.
  static bool get isSupported => !Platform.isIOS;

  /// The user's own shell where the OS says so, and a shell that certainly
  /// exists where it does not.
  ///
  /// `$SHELL` rather than a hard-coded path, because a terminal that ignores
  /// which shell someone chose is a terminal they have to `exec` out of every
  /// time they open it.
  static String get shellPath {
    if (Platform.isWindows) {
      return Platform.environment['COMSPEC'] ?? 'cmd.exe';
    }
    if (Platform.isAndroid) return '/system/bin/sh';
    final preferred = Platform.environment['SHELL'];
    if (preferred != null && preferred.isNotEmpty) return preferred;
    return '/bin/sh';
  }

  /// Where a new shell starts, or null where the platform does not say.
  ///
  /// `USERPROFILE` is the Windows spelling of the same idea.
  static String? get _homeDir {
    final env = Platform.environment;
    final home = Platform.isWindows ? env['USERPROFILE'] : env['HOME'];
    return home?.isNotEmpty == true ? home : null;
  }

  var _closed = false;
  final _sessions = <_LocalShellSession>[];

  @override
  bool get isClosed => _closed;

  /// A local process can start another one, so everything built on a second
  /// channel — tmux, the AI helper's probe — works here.
  @override
  bool get supportsExec => true;

  @override
  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    return _start(
      shellPath,
      arguments: const [],
      width: width,
      height: height,
      environment: environment,
    );
  }

  @override
  Future<ShellSession> execute(
    String command, {
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    return _start(
      shellPath,
      // `/C` on Windows, where `cmd` spells the same idea differently and
      // taking the POSIX form would run nothing at all.
      arguments: [Platform.isWindows ? '/C' : '-c', command],
      width: width,
      height: height,
      environment: environment,
    );
  }

  _LocalShellSession _start(
    String executable, {
    required List<String> arguments,
    required int width,
    required int height,
    Map<String, String>? environment,
  }) {
    if (_closed) {
      throw StateError('This local shell backend is closed');
    }
    final session = _LocalShellSession(
      Pty.start(
        executable,
        arguments: arguments,
        environment: environment,
        // Where a terminal opens. The app's own working directory is wherever
        // it was launched from — `/` under Finder or the Dock — which made
        // every new shell start with `cd ~`.
        workingDirectory: _homeDir,
        // A terminal that has not been laid out yet reports zero, and a pty of
        // no size makes programs that ask draw nothing.
        rows: height > 0 ? height : 25,
        columns: width > 0 ? width : 80,
      ),
    );
    _sessions.add(session);
    unawaited(session.done.whenComplete(() => _sessions.remove(session)));
    return session;
  }

  /// Nothing to reach, so nothing can be unreachable.
  ///
  /// The keep-alive this drives is about a link going away underneath a
  /// session. There is no link: a local shell is either running or has exited,
  /// and its exit is reported by [ShellSession.done] like any other.
  @override
  Future<void> ping() async {}

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    // A copy: closing each one removes it from the list.
    for (final session in [..._sessions]) {
      session.close();
    }
  }
}

/// [ShellSession] on a local pseudo-terminal.
class _LocalShellSession implements ShellSession {
  _LocalShellSession(this._pty);

  final Pty _pty;

  @override
  Stream<Uint8List>? get stdout => _pty.output;

  /// Null, like the monitor agent's PTY: a pseudo-terminal merges the two the
  /// way a real terminal does, and there is no second stream to offer.
  @override
  Stream<Uint8List>? get stderr => null;

  @override
  void write(List<int> data) =>
      _pty.write(data is Uint8List ? data : Uint8List.fromList(data));

  @override
  void resizeTerminal(int width, int height) => _pty.resize(height, width);

  @override
  Future<void> get done => _pty.exitCode;

  @override
  void close() {
    // The shell's whole process group, not only the shell. `forkpty` makes the
    // child a session leader, so its pid is its group id, and whatever is in
    // the foreground — `top`, an editor, a build — is in that group. Signalling
    // the leader alone leaves those running with their terminal gone.
    try {
      if (!Platform.isWindows) {
        Process.killPid(-_pty.pid, ProcessSignal.sigterm);
      }
    } catch (_) {
      // No such group, or a platform that will not take a negative pid. The
      // shell itself is still killed below.
    }
    try {
      _pty.kill();
    } catch (_) {
      // Already gone. `done` has completed or is about to.
    }
  }
}
