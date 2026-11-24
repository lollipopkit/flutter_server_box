import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../../../scripts/release/verify_android_version_codes.dart' as verifier;

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('verify_android_version_codes_');
  });

  tearDown(() {
    temp.deleteSync(recursive: true);
  });

  File writePubspec(String content) =>
      File('${temp.path}/pubspec.yaml')..writeAsStringSync(content);

  File writeMetadata(Object data) => File('${temp.path}/output-metadata.json')
    ..writeAsStringSync(data is String ? data : jsonEncode(data));

  Map<String, Object?> element(String abi, int versionCode, String file) => {
    'type': 'ONE_OF_MANY',
    'filters': [
      {'filterType': 'ABI', 'value': abi},
    ],
    'versionCode': versionCode,
    'versionName': '1.0.1962',
    'outputFile': file,
  };

  test('accepts all three split ABIs with expected <build>0<abi> codes', () {
    final pubspec = writePubspec('name: server_box\nversion: 1.0.1962+1962\n');
    final meta = writeMetadata({
      'elements': [
        element('x86_64', 196201, 'app-x86_64-release-unsigned.apk'),
        element('armeabi-v7a', 196202, 'app-armeabi-v7a-release-unsigned.apk'),
        element('arm64-v8a', 196203, 'app-arm64-v8a-release-unsigned.apk'),
      ],
    });

    final checked = verifier.verifyAndroidVersionCodes(
      metadataFile: meta,
      pubspecFile: pubspec,
      expectedOutputFiles: const {
        'app-x86_64-release-unsigned.apk',
        'app-armeabi-v7a-release-unsigned.apk',
        'app-arm64-v8a-release-unsigned.apk',
      },
    );
    expect(checked, 3);
  });

  test('supports quoted top-level pubspec version and ignores indented keys', () {
    final pubspec = writePubspec('''
name: server_box
nested:
  version: 0.0.1+999
version: "1.0.1962+1962" # comment
''');
    expect(verifier.readPubspecBuildNumber(pubspec), 1962);

    final singleQuoted = writePubspec("version: '1.0.1963+1963'\n");
    expect(verifier.readPubspecBuildNumber(singleQuoted), 1963);
  });

  test('rejects Flutter 3.50 double-offset versionCode (596201 vs 196201)', () {
    final pubspec = writePubspec('version: 1.0.1962+1962\n');
    final meta = writeMetadata({
      'elements': [
        element('x86_64', 596201, 'app-x86_64-release-unsigned.apk'),
      ],
    });

    expect(
      () => verifier.verifyAndroidVersionCodes(
        metadataFile: meta,
        pubspecFile: pubspec,
      ),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('596201'), contains('196201')),
        ),
      ),
    );
  });

  test('rejects missing ABI filter, duplicate ABI, and outputFile set mismatch', () {
    final pubspec = writePubspec('version: 1.0.1962+1962\n');

    final noAbi = writeMetadata({
      'elements': [
        {
          'type': 'SINGLE',
          'filters': const [],
          'versionCode': 1962,
          'outputFile': 'app-release-unsigned.apk',
        },
      ],
    });
    expect(
      () => verifier.verifyAndroidVersionCodes(
        metadataFile: noAbi,
        pubspecFile: pubspec,
      ),
      throwsFormatException,
    );

    final dupAbi = writeMetadata({
      'elements': [
        element('x86_64', 196201, 'app-x86_64-release-unsigned.apk'),
        element('x86_64', 196201, 'app-x86_64-dup.apk'),
      ],
    });
    expect(
      () => verifier.verifyAndroidVersionCodes(
        metadataFile: dupAbi,
        pubspecFile: pubspec,
      ),
      throwsFormatException,
    );

    final missingExpected = writeMetadata({
      'elements': [
        element('x86_64', 196201, 'app-x86_64-release-unsigned.apk'),
      ],
    });
    expect(
      () => verifier.verifyAndroidVersionCodes(
        metadataFile: missingExpected,
        pubspecFile: pubspec,
        expectedOutputFiles: const {
          'app-x86_64-release-unsigned.apk',
          'app-arm64-v8a-release-unsigned.apk',
        },
      ),
      throwsFormatException,
    );
  });

  test('rejects malformed JSON and non-integer versionCode cleanly', () {
    final pubspec = writePubspec('version: 1.0.1962+1962\n');

    final badJson = writeMetadata('{not json');
    expect(
      () => verifier.verifyAndroidVersionCodes(
        metadataFile: badJson,
        pubspecFile: pubspec,
      ),
      throwsFormatException,
    );

    final stringCode = writeMetadata({
      'elements': [
        {
          'filters': [
            {'filterType': 'ABI', 'value': 'x86_64'},
          ],
          'versionCode': '196201',
          'outputFile': 'app-x86_64-release-unsigned.apk',
        },
      ],
    });
    expect(
      () => verifier.verifyAndroidVersionCodes(
        metadataFile: stringCode,
        pubspecFile: pubspec,
      ),
      throwsFormatException,
    );
  });
}
