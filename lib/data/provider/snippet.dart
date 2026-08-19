import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:server_box/core/sync.dart';
import 'package:server_box/data/model/server/snippet.dart';
import 'package:server_box/data/res/store.dart';

part 'snippet.freezed.dart';
part 'snippet.g.dart';

@freezed
abstract class SnippetState with _$SnippetState {
  const factory SnippetState({
    @Default(<Snippet>[]) List<Snippet> snippets,
    @Default(<String>{}) Set<String> tags,
  }) = _SnippetState;
}

@Riverpod(keepAlive: true)
class SnippetNotifier extends _$SnippetNotifier {
  @override
  SnippetState build() {
    return _load();
  }

  void reload() {
    Stores.snippet.dropCache();
    final newState = _load();
    if (newState == state) return;
    state = newState;
  }

  SnippetState _load() {
    final snippets = Stores.snippet.fetch();
    final order = Stores.setting.snippetOrder.fetch();

    List<Snippet> orderedSnippets = snippets;
    if (order.isNotEmpty) {
      final surplus = snippets.reorder(
        order: order,
        finder: (n, name) => n.name == name,
      );
      order.removeWhere((e) => surplus.any((ele) => ele == e));
      if (order != Stores.setting.snippetOrder.fetch()) {
        Stores.setting.snippetOrder.put(order);
      }
      orderedSnippets = snippets;
    }

    final newTags = _computeTags(orderedSnippets);
    return stateOrNull?.copyWith(snippets: orderedSnippets, tags: newTags) ??
        SnippetState(snippets: orderedSnippets, tags: newTags);
  }

  Set<String> _computeTags(List<Snippet> snippets) {
    final tags = <String>{};
    for (final s in snippets) {
      final t = s.tags;
      if (t != null) {
        tags.addAll(t);
      }
    }
    return tags;
  }

  Future<void> add(Snippet snippet) async {
    final newSnippets = [...state.snippets, snippet];
    final newTags = _computeTags(newSnippets);
    Stores.snippet.put(snippet);
    state = state.copyWith(snippets: newSnippets, tags: newTags);
    bakSync.sync(milliDelay: 1000);
  }

  Future<void> del(Snippet snippet) async {
    final newSnippets = state.snippets
        .where((s) => s.id != snippet.id)
        .toList();
    final newTags = _computeTags(newSnippets);
    Stores.snippet.delete(snippet);
    state = state.copyWith(snippets: newSnippets, tags: newTags);
    bakSync.sync(milliDelay: 1000);
  }

  /// A rename is an update of columns, not a delete and an insert: the two
  /// carry the same id, and deleting first would tombstone a record that is
  /// still there and take its tags and auto-run targets with it.
  Future<void> update(Snippet old, Snippet newOne) async {
    final newSnippets = state.snippets
        .map((s) => s.id == old.id ? newOne : s)
        .toList();
    final newTags = _computeTags(newSnippets);
    Stores.snippet.put(newOne);
    state = state.copyWith(snippets: newSnippets, tags: newTags);
    bakSync.sync(milliDelay: 1000);
  }

  /// One `UPDATE` over the tag rows, rather than rewriting every snippet that
  /// carries the tag.
  Future<void> renameTag(String old, String newOne) async {
    Stores.snippet.renameTag(old, newOne);
    state = _load();
    bakSync.sync(milliDelay: 1000);
  }
}
