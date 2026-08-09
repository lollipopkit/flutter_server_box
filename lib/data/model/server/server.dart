import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/app/scripts/cmd_types.dart';
import 'package:server_box/data/model/server/amd.dart';
import 'package:server_box/data/model/server/battery.dart';
import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/disk_smart.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/nvdia.dart';
import 'package:server_box/data/model/server/sensors.dart';
import 'package:server_box/data/model/server/status_history.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';

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
  List<DiskSmart> diskSmart;
  List<NvidiaSmiItem>? nvidia;
  List<AmdSmiItem>? amd;
  final List<Battery> batteries = [];
  final Map<StatusCmdType, String> more = {};
  final List<SensorItem> sensors = [];
  DiskUsage? diskUsage;
  final Map<String, String> customCmds = {};

  /// Trend data for the chart cards, appended to after every successful
  /// refresh. Lives here rather than in the UI so it survives navigation, and
  /// so both the SSH and the monitor HTTP path feed one buffer.
  ///
  /// A refresh builds a new [ServerStatus] around the same mutable sub-objects
  /// (`cpu`, `netSpeed`, ...); callers doing that must carry this over too, or
  /// the trend restarts from empty every cycle.
  final StatusHistory history;

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
    this.diskSmart = const [],
    this.err,
    this.nvidia,
    this.diskUsage,
    StatusHistory? history,
  }) : history = history ?? StatusHistory();
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

  /// Orders by declaration index: failed < disconnected < connecting <
  /// connected < loading < finished. Do NOT reorder the enum values
  /// above without auditing all call sites that rely on this ordering.
  bool operator <(ServerConn other) => index < other.index;
}
