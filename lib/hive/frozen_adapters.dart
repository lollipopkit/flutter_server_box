import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/app/net_view.dart';
import 'package:server_box/data/model/app/tab.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';

/// The adapters that were generated from live models, frozen as the last
/// generation wrote them, so the models carry no Hive annotations and a change
/// to one cannot change what an old box reads as (see `legacy_adapters.dart`).
///
/// An enum read on its own still answers the app's enum, by the byte the
/// generated adapter gave each case; one nested in a record answers the JSON
/// value its model wrote.
///
/// TODO: delete with `HiveImport`.
/// [override] re-registers over what a test put in their place.
void registerHiveFrozenAdapters({bool override = false}) {
  void register<T>(TypeAdapter<T> adapter) => Hive.registerAdapter(adapter, override: override);

  register(_EnumAdapter(103, AppTab.server, const {
    0: AppTab.server,
    1: AppTab.ssh,
    2: AppTab.file,
    3: AppTab.snippet,
    4: AppTab.agent,
    5: AppTab.benchmark,
    6: AppTab.remoteDesktop,
    7: AppTab.virt,
    8: AppTab.workspace,
    9: AppTab.monitor,
  }));
  register(_EnumAdapter(5, NetViewType.conn, const {
    0: NetViewType.conn,
    1: NetViewType.speed,
    2: NetViewType.traffic,
  }));
  register(_EnumAdapter(6, ServerFuncBtn.terminal, const {
    0: ServerFuncBtn.terminal,
    1: ServerFuncBtn.files,
    2: ServerFuncBtn.container,
    3: ServerFuncBtn.process,
    5: ServerFuncBtn.snippet,
    6: ServerFuncBtn.iperf,
    8: ServerFuncBtn.systemd,
    9: ServerFuncBtn.portForward,
    10: ServerFuncBtn.power,
    12: ServerFuncBtn.users,
    13: ServerFuncBtn.scheduledTasks,
    14: ServerFuncBtn.remoteDesktop,
    15: ServerFuncBtn.firewall,
    16: ServerFuncBtn.storage,
    17: ServerFuncBtn.shares,
  }));
  register(_EnumAdapter(9, SystemType.linux, const {
    0: SystemType.linux,
    1: SystemType.bsd,
    2: SystemType.windows,
  }));
  register(
    _WireAdapter(102, const ['success', 'timeout', 'auth_failed', 'network_error', 'unknown_error'], LegacyConnectionResult.new),
  );
  register(_WireAdapter(12, const ['local', 'remote', 'dynamic'], LegacyPortForwardType.new));
  register(LegacyWakeOnLanCfgAdapter());
  register(LegacyPortForwardConfigAdapter());
  register(LegacyConnectionStatAdapter());
  register(LegacyServerConnectionStatsAdapter());
}

/// A byte, as the app's enum [T]; an unknown byte is [fallback], as the
/// generated adapter answered.
final class _EnumAdapter<T extends Enum> extends TypeAdapter<T> {
  const _EnumAdapter(this.typeId, this.fallback, this.cases);

  @override
  final int typeId;
  final T fallback;
  final Map<int, T> cases;

  @override
  T read(BinaryReader reader) => cases[reader.readByte()] ?? fallback;

  @override
  void write(BinaryWriter writer, T obj) => throw UnsupportedError('Hive is read-only');
}

/// A nested enum's byte, as the value its model's JSON wrote; an unknown
/// byte is the first, as the generated adapter answered.
final class _WireAdapter<T extends LegacyWire> extends TypeAdapter<T> {
  const _WireAdapter(this.typeId, this.values, this.wrap);

  @override
  final int typeId;
  final List<String> values;
  final T Function(String) wrap;

  @override
  T read(BinaryReader reader) {
    final index = reader.readByte();
    return wrap(index < values.length ? values[index] : values.first);
  }

  @override
  void write(BinaryWriter writer, T obj) => throw UnsupportedError('Hive is read-only');
}

/// A nested enum as its JSON value. One type per enum: Hive keys adapters by
/// runtime type as well as by id.
sealed class LegacyWire {
  const LegacyWire(this.value);

  final String value;

  String toJson() => value;
}

/// typeId 102.
final class LegacyConnectionResult extends LegacyWire {
  const LegacyConnectionResult(super.value);
}

/// typeId 12.
final class LegacyPortForwardType extends LegacyWire {
  const LegacyPortForwardType(super.value);
}

