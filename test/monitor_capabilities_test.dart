import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

void main() {
  group('ServerCapabilities', () {
    const monitor = MonitorHttpCredential(addr: 'https://agent:3770');

    test('a monitor server without SSH has no shell', () {
      final spi = Spi(name: 'test', id: 'b', monitorHttp: monitor);
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
      );
      expect(caps.shell, isFalse);
      expect(caps.terminal, isFalse);
    });

    test('an agent granted full access answers for everything', () {
      // One grant, not one per feature: anyone who can open a shell through
      // the agent can run anything in it, so withholding SFTP or the process
      // page from the same grant withholds nothing — it only makes the app
      // pretend the machine is out of reach.
      final spi = Spi(
        name: 'test',
        id: 'd',
        monitorHttp: const MonitorHttpCredential(addr: 'https://agent:3770'),
      );
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
        granted: const MonitorRemoteAccess(fullAccess: true),
      );
      expect(caps.terminal, isTrue);
      expect(caps.shell, isTrue);
      expect(caps.storedHistory, isTrue);
    });

    test('SSH wins when both are somehow configured', () {
      // `validate` rejects this, so it can only arrive from hand-edited
      // storage — and then the more capable answer is the safe one
      final spi = Spi(
        name: 'test',
        id: 'e',
        ssh: const SshCredential(ip: '10.0.0.1'),
        monitorHttp: const MonitorHttpCredential(addr: 'https://agent:3770'),
      );
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
        granted: const MonitorRemoteAccess(fullAccess: true),
      );
      expect(caps.shell, isTrue);
    });

    test('a plain SSH server is unchanged', () {
      final spi = Spi(
        name: 'test',
        id: 'c',
        ssh: const SshCredential(ip: '10.0.0.1'),
      );
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
      );
      expect(caps.shell, isTrue);
      expect(caps.persistentSession, isTrue);
      expect(caps.storedHistory, isFalse);
    });
  });
}
