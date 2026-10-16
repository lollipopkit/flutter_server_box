import 'dart:async';
import 'dart:io';

final class ProcessTree {
  const ProcessTree._();

  /// The process group [process] leads, or null when it does not lead one.
  ///
  /// The distinction is the whole of it. `Process.start` does not put a child
  /// in a group of its own — it inherits this app's — so the group id read off
  /// one is this app's own, and `killPid(-that)` signals **every process in
  /// it**, this app included. Cancelling a local command would have killed the
  /// app that asked.
  ///
  /// So the id is returned only when the child is the group leader, which is
  /// the one case where the group contains it and its descendants and nothing
  /// else. Anywhere else the caller walks the tree by parent instead, which is
  /// slower and reaches only what it should.
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
      final pgid = int.tryParse('${result.stdout}'.trim());
      return pgid == process.pid ? pgid : null;
    } catch (_) {
      return null;
    }
  }

  /// Ends [process] and what it started. Asynchronous: `taskkill` and `ps`
  /// are processes of their own, and waiting on one synchronously would hold
  /// the UI isolate. The tree is signalled before its root, whose end would
  /// leave the descendants to init and out of reach.
  static Future<void> terminate(Process process, int? processGroupId) async {
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']).timeout(_toolTimeout);
      } else if (processGroupId != null) {
        Process.killPid(-processGroupId);
      } else {
        await _killUnixTree(process.pid, ProcessSignal.sigterm);
      }
    } catch (_) {}
    process.kill(ProcessSignal.sigterm);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    try {
      process.kill(ProcessSignal.sigkill);
    } catch (_) {}
    try {
      if (!Platform.isWindows && processGroupId != null) {
        Process.killPid(-processGroupId, ProcessSignal.sigkill);
      } else if (!Platform.isWindows) {
        await _killUnixTree(process.pid, ProcessSignal.sigkill);
      }
    } catch (_) {}
  }

  static const _toolTimeout = Duration(seconds: 5);

  static Future<void> _killUnixTree(int rootPid, ProcessSignal signal) async {
    // One comma-separated format, not two arguments. BSD `ps` — which is the
    // one on macOS — reads the second as a file and refuses with "illegal
    // argument: ppid=", so this returned without killing anything at all and
    // the descendants it exists to reach went on running.
    final result = await Process.run('ps', ['-eo', 'pid=,ppid=']).timeout(_toolTimeout);
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
