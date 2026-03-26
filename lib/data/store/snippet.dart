import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/snippet.dart';

class SnippetStore extends HiveStore {
  SnippetStore._() : super('snippet');

  static final instance = SnippetStore._();

  List<Snippet>? _cache;

  void put(Snippet snippet) {
    set(snippet.name, snippet);
    _cache = null;
  }

  List<Snippet> fetch() {
    return _cache ??= _loadAll();
  }

  List<Snippet> _loadAll() {
    final ss = <Snippet>{};
    for (final key in keys()) {
      final s = get<Snippet>(
        key,
        fromObj: (val) {
          if (val is Snippet) return val;
          if (val is Map<dynamic, dynamic>) {
            final map = val.toStrDynMap;
            if (map == null) return null;
            try {
              final snippet = Snippet.fromJson(map as Map<String, dynamic>);
              put(snippet);
              return snippet;
            } catch (e) {
              dprint('Parsing Snippet from JSON', e);
            }
          }
          return null;
        },
      );
      if (s != null) {
        ss.add(s);
      }
    }
    return ss.toList();
  }

  void delete(Snippet s) {
    remove(s.name);
    _cache = null;
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