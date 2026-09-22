import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/ssh/virtual_key.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/view/page/storage/server_file.dart';

/// What the order in the server editor actually decides.
///
/// A server carrying both transports can be reached either way, so for every
/// feature both of them can serve, the one the user put first is the one that
/// serves it. That used to be true of status and commands only: the terminal
/// and the file browser each had a rule of their own that came down to "SSH
/// wins wherever it exists", so a server dragged agent-first kept both of them
/// on sshd and nothing said why.
void main() {
  const monitor = MonitorHttpCredential(addr: 'https://agent:3770');
  const ssh = SshCredential(ip: 'host', port: 22, user: 'root', pwd: 'p');
  const full = MonitorRemoteAccess(
    terminal: true,
    fullAccess: true,
    files: true,
  );

  Spi server({
    bool withSsh = true,
    bool withMonitor = true,
    ServerTransport? prefer,
  }) => Spi(
    name: 'test',
    id: 'id',
    ssh: withSsh ? ssh : null,
    monitorHttp: withMonitor ? monitor : null,
    preferredTransport: prefer,
  );

  group('the shell', () {
    test('goes to the agent when the agent leads and grants one', () {
      final spi = server(prefer: ServerTransport.monitorHttp);
      expect(serverShellUsesAgent(spi, full), isTrue);
    });

    test('goes to SSH when SSH leads, however the agent is configured', () {
      final spi = server(prefer: ServerTransport.ssh);
      expect(serverShellUsesAgent(spi, full), isFalse);
    });

    test('goes to SSH when nothing is preferred', () {
      // The default this field has always had: a server that gains an agent
      // does not quietly lose the terminal it was using.
      expect(serverShellUsesAgent(server(), full), isFalse);
    });

    test('falls back to SSH when the agent leads but grants no shell', () {
      // A preference the agent will not honour is not honoured into a dead
      // end. The alternative is a terminal that refuses to open on a server
      // whose sshd is right there.
      final spi = server(prefer: ServerTransport.monitorHttp);
      expect(serverShellUsesAgent(spi, const MonitorRemoteAccess()), isFalse);
      expect(serverShellUsesAgent(spi, null), isFalse);
    });

    test('full access without a terminal does not select the agent PTY', () {
      final spi = server(prefer: ServerTransport.monitorHttp);
      expect(
        serverShellUsesAgent(spi, const MonitorRemoteAccess(fullAccess: true)),
        isFalse,
      );
    });

    test('is the agent for a server that has no SSH at all', () {
      final spi = server(withSsh: false);
      expect(serverShellUsesAgent(spi, full), isTrue);
    });
  });

  group('the tmux key', () {
    // An agent's PTY has no exec channel, so the switcher cannot list
    // anything — and a key drawn on a strip that does nothing when tapped is
    // the failure `worksOn` exists to prevent.
    bool tmuxOn(Spi spi, MonitorRemoteAccess? granted) => VirtKey.tmux.worksOn(
      spi,
      shellUsesAgent: serverShellUsesAgent(spi, granted),
    );

    test('is gone when the shell is the agent PTY', () {
      expect(tmuxOn(server(prefer: ServerTransport.monitorHttp), full), isFalse);
    });

    test('is there when the shell is SSH', () {
      expect(tmuxOn(server(prefer: ServerTransport.ssh), full), isTrue);
      expect(tmuxOn(server(), full), isTrue);
    });

    // What the old predicate got wrong. It read `Spi.transport`, which says
    // the agent leads; the grant says the agent will not serve a shell, so
    // SSH carries the session and tmux works on it perfectly well. The key
    // was hidden on the one server that is configured both ways.
    test('is there when the agent leads but will not serve a shell', () {
      final spi = server(prefer: ServerTransport.monitorHttp);
      expect(tmuxOn(spi, const MonitorRemoteAccess()), isTrue);
      expect(tmuxOn(spi, null), isTrue);
    });

    test('is gone on a server with no SSH to fall back to', () {
      expect(tmuxOn(server(withSsh: false), full), isFalse);
    });
  });

  group('the file browser', () {
    test('uses the agent when the agent leads and has its file API', () {
      final spi = server(prefer: ServerTransport.monitorHttp);
      expect(serverFilesUseAgent(spi, full), isTrue);
    });

    test('uses SFTP when SSH leads', () {
      final spi = server(prefer: ServerTransport.ssh);
      expect(serverFilesUseAgent(spi, full), isFalse);
    });

    test('uses SFTP when the agent leads without its file API', () {
      final spi = server(prefer: ServerTransport.monitorHttp);
      expect(serverFilesUseAgent(spi, const MonitorRemoteAccess()), isFalse);
      expect(serverFilesUseAgent(spi, null), isFalse);
      // Not `ServerCapabilities.files`, which is the union and so answers true
      // for every server with an SSH credential however the agent is
      // configured — asking it here put the agent's page in front of a server
      // whose agent serves no files.
      expect(
        ServerCapabilities.ofSpi(spi, granted: const MonitorRemoteAccess())
            .files,
        isTrue,
      );
    });

    test('uses the agent for a server with no byte stream to run SFTP on', () {
      // The case the file API exists for: an agent on a host whose sshd this
      // app cannot reach. No order to resolve, so the grant decides alone.
      final spi = server(withSsh: false);
      expect(serverFilesUseAgent(spi, full), isTrue);
    });

    test('never uses the agent on a server that has none', () {
      final spi = server(withMonitor: false);
      expect(serverFilesUseAgent(spi, full), isFalse);
      expect(
        ServerCapabilities.ofSpi(spi).byteStream,
        isTrue,
        reason: 'SFTP is the remaining answer',
      );
    });
  });

  group('a command', () {
    // `ensureExec` already followed the order; this is the assertion that the
    // three now agree, which is the whole point of the change.
    test('goes the same way the shell and the files do', () {
      for (final prefer in ServerTransport.values) {
        final spi = server(prefer: prefer);
        final leads = ServerConnectCredential.fromSpi(spi);
        final agentLeads = leads is ServerConnectCredentialMonitorHttp;
        expect(
          agentLeads,
          prefer == ServerTransport.monitorHttp,
          reason: 'exec follows $prefer',
        );
        expect(serverShellUsesAgent(spi, full), agentLeads);
        expect(serverFilesUseAgent(spi, full), agentLeads);
      }
    });
  });
}
