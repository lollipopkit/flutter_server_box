import 'dart:convert';

import 'package:toolbox/core/persistant_store.dart';
import 'package:toolbox/data/model/server/snippet.dart';

class SnippetStore extends PersistentStore {
  void put(Snippet snippet) {
    final ss = fetch();
    if (!have(snippet)) ss.add(snippet);
    box.put('snippet', json.encode(ss));
  }

  List<Snippet> fetch() {
    return getSnippetList(
        json.decode(box.get('snippet', defaultValue: '[]')!));
  }

  void delete(Snippet s) {
    final ss = fetch();
    ss.removeAt(index(s));
    box.put('snippet', json.encode(ss));
  }

  void update(Snippet old, Snippet newInfo) {
    final ss = fetch();
    ss[index(old)] = newInfo;
    box.put('snippet', json.encode(ss));
  }

  int index(Snippet s) => fetch().indexWhere((e) => e.name == s.name);

  bool have(Snippet s) => index(s) != -1;
}