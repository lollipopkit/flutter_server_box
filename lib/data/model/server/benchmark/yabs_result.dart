import 'package:freezed_annotation/freezed_annotation.dart';

part 'yabs_result.freezed.dart';
part 'yabs_result.g.dart';

/// One yabs run's `-w` output.
///
/// **Every field is parsed leniently, on purpose.** yabs builds this JSON by
/// concatenating shell strings — `'"cores":'$CPU_CORES','` and so on — with no
/// encoder in between, so a value it failed to collect arrives as an empty
/// slot, a number arrives as a string on one distro and a number on the next,
/// and a distro name containing a quote produces a document no parser accepts.
/// The alternative to leniency is throwing away a complete benchmark because
/// `lscpu` printed something unexpected in one field, which would be the wrong
/// trade for something the user waited fifteen minutes for.
///
/// For the same reason the raw text is kept beside this on the record (see
/// `BenchmarkRun.resultJson`): what this class did not understand is still
/// there, and a later build can read it without asking for the run again.
@freezed
abstract class YabsResult with _$YabsResult {
  const YabsResult._();

  const factory YabsResult({
    @Default('') String version,
    @Default('') String time,
    @Default(YabsOs()) YabsOs os,
    @Default(YabsNet()) YabsNet net,
    @Default(YabsCpu()) YabsCpu cpu,
    @Default(YabsMem()) YabsMem mem,

    /// The device fio tested. Absent when the disk phase did not run.
    String? partition,
    @Default([]) List<YabsFio> fio,
    @Default([]) List<YabsIperf> iperf,
    @Default([]) List<YabsGeekbench> geekbench,
    @JsonKey(name: 'ip_info') YabsIpInfo? ipInfo,
    YabsRuntime? runtime,
  }) = _YabsResult;

  factory YabsResult.fromJson(Map<String, dynamic> json) =>
      _$YabsResultFromJson(json);
}

@freezed
abstract class YabsOs with _$YabsOs {
  const factory YabsOs({
    @Default('') String arch,
    @Default('') String distro,
    @Default('') String kernel,

    /// Seconds, from `/proc/uptime`, so fractional.
    @JsonKey(fromJson: yabsDouble) double? uptime,

    /// The virtualisation yabs detected — `KVM`, `LXC`, and so on. Empty on
    /// bare metal, which is a result rather than a gap.
    @Default('') String vm,
  }) = _YabsOs;

  factory YabsOs.fromJson(Map<String, dynamic> json) => _$YabsOsFromJson(json);
}

@freezed
abstract class YabsNet with _$YabsNet {
  const factory YabsNet({
    @JsonKey(fromJson: yabsBool) @Default(false) bool ipv4,
    @JsonKey(fromJson: yabsBool) @Default(false) bool ipv6,
  }) = _YabsNet;

  factory YabsNet.fromJson(Map<String, dynamic> json) =>
      _$YabsNetFromJson(json);
}

@freezed
abstract class YabsCpu with _$YabsCpu {
  const factory YabsCpu({
    @Default('') String model,
    @JsonKey(fromJson: yabsInt) int? cores,

    /// A string because yabs writes it as one, units and all.
    @Default('') String freq,

    /// AES-NI, and hardware virtualisation. Both are the difference between a
    /// host that can do a job and one that will crawl through it.
    @JsonKey(fromJson: yabsBool) @Default(false) bool aes,
    @JsonKey(fromJson: yabsBool) @Default(false) bool virt,
  }) = _YabsCpu;

  factory YabsCpu.fromJson(Map<String, dynamic> json) =>
      _$YabsCpuFromJson(json);
}

/// Memory and disk totals.
///
/// yabs reports RAM and swap in KiB and the disk in KB, and says so in the
/// `*_units` fields rather than normalising. Those fields are kept because they
/// are what the numbers mean; nothing here assumes them.
@freezed
abstract class YabsMem with _$YabsMem {
  const YabsMem._();

  const factory YabsMem({
    @JsonKey(fromJson: yabsInt) int? ram,
    @JsonKey(name: 'ram_units') @Default('KiB') String ramUnits,
    @JsonKey(fromJson: yabsInt) int? swap,
    @JsonKey(name: 'swap_units') @Default('KiB') String swapUnits,
    @JsonKey(fromJson: yabsInt) int? disk,
    @JsonKey(name: 'disk_units') @Default('KB') String diskUnits,
  }) = _YabsMem;

  factory YabsMem.fromJson(Map<String, dynamic> json) =>
      _$YabsMemFromJson(json);

  int? get ramBytes => _bytes(ram, ramUnits);
  int? get swapBytes => _bytes(swap, swapUnits);
  int? get diskBytes => _bytes(disk, diskUnits);

  /// The unit strings yabs writes are fixed, but read rather than assumed: it
  /// has changed one before, and a silent factor-of-1024 error in a memory
  /// figure is not something a reader would catch.
  static int? _bytes(int? value, String units) {
    if (value == null) return null;
    return switch (units.toLowerCase()) {
      'kib' => value * 1024,
      'mib' => value * 1024 * 1024,
      'gib' => value * 1024 * 1024 * 1024,
      'kb' => value * 1000,
      'mb' => value * 1000 * 1000,
      'gb' => value * 1000 * 1000 * 1000,
      'b' || '' => value,
      _ => null,
    };
  }
}

/// One fio block size, read/write/mixed.
///
/// Speeds are in `speed_units` — KBps in every version so far — and the IOPS
/// figures are counts.
@freezed
abstract class YabsFio with _$YabsFio {
  const YabsFio._();

