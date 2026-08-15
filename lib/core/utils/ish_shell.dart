import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/data/model/server/shell_backend.dart';

/// [ShellBackend] over the Linux guest on iOS.
///
/// The fourth answer to "where do these bytes come from", after SSH, a monitor
/// agent's PTY and this device's own shell. Nothing above [ShellBackend]
/// changes; what is different is underneath, and it is unlike the other three
/// in one way that shows: **there is one guest per app process**, because the
/// engine keeps its kernel state in globals. So this backend hands out one
/// session, and asking for a second returns the same one.
///
/// That is not a limitation to route around. A guest is a machine; two
/// terminals on it are two processes *inside* it, which is what the shell
/// already does — and how the Android rootfs behaves too, from the other
/// direction.
class IshShellBackend implements ShellBackend {
  IshShellBackend();

  /// Whether this build can open one at all — see [IosRootfs.isAvailable],
  /// which is false whenever the engine was stripped from the build.
  static bool get isSupported => IosRootfs.isAvailable;

  final _sessions = <_IshSession>[];
  var _closed = false;

  @override
  bool get isClosed => _closed;

  /// Yes. Every session is a process in the machine with a pty of its own, so
  /// a command run beside the terminal cannot land on the terminal's output.
  @override
  bool get supportsExec => true;

  @override
  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async => _start(null, width, height);

  @override
  Future<ShellSession> execute(
    String command, {
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async => _start(command, width, height);

  _IshSession _start(String? command, int width, int height) {
    if (_closed) throw StateError('This guest has been closed');

    // The machine, once. -EEXIST means it is already up — from an earlier
    // terminal, or from the Agent — and that is not an error: it is the
    // machine, and this is another process on it.
    final booted = IosRootfs.boot();
    if (booted < 0 && booted != -17) {
      throw StateError('The Linux guest did not start ($booted)');
    }

    final id = IosRootfs.open(
      command: command,
      columns: width > 0 ? width : 80,
      rows: height > 0 ? height : 25,
    );
    if (id < 0) throw StateError('The Linux guest refused a session ($id)');

    final session = _IshSession(id, onClosed: (s) => _sessions.remove(s));
    _sessions.add(session);
    return session;
  }

  /// Nothing to reach. The guest is in this process.
  @override
  Future<void> ping() async {}

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    // The machine is deliberately *not* stopped. It cannot be started again in
    // this process, and its init is a loop that exists so nothing can end it —
    // closing a terminal closes that terminal, not the computer.
    for (final session in [..._sessions]) {
      session.close();
    }
  }
}

/// One console on the guest.
class _IshSession implements ShellSession {
  _IshSession(this.id, {required this.onClosed}) {
    _poll = Timer.periodic(_interval, (_) => _drain());
  }

  /// Its handle in the engine — a process there, with a pty of its own.
  final int id;
  final void Function(_IshSession session) onClosed;

  /// Polled rather than pushed, and from Dart rather than a native thread.
  ///
  /// `sbm_ish_read` waits for its timeout, so a blocking read on this isolate
  /// starves the framework — measured: a test that did it never completed. A
  /// non-blocking read on a timer costs one FFI call a frame and needs no port
  /// plumbing; if that ever shows up in a profile, the answer is a native
  /// thread posting to a `SendPort`, not a longer timeout here.
  static const _interval = Duration(milliseconds: 16);

  final _output = StreamController<Uint8List>.broadcast();
  Timer? _poll;
  final _done = Completer<void>();

  void _drain() {
    // Zero, so this returns whatever is there and no more. The wait, if any,
    // is the timer's.
    final chunk = IosRootfs.read(id, timeout: Duration.zero);
    if (chunk == null) {
      // This session ended — its shell exited, or its command finished. The
      // machine is untouched; only this process on it is over.
      _finish();
      return;
    }
    if (chunk.isEmpty) return;
    _output.add(Uint8List.fromList(utf8.encode(chunk)));
  }

  void _finish() {
    if (_done.isCompleted) return;
    _poll?.cancel();
    _poll = null;
    _done.complete();
    _output.close();
    IosRootfs.close(id);
    onClosed(this);
  }

  @override
  Stream<Uint8List>? get stdout => _output.stream;

  /// Null, like every other pseudo-terminal here: a console merges the two the
  /// way a real terminal does.
  @override
  Stream<Uint8List>? get stderr => null;

  @override
  void write(List<int> data) {
    // As typed. The guest's line discipline is what turns a carriage return
    // into a newline, so passing the bytes through is both simpler and the
    // only thing that makes Enter work.
    IosRootfs.write(id, utf8.decode(data, allowMalformed: true));
  }

  @override
  void resizeTerminal(int width, int height) =>
      IosRootfs.resize(id, width, height);

  @override
  Future<void> get done => _done.future;

  @override
  void close() => _finish();
}
