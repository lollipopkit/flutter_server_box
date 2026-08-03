import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_isolate/easy_isolate.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/sftp_timeout.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/sftp/req.dart';

const _sftpChunkSize = 32 * 1024;

const _sftpDownloadMaxPendingRequests = 64;

const _sftpDownloadMinIdleTimeout = Duration(seconds: 60);

const _sftpUploadMaxBytesOnTheWire = _sftpChunkSize * 64;

var _sftpPromptSequence = 0;

final _keyboardInteractiveResponses = <int, Completer<List<String>?>>{};

final _hostKeyResponses = <int, Completer<bool>>{};

class SftpKeyboardInteractivePrompt {
  final int id;
  final Spi spi;
  final SSHUserInfoRequest request;
  final DateTime expiresAt;

  const SftpKeyboardInteractivePrompt({
    required this.id,
    required this.spi,
    required this.request,
    required this.expiresAt,
  });
}

class SftpKeyboardInteractiveResponse {
  final int id;
  final List<String>? responses;

  const SftpKeyboardInteractiveResponse({
    required this.id,
    required this.responses,
  });
}

class SftpHostKeyPrompt {
  final int id;
  final HostKeyPromptInfo info;

  const SftpHostKeyPrompt({required this.id, required this.info});
}

class SftpHostKeyResponse {
  final int id;
  final bool accepted;

  const SftpHostKeyResponse({required this.id, required this.accepted});
}

class SftpHostKeyAccepted {
  final String storageKey;
  final String fingerprintHex;

  const SftpHostKeyAccepted({
    required this.storageKey,
    required this.fingerprintHex,
  });
}

Duration _sftpPrepareTimeout(SftpReq req) {
  final seconds = req.timeoutSeconds;
  return sftpOperationTimeout(seconds);
}

Duration _sftpDownloadIdleTimeout(SftpReq req) {
  final seconds = req.timeoutSeconds;
  final timeout = Duration(seconds: seconds <= 0 ? 60 : seconds);
  return timeout < _sftpDownloadMinIdleTimeout
      ? _sftpDownloadMinIdleTimeout
      : timeout;
}

Future<SSHClient> _connectSftpSsh(SftpReq req, SendPort mainSendPort) async {
  final client = await genClient(
    req.spi,
    privateKey: req.privateKey,
    jumpSpi: req.jumpSpi,
    jumpPrivateKey: req.jumpPrivateKey,
    privateKeysByKeyId: req.privateKeysByKeyId,
    jumpSpisById: req.jumpSpisById,
    knownHostFingerprints: req.knownHostFingerprints,
    onKeyboardInteractive: (server, request) =>
        _requestKeyboardInteractive(mainSendPort, server, request),
    onHostKeyPrompt: (info) => _requestHostKey(mainSendPort, info),
    onHostKeyAccepted: (storageKey, fingerprintHex) {
      mainSendPort.send(
        SftpHostKeyAccepted(
          storageKey: storageKey,
          fingerprintHex: fingerprintHex,
        ),
      );
    },
  );
  try {
    await client.authenticated;
    return client;
  } catch (_) {
    client.close();
    rethrow;
  }
}

Future<List<String>?> _requestKeyboardInteractive(
  SendPort mainSendPort,
  Spi spi,
  SSHUserInfoRequest request,
) async {
  final id = _sftpPromptSequence++;
  final completer = Completer<List<String>?>();
  final expiresAt = DateTime.now().add(KeyboardInteractiveAuth.promptTimeout);
  _keyboardInteractiveResponses[id] = completer;
  mainSendPort.send(
    SftpKeyboardInteractivePrompt(
      id: id,
      spi: spi,
      request: request,
      expiresAt: expiresAt,
    ),
  );
  try {
    return await completer.future.timeout(KeyboardInteractiveAuth.promptTimeout);
  } on TimeoutException {
    return null;
  } finally {
    _keyboardInteractiveResponses.remove(id);
  }
}

