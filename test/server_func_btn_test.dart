import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/feature.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';

import 'helpers/test_db.dart';

/// What [Features.autoAdd] does to a function-bar row the user has already
/// arranged, across an upgrade.
///
/// Ids rather than indices since m021: the row survives a backup and a sync,
/// and an index stops meaning what it said the moment a case moves.
void main() {
  late SettingStore setting;

  setUp(() async {
    await openTestDb();
    setting = SettingStore('setting_test');
    getIt.registerSingleton<SettingStore>(setting);
  });

  tearDown(() async {
    await getIt.reset();
    await closeTestDb();
  });

  /// The stored row, as ids — what the setting actually holds.
  List<String> row() => setting.serverFuncBtns.get();

  test('adds every entry that shipped during the upgrade', () async {
    // A row from before systemd, port forwarding and Power shipped.
    setting.serverFuncBtns.put([
      ServerFuncBtn.terminal.id,
      ServerFuncBtn.files.id,
    ]);

    Features.autoAdd(1000, 1536);

    expect(row(), [
      ServerFuncBtn.terminal.id,
      ServerFuncBtn.files.id,
      ServerFuncBtn.systemd.id,
      ServerFuncBtn.portForward.id,
      ServerFuncBtn.power.id,
    ]);
  });

  test(
    'uses release tags as the Systemd and port-forward boundaries',
    () async {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.id]);

      Features.autoAdd(1051, 1070);
      expect(row(), [
        ServerFuncBtn.terminal.id,
        ServerFuncBtn.systemd.id,
      ]);

      Features.autoAdd(1340, 1351);
      expect(row(), [
        ServerFuncBtn.terminal.id,
        ServerFuncBtn.systemd.id,
        ServerFuncBtn.portForward.id,
      ]);
    },
  );

  test('adds no entry when the target is the release boundary', () {
    const boundaries = {
      1051: ServerFuncBtn.systemd,
      1340: ServerFuncBtn.portForward,
      1491: ServerFuncBtn.power,
    };

    for (final MapEntry(key: boundary, value: button) in boundaries.entries) {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.id]);

      Features.autoAdd(boundary - 1, boundary);

      expect(row(), isNot(contains(button.id)));
    }
  });

  test('adds nothing for an upgrade that shipped no new entry', () async {
    setting.serverFuncBtns.put([ServerFuncBtn.terminal.id]);

    // A window after the newest entry's boundary. It has to move whenever one
    // is added, which is the point: the assertion is about a window containing
    // no entry, not about two particular numbers.
    Features.autoAdd(1492, 1600);

    expect(row(), [ServerFuncBtn.terminal.id]);
  });

  test('leaves an entry the user removed removed', () async {
    // The bug the release window fixes: this install has already run a build
    // containing Power, and the user took it out of the row. An
    // upgrade to 1600 must not put it back — and would have, when the rule was
    // `to` alone.
    setting.serverFuncBtns.put([
      ServerFuncBtn.terminal.id,
      ServerFuncBtn.systemd.id,
    ]);

    Features.autoAdd(1536, 1600);

    expect(row(), [ServerFuncBtn.terminal.id, ServerFuncBtn.systemd.id]);
  });

  test('an entry already in the row is not added twice', () async {
    setting.serverFuncBtns.put([
      ServerFuncBtn.power.id,
      ServerFuncBtn.terminal.id,
    ]);

    Features.autoAdd(1000, 1536);

    expect(
      row().where((e) => e == ServerFuncBtn.power.id).length,
      1,
      reason: 'power was already there',
    );
  });

  for (final retainedBuild in [1466, 1480, 1491]) {
    test('adds Power when upgrading from v$retainedBuild', () async {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.id]);

      Features.autoAdd(retainedBuild, 1536);

      expect(row(), [ServerFuncBtn.terminal.id, ServerFuncBtn.power.id]);
    });
  }


  test('a fresh install gets the defaults untouched', () async {
    // lastVer is 0 on a first run, and the window is wide open — but the
    // defaults already list every entry, so nothing is appended to them.
    Features.autoAdd(0, 1600);

    expect(
      setting.get<List>('serverBtns'),
      isNull,
      reason: 'nothing was written, so the defaults still apply',
    );
    expect(row(), ServerFuncBtn.defaultIds);
    expect(
      ServerFuncBtn.defaultIds,
      containsAll([
        ServerFuncBtn.systemd.id,
        ServerFuncBtn.portForward.id,
        ServerFuncBtn.power.id,
      ]),
    );
  });
}
