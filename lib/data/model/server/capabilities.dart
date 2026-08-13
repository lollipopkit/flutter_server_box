import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';

/// What a way of reaching a server can do.
///
/// The questions are the ones the UI has to answer before it offers something:
/// each server function button asks exactly one of them (see
/// `ServerFuncBtn.availableWith`), and the server detail page asks two more.
/// Asking here instead of testing which transport is in use is what keeps
/// every feature that happens to need a shell from knowing that "SSH" is the
/// thing that provides one.
///
/// An interface with one implementation per transport, rather than a bag of
/// booleans somebody fills in: the answers differ per transport for reasons
/// that belong to that transport, and a third one should be a new class here
/// rather than another branch inside a factory. [of] is the only place a
/// credential picks between them.
abstract interface class ServerCapabilities {
  /// A command can be run and its output read: the process and systemd pages,
  /// containers, power control.
  bool get shell;

  /// An interactive terminal can be opened — the terminal page, and the
  /// snippet and iperf buttons, which both end in one.
  ///
  /// Separate from [shell] because they are different questions: one is "can a
  /// shell be had", the other "can anything be run". A transport may grow one
  /// without the other.
  bool get terminal;

  /// Bidirectional byte streams can be opened: SFTP moves file contents, port
  /// forwarding moves a TCP connection.
  ///
  /// Separate from [shell] because a transport can carry a command and its
  /// output without being able to carry a stream — which is exactly a monitor
  /// agent's HTTP API. Offering SFTP on one would open a page that can only
  /// ever fail.
  bool get byteStream;

  /// The transport keeps its own trend history that can prefill the local
  /// buffer (see `StatusHistory.seed`). False means the buffer only ever holds
  /// what this app sampled while the page was open.
  bool get storedHistory;

  /// Whether a connected-but-not-yet-fetched state is observable. A long-lived
  /// connection makes "connected" a real state; a transport that only ever
  /// makes requests has nothing but "has it answered yet".
  bool get persistentSession;

  /// The implementation for how this server is reached.
  ///
  /// [granted] is what the server's agent said it allows, for a monitor
  /// server; ignored for an SSH one, which answers for itself.
  static ServerCapabilities of(
    ServerConnectCredential credential, {
    MonitorRemoteAccess? granted,
  }) {
    return switch (credential) {
      ServerConnectCredentialSsh() => const SshCapabilities(),
      ServerConnectCredentialMonitorHttp() => MonitorHttpCapabilities(
        granted ?? MonitorRemoteAccess.none,
      ),
    };
  }
}

/// An SSH connection, which can do all of it.
///
/// Not because SSH is special, but because every one of these questions was
/// originally asked about SSH: a shell, a PTY and a channel are three things
/// one connection already carries. What it does not have is history — the app
/// samples the machine itself, so a page opened now starts with an empty
/// buffer.
class SshCapabilities implements ServerCapabilities {
  const SshCapabilities();

  /// Every instance describes the same thing, so they are all the same
  /// instance as far as anything watching is concerned. Without this, an
  /// implementation that is `const` compares identical while one built from a
  /// grant never does — and a caller that selects on capabilities would see
  /// one transport never update and the other update constantly.
  @override
  bool operator ==(Object other) => other is SshCapabilities;

  @override
  int get hashCode => (SshCapabilities).hashCode;

  @override
  bool get shell => true;

  @override
  bool get terminal => true;

  @override
  bool get byteStream => true;

  @override
  bool get storedHistory => false;

  @override
  bool get persistentSession => true;
}

/// A `monitor` agent's HTTP API, which can do whatever the agent says it will.
///
/// A monitor server is reached through its agent and nowhere else, so what it
/// can do is the agent's answer alone. It used to be able to carry SSH
/// credentials tunneled to the machine's own sshd; that was a second way to
/// the same place, configured separately, and it meant "what can this server
/// do" had two sources.
class MonitorHttpCapabilities implements ServerCapabilities {
  const MonitorHttpCapabilities(this.granted);

  /// What the agent reported on `GET /api/v1/capabilities`. Defaults to
  /// granting nothing, which is also the answer before the first poll and for
  /// an agent too old to have the endpoint.
  final MonitorRemoteAccess granted;

  /// One grant, not one per feature. Anyone who can open a shell through the
  /// agent can run anything in it, so a second switch for commands would
  /// withhold nothing — it would only make the app pretend. The agent folds
  /// its own transport check into this, so it is already false on a link the
  /// agent would refuse.
  @override
  bool get shell => granted.fullAccess;

  @override
  bool get terminal => granted.fullAccess;

  /// The agent has no endpoint that relays a connection to an address the app
  /// names. That is a missing endpoint rather than a second decision, so this
  /// is not a third switch — it flips for every agent at once when one lands.
  // TODO: `granted.fullAccess` once the agent relays to a named address, the
  // way `MonitorTunnelSocket` did for one fixed address.
  @override
  bool get byteStream => false;

  /// The agent has been sampling since before the app asked, which is the
  /// point of running one.
  @override
  bool get storedHistory => true;

  @override
  bool get persistentSession => false;

  /// Two agents granting the same things answer the same, so a poll that finds
  /// no change publishes no change. See [SshCapabilities.==].
  @override
  bool operator ==(Object other) =>
      other is MonitorHttpCapabilities && other.granted == granted;

  @override
  int get hashCode => Object.hash(MonitorHttpCapabilities, granted);
}
