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

  _IshSession? _session;
  var _closed = false;

  @override
  bool get isClosed => _closed;

  /// No. A second command needs a second channel, and there is one console.
  ///
  /// The Agent's shell tool and tmux both ask this before using it, so
  /// answering honestly here is what keeps them off a path that would
  /// interleave two commands' output on one terminal.
  @override
  bool get supportsExec => false;

  @override
  Future<ShellSession> openShell({
    required int width,
    required int height,
    Map<String, String>? environment,
  }) async {
    if (_closed) throw StateError('This guest has been closed');
    // The same one, if there is one. `sbm_ish_boot` refuses a second guest
    // rather than corrupting the first, and a session that silently attached
    // to a refusal would look like a terminal that never answers.
    final existing = _session;
    if (existing != null) return existing;

    final err = IosRootfs.boot('', columns: width, rows: height);
    // -EEXIST: a guest is already running, from an earlier session in this
    // process. Attaching to it is right — it is the machine.
    if (err < 0 && err != -17) {
      throw StateError('The Linux guest did not start ($err)');
    }
    return _session = _IshSession(onClosed: () => _session = null);
  }

  @override
  Future<ShellSession> execute(
    String command, {
    required int width,
    required int height,
    Map<String, String>? environment,
  }) {
    // [supportsExec] says so; this is the path a caller takes anyway if it
    // ignored that, and a clear refusal beats interleaved output.
    throw StateError('The Linux guest runs one console; use openShell');
  }

  /// Nothing to reach. The guest is in this process.
  @override
  Future<void> ping() async {}

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    // The guest is deliberately *not* stopped. It is the app's one machine,
    // it cannot be started again in this process, and its init is a loop that
    // exists so nothing can end it — closing a terminal is closing a view of
    // it, not switching the computer off.
    _session?.close();
  }
}

/// One console on the guest.
class _IshSession implements ShellSession {
  _IshSession({required this.onClosed}) {
    _poll = Timer.periodic(_interval, (_) => _drain());
  }

  final void Function() onClosed;

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
    final chunk = IosRootfs.read(timeout: Duration.zero);
    if (chunk == null) {
      // The guest ended, which on iOS also means the app is going: init is a
      // loop precisely so this does not happen. Reported all the same, so a
      // page that outlives it shows a closed terminal rather than a live one.
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
    onClosed();
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
    IosRootfs.write(utf8.decode(data, allowMalformed: true));
  }

  @override
  void resizeTerminal(int width, int height) =>
      IosRootfs.resize(width, height);

  @override
  Future<void> get done => _done.future;

  @override
  void close() => _finish();
}
