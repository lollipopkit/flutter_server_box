import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/scp_protocol.dart';

/// A scripted `scp`, so the protocol can be exercised without a server.
///
/// The real far side is a program that reads and writes in lockstep, and that
/// is exactly what this is: [onWrite] sees everything this device sends and
/// decides what comes back. Nothing here mocks the protocol — it *is* the other
/// half of it, which is what makes a mistake in either half show up.
final class _FakeScp implements ScpChannel {
  _FakeScp({this.exit = 0});

  final _out = StreamController<Uint8List>();
  final _err = StreamController<Uint8List>();

  /// Everything this device sent, in order.
  final sent = BytesBuilder(copy: false);

  /// Called with each piece this device sends.
  void Function(_FakeScp remote, Uint8List data)? onWrite;

  int? exit;

  var inputClosed = false;
  var closed = false;

  @override
  Stream<Uint8List> get stdout => _out.stream;

  @override
  Stream<Uint8List> get stderr => _err.stream;

  @override
  void add(Uint8List data) {
    sent.add(data);
    onWrite?.call(this, data);
  }

  @override
  Future<void> flush() async {}

  @override
  Future<void> closeInput() async {
    inputClosed = true;
  }

  @override
  Future<int?> exitCode({Duration? timeout}) async => exit;

  @override
  void close() {
    closed = true;
    if (!_out.isClosed) _out.close();
    if (!_err.isClosed) _err.close();
  }

  /// What the far side answers with.
  void reply(List<int> bytes) => _out.add(Uint8List.fromList(bytes));

  void replyText(String text) => reply(utf8.encode(text));

  void ack() => reply(const [0]);

  void complain(String message, {int severity = 1}) =>
      reply([severity, ...utf8.encode('$message\n')]);

  void sayOnStderr(String text) => _err.add(Uint8List.fromList(utf8.encode(text)));

  void endOutput() {
    if (!_out.isClosed) _out.close();
    if (!_err.isClosed) _err.close();
  }
}

/// A source that hands over [contents] and then goes away.
_FakeScp _source(String contents, {String name = 'hosts', String mode = '0644'}) {
  final remote = _FakeScp();
  var step = 0;
  remote.onWrite = (r, _) {
    switch (step++) {
      // The client's opening `\0`: "send it".
      case 0:
        r.replyText('C$mode ${utf8.encode(contents).length} $name\n');
      // The client's `\0` after the header: the contents, then the status byte
      // that says they arrived whole.
      case 1:
        r.replyText(contents);
        r.ack();
      // The client's final `\0`.
      case 2:
        r.endOutput();
    }
  };
  return remote;
}

