import 'dart:io';

import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/server/firewalld.dart';
import 'package:server_box/data/service/firewall.dart';

final class FirewalldManagerException implements Exception {
  const FirewalldManagerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Why a value typed for firewalld cannot be used, said before it is asked.
enum FirewalldInputIssue {
  invalidPort,
  invalidSource,
  invalidInterface,
  invalidRichRule,
  invalidForwardPort,
}

/// Reads and changes a server's firewalld.
///
/// Run as root, like ufw: firewalld answers an unprivileged caller only
/// where polkit says so, and changes nothing for one.
abstract final class FirewalldManager {
  static const runningMarker = 'SrvBoxFwd.Running';
  static const versionMarker = 'SrvBoxFwd.Version\t';
  static const defaultMarker = 'SrvBoxFwd.Default\t';
  static const panicMarker = 'SrvBoxFwd.Panic\t';
  static const runtimeMarker = 'SrvBoxFwd.Runtime';
  static const permanentMarker = 'SrvBoxFwd.Permanent';
  static const policiesMarker = 'SrvBoxFwd.Policies';
  static const servicesMarker = 'SrvBoxFwd.Services';
  static const serviceNamesMarker = 'SrvBoxFwd.ServiceNames';

  static const _serviceDirs =
      '/usr/lib/firewalld/services /etc/firewalld/services';

  /// Both configurations while the daemon runs; the written one through
  /// `firewall-offline-cmd` while it does not, since `firewall-cmd` then
  /// answers nothing but "not running".
  ///
  /// Services are read from their files rather than asked of firewalld one
  /// by one: `firewall-cmd` is a Python program that takes a third of a
  /// second to start, and a zone names a dozen.
  ///
  /// Section markers start a line; every line firewalld prints under a zone
  /// is indented, so none can look like one. Never exits 2 — see
  /// [firewallScript].
  static const readScript =
      '$kFirewallEnv\n'
      'if firewall-cmd --state >/dev/null 2>&1; then\n'
      '  echo $runningMarker\n'
      "  printf '$versionMarker%s\\n' \"\$(firewall-cmd --version 2>/dev/null)\"\n"
      "  printf '$defaultMarker%s\\n' \"\$(firewall-cmd --get-default-zone 2>/dev/null)\"\n"
      "  printf '$panicMarker%s\\n' \"\$(firewall-cmd --query-panic 2>/dev/null)\"\n"
      '  echo $runtimeMarker\n'
      '  firewall-cmd --list-all-zones 2>/dev/null\n'
      '  echo $permanentMarker\n'
      '  firewall-cmd --permanent --list-all-zones 2>/dev/null\n'
      '  echo $policiesMarker\n'
      '  firewall-cmd --list-all-policies 2>/dev/null\n'
      'else\n'
      "  printf '$versionMarker%s\\n' \"\$(firewall-offline-cmd --version 2>/dev/null)\"\n"
      "  printf '$defaultMarker%s\\n' \"\$(firewall-offline-cmd --get-default-zone 2>/dev/null)\"\n"
      '  echo $permanentMarker\n'
      '  firewall-offline-cmd --list-all-zones 2>/dev/null\n'
      'fi\n'
      'echo $servicesMarker\n'
      "grep -H -o -E '<(port|include) [^>]*>' "
      r'$(for d in ' '$_serviceDirs' r'; do ls -d "$d"/*.xml 2>/dev/null; done)'
      ' 2>/dev/null\n'
      'echo $serviceNamesMarker\n'
      'for d in $_serviceDirs; do ls "\$d" 2>/dev/null; done\n'
      'exit 0\n';

