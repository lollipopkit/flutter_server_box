import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/data/model/sftp/absolute_path.dart';

class SftpBrowserStatus {
  final List<SftpName> files = [];
  final AbsolutePath path = AbsolutePath('/');
  SftpClient? client;

  SftpBrowserStatus(SSHClient client) {
    client.sftp().then((value) => this.client = value);
  }
}
