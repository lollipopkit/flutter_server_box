import 'package:ssh2/ssh2.dart';
import 'package:toolbox/data/model/server_private_info.dart';
import 'package:toolbox/data/model/server_status.dart';

class ServerInfo {
  ServerPrivateInfo info;
  ServerStatus status;
  SSHClient client;

  ServerInfo(this.info, this.status, this.client);
}
