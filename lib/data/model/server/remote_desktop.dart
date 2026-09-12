import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_desktop.freezed.dart';
part 'remote_desktop.g.dart';

enum RemoteDesktopProtocol {
  @JsonValue('rdp')
  rdp,
  @JsonValue('vnc')
  vnc,
}

extension RemoteDesktopProtocolX on RemoteDesktopProtocol {
  int get defaultPort => switch (this) {
    RemoteDesktopProtocol.rdp => 3389,
    RemoteDesktopProtocol.vnc => 5900,
  };
}

/// A saved route to a desktop reachable from one SSH server.
///
/// The target address is deliberately interpreted by the SSH server rather
/// than by this device. This lets a profile point at localhost or an internal
/// address without exposing the desktop protocol to the public network.
@Freezed(toStringOverride: false)
abstract class RemoteDesktopProfile with _$RemoteDesktopProfile {
  const RemoteDesktopProfile._();

  const factory RemoteDesktopProfile({
    required String id,
    required String serverId,
    required String name,
    required RemoteDesktopProtocol protocol,
    @Default('127.0.0.1') String host,
    required int port,
    String? username,
    String? password,
    String? domain,
    @Default(false) bool viewOnly,
    @Default(true) bool shared,
    String? trustedCertSha256,
  }) = _RemoteDesktopProfile;

  factory RemoteDesktopProfile.fromJson(Map<String, dynamic> json) =>
      _$RemoteDesktopProfileFromJson(json);

  factory RemoteDesktopProfile.defaults({
    required String id,
    required String serverId,
    required String name,
    required RemoteDesktopProtocol protocol,
  }) => RemoteDesktopProfile(
    id: id,
    serverId: serverId,
    name: name,
    protocol: protocol,
    port: protocol.defaultPort,
  );

  /// Certificate trust belongs to exactly one RDP endpoint.
  RemoteDesktopProfile clearTrustWhenEndpointChanged(
    RemoteDesktopProfile? previous,
  ) {
    if (previous == null ||
        (previous.protocol == protocol &&
            previous.host == host &&
            previous.port == port)) {
      return this;
    }
    return copyWith(trustedCertSha256: null);
  }

  /// Credentials and certificate material must never enter diagnostics.
  @override
  String toString() =>
      'RemoteDesktopProfile(id: $id, serverId: $serverId, name: $name, '
      'protocol: ${protocol.name}, host: $host, port: $port, '
      'username: ${username == null ? "null" : "<redacted>"}, '
      'password: ${password == null ? "null" : "<redacted>"}, '
      'domain: ${domain == null ? "null" : "<redacted>"}, '
      'viewOnly: $viewOnly, shared: $shared, '
      'trustedCertSha256: ${trustedCertSha256 == null ? "null" : "<redacted>"})';
}
