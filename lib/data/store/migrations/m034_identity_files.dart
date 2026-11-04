import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/store/schema.dart';

/// Moves a server's `IdentityFile` paths out of `server.ssh_key_path` into the
/// `server_identity_file` child table.
///
/// The column held one path as itself, or several as JSON behind
/// [legacyPrefix] — a list inside a scalar column, which nothing could query
/// and every reader had to decode. The column stays, emptied: removing it is a
/// rebuild of `server` and its six cascading children.
///
/// The DDL is written here rather than left to Drift, which only creates
/// tables for a database being made; `m034_identity_files_test.dart` checks
/// the two agree.
class IdentityFilesMigration implements SchemaMigration {
  const IdentityFilesMigration();

  /// What the store wrote before this step for more than one path.
  static const legacyPrefix = 'server-box:identity-files:';

  @override
  int get from => 34;

  @override
  Future<void> apply() async {
    final db = SqliteDb.instance;
    db.execute(
      'CREATE TABLE IF NOT EXISTS server_identity_file ('
      'server_id TEXT NOT NULL REFERENCES server (id) ON DELETE CASCADE, '
      'ord INTEGER NOT NULL, '
      'path TEXT NOT NULL, '
      'PRIMARY KEY (server_id, ord)'
      ') WITHOUT ROWID;',
    );
    final rows = db.select(
      'SELECT id, ssh_key_path FROM server WHERE ssh_key_path IS NOT NULL;',
    );
    for (final row in rows) {
      final id = row['id'] as String;
      final paths = decode(row['ssh_key_path'] as String);
      // Replaced rather than added to, so a step that stopped partway and
      // runs again writes each server's list once.
      db.execute('DELETE FROM server_identity_file WHERE server_id = ?;', [id]);
      for (final (ord, path) in paths.indexed) {
        db.execute('INSERT INTO server_identity_file VALUES (?, ?, ?);', [id, ord, path]);
      }
      db.execute('UPDATE server SET ssh_key_path = NULL WHERE id = ?;', [id]);
    }
  }

  /// The paths a `ssh_key_path` value held.
  ///
  /// A value that only looks like the encoded form — the prefix, then
  /// something that is not a JSON list — is one path, kept as typed.
  static List<String> decode(String stored) {
    if (stored.isEmpty) return const [];
    if (!stored.startsWith(legacyPrefix)) return [stored];
    try {
      final decoded = jsonDecode(stored.substring(legacyPrefix.length));
      if (decoded is! List) return [stored];
      return [
        for (final p in decoded.whereType<String>())
          if (p.isNotEmpty) p,
      ];
    } catch (_) {
      return [stored];
    }
  }
}
