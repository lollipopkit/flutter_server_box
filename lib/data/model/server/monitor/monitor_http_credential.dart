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

  final String? pwd;

  /// The account name an agent from before it had one account signs in with.
  /// Kept (`server.monitor_user`, `user` in a backup) and sent with every
  /// `/login`, which a one-account agent ignores, so such an agent stays
  /// reachable until it is updated (`showMonitorUpdate`).
  ///
  /// TODO: remove, with the column, once no agent from before the one-account
  /// agent is left.
  @JsonKey(name: 'user')
  final String? legacyUser;

  /// SHA-256 of the certificate the user accepted for this agent, lowercase
  /// hex. Read only when the system does not trust the certificate (an agent's
  /// own self-signed one): a CA-valid agent needs none. Absent, such a
  /// certificate is refused and shown for review rather than trusted.
  final String? certSha256;

  /// Permit this connection to use plaintext HTTP away from loopback.
  ///
  /// Off by default: a private address does not prove a link cannot be read or
  /// redirected. The monitor must independently allow any sensitive endpoint
  /// over plaintext: `[remote_access] allow_insecure = true`.
  final bool allowInsecure;

  const MonitorHttpCredential({
    required this.addr,
    this.pwd,
    this.legacyUser,
    this.certSha256,
    this.allowInsecure = false,
  });

  /// The same agent, signed in to as [user] — see [legacyUser].
  MonitorHttpCredential withLegacyUser(String user) => MonitorHttpCredential(
    addr: addr,
    pwd: pwd,
    legacyUser: user,
    certSha256: certSha256,
    allowInsecure: allowInsecure,
  );

  /// The same agent with another password — its account's, changed.
  MonitorHttpCredential withPwd(String pwd) => MonitorHttpCredential(
    addr: addr,
    pwd: pwd,
    legacyUser: legacyUser,
    certSha256: certSha256,
    allowInsecure: allowInsecure,
  );

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
    pwd: pwd,
    legacyUser: legacyUser,
    certSha256: certSha256,
    allowInsecure: true,
  );

  /// The same connection trusting the certificate [pin] names.
  MonitorHttpCredential withCertSha256(String? pin) => MonitorHttpCredential(
    addr: addr,
    pwd: pwd,
    legacyUser: legacyUser,
    certSha256: pin,
    allowInsecure: allowInsecure,
  );

  @override
  bool operator ==(Object other) {
    return other is MonitorHttpCredential &&
        other.addr == addr &&
        other.pwd == pwd &&
        other.legacyUser == legacyUser &&
        other.certSha256 == certSha256 &&
        other.allowInsecure == allowInsecure;
  }

  @override
  int get hashCode => Object.hash(
    addr,
    pwd,
    legacyUser,
    certSha256,
    allowInsecure,
  );
}
