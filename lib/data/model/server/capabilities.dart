import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

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
  /// A command can be run and its output read: the process and service pages,
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

  /// Files can be browsed and moved: the file tab, the file button, and either
  /// end of a transfer.
  ///
  /// Its own question rather than [byteStream] read twice, because the two
  /// come apart the moment a `monitor` agent grows a file API — a server with
  /// no reachable sshd would answer false to one and true to the other. Until
  /// then SFTP is the only way files move, so this *is* [byteStream].
  bool get files;

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

  /// What a server can do across every way it is reachable.
  ///
  /// The union, not the preferred transport's answer. A server carrying both
  /// SSH and an agent really can do both sets of things — the agent has
  /// history the app never sampled, sshd has a byte stream the agent has no
  /// endpoint for — and asking "which transport leads" would hide half of
  /// that behind a preference that is about *ordering*, not about ability.
  ///
  /// Which transport a given feature ends up using is decided where it is
  /// used, by whichever can carry it. That is the whole reason these are
  /// questions about a server rather than about a connection.
  static ServerCapabilities ofSpi(
    Spi spi, {
    MonitorRemoteAccess? granted,
  }) {
    final primary = of(
      ServerConnectCredential.fromSpi(spi),
      granted: granted,
    );
    final fallback = ServerConnectCredential.fallbackOf(spi);
    if (fallback == null) return primary;
    return UnionCapabilities(primary, of(fallback, granted: granted));
  }
}

/// Two transports' answers, taken together.
///
/// Deliberately not a class that knows about SSH or about agents: it is the
/// same "either of these can do it" no matter which two it is given, and a
/// third transport would compose the same way.
class UnionCapabilities implements ServerCapabilities {
  const UnionCapabilities(this.a, this.b);

  final ServerCapabilities a;
  final ServerCapabilities b;

  @override
  bool get shell => a.shell || b.shell;

  @override
  bool get terminal => a.terminal || b.terminal;

  @override
  bool get byteStream => a.byteStream || b.byteStream;

  @override
  bool get files => a.files || b.files;

  @override
  bool get storedHistory => a.storedHistory || b.storedHistory;

  /// True when *either* keeps a connection, because the question this answers
  /// is "might a caller be made to wait for one" — and one long-lived
  /// connection is enough to make that so.
  @override
  bool get persistentSession => a.persistentSession || b.persistentSession;

  /// Order does not matter: a union of the same two answers the same either
  /// way round, and which one leads is a preference about ordering rather than
  /// about ability. Without this a server whose preference flipped would
  /// publish a change to every watcher of its capabilities and none of the
  /// answers would differ.
  @override
  bool operator ==(Object other) =>
      other is UnionCapabilities &&
      ((other.a == a && other.b == b) || (other.a == b && other.b == a));

  @override
  int get hashCode => Object.hash(UnionCapabilities, a.hashCode ^ b.hashCode);
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
  bool get files => true;

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
  /// names. A future endpoint would enable this for every agent at once.
  @override
  bool get byteStream => false;

  /// The agent's own answer, from `GET /api/v1/capabilities`.
  ///
  /// Not [byteStream]: the file API is an endpoint of the agent's, confined to
  /// the roots its operator named, and needs no stream this app can point
  /// anywhere. A server with no reachable sshd can browse files and still not
  /// carry SFTP — which is the case the endpoint exists for.
  @override
  bool get files => granted.files;

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
