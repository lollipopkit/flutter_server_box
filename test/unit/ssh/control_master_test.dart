import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/ssh/config.dart';
import 'package:server_box/core/ssh/control_master.dart';

void main() {
  test('%h and %C take the host lowercased, as OpenSSH does', () {
    String? expand(String host) => SSHConfig.expandControlPath(
      '/tmp/cm-%C-%h',
      hostname: host,
      remoteUser: 'u',
      port: 22,
      localHost: 'mac.local',
    );

    expect(expand('MyBox.Example.COM'), expand('mybox.example.com'));
    expect(expand('MyBox.Example.COM'), endsWith('-mybox.example.com'));
  });

  group('the master\'s connection is the one with the token', () {
    late Directory dir;
    late ServerSocket listener;
    late String path;
    final token = Uint8List.fromList(List.generate(16, (i) => i + 1));

    setUp(() async {
      dir = await Directory('/tmp').createTemp('sbmuxt');
      path = '${dir.path}/s';
      listener = await ServerSocket.bind(
        InternetAddress(path, type: InternetAddressType.unix),
        0,
      );
    });

    tearDown(() async {
      await listener.close();
      await dir.delete(recursive: true);
    });

    Future<Socket> dial() =>
        Socket.connect(InternetAddress(path, type: InternetAddressType.unix), 0);

    test('one that connects first without it is turned away', () async {
      final accept = StdioAccept(listener, token);

      final impostor = await dial();
      impostor.add(Uint8List(16));
      final turnedAway = impostor.drain<void>().then((_) => true);

      final real = await dial();
      // The token in two pieces, the stream right behind it.
      real.add(token.sublist(0, 5));
      await real.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      real.add([...token.sublist(5), ...utf8.encode('SSH-2.0-x')]);
      await real.flush();

      final ours = await accept.socket.timeout(const Duration(seconds: 2));
      final first = await ours.stream.first.timeout(const Duration(seconds: 2));
      expect(utf8.decode(first), 'SSH-2.0-x');
      expect(await turnedAway.timeout(const Duration(seconds: 2)), isTrue);

      accept.cancel();
      ours.destroy();
      real.destroy();
    });

    test('cancelled, a connection still being read is closed', () async {
      final accept = StdioAccept(listener, token);
      final pending = await dial();
      pending.add(token.sublist(0, 3));
      await pending.flush();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      accept.cancel();

      await pending.drain<void>().timeout(const Duration(seconds: 2));
    });
  });
}
