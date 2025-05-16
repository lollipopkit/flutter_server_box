import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/snippet.dart';

class SnippetStore extends HiveStore {
  SnippetStore._() : super('snippet');

  static final instance = SnippetStore._();

  void put(Snippet snippet) {
    set(snippet.name, snippet);
  }

  List<Snippet> fetch() {
    final ss = <Snippet>{};
    for (final key in keys()) {
      final s = box.get(key);
      if (s != null && s is Snippet) {
        ss.add(s);
      }
    }
    return ss.toList();
  }

  void delete(Snippet s) {
    remove(s.name);
  }

  void update(Snippet old, Snippet newInfo) {
    if (!have(old)) {
      throw Exception('Old snippet: $old not found');
    }
    delete(old);
    put(newInfo);
  }

  bool have(Snippet s) => get(s.name) != null;
}
