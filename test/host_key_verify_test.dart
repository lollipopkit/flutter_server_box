import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';

import 'helpers/spi_fixture.dart';

/// What happens to the store when the user says no.
///
/// Accepting a host key had been exercised; refusing one never had, and the
/// reason was that everything around this needs a socket and a server that has
/// changed its key. The decision itself needs neither — it is a function of
/// what is already known, what was offered, and what the user answered — so
/// this is that table, every cell of it.
///
/// The cell that matters is the mismatch that was refused: the key already on
/// file has to still be there afterwards. Overwriting it would turn one
/// refusal into permanent trust of whatever answered next time, which is the
/// attack this dialog exists to stop.
void main() {
  /// A fingerprint's bytes. The verifier formats them itself, so what a test
  /// hands in only has to be distinct.
  Uint8List key(int seed) => Uint8List.fromList([seed, seed + 1, seed + 2]);

  /// The hex the verifier makes of [key], which is what lands in the store.
  String hexOf(int seed) =>
      [seed, seed + 1, seed + 2].map((b) => b.toRadixString(16).padLeft(2, '0')).join(':');

  /// A verifier over [cache], answering every prompt with [answer].
  ///
  /// [asked] collects what the user was shown, because "was the user asked at
  /// all" is half of what is under test — a host already known must connect
  /// without a dialog, or every reconnect interrupts.
  ({HostKeyVerifier verifier, List<HostKeyPromptInfo> asked, List<String> wrote})
  build(Map<String, String> cache, {required bool answer}) {
    final asked = <HostKeyPromptInfo>[];
    final wrote = <String>[];
    return (
      verifier: HostKeyVerifier(
        spi: spiFixture(name: 'srv', id: 'srv-1', ip: '192.0.2.1', user: 'u'),
        cache: cache,
        prompt: (info) async {
          asked.add(info);
          return answer;
        },
        persistCallback: (storageKey, hex) => wrote.add('$storageKey=$hex'),
      ),
      asked: asked,
      wrote: wrote,
    );
  }

  group('a host nobody has seen', () {
    test('is trusted once the user says so, and written down', () async {
      final cache = <String, String>{};
      final t = build(cache, answer: true);

      expect(await t.verifier.call('ssh-ed25519', key(1)), isTrue);

      expect(t.asked.single.isMismatch, isFalse);
      expect(t.wrote, ['srv-1::ssh-ed25519=${hexOf(1)}']);
      expect(cache['srv-1::ssh-ed25519'], hexOf(1));
    });

    test('is refused, and nothing is written down', () async {
      final cache = <String, String>{};
      final t = build(cache, answer: false);

      expect(await t.verifier.call('ssh-ed25519', key(1)), isFalse);

      expect(t.asked, hasLength(1));
      expect(t.wrote, isEmpty, reason: 'a refusal is not a decision to store');
      expect(cache, isEmpty);
    });
  });

  group('a host already on file', () {
    test('offering the same key is not asked about again', () async {
      final cache = {'srv-1::ssh-ed25519': hexOf(1)};
      final t = build(cache, answer: false);

      expect(await t.verifier.call('ssh-ed25519', key(1)), isTrue);

      expect(
        t.asked,
        isEmpty,
        reason: 'the answer would have been no — reaching the prompt at all '
            'means every reconnect asks again',
      );
      expect(t.wrote, isEmpty);
    });

    test('offering a different one is asked about as a mismatch', () async {
      final cache = {'srv-1::ssh-ed25519': hexOf(1)};
      final t = build(cache, answer: true);

      expect(await t.verifier.call('ssh-ed25519', key(9)), isTrue);

      final info = t.asked.single;
      expect(info.isMismatch, isTrue);
      expect(
        info.previousFingerprintHex,
        hexOf(1),
        reason: 'the dialog has to show what it is replacing, or the user is '
            'agreeing to nothing in particular',
      );
      expect(cache['srv-1::ssh-ed25519'], hexOf(9));
      expect(t.wrote, ['srv-1::ssh-ed25519=${hexOf(9)}']);
    });

    test('and refusing it leaves the key that was there', () async {
      final cache = {'srv-1::ssh-ed25519': hexOf(1)};
      final t = build(cache, answer: false);

      expect(await t.verifier.call('ssh-ed25519', key(9)), isFalse);

      expect(
        cache['srv-1::ssh-ed25519'],
        hexOf(1),
        reason: 'replacing it here would trust whatever answered next time, '
            'which is what the user just refused',
      );
      expect(t.wrote, isEmpty);
    });
  });

  test('key types are filed apart, so one does not vouch for another', () async {
    // A server offers whichever type the client negotiated. Filed under one
    // key, an accepted ed25519 would silently vouch for an RSA key nobody has
    // seen — and the mismatch branch above would never run.
    final cache = {'srv-1::ssh-ed25519': hexOf(1)};
    final t = build(cache, answer: true);

    expect(await t.verifier.call('ssh-rsa', key(5)), isTrue);

    expect(t.asked.single.isMismatch, isFalse);
    expect(cache, {
      'srv-1::ssh-ed25519': hexOf(1),
      'srv-1::ssh-rsa': hexOf(5),
    });
  });
}
