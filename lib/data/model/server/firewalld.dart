import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/firewall.dart';

/// What a zone does with a packet nothing in it matched.
///
/// `default` rejects, and is what a zone has unless it says otherwise.
/// `%%REJECT%%` is how firewalld writes `REJECT`.
enum FirewalldTarget {
  defaultTarget('default'),
  accept('ACCEPT'),
  drop('DROP'),
  reject('%%REJECT%%');

  const FirewalldTarget(this.token);

  /// What `--list-all` prints, and `--set-target` takes.
  final String token;

  static FirewalldTarget? fromToken(String? value) => switch (value) {
    'REJECT' => reject,
    _ => values.firstWhereOrNull((e) => e.token == value),
  };

  /// As a person reads it: `REJECT` rather than `%%REJECT%%`.
  String get label => this == reject ? 'REJECT' : token;
}

/// One port spec: `8080/tcp`, `6000-6010/udp`.
final class FirewalldPort {
  const FirewalldPort(this.port, this.protocol);

  final String port;
  final String protocol;

  static FirewalldPort? parse(String spec) {
    final slash = spec.indexOf('/');
    if (slash <= 0 || slash == spec.length - 1) return null;
    return FirewalldPort(spec.substring(0, slash), spec.substring(slash + 1));
  }

  bool covers(int port, String protocol) =>
      this.protocol == protocol && portSpecCovers(this.port, port);

  @override
  String toString() => '$port/$protocol';

  @override
  bool operator ==(Object other) =>
      other is FirewalldPort && other.port == port && other.protocol == protocol;

  @override
  int get hashCode => Object.hash(port, protocol);
}

/// A rich rule, read as far as it decides what reaches this host.
///
/// [raw] is what firewalld printed, and what removing it names.
final class FirewalldRichRule {
  const FirewalldRichRule({
    required this.raw,
    this.priority = 0,
    this.family,
    this.source,
    this.sourceNot = false,
    this.sourceOther = false,
    this.destination,
    this.destinationNot = false,
    this.element,
    this.service,
    this.port,
    this.protocol,
    this.action,
    this.limited = false,
  });

  final String raw;
  final int priority;

  /// `ipv4`, `ipv6`, or null for both.
  final String? family;

  final String? source;
  final bool sourceNot;

  /// A source by ipset or MAC, which this app cannot test an address against.
  final bool sourceOther;

  final String? destination;
  final bool destinationNot;

  /// `service`, `port`, `protocol`, `icmp-block`, `forward-port`, …; null
  /// for a rule about all traffic.
  final String? element;
  final String? service;

  /// With [protocol]: the `port` element's.
  final String? port;

  /// The `port` element's protocol, or the `protocol` element's value.
  final String? protocol;

  /// `accept`, `reject`, `drop`, `mark`; null for a rule that only logs.
  final String? action;

  /// The action has a `limit`.
  final bool limited;

  static final _token = RegExp(r'([\w-]+)="([^"]*)"|(\S+)');

  static const _elements = {
    'service',
    'port',
    'protocol',
    'icmp-block',
    'icmp-type',
    'masquerade',
    'forward-port',
    'source-port',
    'tcp-mss-clamp',
  };

  static const _actions = {'accept', 'reject', 'drop', 'mark'};

  static FirewalldRichRule parse(String raw) {
    var priority = 0;
    String? family, source, destination, element, service, port, protocol;
    String? action;
    var sourceNot = false, sourceOther = false, destinationNot = false;
    var limited = false;
    String? context;
    for (final match in _token.allMatches(raw)) {
      final word = match.group(3);
      if (word != null) {
        if (word == 'not') {
          if (context == 'source') sourceNot = true;
          if (context == 'destination') destinationNot = true;
        } else if (word == 'limit') {
          if (_actions.contains(context)) limited = true;
          context = 'limit';
        } else {
          context = word;
          if (_elements.contains(word)) element = word;
          if (_actions.contains(word)) action = word;
        }
        continue;
      }
      final key = match.group(1)!;
      final value = match.group(2)!;
      switch ((context, key)) {
        case ('rule', 'priority'):
          priority = int.tryParse(value) ?? 0;
        case ('rule', 'family'):
          family = value;
        case ('source', 'address'):
          source = value;
        case ('source', 'ipset' || 'mac'):
          sourceOther = true;
        case ('destination', 'address'):
          destination = value;
        case ('service', 'name'):
          service = value;
        case ('port', 'port'):
          port = value;
        case ('port', 'protocol'):
          protocol = value;
        case ('protocol', 'value'):
          protocol = value;
      }
    }
    return FirewalldRichRule(
      raw: raw,
      priority: priority,
      family: family,
      source: source,
      sourceNot: sourceNot,
      sourceOther: sourceOther,
      destination: destination,
      destinationNot: destinationNot,
      element: element,
      service: service,
      port: port,
      protocol: protocol,
      action: action,
      limited: limited,
    );
  }

