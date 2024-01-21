import 'package:toolbox/data/model/container/type.dart';

import '../../core/persistant_store.dart';

const _keyConfig = 'providerConfig';

class DockerStore extends PersistentStore {
  DockerStore() : super('docker');

  String? fetch(String? id) {
    return box.get(id);
  }

  void put(String id, String host) {
    box.put(id, host);
  }

  ContainerType getType([String? id]) {
    final cfg = box.get(_keyConfig + (id ?? ''));
    if (cfg == null) {
      return ContainerType.docker;
    } else {
      return ContainerType.values.firstWhere((e) => e.toString() == cfg);
    }
  }

  void setType(String? id, ContainerType type) {
    box.put(_keyConfig + (id ?? ''), type.toString());
  }
}
