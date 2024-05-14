import 'package:fl_lib/fl_lib.dart';

import '../model/server/snippet.dart';

class SnippetStore extends PersistentStore {
  SnippetStore() : super('snippet');

  void put(Snippet snippet) {
    box.put(snippet.name, snippet);
    box.updateLastModified();
  }

  List<Snippet> fetch() {
    final keys = box.keys;
    final ss = <Snippet>[];
    for (final key in keys) {
      final s = box.get(key);
      if (s != null && s is Snippet) {
        ss.add(s);
      }
    }
    return ss;
  }

  void delete(Snippet s) {
    box.delete(s.name);
    box.updateLastModified();
  }
}
