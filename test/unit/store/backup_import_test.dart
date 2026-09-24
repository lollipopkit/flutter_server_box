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

  test('full exports use restore while server arrays use bulk import', () {
    final text = backup.toJsonString();
    expect(MergeableUtils.isBackup(text), isTrue);
    expect(MergeableUtils.fromJsonString(text).$1, isA<BackupV2>());
    expect(MergeableUtils.isBackup('[{"name":"example"}]'), isFalse);
    final encrypted = Cryptor.encrypt(text, 'synthetic-password');
    expect(MergeableUtils.isBackup(encrypted), isTrue);
    expect(
      MergeableUtils.fromJsonString(encrypted, 'synthetic-password').$1,
      isA<BackupV2>(),
    );
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

  test('wrong passwords retain the decryption error', () {
    final encrypted = Cryptor.encrypt(backup.toJsonString(), 'correct');
    expect(
      () => MergeableUtils.fromJsonString(encrypted, 'wrong'),
      throwsA(predicate((e) => e.toString().contains('decrypt'))),
    );
  });
}
