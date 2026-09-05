import 'package:server_box/data/model/server/benchmark/yabs_options.dart';

/// What a set of options is going to cost, shown before the run starts.
///
/// The numbers below are yabs' own parameters rather than measurements, and
/// they are here because both costs are invisible at the moment the decision is
/// made and expensive by the time they are not: a disk test that takes three
/// minutes is a surprise on a page with a spinner, and an iperf run is tens of
/// gigabytes on a plan somebody pays for by the gigabyte.
///
/// Deliberately rounded and deliberately labelled "about". A precise-looking
/// figure derived from a link speed nobody has measured would be a worse answer
/// than an approximate one that is honest about being approximate.
class BenchmarkEstimate {
  const BenchmarkEstimate(this.options);

  final YabsOptions options;

  /// yabs runs four block sizes for 30 seconds each, plus setup.
  static const _diskMinutes = 3;

  /// Seven locations, or three, each tested in both directions with a 15
  /// second timeout and up to three attempts.
  static const _perLocationMinutes = 0.6;

  /// Download, run, upload. Geekbench 6 on a small VPS is routinely worse than
  /// this.
  static const _cpuMinutes = 6;

  static const _fullLocations = 7;
  static const _reducedLocations = 3;

  int get _locations =>
      options.reducedNetwork ? _reducedLocations : _fullLocations;

  /// Both address families are tested when the host has both, which doubles the
  /// network phase. Assumed here, since it is the common case on a VPS and
  /// guessing low is the direction that surprises people.
  static const _addressFamilies = 2;

  int get minutes {
    var total = 1.0;
    if (options.disk) total += _diskMinutes;
    if (options.network) {
      total += _locations * _perLocationMinutes * _addressFamilies;
    }
    if (options.cpu) total += _cpuMinutes;
    return total.ceil();
  }

  /// Bytes iperf will move, at an assumed link rate.
  ///
  /// 1 Gbps is the assumption: it is what a VPS usually has, and a host with
  /// ten times that moves ten times this. Said as "about" for exactly that
  /// reason — the point is the order of magnitude, which is the part people get
  /// wrong.
  static const _assumedBitsPerSec = 1e9;
  static const _secondsPerDirection = 15;
  static const _directions = 2;

  double get trafficBytes {
    if (!options.network) return 0;
    return _locations *
        _directions *
        _addressFamilies *
        _secondsPerDirection *
        _assumedBitsPerSec /
        8;
  }

  /// The same figure for the other setting, so the switch can say what it
  /// saves rather than only what it does.
  double trafficBytesWith({required bool reduced}) {
    final locations = reduced ? _reducedLocations : _fullLocations;
    return locations *
        _directions *
        _addressFamilies *
        _secondsPerDirection *
        _assumedBitsPerSec /
        8;
  }

  /// Free space the disk phase needs, or null when it is not running.
  ///
  /// yabs skips the phase below this and says so only in the log, so it is
  /// worth stating up front.
  static const diskFreeBytes = 2 * 1024 * 1024 * 1024;

  int? get requiredFreeBytes => options.disk ? diskFreeBytes : null;
}
