/// `PveTermShellBackend` over a fake console: the terminal's bytes and sizes
/// reach it in order, its output reaches the shell, and its ending — from
/// either side — is told apart. termproxy's own protocol is
/// `sbm_virt::pve::console`'s, tested there and end to end in
/// `pve_console_test.dart`.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/pve_termproxy.dart';
import 'package:server_box/data/model/app/error.dart';

import '../../helpers/fake_pve_console.dart';

void main() {
  late FakePveConsole console;

  setUp(() => console = FakePveConsole());

  test('output reaches the shell; input and sizes the console, in order', () async {
    console.output(utf8.encode('welcome\r\n'));
    final backend = PveTermShellBackend(console);
    addTearDown(backend.close);
    expect(backend.supportsExec, isFalse);

    final shell = await backend.openShell(width: 80, height: 24);
    final out = StringBuffer();
    final sub = shell.stdout!.listen((b) => out.write(utf8.decode(b)));
    addTearDown(sub.cancel);

    // A send takes a hop and a resize does not: queued, they still arrive
    // in the order they were made.
    shell.write(utf8.encode('uptime\r'));
    shell.resizeTerminal(100, 30);
    shell.resizeTerminal(0, 30);
    await console.next((c) => c == 'resize:100x30');
    expect(console.calls, ['resize:80x24', 'send:uptime\r', 'resize:100x30']);

    console.output(utf8.encode(' 12:00 up'));
    await pumpUntil(() => out.toString().contains('up'));
    expect(out.toString(), 'welcome\r\n 12:00 up');

    await expectLater(
      backend.openShell(width: 1, height: 1),
      throwsStateError,
      reason: 'one ticket, one shell',
    );
  });

  test('output before the shell is bound is held for it', () async {
    console
      ..output(utf8.encode('login: '))
      ..output(utf8.encode('again'));
    final backend = PveTermShellBackend(console);
    addTearDown(backend.close);
    await pumpUntil(() => console.reads >= 3);
    final shell = await backend.openShell(width: 80, height: 24);
    expect(
      await shell.stdout!.map(utf8.decode).take(2).toList(),
      ['login: ', 'again'],
    );
  });

  test('the console ending ends the shell and the backend', () async {
    final backend = PveTermShellBackend(console);
    final shell = await backend.openShell(width: 80, height: 24);
    unawaited(shell.stdout!.drain<void>());
    expect(backend.isClosed, isFalse);
    await backend.ping();

    console.end();
    await shell.done.timeout(const Duration(seconds: 5));
    expect(backend.isClosed, isTrue);
    await expectLater(backend.ping(), throwsStateError);
    await expectLater(
      backend.openShell(width: 1, height: 1),
      throwsA(isA<StateError>()),
    );
  });

  test('a failed write is the console gone', () async {
    final backend = PveTermShellBackend(console);
    final shell = await backend.openShell(width: 80, height: 24);
    console.failSends = true;
    shell.write(const [1]);
    await shell.done.timeout(const Duration(seconds: 5));
    expect(backend.isClosed, isTrue);
  });

  test('a console that ended before the shell is unreachable', () async {
    console.end();
    final backend = PveTermShellBackend(console);
    await pumpUntil(() => console.reads >= 1);
    await Future<void>.delayed(Duration.zero);
    await expectLater(
      backend.openShell(width: 80, height: 24),
      throwsA(
        isA<VirtErr>().having((e) => e.type, 'type', VirtErrType.unreachable),
      ),
    );
  });

  test('closing the shell here hangs up, and is not a lost link', () async {
    final backend = PveTermShellBackend(console);
    final shell = await backend.openShell(width: 80, height: 24);
    shell.close();
    await shell.done.timeout(const Duration(seconds: 5));
    expect(console.closed, isTrue);
    // The terminal page reconnects a closed backend; a disconnect the user
    // asked for must not be answered with a new console.
    expect(backend.isClosed, isFalse);
    backend.close();
    expect(backend.isClosed, isTrue);
  });
}

Future<void> pumpUntil(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
