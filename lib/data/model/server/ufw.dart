import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:material_ui/material_ui.dart';
import 'package:server_box/data/model/server/firewall.dart';

/// What a ufw rule does with a packet it matches. Named as ufw names them,
/// which is also the word the rule is added with.
enum UfwAction {
  allow,
  deny,
  reject,

  /// Allows, but denies an address that opened six or more connections in
  /// the last thirty seconds.
  limit;

  static UfwAction? fromName(String? value) =>
      values.firstWhereOrNull((e) => e.name == value);

  /// Whether a matching packet is let through.
  bool get admits => this == allow || this == limit;

  Color get color => switch (this) {
    allow => Colors.green,
    deny => Colors.red,
    reject => Colors.orange,
    limit => Colors.blue,
  };
}

enum UfwDirection {
  incoming('in'),
  outgoing('out');

  const UfwDirection(this.token);

  /// The word ufw takes and writes: `in`, `out`.
  final String token;

  static UfwDirection? fromToken(String? value) =>
      values.firstWhereOrNull((e) => e.token == value);
}

/// What ufw does with a packet no rule matched.
///
/// Stored in `/etc/default/ufw` under iptables' names (`ACCEPT`, `DROP`,
/// `REJECT`); set with ufw's (`ufw default deny incoming`).
enum UfwPolicy {
  allow('ACCEPT'),
  deny('DROP'),
  reject('REJECT');

  const UfwPolicy(this.target);

  final String target;

  static UfwPolicy? fromTarget(String? value) =>
      values.firstWhereOrNull((e) => e.target == value?.toUpperCase());
}

/// The three chains a default policy is set for.
enum UfwChain {
  incoming('INPUT'),
  outgoing('OUTPUT'),
  routed('FORWARD');

  const UfwChain(this.key);

  /// `DEFAULT_<key>_POLICY` in `/etc/default/ufw`.
  final String key;
}

enum UfwLogLevel {
  off,
  low,
  medium,
  high,
  full;

  static UfwLogLevel? fromName(String? value) =>
      values.firstWhereOrNull((e) => e.name == value?.toLowerCase());
}

enum UfwIpVersion { v4, v6, both }

/// What a rule logs of its own, beyond ufw's logging level.
enum UfwLog {
  /// New connections the rule matches.
  log('log'),

  /// Every packet the rule matches.
  logAll('log-all');

  const UfwLog(this.token);

  /// The word ufw takes and writes.
  final String token;

  static UfwLog? fromToken(String? value) =>
      values.firstWhereOrNull((e) => e.token == value);
}

/// One end of a rule: an address, and a port or an application profile.
final class UfwEndpoint {
  const UfwEndpoint({this.address, this.port, this.app});

  /// Null for any address.
  final String? address;

  /// As ufw writes it: `22`, `80,443`, `6000:6010`. Null for any port.
  final String? port;

  /// The application profile [port] came from, as the rule was added.
  final String? app;

  bool get isAny => address == null && port == null && app == null;
}

/// One rule, as ufw keeps it in `/etc/ufw/user.rules` and `user6.rules`.
///
/// Read from the `### tuple ###` lines of those files rather than from
/// `ufw status`. The status table is drawn for reading: its columns are
/// padded to a width a long rule overflows, its words are translated with the
/// server's locale, and an inactive firewall prints no rules at all. The
/// tuples are what ufw itself reloads its rules from.
final class UfwRule {
  const UfwRule({
    required this.action,
    required this.direction,
    required this.protocol,
    required this.to,
    required this.from,
    required this.ipVersion,
    required this.tuples,
    this.routed = false,
    this.log,
    this.interfaceIn,
    this.interfaceOut,
    this.comment,
  });

  final UfwAction action;
  final UfwDirection direction;

  /// A `ufw route` rule, which matches forwarded packets rather than those
  /// addressed to this host.
  final bool routed;

  /// Null when the rule logs nothing of its own.
  final UfwLog? log;

  /// `tcp`, `udp`, another protocol name, or null for any.
  final String? protocol;

  final UfwEndpoint to;
  final UfwEndpoint from;

  /// The interface a packet arrives on, for an incoming or routed rule.
  final String? interfaceIn;

  /// The interface a packet leaves by, for an outgoing or routed rule.
  final String? interfaceOut;

  final String? comment;

