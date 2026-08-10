import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/model/ai/agent_conversation.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/store/agent_conversation.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late AgentConversationStore store;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-agent-test-');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('agent_conversation_test');
    store = AgentConversationStore.forBox(box);
  });

  setUp(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });

  test('round-trips protocol-complete conversation items', () {
    const command = AskAiCommand(
      id: 'call-1',
      command: 'uptime',
      description: 'Inspect uptime',
      rawArguments:
          '{"command":"uptime","description":"Inspect uptime","safe_to_run":true}',
      modelSafeToRun: true,
    );
    final createdAt = DateTime.fromMillisecondsSinceEpoch(1000);
    final conversation = AgentConversation(
      id: 'conversation-1',
      serverId: 'server-1',
      title: '',
      createdAt: createdAt,
      updatedAt: createdAt,
      protocol: AskAiProtocol.responses,
      providerBaseUrl: 'https://api.openai.com',
      model: 'gpt-test',
      items: const [
        AskAiMessageItem.user('Check uptime.'),
        AskAiReasoningItem(
          rawResponseItem: {
            'id': 'rs-1',
            'type': 'reasoning',
            'encrypted_content': 'encrypted',
            'summary': [],
          },
        ),
        AskAiFunctionCallItem(command: command, responseItemId: 'fc-1'),
        AskAiFunctionOutputItem(
          callId: 'call-1',
          output: '{"exit_code":0,"stdout":"up 2 days"}',
        ),
      ],
    );

    expect(store.save(conversation), isTrue);
    final restored = store.fetch('conversation-1');

    expect(restored, isNotNull);
    expect(restored!.title, 'Check uptime.');
    expect(restored.protocol, AskAiProtocol.responses);
    expect(restored.items, hasLength(4));
    final reasoning = restored.items.whereType<AskAiReasoningItem>().single;
    expect(reasoning.rawResponseItem['encrypted_content'], 'encrypted');
    final call = restored.items.whereType<AskAiFunctionCallItem>().single;
    expect(call.command.id, 'call-1');
    expect(call.command.canAutoRun, isTrue);
    expect(store.activeConversationId('server-1'), 'conversation-1');
  });

  test('isolates servers and prunes only their oldest conversations', () {
    for (
      var index = 0;
      index < AgentConversationStore.maxConversationsPerServer + 1;
      index++
    ) {
      store.create(
        serverId: 'server-a',
        protocol: AskAiProtocol.chatCompletions,
        providerBaseUrl: 'https://example.com',
        model: 'model-a',
        title: 'Conversation $index',
        now: DateTime.fromMillisecondsSinceEpoch(index * 1000),
      );
    }
    final other = store.create(
      serverId: 'server-b',
      protocol: AskAiProtocol.responses,
      providerBaseUrl: 'https://api.openai.com',
      model: 'model-b',
      title: 'Other server',
    );

    final serverA = store.fetchForServer('server-a');
    expect(
      serverA,
      hasLength(AgentConversationStore.maxConversationsPerServer),
    );
    expect(serverA.first.title, 'Conversation 30');
    expect(serverA.any((item) => item.title == 'Conversation 0'), isFalse);
    expect(store.fetchForServer('server-b').single.id, other.id);
  });

  test('deleting the active conversation selects the next newest one', () {
    final older = store.create(
      serverId: 'server-1',
      protocol: AskAiProtocol.chatCompletions,
      providerBaseUrl: 'https://example.com',
      model: 'model',
      now: DateTime.fromMillisecondsSinceEpoch(1000),
    );
    final newer = store.create(
      serverId: 'server-1',
      protocol: AskAiProtocol.chatCompletions,
      providerBaseUrl: 'https://example.com',
      model: 'model',
      now: DateTime.fromMillisecondsSinceEpoch(2000),
    );

    store.deleteConversation('server-1', newer.id);

    expect(store.activeConversationId('server-1'), older.id);
    expect(store.fetch(newer.id), isNull);
  });

  test('trims whole old turns without splitting tool protocol pairs', () {
    final items = <AskAiConversationItem>[];
    for (var turn = 0; turn < 3; turn++) {
      items.add(AskAiMessageItem.user('Turn $turn'));
      for (var index = 0; index < 90; index++) {
        items.add(AskAiMessageItem.assistant('Reply $turn-$index'));
      }
    }

    final trimmed = AgentConversationStore.trimItemsForStorage(items);

    expect(trimmed.length, lessThanOrEqualTo(240));
    expect(trimmed.first, isA<AskAiMessageItem>());
    expect((trimmed.first as AskAiMessageItem).content, 'Turn 1');
    expect(
      trimmed.whereType<AskAiMessageItem>().any(
        (item) => item.content == 'Turn 0',
      ),
      isFalse,
    );
  });

  test('clearServer does not remove conversations from other servers', () {
    store.create(
      serverId: 'server-a',
      protocol: AskAiProtocol.chatCompletions,
      providerBaseUrl: 'https://example.com',
      model: 'model',
    );
    final other = store.create(
      serverId: 'server-b',
      protocol: AskAiProtocol.chatCompletions,
      providerBaseUrl: 'https://example.com',
      model: 'model',
    );

    store.clearServer('server-a');

    expect(store.fetchForServer('server-a'), isEmpty);
    expect(store.fetchForServer('server-b').single.id, other.id);
  });
}
