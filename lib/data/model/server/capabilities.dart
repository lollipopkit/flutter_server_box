import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';

/// What a server's connection method can actually do.
///
/// The UI asks this instead of testing which transport is in use. Without it,
/// every feature that happens to need a shell has to know that "SSH" is the
/// one that provides it, and adding a third transport means hunting down
/// `is ServerConnectCredentialSsh` checks scattered across the widget tree.
class ServerCapabilities {
  /// Features that need to reach the machine rather than just read a status
  /// from it: SFTP, the process and systemd pages, snippets, containers, port
  /// forwarding, power control.
  ///
  /// True over SSH, however that SSH is reached, and true for a monitor agent
  /// told to grant full access — which is the same grant its panel login
  /// already carries.
  final bool shell;

  /// An interactive terminal can be opened. Implied by [shell] everywhere it
  /// is true today, and kept separate because the two are different questions:
  /// one is "can a shell be had", the other "can anything be run".
  ///
  /// Separate from [shell] because the two used to be the same question, and
  /// answering it with one boolean would offer SFTP and port forwarding on a
  /// connection that cannot carry them.
  final bool terminal;

  /// Bidirectional byte streams can be opened: SFTP moves file contents, port
  /// forwarding moves a TCP connection.
  ///
  /// Separate from [shell] because a transport can carry a command and its
  /// output without being able to carry a stream — which is exactly a monitor
  /// agent's HTTP API. Offering SFTP on one would open a page that can only
  /// ever fail.
  // TODO: true for a full-access agent once it relays a connection to an
  // address the caller names, the way `MonitorTunnelSocket` did for one fixed
  // address.
  final bool byteStream;

  /// The source keeps its own trend history that can prefill the local buffer
  /// (see `StatusHistory.seed`). False means the buffer only ever holds what
  /// this app sampled while the page was open.
  final bool storedHistory;

  /// Whether a connected-but-not-yet-fetched state is observable. SSH holds a
  /// long-lived client, so "connected" is a real state; a stateless HTTP
  /// transport only ever has "has it answered yet".
  final bool persistentSession;

  const ServerCapabilities({
    required this.shell,
    required this.terminal,
    required this.byteStream,
    required this.storedHistory,
    required this.persistentSession,
  });

  static const ssh = ServerCapabilities(
    shell: true,
    terminal: true,
    byteStream: true,
    storedHistory: false,
    persistentSession: true,
  );

  /// Status over monitor's HTTP API, with no way to reach a shell.
  static const monitorHttp = ServerCapabilities(
    shell: false,
    terminal: false,
    byteStream: false,
    storedHistory: true,
    persistentSession: false,
  );

  /// Status over monitor's HTTP API, with the agent granting full access
  /// (`MonitorHttpCredential.fullAccess`).
  ///
  /// One switch, not one per feature. The agent's own grant is what decides
  /// this: with it the app can open a shell, run a command and reach a port
  /// through the agent, all of which the panel login already implied — anyone
  /// who can get a shell can run anything in it. Splitting them would have
  /// been three switches describing one decision.
  ///
  /// [byteStream] is false while the agent has no way to relay a connection to
  /// an address the app names; that is a missing endpoint, not a second
  /// decision, and it flips to true for everyone once the agent grows one.
  static const monitorHttpFullAccess = ServerCapabilities(
    shell: true,
    terminal: true,
    byteStream: false,
    storedHistory: true,
    persistentSession: false,
  );

  static ServerCapabilities of(
    ServerConnectCredential credential, {
    MonitorRemoteAccess? granted,
  }) {
    return switch (credential) {
      ServerConnectCredentialSsh() => ssh,
      // A monitor server is reached through its agent and nowhere else, so
      // what it can do is the agent's answer alone. It used to be able to
      // carry SSH credentials tunneled to the machine's own sshd; that was a
      // second way to the same place, configured separately, and it meant
      // "what can this server do" had two sources.
      ServerConnectCredentialMonitorHttp() =>
        (granted?.fullAccess ?? false) ? monitorHttpFullAccess : monitorHttp,
    };
  }
}
