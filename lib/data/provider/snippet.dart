import 'dart:convert';

import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/store/snippet.dart';
import 'package:toolbox/locator.dart';

class SnippetProvider extends BusyProvider {
  List<Snippet> get snippets => _snippets;
  final _store = locator<SnippetStore>();
  late List<Snippet> _snippets;

  void loadData() {
    _snippets = _store.fetch();
  }

  void add(Snippet snippet) {
    _snippets.add(snippet);
    _store.put(snippet);
    notifyListeners();
  }

  void del(Snippet snippet) {
    _snippets.remove(snippet);
    _store.delete(snippet);
    notifyListeners();
  }

  void update(Snippet old, Snippet newOne) {
    _store.delete(old);
    _store.put(newOne);
    _snippets.remove(old);
    _snippets.add(newOne);
    notifyListeners();
  }

  String get export => json.encode(snippets);
}
