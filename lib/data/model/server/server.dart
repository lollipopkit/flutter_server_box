import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/server_status.dart';

import '../app/tag_pickable.dart';

class Server implements TagPickable {
  ServerPrivateInfo spi;
  ServerStatus status;
  SSHClient? client;
  ServerState state;

  /// Whether is generating client. 
  /// Use this to avoid reconnecting if last connect try not finished.
  bool isGenerating = false;

  Server(this.spi, this.status, this.client, this.state);

  @override
  bool containsTag(String tag) {
    return spi.tags?.contains(tag) ?? false;
  }

  @override
  String get tagName => spi.id;
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
