import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:xterm/xterm.dart';

void main() {
  group('typing', _stopsWhenReplaced);

  final spi = Spi(
    name: 'box',
    id: 'box-1',
    ssh: const SshCredential(ip: '10.0.0.1', user: 'lk', port: 2222),
  );

  group('which snippets a terminal on this device can run', () {
    test('one that names a server cannot run without one', () {
      for (final script in [
        r'ssh ${user}@${host}',
        r'echo ${port}',
        r'curl http://${host}:8080',
        r'echo ${name} ${id}',
        r'sshpass -p ${pwd} true',
      ]) {
        expect(
          Snippet(id: 'n', name: 'n', script: script).needsServer,
          isTrue,
          reason: script,
        );
      }
    });

    test('one that names none can', () {
      for (final script in [
        'df -h',
        r'echo $HOME',
        // A shell variable of the app's own spelling is still the shell's.
        r'for f in *; do echo "$f"; done',
        // Terminal keys are the terminal's, not a server's.
        r'${ctrl+c}',
      ]) {
        expect(
          Snippet(id: 'n', name: 'n', script: script).needsServer,
          isFalse,
          reason: script,
        );
      }
    });
  });

  group('formatting', () {
    test('a server answers its own placeholders', () {
      const snippet = Snippet(id: 'n', name: 'n', script: r'ssh ${user}@${host} -p ${port}');
      expect(snippet.fmtWithSpi(spi), 'ssh lk@10.0.0.1 -p 2222');
    });

    test('with no server the script is left as it was written', () {
      // Reached only for a script that names no server, so there is nothing
      // here to substitute. Substituting an empty string would have turned
      // `ssh ${user}@${host}` into `ssh @`, which is a different command
      // rather than a refusal — hence [Snippet.needsServer] filtering first.
      const snippet = Snippet(id: 'n', name: 'n', script: 'df -h');
      expect(snippet.fmtWithSpi(null), 'df -h');
    });
  });
}

/// A snippet that waits stops typing once the shell it began in has gone.
void _stopsWhenReplaced() {
  test('after a wait, nothing more once the shell is not the one', () {
    fakeAsync((async) {
      final typed = StringBuffer();
      final terminal = Terminal()..onOutput = typed.write;
      var alive = true;
      unawaited(
        const Snippet(
          id: 's',
          name: 's',
          script: r'first ${sleep 1} second',
        ).runInTerm(terminal, null, alive: () => alive),
      );
      async.flushMicrotasks();
      expect(typed.toString(), contains('first'));
      alive = false;
      async.elapse(const Duration(seconds: 2));
      expect(typed.toString(), isNot(contains('second')));
    });
  });

  test('and all of it while it is', () {
    fakeAsync((async) {
      final typed = StringBuffer();
      final terminal = Terminal()..onOutput = typed.write;
      unawaited(
        const Snippet(
          id: 's',
          name: 's',
          script: r'first ${sleep 1} second',
        ).runInTerm(terminal, null, alive: () => true),
      );
      async.elapse(const Duration(seconds: 2));
      expect(typed.toString(), contains('second'));
    });
  });
}
