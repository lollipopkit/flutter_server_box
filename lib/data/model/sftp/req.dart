part of 'worker.dart';

class SftpReq {
  final Spi spi;
  final String remotePath;
  final String localPath;
  final SftpReqType type;
  String? privateKey;
  Spi? jumpSpi;
  String? jumpPrivateKey;
  Map<String, Spi>? jumpSpisById;
  Map<String, String>? privateKeysByKeyId;
  Map<String, String>? knownHostFingerprints;

  SftpReq(this.spi, this.remotePath, this.localPath, this.type) {
    privateKeysByKeyId = {};

    final keyId = spi.keyId;
    if (keyId != null) {
      privateKey = getPrivateKey(keyId);
      privateKeysByKeyId![keyId] = privateKey!;
    }

    final allServers = {
      for (final server in Stores.server.fetch()) server.id: server,
    };
    jumpSpisById = collectJumpServers(spi: spi, serversById: allServers);

    if (spi.jumpId != null) {
      jumpSpi = jumpSpisById?[spi.jumpId];
      jumpPrivateKey = Stores.key.fetchOne(jumpSpi?.keyId)?.key;
      if (jumpSpi?.keyId case final jumpKeyId?) {
        if (jumpPrivateKey != null) {
          privateKeysByKeyId![jumpKeyId] = jumpPrivateKey!;
        }
      }
    }

    for (final jump in jumpSpisById?.values ?? const <Spi>[]) {
      final jumpKeyId = jump.keyId;
      if (jumpKeyId == null || privateKeysByKeyId!.containsKey(jumpKeyId)) {
        continue;
      }
      final key = Stores.key.fetchOne(jumpKeyId)?.key;
      if (key == null) {
        continue;
      }
      privateKeysByKeyId![jumpKeyId] = key;
    }

    if (jumpSpisById != null && jumpSpisById!.isEmpty) {
      jumpSpisById = null;
    }
    if (privateKeysByKeyId != null && privateKeysByKeyId!.isEmpty) {
      privateKeysByKeyId = null;
    }

    try {
      knownHostFingerprints = Map<String, String>.from(
        Stores.setting.sshKnownHostFingerprints.get(),
      );
    } catch (e, s) {
      Loggers.app.warning('Failed to load SSH known host fingerprints', e, s);
      knownHostFingerprints = null;
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

  String get fileName => req.localPath.split(Pfs.seperator).last;

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
    worker = SftpWorker(onNotify: onNotify, req: req)..init();
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
