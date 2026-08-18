import 'package:server_box/data/model/server/conn.dart';
import 'package:server_box/data/model/server/cpu.dart';
import 'package:server_box/data/model/server/disk.dart';
import 'package:server_box/data/model/server/memory.dart';
import 'package:server_box/data/model/server/net_speed.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/temp.dart';

abstract final class InitStatus {
  static const Memory mem = Memory(total: 1, free: 1, avail: 1);

  // The time series start out genuinely empty. They used to be seeded with two
  // synthetic all-zero samples so `pre`/`now` would never throw, which made
  // the first reading a delta against invented data.
  static Cpus get cpus => Cpus();
  static NetSpeed get netSpeed => NetSpeed();
  static ServerStatus get status => ServerStatus(
    cpu: cpus,
    mem: mem,
    disk: [
      Disk(
        path: '/',
        mount: '/',
        usedPercent: 0,
        used: BigInt.zero,
        size: BigInt.one,
        avail: BigInt.zero,
      ),
    ],
    tcp: const Conn(maxConn: 0, fail: 0),
    netSpeed: netSpeed,
    swap: const Swap(total: 0, free: 0, cached: 0),
    system: SystemType.linux,
    temps: Temperatures(),
    diskIO: DiskIO(),
    diskSmart: const [],
  );
}