void main() {
  group('reading a file', () {
    test('hands over exactly what the far side sent', () async {
      final remote = _source('127.0.0.1 localhost\n');

      final read = await scpRead(remote, '/etc/hosts').toList();

      expect(utf8.decode(read.expand((c) => c).toList()), '127.0.0.1 localhost\n');
      // Three single `\0`s: start, after the header, after the contents. The
      // far side is waiting for each one and sends nothing until it arrives.
      expect(remote.sent.toBytes(), Uint8List.fromList([0, 0, 0]));
      expect(remote.inputClosed, isTrue);
    });

    test('an empty file is a file, not a failure', () async {
      final remote = _source('');

      final read = await scpRead(remote, '/tmp/empty').toList();

      expect(read.expand((c) => c), isEmpty);
    });

    test('a refusal arrives as the message the far side wrote', () async {
      final remote = _FakeScp(exit: 1);
      remote.onWrite = (r, _) =>
          r.complain('scp: /etc/shadow: Permission denied');

      // The remote's own words, so that `classifyFileError` reads the same
      // thing here as it does for an SFTP status code and the browser can
      // offer sudo.
      await expectLater(
        scpRead(remote, '/etc/shadow').toList(),
        throwsA(
          isA<ScpException>().having(
            (e) => e.message,
            'message',
            contains('Permission denied'),
          ),
        ),
      );
    });

    test('a host with no scp says so rather than timing out', () async {
      final remote = _FakeScp(exit: 127);
      remote.onWrite = (r, _) => r.endOutput();

      await expectLater(
        scpRead(remote, '/etc/hosts').toList(),
        throwsA(
          isA<ScpException>().having(
            (e) => e.message,
            'message',
            contains('not found on the remote host'),
          ),
        ),
      );
    });

    test('a login banner is reported, not read as contents', () async {
      // A `.profile` that prints something lands ahead of everything scp says.
      // Read as protocol it would be a header, and the file would arrive as
      // whatever the banner happened to parse to.
      final remote = _FakeScp();
      remote.onWrite = (r, _) {
        r.replyText('Welcome to OpenWrt\n');
        r.endOutput();
      };

      await expectLater(
        scpRead(remote, '/etc/hosts').toList(),
        throwsA(
          isA<ScpException>().having(
            (e) => e.message,
            'message',
            contains('Welcome to OpenWrt'),
          ),
        ),
      );
    });

    test('a connection that dies mid-file is not a short file', () async {
      final remote = _FakeScp();
      var step = 0;
      remote.onWrite = (r, _) {
        switch (step++) {
          case 0:
            r.replyText('C0644 10 hosts\n');
          case 1:
            r.replyText('abc');
            r.endOutput();
        }
      };

      await expectLater(
        scpRead(remote, '/etc/hosts').toList(),
        throwsA(isA<ScpException>()),
      );
    });

    test('a header that never ends is refused, not half-read', () async {
      // Stopping quietly at the limit would leave the rest of the header in
      // the stream, where the bytes after it are read as file contents — a
      // transfer that arrives shifted rather than one that fails.
      final remote = _FakeScp();
      remote.onWrite = (r, _) => r.replyText('C0644 10 ${'a' * 5000}');

      await expectLater(
        scpRead(remote, '/tmp/x').toList(),
        throwsA(isA<ScpException>()),
      );
    });

    test('an offset drops the bytes before it', () async {
      // The protocol cannot start anywhere but zero, so the whole file comes
      // across and the head of it is discarded here.
      final remote = _source('0123456789');

      final read = await scpRead(remote, '/tmp/x', offset: 4).toList();

      expect(utf8.decode(read.expand((c) => c).toList()), '456789');
    });
  });

  group('writing a file', () {
    /// A sink that accepts a header and then [size] bytes.
    _FakeScp sink() {
      final remote = _FakeScp();
      final received = BytesBuilder(copy: false);
      final header = <int>[];
      var declared = -1;
      remote.onWrite = (r, data) {
        if (declared < 0) {
          header.addAll(data);
          final end = header.indexOf(0x0A);
          if (end < 0) return;
          final line = utf8.decode(header.sublist(0, end));
          declared = int.parse(line.split(' ')[1]);
          r.ack();
          return;
        }
        if (received.length < declared) {
          received.add(data);
          return;
        }
        // The terminating `\0` after the contents.
        r.ack();
      };
      // The sink speaks first.
      scheduleMicrotask(remote.ack);
      return remote;
    }

    test('declares the size and the mode before the contents', () async {
      final remote = sink();

      await scpWrite(
        remote,
        '/tmp/hosts',
        Stream.value(utf8.encode('hello')),
        size: 5,
        mode: 0x1A4,
      );

      final sent = utf8.decode(remote.sent.toBytes());
      expect(sent, startsWith('C0644 5 hosts\n'));
      expect(sent, contains('hello'));
      // The `\0` that tells the sink the file is over. Without it the far side
      // never closes the file it has been writing.
      expect(sent.codeUnits.last, 0);
      expect(remote.inputClosed, isTrue);
    });

    test('a name that could be read as protocol is neutered', () async {
      final remote = sink();

      // A file whose name contains a newline would end the header line early
      // and leave the rest of it being read as the contents. The field is only
      // used when the destination is a directory, which this never writes to.
      await scpWrite(
        remote,
        '/tmp/two\nlines',
        Stream.value(const <int>[]),
        size: 0,
      );

      expect(utf8.decode(remote.sent.toBytes()), startsWith('C0644 0 two_lines\n'));
    });

    test('a stream longer than it declared is refused, not sent', () async {
      final remote = sink();

      // Sending it would leave the far side reading file contents as protocol,
      // which is a corrupt file rather than a failed transfer.
      await expectLater(
        scpWrite(
          remote,
          '/tmp/x',
          Stream.value(utf8.encode('too much')),
          size: 3,
        ),
        throwsA(isA<ScpException>()),
      );
    });

    test('a stream shorter than it declared is refused too', () async {
      final remote = sink();

      await expectLater(
        scpWrite(
          remote,
          '/tmp/x',
          Stream.value(utf8.encode('ab')),
          size: 10,
        ),
        throwsA(isA<ScpException>()),
      );
    });

    test('a refused destination arrives as the far side worded it', () async {
      final remote = _FakeScp(exit: 1);
      scheduleMicrotask(
        () => remote.complain('scp: /etc/hosts: Permission denied'),
      );

      await expectLater(
        scpWrite(
          remote,
          '/etc/hosts',
          Stream.value(utf8.encode('x')),
          size: 1,
        ),
        throwsA(
          isA<ScpException>().having(
            (e) => e.message,
            'message',
            contains('Permission denied'),
          ),
        ),
      );
    });

    test('a producer that stalls does not hold the transfer open', () async {
      // The timeout used to cover only the half of this that waits on the far
      // side, so a source that opened the channel and then stopped emitting
      // left the write pending forever with a remote `scp -t` holding its
      // staging file.
      final remote = sink();

      await expectLater(
        scpWrite(
          remote,
          '/tmp/x',
          // Never completes, and never emits.
          StreamController<List<int>>().stream,
          size: 4,
          timeout: const Duration(milliseconds: 200),
        ),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('what scp printed on stderr beats a bare exit code', () async {
      final remote = _FakeScp(exit: 1);
      remote.sayOnStderr('sh: scp: not found\n');
      scheduleMicrotask(remote.endOutput);

      await expectLater(
        scpWrite(remote, '/tmp/x', Stream.value(utf8.encode('x')), size: 1),
        throwsA(
          isA<ScpException>().having(
            (e) => e.message,
            'message',
            contains('sh: scp: not found'),
          ),
        ),
      );
    });
  });
}
