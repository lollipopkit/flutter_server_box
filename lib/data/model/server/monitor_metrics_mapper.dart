import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/amd.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/monitor_metrics.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/nvdia.dart';
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
  _apply('gpu', () => _applyGpus(ss, m));
  _apply('conn', () => _applyConn(ss, m));
  _apply('more', () => _applyMore(ss, m));
  _apply('diskio', () => _applyDiskIO(ss, m, time));
  _apply('battery', () => _applyBatteries(ss, m));
  _apply('sensors', () => _applySensors(ss, m));
  _apply('smart', () => _applySmart(ss, m));
  _apply('custom', () => _applyCustomCmds(ss, m));

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

/// Sub-percent resolution for the synthetic CPU counter below; any value works
/// as long as it is the same for the busy and idle halves, since [Cpus] only
/// ever looks at their ratio.
const _kCpuScale = 1000;

/// monitor's `CpuCoreTime.used`/`total` cannot be handed to [Cpus] directly.
/// [Cpus] divides by the `total` delta between two samples, which is right for
/// Linux's cumulative `/proc/stat` ticks but zero for the constant-scale
/// one-shot percentages the agent produces on Bsd/Windows/macOS — that
/// division yielded ±Infinity for user/sys/io and a flat 100% idle.
///
/// monitor already resolves the platform ambiguity and ships the answer as
/// `usage_percent`, so accumulate that into a synthetic monotonic counter.
/// This is the same convention `_accumulateWindowsCpu` uses in
/// `server_status_update_req.dart` for Windows' instantaneous source. All busy
/// time lands in `user` because monitor carries no user/sys/nice/iowait/irq/
/// softirq breakdown; those stay 0, as they already do on the Windows path.
void _applyCpu(ServerStatus ss, MonitorMetrics m) {
  final percents = _cpuPercents(m);
  if (percents == null) return;

  // Index 0 of the previous sample is the "cpu" summary; per-core starts at 1
  final prev = ss.cpu.now;
  var totalUsed = 0;
  var totalIdle = 0;
  final perCore = <SingleCpuCore>[];
  for (var i = 0; i < percents.length; i++) {
    final p = i + 1 < prev.length ? prev[i + 1] : null;
    final used = (p?.user ?? 0) + (percents[i] * _kCpuScale).round();
    final idle = (p?.idle ?? 0) + ((100 - percents[i]) * _kCpuScale).round();
    totalUsed += used;
    totalIdle += idle;
    perCore.add(SingleCpuCore('cpu$i', used, 0, 0, idle, 0, 0, 0));
  }
  ss.cpu.update([
    SingleCpuCore('cpu', totalUsed, 0, 0, totalIdle, 0, 0, 0),
    ...perCore,
  ]);

  final brand = m.cpuBrand;
  if (brand != null && brand.isNotEmpty) {
    ss.cpu.brand.clear();
    ss.cpu.brand[brand] = percents.length;
  }
}

/// One reading per core, or null when this sample says nothing usable.
///
/// The per-core list is preferred; an agent that predates it reports only the
/// aggregate `cpu_usage`, and a single synthetic core carrying that is what
/// keeps the top-line percentage moving instead of the page showing the last
/// figure a newer agent happened to send. Which is what returning early on an
/// empty list did: `ss.cpu` kept its previous sample, and the history buffer
/// then recorded that stale percentage as the current one.
///
/// Null, not an empty list, when a core has no reading at all: the agent
/// reports that on its first Linux cycle, before it has a baseline, and
/// accumulating a fabricated 0 would draw a dip that never happened.
List<double>? _cpuPercents(MonitorMetrics m) {
  if (m.cpuCores.isEmpty) {
    return [m.cpuUsage.clamp(0.0, 100.0)];
  }
  final percents = <double>[];
  for (final c in m.cpuCores) {
    final p = c.usagePercent;
    if (p == null) return null;
    percents.add(p.clamp(0.0, 100.0));
  }
  return percents;
}

/// monitor reports memory, swap and disk sizes in **bytes**
/// (`adapt_memory`/`disk_details` multiply the parsed KiB by 1024), while the
/// app's [Memory]/[Swap]/[Disk] carry the KiB their `/proc/meminfo` and
/// `df -k` sources produce. Passing bytes straight through rendered a 64 GiB
/// host as "64 TB".
int _toKib(int bytes) => bytes ~/ 1024;

/// monitor doesn't report `avail` separately from `used`; `avail` is derived
/// as `total - used`, which reproduces monitor's own `usage_percent` exactly.
void _applyMemory(ServerStatus ss, MonitorMetrics m) {
  ss.mem = Memory(
    total: _toKib(m.memory.total),
    free: _toKib(m.memory.free),
    avail: _toKib(m.memory.total - m.memory.used),
  );
}

