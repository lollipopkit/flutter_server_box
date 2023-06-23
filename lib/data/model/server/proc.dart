// Models for `ps -aux`

// Each line
import 'dart:convert';

class Proc {
  final String user;
  final int pid;
  final double cpu;
  final double mem;
  final String vsz;
  final String rss;
  final String tty;
  final String stat;
  final String start;
  final String time;
  final String command;

  Proc({
    required this.user,
    required this.pid,
    required this.cpu,
    required this.mem,
    required this.vsz,
    required this.rss,
    required this.tty,
    required this.stat,
    required this.start,
    required this.time,
    required this.command,
  });

  factory Proc.parse(String raw) {
    final parts = raw.split(RegExp(r'\s+'));
    return Proc(
      user: parts[0],
      pid: int.parse(parts[1]),
      cpu: double.parse(parts[2]),
      mem: double.parse(parts[3]),
      vsz: parts[4],
      rss: parts[5],
      tty: parts[6],
      stat: parts[7],
      start: parts[8],
      time: parts[9],
      command: parts.sublist(10).join(' '),
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
    return const JsonEncoder.withIndent('  ').convert(toJson());
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

  PsResult({
    required this.procs,
    this.error,
  });

  factory PsResult.parse(String raw, {ProcSortMode sort = ProcSortMode.cpu}) {
    final lines = raw.split('\n');
    final procs = <Proc>[];
    var err = '';
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      try {
        procs.add(Proc.parse(line));
      } catch (e) {
        err += '$line: $e\n';
      }
    }
    switch (sort) {
      case ProcSortMode.cpu:
        procs.sort((a, b) => b.cpu.compareTo(a.cpu));
        break;
      case ProcSortMode.mem:
        procs.sort((a, b) => b.mem.compareTo(a.mem));
        break;
      case ProcSortMode.pid:
        procs.sort((a, b) => a.pid.compareTo(b.pid));
        break;
      case ProcSortMode.user:
        procs.sort((a, b) => a.user.compareTo(b.user));
        break;
    }
    return PsResult(procs: procs, error: err.isEmpty ? null : err);
  }
}

enum ProcSortMode {
  cpu,
  mem,
  pid,
  user;
}
