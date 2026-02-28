import 'package:drift/drift.dart' as d;
import 'package:server_box/data/db/app_db.dart' as adb;
import 'package:server_box/data/model/server/snippet.dart';

class SnippetStore {
  SnippetStore._();

  static final instance = SnippetStore._();

  adb.AppDb get _db => adb.AppDb.instance;

  Future<void> put(Snippet snippet) async {
    await _upsert(snippet);
  }

  Future<List<Snippet>> fetch() async {
    final rows = await _db.select(_db.snippets).get();
    final list = <Snippet>[];
    for (final row in rows) {
      final s = await fetchOne(row.name);
      if (s != null) list.add(s);
    }
    return list;
  }

  Future<Snippet?> fetchOne(String name) async {
    final row = await (_db.select(_db.snippets)
          ..where((tbl) => tbl.name.equals(name)))
        .getSingleOrNull();
    if (row == null) return null;

    final tags = await (_db.select(_db.snippetTags)
          ..where((tbl) => tbl.snippetName.equals(name)))
        .get();

    final autoRuns = await (_db.select(_db.snippetAutoRuns)
          ..where((tbl) => tbl.snippetName.equals(name)))
        .get();

    return Snippet(
      name: row.name,
      script: row.script,
      note: row.note,
      tags: tags.map((e) => e.tag).toList(growable: false),
      autoRunOn: autoRuns.map((e) => e.serverId).toList(growable: false),
    );
  }

  Future<void> delete(Snippet s) async {
    await (_db.delete(_db.snippets)..where((tbl) => tbl.name.equals(s.name))).go();
  }

  Future<void> update(Snippet old, Snippet newInfo) async {
    if (!await have(old)) {
      throw Exception('Old snippet: $old not found');
    }
    if (old.name != newInfo.name) {
      await delete(old);
    }
    await put(newInfo);
  }

  Future<bool> have(Snippet s) async => await fetchOne(s.name) != null;

  Future<Set<String>> keys() async {
    final query = _db.selectOnly(_db.snippets)..addColumns([_db.snippets.name]);
    final rows = await query.get();
    return rows
        .map((row) => row.read(_db.snippets.name))
        .whereType<String>()
        .toSet();
  }

  Future<void> clear() async {
    await _db.delete(_db.snippets).go();
  }

  Future<void> _upsert(Snippet snippet) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _db.into(_db.snippets).insertOnConflictUpdate(
            adb.SnippetsCompanion.insert(
              name: snippet.name,
              script: snippet.script,
              note: d.Value(snippet.note),
              updatedAt: now,
            ),
          );

      await (_db.delete(_db.snippetTags)
            ..where((tbl) => tbl.snippetName.equals(snippet.name)))
          .go();
      for (final tag in snippet.tags ?? const <String>[]) {
        await _db.into(_db.snippetTags).insert(
              adb.SnippetTagsCompanion.insert(
                snippetName: snippet.name,
                tag: tag,
              ),
              mode: d.InsertMode.insertOrIgnore,
            );
      }

      await (_db.delete(_db.snippetAutoRuns)
            ..where((tbl) => tbl.snippetName.equals(snippet.name)))
          .go();
      for (final id in snippet.autoRunOn ?? const <String>[]) {
        await _db.into(_db.snippetAutoRuns).insert(
              adb.SnippetAutoRunsCompanion.insert(
                snippetName: snippet.name,
                serverId: id,
              ),
              mode: d.InsertMode.insertOrIgnore,
            );
      }
    });
  }
}
