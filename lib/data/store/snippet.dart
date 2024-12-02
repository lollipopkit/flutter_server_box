import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/snippet.dart';

class SnippetStore extends HiveStore {
  SnippetStore._() : super('snippet');

  static final instance = SnippetStore._();

  void put(Snippet snippet) {
    // box.put(snippet.name, snippet);
    // box.updateLastModified();
    set(snippet.name, snippet);
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
    // box.delete(s.name);
    // box.updateLastModified();
    remove(s.name);
  }
}
