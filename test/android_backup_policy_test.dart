import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const manifest = 'android/app/src/main/AndroidManifest.xml';
  const obsoleteRules = 'android/app/src/main/res/xml/backup_rules.xml';

  test('Android system backup stays disabled', () {
    final source = File(manifest).readAsStringSync();

    expect(source, contains('android:allowBackup="false"'));
    expect(source, isNot(contains('android:fullBackupContent=')));
    expect(source, isNot(contains('android:dataExtractionRules=')));
    expect(source, isNot(contains('android:restoreAnyVersion=')));
  });

  test('no obsolete backup rules suggest the database is transferable', () {
    expect(File(obsoleteRules).existsSync(), isFalse);
  });
}
