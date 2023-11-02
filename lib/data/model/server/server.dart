import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/server_status.dart';

import '../app/tag_pickable.dart';

class Server implements TagPickable {
  ServerPrivateInfo spi;
  ServerStatus status;
  SSHClient? client;
  ServerState state;

  /// Whether is connectting, parsing and etc.
  bool isBusy = false;

  Server(this.spi, this.status, this.client, this.state);

  @override
  bool containsTag(String tag) {
    return spi.tags?.contains(tag) ?? false;
  }

  @override
  String get tagName => spi.id;

  bool get needGenClient => state < ServerState.connecting;

  bool get canViewDetails => state == ServerState.finished;

  String get id => spi.id;
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

  operator <(ServerState other) => index < other.index;
}