  /// [UfwIpVersion.both] where ufw added the same rule to both families, as
  /// it does for a rule naming no address; deleting it deletes both.
  final UfwIpVersion ipVersion;

  /// The tuple lines this rule was read from, v4's first. Deletion names a
  /// rule by these, never by a position the list may have moved since.
  final List<String> tuples;

  /// The rule's port spec as `ufw status` prints it: `22/tcp`, `25`.
  static String? portSpec(String? port, String? protocol) {
    if (port == null) return null;
    return protocol == null ? port : '$port/$protocol';
  }

  /// What this rule does to a new connection like [access]: its verdict,
  /// and whether it surely applies or only might.
  ///
  /// Null when it surely does not. "Might" is an address, a source port or
  /// an interface this app cannot know for the connection.
  ({FirewallReach verdict, bool sure})? judge(FirewallAccess access) {
    if (routed || direction != UfwDirection.incoming) return null;
    if (protocol != null && protocol != 'tcp') return null;
    if (!portSpecCovers(to.port, access.port)) return null;
    final client = access.client;
    if (client != null) {
      final v6 = client.type == InternetAddressType.IPv6;
      if (ipVersion == (v6 ? UfwIpVersion.v4 : UfwIpVersion.v6)) return null;
    }
    var sure = interfaceIn == null && from.port == null;
    for (final (network, address) in [
      (from.address, client),
      (to.address, access.server),
    ]) {
      if (network == null) continue;
      final contains = address == null
          ? null
          : networkContains(network, address);
      if (contains == false) return null;
      if (contains == null) sure = false;
    }
    return (
      verdict: switch (action) {
        UfwAction.allow => FirewallReach.open,
        UfwAction.limit => FirewallReach.limited,
        UfwAction.deny || UfwAction.reject => FirewallReach.blocked,
      },
      sure: sure,
    );
  }
}

/// One port spec of an application profile: `80,443/tcp`, `53`.
final class UfwAppPort {
  const UfwAppPort(this.port, this.protocol);

  final String port;

  /// Null for both.
  final String? protocol;

  static UfwAppPort? parse(String spec) {
    final value = spec.trim();
    if (value.isEmpty) return null;
    final slash = value.indexOf('/');
    return slash < 0
        ? UfwAppPort(value, null)
        : UfwAppPort(value.substring(0, slash), value.substring(slash + 1));
  }
}

/// An application profile: a name a rule can use for its ports.
final class UfwApp {
  const UfwApp(this.name, this.ports);

  final String name;
  final List<UfwAppPort> ports;
}

/// What a server's ufw is doing, as one read found it.
final class UfwSnapshot {
  const UfwSnapshot({
    required this.active,
    required this.rules,
    required this.policies,
    required this.apps,
    this.statusLine,
    this.version,
    this.logLevel,
    this.ipv6 = true,
  });

  /// Whether ufw's rules are loaded now; null when `ufw status` answered
  /// something other than a status, which [statusLine] then holds.
  final bool? active;
  final String? statusLine;

  /// `0.36.2`.
  final String? version;
  final UfwLogLevel? logLevel;

  /// `IPV6=yes`. With it off ufw loads no v6 rule, so none is listed.
  final bool ipv6;

  final Map<UfwChain, UfwPolicy> policies;
  final List<UfwRule> rules;

  /// Application profiles a rule can name, from `ufw app info all`.
  final List<UfwApp> apps;

  /// Whether a new connection like [access] gets through, the way ufw
  /// decides it: the first rule that matches, else the incoming policy.
  ///
  /// [active], [rules] and [incoming] stand in for this snapshot's own, to
  /// ask about a change before it is made.
  ///
  /// A rule that only might match — an address, a source port or an
  /// interface this app cannot know for the connection — makes the answer
  /// [FirewallReach.unknown] where it would decide otherwise than the rule
  /// that surely matches after it.
  FirewallReach reach(
    FirewallAccess access, {
    bool? active,
    List<UfwRule>? rules,
    UfwPolicy? incoming,
  }) {
    if (!(active ?? this.active ?? false)) return FirewallReach.open;
    // With IPv6 off ufw leaves ip6tables alone, whatever the rules say.
    if (!ipv6 && access.client?.type == InternetAddressType.IPv6) {
      return FirewallReach.open;
    }
    final maybes = <FirewallReach>{};
    FirewallReach? decided;
    for (final rule in rules ?? this.rules) {
      final judged = rule.judge(access);
      if (judged == null) continue;
      if (!judged.sure) {
        maybes.add(judged.verdict);
        continue;
      }
      decided = judged.verdict;
      break;
    }
    decided ??= switch (incoming ?? policies[UfwChain.incoming]) {
      UfwPolicy.allow => FirewallReach.open,
      // Not knowing it is not knowing ufw lets anything in.
      UfwPolicy.deny || UfwPolicy.reject || null => FirewallReach.blocked,
    };
    final verdict = decided;
    if (maybes.any((maybe) => maybe.admits != verdict.admits)) {
      return FirewallReach.unknown;
    }
    return verdict;
  }

