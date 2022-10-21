import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/server_status.dart';

class ServerInfo {
  ServerPrivateInfo info;
  ServerStatus status;
  SSHClient? client;
  ServerConnectionState connectionState;

  ServerInfo(this.info, this.status, this.client, this.connectionState);
}

enum ServerConnectionState { disconnected, connecting, connected, failed }
