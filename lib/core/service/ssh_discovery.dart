import 'package:material_ui/material_ui.dart';
import 'package:server_box/core/service/ssh_discovery_cloudflare.dart';
import 'package:server_box/core/service/ssh_discovery_lan.dart';
import 'package:server_box/core/service/ssh_discovery_ssh_config.dart';
import 'package:server_box/core/service/ssh_discovery_tailscale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

/// A host an [SshDiscovery] found, as the server adding it saves.
@immutable
final class DiscoveredSshHost {
  const DiscoveredSshHost({
    required this.key,
    required this.server,
    this.detail,
    this.online,
    this.via = const [],
    this.userKnown = false,
  });

  /// Stable across runs of one source, for the selection.
  final String key;
  final Spi server;

  /// What tells two results apart, such as the SSH banner.
  final String? detail;

  /// Null when the source does not know.
  final bool? online;

  /// The servers [server] jumps through, which are added with it.
  final List<Spi> via;

  /// The source names the account, rather than [server] carrying the default.
  final bool userKnown;

  String get host => server.ssh?.ip ?? '';
  int get port => server.ssh?.port ?? 22;
  String get address => '$host:$port';

  /// The name is the address itself, as for a LAN scan.
  bool get unnamed => server.name == host;

  /// Whether [spi] is already this host.
  bool isServer(Spi spi) => sameHost(server, spi, user: userKnown);

  /// The one rule for "already a server": the same address, and the same
  /// account when the source named one.
  static bool sameHost(Spi a, Spi b, {required bool user}) {
    final x = a.ssh, y = b.ssh;
    return !a.local &&
        !b.local &&
        x != null &&
        y != null &&
        x.ip == y.ip &&
        x.port == y.port &&
        (!user || x.user == y.user);
  }

  @override
  bool operator ==(Object other) =>
      other is DiscoveredSshHost && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// What a run found, and where it looked.
typedef SshDiscoveryRun = ({List<DiscoveredSshHost> hosts, String? scope});

/// A secret a source needs before it can run, such as an API token. Asked for
/// on the page and kept in memory only.
@immutable
final class SshDiscoveryCredential {
  const SshDiscoveryCredential({required this.label, this.hint});

  final String label;

  /// What the secret has to allow, under the field.
  final String? hint;
}

/// Why a run could not start, shown in place of its results.
final class SshDiscoveryException implements Exception {
  const SshDiscoveryException(this.message, {this.tip, this.needsFile = false});

  final String message;
  final String? tip;

  /// The source can read a file the user picks instead: the run is retried
  /// with its path as the input.
  final bool needsFile;

  @override
  String toString() => message;
}

/// A way of finding SSH hosts to add as servers.
///
/// The discovery view draws one tab per source in [available], from its
/// [label], [icon] and [scope], and starts it the way it asks: by a button,
/// at once ([auto]), or with a [credential].
abstract interface class SshDiscovery {
  /// Stable across launches, for keys.
  String get id;
  String get label;
  IconData get icon;

  /// Runs as soon as it is shown: reading it costs nothing.
  bool get auto;

  SshDiscoveryCredential? get credential;

  /// What a run looks at, shown before it starts; null when unknown.
  Future<String?> scope();

  /// [input] is the [credential], or a picked file after
  /// [SshDiscoveryException.needsFile].
  Future<SshDiscoveryRun> discover({String? input});

  /// The sources this build and device can run, in the order shown.
  static Future<List<SshDiscovery>> available() async {
    final (ssh, tailscale) = await (
      SshConfigDiscovery.isAvailable(),
      TailscaleDiscovery.find(),
    ).wait;
    return [
      if (ssh) const SshConfigDiscovery(),
      if (LanSshDiscovery.isSupported) const LanSshDiscovery(),
      ?tailscale,
      if (CloudflareDiscovery.isSupported) const CloudflareDiscovery(),
    ];
  }
}
