import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/service/ssh_discovery_lan.dart';

/// A host an [SshDiscovery] found.
@immutable
final class DiscoveredSshHost {
  const DiscoveredSshHost({
    required this.host,
    this.port = 22,
    this.name,
    this.user,
    this.detail,
  });

  final String host;
  final int port;

  /// What the source calls the machine, when it knows.
  final String? name;
  final String? user;

  /// What tells two results apart, such as the SSH banner.
  final String? detail;

  String get address => '$host:$port';

  @override
  bool operator ==(Object other) =>
      other is DiscoveredSshHost && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);
}

/// A way of finding SSH hosts to add as servers.
///
/// The discovery view draws one tab per source in [available], from its
/// [label], [icon] and [scope].
abstract interface class SshDiscovery {
  /// Stable across launches, for keys.
  String get id;
  String get label;
  IconData get icon;

  /// What a run looks at, such as `192.168.1.0/24`; null when unknown.
  Future<String?> scope();

  Future<List<DiscoveredSshHost>> discover();

  /// The sources this build can run.
  static List<SshDiscovery> get available => [
    if (LanSshDiscovery.isSupported) const LanSshDiscovery(),
  ];
}
