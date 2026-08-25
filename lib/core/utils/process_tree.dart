import 'dart:async';
import 'dart:io';

final class ProcessTree {
  const ProcessTree._();

  static Future<int?> groupId(Process process) async {
    if (Platform.isWindows) return null;
    try {
      final result = await Process.run('ps', [
        '-o',
        'pgid=',
        '-p',
        '${process.pid}',
      ]).timeout(const Duration(seconds: 1));
      if (result.exitCode != 0) return null;
      return int.tryParse('${result.stdout}'.trim());
    } catch (_) {
      return null;
    }
  }

  static void terminate(Process process, int? processGroupId) {
    try {
      if (Platform.isWindows) {
        Process.runSync('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
      } else if (processGroupId != null) {
        Process.killPid(-processGroupId);
      } else {
        _killUnixTree(process.pid, ProcessSignal.sigterm);
      }
    } catch (_) {}
    process.kill(ProcessSignal.sigterm);
    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
      try {
        if (!Platform.isWindows && processGroupId != null) {
          Process.killPid(-processGroupId, ProcessSignal.sigkill);
        } else if (!Platform.isWindows) {
          _killUnixTree(process.pid, ProcessSignal.sigkill);
        }
      } catch (_) {}
    });
  }

  static void _killUnixTree(int rootPid, ProcessSignal signal) {
    final result = Process.runSync('ps', ['-eo', 'pid=', 'ppid=']);
    if (result.exitCode != 0) return;
    final children = <int, List<int>>{};
    for (final line in '${result.stdout}'.split('\n')) {
      final fields = line.trim().split(RegExp(r'\s+'));
      if (fields.length != 2) continue;
      final pid = int.tryParse(fields[0]);
      final parent = int.tryParse(fields[1]);
      if (pid == null || parent == null) continue;
      children.putIfAbsent(parent, () => []).add(pid);
    }

    void kill(int pid) {
      for (final child in children[pid] ?? const <int>[]) {
        kill(child);
      }
      try {
        Process.killPid(pid, signal);
      } catch (_) {}
    }

    kill(rootPid);
  }
}
