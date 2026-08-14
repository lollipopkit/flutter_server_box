import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';

void main() {
  const known = {
    'abc::ssh-ed25519': 'aa:bb',
    'abc::ssh-rsa': 'cc:dd',
    'abcdef::ssh-ed25519': 'ee:ff',
    'other::ssh-ed25519': '11:22',
  };

  test('takes every key type a host offered', () {
    // One connection can accept more than one, and leaving either behind means
    // the entry is still there for an id nothing will look up.
    expect(withoutHostKeysFor(known, 'abc'), {
      'abcdef::ssh-ed25519': 'ee:ff',
      'other::ssh-ed25519': '11:22',
    });
  });

  test('an id that merely starts the same is left alone', () {
    // The separator is the whole of the correctness: matching on the id alone
    // would take `abcdef`'s key along with `abc`'s.
    expect(withoutHostKeysFor(known, 'abcdef').keys, containsAll(<String>[
      'abc::ssh-ed25519',
      'abc::ssh-rsa',
      'other::ssh-ed25519',
    ]));
    expect(withoutHostKeysFor(known, 'abcdef'), isNot(contains('abcdef::ssh-ed25519')));
  });

  test('an id with nothing filed under it changes nothing', () {
    expect(withoutHostKeysFor(known, 'missing'), known);
  });

  test('an empty id takes nothing, rather than everything', () {
    // `''` would produce the prefix `::`, which matches nothing here — but an
    // id is never empty in practice and wiping the store on one would be the
    // worst possible reading of it.
    expect(withoutHostKeysFor(known, ''), known);
  });
}
