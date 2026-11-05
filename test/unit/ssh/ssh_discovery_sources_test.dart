import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/service/ssh_discovery.dart';
import 'package:server_box/core/service/ssh_discovery_cloudflare.dart';
import 'package:server_box/core/service/ssh_discovery_ssh_config.dart';
import 'package:server_box/core/service/ssh_discovery_tailscale.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

void main() {
  group('Tailscale', () {
    const ts = TailscaleDiscovery('/usr/bin/tailscale');

    Map<String, Object?> peer(String host, String os, {bool online = true}) => {
      'ID': 'n-$host',
      'HostName': host,
      'DNSName': '$host.example.ts.net.',
      'OS': os,
      'Online': online,
      'TailscaleIPs': ['100.64.0.${host.length}', 'fd7a::1'],
    };

    String status({bool magicDns = true, String state = 'Running'}) =>
        jsonEncode({
          'BackendState': state,
          'CurrentTailnet': {
            'Name': 'me@example.com',
            'MagicDNSSuffix': 'example.ts.net',
            'MagicDNSEnabled': magicDns,
          },
          'Peer': {
            'a': peer('nas', 'linux'),
            'b': peer('phone', 'iOS'),
            'c': peer('desk', 'windows', online: false),
          },
        });

    test('peers by MagicDNS name, phones left out', () {
      final run = ts.parse(status());
      expect(run.scope, 'example.ts.net');
      expect(run.hosts.map((e) => (e.server.name, e.host, e.online)), [
        ('nas', 'nas.example.ts.net', true),
        ('desk', 'desk.example.ts.net', false),
      ]);
      expect(run.hosts.first.detail, '100.64.0.3 · linux');
    });

    test('by IPv4 without MagicDNS', () {
      final run = ts.parse(status(magicDns: false));
      expect(run.hosts.map((e) => e.host), ['100.64.0.3', '100.64.0.4']);
    });

    test('a backend not running is an error, not an empty list', () {
      expect(
        () => ts.parse(status(state: 'Stopped')),
        throwsA(isA<SshDiscoveryException>()),
      );
    });
  });

  group('Cloudflare', () {
    test('ssh:// rules with a hostname, through cloudflared', () {
      final hosts = CloudflareDiscovery.hostsOf(
        {'name': 'home', 'status': 'healthy'},
        {
          'config': {
            'ingress': [
              {'hostname': 'ssh.example.com', 'service': 'ssh://localhost:22'},
              {'hostname': 'web.example.com', 'service': 'http://localhost:80'},
              {'hostname': '*.example.com', 'service': 'ssh://localhost:22'},
              {'service': 'http_status:404'},
            ],
          },
        },
      );
      expect(hosts.single.host, 'ssh.example.com');
      expect(hosts.single.online, isTrue);
      expect(hosts.single.detail, 'home · ssh://localhost:22');
      expect(
        hosts.single.server.ssh?.proxyCommand,
        CloudflareDiscovery.proxyCommand,
      );
    });

    test('a locally managed tunnel has no configuration to read', () {
      expect(
        CloudflareDiscovery.hostsOf({'status': 'down'}, {'config': null}),
        isEmpty,
      );
    });
  });

  test('SSH config: each host carries the hops its jumps name', () {
    const bastion = Spi(
      name: 'bastion',
      id: 'b',
      ssh: SshCredential(ip: 'bastion.example.com'),
    );
    const edge = Spi(
      name: 'edge',
      id: 'e',
      ssh: SshCredential(ip: '10.0.0.1', jumpIds: ['b']),
    );
    const db = Spi(
      name: 'db',
      id: 'd',
      ssh: SshCredential(ip: '10.0.0.2', jumpIds: ['e']),
    );
    final hosts = SshConfigDiscovery.hostsOf([bastion, edge, db]);
    expect(hosts.map((e) => e.via.map((v) => v.id).toList()), [
      <String>[],
      ['b'],
      ['b', 'e'],
    ]);
    expect(hosts.last.detail, 'ProxyJump edge');
  });
}
