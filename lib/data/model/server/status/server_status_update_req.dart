import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/server/block_device.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/status/amd.dart';
import 'package:server_box/data/model/server/status/battery.dart';
import 'package:server_box/data/model/server/status/conn.dart';
import 'package:server_box/data/model/server/status/cpu.dart';
import 'package:server_box/data/model/server/status/disk.dart';
import 'package:server_box/data/model/server/status/disk_smart.dart';
import 'package:server_box/data/model/server/status/gpu.dart';
import 'package:server_box/data/model/server/status/memory.dart';
import 'package:server_box/data/model/server/status/net_speed.dart';
import 'package:server_box/data/model/server/status/nvdia.dart';
import 'package:server_box/data/model/server/status/sensors.dart';
import 'package:server_box/data/model/server/status/temp.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/res/status.dart';
import 'package:server_box/src/rust/api/parser.dart' as ffi;
import 'package:server_box/src/rust/api/script.dart' as script_ffi;

class ServerStatusUpdateReq {
  final ServerStatus ss;

  /// The script's sections, in the order it printed them — see
  /// `parse_script_segments`. Custom commands are read out in that order, so
  /// this must not be rebuilt as an unordered map on the way here.
  final Map<String, String> parsedOutput;
  final SystemType system;
  final double tempDivisor;

  /// [ServerCustom.diskCountsNetwork].
  final bool diskCountsNetwork;

  const ServerStatusUpdateReq({
    required this.system,
    required this.ss,
    required this.parsedOutput,
    this.tempDivisor = 1000.0,
    this.diskCountsNetwork = false,
  });
}

/// Parsing lives in the shared Rust library `sbm_parser`; this
/// file only assembles the FFI report into models and updates windowed state
/// (cpu/netSpeed/diskIO).
Future<ServerStatus> getStatus(ServerStatusUpdateReq req) async {
  final ss = _createWorkingStatus(req.ss, req.system);
  final systemStr = switch (req.system) {
    SystemType.linux => 'linux',
    SystemType.bsd => 'bsd',
    SystemType.windows => 'windows',
  };

  final status = await ffi.parseStatus(
    system: systemStr,
    raw: req.parsedOutput,
    tempDivisor: req.tempDivisor,
    countNetwork: req.diskCountsNetwork,
  );

  final time =
      int.tryParse(StatusCmdType.time.findInMap(req.parsedOutput).trim()) ??
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // Parse each segment independently so one failure does not discard results
  // from the other segments.
  _apply(ss, 'cpu', () => _applyCpu(ss, status, req.system));
  _apply(ss, 'mem', () => _applyMemory(ss, status));
  _apply(ss, 'swap', () => _applySwap(ss, status));
  _apply(ss, 'disk', () => _applyDisks(ss, status));
  _apply(ss, 'net', () => _applyNet(ss, status, time));
  _apply(ss, 'temps', () => _applyTemps(ss, status));
  _apply(ss, 'conn', () => _applyConn(ss, status));
  _apply(ss, 'more', () => _applyMore(ss, status));
  _apply(ss, 'diskio', () => _applyDiskIO(ss, status, req.system, time));
  _apply(ss, 'battery', () => _applyBatteries(ss, status));
  _apply(ss, 'sensors', () => _applySensors(ss, status));
  _apply(ss, 'nvidia', () => _applyNvidia(ss, status));
  _apply(ss, 'amd', () => _applyAmd(ss, status));
  _apply(ss, 'gpus', () => _applyGpus(ss, status));
  _apply(ss, 'smart', () => _applySmart(ss, status));
  // Taken from what the script printed, not from a list the app holds: the
  // commands live on the server now, so their names and their order are only
  // knowable from the output.
  _apply(ss, 'custom', () {
    for (final e in req.parsedOutput.entries) {
      final name = script_ffi.customResultName(key: e.key);
      if (name == null) continue;
      ss.customCmds[name] = e.value;
    }
  });

  _noteFailedSections(ss, status, req.parsedOutput, req.system);

  return ss;
}

/// How much of a command's complaint is kept as the reason.
///
/// Enough to read the shell's line and the one under it, and no more: this is
/// held per section on every status object, and the section that "failed"
/// might be one whose output the parser simply did not understand — a `sensors`
/// table in a format this build cannot read is kilobytes of it.
const _kSectionErrMaxLines = 5;
const _kSectionErrMaxChars = 500;