/// monitor doesn't report swap `cached`; set to 0 (unused by any current UI
/// beyond a debug display).
void _applySwap(ServerStatus ss, MonitorMetrics m) {
  ss.swap = Swap(
    total: _toKib(m.swap.total),
    free: _toKib(m.swap.total - m.swap.used),
    cached: 0,
  );
}

/// The per-mount list where the agent sends one, and the aggregate otherwise.
///
/// An agent predating `disk_details` reports only totals, and mapping the
/// detail list alone left those servers showing no disks at all rather than
/// the one figure they do report. The synthetic entry is named `/` because
/// that is what the aggregate is a total of, and nothing downstream reads a
/// mount as a path to anything.
void _applyDisks(ServerStatus ss, MonitorMetrics m) {
  if (m.diskDetails.isEmpty) {
    final total = m.disk.total;
    ss.disk = total <= 0
        ? const []
        : [
            Disk(
              path: '/',
              mount: '/',
              usedPercent: m.disk.usagePercent.round(),
              used: BigInt.from(_toKib(m.disk.used)),
              size: BigInt.from(_toKib(total)),
              avail: BigInt.from(_toKib(m.disk.free)),
            ),
          ];
  } else {
    ss.disk = m.diskDetails
        .map(
          (d) => Disk(
            path: d.path,
            fsTyp: d.fsType,
            mount: d.mount,
            usedPercent: d.usagePercent.round(),
            used: BigInt.from(_toKib(d.used)),
            size: BigInt.from(_toKib(d.total)),
            avail: BigInt.from(_toKib(d.total - d.used)),
          ),
        )
        .toList();
  }
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

/// Every sensor the agent reported, keyed by device.
///
/// Falls back to the single aggregate `temperature` for agents predating the
/// per-sensor list, stored under a recognized CPU-temp key so
/// `Temperatures.first` still picks it up.
void _applyTemps(ServerStatus ss, MonitorMetrics m) {
  if (m.temps.isNotEmpty) {
    ss.temps.setAll({for (final t in m.temps) t.device: t.value});
    return;
  }
  final t = m.temperature;
  if (t == null) return;
  ss.temps.setAll({'cpu_thermal': t});
}

/// The agent's flattened `gpus`, split back into the two lists the status page
/// draws.
///
/// It was decoded and then dropped: a server reached over the agent showed no
/// GPU card at all, while the same machine over SSH showed every one of them.
/// Which list a card belongs in is [MonitorGpuMetrics.isAmd].
///
/// `fanSpeed` and `clockSpeed` are 0 because the agent carries neither — the
/// same kind of known, stated loss as SMART's `rawData`. Null rather than an
/// empty list when the agent reports none, since that is what the status page
/// reads as "this machine has no card".
void _applyGpus(ServerStatus ss, MonitorMetrics m) {
  if (m.gpus.isEmpty) {
    ss.nvidia = null;
    ss.amd = null;
    return;
  }
  final nvidia = <NvidiaSmiItem>[];
  final amd = <AmdSmiItem>[];
  for (final g in m.gpus) {
    if (g.isAmd) {
      amd.add(
        AmdSmiItem(
          name: g.name,
          temp: g.temperature,
          power: g.power,
          memory: AmdSmiMem(g.memoryTotal, g.memoryUsed, g.memoryUnit, const []),
          utilization: g.usagePercent.round(),
          fanSpeed: 0,
          clockSpeed: 0,
        ),
      );
    } else {
      nvidia.add(
        NvidiaSmiItem(
          name: g.name,
          temp: g.temperature,
          power: g.power,
          memory: NvidiaSmiMem(
            g.memoryTotal,
            g.memoryUsed,
            g.memoryUnit,
            const [],
          ),
          percent: g.usagePercent.round(),
          fanSpeed: 0,
        ),
      );
    }
  }
  ss.nvidia = nvidia.isEmpty ? null : nvidia;
  ss.amd = amd.isEmpty ? null : amd;
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
  // Absent on an agent predating the field, where the prose is all there is;
  // left as it was rather than cleared, for the same reason as the SSH path.
  final osId = m.osId;
  if (osId != null && osId.isNotEmpty) {
    ss.osId = osId;
    // Written together and only here, exactly as the SSH path does it: an
    // empty `os_id_like` means "declares no parent" when `os_id` is there to
    // say the file was read, and "nothing was read" when it is not. Assigned
    // rather than skipped-when-empty, or a host that stopped being a
    // derivative kept the parent it used to declare and `resolveDist` fell
    // through to it whenever the new id was one this build does not know.
    ss.osIdLike = m.osIdLike;
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
/// machinery. Reusing the same delta path the SSH path already uses keeps
/// rate computation single-sourced.
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

/// The same commands the SSH path reads out of the status script's output,
/// arriving already split by the agent. Order is the agent's, which is the
/// order the files run in, which is the order the user arranged.
void _applyCustomCmds(ServerStatus ss, MonitorMetrics m) {
  ss.customCmds.clear();
  for (final c in m.customCmds) {
    ss.customCmds[c.name] = c.output;
  }
}
