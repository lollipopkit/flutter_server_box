import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/firewall.dart';
import 'package:server_box/data/service/firewall.dart';

void main() {
  group('FirewallAccess.fromSshConnection', () {
    test('reads the server port, not the one dialled', () {
      final access = FirewallAccess.fromSshConnection(
        '203.0.113.5 51234 10.0.0.2 22',
      )!;
      expect(access.via, FirewallAccessVia.ssh);
      expect(access.port, 22);
      expect(access.client!.address, '203.0.113.5');
      expect(access.server!.address, '10.0.0.2');
    });

    test('takes IPv6 with a zone', () {
      final access = FirewallAccess.fromSshConnection(
        'fe80::1%eth0 51234 fe80::2%eth0 2222',
      )!;
      expect(access.port, 2222);
      expect(access.client!.type, InternetAddressType.IPv6);
    });

    test('nothing for what is not one', () {
      expect(FirewallAccess.fromSshConnection(''), isNull);
      expect(FirewallAccess.fromSshConnection(null), isNull);
      expect(FirewallAccess.fromSshConnection('a b c d'), isNull);
      expect(FirewallAccess.fromSshConnection('1.1.1.1 1 2.2.2.2 0'), isNull);
    });
  });

  group('networkContains', () {
    final v4 = InternetAddress('192.168.1.77');
    final v6 = InternetAddress('2001:db8::5');

    test('networks and single addresses', () {
      expect(networkContains('192.168.1.0/24', v4), isTrue);
      expect(networkContains('192.168.0.0/23', v4), isTrue);
      expect(networkContains('192.168.2.0/24', v4), isFalse);
      expect(networkContains('192.168.1.77', v4), isTrue);
      expect(networkContains('0.0.0.0/0', v4), isTrue);
      expect(networkContains('192.168.1.64/27', v4), isTrue);
      expect(networkContains('192.168.1.96/27', v4), isFalse);
      expect(networkContains('2001:db8::/32', v6), isTrue);
      expect(networkContains('2001:db9::/32', v6), isFalse);
    });

    test('never across families', () {
      expect(networkContains('0.0.0.0/0', v6), isFalse);
      expect(networkContains('::/0', v4), isFalse);
    });

    test('null for what will not parse', () {
      expect(networkContains('example.com', v4), isNull);
      expect(networkContains('10.0.0.0/40', v4), isNull);
      expect(networkContains('ipset:foo', v4), isNull);
    });
  });

  test('portSpecCovers reads both ufw and firewalld ranges', () {
    expect(portSpecCovers(null, 22), isTrue);
    expect(portSpecCovers('22', 22), isTrue);
    expect(portSpecCovers('80,443', 443), isTrue);
    expect(portSpecCovers('6000:6010', 6005), isTrue);
    expect(portSpecCovers('6000-6010', 6010), isTrue);
    expect(portSpecCovers('6000-6010', 6011), isFalse);
  });

  test('worstChange says only what got worse', () {
    expect(
      worstChange([(FirewallReach.open, FirewallReach.open)]),
      isNull,
    );
    expect(
      worstChange([(FirewallReach.blocked, FirewallReach.blocked)]),
      isNull,
    );
    expect(
      worstChange([
        (FirewallReach.open, FirewallReach.unknown),
        (FirewallReach.open, FirewallReach.blocked),
      ]),
      FirewallReach.blocked,
    );
    expect(
      worstChange([(FirewallReach.open, FirewallReach.limited)]),
      FirewallReach.limited,
    );
  });

  group('FirewallProbe', () {
    test('reads what is installed, what is on, and the connection', () {
      final result = FirewallProbe.parse(
        '${FirewallProbe.ufwMarker}yes\n'
        '${FirewallProbe.firewalldMarker}inactive\n'
        '${FirewallProbe.uidMarker}1000\n'
        '${FirewallProbe.sshMarker}10.9.9.9 51000 192.168.215.3 22\n'
        '${FirewallProbe.ifaceMarker}eth0\n',
      );
      expect(result.installed, {
        FirewallKind.ufw: true,
        FirewallKind.firewalld: false,
      });
      expect(result.root, isFalse);
      expect(result.ssh!.port, 22);
      expect(result.sshInterface, 'eth0');
      expect(result.preferred, FirewallKind.ufw);
    });

    test('firewalld without systemd answers from the daemon', () {
      final result = FirewallProbe.parse(
        '${FirewallProbe.firewalldMarker}running\n'
        '${FirewallProbe.uidMarker}0\n'
        '${FirewallProbe.sshMarker}\n',
      );
      expect(result.installed, {FirewallKind.firewalld: true});
      expect(result.root, isTrue);
      expect(result.ssh, isNull);
    });

    test('prefers the one that is on, firewalld when both are', () {
      FirewallKind? preferred(String ufw, String firewalld) =>
          FirewallProbe.parse(
            '${FirewallProbe.ufwMarker}$ufw\n'
            '${FirewallProbe.firewalldMarker}$firewalld\n',
          ).preferred;
      expect(preferred('no', 'active'), FirewallKind.firewalld);
      expect(preferred('yes', 'inactive'), FirewallKind.ufw);
      expect(preferred('no', 'not running'), FirewallKind.ufw);
      expect(preferred('yes', 'active'), FirewallKind.firewalld);
      expect(
        FirewallProbe.parse('${FirewallProbe.ufwMarker}"yes"\n').installed,
        {FirewallKind.ufw: true},
      );
      expect(FirewallProbe.parse('').preferred, isNull);
    });
  });

  group('firewallScript', () {
    Future<int> exitOf(List<String> commands) async =>
        (await Process.run('sh', ['-c', firewallScript(commands)])).exitCode;

    test('stops at the first failure and keeps its status', () async {
      expect(await exitOf(['true', 'exit 7', 'exit 0']), 7);
      expect(await exitOf(['true', 'true']), 0);
    });

    test('never exits 2, which reads as a refused sudo password', () async {
      expect(await exitOf(['exit 2']), 1);
    });
  });
}
