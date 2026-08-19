import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/store/server.dart';

class PortForwardStore extends SqliteStore {
  PortForwardStore._() : super('port_forward');

  /// The same seam [ServerStore.forTest] has: a distinct store name, so a test
  /// tree writing here cannot touch what the app stores.
  PortForwardStore.forTest() : super('port_forward_test');

  static final instance = PortForwardStore._();

  void put(PortForwardConfig config) {
    set(config.id, config);
  }

  List<PortForwardConfig> fetch(String serverId) {
    final configs = <PortForwardConfig>[];
    // One query, not one per key: `getAllMap` reads the store in a single
    // statement.
    for (final raw in getAllMap().values) {
      if (raw is! Map) continue;
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
