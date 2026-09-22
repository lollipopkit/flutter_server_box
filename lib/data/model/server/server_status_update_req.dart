import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/app/scripts/script_consts.dart';
import 'package:server_box/data/model/server/amd.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/gpu.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/nvdia.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';
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

  const ServerStatusUpdateReq({
    required this.system,
    required this.ss,
    required this.parsedOutput,
    this.tempDivisor = 1000.0,
  });
}

/// Parsing lives in the shared Rust library `sbm_parser`; this
/// file only assembles the FFI JSON into models and updates windowed state
/// (cpu/netSpeed/diskIO).
Future<ServerStatus> getStatus(ServerStatusUpdateReq req) async {
  final ss = _createWorkingStatus(req.ss, req.system);
  final systemStr = switch (req.system) {
    SystemType.linux => 'linux',
    SystemType.bsd => 'bsd',
    SystemType.windows => 'windows',
  };

  final statusJson = await ffi.parseStatusJson(
    system: systemStr,
    raw: req.parsedOutput,
    tempDivisor: req.tempDivisor,
  );
  final status = jsonDecode(statusJson) as Map<String, dynamic>;

  final time =
      int.tryParse(StatusCmdType.time.findInMap(req.parsedOutput).trim()) ??
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  // Parse each segment independently so one failure does not discard results
  // from the other segments.
  _apply(ss, 'cpu', () => _applyCpu(ss, status, req.system));
  _apply(ss, 'mem', () => _applyMemory(ss, status));
  _apply(ss, 'swap', () => _applySwap(ss, status));
  _apply(ss, 'disk', () => _applyDisks(ss, status));
  _apply(ss, 'net', () => _applyNet(ss, status, req, time));
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
  Map<String, dynamic> status,
  Map<String, String> raw,
  SystemType system,
) {
  void check(List<String> cmds, List<String> sections, bool parsed) {
    if (parsed) return;
    final said = cmds
        .map((cmd) => raw[cmd]?.trim() ?? '')
        .firstWhere((text) => text.isNotEmpty, orElse: () => '');
    if (said.isEmpty) return;
    final reason = _reasonOf(said);
    for (final section in sections) {
      // A parse that threw said something more specific about this section and
      // has already recorded it.
      ss.sectionErrs.putIfAbsent(section, () => reason);
    }
  }

  bool list(String key) => (status[key] as List?)?.isNotEmpty ?? false;

  check(const ['cpu'], const ['cpu'], list('cpu'));
  check(const ['mem'], const ['mem', 'swap'], status['mem'] != null);
  check(const ['disk'], const ['disk'], list('disks'));
  // Windows' interface counters are a second parse of the same segment, and
  // the shared one is empty there by design — asking it would report every
  // Windows host's network as unreadable.
  if (system != SystemType.windows) {
    check(const ['net'], const ['net'], list('net'));
  }
  check(const ['diskio'], const ['diskio'], list('diskio'));
  check(
    const ['tempType', 'tempVal', 'temp'],
    const ['temps'],
    (status['temps'] as Map?)?.isNotEmpty ?? false,
  );
  check(const ['battery'], const ['battery'], list('batteries'));
  check(const ['sensors'], const ['sensors'], list('sensors'));
  check(const ['gpu'], const ['gpus'], list('gpus'));
  check(const ['nvidia'], const ['nvidia'], list('nvidia'));
  check(const ['diskSmart'], const ['smart'], list('disk_smart'));
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

List<SingleCpuCore> _coresFromJson(List cores) {
  return cores
      .map(
        (c) => SingleCpuCore(
          c['id'] as String,
          c['user'] as int,
          c['sys'] as int,
          c['nice'] as int,
          c['idle'] as int,
          c['iowait'] as int,
          c['irq'] as int,
          c['softirq'] as int,
        ),
      )
      .toList();
}

void _applyCpu(ServerStatus ss, Map<String, dynamic> status, SystemType system) {
  var cores = _coresFromJson(status['cpu'] as List);
  if (cores.isEmpty) return;

  if (system == SystemType.windows) {
    // Windows provides instantaneous percentages only. Add them to the previous
    // pseudo-counters to simulate cumulative ticks.
    cores = _accumulateWindowsCpu(cores, ss.cpu.now);
  }
  ss.cpu.update(cores);

  final brand = status['cpu_brand'] as List;
  if (brand.isNotEmpty) {
    ss.cpu.brand.clear();
    for (final entry in brand) {
      ss.cpu.brand[entry[0] as String] = entry[1] as int;
    }
  }
}

List<SingleCpuCore> _accumulateWindowsCpu(
  List<SingleCpuCore> fresh,
  List<SingleCpuCore> prev,
) {
  // The first entry in `fresh` and `prev` is the CPU summary; per-core entries
  // start at index 1.
  final cores = <SingleCpuCore>[];
  var totalUser = 0;
  var totalIdle = 0;
  for (var i = 1; i < fresh.length; i++) {
    final p = i < prev.length ? prev[i] : null;
    final user = (p?.user ?? 0) + fresh[i].user;
    final idle = (p?.idle ?? 0) + fresh[i].idle;
    totalUser += user;
    totalIdle += idle;
    cores.add(SingleCpuCore(fresh[i].id, user, 0, 0, idle, 0, 0, 0));
  }
  cores.insert(0, SingleCpuCore('cpu', totalUser, 0, 0, totalIdle, 0, 0, 0));
  return cores;
}

void _applyMemory(ServerStatus ss, Map<String, dynamic> status) {
  final mem = status['mem'];
  if (mem == null) return;
  ss.mem = Memory(
    total: mem['total'] as int,
    free: mem['free'] as int,
    avail: mem['avail'] as int,
  );
}

void _applySwap(ServerStatus ss, Map<String, dynamic> status) {
  final swap = status['swap'];
  if (swap == null) return;
  ss.swap = Swap(
    total: swap['total'] as int,
    free: swap['free'] as int,
    cached: swap['cached'] as int,
  );
}

Disk _diskFromJson(Map<String, dynamic> d) {
  return Disk(
    path: d['path'] as String,
    fsTyp: d['fs_type'] as String?,
    mount: d['mount'] as String,
    usedPercent: d['used_percent'] as int,
    used: BigInt.from(d['used'] as int),
    size: BigInt.from(d['size'] as int),
    avail: BigInt.from(d['avail'] as int),
    name: d['name'] as String?,
    kname: d['kname'] as String?,
    uuid: d['uuid'] as String?,
    children: (d['children'] as List)
        .map((c) => _diskFromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

void _applyDisks(ServerStatus ss, Map<String, dynamic> status) {
  ss.disk = (status['disks'] as List)
      .map((d) => _diskFromJson(d as Map<String, dynamic>))
      .toList();
  try {
    ss.diskUsage = ss.disk.isEmpty ? null : DiskUsage.parse(ss.disk);
  } catch (e, s) {
    Loggers.app.warning(e, s);
  }
}

void _applyNet(
  ServerStatus ss,
  Map<String, dynamic> status,
  ServerStatusUpdateReq req,
  int time,
) {
  final List<NetSpeedPart> parts;
  if (req.system == SystemType.windows) {
    // Windows network speed comes from a two-sample WMI delta; the FFI returns
    // the rates directly.
    final speedsJson = ffi.parseWindowsNetSpeedJson(
      raw: WindowsStatusCmdType.net.findInMap(req.parsedOutput),
    );
    parts = (jsonDecode(speedsJson) as List)
        .map(
          (s) => NetSpeedPart(
            s['name'] as String,
            BigInt.from((s['rx'] as num).toInt()),
            BigInt.from((s['tx'] as num).toInt()),
            time,
          ),
        )
        .toList();
  } else {
    parts = (status['net'] as List)
        .map(
          (n) => NetSpeedPart(
            n['device'] as String,
            BigInt.from(n['rx_bytes'] as int),
            BigInt.from(n['tx_bytes'] as int),
            time,
          ),
        )
        .toList();
  }
  if (parts.isNotEmpty) {
    ss.netSpeed.update(parts);
  }
}

void _applyTemps(ServerStatus ss, Map<String, dynamic> status) {
  final temps = status['temps'] as Map<String, dynamic>;
  ss.temps.setAll(temps.map((k, v) => MapEntry(k, (v as num).toDouble())));
}

void _applyConn(ServerStatus ss, Map<String, dynamic> status) {
  final conn = status['conn'];
  if (conn == null) return;
  ss.tcp = Conn(maxConn: conn['max_conn'] as int, fail: conn['fail'] as int);
}

void _applyMore(ServerStatus ss, Map<String, dynamic> status) {
  final sys = status['sys'] as String?;
  if (sys != null && sys.isNotEmpty) {
    ss.more[StatusCmdType.sys] = sys;
  }
  // Both absent on BSD and Windows, and on a Linux old enough to have no
  // `/etc/os-release`; left as they were rather than cleared, so a poll that
  // failed to read the file does not throw away what the last one found.
  final osId = status['os_id'] as String?;
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
    //
    // `whereType`, not `cast`. A cast is a lazy view: a non-String element is
    // found at the first iteration, which is `resolveDist` — reached from
    // `DistIconOf` while the tree is building, so a malformed value would
    // throw there instead of being caught by the section guard around this.
    ss.osIdLike =
        (status['os_id_like'] as List?)?.whereType<String>().toList() ??
        const [];
  }
  // Left alone when the section is absent rather than cleared: this refreshes
  // on the extended cadence, so most polls carry no `ips` at all and clearing
  // would blank the globe's answer between two extended runs.
  final ips = (status['ips'] as List?)?.whereType<String>().toList();
  if (ips != null && ips.isNotEmpty) ss.ips = ips;

  final host = status['host'] as String?;
  if (host != null && !host.contains(ScriptConstants.scriptFile)) {
    ss.more[StatusCmdType.host] = host;
  }
  final uptime = status['uptime'] as String?;
  if (uptime != null && uptime.isNotEmpty) {
    ss.more[StatusCmdType.uptime] = uptime;
  }
}

void _applyDiskIO(
  ServerStatus ss,
  Map<String, dynamic> status,
  SystemType system,
  int time,
) {
  final pieces = (status['diskio'] as List)
      .map(
        (p) => DiskIOPiece(
          dev: p['dev'] as String,
          sectorsRead: p['sectors_read'] as int,
          sectorsWrite: p['sectors_write'] as int,
          time: time,
        ),
      )
      .toList();
  if (pieces.isNotEmpty) {
    ss.diskIO.updateForSystem(pieces, system);
  }
}

void _applyBatteries(ServerStatus ss, Map<String, dynamic> status) {
  final batteries = (status['batteries'] as List)
      .map(
        (b) => Battery(
          percent: b['percent'] as int?,
          status: BatteryStatus.values.byName(b['status'] as String),
          name: b['name'] as String?,
          cycle: b['cycle'] as int?,
          tech: b['tech'] as String?,
        ),
      )
      .toList();
  ss.batteries.clear();
  ss.batteries.addAll(batteries);
}

void _applySensors(ServerStatus ss, Map<String, dynamic> status) {
  final sensors = (status['sensors'] as List).map((s) {
    final details = <String, String>{};
    for (final pair in s['details'] as List) {
      details[pair[0] as String] = pair[1] as String;
    }
    return SensorItem(
      device: s['device'] as String,
      adapter: SensorAdaptor.parse(s['adapter'] as String),
      details: details,
    );
  }).toList();
  if (sensors.isNotEmpty) {
    ss.sensors.clear();
    ss.sensors.addAll(sensors);
  }
}

GpuMemProcessJson _gpuProcess(Map<String, dynamic> p) => (
  pid: p['pid'] as int,
  name: p['name'] as String,
  memory: p['memory'] as int,
);

typedef GpuMemProcessJson = ({int pid, String name, int memory});

void _applyNvidia(ServerStatus ss, Map<String, dynamic> status) {
  ss.nvidia = (status['nvidia'] as List).map((g) {
    final mem = g['memory'] as Map<String, dynamic>?;
    return NvidiaSmiItem(
      name: g['name'] as String,
      temp: g['temp'] as int?,
      power: g['power'] as String?,
      percent: g['percent'] as int?,
      fanSpeed: g['fan_speed'] as int?,
      memory: mem == null
          ? null
          : NvidiaSmiMem(
              mem['total'] as int,
              mem['used'] as int,
              mem['unit'] as String,
              (mem['processes'] as List).map((p) {
                final proc = _gpuProcess(p as Map<String, dynamic>);
                return NvidiaSmiMemProcess(proc.pid, proc.name, proc.memory);
              }).toList(),
            ),
    );
  }).toList();
}

void _applyAmd(ServerStatus ss, Map<String, dynamic> status) {
  ss.amd = (status['amd'] as List).map((g) {
    final mem = g['memory'] as Map<String, dynamic>?;
    return AmdSmiItem(
      name: g['name'] as String,
      temp: g['temp'] as int?,
      power: g['power'] as String?,
      utilization: g['utilization'] as int?,
      fanSpeed: g['fan_speed'] as int?,
      clockSpeed: g['clock_speed'] as int?,
      memory: mem == null
          ? null
          : AmdSmiMem(
              mem['total'] as int,
              mem['used'] as int,
              mem['unit'] as String,
              (mem['processes'] as List).map((p) {
                final proc = _gpuProcess(p as Map<String, dynamic>);
                return AmdSmiMemProcess(proc.pid, proc.name, proc.memory);
              }).toList(),
            ),
    );
  }).toList();
}

void _applyGpus(ServerStatus ss, Map<String, dynamic> status) {
  ss.gpus = (status['gpus'] as List)
      .map((gpu) => GpuItem.fromJson(gpu as Map<String, dynamic>))
      .toList();
}

void _applySmart(ServerStatus ss, Map<String, dynamic> status) {
  ss.diskSmart = (status['disk_smart'] as List).map((d) {
    final attrs = <String, SmartAttribute>{};
    (d['smart_attributes'] as Map<String, dynamic>).forEach((name, a) {
      final flags = a['flags'] as Map<String, dynamic>;
      attrs[name] = SmartAttribute(
        id: a['id'] as int?,
        name: a['name'] as String,
        value: a['value'] as int?,
        worst: a['worst'] as int?,
        thresh: a['thresh'] as int?,
        whenFailed: a['when_failed'] as String?,
        rawValue: a['raw_value'],
        rawString: a['raw_string'] as String?,
        flags: SmartAttributeFlags(
          value: flags['value'] as int?,
          string: flags['string'] as String?,
          prefailure: flags['prefailure'] as bool,
          updatedOnline: flags['updated_online'] as bool,
          performance: flags['performance'] as bool,
          errorRate: flags['error_rate'] as bool,
          eventCount: flags['event_count'] as bool,
          autoKeep: flags['auto_keep'] as bool,
        ),
      );
    });
    return DiskSmart(
      device: d['device'] as String,
      healthy: d['healthy'] as bool?,
      temperature: (d['temperature'] as num?)?.toDouble(),
      model: d['model'] as String?,
      serial: d['serial'] as String?,
      powerOnHours: d['power_on_hours'] as int?,
      powerCycleCount: d['power_cycle_count'] as int?,
      rawData: d['raw_data'] as Map<String, dynamic>,
      smartAttributes: attrs,
    );
  }).toList();
}
