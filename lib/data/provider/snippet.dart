import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:toolbox/data/model/server/snippet.dart';
import 'package:toolbox/data/res/store.dart';

import '../../core/extension/order.dart';

class SnippetProvider extends ChangeNotifier {
  late Order<Snippet> _snippets;
  Order<Snippet> get snippets => _snippets;

  final _tags = <String>[];
  List<String> get tags => _tags;

  void load() {
    _snippets = Stores.snippet.fetch();
    final order = Stores.setting.snippetOrder.fetch();
    if (order.isNotEmpty) {
      final surplus = _snippets.reorder(
        order: order,
        finder: (n, name) => n.name == name,
      );
      order.removeWhere((e) => surplus.any((ele) => ele == e));
      if (order != Stores.setting.snippetOrder.fetch()) {
        Stores.setting.snippetOrder.put(order);
      }
    }
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
    Stores.snippet.put(snippet);
    _updateTags();
    notifyListeners();
  }

  void del(Snippet snippet) {
    _snippets.remove(snippet);
    Stores.snippet.delete(snippet);
    _updateTags();
    notifyListeners();
  }

  void update(Snippet old, Snippet newOne) {
    Stores.snippet.delete(old);
    Stores.snippet.put(newOne);
    _snippets.remove(old);
    _snippets.add(newOne);
    _updateTags();
    notifyListeners();
  }

  void renameTag(String old, String newOne) {
    for (final s in _snippets) {
      if (s.tags?.contains(old) ?? false) {
        s.tags?.remove(old);
        s.tags?.add(newOne);
        Stores.snippet.put(s);
      }
    }
    _updateTags();
    notifyListeners();
  }

  String get export => json.encode(snippets);
}
