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

  /// Reach the machine through the agent with no SSH credentials, as the
  /// account the agent runs as: a terminal, a command, a forwarded port.
  ///
  /// One switch for all of it rather than one per feature. Anyone who can open
  /// a shell can run anything in it, so a grant that gives the terminal and
  /// withholds the rest withholds nothing — it only makes the app pretend.
  ///
  /// Off by default, and only ever a request: the agent decides whether to
  /// offer this at all (`remote_access.full_access`) and re-checks when the
  /// connection arrives. What it costs is that the monitor password becomes
  /// equivalent to a shell on that machine — with none of sshd's
  /// authentication, logging or second factor — which is why it is a separate,
  /// deliberate switch rather than something implied by configuring monitor.
  ///
  /// Mutually exclusive with [SshCredential.viaMonitor]: both answer "where
  /// does this server's shell come from", and [Spix.validate] enforces it.
  @JsonKey(defaultValue: false)
  final bool fullAccess;

  const MonitorHttpCredential({
    required this.addr,
    this.user,
    this.pwd,
    this.ignoreCert = false,
    this.fullAccess = false,
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
        other.fullAccess == fullAccess;
  }

  @override
  int get hashCode => Object.hash(
    addr,
    user,
    pwd,
    ignoreCert,
    fullAccess,
  );
}
