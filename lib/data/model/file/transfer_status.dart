import 'dart:async';
import 'dart:io';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/local_file_backend.dart';
import 'package:server_box/core/utils/monitor_file_backend.dart';
import 'package:server_box/data/model/file/copy_tree.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/file/transfer_worker.dart';

/// One transfer, and everything a list has to say about it.
class FileTransferStatus {
  FileTransferStatus({
    required this.job,
    required this.notifyListeners,
    this.completer,
  }) : id = _nextId++ {
    if (job.needsIsolate) {
      worker = FileTransferWorker(onNotify: onNotify, job: job);
      unawaited(_initWorker());
    } else {
      unawaited(_runHere());
    }
  }

  /// A counter, not a timestamp.
  ///
  /// `DateTime.now()` advances in millisecond steps on Windows, so two
  /// transfers queued in one tap got the same id — and `get(id)` then threw
  /// out of `singleWhere`, was swallowed, and reported a failed transfer as
  /// having succeeded.
  final int id;

  static int _nextId = 0;

  /// When this was queued. Was read back out of [id] while that was a
  /// timestamp; kept as its own field now that it is not.
  final DateTime startedAt = DateTime.now();

  final FileTransfer job;
  final void Function() notifyListeners;
  final Completer? completer;

  /// Null for a transfer that runs on this isolate, which is the pairs with no
  /// crypto in them.
  FileTransferWorker? worker;

  /// Where the bytes are landing until they are renamed into place, as the
  /// transfer reported it. Null before it opens one and after it renames.
  String? stagingPath;

  String get fileName => job.name;

  double? progress;
  double? speedBytesPerSecond;
  int? transferredBytes;
  DateTime? _speedSampleTime;
  int _speedSampleBytes = 0;
  FileTransferStage? status;
  int? size;
  Exception? error;
  Duration? spentTime;
  bool _disposed = false;

  @override
  bool operator ==(Object other) =>
      other is FileTransferStatus && id == other.id;

