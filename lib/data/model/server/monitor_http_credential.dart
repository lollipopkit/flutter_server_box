import 'package:json_annotation/json_annotation.dart';

part 'monitor_http_credential.g.dart';

/// Connection info for reaching a server via its `monitor` instance's HTTP
/// API instead of SSH+shell. Lives directly on [Spi], as a peer of the SSH
/// connection fields (`ip`/`port`/`user`/`pwd`/`keyId`) — this is a second,
/// equally first-class way to reach the data-fetch layer, not a misc
/// per-server setting (those live in `ServerCustom`).
@JsonSerializable(includeIfNull: false)
final class MonitorHttpCredential {
  /// e.g. `https://1.2.3.4:3770`
  final String addr;

  final String? user;

  final String? pwd;

  final bool ignoreCert;

  /// Open a terminal through the agent with no SSH credentials, as the
  /// account the agent runs as.
  ///
  /// Off by default, and only ever a request: the agent decides whether to
  /// offer this at all (`remote_access.passwordless_terminal`) and re-checks
  /// when the connection arrives. What it costs is that the monitor password
  /// becomes equivalent to a shell on that machine — with none of sshd's
  /// authentication, logging or second factor — which is why it is a separate,
  /// deliberate switch rather than something implied by configuring monitor.
  ///
  /// Mutually exclusive with [SshCredential.viaMonitor]: both answer "where
  /// does this server's shell come from", and [Spix.validate] enforces it.
  @JsonKey(defaultValue: false)
  final bool passwordlessTerminal;

  const MonitorHttpCredential({
    required this.addr,
    this.user,
    this.pwd,
    this.ignoreCert = false,
    this.passwordlessTerminal = false,
  });

  factory MonitorHttpCredential.fromJson(Map<String, dynamic> json) =>
      _$MonitorHttpCredentialFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorHttpCredentialToJson(this);

  @override
  bool operator ==(Object other) {
    return other is MonitorHttpCredential &&
        other.addr == addr &&
        other.user == user &&
        other.pwd == pwd &&
        other.ignoreCert == ignoreCert &&
        other.passwordlessTerminal == passwordlessTerminal;
  }

  @override
  int get hashCode => Object.hash(
    addr,
    user,
    pwd,
    ignoreCert,
    passwordlessTerminal,
  );
}
