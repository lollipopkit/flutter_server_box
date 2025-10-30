import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/proxy_command_executor.dart';
import 'package:server_box/data/model/server/proxy_command_config.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

void main() {
  group('ProxyCommandConfig Tests', () {
    test('should create ProxyCommandConfig with required fields', () {
      const config = ProxyCommandConfig(
        command: 'cloudflared access ssh --hostname %h',
        timeout: Duration(seconds: 30),
        requiresExecutable: true,
        executableName: 'cloudflared',
      );

      expect(config.command, equals('cloudflared access ssh --hostname %h'));
      expect(config.timeout.inSeconds, equals(30));
      expect(config.requiresExecutable, isTrue);
      expect(config.executableName, equals('cloudflared'));
    });

    test('should get final command with placeholders replaced', () {
      const config = ProxyCommandConfig(
        command: 'cloudflared access ssh --hostname %h --port %p',
        timeout: Duration(seconds: 30),
      );

      final finalCommand = config.getFinalCommand(
        hostname: 'example.com',
        port: 22,
        user: 'testuser',
      );

      expect(finalCommand, equals('cloudflared access ssh --hostname example.com --port 22'));
    });

    test('should handle all placeholders correctly', () {
      const config = ProxyCommandConfig(
        command: 'ssh -W %h:%p -l %r bastion.example.com',
        timeout: Duration(seconds: 10),
      );

      final finalCommand = config.getFinalCommand(
        hostname: 'target.example.com',
        port: 2222,
        user: 'admin',
      );

      expect(finalCommand, equals('ssh -W target.example.com:2222 -l admin bastion.example.com'));
    });

    test('should validate presets from map', () {
      final presets = proxyCommandPresets;

      final cloudflareConfig = presets['cloudflare_access'];
      expect(cloudflareConfig, isNotNull);
      expect(cloudflareConfig!.command, equals('cloudflared access ssh --hostname %h'));
      expect(cloudflareConfig.requiresExecutable, isTrue);
      expect(cloudflareConfig.executableName, equals('cloudflared'));

      final sshBastionConfig = presets['ssh_via_bastion'];
      expect(sshBastionConfig, isNotNull);
      expect(sshBastionConfig!.command, equals('ssh -W %h:%p bastion.example.com'));
      expect(sshBastionConfig.requiresExecutable, isFalse);

      final ncConfig = presets['nc_netcat'];
      expect(ncConfig, isNotNull);
      expect(ncConfig!.command, equals('nc %h %p'));
      expect(ncConfig.requiresExecutable, isFalse);

      final socatConfig = presets['socat'];
      expect(socatConfig, isNotNull);
      expect(socatConfig!.command, equals('socat - PROXY:%h:%p,proxyport=8080'));
      expect(socatConfig.requiresExecutable, isFalse);
    });
  });

  group('Spi with ProxyCommand Tests', () {
    test('should create Spi with ProxyCommand configuration', () {
      final spi = Spi(
        name: 'Test Server',
        ip: 'example.com',
        port: 22,
        user: 'testuser',
        pwd: 'testpass',
        proxyCommand: const ProxyCommandConfig(
          command: 'cloudflared access ssh --hostname %h',
          timeout: Duration(seconds: 30),
          requiresExecutable: true,
          executableName: 'cloudflared',
        ),
      );

      expect(spi.name, equals('Test Server'));
      expect(spi.proxyCommand, isNotNull);
      expect(spi.proxyCommand!.command, equals('cloudflared access ssh --hostname %h'));
      expect(spi.proxyCommand!.requiresExecutable, isTrue);
    });

    test('should handle Spi without ProxyCommand', () {
      final spi = Spi(
        name: 'Test Server',
        ip: 'example.com',
        port: 22,
        user: 'testuser',
        pwd: 'testpass',
      );

      expect(spi.proxyCommand, isNull);
    });

    test('should serialize and deserialize Spi with ProxyCommand', () {
      final originalSpi = Spi(
        name: 'Test Server',
        ip: 'example.com',
        port: 22,
        user: 'testuser',
        pwd: 'testpass',
        proxyCommand: const ProxyCommandConfig(
          command: 'cloudflared access ssh --hostname %h',
          timeout: Duration(seconds: 30),
          requiresExecutable: true,
          executableName: 'cloudflared',
        ),
      );

      final json = originalSpi.toJson();
      final deserializedSpi = Spi.fromJson(json);

      expect(deserializedSpi.name, equals(originalSpi.name));
      expect(deserializedSpi.ip, equals(originalSpi.ip));
      expect(deserializedSpi.proxyCommand, isNotNull);
      expect(deserializedSpi.proxyCommand!.command, equals(originalSpi.proxyCommand!.command));
      expect(deserializedSpi.proxyCommand!.requiresExecutable, equals(originalSpi.proxyCommand!.requiresExecutable));
      expect(deserializedSpi.proxyCommand!.executableName, equals(originalSpi.proxyCommand!.executableName));
    });
  });

  group('ProxyCommandExecutor Tokenization', () {
    test('tokenizeCommand handles quoted paths', () {
      final tokens = ProxyCommandExecutor.tokenizeCommand(
        'ssh -i "/Users/John Doe/.ssh/id_rsa" -W %h:%p bastion.example.com',
      );

      expect(
        tokens,
        equals([
          'ssh',
          '-i',
          '/Users/John Doe/.ssh/id_rsa',
          '-W',
          '%h:%p',
          'bastion.example.com',
        ]),
      );
    });

    test('tokenizeCommand throws on unmatched quote', () {
      expect(
        () => ProxyCommandExecutor.tokenizeCommand('ssh -i "/Users/John Doe/.ssh/id_rsa'),
        throwsA(isA<ProxyCommandException>()),
      );
    });
  });
}
