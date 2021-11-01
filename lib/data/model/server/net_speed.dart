import 'dart:math';

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

  NetSpeed update(List<NetSpeedPart> newOne) => NetSpeed(now, newOne);

  int get timeDiff => now[0].time - old[0].time;

  String speedIn({String? device}) {
    if (old[0].device == '' || now[0].device == '') return '0kb/s';
    int idx = 0;
    if (device != null) {
      for (var item in now) {
        if (item.device == device) {
          idx = now.indexOf(item);
          break;
        }
      }
    }
    final speedInBytesPerSecond =
        (now[idx].bytesIn - old[idx].bytesIn) / timeDiff;
    int squareTimes = 0;
    for (; speedInBytesPerSecond / pow(1024, squareTimes) > 1024;) {
      if (squareTimes >= suffixs.length - 1) break;
      squareTimes++;
    }
    return '${(speedInBytesPerSecond / pow(1024, squareTimes)).toStringAsFixed(1)} ${suffixs[squareTimes]}';
  }

  String speedOut({String? device}) {
    if (old[0].device == '' || now[0].device == '') return '0kb/s';
    int idx = 0;
    if (device != null) {
      for (var item in now) {
        if (item.device == device) {
          idx = now.indexOf(item);
          break;
        }
      }
    }
    final speedInBytesPerSecond =
        (now[idx].bytesOut - old[idx].bytesOut) / timeDiff;
    int squareTimes = 0;
    for (; speedInBytesPerSecond / pow(1024, squareTimes) > 1024;) {
      if (squareTimes >= suffixs.length - 1) break;
      squareTimes++;
    }
    return '${(speedInBytesPerSecond / pow(1024, squareTimes)).toStringAsFixed(1)} ${suffixs[squareTimes]}';
  }
}

const suffixs = ['b/s', 'kb/s', 'mb/s', 'gb/s'];
