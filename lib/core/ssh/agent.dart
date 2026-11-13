import 'dart:async';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/ssh/config.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/src/rust/api/agent_pipe.dart';

/// Whether this build can reach an ssh-agent: a Unix socket, or on Windows a
/// named pipe. The Mac App Store build's sandbox keeps one out of reach.
bool get sshAgentSupported =>
    isLinux || isWindows || (isMacOS && !Pfs.isMacSandboxed);

/// Where Windows' OpenSSH agent listens when `SSH_AUTH_SOCK` says nothing, as
/// its `ssh` assumes.
const windowsAgentPipe = r'\\.\pipe\openssh-ssh-agent';

/// Whether [path] names a Windows named pipe rather than a socket file.
bool isNamedPipe(String path) =>
    RegExp(r'^[\\/]{2}[.?][\\/]pipe[\\/]', caseSensitive: false).hasMatch(path);

/// The agent [ssh] names and the keys it holds; null when it names none.
///
/// An agent that cannot be reached, or one this build cannot reach at all (a
/// server set up on a desktop, synced to a phone), is an error only when it
/// was the one way in: with [hasOtherAuth] (a password, a key) the connection
/// goes on without it, as OpenSSH's does.
Future<({SSHAgentClient client, List<SSHAgentIdentity> keys})?> openSshAgent(
  SshCredential ssh, {
  required bool hasOtherAuth,
  String? originalHost,
}) async {
  final name = ssh.identityAgent;
  if (name == null) return null;
  if (!sshAgentSupported) {
    // Nothing to warn about every connection: the server says which agent it
    // uses on the machine it was set up on.
    if (hasOtherAuth) return null;
    throw SSHErr(type: SSHErrType.agent, message: l10n.sshAgentUnsupported);
  }

  final path =
      SSHConfig.expandIdentityAgent(
        name,
        hostname: ssh.ip,
        remoteUser: ssh.user,
        originalHost: originalHost,
        port: ssh.port,
      ) ??
      (isWindows && name == SshCredential.authSock ? windowsAgentPipe : null);
  if (path == null) {
    return _unavailable(l10n.sshAgentUnset(name), null, hasOtherAuth);
  }
  // dart:io has no Unix sockets on Windows, and Windows' agents listen on
  // pipes: a socket path there is one from another environment (MSYS, WSL).
  if (isWindows && !isNamedPipe(path)) {
    return _unavailable(l10n.sshAgentNotPipe(path), null, hasOtherAuth);
  }
  SSHAgentClient? client;
  try {
    const timeout = Duration(seconds: 5);
    client = SSHAgentClient(
      isWindows
          ? PipeSocket(
              _AgentPipeIo(
                await AgentPipe.connect(
                  path: path,
                  timeoutMs: timeout.inMilliseconds,
                ),
              ),
            )
          : await SSHSocket.connectUnix(path, timeout: timeout),
    );
    return (client: client, keys: await client.identities());
  } catch (e) {
    await client?.close();
    return _unavailable(l10n.sshAgentUnreachable(path, '$e'), e, hasOtherAuth);
  }
}

Null _unavailable(String message, Object? cause, bool hasOtherAuth) {
  if (!hasOtherAuth) {
    throw SSHErr(type: SSHErrType.agent, message: message, cause: cause);
  }
  Loggers.app.warning('$message; trying the other methods', cause);
  return null;
}

/// What [PipeSocket] needs of a pipe: [AgentPipe], or a test's.
abstract interface class PipeIo {
  /// The next bytes; null once the pipe has ended.
  Future<Uint8List?> read();
  Future<void> write(List<int> data);

  /// Ends the connection, and with it a [read] waiting.
  Future<void> close();
}

class _AgentPipeIo implements PipeIo {
  _AgentPipeIo(this._pipe);

  final AgentPipe _pipe;

  @override
  Future<Uint8List?> read() => _pipe.read();

  @override
  Future<void> write(List<int> data) => _pipe.write(data: data);

  @override
  Future<void> close() async {
    await _pipe.close();
    _pipe.dispose();
  }
}

/// A pipe as the socket [SSHAgentClient] reads and writes.
@visibleForTesting
class PipeSocket implements SSHSocket {
  PipeSocket(this._io) {
    unawaited(_readLoop());
    unawaited(_writeLoop());
  }

  final PipeIo _io;
  final _incoming = StreamController<Uint8List>();
  final _outgoing = StreamController<List<int>>();
  final _done = Completer<void>();

  @override
  Stream<Uint8List> get stream => _incoming.stream;

  @override
  StreamSink<List<int>> get sink => _outgoing.sink;

  @override
  Future<void> get done => _done.future;

  Future<void> _readLoop() async {
    try {
      while (!_done.isCompleted) {
        final bytes = await _io.read();
        if (bytes == null || _done.isCompleted) break;
        _incoming.add(bytes);
      }
      await _end();
    } catch (e, s) {
      await _end(e, s);
    }
  }

  Future<void> _writeLoop() async {
    try {
      await for (final bytes in _outgoing.stream) {
        if (_done.isCompleted) break;
        await _io.write(bytes);
      }
    } catch (e, s) {
      await _end(e, s);
    }
  }

  /// Once, whichever comes first: the far end, a failure, or [close]. An
  /// error reaches [done] (where [SSHAgentClient] hears a failed write) and
  /// the stream; nothing is added after.
  Future<void> _end([Object? error, StackTrace? stack]) async {
    if (_done.isCompleted) return;
    if (error == null) {
      _done.complete();
    } else {
      _done.completeError(error, stack);
      _incoming.addError(error, stack);
    }
    unawaited(_incoming.close());
    // Not waited for: a write the pipe never takes ends with it.
    unawaited(_outgoing.close());
    await _io.close();
  }

  @override
  Future<void> close() => _end();

  @override
  void destroy() => unawaited(_end());

  @override
  Future<void> flush() async {}

  @override
  String toString() => 'PipeSocket';
}
