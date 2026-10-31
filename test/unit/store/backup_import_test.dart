import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/bak/backup.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/utils.dart';

void main() {
  const backup = BackupV2(
    version: BackupV2.formatVer,
    date: 123,
    spis: {},
    snippets: {},
    keys: {},
    container: {},
    history: {},
    settings: {},
  );

  test('full exports use restore while server arrays use bulk import', () async {
    final text = backup.toJsonString();
    expect(MergeableUtils.isBackup(text), isTrue);
    expect(MergeableUtils.fromJsonString(text).$1, isA<BackupV2>());
    expect(MergeableUtils.isBackup('[{"name":"example"}]'), isFalse);

    // The envelope this build writes, and the one every build before wrote.
    final age = await AgeCryptor.encrypt(utf8.encode(text), 'synthetic-password');
    final lkfl = Cryptor.encrypt(text, 'synthetic-password');
    for (final encrypted in [age, lkfl]) {
      expect(MergeableUtils.isBackup(encrypted), isTrue);
      final plain = await BackupV2.unlock(
        utf8.encode(encrypted),
        'synthetic-password',
      );
      expect(MergeableUtils.fromBytes(plain).$1, isA<BackupV2>());
    }
  });

  test('legacy array-based backups still restore', () {
    final text = jsonEncode({
      'version': 1,
      'date': '12:00',
      'spis': [],
      'snippets': [],
      'keys': [],
      'container': {},
      'history': {},
      'settings': {},
    });
    expect(MergeableUtils.isBackup(text), isTrue);
    expect(MergeableUtils.fromJsonString(text).$1, isA<Backup>());
    final legacy = jsonEncode(text.codeUnits.map((e) => e * 2 + 1).toList());
    expect(MergeableUtils.isBackup(legacy), isTrue);
    expect(MergeableUtils.fromJsonString(legacy).$1, isA<Backup>());
  });

  test('current-format and versionless maps do not fall back to v1', () {
    final legacyShape = {
      'version': BackupV2.formatVer,
      'date': '12:00',
      'spis': [],
      'snippets': [],
      'keys': [],
      'container': {},
      'history': {},
      'settings': {},
    };
    final versionless = Map<String, dynamic>.from(legacyShape)
      ..remove('version');

    expect(
      () => MergeableUtils.fromJsonString(jsonEncode(legacyShape)),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => MergeableUtils.fromJsonString(jsonEncode(versionless)),
      throwsA(isA<TypeError>()),
    );
  });

  test('bytes that are not text do not fall back to v1', () {
    // Decrypted with the right password and still not a backup: the
    // current reader's error, not a decoding error from the v1 fallback.
    expect(
      () => MergeableUtils.fromBytes([0x1f, 0x8b, 0xff, 0xfe]),
      throwsA(isNot(isA<TypeError>())),
    );
  });

  test('a wrong password is said as one, for either envelope', () async {
    final text = backup.toJsonString();
    final age = await AgeCryptor.encrypt(utf8.encode(text), 'correct');
    final lkfl = Cryptor.encrypt(text, 'correct');
    for (final encrypted in [age, lkfl]) {
      await expectLater(
        BackupV2.unlock(utf8.encode(encrypted), 'wrong'),
        throwsA(isA<WrongPasswordException>()),
      );
    }
    await expectLater(
      BackupV2.unlock(utf8.encode(age), null),
      throwsA(predicate((e) => e.toString().contains('no password'))),
    );
  });
}
