import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:server_box/core/utils/ssh_config.dart';

void main() {
  group('SSHConfig Tests', () {
    late Directory tempDir;
    late File configFile;

    setUp(() async {
      // Create temporary directory for test SSH config files
      tempDir = await Directory.systemTemp.createTemp('ssh_config_test');
      configFile = File('${tempDir.path}/config');
    });

    tearDown(() async {
      // Clean up temporary files
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('configExists returns false for non-existent file', () async {
      final (_, exists) = SSHConfig.configExists('/non/existent/path');
      expect(exists, false);
    });

    test('configExists returns true for existing file', () async {
      await configFile.writeAsString('Host example\n  HostName example.com\n');
      final (_, exists) = SSHConfig.configExists(configFile.path);
      expect(exists, true);
    });

    test('parseConfig handles empty file', () async {
      await configFile.writeAsString('');
      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, isEmpty);
    });

    test('parseConfig handles file with only comments', () async {
      await configFile.writeAsString('''
# This is a comment
# Another comment
''');
      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, isEmpty);
    });

    test('parseConfig parses single host correctly', () async {
      await configFile.writeAsString('''
Host myserver
  HostName 192.168.1.100
  User admin
  Port 2222
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(1));

      final server = servers.first;
      expect(server.name, 'myserver');
      expect(server.ssh?.ip, '192.168.1.100');
      expect(server.ssh?.user, 'admin');
      expect(server.ssh?.port, 2222);
    });

    test('parseConfig handles missing HostName', () async {
      await configFile.writeAsString('''
Host myserver
  User admin
  Port 2222
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, isEmpty); // Should skip hosts without HostName
    });

    test('parseConfig uses defaults for missing optional fields', () async {
      await configFile.writeAsString('''
Host simple
  HostName example.com
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(1));

      final server = servers.first;
      expect(server.name, 'simple');
      expect(server.ssh?.ip, 'example.com');
      expect(server.ssh?.user, 'root'); // default user
      expect(server.ssh?.port, 22); // default port
    });

    test('parseConfig handles multiple hosts', () async {
      await configFile.writeAsString('''
Host server1
  HostName 192.168.1.100
  User alice
  Port 22

Host server2
  HostName 192.168.1.200
  User bob
  Port 2222

Host server3
  HostName example.com
  User charlie
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(3));

      expect(servers[0].name, 'server1');
      expect(servers[0].ssh?.ip, '192.168.1.100');
      expect(servers[0].ssh?.user, 'alice');
      expect(servers[0].ssh?.port, 22);

      expect(servers[1].name, 'server2');
      expect(servers[1].ssh?.ip, '192.168.1.200');
      expect(servers[1].ssh?.user, 'bob');
      expect(servers[1].ssh?.port, 2222);

      expect(servers[2].name, 'server3');
      expect(servers[2].ssh?.ip, 'example.com');
      expect(servers[2].ssh?.user, 'charlie');
      expect(servers[2].ssh?.port, 22);
    });

    test('parseConfig handles case insensitive keywords', () async {
      await configFile.writeAsString('''
host myserver
  hostname 192.168.1.100
  user admin
  port 2222
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(1));

      final server = servers.first;
      expect(server.name, 'myserver');
      expect(server.ssh?.ip, '192.168.1.100');
      expect(server.ssh?.user, 'admin');
      expect(server.ssh?.port, 2222);
    });

    test('parseConfig handles comments and empty lines', () async {
      await configFile.writeAsString('''
# Global settings
Host *
  ServerAliveInterval 60

# My development server
Host devserver
  HostName 192.168.1.50
  User developer  # development user
  Port 22

# Empty line below

Host prodserver
  HostName 10.0.0.100
  User production
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(2));

      expect(servers[0].name, 'devserver');
      expect(servers[0].ssh?.ip, '192.168.1.50');
      expect(servers[0].ssh?.user, 'developer');

      expect(servers[1].name, 'prodserver');
      expect(servers[1].ssh?.ip, '10.0.0.100');
      expect(servers[1].ssh?.user, 'production');
    });

    test('parseConfig handles wildcard hosts', () async {
      await configFile.writeAsString('''
Host *
  User defaultuser
  Port 2222

Host myserver
  HostName 192.168.1.100
  User admin
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(1)); // Only named hosts, not wildcards

      final server = servers.first;
      expect(server.name, 'myserver');
      expect(server.ssh?.ip, '192.168.1.100');
      expect(server.ssh?.user, 'defaultuser');
      expect(server.ssh?.port, 2222);
    });

    test('parseConfig handles IdentityFile', () async {
      await configFile.writeAsString('''
Host keyserver
  HostName 192.168.1.100
  User admin
  IdentityFile ~/.ssh/special_key
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(1));

      final server = servers.first;
      // A path, never a key-store id — asserting `keyId` here is what let the
      // bug ship: every reader looks that field up in `Stores.key`.
      expect(server.ssh?.keyPath, '~/.ssh/special_key');
      expect(server.ssh?.keyId, isNull);
    });

    test('expands supported IdentityFile tokens', () {
      final localUser =
          Platform.environment['USER'] ??
          Platform.environment['USERNAME'] ??
          '';
      expect(
        SSHConfig.expandIdentityFile(
          r'keys/%h-%n-%p-%r-%u-%%',
          hostname: 'prod.example.com',
          originalHost: 'prod',
          port: 2200,
          remoteUser: 'deploy',
        ),
        'keys/prod.example.com-prod-2200-deploy-$localUser-%',
      );
    });

    test('preserves escaped spaces and repeated IdentityFile values', () async {
      await configFile.writeAsString(r'''
Host keyserver
  HostName 192.168.1.100
  IdentityFile ~/.ssh/key\ with\ spaces
  IdentityFile ~/.ssh/fallback
''');

      final server = (await SSHConfig.parseConfig(configFile.path)).single;
      expect(server.ssh?.keyPath, '~/.ssh/key with spaces');
      expect(server.ssh?.identityFiles, [
        '~/.ssh/key with spaces',
        '~/.ssh/fallback',
      ]);
    });

    test('parseConfig handles quoted values', () async {
      await configFile.writeAsString('''
Host "server with spaces"
  HostName "192.168.1.100"
  User "admin user"
  IdentityFile "~/.ssh/key with spaces"
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(1));

      final server = servers.first;
      expect(server.name, 'server with spaces');
      expect(server.ssh?.ip, '192.168.1.100');
      expect(server.ssh?.user, 'admin user');
      expect(server.ssh?.keyPath, '~/.ssh/key with spaces');
      expect(server.ssh?.keyId, isNull);
    });

    test('parseConfig handles invalid port values', () async {
      await configFile.writeAsString('''
Host badport
  HostName 192.168.1.100
  Port notanumber

Host goodserver
  HostName 192.168.1.200
  Port 2222

Host zero
  HostName 192.168.1.201
  Port 0

Host high
  HostName 192.168.1.202
  Port 65536
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(4));

      // First server should use default port due to invalid port
      expect(servers[0].name, 'badport');
      expect(servers[0].ssh?.port, 22); // default port

      // Second server should use specified port
      expect(servers[1].name, 'goodserver');
      expect(servers[1].ssh?.port, 2222);
      expect(servers[2].ssh?.port, 22);
      expect(servers[3].ssh?.port, 22);
    });

    test('parseConfig imports each concrete host pattern', () async {
      await configFile.writeAsString('''
Host server1 server2
  HostName 192.168.1.100

Host singleserver
  HostName 192.168.1.200
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers.map((e) => e.name), [
        'server1',
        'server2',
        'singleserver',
      ]);
    });

    test('parseConfig resolves ProxyJump aliases', () async {
      await configFile.writeAsString('''
Host bastion
  HostName bastion.example.com

Host jumpserver
  HostName 192.168.1.100
  User admin
  ProxyJump bastion
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(2));

      final server = servers.firstWhere((e) => e.name == 'jumpserver');
      final bastion = servers.firstWhere((e) => e.name == 'bastion');
      expect(server.name, 'jumpserver');
      expect(server.ssh?.ip, '192.168.1.100');
      expect(server.ssh?.user, 'admin');
      expect(server.ssh?.resolvedJumpIds, [bastion.id]);
    });

    test('preserves ProxyJump lists and user/port overrides', () async {
      await configFile.writeAsString('''
Host first
  HostName first.example.com
  User old
  Port 22

Host second
  HostName second.example.com

Host target
  HostName target.example.com
  ProxyJump jumpuser@first:2200,second
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      final target = servers.firstWhere((e) => e.name == 'target');
      final second = servers.firstWhere((e) => e.name == 'second');
      final override = servers.firstWhere(
        (e) => e.id == target.ssh!.resolvedJumpIds.first,
      );
      expect(target.ssh?.resolvedJumpIds, [override.id, second.id]);
      expect(override.ssh?.user, 'jumpuser');
      expect(override.ssh?.port, 2200);
    });

    test('imports a direct ProxyJump host specification', () async {
      await configFile.writeAsString('''
Host target
  HostName target.example.com
  ProxyJump deploy@bastion.example.com:2200
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      final target = servers.firstWhere((e) => e.name == 'target');
      final jump = servers.firstWhere(
        (e) => e.id == target.ssh!.resolvedJumpIds.single,
      );
      expect(jump.ssh?.ip, 'bastion.example.com');
      expect(jump.ssh?.user, 'deploy');
      expect(jump.ssh?.port, 2200);
      expect(
        servers.where((e) => e.ssh?.ip == 'bastion.example.com'),
        hasLength(1),
      );
    });

    test('removes references to an invalid ProxyJump owner', () async {
      await configFile.writeAsString('''
Host broken
  HostName broken.example.com
  ProxyJump broken

Host target
  HostName target.example.com
  ProxyJump broken,direct.example.com
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers.where((e) => e.name == 'broken'), isEmpty);
      final target = servers.firstWhere((e) => e.name == 'target');
      final jumps = target.ssh!.resolvedJumpIds;
      expect(jumps, hasLength(1));
      expect(
        servers.firstWhere((e) => e.id == jumps.single).ssh?.ip,
        'direct.example.com',
      );
    });

    test('parseConfig returns empty list for non-existent file', () async {
      final servers = await SSHConfig.parseConfig('/non/existent/path');
      expect(servers, isEmpty);
    });

    test('parseConfig handles real-world SSH config example', () async {
      await configFile.writeAsString('''
# Default settings for all hosts
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes

# Production servers
Host prod-web-01
    HostName 10.0.1.100
    User deploy
    Port 22
    IdentityFile ~/.ssh/production.pem

Host prod-db-01
    HostName 10.0.1.200
    User ubuntu
    Port 2222
    IdentityFile ~/.ssh/production.pem

# Development environment
Host dev
    HostName dev.example.com
    User developer
    Port 22

# Jump host configuration
Host bastion
    HostName bastion.example.com
    User ec2-user
    IdentityFile ~/.ssh/bastion.pem

Host internal-server
    HostName 172.16.0.50
    User admin
    ProxyJump bastion
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(5));

      // Check specific servers
      final prodWeb = servers.firstWhere((s) => s.name == 'prod-web-01');
      expect(prodWeb.ssh?.ip, '10.0.1.100');
      expect(prodWeb.ssh?.user, 'deploy');
      expect(prodWeb.ssh?.port, 22);
      expect(prodWeb.ssh?.keyPath, '~/.ssh/production.pem');
      expect(prodWeb.ssh?.keyId, isNull);

      final prodDb = servers.firstWhere((s) => s.name == 'prod-db-01');
      expect(prodDb.ssh?.ip, '10.0.1.200');
      expect(prodDb.ssh?.user, 'ubuntu');
      expect(prodDb.ssh?.port, 2222);

      final dev = servers.firstWhere((s) => s.name == 'dev');
      expect(dev.ssh?.ip, 'dev.example.com');
      expect(dev.ssh?.user, 'developer');
      expect(dev.ssh?.port, 22);
      expect(dev.ssh?.keyPath, isNull);
      expect(dev.ssh?.keyId, isNull);
    });

    group('_stripInlineComment', () {
      test('preserves hash characters inside quotes', () {
        expect(
          SSHConfig.stripInlineCommentForTest("ProxyCommand echo '#'"),
          "ProxyCommand echo '#'",
        );
        expect(
          SSHConfig.stripInlineCommentForTest('ProxyCommand echo "#"'),
          'ProxyCommand echo "#"',
        );
      });

      test('preserves escaped hash characters', () {
        expect(
          SSHConfig.stripInlineCommentForTest(r'ProxyCommand echo \#'),
          r'ProxyCommand echo \#',
        );
      });

      test('removes whitespace-prefixed inline comments', () {
        expect(
          SSHConfig.stripInlineCommentForTest('value  # comment'),
          'value',
        );
      });

      test('preserves hash without preceding whitespace', () {
        expect(SSHConfig.stripInlineCommentForTest('foo#bar'), 'foo#bar');
      });

      test('handles combined escapes and quotes', () {
        expect(
          SSHConfig.stripInlineCommentForTest(
            r'''ProxyCommand sh -c "echo \# '#'"  # comment''',
          ),
          r'''ProxyCommand sh -c "echo \# '#'"''',
        );
      });
    });
  });
}
