/// What a `monitor` agent will actually accept on its remote-access
/// endpoints, from `GET /api/v1/capabilities`.
///
/// Reports behaviour rather than configuration: [terminal] already accounts
/// for the agent's transport check, so a client can hide an entry instead of
/// offering one that answers 403.
///
/// Written by hand rather than generated: it is three booleans with a
/// deliberate default of "not offered", which is the answer an older agent
/// (whose `/capabilities` has no `remote_access` at all) should produce.
class MonitorRemoteAccess {
  /// The agent will serve a terminal over this connection.
  final bool terminal;

  /// The agent will let this app reach the machine with no SSH credentials —
  /// a shell, a command, a forwarded port — as the account it runs as.
  ///
  /// The agent re-checks this when each request arrives. The app uses it only
  /// to decide which actions to offer.
  final bool fullAccess;

  /// The agent will serve `/api/v1/fs/*`.
  ///
  /// Its own answer rather than part of [fullAccess]: the agent's file API is
  /// confined to the roots its operator named, so it can be on while the shell
  /// is off. False also for an agent too old to have the endpoint, which is
  /// what the default gives.
  final bool files;

  /// The agent will relay a TCP connection to an address this app names.
  ///
  /// Granted by the same switch as [fullAccess] — anyone who can open a shell
  /// can `ssh -L` from it, so withholding this would withhold nothing — but a
  /// separate answer for a client: an agent older than the endpoint reports
  /// `full_access` and would still refuse the upgrade, and this is what says
  /// which of the two it is.
  final bool stream;

  const MonitorRemoteAccess({
    this.terminal = false,
    this.fullAccess = false,
    this.files = false,
    this.stream = false,
  });

  static const none = MonitorRemoteAccess();

  factory MonitorRemoteAccess.fromJson(Map<String, dynamic> json) {
    bool flag(String key) => json[key] == true;
    return MonitorRemoteAccess(
      terminal: flag('terminal'),
      fullAccess: flag('full_access'),
      files: flag('files'),
      stream: flag('stream'),
    );
  }

  @override
  String toString() =>
      'MonitorRemoteAccess(terminal: $terminal, fullAccess: $fullAccess, '
      'files: $files, stream: $stream)';

  @override
  bool operator ==(Object other) =>
    other is MonitorRemoteAccess &&
       terminal == other.terminal &&
       fullAccess == other.fullAccess &&
       files == other.files &&
       stream == other.stream;

  @override
  int get hashCode => Object.hash(terminal, fullAccess, files, stream);
}
