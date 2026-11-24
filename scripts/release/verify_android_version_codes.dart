import 'dart:convert';
import 'dart:io';

const kAndroidAbiCodes = <String, int>{
  'x86_64': 1,
  'armeabi-v7a': 2,
  'arm64-v8a': 3,
};

/// Verifies that split-per-ABI release APKs carry the expected `<build>0<abi>`
/// versionCode (matching F-Droid's recipe and Google Play release ordering)
/// rather than Flutter's default `abiOffset * 1000 + build` offset.
void main(List<String> args) {
  final metadataPath = args.isNotEmpty
      ? args[0]
      : 'build/app/outputs/apk/release/output-metadata.json';
  final pubspecPath = args.length > 1 ? args[1] : 'pubspec.yaml';
  final expectedOutputFiles = args.length > 2 ? args.sublist(2).toSet() : null;

  try {
    final checked = verifyAndroidVersionCodes(
      metadataFile: File(metadataPath),
      pubspecFile: File(pubspecPath),
      expectedOutputFiles: expectedOutputFiles,
    );
    stdout.writeln('Verified versionCode for $checked split APK(s).');
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    exit(1);
  }
}

/// Validates [metadataFile] against [pubspecFile]'s build number and optional
/// [expectedOutputFiles], throwing [FormatException] on any mismatch.
int verifyAndroidVersionCodes({
  required File metadataFile,
  required File pubspecFile,
  Set<String>? expectedOutputFiles,
}) {
  final baseVersionCode = readPubspecBuildNumber(pubspecFile);
  if (!metadataFile.existsSync()) {
    throw FormatException('Missing APK metadata file: ${metadataFile.path}');
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(metadataFile.readAsStringSync());
  } on FormatException catch (e) {
    throw FormatException('Invalid JSON in ${metadataFile.path}: ${e.message}');
  }
  if (decoded is! Map) {
    throw FormatException(
      'Expected JSON object in ${metadataFile.path}, got ${decoded.runtimeType}',
    );
  }

  final elements = decoded['elements'];
  if (elements is! List || elements.isEmpty) {
    throw FormatException('No APK elements in ${metadataFile.path}');
  }

  final seenAbis = <String>{};
  final seenFiles = <String>{};
  for (final raw in elements) {
    if (raw is! Map) {
      throw FormatException(
        'Malformed element in ${metadataFile.path}: expected object',
      );
    }
    final filters = raw['filters'];
    if (filters is! List) {
      throw FormatException(
        'Missing filters list for element in ${metadataFile.path}',
      );
    }
    String? abi;
    for (final filter in filters) {
      if (filter is! Map) {
        throw FormatException(
          'Malformed filter entry in ${metadataFile.path}',
        );
      }
      if (filter['filterType'] == 'ABI') {
        final value = filter['value'];
        if (value is! String || value.isEmpty) {
          throw FormatException(
            'Malformed ABI filter value in ${metadataFile.path}',
          );
        }
        abi = value;
        break;
      }
    }
    if (abi == null) {
      throw FormatException(
        'Missing ABI filter for element (${raw['outputFile']}) in ${metadataFile.path}',
      );
    }
    if (!seenAbis.add(abi)) {
      throw FormatException('Duplicate ABI entry in ${metadataFile.path}: $abi');
    }
    final abiCode = kAndroidAbiCodes[abi];
    if (abiCode == null) {
      throw FormatException('Unexpected ABI in ${metadataFile.path}: $abi');
    }
    final outputFile = raw['outputFile'];
    if (outputFile is! String || outputFile.isEmpty) {
      throw FormatException(
        'Missing outputFile for $abi in ${metadataFile.path}',
      );
    }
    seenFiles.add(outputFile);

    final actual = raw['versionCode'];
    if (actual is! int) {
      throw FormatException(
        'Invalid versionCode for $abi ($outputFile): expected int, got $actual',
      );
    }
    final expected = baseVersionCode * 100 + abiCode;
    if (actual != expected) {
      throw FormatException(
        'Unexpected versionCode for $abi ($outputFile): '
        'got $actual, expected $expected (base $baseVersionCode)',
      );
    }
  }

  if (expectedOutputFiles != null && expectedOutputFiles.isNotEmpty) {
    final missing = expectedOutputFiles.difference(seenFiles);
    final extra = seenFiles.difference(expectedOutputFiles);
    if (missing.isNotEmpty || extra.isNotEmpty) {
      throw FormatException(
        'APK metadata outputFile set mismatch in ${metadataFile.path} '
        '(missing: ${missing.toList()..sort()}, extra: ${extra.toList()..sort()})',
      );
    }
  }

  return seenAbis.length;
}

int readPubspecBuildNumber(File pubspec) {
  if (!pubspec.existsSync()) {
    throw FormatException('Missing pubspec: ${pubspec.path}');
  }
  final pattern = RegExp(
    r'''^version:\s*(?:"([^\s#"]+)\+(\d+)"|'([^\s#']+)\+(\d+)'|([^\s#'"]+)\+(\d+))\s*(?:#.*)?$''',
  );
  for (final line in pubspec.readAsLinesSync()) {
    final match = pattern.firstMatch(line);
    if (match != null) {
      final build = match.group(2) ?? match.group(4) ?? match.group(6)!;
      return int.parse(build);
    }
  }
  throw FormatException('Could not parse +<buildNumber> from ${pubspec.path}');
}
