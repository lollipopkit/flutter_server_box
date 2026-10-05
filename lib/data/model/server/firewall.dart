import 'package:server_box/src/rust/api/firewall.dart';

export 'package:server_box/src/rust/api/firewall.dart';

/// A firewall — ufw or firewalld — is `sbm_parser::firewall`'s: the scripts
/// that read it, what they print, the commands that change it, and whether a
/// change would shut a way the app reaches the server. These carry calls to
/// it; nothing here decides anything.
extension FirewallProbeResultX on FirewallProbeResult {
  /// Each firewall found, and whether it is on.
  Map<FirewallKind, bool> get installed => {
    FirewallKind.ufw: ?ufw,
    FirewallKind.firewalld: ?firewalld,
  };

  /// The firewall to show first.
  FirewallKind? get preferred => firewallPreferred(probe: this);
}
