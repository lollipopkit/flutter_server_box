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

  NetViewType get next {
    switch (this) {
      case conn:
        return speed;
      case speed:
        return traffic;
      case traffic:
        return conn;
    }
  }

  String get toStr {
    switch (this) {
      case NetViewType.conn:
        return l10n.conn;
      case NetViewType.traffic:
        return l10n.traffic;
      case NetViewType.speed:
        return l10n.speed;
    }
  }

  (String, String) build(ServerStatus ss) {
    final ignoreLocal = Stores.setting.ignoreLocalNet.fetch();
    switch (this) {
      case NetViewType.conn:
        return (
          '${l10n.conn}:\n${ss.tcp.maxConn}',
          '${l10n.failed}:\n${ss.tcp.fail}',
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

  int toJson() {
    switch (this) {
      case NetViewType.conn:
        return 0;
      case NetViewType.speed:
        return 1;
      case NetViewType.traffic:
        return 2;
    }
  }

  static NetViewType fromJson(int json) {
    switch (json) {
      case 0:
        return NetViewType.conn;
      case 2:
        return NetViewType.traffic;
      default:
        return NetViewType.speed;
    }
  }
}