  static FirewalldSnapshot parse(String output) {
    const markers = {
      runtimeMarker,
      permanentMarker,
      policiesMarker,
      servicesMarker,
      serviceNamesMarker,
    };
    var running = false;
    String? version, defaultZone;
    var panic = false;
    final sections = <String, List<String>>{};
    String? section;
    for (final raw in output.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      if (line == runningMarker) {
        running = true;
      } else if (line.startsWith(versionMarker)) {
        version = line.substring(versionMarker.length).trim();
      } else if (line.startsWith(defaultMarker)) {
        defaultZone = line.substring(defaultMarker.length).trim();
      } else if (line.startsWith(panicMarker)) {
        panic = line.substring(panicMarker.length).trim() == 'yes';
      } else if (markers.contains(line)) {
        section = line;
        sections[line] = [];
      } else if (section != null) {
        sections[section]!.add(raw.replaceAll('\r', ''));
      }
    }
    final permanent = sections[permanentMarker];
    if (permanent == null) {
      throw const FirewalldManagerException('Unable to read firewalld zones');
    }
    final services = parseServices(sections[servicesMarker] ?? const []);
    final names = {
      for (final line in sections[serviceNamesMarker] ?? const <String>[])
        if (line.trim().endsWith('.xml'))
          line.trim().substring(0, line.trim().length - 4),
    }.toList()..sort();
    return FirewalldSnapshot(
      running: running,
      version: version?.isEmpty ?? true ? null : version,
      defaultZone: defaultZone?.isEmpty ?? true ? null : defaultZone,
      panic: panic,
      runtime: running ? parseZones(sections[runtimeMarker] ?? const []) : null,
      permanent: parseZones(permanent),
      policies: parsePolicies(sections[policiesMarker] ?? const []),
      services: services,
      serviceNames: names,
    );
  }

  /// `--list-all-zones`: a line per zone name, `(active)` after one in use,
  /// then its `key: value` lines indented by two spaces, and the items of a
  /// multi-line key — forward ports, rich rules — indented by a tab.
  static List<FirewalldZone> parseZones(List<String> lines) {
    return [for (final block in _blocks(lines)) ?_zone(block)];
  }

  /// One zone's or policy's lines: the words of each `key: value`, and the
  /// tab-indented lines under a key, each one item whole.

  static List<_Block> _blocks(List<String> lines) {
    final blocks = <_Block>[];
    _Block? block;
    String? key;
    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      if (line.startsWith('\t')) {
        if (block != null && key != null) {
          block.items.putIfAbsent(key, () => []).add(line.trim());
        }
      } else if (line.startsWith(' ')) {
        final colon = line.indexOf(':');
        if (block == null || colon < 0) continue;
        key = line.substring(0, colon).trim();
        block.fields[key] = [
          for (final word in line.substring(colon + 1).trim().split(' '))
            if (word.isNotEmpty) word,
        ];
      } else {
        key = null;
        blocks.add(block = (header: line.trim(), fields: {}, items: {}));
      }
    }
    return blocks;
  }

  static FirewalldZone? _zone(_Block block) {
    final name = block.header.split(' ').first;
    if (name.isEmpty) return null;
    final f = block.fields;
    List<String> list(String key) => List.unmodifiable(f[key] ?? const []);
    List<FirewalldPort> ports(String key) => [
      for (final spec in f[key] ?? const <String>[])
        ?FirewalldPort.parse(spec),
    ];
    return FirewalldZone(
      name: name,
      active: _flags(block).contains('active'),
      target:
          FirewalldTarget.fromToken(f['target']?.firstOrNull) ??
          FirewalldTarget.defaultTarget,
      interfaces: list('interfaces'),
      sources: list('sources'),
      services: list('services'),
      ports: ports('ports'),
      protocols: list('protocols'),
      sourcePorts: ports('source-ports'),
      forwardPorts: List.unmodifiable(block.items['forward-ports'] ?? const []),
      richRules: [
        for (final rule in block.items['rich rules'] ?? const <String>[])
          FirewalldRichRule.parse(rule),
      ],
      masquerade: f['masquerade']?.firstOrNull == 'yes',
    );
  }

  /// The words in parentheses after a block's name: `public (default,
  /// active)` has `default` and `active`. Never the name itself, which may
  /// hold any of them — a zone may be called `inactive`.
  static Set<String> _flags(_Block block) {
    final match = RegExp(r'^\S+\s+\(([^)]*)\)$').firstMatch(block.header);
    if (match == null) return const {};
    return {for (final flag in match.group(1)!.split(',')) flag.trim()};
  }

  /// Active policies, as far as they may decide what reaches this host.
  static List<FirewalldPolicy> parsePolicies(List<String> lines) {
    return [
      for (final block in _blocks(lines))
        if (_flags(block).contains('active'))
          FirewalldPolicy(
            name: block.header.split(' ').first,
            target: block.fields['target']?.firstOrNull ?? 'CONTINUE',
            egressHost:
                block.fields['egress-zones']?.contains('HOST') ?? false,
            decides:
                (block.fields['target']?.firstOrNull ?? 'CONTINUE') !=
                    'CONTINUE' ||
                [
                  'services',
                  'ports',
                  'protocols',
                  'forward-ports',
                ].any((k) => block.fields[k]?.isNotEmpty ?? false) ||
                (block.items['rich rules'] ?? const []).any(
                  (r) => !r.contains('icmp-type'),
                ),
          ),
    ];
  }

