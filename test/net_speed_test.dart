import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/net_speed.dart';

NetSpeedPart _part(String dev, int inB, int outB, int time) =>
    NetSpeedPart(dev, BigInt.from(inB), BigInt.from(outB), time);

/// Feeds samples through the public API, since a [NetSpeed] now starts out
/// genuinely empty instead of being constructed around two fabricated samples.
NetSpeed _seeded(List<List<NetSpeedPart>> samples) {
  final ns = NetSpeed();
  for (final s in samples) {
    ns.update(s);
  }
  return ns;
}

void main() {
  group('NetSpeedPart', () {
    test('same() matches on device name only', () {
      expect(_part('eth0', 1000, 500, 1000).same(_part('eth0', 2000, 1000, 2000)), isTrue);
      expect(_part('eth0', 1000, 500, 1000).same(_part('eth1', 1000, 500, 1000)), isFalse);
    });
  });

  group('NetSpeed windows', () {
    test('no reading until a second sample exists', () {
      final ns = _seeded([
        [_part('eth0', 1000, 500, 1000)],
      ]);
      expect(ns.speedInBytes(0), isNull);
      expect(ns.speedOutBytes(0), isNull);
      expect(ns.speedIn(device: 'eth0'), NetSpeed.noReading);
      // Totals are point-in-time, so they read from the single sample
      expect(ns.sizeIn(device: 'eth0'), '1000 B');
    });

    test('no reading when the source has not advanced', () {
      // Same timestamp twice: monitor refreshes its metrics once per collection
      // cycle, so polling faster returns the same instant. Dividing by that gap
      // used to produce NaN/Infinity; it must report nothing instead of 0.
      final ns = _seeded([
        [_part('eth0', 100, 200, 1)],
        [_part('eth0', 200, 400, 1)],
      ]);
      expect(ns.speedInBytes(0), isNull);
      expect(ns.speedOutBytes(0), isNull);
      expect(ns.speedIn(device: 'eth0'), NetSpeed.noReading);
    });

    test('no reading when the counter goes backwards', () {
      // Interface reset / reboot — a saturating delta would report a flat 0,
      // which is indistinguishable from a genuinely idle link
      final ns = _seeded([
        [_part('eth0', 1000, 1000, 1000)],
        [_part('eth0', 10, 10, 2000)],
      ]);
      expect(ns.speedInBytes(0), isNull);
      expect(ns.speedOutBytes(0), isNull);
    });

    test('rate is the delta over the real elapsed time', () {
      final ns = _seeded([
        [_part('eth0', 1000000, 500000, 1000)],
        [_part('eth0', 2000000, 1000000, 2000)],
      ]);
      expect(ns.speedInBytes(0), 1000);
      expect(ns.speedOutBytes(0), 500);
      expect(ns.speedIn(device: 'eth0'), '1000 B/s');
      expect(ns.speedOut(device: 'eth0'), '500 B/s');
      expect(ns.sizeIn(device: 'eth0'), '1.9 MB');
      expect(ns.sizeOut(device: 'eth0'), '976.6 KB');
    });

    test('a device that appeared this refresh has no rate yet', () {
      final ns = _seeded([
        [_part('eth0', 1000, 1000, 1000)],
        [_part('eth0', 3000, 3000, 2000), _part('eth1', 5000, 5000, 2000)],
      ]);
      expect(ns.speedInBytes(ns.deviceIdx('eth0')), 2);
      expect(ns.speedInBytes(ns.deviceIdx('eth1')), 0);
    });

    test('devices are realigned when the collection order changes', () {
      final ns = _seeded([
        [_part('eth0', 1000, 1000, 1000), _part('eth1', 9000, 9000, 1000)],
        [_part('eth1', 9500, 9500, 2000), _part('eth0', 2000, 2000, 2000)],
      ]);
      // 1000 B over 1000 s, and 500 B over 1000 s
      expect(ns.speedInBytes(ns.deviceIdx('eth0')), 1.0);
      expect(ns.speedInBytes(ns.deviceIdx('eth1')), 0.5);
    });
  });

  group('NetSpeed device lists', () {
    test('real interface filtering', () {
      final ns = _seeded([
        [
          _part('eth0', 1000, 500, 1000),
          _part('wlan0', 1000, 500, 1000),
          _part('en0', 1000, 500, 1000),
          _part('lo', 1000, 500, 1000),
          _part('docker0', 1000, 500, 1000),
        ],
      ]);
      expect(ns.devices, containsAll(['eth0', 'wlan0', 'en0', 'lo', 'docker0']));
      expect(ns.realIfaces, containsAll(['eth0', 'wlan0', 'en0']));
      expect(ns.realIfaces, isNot(contains('lo')));
      expect(ns.realIfaces, isNot(contains('docker0')));
    });

    test('deviceIdx falls back to 0 for unknown devices', () {
      final ns = _seeded([
        [_part('eth0', 1000, 500, 1000), _part('eth1', 1000, 500, 1000)],
      ]);
      expect(ns.deviceIdx('eth0'), 0);
      expect(ns.deviceIdx('eth1'), 1);
      expect(ns.deviceIdx('nonexistent'), 0);
    });

    test('prefix list', () {
      expect(
        NetSpeed.realIfacePrefixs,
        containsAll(['eth', 'wlan', 'en', 'ww', 'wl']),
      );
    });
  });

  group('NetSpeed cached values', () {
    test('start as no-reading and fill in once a window exists', () {
      final ns = NetSpeed();
      expect(ns.cachedVals.speedIn, NetSpeed.noReading);

      ns.update([_part('eth0', 1000000, 500000, 1000)]);
      expect(ns.cachedVals.speedIn, NetSpeed.noReading);
      expect(ns.cachedVals.sizeIn, isNot(NetSpeed.noReading));

      ns.update([_part('eth0', 2000000, 1000000, 2000)]);
      expect(ns.cachedVals.speedIn, '1000 B/s');
      expect(ns.cachedVals.speedOut, '500 B/s');
    });
  });
}
