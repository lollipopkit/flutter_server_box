import 'package:toolbox/core/extension/numx.dart';

import 'time_seq.dart';

class NetSpeedPart extends TimeSeqIface<NetSpeedPart> {
  final String device;
  final BigInt bytesIn;
  final BigInt bytesOut;
  final int time;

  NetSpeedPart(this.device, this.bytesIn, this.bytesOut, this.time);

  @override
  bool same(NetSpeedPart other) => device == other.device;
}

class NetSpeed extends TimeSeq<NetSpeedPart> {
  NetSpeed(super.pre, super.now);

  List<String> get devices => now.map((e) => e.device).toList();

  BigInt get _timeDiff => BigInt.from(now[0].time - pre[0].time);

  double speedInBytes(int i) => (now[i].bytesIn - pre[i].bytesIn) / _timeDiff;
  double speedOutBytes(int i) =>
      (now[i].bytesOut - pre[i].bytesOut) / _timeDiff;
  BigInt sizeInBytes(int i) => now[i].bytesIn;
  BigInt sizeOutBytes(int i) => now[i].bytesOut;

  String speedIn({String? device, bool all = false}) {
    if (pre[0].device == '' || now[0].device == '') return '0kb/s';
    if (all) {
      var speed = 0.0;
      for (var i = 0; i < now.length; i++) {
        speed += speedInBytes(i);
      }
      return buildStandardOutput(speed);
    }
    final idx = deviceIdx(device);
    return buildStandardOutput(speedInBytes(idx));
  }

  String sizeIn({String? device, bool all = false}) {
    if (pre[0].device == '' || now[0].device == '') return '0kb';
    if (all) {
      var size = BigInt.from(0);
      for (var i = 0; i < now.length; i++) {
        size += sizeInBytes(i);
      }
      return size.convertBytes;
    }
    final idx = deviceIdx(device);
    return sizeInBytes(idx).convertBytes;
  }

  String speedOut({String? device, bool all = false}) {
    if (pre[0].device == '' || now[0].device == '') return '0kb/s';
    if (all) {
      var speed = 0.0;
      for (var i = 0; i < now.length; i++) {
        speed += speedOutBytes(i);
      }
      return buildStandardOutput(speed);
    }
    final idx = deviceIdx(device);
    return buildStandardOutput(speedOutBytes(idx));
  }

  String sizeOut({String? device, bool all = false}) {
    if (pre[0].device == '' || now[0].device == '') return '0kb';
    if (all) {
      var size = BigInt.from(0);
      for (var i = 0; i < now.length; i++) {
        size += sizeOutBytes(i);
      }
      return size.convertBytes;
    }
    final idx = deviceIdx(device);
    return sizeOutBytes(idx).convertBytes;
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

  String buildStandardOutput(double speed) => '${speed.convertBytes}/s';
}

/// [raw] example:
/// Inter-|   Receive                                                |  Transmit
///   face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed
///   lo: 45929941  269112    0    0    0     0          0         0 45929941  269112    0    0    0     0       0          0
///   eth0: 48481023  505772    0    0    0     0          0         0 36002262  202307    0    0    0     0       0          0
List<NetSpeedPart> parseNetSpeed(String raw, int time) {
  final split = raw.split('\n');
  if (split.length < 4) {
    return [];
  }

  final results = <NetSpeedPart>[];
  for (final item in split.sublist(2, split.length - 1)) {
    final data = item.trim().split(':');
    final device = data.first;
    final bytes = data.last.trim().split(' ');
    bytes.removeWhere((element) => element == '');
    final bytesIn = BigInt.parse(bytes.first);
    final bytesOut = BigInt.parse(bytes[8]);
    results.add(NetSpeedPart(device, bytesIn, bytesOut, time));
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
List<NetSpeedPart> parseBsdNetSpeed(String raw, int time) {
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