String _reasonOf(String said) {
  final lines = said
      .split('\n')
      .map((l) => l.trimRight())
      .where((l) => l.isNotEmpty)
      .take(_kSectionErrMaxLines)
      .join('\n');
  return lines.length <= _kSectionErrMaxChars
      ? lines
      : '${lines.substring(0, _kSectionErrMaxChars)}…';
}

/// Sections whose command said something and whose parse found nothing in it.
///
/// A reading that is not there is two different machines: one that has no such
/// hardware, and one whose command could not run. The status function sends
/// stderr to stdout (see `unix_command` in the shared script builder), so each
/// command's complaint lands inside that command's own segment — which makes
/// the difference between the two a question about the segment rather than a
/// guess about the text. Nothing said and nothing parsed is absence, and the
/// page draws absence. Something said and nothing parsed is a failure, and what
/// was said is the reason the page prints where the reading would be.
///
/// Grouped by command rather than by section: `mem` and `swap` are read out of
/// one `/proc/meminfo`, so neither of them is missing for a reason of its own.
///
/// A command whose failure is routine keeps its own `2>/dev/null` in the
/// manifest and never reaches here — a machine with no thermal zones is not a
/// machine whose temperature could not be read.
void _noteFailedSections(
  ServerStatus ss,
  ffi.StatusReport status,
  Map<String, String> raw,
  SystemType system,
) {
  /// [always]: every machine has one, so an empty segment is a failure too; a
  /// missing one is still a disabled command.
  void check(
    List<String> cmds,
    List<String> sections,
    bool parsed, {
    bool always = false,
  }) {
    if (parsed) return;
    final said = cmds
        .map((cmd) => raw[cmd]?.trim() ?? '')
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    final ran = cmds.any(raw.containsKey);
    if (said.isEmpty && !(always && ran)) return;
    final reason = said.isEmpty ? libL10n.empty : _reasonOf(said);
    for (final section in sections) {
      // A parse that threw said something more specific about this section and
      // has already recorded it.
      ss.sectionErrs.putIfAbsent(section, () => reason);
    }
  }

  check(const ['cpu'], const ['cpu'], status.cpu.isNotEmpty);
  check(
    const ['mem'],
    // Only Linux reads swap, out of the same /proc/meminfo, and a swap that
    // parsed is not failed by a missing MemTotal.
    ['mem', if (system == SystemType.linux && status.swap == null) 'swap'],
    status.mem != null,
    always: true,
  );
  check(const ['disk'], const ['disk'], status.disks.isNotEmpty);
  // Windows' interface counters are a second parse of the same segment, and
  // the shared one is empty there by design — asking it would report every
  // Windows host's network as unreadable.
  if (system != SystemType.windows) {
    check(const ['net'], const ['net'], status.net.isNotEmpty);
  }
  check(const ['diskio'], const ['diskio'], status.diskio.isNotEmpty);
  check(
    const ['tempType', 'tempVal', 'temp'],
    const ['temps'],
    status.temps.isNotEmpty,
  );
  check(const ['battery'], const ['battery'], status.batteries.isNotEmpty);
  check(const ['sensors'], const ['sensors'], status.sensors.isNotEmpty);
  check(const ['gpu'], const ['gpus'], status.gpus.isNotEmpty);
  check(const ['nvidia'], const ['nvidia'], status.nvidia.isNotEmpty);
  check(const ['diskSmart'], const ['smart'], status.diskSmart.isNotEmpty);
}

void _apply(ServerStatus ss, String section, void Function() fn) {
  try {
    fn();
    ss.sectionErrs.remove(section);
  } catch (e, s) {
    Loggers.app.warning('Apply $section failed', e, s);
    // Kept for the row that has no reading because of it. The message is the
    // exception's own: what a section failed on is not something this app can
    // rephrase usefully, and the raw text is what a bug report needs.
    ss.sectionErrs[section] = e.toString();
  }
}

