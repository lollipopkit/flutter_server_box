import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/server_status.dart';

class Server {
  ServerPrivateInfo spi;
  ServerStatus status;
  SSHClient? client;
  ServerState state;

  Server(this.spi, this.status, this.client, this.state);
}

enum ServerState {
  failed,
  disconnected,
  connecting,

  /// Connected to server
  connected,

  /// Status parsing
  loading,

  /// Status parsing finished
  finished;

  bool get shouldConnect => this < ServerState.connecting;

  bool get canViewDetails => this == ServerState.finished;

  operator <(ServerState other) => index < other.index;
}
