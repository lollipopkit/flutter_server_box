import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:dartssh2/dartssh2.dart';
import 'package:easy_isolate/easy_isolate.dart';

import 'download_item.dart';
import 'download_status.dart';

class SftpDownloadWorker {
  SftpDownloadWorker(
      {required this.onNotify, required this.item, this.privateKey});

  final Function(Object event) onNotify;
  final DownloadItem item;
  final worker = Worker();
  final String? privateKey;

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
    worker.sendMessage(DownloadItemEvent(item, privateKey));
  }

  /// Handle the messages coming from the isolate
  void mainMessageHandler(dynamic data, SendPort isolateSendPort) {
    onNotify(data);
  }

  /// Handle the messages coming from the main
  static isolateMessageHandler(
      dynamic data, SendPort mainSendPort, SendErrorFunction sendError) async {
    if (data is DownloadItemEvent) {
      try {
        mainSendPort.send(SftpWorkerStatus.preparing);
        final watch = Stopwatch()..start();
        final item = data.item;
        final spi = item.spi;
        final socket = await SSHSocket.connect(spi.ip, spi.port);
        SSHClient client;
        if (spi.pubKeyId == null) {
          client = SSHClient(socket,
              username: spi.user, onPasswordRequest: () => spi.pwd);
        } else {
          client = SSHClient(socket,
              username: spi.user,
              identities: SSHKeyPair.fromPem(data.privateKey!));
        }
        mainSendPort.send(SftpWorkerStatus.sshConnectted);

        final remotePath = item.remotePath;
        final localPath = item.localPath;
        await Directory(localPath.substring(0, item.localPath.lastIndexOf('/')))
            .create(recursive: true);
        final local = File(localPath);
        if (await local.exists()) {
          await local.delete();
        }
        final localFile = local.openWrite(mode: FileMode.append);
        final file = await (await client.sftp()).open(remotePath);
        final size = (await file.stat()).size;
        if (size == null) {
          mainSendPort.send(Exception('can not get file size'));
          return;
        }
        const defaultChunkSize = 1024 * 1024;
        final chunkSize = size > defaultChunkSize ? defaultChunkSize : size;
        mainSendPort.send(size);
        mainSendPort.send(SftpWorkerStatus.downloading);
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
  }
}
