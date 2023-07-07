import 'dart:convert';

import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/store/snippet.dart';
import 'package:toolbox/locator.dart';

import '../../core/extension/order.dart';

class SnippetProvider extends BusyProvider {
  late Order<Snippet> _snippets;
  Order<Snippet> get snippets => _snippets;

  final _tags = <String>[];
  List<String> get tags => _tags;

  final _store = locator<SnippetStore>();

  void loadData() {
    _snippets = _store.fetch();
    _updateTags();
  }

  void _updateTags() {
    _tags.clear();
    final tags = <String>{};
    for (final s in _snippets) {
      if (s.tags?.isEmpty ?? true) {
        continue;
      }
      tags.addAll(s.tags!);
    }
    _tags.addAll(tags);
  }

  void add(Snippet snippet) {
    _snippets.add(snippet);
    _store.put(snippet);
    notifyListeners();
    _updateTags();
  }

  void del(Snippet snippet) {
    _snippets.remove(snippet);
    _store.delete(snippet);
    notifyListeners();
    _updateTags();
  }

  void update(Snippet old, Snippet newOne) {
    _store.delete(old);
    _store.put(newOne);
    _snippets.remove(old);
    _snippets.add(newOne);
    notifyListeners();
    _updateTags();
  }

  void renameTag(String old, String newOne) {
    for (final s in _snippets) {
      if (s.tags?.contains(old) ?? false) {
        s.tags?.remove(old);
        s.tags?.add(newOne);
      }
    }
    for (final s in _snippets) {
      _store.put(s);
    }
    notifyListeners();
    _updateTags();
  }

  String get export => json.encode(snippets);
}
