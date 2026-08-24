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

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/m004_kv_to_tables.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';

import 'helpers/spi_fixture.dart';
import 'helpers/test_db.dart';

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

  /// The move used to be a scan of every server on every launch. It is part of
  /// `KvToTablesMigration` now, and it had to be: that step remaps the private
  /// key ids, so a `keyId` naming no key becomes a null there — and after that
  /// there is nothing left to recognise as a path.
  group('the key migration', () {
    late ServerStore servers;
    late PrivateKeyStore keys;

    setUp(() async {
      // In memory: this tree writes as it builds, and a test has no
      // business leaving a database behind.
      await openTestDb();
      servers = ServerStore.forTest();
      keys = PrivateKeyStore.forTest();
    });

    tearDown(SqliteDb.close);

    /// One row of the shape m004 reads: the key-value layout m003 leaves.
    void seed(String store, String key, Map<String, Object?> value) {
      SqliteDb.instance.execute(
        'INSERT INTO kv (store, key, value, updated_at) VALUES (?, ?, ?, 0);',
        [store, key, json.encode(value)],
      );
    }

    void seedServer(String id, {String? keyId, String? keyPath}) => seed(
      'server',
      id,
      {
        'id': id,
        'name': 'srv $id',
        'ssh': {
          'ip': '10.0.0.1',
          'port': 22,
          'user': 'root',
          'keyId': ?keyId,
          'keyPath': ?keyPath,
        },
      },
    );

    /// The old shape: the key's id *was* its name.
    void seedKey(String name) => seed('key', name, {'id': name, 'key': 'PEM'});

    Future<void> migrate() => const KvToTablesMigration().apply();

    Spi reread(String id) => servers.fetchOneRaw(id)!;

    test('a path that names no stored key moves to keyPath', () async {
      seedServer('a', keyId: '~/.ssh/id_ed25519');

      await migrate();

      final ssh = reread('a').ssh!;
      expect(ssh.keyPath, '~/.ssh/id_ed25519');
      expect(ssh.keyId, isNull);
    });

    test('a key id that looks like a path is left alone', () async {
      // A key's id was whatever the user typed for its name, so this is a real
      // key and not the import bug — and moving it would break a working server
      seedKey('keys/prod');
      seedServer('b', keyId: 'keys/prod');

      await migrate();

      final ssh = reread('b').ssh!;
      expect(ssh.keyPath, isNull);
      // The id it points at is generated now, and it is the one the key got.
      expect(ssh.keyId, keys.fetchByName('keys/prod')!.id);
    });

    test('an ordinary key id follows the key to its new id', () async {
      seedKey('work');
      seedServer('c', keyId: 'work');

      await migrate();

      final key = keys.fetchByName('work')!;
      expect(key.id, isNot('work'), reason: 'an id is not a name');
      expect(reread('c').ssh!.keyId, key.id);
      expect(reread('c').ssh!.keyPath, isNull);
    });

    test('a keyPath already set is not overwritten', () async {
      seedServer('d', keyPath: '/abs/path/key');

      await migrate();

      expect(reread('d').ssh!.keyPath, '/abs/path/key');
      expect(reread('d').ssh!.keyId, isNull);
    });

    test('a monitor server has no SSH to look at', () async {
      seed('server', 'e', {
        'id': 'e',
        'name': 'monitor only',
        'monitorHttp': {'addr': 'https://10.0.0.9:3770'},
      });

      await migrate();

      expect(reread('e').ssh, isNull);
    });

    test('two keys that shared a name both survive, under one each', () async {
      // Nothing enforced that the name was unique across the two places a key
      // could be created, and it is the primary key of the table now.
      seed('key', 'dup', {'id': 'dup', 'key': 'FIRST'});
      seed('key', 'dup-2', {'id': 'dup', 'key': 'SECOND'});

      await migrate();

      final all = keys.fetch();
      expect(all.length, 2);
      expect(all.map((e) => e.id).toSet().length, 2);
      expect(all.map((e) => e.name).toSet(), {'dup', 'dup (2)'});
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

    // The size check threw inside a `catch (_)` meant for a failed stat, so
    // the file it had just rejected was read into memory on the next line
    test('a file past the size cap is refused, not read anyway', () {
      final file = File('${tempDir.path}/huge')
        ..writeAsStringSync('x' * (1024 * 1024 + 1));

      final ssh = SshCredential(ip: 'a', keyPath: file.path);
      expect(
        () => resolvePrivateKey(ssh),
        throwsA(
          predicate(
            (e) => e.toString().contains('${tempDir.path}/huge'),
            'names the file it refused',
          ),
        ),
      );
    });

    test('and the async loader refuses it too', () async {
      final file = File('${tempDir.path}/huge')
        ..writeAsStringSync('x' * (1024 * 1024 + 1));

      final ssh = SshCredential(ip: 'a', keyPath: file.path);
      await expectLater(
        resolvePrivateKeyAsync(ssh),
        throwsA(
          predicate(
            (e) => e.toString().contains('${tempDir.path}/huge'),
            'names the file it refused',
          ),
        ),
      );
    });
  });

  group('genClient', () {
    test('a key it cannot read does not leave the socket open', () async {
      // The socket is opened before the key is resolved, and a caller that
      // gets a key error gets no handle to close it with. A status poll
      // retries, so this used to leak one connection per attempt.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);

      final closed = Completer<void>();
      server.listen((socket) {
        socket.listen(
          (_) {},
          onDone: () {
            if (!closed.isCompleted) closed.complete();
          },
          onError: (_) {
            if (!closed.isCompleted) closed.complete();
          },
          cancelOnError: true,
        );
      });

      final spi = spiFixture(
        name: 'unreadable key',
        id: 'leak-test',
        ip: server.address.address,
        port: server.port,
        keyPath: '/definitely/not/here/id_ed25519',
      );

      await expectLater(genClient(spi), throwsA(isA<SSHErr>()));

      // Nothing was ever sent, so the far end learns of it by the close alone
      await expectLater(
        closed.future.timeout(const Duration(seconds: 5)),
        completes,
      );
    });
  });
}