  /// What this rule decides for a new TCP connection like [access], and
  /// whether it surely applies; null when it surely does not, or decides
  /// nothing. [services] are the ports of each service by name.
  ({FirewallReach verdict, bool sure})? judge(
    FirewallAccess access,
    Map<String, List<FirewalldPort>> services,
  ) {
    final verdict = switch (action) {
      'accept' => limited ? FirewallReach.limited : FirewallReach.open,
      'reject' || 'drop' => FirewallReach.blocked,
      _ => null,
    };
    if (verdict == null) return null;
    var sure = true;
    if (access.client case final client?) {
      final v6 = client.type == InternetAddressType.IPv6;
      if (family != null && family != (v6 ? 'ipv6' : 'ipv4')) return null;
    } else if (family != null) {
      sure = false;
    }
    if (sourceOther) sure = false;
    for (final (network, address, not) in [
      (source, access.client, sourceNot),
      (destination, access.server, destinationNot),
    ]) {
      if (network == null) continue;
      final contains = address == null ? null : networkContains(network, address);
      if (contains == null) {
        sure = false;
      } else if (contains == not) {
        return null;
      }
    }
    switch (element) {
      case null:
        break;
      case 'service':
        final ports = services[service];
        if (ports == null) {
          sure = false;
        } else if (!ports.any((p) => p.covers(access.port, 'tcp'))) {
          return null;
        }
      case 'port':
        if (protocol != 'tcp' || !portSpecCovers(port, access.port)) {
          return null;
        }
      case 'protocol':
        if (protocol != 'tcp') return null;
      case 'source-port':
        sure = false;
      default:
        return null;
    }
    return (verdict: verdict, sure: sure);
  }
}

/// One zone, as one configuration — runtime or permanent — has it.
final class FirewalldZone {
  const FirewalldZone({
    required this.name,
    this.target = FirewalldTarget.defaultTarget,
    this.active = false,
    this.interfaces = const [],
    this.sources = const [],
    this.services = const [],
    this.ports = const [],
    this.protocols = const [],
    this.sourcePorts = const [],
    this.forwardPorts = const [],
    this.richRules = const [],
    this.masquerade = false,
  });

  final String name;
  final FirewalldTarget target;

  /// Has an interface or a source bound to it, so something reaches it.
  final bool active;
  final List<String> interfaces;
  final List<String> sources;
  final List<String> services;
  final List<FirewalldPort> ports;
  final List<String> protocols;
  final List<FirewalldPort> sourcePorts;

  /// `port=80:proto=tcp:toport=8080:toaddr=`, as firewalld writes them.
  final List<String> forwardPorts;
  final List<FirewalldRichRule> richRules;
  final bool masquerade;

  FirewalldZone copyWith({
    FirewalldTarget? target,
    List<String>? interfaces,
    List<String>? sources,
    List<String>? services,
    List<FirewalldPort>? ports,
    List<String>? protocols,
    List<String>? forwardPorts,
    List<FirewalldRichRule>? richRules,
  }) => FirewalldZone(
    name: name,
    target: target ?? this.target,
    active: active,
    interfaces: interfaces ?? this.interfaces,
    sources: sources ?? this.sources,
    services: services ?? this.services,
    ports: ports ?? this.ports,
    protocols: protocols ?? this.protocols,
    sourcePorts: sourcePorts,
    forwardPorts: forwardPorts ?? this.forwardPorts,
    richRules: richRules ?? this.richRules,
    masquerade: masquerade,
  );

