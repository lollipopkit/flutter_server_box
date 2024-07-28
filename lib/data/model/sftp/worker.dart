import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_isolate/easy_isolate.dart';
import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/utils/server.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/res/store.dart';

part 'req.dart';

class SftpWorker {
  final Function(Object event) onNotify;
  final SftpReq req;

  final worker = Worker();

  SftpWorker({
    required this.onNotify,
    required this.req,
  });

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
        default:
          sendError(Exception('unknown type'));
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
    );
    mainSendPort.send(SftpWorkerStatus.sshConnectted);

    /// Create the directory if not exists
    final dirPath = req.localPath.substring(0, req.localPath.lastIndexOf('/'));
    await Directory(dirPath).create(recursive: true);

    /// Use [FileMode.write] to overwrite the file
    final localFile = File(req.localPath).openWrite(mode: FileMode.write);
    final file = await (await client.sftp()).open(req.remotePath);
    final size = (await file.stat()).size;
    if (size == null) {
      mainSendPort.send(Exception('can\'t get file size: ${req.remotePath}'));
      return;
    }

    mainSendPort.send(size);
    mainSendPort.send(SftpWorkerStatus.loading);

    // Read 2m each time
    // Issue #161
    // The download speed is about 2m/s may due to single core performance
    const defaultChunkSize = 1024 * 1024 * 2;
    final chunkSize = size > defaultChunkSize ? defaultChunkSize : size;
    for (var i = 0; i < size; i += chunkSize) {
      final fileData = file.read(length: chunkSize);
      await for (var form in fileData) {
        localFile.add(form);
        mainSendPort.send((i + form.length) / size * 100);
      }
    }

    await localFile.close();
    await file.close();

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
    final sftp = await client.sftp();
    // If remote exists, overwrite it
    final file = await sftp.open(
      req.remotePath,
      mode: SftpFileOpenMode.truncate |
          SftpFileOpenMode.create |
          SftpFileOpenMode.write,
    );
    final writer = file.write(
      localFile,
      onProgress: (total) {
        mainSendPort.send(total / localLen * 100);
      },
    );
    await writer.done;
    await file.close();
    mainSendPort.send(watch.elapsed);
    mainSendPort.send(SftpWorkerStatus.finished);
  } catch (e) {
    mainSendPort.send(e);
  }
}
