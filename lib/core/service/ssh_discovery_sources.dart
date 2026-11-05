import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/core/service/ssh_discovery_cloudflare.dart';
import 'package:server_box/core/service/ssh_discovery_lan.dart';
import 'package:server_box/core/service/ssh_discovery_ssh_config.dart';
import 'package:server_box/core/service/ssh_discovery_tailscale.dart';

/// The [SshDiscovery] sources this build and device can run, in the order
/// shown.
Future<List<SshDiscovery>> availableSshDiscoveries() async {
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
