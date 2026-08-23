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
/// The two fields here are the two that belong to *this device*. The account
/// is a [BmcCredential] referenced by [credId], because a rack shares one.
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

  /// Which [BmcCredential] to log in with, or null when none has been picked.
  ///
  /// A reference rather than the account itself: see that class for why. Null
  /// is a BMC that has an address and nothing to authenticate with, which the
  /// editor allows and [isComplete] answers false to.
  final String? credId;

  /// SHA-256 of the DER form of the certificate this BMC presented when the
  /// user last reviewed it, lowercase hex.
  ///
  /// BMCs ship self-signed certificates, so there is nothing for a CA to say
  /// about them. What can be said is "this is the same one as last time",
  /// which is what SSH host keys already do in this app.
  ///
  /// Per device and never shared, which is why it is here and not on the
  /// credential: two BMCs do not present the same certificate.
  ///
  /// Absent means nothing has been reviewed yet, and a connection is refused
  /// rather than trusted: the alternative is the ignore-the-certificate switch
  /// PVE and the monitor agent carry, and a management interface holding power
  /// control is the worst place to extend it to.
  final String? certSha256;

  const BmcCfg({required this.addr, this.credId, this.certSha256});

  factory BmcCfg.fromJson(Map<String, dynamic> json) => _$BmcCfgFromJson(json);

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
  ///
  /// Null when [addr] is not a usable URI. Returning it rather than throwing
  /// keeps this callable from the editor, where the address is half-typed for
  /// as long as someone is typing it.
  int? get port {
    final parsed = uri;
    if (parsed == null) return null;
    // `Uri.port` already answers 443 or 80 for a URL that names no port, so
    // the only case left is a scheme it has no default for — which `uri` has
    // already refused.
    return parsed.port;
  }

  /// Whether this is filled in enough to try.
  ///
  /// The certificate is not part of it: an address and an account are what the
  /// user supplies from the edit page, and reviewing the certificate needs a
  /// connection, which needs these first.
  bool get isComplete => uri != null && credId?.isNotEmpty == true;

  BmcCfg copyWith({
    String? addr,
    Object? credId = _unset,
    Object? certSha256 = _unset,
  }) {
    return BmcCfg(
      addr: addr ?? this.addr,
      credId: credId == _unset ? this.credId : credId as String?,
      certSha256: certSha256 == _unset
          ? this.certSha256
          : certSha256 as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BmcCfg &&
      addr == other.addr &&
      credId == other.credId &&
      certSha256 == other.certSha256;

  @override
  int get hashCode => Object.hash(addr, credId, certSha256);

  @override
  String toString() => 'BmcCfg($addr)';
}

/// Sentinel so [BmcCfg.copyWith] can tell "leave as-is" from "set to null" —
/// clearing a pinned certificate is a thing a caller has to be able to say.
const _unset = Object();
