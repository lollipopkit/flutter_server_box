import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/app/menu/server_func.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/monitor_remote_access.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/res/store.dart';
import 'package:server_box/data/store/setting.dart';
import 'package:server_box/view/widget/server_func_btns.dart';

import '../../helpers/test_db.dart';

/// Two questions about the row of things that can be done to a server: what
/// `ServerFuncBtn.autoAddNewFuncs` does to an arrangement across an upgrade,
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

  /// The stored row, as names — what the setting actually holds.
  List<String> row() => setting.serverFuncBtns.get();

  test('adds every entry that shipped during the upgrade', () async {
    // A row from before any of the entries with release boundaries shipped.
    setting.serverFuncBtns.put([
      ServerFuncBtn.terminal.name,
      ServerFuncBtn.files.name,
    ]);

    ServerFuncBtn.autoAddNewFuncs(1000, 1600);

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

      ServerFuncBtn.autoAddNewFuncs(1051, 1070);
      expect(row(), [
        ServerFuncBtn.terminal.name,
        ServerFuncBtn.systemd.name,
      ]);

      ServerFuncBtn.autoAddNewFuncs(1340, 1351);
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
    ];

    for (final (boundary, button) in boundaries) {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

      ServerFuncBtn.autoAddNewFuncs(boundary - 1, boundary);

      expect(row(), isNot(contains(button.name)));
    }
  });

  test('adds nothing for an upgrade that shipped no new entry', () async {
    setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

    // A window after the newest entry's boundary. It has to move whenever one
    // is added, which is the point: the assertion is about a window containing
    // no entry, not about two particular numbers.
    ServerFuncBtn.autoAddNewFuncs(1580, 1600);

    expect(row(), [ServerFuncBtn.terminal.name]);
  });

  test('adds remote desktop after the last build without it', () async {
    setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

    ServerFuncBtn.autoAddNewFuncs(1617, 1618);

    expect(row(), [
      ServerFuncBtn.terminal.name,
      ServerFuncBtn.remoteDesktop.name,
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

    ServerFuncBtn.autoAddNewFuncs(1580, 1600);

    expect(row(), [ServerFuncBtn.terminal.name, ServerFuncBtn.systemd.name]);
  });

  test('an entry already in the row is not added twice', () async {
    setting.serverFuncBtns.put([
      ServerFuncBtn.power.name,
      ServerFuncBtn.terminal.name,
    ]);

    ServerFuncBtn.autoAddNewFuncs(1000, 1536);

    expect(
      row().where((e) => e == ServerFuncBtn.power.name).length,
      1,
      reason: 'power was already there',
    );
  });

  for (final retainedBuild in [1466, 1480, 1491]) {
    test('adds Power when upgrading from v$retainedBuild', () async {
      setting.serverFuncBtns.put([ServerFuncBtn.terminal.name]);

      ServerFuncBtn.autoAddNewFuncs(retainedBuild, 1536);

      expect(row(), [ServerFuncBtn.terminal.name, ServerFuncBtn.power.name]);
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
  /// `ServerDetailPage` used to draw the row only when `capabilities.terminal`
  /// was true, which is `full_access` for a monitor server. An agent that
  /// grants `[remote_access.fs]` and nothing else has a Files button and no
  /// others, and that server lost its whole row — while the Files tab, which
  /// asks `caps.files`, went on listing it.
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

    /// Every entry stays on the row, so what the grant decides is the order
    /// and which of them can be used — not how long the row is.
    test('an agent granting only files leaves Files the one usable button', () {
      final btns = serverFuncBtnsFor(
        monitorOnly,
        const MonitorRemoteAccess(files: true),
      );

      expect(usable(btns), [ServerFuncBtn.files]);
      expect(btns.first.btn, ServerFuncBtn.files);
      expect(btns, hasLength(ServerFuncBtn.values.length));
      // The rest keep the user's arrangement behind it.
      expect(btns.last.available, isFalse);
    });

    test('an agent granting nothing leaves nothing usable', () {
      expect(
        usable(serverFuncBtnsFor(monitorOnly, MonitorRemoteAccess.none)),
        isEmpty,
      );
      // Before the first poll the agent has said nothing, which is not a grant.
      expect(usable(serverFuncBtnsFor(monitorOnly, null)), isEmpty);
    });

    test('full access without desktop relay keeps SSH-only actions out', () {
      final btns = usable(
        serverFuncBtnsFor(
          monitorOnly,
          const MonitorRemoteAccess(
            fullAccess: true,
            terminal: true,
            files: true,
          ),
        ),
      );

      // Older agents lack the desktop endpoint; generic port forwarding
      // remains SSH-only even when the agent can run commands.
      expect(btns, isNot(contains(ServerFuncBtn.portForward)));
      expect(btns, isNot(contains(ServerFuncBtn.remoteDesktop)));
      expect(btns, contains(ServerFuncBtn.terminal));
      expect(btns, contains(ServerFuncBtn.files));
      expect(btns, contains(ServerFuncBtn.container));
    });

    test('desktop relay enables RDP/VNC without generic port forwarding', () {
      final btns = usable(
        serverFuncBtnsFor(
          monitorOnly,
          const MonitorRemoteAccess(desktop: true, fullAccess: true),
        ),
      );
      expect(btns, contains(ServerFuncBtn.remoteDesktop));
      expect(btns, isNot(contains(ServerFuncBtn.portForward)));
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
