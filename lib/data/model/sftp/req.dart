import 'dart:async';

import 'package:toolbox/data/res/logger.dart';
import 'package:toolbox/data/res/store.dart';

import '../../../core/utils/server.dart';
import '../server/server_private_info.dart';
import 'worker.dart';

class SftpReq {
  final ServerPrivateInfo spi;
  final String remotePath;
  final String localPath;
  final SftpReqType type;
  String? privateKey;
  ServerPrivateInfo? jumpSpi;
  String? jumpPrivateKey;

  SftpReq(
    this.spi,
    this.remotePath,
    this.localPath,
    this.type,
  ) {
    final keyId = spi.keyId;
    if (keyId != null) {
      privateKey = getPrivateKey(keyId);
    }
    if (spi.jumpId != null) {
      jumpSpi = Stores.server.box.get(spi.jumpId);
      jumpPrivateKey = Stores.key.get(jumpSpi?.keyId)?.key;
    }
  }
}

enum SftpReqType { download, upload }

class SftpReqStatus {
  final int id;
  final SftpReq req;
  final void Function() notifyListeners;
  late SftpWorker worker;
  final Completer? completer;

  String get fileName => req.localPath.split('/').last;

  // status of the download
  double? progress;
  SftpWorkerStatus? status;
  int? size;
  Exception? error;
  Duration? spentTime;

  SftpReqStatus({
    required this.req,
    required this.notifyListeners,
    this.completer,
  }) : id = DateTime.now().microsecondsSinceEpoch {
    worker = SftpWorker(
      onNotify: onNotify,
      req: req,
    )..init();
  }

  @override
  bool operator ==(Object other) => other is SftpReqStatus && id == other.id;

  @override
  int get hashCode => id ^ super.hashCode;

  void dispose() {
    // ignore: deprecated_member_use_from_same_package
    worker.dispose();
    completer?.complete();
  }

  void onNotify(dynamic event) {
    switch (event.runtimeType) {
      case SftpWorkerStatus:
        status = event;
        if (status == SftpWorkerStatus.finished) {
          dispose();
        }
        break;
      case double:
        progress = event;
        break;
      case int:
        size = event;
        break;
      case Duration:
        spentTime = event;
        break;
      default:
        error = Exception('sftp worker event: $event');
        Loggers.app.warning(error);
        dispose();
        break;
    }
    notifyListeners();
  }
}

enum SftpWorkerStatus { preparing, sshConnectted, loading, finished }
