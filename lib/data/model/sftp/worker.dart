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

const _sftpDownloadChunkSize = 16 * 1024;

const _sftpDownloadMaxPendingRequests = 1;

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
  SSHClient? client;
  SftpClient? sftp;
  SftpFile? remoteFile;
  Object? error;
  StackTrace? stackTrace;

  try {
    mainSendPort.send(SftpWorkerStatus.preparing);
    final watch = Stopwatch()..start();
    client = await genClient(
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
    final openedSftp = await _withSftpPrepareTimeout(
      req,
      'open download session',
      client.sftp(),
    );
    sftp = openedSftp;

    Loggers.app.info('SFTP download opening remote file: ${req.remotePath}');
    final openedRemoteFile = await _withSftpPrepareTimeout(
      req,
      'open remote file for download',
      openedSftp.open(req.remotePath),
    );
    remoteFile = openedRemoteFile;
    Loggers.app.info('SFTP download reading remote size: ${req.remotePath}');
    final size = (await _withSftpPrepareTimeout(
      req,
      'stat remote file',
      openedRemoteFile.stat(),
    )).size;
    if (size == null) {
      throw Exception('can\'t get file size: ${req.remotePath}');
    }

    mainSendPort.send(size);
    mainSendPort.send(SftpWorkerStatus.loading);
    Loggers.app.info(
      'SFTP download started: ${req.remotePath}, '
      'chunk=$_sftpDownloadChunkSize, pending=$_sftpDownloadMaxPendingRequests',
    );

    var lastProgress = -1.0;
    final localFile = File(req.localPath).openWrite(mode: FileMode.write);

    try {
      const segmentSize = 5 * 1024 * 1024; // 5MB per segment
      var offset = 0;
      var totalBytes = 0;
      var chunkCount = 0;
      final dlWatch = Stopwatch()..start();
      Loggers.app.info('SFTP download start size=$size');

      final timeout = Duration(
        seconds: req.timeoutSeconds <= 0 ? 60 : req.timeoutSeconds,
      );

      while (offset < size) {
        final remaining = size - offset;
        final length = remaining < segmentSize ? remaining : segmentSize;
        var segmentBytes = 0;

        try {
          await for (final chunk
              in openedRemoteFile
                  .read(
                    length: length,
                    offset: offset,
                    chunkSize: _sftpDownloadChunkSize,
                    maxPendingRequests: _sftpDownloadMaxPendingRequests,
                  )
                  .timeout(timeout)) {
            localFile.add(chunk);
            segmentBytes += chunk.length;
            totalBytes += chunk.length;
            chunkCount++;

            if (size > 0) {
              final progress =
                  (totalBytes / size * 100 * 10).roundToDouble() / 10;
              if (progress != lastProgress) {
                lastProgress = progress;
                mainSendPort.send(progress);
              }
            }
          }
        } on TimeoutException {
          throw SftpError('Download timed out at offset=$offset');
        }

        if (segmentBytes == 0) {
          throw SftpError(
            'Download returned 0 bytes at offset=$offset',
          );
        }
        offset += segmentBytes;
      }

      Loggers.app.info(
        'SFTP download done total=$totalBytes chunks=$chunkCount '
        'time=${dlWatch.elapsedMilliseconds}ms',
      );
    } finally {
      await localFile.close();
    }

    mainSendPort.send(watch.elapsed);
    mainSendPort.send(SftpWorkerStatus.finished);
  } catch (e, s) {
    error = e;
    stackTrace = s;
  } finally {
    await _closeSftpResources(
      remoteFile: remoteFile,
      sftp: sftp,
      client: client,
    );
  }

  if (error != null) {
    Loggers.app.warning(
      'SFTP download failed: ${req.remotePath}',
      error,
      stackTrace,
    );
    mainSendPort.send(error);
  }
}

Future<void> _upload(
  SftpReq req,
  SendPort mainSendPort,
  SendErrorFunction sendError,
) async {
  SSHClient? client;
  SftpClient? sftp;
  SftpFile? remoteFile;
  Object? error;
  StackTrace? stackTrace;

  try {
    mainSendPort.send(SftpWorkerStatus.preparing);
    final watch = Stopwatch()..start();
    client = await genClient(
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
    final openedSftp = await _withSftpPrepareTimeout(
      req,
      'open upload session',
      client.sftp(),
    );
    sftp = openedSftp;
    // If remote exists, overwrite it
    Loggers.app.info('SFTP upload opening remote file: ${req.remotePath}');
    final openedRemoteFile = await _withSftpPrepareTimeout(
      req,
      'open remote file for upload',
      openedSftp.open(
        req.remotePath,
        mode:
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.create |
            SftpFileOpenMode.write,
      ),
    );
    remoteFile = openedRemoteFile;
    mainSendPort.send(SftpWorkerStatus.loading);
    Loggers.app.info(
      'SFTP upload started: ${req.remotePath}, '
      'chunk=$_sftpTransferChunkSize, maxBytes=$_sftpUploadMaxBytesOnTheWire',
    );
    var lastProgress = -1;
    final writer = openedRemoteFile.write(
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
    mainSendPort.send(watch.elapsed);
    mainSendPort.send(SftpWorkerStatus.finished);
  } catch (e, s) {
    error = e;
    stackTrace = s;
  } finally {
    await _closeSftpResources(
      remoteFile: remoteFile,
      sftp: sftp,
      client: client,
    );
  }

  if (error != null) {
    Loggers.app.warning(
      'SFTP upload failed: ${req.remotePath}',
      error,
      stackTrace,
    );
    mainSendPort.send(error);
  }
}

Future<void> _closeSftpResources({
  required SftpFile? remoteFile,
  required SftpClient? sftp,
  required SSHClient? client,
}) async {
  if (remoteFile != null && !remoteFile.isClosed) {
    try {
      await remoteFile.close();
    } catch (e, s) {
      Loggers.app.warning('Failed to close SFTP remote file', e, s);
    }
  }

  if (sftp != null) {
    try {
      sftp.close();
    } catch (e, s) {
      Loggers.app.warning('Failed to close SFTP session', e, s);
    }
  }

  if (client != null) {
    try {
      client.close();
    } catch (e, s) {
      Loggers.app.warning('Failed to close SSH client', e, s);
    }
  }
}
