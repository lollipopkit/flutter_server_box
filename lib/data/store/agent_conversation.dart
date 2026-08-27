import 'dart:async';
import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:sqlite3/sqlite3.dart';

/// Agent conversations, one row each, plus which one is open per server.
///
/// Tables rather than a K-V store because both reads are per server: "every
/// conversation for this server, newest first" was a scan of every conversation
/// in the app followed by an in-memory sort, and the 30-per-server cap was that
/// same scan again. Both are indexed queries here.
///
/// The conversation stays one JSON column. Nothing queries inside the item list
/// — it is read whole or not at all — and the two fields that are queried are
/// lifted out beside it.
///
/// Left out of backup and sync on purpose: these may contain terminal output
/// and reasoning.
class AgentConversationStore {
  AgentConversationStore();

  static final instance = AgentConversationStore();

  static const maxConversationsPerServer = 30;
  static const maxItemsPerConversation = 240;
  static const maxCharactersPerConversation = 512000;

  Database get _db => SqliteDb.instance;

  static const _conv = 'agent_conversation';
  static const _active = 'agent_active_conversation';

  final _changes = StreamController<void>.broadcast();

  /// Fires after any write here.
  ///
  /// What `box.watch()` was: a view showing the conversation list has to notice
  /// a write it did not make itself, and every write goes through this class.
  Stream<void> watch() => _changes.stream;

  /// Announces a transaction performed by another store over these tables.
  void notifyExternalChange() {
    if (!_changes.isClosed) _changes.add(null);
  }

  List<AgentConversation> fetchForServer(String serverId) {
    final rows = _db.select(
      'SELECT data FROM $_conv WHERE server_id = ? ORDER BY updated_at DESC;',
      [serverId],
    );
    final result = <AgentConversation>[];
    for (final row in rows) {
      final conversation = _decode(row['data'] as String);
      if (conversation != null) result.add(conversation);
    }
    return result;
  }

  AgentConversation? fetch(String conversationId) {
    final rows = _db.select('SELECT data FROM $_conv WHERE id = ?;', [
      conversationId,
    ]);
    if (rows.isEmpty) return null;
    return _decode(rows.single['data'] as String);
  }

  AgentConversation? fetchActive(String serverId) {
    final id = activeConversationId(serverId);
    if (id == null) return null;
    final conversation = fetch(id);
    return conversation?.serverId == serverId ? conversation : null;
  }

  String? activeConversationId(String serverId) {
    final rows = _db.select(
      'SELECT conversation_id FROM $_active WHERE server_id = ?;',
      [serverId],
    );
    if (rows.isEmpty) return null;
    final value = rows.single['conversation_id'] as String;
    return value.isNotEmpty ? value : null;
  }

  AgentConversation create({
    required String serverId,
    required AskAiProtocol protocol,
    required String providerBaseUrl,
    required String model,
    String title = '',
    DateTime? now,
  }) {
    final timestamp = now ?? DateTime.now();
    final conversation = AgentConversation(
      id: ShortId.generate(),
      serverId: serverId,
      title: title,
      createdAt: timestamp,
      updatedAt: timestamp,
      protocol: protocol,
      providerBaseUrl: providerBaseUrl,
      model: model,
      items: const [],
    );
    save(conversation);
    return conversation;
  }

  bool save(AgentConversation conversation, {bool setActive = true}) {
    final normalized = conversation.copyWith(
      title: _normalizeTitle(conversation.title, conversation.items),
      items: trimItemsForStorage(conversation.items),
    );
    // One unit, and the caller treats `false` as "not saved". Three statements
    // otherwise: a conversation could be stored but not made active, or stored
    // without the over-cap ones being dropped, and the caller would be told it
    // failed while part of it stood.
    try {
      SqliteStore.transact(() {
        _upsert(normalized);
        if (setActive) _setActiveRow(normalized.serverId, normalized.id);
        _pruneServer(normalized.serverId);
      });
    } catch (e) {
      dprint('Saving AgentConversation', e);
      return false;
    }
    // After it commits, so nothing is told to re-read a state that was undone.
    _changes.add(null);
    return true;
  }

  bool setActive(String serverId, String conversationId) {
    final conversation = fetch(conversationId);
    if (conversation == null || conversation.serverId != serverId) return false;
    _setActiveRow(serverId, conversationId);
    _changes.add(null);
    return true;
  }

  bool rename(String conversationId, String title) {
    final conversation = fetch(conversationId);
    if (conversation == null) return false;
    return save(
      conversation.copyWith(title: title.trim(), updatedAt: DateTime.now()),
      setActive: false,
    );
  }

  void deleteConversation(String serverId, String conversationId) {
    final conversation = fetch(conversationId);
    if (conversation == null || conversation.serverId != serverId) return;
    // Asked before the delete: the active row references the conversation and
    // cascades with it, so afterwards there is nothing left to compare.
    final wasActive = activeConversationId(serverId) == conversationId;
    // One unit: the delete cascades the active row away, so committing it
    // without the replacement would leave the server with none.
    SqliteStore.transact(() {
      _db.execute('DELETE FROM $_conv WHERE id = ?;', [conversationId]);
      if (wasActive) {
        final remaining = fetchForServer(serverId);
        if (remaining.isNotEmpty) _setActiveRow(serverId, remaining.first.id);
      }
    });

    // Exactly once, whichever way this returns. Deleting a conversation that
    // was not the active one used to return before notifying at all, leaving
    // the list showing a row that is gone; promoting a replacement notified
    // twice, because `setActive` notifies too.
    _changes.add(null);
  }

