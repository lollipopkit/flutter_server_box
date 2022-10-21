import 'package:toolbox/core/extension/numx.dart';

class NetSpeedPart {
  String device;
  int bytesIn;
  int bytesOut;
  int time;
  NetSpeedPart(this.device, this.bytesIn, this.bytesOut, this.time);
}

class NetSpeed {
  List<NetSpeedPart> old;
  List<NetSpeedPart> now;
  NetSpeed(this.old, this.now);

  List<String> get devices {
    final devices = <String>[];
    for (var item in now) {
      devices.add(item.device);
    }
    return devices;
  }

  void update(List<NetSpeedPart> newOne) {
    old = now;
    now = newOne;
  }

  int get timeDiff => now[0].time - old[0].time;

  String speedIn({String? device}) {
    if (old[0].device == '' || now[0].device == '') return '0kb/s';
    final idx = deviceIdx(device);
    final speedInBytesPerSecond =
        (now[idx].bytesIn - old[idx].bytesIn) / timeDiff;
    return buildStandardOutput(speedInBytesPerSecond);
  }

  String speedOut({String? device}) {
    if (old[0].device == '' || now[0].device == '') return '0kb/s';
    final idx = deviceIdx(device);
    final speedOutBytesPerSecond =
        (now[idx].bytesOut - old[idx].bytesOut) / timeDiff;
    return buildStandardOutput(speedOutBytesPerSecond);
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

  String buildStandardOutput(double speed) =>
      '${speed.convertBytes.toLowerCase()}/s';
}
