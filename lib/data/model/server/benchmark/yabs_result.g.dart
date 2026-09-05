// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'yabs_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_YabsResult _$YabsResultFromJson(Map<String, dynamic> json) => _YabsResult(
  version: json['version'] as String? ?? '',
  time: json['time'] as String? ?? '',
  os: json['os'] == null
      ? const YabsOs()
      : YabsOs.fromJson(json['os'] as Map<String, dynamic>),
  net: json['net'] == null
      ? const YabsNet()
      : YabsNet.fromJson(json['net'] as Map<String, dynamic>),
  cpu: json['cpu'] == null
      ? const YabsCpu()
      : YabsCpu.fromJson(json['cpu'] as Map<String, dynamic>),
  mem: json['mem'] == null
      ? const YabsMem()
      : YabsMem.fromJson(json['mem'] as Map<String, dynamic>),
  partition: json['partition'] as String?,
  fio:
      (json['fio'] as List<dynamic>?)
          ?.map((e) => YabsFio.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  iperf:
      (json['iperf'] as List<dynamic>?)
          ?.map((e) => YabsIperf.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  geekbench:
      (json['geekbench'] as List<dynamic>?)
          ?.map((e) => YabsGeekbench.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  ipInfo: json['ip_info'] == null
      ? null
      : YabsIpInfo.fromJson(json['ip_info'] as Map<String, dynamic>),
  runtime: json['runtime'] == null
      ? null
      : YabsRuntime.fromJson(json['runtime'] as Map<String, dynamic>),
);

Map<String, dynamic> _$YabsResultToJson(_YabsResult instance) =>
    <String, dynamic>{
      'version': instance.version,
      'time': instance.time,
      'os': instance.os,
      'net': instance.net,
      'cpu': instance.cpu,
      'mem': instance.mem,
      'partition': instance.partition,
      'fio': instance.fio,
      'iperf': instance.iperf,
      'geekbench': instance.geekbench,
      'ip_info': instance.ipInfo,
      'runtime': instance.runtime,
    };

_YabsOs _$YabsOsFromJson(Map<String, dynamic> json) => _YabsOs(
  arch: json['arch'] as String? ?? '',
  distro: json['distro'] as String? ?? '',
  kernel: json['kernel'] as String? ?? '',
  uptime: yabsDouble(json['uptime']),
  vm: json['vm'] as String? ?? '',
);

Map<String, dynamic> _$YabsOsToJson(_YabsOs instance) => <String, dynamic>{
  'arch': instance.arch,
  'distro': instance.distro,
  'kernel': instance.kernel,
  'uptime': instance.uptime,
  'vm': instance.vm,
};

_YabsNet _$YabsNetFromJson(Map<String, dynamic> json) => _YabsNet(
  ipv4: json['ipv4'] == null ? false : yabsBool(json['ipv4']),
  ipv6: json['ipv6'] == null ? false : yabsBool(json['ipv6']),
);

Map<String, dynamic> _$YabsNetToJson(_YabsNet instance) => <String, dynamic>{
  'ipv4': instance.ipv4,
  'ipv6': instance.ipv6,
};

_YabsCpu _$YabsCpuFromJson(Map<String, dynamic> json) => _YabsCpu(
  model: json['model'] as String? ?? '',
  cores: yabsInt(json['cores']),
  freq: json['freq'] as String? ?? '',
  aes: json['aes'] == null ? false : yabsBool(json['aes']),
  virt: json['virt'] == null ? false : yabsBool(json['virt']),
);

Map<String, dynamic> _$YabsCpuToJson(_YabsCpu instance) => <String, dynamic>{
  'model': instance.model,
  'cores': instance.cores,
  'freq': instance.freq,
  'aes': instance.aes,
  'virt': instance.virt,
};

_YabsMem _$YabsMemFromJson(Map<String, dynamic> json) => _YabsMem(
  ram: yabsInt(json['ram']),
  ramUnits: json['ram_units'] as String? ?? 'KiB',
  swap: yabsInt(json['swap']),
  swapUnits: json['swap_units'] as String? ?? 'KiB',
  disk: yabsInt(json['disk']),
  diskUnits: json['disk_units'] as String? ?? 'KB',
);

Map<String, dynamic> _$YabsMemToJson(_YabsMem instance) => <String, dynamic>{
  'ram': instance.ram,
  'ram_units': instance.ramUnits,
  'swap': instance.swap,
  'swap_units': instance.swapUnits,
  'disk': instance.disk,
  'disk_units': instance.diskUnits,
};

_YabsFio _$YabsFioFromJson(Map<String, dynamic> json) => _YabsFio(
  bs: json['bs'] as String? ?? '',
  speedRead: yabsDouble(json['speed_r']),
  iopsRead: yabsDouble(json['iops_r']),
  speedWrite: yabsDouble(json['speed_w']),
  iopsWrite: yabsDouble(json['iops_w']),
  speedTotal: yabsDouble(json['speed_rw']),
  iopsTotal: yabsDouble(json['iops_rw']),
  speedUnits: json['speed_units'] as String? ?? 'KBps',
);

Map<String, dynamic> _$YabsFioToJson(_YabsFio instance) => <String, dynamic>{
  'bs': instance.bs,
  'speed_r': instance.speedRead,
  'iops_r': instance.iopsRead,
  'speed_w': instance.speedWrite,
  'iops_w': instance.iopsWrite,
  'speed_rw': instance.speedTotal,
  'iops_rw': instance.iopsTotal,
  'speed_units': instance.speedUnits,
};

_YabsIperf _$YabsIperfFromJson(Map<String, dynamic> json) => _YabsIperf(
  mode: json['mode'] as String? ?? '',
  provider: json['provider'] as String? ?? '',
  loc: json['loc'] as String? ?? '',
  send: json['send'] as String? ?? '',
  recv: json['recv'] as String? ?? '',
  latency: json['latency'] as String? ?? '',
);

Map<String, dynamic> _$YabsIperfToJson(_YabsIperf instance) =>
    <String, dynamic>{
      'mode': instance.mode,
      'provider': instance.provider,
      'loc': instance.loc,
      'send': instance.send,
      'recv': instance.recv,
      'latency': instance.latency,
    };

_YabsGeekbench _$YabsGeekbenchFromJson(Map<String, dynamic> json) =>
    _YabsGeekbench(
      version: yabsInt(json['version']),
      single: yabsInt(json['single']),
      multi: yabsInt(json['multi']),
      url: json['url'] as String? ?? '',
    );

Map<String, dynamic> _$YabsGeekbenchToJson(_YabsGeekbench instance) =>
    <String, dynamic>{
      'version': instance.version,
      'single': instance.single,
      'multi': instance.multi,
      'url': instance.url,
    };

_YabsIpInfo _$YabsIpInfoFromJson(Map<String, dynamic> json) => _YabsIpInfo(
  protocol: json['protocol'] as String? ?? '',
  isp: json['isp'] as String? ?? '',
  asn: json['asn'] as String? ?? '',
  org: json['org'] as String? ?? '',
  city: json['city'] as String? ?? '',
  region: json['region'] as String? ?? '',
  regionCode: json['region_code'] as String? ?? '',
  country: json['country'] as String? ?? '',
);

Map<String, dynamic> _$YabsIpInfoToJson(_YabsIpInfo instance) =>
    <String, dynamic>{
      'protocol': instance.protocol,
      'isp': instance.isp,
      'asn': instance.asn,
      'org': instance.org,
      'city': instance.city,
      'region': instance.region,
      'region_code': instance.regionCode,
      'country': instance.country,
    };

_YabsRuntime _$YabsRuntimeFromJson(Map<String, dynamic> json) => _YabsRuntime(
  start: yabsInt(json['start']),
  end: yabsInt(json['end']),
  elapsed: yabsInt(json['elapsed']),
);

Map<String, dynamic> _$YabsRuntimeToJson(_YabsRuntime instance) =>
    <String, dynamic>{
      'start': instance.start,
      'end': instance.end,
      'elapsed': instance.elapsed,
    };
