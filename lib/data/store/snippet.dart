import 'package:meta/meta.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/store/cached_store.dart';

class SnippetStore extends CachedSqliteStore<Snippet> {
  SnippetStore._() : super('snippet');

  /// The same seam [ServerStore.forTest] has: a distinct store name, so a test
  /// on `SqliteDb.openInMemory()` cannot collide with another test's rows.
  @visibleForTesting
  SnippetStore.forTest() : super('snippet_test');

  static final instance = SnippetStore._();

  @override
  String getKey(Snippet item) => item.name;

  @override
  Snippet? fromJson(Map<String, dynamic> json) => Snippet.fromJson(json);
}