/// Creates a per-refresh working snapshot.
///
/// `cpu`, `netSpeed`, `diskIO` and `history` intentionally reuse the source
/// references because their rolling/history state is needed across refreshes.
/// Leaving `history` out gave every refresh an empty buffer, so the trend
/// charts only ever held the sample taken moments ago — one point, drawn at
/// the left edge.
ServerStatus _createWorkingStatus(ServerStatus source, SystemType system) {
  return ServerStatus(
    history: source.history,
    cpu: Cpus.copy(source.cpu),
    mem: InitStatus.mem,
    disk: const [],
    tcp: const Conn(maxConn: 0, fail: 0),
    netSpeed: NetSpeed.copy(source.netSpeed),
    swap: const Swap(total: 0, free: 0, cached: 0),
    temps: Temperatures(),
    system: system,
    diskIO: DiskIO.copy(source.diskIO),
    diskSmart: const [],
    err: source.err,
  )
  // Carried, not reset. `_applyMore` only writes these when the response has
  // them, on the stated grounds that a poll which could not read
  // `/etc/os-release` should not throw away what the last one found — and that
  // is only true if they start here. Without it every poll of a BSD, a Windows
  // host or a Linux too old for that file cleared the distribution, so the
  // mark beside its name blinked out and came back on the next successful
  // read.
  ..osId = source.osId
  ..osIdLike = source.osIdLike
  // Same reason, and it was missing: `_applyMore` writes `ips` only when the
  // response carried some, so without this a poll whose extended output did
  // not arrive cleared the addresses — and the server dropped off the globe
  // back into the unplaced strip until another extended cycle came round.
  ..ips = source.ips;
}

SingleCpuCore _core(ffi.CpuCore c) => SingleCpuCore(
  c.id,
  c.user.toInt(),
  c.sys.toInt(),
  c.nice.toInt(),
  c.idle.toInt(),
  c.iowait.toInt(),
  c.irq.toInt(),
  c.softirq.toInt(),
);

void _applyCpu(ServerStatus ss, ffi.StatusReport status, SystemType system) {
  var cores = status.cpu.map(_core).toList();
  if (cores.isEmpty) return;

  switch (system) {
    // Both report instantaneous percentages rather than `/proc/stat`'s
    // cumulative ticks, and [Cpus] reads usage off the difference between two
    // samples. Two percentage snapshots each sum to about 100, so taken as
    // counters the window's total moves by nothing, or backwards, and the
    // reading was "none" on most polls. Adding each to the previous
    // pseudo-counter turns them into ticks.
    case SystemType.windows:
      cores = _accumulatePercentCpu(cores.skip(1).toList(), ss.cpu.now);
    case SystemType.bsd:
      // No summary row here: macOS repeats its one aggregate reading per
      // core, and FreeBSD's `-P` gives the cores alone.
      cores = _accumulatePercentCpu(cores, ss.cpu.now);
    case SystemType.linux:
      break;
  }
  ss.cpu.update(cores);

  if (status.cpuBrand.isNotEmpty) {
    ss.cpu.brand.clear();
    for (final (name, count) in status.cpuBrand) {
      ss.cpu.brand[name] = count;
    }
  }
}

/// [fresh] percentage readings for each core, as pseudo-counters: each field
/// added to the same core's field in [prev], with the summary row [Cpus]
/// expects at index 0 rebuilt as the sum of the cores.
///
/// [prev] carries that summary at index 0, so its cores start at 1.
List<SingleCpuCore> _accumulatePercentCpu(
  List<SingleCpuCore> fresh,
  List<SingleCpuCore> prev,
) {
  final cores = <SingleCpuCore>[];
  var user = 0, sys = 0, nice = 0, idle = 0, iowait = 0, irq = 0, softirq = 0;
  for (var i = 0; i < fresh.length; i++) {
    final f = fresh[i];
    final p = i + 1 < prev.length ? prev[i + 1] : null;
    final core = SingleCpuCore(
      f.id,
      (p?.user ?? 0) + f.user,
      (p?.sys ?? 0) + f.sys,
      (p?.nice ?? 0) + f.nice,
      (p?.idle ?? 0) + f.idle,
      (p?.iowait ?? 0) + f.iowait,
      (p?.irq ?? 0) + f.irq,
      (p?.softirq ?? 0) + f.softirq,
    );
    user += core.user;
    sys += core.sys;
    nice += core.nice;
    idle += core.idle;
    iowait += core.iowait;
    irq += core.irq;
    softirq += core.softirq;
    cores.add(core);
  }
  cores.insert(
    0,
    SingleCpuCore('cpu', user, sys, nice, idle, iowait, irq, softirq),
  );
  return cores;
}

