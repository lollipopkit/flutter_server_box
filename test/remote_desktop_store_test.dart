import 'package:fl_lib/fl_lib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:server_box/data/model/server/remote_desktop.dart';
import 'package:server_box/data/store/entity_store.dart';
import 'package:server_box/data/store/remote_desktop.dart';

import 'helpers/test_db.dart';

void main() {
  late RemoteDesktopStore store;

  setUp(() async {
    await openTestDb();
    SqliteDb.instance.execute(
      'INSERT INTO server (id, name, ssh_ip) VALUES '
      "('srv-1', 'one', '10.0.0.1'), ('srv-2', 'two', '10.0.0.2');",
    );
    store = RemoteDesktopStore();
  });

  tearDown(closeTestDb);

  const rdp = RemoteDesktopProfile(
    id: 'rdp-1',
    serverId: 'srv-1',
    name: 'Windows',
    protocol: RemoteDesktopProtocol.rdp,
    port: 3389,
    username: 'administrator',
    password: 'secret',
    domain: 'EXAMPLE',
    trustedCertSha256: 'AA:BB',
  );

  test('RDP and VNC profiles round-trip with their protocol fields', () {
    store.put(rdp);
    store.put(
      const RemoteDesktopProfile(
        id: 'vnc-1',
        serverId: 'srv-1',
        name: 'Console',
        protocol: RemoteDesktopProtocol.vnc,
        port: 5901,
        viewOnly: true,
        shared: false,
      ),
    );

    final profiles = store.fetchForServer('srv-1');
    expect(profiles, hasLength(2));
    expect(profiles.first.name, 'Console');
    expect(profiles.last, rdp);
  });

  test('defaults do not persist a password', () {
    final profile = RemoteDesktopProfile.defaults(
      id: 'vnc-default',
      serverId: 'srv-1',
      name: 'VNC',
      protocol: RemoteDesktopProtocol.vnc,
    );
    store.put(profile);

    final read = store.fetchForServer('srv-1').single;
    expect(read.host, '127.0.0.1');
    expect(read.port, 5900);
    expect(read.password, isNull);
    expect(read.shared, isTrue);
  });

  test('names are unique within a server, not globally', () {
    store.put(rdp);
    expect(
      () => store.put(rdp.copyWith(id: 'rdp-2')),
      throwsA(isA<DuplicateNameException>()),
    );
    expect(
      () => store.put(rdp.copyWith(id: 'rdp-other', serverId: 'srv-2')),
      returnsNormally,
    );
  });

  test('changing the trusted endpoint clears its certificate pin', () {
    store.put(rdp);
    store.put(rdp.copyWith(host: 'windows.internal'));
    expect(store.fetchForServer('srv-1').single.trustedCertSha256, isNull);

    store.put(rdp.copyWith(trustedCertSha256: 'CC:DD'));
    store.put(rdp.copyWith(trustedCertSha256: 'EE:FF'));
    expect(
      store.fetchForServer('srv-1').single.trustedCertSha256,
      'EE:FF',
      reason: 'trust can be explicitly replaced for the same endpoint',
    );
  });

  test('diagnostics redact credentials and certificate material', () {
    final text = rdp.toString();
    expect(text, isNot(contains('secret')));
    expect(text, isNot(contains('administrator')));
    expect(text, isNot(contains('EXAMPLE')));
    expect(text, isNot(contains('AA:BB')));
    expect(text, contains('127.0.0.1'));
  });

  test('deleting a server cascades profiles', () {
    store.put(rdp);
    SqliteDb.instance.execute("DELETE FROM server WHERE id = 'srv-1';");
    store.dropCache();
    expect(store.fetchForServer('srv-1'), isEmpty);
  });
}
