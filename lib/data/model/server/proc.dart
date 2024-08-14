import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/res/misc.dart';

class _ProcValIdxMap {
  final int pid;
  final int? user;
  final int? cpu;
  final int? mem;
  final int? vsz;
  final int? rss;
  final int? tty;
  final int? stat;
  final int? start;
  final int? time;
  final int command;

  const _ProcValIdxMap({
    required this.pid,
    this.user,
    this.cpu,
    this.mem,
    this.vsz,
    this.rss,
    this.tty,
    this.stat,
    this.start,
    this.time,
    required this.command,
  });
}

/// Some field can be null due to incompatible format on `BSD` and `Alpine`
class Proc {
  final String? user;
  final int pid;
  final double? cpu;
  final double? mem;
  final String? vsz;
  final String? rss;
  final String? tty;
  final String? stat;
  final String? start;
  final String? time;
  final String command;

  const Proc({
    this.user,
    required this.pid,
    this.cpu,
    this.mem,
    this.vsz,
    this.rss,
    this.tty,
    this.stat,
    this.start,
    this.time,
    required this.command,
  });

  factory Proc._parse(String raw, _ProcValIdxMap map) {
    final parts = raw.split(RegExp(r'\s+'));
    return Proc(
      user: map.user == null ? null : parts[map.user!],
      pid: int.parse(parts[map.pid]),
      cpu: map.cpu == null ? null : double.parse(parts[map.cpu!]),
      mem: map.mem == null ? null : double.parse(parts[map.mem!]),
      vsz: map.vsz == null ? null : parts[map.vsz!],
      rss: map.rss == null ? null : parts[map.rss!],
      tty: map.tty == null ? null : parts[map.tty!],
      stat: map.stat == null ? null : parts[map.stat!],
      start: map.start == null ? null : parts[map.start!],
      time: map.time == null ? null : parts[map.time!],
      command: parts.sublist(map.command).join(' '),
    );
  }

  Map toJson() {
    return {
      'user': user,
      'pid': pid,
      'cpu': cpu,
      'mem': mem,
      'vsz': vsz,
      'rss': rss,
      'tty': tty,
      'stat': stat,
      'start': start,
      'time': time,
      'command': command,
    };
  }

  @override
  String toString() {
    return Miscs.jsonEncoder.convert(toJson());
  }

  String get binary {
    final parts = command.split(' ');
    return parts[0];
  }
}

// `ps -aux` result
class PsResult {
  final List<Proc> procs;
  final String? error;

  const PsResult({
    required this.procs,
    this.error,
  });

  factory PsResult.parse(String raw, {ProcSortMode sort = ProcSortMode.cpu}) {
    final lines = raw.split('\n').map((e) => e.trim()).toList();
    if (lines.isEmpty) return const PsResult(procs: [], error: null);

    final header = lines[0];
    final parts = header.split(RegExp(r'\s+'));
    parts.removeWhere((element) => element.isEmpty);
    final map = _ProcValIdxMap(
      pid: parts.indexOfOrNull('PID')!,
      user: parts.indexOfOrNull('USER'),
      cpu: parts.indexOfOrNull('%CPU'),
      mem: parts.indexOfOrNull('%MEM'),
      vsz: parts.indexOfOrNull('VSZ'),
      rss: parts.indexOfOrNull('RSS'),
      tty: parts.indexOfOrNull('TTY'),
      stat: parts.indexOfOrNull('STAT'),
      start: parts.indexOfOrNull('START'),
      time: parts.indexOfOrNull('TIME'),
      command: parts.indexOfOrNull('COMMAND') ?? parts.indexOfOrNull('CMD')!,
    );

    final procs = <Proc>[];
    final errs = <String>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      try {
        procs.add(Proc._parse(line, map));
      } catch (e, trace) {
        errs.add('$line: $e');
        Loggers.app.warning('Process failed', e, trace);
      }
    }

    switch (sort) {
      case ProcSortMode.cpu:
        procs.sort((a, b) => b.cpu?.compareTo(a.cpu ?? 0) ?? 0);
        break;
      case ProcSortMode.mem:
        procs.sort((a, b) => b.mem?.compareTo(a.mem ?? 0) ?? 0);
        break;
      case ProcSortMode.pid:
        procs.sort((a, b) => a.pid.compareTo(b.pid));
        break;
      case ProcSortMode.user:
        procs.sort((a, b) => a.user?.compareTo(b.user ?? '') ?? 0);
        break;
      case ProcSortMode.name:
        procs.sort((a, b) => a.binary.compareTo(b.binary));
        break;
    }
    return PsResult(procs: procs, error: errs.isEmpty ? null : errs.join('\n'));
  }
}

enum ProcSortMode {
  cpu,
  mem,
  pid,
  user,
  name,
  ;
}

extension _StrIndex on List<String> {
  int? indexOfOrNull(String val) {
    final idx = indexOf(val);
    return idx == -1 ? null : idx;
  }
}
