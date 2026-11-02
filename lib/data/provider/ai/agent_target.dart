/// Which machine an Agent tool call is about ([AgentSshTarget]), and the
/// handle a tool works on once it is resolved ([AgentShellHandle]).
library;

import 'package:dartssh2/dartssh2.dart';
import 'package:fl_tty/fl_tty.dart';
import 'package:meta/meta.dart';
import 'package:server_box/core/utils/local_device.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// A machine a tool call is about, ready to be worked on.
///
/// [exec] is how a command runs there. It is the interface the process,
/// service and container pages already use, which is what lets a server
/// reached only over its monitor agent answer at all — it has no `SSHClient`
/// to hand anybody, and asking for one is what used to refuse it.
///
/// [client] is the SSH connection when there is one, and only the file tools
/// need it: SFTP is a byte stream, and there is no equivalent over the agent's
/// HTTP API. Null means those tools have to say so rather than assume.
///
/// [serverId] is null for a connection that is not a configured server — it is
/// what makes a result say "no particular server" rather than name someone
/// else's.
/// [fileTransport] is which protocol carries this host's files, so the file
/// tools open a backend rather than insisting on SFTP — a server told to use
/// `scp` has no subsystem to open.
///
/// [expectedSpi] is the server as it was when this handle was resolved, and
/// null where there is no configured server to compare against. Every await in
/// a tool re-checks it: an edit or a disconnect mid-operation would otherwise
/// leave the tool finishing against the host it started on and reporting the
/// result under the new one's name.
typedef AgentShellHandle = ({
  CommandExec exec,
  SSHClient? client,
  String? serverId,
  SshFileTransport fileTransport,
  Spi? expectedSpi,
});

/// Which machine a shell or file tool call is about.
///
/// The three tools that run something take an [AgentShellHandle] and never ask
/// how the connection behind it was reached. That is the whole point of the
/// type: remote execution is not the same thing as "a server in the list", and
/// the tools have stopped assuming it is.
@immutable
sealed class AgentSshTarget {
  const AgentSshTarget();

  /// Reads the target out of a tool call.
  ///
  /// One place, so that a second kind of target is one case here rather than
  /// a condition in each of the three tools that run something.
  ///
  /// Exactly one, never a default: a call naming both is a model that has lost
  /// track of which machine it is on, and picking one of them for it would run
  /// the command somewhere nobody chose.
  factory AgentSshTarget.fromArguments(AskAiCommand proposal) {
    final serverId = proposal.serverId;
    final sessionId = proposal.sessionId;
    if (serverId != null && sessionId != null) {
      throw const FormatException(
        'Name either server_id or session_id, not both. Drop the one that is '
        'not the machine you mean and call this again.',
      );
    }
    if (sessionId != null) return AdHocSessionTarget(sessionId);
    if (serverId == LocalDevice.id) return const LocalTarget();
    if (serverId != null) return ConfiguredServerTarget(serverId);
    // Says what to do about it, because this is read by the model as the
    // tool's output and it is the whole of what it gets to work from. An
    // omitted argument and an empty one arrive here the same way, so neither
    // is worth naming separately.
    throw const FormatException(
      'Name the machine this is for: server_id for a server in the list, or '
      'session_id for a connection opened with ssh_connect. Exactly one of '
      'the two, and not an empty string.',
    );
  }
}

/// A server the user has configured in the app.
final class ConfiguredServerTarget extends AgentSshTarget {
  const ConfiguredServerTarget(this.serverId);

  final String serverId;
}

/// The machine the app is running on.
///
/// Named through `server_id` rather than a field of its own, so the tools'
/// schema is unchanged and the model has one place to say which machine it
/// means. The reserved id cannot collide with a configured server's — see
/// [LocalDevice.id].
final class LocalTarget extends AgentSshTarget {
  const LocalTarget();
}

/// A host connected to for this conversation only.
final class AdHocSessionTarget extends AgentSshTarget {
  const AdHocSessionTarget(this.sessionId);

  final String sessionId;
}
