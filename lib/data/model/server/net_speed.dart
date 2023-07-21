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

  double _speedIn(int i) => (_now[i].bytesIn - _old[i].bytesIn) / timeDiff;
  double _speedOut(int i) => (_now[i].bytesOut - _old[i].bytesOut) / timeDiff;
  BigInt _sizeIn(int i) => _now[i].bytesIn;
  BigInt _sizeOut(int i) => _now[i].bytesOut;

  String speedIn({String? device, bool all = false}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb/s';
    if (all) {
      var speed = 0.0;
      for (var i = 0; i < _now.length; i++) {
        speed += _speedIn(i);
      }
      return buildStandardOutput(speed);
    }
    final idx = deviceIdx(device);
    return buildStandardOutput(_speedIn(idx));
  }

  String sizeIn({String? device, bool all = false}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb';
    if (all) {
      var size = BigInt.from(0);
      for (var i = 0; i < _now.length; i++) {
        size += _sizeIn(i);
      }
      return size.convertBytes;
    }
    final idx = deviceIdx(device);
    return _sizeIn(idx).convertBytes;
  }

  String speedOut({String? device, bool all = false}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb/s';
    if (all) {
      var speed = 0.0;
      for (var i = 0; i < _now.length; i++) {
        speed += _speedOut(i);
      }
      return buildStandardOutput(speed);
    }
    final idx = deviceIdx(device);
    return buildStandardOutput(_speedOut(idx));
  }

  String sizeOut({String? device, bool all = false}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb';
    if (all) {
      var size = BigInt.from(0);
      for (var i = 0; i < _now.length; i++) {
        size += _sizeOut(i);
      }
      return size.convertBytes;
    }
    final idx = deviceIdx(device);
    return _sizeOut(idx).convertBytes;
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
