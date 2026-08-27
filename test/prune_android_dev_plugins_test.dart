import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../scripts/release/prune-android-dev-plugins.dart' as prune;

void main() {
  test('removes dev-only Android metadata and stale Java registration', () {
    final originalDirectory = Directory.current;
    final temp = Directory.systemTemp.createTempSync(
      'prune-android-dev-plugins-',
    );
    addTearDown(() {
      Directory.current = originalDirectory;
      temp.deleteSync(recursive: true);
    });

    final registrant = File(
      '${temp.path}/android/app/src/main/java/io/flutter/plugins/'
      'GeneratedPluginRegistrant.java',
    )..createSync(recursive: true);
    registrant.writeAsStringSync('''
public final class GeneratedPluginRegistrant {
  public static void registerWith() {
    try {
      add(new example.ReleasePlugin());
    } catch (Exception e) {
      log("Error registering plugin release_plugin, example.ReleasePlugin", e);
    }
    try {
      add(new dev.flutter.plugins.integration_test.IntegrationTestPlugin());
    } catch (Exception e) {
      log("Error registering plugin integration_test, dev.flutter.plugins.integration_test.IntegrationTestPlugin", e);
    }
  }
}
''');
    File('${temp.path}/.flutter-plugins-dependencies').writeAsStringSync(
      jsonEncode({
        'plugins': {
          'android': [
            {'name': 'release_plugin', 'dev_dependency': false},
            {'name': 'integration_test', 'dev_dependency': true},
          ],
          'ios': [
            {'name': 'integration_test', 'dev_dependency': true},
          ],
        },
      }),
    );

    Directory.current = temp;
    prune.main();

    final metadata =
        jsonDecode(File('.flutter-plugins-dependencies').readAsStringSync())
            as Map<String, dynamic>;
    final plugins = metadata['plugins'] as Map<String, dynamic>;
    expect(
      (plugins['android'] as List<dynamic>).map(
        (entry) => (entry as Map<String, dynamic>)['name'],
      ),
      ['release_plugin'],
    );
    expect(plugins['ios'] as List<dynamic>, hasLength(1));

    final generatedJava = registrant.readAsStringSync();
    expect(generatedJava, contains('example.ReleasePlugin'));
    expect(generatedJava, isNot(contains('integration_test')));
    expect(generatedJava, isNot(contains('IntegrationTestPlugin')));
  });
}
