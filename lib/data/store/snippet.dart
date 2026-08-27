import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/store/entity_store.dart';

/// Snippets, as rows in `snippet` plus its two child tables.
///
/// `tags` and `autoRunOn` were JSON arrays inside the record, so "which
/// snippets run on this server" meant decoding every snippet, and deleting a
/// server left it named in the ones that did. Both are rows that cascade now.
class SnippetStore extends EntityStore<Snippet> {
  SnippetStore();

  static final instance = SnippetStore();

  @override
  String get table => 'snippet';

  @override
  String idOf(Snippet item) => item.id;

  @override
  String? nameOf(Snippet item) => item.name;

  @override
  List<Snippet> readAll() {
    final rows = db.select('SELECT id, name, script, note FROM snippet;');
    if (rows.isEmpty) return const [];

    final tags = _group('SELECT snippet_id, tag FROM snippet_tag;', 'tag');
    final autoRun = _group(
      'SELECT snippet_id, server_id FROM snippet_auto_run_on;',
      'server_id',
    );

    return [
      for (final row in rows)
        Snippet(
          id: row['id'] as String,
          name: row['name'] as String,
          script: row['script'] as String,
          note: row['note'] as String?,
          tags: tags[row['id']],
          autoRunOn: autoRun[row['id']],
        ),
    ];
  }

  Map<String, List<String>> _group(String sql, String column) {
    final out = <String, List<String>>{};
    for (final row in db.select(sql)) {
      (out[row['snippet_id'] as String] ??= []).add(row[column] as String);
    }
    return out;
  }

  @override
  void write(Snippet item) {
    upsert(
      const ['id', 'name', 'script', 'note'],
      [item.id, item.name, item.script, item.note],
    );

    // Replaced wholesale rather than diffed: the record arrives as one object,
    // so what it does not carry is what was removed.
    db.execute('DELETE FROM snippet_tag WHERE snippet_id = ?;', [item.id]);
    db.execute('DELETE FROM snippet_auto_run_on WHERE snippet_id = ?;', [
      item.id,
    ]);

    for (final tag in item.tags ?? const <String>[]) {
      db.execute('INSERT OR IGNORE INTO snippet_tag VALUES (?, ?);', [
        item.id,
        tag,
      ]);
    }
    for (final serverId in item.autoRunOn ?? const <String>[]) {
      // A server that is not there is dropped rather than written as a
      // dangling reference — the foreign key would refuse it anyway, and
      // refusing would fail the whole save over a server deleted long ago.
      final exists = db.select('SELECT 1 FROM server WHERE id = ?;', [
        serverId,
      ]).isNotEmpty;
      if (!exists) continue;
      db.execute('INSERT OR IGNORE INTO snippet_auto_run_on VALUES (?, ?);', [
        item.id,
        serverId,
      ]);
    }
  }

  @override
  Map<String, dynamic> toJson(Snippet item) => item.toJson();

  @override
  Snippet? fromJson(Map<String, dynamic> json) {
    try {
      return Snippet.fromJson(json);
    } catch (e) {
      dprint('Parsing Snippet from JSON', e);
      return null;
    }
  }

  /// A snippet from a backup written before ids existed gets a fresh one from
  /// `Snippet.fromJson` on every decode, so the name is what identifies it.
  @override
  Snippet reconcile(Snippet incoming) {
    if (fetchOneRaw(incoming.id) != null) return incoming;
    final existing = fetchByName(incoming.name);
    return existing == null ? incoming : incoming.copyWith(id: existing.id);
  }

  /// The snippet called [name]. The UI keeps names unique and `snippetOrder`
  /// is a list of them, so this is how an order entry finds its record.
  Snippet? fetchByName(String name) {
    for (final snippet in fetch()) {
      if (snippet.name == name) return snippet;
    }
    return null;
  }

  /// Snippets to run when [serverId] connects, as a query rather than a decode
  /// of every record.
  List<String> autoRunIdsFor(String serverId) => db
      .select(
        'SELECT snippet_id FROM snippet_auto_run_on WHERE server_id = ?;',
        [serverId],
      )
      .map((r) => r['snippet_id'] as String)
      .toList();

  /// Every tag in use, for the filter bar.
  List<String> allTags() => db
      .select('SELECT DISTINCT tag FROM snippet_tag ORDER BY tag;')
      .map((r) => r['tag'] as String)
      .toList();

  /// Renames a tag across every snippet carrying it, in one statement.
  ///
  /// The parents are stamped so the change is one the sync can see.
  void renameTag(String from, String to) {
    SqliteStore.transact(() {
      final owners = db
          .select('SELECT snippet_id FROM snippet_tag WHERE tag = ?;', [from])
          .map((r) => r['snippet_id'] as String)
          .toList();
      if (owners.isEmpty) return;
      // `OR REPLACE`, since a snippet may already carry the target tag and
      // (snippet_id, tag) is the primary key.
      db.execute('UPDATE OR REPLACE snippet_tag SET tag = ? WHERE tag = ?;', [
        to,
        from,
      ]);
      for (final id in owners) {
        synced.stamp(id);
      }
    });
    invalidate();
  }
}
