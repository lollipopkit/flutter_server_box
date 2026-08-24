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

  group('grouping them for the settings page', () {
    test('a server with several types keeps them together, sorted', () {
      final grouped = groupHostKeysByServer(known);

      expect(grouped['abc']!.map((k) => k.keyType), ['ssh-ed25519', 'ssh-rsa']);
      expect(grouped['abc']!.first.fingerprint, 'aa:bb');
    });

    test('an id that merely starts the same is its own server', () {
      // The same distinction `withoutHostKeysFor` exists for, from the other
      // side: a list that folded `abcdef` into `abc` would offer to forget a
      // key belonging to a different host.
      final grouped = groupHostKeysByServer(known);

      expect(grouped.keys, containsAll(['abc', 'abcdef', 'other']));
      expect(grouped['abcdef'], hasLength(1));
    });

    test('the split is on the last separator, not the first', () {
      // A key type is an SSH algorithm name and carries no `::`, while an id
      // restored from a backup is whatever that file said — so the id is
      // everything before the last one. Taking the first read this as server
      // `a` with the type `b::ssh-rsa`, which is a server it does not belong
      // to and a type that is not one.
      final grouped = groupHostKeysByServer({'a::b::ssh-rsa': 'ff'});

      expect(grouped.keys, ['a::b']);
      expect(grouped['a::b']!.single.keyType, 'ssh-rsa');
    });

    test('and forgetting one id does not reach into another that extends it',
        () {
      // The same mistake from the other side: `startsWith('a::')` is true of
      // `a::b::ssh-rsa`, so forgetting server `a` took the distinct server
      // `a::b`'s key with it.
      const nested = {'a::ssh-rsa': 'aa', 'a::b::ssh-rsa': 'bb'};

      expect(withoutHostKeysFor(nested, 'a'), {'a::b::ssh-rsa': 'bb'});
      expect(withoutHostKeysFor(nested, 'a::b'), {'a::ssh-rsa': 'aa'});
    });

    test('an entry with no separator is kept, not dropped', () {
      // Unreadable rather than absent. Something this app trusts and cannot
      // show is worse than something it shows under a strange name.
      final grouped = groupHostKeysByServer({'malformed': 'ff'});

      expect(grouped['malformed']!.single.keyType, '');
      expect(grouped['malformed']!.single.storageKey, 'malformed');
    });

    test('nothing known groups to nothing', () {
      expect(groupHostKeysByServer(const {}), isEmpty);
    });
  });
}
