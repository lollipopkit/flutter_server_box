import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/version.dart';

void main() {
  group('parseVersionParts', () {
    test('parses numeric version parts', () {
      expect(parseVersionParts('7.4'), [7, 4, 0]);
      expect(parseVersionParts('8.1.2'), [8, 1, 2]);
      expect(parseVersionParts('pve-manager/10.0-1'), [10, 0, 0]);
    });

    test('returns null for malformed input without digits', () {
      expect(parseVersionParts('unknown'), isNull);
      expect(parseVersionParts(''), isNull);
    });

    test('returns null for oversized numeric parts', () {
      expect(parseVersionParts('999999999999999999999999999999.0'), isNull);
    });
  });

  group('isVersionLessThan', () {
    test('compares major and minor numerically', () {
      expect(isVersionLessThan('7.4', const [8, 0]), isTrue);
      expect(isVersionLessThan('8.0', const [8, 0]), isFalse);
      expect(isVersionLessThan('8.1', const [8, 0]), isFalse);
      expect(isVersionLessThan('10.0', const [8, 0]), isFalse);
    });

    test('does not flag malformed versions as older', () {
      expect(isVersionLessThan('unknown', const [8, 0]), isFalse);
    });
  });
}