Future<bool> _requestHostKey(
  SendPort mainSendPort,
  HostKeyPromptInfo info,
) async {
  final id = _sftpPromptSequence++;
  final completer = Completer<bool>();
  _hostKeyResponses[id] = completer;
  mainSendPort.send(SftpHostKeyPrompt(id: id, info: info));
  try {
    return await completer.future.timeout(KeyboardInteractiveAuth.promptTimeout);
  } on TimeoutException {
    return false;
  } finally {
    _hostKeyResponses.remove(id);
  }
}

class SftpWorker {
  final Function(Object event) onNotify;
  final SftpReq req;

  final worker = Worker();

  SftpWorker({required this.onNotify, required this.req});

  void dispose() {
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
  Future<void> mainMessageHandler(
    dynamic data,
    SendPort isolateSendPort,
  ) async {
    switch (data) {
      case final SftpKeyboardInteractivePrompt prompt:
        List<String>? responses;
        try {
          final timeout = prompt.expiresAt.difference(DateTime.now());
          if (timeout > Duration.zero) {
            responses = await KeyboardInteractiveAuth.handle(
              prompt.spi,
              prompt.request,
              timeout: timeout,
            );
          }
        } catch (e, s) {
          Loggers.app.warning('SFTP interactive authentication failed', e, s);
        }
        isolateSendPort.send(
          SftpKeyboardInteractiveResponse(
            id: prompt.id,
            responses: responses,
          ),
        );
        return;
      case final SftpHostKeyPrompt prompt:
        var accepted = false;
        try {
          accepted = await showHostKeyPrompt(prompt.info);
        } catch (e, s) {
          Loggers.app.warning('SFTP host key prompt failed', e, s);
        }
        isolateSendPort.send(
          SftpHostKeyResponse(id: prompt.id, accepted: accepted),
        );
        return;
      case final SftpHostKeyAccepted accepted:
        persistHostKeyFingerprint(
          accepted.storageKey,
          accepted.fingerprintHex,
        );
        return;
      default:
        onNotify(data);
    }
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
          await _download(data, mainSendPort);
          break;
        case SftpReqType.upload:
          await _upload(data, mainSendPort);
          break;
      }
      break;
    case final SftpKeyboardInteractiveResponse response:
      final completer = _keyboardInteractiveResponses[response.id];
      if (completer != null && !completer.isCompleted) {
        completer.complete(response.responses);
      }
      break;
    case final SftpHostKeyResponse response:
      final completer = _hostKeyResponses[response.id];
      if (completer != null && !completer.isCompleted) {
        completer.complete(response.accepted);
      }
      break;
    default:
      sendError(Exception('unknown event'));
  }
}

