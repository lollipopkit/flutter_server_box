import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/utils/ios_rootfs.dart';
import 'package:server_box/core/utils/ish_exec.dart';
import 'package:server_box/data/model/app/error.dart';

/// A ProxyCommand on iOS: the command in the Linux guest, its terminal turned
/// into a byte pipe.
///
/// iOS starts no processes, so there is no stdin and stdout to hand SSH as
/// there is everywhere else. What the engine offers is a session on a
/// terminal, and a terminal is not a pipe: it echoes input, turns `\r` into
/// `\n`, and takes `^C` for a signal — any of which, applied to SSH's bytes,
/// breaks the connection in a way that looks like the server's fault. So the
/// session first puts its terminal in raw mode, where the engine's line
/// discipline passes bytes through untouched (`fs/tty.c`: no echo, no
/// translation and no signals outside canonical mode, and no output
/// processing without `OPOST`), and only then runs the command.
///
/// Until it has, anything written would still be echoed back into the stream,
/// and SSH writes its version line the moment it connects. So the session
/// prints [readyMarker] once the terminal is raw, and nothing is written — or
/// read as the command's output — before it arrives.
///
/// The command's stderr goes to a file, not the terminal: on a terminal it
/// would be mixed into SSH's bytes. It is logged when the session ends, as the
/// desktop logs a process's stderr.
final class IshProxySocket implements SSHSocket {
  IshProxySocket._(this._session, this._files, this._errFile);

  /// Printed by the session once its terminal is raw. Control characters on
  /// both sides, so no shell output or login banner produces it by accident.
  @visibleForTesting
  static const readyMarker = '\u0001SBM-PROXY-READY\u0002';
  static final _marker = utf8.encode(readyMarker);

  /// How often the session is looked at: a terminal's frame, as [IshExec]'s.
  static const _interval = Duration(milliseconds: 16);

  /// Reads per look, so a burst is taken in one frame rather than 8 KB a
  /// frame — which was a ceiling of about 500 KB/s on an SFTP transfer.
  static const _readsPerTick = 64;

  /// Output held while waiting for [readyMarker]. A shell that prints this
  /// much before it is the wrong command, not a slow one.
  static const _preambleLimit = 64 * 1024;

  final int _session;
  final List<File> _files;
  final File _errFile;

  final _incoming = StreamController<Uint8List>();
  final _outgoing = StreamController<List<int>>();
  final _pending = ListQueue<Uint8List>();
  var _pendingOffset = 0;
  final _done = Completer<void>();
  final _ready = Completer<void>();
  final _preamble = BytesBuilder(copy: false);
  var _isReady = false;
  var _closed = false;

  /// Whether the command has sent anything. A proxy that ends before it
  /// has — `nc` not installed, a host it could not reach — failed, and what
  /// it wrote to stderr is the reason.
  var _receivedAny = false;
  Timer? _timer;
  final _drained = <Completer<void>>[];

  /// Why bytes handed to [sink] were not delivered, once one was refused.
  /// What [flush] answers from then on, so a caller does not take bytes that
  /// never reached the proxy for sent ones.
  SSHErr? _writeError;

