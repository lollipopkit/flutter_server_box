import 'package:toolbox/core/extension/numx.dart';

class NetSpeedPart {
  String device;
  BigInt bytesIn;
  BigInt bytesOut;
  BigInt time;
  NetSpeedPart(this.device, this.bytesIn, this.bytesOut, this.time);
}

class NetSpeed {
  List<NetSpeedPart> _old;
  List<NetSpeedPart> _now;
  NetSpeed(this._old, this._now);

  List<String> get devices {
    final devices = <String>[];
    for (var item in _now) {
      devices.add(item.device);
    }
    return devices;
  }

  void update(List<NetSpeedPart> newOne) {
    _old = _now;
    _now = newOne;
  }

  BigInt get timeDiff => _now[0].time - _old[0].time;

  String speedIn({String? device}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb/s';
    final idx = deviceIdx(device);
    final speedInBytesPerSecond =
        (_now[idx].bytesIn - _old[idx].bytesIn) / timeDiff;
    return buildStandardOutput(speedInBytesPerSecond);
  }

  String totalIn({String? device}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb';
    final idx = deviceIdx(device);
    final totalInBytes = _now[idx].bytesIn;
    return totalInBytes.toInt().convertBytes;
  }

  String speedOut({String? device}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb/s';
    final idx = deviceIdx(device);
    final speedOutBytesPerSecond =
        (_now[idx].bytesOut - _old[idx].bytesOut) / timeDiff;
    return buildStandardOutput(speedOutBytesPerSecond);
  }

  String totalOut({String? device}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb';
    final idx = deviceIdx(device);
    final totalOutBytes = _now[idx].bytesOut;
    return totalOutBytes.toInt().convertBytes;
  }

  int deviceIdx(String? device) {
    if (device != null) {
      for (var item in _now) {
        if (item.device == device) {
          return _now.indexOf(item);
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
/// 1635752901
List<NetSpeedPart> parseNetSpeed(String raw) {
  final split = raw.split('\n');
  if (split.length < 4) {
    return [];
  }

  final time = BigInt.parse(split[split.length - 1]);
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
