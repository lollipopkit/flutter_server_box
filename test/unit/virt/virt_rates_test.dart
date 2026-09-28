import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/virt/virt_rates.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  VirtCounterSample at(int seconds, int netIn) =>
      VirtCounterSample(at: t0.add(Duration(seconds: seconds)), netIn: netIn);

  group('holding until the counters change', () {
    test('an unchanged reading within the hold repeats the last rate', () {
      final r = VirtRateTracker(holdUntilChanged: true);
      r.add('g', at(0, 0));
      expect(r.add('g', at(10, 1000)).netIn, 100);
      expect(r.add('g', at(12, 1000)).netIn, 100);
      expect(r.add('g', at(40, 1000)).netIn, 0, reason: 'past the hold: idle');
    });

    test('the first step after a long idle is not spread over the idle', () {
      final r = VirtRateTracker(holdUntilChanged: true);
      r.add('g', at(0, 0));
      r.add('g', at(10, 1000));
      for (var s = 20; s <= 3600; s += 10) {
        expect(r.add('g', at(s, 1000)).netIn, anyOf(0, 100));
      }
      // 10 MB in pvestatd's latest step, an hour after the last one.
      const mb10 = 10 * 1000 * 1000;
      final rate = r.add('g', at(3610, 1000 + mb10)).netIn!;
      expect(rate, greaterThanOrEqualTo(mb10 / (r.holdFor.inSeconds + 10)));
    });
  });
}
