import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/res/store.dart';

const _keyConfig = 'providerConfig';

class ContainerStore extends HiveStore {
  ContainerStore._() : super('docker');

  static final instance = ContainerStore._();

  String? fetch(String? id) {
    return box.get(id);
  }

  void put(String id, String host) {
    box.put(id, host);
    updateLastUpdateTs();
  }

  ContainerType getType([String id = '']) {
    final cfg = box.get(_keyConfig + id);
    if (cfg != null) {
      final type =
          ContainerType.values.firstWhereOrNull((e) => e.toString() == cfg);
      if (type != null) return type;
    }

    return defaultType;
  }

  ContainerType get defaultType {
    if (Stores.setting.usePodman.get()) return ContainerType.podman;
    return ContainerType.docker;
  }

  void setType(ContainerType type, [String id = '']) {
    if (type == defaultType) {
      box.delete(_keyConfig + id);
    } else {
      box.put(_keyConfig + id, type.toString());
    }
    updateLastUpdateTs();
  }
}
