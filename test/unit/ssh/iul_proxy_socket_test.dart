import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/ssh/iul_proxy_socket.dart';
import 'package:server_box/data/model/app/error.dart';

void main() {
  group('IulProxySocket.wrap', () {
    test('what the guest prints is the marker the socket waits for', () async {
      // Run the prefix through a real `sh`: `printf` has to turn the octal
      // escapes into the two control bytes, or the socket never sees it.
      final script = IulProxySocket.wrap('true', err: '/dev/null');
      final printf = script.split('; ')[1];
      final result = await Process.run('sh', ['-c', printf], stdoutEncoding: null);
      expect(
        result.stdout as List<int>,
        utf8.encode(IulProxySocket.readyMarker),
      );
    });

    test('the terminal is made raw before anything else runs', () {
      final script = IulProxySocket.wrap('nc %h %p', err: '/tmp/x.err');
      expect(script, startsWith('stty raw -echo || exit 97; '));
      expect(script, endsWith("exec sh -c 'nc %h %p' 2>'/tmp/x.err'"));
    });

    test('a quote in the command stays inside it', () async {
      final script = IulProxySocket.wrap(r"echo 'a b'; echo it\'s", err: '/e');
      final exec = script.substring(script.indexOf('exec sh -c ') + 11);
      final command = exec.substring(0, exec.lastIndexOf(' 2>'));
      // What a shell reads back is exactly what was wrapped.
      final result = await Process.run('sh', ['-c', 'printf %s $command']);
      expect(result.stdout, r"echo 'a b'; echo it\'s");
    });
  });

  group('IulProxySocket.indexOf', () {
    final marker = utf8.encode(IulProxySocket.readyMarker);

    test('finds the marker after a preamble', () {
      final bytes = [...utf8.encode('motd\r\n'), ...marker, 0x53, 0x53];
      expect(IulProxySocket.indexOf(bytes, marker), 6);
    });

    test('answers -1 for a marker cut off at the end', () {
      final bytes = marker.sublist(0, marker.length - 1);
      expect(IulProxySocket.indexOf(bytes, marker), -1);
    });

    test('answers -1 for nothing', () {
      expect(IulProxySocket.indexOf(const [], marker), -1);
    });
  });

  group('IulProxySocket.flush and close', () {
    test('sink.add followed immediately by flush waits until all bytes are written', () async {
      final dir = await Directory.systemTemp.createTemp('iul_proxy_flush_');
      addTearDown(() => dir.delete(recursive: true));
      final errFile = File('${dir.path}/proxy.err');
      final reads = <Uint8List?>[
        Uint8List.fromList(utf8.encode(IulProxySocket.readyMarker)),
      ];
      final written = <int>[];
      var flushed = false;
      var closed = false;
      var canWrite = true;

      final socket = IulProxySocket.forTesting(
        errFile: errFile,
        read: (_, {Duration timeout = Duration.zero}) {
          if (reads.isNotEmpty) return reads.removeAt(0);
          canWrite = true;
          return closed ? null : Uint8List(0);
        },
        tryWrite: (_, bytes) {
          if (!canWrite) return 0;
          canWrite = false;
          final take = bytes.length > 3 ? 3 : bytes.length;
          written.addAll(bytes.sublist(0, take));
          return take;
        },
        exitCode: (_) => closed ? 0 : null,
        closeSession: (_) => closed = true,
      );

      await socket.ready;
      final payload = utf8.encode('hello-proxy-flush');
      socket.sink.add(payload);
      final flushFuture = socket.flush().then((_) => flushed = true);

      // Pump microtasks; flush must remain pending until ticks drain the queue.
      await Future<void>.delayed(Duration.zero);
      expect(flushed, isFalse);
      expect(written.length, lessThan(payload.length));

      await flushFuture;
      expect(flushed, isTrue);
      expect(written, payload);

      closed = true;
      await socket.close();
    });

    test('sink.add followed immediately by close drains pending bytes before teardown', () async {
      final dir = await Directory.systemTemp.createTemp('iul_proxy_close_');
      addTearDown(() => dir.delete(recursive: true));
      final errFile = File('${dir.path}/proxy.err');
      final reads = <Uint8List?>[
        Uint8List.fromList(utf8.encode(IulProxySocket.readyMarker)),
      ];
      final written = <int>[];
      var sessionClosed = false;
      var canWrite = true;

      final socket = IulProxySocket.forTesting(
        errFile: errFile,
        read: (_, {Duration timeout = Duration.zero}) {
          if (reads.isNotEmpty) return reads.removeAt(0);
          canWrite = true;
          return sessionClosed ? null : Uint8List(0);
        },
        tryWrite: (_, bytes) {
          if (sessionClosed) return -1;
          if (!canWrite) return 0;
          canWrite = false;
          final take = bytes.length > 4 ? 4 : bytes.length;
          written.addAll(bytes.sublist(0, take));
          return take;
        },
        exitCode: (_) => sessionClosed ? 0 : null,
        closeSession: (_) => sessionClosed = true,
      );

      await socket.ready;
      final payload = utf8.encode('drain-before-close');
      socket.sink.add(payload);
      await socket.close();

      expect(sessionClosed, isTrue);
      expect(written, payload);
    });

    test('transient StateError on read does not tear down the session', () async {
      final dir = await Directory.systemTemp.createTemp('iul_proxy_busy_');
      addTearDown(() => dir.delete(recursive: true));
      final errFile = File('${dir.path}/proxy.err');
      var call = 0;
      var closed = false;
      final received = <int>[];

      final socket = IulProxySocket.forTesting(
        errFile: errFile,
        read: (_, {Duration timeout = Duration.zero}) {
          call++;
          if (call == 1) {
            return Uint8List.fromList(utf8.encode(IulProxySocket.readyMarker));
          }
          if (call == 2) throw StateError('busy');
          if (call == 3) return Uint8List.fromList(utf8.encode('ok'));
          return closed ? null : Uint8List(0);
        },
        tryWrite: (_, bytes) => bytes.length,
        exitCode: (_) => closed ? 0 : null,
        closeSession: (_) => closed = true,
      );

      final sub = socket.stream.listen(received.addAll);
      await socket.ready;
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(utf8.decode(received), 'ok');

      closed = true;
      await socket.close();
      await sub.cancel();
    });

    test('a session lock that stays taken ends the session', () async {
      final dir = await Directory.systemTemp.createTemp('iul_proxy_stuck_');
      addTearDown(() => dir.delete(recursive: true));
      final errFile = File('${dir.path}/proxy.err');
      var readySent = false;
      var reads = 0;
      var closed = false;

      final socket = IulProxySocket.forTesting(
        errFile: errFile,
        read: (_, {Duration timeout = Duration.zero}) {
          if (!readySent) {
            readySent = true;
            return Uint8List.fromList(utf8.encode(IulProxySocket.readyMarker));
          }
          reads++;
          throw StateError('busy');
        },
        tryWrite: (_, bytes) => bytes.length,
        exitCode: (_) => null,
        closeSession: (_) => closed = true,
      );

      final errors = <Object>[];
      final sub = socket.stream.listen((_) {}, onError: errors.add);
      await socket.ready;
      await socket.done.timeout(const Duration(seconds: 2));
      expect(closed, isTrue);
      expect(reads, 3);
      expect(errors.single, isA<StateError>());
      await sub.cancel();
    });

    test('premature session end with buffered bytes fails flush', () async {
      final dir = await Directory.systemTemp.createTemp('iul_proxy_drop_');
      addTearDown(() => dir.delete(recursive: true));
      final errFile = File('${dir.path}/proxy.err');
      var call = 0;
      var closed = false;

      final socket = IulProxySocket.forTesting(
        errFile: errFile,
        read: (_, {Duration timeout = Duration.zero}) {
          call++;
          if (call == 1) {
            return Uint8List.fromList(utf8.encode(IulProxySocket.readyMarker));
          }
          if (call == 2) return Uint8List(0);
          return null;
        },
        tryWrite: (_, _) => 0,
        exitCode: (_) => closed ? 1 : null,
        closeSession: (_) => closed = true,
      );

      await socket.ready;
      socket.sink.add(utf8.encode('unsent-payload'));
      await expectLater(socket.flush(), throwsA(isA<SSHErr>()));
      await expectLater(socket.flush(), throwsA(isA<SSHErr>()));
      await socket.done;
    });

    test('writing after close records write error for flush', () async {
      final dir = await Directory.systemTemp.createTemp('iul_proxy_postclose_');
      addTearDown(() => dir.delete(recursive: true));
      final errFile = File('${dir.path}/proxy.err');
      var readySent = false;
      var closed = false;

      final socket = IulProxySocket.forTesting(
        errFile: errFile,
        read: (_, {Duration timeout = Duration.zero}) {
          if (!readySent) {
            readySent = true;
            return Uint8List.fromList(utf8.encode(IulProxySocket.readyMarker));
          }
          return closed ? null : Uint8List(0);
        },
        tryWrite: (_, bytes) => bytes.length,
        exitCode: (_) => closed ? 0 : null,
        closeSession: (_) => closed = true,
      );

      await socket.ready;
      final closeFuture = socket.close();
      socket.sink.add(utf8.encode('too-late'));
      await closeFuture;
      await expectLater(socket.flush(), throwsA(isA<SSHErr>()));
    });

    test('flush while _runFinish awaits stderr still observes write error', () async {
      final dir = await Directory.systemTemp.createTemp('iul_proxy_midfinish_');
      addTearDown(() => dir.delete(recursive: true));
      final errFile = File('${dir.path}/proxy.err');
      await errFile.writeAsString('remote closed\n');

      var call = 0;
      var closed = false;
      Future<void>? flushDuringFinish;
      late IulProxySocket socket;

      socket = IulProxySocket.forTesting(
        errFile: errFile,
        read: (_, {Duration timeout = Duration.zero}) {
          call++;
          if (call == 1) {
            return Uint8List.fromList(utf8.encode(IulProxySocket.readyMarker));
          }
          if (call == 2) return Uint8List(0);
          // On EOF (`null`), invoke flush() immediately on the same tick
          // while _runFinish is suspended at `await _readErr()`.
          scheduleMicrotask(() {
            flushDuringFinish ??= expectLater(
              socket.flush(),
              throwsA(isA<SSHErr>()),
            );
          });
          return null;
        },
        tryWrite: (_, _) => 0,
        exitCode: (_) => closed ? 1 : null,
        closeSession: (_) => closed = true,
      );

      await socket.ready;
      socket.sink.add(utf8.encode('unsent-while-finishing'));
      await socket.done;
      expect(flushDuringFinish, isNotNull);
      await flushDuringFinish!;
    });
  });
}
