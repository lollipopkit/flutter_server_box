import 'dart:async';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/foundation.dart';
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
  void _scheduleBackupSync() {
    try {
      final maybe = bakSync.sync(milliDelay: 1000);
      if (maybe is Future<void>) {
        unawaited(
          maybe.catchError((Object e, StackTrace s) {
            Loggers.app.warning('bakSync.sync(snippet) failed', e, s);
          }),
        );
      }
    } catch (e, s) {
      Loggers.app.warning('bakSync.sync(snippet) failed', e, s);
    }
  }

  @override
  SnippetState build() {
    unawaited(reload());
    return const SnippetState();
  }

  Future<void> reload() async {
    try {
      final newState = await _load();
      if (newState == state) return;
      state = newState;
    } catch (e, s) {
      Loggers.app.warning('Reload snippets failed', e, s);
    }
  }

  Future<SnippetState> _load() async {
    final snippets = await Stores.snippet.fetch();
    final persistedOrder = Stores.setting.snippetOrder.fetch();
    final order = List<String>.from(persistedOrder);

    final orderedSnippets = List<Snippet>.from(snippets);
    if (order.isNotEmpty) {
      final surplus = orderedSnippets.reorder(
        order: order,
        finder: (n, name) => n.name == name,
      );
      order.removeWhere((e) => surplus.any((ele) => ele == e));
      if (!listEquals(persistedOrder, order)) {
        await Stores.setting.snippetOrder.put(order);
      }
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

  void add(Snippet snippet) {
    final prev = state;
    final newSnippets = [...prev.snippets, snippet];
    final newTags = _computeTags(newSnippets);
    final optimistic = prev.copyWith(snippets: newSnippets, tags: newTags);
    state = optimistic;
    unawaited(_persistAdd(snippet, prev, optimistic));
  }

  Future<void> _persistAdd(
    Snippet snippet,
    SnippetState prev,
    SnippetState optimistic,
  ) async {
    try {
      await Stores.snippet.put(snippet);
      _scheduleBackupSync();
    } catch (e, s) {
      Loggers.app.warning('Add snippet persist failed(${snippet.name})', e, s);
      if (state == optimistic) {
        state = prev;
      }
    }
  }

  void del(Snippet snippet) {
    final prev = state;
    final newSnippets = prev.snippets.where((s) => s != snippet).toList();
    final newTags = _computeTags(newSnippets);
    final optimistic = prev.copyWith(snippets: newSnippets, tags: newTags);
    state = optimistic;
    unawaited(_persistDelete(snippet, prev, optimistic));
  }

  Future<void> _persistDelete(
    Snippet snippet,
    SnippetState prev,
    SnippetState optimistic,
  ) async {
    try {
      await Stores.snippet.delete(snippet);
      _scheduleBackupSync();
    } catch (e, s) {
      Loggers.app.warning(
        'Delete snippet persist failed(${snippet.name})',
        e,
        s,
      );
      if (state == optimistic) {
        state = prev;
      }
    }
  }

  Future<void> update(Snippet old, Snippet newOne) async {
    final prev = state;
    final newSnippets = prev.snippets
        .map((s) => s == old ? newOne : s)
        .toList();
    final newTags = _computeTags(newSnippets);
    final optimistic = prev.copyWith(snippets: newSnippets, tags: newTags);
    state = optimistic;
    var wroteNewForRename = false;
    try {
      if (old.name == newOne.name) {
        await Stores.snippet.put(newOne);
      } else {
        await Stores.snippet.put(newOne);
        wroteNewForRename = true;
        await Stores.snippet.delete(old);
      }
      _scheduleBackupSync();
    } catch (e, s) {
      Loggers.app.warning(
        'Update snippet persist failed(${old.name} -> ${newOne.name})',
        e,
        s,
      );
      if (old.name != newOne.name && wroteNewForRename) {
        try {
          await Stores.snippet.delete(newOne);
        } catch (rollbackErr, rollbackSt) {
          Loggers.app.warning(
            'Rollback snippet rename failed(${newOne.name})',
            rollbackErr,
            rollbackSt,
          );
        }
      }
      if (state == optimistic) {
        state = prev;
      }
    }
  }

  Future<void> renameTag(String old, String newOne) async {
    final updatedSnippets = <Snippet>[];
    final writeFutures = <Future<void>>[];
    for (final s in state.snippets) {
      if (s.tags?.contains(old) ?? false) {
        final newTags = Set<String>.from(s.tags!);
        newTags.remove(old);
        newTags.add(newOne);
        final updatedSnippet = s.copyWith(tags: newTags.toList());
        updatedSnippets.add(updatedSnippet);
        writeFutures.add(Stores.snippet.put(updatedSnippet));
      } else {
        updatedSnippets.add(s);
      }
    }
    final newTags = _computeTags(updatedSnippets);
    state = state.copyWith(snippets: updatedSnippets, tags: newTags);
    try {
      await Future.wait(writeFutures);
    } catch (e, s) {
      Loggers.app.warning('Rename snippet tag persist failed', e, s);
      await reload();
      return;
    }
    _scheduleBackupSync();
  }
}
