import 'package:fl_pi_llm_ui/fl_pi_llm_ui.dart' show ChatMeta, LlmStores;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/core/llm/scope.dart';
import 'package:server_box/data/model/app/float_shell.dart';
import 'package:server_box/data/provider/ai/agent_shell.dart';
import 'package:server_box/data/provider/app/terminal_shell.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import '../../helpers/test_db.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await openTestDb();
    getIt.registerSingleton<SettingStore>(SettingStore('setting_test'));
  });

  tearDown(() async {
    AgentChats.reset();
    await getIt.reset();
    await closeTestDb();
  });

  test('the Agent floats until closed, and stays closed once it is', () {
    var c = ProviderContainer();
    expect(c.read(agentShellProvider), FloatShellMode.expanded);
    expect(c.read(terminalShellProvider).mode, FloatShellMode.hidden, reason: 'the terminal still starts closed');

    c.read(agentShellProvider.notifier).hide();
    c.dispose();
    c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(agentShellProvider), FloatShellMode.hidden);
  });

  // Starting at the newest chat had the floating window open over whatever the
  // app launched to, with a conversation nobody had asked for.
  test('the Agent starts at an empty chat and floats once there is one', () {
    final terminal = AgentScope.terminal('srv');
    LlmStores.chat.put(ChatMeta(id: 'agent-1', updatedAt: DateTime(2026)));
    LlmStores.chat.put(ChatMeta(id: 'term-1', updatedAt: DateTime(2026), scope: terminal));
    AgentChats.reset();

    expect(AgentChats.of(null).value, isNull);
    expect(AgentChats.of(terminal).value, 'term-1', reason: 'a terminal picks up its server\'s chat');
    expect(AgentChats.engaged.value, isFalse);

    AgentChats.select(terminal, 'term-1');
    expect(AgentChats.engaged.value, isFalse, reason: 'a terminal\'s chat is not the Agent\'s');

    AgentChats.select(null, 'agent-1');
    expect(AgentChats.engaged.value, isTrue);
    AgentChats.startNew(null);
    expect(AgentChats.engaged.value, isTrue, reason: 'a new chat in the window keeps the window');
  });

  test('the float button floats even an empty chat', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final shell = c.read(agentShellProvider.notifier)..hide();
    expect(AgentChats.engaged.value, isFalse);
    shell.toggle();
    expect(AgentChats.engaged.value, isTrue);
  });
}
