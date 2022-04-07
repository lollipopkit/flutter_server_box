import 'dart:convert';

import 'package:toolbox/core/provider_base.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/store/snippet.dart';
import 'package:toolbox/locator.dart';

class SnippetProvider extends BusyProvider {
  List<Snippet> get snippets => _snippets;
  late List<Snippet> _snippets;

  void loadData() {
    _snippets = locator<SnippetStore>().fetch();
  }

  void add(Snippet snippet) {
    if (have(snippet)) return;
    _snippets.add(snippet);
    locator<SnippetStore>().put(snippet);
    notifyListeners();
  }

  void del(Snippet snippet) {
    if (!have(snippet)) return;
    _snippets.removeAt(index(snippet));
    locator<SnippetStore>().delete(snippet);
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
    locator<SnippetStore>().update(old, newOne);
    notifyListeners();
  }

  String get export => json.encode(snippets);
}
