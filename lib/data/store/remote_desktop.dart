import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:sqlite3/sqlite3.dart';

/// Remote desktop profiles, as syncable rows in `remote_desktop_profile`.
class RemoteDesktopStore extends EntityStore<RemoteDesktopProfile> {
  RemoteDesktopStore();

  static final instance = RemoteDesktopStore();

  @override
  String get table => 'remote_desktop_profile';

  @override
  String idOf(RemoteDesktopProfile item) => item.id;

  @override
  String? nameOf(RemoteDesktopProfile item) => item.name;

  @override
  List<RemoteDesktopProfile> readAll() => db
      .select('SELECT * FROM remote_desktop_profile;')
      .map(_fromRow)
      .toList();

  static RemoteDesktopProfile _fromRow(Row row) => RemoteDesktopProfile(
    id: row['id'] as String,
    serverId: row['server_id'] as String,
    name: row['name'] as String,
    protocol: RemoteDesktopProtocol.values.firstWhere(
      (value) => value.name == row['protocol'],
    ),
    host: row['host'] as String,
    port: row['port'] as int,
    username: row['username'] as String?,
    password: row['password'] as String?,
    domain: row['domain'] as String?,
    viewOnly: (row['view_only'] as int) != 0,
    shared: (row['shared'] as int) != 0,
    trustedCertSha256: row['trusted_cert_sha256'] as String?,
  );

  @override
  void put(RemoteDesktopProfile item) {
    super.put(item.clearTrustWhenEndpointChanged(fetchOneRaw(item.id)));
  }

  @override
  void write(RemoteDesktopProfile item) => upsert(
    const [
      'id',
      'server_id',
      'name',
      'protocol',
      'host',
      'port',
      'username',
      'password',
      'domain',
      'view_only',
      'shared',
      'trusted_cert_sha256',
    ],
    [
      item.id,
      item.serverId,
      item.name,
      item.protocol.name,
      item.host,
      item.port,
      item.username,
      item.password,
      item.domain,
      item.viewOnly ? 1 : 0,
      item.shared ? 1 : 0,
      item.trustedCertSha256,
    ],
  );

  @override
  Map<String, dynamic> toJson(RemoteDesktopProfile item) => item.toJson();

  @override
  RemoteDesktopProfile? fromJson(Map<String, dynamic> json) {
    try {
      return RemoteDesktopProfile.fromJson(json);
    } catch (e) {
      dprint('Parsing RemoteDesktopProfile from JSON', e);
      return null;
    }
  }

  List<RemoteDesktopProfile> fetchForServer(String serverId) => db
      .select(
        'SELECT * FROM remote_desktop_profile WHERE server_id = ? '
        'ORDER BY name COLLATE NOCASE;',
        [serverId],
      )
      .map(_fromRow)
      .toList();

  /// Removes one server's profiles one by one so each leaves a tombstone.
  void clearServer(String serverId) {
    for (final profile in fetchForServer(serverId)) {
      delete(profile);
    }
  }
}
