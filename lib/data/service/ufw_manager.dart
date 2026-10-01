import 'dart:convert';
import 'dart:io';

import 'package:server_box/core/utils/shell_quote.dart';
import 'package:server_box/data/model/server/ufw.dart';
import 'package:server_box/data/service/firewall.dart';

final class UfwManagerException implements Exception {
  const UfwManagerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads and changes a server's ufw.
///
/// Everything here needs root: ufw keeps its rule files `0640 root`, and
/// `ufw status` refuses anyone else. The page runs these through
/// `PrivilegedExec`, after `FirewallProbe` found ufw without it.
abstract final class UfwManager {
  static const versionMarker = 'SrvBoxUfw.Version\t';
  static const statusMarker = 'SrvBoxUfw.Status\t';
  static const defaultsMarker = 'SrvBoxUfw.Defaults';
  static const confMarker = 'SrvBoxUfw.Conf';
  static const v4Marker = 'SrvBoxUfw.V4';
  static const v6Marker = 'SrvBoxUfw.V6';
  static const appsMarker = 'SrvBoxUfw.Apps';

  static const _rules4 = '/etc/ufw/user.rules';
  static const _rules6 = '/etc/ufw/user6.rules';

  /// Never exits 2: that is how `PrivilegedExec` says sudo refused the
  /// password, and `grep` exits 2 on a file it cannot open. An unreadable v4
  /// file is an error of its own rather than an empty rule list.
  static const readScript =
      '$kFirewallEnv\n'
      "[ -r $_rules4 ] || { echo 'Cannot read $_rules4' >&2; exit 1; }\n"
      r'v=$(ufw version 2>/dev/null | head -n 1)' '\n'
      r's=$(ufw status 2>&1 | head -n 1)' '\n'
      "printf '$versionMarker%s\\n' \"\$v\"\n"
      "printf '$statusMarker%s\\n' \"\$s\"\n"
      'echo $defaultsMarker\n'
      "grep -E '^(IPV6|DEFAULT_[A-Z]+_POLICY)=' /etc/default/ufw 2>/dev/null\n"
      'echo $confMarker\n'
      "grep -E '^LOGLEVEL=' /etc/ufw/ufw.conf 2>/dev/null\n"
      'echo $v4Marker\n'
      "grep '^$tuplePrefix' $_rules4 2>/dev/null\n"
      'echo $v6Marker\n'
      "grep '^$tuplePrefix' $_rules6 2>/dev/null\n"
      'echo $appsMarker\n'
      'ufw app info all 2>/dev/null\n'
      'exit 0\n';

  static UfwSnapshot parse(String output) {
    const sectionMarkers = {
      defaultsMarker,
      confMarker,
      v4Marker,
      v6Marker,
      appsMarker,
    };
    String? version;
    String? status;
    final sections = <String, List<String>>{};
    String? section;
    for (final raw in output.replaceAll('\r\n', '\n').split('\n')) {
      final line = raw.trimRight();
      if (line.startsWith(versionMarker)) {
        version = line.substring(versionMarker.length).trim();
        continue;
      }
      if (line.startsWith(statusMarker)) {
        status = line.substring(statusMarker.length).trim();
        continue;
      }
      if (sectionMarkers.contains(line)) {
        section = line;
        sections[line] = [];
        continue;
      }
      if (section != null && line.isNotEmpty) sections[section]!.add(line);
    }
    if (status == null) {
      throw const UfwManagerException('Unable to read the ufw status');
    }

    final defaults = _keyValues(sections[defaultsMarker]);
    final conf = _keyValues(sections[confMarker]);
    final ipv6 = defaults['IPV6']?.toLowerCase() != 'no';
    final policies = <UfwChain, UfwPolicy>{
      for (final chain in UfwChain.values)
        chain: ?UfwPolicy.fromTarget(defaults['DEFAULT_${chain.key}_POLICY']),
    };

    return UfwSnapshot(
      active: switch (status) {
        'Status: active' => true,
        'Status: inactive' => false,
        _ => null,
      },
      statusLine: status,
      version: version?.replaceFirst(RegExp(r'^ufw\s+'), ''),
      logLevel: UfwLogLevel.fromName(conf['LOGLEVEL']),
      ipv6: ipv6,
      policies: policies,
      rules: mergeRules(
        sections[v4Marker] ?? const [],
        ipv6 ? sections[v6Marker] ?? const [] : const [],
      ),
      apps: parseApps(sections[appsMarker] ?? const []),
    );
  }

