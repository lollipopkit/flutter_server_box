import 'package:dartssh2/dartssh2.dart';
import 'package:toolbox/data/model/server/conn.dart';
import 'package:toolbox/data/model/server/cpu.dart';
import 'package:toolbox/data/model/server/disk.dart';
import 'package:toolbox/data/model/server/memory.dart';
import 'package:toolbox/data/model/server/net_speed.dart';
import 'package:toolbox/data/model/server/server_private_info.dart';
import 'package:toolbox/data/model/server/system.dart';
import 'package:toolbox/data/model/server/temp.dart';

import '../app/tag_pickable.dart';

class Server implements TagPickable {
  ServerPrivateInfo spi;
  ServerStatus status;
  SSHClient? client;
  ServerState state;

  Server(
    this.spi,
    this.status,
    this.state, {
    this.client,
  });

  @override
  bool containsTag(String tag) {
    return spi.tags?.contains(tag) ?? false;
  }

  @override
  String get tagName => spi.id;

  bool get needGenClient => state < ServerState.connecting;

  bool get canViewDetails => state == ServerState.finished;

  String get id => spi.id;

  bool get isBusy => status._isBusy;

  set isBusy(bool value) => status._isBusy = value;
}

class ServerStatus {
  Cpus cpu;
  Memory mem;
  Swap swap;
  String sysVer;
  String uptime;
  List<Disk> disk;
  Conn tcp;
  NetSpeed netSpeed;
  Temperatures temps;
  SystemType system;
  String? err;
  DiskIO diskIO;

  /// Whether is connectting, parsing and etc.
  bool _isBusy = false;

  ServerStatus({
    required this.cpu,
    required this.mem,
    required this.sysVer,
    required this.uptime,
    required this.disk,
    required this.tcp,
    required this.netSpeed,
    required this.swap,
    required this.temps,
    required this.system,
    required this.diskIO,
    this.err,
  });
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