Future<void> _download(
  SftpReq req,
  SendPort mainSendPort,
) async {
  SSHClient? client;
  SftpClient? sftp;
  SftpFile? remoteFile;
  Object? error;
  StackTrace? stackTrace;

  try {
    mainSendPort.send(SftpWorkerStatus.preparing);
    final watch = Stopwatch()..start();
    client = await _connectSftpSsh(req, mainSendPort);
    mainSendPort.send(SftpWorkerStatus.sshConnectted);
    Loggers.app.info('SFTP download SSH connected: ${req.remotePath}');

    final dirPath = req.localPath.substring(
      0,
      req.localPath.lastIndexOf(Pfs.seperator),
    );
    await Directory(dirPath).create(recursive: true);

    Loggers.app.info('SFTP download opening session: ${req.remotePath}');
    final openedSftp = await withSftpSessionOpenTimeout(
      'open download session',
      client.sftp(),
      _sftpPrepareTimeout(req),
    );
    sftp = openedSftp;

    Loggers.app.info('SFTP download opening remote file: ${req.remotePath}');
    final openedRemoteFile = await withSftpOpTimeout(
      'open remote file for download',
      openedSftp.open(req.remotePath),
      _sftpPrepareTimeout(req),
    );
    remoteFile = openedRemoteFile;
    Loggers.app.info('SFTP download reading remote size: ${req.remotePath}');
    final size = (await withSftpOpTimeout(
      'stat remote file',
      openedRemoteFile.stat(),
      _sftpPrepareTimeout(req),
    )).size;
    if (size == null) {
      throw Exception('can\'t get file size: ${req.remotePath}');
    }

    mainSendPort.send(size);
    mainSendPort.send(SftpWorkerStatus.loading);
    Loggers.app.info(
      'SFTP download started: ${req.remotePath}, '
      'chunk=$_sftpChunkSize, pending=$_sftpDownloadMaxPendingRequests',
    );

    final localFile = await File(req.localPath).open(mode: FileMode.write);

    try {
      const segmentSize = 5 * 1024 * 1024; // 5MB per segment
      final progressUpdateInterval = Duration(
        seconds: req.progressUpdateIntervalSeconds,
      );
      final progressUpdateIntervalMs = progressUpdateInterval.inMilliseconds;
      var offset = 0;
      var totalBytes = 0;
      var chunkCount = 0;
      var lastProgressUpdateMs = -progressUpdateIntervalMs;
      final dlWatch = Stopwatch()..start();
      Loggers.app.info('SFTP download start size=$size');

      final timeout = _sftpDownloadIdleTimeout(req);

      while (offset < size) {
        final remaining = size - offset;
        final length = remaining < segmentSize ? remaining : segmentSize;

        Timer? idleTimer;
        final idleTimeout = Completer<Never>();

        void resetIdleTimer() {
          if (idleTimeout.isCompleted) return;
          idleTimer?.cancel();
          idleTimer = Timer(timeout, () {
            if (!idleTimeout.isCompleted) {
              idleTimeout.completeError(
                TimeoutException('SFTP download idle timed out', timeout),
              );
            }
          });
        }

        try {
          resetIdleTimer();
          final downloadFuture = openedRemoteFile.downloadToRandomAccess(
            localFile,
            length: length,
            offset: offset,
            chunkSize: _sftpChunkSize,
            maxPendingRequests: _sftpDownloadMaxPendingRequests,
            onProgress: (bytes) {
              resetIdleTimer();
              final transferred = totalBytes + bytes;
              final progress =
                  (transferred / size * 100 * 10).roundToDouble() / 10;
              final elapsedMs = dlWatch.elapsedMilliseconds;
              final shouldUpdate =
                  elapsedMs - lastProgressUpdateMs >=
                      progressUpdateIntervalMs ||
                  transferred >= size;

              if (shouldUpdate) {
                lastProgressUpdateMs = elapsedMs;
                mainSendPort.send(
                  SftpTransferProgress(
                    percent: progress,
                    transferredBytes: transferred,
                  ),
                );
              }
            },
          );
          final segmentBytes = await Future.any([
            downloadFuture,
            idleTimeout.future,
          ]);

          totalBytes += segmentBytes;
          chunkCount += (segmentBytes / _sftpChunkSize).ceil();
        } on TimeoutException {
          throw SftpError('Download timed out at offset=$offset');
        } finally {
          idleTimer?.cancel();
        }

        if (length > 0 && totalBytes <= offset) {
          throw SftpError('Download returned 0 bytes at offset=$offset');
        }
        offset = totalBytes;
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
) async {
  SSHClient? client;
  SftpClient? sftp;
  SftpFile? remoteFile;
  Object? error;
  StackTrace? stackTrace;

  try {
    mainSendPort.send(SftpWorkerStatus.preparing);
    final watch = Stopwatch()..start();
    client = await _connectSftpSsh(req, mainSendPort);
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
    final openedSftp = await withSftpSessionOpenTimeout(
      'open upload session',
      client.sftp(),
      _sftpPrepareTimeout(req),
    );
    sftp = openedSftp;
    // If remote exists, overwrite it
    Loggers.app.info('SFTP upload opening remote file: ${req.remotePath}');
    final openedRemoteFile = await withSftpOpTimeout(
      'open remote file for upload',
      openedSftp.open(
        req.remotePath,
        mode:
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.create |
            SftpFileOpenMode.write,
      ),
      _sftpPrepareTimeout(req),
    );
    remoteFile = openedRemoteFile;
    mainSendPort.send(SftpWorkerStatus.loading);
    Loggers.app.info(
      'SFTP upload started: ${req.remotePath}, '
      'chunk=$_sftpChunkSize, maxBytes=$_sftpUploadMaxBytesOnTheWire',
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
      chunkSize: _sftpChunkSize,
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