  /// `ufw app info all`: a `Profile:` line per profile, and under `Ports:`
  /// (`Port:` for one) its specs, indented.
  static List<UfwApp> parseApps(List<String> lines) {
    final apps = <UfwApp>[];
    String? name;
    var ports = <UfwAppPort>[];
    var inPorts = false;
    void flush() {
      if (name case final n?) apps.add(UfwApp(n, List.unmodifiable(ports)));
    }

    for (final line in lines) {
      if (line.startsWith('Profile: ')) {
        flush();
        name = line.substring('Profile: '.length).trim();
        ports = [];
        inPorts = false;
      } else if (line == 'Ports:' || line == 'Port:') {
        inPorts = true;
      } else if (inPorts && line.startsWith(' ')) {
        if (UfwAppPort.parse(line) case final port?) ports.add(port);
      } else {
        inPorts = false;
      }
    }
    flush();
    return apps;
  }

  /// `KEY=value` lines, quotes stripped, as ufw reads its own config.
  static Map<String, String> _keyValues(List<String>? lines) {
    final map = <String, String>{};
    for (final line in lines ?? const <String>[]) {
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      map[line.substring(0, eq).trim()] = line
          .substring(eq + 1)
          .trim()
          .replaceAll(RegExp(r'''^["']|["']$'''), '');
    }
    return map;
  }

  static const tuplePrefix = '### tuple ### ';
  static const _any4 = '0.0.0.0/0';
  static const _any6 = '::/0';

  /// The rules of both files in the order ufw numbers them — v4's, then v6's
  /// — with a v6 rule that only repeats a v4 one folded into it.
  ///
  /// A rule naming no address is added to both families at once, and
  /// `ufw status` lists it twice. Listed once here, and deleted as one.
  static List<UfwRule> mergeRules(List<String> v4, List<String> v6) {
    final twins = <String, String>{
      for (final tuple in v6) _v4Twin(tuple): tuple,
    };
    final merged = <String>{};
    final rules = <UfwRule>[];
    for (final tuple in v4) {
      final twin = twins[tuple];
      final rule = parseTuple(
        twin == null ? [tuple] : [tuple, twin],
        twin == null ? UfwIpVersion.v4 : UfwIpVersion.both,
      );
      if (rule == null) continue;
      if (twin != null) merged.add(twin);
      rules.add(rule);
    }
    for (final tuple in v6) {
      if (merged.contains(tuple)) continue;
      if (parseTuple([tuple], UfwIpVersion.v6) case final rule?) {
        rules.add(rule);
      }
    }
    return rules;
  }

  /// [v6Tuple] with its any-addresses written as v4's, which is what the
  /// same rule looks like in `user.rules`.
  static String _v4Twin(String v6Tuple) {
    if (!v6Tuple.startsWith(tuplePrefix)) return v6Tuple;
    final fields = v6Tuple.substring(tuplePrefix.length).split(' ');
    if (fields.length < 7) return v6Tuple;
    for (final i in const [3, 5]) {
      if (fields[i] == _any6) fields[i] = _any4;
    }
    return '$tuplePrefix${fields.join(' ')}';
  }

  /// Reads one rule from its tuple lines, the first of which says what it
  /// is.
  ///
  /// ```text
  /// <action>[_<log>] <proto> <dport> <dst> <sport> <src> [<dapp> <sapp>]
  ///   <direction>[_<iface>][!out_<iface>] [comment=<hex>]
  /// ```
  ///
  /// with `route:` before the action of a routed rule. Null for a line this does not
  /// recognise, which is left out rather than guessed at.
  static UfwRule? parseTuple(List<String> tuples, UfwIpVersion ipVersion) {
    final line = tuples.first;
    if (!line.startsWith(tuplePrefix)) return null;
    var fields = line.substring(tuplePrefix.length).trim().split(' ');
    String? comment;
    if (fields.last.startsWith('comment=')) {
      comment = _decodeComment(fields.last.substring('comment='.length));
      fields = fields.sublist(0, fields.length - 1);
    }
    if (fields.length != 7 && fields.length != 9) return null;

    var head = fields[0];
    final routed = head.startsWith('route:');
    if (routed) head = head.substring('route:'.length);
    final logAt = head.indexOf('_');
    final action = UfwAction.fromName(
      logAt < 0 ? head : head.substring(0, logAt),
    );
    if (action == null) return null;

    UfwDirection? direction;
    String? interfaceIn;
    String? interfaceOut;
    for (final part in fields.last.split('!')) {
      // Split at the first `_` only: an interface may have one of its own.
      final at = part.indexOf('_');
      final dir = UfwDirection.fromToken(at < 0 ? part : part.substring(0, at));
      if (dir == null) return null;
      direction ??= dir;
      final interface = at < 0 ? null : part.substring(at + 1);
      if (dir == UfwDirection.incoming) {
        interfaceIn = interface;
      } else {
        interfaceOut = interface;
      }
    }
    if (direction == null) return null;

    final apps = fields.length == 9;
    return UfwRule(
      action: action,
      log: logAt < 0 ? null : UfwLog.fromToken(head.substring(logAt + 1)),
      routed: routed,
      direction: direction,
      protocol: _orNull(fields[1]),
      to: UfwEndpoint(
        port: _orNull(fields[2]),
        address: _address(fields[3]),
        app: apps ? _app(fields[6]) : null,
      ),
      from: UfwEndpoint(
        port: _orNull(fields[4]),
        address: _address(fields[5]),
        app: apps ? _app(fields[7]) : null,
      ),
      interfaceIn: interfaceIn,
      interfaceOut: interfaceOut,
      comment: comment,
      ipVersion: ipVersion,
      tuples: List.unmodifiable(tuples),
    );
  }

