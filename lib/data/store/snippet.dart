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

  @override
  bool clear({bool? updateLastUpdateTsOnClear}) {
    _suppressWatch = true;
    try {
      _cache = null;
      return super.clear(updateLastUpdateTsOnClear: updateLastUpdateTsOnClear);
    } finally {
      _suppressWatch = false;
    }
  }

  void invalidateCache() {
    _cache = null;
  }

  void put(Snippet snippet) {
    _suppressWatch = true;
    try {
      set(snippet.name, snippet);
      _cache = null;
    } finally {
      _suppressWatch = false;
    }
  }

  void _putWithoutInvalidatingCache(Snippet snippet) {
    _suppressWatch = true;
    try {
      box.put(snippet.name, snippet);
    } finally {
      _suppressWatch = false;
    }
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
    try {
      remove(s.name);
      _cache = null;
    } finally {
      _suppressWatch = false;
    }
  }

  void update(Snippet old, Snippet newInfo) {
    if (!have(old)) {
      throw Exception('Old snippet: $old not found');
    }
    _suppressWatch = true;
    try {
      remove(old.name);
      set(newInfo.name, newInfo);
      _cache = null;
    } finally {
      _suppressWatch = false;
    }
  }

  bool have(Snippet s) => get(s.name) != null;
}