  static final _servicePort = RegExp(r'protocol="([^"]*)"|port="([^"]*)"');
  static final _serviceInclude = RegExp(r'service="([^"]*)"');

  /// `grep -H` over the service files: `path:<port protocol=… port=…/>` and
  /// `path:<include service=…/>`. A file under `/etc` replaces the one of
  /// the same name under `/usr/lib`; an include brings the other service's
  /// ports.
  static Map<String, List<FirewalldPort>> parseServices(List<String> lines) {
    final byFile = <String, ({List<FirewalldPort> ports, List<String> includes})>{};
    for (final line in lines) {
      final tag = line.indexOf(':<');
      if (tag < 0) continue;
      final path = line.substring(0, tag);
      final entry = byFile.putIfAbsent(
        path,
        () => (ports: <FirewalldPort>[], includes: <String>[]),
      );
      final element = line.substring(tag + 1);
      if (element.startsWith('<include')) {
        if (_serviceInclude.firstMatch(element) case final m?) {
          entry.includes.add(m.group(1)!);
        }
        continue;
      }
      String? protocol, port;
      for (final m in _servicePort.allMatches(element)) {
        protocol ??= m.group(1);
        port ??= m.group(2);
      }
      if (protocol != null && port != null && port.isNotEmpty) {
        entry.ports.add(FirewalldPort(port, protocol));
      }
    }
    final own = <String, ({List<FirewalldPort> ports, List<String> includes})>{};
    // `/usr/lib` sorts before `/etc` is applied, so the later one wins.
    final paths = byFile.keys.toList()
      ..sort((a, b) => (a.startsWith('/etc/') ? 1 : 0)
          .compareTo(b.startsWith('/etc/') ? 1 : 0));
    for (final path in paths) {
      final name = path.split('/').last.replaceFirst(RegExp(r'\.xml$'), '');
      own[name] = byFile[path]!;
    }
    List<FirewalldPort> resolve(String name, Set<String> seen) {
      final entry = own[name];
      if (entry == null || !seen.add(name)) return const [];
      return [
        ...entry.ports,
        for (final include in entry.includes) ...resolve(include, seen),
      ];
    }

    return {
      for (final name in own.keys) name: List.unmodifiable(resolve(name, {})),
    };
  }

  /// [args] applied to what is in force and to what is written down while
  /// the daemon runs — a change only to the runtime is gone at the next
  /// reload, one only to the permanent waits for it — and through
  /// `firewall-offline-cmd` to the written one while it does not.
  ///
  /// Adding what is there, or removing what is not, is a warning and exit 0
  /// to `firewall-cmd`, so the two halves are safe when they already differ.
  static List<String> both(bool running, String args) => running
      ? ['firewall-cmd $args', 'firewall-cmd --permanent $args']
      : ['firewall-offline-cmd $args'];

  static String zoneArg(String zone) => '--zone=${shellSingleQuote(zone)}';

  static String _item(String zone, bool add, String kind, String value) =>
      '${zoneArg(zone)} --${add ? 'add' : 'remove'}-$kind=${shellSingleQuote(value)}';

  static List<String> service(bool running, String zone, String name,
          {required bool add}) =>
      both(running, _item(zone, add, 'service', name));

  static List<String> port(bool running, String zone, FirewalldPort port,
          {required bool add}) =>
      both(running, _item(zone, add, 'port', '$port'));

  static List<String> richRule(bool running, String zone, String rule,
          {required bool add}) =>
      both(running, _item(zone, add, 'rich-rule', rule));

  static List<String> source(bool running, String zone, String source,
          {required bool add}) =>
      both(running, _item(zone, add, 'source', source));

  static List<String> forwardPort(bool running, String zone, String spec,
          {required bool add}) =>
      both(running, _item(zone, add, 'forward-port', spec));

  /// A rich rule letting TCP in to [port] before anything in its zone can
  /// refuse it: the lowest priority there is, below every other rich rule.
  static String keepOpenRule(int port) =>
      'rule priority="-32768" port port="$port" protocol="tcp" accept';

  /// Moves [interface] into [zone], out of whichever had it.
  static List<String> changeInterface(
    bool running,
    String zone,
    String interface,
  ) => both(
    running,
    '${zoneArg(zone)} --change-interface=${shellSingleQuote(interface)}',
  );

