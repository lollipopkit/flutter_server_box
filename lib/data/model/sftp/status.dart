import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/sftp/req.dart';
import 'package:server_box/data/model/sftp/worker.dart';

class SftpReqStatus {
  final int id;
  final SftpReq req;
  final void Function() notifyListeners;
  late SftpWorker worker;
  final Completer? completer;

  String get fileName => req.localPath.split(Pfs.seperator).last;

  // status of the download
  double? progress;
  double? speedBytesPerSecond;
  int? transferredBytes;
  DateTime? _speedSampleTime;
  int _speedSampleBytes = 0;
  SftpWorkerStatus? status;
  int? size;
  Exception? error;
  Duration? spentTime;
  bool _disposed = false;

  SftpReqStatus({
    required this.req,
    required this.notifyListeners,
    this.completer,
  }) : id = DateTime.now().microsecondsSinceEpoch {
    worker = SftpWorker(onNotify: onNotify, req: req);
    unawaited(_initWorker());
  }

  @override
  bool operator ==(Object other) => other is SftpReqStatus && id == other.id;

  @override
  int get hashCode => id.hashCode;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    worker.dispose();
    if (completer?.isCompleted == false) {
      completer?.complete(true);
    }
  }

  Future<void> _initWorker() async {
    try {
      await worker.init();
    } catch (e, s) {
      Loggers.app.warning('Failed to initialize SFTP worker', e, s);
      onNotify(e);
    }
  }

  void onNotify(dynamic event) {
    var shouldDispose = false;
    switch (event) {
      case final SftpWorkerStatus val:
        status = val;
        if (status == SftpWorkerStatus.finished) {
          dispose();
        }
        break;
      case final double val:
        progress = val;
        break;
      case final SftpTransferProgress val:
        progress = val.percent;
        transferredBytes = val.transferredBytes;
        _initSpeedSampleIfNeeded(val.transferredBytes);
        break;
      case final int val:
        size = val;
        break;
      case final Duration d:
        spentTime = d;
        break;
      default:
        error = Exception('sftp worker event: $event');
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
    if (status != SftpWorkerStatus.loading) return false;

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
