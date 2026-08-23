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
    PrivateKeyUnlock.promptOverrideForTesting = null;
  });

  tearDown(() {
    PrivateKeyUnlock.forgetAll();
    PrivateKeyUnlock.promptOverrideForTesting = null;
  });

  test('a key that needs no passphrase is never asked about', () async {
    var asked = 0;
    PrivateKeyUnlock.promptOverrideForTesting = ({required keyName, required retry}) async {
      asked++;
      return passphrase;
    };

    expect(PrivateKeyUnlock.isLocked(plainPem), isFalse);
    expect(
      await PrivateKeyUnlock.open(plainPem, cacheKey: 'k', keyName: 'k'),
      plainPem,
      reason: 'it should come back untouched, not re-encoded',
    );
    expect(asked, 0);
  });

  test('a locked key is asked about once and remembered', () async {
    var asked = 0;
    PrivateKeyUnlock.promptOverrideForTesting = ({required keyName, required retry}) async {
      asked++;
      return passphrase;
    };

    expect(PrivateKeyUnlock.isLocked(lockedPem), isTrue);
    final opened = await PrivateKeyUnlock.open(
      lockedPem,
      cacheKey: 'k',
      keyName: 'work laptop',
    );
    expect(PrivateKeyUnlock.isLocked(opened), isFalse);

    await PrivateKeyUnlock.open(lockedPem, cacheKey: 'k', keyName: 'x');
    expect(asked, 1, reason: 'once per key per run, not once per connection');
  });

  test('the key is named when asking', () async {
    String? seen;
    PrivateKeyUnlock.promptOverrideForTesting = ({required keyName, required retry}) async {
      seen = keyName;
      return passphrase;
    };
    await PrivateKeyUnlock.open(
      lockedPem,
      cacheKey: 'k',
      keyName: 'work laptop',
    );
    expect(seen, 'work laptop');
  });

  test('two connections at once produce one prompt', () async {
    var asked = 0;
    PrivateKeyUnlock.promptOverrideForTesting = ({required keyName, required retry}) async {
      asked++;
      // Long enough that the second caller arrives while this is pending,
      // which is the case being tested — a stack of identical dialogs.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return passphrase;
    };

    final results = await Future.wait([
      PrivateKeyUnlock.open(lockedPem, cacheKey: 'k', keyName: 'k'),
      PrivateKeyUnlock.open(lockedPem, cacheKey: 'k', keyName: 'k'),
    ]);
    expect(asked, 1);
    expect(results[0], results[1]);
  });

  test('a wrong passphrase is asked again, and says so', () async {
    final retries = <bool>[];
    PrivateKeyUnlock.promptOverrideForTesting = ({required keyName, required retry}) async {
      retries.add(retry);
      return retries.length == 1 ? 'wrong' : passphrase;
    };

    final opened = await PrivateKeyUnlock.open(
      lockedPem,
      cacheKey: 'k',
      keyName: 'k',
    );
    expect(PrivateKeyUnlock.isLocked(opened), isFalse);
    expect(retries, [false, true], reason: 'the second ask has to say why');
  });

  test('a wrong passphrase every time gives up rather than looping', () async {
    var asked = 0;
    PrivateKeyUnlock.promptOverrideForTesting = ({required keyName, required retry}) async {
      asked++;
      return 'wrong';
    };

    await expectLater(
      PrivateKeyUnlock.open(lockedPem, cacheKey: 'k', keyName: 'k'),
      throwsA(isA<SSHErr>()),
    );
    expect(asked, PrivateKeyUnlock.maxAttempts);
    expect(PrivateKeyUnlock.isOpened('k'), isFalse);
  });

  test('declining fails the connection rather than trying without a key',
      () async {
    PrivateKeyUnlock.promptOverrideForTesting = ({required keyName, required retry}) async => null;

    await expectLater(
      PrivateKeyUnlock.open(lockedPem, cacheKey: 'k', keyName: 'k'),
      throwsA(isA<SSHErr>()),
    );
    expect(PrivateKeyUnlock.isOpened('k'), isFalse);
  });

  group('openedOrNull', () {
    test('answers null for a locked key nobody has opened', () {
      // What the transfer path reads: it cannot ask, so it has to be able to
      // tell "not opened" from "needs no opening".
      expect(
        PrivateKeyUnlock.openedOrNull(lockedPem, cacheKey: 'k'),
        isNull,
      );
      expect(
        PrivateKeyUnlock.openedOrNull(plainPem, cacheKey: 'k'),
        plainPem,
      );
    });

    test('answers the opened key once it has been opened', () async {
      PrivateKeyUnlock.promptOverrideForTesting =
          ({required keyName, required retry}) async => passphrase;
      final opened = await PrivateKeyUnlock.open(
        lockedPem,
        cacheKey: 'k',
        keyName: 'k',
      );
      expect(PrivateKeyUnlock.openedOrNull(lockedPem, cacheKey: 'k'), opened);
    });
  });

  test('forget makes the next connection ask again', () async {
    var asked = 0;
    PrivateKeyUnlock.promptOverrideForTesting = ({required keyName, required retry}) async {
      asked++;
      return passphrase;
    };

    await PrivateKeyUnlock.open(lockedPem, cacheKey: 'k', keyName: 'k');
    // What editing or deleting the key does: the passphrase held was for the
    // bytes that were there when it was given.
    PrivateKeyUnlock.forget('k');
    await PrivateKeyUnlock.open(lockedPem, cacheKey: 'k', keyName: 'k');
    expect(asked, 2);
  });

  test('unreadable input is not locked, so it fails where it is parsed', () {
    // `isLocked` decides whether to put up a dialog. A key that is not a key
    // must not turn into a passphrase prompt.
    expect(PrivateKeyUnlock.isLocked('not a pem at all'), isFalse);
    expect(PrivateKeyUnlock.isLocked(''), isFalse);
  });
}
