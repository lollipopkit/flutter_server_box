import 'package:server_box/data/model/server/firewall.dart';
import 'package:server_box/data/model/server/server_exec.dart';

/// Asks which firewalls a server has, and how this app reaches it — never as
/// root (`sbm_parser::firewall::PROBE_SCRIPT`).
abstract final class FirewallProbe {
  static Future<FirewallProbeResult> run(ServerExec exec) async {
    final result = await exec.run(firewallProbeScript(), entry: 'sh');
    return firewallParseProbe(output: result.stdout);
  }
}
