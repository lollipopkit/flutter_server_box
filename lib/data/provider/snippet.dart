import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/store.dart';

class SnippetProvider extends Provider {
  const SnippetProvider._();
  static const instance = SnippetProvider._();

  static final snippets = <Snippet>[].vn;
  static final tags = <String>{}.vn;

  @override
  void load() {
    super.load();
    final snippets_ = Stores.snippet.fetch();
    final order = Stores.setting.snippetOrder.fetch();
    if (order.isNotEmpty) {
      final surplus = snippets_.reorder(
        order: order,
        finder: (n, name) => n.name == name,
      );
      order.removeWhere((e) => surplus.any((ele) => ele == e));
      if (order != Stores.setting.snippetOrder.fetch()) {
        Stores.setting.snippetOrder.put(order);
      }
    }
    snippets.value = snippets_;
    _updateTags();
  }

  static void _updateTags() {
    final tags_ = <String>{};
    for (final s in snippets.value) {
      final t = s.tags;
      if (t != null) {
        tags_.addAll(t);
      }
    }
    tags.value = tags_;
  }

  static void add(Snippet snippet) {
    snippets.value.add(snippet);
    snippets.notify();
    Stores.snippet.put(snippet);
    _updateTags();
    bakSync.sync(milliDelay: 1000);
  }

  static void del(Snippet snippet) {
    snippets.value.remove(snippet);
    snippets.notify();
    Stores.snippet.delete(snippet);
    _updateTags();
    bakSync.sync(milliDelay: 1000);
  }

  static void update(Snippet old, Snippet newOne) {
    snippets.value.remove(old);
    snippets.value.add(newOne);
    snippets.notify();
    Stores.snippet.delete(old);
    Stores.snippet.put(newOne);
    _updateTags();
    bakSync.sync(milliDelay: 1000);
  }

  static void renameTag(String old, String newOne) {
    for (final s in snippets.value) {
      if (s.tags?.contains(old) ?? false) {
        s.tags?.remove(old);
        s.tags?.add(newOne);
        Stores.snippet.put(s);
      }
    }
    _updateTags();
    bakSync.sync(milliDelay: 1000);
  }
}
