import 'package:json_annotation/json_annotation.dart';

part 'bmc_cfg.g.dart';

/// How to reach this server's BMC, or absent when it has none configured.
///
/// A side channel, like [WakeOnLanCfg] and unlike [SshCredential]: it is not a
/// way of reaching the host, so it is not on the `ServerConnectCredential`
/// axis. It answers about the machine when the host is not answering at all —
/// power state, hardware sensors — because a BMC has its own power rail and
/// its own network port.
///
/// Nested rather than flat fields on `ServerCustom`, where PVE's settings
/// live: flat cannot express "not configured", which is the same reason the
/// SSH fields were extracted into [SshCredential].
///
/// See `docs/principles/bmc.md` for what varies between vendors, and why
/// nothing about the resource layout may be assumed.
@JsonSerializable(includeIfNull: false)
final class BmcCfg {
  /// The Redfish service's base URL, e.g. `https://10.0.0.9`.
  ///
  /// Only the scheme, host and port are used; the service root is always
  /// `/redfish/v1/` and is appended rather than configured.
  final String addr;

  final String user;

  final String? pwd;

  /// SHA-256 of the DER form of the certificate this BMC presented when the
  /// user last reviewed it, lowercase hex.
  ///
  /// BMCs ship self-signed certificates, so there is nothing for a CA to say
  /// about them. What can be said is "this is the same one as last time",
  /// which is what SSH host keys already do in this app.
  ///
  /// Absent means nothing has been reviewed yet, and a connection is refused
  /// rather than trusted: the alternative is the ignore-the-certificate switch
  /// PVE and the monitor agent carry, and a management interface holding power
  /// control is the worst place to extend it to.
  final String? certSha256;

  const BmcCfg({
    required this.addr,
    required this.user,
    this.pwd,
    this.certSha256,
  });

  factory BmcCfg.fromJson(Map<String, dynamic> json) =>
      _$BmcCfgFromJson(json);

  Map<String, dynamic> toJson() => _$BmcCfgToJson(this);

  /// [addr] as a URI, or null when it is not usable as one.
  ///
  /// Returned rather than thrown because this runs while the user is typing.
  Uri? get uri {
    final parsed = Uri.tryParse(addr.trim());
    if (parsed == null || parsed.host.isEmpty) return null;
    if (parsed.scheme != 'https' && parsed.scheme != 'http') return null;
    return parsed;
  }

  /// The port to reach, defaulted per scheme the way a browser would.
  int get port => uri?.port != 0 ? uri!.port : (uri!.scheme == 'http' ? 80 : 443);

  /// Whether this is filled in enough to try.
  ///
  /// The certificate is not part of it: an address and an account are what the
  /// user can supply from the edit page, and reviewing the certificate needs a
  /// connection, which needs these first.
  bool get isComplete => uri != null && user.trim().isNotEmpty;

  BmcCfg copyWith({
    String? addr,
    String? user,
    Object? pwd = _unset,
    Object? certSha256 = _unset,
  }) {
    return BmcCfg(
      addr: addr ?? this.addr,
      user: user ?? this.user,
      pwd: pwd == _unset ? this.pwd : pwd as String?,
      certSha256: certSha256 == _unset
          ? this.certSha256
          : certSha256 as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BmcCfg &&
      addr == other.addr &&
      user == other.user &&
      pwd == other.pwd &&
      certSha256 == other.certSha256;

  @override
  int get hashCode => Object.hash(addr, user, pwd, certSha256);
}

/// Sentinel so [BmcCfg.copyWith] can tell "leave as-is" from "set to null" —
/// clearing a pinned certificate is a thing a caller has to be able to say.
const _unset = Object();
