import '../../core/persistant_store.dart';
import '../model/server/snippet.dart';

class SnippetStore extends PersistentStore<Snippet> {
  SnippetStore() : super('snippet');

  void put(Snippet snippet) {
    box.put(snippet.name, snippet);
  }

  List<Snippet> fetch() {
    final keys = box.keys;
    final ss = <Snippet>[];
    for (final key in keys) {
      final s = box.get(key);
      if (s != null) {
        ss.add(s);
      }
    }
    return ss;
  }

  void delete(Snippet s) {
    box.delete(s.name);
  }
}