  /// Whether a new connection like [access] that this zone handles gets
  /// through, in firewalld's order: rich rules below priority 0, then at 0
  /// the rejects and drops before everything that accepts, then rich rules
  /// above 0, then [target]. Forwarded ports come first of all: they
  /// rewrite the connection before any of it is asked.
  FirewallReach reach(
    FirewallAccess access,
    Map<String, List<FirewalldPort>> services,
  ) {
    final checks = <({FirewallReach verdict, bool sure})?>[];
    for (final spec in forwardPorts) {
      final fields = {
        for (final part in spec.split(':'))
          if (part.indexOf('=') case final eq when eq > 0)
            part.substring(0, eq): part.substring(eq + 1),
      };
      if (fields['proto'] == 'tcp' &&
          portSpecCovers(fields['port'], access.port)) {
        // Sent somewhere else: whether that answers is not this zone's to say.
        checks.add((verdict: FirewallReach.blocked, sure: false));
      }
    }
    final rich = [...richRules]
      ..sort((a, b) => a.priority.compareTo(b.priority));
    List<({FirewallReach verdict, bool sure})?> judged(
      Iterable<FirewalldRichRule> rules,
    ) => [for (final rule in rules) rule.judge(access, services)];

    checks.addAll(judged(rich.where((r) => r.priority < 0)));
    final atZero = judged(rich.where((r) => r.priority == 0));
    checks.addAll(atZero.where((c) => c?.verdict == FirewallReach.blocked));
    final admitted =
        protocols.contains('tcp') ||
        ports.any((p) => p.covers(access.port, 'tcp')) ||
        services.entries.any(
          (e) =>
              this.services.contains(e.key) &&
              e.value.any((p) => p.covers(access.port, 'tcp')),
        );
    if (admitted) checks.add((verdict: FirewallReach.open, sure: true));
    // A service this app has no definition of may be the one that admits it.
    if (this.services.any((s) => !services.containsKey(s))) {
      checks.add((verdict: FirewallReach.open, sure: false));
    }
    if (sourcePorts.any((p) => p.protocol == 'tcp')) {
      checks.add((verdict: FirewallReach.open, sure: false));
    }
    checks.addAll(atZero.where((c) => c?.verdict != FirewallReach.blocked));
    checks.addAll(judged(rich.where((r) => r.priority > 0)));

    final maybes = <FirewallReach>{};
    FirewallReach? decided;
    for (final check in checks) {
      if (check == null) continue;
      if (!check.sure) {
        maybes.add(check.verdict);
        continue;
      }
      decided = check.verdict;
      break;
    }
    final verdict =
        decided ??
        (target == FirewalldTarget.accept
            ? FirewallReach.open
            : FirewallReach.blocked);
    if (maybes.any((m) => m.admits != verdict.admits)) {
      return FirewallReach.unknown;
    }
    return verdict;
  }
}

/// A policy, as far as it can decide what reaches this host.
final class FirewalldPolicy {
  const FirewalldPolicy({
    required this.name,
    required this.target,
    required this.egressHost,
    required this.decides,
  });

  final String name;
  final String target;

  /// Applies to traffic for this host itself.
  final bool egressHost;

  /// Has a target or an entry that accepts or refuses anything other than
  /// ICMP — the default `allow-host-ipv6` only lets ICMPv6 in.
  final bool decides;
}

/// What a server's firewalld is doing, as one read found it.
final class FirewalldSnapshot {
  const FirewalldSnapshot({
    required this.running,
    required this.permanent,
    required this.services,
    required this.serviceNames,
    this.runtime,
    this.defaultZone,
    this.version,
    this.panic = false,
    this.policies = const [],
  });

  /// The daemon is up, and [runtime] is what it enforces.
  final bool running;
  final String? version;
  final String? defaultZone;

  /// Every packet dropped: `--panic-on`.
  final bool panic;

  /// Zones as the daemon has them now; null when it is not running.
  final List<FirewalldZone>? runtime;

  /// Zones as they are written down, and will be after a reload or a boot.
  final List<FirewalldZone> permanent;

  /// The TCP and UDP ports of each service, by name.
  final Map<String, List<FirewalldPort>> services;