  @override
  int get hashCode => id.hashCode;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    // Read before the worker is killed: a transfer that finished has already
    // renamed its staged copy into place and has nothing to clean up.
    final unfinished = status != FileTransferStage.finished;
    worker?.dispose();
    if (unfinished) _discardStaging();
    if (completer?.isCompleted == false) {
      completer?.complete(true);
    }
  }

  /// Whether the inline copy should stop.
  ///
  /// The isolate is stopped by killing it; a copy running here has to be
  /// asked. Without this, cancelling a local copy removed the row and left the
  /// copy running.
  bool get _cancelled => _disposed;

  /// Removes a staged copy the transfer did not get to rename.
  ///
  /// Only where this device is the destination. Killing an isolate skips the
  /// cleanup its own `catch` would have done, and a `.sb-part-N` nobody
  /// deletes is worse than the partial file this staging replaced.
  ///
  /// Swept by name rather than deleted by path: the backend picks the staging
  /// name inside `write`, and the two sides agree on the pattern rather than
  /// on the whole string. Two transfers staging the same destination are
  /// already writing over each other.
  ///
  /// A cancelled *upload* leaves one on the server, which this side cannot
  /// reach without opening the connection again. It is at least visible in the
  /// browser, beside the file it was going to become.
  void _discardStaging() {
    final destination = stagingPath;
    if (destination == null || job.to is! LocalFileRef) return;
    stagingPath = null;
    unawaited(_sweep(destination));
  }

  static Future<void> _sweep(String destination) async {
    try {
      final native = LocalFileBackend.nativePath(destination);
      final dir = File(native).parent;
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        final name = entity.path.split(Platform.pathSeparator).last;
        if (entity is File && isStagingOf(name, destination)) {
          await entity.delete();
        }
      }
    } catch (e, s) {
      Loggers.app.warning('Failed to clean up after a cancelled transfer', e, s);
    }
  }

  Future<void> _initWorker() async {
    try {
      // Before the bundle crosses: the isolate has no screen to ask a
      // passphrase on, so a key stored encrypted has to be opened on this side
      // or it fails over there with nothing to say why.
      for (final ref in [job.from, job.to]) {
        if (ref is SftpFileRef) await ref.creds.unlockKeys();
      }
      await worker!.init();
    } catch (e, s) {
      Loggers.app.warning('Failed to initialize the transfer worker', e, s);
      onNotify(e);
    }
  }

  /// A copy that needs no isolate: this device, a monitor agent, or both.
  ///
  /// The same events an isolate would send, so nothing downstream can tell the
  /// difference — including the list, which shows one row either way.
  Future<void> _runHere() async {
    final source = _backendFor(job.from);
    // One session where both ends are the same place: copying within one
    // agent would otherwise log in twice to move a file it never sends over
    // the network at all.
    final dest = _sameEnd(job.from, job.to) ? source : _backendFor(job.to);
    try {
      onNotify(FileTransferStage.preparing);
      final watch = Stopwatch()..start();
      final plan = await planCopy(
        source,
        job.from.path,
        job.to.path,
        isDir: job.isDir,
      );
      onNotify(plan.totalBytes);
      onNotify(FileTransferStage.loading);

      final total = plan.totalBytes;
      await runCopy(
        plan,
        source,
        dest,
        cancelled: () => _cancelled,
        onProgress: (transferred) => onNotify(
          FileTransferProgress(
            percent: total == 0 ? 0 : transferred / total * 100,
            transferredBytes: transferred,
          ),
        ),
      );

      onNotify(watch.elapsed);
      onNotify(FileTransferStage.finished);
    } on CopyCancelled {
      // The row is already gone and `write` has removed what it staged. There
      // is nobody left to report this to.
    } catch (e, s) {
      Loggers.app.warning('Local copy failed: ${job.from} -> ${job.to}', e, s);
      onNotify(e);
    } finally {
      await source.close();
      if (!identical(dest, source)) await dest.close();
    }
  }

  /// Whether two ends are the same place, and so can share one session.
  static bool _sameEnd(FileRef a, FileRef b) => switch ((a, b)) {
    (LocalFileRef(), LocalFileRef()) => true,
    (MonitorFileRef(spi: final x), MonitorFileRef(spi: final y)) =>
      x.id == y.id,
    _ => false,
  };

  /// An `SftpFileRef` never reaches here — [FileTransfer.needsIsolate] is
  /// exactly the question "is either end SSH".
  static FileBackend _backendFor(FileRef ref) => switch (ref) {
    LocalFileRef() => const LocalFileBackend(),
    MonitorFileRef(:final monitor) => MonitorFileBackend(monitor),
    SftpFileRef() => throw StateError('SFTP transfers run in an isolate'),
  };

  void onNotify(dynamic event) {
    var shouldDispose = false;
    switch (event) {
      case final FileTransferStage val:
        status = val;
        if (status == FileTransferStage.finished) {
          dispose();
        }
      case final FileTransferProgress val:
        progress = val.percent;
        transferredBytes = val.transferredBytes;
        _initSpeedSampleIfNeeded(val.transferredBytes);
      case final int val:
        size = val;
      case final Duration d:
        spentTime = d;
      case final TransferStaging val:
        // An empty path means "renamed into place, nothing left to clean up".
        stagingPath = val.path.isEmpty ? null : val.path;
      default:
        error = Exception('transfer event: $event');
        Loggers.app.warning(error);
        shouldDispose = true;
    }
    notifyListeners();
    if (shouldDispose) dispose();
  }

  void _initSpeedSampleIfNeeded(int transferredBytes) {
    if (_speedSampleTime != null) return;
    _speedSampleTime = DateTime.now();
    _speedSampleBytes = transferredBytes;
  }

  bool refreshSpeed([DateTime? now]) {
    if (status != FileTransferStage.loading) return false;

    final sampleTime = now ?? DateTime.now();
    final sampleBytes = transferredBytes ?? 0;
    final lastSampleTime = _speedSampleTime;
    if (lastSampleTime == null) {
      _speedSampleTime = sampleTime;
      _speedSampleBytes = sampleBytes;
      return false;
    }

    final elapsedMs = sampleTime.difference(lastSampleTime).inMilliseconds;
    if (elapsedMs <= 0) return false;

    final speed = (sampleBytes - _speedSampleBytes) * 1000 / elapsedMs;
    _speedSampleTime = sampleTime;
    _speedSampleBytes = sampleBytes;

    if (speedBytesPerSecond == speed) return false;
    speedBytesPerSecond = speed;
    return true;
  }
}
