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

    test('an agent with terminal and full access grants both', () {
      // The PTY needs both grants. Commands use full access, while the
      // terminal endpoint can be disabled independently.
      final spi = Spi(name: 'test', id: 'd', monitorHttp: monitor);
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
        granted: const MonitorRemoteAccess(terminal: true, fullAccess: true),
      );
      expect(caps.terminal, isTrue);
      expect(caps.shell, isTrue);
      expect(caps.storedHistory, isTrue);
    });

    test('a server carrying both is valid, and answers for both', () {
      // This used to be the rejected case. Carrying both is a configuration
      // someone can ask for, and what it can do is the union: the agent's
      // stored history, and the byte stream the agent has no endpoint for.
      // Reporting only the leading transport's answers would take features
      // away over a preference that is about ordering.
      final spi = Spi(
        name: 'test',
        id: 'e',
        ssh: const SshCredential(ip: '10.0.0.1'),
        monitorHttp: monitor,
      );

      expect(spi.validate(), isNull);

      final caps = ServerCapabilities.ofSpi(spi);
      // SSH's, which the agent alone cannot offer.
      expect(caps.byteStream, isTrue);
      // The agent's, which SSH alone cannot offer.
      expect(caps.storedHistory, isTrue);
    });

    test('a server with neither is what validation now rejects', () {
      // A row with no way in is not a server, it is a name. The database
      // refuses it too — see `tables_schema_test.dart`.
      final spi = Spi(name: 'test', id: 'f');

      expect(spi.validate(), SpiValidationError.noConnectionMethod);
    });

    test('SSH leads when both are configured and nothing says otherwise', () {
      // What every such server was before the field existed, and the
      // transport that can do everything — so a server that gains an agent
      // does not quietly lose its terminal.
      final spi = Spi(
        name: 'test',
        id: 'g',
        ssh: const SshCredential(ip: '10.0.0.1'),
        monitorHttp: monitor,
      );

      expect(spi.transport, ServerTransport.ssh);
      expect(spi.fallbackTransport, ServerTransport.monitorHttp);
    });

    test('a preference for a transport that is not configured is ignored', () {
      // It happens: switching a server's SSH off leaves the preference
      // behind, and nothing clears it. Honouring it would resolve to a
      // credential that does not exist.
      final spi = Spi(
        name: 'test',
        id: 'h',
        monitorHttp: monitor,
        preferredTransport: ServerTransport.ssh,
      );

      expect(spi.transport, ServerTransport.monitorHttp);
      expect(spi.fallbackTransport, isNull);
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

    test('a terminal alone is not the grant commands need', () {
      // The terminal endpoint alone cannot open a shell as the agent's
      // account; that also needs full access.
      const caps = MonitorHttpCapabilities(
        MonitorRemoteAccess(terminal: true),
      );
      expect(caps.shell, isFalse);
      expect(caps.terminal, isFalse);
    });

    test('full access carries no SSH byte stream, but does relay TCP', () {
      // The agent has no channel this app can point at an SFTP subsystem, so
      // `byteStream` — which is what the file transfer asks — stays false and
      // the file browser keeps using the agent's own API. What it *can* do is
      // dial an address the app names, which is the question remote desktop
      // asks instead (`tcpRelay`).
      const caps = MonitorHttpCapabilities(
        MonitorRemoteAccess(fullAccess: true, stream: true),
      );
      expect(caps.shell, isTrue);
      expect(caps.terminal, isFalse);
      expect(caps.byteStream, isFalse);
      expect(caps.tcpRelay, isTrue);
    });

    test('an old agent reports full access and no relay', () {
      // The endpoint is newer than the grant, so an agent that predates it
      // reports `full_access` and would still refuse the upgrade. Reading
      // `fullAccess` for this is what would offer a session that cannot open.
      const caps = MonitorHttpCapabilities(
        MonitorRemoteAccess(fullAccess: true),
      );
      expect(caps.shell, isTrue);
      expect(caps.tcpRelay, isFalse);
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
      MonitorRemoteAccess(terminal: true, fullAccess: true, stream: true),
    );
    /// What an agent older than the relay endpoint reports: the grant, with no
    /// endpoint behind it.
    const grantedBeforeRelay = MonitorHttpCapabilities(
      MonitorRemoteAccess(terminal: true, fullAccess: true),
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
      // and service pages rather than with the entries that open a terminal.
      expect(ServerFuncBtn.power.availableWith(granted), isTrue);
      expect(ServerFuncBtn.power.availableWith(refused), isFalse);
    });

    test('a full-access agent offers everything but the SSH-only streams', () {
      // Files are not among them: full access is the shell grant, and the file
      // API is a grant of its own — see the next test. Port forwarding is not
      // either: the forward page still opens through the SSH client.
      expect(ServerFuncBtn.files.availableWith(granted), isFalse);
      expect(ServerFuncBtn.portForward.availableWith(granted), isFalse);
      for (final btn in ServerFuncBtn.values) {
        if (btn == ServerFuncBtn.files ||
            btn == ServerFuncBtn.portForward) {
          continue;
        }
        expect(btn.availableWith(granted), isTrue, reason: btn.name);
      }
    });

    test('remote desktop follows the relay, not the grant behind it', () {
      // The endpoint is what the session needs, and an agent that has the
      // grant but not the endpoint cannot carry one.
      expect(ServerFuncBtn.remoteDesktop.availableWith(granted), isTrue);
      expect(
        ServerFuncBtn.remoteDesktop.availableWith(grantedBeforeRelay),
        isFalse,
      );
    });

    test('the file entry follows the agent\'s file grant alone', () {
      // The whole point of the entry no longer being called SFTP: an agent
      // that serves files and nothing else is browsable, and one that grants a
      // shell but no file roots is not.
      const filesOnly = MonitorHttpCapabilities(
        MonitorRemoteAccess(files: true),
      );
      expect(ServerFuncBtn.files.availableWith(filesOnly), isTrue);
      expect(ServerFuncBtn.terminal.availableWith(filesOnly), isFalse);
      expect(ServerFuncBtn.files.availableWith(granted), isFalse);
    });
  });
}
