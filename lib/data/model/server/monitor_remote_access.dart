/// What a `monitor` agent will actually accept on its remote-access
/// endpoints, from `GET /api/v1/capabilities`.
///
/// Reports behaviour rather than configuration: [terminal] already accounts
/// for the agent's transport check, so a client can hide an entry instead of
/// offering one that answers 403. [secure] is reported separately so it can
/// explain *why* — an agent on plaintext HTTP serves the tunnel but refuses
/// the terminal, since the tunnel carries end-to-end encrypted SSH and the
/// terminal carries cleartext shell output.
///
/// Written by hand rather than generated: it is five booleans with a
/// deliberate default of "not offered", which is the answer an older agent
/// (whose `/capabilities` has no `remote_access` at all) should produce.
class MonitorRemoteAccess {
  /// The agent will relay an SSH byte stream to its configured `ssh_addr`.
  final bool tunnel;

  /// The agent will serve a terminal over this connection.
  final bool terminal;

  /// The link is TLS or loopback. False means [terminal] is off *because of
  /// the transport*, and configuring TLS would turn it on.
  final bool secure;

  /// The agent will let this app reach the machine with no SSH credentials —
  /// a shell, a command, a forwarded port — as the account it runs as.
  ///
  /// Always re-checked by the agent when the request arrives; this is what the
  /// app asks in order to know what to offer, rather than asking the user to
  /// assert something the agent already knows.
  final bool fullAccess;

  /// The agent will serve `/api/v1/fs/*`.
  ///
  /// Its own answer rather than part of [fullAccess]: the agent's file API is
  /// confined to the roots its operator named, so it can be on while the shell
  /// is off. False also for an agent too old to have the endpoint, which is
  /// what the default gives.
  final bool files;

  const MonitorRemoteAccess({
    this.tunnel = false,
    this.terminal = false,
    this.secure = false,
    this.fullAccess = false,
    this.files = false,
  });

  static const none = MonitorRemoteAccess();

  factory MonitorRemoteAccess.fromJson(Map<String, dynamic> json) {
    bool flag(String key) => json[key] == true;
    return MonitorRemoteAccess(
      tunnel: flag('tunnel'),
      terminal: flag('terminal'),
      secure: flag('secure'),
      fullAccess: flag('full_access'),
      files: flag('files'),
    );
  }

  @override
  String toString() =>
      'MonitorRemoteAccess(tunnel: $tunnel, terminal: $terminal, '
      'secure: $secure, fullAccess: $fullAccess, files: $files)';

  @override
  bool operator ==(Object other) =>
      other is MonitorRemoteAccess &&
      tunnel == other.tunnel &&
      terminal == other.terminal &&
      secure == other.secure &&
      fullAccess == other.fullAccess &&
      files == other.files;

  @override
  int get hashCode => Object.hash(tunnel, terminal, secure, fullAccess, files);
}
