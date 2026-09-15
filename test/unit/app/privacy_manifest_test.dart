import 'dart:io';

import 'package:test/test.dart';
import 'package:xml/xml.dart';

/// Every `PrivacyInfo.xcprivacy` this repo ships, checked the way App Store
/// Connect checks it rather than the way the tools to hand do.
///
/// XML forbids `--` inside a comment. Almost nothing enforces that: neither
/// `plutil -lint` (CoreFoundation's parser) nor `package:xml` objects, and
/// both manifests carrying it looked fine locally and were rejected on upload
/// with `ITMS-91056: Invalid privacy manifest`, which names a path and nothing
/// else. It was the same prose in both files, so iOS and macOS failed
/// together. `xmllint` does object, but is not on a Dart CI runner — hence the
/// explicit check below rather than a parser doing it for us.
///
/// The allowed keys, values and reason codes below are Xcode's own, read out
/// of `DVTCorePlistStructDefs.dvtplugin` (Xcode 26.5). A value outside them is
/// the ITMS-91054/91055/91056 family, and equally invisible until an upload.
void main() {
  const topLevelKeys = {
    'NSPrivacyTracking',
    'NSPrivacyTrackingDomains',
    'NSPrivacyAccessedAPITypes',
    'NSPrivacyCollectedDataTypes',
  };

  /// Category -> the reason codes permitted for it. A code valid for another
  /// category is still invalid here, which is what ITMS-91055 reports.
  const apiReasons = {
    'NSPrivacyAccessedAPICategoryActiveKeyboards': {'3EC4.1', '54BD.1'},
    'NSPrivacyAccessedAPICategoryDiskSpace': {
      '7D9E.1',
      '85F4.1',
      'B728.1',
      'E174.1',
    },
    'NSPrivacyAccessedAPICategoryFileTimestamp': {
      '0A2A.1',
      '3B52.1',
      'C617.1',
      'DDA9.1',
    },
    'NSPrivacyAccessedAPICategorySystemBootTime': {
      '35F9.1',
      '3D61.1',
      '8FFB.1',
    },
    'NSPrivacyAccessedAPICategoryUserDefaults': {
      '1C8F.1',
      'AC6B.1',
      'C56D.1',
      'CA92.1',
    },
  };

  const collectedDataTypes = {
    'NSPrivacyCollectedDataTypeAdvertisingData',
    'NSPrivacyCollectedDataTypeAudioData',
    'NSPrivacyCollectedDataTypeBrowsingHistory',
    'NSPrivacyCollectedDataTypeCoarseLocation',
    'NSPrivacyCollectedDataTypeContacts',
    'NSPrivacyCollectedDataTypeCrashData',
    'NSPrivacyCollectedDataTypeCreditInfo',
    'NSPrivacyCollectedDataTypeCustomerSupport',
    'NSPrivacyCollectedDataTypeDeviceID',
    'NSPrivacyCollectedDataTypeEmailAddress',
    'NSPrivacyCollectedDataTypeEmailsOrTextMessages',
    'NSPrivacyCollectedDataTypeEnvironmentScanning',
    'NSPrivacyCollectedDataTypeFitness',
    'NSPrivacyCollectedDataTypeGameplayContent',
    'NSPrivacyCollectedDataTypeHands',
    'NSPrivacyCollectedDataTypeHead',
    'NSPrivacyCollectedDataTypeHealth',
    'NSPrivacyCollectedDataTypeName',
    'NSPrivacyCollectedDataTypeOtherDataTypes',
    'NSPrivacyCollectedDataTypeOtherDiagnosticData',
    'NSPrivacyCollectedDataTypeOtherFinancialInfo',
    'NSPrivacyCollectedDataTypeOtherUsageData',
    'NSPrivacyCollectedDataTypeOtherUserContactInfo',
    'NSPrivacyCollectedDataTypeOtherUserContent',
    'NSPrivacyCollectedDataTypePaymentInfo',
    'NSPrivacyCollectedDataTypePerformanceData',
    'NSPrivacyCollectedDataTypePhoneNumber',
    'NSPrivacyCollectedDataTypePhotosorVideos',
    'NSPrivacyCollectedDataTypePhysicalAddress',
    'NSPrivacyCollectedDataTypePreciseLocation',
    'NSPrivacyCollectedDataTypeProductInteraction',
    'NSPrivacyCollectedDataTypePurchaseHistory',
    'NSPrivacyCollectedDataTypeSearchHistory',
    'NSPrivacyCollectedDataTypeSensitiveInfo',
    'NSPrivacyCollectedDataTypeUserID',
  };

  const collectedDataPurposes = {
    'NSPrivacyCollectedDataTypePurposeAnalytics',
    'NSPrivacyCollectedDataTypePurposeAppFunctionality',
    'NSPrivacyCollectedDataTypePurposeDeveloperAdvertising',
    'NSPrivacyCollectedDataTypePurposeOther',
    'NSPrivacyCollectedDataTypePurposeProductPersonalization',
    'NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising',
  };

  final manifests = _findManifests();

  test('the manifests are where they are expected to be', () {
    // A rename that quietly drops a target from the sweep would leave this
    // file passing while checking nothing.
    expect(
      manifests.map(_repoPath),
      containsAll([
        'ios/Runner/PrivacyInfo.xcprivacy',
        'ios/StatusWidget/PrivacyInfo.xcprivacy',
        'ios/WatchApp/PrivacyInfo.xcprivacy',
        'macos/Runner/PrivacyInfo.xcprivacy',
      ]),
    );
  });

  for (final file in manifests) {
    group(_repoPath(file), () {
      late final XmlDocument doc;
      late final Map<String, Object?> root;

      setUpAll(() {
        doc = XmlDocument.parse(file.readAsStringSync());
        final plist = doc.rootElement;
        expect(plist.name.local, 'plist');
        final value = _plistValue(plist.childElements.single);
        expect(value, isA<Map<String, Object?>>());
        root = value as Map<String, Object?>;
      });

      test('no comment contains a double-hyphen', () {
        for (final comment in doc.descendants.whereType<XmlComment>()) {
          expect(
            comment.value,
            isNot(contains('--')),
            reason:
                'XML forbids `--` inside a comment, and App Store Connect is '
                'the only thing that says so. Use an em dash.',
          );
        }
      });

      test('declares only keys Apple defines', () {
        expect(root.keys, everyElement(isIn(topLevelKeys)));
        if (root.containsKey('NSPrivacyTracking')) {
          expect(root['NSPrivacyTracking'], isA<bool>());
        }
        final domains = root['NSPrivacyTrackingDomains'];
        if (domains != null) {
          expect(domains, isA<List<Object?>>());
          expect(domains as List<Object?>, everyElement(isA<String>()));
        }
      });

      test('accessed API types name a category and its own reasons', () {
        final types = root['NSPrivacyAccessedAPITypes'] as List<Object?>?;
        if (types == null) return;

        final seen = <String>{};
        for (final entry in types.cast<Map<String, Object?>>()) {
          expect(
            entry.keys.toSet(),
            {'NSPrivacyAccessedAPIType', 'NSPrivacyAccessedAPITypeReasons'},
          );

          final category = entry['NSPrivacyAccessedAPIType'];
          expect(category, isIn(apiReasons.keys));
          // One dict per category; two is a reported rejection cause.
          expect(seen.add(category as String), isTrue, reason: 'duplicated');

          final reasons =
              entry['NSPrivacyAccessedAPITypeReasons'] as List<Object?>;
          expect(reasons, isNotEmpty);
          expect(reasons, everyElement(isIn(apiReasons[category]!)));
        }
      });

      test('collected data types are complete and valid', () {
        final types = root['NSPrivacyCollectedDataTypes'] as List<Object?>?;
        if (types == null) return;

        final seen = <String>{};
        for (final entry in types.cast<Map<String, Object?>>()) {
          // All four are required; a missing one is ITMS-91056.
          expect(entry.keys.toSet(), {
            'NSPrivacyCollectedDataType',
            'NSPrivacyCollectedDataTypeLinked',
            'NSPrivacyCollectedDataTypeTracking',
            'NSPrivacyCollectedDataTypePurposes',
          });

          final type = entry['NSPrivacyCollectedDataType'];
          expect(type, isIn(collectedDataTypes));
          expect(seen.add(type as String), isTrue, reason: 'duplicated');

          expect(entry['NSPrivacyCollectedDataTypeLinked'], isA<bool>());
          expect(entry['NSPrivacyCollectedDataTypeTracking'], isA<bool>());

          final purposes =
              entry['NSPrivacyCollectedDataTypePurposes'] as List<Object?>;
          expect(purposes, isNotEmpty);
          expect(purposes, everyElement(isIn(collectedDataPurposes)));
        }
      });
    });
  }
}

