import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';

void main() {
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
          Snippet(name: 'n', script: script).needsServer,
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
          Snippet(name: 'n', script: script).needsServer,
          isFalse,
          reason: script,
        );
      }
    });
  });

  group('formatting', () {
    test('a server answers its own placeholders', () {
      const snippet = Snippet(name: 'n', script: r'ssh ${user}@${host} -p ${port}');
      expect(snippet.fmtWithSpi(spi), 'ssh lk@10.0.0.1 -p 2222');
    });

    test('with no server the script is left as it was written', () {
      // Reached only for a script that names no server, so there is nothing
      // here to substitute. Substituting an empty string would have turned
      // `ssh ${user}@${host}` into `ssh @`, which is a different command
      // rather than a refusal — hence [Snippet.needsServer] filtering first.
      const snippet = Snippet(name: 'n', script: 'df -h');
      expect(snippet.fmtWithSpi(null), 'df -h');
    });
  });
}
