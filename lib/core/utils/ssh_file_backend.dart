import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/core/utils/scp_file_backend.dart';
import 'package:server_box/core/utils/sftp_escalation.dart';
import 'package:server_box/core/utils/sftp_file_backend.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// The one place that turns an SSH connection into a [FileBackend].
///
/// Two protocols run over the same connection and the choice is the server's
/// (`SshFileTransport`), so every caller that has a client and a server asks
/// here rather than naming a class. The browser and the transfer isolate are
/// the two, and they used to name [SftpFileBackend] directly — which is
/// precisely how a third protocol becomes a branch in each of them.
Future<FileBackend> openSshFileBackend(
  SSHClient client, {
  required SshFileTransport transport,
  SftpEscalation? escalation,
  Duration? timeout,
}) async {
  switch (transport) {
    case SshFileTransport.sftp:
      try {
        return await SftpFileBackend.connect(
          client,
          escalation: escalation,
          timeout: timeout,
        );
      } catch (e) {
        // Wrapped, not swallowed: the failure is reported as it always was,
        // and the wrapper is only so the page above can add the one sentence
        // that turns "SFTP failed" into something the user can act on. A host
        // that has no subsystem to open fails here every single time, and
        // nothing else in the app says the alternative exists.
        throw SftpUnavailable(e);
      }
    case SshFileTransport.scp:
      // Nothing to open. Every operation takes a channel of its own, so the
      // first failure is the first operation rather than this call.
      return ScpFileBackend(client, escalation: escalation, timeout: timeout);
  }
}

/// The SFTP subsystem would not open on a connection that is otherwise up.
///
/// [toString] is the original's, so the detail shown on screen is unchanged and
/// `classifyFileError` reads the same words it always did.
final class SftpUnavailable implements Exception {
  const SftpUnavailable(this.cause);

  final Object cause;

  @override
  String toString() => '$cause';
}