  /// The active row goes with the conversations it references, by cascade.
  void clearServer(String serverId) {
    _db.execute('DELETE FROM $_conv WHERE server_id = ?;', [serverId]);
    _changes.add(null);
  }

  static List<AskAiConversationItem> trimItemsForStorage(
    List<AskAiConversationItem> items,
  ) {
    if (items.isEmpty) return const [];
    var start = 0;
    var characters = items.fold<int>(
      0,
      (sum, item) => sum + item.estimatedCharacters,
    );
    final protocolPairs = _protocolPairIndexes(items);
    while (start < items.length &&
        (items.length - start > maxItemsPerConversation ||
            characters > maxCharactersPerConversation)) {
      final nextUser = _nextUserMessage(items, start + 1);
      final nextStart = _safeTrimEndExclusive(
        protocolPairs,
        start: start,
        initialEndExclusive: nextUser == -1 ? start + 1 : nextUser,
      );
      for (var index = start; index < nextStart; index++) {
        characters -= items[index].estimatedCharacters;
      }
      start = nextStart;
    }
    return List.unmodifiable(items.sublist(start));
  }

  /// Drops everything past the newest [maxConversationsPerServer] for a server.
  ///
  /// One statement, where the K-V version read and decoded every conversation
  /// in the app on every save to find out which ones were past the cap.
  void _pruneServer(String serverId) {
    _db.execute(
      'DELETE FROM $_conv WHERE server_id = ? AND id NOT IN ('
      '  SELECT id FROM $_conv WHERE server_id = ? '
      '  ORDER BY updated_at DESC LIMIT ?'
      ');',
      [serverId, serverId, maxConversationsPerServer],
    );
  }

  static int _nextUserMessage(List<AskAiConversationItem> items, int start) {
    for (var index = start; index < items.length; index++) {
      final item = items[index];
      if (item is AskAiMessageItem && item.role == AskAiMessageRole.user) {
        return index;
      }
    }
    return -1;
  }

  static List<int?> _protocolPairIndexes(List<AskAiConversationItem> items) {
    final pairs = List<int?>.filled(items.length, null, growable: false);
    final pendingCalls = <String, List<int>>{};
    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      if (item is AskAiFunctionCallItem) {
        pendingCalls.putIfAbsent(item.command.id, () => <int>[]).add(index);
        continue;
      }
      if (item is! AskAiFunctionOutputItem) continue;
      final calls = pendingCalls[item.callId];
      if (calls == null || calls.isEmpty) continue;
      final callIndex = calls.removeAt(0);
      pairs[callIndex] = index;
      pairs[index] = callIndex;
    }
    return pairs;
  }

  static int _safeTrimEndExclusive(
    List<int?> protocolPairs, {
    required int start,
    required int initialEndExclusive,
  }) {
    var end = initialEndExclusive
        .clamp(start + 1, protocolPairs.length)
        .toInt();
    for (var index = start; index < end; index++) {
      final pairIndex = protocolPairs[index];
      if (pairIndex != null && pairIndex >= end) end = pairIndex + 1;
    }
    return end;
  }

  static String _normalizeTitle(
    String title,
    List<AskAiConversationItem> items,
  ) {
    final trimmed = title.trim();
    if (trimmed.isNotEmpty) return trimmed;
    for (final item in items) {
      if (item is! AskAiMessageItem || item.role != AskAiMessageRole.user) {
        continue;
      }
      final value = item.content.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (value.isEmpty) continue;
      return value.length <= 60 ? value : '${value.substring(0, 57)}...';
    }
    return '';
  }

  void _upsert(AgentConversation conversation) {
    _db.execute(
      'INSERT INTO $_conv (id, server_id, updated_at, data) VALUES (?, ?, ?, ?) '
      'ON CONFLICT (id) DO UPDATE SET server_id = excluded.server_id, '
      'updated_at = excluded.updated_at, data = excluded.data;',
      [
        conversation.id,
        conversation.serverId,
        conversation.updatedAt.millisecondsSinceEpoch,
        json.encode(conversation.toJson()),
      ],
    );
  }

  void _setActiveRow(String serverId, String conversationId) {
    _db.execute(
      'INSERT INTO $_active (server_id, conversation_id) VALUES (?, ?) '
      'ON CONFLICT (server_id) DO UPDATE SET '
      'conversation_id = excluded.conversation_id;',
      [serverId, conversationId],
    );
  }

  static AgentConversation? _decode(String data) {
    try {
      return _fromMap(json.decode(data) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static AgentConversation? _fromMap(Map<String, dynamic> map) {
    try {
      final conversation = AgentConversation.fromJson(map);
      if (conversation.id.isEmpty || conversation.serverId.isEmpty) return null;
      return conversation;
    } catch (_) {
      return null;
    }
  }
}
