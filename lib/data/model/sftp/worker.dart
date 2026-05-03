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

const _sftpTransferChunkSize = 64 * 1024;
const _sftpDownloadMaxPendingRequests = 16;
const _sftpUploadMaxBytesOnTheWire = _sftpTransferChunkSize * 4;
const _sftpOperationTimeout = Duration(seconds: 30);

Future<T> _withSftpTimeout<T>(Future<T> future, String operation) {
  return future.timeout(
    _sftpOperationTimeout,
    onTimeout: () => throw TimeoutException(
      'SFTP $operation timed out',
      _sftpOperationTimeout,
    ),
  );
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

    final dirPath = req.localPath.substring(
      0,
      req.localPath.lastIndexOf(Pfs.seperator),
    );
    await Directory(dirPath).create(recursive: true);

    final sftp = await _withSftpTimeout(client.sftp(), 'open session');

    final remoteFile = await _withSftpTimeout(
      sftp.open(req.remotePath),
      'open remote file',
    );
    int? size;
    try {
      size = (await _withSftpTimeout(
        remoteFile.stat(),
        'stat remote file',
      )).size;
      if (size == null) {
        mainSendPort.send(Exception('can\'t get file size: ${req.remotePath}'));
        return;
      }
    } finally {
      await remoteFile.close();
    }

    mainSendPort.send(size);
    mainSendPort.send(SftpWorkerStatus.loading);

    var lastProgress = -1.0;
    final localFile = File(req.localPath).openWrite(mode: FileMode.write);

    try {
      await sftp.download(
        req.remotePath,
        localFile,
        onProgress: (bytesRead) {
          final s = size;
          if (s == null || s == 0) return;
          final progress = (bytesRead / s * 100).roundToDouble();
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
    }

    mainSendPort.send(watch.elapsed);
    mainSendPort.send(SftpWorkerStatus.finished);
  } catch (e) {
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

    final local = File(req.localPath);
    if (!await local.exists()) {
      mainSendPort.send(Exception('local file not exists'));
      return;
    }
    final localLen = await local.length();
    mainSendPort.send(localLen);
    mainSendPort.send(SftpWorkerStatus.loading);
    final localFile = local.openRead().cast<Uint8List>();
    final sftp = await _withSftpTimeout(client.sftp(), 'open session');
    // If remote exists, overwrite it
    final file = await _withSftpTimeout(
      sftp.open(
        req.remotePath,
        mode:
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.create |
            SftpFileOpenMode.write,
      ),
      'open remote file',
    );
    var lastProgress = -1;
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
    await file.close();
    mainSendPort.send(watch.elapsed);
    mainSendPort.send(SftpWorkerStatus.finished);
  } catch (e) {
    mainSendPort.send(e);
  }
}
