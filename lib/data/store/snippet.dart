import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/model/server/snippet.dart';

class SnippetStore extends PersistentStore {
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
