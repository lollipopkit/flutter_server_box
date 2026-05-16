import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/port_forward.dart';

class PortForwardStore extends HiveStore {
  PortForwardStore._() : super('port_forward');

  static final instance = PortForwardStore._();

  void put(PortForwardConfig config) {
    set(config.id, config);
  }

  List<PortForwardConfig> fetch(String serverId) {
    final configs = <PortForwardConfig>[];
    for (final key in keys()) {
      final config = get<PortForwardConfig>(
        key,
        fromObj: (val) {
          if (val is PortForwardConfig) return val;
          if (val is Map<dynamic, dynamic>) {
            final map = val.toStrDynMap;
            if (map == null) return null;
            try {
              final config = PortForwardConfig.fromJson(
                map as Map<String, dynamic>,
              );
              put(config);
              return config;
            } catch (e) {
              dprint('Parsing PortForwardConfig from JSON', e);
            }
          }
          return null;
        },
      );
      if (config != null && config.serverId == serverId) {
        configs.add(config);
      }
    }
    return configs;
  }

  void delete(PortForwardConfig config) {
    remove(config.id);
  }

  void deleteByServer(String serverId) {
    final keysToDelete = <dynamic>[];
    for (final key in keys()) {
      final config = get<PortForwardConfig>(key);
      if (config?.serverId == serverId) {
        keysToDelete.add(key);
      }
    }
    for (final key in keysToDelete) {
      remove(key);
    }
  }

  void update(PortForwardConfig old, PortForwardConfig newConfig) {
    if (!have(old)) {
      throw Exception('Old config: $old not found');
    }
    delete(old);
    put(newConfig);
  }

  bool have(PortForwardConfig config) => get(config.id) != null;
}
