import 'package:fl_lib/fl_lib.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/server/port_forward.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:sqlite3/sqlite3.dart';

/// Port forwards, as rows in `port_forward`.
///
/// `server_id` is a foreign key that cascades, so deleting a server takes its
/// forwards with it. Nothing did that before, and [fetch] answered "this
/// server's forwards" by decoding every record in the store.
class PortForwardStore extends EntityStore<PortForwardConfig> {
  PortForwardStore._();

  /// See [PrivateKeyStore.forTest].
  @visibleForTesting
  PortForwardStore.forTest();

  static final instance = PortForwardStore._();

  @override
  String get table => 'port_forward';

  @override
  String idOf(PortForwardConfig item) => item.id;

  @override
  String? nameOf(PortForwardConfig item) => item.name;

  @override
  List<PortForwardConfig> readAll() =>
      db.select('SELECT * FROM port_forward;').map(_fromRow).toList();

  static PortForwardConfig _fromRow(Row row) => PortForwardConfig(
    id: row['id'] as String,
    serverId: row['server_id'] as String,
    name: row['name'] as String,
    type: PortForwardType.values.firstWhere(
      (e) => e.name == row['type'],
      orElse: () => PortForwardType.local,
    ),
    localHost: row['local_host'] as String?,
    localPort: row['local_port'] as int? ?? 0,
    remoteHost: row['remote_host'] as String?,
    remotePort: row['remote_port'] as int?,
  );

  @override
  void write(PortForwardConfig item) => upsert(
    const [
      'id',
      'server_id',
      'name',
      'type',
      'local_host',
      'local_port',
      'remote_host',
      'remote_port',
    ],
    [
      item.id,
      item.serverId,
      item.name,
      item.type.name,
      item.localHost,
      item.localPort,
      item.remoteHost,
      item.remotePort,
    ],
  );

  @override
  Map<String, dynamic> toJson(PortForwardConfig item) => item.toJson();

  @override
  PortForwardConfig? fromJson(Map<String, dynamic> json) {
    try {
      return PortForwardConfig.fromJson(json);
    } catch (e) {
      dprint('Parsing PortForwardConfig from JSON', e);
      return null;
    }
  }

  /// Removes one server's records one by one so each leaves a tombstone.
  ///
  /// The server's foreign key would cascade the row deletion, but it cannot
  /// record a change for this sync root after the child row has disappeared.
  void clearServer(String serverId) {
    for (final config in fetchForServer(serverId)) {
      delete(config);
    }
  }

  /// One server's forwards, as an indexed query.
  List<PortForwardConfig> fetchForServer(String serverId) => db
      .select('SELECT * FROM port_forward WHERE server_id = ?;', [serverId])
      .map(_fromRow)
      .toList();
}
