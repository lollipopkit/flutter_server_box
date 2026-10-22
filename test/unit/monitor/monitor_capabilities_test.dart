import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_access.dart';
import 'package:server_box/data/model/server/monitor_capabilities.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
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

    test('an agent that grants access opens a terminal and runs commands', () {
      final spi = Spi(name: 'test', id: 'd', monitorHttp: monitor);
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
        granted: MonitorAccess.granted,
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
      const caps = MonitorHttpCapabilities(MonitorAccess.none);
      expect(caps.shell, isFalse);
      expect(caps.terminal, isFalse);
      expect(caps.byteStream, isFalse);
      expect(caps.tcpRelay, isFalse);
      expect(caps.remoteListen, isFalse);
      expect(caps.files, isFalse);
    });

    test('access carries no SSH byte stream, but does relay TCP', () {
      // The agent has no channel this app can point at an SFTP subsystem, so
      // `byteStream` — which is what the file transfer asks — stays false and
      // the file browser keeps using the agent's own API. What it *can* do is
      // dial an address the app names, which is the question remote desktop
      // asks instead (`tcpRelay`).
      const caps = MonitorHttpCapabilities(MonitorAccess.granted);
      expect(caps.shell, isTrue);
      expect(caps.terminal, isTrue);
      expect(caps.byteStream, isFalse);
      expect(caps.tcpRelay, isTrue);
      expect(caps.remoteListen, isTrue);
      expect(caps.files, isTrue);
    });

    test('no session to be in the middle of', () {
      const caps = MonitorHttpCapabilities(MonitorAccess.granted);
      expect(caps.persistentSession, isFalse);
    });
  });

  group('ServerFuncBtn.availableWith', () {
    const ssh = SshCapabilities();
    const granted = MonitorHttpCapabilities(MonitorAccess.granted);
    const refused = MonitorHttpCapabilities(MonitorAccess.none);

    test('an SSH server offers every entry', () {
      for (final btn in ServerFuncBtn.values) {
        expect(btn.availableWith(ssh), isTrue, reason: btn.name);
      }
    });

    test('an agent that refuses offers none', () {
      for (final btn in ServerFuncBtn.values) {
        expect(btn.availableWith(refused), isFalse, reason: btn.name);
      }
    });

    test('an agent that grants access offers every entry', () {
      for (final btn in ServerFuncBtn.values) {
        expect(btn.availableWith(granted), isTrue, reason: btn.name);
      }
    });
  });

  group('ServerFuncBtn.unavailableReason', () {
    const monitor = MonitorHttpCredential(addr: 'https://agent:3770');
    final agentOnly = Spi(name: 'test', id: 'r', monitorHttp: monitor);
    const insecure = MonitorAccess(
      ok: false,
      why: MonitorAccessWhy.insecureTransport,
    );

    test('a plaintext link is what an agent-only server is told', () {
      for (final btn in ServerFuncBtn.values) {
        expect(
          btn.unavailableReason(agentOnly, insecure),
          l10n.funcNeedsAgentHttps(btn.toStr),
          reason: btn.name,
        );
      }
    });

    test('a refusal with no reason gets the plain answer', () {
      expect(
        ServerFuncBtn.process.unavailableReason(agentOnly, MonitorAccess.none),
        l10n.funcUnavailableFmt(ServerFuncBtn.process.toStr),
      );
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
    const insecure = MonitorAccess(
      ok: false,
      why: MonitorAccessWhy.insecureTransport,
    );

    test('the agent leading, answers with the agent alone', () {
      // A forward there never falls back to sshd, so sshd being able to
      // listen says nothing about what the forward can do.
      final caps = ServerCapabilities.forwardsOf(
        both(ServerTransport.monitorHttp),
        granted: MonitorAccess.none,
      );
      expect(caps.tcpRelay, isFalse);
      expect(caps.remoteListen, isFalse);
    });

    test('SSH leading, answers with both', () {
      final caps = ServerCapabilities.forwardsOf(
        both(ServerTransport.ssh),
        granted: MonitorAccess.none,
      );
      expect(caps.tcpRelay, isTrue);
      expect(caps.remoteListen, isTrue);
    });

    test('the entry follows the agent where it leads, SSH or not', () {
      final spi = both(ServerTransport.monitorHttp);
      expect(ServerFuncBtn.portForward.availableOn(spi, insecure), isFalse);
      expect(
        ServerFuncBtn.portForward.availableOn(spi, MonitorAccess.granted),
        isTrue,
      );
      // And says what the agent is missing, as an agent-only server would.
      expect(
        ServerFuncBtn.portForward.unavailableReason(spi, insecure),
        l10n.funcNeedsAgentHttps(ServerFuncBtn.portForward.toStr),
      );
      // Everything else still asks the union.
      expect(ServerFuncBtn.files.availableOn(spi, insecure), isTrue);
    });
  });

  // TODO: remove with the fallbacks when MIN_AGENT_PROTOCOL reaches 2.
  group('access, as each protocol says it', () {
    MonitorAccess of(Map<String, dynamic> json) => MonitorCapabilities.fromJson(json).access;

    test('protocol 2 says access', () {
      expect(of({'access': {'ok': true}}), MonitorAccess.granted);
      expect(
        of({'access': {'ok': false, 'why': 'insecure_transport'}}),
        const MonitorAccess(ok: false, why: MonitorAccessWhy.insecureTransport),
      );
    });

    test('protocol 1 says it as the shell grant', () {
      expect(of({'grants': {'shell': {'ok': true}, 'files': {'ok': false}}}), MonitorAccess.granted);
      expect(
        of({'grants': {'shell': {'ok': false, 'why': 'insecure_transport'}}}),
        const MonitorAccess(ok: false, why: MonitorAccessWhy.insecureTransport),
      );
      expect(of({'grants': {'shell': {'ok': false, 'why': 'not_granted'}}}).ok, isFalse);
    });

    test('an agent from before roles says it as full access', () {
      expect(of({'remote_access': {'full_access': true}}), MonitorAccess.granted);
      expect(of({'remote_access': {'full_access': false}}), MonitorAccess.none);
    });

    test('access wins over what an agent answering both protocols adds', () {
      expect(of({'access': {'ok': false}, 'grants': {'shell': {'ok': true}}}).ok, isFalse);
    });

    test('nothing said grants nothing', () {
      expect(of(const {}), MonitorAccess.none);
    });
  });
}
