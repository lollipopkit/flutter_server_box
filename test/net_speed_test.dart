import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/net_speed.dart';

void main() {
  test('NetSpeed returns zero speed for equal timestamps', () {
    final pre = [NetSpeedPart('eth0', BigInt.from(100), BigInt.from(200), 1)];
    final now = [NetSpeedPart('eth0', BigInt.from(200), BigInt.from(400), 1)];
    final netSpeed = NetSpeed(pre, now);

    expect(netSpeed.speedInBytes(0), 0);
    expect(netSpeed.speedOutBytes(0), 0);
  });

  group('NetSpeedPart Tests', () {
    test('NetSpeedPart.same method', () {
      final part1 = NetSpeedPart(
        'eth0',
        BigInt.from(1000),
        BigInt.from(500),
        1000,
      );
      final part2 = NetSpeedPart(
        'eth0',
        BigInt.from(2000),
        BigInt.from(1000),
        2000,
      );
      final part3 = NetSpeedPart(
        'eth1',
        BigInt.from(1000),
        BigInt.from(500),
        1000,
      );

      expect(part1.same(part2), isTrue);
      expect(part1.same(part3), isFalse);
    });
  });

  group('NetSpeed Tests', () {
    test('NetSpeed speed calculations', () {
      final oldData = [
        NetSpeedPart('eth0', BigInt.from(1000000), BigInt.from(500000), 1000),
        NetSpeedPart('lo', BigInt.from(2000000), BigInt.from(1000000), 1000),
      ];
      final newData = [
        NetSpeedPart('eth0', BigInt.from(2000000), BigInt.from(1000000), 2000),
        NetSpeedPart('lo', BigInt.from(3000000), BigInt.from(2000000), 2000),
      ];

      final netSpeed = NetSpeed(oldData, newData);
      netSpeed.onUpdate();

      expect(netSpeed.devices, contains('eth0'));
      expect(netSpeed.devices, contains('lo'));
      expect(netSpeed.realIfaces, contains('eth0'));
      expect(netSpeed.realIfaces, isNot(contains('lo')));
    });

    test('NetSpeed speed calculations for specific device', () {
      final oldData = [
        NetSpeedPart('eth0', BigInt.from(1000000), BigInt.from(500000), 1000),
      ];
      final newData = [
        NetSpeedPart('eth0', BigInt.from(2000000), BigInt.from(1000000), 2000),
      ];

      final netSpeed = NetSpeed(oldData, newData);
      netSpeed.onUpdate();

      final speedIn = netSpeed.speedIn(device: 'eth0');
      final speedOut = netSpeed.speedOut(device: 'eth0');
      final sizeIn = netSpeed.sizeIn(device: 'eth0');
      final sizeOut = netSpeed.sizeOut(device: 'eth0');

      expect(speedIn, equals('1000 B/s'));
      expect(speedOut, equals('500 B/s'));
      expect(sizeIn, equals('1.9 MB'));
      expect(sizeOut, equals('976.6 KB'));
    });

    test('NetSpeed handles empty data gracefully', () {
      final netSpeed = NetSpeed([], []);
      netSpeed.onUpdate();

      expect(netSpeed.speedIn(), equals('N/A'));
      expect(netSpeed.speedOut(), equals('N/A'));
      expect(netSpeed.sizeIn(), equals('N/A'));
      expect(netSpeed.sizeOut(), equals('N/A'));
    });

    test('NetSpeed real interface filtering', () {
      final parts = [
        NetSpeedPart('eth0', BigInt.from(1000), BigInt.from(500), 1000),
        NetSpeedPart('wlan0', BigInt.from(1000), BigInt.from(500), 1000),
        NetSpeedPart('en0', BigInt.from(1000), BigInt.from(500), 1000),
        NetSpeedPart('lo', BigInt.from(1000), BigInt.from(500), 1000),
        NetSpeedPart('docker0', BigInt.from(1000), BigInt.from(500), 1000),
      ];

      final netSpeed = NetSpeed([], parts);
      netSpeed.onUpdate();

      expect(netSpeed.realIfaces, contains('eth0'));
      expect(netSpeed.realIfaces, contains('wlan0'));
      expect(netSpeed.realIfaces, contains('en0'));
      expect(netSpeed.realIfaces, isNot(contains('lo')));
      expect(netSpeed.realIfaces, isNot(contains('docker0')));
    });

    test('NetSpeed deviceIdx method', () {
      final parts = [
        NetSpeedPart('eth0', BigInt.from(1000), BigInt.from(500), 1000),
        NetSpeedPart('eth1', BigInt.from(1000), BigInt.from(500), 1000),
      ];

      final netSpeed = NetSpeed([], parts);
      netSpeed.onUpdate();

      expect(netSpeed.deviceIdx('eth0'), equals(0));
      expect(netSpeed.deviceIdx('eth1'), equals(1));
      expect(netSpeed.deviceIdx('nonexistent'), equals(0));
    });
  });

  group('NetSpeed real interface prefixes', () {
    test('Contains all expected prefixes', () {
      expect(NetSpeed.realIfacePrefixs, contains('eth'));
      expect(NetSpeed.realIfacePrefixs, contains('wlan'));
      expect(NetSpeed.realIfacePrefixs, contains('en'));
      expect(NetSpeed.realIfacePrefixs, contains('ww'));
      expect(NetSpeed.realIfacePrefixs, contains('wl'));
    });
  });

  group('NetSpeed cached values', () {
    test('Updates cached values on onUpdate', () {
      final oldData = [
        NetSpeedPart('eth0', BigInt.from(1000000), BigInt.from(500000), 1000),
      ];
      final newData = [
        NetSpeedPart('eth0', BigInt.from(2000000), BigInt.from(1000000), 2000),
      ];

      final netSpeed = NetSpeed(oldData, newData);
      expect(netSpeed.cachedVals.speedIn, equals('0kb/s'));

      netSpeed.onUpdate();
      expect(netSpeed.cachedVals.speedIn, isNot(equals('0kb/s')));
      expect(netSpeed.cachedVals.speedOut, isNot(equals('0kb/s')));
      expect(netSpeed.cachedVals.sizeIn, isNot(equals('0kb')));
      expect(netSpeed.cachedVals.sizeOut, isNot(equals('0kb')));
    });
  });
}
