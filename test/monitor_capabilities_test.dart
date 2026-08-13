import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

void main() {
  group('ServerCapabilities.of', () {
    const monitor = MonitorHttpCredential(addr: 'https://agent:3770');

    test('a monitor server answers with what its agent granted', () {
      final spi = Spi(name: 'test', id: 'b', monitorHttp: monitor);
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
      );
      expect(caps, isA<MonitorHttpCapabilities>());
      expect(caps.shell, isFalse);
      expect(caps.terminal, isFalse);
    });

    test('an agent granted full access answers for everything', () {
      // One grant, not one per feature: anyone who can open a shell through
      // the agent can run anything in it, so withholding the process page from
      // the same grant withholds nothing — it only makes the app pretend the
      // machine is out of reach.
      final spi = Spi(name: 'test', id: 'd', monitorHttp: monitor);
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
        granted: const MonitorRemoteAccess(fullAccess: true),
      );
      expect(caps.terminal, isTrue);
      expect(caps.shell, isTrue);
      expect(caps.storedHistory, isTrue);
    });

    test('the agent answers when both are somehow configured', () {
      // `Spi.validate` rejects this, so it can only arrive from hand-edited
      // storage. `ServerConnectCredential.fromSpi` reads status over the agent
      // in that case, and what a server can do has to be the same answer as
      // how it is actually reached — otherwise the app offers SFTP over a
      // connection it is not using.
      final spi = Spi(
        name: 'test',
        id: 'e',
        ssh: const SshCredential(ip: '10.0.0.1'),
        monitorHttp: monitor,
      );
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
        granted: const MonitorRemoteAccess(fullAccess: true),
      );
      expect(caps, isA<MonitorHttpCapabilities>());
      expect(caps.byteStream, isFalse);
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

  group('MonitorHttpCapabilities', () {
    test('grants nothing before the agent has been asked', () {
      const caps = MonitorHttpCapabilities(MonitorRemoteAccess.none);
      expect(caps.shell, isFalse);
      expect(caps.terminal, isFalse);
      expect(caps.byteStream, isFalse);
    });

    test('a tunnel or terminal alone is not the grant commands need', () {
      // Both are about reaching the machine's own sshd, which authenticates
      // for itself. Only `full_access` is the agent acting as the account.
      const caps = MonitorHttpCapabilities(
        MonitorRemoteAccess(tunnel: true, terminal: true, secure: true),
      );
      expect(caps.shell, isFalse);
      expect(caps.terminal, isFalse);
    });

    test('full access still carries no byte stream', () {
      // The agent has no endpoint that relays a connection to an address the
      // app names, so SFTP and port forwarding stay out of reach — and stay
      // hidden rather than opening a page that cannot load.
      const caps = MonitorHttpCapabilities(
        MonitorRemoteAccess(fullAccess: true),
      );
      expect(caps.shell, isTrue);
      expect(caps.byteStream, isFalse);
    });

    test('no session to be in the middle of', () {
      const caps = MonitorHttpCapabilities(
        MonitorRemoteAccess(fullAccess: true),
      );
      expect(caps.persistentSession, isFalse);
    });
  });

  group('ServerFuncBtn.availableWith', () {
    const ssh = SshCapabilities();
    const granted = MonitorHttpCapabilities(
      MonitorRemoteAccess(fullAccess: true),
    );
    const refused = MonitorHttpCapabilities(MonitorRemoteAccess.none);

    test('an SSH server offers every entry', () {
      for (final btn in ServerFuncBtn.values) {
        expect(btn.availableWith(ssh), isTrue, reason: btn.name);
      }
    });

    test('an agent that granted nothing offers none', () {
      for (final btn in ServerFuncBtn.values) {
        expect(btn.availableWith(refused), isFalse, reason: btn.name);
      }
    });

    test('powering a machine down needs a shell, not a terminal', () {
      // It runs one of the script's functions, so it belongs with the process
      // and systemd pages rather than with the entries that open a terminal.
      expect(ServerFuncBtn.power.availableWith(granted), isTrue);
      expect(ServerFuncBtn.power.availableWith(refused), isFalse);
    });

    test('a full-access agent offers everything but the byte streams', () {
      expect(ServerFuncBtn.sftp.availableWith(granted), isFalse);
      expect(ServerFuncBtn.portForward.availableWith(granted), isFalse);
      for (final btn in ServerFuncBtn.values) {
        if (btn == ServerFuncBtn.sftp || btn == ServerFuncBtn.portForward) {
          continue;
        }
        expect(btn.availableWith(granted), isTrue, reason: btn.name);
      }
    });
  });
}
