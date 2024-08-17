import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/time_seq.dart';

class NetSpeedPart extends TimeSeqIface<NetSpeedPart> {
  final String device;
  final BigInt bytesIn;
  final BigInt bytesOut;
  final int time;

  NetSpeedPart(this.device, this.bytesIn, this.bytesOut, this.time);

  @override
  bool same(NetSpeedPart other) => device == other.device;
}

typedef CachedNetVals = ({
  String sizeIn,
  String sizeOut,
  String speedIn,
  String speedOut,
});

class NetSpeed extends TimeSeq<List<NetSpeedPart>> {
  NetSpeed(super.init1, super.init2);

  @override
  void onUpdate() {
    devices.clear();
    devices.addAll(now.map((e) => e.device).toList());

    realIfaces.clear();
    realIfaces.addAll(devices
        .where((e) => realIfacePrefixs.any((prefix) => e.startsWith(prefix))));

    final sizeIn = this.sizeIn();
    final sizeOut = this.sizeOut();
    final speedIn = this.speedIn();
    final speedOut = this.speedOut();

    cachedVals = (
      sizeIn: sizeIn,
      sizeOut: sizeOut,
      speedIn: speedIn,
      speedOut: speedOut,
    );
  }

  /// Cached network device list
  final devices = <String>[];

  /// Issue #295
  /// Non-virtual network device prefix
  static const realIfacePrefixs = ['eth', 'wlan', 'en', 'ww', 'wl'];

  /// Cached non-virtual network device prefix
  final realIfaces = <String>[];

  CachedNetVals cachedVals =
      (sizeIn: '0kb', sizeOut: '0kb', speedIn: '0kb/s', speedOut: '0kb/s');

  /// Time diff between [pre] and [now]
  BigInt get _timeDiff => BigInt.from(now[0].time - pre[0].time);

  double speedInBytes(int i) => (now[i].bytesIn - pre[i].bytesIn) / _timeDiff;
  double speedOutBytes(int i) =>
      (now[i].bytesOut - pre[i].bytesOut) / _timeDiff;
  BigInt sizeInBytes(int i) => now[i].bytesIn;
  BigInt sizeOutBytes(int i) => now[i].bytesOut;

  String speedIn({String? device}) {
    if (pre.isEmpty || now.isEmpty) return 'N/A';
    if (pre.length != now.length) return 'N/A';
    if (device == null) {
      var speed = 0.0;
      for (final device in devices) {
        for (final prefix in realIfacePrefixs) {
          if (device.startsWith(prefix)) {
            speed += speedInBytes(devices.indexOf(device));
          }
        }
      }
      return buildStandardOutput(speed);
    }
    final idx = deviceIdx(device);
    return buildStandardOutput(speedInBytes(idx));
  }

  String sizeIn({String? device}) {
    if (pre.isEmpty || now.isEmpty) return 'N/A';
    if (pre.length != now.length) return 'N/A';
    if (device == null) {
      var size = BigInt.from(0);
      for (final device in devices) {
        for (final prefix in realIfacePrefixs) {
          if (device.startsWith(prefix)) {
            size += sizeInBytes(devices.indexOf(device));
          }
        }
      }
      return size.bytes2Str;
    }
    final idx = deviceIdx(device);
    return sizeInBytes(idx).bytes2Str;
  }

  String speedOut({String? device}) {
    if (pre.isEmpty || now.isEmpty) return 'N/A';
    if (pre.length != now.length) return 'N/A';
    if (device == null) {
      var speed = 0.0;
      for (final device in devices) {
        for (final prefix in realIfacePrefixs) {
          if (device.startsWith(prefix)) {
            speed += speedOutBytes(devices.indexOf(device));
          }
        }
      }
      return buildStandardOutput(speed);
    }
    final idx = deviceIdx(device);
    return buildStandardOutput(speedOutBytes(idx));
  }

  String sizeOut({String? device}) {
    if (pre.isEmpty || now.isEmpty) return 'N/A';
    if (pre.length != now.length) return 'N/A';
    if (device == null) {
      var size = BigInt.from(0);
      for (final device in devices) {
        for (final prefix in realIfacePrefixs) {
          if (device.startsWith(prefix)) {
            size += sizeOutBytes(devices.indexOf(device));
          }
        }
      }
      return size.bytes2Str;
    }
    final idx = deviceIdx(device);
    return sizeOutBytes(idx).bytes2Str;
  }

