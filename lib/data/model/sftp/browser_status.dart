import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/data/model/sftp/absolute_path.dart';

class SftpBrowserStatus {
  List<SftpName>? files;
  AbsolutePath? path;
  SftpClient? client;

  SftpBrowserStatus();
}