/// The repo-relative path, `/`-separated on every host. `File.path` carries
/// the platform separator, which would not match the expected paths below on
/// Windows.
String _repoPath(File file) => file.uri.pathSegments.join('/');

/// Every checked-in manifest, build output and third-party copies excluded.
List<File> _findManifests() {
  const roots = ['ios', 'macos', 'packages'];
  const skip = {'build', 'Pods', 'DerivedData', '.symlinks', '.dart_tool'};

  final found = <File>[];
  for (final root in roots) {
    final dir = Directory(root);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final parts = entity.uri.pathSegments;
      if (parts.any(skip.contains)) continue;
      if (parts.last.endsWith('.xcprivacy')) found.add(entity);
    }
  }
  found.sort((a, b) => _repoPath(a).compareTo(_repoPath(b)));
  return found;
}

/// Enough of the plist grammar for a privacy manifest.
Object? _plistValue(XmlElement element) {
  switch (element.name.local) {
    case 'dict':
      final map = <String, Object?>{};
      final children = element.childElements.toList();
      for (var i = 0; i < children.length; i += 2) {
        final key = children[i];
        expect(key.name.local, 'key');
        map[key.innerText] = _plistValue(children[i + 1]);
      }
      return map;
    case 'array':
      return element.childElements.map(_plistValue).toList();
    case 'string':
      return element.innerText;
    case 'true':
      return true;
    case 'false':
      return false;
    case 'integer':
      return int.parse(element.innerText);
    default:
      fail('unsupported plist element <${element.name.local}>');
  }
}
