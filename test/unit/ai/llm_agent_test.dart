// The Agent on the real runtime: fl_pi_llm on QuickJS, a mock
// OpenAI-compatible server standing in for the provider — and for the one
// endpoint the `askAi` settings of an older install pointed at.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/llm/host.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/core/llm/tools.dart';
import 'package:server_box/data/model/ai/ask_ai_models.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/private_key.dart';
import 'package:server_box/data/store/server.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/test_db.dart';

/// What each request asked for, and the tool calls the mock answers with:
/// `ls` for "list files", `rm -rf /srv` for "wipe it", and a closing line
/// once a tool result is in.
Future<(HttpServer, List<Map<String, Object?>>)> _mockServer() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final seen = <Map<String, Object?>>[];
  _keys.clear();
  server.listen((req) async {
    if (req.method == 'GET') {
      req.response
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'data': [
              {'id': 'echo'},
            ],
          }),
        );
      await req.response.close();
      return;
    }
    final body =
        jsonDecode(await utf8.decodeStream(req)) as Map<String, Object?>;
    seen.add(body);
    _keys.add(req.headers.value('authorization') ?? '');
    final msgs = (body['messages'] as List).cast<Map>();
    final res = req.response
      ..headers.contentType = ContentType('text', 'event-stream')
      ..bufferOutput = false;
    void send(Map<String, Object?> delta, [String? finish]) => res.write(
      'data: ${jsonEncode({
        'id': 'c',
        'object': 'chat.completion.chunk',
        'created': 1,
        'model': body['model'],
        'choices': [
          {'index': 0, 'delta': delta, 'finish_reason': finish},
        ],
      })}\n\n',
    );
    void call(String name, Map<String, Object?> args) => send({
      'tool_calls': [
        {
          'index': 0,
          'id': 'call_${seen.length}',
          'type': 'function',
          'function': {'name': name, 'arguments': jsonEncode(args)},
        },
      ],
    }, 'tool_calls');

    final last = msgs.last;
    final text = '${msgs.lastWhere((m) => m['role'] == 'user')['content']}';
    final results = msgs.reversed
        .takeWhile((m) => m['role'] != 'user')
        .where((m) => m['role'] == 'tool')
        .length;
    // A model in a loop: the same read-only command, again and again.
    if (text.contains('keep listing') && results < 4) {
      call('terminal_run', {
        'command': 'ls',
        'description': 'List the files.',
        'safe_to_run': true,
        'destructive': false,
      });
    } else if (last['role'] == 'tool') {
      send({'content': 'Done.'}, 'stop');
    } else if (text.contains('list files')) {
      call('terminal_run', {
        'command': 'ls',
        'description': 'List the files.',
        'safe_to_run': true,
        'destructive': false,
      });
    } else if (text.contains('wipe it')) {
      call('terminal_run', {
        'command': 'rm -rf /srv',
        'description': 'Delete everything under /srv.',
        'safe_to_run': false,
        'destructive': true,
      });
    } else {
      send({'content': 'Hello.'}, 'stop');
    }
    res.write('data: [DONE]\n\n');
    await res.close();
  });
  return (server, seen);
}

ExternalLibrary _nativeLib() => ExternalLibrary.open(switch (Platform
    .operatingSystem) {
  'macos' => 'build/native_assets/macos/libfl_pi_llm.dylib',
  'windows' => 'build/native_assets/windows/fl_pi_llm.dll',
  _ => 'build/native_assets/linux/libfl_pi_llm.so',
});

/// The `Authorization` of each chat request, beside [_mockServer]'s bodies.
final _keys = <String>[];

/// The names of the tools a request offered.
Set<String> _tools(Map<String, Object?> request) => {
  for (final t in (request['tools'] as List? ?? const []).cast<Map>())
    (t['function'] as Map)['name'] as String,
};

