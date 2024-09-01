import 'package:dartssh2/dartssh2.dart';
import 'package:server_box/data/model/app/error.dart';
import 'package:server_box/data/model/app/shell_func.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/nvdia.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';

class Server {
  Spi spi;
  ServerStatus status;
  SSHClient? client;
  ServerConn conn;

  Server(
    this.spi,
    this.status,
    this.conn, {
    this.client,
  });

  bool get needGenClient => conn < ServerConn.connecting;

  bool get canViewDetails => conn == ServerConn.finished;

  String get id => spi.id;
}

class ServerStatus {
  Cpus cpu;
  Memory mem;
  Swap swap;
  List<Disk> disk;
  Conn tcp;
  NetSpeed netSpeed;
  Temperatures temps;
  SystemType system;
  Err? err;
  DiskIO diskIO;
  List<NvidiaSmiItem>? nvidia;
  final List<Battery> batteries = [];
  final Map<StatusCmdType, String> more = {};
  final List<SensorItem> sensors = [];
  DiskUsage? diskUsage;
  final Map<String, String> customCmds = {};

  ServerStatus({
    required this.cpu,
    required this.mem,
    required this.disk,
    required this.tcp,
    required this.netSpeed,
    required this.swap,
    required this.temps,
    required this.system,
    required this.diskIO,
    this.err,
    this.nvidia,
    this.diskUsage,
  });
}

enum ServerConn {
  failed,
  disconnected,
  connecting,

  /// Connected to server
  connected,

  /// Status parsing
  loading,

  /// Status parsing finished
  finished;

  bool operator <(ServerConn other) => index < other.index;
}
