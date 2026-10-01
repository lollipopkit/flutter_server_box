import 'package:server_box/data/model/server/monitor_grants.dart';

/// What a `monitor` agent will actually accept on its remote-access
/// endpoints, from `GET /api/v1/capabilities`.
///
/// Reports behaviour rather than configuration: [terminal] already accounts
/// for the agent's transport check, so a client can hide an entry instead of
/// offering one that answers 403.
///
/// Written by hand rather than generated: it is a few booleans with a
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

  /// The agent will listen on a port of the server's and hand each connection
  /// to this app: a remote port forward, over `/api/v1/listen/ws`.
  ///
  /// The same grant as [stream], for the same reason, and its own answer for
  /// the same reason too: an agent older than the endpoint relays and still
  /// cannot listen.
  final bool listen;

  /// The agent's per-grant answer, with why one is not usable — null for an
  /// agent older than roles (`docs/dev/monitor-permissions.md`), which says
  /// only the booleans above.
  ///
  /// When present the booleans are derived from it, as the agent derives its
  /// own legacy fields: one source, so the two cannot disagree.
  final MonitorGrants? grants;

  const MonitorRemoteAccess({
    this.terminal = false,
    this.fullAccess = false,
    this.files = false,
    this.stream = false,
    this.listen = false,
    this.grants,
  });

  /// [grants] as the booleans every other part of the app asks.
  factory MonitorRemoteAccess.ofGrants(MonitorGrants grants) =>
      MonitorRemoteAccess(
        terminal: grants.shell.ok || grants.sshTerminal.ok,
        fullAccess: grants.shell.ok,
        files: grants.files.ok,
        stream: grants.connect.ok,
        listen: grants.listen.ok,
        grants: grants,
      );

  static const none = MonitorRemoteAccess();

  /// [grants] is `capabilities.grants`, which wins over [json] when there.
  factory MonitorRemoteAccess.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? grants,
  }) {
    if (grants != null) {
      return MonitorRemoteAccess.ofGrants(MonitorGrants.fromJson(grants));
    }
    bool flag(String key) => json[key] == true;
    return MonitorRemoteAccess(
      terminal: flag('terminal'),
      fullAccess: flag('full_access'),
      files: flag('files'),
      stream: flag('stream'),
      listen: flag('listen'),
    );
  }

  @override
  String toString() =>
      'MonitorRemoteAccess(terminal: $terminal, fullAccess: $fullAccess, '
      'files: $files, stream: $stream, listen: $listen, grants: $grants)';

  @override
  bool operator ==(Object other) =>
    other is MonitorRemoteAccess &&
       terminal == other.terminal &&
       fullAccess == other.fullAccess &&
       files == other.files &&
       stream == other.stream &&
       listen == other.listen &&
       grants == other.grants;

  @override
  int get hashCode =>
      Object.hash(terminal, fullAccess, files, stream, listen, grants);
}
