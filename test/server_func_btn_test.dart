import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

/// What `ServerFuncBtn.autoAddNewFuncs` does to a row the user has already
/// arranged, across an upgrade.
void main() {
  late SettingStore setting;

  setUp(() {
    SqliteDb.openInMemory();
    setting = SettingStore.forTest();
    getIt.registerSingleton<SettingStore>(setting);
  });

  tearDown(() async {
    await getIt.reset();
    await SqliteDb.close();
  });

  /// The stored row, as indices — what the setting actually holds.
  List<int> row() => setting.get<List>('serverBtns')?.cast<int>() ?? const [];

  test('adds every entry that shipped during the upgrade', () async {
    // A row from before systemd (1058), portForward (1340) and power (1481).
    setting.set('serverBtns', [
      ServerFuncBtn.terminal.index,
      ServerFuncBtn.files.index,
    ]);

    ServerFuncBtn.autoAddNewFuncs(1000, 1500);

    expect(row(), [
      ServerFuncBtn.terminal.index,
      ServerFuncBtn.files.index,
      ServerFuncBtn.systemd.index,
      ServerFuncBtn.portForward.index,
      ServerFuncBtn.power.index,
    ]);
  });

  test('adds nothing for an upgrade that shipped no new entry', () async {
    setting.set('serverBtns', [ServerFuncBtn.terminal.index]);

    ServerFuncBtn.autoAddNewFuncs(1481, 1600);

    expect(row(), [ServerFuncBtn.terminal.index]);
  });

  test('leaves an entry the user removed removed', () async {
    // The bug the `(from, to]` window fixes: power shipped in 1481, this
    // install has been running 1500, and the user took it out of the row. An
    // upgrade to 1600 must not put it back — and would have, when the rule was
    // `to >= addedVersion` alone.
    setting.set('serverBtns', [
      ServerFuncBtn.terminal.index,
      ServerFuncBtn.systemd.index,
    ]);

    ServerFuncBtn.autoAddNewFuncs(1500, 1600);

    expect(row(), [ServerFuncBtn.terminal.index, ServerFuncBtn.systemd.index]);
  });

  test('an entry already in the row is not added twice', () async {
    setting.set('serverBtns', [
      ServerFuncBtn.power.index,
      ServerFuncBtn.terminal.index,
    ]);

    ServerFuncBtn.autoAddNewFuncs(1000, 1500);

    expect(
      row().where((e) => e == ServerFuncBtn.power.index).length,
      1,
      reason: 'power was already there',
    );
  });

  test('a fresh install gets the defaults untouched', () async {
    // lastVer is 0 on a first run, and the window is wide open — but the
    // defaults already list every entry, so nothing is appended to them.
    ServerFuncBtn.autoAddNewFuncs(0, 1600);

    expect(
      setting.get<List>('serverBtns'),
      isNull,
      reason: 'nothing was written, so the defaults still apply',
    );
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
