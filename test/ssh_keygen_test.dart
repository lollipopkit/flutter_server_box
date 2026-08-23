import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ssh_keygen.dart';

/// Generating a key pair in the app.
///
/// The tests that matter run `ssh-keygen` against what was generated. Every
/// mistake worth making here is invisible to this app on its own: it would
/// write a key, read it back, agree with itself, and hand the server a public
/// key that does not match the private one. `iqmp` is the clearest case — it is
/// q's inverse mod p, the two are interchangeable as far as any round trip
/// through dartssh2 is concerned, and OpenSSH rejects the swapped form.
void main() {
  const passphrase = 'a passphrase with spaces';

  /// The generator's isolate half, called directly: `Computer` is the wrapper,
  /// and a test does not need another isolate to check bytes.
  GeneratedSshKey generate(
    SshKeyAlgorithm algorithm, {
    String comment = 'serverbox',
    String pass = '',
  }) {
    final result = generateSshKeyPair([algorithm.name, comment, pass]);
    return GeneratedSshKey(privatePem: result[0], publicLine: result[1]);
  }

  final sshKeygen = _whichSshKeygen();

  group('interop with ssh-keygen', () {
    for (final algorithm in SshKeyAlgorithm.values) {
      for (final encrypted in [false, true]) {
        final label = encrypted ? 'with a passphrase' : 'unencrypted';
        test('${algorithm.name} $label', () {
          final key = generate(
            algorithm,
            pass: encrypted ? passphrase : '',
          );
          final dir = Directory.systemTemp.createTempSync('sb-keygen-');
          addTearDown(() => dir.deleteSync(recursive: true));
          final file = File('${dir.path}/id')
            ..writeAsStringSync(key.privatePem);
          // ssh-keygen refuses a key the rest of the world can read.
          Process.runSync('chmod', ['600', file.path]);

          final result = Process.runSync(sshKeygen!, [
            '-y',
            '-P',
            encrypted ? passphrase : '',
            '-f',
            file.path,
          ]);
          expect(
            result.exitCode,
            0,
            reason: 'ssh-keygen rejected it: ${result.stderr}',
          );

          // Field by field: `-y` also prints the comment it read out of the
          // private key, so this checks that the comment survived being
          // written — including through encryption, where it is inside the
          // part that gets encrypted.
          final ours = key.publicLine.split(' ');
          final theirs = (result.stdout as String).trim().split(' ');
          expect(theirs[0], ours[0]);
          expect(
            theirs[1],
            ours[1],
            reason: 'the public key ssh-keygen derived is not the one we '
                'would hand a server',
          );
          expect(theirs.skip(2).join(' '), ours.skip(2).join(' '));
        });
      }
    }
  }, skip: sshKeygen == null ? 'ssh-keygen not on PATH' : null);

  group('the private key this app will read back', () {
    test('opens without a passphrase when none was set', () {
      for (final algorithm in SshKeyAlgorithm.values) {
        final key = generate(algorithm);
        expect(SSHKeyPair.isEncryptedPem(key.privatePem), isFalse);
        expect(
          SSHKeyPair.fromPem(key.privatePem),
          hasLength(1),
          reason: algorithm.name,
        );
      }
    });

    test('needs the passphrase when one was set', () {
      final key = generate(SshKeyAlgorithm.ed25519, pass: passphrase);
      expect(SSHKeyPair.isEncryptedPem(key.privatePem), isTrue);
      expect(SSHKeyPair.fromPem(key.privatePem, passphrase), hasLength(1));
      expect(
        () => SSHKeyPair.fromPem(key.privatePem, 'wrong'),
        throwsA(isA<SSHKeyDecryptError>()),
      );
    });
  });

  group('the public key line', () {
    test('is type, key and comment', () {
      final key = generate(SshKeyAlgorithm.ed25519, comment: 'phone');
      final fields = key.publicLine.split(' ');
      expect(fields, hasLength(3));
      expect(fields[0], 'ssh-ed25519');
      expect(fields[2], 'phone');
    });

    test('an empty comment leaves two fields, not a trailing space', () {
      // `authorized_keys` takes everything after the key as the comment, so a
      // trailing space is a comment of one space rather than none.
      final key = generate(SshKeyAlgorithm.ed25519, comment: '   ');
      expect(key.publicLine.split(' '), hasLength(2));
      expect(key.publicLine, isNot(endsWith(' ')));
    });

    test('names the type the key actually is', () {
      for (final algorithm in SshKeyAlgorithm.values) {
        expect(
          generate(algorithm).publicLine.split(' ').first,
          algorithm.keyType,
          reason: '${algorithm.name} announces the wrong type',
        );
      }
    });
  });

  test('two keys of the same kind are different keys', () {
    // A generator seeded from something predictable would pass every other
    // test here.
    final a = generate(SshKeyAlgorithm.ed25519);
    final b = generate(SshKeyAlgorithm.ed25519);
    expect(a.publicLine, isNot(b.publicLine));
    expect(a.privatePem, isNot(b.privatePem));
  });

  test('the same key encrypted twice does not repeat its ciphertext', () {
    // The salt has to be fresh per encryption. Reusing one would be invisible
    // to ssh-keygen and would leak that two files hold the same key.
    final pem = generate(SshKeyAlgorithm.ed25519).privatePem;
    final pair = SSHKeyPair.fromPem(pem).single as OpenSSHKeyPair;
    expect(
      pair.toPem(passphrase: passphrase),
      isNot(pair.toPem(passphrase: passphrase)),
    );
  });

  group('describeSshKey', () {
    test('the fingerprint is the one ssh-keygen prints', () {
      for (final algorithm in SshKeyAlgorithm.values) {
        final key = generate(algorithm, comment: 'phone');
        final dir = Directory.systemTemp.createTempSync('sb-fp-');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File('${dir.path}/id')..writeAsStringSync(key.privatePem);
        Process.runSync('chmod', ['600', file.path]);

        final result = Process.runSync(sshKeygen!, ['-l', '-f', file.path]);
        expect(result.exitCode, 0, reason: '${result.stderr}');
        // `-l` prints `<bits> SHA256:… <comment> (<TYPE>)`.
        final printed = (result.stdout as String).trim().split(' ')[1];
        expect(
          describeSshKey(key.privatePem).fingerprint,
          printed,
          reason: '${algorithm.name}: a fingerprint that does not match what '
              'the server side prints is worse than none',
        );
      }
    }, skip: sshKeygen == null ? 'ssh-keygen not on PATH' : null);

    test('reads the type and comment of an open key', () {
      final key = generate(SshKeyAlgorithm.ed25519, comment: 'phone');
      final digest = describeSshKey(key.privatePem);
      expect(digest.keyType, 'ssh-ed25519');
      expect(digest.comment, 'phone');
      expect(digest.isEmpty, isFalse);
    });

    test('a locked key still has a fingerprint, and no comment', () {
      // The public key sits outside the encrypted blob and the comment does
      // not, so a list can identify a key nobody has unlocked.
      final key = generate(
        SshKeyAlgorithm.ed25519,
        comment: 'phone',
        pass: passphrase,
      );
      final digest = describeSshKey(key.privatePem);
      expect(digest.keyType, 'ssh-ed25519');
      expect(digest.fingerprint, startsWith('SHA256:'));
      expect(digest.comment, isNull);
    });

    test('a locked key fingerprints the same as the open one', () {
      final plain = generate(SshKeyAlgorithm.ed25519, comment: 'phone');
      final pair = SSHKeyPair.fromPem(plain.privatePem).single
          as OpenSSHKeyPair;
      final locked = pair.toPem(passphrase: passphrase);
      expect(
        describeSshKey(locked).fingerprint,
        describeSshKey(plain.privatePem).fingerprint,
      );
    });

    test('an empty comment is absent rather than blank', () {
      final key = generate(SshKeyAlgorithm.ed25519, comment: '  ');
      expect(describeSshKey(key.privatePem).comment, isNull);
    });

    test('anything unreadable says nothing rather than throwing', () {
      // This runs while building a list row.
      for (final input in ['', 'not a pem', '-----BEGIN X-----\nzz\n-----END X-----']) {
        expect(describeSshKey(input).isEmpty, isTrue, reason: input);
      }
    });
  });
}

String? _whichSshKeygen() {
  for (final path in const [
    '/usr/bin/ssh-keygen',
    '/bin/ssh-keygen',
    '/usr/local/bin/ssh-keygen',
  ]) {
    if (File(path).existsSync()) return path;
  }
  final result = Process.runSync(Platform.isWindows ? 'where' : 'which', [
    'ssh-keygen',
  ]);
  if (result.exitCode != 0) return null;
  final found = (result.stdout as String).trim().split('\n').first.trim();
  return found.isEmpty ? null : found;
}
