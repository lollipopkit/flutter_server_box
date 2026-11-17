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

  /// The same agent at another address (a Tailscale or public one), tried
  /// when [addr] cannot be connected to. [certSha256] and [allowInsecure]
  /// apply to both: they describe the agent, not the route to it.
  final String? fallbackAddr;

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
    this.fallbackAddr,
    this.pwd,
    this.legacyUser,
    this.certSha256,
    this.allowInsecure = false,
  });

  /// The same agent, signed in to as [user] — see [legacyUser].
  MonitorHttpCredential withLegacyUser(String user) => _copy(legacyUser: user);

  /// The same agent with another password — its account's, changed.
  MonitorHttpCredential withPwd(String pwd) => _copy(pwd: pwd);

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
  bool get needsInsecureOptIn => insecureAddr != null;

  /// The first of [addrs] refused for being plaintext, which is what
  /// [needsInsecureOptIn] is about. Null once [allowInsecure] is on.
  String? get insecureAddr {
    if (allowInsecure) return null;
    for (final a in addrs) {
      final uri = Uri.tryParse(a.trim());
      if (uri != null && !isSecureRemoteEndpoint(uri)) return a;
    }
    return null;
  }

  /// The first of [addrs] on `https://`: the one [certSha256] is the
  /// certificate of, and the one the editor reads a certificate from.
  String? get tlsAddr {
    for (final a in addrs) {
      if (a.trim().toLowerCase().startsWith('https://')) return a;
    }
    return null;
  }

  /// Where to connect, in order: [addr], then [fallbackAddr] when set.
  List<String> get addrs => [
    addr,
    if (fallbackAddr case final f? when f.trim().isNotEmpty) f,
  ];

  /// The same connection with plaintext HTTP permitted.
  MonitorHttpCredential allowingInsecure() => _copy(allowInsecure: true);

  /// The same connection trusting the certificate [pin] names.
  MonitorHttpCredential withCertSha256(String? pin) =>
      _copy(certSha256: () => pin);

  MonitorHttpCredential _copy({
    String? pwd,
    String? legacyUser,
    String? Function()? certSha256,
    bool? allowInsecure,
  }) => MonitorHttpCredential(
    addr: addr,
    fallbackAddr: fallbackAddr,
    pwd: pwd ?? this.pwd,
    legacyUser: legacyUser ?? this.legacyUser,
    certSha256: certSha256 == null ? this.certSha256 : certSha256(),
    allowInsecure: allowInsecure ?? this.allowInsecure,
  );

  @override
  bool operator ==(Object other) {
    return other is MonitorHttpCredential &&
        other.addr == addr &&
        other.fallbackAddr == fallbackAddr &&
        other.pwd == pwd &&
        other.legacyUser == legacyUser &&
        other.certSha256 == certSha256 &&
        other.allowInsecure == allowInsecure;
  }

  @override
  int get hashCode => Object.hash(
    addr,
    fallbackAddr,
    pwd,
    legacyUser,
    certSha256,
    allowInsecure,
  );
}
