import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/local_file_backend.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/file/transfer_worker.dart';

/// One transfer, and everything a list has to say about it.
class FileTransferStatus {
  FileTransferStatus({
    required this.job,
    required this.notifyListeners,
    this.completer,
  }) : id = DateTime.now().microsecondsSinceEpoch {
    if (job.needsIsolate) {
      worker = FileTransferWorker(onNotify: onNotify, job: job);
      unawaited(_initWorker());
    } else {
      unawaited(_runHere());
    }
  }

  final int id;
  final FileTransfer job;
  final void Function() notifyListeners;
  final Completer? completer;

  /// Null for a transfer that runs on this isolate, which is the pairs with no
  /// crypto in them.
  FileTransferWorker? worker;

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
    worker?.dispose();
    if (completer?.isCompleted == false) {
      completer?.complete(true);
    }
  }

  Future<void> _initWorker() async {
    try {
      await worker!.init();
    } catch (e, s) {
      Loggers.app.warning('Failed to initialize the transfer worker', e, s);
      onNotify(e);
    }
  }

  /// A copy within this device, on the isolate that asked for it.
  ///
  /// The same events an isolate would send, so nothing downstream can tell the
  /// difference — including the list, which shows one row either way.
  Future<void> _runHere() async {
    const backend = LocalFileBackend();
    try {
      onNotify(FileTransferStage.preparing);
      final watch = Stopwatch()..start();
      final total = (await backend.stat(job.from.path))?.size;
      if (total != null) onNotify(total);
      onNotify(FileTransferStage.loading);

      var sent = 0;
      final counted = backend.read(job.from.path).map((chunk) {
        sent += chunk.length;
        onNotify(
          FileTransferProgress(
            percent: total == null || total == 0 ? 0 : sent / total * 100,
            transferredBytes: sent,
          ),
        );
        return chunk;
      });
      await backend.write(job.to.path, counted, size: total);

      onNotify(watch.elapsed);
      onNotify(FileTransferStage.finished);
    } catch (e, s) {
      Loggers.app.warning('Local copy failed: ${job.from} -> ${job.to}', e, s);
      onNotify(e);
    }
  }

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
