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
    final saved = set(
      _conversationKey(normalized.id),
      normalized.toJson(),
      updateLastUpdateTsOnSet: false,
    );
    if (!saved) return false;
    if (setActive) {
      set(
        _activeKey(normalized.serverId),
        normalized.id,
        updateLastUpdateTsOnSet: false,
      );
    }
    _pruneServer(normalized.serverId);
    return true;
  }

  bool setActive(String serverId, String conversationId) {
    final conversation = fetch(conversationId);
    if (conversation == null || conversation.serverId != serverId) return false;
    return set(
      _activeKey(serverId),
      conversationId,
      updateLastUpdateTsOnSet: false,
    );
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
    remove(_conversationKey(conversationId), updateLastUpdateTsOnRemove: false);
    if (activeConversationId(serverId) != conversationId) return;
    final remaining = fetchForServer(serverId);
    if (remaining.isEmpty) {
      remove(_activeKey(serverId), updateLastUpdateTsOnRemove: false);
    } else {
      setActive(serverId, remaining.first.id);
    }
  }

  void clearServer(String serverId) {
    for (final conversation in fetchForServer(serverId)) {
      remove(
        _conversationKey(conversation.id),
        updateLastUpdateTsOnRemove: false,
      );
    }
    remove(_activeKey(serverId), updateLastUpdateTsOnRemove: false);
  }

  @visibleForTesting
  static List<AskAiConversationItem> trimItemsForStorage(
    List<AskAiConversationItem> items,
  ) {
    if (items.isEmpty) return const [];
    var start = 0;
    var characters = items.fold<int>(
      0,
      (sum, item) => sum + item.estimatedCharacters,
    );
    while (start < items.length &&
        (items.length - start > maxItemsPerConversation ||
            characters > maxCharactersPerConversation)) {
      final nextUser = _nextUserMessage(items, start + 1);
      if (nextUser == -1) break;
      for (var index = start; index < nextUser; index++) {
        characters -= items[index].estimatedCharacters;
      }
      start = nextUser;
    }
    return List.unmodifiable(items.sublist(start));
  }

  void _pruneServer(String serverId) {
    final conversations = fetchForServer(serverId);
    for (final conversation in conversations.skip(maxConversationsPerServer)) {
      remove(
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
