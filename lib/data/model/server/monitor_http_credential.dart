import 'package:json_annotation/json_annotation.dart';
import 'package:server_box/core/utils/secure_endpoint.dart';

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

  /// Permit this connection to use plaintext HTTP away from loopback.
  ///
  /// Off by default: a private address does not prove a link cannot be read or
  /// redirected. The monitor must independently allow any sensitive endpoint
  /// over plaintext, such as `[remote_access.fs] allow_insecure = true`.
  final bool allowInsecure;

  const MonitorHttpCredential({
    required this.addr,
    this.user,
    this.pwd,
    this.ignoreCert = false,
    this.allowInsecure = false,
  });

  factory MonitorHttpCredential.fromJson(Map<String, dynamic> json) =>
      _$MonitorHttpCredentialFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorHttpCredentialToJson(this);

  /// Whether this connection will be refused for being plaintext, and turning
  /// [allowInsecure] on is what would let it through.
  ///
  /// The same question `MonitorHttpClient._addr` asks before every request,
  /// asked ahead of time so the editor can say so on save and the detail page
  /// can offer the switch instead of only naming the error. Read off the
  /// configuration rather than off the failure text, which is a localized
  /// sentence and not something to match against.
  bool get needsInsecureOptIn {
    if (allowInsecure) return false;
    final uri = Uri.tryParse(addr.trim());
    if (uri == null) return false;
    return !isSecureRemoteEndpoint(uri);
  }

  /// The same connection with plaintext HTTP permitted.
  MonitorHttpCredential allowingInsecure() => MonitorHttpCredential(
    addr: addr,
    user: user,
    pwd: pwd,
    ignoreCert: ignoreCert,
    allowInsecure: true,
  );

  @override
  bool operator ==(Object other) {
    return other is MonitorHttpCredential &&
        other.addr == addr &&
        other.user == user &&
        other.pwd == pwd &&
        other.ignoreCert == ignoreCert &&
        other.allowInsecure == allowInsecure;
  }

  @override
  int get hashCode => Object.hash(
    addr,
    user,
    pwd,
    ignoreCert,
    allowInsecure,
  );
}