  const factory YabsFio({
    /// The block size, e.g. `4k`.
    @Default('') String bs,
    @JsonKey(name: 'speed_r', fromJson: yabsDouble) double? speedRead,
    @JsonKey(name: 'iops_r', fromJson: yabsDouble) double? iopsRead,
    @JsonKey(name: 'speed_w', fromJson: yabsDouble) double? speedWrite,
    @JsonKey(name: 'iops_w', fromJson: yabsDouble) double? iopsWrite,
    @JsonKey(name: 'speed_rw', fromJson: yabsDouble) double? speedTotal,
    @JsonKey(name: 'iops_rw', fromJson: yabsDouble) double? iopsTotal,
    @JsonKey(name: 'speed_units') @Default('KBps') String speedUnits,
  }) = _YabsFio;

  factory YabsFio.fromJson(Map<String, dynamic> json) =>
      _$YabsFioFromJson(json);

  double? get readBytesPerSec => _bps(speedRead);
  double? get writeBytesPerSec => _bps(speedWrite);
  double? get totalBytesPerSec => _bps(speedTotal);

  double? _bps(double? value) {
    if (value == null) return null;
    return switch (speedUnits.toLowerCase()) {
      'kbps' => value * 1000,
      'mbps' => value * 1000 * 1000,
      'bps' || '' => value,
      _ => null,
    };
  }
}

/// One iperf3 location, one address family.
///
/// The three measurements are strings with their units baked in — `"1.20 Gbits
/// /sec"`, `"12.3 ms"` — because that is what yabs stores. [sendBitsPerSec] and
/// friends pull a comparable number back out; the string stays for display, so
/// a value this could not read is still shown rather than blanked.
@freezed
abstract class YabsIperf with _$YabsIperf {
  const YabsIperf._();

  const factory YabsIperf({
    /// `IPv4` or `IPv6`.
    @Default('') String mode,
    @Default('') String provider,
    @Default('') String loc,
    @Default('') String send,
    @Default('') String recv,
    @Default('') String latency,
  }) = _YabsIperf;

  factory YabsIperf.fromJson(Map<String, dynamic> json) =>
      _$YabsIperfFromJson(json);

  double? get sendBitsPerSec => parseRate(send);
  double? get recvBitsPerSec => parseRate(recv);

  /// Milliseconds, or null when the run reported `--` for a location it could
  /// not reach.
  double? get latencyMs {
    final match = RegExp(r'([\d.]+)').firstMatch(latency);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  /// `"1.20 Gbits/sec"` to bits per second.
  ///
  /// Decimal multipliers, not binary: iperf3 reports network rates, where
  /// `G` has meant 10^9 since long before anyone wrote this.
  static double? parseRate(String raw) {
    final match = RegExp(
      r'([\d.]+)\s*([KMGT]?)',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!);
    if (value == null) return null;
    return value *
        switch (match.group(2)!.toUpperCase()) {
          'K' => 1e3,
          'M' => 1e6,
          'G' => 1e9,
          'T' => 1e12,
          _ => 1.0,
        };
  }
}

@freezed
abstract class YabsGeekbench with _$YabsGeekbench {
  const factory YabsGeekbench({
    @JsonKey(fromJson: yabsInt) int? version,
    @JsonKey(fromJson: yabsInt) int? single,
    @JsonKey(fromJson: yabsInt) int? multi,

    /// The public `browser.geekbench.com` page this run was published to.
    ///
    /// Kept because it is the only way to reach the detail Geekbench keeps and
    /// this does not — and because a user who wants the run taken down needs
    /// somewhere to go.
    @Default('') String url,
  }) = _YabsGeekbench;

  factory YabsGeekbench.fromJson(Map<String, dynamic> json) =>
      _$YabsGeekbenchFromJson(json);
}

@freezed
abstract class YabsIpInfo with _$YabsIpInfo {
  const factory YabsIpInfo({
    @Default('') String protocol,
    @Default('') String isp,
    @Default('') String asn,
    @Default('') String org,
    @Default('') String city,
    @Default('') String region,
    @JsonKey(name: 'region_code') @Default('') String regionCode,
    @Default('') String country,
  }) = _YabsIpInfo;

  factory YabsIpInfo.fromJson(Map<String, dynamic> json) =>
      _$YabsIpInfoFromJson(json);
}

@freezed
abstract class YabsRuntime with _$YabsRuntime {
  const factory YabsRuntime({
    @JsonKey(fromJson: yabsInt) int? start,
    @JsonKey(fromJson: yabsInt) int? end,

    /// Seconds the whole run took, by yabs' own clock.
    @JsonKey(fromJson: yabsInt) int? elapsed,
  }) = _YabsRuntime;

  factory YabsRuntime.fromJson(Map<String, dynamic> json) =>
      _$YabsRuntimeFromJson(json);
}

/// The three below are why this file parses by hand.
///
/// A field yabs could not fill is written as nothing at all, which lands here
/// as a missing key, a null, or the empty string depending on where in the
/// document it was; and a number is sometimes quoted. Every one of those is
/// "not measured", which is what null means here — never zero, because a disk
/// that did 0 IOPS and a disk that was not tested are not the same reading.
int? yabsInt(Object? raw) => switch (raw) {
  final int v => v,
  final num v => v.toInt(),
  final String v => int.tryParse(v.trim()) ?? double.tryParse(v.trim())?.toInt(),
  _ => null,
};

double? yabsDouble(Object? raw) => switch (raw) {
  final num v => v.toDouble(),
  final String v => double.tryParse(v.trim()),
  _ => null,
};

bool yabsBool(Object? raw) => switch (raw) {
  final bool v => v,
  final String v => v.trim().toLowerCase() == 'true',
  final num v => v != 0,
  _ => false,
};
