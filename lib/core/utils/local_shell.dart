import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:server_box/core/utils/android_rootfs.dart';
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
  LocalShellBackend({this.inRootfs = false, this.profileId});

  /// Which installed system, when [inRootfs], or null for the selected one.
  ///
  /// proot is a host process per session, so two backends with different ids
  /// are two systems running at once and nothing has to coordinate them.
  final String? profileId;

  /// Whether shells start inside the Linux userland rather than the platform's
  /// own. Only Android has one — see [AndroidRootfs].
  final bool inRootfs;

  /// Whether this build has a shell to give.
  ///
  /// iOS has none: an App Store app cannot start a process, and there is no
  /// `/bin/sh` inside its container to start.
  ///
  /// macOS depends on which of the two builds this is. The App Store one must
  /// be sandboxed, and a sandboxed process cannot open a pseudo-terminal's
  /// slave device — measured: `Process.run` succeeds, the `forkpty` child
  /// exits 255 before it can exec, and neither a home-relative-path nor a
  /// `/dev/` exception changes it. The DMG is signed without the sandbox
  /// (`macos/Runner/ReleaseDmg.entitlements`) and does have one.
  ///
  /// Asked of the running process rather than baked in at build time, so one
  /// binary is honest in both. Everything else has a shell, though what
  /// Android hands over is a good deal less than a desktop's.
  static bool get isSupported {
    if (Platform.isIOS) return false;
    if (Platform.isMacOS && isSandboxed) return false;
    return true;
  }

  /// Whether macOS is confining this process.
  ///
  /// The same question decides where the app's data lives, so the answer is
  /// [Pfs.isMacSandboxed] rather than a second reading of the environment.
  static bool get isSandboxed => Pfs.isMacSandboxed;

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

  /// Where a new shell starts, or null where there is nowhere to say.
  ///
  /// `USERPROFILE` is the Windows spelling of the same idea.
  ///
  /// Android has neither: an app has no `HOME`, so a shell inherits the
  /// process's working directory and opens at `/`, which is read-only and has
  /// nothing in it. The app's own directory is the one place it can write, so
  /// that is this device's home — and it is exported as `HOME` too, or `cd`
  /// with no argument and every `~` in a command would still point at `/`.
  static String? get homeDir {
    if (Platform.isAndroid) return Paths.doc;
    final env = Platform.environment;
    final home = Platform.isWindows ? env['USERPROFILE'] : env['HOME'];
    return home?.isNotEmpty == true ? home : null;
  }

  var _closed = false;
  final _sessions = <ShellSession>[];

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
    final guest = inRootfs
        ? await AndroidRootfs.enter(profileId: profileId)
        : null;
    if (inRootfs && guest == null) {
      throw StateError('The selected Linux system is no longer available.');
    }
    try {
      return _start(
        guest?.executable ?? shellPath,
        arguments: guest?.arguments ?? const [],
        width: width,
        height: height,
        environment: environment,
        onDone: guest?.release,
      );
    } catch (_) {
      guest?.release();
      rethrow;
    }
  }

  @override
  Future<ShellSession> execute(
    String command, {
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    if (_closed) {
      throw StateError('This local shell backend is closed');
    }
    final guest = inRootfs
        ? await AndroidRootfs.enter(command: command, profileId: profileId)
        : null;
    if (inRootfs && guest == null) {
      throw StateError('The selected Linux system is no longer available.');
    }
    try {
      if (Platform.isWindows && guest == null) {
        // flutter_pty closes its output receive port as soon as a short-lived
        // process exits. ConPTY can report that exit before the last output
        // chunk reaches Dart, so fast commands such as `echo` lose all of
        // their output. A one-off command needs no terminal resizing; using a
        // normal process here also gives cmd.exe the complete Windows
        // environment rather than flutter_pty's POSIX-only subset.
        final process = await Process.start(
          shellPath,
          ['/D', '/C', command],
          workingDirectory: homeDir,
          environment: environment,
          runInShell: false,
        );
        final session = _LocalProcessSession(process);
        _sessions.add(session);
        unawaited(
          session.done.whenComplete(() {
            _sessions.remove(session);
          }),
        );
        return session;
      }
      return _start(
        guest?.executable ?? shellPath,
        arguments:
            guest?.arguments ??
            // `/C` on Windows, where `cmd` spells the same idea differently and
            // taking the POSIX form would run nothing at all.
            [Platform.isWindows ? '/C' : '-c', command],
        width: width,
        height: height,
        environment: environment,
        onDone: guest?.release,
      );
    } catch (_) {
      guest?.release();
      rethrow;
    }
  }

  _LocalShellSession _start(
    String executable, {
    required List<String> arguments,
    required int width,
    required int height,
    Map<String, String>? environment,
    void Function()? onDone,
  }) {
    if (_closed) {
      throw StateError('This local shell backend is closed');
    }
    final home = homeDir;
    final session = _LocalShellSession(
      Pty.start(
        executable,
        arguments: arguments,
        // `HOME` only where the platform did not set one — flutter_pty carries
        // the process's own across, and overriding that would be telling a
        // desktop user their home is somewhere else.
        environment: Platform.isAndroid && home != null
            ? {'HOME': home, ...?environment}
            : environment,
        // Where a terminal opens. The app's own working directory is wherever
        // it was launched from — `/` under Finder or the Dock — which made
        // every new shell start with `cd ~`.
        workingDirectory: home,
        // A terminal that has not been laid out yet reports zero, and a pty of
        // no size makes programs that ask draw nothing.
        rows: height > 0 ? height : 25,
        columns: width > 0 ? width : 80,
      ),
    );
    _sessions.add(session);
    unawaited(
      session.done.whenComplete(() {
        _sessions.remove(session);
        onDone?.call();
      }),
    );
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

/// A short-lived Windows command, where a ConPTY can drop output at exit.
class _LocalProcessSession implements ShellSession {
  _LocalProcessSession(this._process);

  final Process _process;

  @override
  Stream<Uint8List> get stdout => _process.stdout.map(Uint8List.fromList);

  @override
  Stream<Uint8List> get stderr => _process.stderr.map(Uint8List.fromList);

  @override
  void write(List<int> data) => _process.stdin.add(data);

  @override
  void resizeTerminal(int width, int height) {}

  @override
  Future<void> get done => _process.exitCode.then<void>((_) {});

  @override
  void close() => _process.kill();
}

/// [ShellSession] on a local pseudo-terminal.
class _LocalShellSession implements ShellSession {
  _LocalShellSession(this._pty) {
    unawaited(_pty.exitCode.then((_) => _exited = true));
  }

  final Pty _pty;

  /// Whether the shell is already gone, so [close] neither signals a pid that
  /// may since have been reused nor schedules a second attempt at nothing.
  var _exited = false;

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
    if (_exited) return;

    // SIGHUP, not SIGTERM. An interactive shell ignores SIGTERM by design, so
    // a terminal that sends it leaves the shell running with nothing attached
    // — measured on macOS: zsh survives SIGTERM and exits on SIGHUP. Hanging
    // up is also what actually happened: the terminal went away.
    //
    // The whole process group, not only the shell. `forkpty` makes the child a
    // session leader, so its pid is its group id, and whatever is in the
    // foreground — `top`, an editor, a build — is in that group. Signalling
    // the leader alone leaves those running with their terminal gone.
    _signal(ProcessSignal.sighup);

    // For a shell, or a foreground process, that trapped the hangup. Nothing
    // is reading this terminal any more, so leaving it running only leaks it.
    Timer(const Duration(seconds: 3), () {
      if (_exited) return;
      _signal(ProcessSignal.sigkill);
    });
  }

  void _signal(ProcessSignal signal) {
    // Windows has no process group to signal, and `Pty.kill` is what its
    // implementation understands.
    if (Platform.isWindows) {
      try {
        _pty.kill(signal);
      } catch (_) {
        // Already gone.
      }
      return;
    }
    try {
      Process.killPid(-_pty.pid, signal);
    } catch (_) {
      // No such group, or a platform that will not take a negative pid. The
      // leader itself is still signalled below.
    }
    try {
      _pty.kill(signal);
    } catch (_) {
      // Already gone. `done` has completed or is about to.
    }
  }
}
