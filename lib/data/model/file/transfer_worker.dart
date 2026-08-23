import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_isolate/easy_isolate.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/local_file_backend.dart';
import 'package:server_box/core/utils/monitor_file_backend.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/core/utils/sftp_file_backend.dart';
import 'package:server_box/core/utils/sftp_timeout.dart';
import 'package:server_box/core/utils/ssh_auth.dart';
import 'package:server_box/data/model/file/copy_tree.dart';
import 'package:server_box/data/model/file/file_backend.dart';
import 'package:server_box/data/model/file/file_ref.dart';
import 'package:server_box/data/model/file/prompt_queue.dart';
import 'package:server_box/data/model/file/transfer.dart';
import 'package:server_box/data/model/server/server_private_info.dart';

const _sftpChunkSize = 32 * 1024;

const _sftpDownloadMaxPendingRequests = 64;

const _sftpDownloadMinIdleTimeout = Duration(seconds: 60);

const _sftpUploadMaxBytesOnTheWire = _sftpChunkSize * 64;

var _promptSequence = 0;

final _keyboardInteractiveResponses = <int, Completer<List<String>?>>{};

final _hostKeyResponses = <int, Completer<bool>>{};

class TransferKeyboardInteractivePrompt {
  final int id;
  final Spi spi;
  final SSHUserInfoRequest request;
  final DateTime expiresAt;

  const TransferKeyboardInteractivePrompt({
    required this.id,
    required this.spi,
    required this.request,
    required this.expiresAt,
  });
}

class TransferKeyboardInteractiveResponse {
  final int id;
  final List<String>? responses;

  const TransferKeyboardInteractiveResponse({
    required this.id,
    required this.responses,
  });
}

class TransferHostKeyPrompt {
  final int id;
  final HostKeyPromptInfo info;

  const TransferHostKeyPrompt({required this.id, required this.info});
}

class TransferHostKeyResponse {
  final int id;
  final bool accepted;

  const TransferHostKeyResponse({required this.id, required this.accepted});
}

/// Where a transfer is parking its bytes until it can rename them into place.
///
/// Sent so that a cancelled transfer — an isolate killed mid-flight, whose own
/// cleanup never runs — leaves nothing behind on this device.
class TransferStaging {
  const TransferStaging(this.path);

  final String path;
}

class TransferHostKeyAccepted {
  final String storageKey;

  /// OpenSSH-style, `SHA256:<base64-without-padding>` — the same string
  /// `HostKeyPromptInfo.fingerprint` carries. Was `fingerprintHex` back when
  /// it held colon-separated hex, and the name outlived the format.
  final String fingerprint;

  const TransferHostKeyAccepted({
    required this.storageKey,
    required this.fingerprint,
  });
}

Duration _prepareTimeout(FileTransfer job) =>
    sftpOperationTimeout(job.timeoutSeconds);

Duration _downloadIdleTimeout(FileTransfer job) {
  final seconds = job.timeoutSeconds;
  final timeout = Duration(seconds: seconds <= 0 ? 60 : seconds);
  return timeout < _sftpDownloadMinIdleTimeout
      ? _sftpDownloadMinIdleTimeout
      : timeout;
}

