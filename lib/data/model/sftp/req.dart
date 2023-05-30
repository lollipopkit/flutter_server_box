import '../server/server_private_info.dart';
import 'worker.dart';

class SftpReqItem {
  final ServerPrivateInfo spi;
  final String remotePath;
  final String localPath;

  SftpReqItem(this.spi, this.remotePath, this.localPath);
}

enum SftpReqType { download, upload }

class SftpReq {
  final SftpReqItem item;
  final String? privateKey;
  final SftpReqType type;

  SftpReq({required this.item, this.privateKey, required this.type});
}

class SftpReqStatus {
  final int id;
  final SftpReqItem item;
  final void Function() notifyListeners;
  late SftpWorker worker;

  String get fileName => item.localPath.split('/').last;

  // status of the download
  double? progress;
  SftpWorkerStatus? status;
  int? size;
  Exception? error;
  Duration? spentTime;

  SftpReqStatus({
    required this.item,
    required this.notifyListeners,
    required SftpReqType type,
    String? key,
  }) : id = DateTime.now().microsecondsSinceEpoch {
    worker = SftpWorker(
      onNotify: onNotify,
      item: item,
      privateKey: key,
      type: type,
    );
    worker.init();
  }

  @override
  bool operator ==(Object other) => other is SftpReqStatus && id == other.id;

  @override
  int get hashCode => id ^ super.hashCode;

  void onNotify(dynamic event) {
    switch (event.runtimeType) {
      case SftpWorkerStatus:
        status = event;
        if (status == SftpWorkerStatus.finished) {
          worker.dispose();
        }
        break;
      case double:
        progress = event;
        break;
      case int:
        size = event;
        break;
      case Exception:
        error = event;
        break;
      case Duration:
        spentTime = event;
        break;
      default:
    }
    notifyListeners();
  }
}

enum SftpWorkerStatus { preparing, sshConnectted, downloading, finished }
