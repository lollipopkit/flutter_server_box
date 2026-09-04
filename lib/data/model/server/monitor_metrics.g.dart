// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monitor_metrics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MonitorMetrics _$MonitorMetricsFromJson(
  Map<String, dynamic> json,
) => MonitorMetrics(
  timestamp: json['timestamp'] as String,
  extendedUpdatedAt: json['extended_updated_at'] as String?,
  ips:
      (json['ips'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  serverName: json['server_name'] as String,
  cpuUsage: (json['cpu_usage'] as num).toDouble(),
  cpuCores:
      (json['cpu_cores'] as List<dynamic>?)
          ?.map((e) => MonitorCpuCoreTime.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  memory: MonitorMemoryMetrics.fromJson(json['memory'] as Map<String, dynamic>),
  swap: MonitorSwapMetrics.fromJson(json['swap'] as Map<String, dynamic>),
  disk: MonitorDiskMetrics.fromJson(json['disk'] as Map<String, dynamic>),
  network: MonitorNetworkMetrics.fromJson(
    json['network'] as Map<String, dynamic>,
  ),
  temperature: (json['temperature'] as num?)?.toDouble(),
  temps:
      (json['temps'] as List<dynamic>?)
          ?.map((e) => MonitorTempReading.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  sys: json['sys'] as String?,
  osId: json['os_id'] as String?,
  osIdLike:
      (json['os_id_like'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  cpuBrand: json['cpu_brand'] as String?,
  gpus:
      (json['gpus'] as List<dynamic>?)
          ?.map((e) => MonitorGpuMetrics.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  diskDetails:
      (json['disk_details'] as List<dynamic>?)
          ?.map((e) => MonitorDiskDetail.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  ifaces:
      (json['ifaces'] as List<dynamic>?)
          ?.map((e) => MonitorIfaceMetrics.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  uptime: json['uptime'] as String?,
  conn: json['conn'] == null
      ? null
      : MonitorConn.fromJson(json['conn'] as Map<String, dynamic>),
  diskio:
      (json['diskio'] as List<dynamic>?)
          ?.map((e) => MonitorDiskIoPiece.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  batteries:
      (json['batteries'] as List<dynamic>?)
          ?.map((e) => MonitorBattery.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  sensors:
      (json['sensors'] as List<dynamic>?)
          ?.map((e) => MonitorSensorItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  diskSmart:
      (json['disk_smart'] as List<dynamic>?)
          ?.map((e) => MonitorSmartSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  customCmds:
      (json['custom_cmds'] as List<dynamic>?)
          ?.map((e) => MonitorCustomCmd.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$MonitorMetricsToJson(MonitorMetrics instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'extended_updated_at': instance.extendedUpdatedAt,
      'server_name': instance.serverName,
      'cpu_usage': instance.cpuUsage,
      'cpu_cores': instance.cpuCores,
      'memory': instance.memory,
      'swap': instance.swap,
      'disk': instance.disk,
      'network': instance.network,
      'temperature': instance.temperature,
      'temps': instance.temps,
      'sys': instance.sys,
      'os_id': instance.osId,
      'os_id_like': instance.osIdLike,
      'cpu_brand': instance.cpuBrand,
      'gpus': instance.gpus,
      'disk_details': instance.diskDetails,
      'ifaces': instance.ifaces,
      'uptime': instance.uptime,
      'conn': instance.conn,
      'diskio': instance.diskio,
      'batteries': instance.batteries,
      'sensors': instance.sensors,
      'disk_smart': instance.diskSmart,
      'custom_cmds': instance.customCmds,
      'ips': instance.ips,
    };

MonitorCpuCoreTime _$MonitorCpuCoreTimeFromJson(Map<String, dynamic> json) =>
    MonitorCpuCoreTime(
      used: (json['used'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      usagePercent: (json['usage_percent'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$MonitorCpuCoreTimeToJson(MonitorCpuCoreTime instance) =>
    <String, dynamic>{
      'used': instance.used,
      'total': instance.total,
      'usage_percent': instance.usagePercent,
    };

MonitorTempReading _$MonitorTempReadingFromJson(Map<String, dynamic> json) =>
    MonitorTempReading(
      device: json['device'] as String,
      value: (json['value'] as num).toDouble(),
    );

Map<String, dynamic> _$MonitorTempReadingToJson(MonitorTempReading instance) =>
    <String, dynamic>{'device': instance.device, 'value': instance.value};

MonitorCustomCmd _$MonitorCustomCmdFromJson(Map<String, dynamic> json) =>
    MonitorCustomCmd(
      name: json['name'] as String,
      output: json['output'] as String,
    );

Map<String, dynamic> _$MonitorCustomCmdToJson(MonitorCustomCmd instance) =>
    <String, dynamic>{'name': instance.name, 'output': instance.output};

MonitorMemoryMetrics _$MonitorMemoryMetricsFromJson(
  Map<String, dynamic> json,
) => MonitorMemoryMetrics(
  total: (json['total'] as num).toInt(),
  used: (json['used'] as num).toInt(),
  free: (json['free'] as num).toInt(),
  usagePercent: (json['usage_percent'] as num).toDouble(),
);

Map<String, dynamic> _$MonitorMemoryMetricsToJson(
  MonitorMemoryMetrics instance,
) => <String, dynamic>{
  'total': instance.total,
  'used': instance.used,
  'free': instance.free,
  'usage_percent': instance.usagePercent,
};

MonitorSwapMetrics _$MonitorSwapMetricsFromJson(Map<String, dynamic> json) =>
    MonitorSwapMetrics(
      total: (json['total'] as num).toInt(),
      used: (json['used'] as num).toInt(),
      usagePercent: (json['usage_percent'] as num).toDouble(),
    );

Map<String, dynamic> _$MonitorSwapMetricsToJson(MonitorSwapMetrics instance) =>
    <String, dynamic>{
      'total': instance.total,
      'used': instance.used,
      'usage_percent': instance.usagePercent,
    };

MonitorDiskMetrics _$MonitorDiskMetricsFromJson(Map<String, dynamic> json) =>
    MonitorDiskMetrics(
      total: (json['total'] as num).toInt(),
      used: (json['used'] as num).toInt(),
      free: (json['free'] as num).toInt(),
      usagePercent: (json['usage_percent'] as num).toDouble(),
    );

Map<String, dynamic> _$MonitorDiskMetricsToJson(MonitorDiskMetrics instance) =>
    <String, dynamic>{
      'total': instance.total,
      'used': instance.used,
      'free': instance.free,
      'usage_percent': instance.usagePercent,
    };

MonitorNetworkMetrics _$MonitorNetworkMetricsFromJson(
  Map<String, dynamic> json,
) => MonitorNetworkMetrics(
  rxBytes: (json['rx_bytes'] as num).toInt(),
  txBytes: (json['tx_bytes'] as num).toInt(),
);

Map<String, dynamic> _$MonitorNetworkMetricsToJson(
  MonitorNetworkMetrics instance,
) => <String, dynamic>{
  'rx_bytes': instance.rxBytes,
  'tx_bytes': instance.txBytes,
};

MonitorGpuMetrics _$MonitorGpuMetricsFromJson(Map<String, dynamic> json) =>
    MonitorGpuMetrics(
      name: json['name'] as String,
      usagePercent: (json['usage_percent'] as num).toDouble(),
      temperature: (json['temperature'] as num).toInt(),
      power: json['power'] as String,
      memoryUsed: (json['memory_used'] as num).toInt(),
      memoryTotal: (json['memory_total'] as num).toInt(),
      memoryUnit: json['memory_unit'] as String,
      vendor: json['vendor'] as String?,
    );

Map<String, dynamic> _$MonitorGpuMetricsToJson(MonitorGpuMetrics instance) =>
    <String, dynamic>{
      'name': instance.name,
      'usage_percent': instance.usagePercent,
      'temperature': instance.temperature,
      'power': instance.power,
      'memory_used': instance.memoryUsed,
      'memory_total': instance.memoryTotal,
      'memory_unit': instance.memoryUnit,
      'vendor': instance.vendor,
    };

MonitorDiskDetail _$MonitorDiskDetailFromJson(Map<String, dynamic> json) =>
    MonitorDiskDetail(
      path: json['path'] as String,
      mount: json['mount'] as String,
      fsType: json['fs_type'] as String?,
      used: (json['used'] as num).toInt(),
      total: (json['total'] as num).toInt(),
      usagePercent: (json['usage_percent'] as num).toDouble(),
    );

Map<String, dynamic> _$MonitorDiskDetailToJson(MonitorDiskDetail instance) =>
    <String, dynamic>{
      'path': instance.path,
      'mount': instance.mount,
      'fs_type': instance.fsType,
      'used': instance.used,
      'total': instance.total,
      'usage_percent': instance.usagePercent,
    };

MonitorIfaceMetrics _$MonitorIfaceMetricsFromJson(Map<String, dynamic> json) =>
    MonitorIfaceMetrics(
      name: json['name'] as String,
      rxBytes: (json['rx_bytes'] as num).toInt(),
      txBytes: (json['tx_bytes'] as num).toInt(),
    );

Map<String, dynamic> _$MonitorIfaceMetricsToJson(
  MonitorIfaceMetrics instance,
) => <String, dynamic>{
  'name': instance.name,
  'rx_bytes': instance.rxBytes,
  'tx_bytes': instance.txBytes,
};

MonitorConn _$MonitorConnFromJson(Map<String, dynamic> json) => MonitorConn(
  maxConn: (json['max_conn'] as num).toInt(),
  fail: (json['fail'] as num).toInt(),
);

Map<String, dynamic> _$MonitorConnToJson(MonitorConn instance) =>
    <String, dynamic>{'max_conn': instance.maxConn, 'fail': instance.fail};

MonitorDiskIoPiece _$MonitorDiskIoPieceFromJson(Map<String, dynamic> json) =>
    MonitorDiskIoPiece(
      dev: json['dev'] as String,
      sectorsRead: (json['sectors_read'] as num).toInt(),
      sectorsWrite: (json['sectors_write'] as num).toInt(),
    );

Map<String, dynamic> _$MonitorDiskIoPieceToJson(MonitorDiskIoPiece instance) =>
    <String, dynamic>{
      'dev': instance.dev,
      'sectors_read': instance.sectorsRead,
      'sectors_write': instance.sectorsWrite,
    };

MonitorBattery _$MonitorBatteryFromJson(Map<String, dynamic> json) =>
    MonitorBattery(
      percent: (json['percent'] as num?)?.toInt(),
      status: json['status'] as String,
      name: json['name'] as String?,
      cycle: (json['cycle'] as num?)?.toInt(),
      tech: json['tech'] as String?,
    );

Map<String, dynamic> _$MonitorBatteryToJson(MonitorBattery instance) =>
    <String, dynamic>{
      'percent': instance.percent,
      'status': instance.status,
      'name': instance.name,
      'cycle': instance.cycle,
      'tech': instance.tech,
    };

MonitorSensorItem _$MonitorSensorItemFromJson(Map<String, dynamic> json) =>
    MonitorSensorItem(
      device: json['device'] as String,
      adapter: json['adapter'] as String,
      details: (json['details'] as List<dynamic>)
          .map((e) => (e as List<dynamic>).map((e) => e as String).toList())
          .toList(),
    );

Map<String, dynamic> _$MonitorSensorItemToJson(MonitorSensorItem instance) =>
    <String, dynamic>{
      'device': instance.device,
      'adapter': instance.adapter,
      'details': instance.details,
    };

MonitorSmartSummary _$MonitorSmartSummaryFromJson(Map<String, dynamic> json) =>
    MonitorSmartSummary(
      device: json['device'] as String,
      healthy: json['healthy'] as bool?,
      temperature: (json['temperature'] as num?)?.toDouble(),
      model: json['model'] as String?,
      serial: json['serial'] as String?,
      powerOnHours: (json['power_on_hours'] as num?)?.toInt(),
      powerCycleCount: (json['power_cycle_count'] as num?)?.toInt(),
    );

Map<String, dynamic> _$MonitorSmartSummaryToJson(
  MonitorSmartSummary instance,
) => <String, dynamic>{
  'device': instance.device,
  'healthy': instance.healthy,
  'temperature': instance.temperature,
  'model': instance.model,
  'serial': instance.serial,
  'power_on_hours': instance.powerOnHours,
  'power_cycle_count': instance.powerCycleCount,
};

MonitorHistoryPoint _$MonitorHistoryPointFromJson(Map<String, dynamic> json) =>
    MonitorHistoryPoint(
      timestamp: json['timestamp'] as String,
      cpu: (json['cpu'] as num).toDouble(),
      memory: (json['memory'] as num).toDouble(),
      disk: (json['disk'] as num).toDouble(),
      netRxSpeed: (json['net_rx_speed'] as num).toDouble(),
      netTxSpeed: (json['net_tx_speed'] as num).toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      diskioReadSpeed: (json['diskio_read_speed'] as num).toDouble(),
      diskioWriteSpeed: (json['diskio_write_speed'] as num).toDouble(),
      batteryPercent: (json['battery_percent'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$MonitorHistoryPointToJson(
  MonitorHistoryPoint instance,
) => <String, dynamic>{
  'timestamp': instance.timestamp,
  'cpu': instance.cpu,
  'memory': instance.memory,
  'disk': instance.disk,
  'net_rx_speed': instance.netRxSpeed,
  'net_tx_speed': instance.netTxSpeed,
  'temperature': instance.temperature,
  'diskio_read_speed': instance.diskioReadSpeed,
  'diskio_write_speed': instance.diskioWriteSpeed,
  'battery_percent': instance.batteryPercent,
};