void _applyMemory(ServerStatus ss, ffi.StatusReport status) {
  final mem = status.mem;
  if (mem == null) return;
  ss.mem = Memory(total: mem.total.toInt(), free: mem.free.toInt(), avail: mem.avail.toInt());
}

void _applySwap(ServerStatus ss, ffi.StatusReport status) {
  final swap = status.swap;
  if (swap == null) return;
  ss.swap = Swap(total: swap.total.toInt(), free: swap.free.toInt(), cached: swap.cached.toInt());
}

Disk _disk(ffi.Disk d) => Disk(
  path: d.path,
  fsTyp: d.fsType,
  mount: d.mount,
  usedPercent: d.usedPercent,
  used: d.used,
  size: d.size,
  avail: d.avail,
  name: d.name,
  kname: d.kname,
  uuid: d.uuid,
  children: d.children.map(_disk).toList(),
);

BlockDevice _blockDevice(ffi.StatusBlockDevice d) => BlockDevice(
  name: d.name,
  path: d.path,
  kind: d.kind,
  model: d.model,
  size: d.size.toInt(),
  tran: d.tran,
  fsType: d.fsType,
  mount: d.mount,
  inUse: d.inUse,
  children: d.children.map(_blockDevice).toList(),
);

void _applyDisks(ServerStatus ss, ffi.StatusReport status) {
  ss.blockDevices = status.blockDevices.map(_blockDevice).toList();
  ss.disk = status.disks.map(_disk).toList();
  ss.diskUsage = ss.disk.isEmpty ? null : DiskUsage(used: status.diskUsed, size: status.diskSize);
}

/// Cumulative counters on every system, Windows included: the rates are
/// taken across polls by [NetSpeed].
void _applyNet(ServerStatus ss, ffi.StatusReport status, int time) {
  final parts = [for (final n in status.net) NetSpeedPart(n.device, n.rxBytes, n.txBytes, time)];
  if (parts.isNotEmpty) {
    ss.netSpeed.update(parts);
  }
}

void _applyTemps(ServerStatus ss, ffi.StatusReport status) {
  ss.temps.setAll({for (final (name, celsius) in status.temps) name: celsius});
}

void _applyConn(ServerStatus ss, ffi.StatusReport status) {
  final conn = status.conn;
  if (conn == null) return;
  ss.tcp = Conn(maxConn: conn.maxConn, fail: conn.fail);
}

void _applyMore(ServerStatus ss, ffi.StatusReport status) {
  final sys = status.sys;
  if (sys != null && sys.isNotEmpty) {
    ss.more[StatusCmdType.sys] = sys;
  }
  // Both absent on BSD and Windows, and on a Linux old enough to have no
  // `/etc/os-release`; left as they were rather than cleared, so a poll that
  // failed to read the file does not throw away what the last one found.
  final osId = status.osId;
  if (osId != null && osId.isNotEmpty) {
    ss.osId = osId;
    // Written together, and only here. An `ID_LIKE` that came back empty is
    // two different things depending on why: the file said the distribution
    // declares no parent, or the file was never read. `os_id` is the evidence
    // of which — it is only ever set by a successful read — so the parent is
    // replaced when there was one to replace it with, and left alone when the
    // whole section is missing. Without this, a host that stopped being a
    // derivative kept the parent it used to declare, and `resolveDist` fell
    // through to it whenever the new id was one this build does not know.
    ss.osIdLike = status.osIdLike;
  }
  // Left alone when the section is absent rather than cleared: this refreshes
  // on the extended cadence, so most polls carry no `ips` at all and clearing
  // would blank the globe's answer between two extended runs.
  if (status.ips.isNotEmpty) ss.ips = status.ips;

  final host = status.host;
  if (host != null && !host.contains(ScriptConstants.scriptFile)) {
    ss.more[StatusCmdType.host] = host;
  }
  final uptime = status.uptime;
  if (uptime != null && uptime.isNotEmpty) {
    ss.more[StatusCmdType.uptime] = uptime;
  }
}

