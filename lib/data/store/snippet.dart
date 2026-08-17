import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/store/cached_store.dart';

class SnippetStore extends CachedHiveStore<Snippet> {
  SnippetStore._() : super('snippet');

  /// The same seam [ServerStore.forBox] has: `init()` reaches for the
  /// platform's secure storage to get an encryption cipher, which a unit test
  /// has no implementation of.
  @visibleForTesting
  SnippetStore.forBox(Box<dynamic> testBox) : super('snippet_test') {
    box = testBox;
  }

  static final instance = SnippetStore._();

  @override
  String getKey(Snippet item) => item.name;

  @override
  Snippet? fromJson(Map<String, dynamic> json) => Snippet.fromJson(json);
}
