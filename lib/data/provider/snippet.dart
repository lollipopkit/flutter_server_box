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

  void addInfo(Snippet snippet) {
    _snippets.add(snippet);
    locator<SnippetStore>().put(snippet);
    notifyListeners();
  }

  void delInfo(Snippet snippet) {
    _snippets.removeWhere((e) => e.name == snippet.name);
    locator<SnippetStore>().delete(snippet);
    notifyListeners();
  }

  void updateInfo(Snippet old, Snippet newOne) {
    final idx = _snippets.indexWhere((e) => e.name == old.name);
    _snippets[idx] = newOne;
    locator<SnippetStore>().update(old, newOne);
    notifyListeners();
  }
}
