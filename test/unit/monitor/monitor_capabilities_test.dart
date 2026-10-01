import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
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

    test('a full-access agent offers everything but files', () {
      // Full access is the shell grant, and the file API is a grant of its
      // own — see the next test.
      expect(ServerFuncBtn.files.availableWith(granted), isFalse);
      for (final btn in ServerFuncBtn.values) {
        if (btn == ServerFuncBtn.files) continue;
        expect(btn.availableWith(granted), isTrue, reason: btn.name);
      }
    });

    test('remote desktop and port forwarding follow the relay, not the grant '
        'behind it', () {
      // The endpoint is what both need — a local forward is dialled through
      // it as a session is — and an agent that has the grant but not the
      // endpoint cannot carry one.
      for (final btn in [
        ServerFuncBtn.remoteDesktop,
        ServerFuncBtn.portForward,
      ]) {
        expect(btn.availableWith(granted), isTrue, reason: btn.name);
        expect(
          btn.availableWith(grantedBeforeRelay),
          isFalse,
          reason: btn.name,
        );
      }
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
  group('ServerFuncBtn.unavailableReason', () {
    const monitor = MonitorHttpCredential(addr: 'https://agent:3770');
    final agentOnly = Spi(name: 'test', id: 'r', monitorHttp: monitor);

    test('names the grant an agent-only server is missing', () {
      const shellOnly = MonitorRemoteAccess(fullAccess: true);
      expect(
        ServerFuncBtn.files.unavailableReason(agentOnly, shellOnly),
        contains('[remote_access.fs]'),
      );
      expect(
        ServerFuncBtn.terminal.unavailableReason(agentOnly, shellOnly),
        contains('[remote_access.terminal]'),
      );
      expect(
        ServerFuncBtn.process.unavailableReason(
          agentOnly,
          MonitorRemoteAccess.none,
        ),
        contains('full_access'),
      );
    });

    test('a relay missing under full access is an agent to update', () {
      const beforeRelay = MonitorRemoteAccess(terminal: true, fullAccess: true);
      for (final btn in [
        ServerFuncBtn.remoteDesktop,
        ServerFuncBtn.portForward,
      ]) {
        expect(
          btn.unavailableReason(agentOnly, beforeRelay),
          l10n.funcNeedsAgentUpdate(btn.toStr),
          reason: btn.name,
        );
      }
    });

    test('an agent not heard from yet gets the plain answer', () {
      expect(
        ServerFuncBtn.files.unavailableReason(agentOnly, null),
        l10n.funcUnavailableFmt(ServerFuncBtn.files.toStr),
      );
    });
  });

  group('port forwarding on a server with both SSH and an agent', () {
    const monitor = MonitorHttpCredential(addr: 'https://agent:3770');
    Spi both(ServerTransport preferred) => Spi(
      name: 'test',
      id: 'b',
      ssh: const SshCredential(ip: '10.0.0.1'),
      monitorHttp: monitor,
      preferredTransport: preferred,
    );
    /// An agent from before the listen endpoint.
    const relayOnly = MonitorRemoteAccess(
      terminal: true,
      fullAccess: true,
      stream: true,
    );

    test('the agent leading, answers with the agent alone', () {
      // A forward there never falls back to sshd, so sshd being able to
      // listen says nothing about what the forward can do.
      final caps = ServerCapabilities.forwardsOf(
        both(ServerTransport.monitorHttp),
        granted: relayOnly,
      );
      expect(caps.tcpRelay, isTrue);
      expect(caps.remoteListen, isFalse);
    });

    test('SSH leading, answers with both', () {
      final caps = ServerCapabilities.forwardsOf(
        both(ServerTransport.ssh),
        granted: MonitorRemoteAccess.none,
      );
      expect(caps.tcpRelay, isTrue);
      expect(caps.remoteListen, isTrue);
    });

    test('the entry follows the agent where it leads, SSH or not', () {
      final spi = both(ServerTransport.monitorHttp);
      expect(
        ServerFuncBtn.portForward.availableOn(spi, MonitorRemoteAccess.none),
        isFalse,
      );
      expect(ServerFuncBtn.portForward.availableOn(spi, relayOnly), isTrue);
      // And says what the agent is missing, as an agent-only server would.
      expect(
        ServerFuncBtn.portForward.unavailableReason(
          spi,
          MonitorRemoteAccess.none,
        ),
        contains('full_access'),
      );
      // Everything else still asks the union.
      expect(
        ServerFuncBtn.files.availableOn(spi, MonitorRemoteAccess.none),
        isTrue,
      );
    });

    test('an agent that listens can take a remote forward', () {
      const listens = MonitorHttpCapabilities(
        MonitorRemoteAccess(fullAccess: true, stream: true, listen: true),
      );
      expect(listens.remoteListen, isTrue);
      expect(const MonitorHttpCapabilities(relayOnly).remoteListen, isFalse);
      expect(const SshCapabilities().remoteListen, isTrue);
      expect(
        MonitorRemoteAccess.fromJson({'stream': true, 'listen': true}).listen,
        isTrue,
      );
      // An agent too old to say is one that cannot.
      expect(MonitorRemoteAccess.fromJson({'stream': true}).listen, isFalse);
    });
  });
}
