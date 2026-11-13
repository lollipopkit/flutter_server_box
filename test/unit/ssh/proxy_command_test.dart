import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/ssh/proxy_command_socket.dart';

void main() {
  group('what a placeholder may expand to', () {
    test('all supported OpenSSH placeholders are expanded', () {
      expect(
        ProxyCommandSocket.resolveCommand(
          command: 'proxy %% %h %n %p %r %j',
          host: '10.0.0.1',
          originalHost: 'prod',
          port: 2222,
          user: 'deploy',
          jump: 'bastion',
        ),
        'proxy % 10.0.0.1 prod 2222 deploy bastion',
      );
    });

    test('the shapes a real host or user comes in are all allowed', () {
      for (final value in [
        'example.com',
        '192.168.1.10',
        '[2001:db8::1]',
        'fe80::1',
        'my-host_01.internal',
        'root',
        'user@realm',
      ]) {
        expect(
          ProxyCommandSocket.checkSubstitutable('host', value),
          value,
          reason: '$value names a host or a user and has to go through',
        );
      }
    });

    test('anything a shell would read as syntax is refused', () {
      // The expansion is textual and the result runs under `sh -c`, so each of
      // these is a local command executing before authentication. The address
      // is not necessarily this device's own: it arrives from an imported
      // `~/.ssh/config`, a restored backup or a synced peer.
      for (final value in [
        'h; touch /tmp/pwned',
        r'h$(id)',
        'h`id`',
        'h | sh',
        'h && id',
        r'h$IFS',
        'h\nid',
        "h'",
        'h"',
        'h%p',
        r'ad\user',
      ]) {
        expect(
          () => ProxyCommandSocket.checkSubstitutable('host', value),
          throwsA(isA<Object>()),
          reason: '$value must not reach /bin/sh',
        );
      }
    });
  });
}
