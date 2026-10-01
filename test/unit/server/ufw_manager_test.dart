import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/firewall.dart';
import 'package:server_box/data/model/server/ufw.dart';
import 'package:server_box/data/service/ufw_manager.dart';

UfwSnapshot _fixture(String name) => UfwManager.parse(
  File('test/fixtures/ufw/$name').readAsStringSync(),
);

void main() {
  group('parse', () {
    final snapshot = _fixture('active.txt');
    UfwRule rule(String port) =>
        snapshot.rules.firstWhere((rule) => rule.to.port == port);

    test('reads status, version, policies and logging', () {
      expect(snapshot.active, isTrue);
      expect(snapshot.version, '0.36.2');
      expect(snapshot.logLevel, UfwLogLevel.low);
      expect(snapshot.ipv6, isTrue);
      expect(snapshot.policies, {
        UfwChain.incoming: UfwPolicy.deny,
        UfwChain.outgoing: UfwPolicy.allow,
        UfwChain.routed: UfwPolicy.deny,
      });
      expect(snapshot.apps.map((a) => a.name), ['My App', 'OpenSSH']);
      expect(snapshot.apps.first.ports.single.port, '8000,8001');
      expect(snapshot.apps.first.ports.single.protocol, 'tcp');
      expect(snapshot.apps.last.ports.single.port, '22');
    });

    test('lists a rule added to both families once, in ufw order', () {
      // 11 v4 tuples and 6 v6 ones, five of which repeat a v4 rule.
      expect(snapshot.rules, hasLength(12));
      expect(snapshot.rules.first.from.address, '203.0.113.9');
      expect(snapshot.rules.last.from.address, '2001:db8::/32');
      expect(snapshot.rules.last.ipVersion, UfwIpVersion.v6);

      final ssh = rule('22');
      expect(ssh.ipVersion, UfwIpVersion.both);
      expect(ssh.tuples, [
        '### tuple ### allow tcp 22 0.0.0.0/0 any 0.0.0.0/0 in '
            'comment=73736820616363657373',
        '### tuple ### allow tcp 22 ::/0 any ::/0 in '
            'comment=73736820616363657373',
      ]);
      expect(ssh.comment, 'ssh access');
      expect(ssh.protocol, 'tcp');
      expect(ssh.to.address, isNull);
      expect(ssh.from.isAny, isTrue);
    });

    test('keeps a rule with an address in its own family', () {
      final web = rule('80,443');
      expect(web.ipVersion, UfwIpVersion.v4);
      expect(web.from.address, '192.168.1.0/24');
      expect(web.tuples, hasLength(1));
    });

    test('reads direction, interfaces, logging and routing', () {
      final out = snapshot.rules.firstWhere(
        (rule) => rule.direction == UfwDirection.outgoing && rule.log == null,
      );
      expect(out.action, UfwAction.deny);
      expect(out.to.port, '25');
      expect(out.protocol, isNull);

      final reject = snapshot.rules.firstWhere(
        (rule) => rule.action == UfwAction.reject,
      );
      expect(reject.interfaceIn, 'eth0');
      expect(reject.to.port, isNull);

      expect(rule('53').log, UfwLog.log);
      expect(rule('22').log, isNull);
      expect(rule('99').log, UfwLog.logAll);
      expect(rule('99').from.port, '1234');
      expect(rule('99').to.address, '10.0.0.1');

      final routed = rule('8080');
      expect(routed.routed, isTrue);
      expect(routed.action, UfwAction.allow);
      expect(routed.direction, UfwDirection.incoming);
      expect(routed.interfaceIn, 'eth0');
      expect(routed.interfaceOut, 'eth1');
      expect(routed.to.address, '10.1.0.0/16');
    });

    test('splits an interface name at its first underscore only', () {
      final dns = snapshot.rules.firstWhere(
        (rule) => rule.to.address == '1.1.1.1',
      );
      expect(dns.direction, UfwDirection.outgoing);
      expect(dns.interfaceOut, 'br_lan');
      expect(dns.comment, 'dns: 中文');
    });

    test('reads an application profile with its resolved ports', () {
      final app = rule('8000,8001');
      expect(app.to.app, 'My App');
      expect(app.from.app, isNull);
      expect(app.ipVersion, UfwIpVersion.both);
      expect(rule('2222').action, UfwAction.limit);
    });

    test('lists no v6 rule with IPv6 off, and reads inactive', () {
      final off = _fixture('inactive_no_ipv6.txt');
      expect(off.active, isFalse);
      expect(off.ipv6, isFalse);
      expect(off.rules, hasLength(11));
      expect(
        off.rules.every((rule) => rule.ipVersion == UfwIpVersion.v4),
        isTrue,
      );
    });

    test('keeps a status it does not recognise, rather than guessing', () {
      final odd = UfwManager.parse(
        '${UfwManager.statusMarker}ERROR: problem running iptables\n',
      );
      expect(odd.active, isNull);
      expect(odd.statusLine, 'ERROR: problem running iptables');
      expect(odd.rules, isEmpty);
    });

    test('refuses output without a status line', () {
      expect(
        () => UfwManager.parse('Cannot read /etc/ufw/user.rules\n'),
        throwsA(isA<UfwManagerException>()),
      );
    });

    test('skips a tuple it cannot read', () {
      expect(
        UfwManager.mergeRules(['### tuple ### allow tcp 22 in'], const []),
        isEmpty,
      );
      expect(
        UfwManager.mergeRules([
          '### tuple ### frobnicate tcp 22 0.0.0.0/0 any 0.0.0.0/0 in',
        ], const []),
        isEmpty,
      );
    });
  });

  group('reach', () {
    final snapshot = _fixture('active.txt');
    FirewallAccess at(int port, [String? client]) => FirewallAccess(
      via: FirewallAccessVia.ssh,
      port: port,
      client: client == null ? null : InternetAddress(client),
    );

    test('the first rule that matches decides', () {
      expect(snapshot.reach(at(22, '192.0.2.1')), FirewallReach.open);
      expect(snapshot.reach(at(2222, '192.0.2.1')), FirewallReach.limited);
      // Rule 1 denies 203.0.113.9 everything, before 22 is allowed.
      expect(snapshot.reach(at(22, '203.0.113.9')), FirewallReach.blocked);
      expect(snapshot.reach(at(3770, '192.0.2.1')), FirewallReach.blocked);
      // An app profile's ports, as ufw resolved them.
      expect(snapshot.reach(at(8001, '192.0.2.1')), FirewallReach.open);
    });

    test('an address-bound rule decides only for its address', () {
      expect(snapshot.reach(at(443, '192.168.1.20')), FirewallReach.open);
      expect(snapshot.reach(at(443, '192.0.2.1')), FirewallReach.blocked);
      // Unknown where it is from: the rule may or may not be for it.
      expect(snapshot.reach(at(443)), FirewallReach.unknown);
      // A v6 rule says nothing of a v4 connection.
      expect(snapshot.reach(at(5000, '192.0.2.1')), FirewallReach.blocked);
      expect(snapshot.reach(at(5000, '2001:db8::9')), FirewallReach.open);
    });

    test('rule 1 may be the one, for an address not known', () {
      // 203.0.113.9 is denied first; anyone else reaches 22.
      expect(snapshot.reach(at(22)), FirewallReach.unknown);
    });

    test('an interface this app cannot see makes it unknown', () {
      // 22 is allowed before `reject in on eth0 from 10.0.0.5` is reached;
      // 2222's limit comes after it, and eth0 may or may not be the way in.
      expect(snapshot.reach(at(22, '10.0.0.5')), FirewallReach.open);
      expect(snapshot.reach(at(2222, '10.0.0.5')), FirewallReach.unknown);
    });

    test('outgoing, routed and udp rules do not count', () {
      expect(snapshot.reach(at(25, '192.0.2.1')), FirewallReach.blocked);
      expect(snapshot.reach(at(8080, '192.0.2.1')), FirewallReach.blocked);
      expect(snapshot.reach(at(53, '192.0.2.1')), FirewallReach.blocked);
    });

    test('a change is judged before it is made', () {
      final access = at(22, '192.0.2.1');
      final rules = snapshot.rules.where((r) => r.to.port != '22').toList();
      expect(snapshot.reach(access, rules: rules), FirewallReach.blocked);
      expect(
        snapshot.reach(access, rules: rules, incoming: UfwPolicy.allow),
        FirewallReach.open,
      );
      final off = _fixture('inactive_no_ipv6.txt');
      expect(off.reach(access), FirewallReach.open);
      expect(off.reach(access, active: true), FirewallReach.open);
      expect(
        off.reach(access, active: true, rules: const []),
        FirewallReach.blocked,
      );
    });

    test('ufw leaves IPv6 alone with it off', () {
      final off = _fixture('inactive_no_ipv6.txt');
      expect(
        off.reach(at(3770, '2001:db8::9'), active: true),
        FirewallReach.open,
      );
    });

    test('a draft becomes the rules ufw would add', () {
      const deny = UfwRuleDraft(
        action: UfwAction.deny,
        direction: UfwDirection.incoming,
        protocol: 'tcp',
        port: '20:30',
      );
      final access = at(22, '192.0.2.1');
      expect(
        snapshot.reach(
          access,
          rules: snapshot.withRules(deny.asRules(snapshot.apps), prepend: true),
        ),
        FirewallReach.blocked,
      );
      // Last, it comes after the rule that already let 22 in.
      expect(
        snapshot.reach(
          access,
          rules: snapshot.withRules(deny.asRules(snapshot.apps), prepend: false),
        ),
        FirewallReach.open,
      );
      const app = UfwRuleDraft(
        action: UfwAction.reject,
        direction: UfwDirection.incoming,
        app: 'OpenSSH',
      );
      expect(
        snapshot.reach(
          access,
          rules: snapshot.withRules(app.asRules(snapshot.apps), prepend: true),
        ),
        FirewallReach.blocked,
      );
      // From one address only: blocked if it is this one.
      const fromOne = UfwRuleDraft(
        action: UfwAction.deny,
        direction: UfwDirection.incoming,
        from: '192.0.2.0/24',
        prepend: true,
      );
      expect(
        snapshot.reach(
          access,
          rules: snapshot.withRules(fromOne.asRules(snapshot.apps), prepend: true),
        ),
        FirewallReach.blocked,
      );
      expect(
        snapshot.reach(
          at(22, '198.51.100.1'),
          rules: snapshot.withRules(fromOne.asRules(snapshot.apps), prepend: true),
        ),
        FirewallReach.open,
      );
    });
  });

  group('commands', () {
    test('add quotes what was typed and puts proto before from', () {
      const draft = UfwRuleDraft(
        action: UfwAction.allow,
        direction: UfwDirection.incoming,
        protocol: 'tcp',
        port: '80,443',
        from: '192.168.1.0/24',
        interfaceIn: 'br_lan',
        comment: r'web $(id) "x"',
        prepend: true,
      );
      expect(
        UfwManager.addCommand(draft),
        "ufw prepend allow in on 'br_lan' proto tcp "
        "from '192.168.1.0/24' to any port 80,443 "
        r"comment 'web $(id) "
        '"x"\'',
      );
    });

    test('add names an application profile without a protocol', () {
      const draft = UfwRuleDraft(
        action: UfwAction.limit,
        direction: UfwDirection.incoming,
        protocol: 'tcp',
        app: 'My App',
      );
      expect(
        UfwManager.addCommand(draft),
        "ufw limit in from any to any app 'My App'",
      );
    });

    test('delete finds every tuple of the rule by its text', () {
      final ssh = _fixture(
        'active.txt',
      ).rules.firstWhere((rule) => rule.to.port == '22');
      final commands = UfwManager.deleteCommands(ssh);
      expect(commands.where((c) => c.startsWith('t=')), [
        "t='${ssh.tuples[0]}'",
        "t='${ssh.tuples[1]}'",
      ]);
      expect(
        commands.where((c) => c == r'ufw --force delete "$n"'),
        hasLength(2),
      );
      // Never 2, which reads as sudo refusing the password.
      expect(commands.join('\n'), contains('exit 3'));
    });

    test('a routed rule names each interface it has, and none it lacks', () {
      expect(
        UfwManager.addCommand(
          const UfwRuleDraft(
            action: UfwAction.allow,
            direction: UfwDirection.incoming,
            routed: true,
            protocol: 'tcp',
            port: '8080',
            to: '10.1.0.0/16',
            interfaceIn: 'eth0',
            interfaceOut: 'eth1',
            prepend: true,
          ),
        ),
        "ufw route prepend allow in on 'eth0' out on 'eth1' proto tcp "
        "from any to '10.1.0.0/16' port 8080",
      );
      expect(
        UfwManager.addCommand(
          const UfwRuleDraft(
            action: UfwAction.deny,
            direction: UfwDirection.incoming,
            routed: true,
            from: '10.0.0.0/8',
            interfaceOut: 'eth1',
          ),
        ),
        "ufw route deny out on 'eth1' from '10.0.0.0/8' to any",
      );
    });

    test('an outgoing rule reads its outgoing interface only', () {
      expect(
        UfwManager.addCommand(
          const UfwRuleDraft(
            action: UfwAction.allow,
            direction: UfwDirection.outgoing,
            protocol: 'udp',
            port: '53',
            sourcePort: '1024:65535',
            interfaceIn: 'eth0',
            interfaceOut: 'wg0',
            log: UfwLog.logAll,
          ),
        ),
        "ufw allow out on 'wg0' log-all proto udp "
        'from any port 1024:65535 to any port 53',
      );
    });

    test('policy and logging use ufw words', () {
      expect(
        UfwManager.policyCommand(UfwChain.incoming, UfwPolicy.deny),
        'ufw default deny incoming',
      );
      expect(
        UfwManager.policyCommand(UfwChain.routed, UfwPolicy.reject),
        'ufw default reject routed',
      );
      expect(
        UfwManager.loggingCommand(UfwLogLevel.off),
        'ufw logging off',
      );
    });

    test('the rule that keeps this app in goes first', () {
      expect(
        UfwManager.allowTcpCommand(22),
        'ufw prepend allow in proto tcp from any to any port 22',
      );
    });
  });

  group('validateDraft', () {
    UfwDraftIssue? check({
      String port = '',
      String? protocol,
      String? app,
      String from = '',
      String to = '',
      String sourcePort = '',
      String interface = '',
      String comment = '',
      bool routed = false,
      UfwDirection direction = UfwDirection.incoming,
    }) => UfwManager.validateDraft(
      UfwRuleDraft(
        action: UfwAction.allow,
        port: port,
        protocol: protocol,
        app: app,
        from: from,
        to: to,
        sourcePort: sourcePort,
        interfaceIn: interface,
        interfaceOut: interface,
        routed: routed,
        direction: direction,
        comment: comment,
      ),
    );

    test('accepts what ufw accepts', () {
      expect(check(port: '22'), isNull);
      expect(check(port: '22', protocol: 'udp'), isNull);
      expect(check(port: '1,2,3:5', protocol: 'tcp'), isNull);
      expect(check(app: 'OpenSSH'), isNull);
      expect(check(from: '10.0.0.0/8'), isNull);
      expect(check(from: '2001:db8::/32', to: '2001:db8::1'), isNull);
      expect(check(port: '22', interface: 'br_lan', comment: 'é "x"'), isNull);
    });

    test('a rule must match something', () {
      expect(check(), UfwDraftIssue.nothingMatched);
      expect(check(routed: true), UfwDraftIssue.nothingMatched);
      // All of an interface's traffic is something.
      expect(check(interface: 'eth0'), isNull);
      expect(check(interface: 'eth0', routed: true), isNull);
    });

    test('a source port is checked as a port', () {
      expect(check(sourcePort: '53'), isNull);
      expect(check(sourcePort: '53,54'), UfwDraftIssue.portsNeedProtocol);
      expect(check(sourcePort: '70000'), UfwDraftIssue.invalidPort);
      // No protocol is written beside a profile, so none makes a list valid.
      expect(
        check(app: 'My App', sourcePort: '53,54', protocol: 'tcp'),
        UfwDraftIssue.portsNeedProtocol,
      );
      expect(check(app: 'My App', sourcePort: '53', protocol: 'tcp'), isNull);
    });

    test('ports', () {
      expect(check(port: '0'), UfwDraftIssue.invalidPort);
      expect(check(port: '65536'), UfwDraftIssue.invalidPort);
      expect(check(port: '30:20', protocol: 'tcp'), UfwDraftIssue.invalidPort);
      expect(check(port: '22,', protocol: 'tcp'), UfwDraftIssue.invalidPort);
      expect(check(port: 'ssh'), UfwDraftIssue.invalidPort);
      expect(check(port: '22:30'), UfwDraftIssue.portsNeedProtocol);
      expect(check(port: '80,443'), UfwDraftIssue.portsNeedProtocol);
      // A range counts as two of iptables' fifteen.
      final fifteen = List.generate(13, (i) => '${i + 1}').join(',');
      expect(check(port: '$fifteen,20:30', protocol: 'tcp'), isNull);
      expect(
        check(port: '$fifteen,14,20:30', protocol: 'tcp'),
        UfwDraftIssue.tooManyPorts,
      );
    });

    test('addresses', () {
      expect(check(from: 'example.com'), UfwDraftIssue.invalidAddress);
      expect(check(from: '10.0.0.0/33'), UfwDraftIssue.invalidAddress);
      expect(
        check(from: '10.0.0.0/8', to: '2001:db8::1'),
        UfwDraftIssue.mixedIpVersions,
      );
    });

    test('interface and comment', () {
      expect(
        check(port: '22', interface: 'eth0; reboot'),
        UfwDraftIssue.invalidInterface,
      );
      expect(check(port: '22', comment: "it's"), UfwDraftIssue.invalidComment);
      expect(check(port: '22', comment: 'a\nb'), UfwDraftIssue.invalidComment);
    });
  });
}
