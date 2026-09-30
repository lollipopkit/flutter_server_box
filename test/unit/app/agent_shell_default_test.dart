import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
