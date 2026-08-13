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

  const MonitorHttpCredential({
    required this.addr,
    this.user,
    this.pwd,
    this.ignoreCert = false,
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
        other.ignoreCert == ignoreCert;
  }

  @override
  int get hashCode => Object.hash(
    addr,
    user,
    pwd,
    ignoreCert,
  );
}
