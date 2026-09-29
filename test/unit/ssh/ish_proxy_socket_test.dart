import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ish_proxy_socket.dart';

void main() {
  group('IshProxySocket.wrap', () {
    test('what the guest prints is the marker the socket waits for', () async {
      // Run the prefix through a real `sh`: `printf` has to turn the octal
      // escapes into the two control bytes, or the socket never sees it.
      final script = IshProxySocket.wrap('true', err: '/dev/null');
      final printf = script.split('; ')[1];
      final result = await Process.run('sh', ['-c', printf], stdoutEncoding: null);
      expect(
        result.stdout as List<int>,
        utf8.encode(IshProxySocket.readyMarker),
      );
    });

    test('the terminal is made raw before anything else runs', () {
      final script = IshProxySocket.wrap('nc %h %p', err: '/tmp/x.err');
      expect(script, startsWith('stty raw -echo || exit 97; '));
      expect(script, endsWith("exec sh -c 'nc %h %p' 2>'/tmp/x.err'"));
    });

    test('a quote in the command stays inside it', () async {
      final script = IshProxySocket.wrap(r"echo 'a b'; echo it\'s", err: '/e');
      final exec = script.substring(script.indexOf('exec sh -c ') + 11);
      final command = exec.substring(0, exec.lastIndexOf(' 2>'));
      // What a shell reads back is exactly what was wrapped.
      final result = await Process.run('sh', ['-c', 'printf %s $command']);
      expect(result.stdout, r"echo 'a b'; echo it\'s");
    });
  });

  group('IshProxySocket.indexOf', () {
    final marker = utf8.encode(IshProxySocket.readyMarker);

    test('finds the marker after a preamble', () {
      final bytes = [...utf8.encode('motd\r\n'), ...marker, 0x53, 0x53];
      expect(IshProxySocket.indexOf(bytes, marker), 6);
    });

    test('answers -1 for a marker cut off at the end', () {
      final bytes = marker.sublist(0, marker.length - 1);
      expect(IshProxySocket.indexOf(bytes, marker), -1);
    });

    test('answers -1 for nothing', () {
      expect(IshProxySocket.indexOf(const [], marker), -1);
    });
  });
}
