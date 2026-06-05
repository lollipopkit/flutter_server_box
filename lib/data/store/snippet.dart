import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/store/cached_store.dart';

class SnippetStore extends CachedHiveStore<Snippet> {
  SnippetStore._() : super('snippet');

  static final instance = SnippetStore._();

  @override
  String getKey(Snippet item) => item.name;

  @override
  Snippet? fromJson(Map<String, dynamic> json) => Snippet.fromJson(json);
}
