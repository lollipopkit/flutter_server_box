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

  /// The agent will relay an RDP or VNC connection for this app.
  /// TODO: Remove the legacy-agent missing-field fallback when the minimum
  /// supported Monitor version advertises this capability.
  final bool desktop;

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

  const MonitorRemoteAccess({
    this.terminal = false,
    this.desktop = false,
    this.fullAccess = false,
    this.files = false,
  });

  static const none = MonitorRemoteAccess();

  factory MonitorRemoteAccess.fromJson(Map<String, dynamic> json) {
    bool flag(String key) => json[key] == true;
    return MonitorRemoteAccess(
      terminal: flag('terminal'),
      desktop: flag('desktop'),
      fullAccess: flag('full_access'),
      files: flag('files'),
    );
  }

  @override
  String toString() =>
      'MonitorRemoteAccess(terminal: $terminal, desktop: $desktop, fullAccess: $fullAccess, '
      'files: $files)';

  @override
  bool operator ==(Object other) =>
      other is MonitorRemoteAccess &&
      terminal == other.terminal &&
      desktop == other.desktop &&
      fullAccess == other.fullAccess &&
      files == other.files;

  @override
  int get hashCode => Object.hash(terminal, desktop, fullAccess, files);
}