void _applyDiskIO(
  ServerStatus ss,
  ffi.StatusReport status,
  SystemType system,
  int time,
) {
  final pieces = [
    for (final p in status.diskio)
      DiskIOPiece(dev: p.dev, sectorsRead: p.sectorsRead, sectorsWrite: p.sectorsWrite, time: time),
  ];
  if (pieces.isNotEmpty) {
    ss.diskIO.updateForSystem(pieces, system);
  }
}

void _applyBatteries(ServerStatus ss, ffi.StatusReport status) {
  ss.batteries
    ..clear()
    ..addAll([
      for (final b in status.batteries)
        Battery(
          percent: b.percent,
          status: BatteryStatus.values.byName(b.status.name),
          name: b.name,
          cycle: b.cycle,
          tech: b.tech,
        ),
    ]);
}

void _applySensors(ServerStatus ss, ffi.StatusReport status) {
  final sensors = [
    for (final s in status.sensors)
      SensorItem(
        device: s.device,
        adapter: SensorAdaptor.parse(s.adapter),
        details: {for (final (key, value) in s.details) key: value},
      ),
  ];
  if (sensors.isNotEmpty) {
    ss.sensors
      ..clear()
      ..addAll(sensors);
  }
}

void _applyNvidia(ServerStatus ss, ffi.StatusReport status) {
  ss.nvidia = [
    for (final g in status.nvidia)
      NvidiaSmiItem(
        name: g.name,
        temp: g.temp,
        power: g.power,
        percent: g.percent,
        fanSpeed: g.fanSpeed,
        memory: switch (g.memory) {
          null => null,
          final m => NvidiaSmiMem(m.total, m.used, m.unit, [
            for (final p in m.processes) NvidiaSmiMemProcess(p.pid, p.name, p.memory),
          ]),
        },
      ),
  ];
}

void _applyAmd(ServerStatus ss, ffi.StatusReport status) {
  ss.amd = [
    for (final g in status.amd)
      AmdSmiItem(
        name: g.name,
        temp: g.temp,
        power: g.power,
        utilization: g.utilization,
        fanSpeed: g.fanSpeed,
        clockSpeed: g.clockSpeed,
        memory: switch (g.memory) {
          null => null,
          final m => AmdSmiMem(m.total, m.used, m.unit, [
            for (final p in m.processes) AmdSmiMemProcess(p.pid, p.name, p.memory),
          ]),
        },
      ),
  ];
}

void _applyGpus(ServerStatus ss, ffi.StatusReport status) {
  ss.gpus = [
    for (final g in status.gpus)
      GpuItem(
        id: g.id,
        vendor: g.vendor,
        name: g.name,
        utilization: g.utilization,
        temperature: g.temperature,
        power: g.power,
        fanSpeed: g.fanSpeed,
        clockSpeed: g.clockSpeed,
        memory: switch (g.memory) {
          null => null,
          final m => GpuSmiMem(m.total, m.used, m.unit, [
            for (final p in m.processes) GpuSmiMemProcess(p.pid, p.name, p.memory),
          ]),
        },
      ),
  ];
}

void _applySmart(ServerStatus ss, ffi.StatusReport status) {
  ss.diskSmart = [
    for (final d in status.diskSmart)
      DiskSmart(
        device: d.device,
        healthy: d.healthy,
        temperature: d.temperature,
        model: d.model,
        serial: d.serial,
        powerOnHours: d.powerOnHours,
        powerCycleCount: d.powerCycleCount,
        smartAttributes: {
          for (final a in d.attributes)
            a.name: SmartAttribute(
              id: a.id,
              name: a.name,
              value: a.value,
              worst: a.worst,
              thresh: a.thresh,
              whenFailed: a.whenFailed,
              rawValue: a.rawValue,
              rawString: a.rawString,
              flags: SmartAttributeFlags(
                value: a.flags.value,
                string: a.flags.string,
                prefailure: a.flags.prefailure,
                updatedOnline: a.flags.updatedOnline,
                performance: a.flags.performance,
                errorRate: a.flags.errorRate,
                eventCount: a.flags.eventCount,
                autoKeep: a.flags.autoKeep,
              ),
            ),
        },
      ),
  ];
}
