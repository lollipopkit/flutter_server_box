import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/utils/refresh_interval.dart';
import 'package:server_box/data/res/default.dart';

void main() {
  group('normalizeServerStatusRefreshSeconds', () {
    test('keeps manual refresh disabled', () {
      expect(normalizeServerStatusRefreshSeconds(0), isNull);
    });

    test('keeps valid automatic refresh values', () {
      expect(normalizeServerStatusRefreshSeconds(2), 2);
      expect(normalizeServerStatusRefreshSeconds(10), 10);
    });

    test('falls back for invalid automatic refresh values', () {
      expect(normalizeServerStatusRefreshSeconds(1), Defaults.updateInterval);
      expect(normalizeServerStatusRefreshSeconds(-1), Defaults.updateInterval);
      expect(normalizeServerStatusRefreshSeconds(11), Defaults.updateInterval);
    });
  });
}
