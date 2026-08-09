// ignore_for_file: unintended_html_in_doc_comment

import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/time_seq.dart';

class NetSpeedPart extends TimeSeqIface<NetSpeedPart> {
  final String device;
  final BigInt bytesIn;
  final BigInt bytesOut;

  /// Seconds since epoch of the sample these counters came from
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
  NetSpeed();

  NetSpeed.copy(NetSpeed source) : super.copy(source) {
    devices.addAll(source.devices);
    realIfaces.addAll(source.realIfaces);
    _realIfaceIndices.addAll(source._realIfaceIndices);
    cachedVals = source.cachedVals;
  }

  /// Shown wherever a rate can't be computed yet: right after connecting, or
  /// when the source hasn't produced a new sample. Distinct from "0 B/s",
  /// which is a real measurement of an idle link.
  static const noReading = '--';

  @override
  bool advances(List<NetSpeedPart> next) {
    if (next.isEmpty || now.isEmpty) return true;
    return next.first.time > now.first.time;
  }

  @override
  void onUpdate() {
    devices
      ..clear()
      ..addAll(now.map((e) => e.device));

    realIfaces.clear();
    _realIfaceIndices.clear();
    for (var i = 0; i < devices.length; i++) {
      final dev = devices[i];
      if (realIfacePrefixs.any((prefix) => dev.startsWith(prefix))) {
        realIfaces.add(dev);
        _realIfaceIndices.add(i);
      }
    }

    cachedVals = (
      sizeIn: sizeIn(),
      sizeOut: sizeOut(),
      speedIn: speedIn(),
      speedOut: speedOut(),
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
    sizeIn: noReading,
    sizeOut: noReading,
    speedIn: noReading,
    speedOut: noReading,
  );

  /// Seconds covered by the current window, `null` when there isn't one
  double? get _elapsed {
    if (!hasWindow) return null;
    return elapsedSeconds(pre[0].time, now[0].time);
  }

  double? _speed(int i, BigInt Function(NetSpeedPart) counter) {
    final elapsed = _elapsed;
    if (elapsed == null || i >= now.length || i >= pre.length) return null;
    final delta = counterDeltaBig(counter(pre[i]), counter(now[i]));
    if (delta == null) return null;
    return delta.toDouble() / elapsed;
  }

  /// Bytes per second into [i], or `null` when unmeasurable
  double? speedInBytes(int i) => _speed(i, (e) => e.bytesIn);

  /// Bytes per second out of [i], or `null` when unmeasurable
  double? speedOutBytes(int i) => _speed(i, (e) => e.bytesOut);

  BigInt sizeInBytes(int i) => i < now.length ? now[i].bytesIn : BigInt.zero;
  BigInt sizeOutBytes(int i) => i < now.length ? now[i].bytesOut : BigInt.zero;

  /// Summed over real interfaces when [device] is null. `null` if no
  /// interface produced a reading.
  double? speedInBytesOf({String? device}) =>
      _aggregate(device, speedInBytes);

  double? speedOutBytesOf({String? device}) =>
      _aggregate(device, speedOutBytes);

  double? _aggregate(String? device, double? Function(int) of) {
    if (device != null) return of(deviceIdx(device));
    double? sum;
    for (final i in _realIfaceIndices) {
      final v = of(i);
      if (v != null) sum = (sum ?? 0) + v;
    }
    return sum;
  }

  String speedIn({String? device}) => _fmtSpeed(speedInBytesOf(device: device));

  String speedOut({String? device}) =>
      _fmtSpeed(speedOutBytesOf(device: device));

  String sizeIn({String? device}) {
    if (now.isEmpty) return noReading;
    if (device != null) return sizeInBytes(deviceIdx(device)).bytes2Str;
    var size = BigInt.zero;
    for (final i in _realIfaceIndices) {
      size += sizeInBytes(i);
    }
    return size.bytes2Str;
  }

  String sizeOut({String? device}) {
    if (now.isEmpty) return noReading;
    if (device != null) return sizeOutBytes(deviceIdx(device)).bytes2Str;
    var size = BigInt.zero;
    for (final i in _realIfaceIndices) {
      size += sizeOutBytes(i);
    }
    return size.bytes2Str;
  }

  int deviceIdx(String? device) {
    if (device != null) {
      for (var i = 0; i < now.length; i++) {
        if (now[i].device == device) return i;
      }
    }
    return 0;
  }

  static String _fmtSpeed(double? bytesPerSec) =>
      bytesPerSec == null ? noReading : '${bytesPerSec.bytes2Str}/s';
}
