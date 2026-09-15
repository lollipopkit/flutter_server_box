import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

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
    'device_root',
    'device_file',
    'device_database',
    'device_sharedpref',
  ];

  XmlElement rootElement(String path, String expectedName) {
    final document = XmlDocument.parse(File(path).readAsStringSync());
    expect(document.rootElement.name.local, expectedName);
    return document.rootElement;
  }

  String? androidAttribute(XmlElement element, String name) => element
      .attributes
      .where(
        (attribute) =>
            attribute.name.prefix == 'android' && attribute.name.local == name,
      )
      .firstOrNull
      ?.value;

  void expectAllDomainsExcluded(XmlElement section) {
    expect(section.childElements, hasLength(excludedDomains.length));
    expect(
      section.childElements.every((element) => element.name.local == 'exclude'),
      isTrue,
    );
    final rules = {
      for (final exclude in section.childElements)
        exclude.getAttribute('domain'): exclude.getAttribute('path'),
    };
    expect(rules, {for (final domain in excludedDomains) domain: '.'});
    expect(
      section.descendants.whereType<XmlElement>().any(
        (element) => element.name.local == 'include',
      ),
      isFalse,
    );
  }

  test('Android system backup stays disabled', () {
    final root = rootElement(manifest, 'manifest');
    final applications = root.childElements
        .where((element) => element.name.local == 'application')
        .toList();
    expect(applications, hasLength(1));
    final application = applications.single;

    expect(androidAttribute(application, 'allowBackup'), 'false');
    expect(
      androidAttribute(application, 'fullBackupContent'),
      '@xml/backup_rules',
    );
    expect(
      androidAttribute(application, 'dataExtractionRules'),
      '@xml/data_extraction_rules',
    );
    expect(androidAttribute(application, 'hasFragileUserData'), 'true');
    expect(androidAttribute(application, 'restoreAnyVersion'), isNull);
  });

  test('Android 11 and earlier backup rules exclude every app data domain', () {
    expectAllDomainsExcluded(rootElement(backupRules, 'full-backup-content'));
  });

  test('Android 12 rules exclude cloud backup and device transfer', () {
    final root = rootElement(dataExtractionRules, 'data-extraction-rules');
    final sections = root.childElements.toList();
    expect(sections.map((element) => element.name.local).toList(), [
      'cloud-backup',
      'device-transfer',
    ]);
    for (final section in sections) {
      expectAllDomainsExcluded(section);
    }
  });
}
