import 'package:fl_lib/fl_lib.dart';
import 'package:hive_ce/hive.dart';
import 'package:meta/meta.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';

class AgentConversationStore extends HiveStore {
  AgentConversationStore._()
    : super(
        'agent_conversation',
        updateLastUpdateTsOnClear: false,
        updateLastUpdateTsOnRemove: false,
        updateLastUpdateTsOnSet: false,
      );

  @visibleForTesting
  AgentConversationStore.forBox(Box<dynamic> testBox)
    : super(
        'agent_conversation_test',
        updateLastUpdateTsOnClear: false,
        updateLastUpdateTsOnRemove: false,
        updateLastUpdateTsOnSet: false,
      ) {
    box = testBox;
  }

  static final instance = AgentConversationStore._();

  static const maxConversationsPerServer = 30;
  static const maxItemsPerConversation = 240;
  static const maxCharactersPerConversation = 512000;

  static const _conversationPrefix = 'conversation::';
  static const _activePrefix = 'active::';

  List<AgentConversation> fetchForServer(String serverId) {
    final conversations = <AgentConversation>[];
    for (final key in box.keys) {
      if (key is! String || !key.startsWith(_conversationPrefix)) continue;
      final conversation = _conversationFromValue(box.get(key));
      if (conversation?.serverId == serverId) conversations.add(conversation!);
    }
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  AgentConversation? fetch(String conversationId) {
    return _conversationFromValue(box.get(_conversationKey(conversationId)));
  }

  AgentConversation? fetchActive(String serverId) {
    final id = activeConversationId(serverId);
    if (id == null) return null;
    final conversation = fetch(id);
    return conversation?.serverId == serverId ? conversation : null;
  }

  String? activeConversationId(String serverId) {
    final value = box.get(_activeKey(serverId));
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<AgentConversation> create({
    required String serverId,
    required AskAiProtocol protocol,
    required String providerBaseUrl,
    required String model,
    String title = '',
    DateTime? now,
  }) async {
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
    if (!await save(conversation)) {
      throw StateError('Failed to create agent conversation ${conversation.id}');
    }
    return conversation;
  }

  Future<bool> save(
    AgentConversation conversation, {
    bool setActive = true,
  }) async {
    final normalized = conversation.copyWith(
      title: _normalizeTitle(conversation.title, conversation.items),
      items: trimItemsForStorage(conversation.items),
    );
    final saved = await set(
      _conversationKey(normalized.id),
      normalized.toJson(),
      updateLastUpdateTsOnSet: false,
    );
    if (!saved) return false;
    if (setActive) {
      final activated = await set(
        _activeKey(normalized.serverId),
        normalized.id,
        updateLastUpdateTsOnSet: false,
      );
      if (!activated) return false;
    }
    await _pruneServer(normalized.serverId);
    return true;
  }

  Future<bool> setActive(String serverId, String conversationId) async {
    final conversation = fetch(conversationId);
    if (conversation == null || conversation.serverId != serverId) return false;
    return await set(
      _activeKey(serverId),
      conversationId,
      updateLastUpdateTsOnSet: false,
    );
  }

  Future<bool> rename(String conversationId, String title) async {
    final conversation = fetch(conversationId);
    if (conversation == null) return false;
    return await save(
      conversation.copyWith(title: title.trim(), updatedAt: DateTime.now()),
      setActive: false,
    );
  }

  Future<void> deleteConversation(
    String serverId,
    String conversationId,
  ) async {
    final conversation = fetch(conversationId);
    if (conversation == null || conversation.serverId != serverId) return;
    await remove(
      _conversationKey(conversationId),
      updateLastUpdateTsOnRemove: false,
    );
    if (activeConversationId(serverId) != conversationId) return;
    final remaining = fetchForServer(serverId);
    if (remaining.isEmpty) {
      await remove(_activeKey(serverId), updateLastUpdateTsOnRemove: false);
    } else {
      await setActive(serverId, remaining.first.id);
    }
  }

  Future<void> clearServer(String serverId) async {
    for (final conversation in fetchForServer(serverId)) {
      await remove(
        _conversationKey(conversation.id),
        updateLastUpdateTsOnRemove: false,
      );
    }
    await remove(_activeKey(serverId), updateLastUpdateTsOnRemove: false);
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

  Future<void> _pruneServer(String serverId) async {
    final conversations = fetchForServer(serverId);
    for (final conversation in conversations.skip(maxConversationsPerServer)) {
      await remove(
        _conversationKey(conversation.id),
        updateLastUpdateTsOnRemove: false,
      );
    }
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

  static String _conversationKey(String id) => '$_conversationPrefix$id';
  static String _activeKey(String serverId) => '$_activePrefix$serverId';

  static AgentConversation? _conversationFromValue(Object? value) {
    if (value is! Map) return null;
    try {
      final conversation = AgentConversation.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (conversation.id.isEmpty || conversation.serverId.isEmpty) return null;
      return conversation;
    } catch (_) {
      return null;
    }
  }
}
