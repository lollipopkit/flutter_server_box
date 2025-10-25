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
      expect(server.ip, '192.168.1.100');
      expect(server.user, 'admin');
      expect(server.port, 2222);
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
      expect(server.ip, 'example.com');
      expect(server.user, 'root'); // default user
      expect(server.port, 22);     // default port
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
      expect(servers[0].ip, '192.168.1.100');
      expect(servers[0].user, 'alice');
      expect(servers[0].port, 22);
      
      expect(servers[1].name, 'server2');
      expect(servers[1].ip, '192.168.1.200');
      expect(servers[1].user, 'bob');
      expect(servers[1].port, 2222);
      
      expect(servers[2].name, 'server3');
      expect(servers[2].ip, 'example.com');
      expect(servers[2].user, 'charlie');
      expect(servers[2].port, 22);
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
      expect(server.ip, '192.168.1.100');
      expect(server.user, 'admin');
      expect(server.port, 2222);
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
      expect(servers[0].ip, '192.168.1.50');
      expect(servers[0].user, 'developer');
      
      expect(servers[1].name, 'prodserver');
      expect(servers[1].ip, '10.0.0.100');
      expect(servers[1].user, 'production');
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
      expect(server.ip, '192.168.1.100');
      expect(server.user, 'admin');
      expect(server.port, 22); // Uses default, not wildcard setting
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
      expect(server.keyId, '~/.ssh/special_key');
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
      expect(server.ip, '192.168.1.100');
      expect(server.user, 'admin user');
      expect(server.keyId, '~/.ssh/key with spaces');
    });

    test('parseConfig handles invalid port values', () async {
      await configFile.writeAsString('''
Host badport
  HostName 192.168.1.100
  Port notanumber

Host goodserver
  HostName 192.168.1.200
  Port 2222
''');
      
      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(2));
      
      // First server should use default port due to invalid port
      expect(servers[0].name, 'badport');
      expect(servers[0].port, 22); // default port
      
      // Second server should use specified port
      expect(servers[1].name, 'goodserver');
      expect(servers[1].port, 2222);
    });

    test('parseConfig skips hosts with multiple host patterns', () async {
      await configFile.writeAsString('''
Host server1 server2
  HostName 192.168.1.100

Host singleserver
  HostName 192.168.1.200
''');
      
      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(1)); // Only single host patterns
      
      expect(servers[0].name, 'singleserver');
    });

    test('parseConfig handles ProxyJump (ignored)', () async {
      await configFile.writeAsString('''
Host jumpserver
  HostName 192.168.1.100
  User admin
  ProxyJump bastion.example.com
''');
      
      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(1));
      
      final server = servers.first;
      expect(server.name, 'jumpserver');
      expect(server.ip, '192.168.1.100');
      expect(server.user, 'admin');
      // ProxyJump is ignored in current implementation
    });

    test('parseConfig handles ProxyCommand with ssh -W jump host', () async {
      await configFile.writeAsString('''
Host internal
  HostName 172.16.0.50
  User admin
  ProxyCommand ssh -W %h:%p user@bastion.example.com
''');

      final servers = await SSHConfig.parseConfig(configFile.path);
      expect(servers, hasLength(1));

      final server = servers.first;
      expect(server.name, 'internal');
      expect(server.ip, '172.16.0.50');
      expect(server.user, 'admin');
      // Jump host extracted from ProxyCommand token containing user@host
      expect(server.jumpId, 'user@bastion.example.com');
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
      expect(prodWeb.ip, '10.0.1.100');
      expect(prodWeb.user, 'deploy');
      expect(prodWeb.port, 22);
      expect(prodWeb.keyId, '~/.ssh/production.pem');
      
      final prodDb = servers.firstWhere((s) => s.name == 'prod-db-01');
      expect(prodDb.ip, '10.0.1.200');
      expect(prodDb.user, 'ubuntu');
      expect(prodDb.port, 2222);
      
      final dev = servers.firstWhere((s) => s.name == 'dev');
      expect(dev.ip, 'dev.example.com');
      expect(dev.user, 'developer');
      expect(dev.port, 22);
      expect(dev.keyId, isNull);
    });
  });
}
