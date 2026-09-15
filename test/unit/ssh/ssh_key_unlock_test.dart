import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/ssh_key_unlock.dart';
import 'package:server_box/core/utils/ssh_keygen.dart';
import 'package:server_box/data/model/app/error.dart';

/// Opening a key that is stored encrypted.
///
/// The prompt is a parameter, so what is exercised here is the policy: when it
/// asks, when it does not ask again, and what a refusal does. None of that is
/// reachable through a dialog in a test, and all of it decides whether a
/// connection happens.
void main() {
  late String lockedPem;
  late String plainPem;
  late PassphrasePrompt prompt;
  const passphrase = 'let me in';

  setUpAll(() {
    lockedPem = generateSshKeyPair([
      SshKeyAlgorithm.ed25519.name,
      'test',
      passphrase,
    ])[0];
    plainPem = generateSshKeyPair([
      SshKeyAlgorithm.ed25519.name,
      'test',
      '',
    ])[0];
  });

  setUp(() {
    PrivateKeyUnlock.forgetAll();
    prompt = ({required keyName, required retry}) async =>
        throw StateError('unexpected passphrase prompt for $keyName');
  });

  tearDown(() {
    PrivateKeyUnlock.forgetAll();
  });

  Future<String> open(
    String pem, {
    required String cacheKey,
    required String keyName,
  }) => PrivateKeyUnlock.open(
    pem,
    cacheKey: cacheKey,
    keyName: keyName,
    prompt: prompt,
  );

  test('a key that needs no passphrase is never asked about', () async {
    var asked = 0;
    prompt = ({required keyName, required retry}) async {
      asked++;
      return passphrase;
    };

    expect(PrivateKeyUnlock.isLocked(plainPem), isFalse);
    expect(
      await open(plainPem, cacheKey: 'k', keyName: 'k'),
      plainPem,
      reason: 'it should come back untouched, not re-encoded',
    );
    expect(asked, 0);
  });

  test('a locked key is asked about once and remembered', () async {
    var asked = 0;
    prompt = ({required keyName, required retry}) async {
      asked++;
      return passphrase;
    };

    expect(PrivateKeyUnlock.isLocked(lockedPem), isTrue);
    final opened = await open(lockedPem, cacheKey: 'k', keyName: 'work laptop');
    expect(PrivateKeyUnlock.isLocked(opened), isFalse);

    await open(lockedPem, cacheKey: 'k', keyName: 'x');
    expect(asked, 1, reason: 'once per key per run, not once per connection');
  });

  test('the key is named when asking', () async {
    String? seen;
    prompt = ({required keyName, required retry}) async {
      seen = keyName;
      return passphrase;
    };
    await open(lockedPem, cacheKey: 'k', keyName: 'work laptop');
    expect(seen, 'work laptop');
  });

  test('two connections at once produce one prompt', () async {
    var asked = 0;
    prompt = ({required keyName, required retry}) async {
      asked++;
      // Long enough that the second caller arrives while this is pending,
      // which is the case being tested — a stack of identical dialogs.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return passphrase;
    };

    final results = await Future.wait([
      open(lockedPem, cacheKey: 'k', keyName: 'k'),
      open(lockedPem, cacheKey: 'k', keyName: 'k'),
    ]);
    expect(asked, 1);
    expect(results[0], results[1]);
  });

  test('a wrong passphrase is asked again, and says so', () async {
    final retries = <bool>[];
    prompt = ({required keyName, required retry}) async {
      retries.add(retry);
      return retries.length == 1 ? 'wrong' : passphrase;
    };

    final opened = await open(lockedPem, cacheKey: 'k', keyName: 'k');
    expect(PrivateKeyUnlock.isLocked(opened), isFalse);
    expect(retries, [false, true], reason: 'the second ask has to say why');
  });

  test('a wrong passphrase every time gives up rather than looping', () async {
    var asked = 0;
    prompt = ({required keyName, required retry}) async {
      asked++;
      return 'wrong';
    };

    await expectLater(
      open(lockedPem, cacheKey: 'k', keyName: 'k'),
      throwsA(isA<SSHErr>()),
    );
    expect(asked, PrivateKeyUnlock.maxAttempts);
  });

  test(
    'declining fails the connection rather than trying without a key',
    () async {
      prompt = ({required keyName, required retry}) async => null;

      await expectLater(
        open(lockedPem, cacheKey: 'k', keyName: 'k'),
        throwsA(isA<SSHErr>()),
      );
    },
  );

  test('forget makes the next connection ask again', () async {
    var asked = 0;
    prompt = ({required keyName, required retry}) async {
      asked++;
      return passphrase;
    };

    await open(lockedPem, cacheKey: 'k', keyName: 'k');
    // What editing or deleting the key does: the passphrase held was for the
    // bytes that were there when it was given.
    PrivateKeyUnlock.forget('k');
    await open(lockedPem, cacheKey: 'k', keyName: 'k');
    expect(asked, 2);
  });

  test('a refusal is remembered, so the poller does not ask again', () async {
    var asked = 0;
    prompt = ({required keyName, required retry}) async {
      asked++;
      return null;
    };

    for (var i = 0; i < 3; i++) {
      await expectLater(
        open(lockedPem, cacheKey: 'k', keyName: 'k'),
        throwsA(isA<SSHErr>()),
      );
    }
    // Reconnects are on a timer. Asking once per poll, per server sharing the
    // key, is a dialog nobody can get out of.
    expect(asked, 1);

    // Editing the key is what offers it again.
    PrivateKeyUnlock.forget('k');
    await expectLater(
      open(lockedPem, cacheKey: 'k', keyName: 'k'),
      throwsA(isA<SSHErr>()),
    );
    expect(asked, 2);
  });

  test('an empty passphrase is not a guess', () async {
    final answers = ['', '', passphrase];
    var asked = 0;
    prompt = ({required keyName, required retry}) async {
      // Never a retry: nothing was guessed yet, so saying "wrong
      // passphrase" would be reporting a failure that did not happen.
      expect(retry, isFalse);
      return answers[asked++];
    };

    final opened = await open(lockedPem, cacheKey: 'k', keyName: 'k');
    expect(PrivateKeyUnlock.isLocked(opened), isFalse);
    expect(asked, 3, reason: 'the two empty answers cost no attempts');
  });

  test('editing a key mid-prompt does not let the old answer land', () async {
    // The dialog is up when the key is replaced. Its answer describes bytes
    // that are no longer stored, and caching it would authenticate every later
    // connection with the key that was just replaced.
    final released = Completer<void>();
    prompt = ({required keyName, required retry}) async {
      await released.future;
      return passphrase;
    };

    final pending = open(lockedPem, cacheKey: 'k', keyName: 'k');
    PrivateKeyUnlock.forget('k');
    released.complete();
    await pending;

    var askedAgain = 0;
    prompt = ({required keyName, required retry}) async {
      askedAgain++;
      return passphrase;
    };
    await open(lockedPem, cacheKey: 'k', keyName: 'k');
    expect(askedAgain, 1, reason: 'the stale answer must not be cached');
  });

  test('remember seeds what the import page already verified', () async {
    var asked = 0;
    prompt = ({required keyName, required retry}) async {
      asked++;
      return passphrase;
    };

    PrivateKeyUnlock.remember('k', plainPem);
    expect(await open(lockedPem, cacheKey: 'k', keyName: 'k'), plainPem);
    expect(asked, 0, reason: 'the passphrase was typed seconds ago');
  });

  test('unreadable input is not locked, so it fails where it is parsed', () {
    // `isLocked` decides whether to put up a dialog. A key that is not a key
    // must not turn into a passphrase prompt.
    expect(PrivateKeyUnlock.isLocked('not a pem at all'), isFalse);
    expect(PrivateKeyUnlock.isLocked(''), isFalse);
  });
}
