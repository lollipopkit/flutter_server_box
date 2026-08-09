import 'package:server_box/data/model/server/connect_credential.dart';

/// What a server's connection method can actually do.
///
/// The UI asks this instead of testing which transport is in use. Without it,
/// every feature that happens to need a shell has to know that "SSH" is the
/// one that provides it, and adding a third transport means hunting down
/// `is ServerConnectCredentialSsh` checks scattered across the widget tree.
class ServerCapabilities {
  /// Shell-backed features: terminal, SFTP, process list, systemd units,
  /// snippets, container management, port forwarding, power control.
  /// monitor's HTTP API exposes no counterpart for any of them.
  final bool shell;

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
    required this.storedHistory,
    required this.persistentSession,
  });

  static const ssh = ServerCapabilities(
    shell: true,
    storedHistory: false,
    persistentSession: true,
  );

  static const monitorHttp = ServerCapabilities(
    shell: false,
    storedHistory: true,
    persistentSession: false,
  );

  static ServerCapabilities of(ServerConnectCredential credential) {
    return switch (credential) {
      ServerConnectCredentialSsh() => ssh,
      ServerConnectCredentialMonitorHttp() => monitorHttp,
    };
  }
}
