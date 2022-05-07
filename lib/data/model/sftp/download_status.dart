import 'package:toolbox/data/model/sftp/download_worker.dart';

class SftpDownloadStatus {
  final int id;
  final DownloadItem item;
  final void Function() notifyListeners;
  late SftpDownloadWorker worker;

  String get fileName => item.localPath.split('/').last;

  // status of the download
  double? progress;
  SftpWorkerStatus? status;
  int? size;
  Exception? error;
  Duration? spentTime;

  SftpDownloadStatus(this.item, this.notifyListeners, {String? key})
      : id = DateTime.now().microsecondsSinceEpoch {
    worker =
        SftpDownloadWorker(onNotify: onNotify, item: item, privateKey: key);
    worker.init();
  }

  @override
  bool operator ==(Object other) =>
      other is SftpDownloadStatus && id == other.id;

  @override
  int get hashCode => id ^ super.hashCode;

  void onNotify(dynamic event) {
    switch (event.runtimeType) {
      case SftpWorkerStatus:
        status = event;
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
