import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/monitor_metrics.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart';

/// Maps monitor's `MonitorMetrics` (`/api/v1/metrics` JSON) onto the app's
/// existing `ServerStatus` shape, mirroring how
/// `server_status_update_req.dart`'s `getStatus()` applies the SSH+shell FFI
/// JSON — same "reuse `cpu`/`netSpeed`/`diskIO` for rolling deltas, apply the
/// rest per-section with independent try/catch" pattern, so this new source
/// can drive the exact same UI without any per-widget changes.
///
/// Prefers monitor's *detail* lists (`disk_details`/`ifaces`/`cpu_cores`/
/// `diskio`) over its flattened aggregate fields wherever both exist, since
/// the app's UI wants per-mount/per-iface/per-core data. Known, deliberate
/// precision losses (monitor's API just doesn't carry this data) are called
/// out per-section below; none of them affect the top-line usage percentages.
ServerStatus applyMonitorMetrics(ServerStatus ss, MonitorMetrics m) {
  final time = _parseEpochSeconds(m.timestamp);

  _apply('cpu', () => _applyCpu(ss, m));
  _apply('mem', () => _applyMemory(ss, m));
  _apply('swap', () => _applySwap(ss, m));
  _apply('disk', () => _applyDisks(ss, m));
  _apply('net', () => _applyNet(ss, m, time));
  _apply('temps', () => _applyTemps(ss, m));
  _apply('conn', () => _applyConn(ss, m));
  _apply('more', () => _applyMore(ss, m));
  _apply('diskio', () => _applyDiskIO(ss, m, time));
  _apply('battery', () => _applyBatteries(ss, m));
  _apply('sensors', () => _applySensors(ss, m));
  _apply('smart', () => _applySmart(ss, m));

  return ss;
}

void _apply(String section, void Function() fn) {
  try {
    fn();
  } catch (e, s) {
    Loggers.app.warning('Apply monitor $section failed', e, s);
  }
}

int _parseEpochSeconds(String iso) {
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return parsed.millisecondsSinceEpoch ~/ 1000;
}

/// monitor's `CpuCoreTime` only has `used`/`total` (no user/sys/nice/iowait/
/// irq/softirq breakdown) — those sub-fields are set to 0, same convention
/// `_accumulateWindowsCpu` already uses in `server_status_update_req.dart`
/// for Windows' instantaneous-percentage source. Overall usage percentage
/// (index 0, the "cpu" aggregate `Cpus` reads by default) is unaffected.
void _applyCpu(ServerStatus ss, MonitorMetrics m) {
  if (m.cpuCores.isEmpty) return;
  var totalUsed = 0;
  var totalTotal = 0;
  final perCore = <SingleCpuCore>[];
  for (var i = 0; i < m.cpuCores.length; i++) {
    final c = m.cpuCores[i];
    totalUsed += c.used;
    totalTotal += c.total;
    perCore.add(SingleCpuCore('cpu$i', c.used, 0, 0, c.total - c.used, 0, 0, 0));
  }
  final cores = [
    SingleCpuCore('cpu', totalUsed, 0, 0, totalTotal - totalUsed, 0, 0, 0),
    ...perCore,
  ];
  ss.cpu.update(cores);

  final brand = m.cpuBrand;
  if (brand != null && brand.isNotEmpty) {
    ss.cpu.brand.clear();
    ss.cpu.brand[brand] = m.cpuCores.length;
  }
}

/// monitor doesn't report `avail` separately from `used`; `avail` is derived
/// as `total - used`, which reproduces monitor's own `usage_percent` exactly.
void _applyMemory(ServerStatus ss, MonitorMetrics m) {
  ss.mem = Memory(
    total: m.memory.total,
    free: m.memory.free,
    avail: m.memory.total - m.memory.used,
  );
}

/// monitor doesn't report swap `cached`; set to 0 (unused by any current UI
/// beyond a debug display).
void _applySwap(ServerStatus ss, MonitorMetrics m) {
  ss.swap = Swap(
    total: m.swap.total,
    free: m.swap.total - m.swap.used,
    cached: 0,
  );
}