void main() {
  late HttpServer server;
  late List<Map<String, Object?>> seen;
  final ran = <String>[];
  final credentials = MemoryCredentials({});

  setUpAll(() async {
    (server, seen) = await _mockServer();
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
    getIt.registerSingleton<ServerStore>(ServerStore());
    getIt.registerSingleton<PrivateKeyStore>(PrivateKeyStore());
    Stores.setting.serverStatusUpdateInterval.put(0);
    for (final store in LlmStores.all) {
      await store.init();
    }
    SqlitePiSessionStore();
    // What an install that set the Agent up before fl_pi_llm has stored.
    Stores.setting.set('askAi', {
      'baseUrl': 'http://127.0.0.1:${server.port}/v1',
      'apiKey': 'sk-old',
      'model': 'echo',
      'protocol': 'chatCompletions',
      'autoRunSafeCommands': true,
    });

    await LlmHost.init(
      ProviderContainer(),
      credentials: credentials,
      externalLibrary: _nativeLib(),
      // An OpenAI-compatible gateway, as a shell exports it.
      environment: () => {
        'OPENAI_BASE_URL': 'http://127.0.0.1:${server.port}/v1',
        'OPENAI_API_KEY': 'sk-gateway',
        'OPENAI_MODEL': 'echo',
      },
    );
    LlmUi.genTitle = () => false;

    TerminalHosts.register(
      'srv-1',
      TerminalHost(
        serverName: 'web',
        run: (command) async {
          ran.add(command.command);
          return AskAiCommandResult(
            command: command.command,
            stdout: 'a.txt b.txt',
            stderr: '',
            exitCode: 0,
            duration: const Duration(milliseconds: 3),
          );
        },
        insert: (_) {},
        screen: () => r'root@web:~# ',
        cancel: () async {},
      ),
    );
  });

  tearDownAll(() async {
    await Chats.closeAll();
    await Llm.rt.dispose();
    await server.close(force: true);
    await getIt.reset();
    await closeTestDb();
  });

  test('OPENAI_BASE_URL is the system provider, and its key goes nowhere else', () async {
    expect(Llm.configured.value, contains(SystemProvider.id));
    expect(Llm.envAuth.value, isNot(contains('openai')), reason: "a gateway's key is not OpenAI's");
    final id = Chats.create();
    LlmStores.chat.put(LlmStores.chat.fetch(id)!.copyWith(model: const LlmModelRef(SystemProvider.id, 'echo')));
    await Chats.send(id, 'hello');
    expect(seen.last['model'], 'echo');
    expect(_keys.last, 'Bearer sk-gateway');
  });

  group('the settings from before fl_pi_llm', () {
    test('become a provider, its key a credential', () async {
      final provider = LlmStores.llm.customProviders.get()!.single;
      expect(provider.id, LegacyAskAiMigration.providerId);
      expect(provider.api, LlmApi.openaiCompletions);
      expect(provider.baseUrl, 'http://127.0.0.1:${server.port}/v1');
      expect(provider.models, ['echo']);
      expect(
        (await credentials.read(LegacyAskAiMigration.providerId))?.key,
        'sk-old',
      );
      expect(
        LlmStores.llm.defaultModel.get(),
        const LlmModelRef(LegacyAskAiMigration.providerId, 'echo'),
      );
    });

    test('and the row, key and all, is gone from the database', () {
      expect(Stores.setting.get<Object>(LegacyAskAiMigration.key), isNull);
      expect(Stores.setting.agentAutoRunSafe.fetch(), isTrue);
    });
  });

  group("a terminal's chat", () {
    final scope = AgentScope.terminal('srv-1');

    test('is offered that terminal and nothing else', () async {
      final id = Chats.create(scope: scope);
      await Chats.send(id, 'hello');
      expect(_tools(seen.last), {'terminal_run', 'terminal_screen'});
      expect(
        (seen.last['messages'] as List).first['content'],
        contains('"web"'),
        reason: 'the prompt names the server',
      );
    });

    test('runs a read-only command by itself, and reads its result', () async {
      ran.clear();
      final id = Chats.create(scope: scope);
      final chat = await Chats.open(id);
      await Chats.send(id, 'list files');

      expect(ran, ['ls']);
      expect(chat.approvals.value, isEmpty);
      final roles = [for (final e in chat.entries.value) e.message?.role];
      expect(roles, ['user', 'assistant', 'toolResult', 'assistant']);
      expect(chat.entries.value.last.message!.text, 'Done.');
    });

    test('runs no more than a few by itself for one message', () async {
      ran.clear();
      final id = Chats.create(scope: scope);
      final chat = await Chats.open(id);
      final sending = Chats.send(id, 'keep listing');

      while (chat.approvals.value.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(ran, List.filled(AgentTools.maxAutoRuns, 'ls'));
      Chats.answer(id, ApprovalAnswer.deny);
      await sending;
      expect(ran, hasLength(AgentTools.maxAutoRuns));
    });

    test('asks before anything destructive, and a no runs nothing', () async {
      ran.clear();
      final id = Chats.create(scope: scope);
      final chat = await Chats.open(id);
      final sending = Chats.send(id, 'wipe it');

      while (chat.approvals.value.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      final pending = chat.approvals.value.single.call;
      expect(pending.name, 'terminal_run');
      // Every call is its own question for a tool like this one.
      expect(Tools.internal(pending.name)?.allowAlways, isFalse);
      Chats.answer(id, ApprovalAnswer.deny);
      await sending;

      expect(ran, isEmpty);
      expect(chat.entries.value.last.message!.text, 'Done.');
    });
  });

  test('a terminal chat is told of the skills and can load them', () async {
    final root = Directory.systemTemp.createTempSync('skills');
    addTearDown(() {
      Skills.remove('nginx');
      root.deleteSync(recursive: true);
    });
    Skills.root = root.path;
    final md = '---\nname: nginx\ndescription: Checks an nginx config.\n---\nRun nginx -t.\n';
    await Skills.install(
      SkillDiscovery.find({'SKILL.md': Uint8List.fromList(utf8.encode(md))}).single,
      SkillSource.parse('o/r'),
    );

    final id = Chats.create(scope: AgentScope.terminal('srv-1'));
    await Chats.send(id, 'hello');
    expect(_tools(seen.last), {'terminal_run', 'terminal_screen', 'skill'});
    expect(
      (seen.last['messages'] as List).first['content'],
      contains('- nginx: Checks an nginx config.'),
    );
  });

  test("the app-wide Agent's chat gets the servers, not a terminal", () async {
    final id = Chats.create();
    await Chats.send(id, 'hello');
    final tools = _tools(seen.last);
    expect(tools, containsAll(['run_shell_command', 'read_file', 'serverbox']));
    expect(tools.intersection({'terminal_run', 'terminal_screen'}), isEmpty);
  });

  test('a terminal chat is listed apart from the app-wide ones', () {
    final terminal = LlmStores.chat.all(scope: AgentScope.terminal('srv-1'));
    final global = LlmStores.chat.all();
    expect(terminal, isNotEmpty);
    expect(global, isNotEmpty);
    expect(
      {for (final m in terminal) m.id}.intersection({
        for (final m in global) m.id,
      }),
      isEmpty,
    );
  });
}
