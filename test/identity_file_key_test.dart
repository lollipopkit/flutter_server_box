/// `keyId` used to mean two things, and one of them could never work.
///
/// `~/.ssh/config` import wrote an `IdentityFile` path into it while every
/// reader looked it up as a `Stores.key` id, so an imported server with a key
/// could only ever fail to connect — and its edit page showed no key at all,
/// because the picker matches stored ids. The path now has `keyPath`.
///
/// Two halves are worth locking down: records written before the fix have to
/// move, and the move has to be decided against the store rather than by the
/// shape of the string, because a key's id is its user-typed name and one may
/// legitimately look like a path.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/private_key_info.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SshCredential', () {
    test('keyRef names whichever key is set, and tells them apart', () {
      const stored = SshCredential(ip: 'a', keyId: 'work');
      const onDisk = SshCredential(ip: 'a', keyPath: '~/.ssh/id_ed25519');
      const neither = SshCredential(ip: 'a');

      expect(stored.keyRef, 'id:work');
      expect(onDisk.keyRef, 'path:~/.ssh/id_ed25519');
      expect(neither.keyRef, isNull);
    });

    test('keyPath survives a round trip and is absent when unset', () {
      const withPath = SshCredential(ip: 'a', keyPath: '/home/me/.ssh/k');
      expect(
        SshCredential.fromJson(withPath.toJson()).keyPath,
        '/home/me/.ssh/k',
      );

      const withoutPath = SshCredential(ip: 'a', keyId: 'work');
      expect(withoutPath.toJson().containsKey('keyPath'), isFalse);
    });

    test('a key id shaped like a path reference cannot collide with one', () {
      // A key's id is its user-typed name, so somebody can call one exactly
      // what a path reference looks like. Both sides are prefixed for this.
      const named = SshCredential(ip: 'a', keyId: 'path:/home/me/id_ed25519');
      const file = SshCredential(ip: 'a', keyPath: '/home/me/id_ed25519');
      expect(named.keyRef, isNot(file.keyRef));
    });

    test('changing the key file needs a reconnect', () {
      const a = SshCredential(ip: 'a', keyPath: '/k/one');
      const b = SshCredential(ip: 'a', keyPath: '/k/two');
      expect(a.isSameAs(b), isFalse);
    });
  });

  group('migrateIdentityFilePaths', () {
    late Directory tempDir;
    late Box<dynamic> serverBox;
    late Box<dynamic> keyBox;
    late ServerStore servers;
    late PrivateKeyStore keys;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('identity-file-');
      Hive.init(tempDir.path);
      // In memory: a real write started in a test body completes on a callback
      // the fake-async zone is no longer pumping, and `close()` then blocks
      serverBox = await Hive.openBox<dynamic>('server_test', bytes: Uint8List(0));
      keyBox = await Hive.openBox<dynamic>('key_test', bytes: Uint8List(0));
      servers = ServerStore.forBox(serverBox);
      keys = PrivateKeyStore.forBox(keyBox);
    });

    tearDown(() async {
      await serverBox.close();
      await keyBox.close();
      await tempDir.delete(recursive: true);
    });

    Spi reread(String id) => servers.get<Spi>(id)!;

    test('a path that names no stored key moves to keyPath', () {
      servers.put(
        const Spi(
          id: 'a',
          name: 'imported',
          ssh: SshCredential(ip: '10.0.0.1', keyId: '~/.ssh/id_ed25519'),
        ),
      );

      servers.migrateIdentityFilePaths(keys: keys);

      final ssh = reread('a').ssh!;
      expect(ssh.keyPath, '~/.ssh/id_ed25519');
      expect(ssh.keyId, isNull);
    });

    test('a key id that looks like a path is left alone', () {
      // A key's id is whatever the user typed for its name, so this is a real
      // key and not the import bug — and moving it would break a working server
      keys.put(const PrivateKeyInfo(id: 'keys/prod', key: 'PEM'));
      servers.put(
        const Spi(
          id: 'b',
          name: 'named oddly',
          ssh: SshCredential(ip: '10.0.0.2', keyId: 'keys/prod'),
        ),
      );

      servers.migrateIdentityFilePaths(keys: keys);

      final ssh = reread('b').ssh!;
      expect(ssh.keyId, 'keys/prod');
      expect(ssh.keyPath, isNull);
    });

    test('an ordinary key id is untouched', () {
      keys.put(const PrivateKeyInfo(id: 'work', key: 'PEM'));
      servers.put(
        const Spi(
          id: 'c',
          name: 'normal',
          ssh: SshCredential(ip: '10.0.0.3', keyId: 'work'),
        ),
      );

      servers.migrateIdentityFilePaths(keys: keys);

      expect(reread('c').ssh!.keyId, 'work');
      expect(reread('c').ssh!.keyPath, isNull);
    });

    test('running it twice changes nothing further', () {
      servers.put(
        const Spi(
          id: 'd',
          name: 'imported',
          ssh: SshCredential(ip: '10.0.0.4', keyId: '/abs/path/key'),
        ),
      );

      servers.migrateIdentityFilePaths(keys: keys);
      final once = reread('d');
      servers.migrateIdentityFilePaths(keys: keys);

      expect(reread('d'), once);
    });

    test('a server with no SSH at all is skipped', () {
      servers.put(const Spi(id: 'e', name: 'monitor only'));
      servers.migrateIdentityFilePaths(keys: keys);
      expect(reread('e').ssh, isNull);
    });
  });

  group('resolvePrivateKey', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('resolve-key-');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('reads the file a keyPath names', () {
      final file = File('${tempDir.path}/id_ed25519')
        ..writeAsStringSync('-----BEGIN OPENSSH PRIVATE KEY-----\n');

      final ssh = SshCredential(ip: 'a', keyPath: file.path);
      expect(
        resolvePrivateKey(ssh),
        startsWith('-----BEGIN OPENSSH PRIVATE KEY-----'),
      );
    });

    test('a missing file fails naming it, not as a missing key id', () {
      final ssh = SshCredential(ip: 'a', keyPath: '${tempDir.path}/absent');

      // The old failure was `privateKeyNotFoundFmt` with a path in it, which
      // reads as "no such key" and sends the user looking in the wrong place
      expect(
        () => resolvePrivateKey(ssh),
        throwsA(
          predicate(
            (e) => e.toString().contains('${tempDir.path}/absent'),
            'names the file it could not read',
          ),
        ),
      );
    });

    test('no key configured is not an error', () {
      expect(resolvePrivateKey(const SshCredential(ip: 'a')), isNull);
    });
  });
}
