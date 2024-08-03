import 'package:fl_lib/fl_lib.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:server_box/core/extension/context/locale.dart';
import 'package:server_box/data/model/server/server.dart';
import 'package:server_box/data/res/store.dart';

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

  (String, String) build(ServerStatus ss) {
    final ignoreLocal = Stores.setting.ignoreLocalNet.fetch();
    switch (this) {
      case NetViewType.conn:
        return (
          '${l10n.conn}:\n${ss.tcp.maxConn}',
          '${libL10n.fail}:\n${ss.tcp.fail}',
        );
      case NetViewType.speed:
        if (ignoreLocal) {
          return (
            '↓:\n${ss.netSpeed.cachedRealVals.speedIn}',
            '↑:\n${ss.netSpeed.cachedRealVals.speedOut}',
          );
        }
        return (
          '↓:\n${ss.netSpeed.speedIn()}',
          '↑:\n${ss.netSpeed.speedOut()}',
        );
      case NetViewType.traffic:
        if (ignoreLocal) {
          return (
            '↓:\n${ss.netSpeed.cachedRealVals.sizeIn}',
            '↑:\n${ss.netSpeed.cachedRealVals.sizeOut}',
          );
        }
        return (
          '↓:\n${ss.netSpeed.sizeIn()}',
          '↑:\n${ss.netSpeed.sizeOut()}',
        );
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
