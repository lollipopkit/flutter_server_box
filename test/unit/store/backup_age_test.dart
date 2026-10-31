/// The backups a user already has, as the builds that wrote them wrote them,
/// and what `age` itself writes: each restores to the same backup. The
/// fixtures under `test/fixtures/backup/` are never regenerated.
library;

import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/bak/backup2.dart';
import 'package:server_box/data/model/app/bak/utils.dart';
import 'package:server_box/data/res/misc.dart';

void main() {
  const password = 'fixture-password';
  const dir = 'test/fixtures/backup';
  final expected = BackupV2.fromJsonString(
    File('$dir/backup_v4.json').readAsStringSync(),
  );

  Future<void> restores(String file) async {
    final data = File('$dir/$file').readAsBytesSync();
    expect(AgeCryptor.isEncrypted(data), isTrue, reason: file);
    final (mergeable, _) = MergeableUtils.fromBytes(
      await BackupV2.unlock(data, password),
    );
    expect(mergeable, isA<BackupV2>(), reason: file);
    expect((mergeable as BackupV2).toJson(), expected.toJson(), reason: file);
  }

  test(
    'LKFL_ENC V01, gzip inside: what every release before age synced',
    () => restores('lkfl_enc_v01.txt'),
  );

  test(
    'LKFL_ENC V02, the envelope with its cost written in',
    () => restores('lkfl_enc_v02.txt'),
  );

  test('armored age from the age CLI', () => restores('age_armored.txt'));

  test(
    'binary age from the age CLI, gzip inside',
    () => restores('age_binary.age'),
  );

  test('a wrong password is said as one for each', () async {
    for (final file in ['lkfl_enc_v01.txt', 'age_armored.txt']) {
      await expectLater(
        BackupV2.unlock(File('$dir/$file').readAsBytesSync(), 'wrong'),
        throwsA(isA<WrongPasswordException>()),
        reason: file,
      );
    }
  });

  test('the sync file is v4; the older names are read, never written', () {
    expect(Miscs.bakFileName, 'srvbox_bak_v4.age');
    expect(Miscs.plainBakFileName, 'srvbox_bak_v4.json');
    expect(Miscs.legacyBakFileNames, ['srvbox_bak_v3.json', 'srvbox_bak.json']);
  });
}
