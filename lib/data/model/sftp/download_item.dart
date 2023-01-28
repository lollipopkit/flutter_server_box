import '../server/server_private_info.dart';

class DownloadItem {
  DownloadItem(this.spi, this.remotePath, this.localPath);

  final ServerPrivateInfo spi;
  final String remotePath;
  final String localPath;
}

class DownloadItemEvent {
  DownloadItemEvent(this.item, this.privateKey);

  final DownloadItem item;
  final String? privateKey;
}