  int deviceIdx(String? device) {
    if (device != null) {
      for (var item in now) {
        if (item.device == device) {
          return now.indexOf(item);
        }
      }
    }
    return 0;
  }

  String buildStandardOutput(double speed) => '${speed.bytes2Str}/s';

  /// [raw] example:
  /// Inter-|   Receive                                                |  Transmit
  ///   face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
  ///   lo: 45929941  269112    0    0    0     0          0         0 45929941  269112    0    0    0     0       0          0
  ///   eth0: 48481023  505772    0    0    0     0          0         0 36002262  202307    0    0    0     0       0          0
  static List<NetSpeedPart> parse(String raw, int time) {
    final split = raw.split('\n');
    if (split.length < 4) {
      return [];
    }

    final results = <NetSpeedPart>[];
    for (final item in split.sublist(2)) {
      try {
        final data = item.trim().split(':');
        final device = data.firstOrNull;
        if (device == null) continue;
        final bytes = data.last.trim().split(' ');
        bytes.removeWhere((element) => element == '');
        final bytesIn = BigInt.parse(bytes.first);
        final bytesOut = BigInt.parse(bytes[8]);
        results.add(NetSpeedPart(device, bytesIn, bytesOut, time));
      } catch (_) {
        continue;
      }
    }
    return results;
  }

  /// [raw] example:
  /// Name       Mtu   Network       Address            Ipkts Ierrs     Ibytes    Opkts Oerrs     Obytes  Coll
  /// lo0        16384 <Link#1>                      17296531     0 2524959720 17296531     0 2524959720     0
  /// lo0        16384 127           127.0.0.1       17296531     - 2524959720 17296531     - 2524959720     -
  /// lo0        16384 ::1/128     ::1               17296531     - 2524959720 17296531     - 2524959720     -
  /// lo0        16384 fe80::1%lo0 fe80:1::1         17296531     - 2524959720 17296531     - 2524959720     -
  /// gif0*      1280  <Link#2>                             0     0          0        0     0          0     0
  /// stf0*      1280  <Link#3>                             0     0          0        0     0          0     0
  /// en0        1500  <Link#4>    22:20:xx:xx:xx:e6   739447     0  693997876   535600     0   79008877     0
  /// en0        1500  fe80::f1:xx fe80:4::f1:xxxx:9   739447     -  693997876   535600     -   79008877     -
  /// en0        1500  192.168.2     192.168.2.111     739447     -  693997876   535600     -   79008877     -
  /// en0        1500  fd6b:xxxx:3 fd6b:xxxx:xxxx:0:   739447     -  693997876   535600     -   79008877     -
  /// en1        1500  <Link#5>    88:d8:xx:xx:xx:1d        0     0          0        0     0          0     0
  /// utun0      1380  <Link#6>                             0     0          0        3     0        280     0
  /// utun0      1380  fe80::xxxx: fe80:6::xxxx:xxxx        0     -          0        3     -        280     -
  /// utun1      2000  <Link#7>                             0     0          0        3     0        280     0
  /// utun1      2000  fe80::xxxx: fe80:7::xxxx:xxxx        0     -          0        3     -        280     -
  /// utun2      1000  <Link#8>                             0     0          0        3     0        280     0
  /// utun2      1000  fe80::xxxx: fe80:8::xxxx:xxx:        0     -          0        3     -        280     -
  /// utun4      9000  <Link#10>                       746744     0  845373390   386111     0  424400998     0
  /// utun4      9000  198.18.0/16   198.18.0.1        746744     -  845373390   386111     -  424400998     -
  /// en2*       1500  <Link#11>   36:7c:xx:xx:xx:xx        0     0          0        0     0          0     0
  static List<NetSpeedPart> parseBsd(String raw, int time) {
    final split = raw.split('\n');
    if (split.length < 2) {
      return [];
    }

    final results = <NetSpeedPart>[];
    for (final item in split.sublist(1)) {
      final data = item.trim().split(RegExp(r'\s+'));
      final device = data[0];
      if (device.endsWith('*')) {
        continue;
      }
      if (results.any((element) => element.device == device)) {
        continue;
      }
      if (data.length != 11) {
        continue;
      }
      final bytesIn = BigInt.parse(data[6]);
      final bytesOut = BigInt.parse(data[9]);
      results.add(NetSpeedPart(device, bytesIn, bytesOut, time));
    }
    return results;
  }
}