Future<SSHClient> _connectSsh(
  SshTransferCreds creds,
  SendPort mainSendPort,
) async {
  final client = await genClient(
    creds.spi,
    privateKey: creds.privateKey,
    jumpSpi: creds.jumpSpi,
    jumpPrivateKey: creds.jumpPrivateKey,
    privateKeysByKeyId: creds.privateKeysByKeyId,
    jumpSpisById: creds.jumpSpisById,
    knownHostFingerprints: creds.knownHostFingerprints,
    onKeyboardInteractive: (server, request) =>
        _requestKeyboardInteractive(mainSendPort, server, request),
    onHostKeyPrompt: (info) => _requestHostKey(mainSendPort, info),
    onHostKeyAccepted: (storageKey, fingerprint) {
      mainSendPort.send(
        TransferHostKeyAccepted(
          storageKey: storageKey,
          fingerprint: fingerprint,
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
  final id = _promptSequence++;
  final completer = Completer<List<String>?>();
  final expiresAt = DateTime.now().add(KeyboardInteractiveAuth.promptTimeout);
  _keyboardInteractiveResponses[id] = completer;
  mainSendPort.send(
    TransferKeyboardInteractivePrompt(
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
  final id = _promptSequence++;
  final completer = Completer<bool>();
  _hostKeyResponses[id] = completer;
  mainSendPort.send(TransferHostKeyPrompt(id: id, info: info));
  try {
    return await completer.future.timeout(KeyboardInteractiveAuth.promptTimeout);
  } on TimeoutException {
    return false;
  } finally {
    _hostKeyResponses.remove(id);
  }
}

class FileTransferWorker {
  final Function(Object event) onNotify;
  final FileTransfer job;

  final worker = Worker();

  FileTransferWorker({required this.onNotify, required this.job});

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
    worker.sendMessage(job);
  }

  /// Handle the messages coming from the isolate
  Future<void> mainMessageHandler(
    dynamic data,
    SendPort isolateSendPort,
  ) async {
    switch (data) {
      case final TransferKeyboardInteractivePrompt prompt:
        final responses = await PromptQueue.shared.add(() async {
          try {
            final timeout = prompt.expiresAt.difference(DateTime.now());
            if (timeout <= Duration.zero) return null;
            return await KeyboardInteractiveAuth.handle(
              prompt.spi,
              prompt.request,
              timeout: timeout,
            );
          } catch (e, s) {
            Loggers.app.warning('Transfer interactive auth failed', e, s);
            return null;
          }
        });
        isolateSendPort.send(
          TransferKeyboardInteractiveResponse(
            id: prompt.id,
            responses: responses,
          ),
        );
        return;
      case final TransferHostKeyPrompt prompt:
        final accepted = await PromptQueue.shared.add(() async {
          try {
            return await showHostKeyPrompt(prompt.info);
          } catch (e, s) {
            Loggers.app.warning('Transfer host key prompt failed', e, s);
            return false;
          }
        });
        isolateSendPort.send(
          TransferHostKeyResponse(id: prompt.id, accepted: accepted),
        );
        return;
      case final TransferHostKeyAccepted accepted:
        await persistHostKeyFingerprint(
          accepted.storageKey,
          accepted.fingerprint,
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
    case final FileTransfer job:
      // The two pairs that already existed keep their own code: segmented
      // reads, an idle timer and a bounded write window are what make a large
      // file over a slow link finish, and none of that is expressible as
      // `read` piped into `write`. Everything else takes the general path.
      switch ((job.from, job.to)) {
        case (final SftpFileRef from, final LocalFileRef to)
            when job.isSingleFile:
          await _download(job, from, to, mainSendPort);
        case (final LocalFileRef from, final SftpFileRef to)
            when job.isSingleFile:
          await _upload(job, from, to, mainSendPort);
        default:
          await _copy(job, mainSendPort);
      }
    case final TransferKeyboardInteractiveResponse response:
      final completer = _keyboardInteractiveResponses[response.id];
      if (completer != null && !completer.isCompleted) {
        completer.complete(response.responses);
      }
    case final TransferHostKeyResponse response:
      final completer = _hostKeyResponses[response.id];
      if (completer != null && !completer.isCompleted) {
        completer.complete(response.accepted);
      }
    default:
      sendError(Exception('unknown event'));
  }
}

/// A server to this device.
Future<void> _download(
  FileTransfer job,
  SftpFileRef from,
  LocalFileRef to,
  SendPort mainSendPort,
) async {
  SSHClient? client;
  SftpClient? sftp;
  SftpFile? remoteFile;
  File? staging;
  Object? error;
  StackTrace? stackTrace;

  try {
    mainSendPort.send(FileTransferStage.preparing);
    final watch = Stopwatch()..start();
    client = await _connectSsh(from.creds, mainSendPort);
    mainSendPort.send(FileTransferStage.connected);
    Loggers.app.info('Transfer download SSH connected: ${from.path}');

    final dirPath = to.path.substring(0, to.path.lastIndexOf(Pfs.seperator));
    await Directory(dirPath).create(recursive: true);

    Loggers.app.info('Transfer download opening session: ${from.path}');
    final openedSftp = await withSftpSessionOpenTimeout(
      'open download session',
      client.sftp(),
      _prepareTimeout(job),
    );
    sftp = openedSftp;

    Loggers.app.info('Transfer download opening remote file: ${from.path}');
    final openedRemoteFile = await withSftpOpTimeout(
      'open remote file for download',
      openedSftp.open(from.path),
      _prepareTimeout(job),
    );
    remoteFile = openedRemoteFile;
    Loggers.app.info('Transfer download reading remote size: ${from.path}');
    final size = (await withSftpOpTimeout(
      'stat remote file',
      openedRemoteFile.stat(),
      _prepareTimeout(job),
    )).size;
    if (size == null) {
      throw Exception('can\'t get file size: ${from.path}');
    }

    mainSendPort.send(size);
    mainSendPort.send(FileTransferStage.loading);
    Loggers.app.info(
      'Transfer download started: ${from.path}, '
      'chunk=$_sftpChunkSize, pending=$_sftpDownloadMaxPendingRequests',
    );

    // Beside the destination, not under its name: a download that dies
    // halfway used to leave a truncated file where a whole one was expected,
    // and nothing about it said so.
    staging = File('${to.path}.$_stagingSuffix');
    mainSendPort.send(TransferStaging(staging.path));
    final localFile = await staging.open(mode: FileMode.write);

    try {
      const segmentSize = 5 * 1024 * 1024; // 5MB per segment
      final progressUpdateInterval = Duration(
        seconds: job.progressUpdateIntervalSeconds,
      );
      final progressUpdateIntervalMs = progressUpdateInterval.inMilliseconds;
      var offset = 0;
      var totalBytes = 0;
      var chunkCount = 0;
      var lastProgressUpdateMs = -progressUpdateIntervalMs;
      final dlWatch = Stopwatch()..start();
      Loggers.app.info('Transfer download start size=$size');

      final timeout = _downloadIdleTimeout(job);

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
                TimeoutException('Transfer download idle timed out', timeout),
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
                  FileTransferProgress(
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
        'Transfer download done total=$totalBytes chunks=$chunkCount '
        'time=${dlWatch.elapsedMilliseconds}ms',
      );
    } finally {
      await localFile.close();
    }

    await staging.rename(to.path);
    staging = null;
    mainSendPort.send(const TransferStaging(''));

    mainSendPort.send(watch.elapsed);
    mainSendPort.send(FileTransferStage.finished);
  } catch (e, s) {
    error = e;
    stackTrace = s;
  } finally {
    await _discard(staging);
    await _closeSftpResources(
      remoteFile: remoteFile,
      sftp: sftp,
      client: client,
    );
  }

  if (error != null) {
    Loggers.app.warning('Transfer download failed: ${from.path}', error, stackTrace);
    mainSendPort.send(error);
  }
}

/// The name a half-finished transfer is parked under.
///
/// A counter rather than a timestamp: two transfers of the same file, started
/// in the same millisecond, must not stage onto each other.
var _staging = 0;

String get _stagingSuffix => 'sb-part-${_staging++}';

/// Renames [staging] over [path], deleting what is there if the server will
/// not replace it itself. See `SftpFileBackend._replace`, which faces the same
/// `SSH_FXP_RENAME` rule.
Future<void> _replaceRemote(
  SftpClient sftp,
  String staging,
  String path,
  Duration timeout,
) async {
  final Object failure;
  try {
    await withSftpOpTimeout('rename', sftp.rename(staging, path), timeout);
    return;
  } catch (e) {
    failure = e;
  }

  // Only "the destination is in the way" is worth a second attempt. Anything
  // else — no permission, no such directory — is the rename's own answer, and
  // deleting something on the strength of a misread would be worse than
  // failing.
  try {
    await withSftpOpTimeout('stat', sftp.stat(path), timeout);
  } catch (_) {
    throw failure;
  }
  await withSftpOpTimeout('remove', sftp.remove(path), timeout);
  await withSftpOpTimeout('rename', sftp.rename(staging, path), timeout);
}

Future<void> _discardRemote(SftpClient? sftp, String? staging) async {
  if (sftp == null || staging == null) return;
  try {
    await sftp.remove(staging);
  } catch (e, s) {
    Loggers.app.warning('Failed to remove a staged upload', e, s);
  }
}

Future<void> _discard(File? staging) async {
  if (staging == null) return;
  try {
    if (await staging.exists()) await staging.delete();
  } catch (e, s) {
    Loggers.app.warning('Failed to remove a staged download', e, s);
  }
}

/// This device to a server.
Future<void> _upload(
  FileTransfer job,
  LocalFileRef from,
  SftpFileRef to,
  SendPort mainSendPort,
) async {
  SSHClient? client;
  SftpClient? sftp;
  SftpFile? remoteFile;
  String? staging;
  Object? error;
  StackTrace? stackTrace;

  try {
    mainSendPort.send(FileTransferStage.preparing);
    final watch = Stopwatch()..start();
    client = await _connectSsh(to.creds, mainSendPort);
    mainSendPort.send(FileTransferStage.connected);
    Loggers.app.info('Transfer upload SSH connected: ${to.path}');

    final local = File(from.path);
    if (!await local.exists()) {
      mainSendPort.send(Exception('local file not exists'));
      return;
    }
    final localLen = await local.length();
    mainSendPort.send(localLen);
    final localFile = local.openRead().cast<Uint8List>();
    Loggers.app.info('Transfer upload opening session: ${to.path}');
    final openedSftp = await withSftpSessionOpenTimeout(
      'open upload session',
      client.sftp(),
      _prepareTimeout(job),
    );
    sftp = openedSftp;
    // Beside the destination rather than onto it. Truncating first meant a
    // failed upload replaced a good remote file with a partial one.
    staging = '${to.path}.$_stagingSuffix';
    Loggers.app.info('Transfer upload opening remote file: $staging');
    final openedRemoteFile = await withSftpOpTimeout(
      'open remote file for upload',
      openedSftp.open(
        staging,
        mode:
            SftpFileOpenMode.truncate |
            SftpFileOpenMode.create |
            SftpFileOpenMode.write,
      ),
      _prepareTimeout(job),
    );
    remoteFile = openedRemoteFile;
    mainSendPort.send(FileTransferStage.loading);
    Loggers.app.info(
      'Transfer upload started: ${to.path}, '
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
          mainSendPort.send(
            FileTransferProgress(
              percent: progress.toDouble(),
              transferredBytes: total,
            ),
          );
        }
      },
      chunkSize: _sftpChunkSize,
      maxBytesOnTheWire: _sftpUploadMaxBytesOnTheWire,
    );
    await writer.done;
    // Closed before the rename: a server need not see a handle to a path that
    // is about to stop existing.
    await remoteFile.close();
    remoteFile = null;
    await _replaceRemote(openedSftp, staging, to.path, _prepareTimeout(job));
    staging = null;

    mainSendPort.send(watch.elapsed);
    mainSendPort.send(FileTransferStage.finished);
  } catch (e, s) {
    error = e;
    stackTrace = s;
  } finally {
    await _discardRemote(sftp, staging);
    await _closeSftpResources(
      remoteFile: remoteFile,
      sftp: sftp,
      client: client,
    );
  }

  if (error != null) {
    Loggers.app.warning('Transfer upload failed: ${to.path}', error, stackTrace);
    mainSendPort.send(error);
  }
}

/// Any other pair: server to server, and this device to itself.
///
/// [FileBackend.read] into [FileBackend.write], which is the whole of a
/// transfer once neither end is privileged. Slower than the two above over a
/// fast link — no segmenting, no pipelining — and the pairs it serves are the
/// ones that could not be expressed at all before.
Future<void> _copy(FileTransfer job, SendPort mainSendPort) async {
  final closing = <Future<void> Function()>[];
  Object? error;
  StackTrace? stackTrace;

  try {
    mainSendPort.send(FileTransferStage.preparing);
    final watch = Stopwatch()..start();

    final source = await _openBackend(job, job.from, mainSendPort, closing);
    final dest = await _openBackend(job, job.to, mainSendPort, closing);
    mainSendPort.send(FileTransferStage.connected);

    final plan = await planCopy(
      source,
      job.from.path,
      job.to.path,
      isDir: job.isDir,
    );
    mainSendPort.send(plan.totalBytes);
    mainSendPort.send(FileTransferStage.loading);

    final intervalMs = Duration(
      seconds: job.progressUpdateIntervalSeconds,
    ).inMilliseconds;
    var lastUpdateMs = -intervalMs;
    final progressWatch = Stopwatch()..start();
    final total = plan.totalBytes;

    await runCopy(
      plan,
      source,
      dest,
      // Reported per file, so a transfer killed mid-write leaves a name this
      // side can sweep. `write` cleans up after its own failures; being killed
      // is not one of them.
      onStaging: (path) => mainSendPort.send(TransferStaging(path)),
      onProgress: (transferred) {
        final elapsedMs = progressWatch.elapsedMilliseconds;
        final done = total > 0 && transferred >= total;
        if (elapsedMs - lastUpdateMs < intervalMs && !done) return;
        lastUpdateMs = elapsedMs;
        mainSendPort.send(
          FileTransferProgress(
            // Without a total there is no percentage, only bytes. Reported as
            // zero rather than as a guess that would run past 100.
            percent: total == 0
                ? 0
                : (transferred / total * 100 * 10).roundToDouble() / 10,
            transferredBytes: transferred,
          ),
        );
      },
    );

    mainSendPort.send(watch.elapsed);
    mainSendPort.send(FileTransferStage.finished);
  } catch (e, s) {
    error = e;
    stackTrace = s;
  } finally {
    for (final close in closing.reversed) {
      try {
        await close();
      } catch (e, s) {
        Loggers.app.warning('Failed to close a transfer end', e, s);
      }
    }
  }

  if (error != null) {
    Loggers.app.warning(
      'Transfer failed: ${job.from} -> ${job.to}',
      error,
      stackTrace,
    );
    mainSendPort.send(error);
  }
}

Future<FileBackend> _openBackend(
  FileTransfer job,
  FileRef ref,
  SendPort mainSendPort,
  List<Future<void> Function()> closing,
) async {
  switch (ref) {
    case LocalFileRef():
      return const LocalFileBackend();
    case MonitorFileRef(:final monitor):
      // No prompts to marshal, but still a session with a connection pool
      // behind it, so it is registered for closing like the SSH one.
      final backend = MonitorFileBackend(monitor);
      closing.add(backend.close);
      return backend;
    case SftpFileRef(:final creds):
      final client = await _connectSsh(creds, mainSendPort);
      closing.add(() async => client.close());
      // No escalation: there is nobody on this isolate to ask for a password,
      // and a refusal is a refusal.
      final backend = await SftpFileBackend.connect(
        client,
        timeout: _prepareTimeout(job),
      );
      closing.add(backend.close);
      return backend;
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