  /// [rules] with [added] put where ufw puts a new rule: first, or last.
  List<UfwRule> withRules(List<UfwRule> added, {required bool prepend}) =>
      prepend ? [...added, ...rules] : [...rules, ...added];
}

/// A rule as the add form describes it.
final class UfwRuleDraft {
  const UfwRuleDraft({
    required this.action,
    required this.direction,
    this.routed = false,
    this.protocol,
    this.port = '',
    this.sourcePort = '',
    this.app,
    this.from = '',
    this.to = '',
    this.interfaceIn = '',
    this.interfaceOut = '',
    this.log,
    this.comment = '',
    this.prepend = false,
  });

  final UfwAction action;

  /// Which side of this host the rule is on. Not asked of a [routed] rule,
  /// whose interfaces say.
  final UfwDirection direction;

  /// A `ufw route` rule, for packets this host forwards.
  final bool routed;

  /// `tcp`, `udp` or null for both. Not offered with [app], whose profile
  /// says.
  final String? protocol;

  /// The destination port.
  final String port;
  final String sourcePort;
  final String? app;

  /// Empty for any address.
  final String from;
  final String to;

  /// The interface a packet arrives on: an incoming rule's, or a routed
  /// one's. An outgoing rule has none, and this is not read for it.
  final String interfaceIn;

  /// The interface a packet leaves by: an outgoing rule's, or a routed one's.
  /// An incoming rule has none, and this is not read for it.
  final String interfaceOut;

  final UfwLog? log;
  final String comment;

  /// Put before every other rule, rather than after: ufw stops at the first
  /// rule that matches.
  final bool prepend;

  /// [interfaceIn] where this rule has one, trimmed; empty otherwise.
  String get effectiveInterfaceIn =>
      routed || direction == UfwDirection.incoming ? interfaceIn.trim() : '';

  /// [interfaceOut] where this rule has one, trimmed; empty otherwise.
  String get effectiveInterfaceOut =>
      routed || direction == UfwDirection.outgoing ? interfaceOut.trim() : '';

  /// The rules ufw would add for this draft, as far as they decide what
  /// reaches this host: one per port spec of an application profile, which
  /// [apps] says. Without the profile there, none — nothing can be said of
  /// ports this app does not know.
  List<UfwRule> asRules(List<UfwApp> apps) {
    String? orNull(String value) => value.trim().isEmpty ? null : value.trim();
    final ports = app == null
        ? [UfwAppPort(port.trim(), protocol)]
        : apps.firstWhereOrNull((e) => e.name == app)?.ports ?? const [];
    final family = [from, to].any((a) => a.contains(':'))
        ? UfwIpVersion.v6
        : [from, to].any((a) => a.trim().isNotEmpty)
        ? UfwIpVersion.v4
        : UfwIpVersion.both;
    return [
      for (final spec in ports)
        UfwRule(
          action: action,
          direction: direction,
          routed: routed,
          protocol: spec.protocol,
          to: UfwEndpoint(address: orNull(to), port: orNull(spec.port), app: app),
          from: UfwEndpoint(address: orNull(from), port: orNull(sourcePort)),
          interfaceIn: orNull(effectiveInterfaceIn),
          interfaceOut: orNull(effectiveInterfaceOut),
          ipVersion: family,
          tuples: const [],
        ),
    ];
  }
}

/// Why [UfwRuleDraft] cannot be added, said before ufw is asked.
enum UfwDraftIssue {
  nothingMatched,
  invalidPort,
  tooManyPorts,
  portsNeedProtocol,
  invalidAddress,
  mixedIpVersions,
  invalidInterface,
  invalidComment,
}
