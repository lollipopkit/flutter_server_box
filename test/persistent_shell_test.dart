import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/ssh/persistent_shell.dart';

void main() {
  test('PersistentShell parses completed output marker', () {
    const raw = 'cpu:10%\nmem:20%\n__SERVER_BOX_DONE__7:0\n';

    final result = PersistentShell.tryParseCompletedOutput(raw);

    expect(result, isNotNull);
    expect(result!.output, 'cpu:10%\nmem:20%');
    expect(result.exitCode, 0);
  });

  test('PersistentShell waits for full completion marker', () {
    const raw = 'cpu:10%\n__SERVER_BOX_DONE__7:';

    final result = PersistentShell.tryParseCompletedOutput(raw);

    expect(result, isNull);
  });

  test('PersistentShell reuses one session across multiple commands', () async {
    final factory = _FakeSessionFactory();
    final shell = PersistentShell(null, sessionFactory: factory.call);

    final firstFuture = shell.run('echo first');
    await Future<void>.delayed(Duration.zero);
    factory.session.stdoutController.add(
      Uint8List.fromList(utf8.encode('first\n__SERVER_BOX_DONE__1:0\n')),
    );
    final first = await firstFuture;

    final secondFuture = shell.run('echo second');
    await Future<void>.delayed(Duration.zero);
    factory.session.stdoutController.add(
      Uint8List.fromList(utf8.encode('second\n__SERVER_BOX_DONE__2:0\n')),
    );
    final second = await secondFuture;

    expect(factory.createCount, 1);
    expect(first.output, 'first');
    expect(second.output, 'second');
    expect(factory.session.writes, hasLength(2));
  });

  test('PersistentShell combines stderr with stdout output', () async {
    final factory = _FakeSessionFactory();
    final shell = PersistentShell(null, sessionFactory: factory.call);

    final future = shell.run('echo mixed');
    await Future<void>.delayed(Duration.zero);
    factory.session.stdoutController.add(
      Uint8List.fromList(utf8.encode('stdout line\n')),
    );
    factory.session.stderrController.add(
      Uint8List.fromList(utf8.encode('stderr line\n')),
    );
    factory.session.stdoutController.add(
      Uint8List.fromList(utf8.encode('__SERVER_BOX_DONE__1:0\n')),
    );

    final result = await future;

    expect(result.output, 'stdout line\nstderr line');
  });

  test('PersistentShell rejects commands after close', () async {
    final shell = PersistentShell(
      null,
      sessionFactory: _FakeSessionFactory().call,
    );

    await shell.close();

    expect(() => shell.run('echo should fail'), throwsA(isA<StateError>()));
  });

  test('PersistentShell fails pending command when session ends', () async {
    final factory = _FakeSessionFactory();
    final shell = PersistentShell(null, sessionFactory: factory.call);

    final future = shell.run('echo hanging');
    final expectation = expectLater(
      future,
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('ended unexpectedly'),
        ),
      ),
    );

    await Future<void>.delayed(Duration.zero);
    await factory.session.stdoutController.close();
    await factory.session.stderrController.close();
    await expectation;
  });
}

final class _FakeSessionFactory {
  int createCount = 0;
  final session = _FakePersistentShellSession();

  Future<PersistentShellSession> call() async {
    createCount += 1;
    return session;
  }
}

final class _FakePersistentShellSession implements PersistentShellSession {
  final stdoutController = StreamController<Uint8List>();
  final stderrController = StreamController<Uint8List>();
  final writes = <String>[];
  bool isClosed = false;

  @override
  StreamSink<Uint8List> get stdin => _FakeSink((data) {
    writes.add(utf8.decode(data));
  });

  @override
  Stream<Uint8List> get stdout => stdoutController.stream;

  @override
  Stream<Uint8List> get stderr => stderrController.stream;

  @override
  void close() {
    isClosed = true;
  }
}

final class _FakeSink implements StreamSink<Uint8List> {
  final void Function(Uint8List data) _onAdd;

  _FakeSink(this._onAdd);

  @override
  void add(Uint8List data) => _onAdd(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Uint8List> stream) async {
    await for (final chunk in stream) {
      add(chunk);
    }
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> get done async {}
}
