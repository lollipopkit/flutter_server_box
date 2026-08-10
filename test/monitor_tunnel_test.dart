import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/monitor_tunnel_socket.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

/// A stand-in for a `monitor` agent: answers the login and ticket calls, then
/// echoes whatever arrives on the tunnel WebSocket.
///
/// Speaking the real HTTP shape (rather than mocking [MonitorHttpClient])
/// keeps this honest about the parts most likely to break — the ticket
/// exchange and the ws:// URL derivation.
class _FakeAgent {
  _FakeAgent(this._server, this.requestedPaths);

  final HttpServer _server;
  final List<String> requestedPaths;

  static Future<_FakeAgent> start({
    bool grantTicket = true,
    bool echo = true,
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final paths = <String>[];
    final agent = _FakeAgent(server, paths);

    unawaited(() async {
      await for (final req in server) {
        paths.add(req.uri.path);
        switch (req.uri.path) {
          case '/api/v1/login':
            await req.drain<void>();
            req.response
              ..headers.contentType = ContentType.json
              ..write(jsonEncode({'token': 'test-token'}));
            await req.response.close();
          case '/api/v1/ws-ticket':
            await req.drain<void>();
            if (!grantTicket) {
              req.response.statusCode = HttpStatus.forbidden;
              await req.response.close();
              break;
            }
            req.response
              ..headers.contentType = ContentType.json
              ..write(
                jsonEncode({'ticket': 'abc.def', 'expires_in': 30}),
              );
            await req.response.close();
          case '/api/v1/tunnel/ws':
            final socket = await WebSocketTransformer.upgrade(req);
            if (echo) {
              socket.listen(socket.add, onDone: socket.close);
            } else {
              await socket.close();
            }
          default:
            req.response.statusCode = HttpStatus.notFound;
            await req.response.close();
        }
      }
    }());

    return agent;
  }

  MonitorHttpCredential get credential => MonitorHttpCredential(
    addr: 'http://${_server.address.address}:${_server.port}',
    user: 'admin',
    pwd: 'secret',
  );

  Future<void> stop() => _server.close(force: true);
}

void main() {
  group('MonitorTunnelSocket', () {
    late _FakeAgent agent;

    tearDown(() => agent.stop());

    test('logs in, takes a ticket, then relays bytes', () async {
      agent = await _FakeAgent.start();
      final socket = await MonitorTunnelSocket.connect(
        monitor: agent.credential,
      );
      addTearDown(socket.destroy);

      final received = <int>[];
      final gotFive = Completer<void>();
      socket.stream.listen((chunk) {
        received.addAll(chunk);
        if (received.length >= 5 && !gotFive.isCompleted) gotFive.complete();
      });

      socket.sink.add(Uint8List.fromList([1, 2, 3, 4, 5]));
      await gotFive.future.timeout(const Duration(seconds: 5));

      expect(received, [1, 2, 3, 4, 5]);
      expect(
        agent.requestedPaths,
        containsAllInOrder([
          '/api/v1/login',
          '/api/v1/ws-ticket',
          '/api/v1/tunnel/ws',
        ]),
        reason: 'the upgrade must be authorised by a freshly issued ticket',
      );
    });

    test('splits writes larger than one frame', () async {
      agent = await _FakeAgent.start();
      final socket = await MonitorTunnelSocket.connect(
        monitor: agent.credential,
      );
      addTearDown(socket.destroy);

      // The agent's codec rejects frames over 64 KiB; a single oversized
      // write must not be handed over whole
      const total = 100 * 1024;
      final received = <int>[];
      final done = Completer<void>();
      socket.stream.listen((chunk) {
        received.addAll(chunk);
        if (received.length >= total && !done.isCompleted) done.complete();
      });

      socket.sink.add(Uint8List(total)..fillRange(0, total, 0x5A));
      await done.future.timeout(const Duration(seconds: 10));

      expect(received.length, total);
      expect(received.every((b) => b == 0x5A), isTrue);
    });

    test('completes done when the agent closes the tunnel', () async {
      agent = await _FakeAgent.start(echo: false);
      final socket = await MonitorTunnelSocket.connect(
        monitor: agent.credential,
      );
      // Draining is required for the close to surface; dartssh2 always reads
      socket.stream.listen((_) {}, onError: (_) {});

      await expectLater(socket.done.timeout(const Duration(seconds: 5)), completes);
    });

    test('surfaces a refused ticket instead of hanging', () async {
      agent = await _FakeAgent.start(grantTicket: false);
      await expectLater(
        MonitorTunnelSocket.connect(monitor: agent.credential),
        throwsA(anything),
      );
    });
  });

  group('viaMonitor validation', () {
    Spi spiWith({
      required SshCredential? ssh,
      MonitorHttpCredential? monitor,
    }) => Spi(name: 'test', ssh: ssh, monitorHttp: monitor, id: 'test-id');

    const monitor = MonitorHttpCredential(addr: 'https://agent:3770');

    test('accepts a tunnel with a monitor endpoint', () {
      final spi = spiWith(
        ssh: const SshCredential(ip: '', viaMonitor: true),
        monitor: monitor,
      );
      expect(spi.validate(), isNull);
    });

    test('rejects a tunnel with no monitor endpoint', () {
      final spi = spiWith(ssh: const SshCredential(ip: '', viaMonitor: true));
      expect(
        spi.validate(),
        SpiValidationError.monitorTunnelWithoutMonitor,
        reason: 'there would be nothing to tunnel through',
      );
    });

    test('rejects a tunnel combined with another transport', () {
      // Each of these is also an answer to "where does the socket come from",
      // so exactly one may win
      for (final ssh in [
        const SshCredential(ip: '', viaMonitor: true, jumpIds: ['other']),
        const SshCredential(ip: '', viaMonitor: true, proxyCommand: 'nc %h %p'),
        const SshCredential(ip: '', viaMonitor: true, alterUrl: 'a@b:22'),
      ]) {
        expect(
          spiWith(ssh: ssh, monitor: monitor).validate(),
          SpiValidationError.monitorTunnelAndOtherTransport,
        );
      }
    });

    test('rejects a passwordless terminal with no monitor endpoint', () {
      final spi = spiWith(
        ssh: null,
        monitor: const MonitorHttpCredential(
          addr: '  ',
          passwordlessTerminal: true,
        ),
      );
      expect(
        spi.validate(),
        SpiValidationError.passwordlessTerminalWithoutMonitor,
        reason: 'there would be no agent to open it on',
      );
    });

    test('rejects a passwordless terminal alongside SSH', () {
      // Both answer where the shell comes from, and they answer it
      // differently — SSH gives every shell-backed feature, the PTY gives one
      for (final ssh in [
        const SshCredential(ip: '10.0.0.1'),
        const SshCredential(ip: '', viaMonitor: true),
      ]) {
        expect(
          spiWith(
            ssh: ssh,
            monitor: const MonitorHttpCredential(
              addr: 'https://agent:3770',
              passwordlessTerminal: true,
            ),
          ).validate(),
          SpiValidationError.passwordlessTerminalAndSsh,
        );
      }
    });

    test('accepts a passwordless terminal on its own', () {
      final spi = spiWith(
        ssh: null,
        monitor: const MonitorHttpCredential(
          addr: 'https://agent:3770',
          passwordlessTerminal: true,
        ),
      );
      expect(spi.validate(), isNull);
    });

    test('leaves direct SSH alone', () {
      final spi = spiWith(ssh: const SshCredential(ip: '10.0.0.1'));
      expect(spi.validate(), isNull);
    });

    test('changing viaMonitor forces a reconnect', () {
      const direct = SshCredential(ip: '10.0.0.1');
      final tunneled = direct.copyWith(viaMonitor: true);
      expect(
        direct.isSameAs(tunneled),
        isFalse,
        reason: 'how the socket is obtained is part of the connection identity',
      );
    });

    test('survives a JSON round trip, defaulting to false when absent', () {
      const credential = SshCredential(ip: '', user: 'ops', viaMonitor: true);
      final restored = SshCredential.fromJson(credential.toJson());
      expect(restored.viaMonitor, isTrue);
      expect(restored.user, 'ops');

      // Records written before the field existed
      final legacy = SshCredential.fromJson({'ip': '10.0.0.1', 'port': 22});
      expect(legacy.viaMonitor, isFalse);
    });

    test('displayAddr names the agent rather than an empty host', () {
      final spi = spiWith(
        ssh: const SshCredential(ip: '', user: 'ops', viaMonitor: true),
        monitor: monitor,
      );
      expect(spi.displayAddr, 'ops@https://agent:3770');
    });
  });

  group('ServerCapabilities', () {
    const monitor = MonitorHttpCredential(addr: 'https://agent:3770');

    test('a monitor server with SSH configured has a shell', () {
      final spi = Spi(
        name: 'test',
        id: 'a',
        ssh: const SshCredential(ip: '', viaMonitor: true),
        monitorHttp: monitor,
      );
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
      );
      expect(caps.shell, isTrue);
      expect(caps.storedHistory, isTrue);
      expect(
        caps.persistentSession,
        isFalse,
        reason: 'status is still a stateless poll; SSH connects lazily',
      );
    });

    test('a monitor server without SSH has no shell', () {
      final spi = Spi(name: 'test', id: 'b', monitorHttp: monitor);
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
      );
      expect(caps.shell, isFalse);
      expect(caps.terminal, isFalse);
    });

    test('a passwordless agent gives a terminal but not a shell', () {
      // The agent's PTY is one stream, so SFTP, port forwarding and the
      // process pages have nothing to run on. Offering them would be a row of
      // entries that each fail on open.
      final spi = Spi(
        name: 'test',
        id: 'd',
        monitorHttp: const MonitorHttpCredential(
          addr: 'https://agent:3770',
          passwordlessTerminal: true,
        ),
      );
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
      );
      expect(caps.terminal, isTrue);
      expect(caps.shell, isFalse);
      expect(caps.storedHistory, isTrue);
    });

    test('SSH wins when both are somehow configured', () {
      // `validate` rejects this, so it can only arrive from hand-edited
      // storage — and then the more capable answer is the safe one
      final spi = Spi(
        name: 'test',
        id: 'e',
        ssh: const SshCredential(ip: '10.0.0.1'),
        monitorHttp: const MonitorHttpCredential(
          addr: 'https://agent:3770',
          passwordlessTerminal: true,
        ),
      );
      final caps = ServerCapabilities.of(
        ServerConnectCredential.fromSpi(spi),
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
