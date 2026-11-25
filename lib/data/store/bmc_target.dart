import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/bmc/bmc_target.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:sqlite3/sqlite3.dart';

/// Standalone or server-linked Redfish BMC endpoints, stored in `bmc_target`
/// with their tags in `bmc_target_tag`.
class BmcTargetStore extends EntityStore<BmcTarget> {
  BmcTargetStore();

  static final instance = BmcTargetStore();

  @override
  String get table => 'bmc_target';

  @override
  String idOf(BmcTarget item) => item.id;

  @override
  List<BmcTarget> readAll() {
    final rows = db.select(
      'SELECT id, name, addr, cred_id, cert_sha256, server_id FROM bmc_target ORDER BY name, id;',
    );
    if (rows.isEmpty) return const [];

    final tags = <String, List<String>>{};
    for (final row in db.select('SELECT target_id, tag FROM bmc_target_tag;')) {
      (tags[row['target_id'] as String] ??= []).add(row['tag'] as String);
    }

    return [
      for (final row in rows) _fromRow(row, tags[row['id']]),
    ];
  }

  static BmcTarget _fromRow(Row row, List<String>? tags) => BmcTarget(
    id: row['id'] as String,
    name: row['name'] as String,
    addr: row['addr'] as String,
    credId: row['cred_id'] as String?,
    certSha256: row['cert_sha256'] as String?,
    serverId: row['server_id'] as String?,
    tags: tags,
  );

  bool _exists(String tableName, String id) =>
      db.select('SELECT 1 FROM $tableName WHERE id = ?;', [id]).isNotEmpty;

  String? _validCredId(String? credId) {
    if (credId == null || credId.isEmpty) return null;
    return _exists('bmc_credential', credId) ? credId : null;
  }

  String? _validServerId(String? serverId) {
    if (serverId == null || serverId.isEmpty) return null;
    return _exists('server', serverId) ? serverId : null;
  }

  @override
  void write(BmcTarget item) {
    final serverId = _validServerId(item.serverId);
    if (serverId != null) {
      _unlinkOtherTargetsForServer(serverId, keepId: item.id);
    }

    // Only write foreign keys whose parent exists right now; during batched
    // sync, `writeLinks` lands any parent arriving later in the same batch.
    upsert(
      const ['id', 'name', 'addr', 'cred_id', 'cert_sha256', 'server_id'],
      [
        item.id,
        item.name,
        item.addr,
        _validCredId(item.credId),
        item.certSha256,
        serverId,
      ],
    );

    db.execute('DELETE FROM bmc_target_tag WHERE target_id = ?;', [item.id]);
    for (final tag in item.tags ?? const <String>[]) {
      db.execute('INSERT OR IGNORE INTO bmc_target_tag VALUES (?, ?);', [
        item.id,
        tag,
      ]);
    }
  }

  /// Keeps at most one BMC target linked to [serverId]; any previously linked
  /// target becomes standalone rather than disappearing from both views.
  void _unlinkOtherTargetsForServer(String serverId, {required String keepId}) {
    final displaced = db
        .select(
          'SELECT id FROM bmc_target WHERE server_id = ? AND id != ?;',
          [serverId, keepId],
        )
        .map((r) => r['id'] as String)
        .toList();
    if (displaced.isEmpty) return;
    db.execute(
      'UPDATE bmc_target SET server_id = NULL WHERE server_id = ? AND id != ?;',
      [serverId, keepId],
    );
    for (final id in displaced) {
      synced.stamp(id);
    }
  }

  @override
  void writeLinks(BmcTarget item, {bool strict = false}) {
    final credId = _validCredId(item.credId);
    final serverId = _validServerId(item.serverId);
    if (credId == null && serverId == null) return;
    if (serverId != null) {
      _unlinkOtherTargetsForServer(serverId, keepId: item.id);
    }
    db.execute(
      'UPDATE bmc_target SET cred_id = COALESCE(?, cred_id), server_id = COALESCE(?, server_id) WHERE id = ?;',
      [credId, serverId, item.id],
    );
  }

  @override
  Map<String, dynamic> toJson(BmcTarget item) => item.toJson();

  @override
  BmcTarget decodeJson(Map<String, dynamic> json) => BmcTarget.fromJson(json);

  BmcTarget? fetchOne(String? id) => id == null ? null : fetchOneRaw(id);

  /// The BMC linked to [serverId], if any.
  BmcTarget? forServer(String serverId) {
    for (final target in fetch()) {
      if (target.serverId == serverId) return target;
    }
    return null;
  }

  /// Every tag currently used by any BMC target.
  List<String> allTags() => db
      .select('SELECT DISTINCT tag FROM bmc_target_tag ORDER BY tag;')
      .map((r) => r['tag'] as String)
      .toList();

  /// Renames a tag across every BMC target carrying it, stamping affected rows.
  void renameTag(String from, String to) {
    SqliteStore.transact(() {
      final owners = db
          .select('SELECT target_id FROM bmc_target_tag WHERE tag = ?;', [from])
          .map((r) => r['target_id'] as String)
          .toList();
      if (owners.isEmpty) return;
      db.execute(
        'UPDATE OR REPLACE bmc_target_tag SET tag = ? WHERE tag = ?;',
        [to, from],
      );
      for (final id in owners) {
        synced.stamp(id);
      }
    });
    invalidate();
  }
}
