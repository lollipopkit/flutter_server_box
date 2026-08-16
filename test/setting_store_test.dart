import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:server_box/data/store/setting.dart';

void main() {
  late Directory tempDir;
  late Box<dynamic> box;
  late SettingStore store;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('server-box-setting-test-');
    Hive.init(tempDir.path);
    box = await Hive.openBox<dynamic>('setting_test');
    store = SettingStore.forBox(box);
  });

  setUp(() async {
    await box.clear();
  });

  tearDownAll(() async {
    await box.close();
    await tempDir.delete(recursive: true);
  });

  test('adds Agent to the legacy default home tabs once', () async {
    await box.put('homeTabs', ['server', 'ssh', 'file', 'snippet']);

    await store.migrateHomeTabsAgent();

    expect(box.get('homeTabs'), ['server', 'ssh', 'file', 'snippet', 'agent']);
    expect(box.get('homeTabsAgentMigrated'), isTrue);
  });

  test('preserves a custom home tab configuration', () async {
    await box.put('homeTabs', ['server', 'ssh']);

    await store.migrateHomeTabsAgent();

    expect(box.get('homeTabs'), ['server', 'ssh']);
    expect(box.get('homeTabsAgentMigrated'), isTrue);
  });

  test('preserves home tabs that already contain Agent', () async {
    await box.put('homeTabs', ['server', 'ssh', 'file', 'snippet', 'agent']);

    await store.migrateHomeTabsAgent();

    expect(box.get('homeTabs'), ['server', 'ssh', 'file', 'snippet', 'agent']);
    expect(box.get('homeTabsAgentMigrated'), isTrue);
  });

  test('a second migration does not alter later custom tabs', () async {
    await box.put('homeTabs', ['server', 'ssh', 'file', 'snippet']);
    await store.migrateHomeTabsAgent();
    await box.put('homeTabs', ['server', 'agent']);

    await store.migrateHomeTabsAgent();

    expect(box.get('homeTabs'), ['server', 'agent']);
    expect(box.get('homeTabsAgentMigrated'), isTrue);
  });

  test('removes retired setting keys without touching active settings', () async {
    await box.putAll({
      'moveOutServerTabFuncBtns': true,
      'forceSinglePane': true,
      'recordHistory': false,
    });

    await store.removeRetiredKeys();

    expect(box.containsKey('moveOutServerTabFuncBtns'), isFalse);
    expect(box.containsKey('forceSinglePane'), isFalse);
    expect(box.get('recordHistory'), isFalse);
  });
}
