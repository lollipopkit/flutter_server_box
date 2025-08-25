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
    
    final tags = _computeTags(orderedSnippets);
    return SnippetState(snippets: orderedSnippets, tags: tags);
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

  void add(Snippet snippet) {
    final newSnippets = [...state.snippets, snippet];
    final newTags = _computeTags(newSnippets);
    state = state.copyWith(snippets: newSnippets, tags: newTags);
    Stores.snippet.put(snippet);
    bakSync.sync(milliDelay: 1000);
  }

  void del(Snippet snippet) {
    final newSnippets = state.snippets.where((s) => s != snippet).toList();
    final newTags = _computeTags(newSnippets);
    state = state.copyWith(snippets: newSnippets, tags: newTags);
    Stores.snippet.delete(snippet);
    bakSync.sync(milliDelay: 1000);
  }

  void update(Snippet old, Snippet newOne) {
    final newSnippets = state.snippets.map((s) => s == old ? newOne : s).toList();
    final newTags = _computeTags(newSnippets);
    state = state.copyWith(snippets: newSnippets, tags: newTags);
    Stores.snippet.delete(old);
    Stores.snippet.put(newOne);
    bakSync.sync(milliDelay: 1000);
  }

  void renameTag(String old, String newOne) {
    final updatedSnippets = <Snippet>[];
    for (final s in state.snippets) {
      if (s.tags?.contains(old) ?? false) {
        final newTags = Set<String>.from(s.tags!);
        newTags.remove(old);
        newTags.add(newOne);
        final updatedSnippet = s.copyWith(tags: newTags.toList());
        updatedSnippets.add(updatedSnippet);
        Stores.snippet.put(updatedSnippet);
      } else {
        updatedSnippets.add(s);
      }
    }
    final newTags = _computeTags(updatedSnippets);
    state = state.copyWith(snippets: updatedSnippets, tags: newTags);
    bakSync.sync(milliDelay: 1000);
  }
}
