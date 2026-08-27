import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';

import 'helpers/spi_fixture.dart';

HostKeyPromptInfo _info({
  String id = 'srv-1',
  String keyType = 'ssh-ed25519',
  // OpenSSH form, which is the only one this carries now.
  String fingerprint = 'SHA256:q7vMq7vMq7vMq7vMq7vMq7vMq7vMq7vMq7vMq7vMq7s',
}) {
  return HostKeyPromptInfo(
    spi: spiFixture(name: 'srv', id: id, ip: '192.0.2.1', user: 'tester'),
    keyType: keyType,
    fingerprint: fingerprint,
    isMismatch: false,
  );
}

/// `promptHostKeyExclusively` is the gate every host key dialog goes through.
///
/// It exists because a server is reached by more than one connection at a time
/// — status polling, a terminal, an SFTP transfer — and each runs its own
/// `onVerifyHostKey`. What it must not become is a cache: the store is what
/// remembers an accepted key, and a user who declined has to be asked again.
void main() {
  test('the same question twice at once raises one dialog', () async {
    var shown = 0;
    final onScreen = Completer<bool>();
    Future<bool> show() {
      shown++;
      return onScreen.future;
    }

    final first = promptHostKeyExclusively(_info(), show);
    final second = promptHostKeyExclusively(_info(), show);
    await pumpEventQueue();

    expect(shown, 1);

    onScreen.complete(true);
    expect(await first, true);
    expect(await second, true);
  });

  test('a different question for the same server waits its turn', () async {
    final shown = <String>[];
    final ed25519 = Completer<bool>();
    final rsa = Completer<bool>();

    final first = promptHostKeyExclusively(_info(), () {
      shown.add('ssh-ed25519');
      return ed25519.future;
    });
    final second = promptHostKeyExclusively(_info(keyType: 'ssh-rsa'), () {
      shown.add('ssh-rsa');
      return rsa.future;
    });
    await pumpEventQueue();

    expect(shown, ['ssh-ed25519']);

    ed25519.complete(true);
    await pumpEventQueue();

    // Asked, but only once the first was off the screen.
    expect(shown, ['ssh-ed25519', 'ssh-rsa']);

    rsa.complete(false);
    expect(await first, true);
    expect(await second, false);
  });

  test(
    'a changed fingerprint is a different question, not the same one',
    () async {
      final shown = <String>[];
      final stale = Completer<bool>();

      final first = promptHostKeyExclusively(_info(), () {
        shown.add('aa:bb:cc');
        return stale.future;
      });
      final second = promptHostKeyExclusively(
        _info(
          fingerprint: 'SHA256:BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB',
        ),
        () {
          shown.add('dd:ee:ff');
          return Future.value(false);
        },
      );
      await pumpEventQueue();

      expect(shown, ['aa:bb:cc']);

      stale.complete(true);
      expect(await first, true);
      expect(await second, false);
      expect(shown, ['aa:bb:cc', 'dd:ee:ff']);
    },
  );

  test('two servers are asked at the same time', () async {
    var shown = 0;
    final onScreen = Completer<bool>();
    Future<bool> show() {
      shown++;
      return onScreen.future;
    }

    final first = promptHostKeyExclusively(_info(), show);
    final second = promptHostKeyExclusively(_info(id: 'srv-2'), show);
    await pumpEventQueue();

    expect(shown, 2);

    onScreen.complete(true);
    await first;
    await second;
  });

  test('the answer is not remembered for the next attempt', () async {
    var shown = 0;
    Future<bool> show() async {
      shown++;
      return false;
    }

    expect(await promptHostKeyExclusively(_info(), show), false);
    expect(await promptHostKeyExclusively(_info(), show), false);

    // Declining once must not silence the question forever: the next
    // connection attempt is a new decision.
    expect(shown, 2);
  });

  test('a dialog that fails frees the server for the next attempt', () async {
    await expectLater(
      promptHostKeyExclusively(
        _info(),
        () => Future<bool>.error(StateError('no navigator')),
      ),
      throwsStateError,
    );

    var shown = 0;
    final accepted = await promptHostKeyExclusively(_info(), () async {
      shown++;
      return true;
    });

    expect(shown, 1);
    expect(accepted, true);
  });
}
