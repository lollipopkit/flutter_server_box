import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const manifest = 'android/app/src/main/AndroidManifest.xml';
  const backupRules = 'android/app/src/main/res/xml/backup_rules.xml';
  const dataExtractionRules =
      'android/app/src/main/res/xml/data_extraction_rules.xml';
  const excludedDomains = [
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
  ];

  String section(String source, String tag) {
    final match = RegExp(
      '<$tag(?:\\s[^>]*)?>([\\s\\S]*?)</$tag>',
    ).firstMatch(source);
    expect(match, isNotNull, reason: 'missing <$tag>');
    return match!.group(1)!;
  }

  void expectAllDomainsExcluded(String source) {
    for (final domain in excludedDomains) {
      expect(source, contains('<exclude domain="$domain" path="." />'));
    }
  }

  test('Android system backup stays disabled', () {
    final source = File(manifest).readAsStringSync();

    expect(source, contains('android:allowBackup="false"'));
    expect(source, contains('android:fullBackupContent="@xml/backup_rules"'));
    expect(
      source,
      contains('android:dataExtractionRules="@xml/data_extraction_rules"'),
    );
    expect(source, contains('android:hasFragileUserData="true"'));
    expect(source, isNot(contains('android:restoreAnyVersion=')));
  });

  test('Android 11 and earlier backup rules exclude every app data domain', () {
    final source = File(backupRules).readAsStringSync();

    expectAllDomainsExcluded(section(source, 'full-backup-content'));
  });

  test('Android 12 rules exclude cloud backup and device transfer', () {
    final source = File(dataExtractionRules).readAsStringSync();

    expectAllDomainsExcluded(section(source, 'cloud-backup'));
    expectAllDomainsExcluded(section(source, 'device-transfer'));
  });
}
