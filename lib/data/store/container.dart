import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/container/type.dart';
import 'package:server_box/data/res/store.dart';

const _keyConfig = 'providerConfig';
const _keyHost = 'containerHost';

class ContainerStore extends HiveStore {
  ContainerStore._() : super('docker');

  static final instance = ContainerStore._();

  String? fetch(String? id, ContainerType type) {
    final host = box.get(_hostKey(id, type));
    if (host != null || type == ContainerType.podman) return host;

    // Preserve existing Docker host settings stored before per-runtime hosts.
    return box.get(id);
  }

  void put(String id, ContainerType type, String host) {
    set(_hostKey(id, type), host);
  }

  void removeHost(String id, ContainerType type) {
    remove(_hostKey(id, type));
    remove(id);
  }

  String _hostKey(String? id, ContainerType type) =>
      '$_keyHost${type.name}${id ?? ''}';

  ContainerType getType([String id = '']) {
    final cfg = box.get(_keyConfig + id);
    if (cfg != null) {
      final type = ContainerType.values.firstWhereOrNull(
        (e) => e.toString() == cfg,
      );
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
      remove(_keyConfig + id);
    } else {
      set(_keyConfig + id, type.toString());
    }
  }
}