  static List<String> removeInterface(
    bool running,
    String zone,
    String interface,
  ) => both(running, _item(zone, false, 'interface', interface));

  static List<String> masquerade(bool running, String zone,
          {required bool add}) =>
      both(running, '${zoneArg(zone)} --${add ? 'add' : 'remove'}-masquerade');

  /// A target can only be written down; the daemon takes it at a reload,
  /// which also drops every change made only to the runtime.
  static List<String> target(
    bool running,
    String zone,
    FirewalldTarget target,
  ) => running
      ? [
          'firewall-cmd --permanent ${zoneArg(zone)} '
              '--set-target=${shellSingleQuote(target.token)}',
          reloadCommand,
        ]
      : [
          'firewall-offline-cmd ${zoneArg(zone)} '
              '--set-target=${shellSingleQuote(target.token)}',
        ];

  /// Changes both configurations at once, running or not.
  static String defaultZone(bool running, String zone) =>
      '${running ? 'firewall-cmd' : 'firewall-offline-cmd'} '
      '--set-default-zone=${shellSingleQuote(zone)}';

  static const reloadCommand = 'firewall-cmd --reload';
  static const runtimeToPermanentCommand = 'firewall-cmd --runtime-to-permanent';
  static const panicOffCommand = 'firewall-cmd --panic-off';

  /// Started now and at boot; stopped now and at boot — the way ufw's
  /// enable and disable are.
  static const startCommand = 'systemctl enable --now firewalld';
  static const stopCommand = 'systemctl disable --now firewalld';

  static final _port = RegExp(r'^(\d{1,5})(?:-(\d{1,5}))?/(tcp|udp|sctp|dccp)$');
  static final _interface = RegExp(r'^[A-Za-z0-9_.+-]{1,15}$');
  static final _mac = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
  static final _ipset = RegExp(r'^ipset:[A-Za-z0-9_.-]+$');
  static final _forwardPort = RegExp(
    r'^port=\d{1,5}(-\d{1,5})?:proto=(tcp|udp|sctp|dccp)'
    r'(:toport=(\d{1,5}(-\d{1,5})?)?)?(:toaddr=[0-9A-Fa-f.:]*)?$',
  );

  static FirewalldPort? parsePort(String value) {
    final match = _port.firstMatch(value.trim());
    if (match == null) return null;
    final start = int.parse(match.group(1)!);
    final end = int.tryParse(match.group(2) ?? '');
    if (start < 1 || start > 65535) return null;
    if (end != null && (end <= start || end > 65535)) return null;
    return FirewalldPort(
      end == null ? '$start' : '$start-$end',
      match.group(3)!,
    );
  }

  static FirewalldInputIssue? checkSource(String value) {
    final v = value.trim();
    if (_mac.hasMatch(v) || _ipset.hasMatch(v)) return null;
    final slash = v.indexOf('/');
    final address = InternetAddress.tryParse(slash < 0 ? v : v.substring(0, slash));
    if (address == null) return FirewalldInputIssue.invalidSource;
    if (slash >= 0) {
      final bits = address.type == InternetAddressType.IPv6 ? 128 : 32;
      final prefix = int.tryParse(v.substring(slash + 1));
      if (prefix == null || prefix < 0 || prefix > bits) {
        return FirewalldInputIssue.invalidSource;
      }
    }
    return null;
  }

  static FirewalldInputIssue? checkInterface(String value) =>
      _interface.hasMatch(value.trim())
      ? null
      : FirewalldInputIssue.invalidInterface;

  /// firewalld checks the grammar; this only keeps a script one line long.
  static FirewalldInputIssue? checkRichRule(String value) {
    final v = value.trim();
    if (!v.startsWith('rule') || v.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      return FirewalldInputIssue.invalidRichRule;
    }
    return null;
  }

  static FirewalldInputIssue? checkForwardPort(String value) {
    final v = value.trim();
    if (!_forwardPort.hasMatch(v)) return FirewalldInputIssue.invalidForwardPort;
    // Somewhere to send it: another port, another host, or both.
    if (!v.contains(':toport=') && !v.contains(':toaddr=')) {
      return FirewalldInputIssue.invalidForwardPort;
    }
    return null;
  }
}

typedef _Block = ({
  String header,
  Map<String, List<String>> fields,
  Map<String, List<String>> items,
});
