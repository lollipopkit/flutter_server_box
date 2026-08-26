import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

/// What `ServerFuncBtn.autoAddNewFuncs` does to a row the user has already
/// arranged, across an upgrade.
void main() {
  late SettingStore setting;

  setUp(() async {
    await openTestDb();
    setting = SettingStore.forTest();
    getIt.registerSingleton<SettingStore>(setting);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// The stored row, as indices — what the setting actually holds.
  List<int> row() => setting.serverFuncBtns.get();

  test('adds every entry that shipped during the upgrade', () async {
    // A row from before systemd, port forwarding and Power shipped.
    setting.serverFuncBtns.put([
      ServerFuncBtn.terminal.index,
      ServerFuncBtn.files.index,
    ]);

    ServerFuncBtn.autoAddNewFuncs(1000, 1536);

    expect(row(), [
      ServerFuncBtn.terminal.index,
      ServerFuncBtn.files.index,
      ServerFuncBtn.systemd.index,
      ServerFuncBtn.portForward.index,
      ServerFuncBtn.power.index,
    ]);
  });

  test(
    'uses release tags as the Systemd and port-forward boundaries',
    () async {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.index]);

      ServerFuncBtn.autoAddNewFuncs(1051, 1070);
      expect(row(), [
        ServerFuncBtn.terminal.index,
        ServerFuncBtn.systemd.index,
      ]);

      ServerFuncBtn.autoAddNewFuncs(1340, 1351);
      expect(row(), [
        ServerFuncBtn.terminal.index,
        ServerFuncBtn.systemd.index,
        ServerFuncBtn.portForward.index,
      ]);
    },
  );

  test('adds nothing for an upgrade that shipped no new entry', () async {
    setting.serverFuncBtns.put([ServerFuncBtn.terminal.index]);

    ServerFuncBtn.autoAddNewFuncs(1492, 1600);

    expect(row(), [ServerFuncBtn.terminal.index]);
  });

  test('leaves an entry the user removed removed', () async {
    // The bug the release window fixes: this install has already run a build
    // containing Power, and the user took it out of the row. An
    // upgrade to 1600 must not put it back — and would have, when the rule was
    // `to` alone.
    setting.serverFuncBtns.put([
      ServerFuncBtn.terminal.index,
      ServerFuncBtn.systemd.index,
    ]);

    ServerFuncBtn.autoAddNewFuncs(1536, 1600);

    expect(row(), [ServerFuncBtn.terminal.index, ServerFuncBtn.systemd.index]);
  });

  test('an entry already in the row is not added twice', () async {
    setting.serverFuncBtns.put([
      ServerFuncBtn.power.index,
      ServerFuncBtn.terminal.index,
    ]);

    ServerFuncBtn.autoAddNewFuncs(1000, 1536);

    expect(
      row().where((e) => e == ServerFuncBtn.power.index).length,
      1,
      reason: 'power was already there',
    );
  });

  for (final retainedBuild in [1466, 1480, 1491]) {
    test('adds Power when upgrading from v$retainedBuild', () async {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.index]);

      ServerFuncBtn.autoAddNewFuncs(retainedBuild, 1536);

      expect(row(), [ServerFuncBtn.terminal.index, ServerFuncBtn.power.index]);
    });
  }

  test('a fresh install gets the defaults untouched', () async {
    // lastVer is 0 on a first run, and the window is wide open — but the
    // defaults already list every entry, so nothing is appended to them.
    ServerFuncBtn.autoAddNewFuncs(0, 1600);

    expect(
      setting.get<List>('serverBtns'),
      isNull,
      reason: 'nothing was written, so the defaults still apply',
    );
    expect(row(), ServerFuncBtn.defaultIdxs);
    expect(
      ServerFuncBtn.defaultIdxs,
      containsAll([
        ServerFuncBtn.systemd.index,
        ServerFuncBtn.portForward.index,
        ServerFuncBtn.power.index,
      ]),
    );
  });
}
