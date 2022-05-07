import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/sftp/download_status.dart';
import 'package:toolbox/data/model/sftp/download_worker.dart';

class SftpDownloadProvider extends ProviderBase {
  final List<SftpDownloadStatus> _status = [];
  List<SftpDownloadStatus> get status => _status;

  List<SftpDownloadStatus> gets({int? id, String? fileName}) {
    var found = <SftpDownloadStatus>[];
    if (id != null) {
      found = _status.where((e) => e.id == id).toList();
    }
    if (fileName != null) {
      found = found
          .where((e) => e.item.localPath.split('/').last == fileName)
          .toList();
    }
    return found;
  }

  SftpDownloadStatus? get({int? id, String? name}) {
    final found = gets(id: id, fileName: name);
    if (found.isEmpty) return null;
    return found.first;
  }

  void add(DownloadItem item, {String? key}) {
    _status.add(SftpDownloadStatus(item, notifyListeners, key: key));
  }
}