void _applyDisks(ServerStatus ss, MonitorMetrics m) {
  ss.disk = m.diskDetails
      .map(
        (d) => Disk(
          path: d.path,
          fsTyp: d.fsType,
          mount: d.mount,
          usedPercent: d.usagePercent.round(),
          used: BigInt.from(d.used),
          size: BigInt.from(d.total),
          avail: BigInt.from(d.total - d.used),
        ),
      )
      .toList();
  try {
    ss.diskUsage = ss.disk.isEmpty ? null : DiskUsage.parse(ss.disk);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }
}

void _applyNet(ServerStatus ss, MonitorMetrics m, int time) {
  if (m.ifaces.isEmpty) return;
  final parts = m.ifaces
      .map(
        (i) => NetSpeedPart(
          i.name,
          BigInt.from(i.rxBytes),
          BigInt.from(i.txBytes),
          time,
        ),
      )
      .toList();
  ss.netSpeed.update(parts);
}

/// monitor only exposes one aggregate temperature reading (no per-sensor
/// breakdown here — that lives in `sensors`/`disk_smart` instead). Stored
/// under a recognized CPU-temp key so `Temperatures.first` picks it up.
void _applyTemps(ServerStatus ss, MonitorMetrics m) {
  final t = m.temperature;
  if (t == null) return;
  ss.temps.setAll({'cpu_thermal': t});
}

void _applyConn(ServerStatus ss, MonitorMetrics m) {
  final conn = m.conn;
  if (conn == null) return;
  ss.tcp = Conn(maxConn: conn.maxConn, fail: conn.fail);
}

void _applyMore(ServerStatus ss, MonitorMetrics m) {
  final sys = m.sys;
  if (sys != null && sys.isNotEmpty) {
    ss.more[StatusCmdType.sys] = sys;
  }
  if (m.serverName.isNotEmpty) {
    ss.more[StatusCmdType.host] = m.serverName;
  }
  final uptime = m.uptime;
  if (uptime != null && uptime.isNotEmpty) {
    ss.more[StatusCmdType.uptime] = uptime;
  }
}

/// Feeds monitor's cumulative `diskio` (same cumulative-sector semantics as
/// `sbm_parser::types::DiskIoPiece`) into the app's existing `DiskIO` delta
/// machinery — NOT `diskio_rate`, which is monitor's own precomputed rate
/// kept only for its history storage. Reusing the same delta path the SSH
/// path already uses keeps rate computation single-sourced.
void _applyDiskIO(ServerStatus ss, MonitorMetrics m, int time) {
  if (m.diskio.isEmpty) return;
  final pieces = m.diskio
      .map(
        (p) => DiskIOPiece(
          dev: p.dev,
          sectorsRead: p.sectorsRead,
          sectorsWrite: p.sectorsWrite,
          time: time,
        ),
      )
      .toList();
  ss.diskIO.update(pieces);
}

void _applyBatteries(ServerStatus ss, MonitorMetrics m) {
  final batteries = m.batteries
      .map(
        (b) => Battery(
          percent: b.percent,
          status: BatteryStatus.values.byName(b.status),
          name: b.name,
          cycle: b.cycle,
          tech: b.tech,
        ),
      )
      .toList();
  ss.batteries
    ..clear()
    ..addAll(batteries);
}

void _applySensors(ServerStatus ss, MonitorMetrics m) {
  if (m.sensors.isEmpty) return;
  final sensors = m.sensors.map((s) {
    final details = <String, String>{
      for (final pair in s.details) pair[0]: pair[1],
    };
    return SensorItem(
      device: s.device,
      adapter: SensorAdaptor.parse(s.adapter),
      details: details,
    );
  }).toList();
  ss.sensors
    ..clear()
    ..addAll(sensors);
}

/// monitor's `SmartSummary` drops `raw_data`/`smart_attributes` (see
/// `MonitorSmartSummary` doc) — those are set to empty, matching how the app
/// already treats servers where SMART data hasn't been fully collected yet.
void _applySmart(ServerStatus ss, MonitorMetrics m) {
  ss.diskSmart = m.diskSmart
      .map(
        (d) => DiskSmart(
          device: d.device,
          healthy: d.healthy,
          temperature: d.temperature,
          model: d.model,
          serial: d.serial,
          powerOnHours: d.powerOnHours,
          powerCycleCount: d.powerCycleCount,
          rawData: const {},
          smartAttributes: const {},
        ),
      )
      .toList();
}
