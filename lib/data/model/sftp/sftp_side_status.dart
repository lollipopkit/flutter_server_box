import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/sftp/absolute_path.dart';

class SFTPSideViewStatus {
  bool selected = false;
  ServerPrivateInfo? spi;
  List<SftpName>? files;
  AbsolutePath? path;
  SftpClient? client;
  bool isBusy = false;

  SFTPSideViewStatus();
}
