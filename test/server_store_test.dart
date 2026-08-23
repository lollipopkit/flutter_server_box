import 'dart:convert';

import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/custom.dart';
import 'package:server_box/data/model/server/monitor_http_credential.dart';
import 'package:server_box/data/model/server/server_private_info.dart';
import 'package:server_box/data/model/server/ssh_credential.dart';
import 'package:server_box/data/model/server/system.dart';
import 'package:server_box/data/model/server/wol_cfg.dart';
import 'package:server_box/data/store/server.dart';

import 'helpers/test_db.dart';

/// A [Spi] is six tables now, so the question is whether it survives being
/// taken apart and put back together.
void main() {
  late ServerStore store;

  setUp(() async {
    await openTestDb();
    store = ServerStore.forTest();
  });

  tearDown(() async => SqliteDb.close());

  const rich = Spi(
    id: 'srv-1',
    name: 'prod',
    autoConnect: false,
    tags: ['prod', 'db'],
    envs: {'TERM': 'xterm', 'LANG': 'C'},
    disabledCmdTypes: ['sensors'],
    customSystemType: SystemType.linux,
    ssh: SshCredential(
      ip: '10.0.0.1',
      port: 2222,
      user: 'admin',
      pwd: 'hunter2',
      alterUrl: 'a@b:22',
      proxyCommand: 'nc %h %p',
    ),
    wolCfg: WakeOnLanCfg(mac: 'AA:BB:CC:DD:EE:FF', ip: '10.0.0.255'),
    custom: ServerCustom(
      pveAddr: 'https://pve:8006',
      pveIgnoreCert: true,
      cmds: {'up': 'uptime'},
      tempIsCelsius: false,
      netDev: 'eth0',
    ),
  );

  test('a record survives the round trip through six tables', () {
    store.put(rich);
    store.invalidate();

    final got = store.fetchOneRaw('srv-1')!;
    expect(got.name, 'prod');
    expect(got.autoConnect, isFalse);
    expect(got.tags?.toSet(), {'prod', 'db'},
        reason: 'a tag is membership; the child table keeps no order');
    expect(got.envs, {'TERM': 'xterm', 'LANG': 'C'});
    expect(got.disabledCmdTypes, ['sensors']);
    expect(got.customSystemType, SystemType.linux);
    expect(got.ssh?.ip, '10.0.0.1');
    expect(got.ssh?.port, 2222);
    expect(got.ssh?.pwd, 'hunter2');
    expect(got.ssh?.proxyCommand, 'nc %h %p');
    expect(got.wolCfg?.mac, 'AA:BB:CC:DD:EE:FF');
    expect(got.custom?.pveIgnoreCert, isTrue);
    expect(got.custom?.cmds, {'up': 'uptime'});
    expect(got.custom?.tempIsCelsius, isFalse);
  });

  test('a monitor server round trips too', () {
    store.put(const Spi(
      id: 'mon',
      name: 'agent',
      monitorHttp: MonitorHttpCredential(
        addr: 'http://h:3770',
        pwd: 'p',
        allowInsecure: true,
      ),
    ));
    store.invalidate();

    final got = store.fetchOneRaw('mon')!;
    expect(got.ssh, isNull);
    expect(got.monitorHttp?.addr, 'http://h:3770');
    expect(got.monitorHttp?.pwd, 'p');
    expect(got.monitorHttp?.allowInsecure, isTrue);
  });

  test('what an update drops is really dropped', () {
    store.put(rich);
    store.update(rich, rich.copyWith(tags: ['prod'], envs: null));
    store.invalidate();

    final got = store.fetchOneRaw('srv-1')!;
    expect(got.tags, ['prod'], reason: 'the removed tag is gone');
    expect(got.envs, anyOf(isNull, isEmpty));
  });

  test('deleting takes the child rows with it', () {
    store.put(rich);
    store.trustHost('srv-1', 'ssh-ed25519', 'SHA256:x');
    store.deleteById('srv-1');

    for (final t in const ['server_tag', 'server_env', 'known_host']) {
      expect(
        SqliteDb.instance.select('SELECT count(*) AS n FROM $t;').single['n'],
        0,
        reason: t,
      );
    }
    // And says so, so a peer does not put it back.
    expect(
      SqliteDb.instance
          .select("SELECT count(*) AS n FROM tombstone WHERE row_id='srv-1';")
          .single['n'],
      1,
    );
  });

  test('a write stamps the row for the incremental sync', () {
    store.put(rich);
    final first = SqliteDb.instance
        .select('SELECT updated_at, rev FROM server;')
        .single;
    expect(first['updated_at'], greaterThan(0));

    store.put(rich.copyWith(name: 'renamed'));
    final second = SqliteDb.instance
        .select('SELECT updated_at, rev FROM server;')
        .single;
    expect(second['rev'], greaterThan(first['rev'] as int),
        reason: 'two edits in one millisecond still differ');
  });

  test('tags are answered by the database', () {
    store.put(rich);
    store.put(const Spi(
      id: 'srv-2',
      name: 'other',
      tags: ['prod'],
      ssh: SshCredential(ip: '10.0.0.2', user: 'root', port: 22),
    ));

    expect(store.idsWithTag('prod')..sort(), ['srv-1', 'srv-2']);
    expect(store.allTags(), ['db', 'prod']);
  });

  test('a jump host that does not exist is not written', () {
    store.put(rich.copyWith(
      ssh: rich.ssh!.copyWith(jumpIds: ['nope']),
    ));
    store.invalidate();
    expect(store.fetchOneRaw('srv-1')!.ssh?.jumpIds, anyOf(isNull, isEmpty));
  });

  group('restoring a backup', () {
    /// What a backup file holds, rather than what `toJson` returns.
    ///
    /// `Spi.toJson` leaves the nested `SshCredential` as an object — the
    /// backup encoder is what walks it — so a merge is only ever handed the
    /// decoded form.
    Map<String, dynamic> asStored(Spi spi) => Map<String, dynamic>.from(
      json.decode(
        json.encode(spi.toJson(), toEncodable: (o) => (o as dynamic).toJson()),
      ) as Map,
    );

    const jumper = Spi(
      id: 'srv-a',
      name: 'jumper',
      ssh: SshCredential(
        ip: '10.0.0.10',
        user: 'root',
        port: 22,
        jumpIds: ['srv-b'],
      ),
    );
    const target = Spi(
      id: 'srv-b',
      name: 'target',
      ssh: SshCredential(ip: '10.0.0.11', user: 'root', port: 22),
    );

    test('a jump host named before it arrives is still linked', () {
      // The order a backup lists them in is not the order the rows can be
      // written in: a jump host is a server, so `srv-a` names a row that does
      // not exist yet. Writing the link inline dropped it silently.
      store.replaceAll([jumper, target]);

      expect(store.fetchOneRaw('srv-a')!.ssh?.jumpIds, ['srv-b']);
    });

    test('a backup carrying no timestamps still adds its records', () {
      // Every older envelope is like this. Comparing timestamps first made the
      // absent one a tie against a record this device does not have, and the
      // whole backup restored as nothing.
      final added = store.merge({
        'srv-b': asStored(target),
      }, force: false);

      expect(added, isTrue);
      expect(store.fetchOneRaw('srv-b')?.name, 'target');
      expect(
        store.timestamps['srv-b'],
        greaterThan(0),
        reason: 'stamped as now, not as older than everything',
      );
    });

    test('a record the backup never knew about is not deleted', () {
      store.put(rich);
      store.merge({'srv-b': asStored(target)}, force: false);

      expect(store.fetchOneRaw('srv-1'), isNotNull);
    });
  });
}
