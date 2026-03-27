import 'dart:async';

import 'package:fl_lib/fl_lib.dart';

import 'package:server_box/data/model/server/snippet.dart';

class SnippetStore extends HiveStore {
  SnippetStore._() : super('snippet');

  static final instance = SnippetStore._();

  List<Snippet>? _cache;
  StreamSubscription<dynamic>? _boxWatchSub;
  bool _suppressWatch = false;

  @override
  Future<void> init() async {
    await super.init();
    _boxWatchSub?.cancel();
    _boxWatchSub = box.watch().listen((_) {
      if (!_suppressWatch) {
        _cache = null;
      }
    });
  }

  void close() {
    _boxWatchSub?.cancel();
    _boxWatchSub = null;
    _cache = null;
  }

  @override
  bool clear({bool? updateLastUpdateTsOnClear}) {
    _suppressWatch = true;
    _cache = null;
    final result = super.clear(updateLastUpdateTsOnClear: updateLastUpdateTsOnClear);
    _suppressWatch = false;
    return result;
  }

  void invalidateCache() {
    _suppressWatch = true;
    _cache = null;
    _suppressWatch = false;
  }

  void put(Snippet snippet) {
    _suppressWatch = true;
    set(snippet.name, snippet);
    _cache = null;
    _suppressWatch = false;
  }

  void _putWithoutInvalidatingCache(Snippet snippet) {
    box.put(snippet.name, snippet);
  }

  List<Snippet> fetch() {
    return List<Snippet>.from(_cache ??= _loadAll());
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
              _putWithoutInvalidatingCache(snippet);
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
    _suppressWatch = true;
    remove(s.name);
    _cache = null;
    _suppressWatch = false;
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