/// Compressing a backup before encrypting it.
///
/// The reader has to keep accepting three shapes, and the ones that are not
/// what this build writes are the ones worth holding: an uncompressed
/// encrypted backup from every release before this, and a plaintext one from
/// before encryption was required. Neither carries a flag saying so — gzip's
/// own header is what tells them apart — so a reader that got the sniff wrong
/// would fail on exactly the files a user upgrading has.
library;

import 'dart:convert';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

BackupV2 _emptyBackup() => const BackupV2(
  version: BackupV2.formatVer,
  date: 123,
  spis: {},
  snippets: {},
  keys: {},
  container: {},
  history: {},
  settings: {},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('sbm-backup-gzip-');
    Paths.doc = tempDir.path;
    SharedPreferences.setMockInitialValues({});
    await PrefStore.shared.init();
  });

  tearDownAll(() async => tempDir.delete(recursive: true));

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({
      SecureStoreProps.bakPwd.key: 'remote-password',
    });
    SqliteDb.openInMemory();
    await Stores.init();
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  group('reading', () {
    test('what this build writes reads back', () async {
      for (var i = 0; i < 20; i++) {
        Stores.server.put(
          Spi(
            id: 'srv$i',
            name: 'server $i',
            ssh: SshCredential(ip: '10.0.0.$i', user: 'root', pwd: 'pw$i'),
          ),
        );
      }

      final path = await bakSync.writeEncryptedBackup(name: 'gz.json');
      final content = await File(path).readAsString();

      expect(Cryptor.isEncrypted(content), isTrue);
      final back = BackupV2.fromJsonString(content, 'remote-password');
      expect(back.spis.keys, contains('srv7'));
    });

    /// Every release before this one wrote the plaintext JSON straight into
    /// the envelope. Those files are what a user upgrading already has on
    /// their remote, and the first thing this build does is read one.
    test('an uncompressed encrypted backup still reads', () {
      final plain = _emptyBackup().toJsonString();
      final legacy = Cryptor.encrypt(plain, 'remote-password');

      final back = BackupV2.fromJsonString(legacy, 'remote-password');
      expect(back.version, BackupV2.formatVer);
      expect(back.date, 123);
    });

    test('a plaintext backup still reads', () {
      final plain = _emptyBackup().toJsonString();
      expect(BackupV2.fromJsonString(plain).date, 123);
    });

    /// The sniff has to be exact rather than a guess, and it is: JSON always
    /// opens with `{` and gzip always with 0x1f 0x8b, so no input is both.
    test('the two shapes cannot be confused', () {
      final plain = utf8.encode(_emptyBackup().toJsonString());
      expect(plain[0], 0x7b);
      expect(gzip.encode(plain).take(2), [0x1f, 0x8b]);
    });
  });

  group('size', () {
    test('compressing is what makes the payload smaller, not base64', () async {
      for (var i = 0; i < 60; i++) {
        Stores.server.put(
          Spi(
            id: 'srv$i',
            name: 'server number $i',
            ssh: SshCredential(ip: '10.0.0.$i', user: 'root', pwd: 'pw$i'),
          ),
        );
      }

      final plainLen = (await BackupV2.loadFromStore()).toJsonString().length;
      final path = await bakSync.writeEncryptedBackup(name: 'size.json');
      final wireLen = (await File(path).readAsString()).length;

      // Before this change the wire form was base64 of the raw JSON, which is
      // 4/3 of it and always larger. Asserting against that number rather than
      // a fixed ratio is what makes this a regression test: if compression
      // stops happening, the payload goes back above the plaintext length.
      expect(
        wireLen,
        lessThan(plainLen),
        reason: 'wire $wireLen vs plaintext $plainLen',
      );
      // This shape — one record repeated with every key name spelled out —
      // compresses well past 2x even at these sizes.
      expect(wireLen * 2, lessThan(plainLen));
    });
  });

  group('bounds', () {
    test('a bomb is refused as it decompresses, not after', () {
      // 8 MiB of zeroes in a few KiB of gzip. The cap is checked as the output
      // arrives, because gzip's own length field sits at the end of the stream
      // and nothing authenticates it.
      final bomb = gzip.encode(List.filled(8 * 1024 * 1024, 0));
      expect(bomb.length, lessThan(64 * 1024), reason: 'the input is small');

      // The cap is injected rather than the default asserted: a test that fed
      // this to the 256 MiB default would pass with no cap at all.
      expect(
        () => BackupV2.gunzipCapped(bomb, maxBytes: 1024),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('expands past'),
          ),
        ),
      );
    });

    test('an ordinary payload passes the cap', () {
      final data = utf8.encode(_emptyBackup().toJsonString());
      expect(BackupV2.gunzipCapped(gzip.encode(data)), data);
    });
  });
}