  static String? _orNull(String value) => value == 'any' ? null : value;

  static String? _address(String value) =>
      value == _any4 || value == _any6 ? null : value;

  /// ufw writes a profile's spaces as `%20`, and `-` for none.
  static String? _app(String value) =>
      value == '-' ? null : value.replaceAll('%20', ' ');

  /// ufw keeps a comment hex-encoded, so that it is one field.
  static String? _decodeComment(String hex) {
    if (hex.isEmpty || hex.length.isOdd) return null;
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      final byte = int.tryParse(hex.substring(i, i + 2), radix: 16);
      if (byte == null) return null;
      bytes.add(byte);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// [commands] as the script that runs them. See [firewallScript].
  static String script(Iterable<String> commands) => firewallScript(commands);

  /// `--force`: ufw otherwise stops to ask whether SSH may be cut off, on a
  /// terminal nobody is reading. The page asks instead.
  static const enableCommand = 'ufw --force enable';
  static const disableCommand = 'ufw disable';
  static const reloadCommand = 'ufw reload';

  static String policyCommand(UfwChain chain, UfwPolicy policy) =>
      'ufw default ${policy.name} ${chain.name}';

  static String loggingCommand(UfwLogLevel level) => 'ufw logging ${level.name}';

  /// Lets TCP in to [port], before every other rule — what a change that
  /// would shut this app out is preceded by. First, because ufw stops at the
  /// first rule that matches: added last, it would come after the deny that
  /// made it necessary.
  static String allowTcpCommand(int port) =>
      'ufw prepend allow in proto tcp from any to any port $port';

  /// Deletes [rule] by the number ufw gives its tuples now, found on the
  /// server as the script runs. A number taken from the page could name
  /// another rule by then: one added or deleted since shifts every number
  /// after it.
  ///
  /// The number is the tuple's line among the v4 file's, then the v6 file's —
  /// ufw's own order. With IPv6 off ufw does not count the v6 ones, and a v6
  /// tuple's line is past the last number it has: ufw refuses it rather than
  /// deleting another rule.
  static List<String> deleteCommands(UfwRule rule) => [
    for (final tuple in rule.tuples) ...[
      't=${shellSingleQuote(tuple)}',
      "n=\$(grep -h '^$tuplePrefix' $_rules4 $_rules6 2>/dev/null"
          r' | grep -nxF -e "$t" | head -n 1 | cut -d: -f1)',
      r'[ -n "$n" ] || { echo "Rule not found: $t" >&2; exit 3; }',
      r'ufw --force delete "$n"',
    ],
  ];

  /// In the order ufw's parser takes them:
  ///
  /// ```text
  /// ufw [route] [prepend] <action> [in on X] [out on Y] [log] [proto P]
  ///   from A [port P] to B [port P | app N] [comment C]
  /// ```
  static String addCommand(UfwRuleDraft draft) {
    if (validateDraft(draft) case final issue?) {
      throw ArgumentError.value(draft, 'draft', issue.name);
    }
    final app = draft.app;
    final port = draft.port.trim();
    final sourcePort = draft.sourcePort.trim();
    final from = draft.from.trim();
    final to = draft.to.trim();
    final interfaceIn = draft.effectiveInterfaceIn;
    final interfaceOut = draft.effectiveInterfaceOut;
    // A rule on this host has one side, so at most one of the two is set.
    final interface = interfaceIn.isEmpty ? interfaceOut : interfaceIn;
    final comment = draft.comment.trim();
    return [
      'ufw',
      if (draft.routed) 'route',
      if (draft.prepend) 'prepend',
      draft.action.name,
      // A routed rule names a side only with its interface; a rule on this
      // host always names its one side.
      if (draft.routed) ...[
        if (interfaceIn.isNotEmpty) ...['in', 'on', shellSingleQuote(interfaceIn)],
        if (interfaceOut.isNotEmpty)
          ...['out', 'on', shellSingleQuote(interfaceOut)],
      ] else ...[
        draft.direction.token,
        if (interface.isNotEmpty) ...['on', shellSingleQuote(interface)],
      ],
      ?draft.log?.token,
      if (app == null && draft.protocol != null) ...['proto', draft.protocol!],
      'from',
      from.isEmpty ? 'any' : shellSingleQuote(from),
      if (sourcePort.isNotEmpty) ...['port', sourcePort],
      'to',
      to.isEmpty ? 'any' : shellSingleQuote(to),
      if (app != null)
        ...['app', shellSingleQuote(app)]
      else if (port.isNotEmpty)
        ...['port', port],
      if (comment.isNotEmpty) ...['comment', shellSingleQuote(comment)],
    ].join(' ');
  }

  static final _portItem = RegExp(r'^(\d{1,5})(?::(\d{1,5}))?$');
  static final _interface = RegExp(r'^[A-Za-z0-9_.+-]{1,15}$');

  /// What ufw would refuse in [draft], or null. ufw checks again; this says
  /// it in the form, and in the user's language.
  static UfwDraftIssue? validateDraft(UfwRuleDraft draft) {
    final port = draft.app == null ? draft.port.trim() : '';
    final sourcePort = draft.sourcePort.trim();
    final from = draft.from.trim();
    final to = draft.to.trim();
    // A rule may match all of an interface's traffic, and nothing else.
    if (draft.app == null &&
        port.isEmpty &&
        sourcePort.isEmpty &&
        from.isEmpty &&
        to.isEmpty &&
        draft.effectiveInterfaceIn.isEmpty &&
        draft.effectiveInterfaceOut.isEmpty) {
      return UfwDraftIssue.nothingMatched;
    }
    // A rule naming a profile takes its protocol from it, and ufw refuses
    // `proto` beside `app`: none is written.
    final protocol = draft.app == null ? draft.protocol : null;
    for (final spec in [port, sourcePort]) {
      if (spec.isEmpty) continue;
      if (_portIssue(spec, protocol) case final issue?) return issue;
    }
    final fromVersion = from.isEmpty ? null : _ipVersionOf(from);
    final toVersion = to.isEmpty ? null : _ipVersionOf(to);
    if ((from.isNotEmpty && fromVersion == null) ||
        (to.isNotEmpty && toVersion == null)) {
      return UfwDraftIssue.invalidAddress;
    }
    if (fromVersion != null && toVersion != null && fromVersion != toVersion) {
      return UfwDraftIssue.mixedIpVersions;
    }
    for (final name in [
      draft.effectiveInterfaceIn,
      draft.effectiveInterfaceOut,
    ]) {
      if (name.isNotEmpty && !_interface.hasMatch(name)) {
        return UfwDraftIssue.invalidInterface;
      }
    }
    // ufw refuses a quote in a comment as invalid syntax.
    if (draft.comment.contains("'") ||
        draft.comment.contains(RegExp(r'[\x00-\x1f\x7f]'))) {
      return UfwDraftIssue.invalidComment;
    }
    return null;
  }

  /// What ufw would refuse in one side's port [spec].
  static UfwDraftIssue? _portIssue(String spec, String? protocol) {
    // iptables' multiport takes 15 ports, a range counting as two.
    var weight = 0;
    for (final item in spec.split(',')) {
      final match = _portItem.firstMatch(item);
      if (match == null) return UfwDraftIssue.invalidPort;
      final start = int.parse(match.group(1)!);
      final end = int.tryParse(match.group(2) ?? '');
      if (start < 1 || start > 65535) return UfwDraftIssue.invalidPort;
      if (end != null && (end <= start || end > 65535)) {
        return UfwDraftIssue.invalidPort;
      }
      weight += end == null ? 1 : 2;
    }
    if (weight > 15) return UfwDraftIssue.tooManyPorts;
    if (weight > 1 && protocol == null) return UfwDraftIssue.portsNeedProtocol;
    return null;
  }

  /// The family of an address or network, or null when [value] is neither.
  static UfwIpVersion? _ipVersionOf(String value) {
    final slash = value.indexOf('/');
    final host = slash < 0 ? value : value.substring(0, slash);
    final address = InternetAddress.tryParse(host);
    if (address == null) return null;
    final v6 = address.type == InternetAddressType.IPv6;
    if (slash >= 0) {
      final prefix = int.tryParse(value.substring(slash + 1));
      if (prefix == null || prefix < 0 || prefix > (v6 ? 128 : 32)) {
        return null;
      }
    }
    return v6 ? UfwIpVersion.v6 : UfwIpVersion.v4;
  }
}
