import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/generated/l10n/l10n.dart';
import 'package:server_box/view/page/home/android_system.dart';

void main() {
  group('localeTagToCode', () {
    test('the system default is empty', () {
      expect(localeTagToCode(''), '');
    });

    test('a supported language, with or without its region', () {
      expect(localeTagToCode('de'), 'de');
      expect(localeTagToCode('de-AT'), 'de');
      expect(localeTagToCode('pt-BR'), 'pt');
    });

    test('Chinese by script and region', () {
      expect(localeTagToCode('zh-CN'), 'zh');
      expect(localeTagToCode('zh-Hans-SG'), 'zh');
      expect(localeTagToCode('zh-TW'), 'zh_TW');
      expect(localeTagToCode('zh-HK'), 'zh_TW');
      expect(localeTagToCode('zh-Hant'), 'zh_TW');
    });

    test('the first of several, and an unsupported one follows the system', () {
      expect(localeTagToCode('ja,en-US'), 'ja');
      expect(localeTagToCode('sv-SE'), '');
    });
  });

  test('localeCodeToTag names what locales_config.xml lists', () {
    expect(localeCodeToTag(''), '');
    expect(localeCodeToTag('zh'), 'zh-CN');
    expect(localeCodeToTag('zh_TW'), 'zh-TW');
    expect(localeCodeToTag('de'), 'de');
  });

  test('every tag listed round-trips', () {
    for (final tag in const [
      'en', 'az', 'de', 'es', 'fr', 'id', 'it', 'ja', 'ko', 'nl', 'pt', 'ru', //
      'tr', 'uk', 'zh-CN', 'zh-TW',
    ]) {
      expect(localeCodeToTag(localeTagToCode(tag)), tag, reason: tag);
    }
  });

  test('locales_config.xml lists every language the app has', () {
    final xml = File(
      'android/app/src/main/res/xml/locales_config.xml',
    ).readAsStringSync();
    final listed = RegExp(
      r'<locale android:name="([^"]+)"',
    ).allMatches(xml).map((m) => m[1]).toSet();
    final expected = {
      for (final l in AppLocalizations.supportedLocales) localeCodeToTag(l.code),
    };
    expect(listed, expected);
  });
}
