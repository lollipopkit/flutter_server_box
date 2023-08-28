import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:toolbox/data/model/server/server_status.dart';

part 'net_view.g.dart';

@HiveType(typeId: 5)
enum NetViewType {
  @HiveField(0)
  conn,
  @HiveField(1)
  speed,
  @HiveField(2)
  traffic;

  String l10n(S s) {
    switch (this) {
      case NetViewType.conn:
        return s.conn;
      case NetViewType.traffic:
        return s.traffic;
      case NetViewType.speed:
        return s.speed;
    }
  }

  NetViewData build(ServerStatus ss) {
    switch (this) {
      case NetViewType.conn:
        return NetViewData(
          'Conn:\n${ss.tcp.maxConn}',
          'Fail:\n${ss.tcp.fail}',
        );
      case NetViewType.speed:
        return NetViewData(
          'In:\n${ss.netSpeed.speedIn(all: true)}',
          'Out:\n${ss.netSpeed.speedOut(all: true)}',
        );
      case NetViewType.traffic:
        return NetViewData(
          'In:\n${ss.netSpeed.sizeIn(all: true)}',
          'Out:\n${ss.netSpeed.sizeOut(all: true)}',
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

class NetViewData {
  final String up;
  final String down;

  NetViewData(this.up, this.down);
}
