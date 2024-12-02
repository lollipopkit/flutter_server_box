part of 'worker.dart';

class SftpReq {
  final Spi spi;
  final String remotePath;
  final String localPath;
  final SftpReqType type;
  String? privateKey;
  Spi? jumpSpi;
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
      jumpPrivateKey = Stores.key.fetchOne(jumpSpi?.keyId)?.key;
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
    worker._dispose();
    completer?.complete(true);
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
}

enum SftpWorkerStatus { preparing, sshConnectted, loading, finished }
