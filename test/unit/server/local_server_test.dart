import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/local_server.dart';
import 'package:server_box/data/model/server/capabilities.dart';
import 'package:server_box/data/model/server/connect_credential.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/ssh/terminal_session.dart';
import 'package:server_box/view/page/storage/server_file.dart';

/// A server that is this device: what it dials, and what it keeps.
void main() {
  const monitor = MonitorHttpCredential(addr: 'https://agent:3770');
  const ssh = SshCredential(ip: 'host', port: 22, user: 'root', pwd: 'p');
  const full = MonitorRemoteAccess(
    terminal: true,
    fullAccess: true,
    files: true,
  );

  Spi local({bool parked = false}) => Spi(
    name: 'me',
    id: 'id',
    local: true,
    ssh: parked ? ssh : null,
    monitorHttp: parked ? monitor : null,
    preferredTransport: parked ? ServerTransport.monitorHttp : null,
  );

  group('with nothing else configured', () {
    test('is a valid record', () {
      // Neither an address nor an agent, which is otherwise refused.
      expect(local().validate(), isNull);
      expect(
        const Spi(name: 'n', id: 'n').validate(),
        SpiValidationError.noConnectionMethod,
      );
    });

    test('is reached locally and has no fallback', () {
      final spi = local();
      expect(spi.transport, ServerTransport.local);
      expect(spi.fallbackTransport, isNull);
      expect(
        ServerConnectCredential.fromSpi(spi),
        isA<ServerConnectCredentialLocal>(),
      );
      expect(ServerConnectCredential.fallbackOf(spi), isNull);
    });

    test('says localhost rather than an id', () {
      expect(local().displayAddr, 'localhost');
    });
  });

  group('with SSH and an agent parked', () {
    test('keeps both on file and dials neither', () {
      // The switch hides the methods rather than dropping them, so turning it
      // off is not a retyping exercise.
      final spi = local(parked: true);
      expect(spi.ssh, ssh);
      expect(spi.monitor, monitor);
      expect(spi.sshOn, isNull);
      expect(spi.monitorOn, isNull);
      expect(spi.transport, ServerTransport.local);
      expect(spi.fallbackTransport, isNull);
    });

    test('never routes the shell or the files to the agent', () {
      final spi = local(parked: true);
      expect(serverShellUsesAgent(spi, full), isFalse);
      expect(serverFilesUseAgent(spi, full), isFalse);
    });

    test('ignores a conflict among settings that are not dialled', () {
      final spi = local(parked: true).copyWith(
        ssh: ssh.copyWith(jumpIds: ['j'], proxyCommand: 'nc %h %p'),
      );
      expect(spi.validate(), isNull);
      // The same record, dialled, is refused.
      expect(
        spi.copyWith(local: false).validate(),
        SpiValidationError.jumpServerAndProxyCommandConflict,
      );
    });

    test('turning it off brings back the order that was set', () {
      final spi = local(parked: true).copyWith(local: false);
      expect(spi.transport, ServerTransport.monitorHttp);
      expect(spi.fallbackTransport, ServerTransport.ssh);
    });
  });

  test('switching to or from this device reconnects', () {
    final remote = local(parked: true).copyWith(local: false);
    expect(local(parked: true).isSameAs(remote), isFalse);
    expect(local(parked: true).shouldReconnect(remote), isTrue);
    expect(remote.shouldReconnect(local(parked: true)), isTrue);
  });

  test('survives a JSON round trip', () {
    final spi = local(parked: true);
    final read = Spi.fromJson(
      jsonDecode(spi.toJsonString()) as Map<String, dynamic>,
    );
    expect(read.local, isTrue);
    expect(read, spi);
    // An older record has no key at all, and is not this device.
    final older = Spi.fromJson({
      'name': 'n',
      'id': 'n',
      'ssh': {'ip': 'host'},
    });
    expect(older.local, isFalse);
  });

  group('capabilities', () {
    test('are the shell, the terminal and the files, and no stream', () {
      const caps = LocalCapabilities(supported: true);
      expect(caps.shell, isTrue);
      expect(caps.terminal, isTrue);
      expect(caps.files, isTrue);
      expect(caps.byteStream, isFalse);
      expect(caps.tcpRelay, isFalse);
      expect(caps.storedHistory, isFalse);
      expect(caps.persistentSession, isFalse);
    });

    test('are nothing where this build cannot run a process', () {
      // A local server synced to a phone: buttons that can only fail are not
      // offered.
      const caps = LocalCapabilities(supported: false);
      expect(caps.shell, isFalse);
      expect(caps.terminal, isFalse);
      expect(caps.files, isFalse);
    });

    test('follow this platform', () {
      final caps = ServerCapabilities.ofSpi(local(parked: true));
      expect(caps, LocalCapabilities(supported: LocalServer.isSupported));
    });
  });
}
