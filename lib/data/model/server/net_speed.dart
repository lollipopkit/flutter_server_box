import 'package:toolbox/core/extension/numx.dart';

class NetSpeedPart {
  String device;
  int bytesIn;
  int bytesOut;
  int time;
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

  int get timeDiff => _now[0].time - _old[0].time;

  String speedIn({String? device}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb/s';
    final idx = deviceIdx(device);
    final speedInBytesPerSecond =
        (_now[idx].bytesIn - _old[idx].bytesIn) / timeDiff;
    return buildStandardOutput(speedInBytesPerSecond);
  }

  String speedOut({String? device}) {
    if (_old[0].device == '' || _now[0].device == '') return '0kb/s';
    final idx = deviceIdx(device);
    final speedOutBytesPerSecond =
        (_now[idx].bytesOut - _old[idx].bytesOut) / timeDiff;
    return buildStandardOutput(speedOutBytesPerSecond);
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

  String buildStandardOutput(double speed) =>
      '${speed.convertBytes.toLowerCase()}/s';
}
