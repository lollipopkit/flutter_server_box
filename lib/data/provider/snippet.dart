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
    if (have(snippet)) return;
    _snippets.add(snippet);
    _store.put(snippet);
    notifyListeners();
  }

  void del(Snippet snippet) {
    if (!have(snippet)) return;
    _snippets.removeAt(index(snippet));
    _store.delete(snippet);
    notifyListeners();
  }

  int index(Snippet snippet) {
    return _snippets.indexWhere((e) => e.name == snippet.name);
  }

  bool have(Snippet snippet) {
    return index(snippet) != -1;
  }

  void update(Snippet old, Snippet newOne) {
    if (!have(old)) return;
    _snippets[index(old)] = newOne;
    _store.put(newOne);
    notifyListeners();
  }

  String get export => json.encode(snippets);
}
