import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/monitor/monitor_access.dart';
import 'package:server_box/data/model/server/monitor/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/store/migrations/build_features.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/data/store/stores.dart';
import 'package:server_box/view/page/server/widget/server_func_btns.dart';

import '../../helpers/test_db.dart';

/// Two questions about the row of things that can be done to a server: what
/// `addNewServerFuncs` does to an arrangement across an upgrade,
/// and which entries a given connection can actually serve.
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

  group('withNewFuncs, on the row alone', () {
    final shipped = [
      for (final btn in ServerFuncBtn.values)
        if (btn.introducedAfterBuild case final boundary?) (btn, boundary),
    ];

    test('an entry is added by the upgrade its boundary falls in, and no other', () {
      for (final (btn, boundary) in shipped) {
        expect(ServerFuncBtn.withNewFuncs(const [], boundary, boundary + 1), contains(btn.name), reason: btn.name);
        expect(ServerFuncBtn.withNewFuncs(const [], boundary + 1, boundary + 2), isNot(contains(btn.name)), reason: btn.name);
        expect(ServerFuncBtn.withNewFuncs(const [], boundary - 1, boundary), isNot(contains(btn.name)), reason: btn.name);
      }
    });

    test('the row keeps its order, and nothing in it is added again', () {
      final (btn, boundary) = shipped.first;
      final row = [btn.name, ServerFuncBtn.terminal.name];
      final next = ServerFuncBtn.withNewFuncs(row, boundary, boundary + 1);
      expect(next.take(2), row);
      expect(next.where((n) => n == btn.name), hasLength(1));
    });
  });

  /// The stored row, as names — what the setting actually holds.
  List<String> row() => setting.serverFuncBtns.get();

  test('adds every entry that shipped during the upgrade', () async {
    // A row from before any of the entries with release boundaries shipped.
    setting.serverFuncBtns.put([
      ServerFuncBtn.terminal.name,
      ServerFuncBtn.files.name,
    ]);

    addNewServerFuncs(1000, 1600);

    expect(row(), [
      ServerFuncBtn.terminal.name,
      ServerFuncBtn.files.name,
      ServerFuncBtn.systemd.name,
      ServerFuncBtn.portForward.name,
      ServerFuncBtn.power.name,
      ServerFuncBtn.users.name,
      ServerFuncBtn.scheduledTasks.name,
    ]);
  });

  test(
    'uses release tags as the Systemd and port-forward boundaries',
    () async {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

      addNewServerFuncs(1051, 1070);
      expect(row(), [
        ServerFuncBtn.terminal.name,
        ServerFuncBtn.systemd.name,
      ]);

      addNewServerFuncs(1340, 1351);
      expect(row(), [
        ServerFuncBtn.terminal.name,
        ServerFuncBtn.systemd.name,
        ServerFuncBtn.portForward.name,
      ]);
    },
  );

  test('adds no entry when the target is the release boundary', () {
    const boundaries = [
      (1051, ServerFuncBtn.systemd),
      (1340, ServerFuncBtn.portForward),
      (1491, ServerFuncBtn.power),
      (1579, ServerFuncBtn.users),
      (1579, ServerFuncBtn.scheduledTasks),
      (1617, ServerFuncBtn.remoteDesktop),
      (1719, ServerFuncBtn.firewall),
      (1719, ServerFuncBtn.storage),
      (1719, ServerFuncBtn.shares),
    ];

    for (final (boundary, button) in boundaries) {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

      addNewServerFuncs(boundary - 1, boundary);

      expect(row(), isNot(contains(button.name)));
    }
  });

  test('adds nothing for an upgrade that shipped no new entry', () async {
    setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

    // A window after the newest entry's boundary. It has to move whenever one
    // is added, which is the point: the assertion is about a window containing
    // no entry, not about two particular numbers.
    addNewServerFuncs(1580, 1600);

    expect(row(), [ServerFuncBtn.terminal.name]);
  });

  test('adds remote desktop after the last build without it', () async {
    setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

    addNewServerFuncs(1617, 1618);

    expect(row(), [
      ServerFuncBtn.terminal.name,
      ServerFuncBtn.remoteDesktop.name,
    ]);
  });

  test('adds storage and shares after the last build without them', () async {
    setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

    addNewServerFuncs(1719, 1720);

    expect(row(), [
      ServerFuncBtn.terminal.name,
      ServerFuncBtn.firewall.name,
      ServerFuncBtn.storage.name,
      ServerFuncBtn.shares.name,
    ]);
  });

  test('leaves an entry the user removed removed', () async {
    // The bug the release window fixes: this install has already run a build
    // containing Power, and the user took it out of the row. An
    // upgrade to 1600 must not put it back — and would have, when the rule was
    // `to` alone.
    setting.serverFuncBtns.put([
      ServerFuncBtn.terminal.name,
      ServerFuncBtn.systemd.name,
    ]);

    addNewServerFuncs(1580, 1600);

    expect(row(), [ServerFuncBtn.terminal.name, ServerFuncBtn.systemd.name]);
  });

  test('an entry already in the row is not added twice', () async {
    setting.serverFuncBtns.put([
      ServerFuncBtn.power.name,
      ServerFuncBtn.terminal.name,
    ]);

    addNewServerFuncs(1000, 1536);

    expect(
      row().where((e) => e == ServerFuncBtn.power.name).length,
      1,
      reason: 'power was already there',
    );
  });

  for (final retainedBuild in [1466, 1480, 1491]) {
    test('adds Power when upgrading from v$retainedBuild', () async {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

      addNewServerFuncs(retainedBuild, 1536);

      expect(row(), [ServerFuncBtn.terminal.name, ServerFuncBtn.power.name]);
    });
  }


  test('a fresh install gets the defaults untouched', () async {
    // lastVer is 0 on a first run, and the window is wide open — but the
    // defaults already list every entry, so nothing is appended to them.
    addNewServerFuncs(0, 1600);

    expect(
      setting.get<List>('serverBtns'),
      isNull,
      reason: 'nothing was written, so the defaults still apply',
    );
    expect(row(), ServerFuncBtn.defaultNames);
    expect(
      ServerFuncBtn.defaultNames,
      containsAll([
        ServerFuncBtn.systemd.name,
        ServerFuncBtn.portForward.name,
        ServerFuncBtn.power.name,
        ServerFuncBtn.users.name,
        ServerFuncBtn.scheduledTasks.name,
        ServerFuncBtn.remoteDesktop.name,
      ]),
    );
  });

  /// Which entries survive for a connection, and in particular that the row is
  /// not an all-or-nothing question.
  ///
  /// Every entry stays on the row; what the agent's access decides is which
  /// of them can be used.
  group('serverFuncBtnsFor', () {
    const monitorOnly = Spi(
      id: 'm',
      name: 'm',
      monitorHttp: MonitorHttpCredential(addr: 'https://agent.example'),
    );

    setUp(() {
      // Everything on, so what comes back is the capability filter's doing and
      // not the user's arrangement.
      setting.serverFuncBtns.put([
        for (final btn in ServerFuncBtn.values) btn.name,
      ]);
    });

    List<ServerFuncBtn> usable(List<ServerFuncEntry> entries) => [
      for (final entry in entries)
        if (entry.available) entry.btn,
    ];

    test('an agent refusing leaves nothing usable, and every entry on the row',
        () {
      final btns = serverFuncBtnsFor(monitorOnly, MonitorAccess.none);
      expect(usable(btns), isEmpty);
      expect(btns, hasLength(ServerFuncBtn.values.length));
      // Before the first poll the agent has said nothing, which is not a grant.
      expect(usable(serverFuncBtnsFor(monitorOnly, null)), isEmpty);
    });

    test('an agent granting access offers everything', () {
      expect(
        usable(serverFuncBtnsFor(monitorOnly, MonitorAccess.granted)),
        unorderedEquals(ServerFuncBtn.values),
      );
    });

    test('an SSH server is not asked the agent anything', () {
      const ssh = Spi(
        id: 's',
        name: 's',
        ssh: SshCredential(ip: '10.0.0.1', port: 22, user: 'root'),
      );

      // Null grant, and still everything: `granted` describes an agent, and
      // this server has none.
      expect(usable(serverFuncBtnsFor(ssh, null)), ServerFuncBtn.values);
    });
  });
}
