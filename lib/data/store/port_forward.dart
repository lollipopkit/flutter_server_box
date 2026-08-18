import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/port_forward.dart';

class PortForwardStore extends SqliteStore {
  PortForwardStore._() : super('port_forward');

  static final instance = PortForwardStore._();

  void put(PortForwardConfig config) {
    set(config.id, config);
  }

  List<PortForwardConfig> fetch(String serverId) {
    final configs = <PortForwardConfig>[];
    for (final key in keys()) {
      final raw = get<Map>(key);
      if (raw == null) continue;
      final PortForwardConfig config;
      try {
        config = PortForwardConfig.fromJson(Map<String, dynamic>.from(raw));
      } catch (e) {
        dprint('Parsing PortForwardConfig from JSON', e);
        continue;
      }
      if (config.serverId == serverId) configs.add(config);
    }
    return configs;
  }

  void delete(PortForwardConfig config) {
    remove(config.id);
  }
}
