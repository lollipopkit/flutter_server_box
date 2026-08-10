import 'package:server_box/data/model/server/connect_credential.dart';

/// What a server's connection method can actually do.
///
/// The UI asks this instead of testing which transport is in use. Without it,
/// every feature that happens to need a shell has to know that "SSH" is the
/// one that provides it, and adding a third transport means hunting down
/// `is ServerConnectCredentialSsh` checks scattered across the widget tree.
class ServerCapabilities {
  /// Features needing a shell *and* a second channel to run commands on:
  /// SFTP, process list, systemd units, snippets, container management, port
  /// forwarding, power control. In practice this means SSH — monitor's HTTP
  /// API exposes no counterpart for any of them.
  final bool shell;

  /// An interactive terminal can be opened. Implied by [shell], but also true
  /// on its own for a monitor agent offering a passwordless PTY, which is one
  /// stream and therefore a terminal and nothing else.
  ///
  /// Separate from [shell] because the two used to be the same question, and
  /// answering it with one boolean would offer SFTP and port forwarding on a
  /// connection that cannot carry them.
  final bool terminal;

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
    required this.storedHistory,
    required this.persistentSession,
  });

  static const ssh = ServerCapabilities(
    shell: true,
    terminal: true,
    storedHistory: false,
    persistentSession: true,
  );

  /// Status over monitor's HTTP API, with no way to reach a shell.
  static const monitorHttp = ServerCapabilities(
    shell: false,
    terminal: false,
    storedHistory: true,
    persistentSession: false,
  );

  /// Status over monitor's HTTP API, with a passwordless PTY from the agent
  /// (`MonitorHttpCredential.passwordlessTerminal`).
  ///
  /// [shell] stays false: the PTY is a single stream, so everything that
  /// needs a second channel — SFTP, port forwarding, the process and systemd
  /// pages — has nothing to run on.
  static const monitorHttpTerminalOnly = ServerCapabilities(
    shell: false,
    terminal: true,
    storedHistory: true,
    persistentSession: false,
  );

  /// Status over monitor's HTTP API, with SSH reachable through the agent's
  /// tunnel (`SshCredential.viaMonitor`).
  ///
  /// [persistentSession] stays false even though a real `SSHClient` can exist:
  /// it describes the *status* transport, which is still a stateless poll, and
  /// the SSH connection is opened lazily on first shell use rather than held
  /// open for every server that merely could have one.
  static const monitorHttpWithShell = ServerCapabilities(
    shell: true,
    terminal: true,
    storedHistory: true,
    persistentSession: false,
  );

  static ServerCapabilities of(ServerConnectCredential credential) {
    return switch (credential) {
      ServerConnectCredentialSsh() => ssh,
      // Having SSH configured at all is what decides this, whether it is
      // reached directly or through the agent — the features behind it only
      // need an `SSHClient`, not a particular way of getting one. Only when
      // there is none does the agent's own PTY come into it, and that one
      // answers strictly less.
      ServerConnectCredentialMonitorHttp(:final spi, :final monitor) =>
        spi.ssh != null
            ? monitorHttpWithShell
            : monitor.passwordlessTerminal
            ? monitorHttpTerminalOnly
            : monitorHttp,
    };
  }
}
