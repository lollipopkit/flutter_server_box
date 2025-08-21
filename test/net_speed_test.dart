import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/net_speed.dart';

void main() {
  group('NetSpeedPart Tests', () {
    test('NetSpeedPart.same method', () {
      final part1 = NetSpeedPart('eth0', BigInt.from(1000), BigInt.from(500), 1000);
      final part2 = NetSpeedPart('eth0', BigInt.from(2000), BigInt.from(1000), 2000);
      final part3 = NetSpeedPart('eth1', BigInt.from(1000), BigInt.from(500), 1000);
      
      expect(part1.same(part2), isTrue);
      expect(part1.same(part3), isFalse);
    });
  });

  group('NetSpeed Tests', () {
    test('NetSpeed.parse with Linux format', () {
      const raw = '''
Inter-|   Receive                                                |  Transmit
 face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
    lo: 45929941  269112    0    0    0     0          0         0 45929941  269112    0    0    0     0       0          0
  eth0: 48481023  505772    0    0    0     0          0         0 36002262  202307    0    0    0     0       0          0
  wlan0: 12345678  123456    0    0    0     0          0         0 87654321  123456    0    0    0     0       0          0
''';

      final parts = NetSpeed.parse(raw, 1000);
      expect(parts, hasLength(3));
      expect(parts[0].device, equals('lo'));
      expect(parts[0].bytesIn, equals(BigInt.from(45929941)));
      expect(parts[0].bytesOut, equals(BigInt.from(45929941)));
      
      expect(parts[1].device, equals('eth0'));
      expect(parts[1].bytesIn, equals(BigInt.from(48481023)));
      expect(parts[1].bytesOut, equals(BigInt.from(36002262)));
    });

    test('NetSpeed.parseBsd with BSD format', () {
      const raw = '''
Name       Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0        16384 <Link#1>      -              17296531     0 2524959720 17296531     0 2524959720     0
en0        1500  <Link#4>    22:20:xx:xx:xx:e6   739447     0  693997876   535600     0   79008877     0
en1        1500  <Link#5>    88:d8:xx:xx:xx:1d        0     0          0        0     0          0     0
''';

      final parts = NetSpeed.parseBsd(raw, 1000);
      expect(parts, hasLength(3));
      expect(parts[0].device, equals('lo0'));
      expect(parts[0].bytesIn, equals(BigInt.from(2524959720)));
      expect(parts[0].bytesOut, equals(BigInt.from(2524959720)));
      
      expect(parts[1].device, equals('en0'));
      expect(parts[1].bytesIn, equals(BigInt.from(693997876)));
      expect(parts[1].bytesOut, equals(BigInt.from(79008877)));
      
      expect(parts[2].device, equals('en1'));
      expect(parts[2].bytesIn, equals(BigInt.from(0)));
      expect(parts[2].bytesOut, equals(BigInt.from(0)));
    });

    test('NetSpeed.parseBsd skips disabled devices', () {
      const raw = '''
Name       Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
lo0        16384 <Link#1>      -              17296531     0 2524959720 17296531     0 2524959720     0
en2*       1500  <Link#11>   36:7c:xx:xx:xx:xx        0     0          0        0     0          0     0
en0        1500  <Link#4>    22:20:xx:xx:xx:e6   739447     0  693997876   535600     0   79008877     0
''';

      final parts = NetSpeed.parseBsd(raw, 1000);
      expect(parts, hasLength(2));
      expect(parts[0].device, equals('lo0'));
      expect(parts[1].device, equals('en0'));
    });

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