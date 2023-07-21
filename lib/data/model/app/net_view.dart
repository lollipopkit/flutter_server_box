import 'package:hive_flutter/hive_flutter.dart';
import 'package:toolbox/data/model/server/server_status.dart';

part 'net_view.g.dart';

@HiveType(typeId: 5)
enum NetViewType {
  @HiveField(0)
  count,
  @HiveField(1)
  speed,
  @HiveField(2)
  size;

  NetViewData build(ServerStatus ss) {
    switch (this) {
      case NetViewType.count:
        return NetViewData(
          'Conn:\n${ss.tcp.maxConn}',
          'Fail:\n${ss.tcp.fail}',
        );
      case NetViewType.speed:
        return NetViewData(
          'In:\n${ss.netSpeed.speedIn(all: true)}',
          'Out:\n${ss.netSpeed.speedOut(all: true)}',
        );
      case NetViewType.size:
        return NetViewData(
          'In:\n${ss.netSpeed.sizeIn(all: true)}',
          'Out:\n${ss.netSpeed.sizeOut(all: true)}',
        );
    }
  }
}

class NetViewData {
  final String up;
  final String down;

  NetViewData(this.up, this.down);
}
