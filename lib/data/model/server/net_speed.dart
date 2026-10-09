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
    ifaces.addAll(source.ifaces);
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
    ifaces.clear();
    final others = <int>[];
    for (var i = 0; i < devices.length; i++) {
      final dev = devices[i];
      if (isLoopback(dev)) continue;
      ifaces.add(dev);
      if (realIfacePrefixs.any((prefix) => dev.startsWith(prefix))) {
        realIfaces.add(dev);
        _realIfaceIndices.add(i);
      } else {
        others.add(i);
      }
    }
    // Windows names an interface by its adapter ("Realtek PCIe GbE Family
    // Controller", or "Ethernet" through an agent), which no prefix matches.
    // Totals of nothing read as no traffic at all; every interface is closer.
    if (realIfaces.isEmpty) {
      for (final i in others) {
        realIfaces.add(devices[i]);
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

  /// `lo` (Linux), `lo0` (BSD, macOS), `Loopback Pseudo-Interface 1`
  /// (Windows).
  static bool isLoopback(String dev) {
    final name = dev.toLowerCase();
    return name.startsWith('loopback') || _loopbackName.hasMatch(name);
  }

  static final _loopbackName = RegExp(r'^lo\d*$');

  /// The interfaces the totals add up: those matching [realIfacePrefixs], or
  /// every one but loopback where none does.
  final realIfaces = <String>[];

  /// Every interface but loopback: what a reader can pick from, bridges and
  /// tunnels included. The totals stay the sum of [realIfaces].
  final ifaces = <String>[];

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

  /// Bytes moved since boot, summed over real interfaces when [device] is
  /// null. `null` before the first sample.
  BigInt? sizeInBytesOf({String? device}) => _total(device, sizeInBytes);

  BigInt? sizeOutBytesOf({String? device}) => _total(device, sizeOutBytes);

  BigInt? _total(String? device, BigInt Function(int) of) {
    if (now.isEmpty) return null;
    if (device != null) return of(deviceIdx(device));
    var size = BigInt.zero;
    for (final i in _realIfaceIndices) {
      size += of(i);
    }
    return size;
  }

  String sizeIn({String? device}) =>
      sizeInBytesOf(device: device)?.bytes2Str ?? noReading;

  String sizeOut({String? device}) =>
      sizeOutBytesOf(device: device)?.bytes2Str ?? noReading;

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
