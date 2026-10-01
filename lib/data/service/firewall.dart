import 'package:server_box/data/model/server/firewall.dart';
import 'package:server_box/data/model/server/server_exec.dart';

/// The firewalls a server has.
enum FirewallKind { ufw, firewalld }

/// What [FirewallProbe] found, asked without root.
final class FirewallProbeResult {
  const FirewallProbeResult({
    required this.installed,
    required this.root,
    this.ssh,
    this.sshInterface,
  });

  /// Each firewall found, and whether it is on. ufw's from its config
  /// (`ENABLED=yes`, readable by anyone), firewalld's from systemd or the
  /// daemon itself.
  final Map<FirewallKind, bool> installed;

  /// Whether commands run as root.
  final bool root;

  /// The SSH connection the probe ran over, as the server saw it. Null when
  /// it ran over anything else.
  final FirewallAccess? ssh;

  /// The interface [ssh] arrived on, which decides its firewalld zone.
  final String? sshInterface;

  /// The firewall to show first: the one that is on; firewalld where both
  /// are, since its rules are the ones the kernel ends up with when both
  /// load theirs; ufw where neither is.
  FirewallKind? get preferred {
    if (installed.isEmpty) return null;
    if (installed.length == 1) return installed.keys.single;
    if (installed[FirewallKind.firewalld] == true) return FirewallKind.firewalld;
    if (installed[FirewallKind.ufw] == true) return FirewallKind.ufw;
    return FirewallKind.ufw;
  }

}

/// Where the firewalls' commands are: `/usr/sbin`, which Debian leaves out
/// of a non-root `PATH`. `C` because what they print is read.
const kFirewallEnv = r'export LC_ALL=C PATH="$PATH:/usr/sbin:/sbin"';

/// [commands] as one script, stopping at the first that fails.
///
/// Run in a subshell so its exit status can be looked at: 2 is how
/// `PrivilegedExec` says sudo refused the password, and `firewall-cmd` exits
/// 2 on a usage error too. One must not read as the other, or a refused
/// command asks for the password again.
String firewallScript(Iterable<String> commands) => [
  kFirewallEnv,
  '(',
  'set -e',
  ...commands,
  ')',
  r'rc=$?',
  r'[ "$rc" -ne 2 ] || rc=1',
  r'exit "$rc"',
  '',
].join('\n');

/// Asks which firewalls a server has, and how this app reaches it.
abstract final class FirewallProbe {
  static const ufwMarker = 'SrvBoxFw.Ufw\t';
  static const firewalldMarker = 'SrvBoxFw.Firewalld\t';
  static const uidMarker = 'SrvBoxFw.Uid\t';
  static const sshMarker = 'SrvBoxFw.Ssh\t';
  static const ifaceMarker = 'SrvBoxFw.Iface\t';

  /// Never asks for root: a server with neither firewall is said to be one
  /// before anyone is asked for a password. `SSH_CONNECTION` is only there
  /// before `sudo`, which drops it.
  static const script =
      '$kFirewallEnv\n'
      r'''
if command -v ufw >/dev/null 2>&1; then
  printf 'SrvBoxFw.Ufw\t%s\n' "$(grep -E '^ENABLED=' /etc/ufw/ufw.conf 2>/dev/null | cut -d= -f2)"
fi
if command -v firewall-cmd >/dev/null 2>&1; then
  s=$(systemctl is-active firewalld 2>/dev/null)
  [ -n "$s" ] || s=$(firewall-cmd --state 2>&1)
  printf 'SrvBoxFw.Firewalld\t%s\n' "$s"
fi
printf 'SrvBoxFw.Uid\t%s\n' "$(id -u)"
printf 'SrvBoxFw.Ssh\t%s\n' "$SSH_CONNECTION"
if [ -n "$SSH_CONNECTION" ]; then
  set -- $SSH_CONNECTION
  printf 'SrvBoxFw.Iface\t%s\n' "$(ip -o addr show to "${3%%\%*}" 2>/dev/null | awk '{ print $2; exit }')"
fi
''';

  static Future<FirewallProbeResult> run(ServerExec exec) async {
    final result = await exec.run(script, entry: 'sh');
    return parse(result.stdout);
  }

  static FirewallProbeResult parse(String output) {
    final installed = <FirewallKind, bool>{};
    var root = false;
    FirewallAccess? ssh;
    String? sshInterface;
    for (final raw in output.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      String? value(String marker) =>
          line.startsWith(marker) ? line.substring(marker.length).trim() : null;
      if (value(ufwMarker) case final v?) {
        installed[FirewallKind.ufw] = v.replaceAll('"', '').toLowerCase() == 'yes';
      } else if (value(firewalldMarker) case final v?) {
        installed[FirewallKind.firewalld] = v == 'active' || v == 'running';
      } else if (value(uidMarker) case final v?) {
        root = v == '0';
      } else if (value(sshMarker) case final v?) {
        ssh = FirewallAccess.fromSshConnection(v);
      } else if (value(ifaceMarker) case final v? when v.isNotEmpty) {
        sshInterface = v;
      }
    }
    return FirewallProbeResult(
      installed: installed,
      root: root,
      ssh: ssh,
      sshInterface: sshInterface,
    );
  }
}