  /// Every service a zone could name.
  final List<String> serviceNames;
  final List<FirewalldPolicy> policies;

  /// What is in force: [runtime] while running, else [permanent].
  List<FirewalldZone> get zones => runtime ?? permanent;

  FirewalldZone? zone(String name, {bool permanent = false}) =>
      (permanent ? this.permanent : zones).firstWhereOrNull(
        (z) => z.name == name,
      );

  /// The runtime differs from what is written down: a reload or a boot will
  /// change what the firewall does.
  bool get drifted {
    final runtime = this.runtime;
    if (runtime == null) return false;
    String digest(FirewalldZone z) => [
      z.target.token,
      ...[...z.interfaces]..sort(),
      '|',
      ...[...z.sources]..sort(),
      '|',
      ...[...z.services]..sort(),
      '|',
      ...z.ports.map((p) => '$p').toList()..sort(),
      '|',
      ...[...z.protocols]..sort(),
      '|',
      ...[...z.forwardPorts]..sort(),
      '|',
      ...z.richRules.map((r) => r.raw).toList()..sort(),
      '|${z.masquerade}',
    ].join(' ');
    // Interfaces are left out: one NetworkManager put in a zone is
    // runtime-only by nature, and not a difference anyone made.
    final saved = {
      for (final z in permanent) z.name: digest(z.copyWith(interfaces: const [])),
    };
    return runtime.any(
      (z) => saved[z.name] != digest(z.copyWith(interfaces: const [])),
    );
  }

  /// The zones a connection like [access] may be handled by: the one whose
  /// sources hold its address, else the one its interface ([interface],
  /// where known) is in, else the default zone. Where something is not
  /// known, every zone it could be.
  List<FirewalldZone> zonesFor(
    FirewallAccess access,
    String? interface, {
    List<FirewalldZone>? zones,
    String? defaultZone,
  }) {
    final list = zones ?? this.zones;
    final fallback = list.firstWhereOrNull(
      (z) => z.name == (defaultZone ?? this.defaultZone),
    );
    final bySource = <FirewalldZone>{};
    var sourceUnknown = false;
    for (final zone in list) {
      for (final source in zone.sources) {
        final client = access.client;
        final contains = client == null ? null : networkContains(source, client);
        if (contains == true) bySource.add(zone);
        if (contains == null) sourceUnknown = true;
      }
    }
    if (bySource.isNotEmpty && !sourceUnknown) return bySource.toList();
    final byInterface = interface == null
        ? list.where((z) => z.interfaces.isNotEmpty).toList()
        : list.where((z) => z.interfaces.contains(interface)).toList();
    final candidates = <FirewalldZone>{
      ...bySource,
      if (sourceUnknown)
        ...list.where((z) => z.sources.isNotEmpty),
      ...byInterface,
      // The default zone takes an interface no zone names — and, where the
      // interface is unknown, may be the one.
      if (interface == null || byInterface.isEmpty) ?fallback,
    };
    return candidates.toList();
  }

  /// Whether a new connection like [access] gets through. [interface] is
  /// the one it arrives on, where the server said.
  ///
  /// [running], [panic], [zones] and [defaultZone] stand in for this
  /// snapshot's own, to ask about a change before it is made.
  FirewallReach reach(
    FirewallAccess access,
    String? interface, {
    bool? running,
    bool? panic,
    List<FirewalldZone>? zones,
    String? defaultZone,
  }) {
    if (!(running ?? this.running)) return FirewallReach.open;
    if (panic ?? this.panic) return FirewallReach.blocked;
    final candidates = zonesFor(
      access,
      interface,
      zones: zones,
      defaultZone: defaultZone,
    );
    if (candidates.isEmpty) return FirewallReach.unknown;
    final reaches = {for (final z in candidates) z.reach(access, services)};
    var reach = switch (reaches) {
      _ when reaches.length == 1 => reaches.single,
      // Let in by every zone it may be in, some at a rate.
      _ when reaches.every((r) => r.admits) => FirewallReach.limited,
      _ => FirewallReach.unknown,
    };
    if (reach.admits && policies.any((p) => p.egressHost && p.decides)) {
      reach = FirewallReach.unknown;
    }
    return reach;
  }
}