Map<int, dynamic> _fields(BinaryReader reader) {
  final n = reader.readByte();
  return {for (var i = 0; i < n; i++) reader.readByte(): reader.read()};
}

/// typeId 8.
final class LegacyWakeOnLanCfgV1 {
  const LegacyWakeOnLanCfgV1({required this.mac, required this.ip, this.pwd});

  final String mac;
  final String ip;
  final String? pwd;

  WakeOnLanCfg toCfg() => WakeOnLanCfg(mac: mac, ip: ip, pwd: pwd);

  Map<String, dynamic> toJson() => {'mac': mac, 'ip': ip, 'pwd': ?pwd};
}

final class LegacyWakeOnLanCfgAdapter extends TypeAdapter<LegacyWakeOnLanCfgV1> {
  @override
  final typeId = 8;

  @override
  LegacyWakeOnLanCfgV1 read(BinaryReader reader) {
    final f = _fields(reader);
    return LegacyWakeOnLanCfgV1(mac: f[0] as String, ip: f[1] as String, pwd: f[2] as String?);
  }

  @override
  void write(BinaryWriter writer, LegacyWakeOnLanCfgV1 obj) => throw UnsupportedError('Hive is read-only');
}

/// typeId 10; `type` is typeId 12.
final class LegacyPortForwardConfigV1 {
  const LegacyPortForwardConfigV1(this.json);

  final Map<String, dynamic> json;

  Map<String, dynamic> toJson() => json;
}

final class LegacyPortForwardConfigAdapter extends TypeAdapter<LegacyPortForwardConfigV1> {
  @override
  final typeId = 10;

  @override
  LegacyPortForwardConfigV1 read(BinaryReader reader) {
    final f = _fields(reader);
    return LegacyPortForwardConfigV1({
      'id': f[0] as String,
      'serverId': f[7] as String,
      'name': f[1] as String,
      'type': (f[8] as LegacyWire).value,
      'localHost': f[2] as String?,
      'localPort': f[3] == null ? 0 : (f[3] as num).toInt(),
      'remoteHost': f[4] as String?,
      'remotePort': (f[5] as num?)?.toInt(),
    });
  }

  @override
  void write(BinaryWriter writer, LegacyPortForwardConfigV1 obj) => throw UnsupportedError('Hive is read-only');
}

/// typeId 100; `result` is typeId 102.
final class LegacyConnectionStatV1 {
  const LegacyConnectionStatV1(this.json);

  final Map<String, dynamic> json;

  Map<String, dynamic> toJson() => json;
}

final class LegacyConnectionStatAdapter extends TypeAdapter<LegacyConnectionStatV1> {
  @override
  final typeId = 100;

  @override
  LegacyConnectionStatV1 read(BinaryReader reader) {
    final f = _fields(reader);
    return LegacyConnectionStatV1({
      'serverId': f[0] as String,
      'serverName': f[1] as String,
      'timestamp': (f[2] as DateTime).toIso8601String(),
      'result': (f[3] as LegacyWire).value,
      'errorMessage': f[4] == null ? '' : f[4] as String,
      'durationMs': (f[5] as num).toInt(),
    });
  }

  @override
  void write(BinaryWriter writer, LegacyConnectionStatV1 obj) => throw UnsupportedError('Hive is read-only');
}

/// typeId 101.
final class LegacyServerConnectionStatsV1 {
  const LegacyServerConnectionStatsV1(this.json);

  final Map<String, dynamic> json;

  Map<String, dynamic> toJson() => json;
}

final class LegacyServerConnectionStatsAdapter extends TypeAdapter<LegacyServerConnectionStatsV1> {
  @override
  final typeId = 101;

  @override
  LegacyServerConnectionStatsV1 read(BinaryReader reader) {
    final f = _fields(reader);
    return LegacyServerConnectionStatsV1({
      'serverId': f[0] as String,
      'serverName': f[1] as String,
      'totalAttempts': (f[2] as num).toInt(),
      'successCount': (f[3] as num).toInt(),
      'failureCount': (f[4] as num).toInt(),
      'lastSuccessTime': (f[5] as DateTime?)?.toIso8601String(),
      'lastFailureTime': (f[6] as DateTime?)?.toIso8601String(),
      'recentConnections': [
        for (final c in (f[7] as List?) ?? const []) (c as LegacyConnectionStatV1).json,
      ],
      'successRate': (f[8] as num).toDouble(),
    });
  }

  @override
  void write(BinaryWriter writer, LegacyServerConnectionStatsV1 obj) => throw UnsupportedError('Hive is read-only');
}
