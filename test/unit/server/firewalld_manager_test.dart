import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/firewall.dart';
import 'package:server_box/data/model/server/firewalld.dart';
import 'package:server_box/data/service/firewalld_manager.dart';

FirewalldSnapshot _fixture(String name) => FirewalldManager.parse(
  File('test/fixtures/firewalld/$name').readAsStringSync(),
);

FirewallAccess _ssh(String? client, {int port = 22}) => FirewallAccess(
  via: FirewallAccessVia.ssh,
  port: port,
  client: client == null ? null : InternetAddress(client),
);

void main() {
  final running = _fixture('running.txt');

  group('parse', () {
    test('reads the daemon, both configurations and the policies', () {
      expect(running.running, isTrue);
      expect(running.version, '1.3.4');
      expect(running.defaultZone, 'public');
      expect(running.panic, isFalse);
      expect(running.runtime, isNotNull);
      expect(
        running.zones.map((z) => z.name),
        containsAll(['block', 'drop', 'internal', 'public', 'trusted']),
      );
      expect(running.policies.single.name, 'allow-host-ipv6');
      // ICMPv6 only: it decides nothing about a TCP connection.
      expect(running.policies.single.decides, isFalse);
    });

    test('reads a zone whole', () {
      final public = running.zone('public')!;
      expect(public.target, FirewalldTarget.defaultTarget);
      expect(public.active, isFalse);
      expect(public.services, ['cockpit', 'dhcpv6-client', 'http', 'ssh']);
      expect(
        public.ports.map((p) => '$p'),
        containsAll(['8080/tcp', '6000-6010/udp', '7777/tcp']),
      );
      expect(public.masquerade, isTrue);
      expect(public.forwardPorts, ['port=80:proto=tcp:toport=8080:toaddr=']);
      expect(public.richRules, hasLength(2));

      final internal = running.zone('internal')!;
      expect(internal.active, isTrue);
      expect(internal.interfaces, ['eth0']);
      expect(running.zone('trusted')!.target, FirewalldTarget.accept);
      expect(running.zone('trusted')!.sources, ['10.8.0.0/24']);
      expect(running.zone('block')!.target, FirewalldTarget.reject);
    });

    test('runtime and permanent are read apart, and differ', () {
      // 7777 was added to the runtime only, 5555 written down only.
      final runtime = running.zone('public')!.ports.map((p) => '$p');
      final saved = running
          .zone('public', permanent: true)!
          .ports
          .map((p) => '$p');
      expect(runtime, contains('7777/tcp'));
      expect(runtime, isNot(contains('5555/tcp')));
      expect(saved, contains('5555/tcp'));
      expect(saved, isNot(contains('7777/tcp')));
      expect(running.drifted, isTrue);
    });

    test('reads rich rules as far as they decide anything', () {
      final [drop, reject] = running.zone('public')!.richRules;
      expect(drop.priority, -10);
      expect(drop.family, 'ipv4');
      expect(drop.source, '198.51.100.7');
      expect(drop.element, isNull);
      expect(drop.action, 'drop');
      expect(reject.priority, 0);
      expect(reject.source, '203.0.113.0/24');
      expect(reject.element, 'service');
      expect(reject.service, 'ssh');
      expect(reject.action, 'reject');

      final odd = FirewalldRichRule.parse(
        'rule family="ipv4" source not address="10.0.0.0/8" '
        'port port="22" protocol="tcp" log prefix="ssh in" level="info" '
        'accept limit value="3/m"',
      );
      expect(odd.sourceNot, isTrue);
      expect(odd.port, '22');
      expect(odd.protocol, 'tcp');
      expect(odd.action, 'accept');
      expect(odd.limited, isTrue);
    });

    test('services carry their ports, /etc over /usr/lib, with includes', () {
      final services = running.services;
      expect(services['ssh'], [const FirewalldPort('22', 'tcp')]);
      expect(services['myapp'], [
        const FirewalldPort('9000', 'tcp'),
        const FirewalldPort('9001-9002', 'udp'),
      ]);
      // Its own port, and RH-Satellite-6's, and foreman's through that.
      final capsule = services['RH-Satellite-6-capsule']!;
      expect(capsule, contains(const FirewalldPort('8443', 'tcp')));
      expect(capsule, contains(const FirewalldPort('5000', 'tcp')));
      expect(running.serviceNames, containsAll(['ssh', 'http', 'myapp']));
    });

    test('a later file of the same name replaces the earlier', () {
      final services = FirewalldManager.parseServices([
        '/usr/lib/firewalld/services/ssh.xml:<port protocol="tcp" port="22"/>',
        '/etc/firewalld/services/ssh.xml:<port protocol="tcp" port="2222"/>',
      ]);
      expect(services['ssh'], [const FirewalldPort('2222', 'tcp')]);
    });

    test('stopped: only what is written down, through the offline tool', () {
      final stopped = _fixture('stopped.txt');
      expect(stopped.running, isFalse);
      expect(stopped.runtime, isNull);
      expect(stopped.drifted, isFalse);
      expect(
        stopped.zone('public')!.ports.map((p) => '$p'),
        contains('5555/tcp'),
      );
      expect(stopped.reach(_ssh('203.0.113.5'), null), FirewallReach.open);
    });

    test('refuses output with no zones section', () {
      expect(
        () => FirewalldManager.parse('SrvBoxFwd.Version\t1\n'),
        throwsA(isA<FirewalldManagerException>()),
      );
    });
  });

  group('reach', () {
    test('a source zone wins over the interface', () {
      // trusted (ACCEPT) holds 10.8.0.0/24.
      expect(
        running.reach(_ssh('10.8.0.5', port: 3770), 'eth0'),
        FirewallReach.open,
      );
    });

    test("the interface's zone, and its services", () {
      // internal has eth0 and ssh.
      expect(running.reach(_ssh('192.0.2.1'), 'eth0'), FirewallReach.open);
      expect(
        running.reach(_ssh('192.0.2.1', port: 3770), 'eth0'),
        FirewallReach.blocked,
      );
    });

    test('the default zone, and its rich rules in priority order', () {
      // public: priority -10 drops 198.51.100.7; 203.0.113.0/24 is refused
      // ssh at 0, before the ssh service lets anyone else in.
      expect(running.reach(_ssh('192.0.2.1'), 'eth9'), FirewallReach.open);
      expect(running.reach(_ssh('203.0.113.5'), 'eth9'), FirewallReach.blocked);
      expect(
        running.reach(_ssh('198.51.100.7', port: 8080), 'eth9'),
        FirewallReach.blocked,
      );
      expect(
        running.reach(_ssh('192.0.2.1', port: 7777), 'eth9'),
        FirewallReach.open,
      );
    });

    test('what cannot be known is said to be unknown', () {
      // No address, no interface: public's address-bound refusals may apply.
      expect(running.reach(_ssh(null), null), FirewallReach.unknown);
    });

    test('a change is judged before it is made', () {
      final zones = [
        for (final z in running.zones)
          z.name == 'internal'
              ? z.copyWith(
                  services: [...z.services]..remove('ssh'),
                )
              : z,
      ];
      expect(
        running.reach(_ssh('192.0.2.1'), 'eth0', zones: zones),
        FirewallReach.blocked,
      );
      expect(
        running.reach(_ssh('192.0.2.1'), 'eth0', panic: true),
        FirewallReach.blocked,
      );
      expect(
        running.reach(_ssh('192.0.2.1'), 'eth0', running: false),
        FirewallReach.open,
      );
    });

    test('a forwarded port sends the connection elsewhere', () {
      final zone = running.zone('public')!.copyWith(
        forwardPorts: ['port=22:proto=tcp:toport=2222:toaddr='],
      );
      expect(
        zone.reach(_ssh('192.0.2.1'), running.services),
        FirewallReach.unknown,
      );
    });

    test('a policy for the host may decide what a zone let in', () {
      const policy = FirewalldPolicy(
        name: 'p',
        target: 'REJECT',
        egressHost: true,
        decides: true,
      );
      final snapshot = FirewalldSnapshot(
        running: true,
        runtime: running.runtime,
        permanent: running.permanent,
        defaultZone: running.defaultZone,
        services: running.services,
        serviceNames: running.serviceNames,
        policies: const [policy],
      );
      expect(snapshot.reach(_ssh('192.0.2.1'), 'eth0'), FirewallReach.unknown);
    });
  });

  group('commands', () {
    test('a change goes to both configurations while running', () {
      expect(
        FirewalldManager.port(
          true,
          'public',
          const FirewalldPort('22', 'tcp'),
          add: true,
        ),
        [
          "firewall-cmd --zone='public' --add-port='22/tcp'",
          "firewall-cmd --permanent --zone='public' --add-port='22/tcp'",
        ],
      );
      expect(
        FirewalldManager.service(false, 'public', 'ssh', add: false),
        ["firewall-offline-cmd --zone='public' --remove-service='ssh'"],
      );
    });

    test('a rich rule is one quoted word', () {
      expect(
        FirewalldManager.richRule(
          true,
          'public',
          'rule family="ipv4" source address="1.2.3.4" drop',
          add: false,
        ).first,
        "firewall-cmd --zone='public' --remove-rich-rule="
        '\'rule family="ipv4" source address="1.2.3.4" drop\'',
      );
    });

    test('a target is written down and reloaded', () {
      expect(
        FirewalldManager.target(true, 'work', FirewalldTarget.reject),
        [
          "firewall-cmd --permanent --zone='work' --set-target='%%REJECT%%'",
          FirewalldManager.reloadCommand,
        ],
      );
    });
  });

  group('input', () {
    test('ports', () {
      expect(FirewalldManager.parsePort('22/tcp'), const FirewalldPort('22', 'tcp'));
      expect(
        FirewalldManager.parsePort(' 6000-6010/udp '),
        const FirewalldPort('6000-6010', 'udp'),
      );
      expect(FirewalldManager.parsePort('22'), isNull);
      expect(FirewalldManager.parsePort('0/tcp'), isNull);
      expect(FirewalldManager.parsePort('20-10/tcp'), isNull);
      expect(FirewalldManager.parsePort('22/icmp'), isNull);
    });

    test('sources', () {
      expect(FirewalldManager.checkSource('10.0.0.0/8'), isNull);
      expect(FirewalldManager.checkSource('2001:db8::/32'), isNull);
      expect(FirewalldManager.checkSource('ipset:blocklist'), isNull);
      expect(FirewalldManager.checkSource('00:11:22:33:44:55'), isNull);
      expect(
        FirewalldManager.checkSource('10.0.0.0/33'),
        FirewalldInputIssue.invalidSource,
      );
      expect(
        FirewalldManager.checkSource('host.example'),
        FirewalldInputIssue.invalidSource,
      );
    });

    test('interfaces, rich rules and forwarded ports', () {
      expect(FirewalldManager.checkInterface('br_lan'), isNull);
      expect(
        FirewalldManager.checkInterface('eth0; reboot'),
        FirewalldInputIssue.invalidInterface,
      );
      expect(FirewalldManager.checkRichRule('rule drop'), isNull);
      expect(
        FirewalldManager.checkRichRule('drop'),
        FirewalldInputIssue.invalidRichRule,
      );
      expect(
        FirewalldManager.checkRichRule('rule drop\nreboot'),
        FirewalldInputIssue.invalidRichRule,
      );
      expect(
        FirewalldManager.checkForwardPort('port=80:proto=tcp:toport=8080'),
        isNull,
      );
      expect(
        FirewalldManager.checkForwardPort(
          'port=80:proto=tcp:toaddr=192.168.1.2',
        ),
        isNull,
      );
      expect(
        FirewalldManager.checkForwardPort('port=80:proto=tcp'),
        FirewalldInputIssue.invalidForwardPort,
      );
    });
  });
}