  static Future<SSHSocket> connect({
    required String command,
    Duration? timeout,
  }) async {
    final root = IosRootfs.root;
    if (root == null || !IosRootfs.isReadySync) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: l10n.proxyCommandNeedsLinux,
      );
    }
    final booted = IosRootfs.boot();
    if (booted < 0 && booted != IosRootfs.alreadyBooted) {
      throw SSHErr(
        type: SSHErrType.connect,
        message: 'The Linux guest did not start ($booted)',
      );
    }

    final name = '.sbm-proxy-${ShortId.generate()}';
    final directory = Directory(root.joinPath('tmp'));
    await directory.create(recursive: true);
    final errFile = File('${directory.path}/$name.err');
    final files = <File>[errFile];

    final script = wrap(command, err: '/tmp/$name.err');
    var opened = script;
    if (IshExec.needsFile(script)) {
      final file = File('${directory.path}/$name.sh');
      await file.writeAsString(script);
      files.add(file);
      opened = "sh '/tmp/$name.sh'";
    }

    final id = IosRootfs.open(command: opened);
    if (id < 0) {
      await _remove(files);
      throw SSHErr(
        type: SSHErrType.connect,
        message: 'The Linux guest refused a session ($id)',
      );
    }

    final socket = IshProxySocket._(id, files, errFile).._start();
    try {
      final ready = socket._ready.future;
      await (timeout == null ? ready : ready.timeout(timeout));
    } on TimeoutException {
      await socket.close();
      throw SSHErr(
        type: SSHErrType.connect,
        message:
            'ProxyCommand did not start within ${timeout!.inSeconds}s.',
      );
    } catch (_) {
      await socket.close();
      rethrow;
    }
    return socket;
  }

  /// [command], run once the terminal is a pipe.
  ///
  /// `stty` failing ends the session rather than leaving a terminal that would
  /// corrupt the stream; `exec` makes the proxy the session's own process, so
  /// the session ends when it does.
  @visibleForTesting
  static String wrap(String command, {required String err}) {
    String quoted(String value) => "'${value.replaceAll("'", r"'\''")}'";
    return 'stty raw -echo || exit 97; '
        r"printf '\001SBM-PROXY-READY\002'; "
        'exec sh -c ${quoted(command)} 2>${quoted(err)}';
  }

  void _start() {
    _outgoing.stream.listen(
      (data) {
        if (_closed || data.isEmpty) return;
        _pending.add(data is Uint8List ? data : Uint8List.fromList(data));
      },
      onDone: () => unawaited(close()),
    );
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void _tick() {
    if (_closed) return;
    try {
      for (var i = 0; i < _readsPerTick; i++) {
        final chunk = IosRootfs.read(_session, timeout: Duration.zero);
        if (chunk == null) {
          unawaited(_finish());
          return;
        }
        if (chunk.isEmpty) break;
        _receive(chunk);
      }
      if (_isReady) _flushPending();
    } catch (e, s) {
      if (!_ready.isCompleted) _ready.completeError(e, s);
      _incoming.addError(e, s);
      unawaited(_finish());
    }
  }

  void _receive(Uint8List chunk) {
    if (_isReady) {
      _receivedAny = true;
      _incoming.add(chunk);
      return;
    }
    _preamble.add(chunk);
    final seen = _preamble.toBytes();
    final at = indexOf(seen, _marker);
    if (at < 0) {
      if (seen.length > _preambleLimit) {
        _ready.completeError(
          SSHErr(
            type: SSHErrType.connect,
            message: 'ProxyCommand did not start: ${_text(seen)}',
          ),
        );
        unawaited(_finish());
      }
      return;
    }
    _isReady = true;
    final rest = seen.sublist(at + _marker.length);
    if (rest.isNotEmpty) {
      _receivedAny = true;
      _incoming.add(Uint8List.fromList(rest));
    }
    _ready.complete();
  }

  void _flushPending() {
    while (_pending.isNotEmpty) {
      final head = _pending.first;
      final left = Uint8List.sublistView(head, _pendingOffset);
      final written = IosRootfs.tryWrite(_session, left);
      if (written < 0) {
        _writeError = SSHErr(
          type: SSHErrType.connect,
          message: 'ProxyCommand: the guest refused input ($written)',
        );
        unawaited(_finish());
        return;
      }
      if (written == 0) return;
      _pendingOffset += written;
      if (_pendingOffset >= head.length) {
        _pending.removeFirst();
        _pendingOffset = 0;
      }
    }
    for (final waiter in _drained) {
      waiter.complete();
    }
    _drained.clear();
  }

  /// The first index of [pattern] in [bytes], or -1.
  @visibleForTesting
  static int indexOf(List<int> bytes, List<int> pattern) {
    outer:
    for (var i = 0; i + pattern.length <= bytes.length; i++) {
      for (var j = 0; j < pattern.length; j++) {
        if (bytes[i + j] != pattern[j]) continue outer;
      }
      return i;
    }
    return -1;
  }

  static String _text(List<int> bytes) =>
      utf8.decode(bytes, allowMalformed: true).trim();

  Future<void> _finish() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    final exitCode = IosRootfs.exitCode(_session);
    IosRootfs.close(_session);
    final stderr = await _readErr();
    if (!_ready.isCompleted) {
      final said = [_text(_preamble.toBytes()), stderr]
          .where((e) => e.isNotEmpty)
          .join('\n');
      _ready.completeError(
        SSHErr(
          type: SSHErrType.connect,
          message: exitCode == 97
              ? 'ProxyCommand: the terminal could not be made raw.'
              : 'ProxyCommand exited before connecting'
                    '${exitCode == null ? '' : ' ($exitCode)'}'
                    '${said.isEmpty ? '.' : ': $said'}',
        ),
      );
    } else if (!_receivedAny && stderr.isNotEmpty) {
      // Said on the stream, where SSH reports it as the connection's failure,
      // rather than only in a log nobody reading the error will open.
      _incoming.addError(
        SSHErr(
          type: SSHErrType.connect,
          message: 'ProxyCommand exited: $stderr',
        ),
      );
    } else if (stderr.isNotEmpty) {
      Loggers.app.warning('ProxyCommand stderr: $stderr');
    }
    await _remove(_files);
    final writeError = _writeError;
    for (final waiter in _drained) {
      if (writeError == null) {
        waiter.complete();
      } else {
        waiter.completeError(writeError);
      }
    }
    _drained.clear();
    // Not awaited: a single-subscription controller's close completes only
    // once someone has listened, and a failed connect never is.
    unawaited(_incoming.close());
    unawaited(_outgoing.close());
    if (!_done.isCompleted) _done.complete();
  }

  /// The command's stderr, capped as the desktop caps it.
  Future<String> _readErr() async {
    const maxLoggedBytes = 4096;
    try {
      final bytes = await _errFile.readAsBytes();
      final capped = bytes.length <= maxLoggedBytes
          ? bytes
          : bytes.sublist(0, maxLoggedBytes);
      final text = _text(capped);
      return bytes.length > maxLoggedBytes ? '$text [truncated]' : text;
    } catch (_) {
      return '';
    }
  }

  static Future<void> _remove(List<File> files) async {
    for (final file in files) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> get done => _done.future;

  @override
  Future<void> flush() {
    final writeError = _writeError;
    if (writeError != null) return Future.error(writeError);
    if (_closed || _pending.isEmpty) return Future.value();
    final waiter = Completer<void>();
    _drained.add(waiter);
    return waiter.future;
  }

  @override
  Future<void> close() => _finish();

  @override
  void destroy() => unawaited(_finish());

  @override
  String toString() => 'IshProxySocket(session: $_session)';
}
