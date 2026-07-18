// ignore_for_file: unintended_html_in_doc_comment

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

class NetSpeed extends TimeSeq<NetSpeedPart> {
  NetSpeed(super.init1, super.init2);

  @override
  void onUpdate() {
    devices.clear();
    devices.addAll(now.map((e) => e.device).toList());

    realIfaces.clear();
    _realIfaceIndices.clear();
    for (var i = 0; i < devices.length; i++) {
      final dev = devices[i];
      if (realIfacePrefixs.any((prefix) => dev.startsWith(prefix))) {
        realIfaces.add(dev);
        _realIfaceIndices.add(i);
      }
    }

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

  /// Cached indices of real (non-virtual) interfaces in [devices]
  final _realIfaceIndices = <int>[];

  CachedNetVals cachedVals = (
    sizeIn: '0kb',
    sizeOut: '0kb',
    speedIn: '0kb/s',
    speedOut: '0kb/s',
  );

  /// Time diff between [pre] and [now]
  BigInt get _timeDiff => BigInt.from(now[0].time - pre[0].time);

  double speedInBytes(int i) {
    final timeDiff = _timeDiff;
    if (timeDiff <= BigInt.zero) return 0;
    return (now[i].bytesIn - pre[i].bytesIn) / timeDiff;
  }

  double speedOutBytes(int i) {
    final timeDiff = _timeDiff;
    if (timeDiff <= BigInt.zero) return 0;
    return (now[i].bytesOut - pre[i].bytesOut) / timeDiff;
  }
  BigInt sizeInBytes(int i) => now[i].bytesIn;
  BigInt sizeOutBytes(int i) => now[i].bytesOut;

  String speedIn({String? device}) {
    if (pre.isEmpty || now.isEmpty) return 'N/A';
    if (pre.length != now.length) return 'N/A';
    if (device == null) {
      var speed = 0.0;
      for (final i in _realIfaceIndices) {
        speed += speedInBytes(i);
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
      for (final i in _realIfaceIndices) {
        size += sizeInBytes(i);
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
      for (final i in _realIfaceIndices) {
        speed += speedOutBytes(i);
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
      for (final i in _realIfaceIndices) {
        size += sizeOutBytes(i);
      }
      return size.bytes2Str;
    }
    final idx = deviceIdx(device);
    return sizeOutBytes(idx).bytes2Str;
  }

  int deviceIdx(String? device) {
    if (device != null) {
      for (var i = 0; i < now.length; i++) {
        if (now[i].device == device) return i;
      }
    }
    return 0;
  }

  String buildStandardOutput(double speed) => '${speed.bytes2Str}/s';


}
