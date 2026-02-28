import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/snippet.dart';

class SnippetStore extends SqliteStore {
  SnippetStore._() : super('snippet');

  static final instance = SnippetStore._();

  void put(Snippet snippet) {
    set(snippet.name, snippet, toObj: (val) => val?.toJson());
  }

  List<Snippet> fetch() {
    final ss = <Snippet>{};
    for (final key in keys().toList()) {
      final s = get<Snippet>(key, fromObj: _fromObj);
      if (s != null) {
        if (s.name != key) {
          remove(key);
        }
        put(s);
        ss.add(s);
      }
    }
    return ss.toList();
  }

  Snippet? fetchOne(String name) {
    return get<Snippet>(name, fromObj: _fromObj);
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

  bool have(Snippet s) => fetchOne(s.name) != null;

  static Snippet? _fromObj(Object? val) {
    if (val is Snippet) return val;
    if (val is Map<dynamic, dynamic>) {
      final map = val.toStrDynMap;
      if (map == null) return null;
      try {
        return Snippet.fromJson(map as Map<String, dynamic>);
      } catch (e) {
        dprint('Parsing Snippet from JSON', e);
      }
    }
    return null;
  }
}
