import 'package:dartssh2/dartssh2.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/core/ssh/config.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// Whether this build can reach an ssh-agent: a Unix socket, which the Mac
/// App Store build's sandbox keeps out of reach.
///
/// TODO: Windows, whose OpenSSH agent listens on the named pipe
/// `\\.\pipe\openssh-ssh-agent` (#1262).
bool get sshAgentSupported => isLinux || (isMacOS && !Pfs.isMacSandboxed);

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

  final path = SSHConfig.expandIdentityAgent(
    name,
    hostname: ssh.ip,
    remoteUser: ssh.user,
    originalHost: originalHost,
    port: ssh.port,
  );
  if (path == null) {
    return _unavailable(l10n.sshAgentUnset(name), null, hasOtherAuth);
  }
  SSHAgentClient? client;
  try {
    client = SSHAgentClient(
      await SSHSocket.connectUnix(path, timeout: const Duration(seconds: 5)),
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
