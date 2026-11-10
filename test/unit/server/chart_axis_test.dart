import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/view/page/server/chart.dart';

void main() {
  group('niceAxis with a ceiling', () {
    test('a share held at 100% ends its axis at 100', () {
      final axis = niceAxis(trough: 100, peak: 100, binary: false, ceiling: 100);
      expect(axis.top, 100);
      expect(axis.bottom, lessThan(100));
    });

    test('a share near the top ends at 100 rather than past it', () {
      final axis = niceAxis(trough: 60, peak: 99, binary: false, ceiling: 100);
      expect(axis.top, 100);
    });

    test('without one, a flat line is centred as before', () {
      final axis = niceAxis(trough: 100, peak: 100, binary: false);
      expect(axis.top, greaterThan(100));
    });
  });
}
