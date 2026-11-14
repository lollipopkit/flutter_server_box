import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:server_box/core/ssh/config.dart';
import 'package:server_box/core/ssh/owning_socket.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/src/rust/api/control_master.dart';

/// Whether this platform can ask an OpenSSH master for a stream: a
/// Unix-domain socket and descriptor passing. Windows' OpenSSH has no
/// multiplexing.
bool get controlMasterSupported => isLinux || isMacOS;

/// A stream to [host]:[port] from the OpenSSH master [jump] names
/// (`SshCredential.controlPath`), as `ssh -W host:port` asks one; null when
/// there is no master to use, so the caller connects through [jump] itself.
///
/// The master opens the stream and the caller authenticates over it as over
/// any other: the master's own session is never used.
///
/// Throws [SSHErr] when a master refuses the stream: the target it cannot
/// reach, a connection of the caller's own through [jump] cannot either.
Future<SSHSocket?> openThroughMaster(
  Spi jump, {
  required String host,
  required int port,
  required Duration timeout,
}) async {
  final ssh = jump.ssh;
  final template = ssh?.controlPath;
  if (ssh == null || template == null || !controlMasterSupported) return null;
  final path = SSHConfig.expandControlPath(
    template,
    hostname: ssh.ip,
    remoteUser: ssh.user,
    originalHost: jump.name,
    port: ssh.port,
  );
  if (path == null) {
    Loggers.app.info('ControlPath $template of ${jump.name} names nothing');
    return null;
  }
  if (await FileSystemEntity.type(path) != FileSystemEntityType.unixDomainSock) {
    return null;
  }

  // The master is handed a connection to here: a directory of this process's
  // own (mkdtemp, 0700), and the first bytes on it a token only this process
  // and the Rust side know, so a connection anyone else makes is turned away.
  final dir = await Directory.systemTemp.createTemp('sbmux');
  final stdioPath = '${dir.path}/s';
  final token = Uint8List.fromList(
    List.generate(16, (_) => Random.secure().nextInt(256)),
  );
  ServerSocket? listener;
  StdioAccept? accepted;
  try {
    listener = await ServerSocket.bind(
      InternetAddress(stdioPath, type: InternetAddressType.unix),
      0,
    );
    accepted = StdioAccept(listener, token);
    final MuxForward forward;
    try {
      forward = await MuxForward.open(
        controlPath: path,
        stdioPath: stdioPath,
        token: token,
        host: host,
        port: port,
        timeoutMs: timeout.inMilliseconds,
      );
    } on MuxError catch (e) {
      if (e.unreachable) {
        Loggers.app.info('No OpenSSH master to use at $path: ${e.message}');
        return null;
      }
      throw SSHErr(
        type: SSHErrType.connect,
        message: 'OpenSSH master ${jump.name}: channel open failed: ${e.message}',
        cause: e,
      );
    } on SSHErr {
      rethrow;
    } catch (e, st) {
      // The library itself (an isolate without it): connected the usual way.
      Loggers.app.warning('OpenSSH master unusable', e, st);
      return null;
    }
    try {
      final socket = await accepted.socket.timeout(timeout);
      return OwningSocket(socket, () {
        forward.close().whenComplete(forward.dispose).ignore();
      });
    } catch (_) {
      await forward.close();
      forward.dispose();
      rethrow;
    }
  } finally {
    // Whatever was accepted is the caller's now; the listener and its file
    // are nobody's.
    accepted?.cancel();
    unawaited(listener?.close());
    unawaited(dir.delete(recursive: true).then((_) {}, onError: (_) {}));
  }
}

/// The connection on a listener whose first bytes are [_token], with them
/// taken off; any other is closed.
@visibleForTesting
class StdioAccept {
  StdioAccept(ServerSocket listener, this._token) {
    _subscription = listener.listen(_check, onError: (_) {});
  }

  final Uint8List _token;
  late final StreamSubscription<Socket> _subscription;
  final _result = Completer<SSHSocket>();
  final _pending = <Socket>{};

  Future<SSHSocket> get socket => _result.future;

  void _check(Socket socket) {
    _pending.add(socket);
    final head = BytesBuilder(copy: false);
    late final StreamSubscription<Uint8List> sub;
    final rest = StreamController<Uint8List>(
      onPause: () => sub.pause(),
      onResume: () => sub.resume(),
      onCancel: () => sub.cancel(),
    );
    var matched = false;
    sub = socket.listen(
      (data) {
        if (matched) return rest.add(data);
        head.add(data);
        if (head.length < _token.length) return;
        final bytes = head.takeBytes();
        if (_result.isCompleted ||
            !const ListEquality<int>().equals(
              bytes.sublist(0, _token.length),
              _token,
            )) {
          _pending.remove(socket);
          socket.destroy();
          sub.cancel();
          return;
        }
        matched = true;
        _pending.remove(socket);
        _result.complete(_StdioSocket(socket, rest.stream));
        if (bytes.length > _token.length) {
          rest.add(Uint8List.sublistView(bytes, _token.length));
        }
      },
      onError: (Object e, StackTrace st) =>
          matched ? rest.addError(e, st) : socket.destroy(),
      onDone: () {
        _pending.remove(socket);
        if (matched) rest.close();
      },
    );
  }

  /// Stops listening; a connection not yet matched is closed.
  void cancel() {
    _subscription.cancel();
    // A copy: destroying one ends it, and that takes it off [_pending].
    for (final socket in [..._pending]) {
      socket.destroy();
    }
    _pending.clear();
  }
}

/// The matched connection, read from past its token.
class _StdioSocket implements SSHSocket {
  _StdioSocket(this._socket, this.stream);

  final Socket _socket;

  @override
  final Stream<Uint8List> stream;

  @override
  StreamSink<List<int>> get sink => _socket;

  @override
  Future<void> get done => _socket.done;

  @override
  Future<void> close() => _socket.close();

  @override
  void destroy() => _socket.destroy();

  @override
  Future<void> flush() => _socket.flush();

  @override
  String toString() => '_StdioSocket';
}
