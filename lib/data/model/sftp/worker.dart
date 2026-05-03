import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_isolate/easy_isolate.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/jump_chain.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

part 'req.dart';

const _sftpTransferChunkSize = 32 * 1024;
const _sftpDownloadMaxPendingRequests = 64;
const _sftpUploadMaxBytesOnTheWire = _sftpTransferChunkSize * 64;

Duration _sftpPrepareTimeout(SftpReq req) {
  final seconds = req.timeoutSeconds;
  return Duration(seconds: seconds <= 0 ? 5 : seconds);
}

Future<T> _withSftpPrepareTimeout<T>(
  SftpReq req,
  String operation,
  Future<T> future,
) async {
  final timeout = _sftpPrepareTimeout(req);
  try {
    return await future.timeout(timeout);
  } on TimeoutException catch (e, s) {
    final error = TimeoutException('SFTP $operation timed out', timeout);
    Loggers.app.warning(error.message, e, s);
    throw error;
  }
}

class SftpWorker {
  final Function(Object event) onNotify;
  final SftpReq req;

  final worker = Worker();

  SftpWorker({required this.onNotify, required this.req});

  void _dispose() {
    worker.dispose();
  }

  /// Initiate the worker (new thread) and start listen from messages between
  /// the threads
  Future<void> init() async {
    if (worker.isInitialized) worker.dispose();
    await worker.init(
      mainMessageHandler,
      isolateMessageHandler,
      errorHandler: print,
    );
    worker.sendMessage(req);
  }

  /// Handle the messages coming from the isolate
  void mainMessageHandler(dynamic data, SendPort isolateSendPort) {
    onNotify(data);
  }
}

/// Handle the messages coming from the main
Future<void> isolateMessageHandler(
  dynamic data,
  SendPort mainSendPort,
  SendErrorFunction sendError,
) async {
  switch (data) {
    case final SftpReq val:
      switch (val.type) {
        case SftpReqType.download:
          await _download(data, mainSendPort, sendError);
          break;
        case SftpReqType.upload:
          await _upload(data, mainSendPort, sendError);
          break;
      }
      break;
    default:
      sendError(Exception('unknown event'));
  }
}

Future<void> _download(
  SftpReq req,
  SendPort mainSendPort,
  SendErrorFunction sendError,
) async {
  try {
    mainSendPort.send(SftpWorkerStatus.preparing);
    final watch = Stopwatch()..start();
    final client = await genClient(
      req.spi,
      privateKey: req.privateKey,
      jumpSpi: req.jumpSpi,
      jumpPrivateKey: req.jumpPrivateKey,
      privateKeysByKeyId: req.privateKeysByKeyId,
      jumpSpisById: req.jumpSpisById,
      knownHostFingerprints: req.knownHostFingerprints,
    );
    mainSendPort.send(SftpWorkerStatus.sshConnectted);
    Loggers.app.info('SFTP download SSH connected: ${req.remotePath}');

    final dirPath = req.localPath.substring(
      0,
      req.localPath.lastIndexOf(Pfs.seperator),
    );
    await Directory(dirPath).create(recursive: true);

    Loggers.app.info('SFTP download opening session: ${req.remotePath}');
    final sftp = await _withSftpPrepareTimeout(
      req,
      'open download session',
      client.sftp(),
    );

    Loggers.app.info('SFTP download opening remote file: ${req.remotePath}');
    final remoteFile = await _withSftpPrepareTimeout(
      req,
      'open remote file for download',
      sftp.open(req.remotePath),
    );
    Loggers.app.info('SFTP download reading remote size: ${req.remotePath}');
    final size = (await _withSftpPrepareTimeout(
      req,
      'stat remote file',
      remoteFile.stat(),
    )).size;
    if (size == null) {
      await remoteFile.close();
      mainSendPort.send(Exception('can\'t get file size: ${req.remotePath}'));
      return;
    }

    mainSendPort.send(size);
    mainSendPort.send(SftpWorkerStatus.loading);
    Loggers.app.info(
      'SFTP download started: ${req.remotePath}, '
      'chunk=$_sftpTransferChunkSize, pending=$_sftpDownloadMaxPendingRequests',
    );

    var lastProgress = -1.0;
    final localFile = File(req.localPath).openWrite(mode: FileMode.write);

    try {
      await remoteFile.downloadTo(
        localFile,
        length: size,
        onProgress: (bytesRead) {
          if (size == 0) return;
          final progress = (bytesRead / size * 100).roundToDouble();
          if (progress != lastProgress) {
            lastProgress = progress;
            mainSendPort.send(progress);
          }
        },
        chunkSize: _sftpTransferChunkSize,
        maxPendingRequests: _sftpDownloadMaxPendingRequests,
      );
    } finally {
      await localFile.close();
      await remoteFile.close();
    }

    mainSendPort.send(watch.elapsed);
    mainSendPort.send(SftpWorkerStatus.finished);
  } catch (e, s) {
    Loggers.app.warning('SFTP download failed: ${req.remotePath}', e, s);
    mainSendPort.send(e);
  }
}

Future<void> _upload(
  SftpReq req,
  SendPort mainSendPort,
  SendErrorFunction sendError,
) async {
  try {
    mainSendPort.send(SftpWorkerStatus.preparing);
    final watch = Stopwatch()..start();
    final client = await genClient(
      req.spi,
      privateKey: req.privateKey,
      jumpSpi: req.jumpSpi,
      jumpPrivateKey: req.jumpPrivateKey,
      privateKeysByKeyId: req.privateKeysByKeyId,
      jumpSpisById: req.jumpSpisById,
      knownHostFingerprints: req.knownHostFingerprints,
    );
    mainSendPort.send(SftpWorkerStatus.sshConnectted);
    Loggers.app.info('SFTP upload SSH connected: ${req.remotePath}');

    final local = File(req.localPath);
    if (!await local.exists()) {
      mainSendPort.send(Exception('local file not exists'));
      return;
    }
    final localLen = await local.length();
    mainSendPort.send(localLen);
    final localFile = local.openRead().cast<Uint8List>();
    Loggers.app.info('SFTP upload opening session: ${req.remotePath}');
    final sftp = await _withSftpPrepareTimeout(
      req,
      'open upload session',
      client.sftp(),
    );
    // If remote exists, overwrite it
    Loggers.app.info('SFTP upload opening remote file: ${req.remotePath}');
    final file = await _withSftpPrepareTimeout(
      req,
      'open remote file for upload',
      sftp.open(
        req.remotePath,
        mode:
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.create |
            SftpFileOpenMode.write,
      ),
    );
    mainSendPort.send(SftpWorkerStatus.loading);
    Loggers.app.info(
      'SFTP upload started: ${req.remotePath}, '
      'chunk=$_sftpTransferChunkSize, maxBytes=$_sftpUploadMaxBytesOnTheWire',
    );
    var lastProgress = -1;
    try {
      final writer = file.write(
        localFile,
        onProgress: (total) {
          if (localLen == 0) return;
          final progress = (total / localLen * 100).round();
          if (progress != lastProgress) {
            lastProgress = progress;
            mainSendPort.send(progress.toDouble());
          }
        },
        chunkSize: _sftpTransferChunkSize,
        maxBytesOnTheWire: _sftpUploadMaxBytesOnTheWire,
      );
      await writer.done;
    } finally {
      await file.close();
    }
    mainSendPort.send(watch.elapsed);
    mainSendPort.send(SftpWorkerStatus.finished);
  } catch (e, s) {
    Loggers.app.warning('SFTP upload failed: ${req.remotePath}', e, s);
    mainSendPort.send(e);
  }
}
