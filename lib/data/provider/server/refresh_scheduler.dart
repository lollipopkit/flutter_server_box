import 'dart:async';
import 'dart:collection';

typedef ServerRefreshTask = Future<void> Function(String serverId);

/// Coordinates server refresh work across every caller.
///
/// A per-call worker pool is not enough: startup, lifecycle handling and the
/// timer may all ask for a refresh while an earlier request is still running.
/// Each pool can then skip the servers already refreshing and start a different
/// set, making their combined concurrency much larger than any one pool's cap.
///
/// This scheduler owns the single queue instead. Requests for a server that is
/// already queued or active share its future, while requests for other servers
/// wait for one of the global slots.
class ServerRefreshScheduler {
  ServerRefreshScheduler({
    required this.maxConcurrent,
    required ServerRefreshTask refresh,
  }) : assert(maxConcurrent > 0),
       _refresh = refresh;

  final int maxConcurrent;
  final ServerRefreshTask _refresh;

  final Queue<_ServerRefreshJob> _pending = Queue<_ServerRefreshJob>();
  final Map<String, _ServerRefreshJob> _jobs = <String, _ServerRefreshJob>{};
  int _active = 0;

  /// Refreshes [serverIds], sharing work already queued by another request.
  Future<void> refresh(Iterable<String> serverIds) {
    final futures = <Future<void>>[];
    final requested = <String>{};

    for (final serverId in serverIds) {
      if (!requested.add(serverId)) continue;

      var job = _jobs[serverId];
      if (job == null) {
        job = _ServerRefreshJob(serverId);
        _jobs[serverId] = job;
        _pending.add(job);
      }
      futures.add(job.future);
    }

    _drain();
    if (futures.isEmpty) return Future<void>.value();
    return Future.wait(futures);
  }

  void _drain() {
    while (_active < maxConcurrent && _pending.isNotEmpty) {
      final job = _pending.removeFirst();
      _active++;
      unawaited(_run(job));
    }
  }

  Future<void> _run(_ServerRefreshJob job) async {
    try {
      await _refresh(job.serverId);
      job.complete();
    } catch (error, stackTrace) {
      job.completeError(error, stackTrace);
    } finally {
      _active--;
      if (identical(_jobs[job.serverId], job)) {
        _jobs.remove(job.serverId);
      }
      _drain();
    }
  }
}

class _ServerRefreshJob {
  _ServerRefreshJob(this.serverId);

  final String serverId;
  final Completer<void> _completer = Completer<void>();

  Future<void> get future => _completer.future;

  void complete() => _completer.complete();

  void completeError(Object error, StackTrace stackTrace) =>
      _completer.completeError(error, stackTrace);
}
