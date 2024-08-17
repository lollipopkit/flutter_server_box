import 'package:fl_lib/fl_lib.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server.dart';

part 'net_view.g.dart';

@HiveType(typeId: 5)
enum NetViewType {
  @HiveField(0)
  conn,
  @HiveField(1)
  speed,
  @HiveField(2)
  traffic;

  NetViewType get next => switch (this) {
        conn => speed,
        speed => traffic,
        traffic => conn,
      };

  String get toStr => switch (this) {
        NetViewType.conn => l10n.conn,
        NetViewType.traffic => l10n.traffic,
        NetViewType.speed => l10n.speed,
      };

  /// If no device is specified, return the cached value (only real devices,
  /// such as ethX, wlanX...).
  (String, String) build(ServerStatus ss, {String? dev}) {
    final notSepcifyDev = dev == null || dev.isEmpty;
    try {
      switch (this) {
        case NetViewType.conn:
          return (
            '${l10n.conn}:\n${ss.tcp.maxConn}',
            '${libL10n.fail}:\n${ss.tcp.fail}',
          );
        case NetViewType.speed:
          if (notSepcifyDev) {
            return (
              '↓:\n${ss.netSpeed.cachedVals.speedIn}',
              '↑:\n${ss.netSpeed.cachedVals.speedOut}',
            );
          }
          return (
            '↓:\n${ss.netSpeed.speedIn(device: dev)}',
            '↑:\n${ss.netSpeed.speedOut(device: dev)}',
          );
        case NetViewType.traffic:
          if (notSepcifyDev) {
            return (
              '↓:\n${ss.netSpeed.cachedVals.sizeIn}',
              '↑:\n${ss.netSpeed.cachedVals.sizeOut}',
            );
          }
          return (
            '↓:\n${ss.netSpeed.sizeIn(device: dev)}',
            '↑:\n${ss.netSpeed.sizeOut(device: dev)}',
          );
      }
    } catch (e, s) {
      Loggers.app.warning('NetViewType.build', e, s);
      return ('N/A', 'N/A');
    }
  }

  int toJson() => switch (this) {
        NetViewType.conn => 0,
        NetViewType.speed => 1,
        NetViewType.traffic => 2,
      };

  static NetViewType fromJson(int json) => switch (json) {
        0 => NetViewType.conn,
        1 => NetViewType.speed,
        _ => NetViewType.traffic,
      };
}
