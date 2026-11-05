import 'dart:async';

import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/core/ssh/algorithms.dart';
import 'package:server_box/core/ssh/host_keys.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// The host key [ssh]'s server presents, read in the handshake and refused
/// before anything is sent to sign in. Null when it does not answer within
/// [timeout], connecting included.
///
/// Proposes what a connection to [ssh] would, with [prefer] first when given:
/// a server whose key was remembered under that type negotiates it again.
Future<HostKeyId?> probeHostKey(
  SshCredential ssh, {
  String? prefer,
  Duration timeout = const Duration(seconds: 4),
}) async {
  SSHSocket? socket;
  SSHClient? client;
  final found = Completer<HostKeyId?>();
  Future<void> run() async {
    final connected = await SSHSocket.connect(
      ssh.ip,
      ssh.port,
      timeout: timeout,
    );
    // Too late: the caller has given up, and `finally` has run.
    if (found.isCompleted) {
      connected.destroy();
      return;
    }
    socket = connected;
    client = SSHClient(
      socket!,
      username: ssh.user,
      algorithms: SshAlgorithms.of(
        ssh,
        pinnedKeyTypes: {?prefer},
      ),
      onVerifyHostKey: (type, fingerprint) {
        if (!found.isCompleted) {
          found.complete((
            type: type,
            fingerprint: fingerprintToOpenSsh(fingerprint),
          ));
        }
        return false;
      },
    );
    await client!.done;
  }

  final timer = Timer(timeout, () {
    if (!found.isCompleted) found.complete(null);
  });
  try {
    unawaited(
      run().then(
        (_) {
          if (!found.isCompleted) found.complete(null);
        },
        onError: (Object _) {
          // Refused, unreachable or not SSH: nothing to tell it apart by.
          if (!found.isCompleted) found.complete(null);
        },
      ),
    );
    return await found.future;
  } finally {
    timer.cancel();
    client?.close();
    socket?.destroy();
  }
}
