import 'package:json_annotation/json_annotation.dart';

part 'monitor_metrics.g.dart';

/// Dart mirror of monitor's `SystemMetrics` (`monitor/src/monitoring/monitoring.rs`),
/// the JSON shape returned by `GET /api/v1/metrics`. Field names follow the
/// Rust struct's snake_case via [FieldRename.snake].
///
/// This is NOT 1:1 with the app's own `ServerStatus` (which mirrors
/// `sbm_parser::ServerStatus`, the raw SSH+shell-parsed shape) — see
/// `monitor_metrics_mapper.dart` for how the two are reconciled.
@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorMetrics {
  final String timestamp;
  final String extendedUpdatedAt;
  final String serverName;
  final double cpuUsage;
  final List<MonitorCpuCoreTime> cpuCores;
  final MonitorMemoryMetrics memory;
  final MonitorSwapMetrics swap;
  final MonitorDiskMetrics disk;
  final MonitorNetworkMetrics network;
  final double? temperature;

  /// Every sensor the agent could read. Empty on agents predating the
  /// field, where [temperature] is the only reading available.
  final List<MonitorTempReading> temps;
  final String? sys;
  final String? cpuBrand;
  final List<MonitorGpuMetrics> gpus;
  final List<MonitorDiskDetail> diskDetails;
  final List<MonitorIfaceMetrics> ifaces;
  final String? uptime;
  final MonitorConn? conn;
  final List<MonitorDiskIoPiece> diskio;
  final List<MonitorDiskIoRate> diskioRate;
  final List<MonitorBattery> batteries;
  final List<MonitorSensorItem> sensors;
  final List<MonitorSmartSummary> diskSmart;

  const MonitorMetrics({
    required this.timestamp,
    required this.extendedUpdatedAt,
    required this.serverName,
    required this.cpuUsage,
    required this.cpuCores,
    required this.memory,
    required this.swap,
    required this.disk,
    required this.network,
    this.temperature,
    this.temps = const [],
    this.sys,
    this.cpuBrand,
    this.gpus = const [],
    this.diskDetails = const [],
    this.ifaces = const [],
    this.uptime,
    this.conn,
    this.diskio = const [],
    this.diskioRate = const [],
    this.batteries = const [],
    this.sensors = const [],
    this.diskSmart = const [],
  });

  factory MonitorMetrics.fromJson(Map<String, dynamic> json) =>
      _$MonitorMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorMetricsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorCpuCoreTime {
  final int used;
  final int total;

  /// Usage over monitor's own sampling window, 0.0–100.0. Resolved agent-side
  /// (`adapt_cpu`), because what [used]/[total] mean depends on the platform
  /// the agent runs on: cumulative `/proc/stat` ticks on Linux, but a
  /// constant-scale one-shot percentage on Bsd/Windows/macOS. Deriving usage
  /// from the raw pair on this side would be wrong for one of the two.
  ///
  /// `null` on the agent's very first Linux cycle, before it has a baseline,
  /// and on monitor builds predating the field.
  final double? usagePercent;

  const MonitorCpuCoreTime({
    required this.used,
    required this.total,
    this.usagePercent,
  });

  factory MonitorCpuCoreTime.fromJson(Map<String, dynamic> json) =>
      _$MonitorCpuCoreTimeFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorCpuCoreTimeToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorTempReading {
  final String device;

  /// Celsius
  final double value;

  const MonitorTempReading({required this.device, required this.value});

  factory MonitorTempReading.fromJson(Map<String, dynamic> json) =>
      _$MonitorTempReadingFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorTempReadingToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorMemoryMetrics {
  final int total;
  final int used;
  final int free;
  final double usagePercent;

  const MonitorMemoryMetrics({
    required this.total,
    required this.used,
    required this.free,
    required this.usagePercent,
  });

  factory MonitorMemoryMetrics.fromJson(Map<String, dynamic> json) =>
      _$MonitorMemoryMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorMemoryMetricsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorSwapMetrics {
  final int total;
  final int used;
  final double usagePercent;

  const MonitorSwapMetrics({
    required this.total,
    required this.used,
    required this.usagePercent,
  });

  factory MonitorSwapMetrics.fromJson(Map<String, dynamic> json) =>
      _$MonitorSwapMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorSwapMetricsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorDiskMetrics {
  final int total;
  final int used;
  final int free;
  final double usagePercent;

  const MonitorDiskMetrics({
    required this.total,
    required this.used,
    required this.free,
    required this.usagePercent,
  });

  factory MonitorDiskMetrics.fromJson(Map<String, dynamic> json) =>
      _$MonitorDiskMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorDiskMetricsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorNetworkMetrics {
  final int rxBytes;
  final int txBytes;

  const MonitorNetworkMetrics({required this.rxBytes, required this.txBytes});

  factory MonitorNetworkMetrics.fromJson(Map<String, dynamic> json) =>
      _$MonitorNetworkMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorNetworkMetricsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorGpuMetrics {
  final String name;
  final double usagePercent;
  final int temperature;
  final String power;
  final int memoryUsed;
  final int memoryTotal;
  final String memoryUnit;

  const MonitorGpuMetrics({
    required this.name,
    required this.usagePercent,
    required this.temperature,
    required this.power,
    required this.memoryUsed,
    required this.memoryTotal,
    required this.memoryUnit,
  });

  factory MonitorGpuMetrics.fromJson(Map<String, dynamic> json) =>
      _$MonitorGpuMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorGpuMetricsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorDiskDetail {
  final String path;
  final String mount;
  final String? fsType;
  final int used;
  final int total;
  final double usagePercent;

  const MonitorDiskDetail({
    required this.path,
    required this.mount,
    this.fsType,
    required this.used,
    required this.total,
    required this.usagePercent,
  });

  factory MonitorDiskDetail.fromJson(Map<String, dynamic> json) =>
      _$MonitorDiskDetailFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorDiskDetailToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorIfaceMetrics {
  final String name;
  final int rxBytes;
  final int txBytes;

  const MonitorIfaceMetrics({
    required this.name,
    required this.rxBytes,
    required this.txBytes,
  });

  factory MonitorIfaceMetrics.fromJson(Map<String, dynamic> json) =>
      _$MonitorIfaceMetricsFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorIfaceMetricsToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorConn {
  final int maxConn;
  final int fail;

  const MonitorConn({required this.maxConn, required this.fail});

  factory MonitorConn.fromJson(Map<String, dynamic> json) =>
      _$MonitorConnFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorConnToJson(this);
}

/// Cumulative per-device sector counters — same shape/semantics as
/// `sbm_parser::types::DiskIoPiece`, used to drive the app's existing
/// `DiskIO` (`TimeSeq`) delta computation. `diskio_rate` (below) is monitor's
/// own precomputed rate, kept only for parity with the API response; the
/// mapper feeds `diskio` (not `diskio_rate`) into `ss.diskIO.update()` so the
/// app's rolling speed math stays the single source of truth.
@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorDiskIoPiece {
  final String dev;
  final int sectorsRead;
  final int sectorsWrite;

  const MonitorDiskIoPiece({
    required this.dev,
    required this.sectorsRead,
    required this.sectorsWrite,
  });

  factory MonitorDiskIoPiece.fromJson(Map<String, dynamic> json) =>
      _$MonitorDiskIoPieceFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorDiskIoPieceToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorDiskIoRate {
  final String dev;
  final double readBytesPerSec;
  final double writeBytesPerSec;

  const MonitorDiskIoRate({
    required this.dev,
    required this.readBytesPerSec,
    required this.writeBytesPerSec,
  });

  factory MonitorDiskIoRate.fromJson(Map<String, dynamic> json) =>
      _$MonitorDiskIoRateFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorDiskIoRateToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorBattery {
  final int? percent;
  final String status;
  final String? name;
  final int? cycle;
  final String? tech;

  const MonitorBattery({
    this.percent,
    required this.status,
    this.name,
    this.cycle,
    this.tech,
  });

  factory MonitorBattery.fromJson(Map<String, dynamic> json) =>
      _$MonitorBatteryFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorBatteryToJson(this);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorSensorItem {
  final String device;
  final String adapter;
  final List<List<String>> details;

  const MonitorSensorItem({
    required this.device,
    required this.adapter,
    required this.details,
  });

  factory MonitorSensorItem.fromJson(Map<String, dynamic> json) =>
      _$MonitorSensorItemFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorSensorItemToJson(this);
}

/// Mirrors monitor's `SmartSummary` — a trimmed `sbm_parser::types::DiskSmart`
/// without `raw_data`/`smart_attributes` (monitor deliberately drops those to
/// avoid re-serializing a large SMART blob on every poll).
@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorSmartSummary {
  final String device;
  final bool? healthy;
  final double? temperature;
  final String? model;
  final String? serial;
  final int? powerOnHours;
  final int? powerCycleCount;

  const MonitorSmartSummary({
    required this.device,
    this.healthy,
    this.temperature,
    this.model,
    this.serial,
    this.powerOnHours,
    this.powerCycleCount,
  });

  factory MonitorSmartSummary.fromJson(Map<String, dynamic> json) =>
      _$MonitorSmartSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorSmartSummaryToJson(this);
}

/// One bucket from `GET /api/v1/metrics/history?minutes=N`
/// (monitor's `HistoryPoint`, `monitor/src/api/server.rs`). Aggregate-only —
/// no per-core/per-disk/per-iface breakdown, unlike the live `/metrics` snapshot.
@JsonSerializable(fieldRename: FieldRename.snake)
class MonitorHistoryPoint {
  final String timestamp;
  final double cpu;
  final double memory;
  final double disk;
  final double netRxSpeed;
  final double netTxSpeed;
  final double? temperature;
  final double diskioReadSpeed;
  final double diskioWriteSpeed;
  final double? batteryPercent;

  const MonitorHistoryPoint({
    required this.timestamp,
    required this.cpu,
    required this.memory,
    required this.disk,
    required this.netRxSpeed,
    required this.netTxSpeed,
    this.temperature,
    required this.diskioReadSpeed,
    required this.diskioWriteSpeed,
    this.batteryPercent,
  });

  factory MonitorHistoryPoint.fromJson(Map<String, dynamic> json) =>
      _$MonitorHistoryPointFromJson(json);

  Map<String, dynamic> toJson() => _$MonitorHistoryPointToJson(this);
}
